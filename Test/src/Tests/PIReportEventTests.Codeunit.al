namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using System.TestLibraries.Utilities;

/// <summary>
/// Events that follow from a sent report without a decision of the reviewer: answers the agent could not apply go to
/// the salesperson (ProjectChangesNotApplied), a cancelled project is announced (ProjectCancelled). Questions wait for
/// the reviewer's decision.
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
