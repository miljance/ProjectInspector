namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using System.TestLibraries.Utilities;

/// <summary>
/// PCR-22: the services of an analysis workshop name its dates. The agent checked the descriptions itself and missed
/// PRO-01-WSH (a workshop in block 001000, without a Standard block) in some runs, so Business Central lists the
/// workshop tasks without dates on the Project Card and the agent only reads them.
/// </summary>
codeunit 50166 "PI Review Checks Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        ReviewChecks: Codeunit "PI Review Checks";

    [Test]
    procedure WorkshopWithoutDatesIsListed()
    var
        Job: Record Job;
    begin
        // [GIVEN] A workshop project without a Standard block, like PRO-01-WSH: no date in the workshop line
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        CreateWorkshopProject(Job."No.", 'Process review workshop on site');

        // [WHEN] Business Central checks the workshop dates
        // [THEN] The SERVICES task of the workshop is listed; the travel task is not
        Assert.AreEqual('001010', ReviewChecks.GetWorkshopTasksWithoutDates(Job."No."), 'The workshop task without dates must be listed.');
    end;

    [Test]
    procedure WorkshopWithDatesIsNotListed()
    var
        Job: Record Job;
    begin
        // [GIVEN] A workshop whose line names its dates, like FAB-01-IMP
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        CreateWorkshopProject(Job."No.", 'Analysis workshop on site, 10-11 Nov 2026');

        // [WHEN] Business Central checks the workshop dates
        // [THEN] Nothing is listed
        Assert.AreEqual('', ReviewChecks.GetWorkshopTasksWithoutDates(Job."No."), 'A workshop with dates must not be listed.');
    end;

    [Test]
    procedure OtherBlocksAreNotChecked()
    var
        Job: Record Job;
    begin
        // [GIVEN] An implementation block whose services name no dates
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        CreateTask(Job."No.", '002000', 'Q-NEW-1 IMPLEMENTATION', "Job Task Type"::"Begin-Total");
        CreateTask(Job."No.", '002010', 'SERVICES', "Job Task Type"::Posting);
        CreateTask(Job."No.", '002900', 'Total Q-NEW-1', "Job Task Type"::"End-Total");
        CreateLine(Job."No.", '002010', 10000, 'Implementation services');

        // [WHEN] Business Central checks the workshop dates
        // [THEN] Only analysis workshops need dates
        Assert.AreEqual('', ReviewChecks.GetWorkshopTasksWithoutDates(Job."No."), 'Only workshop blocks are checked.');
    end;

    local procedure CreateWorkshopProject(JobNo: Code[20]; ServicesDescription: Text[100])
    begin
        CreateTask(JobNo, '000000', 'Project', "Job Task Type"::"Begin-Total");
        CreateTask(JobNo, '001000', 'Q-26-0430 ANALYSIS WORKSHOP', "Job Task Type"::"Begin-Total");
        CreateTask(JobNo, '001010', 'SERVICES', "Job Task Type"::Posting);
        CreateTask(JobNo, '001020', 'TRAVEL', "Job Task Type"::Posting);
        CreateTask(JobNo, '001900', 'Total Q-26-0430', "Job Task Type"::"End-Total");
        CreateTask(JobNo, '999999', 'Total', "Job Task Type"::"End-Total");
        CreateLine(JobNo, '001010', 10000, ServicesDescription);
        CreateLine(JobNo, '001020', 10000, 'Travel flat fee');
    end;

    local procedure CreateTask(JobNo: Code[20]; JobTaskNo: Code[20]; TaskDescription: Text[100]; JobTaskType: Enum "Job Task Type")
    var
        JobTask: Record "Job Task";
    begin
        JobTask.Init();
        JobTask."Job No." := JobNo;
        JobTask."Job Task No." := JobTaskNo;
        JobTask.Description := TaskDescription;
        JobTask."Job Task Type" := JobTaskType;
        JobTask.Insert(false);
    end;

    local procedure CreateLine(JobNo: Code[20]; JobTaskNo: Code[20]; LineNo: Integer; LineDescription: Text[100])
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        JobPlanningLine.Init();
        JobPlanningLine."Job No." := JobNo;
        JobPlanningLine."Job Task No." := JobTaskNo;
        JobPlanningLine."Line No." := LineNo;
        JobPlanningLine.Description := LineDescription;
        JobPlanningLine.Insert(false);
    end;
}
