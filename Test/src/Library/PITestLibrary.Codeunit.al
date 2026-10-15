namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;

/// <summary>
/// Shared setup for the Project Inspector tests: test projects, sample review reports
/// and the mock dispatcher.
/// </summary>
codeunit 50162 "PI Test Library"
{
    Access = Internal;

    var
        MockTaskDispatcher: Codeunit "PI Mock Task Dispatcher";
        DispatcherProvider: Codeunit "PI Dispatcher Provider";

    /// <summary>
    /// Replaces the agent task dispatcher with the mock and clears the recorded calls.
    /// </summary>
    procedure UseMockDispatcher()
    begin
        MockTaskDispatcher.Reset();
        DispatcherProvider.SetDispatcher(MockTaskDispatcher);
    end;

    procedure CreateProject(var Job: Record Job; Status: Enum "Job Status")
    begin
        Job.Init();
        Job."No." := NewProjectNo();
        Job.Description := 'Project Inspector test project';
        Job.Status := Status;
        Job.Insert(false);
    end;

    procedure NewProjectNo(): Code[20]
    begin
        exit(CopyStr('PIT-' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    procedure LF(): Text[1]
    var
        LineFeed: Text[1];
    begin
        LineFeed[1] := 10;
        exit(LineFeed);
    end;

    procedure CRLF(): Text[2]
    var
        CarriageReturnLineFeed: Text[2];
    begin
        CarriageReturnLineFeed[1] := 13;
        CarriageReturnLineFeed[2] := 10;
        exit(CarriageReturnLineFeed);
    end;

    /// <summary>
    /// The report Project Inspector wrote for FAB-01-IMP during the playground tests.
    /// </summary>
    procedure OpenPointsReport(ProjectNo: Code[20]): Text
    begin
        exit(
            'Project ' + ProjectNo + ' review: OPEN POINTS' + LF() +
            'Blocks: 4 | Total: 75,250 | Days: 44' + LF() +
            'Questions for the salesperson:' + LF() +
            '- Please split the 38 days in task 003010 by phase (PCR-23)' + LF() +
            'Waiting for answers from the salesperson.');
    end;

    /// <summary>
    /// The report Project Inspector wrote for TAI-01-IMP: findings and one question.
    /// </summary>
    procedure ErrorsReport(ProjectNo: Code[20]): Text
    begin
        exit(
            'Project ' + ProjectNo + ' review: ERRORS' + LF() +
            'Blocks: 2 | Total: 20,025 | Days: 15' + LF() +
            'Findings:' + LF() +
            '- Unit Price 1,100 instead of 1,250 for R-CONSULT in task 002010 (PCR-14)' + LF() +
            '- Discount of 375 on R-CONSULT in task 002010 (PCR-16)' + LF() +
            'Questions for the salesperson:' + LF() +
            '- Please confirm the quote number for block 003000 (PCR-12)' + LF() +
            'Needs the project engineer. Not fixed by the agent.');
    end;

    /// <summary>
    /// The report Project Inspector wrote for LIT-01-SUP: two questions.
    /// </summary>
    procedure TwoQuestionsReport(ProjectNo: Code[20]): Text
    begin
        exit(
            'Project ' + ProjectNo + ' review: ERRORS' + LF() +
            'Blocks: 1 | Total: 8,400 | Days: 0' + LF() +
            'Findings:' + LF() +
            '- Customer Litware Inc. (C90040) is blocked (PCR-07)' + LF() +
            'Questions for the salesperson:' + LF() +
            '- Please confirm the planned start and end date (PCR-20)' + LF() +
            '- Please confirm the support contingent of 60 hours in task 002010 (PCR-23)' + LF() +
            'Needs the project engineer. Not fixed by the agent.');
    end;

    procedure OkReport(ProjectNo: Code[20]): Text
    begin
        exit(
            'Project ' + ProjectNo + ' review: OK' + LF() +
            'Blocks: 1 | Total: 3,150 | Days: 2' + LF() +
            'Ready for the project engineer.');
    end;
}
