{$Include GDefines}
{$Include CDefines}
unit CAdvGUI;

interface

uses Basics, Base3D, CTypes, CAST, CMiscItems, C2D, CGUI, CRender, CRes, CInput,
     Windows, SysUtils;

const     
// Panel sliding modes
  slNone = 0; slShow = 1; slHide = 2; slRolledOut = 3;

type
  TEditor = class(TPanel)
    MaxLength: Integer;
    FocusedColor, FocusedTextColor, FocusedLinesColor, CursorColor, Counter: Longword;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetFocus(const AFocused: Boolean); override;
    function Process: Boolean; override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure Render(const Screen: TScreen); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  private
    Changed: Boolean;
    OldText: string;
    function GetText: string;
    procedure SetText(const Value: string);
  public
    property Text: string read GetText write SetText;
  end;

  TZoomingMessage = class(TLabel)
    Zooming, Fading, Faded: Boolean;
    function Process: Boolean; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    procedure SetPosition(const AX, AY: Single); override;
    procedure Show; override;
    procedure Fade; virtual;
    procedure Zoom; virtual;
  private
    ZoomK, ZoomSpeed, FadeK, FadeSpeed, OrigTextXScale, OrigTextYScale, OrigX, OrigY: Single;
    OrigColor, OrigHoverColor: Longword;
  end;

  TList = class(TTextGUIItem)
    Items: TStringArray; TotalItems: Integer;
    Position, TopPosition, MaxItems, EnabledItems, VisibleItems: Integer;
    SelectedColor, DisabledColor: Cardinal;
    TextHeight: Single;
    SortDataType: Integer;
    Scrollable: Boolean;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetChild(Index: Integer; AItem: TItem): TItem; override;
    procedure SetPosition(NewPosition: Integer); virtual;
    procedure SelectLast; virtual;
    procedure SetText(const AText: string); override;
    procedure Add(const AItem: string); virtual;
    procedure Delete(const Index: Integer); virtual;
    procedure Clear; virtual;
    procedure OrderByInds(Inds: TIndArray); virtual;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure Render(const Screen: TScreen); override;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
  protected
    SelectionBar, UpButton, DownButton: TGUIItem;
    ScrollBar: TSlider;
  end;

  TTable = class(TTextGUIItem)
    Columns: TStringArray; TotalCols, MaxCols: Integer;
    Items: array of TStringArray; TotalRows: Integer;
    TopPosition, MaxRows, EnabledItems: Integer;
    SelectedColor, DisabledColor: Cardinal;
    TextHeight: Single;
    SortingColumn: Integer;
    AccSort: Boolean;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Sort(Column: Integer; Acc: Boolean); virtual;
    function SetChild(Index: Integer; AItem: TItem): TItem; override;
    procedure SetText(const AText: string); override;
    procedure SetColumns(ATotalCols: Integer); virtual;
    procedure Clear; virtual;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure Render(const Screen: TScreen); override;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
  protected
    SelectionBar: TGUIItem;
    ListItems: array of TList;
  end;

  TMessagesList = class(TList)
    function SetChild(Index: Integer; AItem: TItem): TItem; override;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    procedure Add(const AItem: string); override;
    procedure Show; override;
    procedure Hide; override;
    procedure Fade; virtual;
    function Process: Boolean; override;
    function ProcessInput(MX, MY: Single): Boolean; override;
  protected
    Fader: TFader;
    PauseProcess: Boolean;
    LastAddTick, HideTimeout: Integer;
    OrigColor, OrigSelColor, OrigDisColor: Longword;
  end;

  TSlidingPanel = class(TPanel)
    Sliding: Cardinal;
    HiddenX, HiddenY: Single;  // Coordinates in hidden state
    Hidden: Boolean;
    procedure Show; override;
    procedure Hide; override;
    procedure InstantHide;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    procedure SetPosition(const AX, AY: Single); override;
    function Process: Boolean; override;
  protected
    OrigX, OrigY: Single;      // Original coordinates (before sliding)
    SlideStep, k: Single;
    HideCounter, HideTimeout: Integer;
  end;

implementation

{ TEditor }

function TEditor.ProcessInput(MX, MY: Single): Boolean;
var i: Integer; AddStr, InputBuf: string;
  hg: THandle;
  P: PChar;
