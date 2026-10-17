namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Projects.Project.Job;
using Microsoft.Sales.Customer;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using System.TestLibraries.Utilities;

/// <summary>
/// buildProjectStructure: Scribe Agent sends all tasks and planning lines of a project in one call. The BC MCP server
/// leaves out Job No. (Job Task) and Line No. (Job Planning Line) on create because the base table marks them not
/// editable, so the action fills them itself, indents the tasks and takes the prices from the cards.
/// </summary>
codeunit 50158 "PI Project Structure Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "PI Test Library";
        ProjectStructure: Codeunit "PI Project Structure";

    [Test]
    procedure TasksAreCreatedIndentedAndTotaled()
    var
        Job: Record Job;
        JobTask: Record "Job Task";
    begin
        // [GIVEN] A new project without tasks
        CreateProjectWithCustomer(Job);

        // [WHEN] The structure is built from the task list
        ProjectStructure.Build(Job, StandardTasksJson(), '[]');

        // [THEN] All tasks exist, indented, and each End-Total got its range
        JobTask.SetRange("Job No.", Job."No.");
        Assert.AreEqual(6, JobTask.Count(), 'Six tasks expected.');
        JobTask.Get(Job."No.", '001010');
        Assert.AreEqual(2, JobTask.Indentation, 'A posting task inside the Standard block has indentation 2.');
        Assert.AreEqual(JobTask."Job Task Type"::Posting, JobTask."Job Task Type", 'Wrong task type.');
        Assert.AreEqual('INTERNAL', JobTask.Description, 'Wrong description.');
        JobTask.Get(Job."No.", '001900');
        Assert.AreEqual('001000..001900', JobTask.Totaling, 'Wrong totaling of the block.');
        JobTask.Get(Job."No.", '999999');
        Assert.AreEqual('000000..999999', JobTask.Totaling, 'Wrong totaling of the project.');
    end;

    [Test]
    procedure PlanningLinesGetLineNumbersAndCardPrices()
    var
        Job: Record Job;
        JobPlanningLine: Record "Job Planning Line";
        ResourceNo: Code[20];
    begin
        // [GIVEN] A project and a resource with the price 1,250 on its card
        CreateProjectWithCustomer(Job);
        ResourceNo := CreateResource(1250);

        // [WHEN] Two lines for the same task are sent, without line numbers and without prices
        ProjectStructure.Build(Job, StandardTasksJson(),
            '[{"jobTaskNo":"002010","type":"Resource","no":"' + ResourceNo + '","description":"Setup","quantity":18},' +
            '{"jobTaskNo":"002010","type":"Resource","no":"' + ResourceNo + '","description":"Testing","quantity":6}]');

        // [THEN] Both lines exist with their own line numbers and the card price
        JobPlanningLine.SetRange("Job No.", Job."No.");
        JobPlanningLine.SetRange("Job Task No.", '002010');
        Assert.AreEqual(2, JobPlanningLine.Count(), 'Two lines expected.');
        JobPlanningLine.FindFirst();
        Assert.AreEqual(10000, JobPlanningLine."Line No.", 'The first line gets 10000.');
        Assert.AreEqual('Setup', JobPlanningLine.Description, 'Wrong description.');
        Assert.AreEqual(1250, JobPlanningLine."Unit Price", 'The price must come from the resource card.');
        Assert.AreEqual(22500, JobPlanningLine."Line Amount", 'Wrong line amount.');
        Assert.AreEqual(JobPlanningLine."Line Type"::"Both Budget and Billable", JobPlanningLine."Line Type", 'Default line type expected.');
        JobPlanningLine.FindLast();
        Assert.AreEqual(20000, JobPlanningLine."Line No.", 'The second line gets 20000.');
    end;

    [Test]
    procedure ProjectWithTasksIsRefused()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project whose structure was already built
        CreateProjectWithCustomer(Job);
        ProjectStructure.Build(Job, StandardTasksJson(), '[]');

        // [WHEN] The structure is sent again
        asserterror ProjectStructure.Build(Job, StandardTasksJson(), '[]');

        // [THEN] Nothing is duplicated
        Assert.ExpectedError('already has tasks');
    end;

    [Test]
    procedure LineForUnknownTaskNamesTheLine()
    var
        Job: Record Job;
        ResourceNo: Code[20];
    begin
        // [GIVEN] A plan whose second line points to a task that is not in the task list
        CreateProjectWithCustomer(Job);
        ResourceNo := CreateResource(1250);

        // [WHEN] The structure is built
        asserterror ProjectStructure.Build(Job, StandardTasksJson(),
            '[{"jobTaskNo":"002010","type":"Resource","no":"' + ResourceNo + '","quantity":1},' +
            '{"jobTaskNo":"007010","type":"Resource","no":"' + ResourceNo + '","quantity":1}]');

        // [THEN] The error names the line and the task, so Scribe can correct the plan
        Assert.ExpectedError('line 2');
        Assert.ExpectedError('007010');
    end;

    [Test]
    procedure UnknownTaskTypeIsRefused()
    var
        Job: Record Job;
    begin
        // [GIVEN] A task list with a task type Business Central does not know
        CreateProjectWithCustomer(Job);

        // [WHEN] The structure is built
        asserterror ProjectStructure.Build(Job, '[{"jobTaskNo":"000000","description":"Project","jobTaskType":"Subtotal"}]', '[]');

        // [THEN] The error names the task and the allowed types
        Assert.ExpectedError('Subtotal');
        Assert.ExpectedError('Begin-Total');
    end;

    [Test]
    procedure UnitOfMeasureOfTheLineIsUsed()
    var
        Job: Record Job;
        JobPlanningLine: Record "Job Planning Line";
        ResourceNo: Code[20];
    begin
        // [GIVEN] A resource priced per hour that can also be planned in days
        CreateProjectWithCustomer(Job);
        ResourceNo := CreateResource(140);
        AddResourceUnitOfMeasure(ResourceNo, 'DAY', 8);

        // [WHEN] Scribe Agent sends a line in days
        ProjectStructure.Build(Job, StandardTasksJson(),
            '[{"jobTaskNo":"002010","type":"Resource","no":"' + ResourceNo + '","quantity":2,"unitOfMeasureCode":"DAY"}]');

        // [THEN] The line is in days, not in the base unit of the resource
        JobPlanningLine.SetRange("Job No.", Job."No.");
        JobPlanningLine.FindFirst();
        Assert.AreEqual('DAY', JobPlanningLine."Unit of Measure Code", 'The unit of measure from the plan must be used.');
        Assert.AreEqual(2, JobPlanningLine.Quantity, 'Wrong quantity.');
    end;

    [Test]
    procedure LineWithoutQuantityIsRefused()
    var
        Job: Record Job;
        ResourceNo: Code[20];
    begin
        // [GIVEN] A plan whose line has no quantity
        CreateProjectWithCustomer(Job);
        ResourceNo := CreateResource(1250);

        // [WHEN] The structure is built
        asserterror ProjectStructure.Build(Job, StandardTasksJson(),
            '[{"jobTaskNo":"002010","type":"Resource","no":"' + ResourceNo + '"}]');

        // [THEN] The error names the missing value instead of planning 0
        Assert.ExpectedError('quantity');
    end;

    [Test]
    procedure WrongPlanningDateNamesTheLine()
    var
        Job: Record Job;
        ResourceNo: Code[20];
    begin
        // [GIVEN] A plan whose second line has a date that is not YYYY-MM-DD
        CreateProjectWithCustomer(Job);
        ResourceNo := CreateResource(1250);

        // [WHEN] The structure is built
        asserterror ProjectStructure.Build(Job, StandardTasksJson(),
            '[{"jobTaskNo":"002010","type":"Resource","no":"' + ResourceNo + '","quantity":1},' +
            '{"jobTaskNo":"002010","type":"Resource","no":"' + ResourceNo + '","quantity":1,"planningDate":"3-4 Feb 2027"}]');

        // [THEN] The error names the line and the expected format
        Assert.ExpectedError('line 2');
        Assert.ExpectedError('YYYY-MM-DD');
    end;

    [Test]
    procedure ProjectNotInPlanningIsRefused()
    var
        Job: Record Job;
    begin
        // [GIVEN] A project that is already in status Quote
        CreateProjectWithCustomer(Job);
        Job.Status := Job.Status::Quote;
        Job.Modify(false);

        // [WHEN] The structure is built
        asserterror ProjectStructure.Build(Job, StandardTasksJson(), '[]');

        // [THEN] Only a new project in Planning is built
        Assert.ExpectedError('Planning');
    end;

    [Test]
    procedure TotalTaskGetsItsTotaling()
    var
        Job: Record Job;
        JobTask: Record "Job Task";
    begin
        // [GIVEN] A task list with a Total task and its totaling
        CreateProjectWithCustomer(Job);

        // [WHEN] The structure is built
        ProjectStructure.Build(Job,
            '[{"jobTaskNo":"000000","description":"Project","jobTaskType":"Begin-Total"},' +
            '{"jobTaskNo":"002010","description":"SERVICES","jobTaskType":"Posting"},' +
            '{"jobTaskNo":"002090","description":"Subtotal services","jobTaskType":"Total","totaling":"002010..002010"},' +
            '{"jobTaskNo":"999999","description":"Total","jobTaskType":"End-Total"}]', '[]');

        // [THEN] The Total task sums the range from the plan
        JobTask.Get(Job."No.", '002090');
        Assert.AreEqual('002010..002010', JobTask.Totaling, 'A Total task needs the totaling from the plan.');
    end;

    [Test]
    procedure LineTakesTheCurrencyOfTheProject()
    var
        Job: Record Job;
        JobPlanningLine: Record "Job Planning Line";
        CurrencyExchangeRate: Record "Currency Exchange Rate";
        ResourceNo: Code[20];
    begin
        // [GIVEN] A project in a foreign currency
        CreateProjectWithCustomer(Job);
        CurrencyExchangeRate.FindLast();
        Job."Currency Code" := CurrencyExchangeRate."Currency Code";
        Job.Modify(false);
        ResourceNo := CreateResource(1250);

        // [WHEN] The structure is built
        ProjectStructure.Build(Job, StandardTasksJson(),
            '[{"jobTaskNo":"002010","type":"Resource","no":"' + ResourceNo + '","quantity":1}]');

        // [THEN] The line is in the project's currency, priced before it was saved
        JobPlanningLine.SetRange("Job No.", Job."No.");
        JobPlanningLine.FindFirst();
        Assert.AreEqual(Job."Currency Code", JobPlanningLine."Currency Code", 'The line must take the currency of the project.');
        Assert.AreNotEqual(0, JobPlanningLine."Currency Factor", 'The line needs the currency factor.');
    end;

    local procedure AddResourceUnitOfMeasure(ResourceNo: Code[20]; UnitOfMeasureCode: Code[10]; QtyPerUnitOfMeasure: Decimal)
    var
        UnitOfMeasure: Record "Unit of Measure";
        ResourceUnitOfMeasure: Record "Resource Unit of Measure";
    begin
        if not UnitOfMeasure.Get(UnitOfMeasureCode) then begin
            UnitOfMeasure.Init();
            UnitOfMeasure.Code := UnitOfMeasureCode;
            UnitOfMeasure.Insert();
        end;
        ResourceUnitOfMeasure.Init();
        ResourceUnitOfMeasure."Resource No." := ResourceNo;
        ResourceUnitOfMeasure.Code := UnitOfMeasureCode;
        ResourceUnitOfMeasure."Qty. per Unit of Measure" := QtyPerUnitOfMeasure;
        ResourceUnitOfMeasure.Insert();
    end;

    local procedure StandardTasksJson(): Text
    begin
        exit(
            '[{"jobTaskNo":"000000","description":"Project","jobTaskType":"Begin-Total"},' +
            '{"jobTaskNo":"001000","description":"Standard","jobTaskType":"Begin-Total"},' +
            '{"jobTaskNo":"001010","description":"INTERNAL","jobTaskType":"Posting"},' +
            '{"jobTaskNo":"001900","description":"Total Standard","jobTaskType":"End-Total"},' +
            '{"jobTaskNo":"002010","description":"SERVICES","jobTaskType":"Posting"},' +
            '{"jobTaskNo":"999999","description":"Total","jobTaskType":"End-Total"}]');
    end;

    /// <summary>
    /// Like a project Scribe Agent creates: tasks need a Bill-to Customer, posting tasks a Project Posting Group.
    /// </summary>
    local procedure CreateProjectWithCustomer(var Job: Record Job)
    var
        Customer: Record Customer;
        JobPostingGroup: Record "Job Posting Group";
    begin
        TestLibrary.CreateProject(Job, Job.Status::Planning);
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.FindFirst();
        JobPostingGroup.FindFirst();
        Job."Bill-to Customer No." := Customer."No.";
        Job."Sell-to Customer No." := Customer."No.";
        Job."Job Posting Group" := JobPostingGroup.Code;
        Job.Modify(false);
    end;

    local procedure CreateResource(UnitPrice: Decimal): Code[20]
    var
        Resource: Record Resource;
        GenProductPostingGroup: Record "Gen. Product Posting Group";
    begin
        GenProductPostingGroup.FindFirst();
        Resource.Init();
        Resource."No." := CopyStr('PIR' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Resource."No."));
        Resource.Name := 'Project Inspector test resource';
        Resource.Insert(true);
        Resource.Validate("Base Unit of Measure", 'HOUR');
        Resource.Validate("Gen. Prod. Posting Group", GenProductPostingGroup.Code);
        Resource.Validate("Unit Price", UnitPrice);
        Resource.Modify(true);
        exit(Resource."No.");
    end;
}
