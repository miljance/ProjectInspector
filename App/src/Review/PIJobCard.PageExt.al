namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

pageextension 50100 "PI Job Card" extends "Job Card"
{
    layout
    {
        addlast(General)
        {
            field("PI Open Points"; Rec."PI Open Points")
            {
                ApplicationArea = Jobs;
                MultiLine = true;
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action(PISendToProjectInspector)
            {
                ApplicationArea = Jobs;
                Caption = 'Send to Project Inspector';
                ToolTip = 'Send this project in status Planning to Project Inspector for a review against the project creation rules.';
                Image = Task;

                trigger OnAction()
                var
                    ReviewTrigger: Codeunit "PI Review Trigger";
                begin
                    ReviewTrigger.SubmitForReview(Rec);
                    Message(SentMsg, Rec."No.");
                end;
            }
        }
    }

    var
        SentMsg: Label 'Project %1 was sent to Project Inspector.', Comment = '%1 = project No.';
}
