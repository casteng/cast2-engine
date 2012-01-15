(*
 @Abstract(CAST II Engine tile maps unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains tilemap implementation classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2TileMaps;

interface

uses
  Logger, 
  BaseMsg, Models,
  {$IFDEF EDITORMODE} BaseGraph, C2MapEditMsg, {$ENDIF}
  SysUtils,
  BaseTypes, Basics, Props, BaseClasses, Resources, Base3D,
  C2Types, C2Maps, CAST2, C2Visual,

  C2Land;

const
  MinLightsCount = 8;
  MaxVisibleWidth = 64;
  MaxVisibleHeight = 64;

type
  TTileMapLight = record
    Light: TLight;                  // Light source
    LocalPos: TVector3s;            // Position of the light source in tile map's frame
  end;

  TTileMap = class;

  TTileMapEditOp = class(C2Maps.TMapEditOp)
  private
  public
    // Inits the operation and returns True if it's valid and can be applied
    function Init(AMap: TMap; ATileX, ATileY, ACursorSize, AValue: Integer; AAligned: Boolean): Boolean;
  end;

  TTileMapTesselator = class(C2Visual.TMappedTesselator)
  private
    // Params
    FUVMapRes:   Resources.TUVMapResource;

//    LightMaps: array of BaseTypes.PDWordBuffer;
    Phase: Single;

    RandomGen: Basics.TRandomGenerator;
    // Lighting
    Lights: array of TTileMapLight;                       // Active lights
    LightsActive: Integer;
    LightVectorSet: Boolean;
    LightVector: TVector3s;
  protected
    AttSeed: Integer;
    InvCellWidthScale, InvCellHeightScale: Single;
    procedure InitLightMaps; virtual;
    procedure ObtainVisibleRange(Camera: TCamera; var IMin, IMax, JMin, JMax: Integer); virtual;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure BeginLighting; override;
    function CalculateLighting(const ALight: TLight; const ALightToItem: TMatrix4s): Boolean; override;

    procedure SetMap(const Map: C2Maps.TMap); override;
    procedure Init; override;
    function GetMaxVertices: Integer; override;

    function TraceRay(Origin, Dir: TVector3s; out ISecPoint: TVector3s): Boolean;
    function ObtainTileAt(X, Y: Single; out TileX, TileY: Integer): Boolean; virtual;
    function GetTileCoords(TileX, TileY: Integer): TVector3s; virtual;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TFgTileMapTesselator = class(TTileMapTesselator)
  protected
    procedure InitLightMaps; override;
  public
//    procedure BeginLighting; override;
//    procedure CalculateLighting(const ALight: TLight; const ALightToItem: TMatrix4s); override;

    procedure Init; override;
    function GetMaxVertices: Integer; override;

    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TTileMap = class(TMappedItem)
  private
    {$IFDEF EDITORMODE}
    function CalcTile(Cursor: C2MapEditMsg.TMapCursor; Camera: TCamera; out TileX, TileY: Integer): Boolean;
    {$ENDIF}
  protected
    {$IFDEF EDITORMODE}
    function DrawCursor(Cursor: C2MapEditMsg.TMapCursor; Camera: TCamera; Screen: TScreen): Boolean; override;
    procedure ModifyBegin(Cursor: TMapCursor; Camera: TCamera); override;
    procedure Modify(Cursor: TMapCursor; Camera: TCamera); override;
    procedure ModifyEnd(Cursor: TMapCursor; Camera: TCamera); override;
    {$ENDIF}
    procedure ResolveLinks; override;
  public
    constructor Create(AManager: TItemsManager); override;
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: Float); override;

    function ObtainTileAt(X, Y: Single; out TileX, TileY: Integer): Boolean;
    function ObtainTileAtScreen(ScreenX, ScreenY: Integer; Camera: TCamera; out TileX, TileY: Integer): Boolean;
    function TraceMap(X, Y, DirX, DirY: Single; out TileX, TileY: Integer): Single;

    procedure HandleMessage(const Msg: TMessage); override;
  end;

  TFgTileMap = class(TTileMap)
  public
    function GetTesselatorClass: CTesselator; override;
    procedure HandleMessage(const Msg: TMessage); override;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TMap, TTileMap, TFgTileMap]);
end;

{ TileMapTesselator }

function TTileMapTesselator.TraceRay(Origin, Dir: TVector3s; out ISecPoint: TVector3s): Boolean;
var d: Single;
begin
  Result := False;
  if Abs(Dir.Z) > epsilon then begin
    ISecPoint.Z := 0;
    d := (Origin.Z - ISecPoint.Z) / Dir.Z;
    ISecPoint.X := Origin.X - Dir.X * d;
    ISecPoint.Y := Origin.Y - Dir.Y * d;
    Result := True;
  end;
end;

function TTileMapTesselator.ObtainTileAt(X, Y: Single; out TileX, TileY: Integer): Boolean;
begin
  Result := False;
  if not Assigned(FMap) then Exit;

  TileX := Round((FMap.Width)*0.5  + X / FMap.CellWidthScale)-1;
  TileY := Round((FMap.Height)*0.5 - Y / FMap.CellHeightScale)-1;

  Result := (TileX >= 0) and (TileY >= 0) and (TileX < FMap.Width) and (TileY < FMap.Height);
end;

function TTileMapTesselator.GetTileCoords(TileX, TileY: Integer): TVector3s;
begin
  Result := GetVector3s((TileX - (FMap.Width-1)*0.5) * FMap.CellWidthScale, ((FMap.Height-1)*0.5 - TileY) * FMap.CellHeightScale, 0);
