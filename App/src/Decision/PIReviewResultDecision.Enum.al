namespace Contoso.ProjectInspector;

/// <summary>
/// The reviewer's decision on a recorded review result. Blank until the reviewer decided on the Review Result card.
/// </summary>
enum 50101 "PI Review Result Decision"
{
    Extensible = false;
    Caption = 'Project Inspector Review Result Decision';

    value(0; " ")
    {
        Caption = ' ', Locked = true;
    }
    value(1; Approve)
    {
        Caption = 'Approve';
    }
    value(2; Reject)
    {
        Caption = 'Reject';
    }
    value(3; "Send Questions")
    {
        Caption = 'Send Questions';
    }
}
