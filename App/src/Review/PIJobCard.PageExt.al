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
            // The reviewer's decisions after a Project Inspector report. The agent clicks them on the reviewer's choice,
            // so they show no message; PI Report Monitor carries them out within a minute.
            action(PIApproveProject)
            {
                ApplicationArea = Jobs;
                Caption = 'Approve Project';
                ToolTip = 'Approve the project after the Project Inspector review. It is set to status Quote and the team is notified.';
                Image = Approve;

                trigger OnAction()
                var
                    ReviewDecisions: Codeunit "PI Review Decisions";
                begin
                    ReviewDecisions.Register(Rec, Enum::"PI Review Decision"::Approve);
                end;
            }
            action(PIRejectProject)
            {
                ApplicationArea = Jobs;
                Caption = 'Reject Project';
                ToolTip = 'Reject the project after the Project Inspector review. The team is notified with the findings of the report.';
                Image = Reject;

                trigger OnAction()
                var
                    ReviewDecisions: Codeunit "PI Review Decisions";
                begin
                    ReviewDecisions.Register(Rec, Enum::"PI Review Decision"::Reject);
                end;
            }
            action(PISendQuestions)
            {
                ApplicationArea = Jobs;
                Caption = 'Send Questions to Salesperson';
                ToolTip = 'Send the questions of the latest Project Inspector report to the salesperson in Teams.';
                Image = SendTo;

                trigger OnAction()
                var
                    ReviewDecisions: Codeunit "PI Review Decisions";
                begin
                    ReviewDecisions.Register(Rec, Enum::"PI Review Decision"::"Send Questions");
                end;
            }
        }
    }

    var
        SentMsg: Label 'Project %1 was sent to Project Inspector.', Comment = '%1 = project No.';
}
