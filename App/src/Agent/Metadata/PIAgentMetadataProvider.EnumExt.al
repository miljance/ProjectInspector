namespace Contoso.ProjectInspector;

using System.Agents;

enumextension 50101 "PI Agent Metadata Provider" extends "Agent Metadata Provider"
{
    value(50100; "Project Inspector")
    {
        Caption = 'Project Inspector';
        Implementation = IAgentFactory = "PI Agent Factory", IAgentMetadata = "PI Agent Metadata", IAgentTaskExecution = "PI Agent Task Execution";
    }
}
