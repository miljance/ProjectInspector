namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using System.TestLibraries.Utilities;

/// <summary>
/// Like the Sales Order Agent and the Payables Agent, Project Inspector belongs to the company where it is activated:
/// every company can activate its own, and an agent of another company neither blocks that nor reviews its projects.
/// </summary>
codeunit 50167 "PI Agent Company Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        AgentFactory: Codeunit "PI Agent Factory";

    [Test]
    procedure AgentOfAnotherCompanyAllowsANewOne()
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
    begin
        // [GIVEN] Only another company has a Project Inspector
        PIAgentSetupRecord.SetRange("Company Name", CompanyName());
        PIAgentSetupRecord.DeleteAll();
        CreateAgentSetup('OTHER COMPANY');

        // [WHEN] This company looks at the agents it can add
        // [THEN] Project Inspector is offered
        Assert.IsTrue(AgentFactory.ShowCanCreateAgent(), 'Each company can activate its own Project Inspector.');
    end;

    [Test]
    procedure AgentOfThisCompanyBlocksASecondOne()
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
    begin
        // [GIVEN] This company has a Project Inspector
        PIAgentSetupRecord.SetRange("Company Name", CompanyName());
        PIAgentSetupRecord.DeleteAll();
        CreateAgentSetup(CopyStr(CompanyName(), 1, 30));

        // [WHEN] This company looks at the agents it can add
        // [THEN] A second one is not offered
        Assert.IsFalse(AgentFactory.ShowCanCreateAgent(), 'One Project Inspector per company.');
    end;

    local procedure CreateAgentSetup(AgentCompanyName: Text[30])
    var
        PIAgentSetupRecord: Record "PI Agent Setup";
    begin
        PIAgentSetupRecord.Init();
        PIAgentSetupRecord."User Security ID" := CreateGuid();
        PIAgentSetupRecord."Company Name" := AgentCompanyName;
        PIAgentSetupRecord.Insert();
    end;
}
