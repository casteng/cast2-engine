{$Include GDefines}
{$Include CDefines}
// Lighting may be incorrect
unit CMaps;

interface

uses CTypes, Basics, Base3D;

const
  MapFileSign = Ord(':') shl 24 + Ord('P') shl 16 + Ord('A') shl 8 + Ord('M');
  OffsH = 0; OffsB = 2; OffsG = 3; OffsR = 4; OffsNZ = 5; OffsNY = 6; OffsNX = 7;
type
  PWordBuffer = ^TWordBuffer;

  TMapFileHeader = packed record
    Sign: Cardinal;
    HeightSize, ColorSize: Word;
    Res1, Res2: Cardinal;
    Width, Height: Word;
    Res3: Cardinal;
  end;

  CMap = class of TMap;
  TMap = class
    MinHeight: Integer;           // Minimal height. If height is lower than minimal, landscape is missing at given point
    BreakHeight: Single;
    Map: array of THCNMapCell;
    MapWidth, MapHeight, MapPower, TileSize, TilePower, HeightPower: Integer;
    MapHalfWidth, MapHalfHeight: Single;
    AmbientColor: TColorB;
    DirLight: TIntLight;
//    Lights: array of TLight;
//    CalcQueue: TCalcQueue;
    LightFront: array of record
      Position: SmallInt;
      Height, Iteration: Byte;
    end;
    CLLine: Cardinal;
    CellsLit, LightSpeed: Cardinal;
    Tiled: Boolean;
    constructor Create(DimX, DimZ, ATileSize: Integer); virtual;
    function LoadMap(Filename: TFilename): Boolean; virtual; abstract;
    function SaveMap(Filename: TFilename): Boolean; virtual; abstract;
    procedure InitLighting(Area: TArea); virtual; abstract;
    procedure SetGlobalLights(Ambient: TColorB; ADirLight: TLight); virtual;

    function GetCellColor(XI, ZI: Integer): Longword; virtual; abstract;
    function GetCellHeight(XI, ZI: Integer): Integer; virtual; abstract;
    function GetColor(X, Z: Single): Longword; virtual; abstract;
    function GetHeight(X, Z: Single): Integer; virtual; abstract;
    function GetCellNormal(XI,ZI : Integer): TSMIntVector3; virtual; abstract;
    function GetNormal(X,Z: Single): TVector3s; virtual; abstract;
    procedure CalcNormals(Area: TArea); virtual; abstract;

    procedure ClearItemHMap(X, Y, Width, Height, Angle: Integer); virtual; abstract;
    procedure ApplyItemHMap(X, Y, Width, Height, Angle: Integer; LHMap: PByteBuffer); virtual; abstract;
    function CalcRay(Ray, K: Integer): Integer; virtual; abstract;
    procedure CalcDirLocal(Area: TArea); virtual; abstract;
    procedure AddCalcArea(Area: TArea; MaxHeight, K: Integer); virtual; abstract;
    procedure ProcessCalcArea(Camera: TCamera); virtual; abstract;
    procedure ReCalcAll(Camera: TCamera); virtual; abstract;

    function LightToInt(Light: TLight): TIntLight; virtual;
    procedure CalcLight(var ALight: TLight); virtual; abstract;
    procedure DelLight(Light: TIntLight); virtual; abstract;
    procedure CopyLitToDir(Area: TArea); virtual; abstract;

    destructor Free; virtual; abstract;
  private
    procedure GetRGBColor(XI, ZI: Integer; var A, R, G, B: Byte); virtual; abstract;
    procedure SetRGBColor(XI, ZI: Integer; A, R, G, B: Byte); virtual; abstract;
  end;

  THCNMap = class(TMap)
//    Map: array of THCNMapCell;
    DirMap, LitMap: array of packed record B, G, R, H: Byte; end;
    constructor Create(DimX, DimZ, ATileSize: Integer); override;
    function LoadMap(Filename: TFilename): Boolean; override;
    function SaveMap(Filename: TFilename): Boolean; override;
    procedure InitLighting(Area: TArea); override;

    function GetCellColor(XI, ZI: Integer): Longword; override;
    function GetCellHeight(XI, ZI: Integer): Integer; override;
    function GetColor(X, Z: Single): Longword; override;
    function GetHeight(X, Z: Single): Integer; override;
    function GetCellNormal(XI,ZI : Integer): TSMIntVector3; override;
    function GetNormal(X,Z: Single): TVector3s; override;
    procedure CalcNormals(Area: TArea); override;

    procedure ClearItemHMap(X, Y, Width, Height, Angle: Integer); override;
    procedure ApplyItemHMap(X, Y, Width, Height, Angle: Integer; LHMap: PByteBuffer); override;
    function CalcRay(Ray, K: Integer): Integer; override;
    procedure CalcDirLocal(Area: TArea); override;
    procedure AddCalcArea(Area: TArea; MaxHeight, K: Integer); override;
    procedure ProcessCalcArea(Camera: TCamera); override;
    procedure ReCalcAll(Camera: TCamera); override;

    procedure CalcLight(var ALight: TLight); override;
    procedure DelLight(Light: TIntLight); override;
    procedure CopyLitToDir(Area: TArea); override;

    procedure MakeCrater(const X, Z: Single; const Radius: Integer); virtual;
    procedure MakeCraterEx(X, Y, Z: Single; const Radius: Integer; const Depth, Scorch: Single; const Smooth: Boolean); virtual;
    destructor Free; override;
  private
    procedure GetRGBColor(XI, ZI: Integer; var A, R, G, B: Byte); override;
    procedure SetRGBColor(XI, ZI: Integer; A, R, G, B: Byte); override;
  end;

implementation

{ TMap }

procedure TMap.SetGlobalLights(Ambient: TColorB; ADirLight: TLight);
begin
  AmbientColor := Ambient;
  if ADirLight.LightType <> ltDirectional then Exit;
  DirLight := LightToInt(ADirLight);
  InitLighting(GetArea(0, 0, MapWidth-1, MapHeight-1));
end;

function TMap.LightToInt(Light: TLight): TIntLight;
var MaxI: Integer;
begin
  Result.LightType := Light.LightType;
  Result.LightOn := Light.LightOn;
  Result.R := Trunc(0.5 + Light.Diffuse.R * 255);
  Result.G := Trunc(0.5 + Light.Diffuse.G * 255);
  Result.B := Trunc(0.5 + Light.Diffuse.B * 255);
  Result.E := 1;
  Result.IntensityMap := nil;
  case Result.LightType of
    ltDirectional: begin
      Result.Direction := GetSmIntVector3(Trunc(0.5 + Light.Direction.X*127), Trunc(0.5 + Light.Direction.Y*127), Trunc(0.5 + Light.Direction.Z*127));
      Result.R1 := 0; Result.R2 := 0; Result.R3 := 0;
      Result.Range := Trunc(0.5 + Light.Range);
    end;
    else begin
      Result.Location := GetIntVector3(Trunc(0.5 + Light.Location.X), Trunc(0.5 + Light.Location.Y), Trunc(0.5 + Light.Location.Z));
      Result.OldLocation := GetIntVector3(Trunc(0.5 + Light.OldLocation.X), Trunc(0.5 + Light.OldLocation.Y), Trunc(0.5 + Light.OldLocation.Z));
