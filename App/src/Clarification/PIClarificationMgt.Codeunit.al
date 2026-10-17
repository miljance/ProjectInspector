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
        ApprovedDecisionTok: Label 'APPROVE', Locked = true;
        RejectedDecisionTok: Label 'REJECT', Locked = true;
        QuestionsSentDecisionTok: Label 'QUESTIONS', Locked = true;
        SendQuestionsDecisionTok: Label 'SEND', Locked = true;

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

    /// <summary>
    /// Called for a review result the agent recorded on the Review Result card: raises ProjectCancelled for a CANCELLED
    /// report and ProjectChangesNotApplied for answers not applied, and carries out the reviewer's decision from the
    /// card. Returns true when an event was raised.
    /// </summary>
    procedure HandleReviewResult(ProjectNo: Code[20]; ReportText: Text; ResultDecision: Enum "PI Review Result Decision"; var DecisionDone: Boolean; var DecisionResult: Text) Raised: Boolean
    var
        Job: Record Job;
        ReviewDecisions: Codeunit "PI Review Decisions";
        NotApplied: Text;
    begin
        DecisionDone := false;
        Clear(DecisionResult);
        if not FindProject(ProjectNo, ReportText, Job) then
            exit(false);

        if IsCancelled(ReportText) then begin
            BusinessEvents.RaiseCancelled(Job, ReportParser.GetClosingLine(ReportText));
            exit(true);
        end;

        NotApplied := ReportParser.GetNotAppliedText(ReportText);
        if NotApplied <> '' then begin
            BusinessEvents.RaiseChangesNotApplied(Job, NotApplied);
            Raised := true;
        end;

        case ResultDecision of
            ResultDecision::Approve:
                DecisionDone := ReviewDecisions.CarryOut(Job, Enum::"PI Review Decision"::Approve, ReportText, DecisionResult);
            ResultDecision::Reject:
                DecisionDone := ReviewDecisions.CarryOut(Job, Enum::"PI Review Decision"::Reject, ReportText, DecisionResult);
            ResultDecision::"Send Questions":
                DecisionDone := ReviewDecisions.CarryOut(Job, Enum::"PI Review Decision"::"Send Questions", ReportText, DecisionResult);
            else
                exit;
        end;
        Raised := true;
    end;

    /// <summary>
    /// True for a CANCELLED report, which is carried out without a reviewer's decision.
    /// </summary>
    procedure IsCancelled(ReportText: Text): Boolean
    begin
        exit(ReportParser.GetStatus(ReportText) = CancelledStatusTok);
    end;

    /// <summary>
    /// The reviewer may overwrite the decision the agent proposed in the reply, so only the start of the word counts:
    /// "APPROVED (change to ...)", "approve", "Reject" and "send questions" are all read. The text is already upper case.
    /// </summary>
    local procedure TryGetDecision(DecisionText: Text; var Decision: Enum "PI Review Decision"): Boolean
    begin
        case true of
            DecisionText.StartsWith(ApprovedDecisionTok):
                Decision := Decision::Approve;
            DecisionText.StartsWith(RejectedDecisionTok):
                Decision := Decision::Reject;
            DecisionText.StartsWith(QuestionsSentDecisionTok), DecisionText.StartsWith(SendQuestionsDecisionTok):
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
