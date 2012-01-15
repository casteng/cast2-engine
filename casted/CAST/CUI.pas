{$Include GDefines}
{$Include CDefines}
unit CUI;

interface

uses Basics, Base3D, CTypes, CRes, CRender, CTess, CFX, CAST;

const
  oHorizontal = 0; oVertical = 1;
  amLeft = 0; amCenter = 1; amRight = 2;

type
  TCFont = class
//    FontTexture: Pointer;
    FontResource{, FontTextureWidth, FontTextureHeight}: Longint;
    Data: Pointer;
    constructor Create(const AWorld: TWorld; const AFontResource: Integer);
  end;

  TUI = class;

  TUIMesh = class(TFXMesh)
    Font: TCFont;
    Orientation, XAlign, YAlign: Cardinal;
    World: TWorld;
    UI: TUI;
    BackColor: Cardinal;
    XScale, YScale: Single;
  end;
  TUIItem = class(TItem)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
  private
    procedure SetXAlign(const Value: Cardinal);
    procedure SetYAlign(const Value: Cardinal);
    function GetBackColor: Cardinal;
    function GetColor: Cardinal;
    procedure SetBackColor(const Value: Cardinal);
    procedure SetColor(const Value: Cardinal);
    function GetXAlign: Cardinal;
    function GetYAlign: Cardinal;
    procedure SetArea(const Value: TArea);
    function GetArea: TArea;
    function GetBottom: Integer;
    function GetLeft: Integer;
    function GetRight: Integer;
    function GetTop: Integer;
  public
    property Area: TArea read GetArea write SetArea;
    property XAlign: Cardinal read GetXAlign write SetXAlign;
    property YAlign: Cardinal read GetYAlign write SetYAlign;
    property Left: Integer read GetLeft;
    property Top: Integer read GetTop;
    property Right: Integer read GetRight;
    property Bottom: Integer read GetBottom;
    property BackColor: Cardinal read GetBackColor write SetBackColor;
    property Color: Cardinal read GetColor write SetColor;
  end;

  TTextMesh = class(TUIMesh)
    TextAlign: Cardinal;
    constructor Create(const AName: TShortName; const AWorld: TWorld; AFont: TCFont; const TextX, TextY: Integer; const AText: string; const AColor1, AColor2: Cardinal); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    procedure SetText(const NewText: string); virtual;
  protected
    FText: string;
  public
    property Text: string read FText write SetText;
  end;
  TText = class(TUIItem)
    procedure SetMesh; override;
    procedure SetText(const NewText: string); virtual;
  private
    function GetTextAlign: Cardinal;
    procedure SetTextAlign(const Value: Cardinal);
    function GetTextX: Integer;
    function GetTextY: Integer;
    procedure SetTextX(const Value: Integer);
    procedure SetTextY(const Value: Integer);
  public
    property TextAlign: Cardinal read GetTextAlign write SetTextAlign;
    property TextX: Integer read GetTextX write SetTextX;
    property TextY: Integer read GetTextY write SetTextY;
  end;

  TBoxMesh = class(TUIMesh)
    constructor Create(const AName: TShortName; const AWorld: TWorld; const AOrientation, ALeft, ATop, AWidth, AHeight, AMaxValue: Integer; const AColor1, AColor2: Cardinal); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    procedure SetValue(const NewValue: Integer); virtual;
    procedure SetMaxValue(const NewMaxValue: Integer); virtual;
  protected
    FValue, FMaxValue: Integer;
  end;
  TBox = class(TUIItem)
  protected
    function GetMaxValue: Integer;
    function GetValue: Integer;
    procedure SetValue(const NewValue: Integer); virtual;
    procedure SetMaxValue(const NewValue: Integer); virtual;
  public
    property Value: Integer read GetValue write SetValue;
    property MaxValue: Integer read GetMaxValue write SetMaxValue;
  end;

  TIconMesh = class(TUIMesh)
    MaxFrame: Integer;
    UVMap: TUVMap;
    constructor Create(const AName: TShortName; const AWorld: TWorld; const ALeft, ATop, AWidth, AHeight: Integer; const AColor: Cardinal); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    procedure SetFrame(const Value: Integer); virtual;
  protected
    FFrame: Integer;
  public
    property Frame: Integer read FFrame write SetFrame;
  end;
  TIcon = class(TUIItem)
    UVMapRes: Integer;
    procedure SetUVMRes(const Value: Integer); virtual;
    function SetProperties(Properties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  private
    function GetFrame: Cardinal;
    procedure SetFrame(const Value: Cardinal);
  public
    property Frame: Cardinal read GetFrame write SetFrame;
  end;

  TUI = class
    World: TWorld;
    Font: TCFont;
    constructor Create(const AWorld: TWorld; FontRes: Integer);
    function AddText(const TextX, TextY: Integer; Str: string; const AColor1, AColor2: Cardinal; const AlignMode: Cardinal = amLeft; const TextAlign: Cardinal = $FFFFFFFF): TText;
    function AddBox(const AOrientation, ALeft, ATop, AWidth, AHeight, AMaxValue: Integer; const AColor1, AColor2: Cardinal; const AMaterialName: TShortName): TBox;
    function AddIcon(const ALeft, ATop, AWidth, AHeight: Integer; const AColor: Cardinal; const AMaterialName: TShortName; const XAlign: Cardinal = amLeft; YALign: Cardinal = amLeft): TIcon;
  end;

  TMenuItem = record
    Name, Value: TText;
    Data: Pointer;
  end;

  TMenu = class
    UI: TUI;
    Area: TArea;
    Color1, Color2, Back: Cardinal;
    Width, ItemHeight: Integer;
    TextMaterial: TShortName;
    TotalItems: Integer;
    Items: array of TMenuItem;
    constructor Create(AUI: TUI; AColor1, AColor2, ABack: Cardinal; AWidth, AItemHeight: Integer; const ATextMaterial: TShortName);
    procedure HandleResize;
    procedure Clear;
    procedure AddItem(const AName, AValue: TShortName; const AData: Pointer = nil);
    procedure MoveCursor(const Amount: Integer);
    procedure Show;
    procedure Hide;
    destructor Free;
  private
    MenuBar: TIcon;
    FPosition: Integer;
    FVisible: Boolean;
    procedure Select(const NewPosition: Integer);
    procedure SetVisibility(const Value: Boolean);
  public
    property Visible: Boolean read FVisible write SetVisibility;
    property Position: Integer read FPosition write Select;
  end;

  TMessageItem = record
    MsgText: TText;
    Y: Single;
  end;

  TPanel = class(TItem)
    UI: TUI;
    Area: TArea;
    Back: Cardinal;
    Width, ItemHeight, MaxVisibleItems: Integer;
    TextMaterial: TShortName;
    procedure Show; virtual;
    procedure Hide; virtual;
  private
    FVisible: Boolean;
    Panel: TIcon;
  end;

  TMsgPanel = class(TPanel)
    TotalItems: Integer;
    Items: array of TMessageItem;
    FadingSpeed: Integer;
    ScrollSpeed: Single;
    constructor Create(AUI: TUI; ABack: Cardinal; AWidth, AMaxVisibleItems, AItemHeight: Integer; const ATextMaterial: TShortName; AScrollSpeed: Single = 1; const AFadingSpeed: Integer = 4);
    function Process: Boolean; override;
    procedure HandleResize;
    procedure Scroll(const Amount: Single);
    procedure Clear;
    procedure AddItem(const AMsgText: TShortMessage; const AColor: Longword = $FFFFFFFF);
    procedure DeleteItem(const Index: Integer);
    procedure Show; override;
    procedure Hide; override;
    destructor Free;
  private
    Fading: Boolean;
    Space: Single;
    Alpha: Cardinal;
    procedure SetVisibility(const Value: Boolean);
  public
    property Visible: Boolean read FVisible write SetVisibility;
  end;

  TInfoPanel = class(TPanel)
    Location3D: TVector3s;
    TotalItems: Integer;
    Items: array of TMessageItem;
    constructor Create(AUI: TUI; ABack: Cardinal; AWidth, AMaxVisibleItems, AItemHeight: Integer; const ATextMaterial: TShortName);
    procedure SetLocation(Loc: TVector3s);
    function Process: Boolean; override;
    procedure AddItem(const AMsgText: TShortMessage; const AColor: Longword = $FFFFFFFF);
    procedure DeleteItem(const Index: Integer);
    procedure Show; override;
    procedure Hide; override;
    destructor Free;
  end;

implementation

{ TUI }

constructor TUI.Create(const AWorld: TWorld; FontRes: Integer);
//var VertexFormat, VertexSize: LongWord;
begin
  World := AWorld;
  if FontRes = -1 then Font := nil else Font := TCFont.Create(World, FontRes);
end;

function TUI.AddText(const TextX, TextY: Integer; Str: string; const AColor1, AColor2: Cardinal; const AlignMode: Cardinal = amLeft; const TextAlign: Cardinal = $FFFFFFFF): TText;
begin
  Result := nil;
  if Font = nil then Exit;
  Result := TText.Create('Text', World);
  Result.AddLOD(TTextMesh.Create('', World, Font, TextX, TextY, Str, AColor1, AColor2));
  Result.XAlign := AlignMode;
  if TextAlign = $FFFFFFFF then Result.TextAlign := AlignMode else Result.TextAlign := TextAlign;
  Result.Location.Z := 0.3;
end;

function TUI.AddBox(const AOrientation, ALeft, ATop, AWidth, AHeight, AMaxValue: Integer; const AColor1, AColor2: Cardinal; const AMaterialName: TShortName): TBox;
begin
  Result := TBox.Create('Box', World);
  Result.AddLOD(TBoxMesh.Create('', World, AOrientation, ALeft, ATop, AWidth, AHeight, AMaxValue, AColor1, AColor2));
  Result.SetMaterial(0, World.Renderer.GetMaterialByName(AMaterialName));
  Result.Location.Z := 0.8;
end;

function TUI.AddIcon(const ALeft, ATop, AWidth, AHeight: Integer; const AColor: Cardinal; const AMaterialName: TShortName; const XAlign: Cardinal = amLeft; YALign: Cardinal = amLeft): TIcon;
begin
  Result := TIcon.Create('Icon', World);
  Result.AddLOD(TIconMesh.Create('', World, ALeft, ATop, AWidth, AHeight, AColor));
  Result.SetMaterial(0, World.Renderer.GetMaterialByName(AMaterialName));
  Result.XAlign := XAlign;
  Result.YAlign := YAlign;
  Result.Location.Z := 0.5;
end;

{ TUIItem}

constructor TUIItem.Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
begin
  inherited;
  XAlign := 0; YALign := 0;
  Sorting := skZAccending;
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfAlways, tfAlways, 0, False, False);
  Order := 500;