// Calculate range based on brightness of light source
      MaxI := Result.R;
      if Result.G > MaxI then MaxI := Result.G;
      if Result.B > MaxI then MaxI := Result.B;
      Result.Range := MaxI * TileSize div 4;
    end;
  end;
  Result.RangeSQ := Result.Range*Result.Range;
end;

constructor TMap.Create(DimX, DimZ, ATileSize: Integer);
begin
  MapWidth := DimX;
  MapPower := 0;
  while MapWidth > 1 do begin               // Calculate which power of to is MapWidth
    MapWidth := MapWidth div 2;
    Inc(MapPower);
  end;
  TileSize := ATileSize;
  TilePower := 0;
  while TileSize > 1 do begin               // Calculate which power of to is TileSize
    TileSize := TileSize div 2;
    Inc(TilePower);
  end;
  MapWidth := DimX; MapHeight := DimZ; TileSize := ATileSize;

  MapHalfWidth := MapWidth * TileSize * 0.5;
  MapHalfHeight := MapHeight * TileSize * 0.5;
  SetLength(Map, MapWidth * MapHeight);
  SetLength(LightFront, MapHeight);
  LightSpeed := MapWidth*2*4*2;
  HeightPower := 6;
  MinHeight := 0;
  BreakHeight := 1000;
end;

{ THCNMap }

constructor THCNMap.Create(DimX, DimZ, ATileSize: Integer);
begin
  inherited;
  SetLength(LitMap, MapWidth * MapHeight);
  SetLength(DirMap, MapWidth * MapHeight);
end;

function THCNMap.LoadMap(Filename: TFilename): Boolean;
var
  f: file;
  Header: TMapFileHeader;
  i, j: Integer;
begin
  Result := False;
  AssignFile(f, FileName);
  try
    Reset(f, 1);
  except
    Exit;
  end;
  try
    BlockRead(f, Header, SizeOf(Header));

    if (Header.Width <> MapWidth) or (Header.Height <> MapHeight) then Create(Header.Width, Header.Height, TileSize);

    with Header do if (Sign <> MapFileSign) or (HeightSize = 0) or (ColorSize = 0) then Exit;

    BlockRead(f, LitMap[0], Header.Width*Header.Height*4);
    for j:=0 to Header.Height - 1 do for i:=0 to Header.Width - 1 do begin
//      Map[j shl MapPower + i].Height := LitMap[j shl MapPower + i].H;
      Map[j shl MapPower + i].R := LitMap[j shl MapPower + i].R;
      Map[j shl MapPower + i].G := LitMap[j shl MapPower + i].G;
      Map[j shl MapPower + i].B := LitMap[j shl MapPower + i].B;
      DirMap[j shl MapPower + i] := LitMap[j shl MapPower + i];
//      DirMap[j shl MapPower + i].H := LitMap[j shl MapPower + i].H;
    end;
    Result := True;
  finally
    CloseFile(f);
  end;
end;

function THCNMap.SaveMap(Filename: TFilename): Boolean;
var
  f: file;
  Header: TMapFileHeader;
  i, j: Integer;
begin
  Result := False;
  with Header do begin
    Sign := MapFileSign;
    HeightSize := 2; ColorSize := 4;
    Width := MapWidth; Height := MapHeight;
  end;
  AssignFile(f, FileName);
  try
    Rewrite(f, 1);
  except
    Exit;
  end;
  try
    BlockWrite(f, Header, SizeOf(Header));
    for j:=0 to Header.Height - 1 do for i:=0 to Header.Width - 1 do begin
//      LitMap[j shl MapPower + i].H := Map[j shl MapPower + i].Height;
      LitMap[j shl MapPower + i].R := Map[j shl MapPower + i].R;
      LitMap[j shl MapPower + i].G := Map[j shl MapPower + i].G;
      LitMap[j shl MapPower + i].B := Map[j shl MapPower + i].B;
    end;
    BlockWrite(f, LitMap[0], Header.Width*Header.Height*4);
    Result := True;
  finally
    CloseFile(f);
  end;
end;

procedure THCNMap.InitLighting(Area: TArea);
var i: Integer;
//  i, j, LK: Integer; LV: TSmIntVector3;
//  Height, LightHeight, LHIncr: Integer;
//  StartX, EndX, StepX, Addr: Integer;
begin
{  LV := Light.Direction;
  StartX := 0; EndX := MapWidth-1;
  if LV.X >= 0 then StepX := 1 else begin
    StartX := MapWidth-1; EndX := 0;
    StepX := -1;
  end;
  if LV.X <> 0 then LHIncr := LV.Y shl 8 div Abs(LV.X) else LHIncr := -255 shl 5;
  for j := 0 to MapHeight-1 do begin
    LightHeight := LitMap[j shl MapPower + StartX].H shl 5 + 1*Map[j shl MapPower + StartX].Res shl 5;
    i := StartX;
    while True do begin
      Addr := j shl MapPower + i;
      Height := LitMap[Addr].H shl 5 + 1*Map[Addr].Res shl 5;
      LightHeight := LightHeight + LHIncr;
      if (LightHeight < Height) then LightHeight := Height;
      Map[Addr].Height := MinI(255, LightHeight shr 5);
      if i = EndX then Break;
      i := i + StepX;
    end;
  end;}
  Area.Left := MinI(MaxI(0, Area.Left), MapWidth-1);
  Area.Right := MinI(MaxI(0, Area.Right), MapWidth-1);
  Area.Top := MinI(MaxI(0, Area.Top), MapHeight-1);
  Area.Bottom := MinI(MaxI(0, Area.Bottom), MapHeight-1);
  for i := Area.Top to Area.Bottom do begin
    if DirLight.Direction.X >= 0 then begin
      if (LightFront[i].Position = -1) or (LightFront[i].Position > Area.Left) then LightFront[i].Position := Area.Left;
    end else begin
      if (LightFront[i].Position = -1) or (LightFront[i].Position < Area.Right) then LightFront[i].Position := Area.Right;
    end;
//      LightFront[i].Height := Map[i shl MapPower + Area.Left].Height;
    LightFront[i].Iteration := 1;
  end;
end;

function THCNMap.GetCellNormal(XI,ZI : Integer): TSMIntVector3;
var NX, NY, NZ, Length:single;
begin
  XI := (XI + MapWidth) and (MapWidth - 1);
  ZI := (ZI + MapHeight) and (MapHeight - 1);
  NX := -{128*}{TileSize*}(LitMap[ZI shl MapPower + (XI+1) and (MapWidth-1)].H - LitMap[ZI shl MapPower + (XI + MapWidth-1) and (MapWidth-1)].H) shl (HeightPower-1);
  NZ := -{128*}{TileSize*}(LitMap[((ZI+1) and (MapHeight-1)) shl MapPower +XI].H - LitMap[(ZI + MapHeight-1) and (MapHeight-1) shl MapPower + XI].H) shl (HeightPower-1);
  NY := TileSize{*TileSize}{128*128};
  Length := InvSqrt( Sqr(NX) + Sqr(NY) + Sqr(NZ) );
  Result.X := Round(NX*127 * Length);
  Result.Y := Round(NY*127 * Length);
  Result.Z := Round(NZ*127 * Length);
