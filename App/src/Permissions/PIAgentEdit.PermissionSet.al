namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>
/// For the Project Inspector agent, next to D365 READ: it applies the salesperson's answers to the project
/// (dates, quantities, new planning lines, quote numbers, Open Points) in step 8 of its instructions.
/// The status is changed by PI Report Monitor after the reviewer's decision, not by the agent.
/// The agent records the review report on the Review Result card (step 9).
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
        tabledata "PI Review Result" = RIM,
        page "PI Review Results" = X,
        page "PI Review Result Card" = X,
        page "PI Agent Role Center" = X;
}