end;

function TUIItem.GetArea: TArea;
begin
  Result := TUIMesh(CurrentLOD).FArea;
end;

function TUIItem.GetBackColor: Cardinal;
begin
  if CurrentLOD <> nil then Result := TUIMesh(CurrentLOD).BackColor;
end;

function TUIItem.GetColor: Cardinal;
begin
  if CurrentLOD <> nil then Result := TUIMesh(CurrentLOD).Color;
end;

function TUIItem.GetLeft: Integer;
begin
  case XAlign of
    amLeft: Result := Area.Left;
    amCenter: Result := Area.Left + (World.Renderer.RenderPars.ActualWidth - Area.Width) div 2;
    amRight: Result := World.Renderer.RenderPars.ActualWidth - Area.Width - Area.Left;
  end;
end;

function TUIItem.GetRight: Integer;
begin
  case XAlign of
    amLeft: Result := Area.Left + Area.Width;
    amCenter: Result := Area.Left + (World.Renderer.RenderPars.ActualWidth + Area.Width) div 2;
    amRight: Result := World.Renderer.RenderPars.ActualWidth - Area.Width - Area.Left;
  end;
end;

function TUIItem.GetTop: Integer;
begin
  case YAlign of
    amLeft: Result := Area.Top;
    amCenter: Result := Area.Top + (World.Renderer.RenderPars.ActualHeight - Area.Height) div 2;
    amRight: Result := World.Renderer.RenderPars.ActualHeight - Area.Height - Area.Top;
  end;