end;

function THCNMap.GetNormal(X, Z: Single): TVector3s;
// Returns interpolated normalized to 1 normal
var
  XI, ZI, NXI, NZI: Word;
  RCX, RCZ: Longint;
  XO, ZO: Single;
  OneOverTS: Single;
begin
  Result := GetVector3s(0, 1, 0);
  RCX := Trunc(X + MapHalfWidth + 0.5); RCZ:=Trunc(Z + MapHalfHeight + 0.5);
  if not Tiled and (RCX < 0) or (RCX > MapWidth*TileSize-1) or
                   (RCZ < 0) or (RCZ > MapHeight*TileSize-1) then Exit;
  if RCX > MapWidth*TileSize-1 then RCX := MapWidth*TileSize-1;
  if RCZ > MapHeight*TileSize-1 then RCZ := MapHeight*TileSize-1;
  if RCX < 0 then RCX := 0; if RCZ < 0 then RCZ := 0;
//  Assert((RCX > 0) and (RCZ > 0), 'THCNMap.GetNormal: RCX or RCZ < 0');
  XI := (RCX shr TilePower); ZI := (RCZ shr TilePower);
  Assert((XI < MapWidth) and (ZI < MapHeight), 'THCNMap.GetColor: XI or ZI exceeds bounds');
  NXI := (XI + 1); NZI := (ZI + 1);
  if NXI >= MapWidth then NXI := MapWidth-1;
  if NZI >= MapHeight then NZI := MapHeight-1;
  OneOverTS := 1 / TileSize;           // Normalize to 1
  XO := (RCX - RCX div TileSize * TileSize) * OneOverTS;
  ZO := (RCZ - RCZ div TileSize * TileSize) * OneOverTS;
  if (XO + ZO) <= 1 then begin
    Result.X := (Map[ZI shl MapPower + XI].NX + (Map[NZI shl MapPower + XI].NX - Map[ZI shl MapPower + XI].NX) * ZO +
                                                (Map[ZI shl MapPower + NXI].NX - Map[ZI shl MapPower + XI].NX) * XO)/127;
    Result.Y := (Map[ZI shl MapPower + XI].NY + (Map[NZI shl MapPower + XI].NY - Map[ZI shl MapPower + XI].NY) * ZO +
                                                (Map[ZI shl MapPower + NXI].NY - Map[ZI shl MapPower + XI].NY) * XO)/127;
    Result.Z := (Map[ZI shl MapPower + XI].NZ + (Map[NZI shl MapPower + XI].NZ - Map[ZI shl MapPower + XI].NZ) * ZO +
                                                (Map[ZI shl MapPower + NXI].NZ - Map[ZI shl MapPower + XI].NZ) * XO)/127;
  end else begin
    Result.X := (Map[NZI shl MapPower + NXI].NX + (Map[NZI shl MapPower + XI].NX - Map[NZI shl MapPower + NXI].NX) * (1 - XO) +
                                                  (Map[ZI shl MapPower + NXI].NX - Map[NZI shl MapPower + NXI].NX) * (1 - ZO))/127;
    Result.Y := (Map[NZI shl MapPower + NXI].NY + (Map[NZI shl MapPower + XI].NY - Map[NZI shl MapPower + NXI].NY) * (1 - XO) +
                                                  (Map[ZI shl MapPower + NXI].NY - Map[NZI shl MapPower + NXI].NY) * (1 - ZO))/127;
    Result.Z := (Map[NZI shl MapPower + NXI].NZ + (Map[NZI shl MapPower + XI].NZ - Map[NZI shl MapPower + NXI].NZ) * (1 - XO) +
                                                  (Map[ZI shl MapPower + NXI].NZ - Map[NZI shl MapPower + NXI].NZ) * (1 - ZO))/127;
  end;
end;

procedure THCNMap.ClearItemHMap(X, Y, Width, Height, Angle: Integer);
var i, j, xi, yi, sx, sy, Dim, MaxHeight: Integer;
begin
  Dim := MaxI(Width+2, Height+2);
  X := MaxI(0, X - Dim shl (TilePower-1)-TileSize shr 1);
  Y := MaxI(0, Y - Dim shl (TilePower-1)-TileSize shr 1);
  sx := x shr TilePower+0;
  sy := Y shr TilePower+0;
  yi := sy;
  MaxHeight := 0;
  for j := 0 to Dim+1 do begin
    xi := sx;
    for i := 0 to Dim+1 do begin
      Map[yi shl MapPower + xi].Res := 0;
      if xi < MapWidth-1 then Inc(xi);
      if MaxHeight < LitMap[yi shl MapPower + xi].H then MaxHeight := LitMap[yi shl MapPower + xi].H;
    end;
    if yi < MapHeight-1 then Inc(yi);
  end;
  AddCalcArea(GetArea(sx, sy, sx+Dim+1, sy+Dim+1), MaxHeight, 6);
end;

procedure THCNMap.ApplyItemHMap(X, Y, Width, Height, Angle: Integer; LHMap: PByteBuffer);
var i, j, sx, sy, xi, yi, hw, hh, cx, cy, MaxHeight: Integer; xw, yw: Single;
begin
  sx := x shr TilePower+0;
  xw := 1-(X and (TileSize-1)) / TileSize;
  sy := Y shr TilePower+0;
  yw := 1-(Y and (TileSize-1)) / TileSize;
  yi := sy;
  MaxHeight := 0;
  hw := Width shl (TilePower-1);
  hh := Height shl (TilePower-1);
  for j := 0 to Height-1 do begin
    xi := sx;
    for i := 0 to Width-1 do begin
      cx := Round(X + (j shl TilePower - hh)*Sin(Angle/180*pi) + (i shl TilePower - hw)*Cos(Angle/180*pi));
      cy := Round(Y + (j shl TilePower - hh)*Cos(Angle/180*pi) + (i shl TilePower - hw)*Sin(Angle/180*pi));

      if cx < 0 then Continue;//cx := 0;
      if cy < 0 then Continue;//cy := 0;

      sx := cx shr TilePower+0;
      xw := 1-(cx and (TileSize-1)) / TileSize;
      sy := cy shr TilePower+0;
      yw := 1-(cy and (TileSize-1)) / TileSize;
      xi := sx;
      yi := sy;

      Inc(Map[yi shl MapPower + xi].Res, Trunc(0.5+LHMap^[j*Width+i]*xw*yw));
      Inc(Map[yi shl MapPower + xi+1].Res, Trunc(0.5+LHMap^[j*Width+i]*(1-xw)*yw));
      Inc(Map[(yi+1) shl MapPower + xi].Res, Trunc(0.5+LHMap^[j*Width+i]*xw*(1-yw)));
      Inc(Map[(yi+1) shl MapPower + xi+1].Res, Trunc(0.5+LHMap^[j*Width+i]*(1-xw)*(1-yw)));

      if MaxHeight < LitMap[yi shl MapPower + xi].H + Map[yi shl MapPower + xi].Res then
       MaxHeight := LitMap[yi shl MapPower + xi].H + Map[yi shl MapPower + xi].Res;
      if MaxHeight < LitMap[yi shl MapPower + xi+1].H + Map[yi shl MapPower + xi+1].Res then
       MaxHeight := LitMap[yi shl MapPower + xi+1].H + Map[yi shl MapPower + xi+1].Res;
      if MaxHeight < LitMap[(yi+1) shl MapPower + xi].H + Map[(yi+1) shl MapPower + xi].Res then
       MaxHeight := LitMap[(yi+1) shl MapPower + xi].H + Map[(yi+1) shl MapPower + xi].Res;
      if MaxHeight < LitMap[(yi+1) shl MapPower + xi+1].H + Map[(yi+1) shl MapPower + xi+1].Res then
       MaxHeight := LitMap[(yi+1) shl MapPower + xi+1].H + Map[(yi+1) shl MapPower + xi+1].Res;

      if xi < MapWidth-2 then Inc(xi);
    end;
    if yi < MapHeight-2 then Inc(yi);
  end;
  AddCalcArea(GetArea(sx, sy, sx+Width, sy+Height), MaxHeight, 6);
