namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using System.TestLibraries.Utilities;

/// <summary>
/// One review step with a real decision field: the agent records the report on the Review Result card and asks for
/// assistance there, so the review opens our card (the outgoing message page of Business Central cannot be extended).
/// The reviewer sets the Decision with an action or in the field and continues; the agent ends the task without a reply.
/// The report monitor job carries out each decided result once.
/// </summary>
codeunit 50163 "PI Review Result Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        ReportMonitor: Codeunit "PI Report Monitor";

    [Test]
    procedure ApprovedResultSetsQuote()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
    begin
        // [GIVEN] The reviewer approved an ERRORS report on the card
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", TestLibrary.ErrorsReport(Job."No."), Enum::"PI Review Result Decision"::Approve);

        // [WHEN] The report monitor runs
        ReportMonitor.ProcessReviewResults();

        // [THEN] The project is in Quote and the result is marked as carried out
        Job.Get(Job."No.");
        Assert.AreEqual(Job.Status::Quote, Job.Status, 'An approved project must be in status Quote.');
        PIReviewResult.Get(PIReviewResult."Entry No.");
        Assert.IsTrue(PIReviewResult.Processed, 'The result must be marked as processed.');
        Assert.AreEqual('Approved: status set to Quote, notification sent to Teams.', PIReviewResult.Result, 'The result must say what was done.');
    end;

    [Test]
    procedure RejectedResultNotifiesOnce()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] The reviewer rejected the report, for example of a project without tasks
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", TestLibrary.ErrorsReport(Job."No."), Enum::"PI Review Result Decision"::Reject);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The report monitor runs twice
        ReportMonitor.ProcessReviewResults();
        ReportMonitor.ProcessReviewResults();

        // [THEN] The salesperson is notified once and the project stays in Planning
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectRejected'), 'The rejection must be sent once.');
        PIReviewResult.Get(PIReviewResult."Entry No.");
        Assert.AreEqual('Rejected: the findings were sent to Teams.', PIReviewResult.Result, 'The result must say what was done.');
        Job.Get(Job."No.");
        Assert.AreEqual(Job.Status::Planning, Job.Status, 'A rejected project stays in Planning.');
    end;

    [Test]
    procedure QuestionsOfTheCardAreSent()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] The reviewer chose Send Questions on an OPEN POINTS report
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", TestLibrary.TwoQuestionsReport(Job."No."), Enum::"PI Review Result Decision"::"Send Questions");
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The report monitor runs
        ReportMonitor.ProcessReviewResults();

        // [THEN] The questions go to the salesperson
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectClarificationRequested'), 'The questions must be sent.');
        PIReviewResult.Get(PIReviewResult."Entry No.");
        Assert.AreEqual('Questions sent to the salesperson in Teams.', PIReviewResult.Result, 'The result must say what was done.');
    end;

    [Test]
    procedure ResultWaitsForTheDecision()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] The agent recorded the report and asked the reviewer; the reviewer has not decided yet
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", TestLibrary.TwoQuestionsReport(Job."No."), Enum::"PI Review Result Decision"::" ");
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The report monitor runs
        ReportMonitor.ProcessReviewResults();

        // [THEN] Nothing goes out and the result waits
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(0, ClarificationEventSpy.GetTotalEventCount(), 'Nothing goes out before the decision.');
        PIReviewResult.Get(PIReviewResult."Entry No.");
        Assert.IsFalse(PIReviewResult.Processed, 'A result without decision must wait.');
    end;

    [Test]
    procedure CancelledResultIsAnnouncedWithoutDecision()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] The salesperson cancelled the project and the agent recorded the CANCELLED report
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", TestLibrary.CancelledReport(Job."No."), Enum::"PI Review Result Decision"::" ");
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The report monitor runs
        ReportMonitor.ProcessReviewResults();

        // [THEN] The cancellation is announced
        UnbindSubscription(ClarificationEventSpy);
        Assert.AreEqual(1, ClarificationEventSpy.GetEventCount('ProjectCancelled'), 'The cancellation must be announced.');
        PIReviewResult.Get(PIReviewResult."Entry No.");
        Assert.AreEqual('Cancelled by the salesperson: notification sent to Teams.', PIReviewResult.Result, 'The result must say what was done.');
    end;

    [Test]
    procedure EditedReportIsStoredLineByLine()
    var
        PIReviewResult: Record "PI Review Result";
    begin
        // [GIVEN] The reviewer edited the report in the full-width view, which returns HTML paragraphs
        // [WHEN] The edited text is stored
        PIReviewResult.SetReportFromHtml('<p>Project X review: OPEN POINTS</p><p>- Please confirm the go-live &amp; dates (PCR-20)</p>');

        // [THEN] The report keeps one line per paragraph, as the questions are sent from it
        Assert.AreEqual('Project X review: OPEN POINTS' + TestLibrary.LF() + '- Please confirm the go-live & dates (PCR-20)', PIReviewResult.Report, 'Wrong stored report.');
    end;

    [Test]
    procedure DecisionWaitsForContinue()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        MockTaskDispatcher: Codeunit "PI Mock Task Dispatcher";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] The reviewer chose Approve on the card, but the agent task still waits for Continue
        TestLibrary.UseMockDispatcher();
        MockTaskDispatcher.SetTaskFinished(false);
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", TestLibrary.ErrorsReport(Job."No."), Enum::"PI Review Result Decision"::Approve, 4711);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The report monitor runs
        ReportMonitor.ProcessReviewResults();

        // [THEN] Nothing happens: the project stays in Planning and no event goes out
        UnbindSubscription(ClarificationEventSpy);
        Job.Get(Job."No.");
        Assert.AreEqual(Job.Status::Planning, Job.Status, 'The decision must wait for Continue.');
        Assert.AreEqual(0, ClarificationEventSpy.GetTotalEventCount(), 'No event before Continue.');
        PIReviewResult.Get(PIReviewResult."Entry No.");
        Assert.IsFalse(PIReviewResult.Processed, 'The result must wait for Continue.');
    end;

    [Test]
    procedure DecisionIsCarriedOutAfterContinue()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        MockTaskDispatcher: Codeunit "PI Mock Task Dispatcher";
        AgentTaskId: BigInteger;
    begin
        // [GIVEN] The reviewer chose Approve and continued; the agent finished the task
        AgentTaskId := 4711;
        TestLibrary.UseMockDispatcher();
        MockTaskDispatcher.SetTaskFinished(true);
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", TestLibrary.ErrorsReport(Job."No."), Enum::"PI Review Result Decision"::Approve, 4711);

        // [WHEN] The report monitor runs
        ReportMonitor.ProcessReviewResults();

        // [THEN] The project is in Quote
        Job.Get(Job."No.");
        Assert.AreEqual(Job.Status::Quote, Job.Status, 'After Continue the decision is carried out.');
        Assert.AreEqual(AgentTaskId, MockTaskDispatcher.GetLastCheckedTaskId(), 'The task of the result must be checked.');
    end;

    [Test]
    procedure OpenResultMovesToTheCurrentTask()
    var
        PIReviewResult: Record "PI Review Result";
        OldTaskId: BigInteger;
        CurrentTaskId: BigInteger;
    begin
        // [GIVEN] An open result of an older, stopped task
        OldTaskId := 58;
        CurrentTaskId := 61;
        PIReviewResult."Agent Task ID" := OldTaskId;

        // [WHEN] The agent of the current task works on it
        PIReviewResult.LinkToAgentTask(CurrentTaskId);

        // [THEN] Its decision waits for the current task
        Assert.AreEqual(CurrentTaskId, PIReviewResult."Agent Task ID", 'An open result must move to the current task.');

        // [WHEN] Code outside an agent session changes it (no task: -1)
        PIReviewResult.LinkToAgentTask(-1);
        // [THEN] It keeps its task
        Assert.AreEqual(CurrentTaskId, PIReviewResult."Agent Task ID", 'Without agent task the result keeps its task.');
    end;

    [Test]
    procedure CarriedOutResultKeepsItsTask()
    var
        PIReviewResult: Record "PI Review Result";
        OldTaskId: BigInteger;
    begin
        // [GIVEN] A result that was already carried out
        OldTaskId := 58;
        PIReviewResult."Agent Task ID" := OldTaskId;
        PIReviewResult.Processed := true;

        // [WHEN] A later task touches it
        PIReviewResult.LinkToAgentTask(61);

        // [THEN] It stays with the task it was carried out for
        Assert.AreEqual(OldTaskId, PIReviewResult."Agent Task ID", 'A carried-out result keeps its task.');
    end;

    [Test]
    procedure StoppedTaskClosesItsResult()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        MockTaskDispatcher: Codeunit "PI Mock Task Dispatcher";
        ClarificationEventSpy: Codeunit "PI Clarification Event Spy";
    begin
        // [GIVEN] An open result whose task the reviewer stopped, even with a decision already chosen
        TestLibrary.UseMockDispatcher();
        MockTaskDispatcher.SetTaskFinished(false);
        MockTaskDispatcher.SetTaskStopped(true);
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", TestLibrary.ErrorsReport(Job."No."), Enum::"PI Review Result Decision"::Approve, 4711);
        BindSubscription(ClarificationEventSpy);

        // [WHEN] The report monitor runs
        ReportMonitor.ProcessReviewResults();

        // [THEN] The result is closed as stopped and nothing is carried out
        UnbindSubscription(ClarificationEventSpy);
        PIReviewResult.Get(PIReviewResult."Entry No.");
        Assert.IsTrue(PIReviewResult.Processed, 'A stopped review must be closed.');
        Assert.AreEqual('Review stopped before a decision.', PIReviewResult.Result, 'The card must say why it was closed.');
        Assert.AreEqual(0, ClarificationEventSpy.GetTotalEventCount(), 'A stopped review sends nothing.');
        Job.Get(Job."No.");
        Assert.AreEqual(Job.Status::Planning, Job.Status, 'A stopped review changes nothing.');
    end;

    [Test]
    procedure EmptyResultOfAStoppedTaskIsClosed()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        MockTaskDispatcher: Codeunit "PI Mock Task Dispatcher";
    begin
        // [GIVEN] A round was started, the agent wrote nothing yet, and the task was stopped
        TestLibrary.UseMockDispatcher();
        MockTaskDispatcher.SetTaskStopped(true);
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(PIReviewResult, Job."No.", '', Enum::"PI Review Result Decision"::" ", 4711);

        // [WHEN] The report monitor runs
        ReportMonitor.ProcessReviewResults();

        // [THEN] The empty result is closed too
        PIReviewResult.Get(PIReviewResult."Entry No.");
        Assert.IsTrue(PIReviewResult.Processed, 'An empty result of a stopped task must be closed.');
    end;

    [Test]
    procedure SubmitCreatesAnOpenResultForTheTask()
    var
        Job: Record Job;
        PIReviewResult: Record "PI Review Result";
        MockTaskDispatcher: Codeunit "PI Mock Task Dispatcher";
        ReviewTrigger: Codeunit "PI Review Trigger";
        AgentTaskId: BigInteger;
    begin
        // [GIVEN] A project in Planning and the agent task the review goes to
        TestLibrary.UseMockDispatcher();
        AgentTaskId := 62;
        MockTaskDispatcher.SetReviewTaskId(AgentTaskId);
        TestLibrary.CreateProject(Job, Job.Status::Planning);

        // [WHEN] The project is sent to Project Inspector
        ReviewTrigger.SubmitForReview(Job);

        // [THEN] Business Central created the result the agent fills in: empty, open, tied to that task
        PIReviewResult.SetRange("Project No.", Job."No.");
        Assert.AreEqual(1, PIReviewResult.Count(), 'One result per review round.');
        PIReviewResult.FindFirst();
        Assert.AreEqual(AgentTaskId, PIReviewResult."Agent Task ID", 'The result belongs to the review task.');
        Assert.AreEqual('', PIReviewResult.Report, 'The agent writes the report.');
        Assert.IsFalse(PIReviewResult.Processed, 'The result is open.');
    end;

    [Test]
    procedure NewRoundReplacesTheOpenResult()
    var
        Job: Record Job;
        OldResult: Record "PI Review Result";
        PIReviewResult: Record "PI Review Result";
        PIClarificationAnswer: Record "PI Clarification Answer";
        ReviewTrigger: Codeunit "PI Review Trigger";
    begin
        // [GIVEN] A project with an open result that was never decided
        TestLibrary.UseMockDispatcher();
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        RecordResult(OldResult, Job."No.", TestLibrary.TwoQuestionsReport(Job."No."), Enum::"PI Review Result Decision"::" ");

        // [WHEN] The salesperson's answer starts the next round
        PIClarificationAnswer."Project No." := Job."No.";
        PIClarificationAnswer.Answer := 'Start 2027-01-04';
        ReviewTrigger.RegisterAnswer(PIClarificationAnswer);

        // [THEN] The old result is closed as replaced and the new round has its own open result
        OldResult.Get(OldResult."Entry No.");
        Assert.IsTrue(OldResult.Processed, 'The older open result must be closed.');
        Assert.AreEqual('Replaced by a newer review round.', OldResult.Result, 'The card must say why it was closed.');
        PIReviewResult.SetRange("Project No.", Job."No.");
        PIReviewResult.SetRange(Processed, false);
        Assert.AreEqual(1, PIReviewResult.Count(), 'Exactly one open result per project.');
    end;

    [Test]
    procedure EntryNoIsAssignedOnInsert()
    var
        FirstResult: Record "PI Review Result";
        SecondResult: Record "PI Review Result";
    begin
        // [GIVEN] Two review results recorded one after the other, like by two agent tasks
        // [WHEN] They are inserted
        FirstResult.Insert(true);
        SecondResult.Insert(true);

        // [THEN] Each has its own number right away, so the page the agent asks from points to its own result
        Assert.AreNotEqual(0, FirstResult."Entry No.", 'The first result needs a number at insert.');
        Assert.AreEqual(FirstResult."Entry No." + 1, SecondResult."Entry No.", 'The next result gets the next number.');
    end;

    [Test]
    procedure StatusShowsTheCurrentStep()
    var
        PIReviewResult: Record "PI Review Result";
    begin
        // [GIVEN] A result Business Central created for a new round
        // [THEN] While the agent reviews, the card says so
        Assert.AreEqual('Project Inspector is reviewing the project.', PIReviewResult.GetStatusText(), 'Wrong status during the review.');

        // [WHEN] The agent wrote the report and the reviewer has not decided yet
        PIReviewResult.Report := 'Project X review: OK';
        // [THEN] The card says that it waits for the decision
        Assert.AreEqual('Waiting for your decision in the task pane.', PIReviewResult.GetStatusText(), 'Wrong status before the decision.');

        // [WHEN] The decision is set but not carried out yet
        PIReviewResult.Decision := PIReviewResult.Decision::Approve;
        // [THEN] The card says what will happen and when
        Assert.AreEqual('Decision: Approve. Carried out after the task is finished.', PIReviewResult.GetStatusText(), 'Wrong status before Continue.');

        // [WHEN] The report monitor carried it out
        PIReviewResult.Processed := true;
        PIReviewResult.Result := 'Approved: status set to Quote, notification sent to Teams.';
        // [THEN] The card says what happened
        Assert.AreEqual('Approved: status set to Quote, notification sent to Teams.', PIReviewResult.GetStatusText(), 'Wrong status after processing.');
    end;

    [Test]
    procedure ReportIsShownLineByLine()
    var
        PIReviewResult: Record "PI Review Result";
    begin
        // [GIVEN] A report with two lines and characters that mean something in HTML
        PIReviewResult.Report := 'Project X review: ERRORS' + TestLibrary.LF() + '- Price < rate card & discount (PCR-16)';

        // [WHEN] The card shows it in the full-width report view
        // [THEN] Every line is its own line and the text is shown as written
        Assert.AreEqual('Project X review: ERRORS<br>- Price &lt; rate card &amp; discount (PCR-16)', PIReviewResult.GetReportAsHtml(), 'Wrong report view.');
    end;

    local procedure RecordResult(var PIReviewResult: Record "PI Review Result"; ProjectNo: Code[20]; ReportText: Text; Decision: Enum "PI Review Result Decision")
    begin
        RecordResult(PIReviewResult, ProjectNo, ReportText, Decision, 0);
    end;

    /// <summary>
    /// AgentTaskId 0 is a result without agent task (recorded by a person, or in a test without agent session).
    /// </summary>
    local procedure RecordResult(var PIReviewResult: Record "PI Review Result"; ProjectNo: Code[20]; ReportText: Text; Decision: Enum "PI Review Result Decision"; AgentTaskId: BigInteger)
    begin
        PIReviewResult.Init();
        PIReviewResult."Project No." := ProjectNo;
        PIReviewResult.Report := CopyStr(ReportText, 1, MaxStrLen(PIReviewResult.Report));
        PIReviewResult.Decision := Decision;
        PIReviewResult.Insert(true);
        PIReviewResult."Agent Task ID" := AgentTaskId;
        PIReviewResult.Modify();
    end;
}
