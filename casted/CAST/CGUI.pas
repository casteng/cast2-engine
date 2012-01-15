{$Include GDefines}
{$Include CDefines}
unit CGUI;

interface

uses
   Logger, 
  Basics, BaseCont, Base3D, CTypes, CAST, C2D, CRender, CRes, CInput, Windows, CMarkup;

const
  cmdKeyESC = cmdGUIBase + 1;
  cmdKeyENTER= cmdGUIBase + 2;
  cmdKeySpace = cmdGUIBase + 3;
  cmdKeyBackspace = cmdGUIBase + 4;
  cmdKeyDelete = cmdGUIBase + 5;
  cmdLeftMouseDown = cmdGUIBase + 10;
  cmdLeftMouseUp = cmdGUIBase + 11;
  cmdLeftMouseClick = cmdGUIBase + 12;

//  cmdRMouseDown = cmdGUIBase + 2; cmdRMouseUp = cmdGUIBase + 3;
//  cmdMouseClick = cmdGUIBase + 4; cmdMouseDblClick = cmdGUIBase + 5;

  cmdGUIFirst = cmdGUIBase + 100;
  cmdGUIRightBottomMoved = cmdGUIBase + 100;
  cmdGUIMouseIn = cmdGUIBase + 200;
  cmdGUIMouseOut = cmdGUIBase + 201;
  cmdGUIClick = cmdGUIBase + 202;
  cmdGUIMouseDown = cmdGUIBase + 203;
  cmdGUIMouseUp = cmdGUIBase + 204;
  cmdGUIChange = cmdGUIBase + 205;

  cmdClipBoardPaste = cmdGUIBase + 250;

  cmdGUILast = cmdGUIBase + 250;

  bsMouseLeft = 1; bsMouseRight = 2; bsMouseMiddle = 4;

// Aligment modes
  aLeft = -1; aTop = -1; aCenter = 0; aRight = 1; aBottom = 1; aPercent = 2;

  MouseInfValue = 10000000.0; // Assigns to mouse X coordinate to avoid farther hover processing
// Controller states
  csShift = 1; csCtrl = 2; csAlt = 3;
// Text wrapping modes
  wmNone = 0; wmCut = -1; wmSimbolWrap = 1; wmWordWrap = 2; wmJustify = 3;
// Move modes
  mmNone = 0; mmMove = 1; mmResize = 2; mmMoveParent = 3; mmResizeParent = 4;

type
  TGUI = class;

  TGUIItem = class(TItem)
    Z: Single;
    CurrentColor, Color, HoverColor, DisabledColor: Longword;
    Enabled, Disabled, Transparent: Boolean;
    AnchorLeft, AnchorTop, AnchorRight, AnchorBottom: Boolean;
    MinWidth, MinHeight, MaxWidth, MaxHeight: Single;
    MoveMode: Integer;
    HAlign, VAlign: Integer;
    WPercent, HPercent: Boolean;                               // Are width and height in percent
    Hover: Boolean;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetLocation(ALocation: TVector3s); override;     // For position changing
    function GetGUI: TGUI; virtual;

    procedure Disable; virtual;
    procedure Enable; virtual;

    procedure Render(const Screen: TScreen); virtual;
    function GetDistanceFromItem(const MX, MY: Single): Single; virtual;
    function IsInBounds(const MX, MY: Single): Boolean; virtual;

    procedure ClearInput(var Commands: TCommandQueue); virtual;
// ProcessInput: processes input and command queue, generating new commands. Removes handled input commands from queue.
// Returns false if farther processing required
    function ProcessInput(MX, MY: Single): Boolean; virtual;
// HandleCommand: handles system commads such as parent control's resize
    procedure HandleCommand(const Command: TCommand); override;

    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;

    procedure SetPosition(const AX, AY: Single); virtual;
    procedure SetDimensions(const AWidth, AHeight: Single); virtual;
    procedure SetAnchors(const AAnchorLeft, AAnchorTop, AAnchorRight, AAnchorBottom: Boolean); virtual;
    procedure SetAlign(const AHAlign, AVAlign: Integer); virtual;
    procedure SetConstraints(const AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Single); virtual;
    procedure SetColor(const AColor: Longword); virtual;
    procedure SetAbility(const AEnabled: Boolean); virtual;
    procedure SetFocus(const AFocused: Boolean); virtual;
    procedure DoMove(const X, Y: Single); virtual;

    procedure SetTextXAlign(const Value: Integer);
    procedure SetTextYAlign(const Value: Integer);
  protected
    Proportion, FX, FY, FWidth, FHeight: Single;
    ProportionsByWidth: Boolean;
    FTextYAlign, FTextXAlign: Integer;
    DragPointX, DragPointY: Single;
    CanFocus, Focused: Boolean;
    LMousePressed, RMousePressed, LShiftPressed, ControlPressed, AltPressed: Boolean; // True if pressed within bounds
    EOnMouseIn, EOnMouseOut, EOnClick, EOnMouseDown, EOnMouseUp, EOnChange: Boolean;
    function GetX: Single;
    function GetY: Single;
    function GetWidth: Single;
    function GetHeight: Single;
  public
    property X: Single read GetX write FX;
    property Y: Single read GetY write FY;
    property Width: Single read GetWidth write FWidth;
    property Height: Single read GetHeight write FHeight;
    property TexXAlign: Integer read FTextXAlign write SetTextXAlign;
    property TexYAlign: Integer read FTextYAlign write SetTextYAlign;
  end;

  TUVGUIItem = class(TGUIItem)
    MaxFrame, NormalFrame: Integer;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    procedure SetFrame(const Value: Integer); virtual;
  protected
    FFrame: Integer;
    UVMapRes: Integer;
    UVMap: TUVMap;
  public
    property Frame: Integer read FFrame write SetFrame;
  end;

  TGUIPoint = class(TGUIItem)
  end;

  TGUILine = class(TGUIItem)
    procedure Render(const Screen: TScreen); override;
  end;

  TTextGUIItem = class(TGUIItem)
    TextXScale, TextYScale: Single;
    Markup: TMarkup;
    function GetTextWidth: Single; virtual;
    procedure SetText(const AText: string); virtual;
    procedure SetTextRes(const ATextRes: Integer); virtual;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetClearedText: string;
    destructor Free;
  protected
    UVMap: TUVMap;
    CharMap: TCharMap;
    TextRes, FontRes, CharMapRes: Integer;
    Colored: Boolean;
    FText, RText: string;         // Text property, text to render and cleared text
  public
    property Text: string read FText write SetText;
    property CText: string read GetClearedText;
  end;

  TWrappingText = class(TTextGUIItem)
    WrapMode: Integer;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    procedure SetText(const AText: string); override;
  protected
    Lines: array of string; TotalLines: Integer;  // May be rendered as multiline text
    LineHeight: Single;
  end;

  TGUICursor = class(TUVGUIItem)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Render(const Screen: TScreen); override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    procedure SetPosition(const AX, AY: Single); override;
    procedure SetFrame(const Value: Integer); override;
    procedure SetFrameRange(const AMin, AMax: Integer); virtual;
    procedure SetWindow(const X1, Y1, X2, Y2: Single); virtual;
  protected
    CMinFrame, CMaxFrame: Integer;
    HotX, HotY: Single;
    WindowX1, WindowY1, WindowX2, WindowY2: Single;
  end;

  TLabel = class(TWrappingText)
    procedure Render(const Screen: TScreen); override;
  end;

  TSwitchLabel = class(TLabel)