end;

procedure THCNMap.CalcNormals(Area: TArea);
var
  i, j: Integer;
  T: TSMIntVector3;
begin
  for j := Area.Top-1 to Area.Bottom+1 do for i := Area.Left-1 to Area.Right+1 do begin   // Warning: This code works for cycled landscape
    T := GetCellNormal(i, j);
    Map[(j + MapHeight) and (MapHeight-1) shl MapPower + (i + MapWidth) and (MapWidth-1)].NX := T.X;
    Map[(j + MapHeight) and (MapHeight-1) shl MapPower + (i + MapWidth) and (MapWidth-1)].NY := T.Y;
    Map[(j + MapHeight) and (MapHeight-1) shl MapPower + (i + MapWidth) and (MapWidth-1)].NZ := T.Z;
  end;
  InitLighting(Area);
end;

procedure THCNMap.GetRGBColor(XI, ZI: Integer; var A, R, G, B: Byte);
var ARGB: Longword;
begin
  ARGB := PDWordBuffer(Map)^[(ZI * MapWidth + XI)*2];
  A := ((ARGB shr 26) and 63) shl 2;
  R := ((ARGB shr 20) and 63) shl 2;
  G := ((ARGB shr 14) and 63) shl 2;
  B := ((ARGB shr 8) and 63) shl 2;
end;

procedure THCNMap.SetRGBColor(XI, ZI: Integer; A, R, G, B: Byte);
begin
  PDWordBuffer(Map)^[(ZI * MapWidth + XI)*2] :=
   PDWordBuffer(Map)^[(ZI * MapWidth + XI)*2] and 255 +
   ( B shr 2 + (G shr 2) shl 6 + (R shr 2) shl 12 + (A shr 2) shl 18 ) shl 8;
end;

function THCNMap.GetCellColor(XI, ZI: Integer): Longword;
var ARGB: Longword;
begin
  ARGB := Longword(LitMap[ZI shl MapPower + XI]);
  Result := ARGB and (63 shl 18) shl 8 + (ARGB and (63 shl 12)) shl 6 +
           (ARGB and (63 shl 6)) shl 4 + (ARGB and 63) shl 2;
end;

function THCNMap.GetCellHeight(XI, ZI: Integer): Integer;
begin
  if XI > MapWidth-1 then XI := MapWidth-1;
  if ZI > MapHeight-1 then ZI := MapHeight-1;
  if XI < 0 then XI := 0; if ZI < 0 then ZI := 0;
  Result := LitMap[ZI shl MapPower + XI].H shl HeightPower;
end;

function THCNMap.GetColor(X, Z: Single): Longword;
var
  XI, ZI, NXI, NZI: Word;
  XO, ZO, RCX, RCZ: Integer;
  c1, c2, c3: Longword;
begin
  Result := $808080;
  RCX := Trunc(X + MapHalfWidth + 0.5); RCZ:=Trunc(Z + MapHalfHeight + 0.5);
  if not Tiled and (RCX < 0) or (RCX > MapWidth*TileSize-1) or
                   (RCZ < 0) or (RCZ > MapHeight*TileSize-1) then Exit;
  if RCX > MapWidth*TileSize-1 then RCX := MapWidth*TileSize-1;
  if RCZ > MapHeight*TileSize-1 then RCZ := MapHeight*TileSize-1;
  if RCX < 0 then RCX := 0; if RCZ < 0 then RCZ := 0;
//  Assert((RCX > 0) and (RCZ > 0), 'THCNMap.GetNormal: RCX or RCZ < 0');
  XI := (RCX shr TilePower); ZI := (RCZ shr TilePower);
  Assert((XI < MapWidth) and (ZI < MapHeight), 'THCNMap.GetColor: XI or ZI exceeds bounds');
  NXI := (XI + 1); NZI := (ZI + 1);
  if NXI >= MapWidth then NXI := MapWidth-1;
  if NZI >= MapHeight then NZI := MapHeight-1;
  XO := RCX - RCX div TileSize * TileSize; ZO := RCZ - RCZ div TileSize * TileSize;
  if (XO + ZO) <= TileSize then begin
    c1 := Longword(LitMap[ZI shl MapPower + XI]);
    c2 := Longword(LitMap[NZI shl MapPower + XI]);
    c3 := Longword(LitMap[ZI shl MapPower + NXI]);
//    Result := BlendColor(BlendColor(c1, c2, zo/TileSize), c3, xo/TileSize);
  end else begin
    c1 := Longword(LitMap[NZI shl MapPower + NXI]);
    c2 := Longword(LitMap[NZI shl MapPower + XI]);
    c3 := Longword(LitMap[ZI shl MapPower + NXI]);
//    Result := BlendColor(BlendColor(c1, c2, 1-xo/TileSize), c3, 1-zo/TileSize);
  end;
  asm
//       U pipe                               V pipe
    push      ESI;       push         EDI
    push      EBX;

    pxor         MM0, MM0

    movd         MM4, XO
    movd         MM5, ZO

    punpcklwd    MM5, MM5
    punpcklwd    MM4, MM4
    punpckldq    MM5, MM5
    punpckldq    MM4, MM4

    mov       EAX, c1
    shl       EAX, 2;    mov       ESI, EAX;         and       ESI, 63 shl 2
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 10;   or     ESI, ECX
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 18;   or     ESI, ECX
    shl       EAX, 2;    and       EAX, 63 shl 26;   or        ESI, EAX
    movd      MM3, ESI

    mov       EAX, c3
    shl       EAX, 2;    mov       ESI, EAX;         and       ESI, 63 shl 2
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 10;   or     ESI, ECX
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 18;   or     ESI, ECX
    shl       EAX, 2;    and       EAX, 63 shl 26;   or        ESI, EAX
    movd      MM1, ESI
