namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using System.Utilities;

/// <summary>
/// Review checks Business Central computes for the agent, which only reads the result on the Project Card: the agent
/// skipped such checks in some runs or got them wrong, Business Central does not.
/// </summary>
codeunit 50120 "PI Review Checks"
{
    Access = Internal;

    var
        // A day and a month name ("10-11 Nov 2026", "3 February"), an ISO date or a dotted date.
        DatePatternTxt: Label '(?i)\b\d{1,2}(\s*[-–]\s*\d{1,2})?\.?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b|\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}\.\d{1,2}\.\d{2,4}\b', Locked = true;

    /// <summary>
    /// PCR-22: the SERVICES tasks of analysis workshop blocks none of whose planning lines name a date, as a
    /// comma-separated list of task numbers, or empty. A block is a Begin-Total task with its tasks up to the next
    /// Begin-Total; a workshop without a Standard block (block 001000) counts like any other.
    /// </summary>
    procedure GetWorkshopTasksWithoutDates(JobNo: Code[20]) TaskList: Text
    var
        JobTask: Record "Job Task";
        InWorkshopBlock: Boolean;
    begin
        JobTask.SetRange("Job No.", JobNo);
        if not JobTask.FindSet() then
            exit('');
        repeat
            case JobTask."Job Task Type" of
                JobTask."Job Task Type"::"Begin-Total":
                    InWorkshopBlock := JobTask.Description.ToUpper().Contains('ANALYSIS WORKSHOP');
                JobTask."Job Task Type"::Posting:
                    if InWorkshopBlock and (JobTask.Description.ToUpper() = 'SERVICES') then
                        if not HasDatedLine(JobNo, JobTask."Job Task No.") then
                            AddTask(TaskList, JobTask."Job Task No.");
            end;
        until JobTask.Next() = 0;
    end;

    local procedure HasDatedLine(JobNo: Code[20]; JobTaskNo: Code[20]): Boolean
    var
        JobPlanningLine: Record "Job Planning Line";
        Regex: Codeunit Regex;
    begin
        JobPlanningLine.SetRange("Job No.", JobNo);
        JobPlanningLine.SetRange("Job Task No.", JobTaskNo);
        JobPlanningLine.SetLoadFields(Description);
        if JobPlanningLine.FindSet() then
            repeat
                if Regex.IsMatch(JobPlanningLine.Description, DatePatternTxt) then
                    exit(true);
            until JobPlanningLine.Next() = 0;
        exit(false);
    end;

    local procedure AddTask(var TaskList: Text; JobTaskNo: Code[20])
    begin
        if TaskList <> '' then
            TaskList += ', ';
        TaskList += JobTaskNo;
    end;
}
