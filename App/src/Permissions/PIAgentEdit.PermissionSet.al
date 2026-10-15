namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>
/// For the Project Inspector agent, next to D365 READ: it applies the salesperson's answers to the project
/// (dates, quantities, new planning lines, quote numbers, Open Points) in step 8 of its instructions.
/// The status is changed by PI Report Monitor on the reviewer's decision, not by the agent.
/// </summary>
permissionset 50101 "PI Agent Edit"
{
    Caption = 'Project Inspector - agent edits';
    Assignable = true;

    Permissions =
        tabledata Job = RM,
        tabledata "Job Task" = RIM,
        tabledata "Job Task Dimension" = RIMD,
        tabledata "Job Planning Line" = RIMD,
        tabledata "PI Review Decision Entry" = RI;
}