end;

function TUIItem.GetBottom: Integer;
begin
  case YAlign of
    amLeft: Result := Area.Top + Area.Height;
    amCenter: Result := Area.Top + (World.Renderer.RenderPars.ActualHeight + Area.Height) div 2;
    amRight: Result := World.Renderer.RenderPars.ActualHeight - Area.Height - Area.Top;
  end;
end;

function TUIItem.GetXAlign: Cardinal;
begin
  if CurrentLOD <> nil then Result := TUIMesh(CurrentLOD).XAlign;
end;

function TUIItem.GetYAlign: Cardinal;
begin
  if CurrentLOD <> nil then Result := TUIMesh(CurrentLOD).YAlign;
end;

procedure TUIItem.SetArea(const Value: TArea);
begin
  TUIMesh(CurrentLOD).FArea := Value;
end;

procedure TUIItem.SetBackColor(const Value: Cardinal);
begin
  if CurrentLOD <> nil then begin
    TUIMesh(CurrentLOD).BackColor := Value;
    TUIMesh(CurrentLOD).VStatus := tsChanged;
  end;
end;

procedure TUIItem.SetColor(const Value: Cardinal);
begin
  if CurrentLOD <> nil then begin
    TUIMesh(CurrentLOD).Color := Value;
    TUIMesh(CurrentLOD).VStatus := tsChanged;
  end;
end;

procedure TUIItem.SetXAlign(const Value: Cardinal);
begin
  if CurrentLOD <> nil then begin
    TTextMesh(CurrentLOD).XAlign := Value;
    CurrentLOD.VStatus := tsChanged
  end;
end;

procedure TUIItem.SetYAlign(const Value: Cardinal);
begin
  if CurrentLOD <> nil then begin
    TTextMesh(CurrentLOD).YAlign := Value;
    CurrentLOD.VStatus := tsChanged
  end;
end;

{ TTextTesselator }

constructor TTextMesh.Create(const AName: TShortName; const AWorld: TWorld; AFont: TCFont; const TextX, TextY: Integer; const AText: string; const AColor1, AColor2: Cardinal);
begin
  inherited Create(AName, GetArea(TextX, TextY, TextX, TextY), 0.1, AColor1);
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];;
  VertexFormat := GetVertexFormat(True, False, True, True, 1);
//  VertexFormat := GetVertexFormat(True, False, False, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalVertices := Length(AText)*4;

  World := AWorld;
  Font := AFont;

  XScale := 128;//Font.FontTextureWidth;   //ToFix: Get real texture dimensions
  YScale := 128;//Font.FontTextureHeight;

  BackColor := AColor2;
  Color := Color and $FFFFFF + BackColor and $FF000000;

  SetText(AText);
end;

procedure TTextMesh.SetText(const NewText: string);
begin
  if NewText = FText then Exit;
  FText := NewText;
  TotalVertices := Length(NewText)*4;
  TotalPrimitives := (2*Length(FText)) + (2*Length(FText)-2);
  if (TotalVertices = LastTotalVertices) and (VStatus = tsTesselated) then VStatus := tsChanged else VStatus := tsSizeChanged;
end;

function TTextMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TLocalVB = TTCDSTBuffer;
var i: Integer; CurX, CurY, StrHLen: Single; Coord: TUV;
begin
  StrHLen := 0;
  with FArea do for i := 0 to Length(FText)-1 do
   StrHLen := StrHLen + TUVMap(World.ResourceManager[Font.FontResource].Data)[Ord(FText[i+1])-32].W*XScale;
  case XAlign of
    amLeft: CurX := FArea.Left - 0.5;
    amCenter: CurX := FArea.Left - 0.5 + Trunc(RenderPars.ActualWidth*0.5);
    amRight: CurX := RenderPars.ActualWidth - FArea.Left - 0.5;
  end;

  case TextAlign of
    amCenter: CurX := Curx - Trunc(StrHLen*0.5);
    amRight: CurX := Curx - StrHLen;
  end;

  with FArea do for i := 0 to Length(FText)-1 do begin
    Coord := TUVMap(World.ResourceManager[Font.FontResource].Data)[Ord(FText[i+1])-32];
    with TLocalVB(VBPTR^)[i*4] do begin
      X := CurX;
      Y := Top - 0.5;
      Z := Depth; RHW := 1/Z;
      DColor := Color; SColor := BackColor;
      U := Coord.U; V := Coord.V;
    end;
    with TLocalVB(VBPTR^)[i*4+1] do begin
      X := CurX + Coord.W*XScale;
      Y := Top - 0.5;
      Z := Depth; RHW := 1/Z;
      DColor := Color; SColor := BackColor;
      U := Coord.U + Coord.W; V := Coord.V;
    end;
    with TLocalVB(VBPTR^)[i*4+3] do begin
      X := CurX + Coord.W*XScale;
      Y := Top + Coord.H*YScale - 0.5;
      Z := Depth; RHW := 1/Z;
      DColor := Color; SColor := BackColor;
      U := Coord.U + Coord.W; V := Coord.V + Coord.H;
    end;
    with TLocalVB(VBPTR^)[i*4+2] do begin
      X := CurX;
      Y := Top + Coord.H*YScale -0.5;
      Z := Depth; RHW := 1/Z;
      DColor := Color; SColor := BackColor;
      U := Coord.U; V := Coord.V + Coord.H;
    end;
    CurX := CurX + Coord.W*XScale;
  end;
  VStatus := tsTesselated;
  LastTotalIndices := 0;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ TBarTesselator }

constructor TBoxMesh.Create(const AName: TShortName; const AWorld: TWorld; const AOrientation, ALeft, ATop, AWidth, AHeight, AMaxValue: Integer; const AColor1, AColor2: Cardinal);
begin
  World := AWorld;
  TotalIndices := 0; LastTotalIndices := 0; LastTotalVertices := 0; TotalStrips := 1; StripOffset := 0;
  IBOffset := 0; VBOffset := 0;

  PrimitiveType := CPTypes[ptTRIANGLESTRIP];;
  VertexFormat := GetVertexFormat(True, False, True, True, 1);
  VertexSize := GetVertexSize(VertexFormat);

  TotalVertices := 8; TotalPrimitives := 6;

  Orientation := AOrientation;
  FArea := GetArea(ALeft, ATop, AWidth, AHeight);
  FMaxValue := AMaxValue;
  BackColor := AColor1; Color := AColor2;

  Depth := 0.1;

  SetValue(0);
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
end;

procedure TBoxMesh.SetMaxValue(const NewMaxValue: Integer);
begin
  if NewMaxValue = FMaxValue then Exit;
  FMaxValue := NewMaxValue;
  if VStatus <> tsSizeChanged then VStatus := tsChanged;
end;

procedure TBoxMesh.SetValue(const NewValue: Integer);
begin
  if NewValue = FValue then Exit;
  FValue := MaxI(0, MinI(FMaxValue, NewValue));
  if VStatus <> tsSizeChanged then VStatus := tsChanged;
end;

function TBoxMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var Temp: Single;
begin
  if FMaxValue = 0 then Temp := 0 else Temp := FValue / FMaxValue;
  with FArea do if Orientation = oHorizontal then begin
    with TTCDSTBuffer(VBPTR^)[1] do begin
      X := Left + Temp * Width;
//      Trunc(0.5 + (Value / MaxValue) * Width);                  //  0  1  4  5
      Y := Top;                                                             //  2  3  6  7
      Z := FDepth; RHW := 1/Z; DColor := Color;                            //
      U := FValue / FMaxValue; V := 0;
    end;                                                                    
    with TTCDSTBuffer(VBPTR^)[3] do begin                                   
      X := TTCDSTBuffer(VBPTR^)[1].X;                                       
      Y := Top + Height;                                                    
      Z := FDepth; RHW := 1/Z; DColor := Color;
      U := Temp; V := 1;
    end;
    with TTCDSTBuffer(VBPTR^)[4] do begin
      X := TTCDSTBuffer(VBPTR^)[1].X;
      Y := Top;
      Z := FDepth; RHW := 1/Z; DColor := BackColor;
      U := Temp; V := 0;
    end;
    with TTCDSTBuffer(VBPTR^)[6] do begin
      X := TTCDSTBuffer(VBPTR^)[1].X;
      Y := Top + Height;
      Z := FDepth; RHW := 1/Z; DColor := BackColor;
      U := Temp; V := 1;
    end;
    with TTCDSTBuffer(VBPTR^)[0] do begin
      X := Left;
      Y := Top;
      Z := FDepth; RHW := 1/Z; DColor := Color;
      U := 0; V := 0;
    end;
    with TTCDSTBuffer(VBPTR^)[2] do begin
      X := Left;
      Y := Top + Height;
      Z := FDepth; RHW := 1/Z; DColor := Color;
      U := 0; V := 1;
    end;
    with TTCDSTBuffer(VBPTR^)[5] do begin
      X := Left + Width;
      Y := Top;
      Z := FDepth; RHW := 1/Z; DColor := BackColor;
      U := 1; V := 0;
    end;
    with TTCDSTBuffer(VBPTR^)[7] do begin
      X := Left + Width;
      Y := Top + Height;
      Z := FDepth; RHW := 1/Z; DColor := BackColor;
      U := 1; V := 1;
    end;
  end else if Orientation = oVertical then begin
    with TTCDSTBuffer(VBPTR^)[0] do begin                                     //  5  7
      X := Left;                                                              //  4  6
      Y := Top + Height;                                                      //  1  3
      Z := FDepth; RHW := 1/Z; DColor := Color;                               //  0  2
      U := 0; V := 1;
    end;
    with TTCDSTBuffer(VBPTR^)[2] do begin
      X := Left + Width;
      Y := Top + Height;
      Z := FDepth; RHW := 1/Z; DColor := Color;
      U := 1; V := 1;
    end;
    with TTCDSTBuffer(VBPTR^)[5] do begin
      X := Left;
      Y := Top;
      Z := FDepth; RHW := 1/Z; DColor := BackColor;
      U := 0; V := 0;
    end;
    with TTCDSTBuffer(VBPTR^)[7] do begin
      X := Left + Width;
      Y := Top;
      Z := FDepth; RHW := 1/Z; DColor := BackColor;
      U := 1; V := 0;
    end;
    with TTCDSTBuffer(VBPTR^)[1] do begin
      X := Left;
      Y := Top + Height - Height * Temp;