end;

procedure TTileMapTesselator.InitLightMaps;
begin
//  SetLength(LightMaps, 1);
//  ReallocMem(LightMaps[0], FMap.Width * FMap.Height * 4);
end;

procedure TTileMapTesselator.ObtainVisibleRange(Camera: TCamera; var IMin, IMax, JMin, JMax: Integer);
var Origin, Vec: TVector3s; IMins, IMaxs, JMins, JMaxs: Single;

function GetFrustumRay(XSign, YSign: Single): TVector3s;
begin
  Result.X := XSign * Cos(pi/2 - Camera.HFoV/2);
  Result.Y := YSign * Cos(pi/2 - Camera.HFoV/2)/Camera.CurrentAspectRatio;
  Result.Z := Sin(pi/2 - Camera.HFoV/2);

  {  d := 0.5*Camera.ScreenWidth / Sin(Camera.HFoV*pi/180/2)*Cos(Camera.HFoV*pi/180/2);
  Ray.X := 0.5*Camera.ScreenWidth;
  Ray.Y := (0.5*Camera.ScreenHeight)*Camera.ScreenWidth/Camera.ScreenHeight/Camera.CurrentAspectRatio;
  Ray.Z := d;}

  Result := Transform3Vector3s(InvertMatrix3s(CutMatrix3s(Camera.ViewMatrix)), Result);

  Result := Transform3Vector3s(InvertMatrix3s(CutMatrix3s(Item.Transform)), Result);
end;

begin
  Origin := Transform4Vector33s(InvertMatrix4s(Item.Transform), Camera.GetAbsLocation);

  IMin := 0;
  JMin := 0;
  IMax := FMap.Width-1;
  JMax := FMap.Height-1;

  if TraceRay(Origin, GetFrustumRay(1, 1), Vec) then begin
    IMins :=  Vec.X; IMaxs :=  Vec.X;
    JMins := -Vec.Y; JMaxs := -Vec.Y;

    if TraceRay(Origin, GetFrustumRay(-1, 1), Vec) then begin
      IMins := MinS(IMins,  Vec.X);
      IMaxs := MaxS(IMaxs,  Vec.X);
      JMins := MinS(JMins, -Vec.Y);
      JMaxs := MaxS(JMaxs, -Vec.Y);

      if TraceRay(Origin, GetFrustumRay(1, -1), Vec) then begin
        IMins := MinS(IMins,  Vec.X);
        IMaxs := MaxS(IMaxs,  Vec.X);
        JMins := MinS(JMins, -Vec.Y);
        JMaxs := MaxS(JMaxs, -Vec.Y);

        if TraceRay(Origin, GetFrustumRay(-1, -1), Vec) then begin
          IMins := MinS(IMins,  Vec.X);
          IMaxs := MaxS(IMaxs,  Vec.X);
          JMins := MinS(JMins, -Vec.Y);
          JMaxs := MaxS(JMaxs, -Vec.Y);

          IMin := Round(MinS(FMap.Width-1,  MaxS(0, FMap.Width*0.5  + IMins / FMap.CellWidthScale-2)));
          IMax := Round(MinS(FMap.Width-1,  MaxS(0, FMap.Width*0.5  + IMaxs / FMap.CellWidthScale)));
          JMin := Round(MinS(FMap.Height-1, MaxS(0, FMap.Height*0.5 + JMins / FMap.CellHeightScale-2)));
          JMax := Round(MinS(FMap.Height-1, MaxS(0, FMap.Height*0.5 + JMaxs / FMap.CellHeightScale)));
        end;
      end;
    end;
  end;
//  IMin := Round(IMins / FMap.CellWidthScale);
//  JMin := Round(JMins / FMap.CellHeightScale);
end;

constructor TTileMapTesselator.Create;
begin
  inherited;
  SetLength(Lights, MinLightsCount);
  RandomGen := Basics.TRandomGenerator.Create;
  Phase := Random*pi;
end;

destructor TTileMapTesselator.Destroy;
begin
  FreeAndNil(RandomGen);
  Lights := nil;
  inherited;
end;

procedure TTileMapTesselator.BeginLighting;
begin
//  FillDWord(LightMaps[0]^, FMap.Width * FMap.Height, 0*$20202020);
  LightVectorSet := False;
  LightsActive := 0;
end;

const BlinkFactor = 0.1;

function TTileMapTesselator.CalculateLighting(const ALight: TLight; const ALightToItem: TMatrix4s): Boolean;
begin
  Result := True;
  if Length(Lights) <= LightsActive then SetLength(Lights, Length(Lights)+1);
  Lights[LightsActive].Light       := ALight;
  Transform4Vector33s(Lights[LightsActive].LocalPos, ALightToItem, ZeroVector3s);
  Inc(LightsActive);

  if not LightVectorSet and (ALight.Kind = ltPoint) then begin
    LightVector := ALight.GetAbsLocation;
    LightVectorSet := True;
  end;
end;

procedure TTileMapTesselator.SetMap(const Map: C2Maps.TMap);
begin
  FMap := Map;
end;

