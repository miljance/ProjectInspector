namespace Contoso.ProjectInspector;

/// <summary>
/// Carries out one review result in its own transaction (Codeunit.Run from PI Report Monitor), so a result that fails
/// rolls back only itself and the other results still go out.
/// </summary>
codeunit 50116 "PI Review Result Processor"
{
    Access = Internal;
    TableNo = "PI Review Result";

    trigger OnRun()
    var
        ReportMonitor: Codeunit "PI Report Monitor";
    begin
        ReportMonitor.CarryOutReviewResult(Rec);
    end;
}
