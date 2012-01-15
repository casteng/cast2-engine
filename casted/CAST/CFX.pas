{$Include GDefines}
{$Include CDefines}
unit CFX;

interface

uses CTypes, Basics, Base3D, Cast, CTess, CRender, CRes, SysUtils, Windows;

const
  UIAllocStep = 256*32;
  MaxLifetime = 1000;
  CurveCapacityStep = 1024;

  cmdKillFX = cmdFXBase + 0;

//  fxkBillBoard = 1; fxkSmokeTrace = 2; fxkBoundingVolume = 3;

type
  TParams = record U, V: Single; end;

  TFXMesh = class(TTesselator)
    Color: Cardinal;
    FXKind: Cardinal;
//    FXManager: TFXManager;
    constructor Create(const AName: TShortName; AArea: TArea; ADepth: Single; AColor: Cardinal); virtual;
    procedure SetArea(const NewArea: TArea); virtual;
    procedure SetDepth(const NewDepth: Single); virtual;
    protected                                                 //ToFix: Move Area property from here
      FArea: TArea;
      FDepth: Single;
    published
      property Depth: Single read FDepth write SetDepth;
  end;

  TBillboardMesh = class(TFXMesh)
    MaxFrame: Integer;
    Location: TVector3s;
    UVMap: TUVMap;
    constructor Create(const AName: TShortName; AColor: Cardinal);
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    procedure SetFrame(const Value: Integer); virtual;
    protected
      FFrame: Integer;
    published
      property Frame: Integer read FFrame write SetFrame;
  end;

  TBillboard = class(TItem)
    AnimationCounter, AnimationDelay, UVMapRes, LightNum, Width, Height, MaxFrame: Integer;
    FramesCycled: Boolean;
    Color: Longword;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetDimensions(const AWidth, AHeight: Integer); virtual;
    procedure SetColor(const AColor: Longword); virtual;
    procedure SetMesh; override;
    function Process: Boolean; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    destructor Free; override;
    procedure SetFrame(const Value: Integer);
    function GetFrame: Integer;
  published
    property Frame: Integer read GetFrame write SetFrame;
  private
    OldLocation: TVector3s;
  end;

  TSmokeTraceMesh = class(TFXMesh)
    TotalPoints: Integer;
    Points: array of TVector3s;
    Size: Integer;
    LifeTime: Integer;
    constructor Create(const AName: TShortName; AColor: Cardinal);
    procedure AddPoint(const APoint: TVector3s); virtual;
    procedure Clear; virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;
  TSmokeTrace = class(TItem)
    GrowSpeed: Integer;
    Alpha, FadeSpeed: Longword;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
    function Process: Boolean; override;
  private
    function GetColor: Longword;
    procedure SetColor(const Value: Longword);
  published
    property Color: Longword read GetColor write SetColor;
  end;

  T3DLineMesh = class(TTesselator)
    Size1, Size2, VScale: Single;
    Color1, Color2: Longword;
    Point1, Point2: TVector4s;
    constructor Create(const AName: TShortName);
    procedure SetPars(const APoint1, APoint2: TVector4s; const AColor1, AColor2: Longword; const ASize1, ASize2, AVScale: Single); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  protected
    ModelMatrix: TMatrix4s;
  end;
  T3DLine = class(TItem)
    FPoint: TVector3s;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetOrientation(AOrientation: TQuaternion); override;
    procedure SetParams(const Color1, Color2: Longword; const Size1, Size2, VScale: Single);
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  private
    function GetColor1: Longword;
    procedure SetColor1(const Value: Longword);
    function GetColor2: Longword;
    procedure SetColor2(const Value: Longword);
    function GetPoint: TVector3s;
    procedure SetPoint(const Value: TVector3s);
  public
    property Color1: Longword read GetColor1 write SetColor1;
    property Color2: Longword read GetColor2 write SetColor2;
    property Point: TVector3s read GetPoint write SetPoint;
  end;

  TCurvePoint = packed record
    Coord: TVector3s;
    Color: Longword;
    Size: Single;
  end;
  TCurveMesh = class(TTesselator)
    MaxPoints, TotalPoints, PointsCapacity: Integer;
    Points: array of TCurvePoint;
    UScale: Single;
    constructor Create(const AName: TShortName); override;
    procedure AddPoint(const ACoord: TVector3s; const AColor: Longword; const ASize: Single); virtual;
    procedure DeletePoints(const Count: Integer); virtual;
    procedure Clear; virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;
  TCurve = class(TItem)
    DefaultColor: Longword;
    PointsToAdd: Integer;
    DefaultSize: Single;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    procedure SetupExternalVariables; override;
    function Process: Boolean; override;
  end;

implementation

{ TFXBase }
constructor TFXMesh.Create(const AName: TShortName; AArea: TArea; ADepth: Single; AColor: Cardinal);
begin
  inherited Create(AName);
  TotalIndices := 0; LastTotalIndices := 0; LastTotalVertices := 0; TotalStrips := 1; StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;

  FXStatus := fxsNormal;
  FArea := AArea;
  FDepth := ADepth;
  Color := AColor;
end;

procedure TFXMesh.SetArea(const NewArea: TArea);
begin
  with FArea do if (NewArea.Left = Left) and (NewArea.Top = Top) and (NewArea.Width = Width) and (NewArea.Height = Height) then Exit;
  FArea := NewArea;
  VStatus := tsChanged;