procedure TTileMapTesselator.Init;
begin
  inherited;

  TesselationStatus[tbVertex].TesselatorType := ttDynamic;

  if Assigned(FMap) then begin
    OldWidth           := FMap.Width;
    OldHeight          := FMap.Height;
    
    TotalVertices   := MaxI(0, (FMap.Width-1) * (FMap.Height-1) * 6);
    TotalPrimitives := MaxI(0, (FMap.Width-1) * (FMap.Height-1) * 2);
    InvCellWidthScale  := 1/FMap.CellWidthScale;
    InvCellHeightScale := 1/FMap.CellHeightScale;

    InitLightMaps;
  end else begin
    TotalVertices   := 0;
    TotalPrimitives := 0;
  end;
  PrimitiveType    := ptTRIANGLELIST;
  InitVertexFormat(GetVertexFormat(False, False, True, True, False, 0, [2]));
end;

function TTileMapTesselator.GetMaxVertices: Integer;
begin
  Result := (MaxVisibleWidth) * (MaxVisibleHeight) * 6;
  if (FMap.Width <> OldWidth) or (FMap.Height <> OldHeight) then Init;
end;

const Radius = 5;

function TTileMapTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  i, j, TileCount, Tile: Integer;
  HalfWidth, HalfHeight: Single;
  UVMap: TUVMap; UVMapLen: Integer;
  IMin, IMax, JMin, JMax: Integer;
  Ang: Single;
  FormFactor: TVector3s;

function GetLitColorD(const Point: TVector3s): TColor;
var
  i: Integer; v: TVector3s; Dist: Single; Color: TColor4s;
begin
  Color := GetColor4S(0, 0, 0, 0);

  for i := 0 to LightsActive-1 do begin
    SubVector3s(v, Point, Lights[i].LocalPos);
    if SqrMagnitude(v) > Sqr(Lights[i].Light.Range) then Continue;
//    Dist := v.Z / SqrMagnitude(v);

    Dist := Sqrt(( Sqr(v.X*FormFactor.X) + Sqr(v.Y*FormFactor.Y) ) / Sqr(Lights[i].Light.Range * FormFactor.Z));

    if Dist < 1 then AddVector4s(Color.RGBA, Color.RGBA, ScaleVector4s(Lights[i].Light.Diffuse.RGBA, 1-Dist));
  end;
  Result := GetColorFrom4s(Color);
end;

function GetLitColorS(const Point: TVector3s): TColor;
var i: Integer; v, LightDir: TVector3s; Dist, Weight: Single;
begin
  Result.C := $FF808080;
  if LightsActive = 0 then Exit;
  Weight := 0;
  LightDir := GetVector3s(0, 0, 0);
  for i := 0 to LightsActive-1 do begin
    SubVector3s(v, Point, Lights[i].LocalPos);
    Dist := SqrMagnitude(v);
    if Dist > Sqr(Lights[i].Light.Range) then Continue;

    Dist :=
    1 - Dist/Sqr(Lights[i].Light.Range);
//    AddVector3s(LightDir, LightDir, NormalizeVector3s(GetVector3s(-v.X * Dist, -v.Y * Dist, Dist * (2+v.Z))));
    AddVector3s(LightDir, LightDir, GetVector3s(-v.X * Dist, -v.Y * Dist, Dist * v.Z));
    Weight := Weight + Dist;
  end;
  if Weight = 0 then Exit;

  LightDir := NormalizeVector3s(GetVector3s(LightDir.X/Weight, LightDir.Y/Weight, 2+LightDir.Z/Weight));
  Result := VectorToColor(ScaleVector3s(LightDir, 1+0*Result.R/255));
end;

var v: TVector3s;

begin
  Result := 0;
  if not Assigned(FUVMapRes) or (FUVMapRes.TotalElements = 0) or
     not Assigned(FMap) or (FMap.Width = 0) or (FMap.Height = 0) or (FMap.Data = nil) then Exit;

  UVMap    := FUVMapRes.Data;
  UVMapLen := FUVMapRes.TotalElements;

  HalfWidth  := (FMap.Width-1)  * FMap.CellWidthScale  * 0.5;
  HalfHeight := (FMap.Height-1) * FMap.CellHeightScale * 0.5;

  // Form factor for torch light blinking imitation
  Ang := (AttSeed+Phase)*DegToRad;
  FormFactor.X := (1+BlinkFactor)+(BlinkFactor*Sin(Ang));
  FormFactor.Y := (1+BlinkFactor)+(BlinkFactor*Cos(Ang));
  FormFactor.Z := 1;//(1+BlinkFactor)+(BlinkFactor*Sin(((AttSeed+Phase)+90)*DegToRad*1));

  TileCount := 0;

  ObtainVisibleRange(Params.Camera, IMin, IMax, JMin, JMax);
  if IMax - IMin > MaxVisibleWidth  then IMax := IMin + MaxVisibleWidth;
  if JMax - JMin > MaxVisibleHeight then JMax := JMin + MaxVisibleHeight;

  for i := IMin to IMax-1 do begin
    for j := JMin to JMax-1 do begin

      Tile := MinI(FMap[i, j], UVMapLen)-1;
      if Tile >= 0 then begin
        v := GetVector3s(i * FMap.CellWidthScale - HalfWidth, -j * FMap.CellHeightScale + HalfHeight, 0);
        SetVertexDataC(v, TileCount*6, VBPTR);
        SetVertexDataD(GetLitColorD(v), TileCount*6, VBPTR);
        SetVertexDataS(GetLitColorS(v), TileCount*6, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U, UVMap^[Tile].V, TileCount*6, VBPTR);

        v := GetVector3s((i+1) * FMap.CellWidthScale - HalfWidth, -(j+0) * FMap.CellHeightScale + HalfHeight, 0);
        SetVertexDataC(v, TileCount*6+1, VBPTR);
        SetVertexDataD(GetLitColorD(v), TileCount*6+1, VBPTR);
        SetVertexDataS(GetLitColorS(v), TileCount*6+1, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U + UVMap^[Tile].W, UVMap^[Tile].V, TileCount*6+1, VBPTR);

        SetVertexDataC(v, TileCount*6+4, VBPTR);
        SetVertexDataD(GetLitColorD(v), TileCount*6+4, VBPTR);
        SetVertexDataS(GetLitColorS(v), TileCount*6+4, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U + UVMap^[Tile].W, UVMap^[Tile].V, TileCount*6+4, VBPTR);

        v := GetVector3s((i+0) * FMap.CellWidthScale - HalfWidth, -(j+1) * FMap.CellHeightScale + HalfHeight, 0);
        SetVertexDataC(v, TileCount*6+2, VBPTR);
        SetVertexDataD(GetLitColorD(v), TileCount*6+2, VBPTR);
        SetVertexDataS(GetLitColorS(v), TileCount*6+2, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U, UVMap^[Tile].V + UVMap^[Tile].H, TileCount*6+2, VBPTR);

        SetVertexDataC(v, TileCount*6+3, VBPTR);
        SetVertexDataD(GetLitColorD(v), TileCount*6+3, VBPTR);
        SetVertexDataS(GetLitColorS(v), TileCount*6+3, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U, UVMap^[Tile].V + UVMap^[Tile].H, TileCount*6+3, VBPTR);

        v := GetVector3s((i+1) * FMap.CellWidthScale - HalfWidth, -(j+1) * FMap.CellHeightScale + HalfHeight, 0);
        SetVertexDataC(v, TileCount*6+5, VBPTR);
        SetVertexDataD(GetLitColorD(v), TileCount*6+5, VBPTR);
        SetVertexDataS(GetLitColorS(v), TileCount*6+5, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U + UVMap^[Tile].W, UVMap^[Tile].V + UVMap^[Tile].H, TileCount*6+5, VBPTR);

        Inc(TileCount);
      end;
    end;
  end;

