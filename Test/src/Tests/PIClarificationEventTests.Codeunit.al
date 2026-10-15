namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using System.TestLibraries.Utilities;

/// <summary>
/// When the reviewer chooses Send Questions, Business Central raises the ProjectClarificationRequested business
/// event with the questions of the report. Power Automate picks it up and asks in Teams.
/// </summary>
codeunit 50153 "PI Clarification Event Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        ClarificationMgt: Codeunit "PI Clarification Mgt.";

    [Test]
    procedure ReportWithQuestionRaisesClarificationEvent()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A project and an OPEN POINTS report for it
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The agent writes the report for the review task of the project
        ClarificationMgt.SendQuestions(Job."No.", TestLibrary.OpenPointsReport(Job."No."));

        // [THEN] One clarification event is raised with the question
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetRaisedCount(), 'One clarification event expected.');
        Assert.AreEqual(Job."No.", ClarificationEventSpy.GetLastProjectNo(), 'Wrong project in the event.');
        Assert.AreEqual('Please split the 38 days in task 003010 by phase (PCR-23)', ClarificationEventSpy.GetLastQuestions(), 'Wrong questions in the event.');
    end;

    [Test]
    procedure SendQuestionsTellsWhetherTheEventWasRaised()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project
        TestLibrary.CreateProject(Job, Job.Status::Planning);

        // [WHEN] The agent writes a report with questions, and then one without
        // [THEN] Only the first one reports a raised event, so the agent timeline can say that the salesperson was asked
        Assert.IsTrue(ClarificationMgt.SendQuestions(Job."No.", TestLibrary.OpenPointsReport(Job."No.")), 'A report with questions must raise the event.');
        Assert.IsFalse(ClarificationMgt.SendQuestions(Job."No.", TestLibrary.OkReport(Job."No.")), 'A report without questions must not raise the event.');
    end;

    [Test]
    procedure ReportWithTwoQuestionsSendsThemOnePerLine()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A project and a report with two questions
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The agent writes the report
        ClarificationMgt.SendQuestions(Job."No.", TestLibrary.TwoQuestionsReport(Job."No."));

        // [THEN] The event carries both questions, one per line
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(
            'Please confirm the planned start and end date (PCR-20)' + TestLibrary.LF() +
            'Please confirm the support contingent of 60 hours in task 002010 (PCR-23)',
            ClarificationEventSpy.GetLastQuestions(), 'Wrong questions in the event.');
    end;

    [Test]
    procedure ReportWithoutQuestionsRaisesNothing()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A project and an OK report
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The agent writes the report
        ClarificationMgt.SendQuestions(Job."No.", TestLibrary.OkReport(Job."No."));

        // [THEN] No clarification is requested
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(0, ClarificationEventSpy.GetRaisedCount(), 'No clarification event expected.');
    end;

    [Test]
    procedure ProjectNoIsTakenFromReportWhenTaskHasNoExternalId()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] A task started by hand in the playground, without External ID
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The agent writes the report
        ClarificationMgt.SendQuestions('', TestLibrary.ErrorsReport(Job."No."));

        // [THEN] The project No. comes from the first line of the report
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetRaisedCount(), 'One clarification event expected.');
        Assert.AreEqual(Job."No.", ClarificationEventSpy.GetLastProjectNo(), 'Wrong project in the event.');
    end;
}