end;

procedure TFXMesh.SetDepth(const NewDepth: Single);
begin
  if NewDepth = FDepth then Exit;
//  FDepth :=  (NewDepth - FXManager.Renderer.ZNear)/(FXManager.Renderer.ZFar-FXManager.Renderer.ZNear);
//  FDepth := (Renderer.ZFar/(Renderer.ZFar-Renderer.ZNear))*(1-Renderer.ZNear/(NewDepth));
//  FDepth := 1;

//  z := (ZFar/(ZFar-ZNear))*(1-ZNear/(BZ-10));
  FDepth := NewDepth;
  VStatus := tsChanged;
end;

{ TFXManager }

constructor TBillboardMesh.Create(const AName: TShortName; AColor: Cardinal);
begin
  inherited Create(AName, GetArea(0, 0, 200000, 200000), 0, AColor);
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(True, False, True, False, 1);
  VertexSize := (3 + VertexFormat and 1 + (VertexFormat shr 1) and 1 * 3 + (VertexFormat shr 2) and 1 + (VertexFormat shr 3) and 1 + (VertexFormat shr 8) and 255 * 2) shl 2;
  TotalVertices := 4; TotalPrimitives := 2;
  MaxFrame := 0;
  UVMap := GetDefaultUVMap;
end;

function TBillboardMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var Transformed: TVector4s; TRHW, SizeX, SizeY: Single;
begin
  Result := 0;
  LastTotalIndices := 0;
  LastTotalVertices := 0;
  TotalPrimitives := 0;
  if FFrame > MaxFrame then Exit;
  Transformed := Transform4Vector3s(RenderPars.TotalMatrix, Location);
  if Transformed.W < 0 then Exit;
  TRHW := 1/Transformed.W;
  Transformed.X := RenderPars.ActualWidth shr 1 + RenderPars.ActualWidth shr 1*Transformed.X * TRHW;
  Transformed.Y := RenderPars.ActualHeight shr 1 - RenderPars.ActualHeight shr 1*Transformed.Y * TRHW;
  SizeX := FArea.Width*TRHW*RenderPars.ActualWidth*0.5*0.005;
  SizeY := FArea.Height*TRHW*RenderPars.ActualHeight*0.5*0.005*RenderPars.CurrentAspectRatio;
  with RenderPars do Transformed.Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));
  with TTCDTBuffer(VBPTR^)[0] do begin
    X := Transformed.X - SizeX;
    Y := Transformed.Y - SizeY;
    Z := Transformed.Z; RHW := TRHW;
    DColor := Color;
    U := UVMap[FFrame].U; V := UVMap[FFrame].V;
  end;
  with TTCDTBuffer(VBPTR^)[1] do begin
    X := Transformed.X + SizeX;
    Y := Transformed.Y - SizeY;
    Z := Transformed.Z; RHW := TRHW;
    DColor := Color;
    U := UVMap[FFrame].U + UVMap[FFrame].W; V := UVMap[FFrame].V;
  end;
  with TTCDTBuffer(VBPTR^)[2] do begin
    X := Transformed.X - SizeX;
    Y := Transformed.Y + SizeY;
    Z := Transformed.Z; RHW := TRHW;
    DColor := Color;
    U := UVMap[FFrame].U; V := UVMap[FFrame].V + UVMap[FFrame].H;
  end;
  with TTCDTBuffer(VBPTR^)[3] do begin
    X := Transformed.X + SizeX;
    Y := Transformed.Y + SizeY;
    Z := Transformed.Z; RHW := TRHW;
    DColor := Color;
    U := UVMap[FFrame].U + UVMap[FFrame].W; V := UVMap[FFrame].V + UVMap[FFrame].H;
  end;
//  VStatus := tsTesselated;
  VStatus := tsChanged;
  LastTotalVertices := 4;
  TotalPrimitives := 2;
  Result := LastTotalVertices;
end;

procedure TBillboardMesh.SetFrame(const Value: Integer);
begin
  if (Value = FFrame) or (Value > MaxFrame) then Exit;
  FFrame := Value;
  VStatus := tsChanged;
end;

{ TBillboard }

constructor TBillboard.Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
begin
  inherited;
  AnimationCounter := 1; AnimationDelay := 1;
  UVMapRes := -1;
  FramesCycled := False;
  LightNum := -1;
  Order := 1100;
end;

procedure TBillboard.SetDimensions(const AWidth, AHeight: Integer);
begin
  Width := AWidth; Height := AHeight;
  TBillBoardmesh(CurrentLOD).SetArea(GetArea(0, 0, Width, Height));
end;

procedure TBillboard.SetColor(const AColor: Longword);
begin
  Color := AColor;
  TBillBoardMesh(CurrentLOD).Color := Color;
  TBillBoardMesh(CurrentLOD).VStatus := tsChanged;
end;

procedure TBillboard.SetMesh;
begin
  ClearMeshes;
  AddLOD(TBillboardMesh.Create('Billboard mesh', $FFFFFFFF));
//  CurrentLOD.VerticesRes := AVerticesRes;
//  CurrentLOD.IndicesRes := AIndicesRes;
//  inherited;
end;

function TBillboard.Process: Boolean;
var arg: Single;
begin
  Result := False;
  with TBillBoardMesh(CurrentLOD) do begin
    with ModelMatrix do Location := GetVector3s(_41, _42, _43);
    if SqrMagnitude(SubVector3s(OldLocation, Location)) > epsilon then if VStatus = tsTesselated then VStatus := tsChanged;
    if (AnimationCounter = 0) then begin
