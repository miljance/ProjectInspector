namespace Contoso.ProjectInspector;

using System.Agents;

/// <summary>
/// One review result. The agent fills in the project and the report and asks for assistance on this page, so the
/// review opens it: the reviewer reads and can edit the report here, and decides with the instructions in the task
/// pane; the agent then sets the Decision. Nothing is carried out before Continue (see PI Report Monitor).
/// Not DelayedInsert: the result must exist while the agent waits for the reviewer.
/// A carried-out result is read-only, so a new review cannot overwrite it.
/// </summary>
page 50108 "PI Review Result Card"
{
    PageType = Card;
    ApplicationArea = Jobs;
    Caption = 'Project Inspector Review Result';
    SourceTable = "PI Review Result";
    // Newest first: the review of an agent task opens this card without moving to the agent's record, so the card
    // must show the result the agent has just written, not the oldest one.
    SourceTableView = sorting("Entry No.") order(descending);
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Project No."; Rec."Project No.") { }
                // Only the reviewer chooses the decision; the agent session cannot change it (see the table).
                field(Decision; Rec.Decision)
                {
                    Editable = not IsAgentSession;
                    Style = Strong;
                }
                // The agent writes the report into this plain field. Visible only in the agent's session: the session is
                // known when the page opens, a condition on the record is not.
                field(Report; Rec.Report)
                {
                    MultiLine = true;
                    Visible = IsAgentSession;
                }
            }
            group(ReportView)
            {
                Caption = 'Review report';
                Visible = not IsAgentSession;

                field(ReportHtml; ReportHtml)
                {
                    Caption = 'Review report';
                    ToolTip = 'Specifies the review report of Project Inspector. Edit it before you decide: the findings and questions are sent as they are here.';
                    ShowCaption = false;
                    MultiLine = true;
                    ExtendedDatatype = RichContent;
                    Editable = not IsProcessed;

                    trigger OnValidate()
                    begin
                        Rec.SetReportFromHtml(ReportHtml);
                    end;
                }
            }
            group(Processing)
            {
                Caption = 'Status';

                field(StatusText; StatusText)
                {
                    Caption = 'Status';
                    ToolTip = 'Specifies the step of the review: waiting for your decision, waiting for Continue, or what Business Central did.';
                    ShowCaption = false;
                    Editable = false;
                }
                field("Processed At"; Rec."Processed At")
                {
                    Visible = Rec.Processed;
                }
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
    begin
        ReportHtml := Rec.GetReportAsHtml();
        StatusText := Rec.GetStatusText();
        IsProcessed := Rec.Processed;
        CurrPage.Editable := not Rec.Processed;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Clear(ReportHtml);
        CurrPage.Editable := true;
    end;

    var
        ReportHtml: Text;
        IsAgentSession: Boolean;
        StatusText: Text;
        IsProcessed: Boolean;
}