// Original:  00000000 AAAAAARR RRRRGGGG GGBBBBBB
//  AAAAAA00 RRRRRR00 GGGGGG00 BBBBBB00
    punpcklbw    MM3, MM0;         punpcklbw    MM1, MM0;
    psubw        MM1, MM3;         pmullw       MM1, MM4;

    mov       EAX, c2
    shl       EAX, 2;    mov       ESI, EAX;         and       ESI, 63 shl 2
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 10;   or     ESI, ECX
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 18;   or     ESI, ECX
    shl       EAX, 2;    and       EAX, 63 shl 26;   or        ESI, EAX
    movd      MM2, ESI
    punpcklbw    MM2, MM0

    psubw        MM2, MM3
    pmullw       MM2, MM5
    paddw        MM1, MM2
    psraw        MM1, 7

    paddw        MM1, MM3;

    pop     EBX
    pop     EDI
    pop     ESI

    packuswb     MM1, MM0
    movd         Result, MM1
    emms
  end;
end;

function THCNMap.GetHeight(X, Z: Single): Integer;
var
  XI, ZI, NXI, NZI: Word;
  XO, ZO, RCX, RCZ: Longint;
begin
  Result := 0;
  RCX := Trunc(X + MapHalfWidth + 0.5); RCZ := Trunc(Z + MapHalfHeight + 0.5);
  if not Tiled and (RCX < 0) or (RCX > MapWidth*TileSize-1) or
                   (RCZ < 0) or (RCZ > MapHeight*TileSize-1) then Exit;
{  if RCX > MapWidth*TileSize-1 then RCX := MapWidth*TileSize-1;
  if RCZ > MapHeight*TileSize-1 then RCZ := MapHeight*TileSize-1;}
  if (RCX > MapWidth*TileSize-1) or (RCZ > MapHeight*TileSize-1) then begin
    Result := 0;
    Exit;
  end;
  if RCX < 0 then RCX := 0; if RCZ < 0 then RCZ := 0;
//  Assert((RCX > 0) and (RCZ > 0), 'THCNMap.GetNormal: RCX or RCZ < 0');
  XI := (RCX shr TilePower); ZI := (RCZ shr TilePower);
  Assert((XI < MapWidth) and (ZI < MapHeight), 'THCNMap.GetHeight: XI or ZI exceeds bounds');
  NXI := (XI + 1); NZI := (ZI + 1);
  if NXI >= MapWidth then NXI := MapWidth-1;
  if NZI >= MapHeight then NZI := MapHeight-1;
  XO := RCX - RCX div TileSize * TileSize; ZO := RCZ - RCZ div TileSize * TileSize;

{  if (XI < 0) or (XI >= MapWidth) or (ZI < 0) or (ZI >= MapHeight) then begin xi :=xi; end;
  if (NXI < 0) or (NXI >= MapWidth) or (NZI < 0) or (NZI >= MapHeight) then begin xi :=xi; end;}

  if (XO + ZO) <= TileSize then begin
    Result := Trunc(0.5 + LitMap[ZI shl MapPower + XI].H + (LitMap[NZI shl MapPower + XI].H - LitMap[ZI shl MapPower + XI].H) * ZO / TileSize +
                         (LitMap[ZI shl MapPower + NXI].H - LitMap[ZI shl MapPower + XI].H) * XO / TileSize) shl HeightPower;
  end else begin
    Result := Trunc(0.5 + LitMap[NZI shl MapPower + NXI].H + (LitMap[NZI shl MapPower + XI].H - LitMap[NZI shl MapPower + NXI].H) * (TileSize - XO) / TileSize +
                         (LitMap[ZI shl MapPower + NXI].H - LitMap[NZI shl MapPower + NXI].H) * (TileSize - ZO) / TileSize) shl HeightPower;
  end;
end;

procedure THCNMap.MakeCrater(const X, Z: Single; const Radius: Integer);
begin
  MakeCraterEx(X, 0, Z, Radius, 2, 0.6, False);
end;

procedure THCNMap.MakeCraterEx(X, Y, Z: Single; const Radius: Integer; const Depth, Scorch: Single; const Smooth: Boolean);
var i, j, XI, ZI: Integer; Area: TArea; SQ, Dist, K: Single; A, R, G, B: Byte;
begin
  if Radius <= 0 then Exit;

  X := X + MapHalfWidth; Z := Z + MapHalfHeight;

  Area.Left := Round(X - Radius) div TileSize;// + MapWidth;
  Area.Top := Round(Z - Radius) div TileSize;// + MapHeight;
  Area.Right := Round(X + Radius) div TileSize;// + MapWidth;
  Area.Bottom := Round(Z + Radius) div TileSize;// + MapHeight;

  K := 1 / TileSize;

  for i := Area.Left to Area.Right do for j := Area.Top to Area.Bottom do begin
    SQ := (i*TileSize - X)*(i*TileSize - X) + (j*TileSize - Z)*(j*TileSize - Z);
    XI := i; ZI := j;
    if (XI >= MapWidth) or (ZI >= MapHeight) or (XI < 0) or (ZI < 0) then Continue;
//    XI := (i + MapWidth) and (MapWidth-1); ZI := (j + MapHeight) and (MapHeight-1);
    if Radius*Radius - SQ >= 0 then begin
      Dist := Sqrt(SQ);
      LitMap[ZI shl MapPower + XI].H := Trunc(0.5 + MaxS(0, LitMap[ZI shl MapPower + XI].H - (Radius - Dist) * K * Depth));
      if LitMap[ZI shl MapPower + XI].H = 0 then begin
        SetRGBColor(XI, ZI, A, 0, 0, 0);
        if XI < MapWidth-1 then SetRGBColor(XI+1, ZI, A, 0, 0, 0);
        if XI > 0 then SetRGBColor(XI-1, ZI, A, 0, 0, 0);
        if ZI < MapHeight-1 then SetRGBColor(XI, ZI+1, A, 0, 0, 0);
        if ZI > 0 then SetRGBColor(XI, ZI-1, A, 0, 0, 0);
      end else begin
        GetRGBColor(XI, ZI, A, R, G, B);
        SetRGBColor(XI, ZI, A,
            MinI(R, Trunc(0.5 + R * (1-Scorch + Scorch*Dist / Radius))),
            MinI(G, Trunc(0.5 + G * (1-Scorch + Scorch*Dist / Radius))),
            MinI(B, Trunc(0.5 + B * (1-Scorch + Scorch*Dist / Radius))));
      end;
      if not Smooth then DirMap[ZI shl MapPower + XI] := LitMap[ZI shl MapPower + XI];
    end;
  end;

  if Smooth then for j := Area.Top to Area.Bottom do begin                     // Smooth cycle
    for i := Area.Left to Area.Right do begin
      XI := (i + MapWidth) and (MapWidth-1); ZI := (j + MapHeight) and (MapHeight-1);
      LitMap[ZI shl MapPower + XI].H := Round((LitMap[(j+MapHeight-1) and (MapHeight-1) shl MapPower + XI].H + LitMap[(j+MapHeight+1) and (MapHeight-1) shl MapPower + XI].H +
                                               LitMap[ZI shl MapPower + (i+MapWidth-1) and (MapWidth-1)].H + LitMap[ZI shl MapPower + (i+MapWidth+1) and (MapWidth-1)].H)/4);
      DirMap[ZI shl MapPower + XI] := LitMap[ZI shl MapPower + XI];
    end;
  end;
  CalcNormals(Area);
  CLLine := (Area.Top + MapHeight) and (MapHeight-1);
