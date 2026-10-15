namespace Contoso.ProjectInspector;

using System.Utilities;

/// <summary>
/// Reads the review report of Project Inspector (format defined in step 7 of the instructions):
///   Project &lt;No.&gt; review: &lt;status&gt;
///   Blocks: ... | Total: ... | Days: ...
///   Findings:
///   - &lt;finding&gt;
///   Questions for the salesperson:
///   - &lt;question&gt;
///   &lt;closing line&gt;
/// </summary>
codeunit 50109 "PI Report Parser"
{
    Access = Internal;

    var
        ProjectPrefixTok: Label 'Project ', Locked = true;
        ReviewSeparatorTok: Label ' review:', Locked = true;
        QuestionsHeaderTok: Label 'Questions for the salesperson:', Locked = true;
        FindingsHeaderTok: Label 'Findings:', Locked = true;
        NotAppliedHeaderTok: Label 'Not applied:', Locked = true;
        BulletTok: Label '- ', Locked = true;

    procedure GetQuestions(ReportText: Text; var Questions: List of [Text])
    begin
        GetSection(ReportText, QuestionsHeaderTok, Questions);
    end;

    /// <summary>
    /// Returns the last line of the report, for example "Stopped: the salesperson cancelled the project.".
    /// </summary>
    procedure GetClosingLine(ReportText: Text): Text
    var
        Lines: List of [Text];
    begin
        GetLines(ReportText, Lines);
        if Lines.Count() = 0 then
            exit('');
        exit(Lines.Get(Lines.Count()));
    end;

    /// <summary>
    /// Returns the findings as one text, one finding per line.
    /// </summary>
    procedure GetFindingsText(ReportText: Text): Text
    var
        Findings: List of [Text];
    begin
        GetSection(ReportText, FindingsHeaderTok, Findings);
        exit(JoinLines(Findings));
    end;

    /// <summary>
    /// Returns the answers the agent could not apply, one per line with the reason.
    /// </summary>
    procedure GetNotAppliedText(ReportText: Text): Text
    var
        NotApplied: List of [Text];
    begin
        GetSection(ReportText, NotAppliedHeaderTok, NotApplied);
        exit(JoinLines(NotApplied));
    end;

    procedure HasQuestions(ReportText: Text): Boolean
    var
        Questions: List of [Text];
    begin
        GetQuestions(ReportText, Questions);
        exit(Questions.Count() > 0);
    end;

    /// <summary>
    /// Returns the questions as one text, one question per line.
    /// </summary>
    procedure GetQuestionsText(ReportText: Text): Text
    var
        Questions: List of [Text];
    begin
        GetQuestions(ReportText, Questions);
        exit(JoinLines(Questions));
    end;

    /// <summary>
    /// Returns the bullet lines under a section header, without the "- ". The section ends at the first line without a bullet.
    /// </summary>
    local procedure GetSection(ReportText: Text; Header: Text; var SectionLines: List of [Text])
    var
        Lines: List of [Text];
        Line: Text;
        InSection: Boolean;
    begin
        Clear(SectionLines);
        GetLines(ReportText, Lines);
        foreach Line in Lines do begin
            if InSection then begin
                if not Line.StartsWith(BulletTok) then
                    exit;
                SectionLines.Add(Line.Substring(StrLen(BulletTok) + 1).Trim());
            end;
            if Line = Header then
                InSection := true;
        end;
    end;

    local procedure JoinLines(Lines: List of [Text]): Text
    var
        Line: Text;
        Result: TextBuilder;
    begin
        foreach Line in Lines do begin
            if Result.Length() > 0 then
                Result.Append(LineFeed());
            Result.Append(Line);
        end;
        exit(Result.ToText());
    end;

    procedure GetProjectNo(ReportText: Text): Code[20]
    var
        FirstLine: Text;
        SeparatorPos: Integer;
    begin
        FirstLine := GetFirstLine(ReportText);
        if not FirstLine.StartsWith(ProjectPrefixTok) then
            exit('');
        SeparatorPos := FirstLine.IndexOf(ReviewSeparatorTok);
        if SeparatorPos = 0 then
            exit('');
        exit(CopyStr(FirstLine.Substring(StrLen(ProjectPrefixTok) + 1, SeparatorPos - StrLen(ProjectPrefixTok) - 1).Trim(), 1, 20));
    end;

    procedure GetStatus(ReportText: Text): Text
    var
        FirstLine: Text;
        SeparatorPos: Integer;
    begin
        FirstLine := GetFirstLine(ReportText);
        SeparatorPos := FirstLine.IndexOf(ReviewSeparatorTok);
        if SeparatorPos = 0 then
            exit('');
        exit(FirstLine.Substring(SeparatorPos + StrLen(ReviewSeparatorTok)).Trim());
    end;

    local procedure GetFirstLine(ReportText: Text): Text
    var
        Lines: List of [Text];
    begin
        GetLines(ReportText, Lines);
        if Lines.Count() = 0 then
            exit('');
        exit(Lines.Get(1));
    end;

    /// <summary>
    /// Splits the report into trimmed, non-empty lines. Works with LF and CR LF line breaks and with the HTML
    /// the agent stores in Business Central (&lt;br&gt; between the lines, entities such as &amp;amp;).
    /// </summary>
    local procedure GetLines(ReportText: Text; var Lines: List of [Text])
    var
        RawLine: Text;
        Line: Text;
        CarriageReturn: Text[1];
    begin
        Clear(Lines);
        CarriageReturn[1] := 13;
        foreach RawLine in ToPlainText(ReportText).Split(LineFeed()) do begin
            Line := RawLine.Replace(CarriageReturn, '').Trim();
            if Line <> '' then
                Lines.Add(Line);
        end;
    end;

    local procedure ToPlainText(ReportText: Text): Text
    var
        Regex: Codeunit Regex;
        PlainText: Text;
    begin
        PlainText := Regex.Replace(ReportText, '(?i)<br\s*/?>|</p\s*>', LineFeed());
        PlainText := Regex.Replace(PlainText, '<[^>]+>', '');
        PlainText := PlainText.Replace('&nbsp;', ' ').Replace('&lt;', '<').Replace('&gt;', '>').Replace('&quot;', '"').Replace('&#39;', '''');
        exit(PlainText.Replace('&amp;', '&'));
    end;

    local procedure LineFeed(): Text[1]
    var
        LF: Text[1];
    begin
        LF[1] := 10;
        exit(LF);
    end;
}