//      OldLocation := Location;
      if FFrame < MaxFrame then begin
        Inc(FFrame);
        if LightNum <> -1 then begin                            // Adjust light source
//          arg := (1-Abs(FFrame - MaxFrame*0.25)/MaxFrame);     // Max at 1 - 1/4
          arg := 1-FFrame/MaxFrame;     // Max at 1 - 1/4
          World.Lights[LightNum].Diffuse.R := arg;
          World.Lights[LightNum].Diffuse.B := arg;
          World.Lights[LightNum].Diffuse.G := arg;
          World.Lights[LightNum].Range := 64*256;
        end;
      end else begin
        FFrame := 0;
        if not FramesCycled then begin
          AnimationCounter := -1;
//          Self.Status := Self.Status and not isProcessing;
          if LightNum <> -1 then World.DeleteLight(LightNum);
          LightNum := -1;
        end;
      end;
      if VStatus = tsTesselated then VStatus := tsChanged;
      if AnimationCounter <> -1 then AnimationCounter := AnimationDelay;
    end else if AnimationCounter <> -1 then Dec(AnimationCounter);
  end;
end;

function TBillboard.GetProperties: TProperties;
begin
  Result := inherited GetProperties;

  NewProperty(Result, 'Billboard color', ptColor32, Pointer(TBillBoardMesh(CurrentLOD).Color));

  NewProperty(Result, 'Animation delay', ptInt32, Pointer(AnimationDelay));
  NewProperty(Result, 'Width', ptInt32, Pointer(TBillBoardMesh(CurrentLOD).FArea.Width div 1000));
  NewProperty(Result, 'Height', ptInt32, Pointer(TBillBoardMesh(CurrentLOD).FArea.Height div 1000));

  NewProperty(Result, 'UV Mapping', ptResource + World.ResourceManager.GetResourceClassIndex('TFontResource') shl 8, Pointer(UVMapRes));
  NewProperty(Result, 'Cycle animation', ptBoolean, Pointer(FramesCycled));
end;

function TBillboard.SetProperties(AProperties: TProperties): Integer;
var NewUVMapRes: Integer;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;

  SetColor(Longword(GetPropertyValue(AProperties, 'Billboard color')));
  AnimationDelay := Integer(GetPropertyValue(AProperties, 'Animation delay'));
  AnimationCounter := AnimationDelay;
  SetDimensions(Integer(GetPropertyValue(AProperties, 'Width'))*1000, Integer(GetPropertyValue(AProperties, 'Height'))*1000);

  NewUVMapRes := Integer(GetPropertyValue(AProperties, 'UV Mapping'));
  if NewUVMapRes = -1 then begin
    MaxFrame := 0;
    TBillBoardMesh(CurrentLOD).MaxFrame := MaxFrame;
    TBillBoardMesh(CurrentLOD).UVMap := GetDefaultUVMap;
    UVMapRes := NewUVMapRes;
  end else with World.ResourceManager[NewUVMapRes] as TArrayResource do begin
//    if UVMapRes = -1 then FreeMem(TBillBoardMesh(CurrentLOD).UVMap);
    MaxFrame := TotalElements - 1;
    TBillBoardMesh(CurrentLOD).MaxFrame := MaxFrame;
    TBillBoardMesh(CurrentLOD).UVMap := TUVMap(Data);
    UVMapRes := NewUVMapRes;
  end;
  FramesCycled := Boolean(GetPropertyValue(AProperties, 'Cycle animation'));
  TBillBoardMesh(CurrentLOD).VStatus := tsChanged;
end;

destructor TBillboard.Free;
begin
  if LightNum <> -1 then World.DeleteLight(LightNum);
  LightNum := -1;
  inherited;
end;

function TBillboard.GetFrame: Integer;
begin
  Result := TBillBoardMesh(CurrentLOD).Frame;
end;

procedure TBillboard.SetFrame(const Value: Integer);
begin
  TBillBoardMesh(CurrentLOD).Frame := Value;
end;

{ TSmokeTrace }

constructor TSmokeTrace.Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
begin
  inherited;
  AddLOD(TSmokeTraceMesh.Create('', $FFFF4040)); Color := $FFFF4040;
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmOne, tfLESSEQUAL, tfAlways, 0, False, False);
//  AddRenderPass(bmSrcAlpha, bmZero, tfLESSEQUAL, tfAlways, 0, False, False);
  GrowSpeed := 100;
  Order := 1000;
end;

function TSmokeTrace.GetColor: Longword;
begin
  Result := TSmokeTraceMesh(CurrentLOD).Color;
end;

procedure TSmokeTrace.SetColor(const Value: Longword);
begin
  TSmokeTraceMesh(CurrentLOD).Color := Value;
  Alpha := Value shr 24;
end;

function TSmokeTrace.Process: Boolean;
var Mesh: TSmokeTraceMesh;
begin
  Result := False;
  Mesh := TSmokeTraceMesh(CurrentLOD);
  Dec(TSmokeTraceMesh(CurrentLOD).LifeTime);
  Inc(TSmokeTraceMesh(CurrentLOD).Size, GrowSpeed);
  if Mesh.FXStatus = fxsFading then Alpha := MinI(255, MaxI(0, Integer(Alpha) - Integer(FadeSpeed)));
  Color := Alpha shl 24 + Color and $FFFFFF;
  if (Mesh.LifeTime < 0) or ((Mesh.FXStatus = fxsFading) and (Color shr 24 = 0)) then begin
    World.Events.Add(cmdKillFX, [Integer(Self)]);
  end;
  if Mesh.VStatus = tsTesselated then Mesh.VStatus := tsChanged;
