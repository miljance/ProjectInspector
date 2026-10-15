namespace Contoso.ProjectInspector;

using System.Agents;
using System.Threading;

/// <summary>
/// Job queue job: reads the replies Project Inspector sent and raises ProjectClarificationRequested for each one with questions.
/// Business Central calls AnalyzeAgentTaskMessage only for the input messages of a task, not for the agent's replies
/// (checked on BC 29), so the event cannot be raised in the agent session. A reply counts once it is Sent or Reviewed,
/// that is after a user chose Continue on the draft.
/// </summary>
codeunit 50113 "PI Report Monitor"
{
    // Public: the job queue runs it from the base application.
    Access = Public;

    var
        JobDescriptionTxt: Label 'Project Inspector: send questions from review reports to the salesperson';

    trigger OnRun()
    begin
        CheckSentReports();
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