//      Trunc(0.5 + (Value / MaxValue) * Height);
      Z := FDepth; RHW := 1/Z; DColor := Color;
      U := 0; V := 1 - FValue / FMaxValue;
    end;                                                                     //  0  1  4  5
    with TTCDSTBuffer(VBPTR^)[3] do begin                                      //  2  3  6  7
      X := Left + Width;                                                     //
      Y := TTCDSTBuffer(VBPTR^)[1].Y;                                          //  5  7
      Z := FDepth; RHW := 1/Z; DColor := Color;                             //  4  6
      U := 1; V := 1 - Temp;
    end;                                                                     //  1  3
    with TTCDSTBuffer(VBPTR^)[4] do begin                                      //  0  2
      X := Left;
      Y := TTCDSTBuffer(VBPTR^)[1].Y;
      Z := FDepth; RHW := 1/Z; DColor := BackColor;
      U := 0; V := 1 - Temp;
    end;
    with TTCDSTBuffer(VBPTR^)[6] do begin
      X := Left + Width;
      Y := TTCDSTBuffer(VBPTR^)[1].Y;
      Z := FDepth; RHW := 1/Z; DColor := BackColor;
      U := 1; V := 1 - Temp;
    end;
  end;
  LastTotalIndices := 0;
  LastTotalVertices := TotalVertices;
  VStatus := tsSizeChanged;
  Result := LastTotalVertices;
end;

{ TCFont }

constructor TCFont.Create(const AWorld: TWorld; const AFontResource: Integer);
begin
  FontResource := AFontResource;
  Data := AWorld.ResourceManager[AFontResource].Data;
//  TexResource := (AResources[FontResource] as TFontResource).FontTexture;

//  if TexResource < 0 then LogError('Unable to create font: Texture not found');

{  if TexResource < 0 then Exit;
  FontTextureWidth := (AResources[TexResource] as TImageResource).Width;
  FontTextureHeight := (AResources[TexResource] as TImageResource).Height;}
//  FontTexture := ARenderer.AddTexture(TexResource);
end;

{ TBox }

procedure TBox.SetValue(const NewValue: Integer);
begin
  TBoxMesh(CurrentLOD).SetValue(NewValue);
end;

procedure TBox.SetMaxValue(const NewValue: Integer);
begin
  TBoxMesh(CurrentLOD).SetMaxValue(NewValue);
end;

function TBox.GetMaxValue: Integer;
begin
  Result := TBoxMesh(CurrentLOD).FMaxValue;
end;

function TBox.GetValue: Integer;
begin
  Result := TBoxMesh(CurrentLOD).FValue;
end;

{ TText }

function TText.GetTextAlign: Cardinal;
begin
  if CurrentLOD <> nil then Result := TTextMesh(CurrentLOD).TextAlign;
end;

procedure TText.SetTextAlign(const Value: Cardinal);
begin
  if CurrentLOD <> nil then begin
    TTextMesh(CurrentLOD).TextAlign := Value;
    TTextMesh(CurrentLOD).VStatus := tsChanged;
  end;
end;

procedure TText.SetMesh;
begin
  AddLOD(TTextMesh.Create('', World, nil, 0, 0, '', $FFFFFFFF, 0));
end;

procedure TText.SetText(const NewText: string);
begin
  if CurrentLOD <> nil then TTextMesh(CurrentLOD).Text := NewText;
end;

function TText.GetTextX: Integer;
begin
  Result := Area.Left;
end;

function TText.GetTextY: Integer;
begin
  Result := Area.Top;
end;

procedure TText.SetTextX(const Value: Integer);
begin
  TUIMesh(CurrentLOD).FArea.Left := Value;
  CurrentLOD.VStatus := tsChanged;
end;

procedure TText.SetTextY(const Value: Integer);
begin
  TUIMesh(CurrentLOD).FArea.Top := Value;
  CurrentLOD.VStatus := tsChanged;
end;

{ TIcon }

function TIcon.GetFrame: Cardinal;
begin
  Result := TIconMesh(CurrentLOD).Frame;
end;