end;

{ TSmokeTraceMesh }

constructor TSmokeTraceMesh.Create(const AName: TShortName; AColor: Cardinal);
begin
  inherited Create(AName, GetArea(0, 0, 0, 0), 0, AColor);
  Size := 20000;
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(True, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalVertices := 0; TotalPrimitives := 0;
  LifeTime := MaxLifeTime;
end;

procedure TSmokeTraceMesh.AddPoint(const APoint: TVector3s);
begin
  Inc(TotalPoints); SetLength(Points, TotalPoints);
  Points[TotalPoints - 1] := APoint;
  Inc(TotalVertices, 2); TotalPrimitives := TotalVertices - 2;
  VStatus := tsSizeChanged;
  LifeTime := MaxLifeTime;
end;

procedure TSmokeTraceMesh.Clear;
begin
  TotalVertices := 0; TotalPrimitives := 0;
  TotalPoints := 0; SetLength(Points, TotalPoints);
  VStatus := tsSizeChanged;
end;

function TSmokeTraceMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var
  i: Integer; Transformed: TVector4s; TRHW: Single;
  VX, VY, VZ, VL, PX, PY, OPX, OPY, TPX, TPY, LastX, LastY, Len: Single; l: Single;
begin
  Result := 0;
  LastTotalIndices := 0;
  LastTotalVertices := 0;
  TotalPrimitives := 0;
  if TotalPoints <= 1 then Exit;

  TotalPrimitives := TotalPoints*2 - 2;

  Len := 0;
  for i := 0 to TotalPoints - 1 do begin
    Transformed := Transform4Vector3s(RenderPars.TotalMatrix, Points[i]);
//    Transformed.X := Points[i].X; Transformed.Y := Points[i].Y;
    if Transformed.W < 0 then begin
      Transformed.W := 0.00000001;
//      Continue;
    end;

    TRHW := 1/Transformed.W;
    with TTCDTBuffer(VBPTR^)[i*2] do begin
      X := RenderPars.ActualWidth shr 1 + RenderPars.ActualWidth shr 1*Transformed.X * TRHW;
      Y := RenderPars.ActualHeight shr 1 - RenderPars.ActualHeight shr 1*Transformed.Y * TRHW;
      with RenderPars do Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));
      RHW := TRHW;
      DColor := Color;

      if i > 0 then begin
        l := Sqrt( Sqr(Points[i].X-Points[i-1].X)+Sqr(Points[i].Y-Points[i-1].Y)+Sqr(Points[i].Z-Points[i-1].Z) );
        Len := Len + l;
      end;
      U := (Len+lifetime)*0.001;
      TTCDTBuffer(VBPTR^)[i*2+1].U := U;
      V := 0
    end;
  end;

//  OPX := 0; OPY := 0;

  with TTCDTBuffer(VBPTR^)[0] do begin
    VX := TTCDTBuffer(VBPTR^)[2].X - X; VY := TTCDTBuffer(VBPTR^)[2].Y - Y;
    VL := InvSqrt(VX*VX + VY*VY);
    Len := 1/VL;
    PX := VL*(VX * 0 - VY * 1); PY := VL*(VX * 1 + VY * 0);
    OPX := PX; OPY := PY;

    TTCDTBuffer(VBPTR^)[1].X := X - PX*Size*RHW;
    TTCDTBuffer(VBPTR^)[1].Y := Y - PY*Size*RHW;

    TTCDTBuffer(VBPTR^)[1].Z := Z; TTCDTBuffer(VBPTR^)[1].RHW := RHW; TTCDTBuffer(VBPTR^)[1].DColor := Color;
//    TTCDTBuffer(VBPTR^)[1].U := 0;
    TTCDTBuffer(VBPTR^)[1].V := 1;
    X := X + PX*Size*RHW; Y := Y + PY*Size*RHW;
  end;

  for i := 1 to TotalPoints - 2 do begin
    with TTCDTBuffer(VBPTR^)[i*2] do begin
      VX := TTCDTBuffer(VBPTR^)[i*2+2].X - X; VY := TTCDTBuffer(VBPTR^)[i*2+2].Y - Y;
      VL := InvSqrt(VX*VX + VY*VY);
      Len := Len + 1/VL;
      TPX := VL*(VX * 0 - VY * 1); TPY := VL*(VX * 1 + VY * 0);
      PX := (OPX + TPX) * 0.5; PY := (OPY + TPY) * 0.5;
      OPX := 0*PX + TPX;
      OPY := 0*PY + TPY;

      TTCDTBuffer(VBPTR^)[i*2+1].X := X - PX*Size*RHW;
      TTCDTBuffer(VBPTR^)[i*2+1].Y := Y - PY*Size*RHW;
      TTCDTBuffer(VBPTR^)[i*2+1].Z := Z; TTCDTBuffer(VBPTR^)[i*2+1].RHW := RHW; TTCDTBuffer(VBPTR^)[i*2+1].DColor := Color;