//   Log(Format('Tiles rendered: %D', [TileCount])); 

  TesselationStatus[tbVertex].Status := tsChanged;
  Result            := TileCount*6;
  TotalPrimitives   := TileCount*2;
  TotalVertices     := Result;
  LastTotalVertices := TotalVertices;
end;

{ TFgTileMapTesselator }

procedure TFgTileMapTesselator.InitLightMaps;
begin
//  SetLength(LightMaps, 2);
//  ReallocMem(LightMaps[0], FMap.Width * FMap.Height * 4);
//  ReallocMem(LightMaps[1], FMap.Width * FMap.Height * 4);
end;

procedure TFgTileMapTesselator.Init;
begin
  inherited;
  if Assigned(FMap) then begin
    TotalVertices   := MaxI(0, (FMap.Width-1) * (FMap.Height-1) * 6)*2;
    TotalPrimitives := MaxI(0, (FMap.Width-1) * (FMap.Height-1) * 2)*2;
  end else begin
    TotalVertices   := 0;
    TotalPrimitives := 0;
  end;
  PrimitiveType    := ptTRIANGLELIST;                                            // TODO -cOptimization : Switch to strips
  InitVertexFormat(GetVertexFormat(False, False, True, True, False, 0, [2]));
end;

function TFgTileMapTesselator.GetMaxVertices: Integer;
begin
  Result := (MaxVisibleWidth) * (MaxVisibleHeight) * 6 * 2;
  if (FMap.Width <> OldWidth) or (FMap.Height <> OldHeight) then Init;
end;

function TFgTileMapTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  i, j, QuadCount, Tile: Integer;
  BlockExists: Boolean;
  HalfWidth, HalfHeight, Y: Single;
  UVMap: TUVMap; UVMapLen: Integer;
  IMin, IMax, JMin, JMax: Integer;

  Ang: Single;
  FormFactor: TVector3s;

  function GetLitColorD(const Point: TVector3s): TColor;
  var
    i: Integer; v: TVector3s; Dist: Single; Color: TColor4s;
  begin
    Color := GetColor4S(0, 0, 0, 0);

    for i := 0 to LightsActive-1 do begin
      SubVector3s(v, Point, Lights[i].LocalPos);
      if SqrMagnitude(v) > Sqr(Lights[i].Light.Range) then Continue;
