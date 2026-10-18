namespace Contoso.ProjectInspector;

/// <summary>
/// Reads the agent's sent reports in its own transaction (PI Report Monitor runs it with Codeunit.Run), so an error in
/// one of them does not fail the job queue run and the review results are still processed.
/// </summary>
codeunit 50119 "PI Sent Report Check"
{
    Access = Internal;

    trigger OnRun()
    var
        ReportMonitor: Codeunit "PI Report Monitor";
    begin
        ReportMonitor.CheckSentReports();
    end;
}
