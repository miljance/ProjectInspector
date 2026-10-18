namespace Contoso.ProjectInspector;

using System.Agents;
using System.Environment;
using System.Security.AccessControl;
using System.Upgrade;

/// <summary>
/// Every new version of the app brings the instructions from .resources/Instructions/InstructionsV1.txt
/// to all Project Inspector agents. Change the instructions in that file, raise the app version and publish.
/// The upgrade never touches the agent's permissions: they were given in the company where the agent was activated,
/// and a per-database upgrade has no company, so writing them here gave the agent its permission sets in every
/// company (seen on BC 29). Changes inside a permission set reach the agent anyway, because it holds the set itself.
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
        User: Record User;
        PIAgentSetup: Codeunit "PI Agent Setup";
        AgentUserMissingTxt: Label 'A Project Inspector agent user no longer exists; its instructions were not updated.', Locked = true;
    begin
        PIAgentSetup.RegisterCapability();

        if not PIAgentSetupRecord.FindSet() then
            exit;

        repeat
            // An agent whose user was deleted must not block the upgrade of the app.
            if User.Get(PIAgentSetupRecord."User Security ID") then begin
                PIAgentSetup.UpdateInstructions(PIAgentSetupRecord."User Security ID");
                LimitAgentToItsCompanies(PIAgentSetupRecord."User Security ID");
                AssignAgentToItsCompany(PIAgentSetupRecord);
            end else
                Session.LogMessage('PI0002', AgentUserMissingTxt, Verbosity::Warning, DataClassification::SystemMetadata,
                    TelemetryScope::ExtensionPublisher, 'Category', 'Project Inspector');
        until PIAgentSetupRecord.Next() = 0;
        SetAgentSetupCompanyTag();
    end;

    local procedure SetAgentSetupCompanyTag()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
        PIUpgradeTags: Codeunit "PI Upgrade Tags";
    begin
        if not UpgradeTag.HasUpgradeTag(PIUpgradeTags.GetAgentSetupCompanyTag()) then
            UpgradeTag.SetUpgradeTag(PIUpgradeTags.GetAgentSetupCompanyTag());
    end;

    /// <summary>
    /// Once: versions up to 2.27 wrote the agent's permission sets on every upgrade without a company, which means every
    /// company. Rows without a company are replaced by rows for each company where the agent has review results, that is
    /// where it was activated and used; rows with a company are kept. Nothing changes when no such company exists.
    /// </summary>
    local procedure LimitAgentToItsCompanies(AgentUserSecurityId: Guid)
    var
        AccessControl: Record "Access Control";
        TempLimitedAccessControl: Record "Access Control Buffer" temporary;
        Agent: Codeunit Agent;
        UpgradeTag: Codeunit "Upgrade Tag";
        PIUpgradeTags: Codeunit "PI Upgrade Tags";
        UsedCompanies: List of [Text[30]];
        UsedCompany: Text[30];
        NoCompanyTxt: Label 'The Project Inspector agent has no review results in any company; its permissions were left as they are.', Locked = true;
    begin
        if UpgradeTag.HasUpgradeTag(PIUpgradeTags.GetAgentCompaniesTag()) then
            exit;

        // Read directly: Agent.GetAccessControl fails on BC 29 (it copies Access Control into Access Control Buffer
        // with Copy, which needs the same table).
        AccessControl.SetRange("User Security ID", AgentUserSecurityId);
        AccessControl.SetRange("Company Name", '');
        if not AccessControl.IsEmpty() then begin
            UsedCompanies := GetCompaniesWithReviews();

            if UsedCompanies.Count() = 0 then
                Session.LogMessage('PI0003', NoCompanyTxt, Verbosity::Warning, DataClassification::SystemMetadata,
                    TelemetryScope::ExtensionPublisher, 'Category', 'Project Inspector')
            else begin
                AccessControl.SetRange("Company Name");
                if AccessControl.FindSet() then
                    repeat
                        if AccessControl."Company Name" <> '' then
                            AddAccessControl(TempLimitedAccessControl, AccessControl, AccessControl."Company Name")
                        else
                            foreach UsedCompany in UsedCompanies do
                                AddAccessControl(TempLimitedAccessControl, AccessControl, UsedCompany);
                    until AccessControl.Next() = 0;
                Agent.UpdateAccessControl(AgentUserSecurityId, TempLimitedAccessControl);
            end;
        end;

        UpgradeTag.SetUpgradeTag(PIUpgradeTags.GetAgentCompaniesTag());
    end;

    /// <summary>
    /// Once: agents created before 2.30 belong to no company (one Project Inspector per environment). Each gets the
    /// company where it has review results, so every other company can activate its own agent. An agent used in no
    /// company or in several keeps no company and is logged.
    /// </summary>
    local procedure AssignAgentToItsCompany(var PIAgentSetupRecord: Record "PI Agent Setup")
    var
        AssignedAgent: Record "PI Agent Setup";
        UpgradeTag: Codeunit "Upgrade Tag";
        PIUpgradeTags: Codeunit "PI Upgrade Tags";
        UsedCompanies: List of [Text[30]];
        NoSingleCompanyTxt: Label 'A Project Inspector agent has review results in no company or in several; it was not assigned to a company.', Locked = true;
    begin
        if UpgradeTag.HasUpgradeTag(PIUpgradeTags.GetAgentSetupCompanyTag()) then
            exit;
        if PIAgentSetupRecord."Company Name" <> '' then
            exit;

        UsedCompanies := GetCompaniesWithReviews();
        if UsedCompanies.Count() = 1 then begin
            AssignedAgent.Get(PIAgentSetupRecord."User Security ID");
            AssignedAgent."Company Name" := UsedCompanies.Get(1);
            AssignedAgent.Modify();
        end else
            Session.LogMessage('PI0004', NoSingleCompanyTxt, Verbosity::Warning, DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher, 'Category', 'Project Inspector');
    end;

    /// <summary>
    /// The companies where Project Inspector has review results: a result exists only where it really reviewed.
    /// </summary>
    local procedure GetCompaniesWithReviews() UsedCompanies: List of [Text[30]]
    var
        Company: Record Company;
        PIReviewResult: Record "PI Review Result";
    begin
        if Company.FindSet() then
            repeat
                PIReviewResult.ChangeCompany(Company.Name);
                if not PIReviewResult.IsEmpty() then
                    UsedCompanies.Add(Company.Name);
            until Company.Next() = 0;
    end;

    local procedure AddAccessControl(var TempLimitedAccessControl: Record "Access Control Buffer" temporary; AccessControl: Record "Access Control"; CompanyNameToGrant: Text[30])
    begin
        TempLimitedAccessControl.Init();
        TempLimitedAccessControl."Company Name" := CompanyNameToGrant;
        TempLimitedAccessControl.Scope := AccessControl.Scope;
        TempLimitedAccessControl."App ID" := AccessControl."App ID";
        TempLimitedAccessControl."Role ID" := AccessControl."Role ID";
        if TempLimitedAccessControl.Insert() then;
    end;

    /// <summary>
    /// One-time steps, each guarded by its upgrade tag (PI Upgrade Tags), and the report monitor job, repaired on every
    /// upgrade: a publish can break the run that is just running and leave the job in Error.
    /// </summary>
    trigger OnUpgradePerCompany()
    var
        ReportMonitor: Codeunit "PI Report Monitor";
    begin
        LinkResultsToTasks();
        SetAgentProfile();
        ReportMonitor.RepairJobQueueEntry();
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
