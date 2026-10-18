namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;

/// <summary>
/// For the Project Inspector agent, next to D365 READ: it applies the salesperson's answers to the project
/// (dates, quantities, new planning lines and TRAVEL tasks, quote numbers, Open Points) under When answers arrive.
/// The status is changed by PI Report Monitor after the reviewer's decision, not by the agent.
/// The agent records the review report on the Review Result card (step 8).
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
        // A new planning line takes its Job Contract Entry No. from this counter (seen on BC 29 when the agent added
        // the travel line of an answer).
        tabledata "Job Entry No." = Rim,
        tabledata "PI Review Result" = RIM,
        page "PI Review Results" = X,
        page "PI Review Result Card" = X,
        page "PI Agent Role Center" = X;
}
