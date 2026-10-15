namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using System.TestLibraries.Utilities;

/// <summary>
/// Reads the review report written by Project Inspector (format from step 7 of the instructions).
/// </summary>
codeunit 50151 "PI Report Parser Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        ReportParser: Codeunit "PI Report Parser";

    [Test]
    procedure GetQuestionsReturnsTheQuestion()
    var
        Questions: List of [Text];
    begin
        // [GIVEN] An OPEN POINTS report with one question
        // [WHEN] The questions are read
        ReportParser.GetQuestions(TestLibrary.OpenPointsReport('FAB-01-IMP'), Questions);

        // [THEN] The question is returned without the leading dash
        Assert.AreEqual(1, Questions.Count(), 'One question expected.');
        Assert.AreEqual('Please split the 38 days in task 003010 by phase (PCR-23)', Questions.Get(1), 'Wrong question text.');
    end;

    [Test]
    procedure GetQuestionsIgnoresFindingsAndClosingLine()
    var
        Questions: List of [Text];
    begin
        // [GIVEN] An ERRORS report with two findings, one question and a closing line
        // [WHEN] The questions are read
        ReportParser.GetQuestions(TestLibrary.ErrorsReport('TAI-01-IMP'), Questions);

        // [THEN] Only the question is returned
        Assert.AreEqual(1, Questions.Count(), 'One question expected.');
        Assert.AreEqual('Please confirm the quote number for block 003000 (PCR-12)', Questions.Get(1), 'Wrong question text.');
    end;

    [Test]
    procedure GetQuestionsReturnsAllQuestions()
    var
        Questions: List of [Text];
    begin
        // [GIVEN] A report with two questions
        // [WHEN] The questions are read
        ReportParser.GetQuestions(TestLibrary.TwoQuestionsReport('LIT-01-SUP'), Questions);

        // [THEN] Both questions are returned in order
        Assert.AreEqual(2, Questions.Count(), 'Two questions expected.');
        Assert.AreEqual('Please confirm the planned start and end date (PCR-20)', Questions.Get(1), 'Wrong first question.');
        Assert.AreEqual('Please confirm the support contingent of 60 hours in task 002010 (PCR-23)', Questions.Get(2), 'Wrong second question.');
    end;

    [Test]
    procedure GetQuestionsReturnsNothingForOkReport()
    var
        Questions: List of [Text];
    begin
        // [GIVEN] An OK report
        // [WHEN] The questions are read
        ReportParser.GetQuestions(TestLibrary.OkReport('PRO-01-WSH'), Questions);

        // [THEN] There are no questions
        Assert.AreEqual(0, Questions.Count(), 'No questions expected.');
        Assert.IsFalse(ReportParser.HasQuestions(TestLibrary.OkReport('PRO-01-WSH')), 'HasQuestions must be false.');
    end;

    [Test]
    procedure GetQuestionsHandlesWindowsLineBreaks()
    var
        Questions: List of [Text];
        ReportText: Text;
    begin
        // [GIVEN] The OPEN POINTS report with CR LF line breaks
        ReportText := TestLibrary.OpenPointsReport('FAB-01-IMP').Replace(TestLibrary.LF(), TestLibrary.CRLF());

        // [WHEN] The questions are read
        ReportParser.GetQuestions(ReportText, Questions);

        // [THEN] The question is returned without a trailing carriage return
        Assert.AreEqual(1, Questions.Count(), 'One question expected.');
        Assert.AreEqual('Please split the 38 days in task 003010 by phase (PCR-23)', Questions.Get(1), 'Wrong question text.');
    end;

    [Test]
    procedure GetProjectNoReadsTheFirstLine()
    begin
        // [GIVEN] An ERRORS report for TAI-01-IMP
        // [WHEN] The project No. is read
        // [THEN] It is the No. between "Project" and "review:"
        Assert.AreEqual('TAI-01-IMP', ReportParser.GetProjectNo(TestLibrary.ErrorsReport('TAI-01-IMP')), 'Wrong project No.');
    end;

    [Test]
    procedure GetStatusReadsTheFirstLine()
    begin
        // [GIVEN] Reports with different statuses
        // [WHEN] The status is read
        // [THEN] It is the text after "review:"
        Assert.AreEqual('ERRORS', ReportParser.GetStatus(TestLibrary.ErrorsReport('TAI-01-IMP')), 'Wrong status.');
        Assert.AreEqual('OPEN POINTS', ReportParser.GetStatus(TestLibrary.OpenPointsReport('FAB-01-IMP')), 'Wrong status.');
        Assert.AreEqual('OK', ReportParser.GetStatus(TestLibrary.OkReport('PRO-01-WSH')), 'Wrong status.');
    end;

    [Test]
    procedure GetProjectNoIsEmptyForOtherMessages()
    begin
        // [GIVEN] A message that is not a review report
        // [WHEN] The project No. is read
        // [THEN] Nothing is returned
        Assert.AreEqual('', ReportParser.GetProjectNo('I could not find the project.'), 'No project No. expected.');
    end;
}
