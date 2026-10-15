namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Raises the business events for a review report: automatically for answers not applied and cancellations,
/// on the reviewer's decision for the questions.
/// </summary>
codeunit 50110 "PI Clarification Mgt."
{
    Access = Internal;

    var
        ReportParser: Codeunit "PI Report Parser";
        BusinessEvents: Codeunit "PI Business Events";
        CancelledStatusTok: Label 'CANCELLED', Locked = true;
        ApprovedDecisionTok: Label 'APPROVED', Locked = true;
        RejectedDecisionTok: Label 'REJECTED', Locked = true;
        QuestionsSentDecisionTok: Label 'QUESTIONS SENT', Locked = true;

    /// <summary>
    /// Called for every report the agent sent: raises ProjectChangesNotApplied and ProjectCancelled, and carries out the
    /// reviewer's decision the agent wrote into the report ("Decision: APPROVED / REJECTED / QUESTIONS SENT").
    /// Questions go out only on that decision. Returns true when an event was raised.
    /// </summary>
    /// <param name="ExternalId">External ID of the agent task, which is the project No. Empty for tasks started by hand.</param>
    /// <param name="ReportText">The text of the agent message.</param>
    procedure HandleAgentReport(ExternalId: Text; ReportText: Text) Raised: Boolean
    var
        Job: Record Job;
        ReviewDecisions: Codeunit "PI Review Decisions";
        NotApplied: Text;
        Decision: Enum "PI Review Decision";
    begin
        if not FindProject(ExternalId, ReportText, Job) then
            exit(false);

        if ReportParser.GetStatus(ReportText) = CancelledStatusTok then begin
            BusinessEvents.RaiseCancelled(Job, ReportParser.GetClosingLine(ReportText));
            exit(true);
        end;

        NotApplied := ReportParser.GetNotAppliedText(ReportText);
        if NotApplied <> '' then begin
            BusinessEvents.RaiseChangesNotApplied(Job, NotApplied);
            Raised := true;
        end;

        if TryGetDecision(ReportParser.GetDecision(ReportText), Decision) then begin
            ReviewDecisions.CarryOut(Job, Decision, ReportText);
            Raised := true;
        end;
    end;

    local procedure TryGetDecision(DecisionText: Text; var Decision: Enum "PI Review Decision"): Boolean
    begin
        case DecisionText of
            ApprovedDecisionTok:
                Decision := Decision::Approve;
            RejectedDecisionTok:
                Decision := Decision::Reject;
            QuestionsSentDecisionTok:
                Decision := Decision::"Send Questions";
            else
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Sends the questions of the report to the salesperson. Returns true when the business event was raised.
    /// </summary>
    procedure SendQuestions(ExternalId: Text; ReportText: Text): Boolean
    var
        Job: Record Job;
    begin
        if not ReportParser.HasQuestions(ReportText) then
            exit(false);
        if not FindProject(ExternalId, ReportText, Job) then
            exit(false);

        BusinessEvents.RaiseClarificationRequested(Job, ReportParser.GetStatus(ReportText), ReportParser.GetQuestionsText(ReportText));
        exit(true);
    end;

    /// <summary>
    /// The project of the report: the External ID of the task, otherwise the project No. in the first line.
    /// A project that no longer exists still gets its No., so the event names it.
    /// </summary>
    local procedure FindProject(ExternalId: Text; ReportText: Text; var Job: Record Job): Boolean
    var
        ProjectNo: Code[20];
    begin
        ProjectNo := CopyStr(ExternalId, 1, MaxStrLen(ProjectNo));
        if ProjectNo = '' then
            ProjectNo := ReportParser.GetProjectNo(ReportText);
        if ProjectNo = '' then
            exit(false);

        if not Job.Get(ProjectNo) then
            Job."No." := ProjectNo;
        exit(true);
    end;
}