// Splits text to variants by "\&". "\\" threats as "\"
    Variants: TStringArray; TotalVariants: Integer;
    procedure SetText(const AText: string); override;
    procedure SetVariantIndex(const Value: Integer); virtual;
    function ProcessInput(MX, MY: Single): Boolean; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function IndexOf(const Value: string): Integer; virtual;
  protected
    SWText: string;
    FVariantIndex: Integer;
  public
    property VariantIndex: Integer read FVariantIndex write SetVariantIndex;
  end;

  TPanel = class(TUVGUIItem)
    LineColor, LineHoverColor: Longword;
    CurrentFrame: Integer;
    procedure Render(const Screen: TScreen); override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure SetLineColor(const ALineColor: Longword);
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  protected
    CurrentLineColor: Longword;
  end;

  TSwitchButton = class(TPanel)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetFrame(const Value: Integer); override;
    procedure SetFrameRange(const AMin, AMax: Integer); virtual;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function ProcessInput(MX, MY: Single): Boolean; override;
  protected
    MinSwitchFrame, MaxSwitchFrame: Integer;
    function GetVariantIndex: Integer;
    procedure SetVariantIndex(const Value: Integer);
  public
    property VariantIndex: Integer read GetVariantIndex write SetVariantIndex;
  end;

  TCheckBox = class(TPanel)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  protected
    FChecked: Boolean;
    HoverFrame, CheckedFrame, HoverCheckedFrame: Integer;
    procedure SetChecked(const Value: Boolean);
  public
    property Checked: Boolean read FChecked write SetChecked;
  end;

  TButton = class(TPanel)
    Pressed: Boolean;
    function ProcessInput(MX, MY: Single): Boolean; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Process: Boolean; override;
  protected
    HoverFrame, PressedFrame: Integer;
    RepeatDelay, RepeatTimer: Integer;
    RepeatsPerTick, RepeatsCounter: Single;
  end;

  TSlider = class(TUVGUIItem)
    ValueColor, HoverValueColor: Longword;
    ValueFrame: Integer;
    Vertical, FreeChange, Tracking: Boolean;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Render(const Screen: TScreen); override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function SetValueByCoord(const MX, MY: Single): Boolean; virtual;
  private
    procedure SetMaxValue(const Value: Integer);
    procedure SetValue(const Value: Integer);
  protected
    FValue, FMaxValue: Integer;
    CurrentValueColor: Longword;
  public
    property Value: Integer read FValue write SetValue;
    property MaxValue: Integer read FMaxValue write SetMaxValue;
  end;

  TGUI = class(TItem)
    ItemTexts: TSimpleConfig;
    Screen: TScreen;
    FocusedControl: TGUIItem;
    Controller: TController;
    HoldInput: Boolean;
    Commands: TCommandQueue;        // For GUI-generated commands
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Init(AController: TController; ACommands: TCommandQueue); virtual;
    procedure SetItemTexts(AItemTexts: TSimpleConfig); virtual;
    function GetControllerState(const State: Cardinal): Integer; virtual;

    procedure SetScreen(const AScreen: TScreen); virtual;
    procedure Render(Renderer: TRenderer); override;

    function SetChild(Index: Integer; AItem: TItem): TItem; override;

    function ProcessInput(MX, MY: Single): Boolean; virtual;
    procedure HandleCommand(const Command: TCommand); override;

    function AddLabel(AX, AY: Single; AText: string; AColor: Longword): TLabel; virtual;
    function AddPanel(AX, AY, AWidth, AHeight: Single; ABackColor, ALineColor: Longword): TPanel; virtual;
  private
    OldWidth, OldHeight: Integer;
  end;

implementation

{ TGUIItem }

constructor TGUIItem.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  SetAbility(True);
  SetConstraints(0, 0, 10000, 10000);
  SetPosition(0, 0);
  SetDimensions(100, 100);
  SetColor($FFFFFFFF);
  SetAnchors(True, True, False, False);
  SetAlign(-1, -1);
  EOnMouseIn := False;
  EOnMouseOut := False;
  EOnClick := False;
  EOnMouseDown := False;
  EOnMouseUp := False;
  EOnChange := False;
  CanFocus := False;
  Focused := False;
  Transparent := False;
  MoveMode := mmNone;
  LMousePressed := False; RMousePressed := False; LShiftPressed := False;
  ControlPressed := False; AltPressed := False;
  Status := Status or isPauseProcessing;            
end;

procedure TGUIItem.Render(const Screen: TScreen);
var i: Integer;
begin
  Screen.SetViewport(X, Y, X + Width - 1, Y + Height - 1);
  for i := 0 to TotalChilds-1 do if Childs[i] is TGUIItem then begin
    if Childs[i].Status and isVisible <> 0 then TGuiItem(Childs[i]).Render(Screen)
  end else Childs[i].Render(World.Renderer);
  Screen.PopViewport;
end;

procedure TGUIItem.SetColor(const AColor: Longword);
begin
  Color := AColor; CurrentColor := Color;
end;

function TGUIItem.GetWidth: Single;
begin
  if WPercent then begin
    if (Parent = nil) or (Parent is TGUI) then
     Result := Trunc(0.5 + World.Renderer.RenderPars.ActualWidth * OneOver100 * FWidth) else
      Result := Trunc(0.5 + TGUIItem(Parent).Width * OneOver100 * FWidth);
  end else Result := MinS(MaxWidth, MaxS(MinWidth, FWidth));
end;

function TGUIItem.GetHeight: Single;
begin
  if HPercent then begin
    if (Parent = nil) or (Parent is TGUI) then
     Result := Trunc(0.5 + World.Renderer.RenderPars.ActualHeight * OneOver100 * FHeight) else
      Result := Trunc(0.5 + TGUIItem(Parent).Height * OneOver100 * FHeight);
  end else Result := MinS(MaxHeight, MaxS(MinHeight, FHeight));
end;

procedure TGUIItem.SetDimensions(const AWidth, AHeight: Single);
var i: Integer; OldWidth, OldHeight: Single;
begin
  OldWidth := Width; OldHeight := Height;
  FWidth := AWidth; FHeight := AHeight;
  if Proportion <> 0 then
   if ProportionsByWidth then FHeight := Trunc(0.5 + Width / Proportion) else FWidth := Trunc(0.5 + Height * Proportion);
  for i := 0 to TotalChilds - 1 do if Assigned(Childs[i]) then Childs[i].HandleCommand(NewCommandF(cmdGUIRightBottomMoved, [Width - OldWidth, Height - OldHeight]));
end;

procedure TGUIItem.SetPosition(const AX, AY: Single);
begin
  FX := AX; FY := AY;
end;