//      TTCDTBuffer(VBPTR^)[i*2+1].U := Len/128;
//      TTCDTBuffer(VBPTR^)[i*2].U := TTCDTBuffer(VBPTR^)[i*2+1].U;
      TTCDTBuffer(VBPTR^)[i*2+1].V := 1;
      X := X + PX*Size*RHW; Y := Y + PY*Size*RHW;
    end;
  end;

  with TTCDTBuffer(VBPTR^)[TotalPoints*2-2] do begin
    VX := X - TTCDTBuffer(VBPTR^)[TotalPoints*2-4].X; VY := Y - TTCDTBuffer(VBPTR^)[TotalPoints*2-4].Y;
    VL := InvSqrt(VX*VX + VY*VY);
    Len := Len + 1/VL;
    PX := VL*(VX * 0 - VY * 1); PY := VL*(VX * 1 + VY * 0);
    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].X := X - PX*Size*RHW;
    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].Y := Y - PY*Size*RHW;
    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].Z := Z; TTCDTBuffer(VBPTR^)[TotalPoints*2-1].RHW := RHW; TTCDTBuffer(VBPTR^)[TotalPoints*2-1].DColor := Color;
//    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].U := Len/128;
//    TTCDTBuffer(VBPTR^)[TotalPoints*2-2].U := TTCDTBuffer(VBPTR^)[TotalPoints*2-1].U;
    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].V := 1;
    LastX := X + PX*Size*RHW; LastY := Y + PY*Size*RHW;
  end;

  TTCDTBuffer(VBPTR^)[TotalPoints*2-2].X := LastX; TTCDTBuffer(VBPTR^)[TotalPoints*2-2].Y := LastY;
//  VStatus := tsTesselated;
  VStatus := tsChanged;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ T3DLineTesselator }

constructor T3DLineMesh.Create(const AName: TShortName);
begin
  inherited Create(AName);
  IndexingVertices := 0;

  Size1 := 500; Size2 := 500; VScale := 1;
  Color1 := $80808080; Color2 := $80808080;
  Point1 := GetVector4s(0, 0, 0, 1); Point2 := Point1;

  PrimitiveType := CPTypes[ptTRIANGLEFAN];
  InitVertexFormat(GetVertexFormat(False, False, True, False, 1));

  TotalIndices := 0; TotalVertices := 6; TotalPrimitives := 4;

  VStatus := tsSizeChanged;
end;

procedure T3DLineMesh.SetPars(const APoint1, APoint2: TVector4s; const AColor1, AColor2: Longword; const ASize1, ASize2, AVScale: Single);
begin
  Point1 := APoint1; Point2 := APoint2;
  Color1 := AColor1; Color2 := AColor2;
  Size1  := ASize1;  Size2 := ASize2;
  VScale := AVScale;
  VStatus := tsChanged;
end;

function T3DLineMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var
  Trans1, Trans2: TVector4s; 
  V, W, N, I, Cam: TVector3s;
  Len, d, e: Single;
begin
//  Size1 := 150; Size2 := 1500;
  Result := 0;
  TotalVertices := 0; TotalPrimitives := 0;
  if LastTotalVertices <> TotalVertices then VStatus := tsSizeChanged else VStatus := tsChanged;
  LastTotalIndices := 0; LastTotalVertices := 0;

//  Cam := CutVector3s(Transform4Vector4s(ModelMatrix, GetVector4s(RenderPars.Camera.X, RenderPars.Camera.Y, RenderPars.Camera.Z, 1)));
  Cam := GetVector3s(RenderPars.Camera.X, RenderPars.Camera.Y, RenderPars.Camera.Z);

  Trans1 := Transform4Vector4s(ModelMatrix, Point1);
  Trans2 := Transform4Vector4s(ModelMatrix, Point2);

//  Trans1 := CutVector3s(Point1); Trans2 := CutVector3s(Point2);

  N := CutVector3s(SubVector4s(Trans2, Trans1));
  V := GetVector3s(- Trans1.X + Cam.X, - Trans1.Y + Cam.Y, - Trans1.Z + Cam.Z);
  W := N;
  d := DotProductVector3s(N, V);
  e := DotProductVector3s(N, W);
  I := AddVector3s(CutVector3s(Trans1), ScaleVector3s(W, d/e));

  N := CrossProductVector3s(GetVector3s(I.X - Cam.X, I.Y - Cam.Y, I.Z - Cam.Z), N);

  N := Transform3Vector3s(GetTransposedMatrix3s(CutMatrix3s(ModelMatrix)), N);

  Len := InvSqrt(SqrMagnitude(N));

//  N := GetVector3s(1, 0, 0); Len := 1;

