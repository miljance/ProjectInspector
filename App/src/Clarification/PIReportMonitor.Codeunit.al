namespace Contoso.ProjectInspector;

using System.Agents;
using System.Threading;

/// <summary>
/// Job queue job: reads the replies Project Inspector sent, raises the events for answers not applied and cancelled
/// projects, and carries out the reviewer's decision the agent wrote into the reply (Approve, Reject, Send Questions).
/// Business Central calls AnalyzeAgentTaskMessage only for the input messages of a task, not for the agent's replies
/// (checked on BC 29), so the events cannot be raised in the agent session. A reply counts once it is Sent or Reviewed,
/// that is after a user chose Continue on the draft.
/// Since 2.5 the agent records its report on the Review Result card and the reviewer decides there; those results are
/// carried out here too.
/// </summary>
codeunit 50113 "PI Report Monitor"
{
    // Public: the job queue runs it from the base application.
    Access = Public;

    var
        JobDescriptionTxt: Label 'Project Inspector: send review decisions and notifications';
        RecordedStatusTxt: Label 'Recorded', Locked = true;
        ApprovedResultTxt: Label 'Approved: status set to Quote, notification sent to Teams.';
        RejectedResultTxt: Label 'Rejected: the findings were sent to Teams.';
        QuestionsSentResultTxt: Label 'Questions sent to the salesperson in Teams.';
        CancelledResultTxt: Label 'Cancelled by the salesperson: notification sent to Teams.';
        NotAppliedResultTxt: Label '%1 Answers that could not be applied were sent to Teams.', Comment = '%1 = what was done with the decision';
        StoppedResultTxt: Label 'Review stopped before a decision.';

    trigger OnRun()
    begin
        CheckSentReports();
        ProcessReviewResults();
    end;

    /// <summary>
    /// Carries out every review result the agent recorded, once: when the reviewer decided, or for a CANCELLED report.
    /// Nothing happens before Continue: a decision chosen on the card counts only after the agent task that recorded
    /// the result has finished. A result without agent task (recorded by a person) counts at once.
    /// A result whose task was stopped is closed without carrying anything out.
    /// </summary>
    procedure ProcessReviewResults()
    var
        PIReviewResult: Record "PI Review Result";
        ProcessedReviewResult: Record "PI Review Result";
        ClarificationMgt: Codeunit "PI Clarification Mgt.";
        DispatcherProvider: Codeunit "PI Dispatcher Provider";
        Dispatcher: Interface "PI ITask Dispatcher";
    begin
        Dispatcher := DispatcherProvider.GetDispatcher();
        PIReviewResult.SetCurrentKey(Processed, "Entry No.");
        PIReviewResult.SetRange(Processed, false);
        if not PIReviewResult.FindSet() then
            exit;

        repeat
            if (PIReviewResult."Agent Task ID" > 0) and Dispatcher.IsReviewTaskStopped(PIReviewResult."Agent Task ID") then begin
                ProcessedReviewResult.Get(PIReviewResult."Entry No.");
                ProcessedReviewResult.Result := StoppedResultTxt;
                ProcessedReviewResult.Processed := true;
                ProcessedReviewResult."Processed At" := CurrentDateTime();
                ProcessedReviewResult.Modify();
            end else
            if (PIReviewResult.Report <> '') and
               ((PIReviewResult.Decision <> PIReviewResult.Decision::" ") or ClarificationMgt.IsCancelled(PIReviewResult.Report)) and
               ((PIReviewResult."Agent Task ID" <= 0) or Dispatcher.IsReviewTaskFinished(PIReviewResult."Agent Task ID"))
            then begin
                // Processed is in the key the loop runs on, so the change is written through a second record.
                ProcessedReviewResult.Get(PIReviewResult."Entry No.");
                ClarificationMgt.HandleReviewResult(ProcessedReviewResult."Project No.", ProcessedReviewResult.Report, ProcessedReviewResult.Decision);
                ProcessedReviewResult.Result := GetResultText(ProcessedReviewResult);
                ProcessedReviewResult.Processed := true;
                ProcessedReviewResult."Processed At" := CurrentDateTime();
                ProcessedReviewResult.Modify();
            end;
        until PIReviewResult.Next() = 0;
    end;

    /// <summary>
    /// What happened with a carried-out result, for the Result field on the card.
    /// </summary>
    local procedure GetResultText(var PIReviewResult: Record "PI Review Result"): Text[250]
    var
        ClarificationMgt: Codeunit "PI Clarification Mgt.";
        ReportParser: Codeunit "PI Report Parser";
        ResultText: Text;
    begin
        if ClarificationMgt.IsCancelled(PIReviewResult.Report) then
            exit(CancelledResultTxt);

        case PIReviewResult.Decision of
            PIReviewResult.Decision::Approve:
                ResultText := ApprovedResultTxt;
            PIReviewResult.Decision::Reject:
                ResultText := RejectedResultTxt;
            PIReviewResult.Decision::"Send Questions":
                ResultText := QuestionsSentResultTxt;
        end;
        if ReportParser.GetNotAppliedText(PIReviewResult.Report) <> '' then
            ResultText := StrSubstNo(NotAppliedResultTxt, ResultText);
        exit(CopyStr(ResultText, 1, 250));
    end;

    /// <summary>
    /// Links results recorded before version 2.8 to the newest task of their project, so a decision chosen on the
    /// card before the upgrade also waits for Continue. Called on upgrade.
    /// </summary>
    procedure LinkResultsToTasks()
    var
        PIReviewResult: Record "PI Review Result";
        AgentTask: Record "Agent Task";
    begin
        PIReviewResult.SetRange(Processed, false);
        PIReviewResult.SetRange("Agent Task ID", 0);
        if PIReviewResult.FindSet(true) then
            repeat
                AgentTask.SetRange("External ID", PIReviewResult."Project No.");
                AgentTask.SetRange("Company Name", CompanyName());
                if AgentTask.FindLast() then begin
                    PIReviewResult."Agent Task ID" := AgentTask.ID;
                    PIReviewResult.Modify();
                end;
            until PIReviewResult.Next() = 0;
    end;

    /// <summary>
    /// The newest report of Project Inspector on the newest task of the project in this company: its reply, or the
    /// result it recorded on the Review Result card when that is newer (ReportStatus is then "Recorded").
    /// </summary>
    procedure GetLatestReport(ProjectNo: Code[20]; var TaskId: BigInteger; var TaskStatus: Text; var ReportStatus: Text; var ReportCreatedAt: DateTime; var ReportText: Text): Boolean
    var
        AgentTask: Record "Agent Task";
        AgentTaskMessage: Record "Agent Task Message";
        PIReviewResult: Record "PI Review Result";
        PIAgentSetup: Codeunit "PI Agent Setup";
        AgentMessage: Codeunit "Agent Message";
        AgentUserSecurityId: Guid;
    begin
        Clear(TaskId);
        Clear(TaskStatus);
        Clear(ReportStatus);
        Clear(ReportCreatedAt);
        Clear(ReportText);
        if not PIAgentSetup.TryGetActiveAgent(AgentUserSecurityId) then
            exit(false);

        AgentTask.SetRange("Agent User Security ID", AgentUserSecurityId);
        AgentTask.SetRange("External ID", ProjectNo);
        AgentTask.SetRange("Company Name", CompanyName());
        if not AgentTask.FindLast() then
            exit(false);
        TaskId := AgentTask.ID;
        TaskStatus := Format(AgentTask.Status);

        AgentTaskMessage.SetRange("Task ID", AgentTask.ID);
        AgentTaskMessage.SetRange(Type, AgentTaskMessage.Type::Output);
        if AgentTaskMessage.FindSet() then
            repeat
                if AgentTaskMessage.SystemCreatedAt > ReportCreatedAt then begin
                    ReportCreatedAt := AgentTaskMessage.SystemCreatedAt;
                    ReportStatus := Format(AgentTaskMessage.Status);
                    ReportText := AgentMessage.GetText(AgentTaskMessage);
                end;
            until AgentTaskMessage.Next() = 0;

        PIReviewResult.SetRange("Project No.", ProjectNo);
        PIReviewResult.SetFilter(Report, '<>%1', '');
        PIReviewResult.SetFilter("Recorded At", '>%1', ReportCreatedAt);
        if PIReviewResult.FindLast() then begin
            ReportCreatedAt := PIReviewResult."Recorded At";
            ReportStatus := RecordedStatusTxt;
            ReportText := PIReviewResult.Report;
        end;
        exit(ReportText <> '');
    end;

    procedure CheckSentReports()
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
    begin
        if PIAgentSetupRecord.FindSet() then
            repeat
                CheckAgent(PIAgentSetupRecord."User Security ID");
            until PIAgentSetupRecord.Next() = 0;
    end;

    /// <summary>
    /// Reads one reply of the agent. Each reply is read once; the business event is raised when it has questions.
    /// </summary>
    procedure ProcessReport(MessageId: Guid; TaskId: BigInteger; ExternalId: Text; ReportText: Text): Boolean
    var
        PIProcessedReport: Record "PI Processed Report";
        ClarificationMgt: Codeunit "PI Clarification Mgt.";
    begin
        if PIProcessedReport.Get(MessageId) then
            exit(false);

        PIProcessedReport.Init();
        PIProcessedReport."Message ID" := MessageId;
        PIProcessedReport."Task ID" := TaskId;
        PIProcessedReport."Project No." := CopyStr(ExternalId, 1, MaxStrLen(PIProcessedReport."Project No."));
        PIProcessedReport."Event Raised" := ClarificationMgt.HandleAgentReport(ExternalId, ReportText);
        PIProcessedReport."Processed At" := CurrentDateTime();
        PIProcessedReport.Insert();
        exit(PIProcessedReport."Event Raised");
    end;

    /// <summary>
    /// Creates the recurring job in the current company, once. Replies written before that are not read,
    /// so old reports are not sent to the salesperson again. Needs write permission on job queue entries.
    /// </summary>
    procedure EnsureJobQueueEntry(AgentUserSecurityId: Guid)
    var
        JobQueueEntry: Record "Job Queue Entry";
        PIAgentKPI: Record "PI Agent KPI";
    begin
        PIAgentKPI.StartReportCheck(AgentUserSecurityId);

        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"PI Report Monitor");
        if not JobQueueEntry.IsEmpty() then
            exit;
        if not JobQueueEntry.WritePermission() then
            exit;

        JobQueueEntry.Init();
        JobQueueEntry.Validate("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.Validate("Object ID to Run", Codeunit::"PI Report Monitor");
        JobQueueEntry.Description := CopyStr(JobDescriptionTxt, 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."Run on Mondays" := true;
        JobQueueEntry."Run on Tuesdays" := true;
        JobQueueEntry."Run on Wednesdays" := true;
        JobQueueEntry."Run on Thursdays" := true;
        JobQueueEntry."Run on Fridays" := true;
        JobQueueEntry."Run on Saturdays" := true;
        JobQueueEntry."Run on Sundays" := true;
        JobQueueEntry."No. of Minutes between Runs" := 1;
        Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry);
    end;

    local procedure CheckAgent(AgentUserSecurityId: Guid)
    var
        AgentTask: Record "Agent Task";
        AgentTaskMessage: Record "Agent Task Message";
        PIAgentKPI: Record "PI Agent KPI";
        AgentMessage: Codeunit "Agent Message";
    begin
        AgentTaskMessage.SetRange("Agent User Security ID", AgentUserSecurityId);
        AgentTaskMessage.SetRange(Type, AgentTaskMessage.Type::Output);
        AgentTaskMessage.SetFilter(Status, '%1|%2', AgentTaskMessage.Status::Sent, AgentTaskMessage.Status::Reviewed);
        AgentTaskMessage.SetFilter(SystemCreatedAt, '>=%1', PIAgentKPI.StartReportCheck(AgentUserSecurityId));
        if not AgentTaskMessage.FindSet() then
            exit;

        repeat
            if AgentTask.Get(AgentTaskMessage."Task ID") then
                if AgentTask."Company Name" = CompanyName() then
                    ProcessReport(AgentTaskMessage.ID, AgentTaskMessage."Task ID", AgentTask."External ID", AgentMessage.GetText(AgentTaskMessage));
        until AgentTaskMessage.Next() = 0;
    end;
}
