namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Logs the reviewer's decision on a Project Inspector report and carries it out (the agent writes the decision
/// into its report, PI Report Monitor reads it):
/// Approve sets the project to Quote and raises ProjectReviewApproved, Reject raises ProjectRejected with the findings,
/// Send Questions raises ProjectClarificationRequested with the questions of the report.
/// </summary>
codeunit 50114 "PI Review Decisions"
{
    Access = Internal;

    var
        ApprovedResultTxt: Label 'Status set to Quote; team notified.';
        NotInPlanningResultTxt: Label 'Project was not in Planning (status %1); team notified.', Comment = '%1 = project status';
        RejectedResultTxt: Label 'Team notified with the findings.';
        QuestionsSentResultTxt: Label 'Questions sent to the salesperson.';
        NoQuestionsResultTxt: Label 'The latest report has no questions; nothing was sent.';
        ProjectNotFoundResultTxt: Label 'Project %1 does not exist.', Comment = '%1 = project No.';

    /// <summary>
    /// Logs the decision and carries it out with the report it was made on.
    /// </summary>
    procedure CarryOut(var Job: Record Job; Decision: Enum "PI Review Decision"; ReportText: Text)
    var
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
    begin
        PIReviewDecisionEntry.Get(Register(Job, Decision));
        ProcessDecision(PIReviewDecisionEntry, ReportText);
    end;

    procedure Register(var Job: Record Job; Decision: Enum "PI Review Decision"): Integer
    var
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
    begin
        PIReviewDecisionEntry.Init();
        PIReviewDecisionEntry."Project No." := Job."No.";
        PIReviewDecisionEntry.Decision := Decision;
        PIReviewDecisionEntry."Decided At" := CurrentDateTime();
        PIReviewDecisionEntry."Decided By" := CopyStr(UserId(), 1, MaxStrLen(PIReviewDecisionEntry."Decided By"));
        PIReviewDecisionEntry.Insert(true);
        exit(PIReviewDecisionEntry."Entry No.");
    end;

    /// <summary>
    /// Carries out one decision, using the latest report of the project. A processed decision is not carried out again.
    /// </summary>
    procedure ProcessDecision(var PIReviewDecisionEntry: Record "PI Review Decision Entry"; ReportText: Text)
    var
        Job: Record Job;
        BusinessEvents: Codeunit "PI Business Events";
        ClarificationMgt: Codeunit "PI Clarification Mgt.";
        ReportParser: Codeunit "PI Report Parser";
        Result: Text;
    begin
        if PIReviewDecisionEntry.Processed then
            exit;

        if not Job.Get(PIReviewDecisionEntry."Project No.") then
            Result := StrSubstNo(ProjectNotFoundResultTxt, PIReviewDecisionEntry."Project No.")
        else
            case PIReviewDecisionEntry.Decision of
                PIReviewDecisionEntry.Decision::Approve:
                    begin
                        Result := ApprovedResultTxt;
                        if Job.Status = Job.Status::Planning then begin
                            Job.Validate(Status, Job.Status::Quote);
                            Job.Modify(true);
                        end else
                            Result := StrSubstNo(NotInPlanningResultTxt, Job.Status);
                        BusinessEvents.RaiseReviewApproved(Job);
                    end;
                PIReviewDecisionEntry.Decision::Reject:
                    begin
                        BusinessEvents.RaiseRejected(Job, ReportParser.GetFindingsText(ReportText));
                        Result := RejectedResultTxt;
                    end;
                PIReviewDecisionEntry.Decision::"Send Questions":
                    if ClarificationMgt.SendQuestions(Job."No.", ReportText) then
                        Result := QuestionsSentResultTxt
                    else
                        Result := NoQuestionsResultTxt;
            end;

        PIReviewDecisionEntry.Processed := true;
        PIReviewDecisionEntry."Processed At" := CurrentDateTime();
        PIReviewDecisionEntry.Result := CopyStr(Result, 1, MaxStrLen(PIReviewDecisionEntry.Result));
        PIReviewDecisionEntry.Modify();
    end;
}