//  1           2
//        0
//  4           3

  SetVertexDataC((Point1.X + Point2.X) * 0.5, (Point1.Y + Point2.Y) * 0.5, (Point1.Z + Point2.Z) * 0.5, 0, VBPtr);
  SetVertexDataD(BlendColor(Color1, Color2, 0.5) + 0*$FFFF8080, 0, VBPtr);
  SetVertexDataUV(0.5, VScale * 0.5, 0, VBPtr);

  SetVertexDataC(Point1.X - N.X * Len * Size1, Point1.Y - N.Y * Len * Size1, Point1.Z - N.Z * Len * Size1, 1, VBPtr);
  SetVertexDataD(Color1 + 0*$FFFFFFFF, 1, VBPtr);
  SetVertexDataUV(0, VScale, 1, VBPtr);

  SetVertexDataC(Point2.X - N.X * Len * Size2, Point2.Y - N.Y * Len * Size2, Point2.Z - N.Z * Len * Size2, 2, VBPtr);
  SetVertexDataD(Color2 + 0*$FF0000FF, 2, VBPtr);
  SetVertexDataUV(0, 0 + 0*0.5, 2, VBPtr);

  {  SetVertexDataC(Point2.X, Point2.Y, Point2.Z, 3, VBPtr);
  SetVertexDataD(Color2*0 + $FF008080, 3, VBPtr);
  SetVertexDataUV(0.5, 0, 3, VBPtr);}

  SetVertexDataC(Point1.X + N.X * Len * Size1, Point1.Y + N.Y * Len * Size1, Point1.Z + N.Z * Len * Size1, 4, VBPtr);
  SetVertexDataD(Color1 + 0*$FFFF0000, 4, VBPtr);
  SetVertexDataUV(1, VScale, 4, VBPtr);

  SetVertexDataC(Point2.X + N.X * Len * Size2, Point2.Y + N.Y * Len * Size2, Point2.Z + N.Z * Len * Size2, 3, VBPtr);
  SetVertexDataD(Color2 + 0*$FF00FF00, 3, VBPtr);
  SetVertexDataUV(1, 0, 3, VBPtr);

  SetVertexDataC(Point1.X - N.X * Len * Size1, Point1.Y - N.Y * Len * Size1, Point1.Z - N.Z * Len * Size1, 5, VBPtr);
  SetVertexDataD(Color1 + 0*$FFFFFFFF, 5, VBPtr);
  SetVertexDataUV(0, VScale, 5, VBPtr);

  VStatus := tsTesselated;
  TotalVertices := 6; TotalPrimitives := 4;
//  if LastTotalVertices <> TotalVertices then VStatus := tsSizeChanged else VStatus := tsChanged;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ T3DLine }

constructor T3DLine.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  AddLOD(T3DLineMesh.Create(''));
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmOne, tfLESSEQUAL, tfAlways, 0, False, False);
  Order := 1000;
//  CullMode := cmNone;
  Point := GetVector3s(0, 0, 1000);
end;

procedure T3DLine.SetOrientation(AOrientation: TQuaternion);
var Mesh: T3DLineMesh;
begin
  inherited;
  Mesh := CurrentLOD as T3DLineMesh;
  Mesh.ModelMatrix := ModelMatrix;
  SetParams(Mesh.Color1, Mesh.Color2, Mesh.Size1, Mesh.Size2, Mesh.VScale);
end;

procedure T3DLine.SetParams(const Color1, Color2: Longword; const Size1, Size2, VScale: Single);
begin
//  (CurrentLOD as T3DLineMesh).SetPars(Transform4Vector3s(ModelMatrix, GetVector3s(0, 0, 0)), Transform4Vector3s(ModelMatrix, FPoint), Color1, Color2, Size);
  (CurrentLOD as T3DLineMesh).SetPars(GetVector4s(0, 0, 0, 1), GetVector4s(FPoint.X, FPoint.Y, FPoint.Z, 1), Color1, Color2, Size1, Size2, VScale);
end;

function T3DLine.GetProperties: TProperties;
var Mesh: T3DLineMesh;
begin
  Mesh := CurrentLOD as T3DLineMesh;
  Result := inherited GetProperties;
  NewProperty(Result, 'DX', ptSingle, Pointer(FPoint.X));
  NewProperty(Result, 'DY', ptSingle, Pointer(FPoint.Y));
  NewProperty(Result, 'DZ', ptSingle, Pointer(FPoint.Z));
  NewProperty(Result, 'Color 1', ptColor32, Pointer(Mesh.Color1));
  NewProperty(Result, 'Color 2', ptColor32, Pointer(Mesh.Color2));
  NewProperty(Result, 'Size1', ptSingle, Pointer(Mesh.Size1));
  NewProperty(Result, 'Size2', ptSingle, Pointer(Mesh.Size2));
  NewProperty(Result, 'V scale', ptSingle, Pointer(Mesh.VScale));
end;

function T3DLine.SetProperties(AProperties: TProperties): Integer;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;
  FPoint := GetVector3s(Single(GetPropertyValue(AProperties, 'DX')),
                        Single(GetPropertyValue(AProperties, 'DY')),
                        Single(GetPropertyValue(AProperties, 'DZ')));
  SetParams(Longword(GetPropertyValue(AProperties, 'Color 1')), Longword(GetPropertyValue(AProperties, 'Color 2')),
              Single(GetPropertyValue(AProperties, 'Size1')), Single(GetPropertyValue(AProperties, 'Size2')),
              Single(GetPropertyValue(AProperties, 'V scale')) );
end;

function T3DLine.GetColor1: Longword;
begin
  Result := (CurrentLOD as T3DLineMesh).Color1;
end;

procedure T3DLine.SetColor1(const Value: Longword);
begin
  (CurrentLOD as T3DLineMesh).Color1 := Value;
end;

function T3DLine.GetColor2: Longword;
begin
  Result := (CurrentLOD as T3DLineMesh).Color2;
end;

procedure T3DLine.SetColor2(const Value: Longword);
begin
  (CurrentLOD as T3DLineMesh).Color2 := Value;
end;