end;

procedure THCNMap.DelLight(Light: TIntLight);
var j, Offset, W: Integer;
begin
  case Light.LightType of
    ltOmniNoShadow, ltOmni, ltOmniBlink, ltSpotNoShadow, ltSpot, ltSpotBlink, ltSimpleSpot: begin
      with Light do for j := MaxI(0, OldLocation.Z - Range) shr TilePower to MinI(MapHeight-1, (OldLocation.Z + Range) shr TilePower) do begin
        Offset := OldLocation.X - Range; W := -Offset; if W < 0 then W := 0; if Offset < 0 then Offset := 0;
        W := W + MaxI(0, OldLocation.X + Range - (MapWidth-1) shl 8);
        Move(DirMap[j shl MapPower+Offset shr 8], LitMap[j shl MapPower+Offset shr 8], (2*Range+1) shr 6-W shr 8);
      end;
    end;
  end;
end;

function THCNMap.CalcRay(Ray, K: Integer): Integer;
var
  i, DotP, OldDotP: Integer; LV: TSmIntVector3;
  Height, LightHeight, LHIncr: Integer;
  Lightness: record R, G, B, Total: Integer; end;
  StepX, Addr: Integer;
  ARGB: Longword;
begin
  Result := 0;

  LV := DirLight.Direction;
  LV.X := LV.X;
  if LV.X >= 0 then StepX := 1 else StepX := -1;

  i := LightFront[Ray].Position;
  if ((i = 0) and (StepX < 0)) or ((i = MapWidth-1) and (StepX > 0)) then Exit;

  if LV.X <> 0 then LHIncr := LV.Y shl 8 div Abs(LV.X) else LHIncr := -255 shl HeightPower;

  LightHeight := Map[Ray shl MapPower + i].Height shl HeightPower;
  while True do begin
    Addr := Ray shl MapPower + i;
    try
      Height := (LitMap[Addr].H + Map[Addr].Res) shl HeightPower;
    except
      Height := 0;
    end;
    LightHeight := LightHeight + LHIncr;
    if (LightHeight >= Height) then begin
      DotP := 0;
      with Map[Addr] do DotP := MaxI(0, -( (NX*LV.X + NY*LV.Y + NZ*LV.Z)));
      if Map[Addr].Res = 0 then DotP := DotP * (32 - MinI(32, (LightHeight - Height) shr 4));
    end else begin
//    if Map[Addr].Res > 0 then DotP := 0 else
      with Map[Addr] do DotP := MaxI(0, -( (NX*LV.X + NY*LV.Y + NZ*LV.Z))) * (32);
      DotP := (DotP * MaxI(0, (16-Map[Addr].Res))) shr 4;
      LightHeight := Height;
    end;
    Lightness.R := DirLight.R*DotP shr (8+7);
    Lightness.G := DirLight.G*DotP shr (8+7);
    Lightness.B := DirLight.B*DotP shr (8+7);
    Map[Addr].Height := MinI(255 shl HeightPower, LightHeight) shr HeightPower;
    case K of
      1: begin
{        DirMap[Addr].R := MinI(255, (Map[Addr].R * (Lightness.R+AmbientColor.R shl 6)) shr 13);
        DirMap[Addr].G := MinI(255, (Map[Addr].G * (Lightness.G+AmbientColor.G shl 6)) shr 13);
        DirMap[Addr].B := MinI(255, (Map[Addr].B * (Lightness.B+AmbientColor.B shl 6)) shr 13);}
        ARGB := PDWordBuffer(Map)^[Addr*2];
        Lightness.R := MinI(63, ((ARGB shr 20) and 63 * (Lightness.R+AmbientColor.R shl 6)) shr 13);
        Lightness.G := MinI(63, ((ARGB shr 14) and 63 * (Lightness.G+AmbientColor.G shl 6)) shr 13);
        Lightness.B := MinI(63, ((ARGB shr 8) and 63 * (Lightness.B+AmbientColor.B shl 6)) shr 13);

        PDWordBuffer(DirMap)^[Addr] :=
         PDWordBuffer(DirMap)^[Addr] and (255 shl 24) + (ARGB and (63 shl 26)) shr 8+
          LightNess.R shl 12 + LightNess.G shl 6 + LightNess.B;
      end;
      2, 4: begin
        DirMap[Addr].R := (DirMap[Addr].R*1 + MinI(255, Map[Addr].R * (Lightness.R+64 shl 6) shr 12)) shr 1;
        DirMap[Addr].G := (DirMap[Addr].G*1 + MinI(255, Map[Addr].G * (Lightness.G+64 shl 6) shr 12)) shr 1;
        DirMap[Addr].B := (DirMap[Addr].B*1 + MinI(255, Map[Addr].B * (Lightness.B+64 shl 6) shr 12)) shr 1;
      end;
      5: begin
        DirMap[Addr].R := (DirMap[Addr].R*3*1 + MinI(255, Map[Addr].R * (Lightness.R+64 shl 6) shr 12)) shr 2;
        DirMap[Addr].G := (DirMap[Addr].G*3*1 + MinI(255, Map[Addr].G * (Lightness.G+64 shl 6) shr 12)) shr 2;
        DirMap[Addr].B := (DirMap[Addr].B*3*1 + MinI(255, Map[Addr].B * (Lightness.B+64 shl 6) shr 12)) shr 2;
      end;
      6: begin
        DirMap[Addr].R := (DirMap[Addr].R*7*1 + MinI(255, Map[Addr].R * (Lightness.R+64 shl 6) shr 12)) shr 3;
        DirMap[Addr].G := (DirMap[Addr].G*7*1 + MinI(255, Map[Addr].G * (Lightness.G+64 shl 6) shr 12)) shr 3;
        DirMap[Addr].B := (DirMap[Addr].B*7*1 + MinI(255, Map[Addr].B * (Lightness.B+64 shl 6) shr 12)) shr 3;
      end;
    end;
    if ((i = 0) or (i = MapWidth-1)) and (i <> LightFront[Ray].Position) then Break;
    OldDotP := DotP;
    i := i + StepX;
  end;
  Result := MaxI(i, LightFront[Ray].Position) - MinI(i, LightFront[Ray].Position)+1;
  Move(DirMap[Ray shl MapPower + MinI(i, LightFront[Ray].Position)],
       LitMap[Ray shl MapPower + MinI(i, LightFront[Ray].Position)], Result*SizeOf(LitMap[0]));
end;

