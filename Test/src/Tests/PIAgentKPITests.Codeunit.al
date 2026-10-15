namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using System.TestLibraries.Utilities;

/// <summary>
/// The summary page shows which instructions the agent has. A task keeps the instructions it was created with,
/// and Business Central cannot read them back from the agent, so this is the only way to check an upgrade.
/// </summary>
codeunit 50154 "PI Agent KPI Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure SetInstructionsVersionStoresVersionAndTime()
    var
        PIAgentKPI: Record "PI Agent KPI";
        AgentUserSecurityId: Guid;
        StartedAt: DateTime;
    begin
        // [GIVEN] An agent without a summary record
        AgentUserSecurityId := CreateGuid();
        StartedAt := CurrentDateTime();

        // [WHEN] The instructions of version 1.2.0.0 are set on the agent
        PIAgentKPI.SetInstructionsVersion(AgentUserSecurityId, '1.2.0.0');

        // [THEN] The summary record shows the version and when it was set
        PIAgentKPI.Get(AgentUserSecurityId);
        Assert.AreEqual('1.2.0.0', PIAgentKPI."Instructions Version", 'Wrong instructions version.');
        Assert.IsTrue(PIAgentKPI."Instructions Updated At" >= StartedAt, 'Instructions Updated At must be set.');
    end;

    [Test]
    procedure SetInstructionsVersionKeepsTheCounters()
    var
        PIAgentKPI: Record "PI Agent KPI";
        AgentUserSecurityId: Guid;
    begin
        // [GIVEN] An agent that already reviewed a project
        AgentUserSecurityId := CreateGuid();
        PIAgentKPI.AddReviewRequested(AgentUserSecurityId);

        // [WHEN] New instructions are set
        PIAgentKPI.SetInstructionsVersion(AgentUserSecurityId, '1.2.0.0');

        // [THEN] The review counter is unchanged
        PIAgentKPI.Get(AgentUserSecurityId);
        Assert.AreEqual(1, PIAgentKPI."Reviews Requested", 'The review counter must be kept.');
    end;
}
