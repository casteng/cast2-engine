(*
 @Abstract(CAST Engine DirectX 8 GUI items unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains ready to use GUI items such as button, label etc
*)
{$Include GDefines}
{$Include C2Defines}
unit C2GUIItems;

interface

uses
  Logger, 
  Basics, Base3D, Props, BaseGraph,
  C2Types, CAST2, C22D, Markup, C2Visual, C2GUI;

type
  TGUIPoint = class(TGUIItem)
  end;

  TGUILine = class(TGUIItem)
    procedure Render; override;
  end;

{  TGUICursor = class(TUVGUIItem)
    constructor Create; override;
    procedure Render; override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure GetProperties(var Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;
    procedure SetPosition(const AX, AY: Single); override;
    procedure SetFrame(const Value: Integer); override;
    procedure SetFrameRange(const AMin, AMax: Integer); virtual;
    procedure SetWindow(const X1, Y1, X2, Y2: Single); virtual;
  protected
    CMinFrame, CMaxFrame: Integer;
    HotX, HotY: Single;
    WindowX1, WindowY1, WindowX2, WindowY2: Single;
  end;}

  TLabel = class(TWrappingText)
    procedure Render; override;
  end;

(*  TSwitchLabel = class(TLabel)
// Splits text to variants by "\&". "\\" threats as "\"
    Variants: TStringArray; TotalVariants: Integer;
    procedure SetText(const AText: string); override;
    procedure SetVariantIndex(const Value: Integer); virtual;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure GetProperties(var Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;
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
    procedure Render; override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure SetLineColor(const ALineColor: Longword);
    procedure GetProperties(var Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;
  protected
    CurrentLineColor: Longword;
  end;

  TSwitchButton = class(TPanel)
    constructor Create; override;
    procedure SetFrame(const Value: Integer); override;
    procedure SetFrameRange(const AMin, AMax: Integer); virtual;
    procedure GetProperties(var Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;
    function ProcessInput(MX, MY: Single): Boolean; override;
  protected
    MinSwitchFrame, MaxSwitchFrame: Integer;
    function GetVariantIndex: Integer;
    procedure SetVariantIndex(const Value: Integer);
  public
    property VariantIndex: Integer read GetVariantIndex write SetVariantIndex;
  end;

  TCheckBox = class(TPanel)
    constructor Create; override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure GetProperties(var Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;
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
    procedure GetProperties(var Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;
    procedure Process; override;
  protected
    HoverFrame, PressedFrame: Integer;
    RepeatDelay, RepeatTimer: Integer;
    RepeatsPerTick, RepeatsCounter: Single;
  end;

  TSlider = class(TUVGUIItem)
    ValueColor, HoverValueColor: Longword;
    ValueFrame: Integer;
    Vertical, FreeChange, Tracking: Boolean;
    constructor Create; override;
    procedure Render; override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure GetProperties(var Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;
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
  end;*)

implementation

uses C2Tess2D;

{ TGUILine }

procedure TGUILine.Render;
var i, PCnt: Integer; Point: TGUIPoint;
begin
  Screen.SetViewport(Screen.ConstructViewport(X, Y, X + Width - 1, Y + Height - 1));

  SetTechnique(CurTechnique);

  PCnt := 0;
  for i := 0 to TotalChilds-1 do if Childs[i] is TGUIPoint then begin
    Point := Childs[i] as TGUIPoint;
    Screen.SetColor(Point.CurrentColor);
    if PCnt = 0 then Screen.MoveTo(Point.X, Point.Y) else Screen.LineTo(Point.X, Point.Y);
    Inc(PCnt);
  end;

  inherited;

  Screen.RestoreViewport;
end;

{ TGUICursor }

{constructor TGUICursor.Create;
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
end;}

{ TLabel }

procedure TLabel.Render;

const Dg = 256;
var i, j: Integer;
begin
  if CurTechnique = nil then Exit;

  SetTechnique(CurTechnique);

  if (Font = nil) or (RText = '') then Exit;

//  Screen.DrawLine(Random(200), Random(200), Random(200), Random(200));
//  Screen.Bar(Random(200), Random(200), Random(200), Random(200));
{  for i := 0 to 15 do for j := 0 to 15 do begin
    Screen.SetColor((i * 16 + (j * 16) shl 8) or $FF000000);
    Screen.Bar(X + i*16, Y + j*16, X + i*16+14, Y + j*16+14);
    Screen.SetColor(((15-i) * 16 + (j * 16) shl 16) or $FF000000);
    Screen.Line(X + i*16, Y + j*16, X + i*16+14, Y + j*16+14);
  end;

  Screen.MoveTo(X + 100, Y);
  for i := 0 to TicksProcessed and (Dg-1) do Screen.LineTo(X + Cos(i/Dg*2*pi)*100, Y + Sin(i/Dg*2*pi)*100);
 }
//  Screen.Bar(X, Y, X + 200, Y + Height);

  Screen.SetColor(CurrentColor);
  Screen.SetFont(Font.Font);
  case WrapMode of
    wmNone: if Colored then Screen.PutFormattedText(X, Y, RText) else Screen.PutText(X, Y, RText);
    wmCut: ;
    wmSimbolWrap, wmWordWrap: for i := 0 to TotalLines-1 do
     if Colored then Screen.PutFormattedText(X, Y+i*LineHeight, Lines[i]) else Screen.PutText(X, Y+i*LineHeight, Lines[i]);
    wmJustify: ;
  end;

  inherited;
end;
end.
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

end.
