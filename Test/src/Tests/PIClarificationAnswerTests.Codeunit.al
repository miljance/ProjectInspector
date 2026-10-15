namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using System.TestLibraries.Utilities;

/// <summary>
/// The salesperson answers in Teams, Power Automate posts the answer to the
/// clarificationAnswers API and the answer goes to the review task of the project.
/// </summary>
codeunit 50152 "PI Clarification Answer Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        MockTaskDispatcher: Codeunit "PI Mock Task Dispatcher";
        ReviewTrigger: Codeunit "PI Review Trigger";
        SplitAnswerTxt: Label '18 days setup, 8 days data migration, 6 days integration, 6 days testing', Locked = true;

    [Test]
    procedure RegisterAnswerForwardsAnswerToReviewTask()
    var
        Job: Record Job;
        ClarificationAnswer: Record "PI Clarification Answer";
    begin
        // [GIVEN] A project in review and an answer from the salesperson
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        ClarificationAnswer."Project No." := Job."No.";
        ClarificationAnswer.Answer := SplitAnswerTxt;

        // [WHEN] The answer is registered
        ReviewTrigger.RegisterAnswer(ClarificationAnswer);

        // [THEN] The answer is added to the review task of that project
        Assert.AreEqual(1, MockTaskDispatcher.GetAnswerCount(), 'The answer must be added to the review task.');
        Assert.AreEqual(Job."No.", MockTaskDispatcher.GetLastAnswerProjectNo(), 'The answer went to the wrong project.');
        Assert.IsTrue(StrPos(MockTaskDispatcher.GetLastAnswer(), SplitAnswerTxt) > 0, 'The message must contain the answer.');
        Assert.IsTrue(StrPos(MockTaskDispatcher.GetLastAnswer(), Job."No.") > 0, 'The message must name the project.');
    end;

    [Test]
    procedure RegisterAnswerStampsReceivedAt()
    var
        Job: Record Job;
        ClarificationAnswer: Record "PI Clarification Answer";
    begin
        // [GIVEN] A project in review and an answer from the salesperson
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        ClarificationAnswer."Project No." := Job."No.";
        ClarificationAnswer.Answer := SplitAnswerTxt;

        // [WHEN] The answer is registered
        ReviewTrigger.RegisterAnswer(ClarificationAnswer);

        // [THEN] The time it was received is stored
        Assert.AreNotEqual(0DT, ClarificationAnswer."Received At", 'Received At must be filled in.');
    end;

    [Test]
    procedure RegisterAnswerFailsForEmptyAnswer()
    var
        Job: Record Job;
        ClarificationAnswer: Record "PI Clarification Answer";
    begin
        // [GIVEN] A project in review and an empty answer
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        ClarificationAnswer."Project No." := Job."No.";
        ClarificationAnswer.Answer := '   ';

        // [WHEN] The answer is registered
        asserterror ReviewTrigger.RegisterAnswer(ClarificationAnswer);

        // [THEN] It is rejected and nothing is sent to the agent
        Assert.ExpectedError('The answer is empty');
        Assert.AreEqual(0, MockTaskDispatcher.GetAnswerCount(), 'Nothing must be sent to the agent.');
    end;

    [Test]
    procedure RegisterAnswerFailsForUnknownProject()
    var
        ClarificationAnswer: Record "PI Clarification Answer";
    begin
        // [GIVEN] An answer for a project that does not exist
        TestLibrary.UseMockDispatcher();
        ClarificationAnswer."Project No." := TestLibrary.NewProjectNo();
        ClarificationAnswer.Answer := SplitAnswerTxt;

        // [WHEN] The answer is registered
        asserterror ReviewTrigger.RegisterAnswer(ClarificationAnswer);

        // [THEN] It is rejected and nothing is sent to the agent
        Assert.ExpectedError('does not exist');
        Assert.AreEqual(0, MockTaskDispatcher.GetAnswerCount(), 'Nothing must be sent to the agent.');
    end;
}
