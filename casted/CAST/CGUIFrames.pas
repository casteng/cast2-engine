{$Include GDefines}
{$Include CDefines}
unit CGUIFrames;

interface

uses Basics, CTypes, CAST, C2D, CRender, CRes, CInput, CGUI;

type
  TFrame = class(TUVGUIItem)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Render(const Screen: TScreen); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  private
    TWidth, LWidth, RWidth, BWidth: Single;
    TLFrame, TFrame, TRFrame, LFrame, RFrame, BLFrame, BFrame, BRFrame: Integer;
//    LeftFrame, TopFrame, RightFrame, BottomFrame: Boolean;
  end;
  TFramedButton = class(TUVGUIItem)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function ProcessInput(MX, MY: Single): Boolean; override;
    procedure Render(const Screen: TScreen); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  private
    LWidth, RWidth: Single;
    LFrame, RFrame,
    LeftFrame, RightFrame, HoverFrame, HLFrame, HRFrame, PressedFrame, PLFrame, PRFrame: Integer;
  end;

implementation

{ TFrame }

constructor TFrame.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  TWidth := 8; LWidth := 8; RWidth := 8; BWidth := 8;
end;

function TFrame.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Top border width', ptSingle, Pointer(TWidth));
  NewProperty(Result, 'Left border width', ptSingle, Pointer(LWidth));
  NewProperty(Result, 'Right border width', ptSingle, Pointer(RWidth));
  NewProperty(Result, 'Bottom border width', ptSingle, Pointer(BWidth));
  NewProperty(Result, 'UV mapping', ptGroupBegin, nil);
    NewProperty(Result, 'Top left corner frame', ptInt32, Pointer(TLFrame));
    NewProperty(Result, 'Top side frame', ptInt32, Pointer(TFrame));
    NewProperty(Result, 'Top right corner frame', ptInt32, Pointer(TRFrame));
    NewProperty(Result, 'Left side frame', ptInt32, Pointer(LFrame));
    NewProperty(Result, 'Right side frame', ptInt32, Pointer(RFrame));
    NewProperty(Result, 'Bottom left corner frame', ptInt32, Pointer(BLFrame));
    NewProperty(Result, 'Bottom side frame', ptInt32, Pointer(BFrame));
    NewProperty(Result, 'Bottom right corner frame', ptInt32, Pointer(BRFrame));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TFrame.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  TWidth := Single(GetPropertyValue(AProperties, 'Top border width'));
  LWidth := Single(GetPropertyValue(AProperties, 'Left border width'));
  RWidth := Single(GetPropertyValue(AProperties, 'Right border width'));
  BWidth := Single(GetPropertyValue(AProperties, 'Bottom border width'));

  TLFrame := Integer(GetPropertyValue(AProperties, 'Top left corner frame'));
  TFrame := Integer(GetPropertyValue(AProperties, 'Top side frame'));
  TRFrame := Integer(GetPropertyValue(AProperties, 'Top right corner frame'));
  LFrame := Integer(GetPropertyValue(AProperties, 'Left side frame'));
  RFrame := Integer(GetPropertyValue(AProperties, 'Right side frame'));
  BLFrame := Integer(GetPropertyValue(AProperties, 'Bottom left corner frame'));
  BFrame := Integer(GetPropertyValue(AProperties, 'Bottom side frame'));
  BRFrame := Integer(GetPropertyValue(AProperties, 'Bottom right corner frame'));

  Result := 0;
end;