//      Dist := v.Z / SqrMagnitude(v);

      Dist := Sqrt(( Sqr(v.X*FormFactor.X) + Sqr(v.Y*FormFactor.Y) ) / Sqr(Lights[i].Light.Range * FormFactor.Z));

      if Dist < 1 then AddVector4s(Color.RGBA, Color.RGBA, ScaleVector4s(Lights[i].Light.Diffuse.RGBA, 0.2*(1-Dist)));
  //    v := NormalizeVector3s(v);
    end;
    Result := GetColorFrom4s(Color);
  end;

  function GetLitColorS(const Point: TVector3s): TColor;
  var i, MinI: Integer; v: TVector3s; MinDist, Dist: Single;
  begin
    Result.C := $FF808080;
    MinI := -1;
    for i := 0 to LightsActive-1 do begin
      Dist := SqrMagnitude(SubVector3s(Point, Lights[i].LocalPos));
      if Dist > Sqr(Lights[i].Light.Range) then Continue;
      if (MinI = -1) or (Dist < MinDist) then begin
        MinDist := Dist;
        MinI := i;
      end;
    end;
    if MinI = -1 then Exit;
    SubVector3s(v, Point, Lights[MinI].LocalPos);
    v := NormalizeVector3s(GetVector3s(-v.X, v.Y, 1));
    Result := VectorToColor(ScaleVector3s(v, 1+0*Result.R/255));
  end;

  function GetLitColorTopD(Point: TVector3s): TColor;
  var
    i: Integer; v: TVector3s; Dist: Single; Color: TColor4s;
  begin
    Color := GetColor4S(0, 0, 0, 0);

    for i := 0 to LightsActive-1 do if Lights[i].LocalPos.Y - Point.Y > 0 then begin
      SubVector3s(v, Point, Lights[i].LocalPos);
      if SqrMagnitude(v) > Sqr(Lights[i].Light.Range) then Continue;
  //    Dist := v.Z / SqrMagnitude(v);

      Dist := Sqrt(( Sqr(v.X*FormFactor.X) + Sqr(v.Y*FormFactor.Y) ) / Sqr(Lights[i].Light.Range * FormFactor.Z));
  //    Dist := 1+v.Y/SqrMagnitude(v);

      if Dist < 1 then AddVector4s(Color.RGBA, Color.RGBA, ScaleVector4s(Lights[i].Light.Diffuse.RGBA, 1-Dist));
  //    v := NormalizeVector3s(v);
    end;
    Result := GetColorFrom4s(Color);
  end;

  function GetLitColorTopS(const Point: TVector3s): TColor;
  var i, MinI: Integer; v: TVector3s; MinDist, Dist: Single;
  begin
    Result.C := $FF808080;
    MinI := -1;
    for i := 0 to LightsActive-1 do if Lights[i].LocalPos.Y - Point.Y > 0 then begin
      Dist := SqrMagnitude(SubVector3s(Point, Lights[i].LocalPos));
      if Dist > Sqr(Lights[i].Light.Range) then Continue;
      if (MinI = -1) or (Dist < MinDist) then begin
        MinDist := Dist;
        MinI := i;
      end;
    end;
    if MinI = -1 then Exit;
    SubVector3s(v, Point, Lights[MinI].LocalPos);
    v := NormalizeVector3s(GetVector3s(-v.X, -v.y, 0.5));
    Result := VectorToColor(ScaleVector3s(v, 1+0*Result.R/255));
  end;

var v: TVector3s;

begin
  Result := 0;
  if not Assigned(FUVMapRes) or (FUVMapRes.TotalElements = 0) or
     not Assigned(FMap) or (FMap.Width = 0) or (FMap.Height = 0) or (FMap.Data = nil) then Exit;

  UVMap    := FUVMapRes.Data;
  UVMapLen := FUVMapRes.TotalElements;

  HalfWidth  := (FMap.Width-1)  * FMap.CellWidthScale  * 0.5;
  HalfHeight := (FMap.Height-1) * FMap.CellHeightScale * 0.5;

  // Form factor for torch light blinking imitation
  Ang := (AttSeed+Phase)*DegToRad;
  FormFactor.X := (1+BlinkFactor)+(BlinkFactor*Sin(Ang));
  FormFactor.Y := (1+BlinkFactor)+(BlinkFactor*Cos(Ang));
  FormFactor.Z := 1;//(1+BlinkFactor)+(BlinkFactor*Sin(((AttSeed+Phase)+90)*DegToRad*1));

  ObtainVisibleRange(Params.Camera, IMin, IMax, JMin, JMax);
  if IMax - IMin > MaxVisibleWidth  then IMax := IMin + MaxVisibleWidth;
  if JMax - JMin > MaxVisibleHeight then JMax := JMin + MaxVisibleHeight;

  QuadCount := 0;

  for i := IMin to IMax-1 do begin
    BlockExists := JMin <> 0;
    for j := JMin to JMax-1 do begin
      Tile := MinI(FMap[i, j]*3, UVMapLen)-3;

      if Tile >= 0 then begin
        if not BlockExists then begin                                                // Top surface
          Y := -j * FMap.CellHeightScale + HalfHeight;

          v := GetVector3s(i * FMap.CellWidthScale - HalfWidth, Y, 0);

          SetVertexDataC(v, QuadCount*6, VBPTR);
          SetVertexDataD(GetLitColorTopD(v), QuadCount*6, VBPTR);
          SetVertexDataS(GetLitColorTopS(v), QuadCount*6, VBPTR);
          SetVertexDataUV(UVMap^[Tile + 1].U, UVMap^[Tile + 1].V, QuadCount*6, VBPTR);

          v := GetVector3s((i+1) * FMap.CellWidthScale - HalfWidth, Y, 0);

          SetVertexDataC(v, QuadCount*6+1, VBPTR);
          SetVertexDataD(GetLitColorTopD(v), QuadCount*6+1, VBPTR);
          SetVertexDataS(GetLitColorTopS(v), QuadCount*6+1, VBPTR);
          SetVertexDataUV(UVMap^[Tile + 1].U + UVMap^[Tile + 1].W, UVMap^[Tile + 1].V, QuadCount*6+1, VBPTR);

          SetVertexDataC(v, QuadCount*6+4, VBPTR);
          SetVertexDataD(GetLitColorTopD(v), QuadCount*6+4, VBPTR);
          SetVertexDataS(GetLitColorTopS(v), QuadCount*6+4, VBPTR);
          SetVertexDataUV(UVMap^[Tile + 1].U + UVMap^[Tile + 1].W, UVMap^[Tile + 1].V, QuadCount*6+4, VBPTR);

          v := GetVector3s((i+0) * FMap.CellWidthScale - HalfWidth, Y, -FMap.DepthScale);

          SetVertexDataC(v, QuadCount*6+2, VBPTR);
          SetVertexDataD(GetLitColorTopD(v), QuadCount*6+2, VBPTR);
          SetVertexDataS(GetLitColorTopS(v), QuadCount*6+2, VBPTR);
          SetVertexDataUV(UVMap^[Tile + 1].U, UVMap^[Tile + 1].V + UVMap^[Tile + 1].H, QuadCount*6+2, VBPTR);

          SetVertexDataC(v, QuadCount*6+3, VBPTR);
          SetVertexDataD(GetLitColorTopD(v), QuadCount*6+3, VBPTR);
          SetVertexDataS(GetLitColorTopS(v), QuadCount*6+3, VBPTR);
          SetVertexDataUV(UVMap^[Tile + 1].U, UVMap^[Tile + 1].V + UVMap^[Tile + 1].H, QuadCount*6+3, VBPTR);

          v := GetVector3s((i+1) * FMap.CellWidthScale - HalfWidth, Y, -FMap.DepthScale);

          SetVertexDataC(v, QuadCount*6+5, VBPTR);
          SetVertexDataD(GetLitColorTopD(v), QuadCount*6+5, VBPTR);
          SetVertexDataS(GetLitColorTopS(v), QuadCount*6+5, VBPTR);
          SetVertexDataUV(UVMap^[Tile + 1].U + UVMap^[Tile + 1].W, UVMap^[Tile + 1].V + UVMap^[Tile + 1].H, QuadCount*6+5, VBPTR);

          Inc(QuadCount);
        end;

