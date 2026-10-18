namespace Contoso.ProjectInspector.Test;

using Microsoft.Projects.Project.Planning;
using System.TestLibraries.Utilities;

/// <summary>
/// The agent checks discounts (PCR-16) on the Project Planning Lines page. Business Central hides Line Discount
/// Amount there, so the agent had to compute Quantity x Unit Price minus Line Amount itself and sometimes got it
/// wrong; Project Inspector shows the column.
/// </summary>
codeunit 50165 "PI Planning Lines Page Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure LineDiscountAmountIsShown()
    var
        JobPlanningLines: TestPage "Job Planning Lines";
    begin
        // [WHEN] The planning lines are opened
        JobPlanningLines.OpenView();

        // [THEN] The discount of every line is shown, so nobody has to compute it
        Assert.IsTrue(JobPlanningLines."Line Discount Amount".Visible(), 'Line Discount Amount must be shown.');
        JobPlanningLines.Close();
    end;
}
