namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>
/// Builds the tasks and planning lines of a project in one transaction (buildProjectStructure on projectReviews).
/// Scribe Agent cannot create them one by one through the BC MCP server: the server leaves out Job No. on Job Task and
/// Line No. on Job Planning Line, because the base tables mark them not editable. This codeunit fills both itself,
/// indents the tasks like "Indent Project Tasks" on the Project Card and validates each line, so prices come from the cards.
/// </summary>
codeunit 50115 "PI Project Structure"
{
    Access = Internal;

    var
        ProjectHasTasksErr: Label 'Project %1 already has tasks. buildProjectStructure only builds a new project.', Comment = '%1 = project No.';
        NotAnArrayErr: Label '%1 must be a JSON array.', Comment = '%1 = tasksJson or linesJson';
        MissingValueErr: Label '%1 %2 has no %3.', Comment = '%1 = task or line, %2 = position in the list, %3 = JSON property name';
        UnknownTaskTypeErr: Label 'Task %1 has the task type "%2". Use Posting, Heading, Total, Begin-Total or End-Total.', Comment = '%1 = task No., %2 = task type from the plan';
        UnknownLineTypeErr: Label 'Planning line %1 has the line type "%2". Use Budget, Billable or Both Budget and Billable.', Comment = '%1 = position in the list, %2 = line type from the plan';
        UnknownTypeErr: Label 'Planning line %1 has the type "%2". Use Resource, Item or G/L Account.', Comment = '%1 = position in the list, %2 = type from the plan';
        UnknownTaskErr: Label 'Planning line %1 belongs to task %2, which is not a task of project %3.', Comment = '%1 = position in the list, %2 = task No., %3 = project No.';
        NotInPlanningErr: Label 'Project %1 is in status %2. buildProjectStructure only builds a project in status Planning.', Comment = '%1 = project No., %2 = status';
        WrongDateErr: Label 'Planning line %1 has the planning date "%2". Use the format YYYY-MM-DD, for example 2026-11-10.', Comment = '%1 = position in the list, %2 = date from the plan';
        QuantityTok: Label 'quantity', Locked = true;
        TaskTok: Label 'Task', Locked = true;
        LineTok: Label 'Planning line', Locked = true;

    /// <summary>
    /// TasksJson: [{"jobTaskNo","description","jobTaskType","totaling"}], ordered by task No.; totaling is used for
    /// Total tasks (End-Total tasks get theirs from the indentation).
    /// LinesJson: [{"jobTaskNo","type","no","description","quantity","unitOfMeasureCode","lineType","planningDate"}];
    /// description, unitOfMeasureCode (default the base unit of the resource or item), lineType (default Both Budget and
    /// Billable) and planningDate (YYYY-MM-DD, default the project's Starting Date, else the work date) are optional.
    /// </summary>
    procedure Build(var Job: Record Job; TasksJson: Text; LinesJson: Text)
    var
        JobTask: Record "Job Task";
        JobTaskIndent: Codeunit "Job Task-Indent";
        Tasks: JsonArray;
    begin
        if Job.Status <> Job.Status::Planning then
            Error(NotInPlanningErr, Job."No.", Job.Status);
        JobTask.SetRange("Job No.", Job."No.");
        if not JobTask.IsEmpty() then
            Error(ProjectHasTasksErr, Job."No.");

        Tasks := ParseArray(TasksJson, 'tasksJson');
        CreateTasks(Job, Tasks);
        JobTaskIndent.Indent(Job."No.", true);
        SetTotaling(Job, Tasks);
        CreateLines(Job, ParseArray(LinesJson, 'linesJson'));
    end;

    /// <summary>
    /// Job Task-Indent fills the Totaling of End-Total tasks only; a Total task keeps the range from the plan.
    /// </summary>
    local procedure SetTotaling(var Job: Record Job; Tasks: JsonArray)
    var
        JobTask: Record "Job Task";
        TaskToken: JsonToken;
        Task: JsonObject;
        Totaling: Text;
    begin
        foreach TaskToken in Tasks do begin
            Task := TaskToken.AsObject();
            Totaling := GetText(Task, 'totaling');
            if Totaling <> '' then
                if JobTask.Get(Job."No.", CopyStr(GetText(Task, 'jobTaskNo'), 1, MaxStrLen(JobTask."Job Task No."))) then
                    if JobTask."Job Task Type" = JobTask."Job Task Type"::Total then begin
                        JobTask.Validate(Totaling, CopyStr(Totaling, 1, MaxStrLen(JobTask.Totaling)));
                        JobTask.Modify(true);
                    end;
        end;
    end;

    local procedure CreateTasks(var Job: Record Job; Tasks: JsonArray)
    var
        JobTask: Record "Job Task";
        TaskToken: JsonToken;
        Task: JsonObject;
        Position: Integer;
    begin
        foreach TaskToken in Tasks do begin
            Position += 1;
            Task := TaskToken.AsObject();
            JobTask.Init();
            JobTask."Job No." := Job."No.";
            JobTask.Validate("Job Task No.", CopyStr(GetRequiredText(Task, 'jobTaskNo', TaskTok, Position), 1, MaxStrLen(JobTask."Job Task No.")));
            JobTask.Validate(Description, CopyStr(GetText(Task, 'description'), 1, MaxStrLen(JobTask.Description)));
            JobTask.Validate("Job Task Type", ParseTaskType(JobTask."Job Task No.", GetText(Task, 'jobTaskType')));
            JobTask.Insert(true);
        end;
    end;

    local procedure CreateLines(var Job: Record Job; Lines: JsonArray)
    var
        JobTask: Record "Job Task";
        JobPlanningLine: Record "Job Planning Line";
        LastJobPlanningLine: Record "Job Planning Line";
        LineToken: JsonToken;
        Line: JsonObject;
        JobTaskNo: Code[20];
        Position: Integer;
        Description: Text;
        UnitOfMeasureCode: Text;
        PlanningDate: Date;
    begin
        foreach LineToken in Lines do begin
            Position += 1;
            Line := LineToken.AsObject();
            JobTaskNo := CopyStr(GetRequiredText(Line, 'jobTaskNo', LineTok, Position), 1, MaxStrLen(JobTaskNo));
            if not JobTask.Get(Job."No.", JobTaskNo) then
                Error(UnknownTaskErr, Position, JobTaskNo, Job."No.");

            PlanningDate := Job."Starting Date";
            if GetText(Line, 'planningDate') <> '' then
                if not Evaluate(PlanningDate, GetText(Line, 'planningDate'), 9) then
                    Error(WrongDateErr, Position, GetText(Line, 'planningDate'));
            if PlanningDate = 0D then
                PlanningDate := WorkDate();

            JobPlanningLine.Init();
            JobPlanningLine."Job No." := Job."No.";
            JobPlanningLine."Job Task No." := JobTaskNo;
            JobPlanningLine."Line No." := GetNextLineNo(Job."No.", JobTaskNo);
            // Like the Project Planning Lines page: the project's currency and price calculation methods are set before
            // the line is priced. Insert would set the currency only after the prices were calculated in LCY.
            LastJobPlanningLine := JobPlanningLine;
            LastJobPlanningLine.Type := ParseLineSourceType(Position, GetRequiredText(Line, 'type', LineTok, Position));
            LastJobPlanningLine."Line Type" := ParseLineType(Position, GetText(Line, 'lineType'));
            LastJobPlanningLine."Planning Date" := PlanningDate;
            JobPlanningLine.SetUpNewLine(LastJobPlanningLine);
            JobPlanningLine.Validate("No.", CopyStr(GetRequiredText(Line, 'no', LineTok, Position), 1, MaxStrLen(JobPlanningLine."No.")));
            Description := GetText(Line, 'description');
            if Description <> '' then
                JobPlanningLine.Validate(Description, CopyStr(Description, 1, MaxStrLen(JobPlanningLine.Description)));
            UnitOfMeasureCode := GetText(Line, 'unitOfMeasureCode');
            if UnitOfMeasureCode <> '' then
                JobPlanningLine.Validate("Unit of Measure Code", CopyStr(UnitOfMeasureCode, 1, MaxStrLen(JobPlanningLine."Unit of Measure Code")));
            JobPlanningLine.Validate(Quantity, GetRequiredDecimal(Line, QuantityTok, Position));
            JobPlanningLine.Insert(true);
        end;
    end;

    local procedure GetNextLineNo(JobNo: Code[20]; JobTaskNo: Code[20]): Integer
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        JobPlanningLine.SetRange("Job No.", JobNo);
        JobPlanningLine.SetRange("Job Task No.", JobTaskNo);
        if JobPlanningLine.FindLast() then
            exit(JobPlanningLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure ParseTaskType(JobTaskNo: Code[20]; TaskType: Text): Enum "Job Task Type"
    begin
        case LowerCase(DelChr(TaskType, '=', ' -')) of
            '', 'posting':
                exit(Enum::"Job Task Type"::Posting);
            'heading':
                exit(Enum::"Job Task Type"::Heading);
            'total':
                exit(Enum::"Job Task Type"::Total);
            'begintotal':
                exit(Enum::"Job Task Type"::"Begin-Total");
            'endtotal':
                exit(Enum::"Job Task Type"::"End-Total");
        end;
        Error(UnknownTaskTypeErr, JobTaskNo, TaskType);
    end;

    local procedure ParseLineType(Position: Integer; LineType: Text): Enum "Job Planning Line Line Type"
    begin
        case LowerCase(DelChr(LineType, '=', ' ')) of
            '', 'bothbudgetandbillable':
                exit(Enum::"Job Planning Line Line Type"::"Both Budget and Billable");
            'budget':
                exit(Enum::"Job Planning Line Line Type"::Budget);
            'billable':
                exit(Enum::"Job Planning Line Line Type"::Billable);
        end;
        Error(UnknownLineTypeErr, Position, LineType);
    end;

    local procedure ParseLineSourceType(Position: Integer; LineSourceType: Text): Enum "Job Planning Line Type"
    begin
        case LowerCase(DelChr(LineSourceType, '=', ' /')) of
            'resource':
                exit(Enum::"Job Planning Line Type"::Resource);
            'item':
                exit(Enum::"Job Planning Line Type"::Item);
            'glaccount':
                exit(Enum::"Job Planning Line Type"::"G/L Account");
        end;
        Error(UnknownTypeErr, Position, LineSourceType);
    end;

    local procedure ParseArray(Json: Text; ParameterName: Text) Result: JsonArray
    begin
        if DelChr(Json, '<>', ' ') = '' then
            exit;
        if not Result.ReadFrom(Json) then
            Error(NotAnArrayErr, ParameterName);
    end;

    local procedure GetRequiredText(Object: JsonObject; PropertyName: Text; Kind: Text; Position: Integer): Text
    var
        Value: Text;
    begin
        Value := GetText(Object, PropertyName);
        if Value = '' then
            Error(MissingValueErr, Kind, Position, PropertyName);
        exit(Value);
    end;

    local procedure GetText(Object: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Object.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure GetRequiredDecimal(Object: JsonObject; PropertyName: Text; Position: Integer): Decimal
    var
        Token: JsonToken;
    begin
        if Object.Get(PropertyName, Token) then
            if Token.IsValue() then
                if not Token.AsValue().IsNull() then
                    exit(Token.AsValue().AsDecimal());
        Error(MissingValueErr, LineTok, Position, PropertyName);
    end;
}
