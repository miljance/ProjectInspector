namespace Contoso.ProjectInspector;

using System.Upgrade;

/// <summary>
/// Upgrade tags of the one-time upgrade steps. Instructions and permissions are set on every upgrade on purpose (a new
/// version brings new instructions); the steps here run once per company.
/// </summary>
codeunit 50117 "PI Upgrade Tags"
{
    Access = Internal;

    procedure GetLinkResultsToTasksTag(): Code[250]
    begin
        exit('PI-LINK-RESULTS-TO-TASKS-20261017');
    end;

    procedure GetAgentProfileTag(): Code[250]
    begin
        exit('PI-AGENT-PROFILE-20261017');
    end;

    /// <summary>
    /// A new installation needs none of the one-time steps: results start with their task, the agent starts with its
    /// profile.
    /// </summary>
    procedure SetAllPerCompanyTags()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetLinkResultsToTasksTag()) then
            UpgradeTag.SetUpgradeTag(GetLinkResultsToTasksTag());
        if not UpgradeTag.HasUpgradeTag(GetAgentProfileTag()) then
            UpgradeTag.SetUpgradeTag(GetAgentProfileTag());
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", OnGetPerCompanyUpgradeTags, '', false, false)]
    local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        PerCompanyUpgradeTags.Add(GetLinkResultsToTasksTag());
        PerCompanyUpgradeTags.Add(GetAgentProfileTag());
    end;
}