begin
  Result := inherited ProcessInput(MX, MY);

  if (TotalChilds < 1) or (Childs[0] = nil) then Exit;

  Changed := False;

  if Focused then begin
    AddStr := '';
    for i := GetGUI.Commands.TotalCommands-1 downto 0 do case GetGUI.Commands.Commands[i].CommandID of
      cmdClipBoardPaste: begin
        OpenClipboard(0);
        hg := GetClipboardData(CF_TEXT);
        CloseClipboard;
        P := GlobalLock(hg);
        AddStr := AddStr + Copy(P, 0, Length(P));
        GlobalUnlock(hg);
      end;
      cmdKeyESC: begin
        Changed := Text <> OldText;
        Text := OldText; SetFocus(False);
        GetGUI.Commands.DeleteCmd(cmdKeyESC, False);
        Break;
      end;
      cmdKeyENTER: begin
        SetFocus(False); Break;
      end;
{      cmdKeyBackspace: if (Length(TLabel(Childs[0]).Text) > 0) then begin
        TLabel(Childs[0]).Text := Copy(TLabel(Childs[0]).Text, 0, Length(TLabel(Childs[0]).Text)-1);
        Changed := True;
      end;}
      cmdKeyDelete: if (Length(TLabel(Childs[0]).Text) > 0) then begin
        TLabel(Childs[0]).Text := ''; Changed := True;
      end;
    end;

    InputBuf := GetGUI.Controller.InputBuffer;
    if (InputBuf = Chr(8)) then begin
      if (Length(TLabel(Childs[0]).Text) > 0) then begin
        TLabel(Childs[0]).Text := Copy(TLabel(Childs[0]).Text, 0, Length(TLabel(Childs[0]).Text)-1);
        Changed := True;
      end;
    end else AddStr := AddStr + InputBuf;

    AddStr := Copy(AddStr, 1, MaxI(0, MaxLength - Length(TLabel(Childs[0]).Text)));
    (Childs[0] as TLabel).Text := (Childs[0] as TLabel).Text + AddStr;

    Changed := Changed or (AddStr <> '');

    if Changed and EOnChange then GetGUI.Commands.Add(cmdGUIChange, [Integer(Self)]);

    CurrentColor := FocusedColor;
    (Childs[0] as TLabel).CurrentColor := FocusedTextColor;
    CurrentLineColor := FocusedLinesColor;
    GetGUI.HoldInput := True;
  end;

  Result := Result or Hover or RMousePressed;
//  if Result then ClearInput(Commands);

end;

procedure TEditor.Render(const Screen: TScreen);
var Lbl: TLabel;
begin
  inherited;
  if Focused then begin
    Lbl := TLabel(Childs[0]);
    Screen.SetRenderPasses(RenderPasses);
    Screen.SetColor(CursorColor);
    Screen.Bar(X + Lbl.X + Lbl.GetTextWidth, Y + Height - 4, X + Lbl.X + Lbl.GetTextWidth + Lbl.TextXScale / 16, Y + Height - 2);
  end;
end;

constructor TEditor.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  AddChild(TLabel.Create(AName+'_Text', AWorld, Self));
  CanFocus := True;
  MaxLength := 255;
end;

function TEditor.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Max length', ptInt32, Pointer(MaxLength));
  NewProperty(Result, 'Focused color', ptColor32, Pointer(FocusedColor));
  NewProperty(Result, 'Focused text color', ptColor32, Pointer(FocusedTextColor));
  NewProperty(Result, 'Focused lines color', ptColor32, Pointer(FocusedLinesColor));
end;

function TEditor.SetProperties(AProperties: TProperties): Integer;
begin
  if inherited SetProperties(AProperties) < 0 then Exit;
  MaxLength := Integer(GetPropertyValue(AProperties, 'Max length'));
  FocusedColor := Longword(GetPropertyValue(AProperties, 'Focused color'));
  FocusedTextColor := Longword(GetPropertyValue(AProperties, 'Focused text color'));
  FocusedLinesColor := Longword(GetPropertyValue(AProperties, 'Focused lines color'));
  Result := 0;
end;