//        Color := $FF808080;
{         or MinI($FF, (Sqr(Round(IMin * FMap.CellWidthScale  - i * FMap.CellWidthScale)) +
                                         Sqr(Round(JMin * FMap.CellHeightScale - j * FMap.CellHeightScale))
        ));}

        v := GetVector3s(i * FMap.CellWidthScale - HalfWidth, -j * FMap.CellHeightScale + HalfHeight, -FMap.DepthScale);
        SetVertexDataC(v, QuadCount*6, VBPTR);
        SetVertexDataD(GetLitColorD(v), QuadCount*6, VBPTR);
        SetVertexDataS(GetLitColorS(v), QuadCount*6, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U, UVMap^[Tile].V, QuadCount*6, VBPTR);

        v := GetVector3s((i+1) * FMap.CellWidthScale - HalfWidth, -(j+0) * FMap.CellHeightScale + HalfHeight, -FMap.DepthScale);
        SetVertexDataC(v, QuadCount*6+1, VBPTR);
        SetVertexDataD(GetLitColorD(v), QuadCount*6+1, VBPTR);
        SetVertexDataS(GetLitColorS(v), QuadCount*6+1, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U + UVMap^[Tile].W, UVMap^[Tile].V, QuadCount*6+1, VBPTR);

        SetVertexDataC(v, QuadCount*6+4, VBPTR);
        SetVertexDataD(GetLitColorD(v), QuadCount*6+4, VBPTR);
        SetVertexDataS(GetLitColorS(v), QuadCount*6+4, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U + UVMap^[Tile].W, UVMap^[Tile].V, QuadCount*6+4, VBPTR);

        v := GetVector3s((i+0) * FMap.CellWidthScale - HalfWidth, -(j+1) * FMap.CellHeightScale + HalfHeight, -FMap.DepthScale);
        SetVertexDataC(v, QuadCount*6+2, VBPTR);
        SetVertexDataD(GetLitColorD(v), QuadCount*6+2, VBPTR);
        SetVertexDataS(GetLitColorS(v), QuadCount*6+2, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U, UVMap^[Tile].V + UVMap^[Tile].H, QuadCount*6+2, VBPTR);

        SetVertexDataC(v, QuadCount*6+3, VBPTR);
        SetVertexDataD(GetLitColorD(v), QuadCount*6+3, VBPTR);
        SetVertexDataS(GetLitColorS(v), QuadCount*6+3, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U, UVMap^[Tile].V + UVMap^[Tile].H, QuadCount*6+3, VBPTR);

        v := GetVector3s((i+1) * FMap.CellWidthScale - HalfWidth, -(j+1) * FMap.CellHeightScale + HalfHeight, -FMap.DepthScale);
        SetVertexDataC(v, QuadCount*6+5, VBPTR);
        SetVertexDataD(GetLitColorD(v), QuadCount*6+5, VBPTR);
        SetVertexDataS(GetLitColorS(v), QuadCount*6+5, VBPTR);
        SetVertexDataUV(UVMap^[Tile].U + UVMap^[Tile].W, UVMap^[Tile].V + UVMap^[Tile].H, QuadCount*6+5, VBPTR);

        Inc(QuadCount);

        BlockExists := True;
      end else BlockExists := False;
    end;
  end;

//   Log(Format('Quads rendered: %D', [QuadCount])); 

  TesselationStatus[tbVertex].Status := tsChanged;
  Result            := QuadCount*6;
  TotalPrimitives   := QuadCount*2;
  TotalVertices     := Result;
  LastTotalVertices := TotalVertices;
end;

{ TTileMap }

const UVMapPropName = 'UV Map';

{$IFDEF EDITORMODE}
function TTileMap.CalcTile(Cursor: TMapCursor; Camera: TCamera; out TileX, TileY: Integer): Boolean;
// Returns true if cursor points to a valid tile
var Point: TVector3s;
begin
  Result := Assigned(CurrentTesselator) and
            (CurrentTesselator as TTileMapTesselator).TraceRay(Transform4Vector33s(InvertMatrix4s(Transform), Camera.GetAbsLocation),
                                                        Camera.GetPickRayInWorld(Cursor.MouseX, Cursor.MouseY), Point) and
            (CurrentTesselator as TTileMapTesselator).ObtainTileAt(Point.X, Point.Y, TileX, TileY);
