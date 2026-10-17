namespace Contoso.ProjectInspector;

/// <summary>
/// For users and service connections that send projects to Project Inspector or pass answers to it:
/// project managers, the Copilot Studio (Scribe Agent) connection and the Power Automate connection.
/// The agent itself runs with D365 READ (see PI Agent Setup).
/// </summary>
permissionset 50100 "PI Project Inspector"
{
    Caption = 'Project Inspector - use';
    Assignable = true;

    Permissions =
        tabledata "PI Clarification Answer" = RIM,
        tabledata "PI Review Result" = RM,
        page "PI Review Results" = X,
        page "PI Review Result Card" = X,
        table "PI Clarification Answer" = X,
        page "PI Project Reviews API" = X,
        page "PI Clarification Answers API" = X,
        page "PI Clarification Answers" = X,
        page "PI Agent Status API" = X,
        codeunit "PI Review Trigger" = X,
        codeunit "PI Business Events" = X,
        codeunit "PI Report Monitor" = X;
}
