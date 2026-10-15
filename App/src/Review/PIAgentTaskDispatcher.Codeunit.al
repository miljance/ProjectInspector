namespace Contoso.ProjectInspector;

using System.Agents;

/// <summary>
/// Creates and continues Project Inspector tasks with the Tasks AL API.
/// One task per project: the External ID of the task is the project No.
/// </summary>
codeunit 50107 "PI Agent Task Dispatcher" implements "PI ITask Dispatcher"
{
    Access = Internal;

    var
        PIAgentSetup: Codeunit "PI Agent Setup";
        NoActiveAgentErr: Label 'No active Project Inspector agent was found. Set up and activate Project Inspector first.';
        NoReviewTaskErr: Label 'There is no Project Inspector task for project %1. Send the project to Project Inspector first.', Comment = '%1 = project No.';

    procedure IsAvailable(): Boolean
    var
        AgentUserSecurityId: Guid;
    begin
        exit(PIAgentSetup.TryGetActiveAgent(AgentUserSecurityId));
    end;

    procedure SendReview(ProjectNo: Code[20]; TaskTitle: Text[150]; MessageText: Text)
    var
        AgentTaskRecord: Record "Agent Task";
        PIAgentKPI: Record "PI Agent KPI";
        AgentTaskBuilder: Codeunit "Agent Task Builder";
        ReportMonitor: Codeunit "PI Report Monitor";
        AgentTaskMessageBuilder: Codeunit "Agent Task Message Builder";
        AgentUserSecurityId: Guid;
    begin
        AgentUserSecurityId := GetActiveAgent();

        if FindReviewTask(AgentUserSecurityId, ProjectNo, AgentTaskRecord) then
            AddMessageToTask(AgentTaskRecord, MessageText)
        else begin
            AgentTaskMessageBuilder
                .Initialize(GetSender(), MessageText)
                .SetRequiresReview(false);
            AgentTaskBuilder
                .Initialize(AgentUserSecurityId, TaskTitle)
                .SetExternalId(ProjectNo)
                .AddTaskMessage(AgentTaskMessageBuilder)
                .Create();
        end;

        PIAgentKPI.AddReviewRequested(AgentUserSecurityId);
        ReportMonitor.EnsureJobQueueEntry(AgentUserSecurityId);
    end;

    procedure AddAnswer(ProjectNo: Code[20]; MessageText: Text)
    var
        AgentTaskRecord: Record "Agent Task";
        PIAgentKPI: Record "PI Agent KPI";
        AgentUserSecurityId: Guid;
    begin
        AgentUserSecurityId := GetActiveAgent();

        if not FindReviewTask(AgentUserSecurityId, ProjectNo, AgentTaskRecord) then
            Error(NoReviewTaskErr, ProjectNo);

        AddMessageToTask(AgentTaskRecord, MessageText);
        PIAgentKPI.AddAnswerReceived(AgentUserSecurityId);
    end;

    procedure StopReview(ProjectNo: Code[20])
    var
        AgentTaskRecord: Record "Agent Task";
        AgentTask: Codeunit "Agent Task";
        AgentUserSecurityId: Guid;
        Attempts: Integer;
    begin
        AgentUserSecurityId := GetActiveAgent();
        Attempts := 0;
        // A stopped task no longer matches FindReviewTask; the limit only guards against a task that does not stop.
        while FindReviewTask(AgentUserSecurityId, ProjectNo, AgentTaskRecord) and (Attempts < 10) do begin
            AgentTask.StopTask(AgentTaskRecord.ID, false);
            Attempts += 1;
        end;
    end;

    local procedure GetActiveAgent() AgentUserSecurityId: Guid
    begin
        if not PIAgentSetup.TryGetActiveAgent(AgentUserSecurityId) then
            Error(NoActiveAgentErr);
    end;

    /// <summary>
    /// Finds the newest task of the project that can still run. A stopped or archived task never runs again,
    /// even with new input, so the project then gets a new task (which also starts with the current instructions).
    /// </summary>
    local procedure FindReviewTask(AgentUserSecurityId: Guid; ProjectNo: Code[20]; var AgentTaskRecord: Record "Agent Task"): Boolean
    begin
        AgentTaskRecord.Reset();
        AgentTaskRecord.SetRange("Agent User Security ID", AgentUserSecurityId);
        AgentTaskRecord.SetRange("External ID", ProjectNo);
        AgentTaskRecord.SetRange(Archived, false);
        AgentTaskRecord.SetFilter(Status, '<>%1&<>%2&<>%3',
            AgentTaskRecord.Status::"Stopped by User", AgentTaskRecord.Status::"Stopped by System", AgentTaskRecord.Status::Stopping);
        exit(AgentTaskRecord.FindLast());
    end;

    local procedure AddMessageToTask(var AgentTaskRecord: Record "Agent Task"; MessageText: Text)
    var
        AgentTaskMessageBuilder: Codeunit "Agent Task Message Builder";
    begin
        // Messages come from the review triggers and from the clarificationAnswers API, not from outside users,
        // so they do not need a manual approval before the agent continues.
        // Create(true) sets the task to Ready when its status allows it.
        AgentTaskMessageBuilder
            .Initialize(GetSender(), MessageText)
            .SetRequiresReview(false)
            .SetAgentTask(AgentTaskRecord)
            .Create(true);
    end;

    local procedure GetSender(): Text[250]
    begin
        exit(CopyStr(UserId(), 1, 250));
    end;
}
