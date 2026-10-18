namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using System.Agents;

pageextension 50100 "PI Job Card" extends "Job Card"
{
    layout
    {
        // The agent edits the plain field (it adds "Answered: ..." to settled points). People get a full-width editor in its own
        // FastTab, one point per line, like the outgoing message editor.
        addlast(General)
        {
            field("PI Open Points"; Rec."PI Open Points")
            {
                ApplicationArea = Jobs;
                MultiLine = true;
                Visible = IsAgentSession;
            }
            field("PI Planned Days"; Rec."PI Planned Days")
            {
                ApplicationArea = Jobs;
            }
            field(PIWorkshopDatesMissing; WorkshopDatesMissing)
            {
                ApplicationArea = Jobs;
                Caption = 'Workshop Dates Missing';
                ToolTip = 'Specifies the SERVICES tasks of analysis workshop blocks whose planning lines name no date (PCR-22). Project Inspector asks the salesperson for the dates of these tasks.';
                Editable = false;
            }
        }
        addafter(General)
        {
            group(PIOpenPoints)
            {
                Caption = 'Open Points';
                Visible = not IsAgentSession;

                field(PIOpenPointsHtml; OpenPointsHtml)
                {
                    ApplicationArea = Jobs;
                    Caption = 'Open Points';
                    ToolTip = 'Specifies the open points Scribe Agent found in the conversation, one per line as <topic>: <question> (PCR-24). Project Inspector asks the salesperson about each of them.';
                    ShowCaption = false;
                    MultiLine = true;
                    ExtendedDatatype = RichContent;

                    trigger OnValidate()
                    var
                        ReportParser: Codeunit "PI Report Parser";
                    begin
                        Rec.Validate("PI Open Points", CopyStr(ReportParser.ToReportText(OpenPointsHtml), 1, MaxStrLen(Rec."PI Open Points")));
                    end;
                }
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

    trigger OnOpenPage()
    var
        AgentSession: Codeunit "Agent Session";
        AgentMetadataProvider: Enum "Agent Metadata Provider";
    begin
        IsAgentSession := AgentSession.IsAgentSession(AgentMetadataProvider);
    end;

    trigger OnAfterGetCurrRecord()
    var
        ReportParser: Codeunit "PI Report Parser";
        ReviewChecks: Codeunit "PI Review Checks";
    begin
        OpenPointsHtml := ReportParser.ToHtml(Rec."PI Open Points");
        WorkshopDatesMissing := ReviewChecks.GetWorkshopTasksWithoutDates(Rec."No.");
    end;

    var
        SentMsg: Label 'Project %1 was sent to Project Inspector.', Comment = '%1 = project No.';
        OpenPointsHtml: Text;
        WorkshopDatesMissing: Text;
        IsAgentSession: Boolean;
}