function TGUIItem.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Left', ptSingle, Pointer(FX));
  NewProperty(Result, 'Top', ptSingle, Pointer(FY));
  NewProperty(Result, 'Width', ptSingle, Pointer(FWidth));
  NewProperty(Result, 'Height', ptSingle, Pointer(FHeight));
  NewProperty(Result, 'Color', ptColor32, Pointer(Color));
  NewProperty(Result, 'Hover color', ptColor32, Pointer(HoverColor));
  NewProperty(Result, 'Disabled color', ptColor32, Pointer(DisabledColor));
  NewProperty(Result, 'Enabled', ptBoolean, Pointer(Enabled));
  NewProperty(Result, 'Transparent', ptBoolean, Pointer(Transparent));
  NewProperty(Result, 'Move mode', ptInt32, Pointer(MoveMode));
  NewProperty(Result, 'Layout', ptGroupBegin, nil);
    NewProperty(Result, 'Left anchor', ptBoolean, Pointer(AnchorLeft));
    NewProperty(Result, 'Top anchor', ptBoolean, Pointer(AnchorTop));
    NewProperty(Result, 'Right anchor', ptBoolean, Pointer(AnchorRight));
    NewProperty(Result, 'Bottom anchor', ptBoolean, Pointer(AnchorBottom));
    NewProperty(Result, 'Min width', ptSingle, Pointer(MinWidth));
    NewProperty(Result, 'Min height', ptSingle, Pointer(MinHeight));
    NewProperty(Result, 'Max width', ptSingle, Pointer(MaxWidth));
    NewProperty(Result, 'Max height', ptSingle, Pointer(MaxHeight));
    NewProperty(Result, 'Horizontal align', ptInt32, Pointer(HAlign));
    NewProperty(Result, 'Vertical align', ptInt32, Pointer(VAlign));
    NewProperty(Result, 'Width in percents', ptBoolean, Pointer(WPercent));
    NewProperty(Result, 'Height in percents', ptBoolean, Pointer(HPercent));
    NewProperty(Result, 'Proportion by width', ptBoolean, Pointer(ProportionsByWidth));
    NewProperty(Result, 'Proportion', ptSingle, Pointer(Proportion));
  NewProperty(Result, '', ptGroupEnd, nil);
  NewProperty(Result, 'Creation of events', ptGroupBegin, nil);
    NewProperty(Result, 'On mouse in', ptBoolean, Pointer(EOnMouseIn));
    NewProperty(Result, 'On mouse out', ptBoolean, Pointer(EOnMouseOut));
    NewProperty(Result, 'On click', ptBoolean, Pointer(EOnClick));
    NewProperty(Result, 'On mouse down', ptBoolean, Pointer(EOnMouseDown));
    NewProperty(Result, 'On mouse up', ptBoolean, Pointer(EOnMouseUp));
    NewProperty(Result, 'On change', ptBoolean, Pointer(EOnChange));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TGUIItem.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  SetColor(Longword(GetPropertyValue(AProperties, 'Color')));
  HoverColor := Longword(GetPropertyValue(AProperties, 'Hover color'));
  DisabledColor := Longword(GetPropertyValue(AProperties, 'Disabled color'));
  SetAbility(Boolean(GetPropertyValue(AProperties, 'Enabled')));
  Transparent := Boolean(GetPropertyValue(AProperties, 'Transparent'));
  MoveMode := Integer(GetPropertyValue(AProperties, 'Move mode'));
  SetAnchors(Boolean(GetPropertyValue(AProperties, 'Left anchor')), Boolean(GetPropertyValue(AProperties, 'Top anchor')), Boolean(GetPropertyValue(AProperties, 'Right anchor')), Boolean(GetPropertyValue(AProperties, 'Bottom anchor')));
  SetConstraints(Single(GetPropertyValue(AProperties, 'Min width')), Single(GetPropertyValue(AProperties, 'Min height')), Single(GetPropertyValue(AProperties, 'Max width')), Single(GetPropertyValue(AProperties, 'Max height')));
  SetAlign(Integer(GetPropertyValue(AProperties, 'Horizontal align', Pointer(-1))), Integer(GetPropertyValue(AProperties, 'Vertical align', Pointer(-1))));
  WPercent := Boolean(GetPropertyValue(AProperties, 'Width in percents'));
  HPercent := Boolean(GetPropertyValue(AProperties, 'Height in percents'));
  
  ProportionsByWidth := Boolean(GetPropertyValue(AProperties, 'Proportion by width'));
  Proportion := Single(GetPropertyValue(AProperties, 'Proportion'));

  SetPosition(Single(GetPropertyValue(AProperties, 'Left')), Single(GetPropertyValue(AProperties, 'Top')));
  SetDimensions(Single(GetPropertyValue(AProperties, 'Width')), Single(GetPropertyValue(AProperties, 'Height')));

  EOnMouseIn := Boolean(GetPropertyValue(AProperties, 'On mouse in'));
  EOnMouseOut := Boolean(GetPropertyValue(AProperties, 'On mouse out'));
  EOnClick := Boolean(GetPropertyValue(AProperties, 'On click'));
  EOnMouseDown := Boolean(GetPropertyValue(AProperties, 'On mouse down'));
  EOnMouseUp := Boolean(GetPropertyValue(AProperties, 'On mouse up'));
  EOnChange := Boolean(GetPropertyValue(AProperties, 'On change'));
  Result := 0;
end;

procedure TGUIItem.ClearInput(var Commands: TCommandQueue);
var i: Integer;
begin
  for i := Commands.TotalCommands-1 downto 0 do with Commands.Commands[i] do
   if ((CommandID = cmdKeyDown) or (CommandID = cmdKeyUp) or (CommandID = cmdKeyClick)) and
      ((Arg1 = IK_MouseLeft) or (Arg1 = IK_MOUSERIGHT)) then Commands.Delete(i);
end;

function TGUIItem.ProcessInput(MX, MY: Single): Boolean;
var i: Integer;
begin
//  Status := Status or isPauseProcessing;
  Result := False;

// Handle transparent mode
  if Transparent and not Disabled then begin
    if Parent is TGUIItem then begin
      Hover := TGUIItem(Parent).Hover;
      LMousePressed := TGUIItem(Parent).LMousePressed;
    end;
    if Hover then CurrentColor := HoverColor else CurrentColor := Color;
    Exit;
  end;

// Process childs
//  if (not LMousePressed) and (not RMousePressed) then            // For what reason?
  for i := TotalChilds-1 downto 0 do if (Childs[i] is TGUIItem) and (Childs[i].Status and isVisible <> 0) and (Childs[i].Status and isProcessing <> 0) then begin
    if not Enabled then TGUIItem(Childs[i]).Disabled := True else if TGUIItem(Childs[i]).Enabled then TGUIItem(Childs[i]).Disabled := False;
    if TGUIItem(Childs[i]).ProcessInput(MX - X, MY - Y) then begin
      MX := MouseInfValue;
      Result := True;
//     Childs[i].ChangeID(TotalChilds-1);
    end;
  end;

// Handle disabled mode
  if Disabled then begin
    CurrentColor := DisabledColor;
    Exit;
  end;

// Detect mousein and mouseout
  if IsInBounds(MX, MY) then begin
    if EOnMouseIn and not Hover then GetGUI.Commands.Add(cmdGUIMouseIn, [Integer(Self)]);
    Hover := True;
    CurrentColor := HoverColor;
  end else begin
    if EOnMouseOut and Hover then GetGUI.Commands.Add(cmdGUIMouseOut, [Integer(Self)]);
    if not LMousePressed or (MoveMode = mmNone) then begin
      Hover := False;
      CurrentColor := Color;
    end;
  end;

  for i := GetGUI.Commands.TotalCommands-1 downto 0 do begin
    if (GetGUI.Commands.Commands[i].CommandID = cmdLeftMouseClick) then begin
      if Hover then SetFocus(True) else SetFocus(False);
    end;

    if (GetGUI.Commands.Commands[i].CommandID = cmdLeftMouseDown) and Hover  then if not LMousePressed then begin
      if EOnMouseDown then GetGUI.Commands.Add(cmdGUIMouseDown, [Integer(Self)]);
      LMousePressed := True;
      DragPointX := MX; DragPointY := MY;
    end;

    if (GetGUI.Commands.Commands[i].CommandID = cmdLeftMouseUp) then if LMousePressed then begin
      if EOnMouseUp then GetGUI.Commands.Add(cmdGUIMouseUp, [Integer(Self)]);
      if Hover and EOnClick then GetGUI.Commands.Add(cmdGUIClick, [Integer(Self)]);
      LMousePressed := False;
    end;

{    if (GetGUI.Commands.Commands[i].CommandID = cmdKeyDown) and Hover then begin
      if GetGUI.Commands.Commands[i].Arg1 = IK_LSHIFT then LShiftPressed := True;
      if GetGUI.Commands.Commands[i].Arg1 = IK_CONTROL then ControlPressed := True;
      if GetGUI.Commands.Commands[i].Arg1 = IK_ALT then AltPressed := True;
      if GetGUI.Commands.Commands[i].Arg1 = IK_MOUSELEFT then if not LMousePressed then begin
        if EOnMouseDown then GetGUI.Commands.Add(cmdGUIMouseDown, [Integer(Self)]);
        LMousePressed := True;
        DragPointX := MX; DragPointY := MY;
      end;
      if GetGUI.Commands.Commands[i].Arg1 = IK_MOUSERIGHT then begin
        RMousePressed := True;
        DragPointX := MX-Width; DragPointY := MY-Height;
      end;
    end;}


 {   if GetGUI.Commands.Commands[i].CommandID = cmdKeyUp then begin
      if (GetGUI.Commands.Commands[i].Arg1 = IK_LSHIFT) then LShiftPressed := False;
      if GetGUI.Commands.Commands[i].Arg1 = IK_CONTROL then ControlPressed := False;
      if GetGUI.Commands.Commands[i].Arg1 = IK_ALT then AltPressed := False;
      if (GetGUI.Commands.Commands[i].Arg1 = IK_MOUSELEFT) then if LMousePressed then begin
        if EOnMouseUp then GetGUI.Commands.Add(cmdGUIMouseUp, [Integer(Self)]);
        if Hover and EOnClick then GetGUI.Commands.Add(cmdGUIClick, [Integer(Self)]);
        LMousePressed := False;
      end;
      if (GetGUI.Commands.Commands[i].Arg1 = IK_MOUSERIGHT) then RMousePressed := False;
    end;}
  end;

  if LMousePressed and (MX < MouseInfValue * 0.5) then begin
    DoMove(MX - DragPointX, MY - DragPointY);
    DragPointX := MX;
    DragPointY := MY;
  end;