end;

function TTileMap.DrawCursor(Cursor: TMapCursor; Camera: TCamera; Screen: TScreen): Boolean;
var TileX, TileY, i, j, CursorSize: Integer; Point: TVector3s;
begin
  Result := False;

  if not CalcTile(Cursor, Camera, TileX, TileY) then Exit;

  CursorSize := ClampI(Cursor.Params.GetAsInteger('Size'), 1, MaxCursorSize);

  for i := MinI(FMap.Width-1, MaxI(0, TileX - CursorSize div 2)) to MinI(FMap.Width-1, MaxI(0, TileX - CursorSize div 2 + CursorSize-1)) do
    for j := MinI(FMap.Height-1, MaxI(0, TileY - CursorSize div 2)) to MinI(FMap.Height-1, MaxI(0, TileY - CursorSize div 2 + CursorSize-1)) do
      with (CurrentTesselator as TTileMapTesselator) do begin
        Point := Transform4Vector33s(Transform, GetTileCoords(i, j));
        Screen.MoveToVec(Camera.Project(Point).xyz);
        Point := Transform4Vector33s(Transform, GetTileCoords(i+1, j));
        Screen.LineToVec(Camera.Project(Point).xyz);
        Point := Transform4Vector33s(Transform, GetTileCoords(i+1, j+1));
        Screen.LineToVec(Camera.Project(Point).xyz);
        Point := Transform4Vector33s(Transform, GetTileCoords(i, j+1));
        Screen.LineToVec(Camera.Project(Point).xyz);
        Point := Transform4Vector33s(Transform, GetTileCoords(i, j));
        Screen.LineToVec(Camera.Project(Point).xyz);
    //    Screen.Bar(Transformed.X, Transformed.Y, Transformed.X+10, Transformed.Y+10);
      end;
  Result := True;
end;

procedure TTileMap.ModifyBegin(Cursor: TMapCursor; Camera: TCamera);
begin
  Modify(Cursor, Camera);
end;

procedure TTileMap.Modify(Cursor: TMapCursor; Camera: TCamera);
var Tilex, TileY: Integer; Op: TTileMapEditOp;
begin
  if (Cursor.MouseX = Cursor.LastEditMouseX) and (Cursor.MouseY = Cursor.LastEditMouseY) then Exit;
  if not CalcTile(Cursor, Camera, TileX, TileY) then Exit;
  if (FMap as THeightMap).Data = nil then Exit;

  Op := TTileMapEditOp.Create;
  if Op.Init(FMap, TileX, TileY, ClampI(Cursor.Params.GetAsInteger('Size'), 1, MaxCursorSize), Cursor.Value, Cursor.Aligned) then begin
    Cursor.Operation := Op;
  end else Op.Free;
end;

procedure TTileMap.ModifyEnd(Cursor: TMapCursor; Camera: TCamera);
begin
//  Modify(Cursor, Camera);
end;

{$ENDIF}

procedure TTileMap.ResolveLinks;
var Item: TItem;
begin
  inherited;

  if CurrentTesselator is TTileMapTesselator then begin
    ResolveLink(UVMapPropName, Item);
    if Assigned(Item) then begin
      (CurrentTesselator as TTileMapTesselator).FUVMapRes := (Item as TUVMapResource);
      CurrentTesselator.Init;
      if Assigned((CurrentTesselator as TTileMapTesselator).FMap) then with (CurrentTesselator as TTileMapTesselator).FMap do begin
        BoundingBox.P1 := GetVector3s(-Width * CellWidthScale * 0.5, -Height * CellHeightScale * 0.5, -DepthScale);
        BoundingBox.P2 := GetVector3s( Width * CellWidthScale * 0.5,  Height * CellHeightScale * 0.5,  0);
      end else begin
        BoundingBox.P1 := GetVector3s(0, 0, 0);
        BoundingBox.P2 := GetVector3s(0, 0, 0);
      end;
    end;
  end;
end;

constructor TTileMap.Create(AManager: TItemsManager);
begin
  FCustomLighting := True;
  inherited;
end;

function TTileMap.GetTesselatorClass: CTesselator; begin Result := TTileMapTesselator; end;

procedure TTileMap.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if Assigned(Result) then begin
  end;

  AddItemLink(Result, UVMapPropName, [], 'TUVMapResource');
end;

procedure TTileMap.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid(UVMapPropName) then SetLinkProperty(UVMapPropName, Properties[UVMapPropName]);

  ResolveLinks;
end;

procedure TTileMap.HandleMessage(const Msg: TMessage);
begin
  inherited;
  {$IFDEF EDITORMODE}
{  if Msg.ClassType = TMapDrawCursorMsg then with TMapDrawCursorMsg(Msg) do DrawCursor(Cursor, Cursor.Camera, Cursor.Screen);
  if (Msg.ClassType = TMapModifyBeginMsg) or (Msg.ClassType = TMapModifyMsg) then with TMapEditorMessage(Msg) do Modify(Cursor, Cursor.Camera);}

  if Msg.ClassType = TRequestMapEditVisuals then with TRequestMapEditVisuals(Msg) do begin
    if Assigned(CurTechnique) and Assigned(CurTechnique.Passes[0]) then
      CurTechnique.Passes[0].ObtainLinkedItemName('Stage #0\Texture', Cursor.MainTextureName);
    ObtainLinkedItemName(UVMapPropName, Cursor.UVMapName);
    Cursor.UVMapStep := 1;
  end;
  {$ENDIF}