procedure TFrame.Render(const Screen: TScreen);
var RTWidth, RLWidth, RRWidth, RBWidth: Single;
begin
  RLWidth := MinS(Width, LWidth); RRWidth := MinS(Width, RWidth);
  RTWidth := MinS(Height, TWidth); RBWidth := MinS(Height, BWidth);

  Screen.SetColor(CurrentColor);
  Screen.SetRenderPasses(RenderPasses);

  Screen.SetUV(UVMap[TLFrame]);
  Screen.Bar(X, Y, X + RLWidth, Y + RTWidth);
  Screen.SetUV(UVMap[TFrame]);
  Screen.Bar(X + RLWidth, Y, X + Width - RRWidth, Y + RTWidth);
  Screen.SetUV(UVMap[TRFrame]);
  Screen.Bar(X + Width - RRWidth, Y, X + Width, Y + RTWidth);

  Screen.SetUV(UVMap[LFrame]);
  Screen.Bar(X, Y + RTWidth, X + RLWidth, Y + Height - RBWidth);
  Screen.SetUV(UVMap[RFrame]);
  Screen.Bar(X + Width - RRWidth, Y + RTWidth, X + Width, Y + Height - RBWidth);

  Screen.SetUV(UVMap[BLFrame]);
  Screen.Bar(X, Y + Height - RBWidth, X + RLWidth, Y + Height);
  Screen.SetUV(UVMap[BFrame]);
  Screen.Bar(X + RLWidth, Y + Height - RBWidth, X + Width - RRWidth, Y + Height);
  Screen.SetUV(UVMap[BRFrame]);
  Screen.Bar(X + Width - RRWidth, Y + Height - RBWidth, X + Width, Y + Height);

  inherited;
end;

{ TFramedButton }

constructor TFramedButton.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  LWidth := 8; RWidth := 8;
end;

function TFramedButton.ProcessInput(MX, MY: Single): Boolean;
begin
  Result := inherited ProcessInput(MX, MY);
  if LMousePressed then begin
    Frame := PressedFrame;
    LFrame := PLFrame;
    RFrame := PRFrame;
  end else if Hover then begin
    Frame := HoverFrame;
    LFrame := HLFrame;
    RFrame := HRFrame;
  end else begin
    Frame := NormalFrame;
    LFrame := LeftFrame;
    RFrame := RightFrame;
  end;
end;

function TFramedButton.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Left part width', ptSingle, Pointer(LWidth));
  NewProperty(Result, 'Right part width', ptSingle, Pointer(RWidth));
  NewProperty(Result, 'UV mapping', ptGroupBegin, nil);
    NewProperty(Result, 'Left part frame', ptInt32, Pointer(LeftFrame));
    NewProperty(Result, 'Right part frame', ptInt32, Pointer(RightFrame));
    NewProperty(Result, 'Hover frame', ptInt32, Pointer(HoverFrame));
    NewProperty(Result, 'Hover left part frame', ptInt32, Pointer(HLFrame));
    NewProperty(Result, 'Hover right part frame', ptInt32, Pointer(HRFrame));
    NewProperty(Result, 'Pressed frame', ptInt32, Pointer(PressedFrame));
    NewProperty(Result, 'Pressed left part frame', ptInt32, Pointer(PLFrame));
    NewProperty(Result, 'Pressed right part frame', ptInt32, Pointer(PRFrame));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TFramedButton.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  LWidth := Single(GetPropertyValue(AProperties, 'Left part width'));
  RWidth := Single(GetPropertyValue(AProperties, 'Right part width'));

  LeftFrame := Integer(GetPropertyValue(AProperties, 'Left part frame'));
  RightFrame := Integer(GetPropertyValue(AProperties, 'Right part frame'));
  RFrame := RightFrame;
  LFrame := LeftFrame;

  HoverFrame := Integer(GetPropertyValue(AProperties, 'Hover frame'));
  HLFrame := Integer(GetPropertyValue(AProperties, 'Hover left part frame'));
  HRFrame := Integer(GetPropertyValue(AProperties, 'Hover right part frame'));

  PressedFrame := Integer(GetPropertyValue(AProperties, 'Pressed frame'));
  PLFrame := Integer(GetPropertyValue(AProperties, 'Pressed left part frame'));
  PRFrame := Integer(GetPropertyValue(AProperties, 'Pressed right part frame'));

  Result := 0;
end;

procedure TFramedButton.Render(const Screen: TScreen);
var RLWidth, RRWidth: Single;
begin
  RLWidth := MinS(Width, LWidth); RRWidth := MinS(Width, RWidth);

  Screen.SetColor(CurrentColor);
  Screen.SetRenderPasses(RenderPasses);

  Screen.SetUV(UVMap[LFrame]);
  Screen.Bar(X, Y, X + RLWidth, Y + Height);
  Screen.SetUV(UVMap[Frame]);
  Screen.Bar(X + RLWidth, Y, X + Width - RRWidth, Y + Height);
  Screen.SetUV(UVMap[RFrame]);
  Screen.Bar(X + Width - RRWidth, Y, X + Width, Y + Height);

  inherited;
end;

end.
