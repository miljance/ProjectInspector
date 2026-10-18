namespace Contoso.ProjectInspector;

codeunit 50101 "PI Agent Install"
{
    Subtype = Install;
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    trigger OnInstallAppPerDatabase()
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
        PIAgentSetup: Codeunit "PI Agent Setup";
        PIUpgradeTags: Codeunit "PI Upgrade Tags";
    begin
        PIAgentSetup.RegisterCapability();
        PIUpgradeTags.SetAllPerDatabaseTags();

        if not PIAgentSetupRecord.FindSet() then
            exit;

        repeat
            PIAgentSetup.UpdateInstructions(PIAgentSetupRecord."User Security ID");
        until PIAgentSetupRecord.Next() = 0;
    end;

    trigger OnInstallAppPerCompany()
    var
        PIUpgradeTags: Codeunit "PI Upgrade Tags";
    begin
        PIUpgradeTags.SetAllPerCompanyTags();
    end;
}
