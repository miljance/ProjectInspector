namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using System.TestLibraries.Utilities;

/// <summary>
/// Business Central calls AnalyzeAgentTaskMessage only for the input messages of an agent task, not for the
/// agent's replies. The report monitor job therefore reads the replies that were sent and raises the automatic
/// events (answers not applied, project cancelled) for each of them exactly once.
/// </summary>
codeunit 50155 "PI Report Monitor Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        ReportMonitor: Codeunit "PI Report Monitor";

    [Test]
    procedure SentReportWithChangesNotAppliedRaisesTheEventOnce()
    var
        Job: Record Job;
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
        MessageId: Guid;
    begin
        // [GIVEN] A reply of the agent after applying answers, with points it could not apply
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        MessageId := CreateGuid();
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The monitor sees the same reply twice (two job runs)
        ReportMonitor.ProcessReport(MessageId, 25, Job."No.", TestLibrary.AnswersAppliedReport(Job."No."));
        ReportMonitor.ProcessReport(MessageId, 25, Job."No.", TestLibrary.AnswersAppliedReport(Job."No."));

        // [THEN] The salesperson is told once; the questions of the report are not sent without a decision
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectChangesNotApplied'), 'The event must be raised once per reply.');
        Assert.AreEqual(0, ClarificationEventSpy.GetEventCount('ProjectClarificationRequested'), 'Questions go out only on the reviewer''s decision.');
    end;

    [Test]
    procedure ProcessedReportIsLogged()
    var
        Job: Record Job;
        PIProcessedReport: Record "PI Processed Report";
        MessageId: Guid;
        TaskId: BigInteger;
    begin
        // [GIVEN] A reply of the agent with points it could not apply
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        MessageId := CreateGuid();
        TaskId := 25;

        // [WHEN] The monitor processes it
        ReportMonitor.ProcessReport(MessageId, TaskId, Job."No.", TestLibrary.AnswersAppliedReport(Job."No."));

        // [THEN] The log shows the task, the project and that the event was raised
        PIProcessedReport.Get(MessageId);
        Assert.AreEqual(TaskId, PIProcessedReport."Task ID", 'Wrong task ID.');
        Assert.AreEqual(Job."No.", PIProcessedReport."Project No.", 'Wrong project No.');
        Assert.IsTrue(PIProcessedReport."Event Raised", 'The event must be logged as raised.');
    end;

    [Test]
    procedure ReportWithOnlyQuestionsIsLoggedWithoutEvent()
    var
        Job: Record Job;
        PIProcessedReport: Record "PI Processed Report";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
        MessageId: Guid;
    begin
        // [GIVEN] An OPEN POINTS reply: questions, nothing applied
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        MessageId := CreateGuid();
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The monitor processes it
        ReportMonitor.ProcessReport(MessageId, 25, Job."No.", TestLibrary.OpenPointsReport(Job."No."));

        // [THEN] Nobody is asked before the reviewer decides, but the reply is logged so it is not read again
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(0, ClarificationEventSpy.GetTotalEventCount(), 'No event before the reviewer decides.');
        PIProcessedReport.Get(MessageId);
        Assert.IsFalse(PIProcessedReport."Event Raised", 'The event must be logged as not raised.');
    end;
}