procedure T3DLine.SetPoint(const Value: TVector3s);
begin
  FPoint := Value;
  SetParams((CurrentLOD as T3DLineMesh).Color1, (CurrentLOD as T3DLineMesh).Color2, (CurrentLOD as T3DLineMesh).Size1, (CurrentLOD as T3DLineMesh).Size2, (CurrentLOD as T3DLineMesh).VScale);
end;

function T3DLine.GetPoint: TVector3s;
begin
  Result := FPoint;
end;

{ TCurveMesh}

constructor TCurveMesh.Create(const AName: TShortName);
begin
  inherited Create(AName);
  LastTotalIndices := 0; LastTotalVertices := 0; IndexingVertices := 0;
  TotalStrips := 1; StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;

  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(True, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalIndices := 0; TotalVertices := 4; TotalPrimitives := 2;

  VStatus := tsSizeChanged;

  TotalPoints := 0; PointsCapacity := 0;

  UScale := 0.0001;
  MaxPoints := 1000;
end;

procedure TCurveMesh.AddPoint(const ACoord: TVector3s; const AColor: Longword; const ASize: Single);
begin
  if TotalPoints >= MaxPoints then Exit;
  Inc(TotalPoints);
  if TotalPoints > PointsCapacity then begin
    Inc(PointsCapacity, CurveCapacityStep); SetLength(Points, PointsCapacity);
  end;
  Points[TotalPoints - 1].Coord := ACoord;
  Points[TotalPoints - 1].Color := AColor;
  Points[TotalPoints - 1].Size := ASize;
  Inc(TotalVertices, 2); TotalPrimitives := TotalVertices - 2;
  VStatus := tsSizeChanged;
end;

procedure TCurveMesh.Clear;
begin
  TotalVertices := 0; TotalPrimitives := 0;
  TotalPoints := 0;
  VStatus := tsSizeChanged;
end;

function TCurveMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var
  i: Integer; Transformed: TVector4s; TRHW: Single;
  VX, VY, VZ, VL, PX, PY, OPX, OPY, TPX, TPY, LastX, LastY, Len: Single; l: Single;
begin
  Result := 0;
  LastTotalIndices := 0;
  LastTotalVertices := 0;
  TotalPrimitives := 0;
  if TotalPoints < 2 then Exit;

  TotalPrimitives := TotalPoints*2 - 2;

  Len := 0;
  for i := 0 to TotalPoints - 1 do begin
    Transformed := Transform4Vector3s(RenderPars.TotalMatrix, Points[i].Coord);
    if Transformed.W < 0 then Transformed.W := 0.00000001;

    TRHW := 1/Transformed.W;
    with TTCDTBuffer(VBPTR^)[i*2] do begin
      X := RenderPars.ActualWidth shr 1 + RenderPars.ActualWidth shr 1*Transformed.X * TRHW;
      Y := RenderPars.ActualHeight shr 1 - RenderPars.ActualHeight shr 1*Transformed.Y * TRHW;
      with RenderPars do Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));
      RHW := TRHW;
      DColor := Points[i].Color;

      if i > 0 then begin
        l := InvSqrt( Sqr(Points[i].Coord.X-Points[i-1].Coord.X)+Sqr(Points[i].Coord.Y-Points[i-1].Coord.Y)+Sqr(Points[i].Coord.Z-Points[i-1].Coord.Z) );
        Len := Len + 1/l;
      end;
      U := Len*UScale;
      TTCDTBuffer(VBPTR^)[i*2+1].U := U;
      V := 0;
    end;
  end;

//  OPX := 0; OPY := 0;

  with TTCDTBuffer(VBPTR^)[0] do begin
    VX := TTCDTBuffer(VBPTR^)[2].X - X; VY := TTCDTBuffer(VBPTR^)[2].Y - Y;
    VL := InvSqrt(VX*VX + VY*VY);
    Len := 1/VL;
    PX := VL*(VX * 0 - VY * 1); PY := VL*(VX * 1 + VY * 0);
    OPX := PX; OPY := PY;

    TTCDTBuffer(VBPTR^)[1].X := X - PX*Points[0].Size*RHW;
    TTCDTBuffer(VBPTR^)[1].Y := Y - PY*Points[0].Size*RHW;

    TTCDTBuffer(VBPTR^)[1].Z := Z; TTCDTBuffer(VBPTR^)[1].RHW := RHW; TTCDTBuffer(VBPTR^)[1].DColor := Points[0].Color;
//    TTCDTBuffer(VBPTR^)[1].U := 0;
    TTCDTBuffer(VBPTR^)[1].V := 1;
    X := X + PX*Points[0].Size*RHW; Y := Y + PY*Points[0].Size*RHW;
  end;

  for i := 1 to TotalPoints - 2 do begin
    with TTCDTBuffer(VBPTR^)[i*2] do begin
      VX := TTCDTBuffer(VBPTR^)[i*2+2].X - X; VY := TTCDTBuffer(VBPTR^)[i*2+2].Y - Y;
      VL := InvSqrt(VX*VX + VY*VY);
      Len := Len + 1/VL;
      TPX := VL*(VX * 0 - VY * 1); TPY := VL*(VX * 1 + VY * 0);
      PX := (OPX + TPX) * 0.5; PY := (OPY + TPY) * 0.5;
      OPX := 0*PX + TPX;
      OPY := 0*PY + TPY;

      TTCDTBuffer(VBPTR^)[i*2+1].X := X - PX*Points[i].Size*RHW;
      TTCDTBuffer(VBPTR^)[i*2+1].Y := Y - PY*Points[i].Size*RHW;
      TTCDTBuffer(VBPTR^)[i*2+1].Z := Z; TTCDTBuffer(VBPTR^)[i*2+1].RHW := RHW; TTCDTBuffer(VBPTR^)[i*2+1].DColor := Points[i].Color;
