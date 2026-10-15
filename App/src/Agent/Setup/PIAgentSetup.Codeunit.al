namespace Contoso.ProjectInspector;

using System.Agents;
using System.AI;
using System.Reflection;
using System.Security.AccessControl;

/// <summary>
/// Identity, profile, permissions and instructions of Project Inspector.
/// Values come from the agent definition exported from Agent Designer
/// (.resources/Instructions/ProjectInspector-agent-export.xml).
/// </summary>
codeunit 50103 "PI Agent Setup"
{
    Access = Internal;

    var
        Agent: Codeunit Agent;
        BaseApplicationAppIdTok: Label '437dbf0e-84ff-417a-965d-ed2bb9650972', Locked = true;
        DefaultPermissionSetTok: Label 'D365 READ', Locked = true;
        AgentEditPermissionSetTok: Label 'PI AGENT EDIT', Locked = true;
        DefaultProfileTok: Label 'PROJECT MANAGER', Locked = true;
        InstructionsResourceTok: Label 'Instructions/InstructionsV1.txt', Locked = true;
        AgentInitialsLbl: Label 'PI', MaxLength = 4;
        AgentNameLbl: Label 'PROJECT INSPECTOR', Locked = true;
        DefaultDisplayNameLbl: Label 'Project Inspector';
        AgentSummaryLbl: Label 'Reviews new projects in Planning against the project creation rules.';

    procedure GetInitials(): Text[4]
    begin
        exit(AgentInitialsLbl);
    end;

    procedure GetSetupPageId(): Integer
    begin
        exit(Page::"PI Agent Setup");
    end;

    procedure GetSummaryPageId(): Integer
    begin
        exit(Page::"PI Agent KPI");
    end;

    [NonDebuggable]
    procedure GetInstructions(): SecretText
    var
        Instructions: Text;
    begin
        Instructions := NavApp.GetResourceAsText(InstructionsResourceTok);
        exit(Instructions);
    end;

    /// <summary>
    /// Project Inspector starts on the standard Project Manager home page, like in Agent Designer.
    /// </summary>
    procedure GetDefaultProfile(var TempAllProfile: Record "All Profile" temporary)
    begin
        Agent.PopulateDefaultProfile(DefaultProfileTok, GetBaseApplicationAppId(), TempAllProfile);
    end;

    /// <summary>
    /// D365 READ for the review, and PI Agent Edit to apply the salesperson's answers to the project (step 8).
    /// </summary>
    procedure GetDefaultAccessControls(var TempAccessControlBuffer: Record "Access Control Buffer" temporary)
    var
        CurrentModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(CurrentModuleInfo);
        TempAccessControlBuffer.Reset();
        TempAccessControlBuffer.DeleteAll();
        AddAccessControl(TempAccessControlBuffer, GetBaseApplicationAppId(), DefaultPermissionSetTok);
        AddAccessControl(TempAccessControlBuffer, CurrentModuleInfo.Id(), AgentEditPermissionSetTok);
    end;

    /// <summary>
    /// Gives an existing agent the current default permissions. Called on upgrade, because agents created
    /// before version 2.0 only had D365 READ.
    /// </summary>
    procedure UpdateAccessControls(AgentUserSecurityId: Guid)
    var
        TempAccessControlBuffer: Record "Access Control Buffer" temporary;
    begin
        GetDefaultAccessControls(TempAccessControlBuffer);
        Agent.UpdateAccessControl(AgentUserSecurityId, TempAccessControlBuffer);
    end;

    local procedure AddAccessControl(var TempAccessControlBuffer: Record "Access Control Buffer" temporary; AppId: Guid; RoleId: Code[20])
    begin
        TempAccessControlBuffer.Init();
        TempAccessControlBuffer."Company Name" := CopyStr(CompanyName(), 1, MaxStrLen(TempAccessControlBuffer."Company Name"));
        TempAccessControlBuffer.Scope := TempAccessControlBuffer.Scope::System;
        TempAccessControlBuffer."App ID" := AppId;
        TempAccessControlBuffer."Role ID" := RoleId;
        TempAccessControlBuffer.Insert();
    end;

    procedure GetAgentMetadataProvider(): Enum "Agent Metadata Provider"
    begin
        exit(Enum::"Agent Metadata Provider"::"Project Inspector");
    end;

    procedure GetAgentUserName(): Code[50]
    begin
        exit(CopyStr(AgentNameLbl + ' - ' + CompanyName(), 1, 50));
    end;

    procedure GetDefaultDisplayName(): Text[80]
    begin
        exit(DefaultDisplayNameLbl);
    end;

    procedure GetAgentSummary(): Text
    begin
        exit(AgentSummaryLbl);
    end;

    /// <summary>
    /// Returns the active Project Inspector agent, if there is one.
    /// </summary>
    procedure TryGetActiveAgent(var AgentUserSecurityId: Guid): Boolean
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
    begin
        Clear(AgentUserSecurityId);
        if not PIAgentSetupRecord.FindSet() then
            exit(false);

        repeat
            if Agent.IsActive(PIAgentSetupRecord."User Security ID") then begin
                AgentUserSecurityId := PIAgentSetupRecord."User Security ID";
                exit(true);
            end;
        until PIAgentSetupRecord.Next() = 0;

        exit(false);
    end;

    procedure RegisterCapability()
    var
        CopilotCapability: Codeunit "Copilot Capability";
        LearnMoreUrlTxt: Label 'https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/ai/ai-development-toolkit-landing-page', Locked = true;
    begin
        if CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Project Inspector") then
            CopilotCapability.UnregisterCapability(Enum::"Copilot Capability"::"Project Inspector");

        CopilotCapability.RegisterCapability(
            Enum::"Copilot Capability"::"Project Inspector",
            Enum::"Copilot Availability"::Preview,
            "Copilot Billing Type"::"Microsoft Billed",
            LearnMoreUrlTxt);
    end;

    procedure UpdateInstructions(AgentUserSecurityId: Guid)
    var
        PIAgentKPI: Record "PI Agent KPI";
        CurrentModuleInfo: ModuleInfo;
    begin
        Agent.SetInstructions(AgentUserSecurityId, GetInstructions());
        NavApp.GetCurrentModuleInfo(CurrentModuleInfo);
        PIAgentKPI.SetInstructionsVersion(AgentUserSecurityId, CopyStr(Format(CurrentModuleInfo.AppVersion()), 1, 30));
    end;

    procedure InitializeSetupRecord(var TempPIAgentSetup: Record "PI Agent Setup" temporary)
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
    begin
        if not IsNullGuid(TempPIAgentSetup."User Security ID") then
            if PIAgentSetupRecord.Get(TempPIAgentSetup."User Security ID") then
                TempPIAgentSetup.TransferFields(PIAgentSetupRecord, false);

        if TempPIAgentSetup.IsEmpty() then
            TempPIAgentSetup.Insert();
    end;

    procedure SaveSetupRecord(var TempPIAgentSetup: Record "PI Agent Setup" temporary; var TempAgentSetupBuffer: Record "Agent Setup Buffer")
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
        AgentSetup: Codeunit "Agent Setup";
        IsNewAgent: Boolean;
    begin
        IsNewAgent := IsNullGuid(TempAgentSetupBuffer."User Security ID");

        if AgentSetup.GetChangesMade(TempAgentSetupBuffer) then begin
            TempPIAgentSetup."User Security ID" := AgentSetup.SaveChanges(TempAgentSetupBuffer);
            if IsNewAgent then
                UpdateInstructions(TempPIAgentSetup."User Security ID");
        end;

        if IsNullGuid(TempPIAgentSetup."User Security ID") then
            exit;

        if PIAgentSetupRecord.Get(TempPIAgentSetup."User Security ID") then
            exit;

        PIAgentSetupRecord.Init();
        PIAgentSetupRecord."User Security ID" := TempPIAgentSetup."User Security ID";
        PIAgentSetupRecord.Insert();
    end;

    local procedure GetBaseApplicationAppId(): Guid
    var
        BaseApplicationAppId: Guid;
    begin
        Evaluate(BaseApplicationAppId, BaseApplicationAppIdTok);
        exit(BaseApplicationAppId);
    end;
}