procedure THCNMap.CalcDirLocal(Area: TArea);
//const ShP = 8; ShSm = 1 shl ShP;
var
  i, j, DotP, OldDotP, LK: Integer; LV: TSmIntVector3;
  Height, LightHeight, LHIncr: Integer;
  Lightness: record R, G, B, Total: Integer; end;
  CurX, StepX, Addr, Fade: Integer;
  OldDotPs, DotPs: array[0..1023] of Integer;
begin
  Fade := 0;
  LV := DirLight.Direction;
  LV.X := LV.X;
  if LV.X >= 0 then StepX := 1 else begin
    StepX := Area.Left;
    Area.Left := Area.Right;
    Area.Right := StepX;
    StepX := -1;
  end;
  if LV.X <> 0 then LHIncr := LV.Y shl 8 div Abs(LV.X) else LHIncr := -255 shl HeightPower;
  CurX := 0 shl 8;
  for j := Area.Top to Area.Bottom do begin
    LightHeight := Map[j shl MapPower + Area.Left].Height shl HeightPower;
    i := Area.Left;
    while True do begin
//    for i := Area.Left to Area.Right do begin
      Addr := j shl MapPower + i;
      Height := LitMap[Addr].H shl HeightPower + 1*Map[Addr].Res shl HeightPower;
      LightHeight := LightHeight + LHIncr;
      if (LightHeight >= Height) then begin
        DotP := 0; if Fade < 4 then Inc(Fade);
        Fade:=0;
        with Map[Addr] do DotP := MaxI(0, -( (NX*LV.X + NY*LV.Y + NZ*LV.Z)));
        if Map[Addr].Res = 0 then DotP := DotP * (32 - MinI(32, (LightHeight - Height) shr 3));
      end else begin
//      if Map[Addr].Res > 0 then DotP := 0 else
        with Map[Addr] do DotP := MaxI(0, -( (NX*LV.X + NY*LV.Y + NZ*LV.Z))) * (32-Fade*4*2);
        DotP := (DotP * MaxI(0, (16-Map[Addr].Res))) shr 4;
        LightHeight := Height;
        if Fade > 0 then Dec(Fade);
      end;
//      if j > Area.Top then DotP := (DotP + DotPs[i]) shr 1;
//      if i > Area.Left then DotP := (DotP + OldDotP) shr 1;
//      if (i > Area.Left) and (j > Area.Top) then DotP := (DotP + DotPs[i] + OldDotPs[i-1] + OldDotP) shr 2;
      Lightness.R := DirLight.R*DotP shr (8+7);
      Lightness.G := DirLight.G*DotP shr (8+7);
      Lightness.B := DirLight.B*DotP shr (8+7);
      Map[Addr].Height := MinI(255 shl HeightPower, LightHeight) shr HeightPower;
      DirMap[Addr].R := (DirMap[Addr].R*7*1 + MinI(255, Map[Addr].R * (Lightness.R+64 shl 6) shr 12)) shr 3;
      DirMap[Addr].G := (DirMap[Addr].G*7*1 + MinI(255, Map[Addr].G * (Lightness.G+64 shl 6) shr 12)) shr 3;
      DirMap[Addr].B := (DirMap[Addr].B*7*1 + MinI(255, Map[Addr].B * (Lightness.B+64 shl 6) shr 12)) shr 3;
{      LitMap[Addr].R := (LitMap[Addr].R + DirMap[Addr].R) shr 1;
      LitMap[Addr].G := (LitMap[Addr].G + DirMap[Addr].G) shr 1;
      LitMap[Addr].B := (LitMap[Addr].B + DirMap[Addr].B) shr 1;}
      if i = Area.Right then Break;
      DotPs[i] := DotP;
      OldDotP := DotP;
      i := i + StepX;
    end;
//    Move(Dotps, OldDotPs, 1024*4);
    Move(DirMap[j shl MapPower + MinI(Area.Right, Area.Left)],
         LitMap[j shl MapPower + MinI(Area.Right, Area.Left)], (MaxI(Area.Right, Area.Left)-MinI(Area.Right, Area.Left)+1)*SizeOf(LitMap[0]));
  end;
end;

procedure THCNMap.AddCalcArea(Area: TArea; MaxHeight, K: Integer);
var i: Integer;
begin
  for i := Area.Top to Area.Bottom do begin
    if DirLight.Direction.X >= 0 then begin
      if (LightFront[i].Position = -1) or (LightFront[i].Position > Area.Left) then LightFront[i].Position := Area.Left;
    end else begin
      if (LightFront[i].Position = -1) or (LightFront[i].Position < Area.Right) then LightFront[i].Position := Area.Right;
    end;
//      LightFront[i].Height := Map[i shl MapPower + Area.Left].Height;
    LightFront[i].Iteration := K;
  end;
end;

procedure THCNMap.ProcessCalcArea(Camera: TCamera);
var i: Integer;
begin
//  while CalcQueue.TotalAreas > 0 do CalcDirLocal(Light, CalcQueue.Extract.Area);
  CellsLit := 0;
  for i := 0 to MapHeight-1 do if LightFront[i].Position <> -1 then begin
    if LightFront[i].Iteration > 0 then begin
      Inc(CellsLit, CalcRay(i, LightFront[i].Iteration));
//      Inc(LightFront[i].Position, );
      Dec(LightFront[i].Iteration);
//      LightFront[i].Position := -1;
    end else LightFront[i].Position := -1;
    if CellsLit >= LightSpeed then Break;
  end;
end;

procedure THCNMap.ReCalcAll(Camera: TCamera);
var i: Integer;
begin
//  while CalcQueue.TotalAreas > 0 do CalcDirLocal(Light, CalcQueue.Extract.Area);
  for i := 0 to MapHeight-1 do begin
    Map[i shl MapPower].Height := 0;
    LightFront[i].Height := 0; LightFront[i].Iteration := 1;
    if DirLight.Direction.X >= 0 then LightFront[i].Position := 0 else LightFront[i].Position := MapWidth-1;
    if LightFront[i].Iteration > 0 then begin
      CalcRay(i, LightFront[i].Iteration);
      Dec(LightFront[i].Iteration);
    end else LightFront[i].Position := -1;
  end;
end;

procedure THCNMap.CalcLight(var ALight: TLight);
var Light: TIntLight;

procedure ApplyOmniDynLight(Light: TIntLight);
var i, j: Integer; LVX, LVY, LVZ, DotP, SQLV: Integer; LR, LG, LB: Byte; ARGB: Longword; OneOverR2: Single;
begin
  OneOverR2 := 1/Light.RangeSQ;
  with Light do for j := MaxI(0, (Location.Z - Range) div 256) to MinI(MapHeight-1, (Location.Z + Range) div 256) do
   for i := MaxI(0, (Location.X - Range) div 256) to MinI(MapWidth-1, (Location.X + Range) div 256) do begin
    LVX := Location.X - i * 256;
    LVZ := Location.Z - j * 256;
    LVY := Location.Y - LitMap[j shl MapPower+i].H; if abs(LVY) > Range then Continue;
    SQLV := LVX*LVX+LVY*LVY+LVZ*LVZ;
    with Map[j shl MapPower+i] do DotP := NX*LVX+NY*LVY+NZ*LVZ;              // ToFix: Optimize it
    if DotP > 0 then begin
      if (SQLV < RangeSQ) then begin
        DotP := Trunc(0.5 + DotP * (1 - SQLV * OneOverR2) / Sqrt(SQLV));