end;

function TTileMap.ObtainTileAt(X, Y: Single; out TileX, TileY: Integer): Boolean;
begin
  Result := (CurrentTesselator is TTileMapTesselator) and TTileMapTesselator(CurrentTesselator).ObtainTileAt(X, Y, TileX, TileY);
end;

function TTileMap.ObtainTileAtScreen(ScreenX, ScreenY: Integer; Camera: TCamera; out TileX, TileY: Integer): Boolean;
var Point: TVector3s;
begin
  Result := Assigned(CurrentTesselator) and
            (CurrentTesselator as TTileMapTesselator).TraceRay(Transform4Vector33s(InvertMatrix4s(Transform), Camera.GetAbsLocation),
                                                        Camera.GetPickRayInWorld(ScreenX, ScreenY), Point) and
            (CurrentTesselator as TTileMapTesselator).ObtainTileAt(Point.X, Point.Y, TileX, TileY);
end;

function TTileMap.TraceMap(X, Y, DirX, DirY: Single; out TileX, TileY: Integer): Single;
// Traces ray to next tile and returns squared distance to it
var Ofs: TVector3s;
begin
  Result := 0;
  if not (CurrentTesselator is TTileMapTesselator) or not TTileMapTesselator(CurrentTesselator).ObtainTileAt(X, Y, TileX, TileY) then Exit;
  if Sqr(DirX) + Sqr(DirY) < epsilon then Exit;

  Ofs := TTileMapTesselator(CurrentTesselator).GetTileCoords(TileX, TileY);

  Ofs.X := X - Ofs.X;
  Ofs.Y := Ofs.Y - Y;

  Assert((Ofs.X >= 0) and (Ofs.Y >= 0), Format('%F / %F', [Ofs.X, Ofs.Y]));

  if (Abs(DirX) < epsilon) then begin                    // up/down case
    Inc(TileY, 1-Ord(DirY > 0)*2);
    if DirY > 0 then Result := Ofs.Y else Result := FMap.CellHeightScale - Ofs.Y;
  end;
  if (Abs(DirY) < epsilon) then begin                    // left/cight case
    Inc(TileX, Ord(DirX > 0)*2-1);
    if DirX > 0 then Result := Ofs.X else Result := FMap.CellWidthScale - Ofs.X;
  end;

{  TileX := Round((FMap.Width)*0.5  + X / FMap.CellWidthScale)-1;
  TileY := Round((FMap.Height)*0.5 - Y / FMap.CellHeightScale)-1;

  Result := (TileX >= 0) and (TileY >= 0) and (TileX < FMap.Width) and (TileY < FMap.Height);}
end;

procedure TTileMap.Process(const DeltaT: Float);
begin
  inherited;
  if not (CurrentTesselator is TTileMapTesselator) then Exit;
  Inc(TTileMapTesselator(CurrentTesselator).AttSeed, 30+Random(30));
//  TTileMapTesselator(CurrentTesselator).RandomGen.InitSequence(1, Round(TimeProcessed));
end;

{ TFgTileMap }

function TFgTileMap.GetTesselatorClass: CTesselator; begin Result := TFgTileMapTesselator; end;

procedure TFgTileMap.HandleMessage(const Msg: TMessage);
begin
  inherited;
  {$IFDEF EDITORMODE}
  if Msg.ClassType = TRequestMapEditVisuals then with TRequestMapEditVisuals(Msg) do Cursor.UVMapStep := 3;
  {$ENDIF}
end;

{ TTileMapEditOp }

function TTileMapEditOp.Init(AMap: TMap; ATileX, ATileY, ACursorSize, AValue: Integer; AAligned: Boolean): Boolean;
var i, j, Value1, Value2, StartI, StartJ: Integer;

  function GetValue(LX, LY: Integer): Integer;
  begin
    if AAligned then
      Result := AValue + (LX mod CursorSize) + (LY mod CursorSize) * CursorSize else
        Result := Value2;
  end;

begin
  Result := False;
  if (ACursorSize = 0) or not Assigned(AMap) then Exit;
  Map        := AMap;
  CellX      := ATileX;
  CellZ      := ATileY;
  CursorSize := ACursorSize;
  GetMem(Buffer, CursorSize * CursorSize * Map.ElementSize);
  Result := True;

  Value1 := AValue;

  StartI := MaxI(0, CellX - CursorSize div 2);
  StartJ := MaxI(0, CellZ - CursorSize div 2);

  for j := StartJ to MinI(Map.Height-1, CellZ - CursorSize div 2 + CursorSize-1) do begin
    Value2 := Value1;
    for i := StartI to MinI(Map.Width-1, CellX - CursorSize div 2 + CursorSize-1) do begin
      case Map.ElementSize of
        1:  PByteBuffer(Buffer)^[(j-StartJ)* CursorSize + i - StartI] := Byte(GetValue(i, j));
        2:  PWordBuffer(Buffer)^[(j-StartJ)* CursorSize + i - StartI] := Word(GetValue(i, j));
        4: PDWordBuffer(Buffer)^[(j-StartJ)* CursorSize + i - StartI] := Cardinal(GetValue(i, j));
      end;
//      Inc(Value2);
    end;
    Inc(Value1, CursorSize);
  end;
end;

begin
  GlobalClassList.Add('C2TileMaps', GetUnitClassList);
end.