//  if RMousePressed and (MX < MouseInfValue * 0.5) and (AllowResize or World.EditorMode) then
//   SetDimensions(MX - DragPointX, MY - DragPointY);

  Result := Result or Hover or RMousePressed;
//  if Result then ClearInput(GetGUI.Commands);
end;

procedure TGUIItem.SetAbility(const AEnabled: Boolean);
begin
  if AEnabled then Enable else Disable;
end;

function TGUIItem.GetDistanceFromItem(const MX, MY: Single): Single;
begin
//  if (MX > X) and (MY > Y) and (MX < X + Width) and (MY < Y + Height) then
end;

function TGUIItem.IsInBounds(const MX, MY: Single): Boolean;
begin
  Result := (MX > X) and (MY > Y) and (MX < X + Width) and (MY < Y + Height);
end;

procedure TGUIItem.SetALign(const AHAlign, AVAlign: Integer);
begin
  HAlign := AHAlign; VAlign := AVAlign;
end;

procedure TGUIItem.SetAnchors(const AAnchorLeft, AAnchorTop, AAnchorRight, AAnchorBottom: Boolean);
begin
  AnchorLeft := AAnchorLeft; AnchorTop := AAnchorTop; AnchorRight := AAnchorRight; AnchorBottom := AAnchorBottom;
end;

procedure TGUIItem.SetConstraints(const AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Single);
begin
  MinWidth := AMinWidth; MinHeight := AMinHeight; MaxWidth := AMaxWidth; MaxHeight := AMaxHeight;
  SetDimensions(FWidth, FHeight); 
end;

procedure TGUIItem.HandleCommand(const Command: TCommand);
var i: Integer; LeftK, RightK, TopK, BottomK, NewW, NewH: Single;
begin
  if Command.CommandID = cmdGUIRightBottomMoved then begin
    case Byte(AnchorRight)*2 + Byte(AnchorLeft) of
      0: begin LeftK := 0.5; RightK := 0; end;
      1: begin LeftK := 0; RightK := 0; end;
      2: begin LeftK := 1; RightK := 0; end;
      3: begin LeftK := 0; RightK := 1; end;
    end;
    case Byte(AnchorBottom)*2 + Byte(AnchorTop) of
      0: begin TopK := 0.5; BottomK := 0; end;
      1: begin TopK := 0; BottomK := 0; end;
      2: begin TopK := 1; BottomK := 0; end;
      3: begin TopK := 0; BottomK := 1; end;
    end;
    if (HAlign = 0) or WPercent then begin LeftK := 0; RightK := 0; end;
    if (VAlign = 0) or HPercent then begin TopK := 0; BottomK := 0; end;
    NewW := FWidth + Trunc(0.0 + Command.F1 * RightK);
    NewH := FHeight + Trunc(0.0 + Command.F2 * BottomK);
    SetDimensions(NewW, NewH);
    SetPosition(FX + Trunc(0.5 + Command.F1 * LeftK), FY + Trunc(0.5 + Command.F2 * TopK));
  end;
  inherited;
end;

procedure TGUIItem.SetTextXAlign(const Value: Integer);
begin
  FTextXAlign := Value;
end;

procedure TGUIItem.SetTextYAlign(const Value: Integer);
begin
  FTextYAlign := Value;
end;

function TGUIItem.GetX: Single;
var ParentWidth: Single;
begin
  if (Parent = nil) or (Parent is TGUI) then
   ParentWidth := World.Renderer.RenderPars.ActualWidth else
    ParentWidth := TGUIItem(Parent).Width;
  case HAlign of
    aLeft: Result := FX;
    aCenter: Result := Trunc(0.5 + (ParentWidth - Width) * 0.5) + FX;
    aRight: Result := ParentWidth - Width + FX;
    aPercent: Result := Trunc(0.5 + ParentWidth * OneOver100 * FX) + Frac(FX);
  end;
end;

function TGUIItem.GetY: Single;
var ParentHeight: Single;
begin
  if (Parent = nil) or (Parent is TGUI) then
   ParentHeight := World.Renderer.RenderPars.ActualHeight else
    ParentHeight := TGUIItem(Parent).Height;
  case VAlign of
    aTop: Result := FY;
    aCenter: Result := Trunc(0.5 + (ParentHeight - Height) * 0.5) + FY;
    aBottom: Result := ParentHeight - Height + FY;
    aPercent: Result := Trunc(0.5 + ParentHeight * OneOver100 * FY) + Frac(FY);
  end;
end;

procedure TGUIItem.SetFocus(const AFocused: Boolean);
var GUI: TGUI;
begin
  if not CanFocus then Exit;
  Focused := AFocused;
  GUI := GetGUI;
  if GUI = nil then Exit;
  case Focused of
    False: if GUI.FocusedControl = Self then GUI.FocusedControl := nil;
    True: begin
      if (GUI.FocusedControl <> nil) and (GUI.FocusedControl <> Self) then GUI.FocusedControl.SetFocus(False);
      GUI.FocusedControl := Self;
    end;
  end;
end;

procedure TGUIItem.DoMove(const X, Y: Single);
var ParentMode: Integer;
begin
  case MoveMode of
    mmMove: begin
      FX := FX + X; FY := FY + Y;
    end;
    mmResize: begin
      FWidth := FWidth + X; FHeight := FHeight + Y;
    end;
    mmMoveParent, mmResizeParent: if Parent is TGUIItem then begin
      ParentMode := (Parent as TGUIItem).MoveMode;           // Save parent's MoveMode
      if MoveMode = mmMoveParent then
       (Parent as TGUIItem).MoveMode := mmMove else
        (Parent as TGUIItem).MoveMode := mmResize;
      (Parent as TGUIItem).DoMove(X, Y);
      (Parent as TGUIItem).MoveMode := ParentMode;
    end;
  end;
end;

function TGUIItem.GetGUI: TGUI;
var Temp: TItem;
begin
  Temp := Parent;
  while (Temp <> nil) and not (Temp is TGUI) do Temp := Temp.Parent;
  Result := Temp as TGUI;
end;

procedure TGUIItem.Disable;
begin
  Enabled := False;
  Disabled := True;
end;

procedure TGUIItem.Enable;
begin
  Enabled := True;
  Disabled := False;
end;

procedure TGUIItem.SetLocation(ALocation: TVector3s);
begin
  inherited SetLocation(GetVector3s(0, 0, 0));
  SetPosition(FX + ALocation.X, FY +  + ALocation.Y);
end;

{ TGUI }

constructor TGUI.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  Controller := nil;
  Screen := TScreen.Create('Screen', World);
  Screen.ClearRenderPasses;
  Screen.AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, True, False);
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, True, False);
  SystemProcessing := True;
  if Assigned(World.Renderer) then begin
    OldWidth := World.Renderer.RenderPars.ActualWidth;
    OldHeight := World.Renderer.RenderPars.ActualHeight;
  end else begin
    OldWidth := -1; OldHeight := -1;
  end;
  FocusedControl := nil;
  Status := Status or isPauseProcessing
end;

function TGUI.AddLabel(AX, AY: Single; AText: string; AColor: Longword): TLabel;
var NI: TLabel;
begin
  NI := TLabel.Create('Text bar', World);
  NI.SetPosition(AX, AY);
  NI.SetText(AText);
  NI.SetColor(AColor);
  NI.SetMaterial(0, World.Renderer.GetMaterialByName('Text S'));
  AddChild(NI);
  Result := NI;
end;

function TGUI.AddPanel(AX, AY, AWidth, AHeight: Single; ABackColor, ALineColor: Longword): TPanel;
var NI: TPanel;
begin
  NI := TPanel.Create('Panel', World);
  NI.SetPosition(AX, AY);
  NI.SetDimensions(AWidth, AHeight);
  NI.SetColor(ABackColor);
  NI.SetLineColor(ALineColor);
