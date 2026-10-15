namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Sends projects to Project Inspector and passes the answers of the salesperson back to the agent.
/// Triggers: Submit for Review (projectReviews API and Project Card action) and a status change to Planning.
/// </summary>
codeunit 50106 "PI Review Trigger"
{
    Access = Public;

    var
        DispatcherProvider: Codeunit "PI Dispatcher Provider";
        ReviewTxt: Label 'Review %1', Comment = '%1 = project No.', Locked = true;
        AnswerTxt: Label 'Answers from the salesperson for project %1:', Comment = '%1 = project No.', Locked = true;
        NotInPlanningErr: Label 'Project %1 is not in status Planning. Project Inspector only reviews projects in status Planning.', Comment = '%1 = project No.';
        NoActiveAgentErr: Label 'No active Project Inspector agent was found. Set up and activate Project Inspector first.';
        EmptyAnswerErr: Label 'The answer is empty.';
        ProjectNotFoundErr: Label 'Project %1 does not exist.', Comment = '%1 = project No.';

    /// <summary>
    /// Sends the project to Project Inspector. Called by Scribe Agent (projectReviews API) and by the Project Card action.
    /// </summary>
    procedure SubmitForReview(var Job: Record Job)
    var
        Dispatcher: Interface "PI ITask Dispatcher";
    begin
        if Job.Status <> Job.Status::Planning then
            Error(NotInPlanningErr, Job."No.");

        Dispatcher := DispatcherProvider.GetDispatcher();
        if not Dispatcher.IsAvailable() then
            Error(NoActiveAgentErr);

        SendReview(Dispatcher, Job);
    end;

    /// <summary>
    /// Called after the Status of a project was validated. Sends the project for review when an existing
    /// project changes to Planning. Never blocks the status change.
    /// </summary>
    procedure OnAfterStatusValidated(var Job: Record Job; var xJob: Record Job)
    var
        ExistingJob: Record Job;
        Dispatcher: Interface "PI ITask Dispatcher";
    begin
        if Job.IsTemporary() then
            exit;
        if Job.Status <> Job.Status::Planning then
            exit;
        if xJob.Status = Job.Status::Planning then
            exit;
        // A new project (for example a POST through the API) has no tasks and planning lines yet.
        // Scribe Agent sends it with Submit for Review when it is complete.
        if not ExistingJob.Get(Job."No.") then
            exit;

        Dispatcher := DispatcherProvider.GetDispatcher();
        if not Dispatcher.IsAvailable() then
            exit;

        SendReview(Dispatcher, Job);
    end;

    /// <summary>
    /// Passes the answer of the salesperson to the review task of the project.
    /// Called by the clarificationAnswers API (Power Automate, after the Teams adaptive card).
    /// </summary>
    procedure RegisterAnswer(var ClarificationAnswer: Record "PI Clarification Answer")
    var
        Job: Record Job;
        Dispatcher: Interface "PI ITask Dispatcher";
        LineFeed: Text[1];
    begin
        if DelChr(ClarificationAnswer.Answer, '<>', ' ') = '' then
            Error(EmptyAnswerErr);
        if not Job.Get(ClarificationAnswer."Project No.") then
            Error(ProjectNotFoundErr, ClarificationAnswer."Project No.");

        LineFeed[1] := 10;
        Dispatcher := DispatcherProvider.GetDispatcher();
        Dispatcher.AddAnswer(Job."No.", StrSubstNo(AnswerTxt, Job."No.") + LineFeed + ClarificationAnswer.Answer);
        ClarificationAnswer."Received At" := CurrentDateTime();
    end;

    local procedure SendReview(Dispatcher: Interface "PI ITask Dispatcher"; var Job: Record Job)
    var
        ReviewText: Text;
    begin
        ReviewText := StrSubstNo(ReviewTxt, Job."No.");
        Dispatcher.SendReview(Job."No.", CopyStr(ReviewText, 1, 150), ReviewText);
    end;
}
