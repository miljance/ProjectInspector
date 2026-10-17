namespace Contoso.ProjectInspector;

/// <summary>
/// Every new version of the app brings the instructions from .resources/Instructions/InstructionsV1.txt
/// to all Project Inspector agents. Change the instructions in that file, raise the app version and publish.
/// </summary>
codeunit 50105 "PI Agent Upgrade"
{
    Subtype = Upgrade;
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    trigger OnUpgradePerDatabase()
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
        PIAgentSetup: Codeunit "PI Agent Setup";
    begin
        PIAgentSetup.RegisterCapability();

        if not PIAgentSetupRecord.FindSet() then
            exit;

        repeat
            PIAgentSetup.UpdateInstructions(PIAgentSetupRecord."User Security ID");
            PIAgentSetup.UpdateAccessControls(PIAgentSetupRecord."User Security ID");
        until PIAgentSetupRecord.Next() = 0;
    end;

    /// <summary>
    /// The profile is part of the agent's user settings, which Business Central reads per company.
    /// </summary>
    trigger OnUpgradePerCompany()
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
        PIAgentSetup: Codeunit "PI Agent Setup";
        ReportMonitor: Codeunit "PI Report Monitor";
    begin
        ReportMonitor.LinkResultsToTasks();

        if not PIAgentSetupRecord.FindSet() then
            exit;

        repeat
            PIAgentSetup.UpdateProfile(PIAgentSetupRecord."User Security ID");
        until PIAgentSetupRecord.Next() = 0;
    end;
}