//  NI.SetMaterial(0, World.Renderer.GetMaterialByName('Text S'));
  AddChild(NI);
  Result := NI;
end;

procedure  TGUI.Render(Renderer: TRenderer);
var i: Integer;
begin
  Screen.Clear;
  Screen.SetViewport(0, 0, Renderer.RenderPars.ActualWidth-1, Renderer.RenderPars.ActualHeight-1);
  for i := 0 to TotalChilds-1 do if Childs[i] is TGUIItem then begin
    if Childs[i].Status and isVisible <> 0 then TGuiItem(Childs[i]).Render(Screen);
  end else Childs[i].Render(World.Renderer);
  Screen.Render(Renderer);
end;

procedure TGUI.SetScreen(const AScreen: TScreen);
begin
  Screen := AScreen;
end;

function TGUI.SetChild(Index: Integer; AItem: TItem): TItem;
begin
  Result := inherited SetChild(Index, AItem);
//  Childs[Index].SetRenderPasses(RenderPasses);
end;

function TGUI.ProcessInput(MX, MY: Single): Boolean;
var i: Integer;
begin
  Status := Status or isPauseProcessing;
  HoldInput := False;
  Result := False;
//  SetAbility(Status and isProcessing <> 0);
//  if not Enabled then Exit;
  for i := TotalChilds-1 downto 0 do if Childs[i] is TGUIItem then begin
    if (Childs[i].Status and isVisible > 0) and (Childs[i].Status and isProcessing > 0) then begin
      if (Childs[i] as TGUIItem).ProcessInput(MX, MY) then begin
        MX := MouseInfValue;
        Result := True;
//        Childs[i].ChangeID(TotalChilds-1);
      end;
    end;
  end;
end;

procedure TGUI.HandleCommand(const Command: TCommand);
var i: Integer;
begin
  inherited;
  if Command.CommandID = cmdResized then begin
    if OldWidth = -1 then begin
      OldWidth := Command.Arg1; OldHeight := Command.Arg2;
    end;
    for i := 0 to TotalChilds - 1 do Childs[i].HandleCommand(NewCommandF(cmdGUIRightBottomMoved, [Command.Arg1 - OldWidth, Command.Arg2 - OldHeight]));
    OldWidth := Command.Arg1; OldHeight := Command.Arg2;
  end;
end;

procedure TGUI.Init(AController: TController; ACommands: TCommandQueue);
begin
  Controller := AController;
  Commands := ACommands;
  if Assigned(World) and Assigned(World.Renderer) then
   HandleCommand(NewCommand(cmdResized, [World.Renderer.RenderPars.ActualWidth, World.Renderer.RenderPars.ActualHeight]));
end;

function TGUI.GetControllerState(const State: Cardinal): Integer;
begin
  Result := 0;
  if Controller = nil then Exit;
  case State of
    csShift: Result := Byte(Controller.ShiftState);
    csCtrl: Result := Byte(Controller.CtrlState);
    csAlt: Result := Byte(Controller.AltState);
  end;
end;

procedure TGUI.SetItemTexts(AItemTexts: TSimpleConfig);
var i, j: Integer; Items: TItems;
begin
  if AItemTexts = nil then Exit;
  ItemTexts := AItemTexts;
  for i := 0 to ItemTexts.TotalOptions-1 do begin
    for j := 0 to GetChildsByName(ItemTexts.Names[i], Items)-1 do
     if Items[j] is TTextGUIItem then (Items[j] as TTextGUIItem).Text := ItemTexts.Values[i];
   SetLength(Items, 0);
  end;
end;

{ TGUICursor }

constructor TGUICursor.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  CMinFrame := 0; CMaxFrame := 0;
  HotX := 0; HotY := 0;
  SetWindow(-1, -1, -1, -1);
end;

function TGUICursor.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Minimal frame number', ptInt32, Pointer(CMinFrame));
  NewProperty(Result, 'Maximal frame number', ptInt32, Pointer(CMaxFrame));
  NewProperty(Result, 'Hot X', ptSingle, Pointer(HotX));
  NewProperty(Result, 'Hot Y', ptSingle, Pointer(HotY));
end;

function TGUICursor.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;

  SetFrameRange(Integer(GetPropertyValue(AProperties, 'Minimal frame number')), Integer(GetPropertyValue(AProperties, 'Maximal frame number')));

  if inherited SetProperties(AProperties) < 0 then Exit;

  HotX := Single(GetPropertyValue(AProperties, 'Hot X'));
  HotY := Single(GetPropertyValue(AProperties, 'Hot Y'));

  Result := 0;
end;

function TGUICursor.ProcessInput(MX, MY: Single): Boolean;
begin
  SetPosition(MX - HotX, MY - HotY);
  Result := inherited ProcessInput(MX, MY);
end;

procedure TGUICursor.SetPosition(const AX, AY: Single);
var NX, NY, WX1, WY1, WX2, WY2: Single;
begin
  if WindowX1 = -1 then WX1 := -HotX else WX1 := WindowX1-HotX;
  if WindowY1 = -1 then WY1 := -HotY else WY1 := WindowY1-HotY;
  if WindowX2 = -1 then WX2 := World.Renderer.RenderPars.ActualWidth-1-HotX else WX2 := WindowX2-HotX;
  if WindowY2 = -1 then WY2 := World.Renderer.RenderPars.ActualHeight-1-HotY else WY2 := WindowY2-HotY;
  NX := MinS(MaxS(AX, WX1), WX2) + 0.5;
  NY := MinS(MaxS(AY, WY1), WY2) + 0.5;
  inherited SetPosition(NX, NY);
end;

procedure TGUICursor.SetWindow(const X1, Y1, X2, Y2: Single);
begin
  WindowX1 := X1; WindowY1 := Y1; WindowX2 := X2; WindowY2 := Y2;
  if WindowX1 > WindowX2 then Swap(WindowX1, WindowX2);
  if WindowY1 > WindowY2 then Swap(WindowY1, WindowY2);
  SetPosition(X, Y);
end;

procedure TGUICursor.SetFrame(const Value: Integer);
begin
  inherited SetFrame(MinI(MaxI(Value, CMinFrame), CMaxFrame));
  NormalFrame := Frame;
end;

procedure TGUICursor.Render(const Screen: TScreen);
begin
  Screen.SetUV(UVMap[Frame]);
  Screen.SetColor(CurrentColor);
  Screen.SetRenderPasses(RenderPasses);
  Screen.Bar(X, Y, X + Width, Y + Height);
  inherited;
end;

procedure TGUICursor.SetFrameRange(const AMin, AMax: Integer);
begin
  CMinFrame := MinI(MaxI(AMin, 0), MaxFrame);
  CMaxFrame := MinI(MaxI(AMax, 0), MaxFrame);
  if CMinFrame > CMaxFrame then Swap(CMinFrame, CMaxFrame);
  SetFrame(Frame);
end;

{ TLabel }

procedure TLabel.Render(const Screen: TScreen);
var i: Integer;
begin
  if RText = '' then Exit;
  Screen.SetColor(CurrentColor);
  Screen.SetRenderPasses(RenderPasses);
  Screen.SetFont(Screen.AddFont(World.ResourceManager, FontRes, CharMapRes, TextXScale, TextYScale));
  case WrapMode of
    wmNone: if Colored then Screen.DrawColoredText(X, Y, @RText) else Screen.DrawText(X, Y, @RText);
    wmCut: ;
    wmSimbolWrap, wmWordWrap: for i := 0 to TotalLines-1 do
     if Colored then Screen.DrawColoredText(X, Y+i*LineHeight, @Lines[i]) else Screen.DrawText(X, Y+i*LineHeight, @Lines[i]);
    wmJustify: ;
  end;
  
  inherited;
end;

{ TTextGUIItem }