procedure TEditor.SetFocus(const AFocused: Boolean);
begin
  inherited;
  if AFocused then OldText := Text;
  GetGUI.Controller.InputBuffer;
end;

function TEditor.Process: Boolean;
begin
  Result := inherited Process;
  if Counter > 0 then Dec(Counter) else begin
    Counter := 15;
    if CursorColor = $FFFFFFFF then CursorColor := $FF000000 else CursorColor := $FFFFFFFF;
  end;
end;

function TEditor.GetText: string;
begin
  Result := (Childs[0] as TLabel).Text;
end;

procedure TEditor.SetText(const Value: string);
begin
//  Changed := Changed or (Value <> Text);
  (Childs[0] as TLabel).SetText(Value);
end;

{ TZoomingMessage }

procedure TZoomingMessage.Fade;
begin
  Fading := True;
  if ZoomSpeed = 0 then ZoomK := 1;
  FadeK := 0;
  TextXScale := OrigTextXScale;
  Width := GetTextWidth;
  TextXScale := OrigTextXScale * ZoomK;
end;

procedure TZoomingMessage.Zoom;
begin
  Zooming := True;
  FadeK := 0; ZoomK := 0;
  TextXScale := OrigTextXScale;
  Width := GetTextWidth;
  TextXScale := OrigTextXScale * ZoomK;
end;

function TZoomingMessage.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Fade speed', ptSingle, Pointer(FadeSpeed));
  NewProperty(Result, 'Zoom speed', ptSingle, Pointer(ZoomSpeed));
end;

function TZoomingMessage.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  FadeSpeed := Single(GetPropertyValue(AProperties, 'Fade speed'));
  ZoomSpeed := Single(GetPropertyValue(AProperties, 'Zoom speed'));

  OrigColor := Color; OrigHoverColor := HoverColor;
  OrigTextXScale := TextXScale; OrigTextYScale := TextYScale;
  Fading := False; FadeK := 0;
  Zooming := False; ZoomK := 0;

//  SetTextRes(Integer(GetPropertyValue(AProperties, 'Text')));

  Result := 0;
end;

function TZoomingMessage.Process: Boolean;
begin
  if Fading then begin
    if FadeK < 1 then FadeK := FadeK + FadeSpeed else begin
      FadeK := 1; Fading := False; Hide;
    end;
  end;
  if Zooming then begin
    if ZoomK < 1 then ZoomK := ZoomK + ZoomSpeed else begin
      ZoomK := 1; Zooming := False; Fade;
    end;

  end;
  if Zooming or Fading then begin
    TextXScale := OrigTextXScale * ZoomK;
    TextYScale := OrigTextYScale * ZoomK;
    FX := OrigX + Width * Maxs(0, (1-ZoomK)) * 0.5;
    FY := OrigY + Height * Maxs(0, (1-ZoomK)) * 0.5;

    Color := OrigColor and $FFFFFF + Longword(Trunc(0.5 + (OrigColor shr 24) * Maxs(0, (1-FadeK)))) shl 24;
    Faded := Color and $FF000000 = 0;
    HoverColor := OrigHoverColor and $FFFFFF + Longword(Trunc(0.5 + (OrigHoverColor shr 24) * (1-FadeK))) shl 24;
  end;
end;

procedure TZoomingMessage.Show;
begin
  inherited;
//  FadeK := 0; ZoomK := 0;
  TextXScale := OrigTextXScale * ZoomK;
    TextYScale := OrigTextYScale * ZoomK;
  Color := OrigColor;
  HoverColor := OrigHoverColor;
  Faded := False;
end;

procedure TZoomingMessage.SetPosition(const AX, AY: Single);
begin
  inherited;
  OrigX := FX; OrigY := FY;
end;

{ TList }

constructor TList.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  Clear;
  MaxItems := 0;
  EnabledItems := MaxInt;
end;

procedure TList.SetPosition(NewPosition: Integer);
begin
  NewPosition := MaxI(-1, MinI(MinI(EnabledItems, TotalItems)-1, NewPosition));
  if (Position <> NewPosition) and EOnChange then GetGUI.Commands.Add(cmdGUIChange, [Integer(Self), NewPosition]);
  Position := NewPosition;
  if (Position < TopPosition) then TopPosition := MaxI(0, Position);
  if (Position >= TopPosition + VisibleItems) then TopPosition := MaxI(0, Position - VisibleItems + 1);
  if ScrollBar <> nil then begin
    ScrollBar.MaxValue := MaxI(1, TotalItems-1);
    if TotalItems = 0 then ScrollBar.Value := 1 else ScrollBar.Value := MaxI(0, TotalItems-Position-1);
  end;
