namespace Contoso.ProjectInspector;

/// <summary>
/// What the reviewer decided after a Project Inspector report.
/// </summary>
enum 50100 "PI Review Decision"
{
    Extensible = false;
    Caption = 'Project Inspector Review Decision';

    value(0; Approve)
    {
        Caption = 'Approve';
    }
    value(1; Reject)
    {
        Caption = 'Reject';
    }
    value(2; "Send Questions")
    {
        Caption = 'Send Questions';
    }
}