function TTextGUIItem.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
//  NewProperty(Result, 'Text', ptResource + World.ResourceManager.GetResourceClassIndex('TTextResource') shl 8, Pointer(TextRes));
  NewProperty(Result, 'Text', ptLongString + Length(FText) shl 8, Pointer(FText));
  NewProperty(Result, 'Colored', ptBoolean, Pointer(Colored));
  NewProperty(Result, 'Font', ptGroupBegin, nil);
    NewProperty(Result, 'UVMap', ptResource + World.ResourceManager.GetResourceClassIndex('TFontResource') shl 8, Pointer(FontRes));
    NewProperty(Result, 'Characters mapping', ptResource + World.ResourceManager.GetResourceClassIndex('TCharMapResource') shl 8, Pointer(CharMapRes));
    NewProperty(Result, 'X scale', ptSingle, Pointer(TextXScale));
    NewProperty(Result, 'Y scale', ptSingle, Pointer(TextYScale));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TTextGUIItem.SetProperties(AProperties: TProperties): Integer;
var Prop: TProperty; s: string;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  FontRes := Integer(GetPropertyValue(AProperties, 'UVMap'));
  CharMapRes := Integer(GetPropertyValue(AProperties, 'Characters mapping'));
  TextXScale := Single(GetPropertyValue(AProperties, 'X scale'));
  TextYScale := Single(GetPropertyValue(AProperties, 'Y scale'));
  Colored := Boolean(GetPropertyValue(AProperties, 'Colored'));

  if (FontRes >= 0) and (FontRes < World.ResourceManager.TotalResources) and (World.ResourceManager[FontRes] is TArrayResource) then
   UVMap := TUVMap(World.ResourceManager[FontRes].Data);
  if (CharMapRes >= 0) and (CharMapRes < World.ResourceManager.TotalResources) and (World.ResourceManager[CharMapRes] is TArrayResource) then
   CharMap := TCharMap(World.ResourceManager[CharMapRes].Data);

  if GetProperty(AProperties, 'Text', Prop) then begin
    if Prop.ValueType and $FF = ptLongString then begin
      RetrieveLongString(Prop.Value, Prop.ValueType shr 8, s);
      SetText(s);
    end else if Prop.ValueType and $FF = ptResource then begin
      SetTextRes(Integer(Prop.Value));
    end;
  end;

  Result := 0;
end;

function TTextGUIItem.GetClearedText: string;
begin
  if Colored then begin
    if Markup = nil then Markup := TSimpleMarkup.Create;
    Markup.FormattedText := RText;
    Result := Markup.ClearedText
  end else Result := RText;
end;

procedure TTextGUIItem.SetText(const AText: string);
begin
  FText := AText; RText := FText;
  Width := GetTextWidth;
end;

procedure TTextGUIItem.SetTextRes(const ATextRes: Integer);
begin
  TextRes := ATextRes;
  if (TextRes = -1) or (TextRes >= World.ResourceManager.TotalResources) or not (World.ResourceManager[TextRes] is TTextResource) then
   SetText('') else
    SetText(TTextResource(World.ResourceManager[TextRes]).GetText);
end;

function TTextGUIItem.GetTextWidth: Single;
var i: Integer;
begin
  Result := 0;
  if (FontRes = -1) or (CharMapRes = -1) or (not (World.ResourceManager[CharMapRes] is TCharMapResource)) then Exit;
  for i := 0 to Length(CText)-1 do
//   Result := Result + TUVMap(World.ResourceManager[FontRes].Data)[Ord(FText[i+1])-32].W * TextXScale;
   Result := Result + TUVMap(World.ResourceManager[FontRes].Data)[TCharMap(World.ResourceManager[CharMapRes].Data)[Ord(CText[i+1])]].W * TextXScale;
end;

destructor TTextGUIItem.Free;
begin
  if Markup <> nil then Markup.Free;
end;

{ TWrappingText }

function TWrappingText.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Text wrapping mode', ptInt32, Pointer(WrapMode));
end;

function TWrappingText.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  WrapMode := Integer(GetPropertyValue(AProperties, 'Text wrapping mode'));
  if inherited SetProperties(AProperties) < 0 then Exit;
  Result := 0;
end;

procedure TWrappingText.SetText(const AText: string);

procedure DoSimbolWrap;
var cc: Integer; cw: Single;
begin
  LineHeight := 0;
  if (UVMap = nil) or (CharMap = nil) then Exit;
  TotalLines := 0;
  if CText = '' then Exit;

  cc := 1; cw := 0;

  Inc(TotalLines); SetLength(Lines, TotalLines);
  Lines[TotalLines-1] := CText[cc];

  cw := UVMap[CharMap[Ord(CText[cc])]].W * TextXScale;
  Inc(cc); 

  while cc <= Length(CText) do begin
    if LineHeight < UVMap[CharMap[Ord(CText[cc])]].H * TextYScale then LineHeight := UVMap[CharMap[Ord(CText[cc])]].H * TextYScale;
    cw := cw + UVMap[CharMap[Ord(CText[cc])]].W * TextXScale;
    if (cw > Width) then begin
      Inc(TotalLines); SetLength(Lines, TotalLines);
      Lines[TotalLines-1] := CText[cc];
      cw := 0;
    end else Lines[TotalLines-1] := Lines[TotalLines-1] + CText[cc];
    Inc(cc);
  end;

  Height := LineHeight * TotalLines;
end;

procedure DoWordWrap;         // ToFix: Separators now can violate bounds
const SeparatorChars = ' +-*/\<>'#10#13;          
var cc, CurLineWords: Integer; cw, WordW: Single; CurWord: string;
begin
  LineHeight := 0; TotalLines := 0;
  if (UVMap = nil) or (CharMap = nil) or (CText = '') or (MarkUp = nil) then Exit;

  cc := 1; cw := 0;

  Inc(TotalLines); SetLength(Lines, TotalLines);
  Lines[TotalLines-1] := '';
  CurLineWords := 0;

  CurWord := Markup.GetTagStrAtPos(cc-1) + CText[cc];
  WordW := UVMap[CharMap[Ord(CText[cc])]].W * TextXScale;
  Inc(cc);

  while cc <= Length(CText)+1 do begin
    if (cc <= Length(CText)) and (LineHeight < UVMap[CharMap[Ord(CText[cc])]].H * TextYScale) then
     LineHeight := UVMap[CharMap[Ord(CText[cc])]].H * TextYScale;

    if (cc = Length(CText)+1) or (Pos(CText[cc], SeparatorChars) > 0) then begin   // Separator encountered
      if (cw + WordW > Width) and (CurLineWords > 0) then begin                    // New line

{        if cw + UVMap[CharMap[Ord(CText[cc])]].W * TextXScale > Width then begin  // Where to put separator character?
          CurWord := CurWord + CText[cc];
          WordW := WordW + UVMap[CharMap[Ord(CText[cc])]].W * TextXScale;
        end else Lines[TotalLines-1] := Lines[TotalLines-1] + CText[cc];}

        Inc(TotalLines); SetLength(Lines, TotalLines);
        Lines[TotalLines-1] := Markup.GetResultTagStrAtPos(cc-1-Length(CurWord));
        if CurWord <> '' then CurLineWords := 1 else CurLineWords := 0;
        cw := 0;
      end else begin                                                               // Line continued
        if CurWord <> '' then Inc(CurLineWords);
      end;

      Lines[TotalLines-1] := Lines[TotalLines-1] + CurWord;
      cw := cw + WordW;

      if cc <= Length(CText) then begin                                            // Add the separator character
        Lines[TotalLines-1] := Lines[TotalLines-1] + Markup.GetTagStrAtPos(cc-1) + CText[cc];
        cw := cw + UVMap[CharMap[Ord(CText[cc])]].W * TextXScale;
      end;

      CurWord := ''; WordW := 0;
    end else begin                                                                 // Alphabetical character
      CurWord := CurWord + Markup.GetTagStrAtPos(cc-1) + CText[cc];
      WordW := WordW + UVMap[CharMap[Ord(CText[cc])]].W * TextXScale;
    end;

    Inc(cc);
  end;

  Height := LineHeight * TotalLines;
end;

begin
  FText := AText; RText := FText; 
  case WrapMode of
    wmNone: inherited;
    wmCut: ;
    wmSimbolWrap: DoSimbolWrap;
    wmWordWrap: DoWordWrap;
    wmJustify: ;
  end;