end;

procedure TList.SelectLast;
begin
  SetPosition(TotalItems-1);
end;

procedure TList.Add(const AItem: string);
var i, sp: Integer;
begin
  if (MaxItems = 0) or (TotalItems < MaxItems) then begin
    Inc(TotalItems); SetLength(Items, TotalItems);
  end else begin
    for i := 0 to TotalItems-2 do Items[i] := Items[i+1];
    sp := Pos('\&', FText);
    if sp > 0 then FText := Copy(FText, sp+2, Length(FText));
  end;  
  
  Items[TotalItems-1] := AItem;
  if FText <> '' then FText := FText + '\&';
  FText := FText + AItem;
  if not Scrollable then begin
    SetDimensions(Width, TotalItems * TextHeight);
    VisibleItems := TotalItems;
  end else VisibleItems := Trunc(Height / TextHeight);

  SetPosition(Position);
end;

procedure TList.Clear;
begin
  FText := '';
  SetLength(Items, 0); TotalItems := 0; TopPosition := 0; SetPosition(-1);
end;

procedure TList.Delete(const Index: Integer);
begin

end;

function TList.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Max items', ptInt32, Pointer(MaxItems));
  NewProperty(Result, 'Enabled items', ptInt32, Pointer(EnabledItems));
  NewProperty(Result, 'Selected text color', ptColor32, Pointer(SelectedColor));
  NewProperty(Result, 'Disabled text color', ptColor32, Pointer(DisabledColor));
  NewProperty(Result, 'Text height', ptSingle, Pointer(TextHeight));
  NewProperty(Result, 'Sort as (Str, Int, Float)', ptInt32, Pointer(SortDataType));
  NewProperty(Result, 'Scrollable', ptBoolean, Pointer(Scrollable));
end;

function TList.SetProperties(AProperties: TProperties): Integer;
begin
  Result := 0;
  MaxItems := Integer(GetPropertyValue(AProperties, 'Max items'));
  EnabledItems := Integer(GetPropertyValue(AProperties, 'Enabled items'));
  TextHeight := Single(GetPropertyValue(AProperties, 'Text height'));
  Scrollable := Boolean(GetPropertyValue(AProperties, 'Scrollable'));
  if inherited SetProperties(AProperties) < 0 then Exit;

  SelectedColor := Longword(GetPropertyValue(AProperties, 'Selected text color'));
  DisabledColor := Longword(GetPropertyValue(AProperties, 'Disabled text color'));

  SortDataType := Integer(GetPropertyValue(AProperties, 'Sort as (Str, Int, Float)'));

  if not Scrollable then begin
    SetDimensions(Width, TotalItems * TextHeight);
    VisibleItems := TotalItems;
  end else VisibleItems := Trunc(Height / TextHeight);
end;

function TList.ProcessInput(MX, MY: Single): Boolean;
var i: Integer;
begin
  Result := inherited ProcessInput(MX, MY);
  if LMousePressed then begin
    if (MY < FY) then SetPosition(MaxI(0, Position-1)) else
     if (MY > FY + Height) then SetPosition(MaxI(0, Position+1)) else
      SetPosition(MaxI(0, TopPosition + Trunc((MY - Y) / TextHeight)));
  end else for i := 0 to GetGUI.Commands.TotalCommands-1 do if GetGUI.Commands.Commands[i].CommandID = cmdGUIClick then begin
    if TGUIItem(GetGUI.Commands.Commands[i].PTR1) = UpButton then SetPosition(MaxI(0, Position-1));
    if TGUIItem(GetGUI.Commands.Commands[i].PTR1) = DownButton then SetPosition(MaxI(0, Position+1));
  end else if (ScrollBar <> nil) and (GetGUI.Commands.Commands[i].CommandID = cmdGUIChange) then begin
    if TGUIItem(GetGUI.Commands.Commands[i].PTR1) = ScrollBar then SetPosition(MaxI(0, TotalItems-ScrollBar.Value-1));
  end;
  if SelectionBar <> nil then SelectionBar.SetPosition(0, (Position - TopPosition) * TextHeight);
