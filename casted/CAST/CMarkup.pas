{$Include GDefines}
{$Include CDefines}
unit CMarkup;

interface

const
// Markup tags
  mtColorSet = 0; mtAlphaColorSet = 1; mtColorReset = 2; mtItalicSet = 3; mtItalicReset = 4;
//Text parsing constants
  cmNone = 0; cmPrefix = 1;

type
  TTag = packed record
    Position, Kind: Integer;
    IData: Longword; PData: Pointer;
  end;

  TMarkup = class
    Tags: array of TTag; TotalTags: Integer;
    procedure ParseFormatting; virtual; abstract;
    function GetTagStrAtPos(const Position: Integer): string; virtual; abstract;
    function GetResultTagStrAtPos(const Position: Integer): string; virtual; abstract;
  private
    CText, FText: string;
    procedure AddTag(const Kind, IntData: Longword; PTRData: Pointer); virtual;
    procedure SetFText(const Value: string); virtual;
    destructor Free;
  public
    property FormattedText: string read FText write SetFText;
    property ClearedText: string read CText;
  end;

  TSimpleMarkup = class(TMarkup)
    procedure ParseFormatting; override;
    function GetTagStrAtPos(const Position: Integer): string; override;
    function GetResultTagStrAtPos(const Position: Integer): string; override;
  end;

implementation

uses SysUtils, Basics;

{ TMarkup }

procedure TMarkup.AddTag(const Kind, IntData: Longword; PTRData: Pointer);
begin
  Inc(TotalTags); SetLength(Tags, TotalTags);
  Tags[TotalTags-1].Position := Length(CText);
  Tags[TotalTags-1].Kind := Kind;
  Tags[TotalTags-1].IData:= IntData;
  Tags[TotalTags-1].PData := PTRData;
end;

destructor TMarkup.Free;
begin
  TotalTags := 0; SetLength(Tags, 0);
end;

procedure TMarkup.SetFText(const Value: string);
begin
  if Value = FText then Exit;
  FText := Value;
  ParseFormatting;
end;

{ TSimpleMarkup }

const PrefixSimbol = '^';
// ToFix: Eliminate useless tags, e.g. ^<CFFFFFF>^<C>
function TSimpleMarkup.GetTagStrAtPos(const Position: Integer): string;
var i, j: Integer;
begin
  Result := '';
  for i := 0 to TotalTags-1 do if Tags[i].Position = Position then begin
    j := i;
    while (j < TotalTags) and (Tags[j].Position = Position) do begin
      case Tags[j].Kind of
        mtColorSet: Result := Result + PrefixSimbol+'<C' + IntToHex(Tags[j].IData, 6) + '>';
        mtAlphaColorSet: Result := Result + PrefixSimbol+'<A' + IntToHex(Tags[j].IData, 8) + '>';
        mtColorReset: Result := Result + PrefixSimbol+'<C>';
        mtItalicSet: Result := Result + PrefixSimbol+'<I' + IntToStr(Tags[j].IData) + '>';
        mtItalicReset: Result := Result + PrefixSimbol+'<I>';
      end;
      Inc(j);
    end;
    Exit;
  end;
end;

function TSimpleMarkup.GetResultTagStrAtPos(const Position: Integer): string;
var j: Integer;
begin
  Result := '';
  j := 0;
  while (j < TotalTags) and (Tags[j].Position <= Position) do begin
    case Tags[j].Kind of
      mtColorSet: Result := Result + PrefixSimbol+'<C' + IntToHex(Tags[j].IData, 6) + '>';
      mtAlphaColorSet: Result := Result + PrefixSimbol+'<A' + IntToHex(Tags[j].IData, 8) + '>';
      mtColorReset: Result := Result + PrefixSimbol+'<C>';
      mtItalicSet: Result := Result + PrefixSimbol+'<I' + IntToStr(Tags[j].IData) + '>';
      mtItalicReset: Result := Result + PrefixSimbol+'<I>';
    end;
    Inc(j);
  end;
end;

procedure TSimpleMarkup.ParseFormatting;
// Valid constructions:
// ^<C00000000>    -   color set without alpha
// ^<A00000000>    -   color set with alpha
// ^<C>            -   color reset
// ^<I30>          -   italic value set in percents of character width
// ^<I>            -   turn off italic
var
  i, CommandEndPos, CommandMode: Integer;
  LastValue, LastCommand, LastResetCommand: Longword;
  Command: string;
begin
  CText := '';
  TotalTags := 0;
  i := 1;
  CommandMode := cmNone;
  LastValue:= 0;
  while i <= Length(FText) do begin
    if (FText[i] = '^') and (CommandMode = cmNone) then CommandMode := cmPrefix else begin
      if (CommandMode = cmPrefix) and (FText[i] = '<') then begin
//        if (FText[i] = '<') then begin
          CommandEndPos := Pos('>', Copy(FText, i+1, Length(FText)));
          Command := Copy(FText, i+1, CommandEndPos-1);
          if Command <> '' then begin
            case UpCase(Command[1]) of
              'C': begin LastCommand := mtColorSet; LastResetCommand := mtColorReset; end;
              'A': begin LastCommand := mtAlphaColorSet; LastResetCommand := mtColorReset; end;
              'I': begin LastCommand := mtItalicSet; LastResetCommand := mtItalicReset; end;
              else Continue;
            end;
            Command := Copy(Command, 2, Length(Command));
            if Command = '' then AddTag(LastResetCommand, 0, nil) else begin
              LastValue := HexStrToIntDef(Command, LastValue);
              AddTag(LastCommand, LastValue, nil);
            end;
          end;
          if CommandEndPos = 0 then i := Length(FText)+1 else i := i + CommandEndPos;
//        end;
        CommandMode := cmNone;
      end else begin
        CText := CText + FText[i];
        CommandMode := cmNone;
      end;
    end;
    Inc(i);
  end;
end;

end.