end;

{ TPanel }

procedure TPanel.SetLineColor(const ALineColor: Longword);
begin
  LineColor := ALineColor; CurrentLineColor := LineColor;
end;

procedure TPanel.Render(const Screen: TScreen);
begin
  Screen.SetUV(UVMap[Frame]);
  Screen.SetColor(CurrentColor);
  Screen.SetRenderPasses(RenderPasses);
  Screen.Bar(X, Y, X + Width, Y + Height);

  if CurrentLineColor > 0 then begin
    Screen.SetColor(CurrentLineColor);
    Screen.SetUV(StdUV);
    Screen.MoveTo(X, Y);
    Screen.LineTo(X+Width, Y);
    Screen.LineTo(X+Width, Y+Height);
    Screen.LineTo(X, Y+Height);
    Screen.LineTo(X, Y);
  end;
  inherited;
end;

function TPanel.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Lines color', ptColor32, Pointer(LineColor));
  NewProperty(Result, 'Lines hover color', ptColor32, Pointer(LineHoverColor));
end;

function TPanel.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  SetLineColor(Longword(GetPropertyValue(AProperties, 'Lines color')));
  LineHoverColor := Longword(GetPropertyValue(AProperties, 'Lines hover color'));

  Result := 0;
end;

function TPanel.ProcessInput(MX, MY: Single): Boolean;
begin
  Result := inherited ProcessInput(MX, MY);
  if Hover then begin
    CurrentLineColor := LineHoverColor;
  end else begin
    CurrentLineColor := LineColor;
  end;
end;

{ TSwitchButton }

constructor TSwitchButton.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  CurrentFrame := 0;
end;

procedure TSwitchButton.SetFrameRange(const AMin, AMax: Integer);
begin
  MinSwitchFrame := MinI(MaxI(AMin, 0), MaxFrame);
  MaxSwitchFrame := MinI(MaxI(AMax, 0), MaxFrame);
  if MinSwitchFrame > MaxSwitchFrame then Swap(MinSwitchFrame, MaxSwitchFrame);
  SetFrame(Frame);
end;

procedure TSwitchButton.SetFrame(const Value: Integer);
begin
  inherited SetFrame(MinI(MaxI(Value, MinSwitchFrame), MaxSwitchFrame));
  NormalFrame := Frame; CurrentFrame := Frame;
end;

function TSwitchButton.ProcessInput(MX, MY: Single): Boolean;
var i: Integer;
begin
  Result := inherited ProcessInput(MX, MY);
  if Hover then for i := 0 to GetGUI.Commands.TotalCommands-1 do
   if (GetGUI.Commands.Commands[i].CommandID = cmdLeftMouseClick) then begin
     Inc(CurrentFrame);
     if EOnChange then GetGUI.Commands.Add(cmdGUIChange, [Integer(Self)]);
     Break;
   end;
  if CurrentFrame > MaxSwitchFrame then CurrentFrame := MinSwitchFrame;
//  if (HoverFrame <> NormalFrame) and IsInBounds(MX, MY) then Inc(CurrentFrame);
  Frame := CurrentFrame;
end;

function TSwitchButton.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Minimal frame number', ptInt32, Pointer(MinSwitchFrame));
  NewProperty(Result, 'Maximal frame number', ptInt32, Pointer(MaxSwitchFrame));
end;

function TSwitchButton.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  SetFrameRange(Integer(GetPropertyValue(AProperties, 'Minimal frame number')), Integer(GetPropertyValue(AProperties, 'Maximal frame number')));

  Result := 0;
end;

function TSwitchButton.GetVariantIndex: Integer;
begin
  Result := Frame - MinSwitchFrame;
end;

procedure TSwitchButton.SetVariantIndex(const Value: Integer);
begin
  Frame := MinSwitchFrame + Value;
end;

{ TUVGUIItem }

constructor TUVGUIItem.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  UVMapRes := -1; UVMap := GetStdUVMap;
end;

function TUVGUIItem.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'UV map', ptResource + World.ResourceManager.GetResourceClassIndex('TFontResource') shl 8, Pointer(UVMapRes));
  NewProperty(Result, 'Normal frame', ptInt32, Pointer(NormalFrame));
end;

function TUVGUIItem.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  UVMapRes := Integer(GetPropertyValue(AProperties, 'UV map'));
  NormalFrame := Integer(GetPropertyValue(AProperties, 'Normal frame'));

  if (UVMapRes < 0) or (UVMapRes >= World.ResourceManager.TotalResources) or not (World.ResourceManager[UVMapRes] is TArrayResource) then UVMap := GetStdUVMap else begin
    MaxFrame := (World.ResourceManager[UVMapRes] as TArrayResource).TotalElements - 1;
    UVMap := (World.ResourceManager[UVMapRes] as TArrayResource).Data;
  end;
  Frame := NormalFrame;
//  SetDimensions(UVMap[Frame].W, UVMap[Frame].H);

  Result := 0;
end;

procedure TUVGUIItem.SetFrame(const Value: Integer);
begin
  if (Value = FFrame) or (Value > MaxFrame) then Exit;
  FFrame := Value;
end;

{ TSlider }

constructor TSlider.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  MaxValue := 100; Value := 0;
end;

function TSlider.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Value color', ptColor32, Pointer(ValueColor));
  NewProperty(Result, 'Hover value color', ptColor32, Pointer(HoverValueColor));
  NewProperty(Result, 'Value frame', ptInt32, Pointer(ValueFrame));
  NewProperty(Result, 'Value', ptInt32, Pointer(FValue));
  NewProperty(Result, 'Max value', ptInt32, Pointer(FMaxValue));
  NewProperty(Result, 'Vertical', ptBoolean, Pointer(Vertical));
  NewProperty(Result, 'Free change', ptBoolean, Pointer(FreeChange));
  NewProperty(Result, 'Tracking', ptBoolean, Pointer(Tracking));
end;

function TSlider.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  ValueColor := Longword(GetPropertyValue(AProperties, 'Value color'));
  HoverValueColor := Longword(GetPropertyValue(AProperties, 'Hover value color'));
  ValueFrame := Integer(GetPropertyValue(AProperties, 'Value frame'));
  SetValue(Integer(GetPropertyValue(AProperties, 'Value')));
  SetMaxValue(Integer(GetPropertyValue(AProperties, 'Max value')));
  Vertical := Boolean(GetPropertyValue(AProperties, 'Vertical'));
  FreeChange := Boolean(GetPropertyValue(AProperties, 'Free change'));
  Tracking := Boolean(GetPropertyValue(AProperties, 'Tracking'));

  Result := 0;
end;

function TSlider.ProcessInput(MX, MY: Single): Boolean;
var i: Integer;
begin
  Result := inherited ProcessInput(MX, MY);
  if Hover then begin
    CurrentValueColor := HoverValueColor;
    for i := 0 to GetGUI.Commands.TotalCommands-1 do begin
      if LMousePressed then begin
        if (GetGUI.Commands.Commands[i].CommandID = cmdLeftMouseUp) then
         if SetValueByCoord(MX, MY) then if EOnChange then GetGUI.Commands.Add(cmdGUIChange, [Integer(Self)]);
      end;
    end;
  end else begin
    CurrentValueColor := ValueColor;
  end;
  if LMousePressed then if Tracking then if SetValueByCoord(MX, MY) then
   if EOnChange then GetGUI.Commands.Add(cmdGUIChange, [Integer(Self)]);
end;