procedure TIcon.SetFrame(const Value: Cardinal);
begin
  TIconMesh(CurrentLOD).SetFrame(Value);
end;

function TIcon.GetProperties: TProperties;
var OldLen: Integer;
begin
  Result := inherited GetProperties;
  OldLen := Length(Result);
  SetLength(Result, OldLen+2);

  Result[OldLen + 0].Name := 'Frame';
  Result[OldLen + 0].ValueType := ptNat32;
  Result[OldLen + 0].Value := Pointer(TBillBoardMesh(CurrentLOD).Frame);

  Result[OldLen + 1].Name := 'UV Mapping';
  Result[OldLen + 1].ValueType := ptResource + World.ResourceManager.GetResourceClassIndex('TFontResource') shl 8;
  Result[OldLen + 1].Value := Pointer(UVMapRes);
end;

function TIcon.SetProperties(Properties: TProperties): Integer;
var OldLen: Integer;
begin
  Result := -1;
  OldLen := inherited SetProperties(Properties);
  if OldLen < 0 then Exit;
  if Length(Properties) - OldLen < 2 then Exit;

  if Properties[OldLen + 0].ValueType <> ptNat32 then Exit;
  if Properties[OldLen + 1].ValueType <> ptResource + World.ResourceManager.GetResourceClassIndex('TFontResource') shl 8 then Exit;

  TIconMesh(CurrentLOD).Frame := Longword(Properties[OldLen + 0].Value);
  SetUVMRes(Integer(Properties[OldLen + 1].Value));

  TIconMesh(CurrentLOD).VStatus := tsChanged;

  Result := OldLen + 2;
end;

procedure TIcon.SetUVMRes(const Value: Integer);
begin
  UVMapRes := Value;
  if UVMapRes <> -1 then with World.ResourceManager[UVMapRes] as TArrayResource do begin
//    FreeMem(TIconMesh(CurrentLOD).UVMap);
    TIconMesh(CurrentLOD).MaxFrame := TotalElements - 1;
    TIconMesh(CurrentLOD).UVMap := TUVMap(Data);
  end else with TIconMesh(CurrentLOD) do begin
    UVMap := GetStdUVMap;
    Frame := 0;
  end;
  TIconMesh(CurrentLOD).VStatus := tsChanged;
end;

{ TIconMesh }

constructor TIconMesh.Create(const AName: TShortName; const AWorld: TWorld; const ALeft, ATop, AWidth, AHeight: Integer; const AColor: Cardinal);
var i: Integer;
begin
  World := AWorld;

  TotalVertices := 4; TotalPrimitives := 2;
  TotalIndices := 0; LastTotalIndices := 0; LastTotalVertices := 0; TotalStrips := 1; StripOffset := 0;
  IBOffset := 0; VBOffset := 0;
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];;
  VertexFormat := GetVertexFormat(True, False, True, True, 1);
  VertexSize := GetVertexSize(VertexFormat);

//  Orientation := AOrientation;
  FArea := GetArea(ALeft, ATop, AWidth, AHeight);
  BackColor := $000000; Color := AColor;

  Depth := 0.1;

  MaxFrame := 0;
  UVMap := GetStdUVMap;
  VStatus := tsSizeChanged;
end;

function TIconMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var CurX, CurY: Single;
begin
  case XAlign of
    amLeft: CurX := FArea.Left - 0.5;
    amCenter: CurX := FArea.Left - 0.5 + (RenderPars.ActualWidth - FArea.Width)*0.5;
    amRight: CurX := RenderPars.ActualWidth - FArea.Width - FArea.Left - 0.5;
  end;
  case YAlign of
    amLeft: CurY := FArea.Top - 0.5;
    amCenter: CurY := FArea.Top - 0.5 + (RenderPars.ActualHeight - FArea.Height)*0.5;
    amRight: CurY := RenderPars.ActualHeight - FArea.Height - FArea.Top - 0.5;
  end;

  with TTCDSTBuffer(VBPTR^)[0] do begin
    X := CurX; Y := CurY;
    Z := FDepth; RHW := 1/FDepth;
    DColor := Color; SColor := BackColor;
    U := UVMap[FFrame].U; V := UVMap[FFrame].V;
  end;
  with TTCDSTBuffer(VBPTR^)[1] do begin
    X := CurX+FArea.Width; Y := CurY;
    Z := FDepth; RHW := 1/FDepth;
    DColor := Color; SColor := BackColor;
    U := UVMap[FFrame].U + UVMap[FFrame].W; V := UVMap[FFrame].V;
  end;
  with TTCDSTBuffer(VBPTR^)[2] do begin
    X := CurX; Y := CurY+FArea.Height;
    Z := FDepth; RHW := 1/FDepth;
    DColor := Color; SColor := BackColor;
    U := UVMap[FFrame].U; V := UVMap[FFrame].V + UVMap[FFrame].H;
  end;
  with TTCDSTBuffer(VBPTR^)[3] do begin
    X := CurX+FArea.Width; Y := CurY+FArea.Height;
    Z := FDepth; RHW := 1/FDepth;
    DColor := Color; SColor := BackColor;
    U := UVMap[FFrame].U + UVMap[FFrame].W; V := UVMap[FFrame].V + UVMap[FFrame].H;
  end;
  VStatus := tsChanged;
  LastTotalIndices := 0;
  LastTotalVertices := 4;
  Result := LastTotalVertices;
end;

