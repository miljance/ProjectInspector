namespace Contoso.ProjectInspector.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using System.TestLibraries.Utilities;

/// <summary>
/// The review report states the consultant days of a project. Adding them up was left to the agent, which got it
/// wrong (42 instead of 44 on FAB-01-IMP), so Business Central sums them on the Project Card: every resource line
/// planned in days (unit of measure DAY); support is planned in hours and is not counted.
/// </summary>
codeunit 50164 "PI Planned Days Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";

    [Test]
    procedure PlannedDaysSumTheResourceLinesInDays()
    var
        Job: Record Job;
        OtherJob: Record Job;
    begin
        // [GIVEN] A project with consultant and trainer days, support hours and travel
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        CreateLine(Job."No.", 10000, "Job Planning Line Type"::Resource, 'R-CONSULT', 'DAY', 18);
        CreateLine(Job."No.", 20000, "Job Planning Line Type"::Resource, 'R-CONSULT', 'DAY', 8);
        CreateLine(Job."No.", 30000, "Job Planning Line Type"::Resource, 'R-TRAINER', 'DAY', 2);
        CreateLine(Job."No.", 40000, "Job Planning Line Type"::Resource, 'R-SUPPORT', 'HOUR', 40);
        CreateLine(Job."No.", 50000, "Job Planning Line Type"::Item, 'I-TRAVEL', 'DAY', 2);
        // [GIVEN] Days of another project
        TestLibrary.CreateProject(OtherJob, OtherJob.Status::Planning);
        CreateLine(OtherJob."No.", 10000, "Job Planning Line Type"::Resource, 'R-CONSULT', 'DAY', 5);

        // [WHEN] The Project Card shows the planned days
        Job.CalcFields("PI Planned Days");

        // [THEN] Only the resource days of this project count
        Assert.AreEqual(28, Job."PI Planned Days", 'Planned Days must sum the resource lines in days.');
    end;

    local procedure CreateLine(JobNo: Code[20]; LineNo: Integer; LineType: Enum "Job Planning Line Type"; No: Code[20]; UnitOfMeasureCode: Code[10]; Qty: Decimal)
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        JobPlanningLine.Init();
        JobPlanningLine."Job No." := JobNo;
        JobPlanningLine."Job Task No." := '002010';
        JobPlanningLine."Line No." := LineNo;
        JobPlanningLine.Type := LineType;
        JobPlanningLine."No." := No;
        JobPlanningLine."Unit of Measure Code" := UnitOfMeasureCode;
        JobPlanningLine.Quantity := Qty;
        JobPlanningLine.Insert(false);
    end;
}