procedure TSlider.Render(const Screen: TScreen);
var Temp: Single; UV: TUV;
begin
  Screen.SetRenderPasses(RenderPasses);

  if FMaxValue = 0 then Temp := 0 else Temp := FValue / FMaxValue;

  if Vertical then begin
    UV.U := UVMap[Frame].U; UV.W := UVMap[Frame].W;
    UV.V := UVMap[Frame].V; UV.H := UVMap[Frame].H * (1-Temp);
    Screen.SetUV(UV);
    Screen.SetColor(CurrentColor);
    Screen.Bar(X, Y, X + Width, Y + Height - Height * Temp);

    UV.U := UVMap[ValueFrame].U; UV.W := UVMap[ValueFrame].W;
    UV.V := UVMap[ValueFrame].V + UVMap[ValueFrame].H * (1-Temp); UV.H := UVMap[ValueFrame].H * Temp;
    Screen.SetUV(UV);
    Screen.SetColor(CurrentValueColor);
    Screen.Bar(X, Y + Height - Height * Temp, X + Width, Y + Height);
  end else begin
    UV.U := UVMap[Frame].U; UV.W := UVMap[Frame].W * Temp;
    UV.V := UVMap[Frame].V; UV.H := UVMap[Frame].H;
    Screen.SetUV(UV);
    Screen.SetColor(CurrentColor);
    Screen.Bar(X, Y, X + Width * Temp, Y + Height);

    UV.U := UVMap[ValueFrame].U + UVMap[ValueFrame].W * Temp; UV.W := UVMap[ValueFrame].W * (1 - Temp);
    UV.V := UVMap[ValueFrame].V; UV.H := UVMap[ValueFrame].H;
    Screen.SetUV(UV);
    Screen.SetColor(CurrentValueColor);
    Screen.Bar(X + Width * Temp, Y, X + Width, Y + Height);
  end;

  inherited;
end;

procedure TSlider.SetMaxValue(const Value: Integer);
begin
  FMaxValue := MaxI(0, Value);
end;

procedure TSlider.SetValue(const Value: Integer);
begin
  FValue := MaxI(0, MinI(MaxValue, Value));
end;

function TSlider.SetValueByCoord(const MX, MY: Single): Boolean;
var OldValue: Integer;
begin
  Result := False;
  if not FreeChange then Exit;

  OldValue := Value;

  if Vertical then begin
    if Height = 0 then Value := 0 else Value := Trunc(0.5 + (Y + Height - MY) / Height * MaxValue);
  end else begin
    if Width = 0 then Value := 0 else Value := Trunc(0.5 + (MX - X) / Width * MaxValue);
  end;
  Result := OldValue <> Value;
end;

{ TCheckBox }

constructor TCheckBox.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  Checked := False;
  CurrentFrame := NormalFrame;
end;

procedure TCheckBox.SetChecked(const Value: Boolean);
begin
  FChecked := Value;
  if FChecked then Frame := CheckedFrame else Frame := NormalFrame;
end;

function TCheckBox.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Hover frame', ptInt32, Pointer(HoverFrame));
  NewProperty(Result, 'Checked frame', ptInt32, Pointer(CheckedFrame));
  NewProperty(Result, 'Hover checked frame', ptInt32, Pointer(HoverCheckedFrame));
  NewProperty(Result, 'Checked', ptBoolean, Pointer(Checked));
end;

function TCheckBox.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  HoverFrame := Integer(GetPropertyValue(AProperties, 'Hover frame'));
  CheckedFrame := Integer(GetPropertyValue(AProperties, 'Checked frame'));
  HoverCheckedFrame := Integer(GetPropertyValue(AProperties, 'Hover checked frame'));
  SetChecked(Boolean(GetPropertyValue(AProperties, 'Checked')));

  Result := 0;
end;

function TCheckBox.ProcessInput(MX, MY: Single): Boolean;
var i: Integer;
begin
  Result := inherited ProcessInput(MX, MY);
  if Hover then begin
    for i := 0 to GetGUI.Commands.TotalCommands-1 do begin
      if (GetGUI.Commands.Commands[i].CommandID = cmdLeftMouseClick) then begin
        SetChecked(not Checked);
        if EOnChange then GetGUI.Commands.Add(cmdGUIChange, [Integer(Self)]);
      end; 
    end;
    if FChecked then Frame := HoverCheckedFrame else Frame := HoverFrame;
  end else begin
    if FChecked then Frame := CheckedFrame else Frame := NormalFrame;
  end;
end;

{ TButton }
function TButton.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Hover frame', ptInt32, Pointer(HoverFrame));
  NewProperty(Result, 'Pressed frame', ptInt32, Pointer(PressedFrame));
  NewProperty(Result, 'Repeating delay', ptInt32, Pointer(RepeatDelay));
  NewProperty(Result, 'Repeats per tick', ptSingle, Pointer(RepeatsPerTick));
end;

function TButton.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  HoverFrame := Integer(GetPropertyValue(AProperties, 'Hover frame'));
  PressedFrame := Integer(GetPropertyValue(AProperties, 'Pressed frame'));
  RepeatDelay := Integer(GetPropertyValue(AProperties, 'Repeating delay'));
  RepeatsPerTick := Single(GetPropertyValue(AProperties, 'Repeats per tick'));

  RepeatsCounter := 0;
  Result := 0;
end;

function TButton.ProcessInput(MX, MY: Single): Boolean;
begin
  Result := inherited ProcessInput(MX, MY);
//  if Transparent and (Parent <> nil) and (Parent is TButton) then LMousePressed := TGUIItem(Parent).LMousePressed;
  Pressed := LMousePressed;
  if Pressed then Frame := PressedFrame else if Hover then Frame := HoverFrame else Frame := NormalFrame;
end;

function TButton.Process: Boolean;
var WasPressed: Boolean;
begin
  WasPressed := LMousePressed;
  Result := inherited Process;
  if LMousePressed then begin
    if not WasPressed then begin
      RepeatTimer := RepeatDelay;
      RepeatsCounter := 0;
    end else if RepeatTimer > 0 then Dec(RepeatTimer) else begin
      RepeatsCounter := RepeatsCounter + RepeatsPerTick;
      while RepeatsCounter >= 1 do begin
        if EOnClick then GetGUI.Commands.Add(cmdGUIClick, [Integer(Self)]);
        RepeatsCounter := RepeatsCounter - 1;
      end;
    end;
  end else RepeatTimer := RepeatDelay;
end;

{ TSwitchLabel }

function TSwitchLabel.ProcessInput(MX, MY: Single): Boolean;
var i: Integer;
begin
  Result := inherited ProcessInput(MX, MY);
  if Hover then for i := 0 to GetGUI.Commands.TotalCommands-1 do
   if (GetGUI.Commands.Commands[i].CommandID = cmdLeftMouseClick) then begin
     if VariantIndex < TotalVariants-1 then VariantIndex := VariantIndex + 1 else VariantIndex := 0;
     if EOnChange then GetGUI.Commands.Add(cmdGUIChange, [Integer(Self)]);
     Break;
   end;
end;

procedure TSwitchLabel.SetText(const AText: string);
begin
  SWText := AText;
  TotalVariants := Split(SWText, '\&', Variants, False);
  VariantIndex := 0;
end;

procedure TSwitchLabel.SetVariantIndex(const Value: Integer);
begin
  if (Value >= 0) and (Value < TotalVariants) then FVariantIndex := Value;
  if FVariantIndex >= Length(Variants) then Exit;
  inherited SetText(Variants[FVariantIndex]);
  FText := SWText;
  if WrapMode = wmNone then Width := GetTextWidth;
end;

function TSwitchLabel.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Variant index', ptInt32, Pointer(VariantIndex));
end;

function TSwitchLabel.SetProperties(AProperties: TProperties): Integer;
begin
  if inherited SetProperties(AProperties) < 0 then Exit;
  VariantIndex := Integer(GetPropertyValue(AProperties, 'Variant index'));
  Result := 0;
end;

function TSwitchLabel.IndexOf(const Value: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to TotalVariants-1 do if Variants[i] = Value then begin
    Result := i;
    Exit;
  end;
end;

{ TGUILine }

procedure TGUILine.Render(const Screen: TScreen);
var i, PCnt: Integer; Point: TGUIPoint;
begin
  Screen.SetRenderPasses(RenderPasses);

  PCnt := 0;
  for i := 0 to TotalChilds-1 do if Childs[i] is TGUIPoint then begin
    Point := Childs[i] as TGUIPoint;
    Screen.SetColor(Point.CurrentColor);
    if PCnt = 0 then Screen.MoveTo(Point.X, Point.Y) else Screen.LineTo(Point.X, Point.Y);
    Inc(PCnt);
  end;

  inherited;
end;

end.