procedure TIconMesh.SetFrame(const Value: Integer);
begin
  if (Value = FFrame) or (Value > MaxFrame) then Exit;
  FFrame := Value;
  VStatus := tsChanged;
end;

{ TMenu }

constructor TMenu.Create(AUI: TUI; AColor1, AColor2, ABack: Cardinal; AWidth, AItemHeight: Integer; const ATextMaterial: TShortName);
begin
  UI := AUI;
  Color1 := AColor1; Color2 := AColor2; Back := ABack;
  Width := AWidth;
  ItemHeight := AItemHeight;
  FPosition := -1;
  FVisible := False;
  MenuBar := UI.AddIcon(0, 0, 0, 0, Back, '', amLeft);
  HandleResize;
  TextMaterial := ATextMaterial;
end;

procedure TMenu.AddItem(const AName, AValue: TShortName; const AData: Pointer = nil);
begin
  Inc(TotalItems); SetLength(Items, TotalItems);

  Items[TotalItems-1].Name := UI.AddText(Area.Left+4, Area.Top + TotalItems*ItemHeight, AName, Color1, $000000FF);
  Items[TotalItems-1].Value := UI.AddText(Area.Left + Area.Width-4, Area.Top + TotalItems*ItemHeight, AValue, Color1, $00FF0000, amLeft, amRight);
  Items[TotalItems-1].Name.SetMaterial(0, UI.World.Renderer.GetMaterialByName(TextMaterial));
  Items[TotalItems-1].Value.SetMaterial(0, UI.World.Renderer.GetMaterialByName(TextMaterial));
  Items[TotalItems-1].Data := AData;

  if Position = -1 then Position := 0;

  MenuBar.Area := GetArea(Area.Left, Area.Top, Width, (TotalItems+2)*ItemHeight);
end;

procedure TMenu.Clear;
begin
  Hide;
  TotalItems := 0; SetLength(Items, TotalItems);
  FPosition := -1;
end;

procedure TMenu.MoveCursor(const Amount: Integer);
var Pos: Integer;
begin
  if TotalItems = 0 then Exit;
  Pos := FPosition + Amount;
  while Pos < 0 do Inc(Pos, TotalItems);
  Select(Pos mod TotalItems);
end;

procedure TMenu.Select(const NewPosition: Integer);
begin
  if (NewPosition >= -1) and (NewPosition < TotalItems) then begin
    if FPosition <> -1 then begin
      Items[FPosition].Name.Color := Color1;
      Items[FPosition].Value.Color := Color1;
    end;
    FPosition := NewPosition;
    if FPosition <> -1 then begin
      Items[FPosition].Name.Color := Color2;
      Items[FPosition].Value.Color := Color2;
    end;
  end;
end;

procedure TMenu.HandleResize;
var i, TotalHeight: Integer;
begin
  TotalHeight := (TotalItems+2)*ItemHeight;
  with UI.World.Renderer.RenderPars do Area := GetArea((ActualWidth - Width) div 2, (ActualHeight - TotalHeight) div 2 , Width, TotalHeight);
  MenuBar.Area := Area;
  for i := 0 to TotalItems-1 do begin
    Items[i].Name.TextX := Area.Left+4;
    Items[i].Name.TextY := Area.Top+(i+1)*ItemHeight;
    Items[i].Value.TextX := Area.Left + Area.Width-4;
    Items[i].Value.TextY := Area.Top+(i+1)*ItemHeight;
  end;
end;

procedure TMenu.Hide;
var i: Integer;
begin
  if not FVisible then Exit;
  UI.World.DeleteItem(MenuBar.ID);
  for i := 0 to TotalItems - 1 do begin
    UI.World.DeleteItem(Items[i].Name.ID);
    UI.World.DeleteItem(Items[i].Value.ID);
  end;
  FVisible := False;
end;

procedure TMenu.Show;
var i: Integer;
begin
  if FVisible then Exit;
  UI.World.AddItem(MenuBar);
  for i := 0 to TotalItems - 1 do begin
    UI.World.AddItem(Items[i].Name);
    UI.World.AddItem(Items[i].Value);
  end;
  FVisible := True;
end;

procedure TMenu.SetVisibility(const Value: Boolean);
begin
  if Value then Show else Hide;
end;

destructor TMenu.Free;
begin
  Hide;
  TotalItems := 0; SetLength(Items, TotalItems);
end;

{ TMsgPanel }

constructor TMsgPanel.Create(AUI: TUI; ABack: Cardinal; AWidth, AMaxVisibleItems, AItemHeight: Integer; const ATextMaterial: TShortName; AScrollSpeed: Single = 1; const AFadingSpeed: Integer = 4);
begin
  UI := AUI;
  Back := ABack;
  Width := AWidth;
  MaxVisibleItems := AMaxVisibleItems;
  SetLength(Items, MaxVisibleItems+1);
  ItemHeight := AItemHeight;
  FVisible := False;
  ScrollSpeed := AScrollSpeed;
  FadingSpeed := AFadingSpeed;

  Alpha := Back shr 24;
  Fading := False;

  Panel := UI.AddIcon(0, 0, Width, ItemHeight * MaxVisibleItems, Back, '', amLeft);
  Space := ItemHeight * MaxVisibleItems;
  HandleResize;
  TextMaterial := ATextMaterial;
  Status := isProcessing;
end;

