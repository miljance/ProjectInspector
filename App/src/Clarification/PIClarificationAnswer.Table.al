namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Answers of salespeople to Project Inspector questions, received from Teams through Power Automate.
/// Kept as a log; each answer is passed to the review task of the project when it is inserted.
/// </summary>
table 50102 "PI Clarification Answer"
{
    Caption = 'Project Inspector Clarification Answer';
    DataClassification = CustomerContent;
    LookupPageId = "PI Clarification Answers";
    DrillDownPageId = "PI Clarification Answers";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            ToolTip = 'Specifies the number of the answer.';
            AutoIncrement = true;
            Editable = false;
        }
        field(2; "Project No."; Code[20])
        {
            Caption = 'Project No.';
            ToolTip = 'Specifies the project the answer belongs to.';
            TableRelation = Job;
        }
        field(3; Answer; Text[2048])
        {
            Caption = 'Answer';
            ToolTip = 'Specifies the answer of the salesperson.';
        }
        field(4; "Answered By"; Text[250])
        {
            Caption = 'Answered By';
            ToolTip = 'Specifies who answered, for example the e-mail of the salesperson in Teams.';
        }
        field(5; "Received At"; DateTime)
        {
            Caption = 'Received At';
            ToolTip = 'Specifies when Business Central received the answer and passed it to Project Inspector.';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Project; "Project No.")
        {
        }
    }
}