//      TTCDTBuffer(VBPTR^)[i*2+1].U := Len/128;
//      TTCDTBuffer(VBPTR^)[i*2].U := TTCDTBuffer(VBPTR^)[i*2+1].U;
      TTCDTBuffer(VBPTR^)[i*2+1].V := 1;
      X := X + PX*Points[i].Size*RHW; Y := Y + PY*Points[i].Size*RHW;
    end;
  end;

  with TTCDTBuffer(VBPTR^)[TotalPoints*2-2] do begin
    VX := X - TTCDTBuffer(VBPTR^)[TotalPoints*2-4].X; VY := Y - TTCDTBuffer(VBPTR^)[TotalPoints*2-4].Y;
    VL := InvSqrt(VX*VX + VY*VY);
    Len := Len + 1/VL;
    PX := VL*(VX * 0 - VY * 1); PY := VL*(VX * 1 + VY * 0);
    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].X := X - PX*Points[TotalPoints-1].Size*RHW;
    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].Y := Y - PY*Points[TotalPoints-1].Size*RHW;
    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].Z := Z; TTCDTBuffer(VBPTR^)[TotalPoints*2-1].RHW := RHW; TTCDTBuffer(VBPTR^)[TotalPoints*2-1].DColor := Points[TotalPoints-1].Color;
//    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].U := Len/128;
//    TTCDTBuffer(VBPTR^)[TotalPoints*2-2].U := TTCDTBuffer(VBPTR^)[TotalPoints*2-1].U;
    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].V := 1;
    LastX := X + PX*Points[TotalPoints-1].Size*RHW; LastY := Y + PY*Points[TotalPoints-1].Size*RHW;
  end;

  TTCDTBuffer(VBPTR^)[TotalPoints*2-2].X := LastX; TTCDTBuffer(VBPTR^)[TotalPoints*2-2].Y := LastY;
//  VStatus := tsTesselated;
  VStatus := tsChanged;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

procedure TCurveMesh.DeletePoints(const Count: Integer);
var i: Integer;
begin
  if Count >= TotalPoints then Clear else if Count > 0 then begin
    for i := Count to TotalPoints-1 do Points[i-Count] := Points[i];
    Dec(TotalPoints, Count);
  end;
end;

{ TCurve }

constructor TCurve.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  AddLOD(TCurveMesh.Create(''));
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmOne, tfLESSEQUAL, tfAlways, 0, False, False);
  Order := 1000;
  CullMode := cmNone;
  DefaultSize := 20000; DefaultColor := $80808080; PointsToAdd := 0;
  TCurveMesh(CurrentLOD).AddPoint(GetVector3s(0, 0, 0), DefaultColor, DefaultSize);
  TCurveMesh(CurrentLOD).AddPoint(GetVector3s(1000, 0, 0), DefaultColor, DefaultSize);
end;

function TCurve.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Max points', ptInt32, Pointer(TCurveMesh(CurrentLOD).MaxPoints));
  NewProperty(Result, 'Points default color', ptColor32, Pointer(DefaultColor));
  NewProperty(Result, 'Points default size', ptSingle, Pointer(DefaultSize));
  NewProperty(Result, 'U scale', ptSingle, Pointer(TCurveMesh(CurrentLOD).UScale));
end;

function TCurve.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  TCurveMesh(CurrentLOD).MaxPoints := Integer(GetPropertyValue(AProperties, 'Max points'));
  DefaultColor := Longword(GetPropertyValue(AProperties, 'Points default color'));
  DefaultSize := Single(GetPropertyValue(AProperties, 'Points default size'));
  TCurveMesh(CurrentLOD).UScale := Single(GetPropertyValue(AProperties, 'U scale'));

  Result := Result + 2;
end;

function TCurve.Process: Boolean;
var i: Integer; Mesh: TCurveMesh;
begin
  Result := inherited Process;
  Mesh := CurrentLOD as TCurveMesh;
  i := 0;
  while (i < Mesh.TotalPoints) and (Mesh.Points[i].Size < 1) do Inc(i);
  Mesh.DeletePoints(i);
  for i := 0 to PointsToAdd-1 do Mesh.AddPoint(GetVector3s(0, 0, 0), DefaultColor, DefaultSize);
end;

procedure TCurve.SetupExternalVariables;
begin
  inherited;
{$IFDEF SCRIPTING}
  World.Compiler.ImportExternalVar('DefaultColor', 'LONGINT', @DefaultColor);
  World.Compiler.ImportExternalVar('DefaultSize', 'REAL', @DefaultSize);
  World.Compiler.ImportExternalVar('TotalPoints', 'LONGINT', @TCurveMesh(CurrentLOD).TotalPoints);
  World.Compiler.ImportExternalVar('Points', 'TCurvePoints', @TCurveMesh(CurrentLOD).Points[0]);
  World.Compiler.ImportExternalVar('PointsToAdd', 'LONGINT', @PointsToAdd);
{$ENDIF}
end;

end.
