namespace Contoso.ProjectInspector;

using System.Upgrade;

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
    /// One-time steps, each guarded by its upgrade tag (PI Upgrade Tags).
    /// </summary>
    trigger OnUpgradePerCompany()
    begin
        LinkResultsToTasks();
        SetAgentProfile();
    end;

    /// <summary>
    /// Results recorded before 2.8 had no agent task; they are linked to the newest task of their project once.
    /// </summary>
    local procedure LinkResultsToTasks()
    var
        ReportMonitor: Codeunit "PI Report Monitor";
        UpgradeTag: Codeunit "Upgrade Tag";
        PIUpgradeTags: Codeunit "PI Upgrade Tags";
    begin
        if UpgradeTag.HasUpgradeTag(PIUpgradeTags.GetLinkResultsToTasksTag()) then
            exit;
        ReportMonitor.LinkResultsToTasks();
        UpgradeTag.SetUpgradeTag(PIUpgradeTags.GetLinkResultsToTasksTag());
    end;

    /// <summary>
    /// Agents created before 2.6 started on the Project Manager home page; they get their own profile once, so a
    /// profile an administrator chooses later is kept. The profile is part of the agent's user settings, which
    /// Business Central reads per company.
    /// </summary>
    local procedure SetAgentProfile()
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
        PIAgentSetup: Codeunit "PI Agent Setup";
        UpgradeTag: Codeunit "Upgrade Tag";
        PIUpgradeTags: Codeunit "PI Upgrade Tags";
    begin
        if UpgradeTag.HasUpgradeTag(PIUpgradeTags.GetAgentProfileTag()) then
            exit;
        if PIAgentSetupRecord.FindSet() then
            repeat
                PIAgentSetup.UpdateProfile(PIAgentSetupRecord."User Security ID");
            until PIAgentSetupRecord.Next() = 0;
        UpgradeTag.SetUpgradeTag(PIUpgradeTags.GetAgentProfileTag());
    end;
}
