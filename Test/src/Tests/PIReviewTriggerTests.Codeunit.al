namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using System.TestLibraries.Utilities;

/// <summary>
/// When does a project go to Project Inspector?
/// 1. Submit for Review (Scribe Agent through MCP, or the action on the Project Card)
/// 2. A project changes back to status Planning
/// The task message only names the project; the External ID of the task is the project No.
/// </summary>
codeunit 50150 "PI Review Trigger Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        MockTaskDispatcher: Codeunit "PI Mock Task Dispatcher";
        ReviewTrigger: Codeunit "PI Review Trigger";

    [Test]
    procedure SubmitForReviewSendsReviewTaskForProject()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project in status Planning
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Planning);

        // [WHEN] The project is submitted for review
        ReviewTrigger.SubmitForReview(Job);

        // [THEN] One review is sent, identified by the project No.
        Assert.AreEqual(1, MockTaskDispatcher.GetSendCount(), 'One review task must be sent.');
        Assert.AreEqual(Job."No.", MockTaskDispatcher.GetLastProjectNo(), 'The review must be identified by the project No.');
    end;

    [Test]
    procedure SubmitForReviewMessageOnlyNamesTheProject()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project in status Planning
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Planning);

        // [WHEN] The project is submitted for review
        ReviewTrigger.SubmitForReview(Job);

        // [THEN] Title and message are "Review <No.>", the agent finds the open points itself
        Assert.AreEqual('Review ' + Job."No.", MockTaskDispatcher.GetLastTitle(), 'Wrong task title.');
        Assert.AreEqual('Review ' + Job."No.", MockTaskDispatcher.GetLastMessage(), 'Wrong task message.');
    end;

    [Test]
    procedure SubmitForReviewFailsWhenProjectIsNotInPlanning()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project in status Quote
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Quote);

        // [WHEN] The project is submitted for review
        asserterror ReviewTrigger.SubmitForReview(Job);

        // [THEN] An error explains that only Planning projects are reviewed, nothing is sent
        Assert.ExpectedError('is not in status Planning');
        Assert.AreEqual(0, MockTaskDispatcher.GetSendCount(), 'No review task must be sent.');
    end;

    [Test]
    procedure SubmitForReviewFailsWhenNoAgentIsActive()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project in status Planning and no active Project Inspector agent
        TestLibrary.UseMockDispatcher();
        MockTaskDispatcher.SetAvailable(false);
        TestLibrary.CreateProject(Job, Job.Status::Planning);

        // [WHEN] The project is submitted for review
        asserterror ReviewTrigger.SubmitForReview(Job);

        // [THEN] The user is told to activate the agent
        Assert.ExpectedError('No active Project Inspector agent');
        Assert.AreEqual(0, MockTaskDispatcher.GetSendCount(), 'No review task must be sent.');
    end;

    [Test]
    procedure StatusChangedToPlanningSendsReview()
    var
        Job: Record Job;
    begin
        // [GIVEN] An existing project in status Quote
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Quote);

        // [WHEN] The status changes back to Planning
        Job.Validate(Status, Job.Status::Planning);

        // [THEN] The project is sent to Project Inspector
        Assert.AreEqual(1, MockTaskDispatcher.GetSendCount(), 'One review task must be sent.');
        Assert.AreEqual(Job."No.", MockTaskDispatcher.GetLastProjectNo(), 'Wrong project sent for review.');
    end;

    [Test]
    procedure StatusChangedFromPlanningDoesNotSendReview()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project in status Planning
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Planning);

        // [WHEN] The project engineer sets status Quote
        Job.Validate(Status, Job.Status::Quote);

        // [THEN] Nothing is sent
        Assert.AreEqual(0, MockTaskDispatcher.GetSendCount(), 'No review task must be sent.');
    end;

    [Test]
    procedure StatusPlanningValidatedAgainDoesNotSendReview()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project in status Planning
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Planning);

        // [WHEN] Planning is validated again
        Job.Validate(Status, Job.Status::Planning);

        // [THEN] Nothing is sent, the status did not change
        Assert.AreEqual(0, MockTaskDispatcher.GetSendCount(), 'No review task must be sent.');
    end;

    [Test]
    procedure StatusPlanningOnUnsavedProjectDoesNotSendReview()
    var
        Job: Record Job;
        xJob: Record Job;
    begin
        // [GIVEN] A project that is not inserted yet (for example a POST through the API), changing from Quote to Planning
        TestLibrary.UseMockDispatcher();
        Job.Init();
        Job."No." := TestLibrary.NewProjectNo();
        xJob := Job;
        xJob.Status := xJob.Status::Quote;
        Job.Status := Job.Status::Planning;

        // [WHEN] The status trigger reports the change before the insert
        // Called directly: Job.Validate(Status) on an unsaved project fails in the base application (it calls Modify),
        // so this state is only reached when another extension handles OnBeforeValidateStatus.
        ReviewTrigger.OnAfterStatusValidated(Job, xJob);

        // [THEN] Nothing is sent: tasks and planning lines do not exist yet, Scribe Agent calls Submit for Review later
        Assert.AreEqual(0, MockTaskDispatcher.GetSendCount(), 'No review task must be sent for an unsaved project.');
    end;

    [Test]
    procedure StatusPlanningOnTemporaryProjectDoesNotSendReview()
    var
        Job: Record Job;
        TempJob: Record Job temporary;
    begin
        // [GIVEN] An existing project in status Quote, copied into a temporary record (for example a page buffer)
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Quote);
        TempJob := Job;
        TempJob.Insert(false);

        // [WHEN] Status Planning is validated on the temporary record
        TempJob.Validate(Status, TempJob.Status::Planning);

        // [THEN] Nothing is sent, only the real project is reviewed
        Assert.AreEqual(0, MockTaskDispatcher.GetSendCount(), 'No review task must be sent for a temporary project.');
    end;

    [Test]
    procedure StatusChangedToPlanningWithoutActiveAgentDoesNotFail()
    var
        Job: Record Job;
    begin
        // [GIVEN] An existing project in status Quote and no active Project Inspector agent
        TestLibrary.UseMockDispatcher();
        MockTaskDispatcher.SetAvailable(false);
        TestLibrary.CreateProject(Job, Job.Status::Quote);

        // [WHEN] The status changes back to Planning
        Job.Validate(Status, Job.Status::Planning);

        // [THEN] The status change is not blocked and nothing is sent
        Assert.AreEqual(Job.Status::Planning, Job.Status, 'The status change must not be blocked.');
        Assert.AreEqual(0, MockTaskDispatcher.GetSendCount(), 'No review task must be sent.');
    end;
}
