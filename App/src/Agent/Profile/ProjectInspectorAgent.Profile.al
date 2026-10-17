namespace Contoso.ProjectInspector;

/// <summary>
/// Profile of the Project Inspector agent: its own home page with the pages its instructions use.
/// </summary>
profile "Project Inspector Agent"
{
    Caption = 'Project Inspector (Copilot)';
    Description = 'Home page of the Project Inspector agent';
    ProfileDescription = 'Reviews new projects in status Planning against the project creation rules and records the review result.';
    RoleCenter = "PI Agent Role Center";
}