function TMsgPanel.Process: Boolean;
begin
  Result := False;
  Scroll(ScrollSpeed);
  if Fading then if Alpha > FadingSpeed then begin
    Dec(Alpha, FadingSpeed); Panel.SetColor(Back and $FFFFFF + Alpha shl 24);
  end else Hide;
end;

procedure TMsgPanel.AddItem(const AMsgText: TShortMessage; const AColor: Longword = $FFFFFFFF);
begin
  Show;
  if Space < ItemHeight then Scroll(ItemHeight - Space);
  Inc(TotalItems);
  Items[TotalItems-1].MsgText := UI.AddText(Area.Left+4, Area.Bottom - ItemHeight, AMsgText, AColor, $00000000);
  Items[TotalItems-1].MsgText.SetMaterial(0, UI.World.Renderer.GetMaterialByName(TextMaterial));
  Items[TotalItems-1].Y := Area.Bottom - ItemHeight;
  UI.World.AddItem(Items[TotalItems-1].MsgText);
  Space := 0;
end;

procedure TMsgPanel.DeleteItem(const Index: Integer);
var i: Integer;
begin
  UI.World.AddToKillList(Items[Index].MsgText, True);
//  Items[Index].MsgText.Free;
  for i := Index to TotalItems-2 do Items[i] := Items[i+1];
  Dec(TotalItems);
end;

procedure TMsgPanel.Clear;
begin
  Hide;
  TotalItems := 0; 
  Space := ItemHeight * MaxVisibleItems;
end;

procedure TMsgPanel.HandleResize;
begin
  Width := MinI(Width, UI.World.Renderer.RenderPars.ActualWidth);
  Area := GetArea(0, 0, Width, ItemHeight * MaxVisibleItems);
  Panel.Area := Area;
end;

procedure TMsgPanel.Scroll(const Amount: Single);
var i: Integer;
begin
  for i := 0 to TotalItems-1 do begin
    Items[i].Y := Items[i].Y - Amount;
    Items[i].MsgText.TextY := Trunc(0.5 + Items[i].Y);
  end;
  Space := Space + Amount;
  if Space > ItemHeight * MaxVisibleItems then begin
    Space := ItemHeight * MaxVisibleItems;
    Fading := True;
  end;
  i := 0;
  while i < TotalItems do begin
    if Items[i].Y <= -ItemHeight then DeleteItem(i) else Break;
    Inc(i);
  end;
end;

procedure TMsgPanel.Hide;
var i: Integer;
begin
  if not FVisible then Exit;
  Fading := False;
  inherited;
  for i := 0 to TotalItems - 1 do UI.World.AddToKillList(Items[i].MsgText, False);
end;

procedure TMsgPanel.Show;
var i: Integer;
begin
  Alpha := Back shr 24;
  Panel.SetColor(Back);
  Fading := False;
  if FVisible then Exit;
  inherited;
  for i := 0 to TotalItems - 1 do UI.World.AddItem(Items[i].MsgText);
end;

procedure TMsgPanel.SetVisibility(const Value: Boolean);
begin
  if Value then Show else Hide;
end;

destructor TMsgPanel.Free;
begin
  Clear;
  SetLength(Items, 0);
end;

{ TPanel }

procedure TPanel.Hide;
begin
  if not FVisible then Exit;
  UI.World.AddToKillList(Panel, False);
  FVisible := False;
end;

procedure TPanel.Show;
begin
  if FVisible then Exit;
  UI.World.AddItem(Panel);
  FVisible := True;
end;

{ TInfoPanel }

constructor TInfoPanel.Create(AUI: TUI; ABack: Cardinal; AWidth, AMaxVisibleItems, AItemHeight: Integer; const ATextMaterial: TShortName);
begin
  UI := AUI;
  Back := ABack;
  Width := AWidth;
  MaxVisibleItems := AMaxVisibleItems;
  SetLength(Items, MaxVisibleItems);
  ItemHeight := AItemHeight;
  FVisible := False;

  Panel := UI.AddIcon(0, 0, Width, ItemHeight * MaxVisibleItems, Back, '', amLeft);
  TextMaterial := ATextMaterial;
  Status := isProcessing;
end;

procedure TInfoPanel.AddItem(const AMsgText: TShortMessage; const AColor: Longword);
begin
  Inc(TotalItems);
  Items[TotalItems-1].MsgText := UI.AddText(Area.Left+4, Area.Bottom - ItemHeight, AMsgText, AColor, $00000000);
  Items[TotalItems-1].MsgText.SetMaterial(0, UI.World.Renderer.GetMaterialByName(TextMaterial));
  UI.World.AddItem(Items[TotalItems-1].MsgText);
end;

procedure TInfoPanel.DeleteItem(const Index: Integer);
var i: Integer;
begin
  UI.World.AddToKillList(Items[Index].MsgText, False);
//  Items[Index].MsgText.Free;
  for i := Index to TotalItems-2 do Items[i] := Items[i+1];
  Dec(TotalItems);
end;

function TInfoPanel.Process: Boolean;
var i: Integer; Location2D: TVector4s;
begin
  Transform4Vector3s(Location2D, World.Renderer.RenderPars.ViewMatrix, Location3D);
end;

procedure TInfoPanel.SetLocation(Loc: TVector3s);
begin
  Location3D := Loc;
end;

procedure TInfoPanel.Show;
begin
  inherited;
end;

procedure TInfoPanel.Hide;
begin
  inherited;
end;

destructor TInfoPanel.Free;
begin
end;

end.
