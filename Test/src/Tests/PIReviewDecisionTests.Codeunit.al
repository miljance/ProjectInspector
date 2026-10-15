namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using System.TestLibraries.Utilities;

/// <summary>
/// After each report the reviewer decides: Approve (status Quote and a notification), Reject (notification with the
/// findings) or Send Questions (the questions go to the salesperson). The decision is recorded by the Project Card
/// action and carried out once by the report monitor.
/// </summary>
codeunit 50157 "PI Review Decision Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        ReviewDecisions: Codeunit "PI Review Decisions";

    [Test]
    procedure RegisterRecordsAnOpenDecision()
    var
        Job: Record Job;
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
    begin
        // [GIVEN] A project in Planning
        TestLibrary.CreateProject(Job, Job.Status::Planning);

        // [WHEN] The reviewer chooses Reject
        ReviewDecisions.Register(Job, Enum::"PI Review Decision"::Reject);

        // [THEN] One open decision for the project, with who and when
        PIReviewDecisionEntry.SetRange("Project No.", Job."No.");
        Assert.AreEqual(1, PIReviewDecisionEntry.Count(), 'One decision expected.');
        PIReviewDecisionEntry.FindFirst();
        Assert.AreEqual(Enum::"PI Review Decision"::Reject, PIReviewDecisionEntry.Decision, 'Wrong decision.');
        Assert.IsFalse(PIReviewDecisionEntry.Processed, 'The decision must wait for the report monitor.');
        Assert.AreEqual(UserId(), PIReviewDecisionEntry."Decided By", 'Wrong user.');
        Assert.AreNotEqual(0DT, PIReviewDecisionEntry."Decided At", 'Decided At must be set.');
    end;

    [Test]
    procedure ApproveSetsQuoteAndNotifies()
    var
        Job: Record Job;
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A project in Planning with an OPEN POINTS report, and the reviewer approves it anyway
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RegisterDecision(Job, Enum::"PI Review Decision"::Approve, PIReviewDecisionEntry);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The decision is carried out
        ReviewDecisions.ProcessDecision(PIReviewDecisionEntry, TestLibrary.OpenPointsReport(Job."No."));

        // [THEN] The project is in Quote, the team is notified, and the questions are not sent
        UnbindSubscription(ClarificationEventSpy);
        Job.Get(Job."No.");
        Assert.AreEqual(Job.Status::Quote, Job.Status, 'Approve must set the project to Quote.');
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectReviewApproved'), 'One ProjectReviewApproved event expected.');
        Assert.AreEqual(0, ClarificationEventSpy.GetEventCount('ProjectClarificationRequested'), 'No questions on Approve.');
        Assert.IsTrue(PIReviewDecisionEntry.Processed, 'The decision must be processed.');
    end;

    [Test]
    procedure RejectNotifiesWithTheFindings()
    var
        Job: Record Job;
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A project with an ERRORS report, and the reviewer rejects it
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RegisterDecision(Job, Enum::"PI Review Decision"::Reject, PIReviewDecisionEntry);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The decision is carried out
        ReviewDecisions.ProcessDecision(PIReviewDecisionEntry, TestLibrary.ErrorsReport(Job."No."));

        // [THEN] One ProjectRejected event with the findings; the status stays Planning
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectRejected'), 'One ProjectRejected event expected.');
        Assert.AreEqual(
            'Unit Price 1,100 instead of 1,250 for R-CONSULT in task 002010 (PCR-14)' + TestLibrary.LF() +
            'Discount of 375 on R-CONSULT in task 002010 (PCR-16)',
            ClarificationEventSpy.GetLastDetails('ProjectRejected'), 'Wrong findings in the event.');
        Job.Get(Job."No.");
        Assert.AreEqual(Job.Status::Planning, Job.Status, 'Reject must not change the status.');
    end;

    [Test]
    procedure SendQuestionsSendsTheQuestionsOfTheReport()
    var
        Job: Record Job;
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A project with two questions, and the reviewer sends them
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RegisterDecision(Job, Enum::"PI Review Decision"::"Send Questions", PIReviewDecisionEntry);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The decision is carried out
        ReviewDecisions.ProcessDecision(PIReviewDecisionEntry, TestLibrary.TwoQuestionsReport(Job."No."));

        // [THEN] The clarification event carries both questions
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectClarificationRequested'), 'One clarification event expected.');
        Assert.AreEqual(
            'Please confirm the planned start and end date (PCR-20)' + TestLibrary.LF() +
            'Please confirm the support contingent of 60 hours in task 002010 (PCR-23)',
            ClarificationEventSpy.GetLastDetails('ProjectClarificationRequested'), 'Wrong questions in the event.');
    end;

    [Test]
    procedure SendQuestionsWithoutQuestionsRaisesNothing()
    var
        Job: Record Job;
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] An OK report, and the reviewer chooses Send Questions by mistake
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RegisterDecision(Job, Enum::"PI Review Decision"::"Send Questions", PIReviewDecisionEntry);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The decision is carried out
        ReviewDecisions.ProcessDecision(PIReviewDecisionEntry, TestLibrary.OkReport(Job."No."));

        // [THEN] Nothing is sent, and the result says why
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(0, ClarificationEventSpy.GetTotalEventCount(), 'No event expected.');
        Assert.IsTrue(PIReviewDecisionEntry.Processed, 'The decision must be processed.');
        Assert.AreNotEqual('', PIReviewDecisionEntry.Result, 'The result must explain that there were no questions.');
    end;

    [Test]
    procedure ProcessedDecisionIsNotCarriedOutAgain()
    var
        Job: Record Job;
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A rejected project
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RegisterDecision(Job, Enum::"PI Review Decision"::Reject, PIReviewDecisionEntry);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The monitor sees the decision twice
        ReviewDecisions.ProcessDecision(PIReviewDecisionEntry, TestLibrary.ErrorsReport(Job."No."));
        ReviewDecisions.ProcessDecision(PIReviewDecisionEntry, TestLibrary.ErrorsReport(Job."No."));

        // [THEN] The team is notified once
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectRejected'), 'The decision must be carried out once.');
    end;

    local procedure RegisterDecision(var Job: Record Job; Decision: Enum "PI Review Decision"; var PIReviewDecisionEntry: Record "PI Review Decision Entry")
    begin
        ReviewDecisions.Register(Job, Decision);
        PIReviewDecisionEntry.SetRange("Project No.", Job."No.");
        PIReviewDecisionEntry.FindLast();
    end;
}
