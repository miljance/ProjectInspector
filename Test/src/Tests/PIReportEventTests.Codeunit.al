namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using System.TestLibraries.Utilities;

/// <summary>
/// Events that follow from a report the agent sent: answers it could not apply go to the salesperson
/// (ProjectChangesNotApplied), a cancelled project is announced (ProjectCancelled), and the reviewer's decision the
/// agent wrote into the report ("Decision: APPROVED / REJECTED / QUESTIONS SENT") is carried out.
/// </summary>
codeunit 50156 "PI Report Event Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        ClarificationMgt: Codeunit "PI Clarification Mgt.";

    [Test]
    procedure ChangesNotAppliedAreSentToTheSalesperson()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A report after applying answers, with two points the agent could not apply
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The report is handled
        ClarificationMgt.HandleAgentReport(Job."No.", TestLibrary.AnswersAppliedReport(Job."No."));

        // [THEN] One ProjectChangesNotApplied event carries both points, and the questions are not sent
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectChangesNotApplied'), 'One ProjectChangesNotApplied event expected.');
        Assert.AreEqual(
            'Customer contact: the Sell-to Contact field is not editable for the agent' + TestLibrary.LF() +
            'Discount of 5%: discounts are not allowed (PCR-16)',
            ClarificationEventSpy.GetLastDetails('ProjectChangesNotApplied'), 'Wrong points in the event.');
        Assert.AreEqual(0, ClarificationEventSpy.GetEventCount('ProjectClarificationRequested'), 'Questions wait for the reviewer.');
    end;

    [Test]
    procedure CancelledProjectIsAnnounced()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] The salesperson cancelled the project and the agent stopped
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The CANCELLED report is handled
        ClarificationMgt.HandleAgentReport(Job."No.", TestLibrary.CancelledReport(Job."No."));

        // [THEN] One ProjectCancelled event with the closing line as the reason
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectCancelled'), 'One ProjectCancelled event expected.');
        Assert.AreEqual('Stopped: the salesperson cancelled the project.', ClarificationEventSpy.GetLastDetails('ProjectCancelled'), 'Wrong reason.');
        Assert.AreEqual(1, ClarificationEventSpy.GetTotalEventCount(), 'No other event expected.');
    end;

    [Test]
    procedure ApprovedDecisionSetsQuoteAndNotifies()
    var
        Job: Record Job;
        PIReviewDecisionEntry: Record "PI Review Decision Entry";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] An OPEN POINTS report that the reviewer approved anyway
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The sent report is handled
        ClarificationMgt.HandleAgentReport(Job."No.", TestLibrary.WithDecision(TestLibrary.OpenPointsReport(Job."No."), 'APPROVED'));

        // [THEN] Quote, one approval event, no questions, and the decision is logged
        UnbindSubscription(ClarificationEventSpy);
        Job.Get(Job."No.");
        Assert.AreEqual(Job.Status::Quote, Job.Status, 'Approve must set the project to Quote.');
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectReviewApproved'), 'One approval event expected.');
        Assert.AreEqual(0, ClarificationEventSpy.GetEventCount('ProjectClarificationRequested'), 'No questions on Approve.');
        PIReviewDecisionEntry.SetRange("Project No.", Job."No.");
        PIReviewDecisionEntry.FindFirst();
        Assert.AreEqual(Enum::"PI Review Decision"::Approve, PIReviewDecisionEntry.Decision, 'The decision must be logged.');
        Assert.IsTrue(PIReviewDecisionEntry.Processed, 'The logged decision must be processed.');
    end;

    [Test]
    procedure RejectedDecisionNotifiesWithTheFindings()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] An ERRORS report that the reviewer rejected
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The sent report is handled
        ClarificationMgt.HandleAgentReport(Job."No.", TestLibrary.WithDecision(TestLibrary.ErrorsReport(Job."No."), 'REJECTED'));

        // [THEN] One rejection event with the findings; the questions of the report are not sent
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectRejected'), 'One rejection event expected.');
        Assert.AreEqual(
            'Unit Price 1,100 instead of 1,250 for R-CONSULT in task 002010 (PCR-14)' + TestLibrary.LF() +
            'Discount of 375 on R-CONSULT in task 002010 (PCR-16)',
            ClarificationEventSpy.GetLastDetails('ProjectRejected'), 'Wrong findings in the event.');
        Assert.AreEqual(0, ClarificationEventSpy.GetEventCount('ProjectClarificationRequested'), 'No questions on Reject.');
    end;

    [Test]
    procedure QuestionsSentDecisionSendsTheQuestions()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A report with two questions, and the reviewer chose to send them
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The sent report is handled
        ClarificationMgt.HandleAgentReport(Job."No.", TestLibrary.WithDecision(TestLibrary.TwoQuestionsReport(Job."No."), 'QUESTIONS SENT'));

        // [THEN] The questions go to the salesperson, the decision line is not one of them
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectClarificationRequested'), 'One clarification event expected.');
        Assert.AreEqual(
            'Please confirm the planned start and end date (PCR-20)' + TestLibrary.LF() +
            'Please confirm the support contingent of 60 hours in task 002010 (PCR-23)',
            ClarificationEventSpy.GetLastDetails('ProjectClarificationRequested'), 'Wrong questions in the event.');
    end;

    [Test]
    procedure ReportWithQuestionsOnlyRaisesNothing()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] An OPEN POINTS report
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The report is handled
        // [THEN] Nothing is raised: the reviewer decides whether the questions go out
        Assert.IsFalse(ClarificationMgt.HandleAgentReport(Job."No.", TestLibrary.OpenPointsReport(Job."No.")), 'No event expected.');
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(0, ClarificationEventSpy.GetTotalEventCount(), 'No event expected.');
    end;
}
