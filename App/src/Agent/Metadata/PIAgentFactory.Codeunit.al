namespace Contoso.ProjectInspector;

using System.Agents;
using System.AI;
using System.Reflection;
using System.Security.AccessControl;

/// <summary>
/// Creates Project Inspector agents: one per company, like the Sales Order Agent.
/// </summary>
codeunit 50100 "PI Agent Factory" implements IAgentFactory
{
    Access = Internal;

    var
        PIAgentSetup: Codeunit "PI Agent Setup";

    procedure GetDefaultInitials(): Text[4]
    begin
        exit(PIAgentSetup.GetInitials());
    end;

    procedure GetFirstTimeSetupPageId(): Integer
    begin
        exit(PIAgentSetup.GetSetupPageId());
    end;

    procedure ShowCanCreateAgent(): Boolean
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
    begin
        // One Project Inspector per company: the review triggers send the company's projects to its own agent.
        PIAgentSetupRecord.SetRange("Company Name", CompanyName());
        exit(PIAgentSetupRecord.IsEmpty());
    end;

    procedure GetCopilotCapability(): Enum "Copilot Capability"
    begin
        exit("Copilot Capability"::"Project Inspector");
    end;

    procedure GetDefaultProfile(var TempAllProfile: Record "All Profile" temporary)
    begin
        PIAgentSetup.GetDefaultProfile(TempAllProfile);
    end;

    procedure GetDefaultAccessControls(var TempAccessControlTemplate: Record "Access Control Buffer" temporary)
    begin
        PIAgentSetup.GetDefaultAccessControls(TempAccessControlTemplate);
    end;
}