//        DotP:=Round(DotP / SQLV * 1024);
        ARGB := PDWordBuffer(LitMap)^[j shl MapPower+i];
        LR := MinI(63, (ARGB shr 12) and 63 + (R*DotP) shr 7 );
        LG := MinI(63, (ARGB shr 6) and 63 + (G*DotP) shr 7 );
        LB := MinI(63, (ARGB) and 63 + (B*DotP) shr 7 );

        PDWordBuffer(LitMap)^[j shl MapPower+i] :=
         PDWordBuffer(LitMap)^[j shl MapPower+i] and (255 shl 24) + (ARGB and (63 shl 18)) +
          LR shl 12 + LG shl 6 + LB;

{        LitMap[j shl MapPower+i].R := MinI(255, LitMap[j shl MapPower+i].R + (R*DotP) shr 6);
        LitMap[j shl MapPower+i].G := MinI(255, LitMap[j shl MapPower+i].G + (G*DotP) shr 6);
        LitMap[j shl MapPower+i].B := MinI(255, LitMap[j shl MapPower+i].B + (B*DotP) shr 6);}
      end;
    end;
   end;
end;

(*procedure ApplyDirLight(Light: TLight);
const ShP = 8; ShSm = 1 shl ShP;
var
  i, DotP, LK: Integer; LV: TSmIntVector3; Height, LightHeight: Integer;
  Lightness: record R, G, B, Total: Integer; end;
  CurX, CurY, StepX, StepY, Addr, Addr2, Fade: Integer;
begin
  Fade := 0;
  Inc(CLLine, 1); if CLLine > 0*100+MapHeight-1 then CLLine := 0;
  LV := Light.Direction;
  StepX := LV.X; StepY := LV.Z;
  if (StepX = 0) and (StepY = 0) then begin StepX := 256; StepY := 0; end;
  if abs(StepX) >= abs(StepY) then begin
    StepY := StepY*256 div abs(StepX);
    if StepX > 0 then StepX := 256 else StepX := -256;
    CurY := CLLine shl 8;
    CurX := 0 shl 8;
    LightHeight := LitMap[CLLine shl MapPower].H shl 5;
    for i := 0 to 0*200+MapWidth - 1 do begin
    if CurY and 255<128 then Addr := (CurY shr 8) shl MapPower+Curx shr 8 else Addr := ((CurY shr 8+1) and (MapHeight-1)) shl MapPower+Curx shr 8;
//      Addr := (CurY shr 8) shl MapPower + CurX shr 8;
      Addr2 := ((CurY shr 8+1) and (MapHeight-1)) shl MapPower + (CurX shr 8) and (MapWidth-1);  // bug??
      {$I CLDir.inc}
      CurX := (CurX + StepX + MapWidth shl 8) and (MapWidth shl 8-1);
//      CurX := (CurX + StepX + 128 shl 8) and (128 shl 8-1);
      Inc(CurY, StepY);
      if CurY > (MapHeight-1) shl 8 then CurY := CurY - (MapHeight-1) shl 8;
//      if CurY > (100-1) shl 8 then CurY := CurY - (100-1) shl 8;
      if CurY < 0 then CurY := CurY + (0*100+1*MapHeight-1) shl 8;
    end;
  end else begin exit;
    StepX := StepX*256 div abs(StepY);
    if StepY > 0 then StepY := 256 else StepY := -256;
    CurX := CLLine shl 8;
    CurY := 0 shl 8;
    LightHeight := LitMap[CLLine{ shl MapPower}].H shl 5;
    for i := 0 to 200+0*MapWidth - 1 do begin
      Addr := (CurY shr 8) shl MapPower + CurX shr 8;
      {$I CLDir.inc}
//      CurX := (CurX + StepX + MapWidth shl 8) and (MapWidth shl 8-1);
      CurY := (CurY + StepY + 128 shl 8) and (128 shl 8-1);
      Inc(CurX, StepX);
//      if CurY > (MapHeight-1) shl 8 then CurY := CurY - (MapHeight-1) shl 8;
      if Curx > (100-1) shl 8 then Curx := Curx - (100-1) shl 8;
      if Curx < 0 then Curx := Curx + (100+0*MapHeight-1) shl 8;
    end;
  end
end;*)

procedure ApplyDirLight(Light: TIntLight);
const ShP = 8; ShSm = 1 shl ShP;
var
  i, DotP, LK: Integer; LV: TSmIntVector3;
  Height, LightHeight, LHIncr: Integer;
  Lightness: record R, G, B, Total: Integer; end;
  CurX, StepX, Addr, Fade: Integer;
begin
  Fade := 0;
  LV := Light.Direction;
  if LV.X >= 0 then StepX := 256 else StepX := -256;
  if LV.X <> 0 then LHIncr := LV.Y shl 8 div Abs(LV.X) else LHIncr := -255 shl HeightPower;
  CurX := 0 shl 8;
  LightHeight := LitMap[CLLine shl MapPower].H shl 5;
  for i := 0 to 0*200+MapWidth - 1 do begin
    Addr := CLLine shl MapPower + CurX shr 8;
//      Addr2 := ((CurY shr 8+1) and (MapHeight-1)) shl MapPower + (CurX shr 8) and (MapWidth-1);
    {$I CLDir.inc}
    CurX := (CurX + StepX + MapWidth shl 8) and (MapWidth shl 8-1);
//      CurX := (CurX + StepX + 128 shl 8) and (128 shl 8-1);
  end;
  Inc(CLLine);
end;

begin
  Light := LightToInt(ALight);
  case Light.LightType of
    ltDirectional: ApplyDirLight(Light);
    ltOmniNoShadow: ApplyOmniDynLight(Light);
  end;
  ALight.OldLocation := ALight.Location;
end;

procedure THCNMap.CopyLitToDir(Area: TArea);
var j: Integer;
begin
  for j := Area.Top to Area.Bottom do begin
{    for i := Area.Left to Area.Right do begin   // Warning: This code works for cycled landscape
      Map[j shl MapPower + i].R := LitMap[j shl MapPower + i].R;
      Map[j shl MapPower + i].G := LitMap[j shl MapPower + i].G;
      Map[j shl MapPower + i].B := LitMap[j shl MapPower + i].B;
    end;}
    Move(LitMap[j shl MapPower + Area.Left], DirMap[j shl MapPower + Area.Left], (Area.Right-Area.Left+1)*SizeOf(LitMap[0]));
  end;
end;

destructor THCNMap.Free;
begin
  SetLength(Map, 0); SetLength(LitMap, 0); SetLength(DirMap, 0);
  Map := nil; LitMap := nil;
  SetLength(LightFront, 0);
//  CalcQueue.Free;
end;

end.