end;

procedure TList.Render(const Screen: TScreen);
var i: Integer;
begin
  if SelectionBar <> nil then if (TotalItems = 0) or (Position = -1) then SelectionBar.Hide else SelectionBar.Show;
  inherited;
  if (Position >= 0) and (Position < TotalItems) then begin
// Selected text
    if Position < EnabledItems then Screen.SetColor(SelectedColor) else Screen.SetColor(DisabledColor);
    Screen.SetRenderPasses(RenderPasses);
    Screen.SetFont(Screen.AddFont(World.ResourceManager, FontRes, CharMapRes, TextXScale, TextYScale));
    Screen.DrawColoredText(X, Y + (Position-TopPosition) * TextHeight, @Items[Position]);
  end;
  
  for i := 0 to VisibleItems-1 do if (TopPosition+i < TotalItems) and (TopPosition+i <> Position) then begin
    if TopPosition+i < EnabledItems then Screen.SetColor(Color) else Screen.SetColor(DisabledColor);
    Screen.SetRenderPasses(RenderPasses);
    Screen.SetFont(Screen.AddFont(World.ResourceManager, FontRes, CharMapRes, TextXScale, TextYScale));
    Screen.DrawColoredText(X, Y + i * TextHeight, @Items[TopPosition+i]);
  end;
end;

procedure TList.SetText(const AText: string);
begin
  Clear;
  FText := AText;
  if FText <> '' then TotalItems := Split(FText, '\&', Items, True) else begin
    TotalItems := 0;
    SetLength(Items, TotalItems);
  end;
  if TotalItems > MaxItems then begin
    SetLength(Items, MaxItems);
    TotalItems := MaxItems;
  end;
  if not Scrollable then begin
    SetDimensions(Width, TotalItems * TextHeight);
    VisibleItems := TotalItems;
  end else VisibleItems := Trunc(Height / TextHeight);
  SetPosition(Position);
end;

function TList.SetChild(Index: Integer; AItem: TItem): TItem;
begin
  Result := inherited SetChild(Index, AItem);
  if (Result <> nil) and (Result is TGUIItem) then begin
    if UpperCase(Result.Name) = 'SELBAR' then SelectionBar := Result as TGUIItem;
    if UpperCase(Result.Name) = 'UPBUTTON' then UpButton := Result as TGUIItem;
    if UpperCase(Result.Name) = 'DOWNBUTTON' then DownButton := Result as TGUIItem;
    if UpperCase(Result.Name) = 'SCROLLBAR' then ScrollBar := Result as TSlider;
  end;
end;

procedure TList.OrderByInds(Inds: TIndArray);
var i: Integer; NewText: string;
begin
  NewText := '';
  for i := 0 to TotalItems-1 do begin
    if i > 0 then NewText := NewText + '\&';
    NewText := NewText + Items[Inds[i]];
  end;
  SetText(NewText);
end;

{ TTable }

constructor TTable.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  MaxCols := 0;
  Clear;
  EnabledItems := MaxInt;
  SortingColumn := -1; AccSort := True;
end;

function TTable.SetChild(Index: Integer; AItem: TItem): TItem;
begin
  Result := inherited SetChild(Index, AItem);
  if (Result is TList) then begin
    if (Index >= TotalCols) then begin
      MaxCols := Index+1;
      SetLength(Items, MaxCols); SetLength(ListItems, MaxCols);
    end;
    ListItems[Index] := Result as TList;
  end;
end;

procedure TTable.SetText(const AText: string);
var i: Integer;
begin
  Clear;
  FText := AText;
  if FText <> '' then TotalCols := MinI(MaxCols, Split(FText, '^/', Columns, True));
  for i := 0 to TotalCols-1 do if ListItems[i] <> nil then ListItems[i].Text := Columns[i];
  SetLength(Columns, 0);
//  Height := TotalItems * TextHeight;
end;

procedure TTable.SetColumns(ATotalCols: Integer);
begin
  TotalCols := MinI(MaxCols, ATotalCols);
