namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Planning;

/// <summary>
/// Shows the discount of every planning line, so the agent reads it for PCR-16 instead of computing
/// Quantity x Unit Price minus Line Amount itself.
/// </summary>
pageextension 50101 "PI Job Planning Lines" extends "Job Planning Lines"
{
    layout
    {
        modify("Line Discount Amount")
        {
            Visible = true;
        }
    }
}