end;

procedure TTable.Clear;
var i: Integer;
begin
  for i := 0 to MaxCols-1 do Items[i] := nil;
  TotalRows := 0; TopPosition := 0;
end;

function TTable.ProcessInput(MX, MY: Single): Boolean;
begin
  Result := inherited ProcessInput(MX, MY);
end;

procedure TTable.Render(const Screen: TScreen);
begin
  inherited;
end;

procedure TTable.Sort(Column: Integer; Acc: Boolean);
var i: Integer; Inds, Values: TIndArray; ValuesS: TSingleArray;
begin
  SortingColumn := Column;
  AccSort := Acc;

  if (Column < 0) or (Column > MaxCols-1) then Exit;

  if ListItems[Column] <> nil then begin
    SetLength(Inds, ListItems[Column].TotalItems);
    case ListItems[Column].SortDataType of
      sdtString: QuickSortStrInd(ListItems[Column].TotalItems, ListItems[Column].Items, Inds, Acc);
      sdtInt: begin
        SetLength(Values, ListItems[Column].TotalItems);
        for i := 0 to ListItems[Column].TotalItems-1 do Values[i] := StrToIntDef(ListItems[Column].Items[i], 0);
        QuickSortIntInd(ListItems[Column].TotalItems, Values, Inds, Acc);
        SetLength(Values, 0);
      end;
      sdtSingle: begin
        SetLength(ValuesS, ListItems[Column].TotalItems);
        for i := 0 to ListItems[Column].TotalItems-1 do ValuesS[i] := StrToFloatDef(AssureFloatFormat(ListItems[Column].Items[i]), 0);
        QuickSortSInd(ListItems[Column].TotalItems, ValuesS, Inds, Acc);
        SetLength(ValuesS, 0);
      end;
    end;
  end;

  for i := 0 to TotalCols-1 do begin
    ListItems[i].OrderByInds(Inds);
  end;
end;

function TTable.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Sorted by', ptInt32, Pointer(SortingColumn));
  NewProperty(Result, 'Accending', ptBoolean, Pointer(AccSort));
end;

function TTable.SetProperties(AProperties: TProperties): Integer;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;
  SortingColumn := Integer(GetPropertyValue(AProperties, 'Sorted by'));
  AccSort := Boolean(GetPropertyValue(AProperties, 'Accending'));
  if SortingColumn <> -1 then Sort(SortingColumn, AccSort);
end;

{ TMessagesList }

procedure TMessagesList.Add(const AItem: string);
begin
  if TotalItems >= MaxItems then Delete(0);
  inherited;
  SetPosition(TotalItems-1);
  LastAddTick := TicksProcessed;
  if HideTimeout >= 0 then Show;
end;

function TMessagesList.GetProperties: TProperties;
begin
  Color := OrigColor;
  SelectedColor := OrigSelColor;
  DisabledColor := OrigDisColor;
  Result := inherited GetProperties;
  NewProperty(Result, 'Hide timeout', ptInt32, Pointer(HideTimeout));
  NewProperty(Result, 'Process while paused', ptBoolean, Pointer(PauseProcess));
end;

function TMessagesList.SetProperties(AProperties: TProperties): Integer;
begin
  Result := inherited SetProperties(AProperties);
  HideTimeout := Integer(GetPropertyValue(AProperties, 'Hide timeout'));
  PauseProcess := Boolean(GetPropertyValue(AProperties, 'Process while paused'));
  if PauseProcess then begin
    Status := Status or isPauseProcessing;
    if Fader <> nil then Fader.Status := Fader.Status or isPauseProcessing;
  end;
  OrigColor := Color;
  OrigSelColor := SelectedColor;
  OrigDisColor := DisabledColor;
end;

function TMessagesList.SetChild(Index: Integer; AItem: TItem): TItem;
begin
  Result := inherited SetChild(Index, AItem);
  if (Result is TFader) then begin
    Fader := Result as TFader;
    if PauseProcess then Fader.Status := Fader.Status or isPauseProcessing;
  end;
end;

procedure TMessagesList.Hide;
begin
  if Fader <> nil then Fader.Hide else inherited;
end;

procedure TMessagesList.Show;
begin
  if Fader <> nil then Fader.Show else inherited;
  LastAddTick := TicksProcessed;
end;

procedure TMessagesList.Fade;

function FadeColor(Color: Longword; Alpha: Single): Longword;
begin
  Result := Color and $FFFFFF or Trunc(0.5 + MinS(Alpha * (Color shr 24), 255)) shl 24;
end;

var i: Integer;

begin
  if Fader = nil then Exit;

  Color := FadeColor(OrigColor, Fader.CurAlpha);
  SelectedColor := FadeColor(OrigSelColor, Fader.CurAlpha);
  DisabledColor := FadeColor(OrigDisColor, Fader.CurAlpha);

  for i := 0 to TotalChilds-1 do if (Childs[i] is TGUIItem) and not (Childs[i] as TGUIItem).Hover then begin
    (Childs[i] as TGUIItem).CurrentColor := FadeColor((Childs[i] as TGUIItem).Color, Fader.CurAlpha);
  end;
end;

function TMessagesList.Process: Boolean;
begin
  Result := inherited Process;
  Fade;

  if Fader.Status and isVisible = 0 then Status := Status and not isVisible else Status := Status or isVisible;

  if (TicksProcessed - LastAddTick > HideTimeout) and (HideTimeout > 0) then Hide;
end;

function TMessagesList.ProcessInput(MX, MY: Single): Boolean;
begin
  Result := inherited ProcessInput(MX, MY);
  if IsInBounds(MX, MY) and (Status and isVisible > 0) then Show;
  Fade;
end;

{ TSlidingPanel }

procedure TSlidingPanel.SetPosition(const AX, AY: Single);
begin
  if (Sliding = slNone) then begin
    OrigX := AX; OrigY := AY;
  end;
  inherited;
end;

procedure TSlidingPanel.Show;
begin
//  if Sliding = slVisible then Exit;     // Already visible
  inherited;
  if Sliding = slRolledOut then K := 0;
  Sliding := slShow;
  Status := Status or isProcessing;          // Enable processing
  Hidden := False;
end;

procedure TSlidingPanel.Hide;
begin
  if Sliding <> slNone then begin
//    inherited;
  end else begin
    K := 1;
  end;
  Sliding := slHide;
end;

procedure TSlidingPanel.InstantHide;
begin
  K := 0;
  HideCounter := 0;
  Sliding := slRolledOut;
end;

function TSlidingPanel.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Sliding speed', ptSingle, Pointer(SlideStep));
  NewProperty(Result, 'Hidden X', ptSingle, Pointer(HiddenX));
  NewProperty(Result, 'Hidden Y', ptSingle, Pointer(HiddenY));
  NewProperty(Result, 'Hide after', ptInt32, Pointer(HideTimeout));
end;

function TSlidingPanel.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  SlideStep := Single(GetPropertyValue(AProperties, 'Sliding speed'));
  HiddenX := Single(GetPropertyValue(AProperties, 'Hidden X'));
  HiddenY := Single(GetPropertyValue(AProperties, 'Hidden Y'));
  HideTimeout := Integer(GetPropertyValue(AProperties, 'Hide after'));

  Result := 0;
end;

function TSlidingPanel.Process: Boolean;
var EndSlide: Boolean;
begin
  Result := inherited Process;
  EndSlide := False;
  case Sliding of
    slShow: begin
      k := k + SlideStep;
      if k >= 1 then begin
        k := 1;
        EndSlide := True;
      end;
    end;
    slHide: begin
      k := k - SlideStep;
      if k <= 0 then begin
        k := 0;
        EndSlide := True;
      end;
    end;
    slRolledOut: if HideCounter > 0 then Dec(HideCounter) else begin
      inherited Hide;                            // Hide the panel
      Hidden := True;
      Status := Status and not isProcessing;     // Disable processing while hidden
    end;
  end;
  if Sliding <> slNone then SetPosition(OrigX*Sin(k*pi/2) + HiddenX*(1-Sin(k*pi/2)), OrigY*Sin(k*pi/2) + HiddenY*(1-Sin(k*pi/2)));
  if EndSlide then begin
    if (K = 0) then begin
      HideCounter := HideTimeout;
      Sliding := slRolledOut;
    end else Sliding := slNone;
  end;
end;

end.
