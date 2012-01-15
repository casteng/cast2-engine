(*
 @abstract(CAST II Engine maps unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: Feb 13, 2007 <br>
 Unit contains basic classes for various maps (tilemaps, heightmaps, etc)
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Maps;

interface

uses SysUtils, BaseTypes, BaseMsg, Basics, Props, Base3D, BaseClasses, Models, ItemMsg;

type
  // Base class for height maps, tile maps, etc
  TMap = class(TItem)
  private
    OneOverCellWidthScale, OneOverCellHeightScale: Single;
  protected
    FElementSize: Integer;
    FWidth, FHeight, FMaxHeight: Integer;
    FCellWidthScale, FCellHeightScale, FDepthScale: Single;
    function GetData: Pointer; virtual; abstract;

    procedure SetCellWidthScale(const Value: Single); virtual;
    procedure SetCellHeightScale(const Value: Single); virtual;
    procedure SetHeightScale(const Value: Single); virtual;

    function GetRawHeight(XI, ZI: Integer): Integer; virtual; abstract;
    procedure SetRawHeight(XI, ZI: Integer; const Value: Integer); virtual; abstract;

    function GetCellHeight(XI, ZI: Integer): Single;

    // Calculate coefficients for interpolation between values given at a rectangle corners
    procedure CalcCoeffs(xo, zo: Single; out k11, k12, k21, k22: Single);
  public
    class function IsAbstract: Boolean; override;

    constructor Create(AManager: TItemsManager); override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    // Returns True if the map object is ready to handle requests
    function IsReady: Boolean; virtual;

    procedure SetDimensions(AWidth, AHeight: Integer); virtual;
    // Returns an interpolated height at the given point
    function GetHeight(X, Z: Single): Single; virtual;
    // Returns a normal at the given cell
    function GetCellNormal(XI,ZI :Integer): TVector3s; virtual;
    // Returns an interpolated normal at the given point
    function GetNormal(X,Z: Single): TVector3s; virtual;
    // Returns indices of map cell containing the given point
    procedure ObtainCell(X, Z: Single; out CellX, CellZ: Integer);

    // Copies a rectangular area of the map to a caller-allocated buffer
    procedure ObtainRectHeights(const ARect: TRect; ABuf: Pointer); virtual;
    // Swaps a rectangular area of the map with the contents of the specified buffer
    procedure SwapRectHeights(const ARect: TRect; ABuf: Pointer); virtual;
    // Adds a rectangular area of the map and the contents of the specified buffer contaning values of type Single
    procedure AddRectHeights(const ARect: TRect; ABuf: Pointer; Scale: Single); virtual;

    // Returns True if the specified in map (model) space ray intersects with the map. Also returns the point of intersection.
    function TraceRay(const Origin, Dir: TVector3s; out Point: TVector3s): Boolean; virtual;

    // Map width
    property Width:  Integer read FWidth;
    // Map height
    property Height: Integer read FHeight;
    // Map cell width
    property CellWidthScale:  Single read FCellWidthScale  write SetCellWidthScale;
    // Map cell height
    property CellHeightScale: Single read FCellHeightScale  write SetCellHeightScale;
    property DepthScale: Single read FDepthScale write SetHeightScale;
    property MaxHeight: Integer read FMaxHeight;

    // Size of single element of raw data
    property ElementSize: Integer read FElementSize;

    // Raw data
    property Data: Pointer read GetData;

    // Raw heights
    property RawHeights[XI, ZI: Integer]: Integer read GetRawHeight write SetRawHeight; default;
  end;

  TMapEditOp = class(Models.TOperation)
  protected
    Map: TMap;
    CellX, CellZ, CursorSize: Integer;
    Buffer: Pointer;
    // Applies the operation. Repeated call will undo the operation.
    procedure DoApply; override;
  public
    destructor Destroy; override;
  end;

implementation

{ TMap }

procedure TMap.SetCellWidthScale(const Value: Single);
begin
  FCellWidthScale := Value;
  if Abs(FCellWidthScale) > epsilon then OneOverCellWidthScale := 1/FCellWidthScale else OneOverCellWidthScale := 0;
end;

procedure TMap.SetCellHeightScale(const Value: Single);
begin
  FCellHeightScale := Value;
  if Abs(FCellHeightScale) > epsilon then OneOverCellHeightScale := 1/FCellHeightScale else OneOverCellHeightScale := 0;
end;

procedure TMap.SetHeightScale(const Value: Single);
begin
  FDepthScale := Value;
end;

function TMap.GetCellHeight(XI, ZI: Integer): Single;
begin
  Result := GetRawHeight(XI, ZI) * DepthScale;
end;

procedure TMap.CalcCoeffs(xo, zo: Single; out k11, k12, k21, k22: Single);
var k: Single;
begin
  if xo > zo then k := xo-zo else k := zo-xo;
  k22 := (xo+zo)*0.5 * (1-k);
  k11 := (1-(xo+zo)*0.5) * (1-k);
  if xo > zo then k21 := k else k21 := 0;
  if zo > xo then k12 := k else k12 := 0;
end;

class function TMap.IsAbstract: Boolean; begin Result := Self = TMap; end;

constructor TMap.Create(AManager: TItemsManager);
begin
  inherited;
end;

procedure TMap.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Width',           vtInt,    [], IntToStr(FWidth),             '');
  Result.Add('Height',          vtInt,    [], IntToStr(FHeight),            '');
  Result.Add('CellWidthScale',  vtSingle, [], FloatToStr(FCellWidthScale),  '0.1-32');
  Result.Add('CellHeightScale', vtSingle, [], FloatToStr(FCellHeightScale), '0.1-32');
  Result.Add('DepthScale',      vtSingle, [], FloatToStr(FDepthScale),      '0-10');
end;

procedure TMap.SetProperties(Properties: Props.TProperties);
var NWidth, NHeight: Integer;
begin
  inherited;
  NWidth  := FWidth;
  NHeight := FHeight;
  if Properties.Valid('Width')  then NWidth  := StrToIntDef(Properties['Width'],  FWidth);
  if Properties.Valid('Height') then NHeight := StrToIntDef(Properties['Height'], FHeight);

  if (NWidth <> FWidth) or (NHeight <> FHeight) then SetDimensions(NWidth, NHeight);

  if Properties.Valid('CellWidthScale')  then CellWidthScale   := StrToFloatDef(Properties['CellWidthScale'],  FCellWidthScale);
  if Properties.Valid('CellHeightScale') then CellHeightScale  := StrToFloatDef(Properties['CellHeightScale'], FCellHeightScale);
  if Properties.Valid('DepthScale')      then DepthScale       := StrToFloatDef(Properties['DepthScale'],      FDepthScale);
end;

function TMap.IsReady: Boolean;
begin
  Result := (FElementSize <> 0) and (FWidth > 0) and (FHeight > 0);
end;

procedure TMap.SetDimensions(AWidth, AHeight: Integer);
begin
  FWidth := AWidth; FHeight := AHeight;
end;

{function TMap.GetCellNormal(XI, ZI: Integer): TVector3s;
var NX1, NZ1, NX2, NZ2: Integer; InvDist: Single;
begin
  Assert((XI >= 0) and (ZI >= 0) and (XI < Width) and (ZI < Height), '');
  NX1 := MaxI(0, XI-1);
  NZ1 := MaxI(0, ZI-1);
  NX2 := MinI(Width-1,  XI+1);
  NZ2 := MinI(Height-1, ZI+1);

  CrossProductVector3s(Result, GetVector3s(0, GetCellHeight(XI, NZ2) - GetCellHeight(XI, NZ1), CellHeightScale*2),
                               GetVector3s(CellWidthScale*2, GetCellHeight(NX2, ZI) - GetCellHeight(NX1, ZI), 0) );

  Result.Y := Result.Y;
  InvDist := InvSqrt(SqrMagnitude(Result));
  Result.X := Result.X * InvDist;
  Result.Y := Result.Y * InvDist;
  Result.Z := Result.Z * InvDist;
end;}

function TMap.GetCellNormal(XI, ZI: Integer): TVector3s;
begin
  Result := GetVector3s(
             GetCellHeight(MaxI(0, XI-1), ZI) - GetCellHeight(MinI(Width-1,  XI+1), ZI),
             CellWidthScale+CellHeightScale,
             GetCellHeight(XI, MaxI(0, ZI-1)) - GetCellHeight(XI, MinI(Height-1, ZI+1)));
  FastNormalizeVector3s(Result);
end;

function TMap.GetHeight(X, Z: Single): Single;                // ToDo: Test with x=2048.0
var k11, k12, k21, k22, xo, zo: Single; X1, Z1, X2, Z2: Integer;
begin
  Result := 0;
  if (X < -Width  * FCellWidthScale  * 0.5 + epsilon) or (X > Width  * FCellWidthScale  * 0.5 - epsilon) or
     (Z < -Height * FCellHeightScale * 0.5 + epsilon) or (Z > Height * FCellHeightScale * 0.5 - epsilon) then Exit;
  X := X + Width  * FCellWidthScale  * 0.5;
  Z := Z + Height * FCellHeightScale * 0.5;
//  X1 := MinI(Width-1,  MaxI(0, Trunc(X * OneOverCellWidthScale )));     { TODO -cOptimization : Optimize }
//  Z1 := MinI(Height-1, MaxI(0, Trunc(Z * OneOverCellHeightScale)));

  X1 := Trunc(X * OneOverCellWidthScale );
  Z1 := Trunc(Z * OneOverCellHeightScale);
  X2 := MinI(Width-1,  X1 + 1);
  Z2 := MinI(Height-1, Z1 + 1);
  xo := (X - X1 * CellWidthScale) * OneOverCellWidthScale;
  zo := (Z - Z1 * CellHeightScale) * OneOverCellHeightScale;

//  Assert((xo >= 0) and (zo >= 0), Format('xo: %3.3F, zo: %3.3F', [xo, zo]));
  if not ((xo <= 1) and (zo <= 1)) then begin
//    Assert((xo <= 1) and (zo <= 1), Format('xo: %3.3F, zo: %3.3F', [xo, zo]));
  end;

//  CalcCoeffs(xo, zo, k11, k12, k21, k22);

//  Result := GetCellHeight(X1, Z1) * K11 + GetCellHeight(X2, Z2) * K22 + GetCellHeight(X2, Z1) * K21 + GetCellHeight(X1, Z2) * K12;

    k11 := GetCellHeight(X1, Z1);
    k12 := GetCellHeight(X1, Z2);
    k21 := GetCellHeight(X2, Z1);
    k22 := GetCellHeight(X2, Z2);

    Result := (k11 * (1-zo) + k12 * zo) * (1-xo) + (k21 * (1-zo) + k22 * zo) * xo;
end;

function TMap.GetNormal(X, Z: Single): TVector3s;
//var k11, k12, k21, k22, xo, zo: Single; X1, Z1, X2, Z2: Integer;
begin
  Result := GetVector3s(0, 1, 0);
  if (X < -Width  * FCellWidthScale  * 0.5) or (X >= Width  * FCellWidthScale  * 0.5) or
     (Z < -Height * FCellHeightScale * 0.5) or (Z >= Height * FCellHeightScale * 0.5) then Exit;
{  X := X + Width  * FCellWidthScale  * 0.5;
  Z := Z + Height * FCellHeightScale * 0.5;
  X1 := Trunc(X * OneOverCellWidthScale );
  Z1 := Trunc(Z * OneOverCellHeightScale);
  X2 := MinI(Width-1,  X1 + 1);
  Z2 := MinI(Height-1, Z1 + 1);
  xo := (X - X1 * CellWidthScale) * OneOverCellWidthScale;
  zo := (Z - Z1 * CellHeightScale) * OneOverCellHeightScale;

  CalcCoeffs(xo, zo, k11, k12, k21, k22);

  Result.X := GetCellNormal(X1, Z1).X * K11 + GetCellNormal(X2, Z2).X * K22 + GetCellNormal(X2, Z1).X * K21 + GetCellNormal(X1, Z2).X * K12;
  Result.Y := GetCellNormal(X1, Z1).Y * K11 + GetCellNormal(X2, Z2).Y * K22 + GetCellNormal(X2, Z1).Y * K21 + GetCellNormal(X1, Z2).Y * K12;
  Result.Z := GetCellNormal(X1, Z1).Z * K11 + GetCellNormal(X2, Z2).Z * K22 + GetCellNormal(X2, Z1).Z * K21 + GetCellNormal(X1, Z2).Z * K12;
 }
  CrossProductVector3s(Result, GetVector3s(0, GetHeight(X, Z + CellHeightScale) - GetHeight(X, Z - CellHeightScale), CellHeightScale*2),
                               GetVector3s(CellWidthScale*2, GetHeight(X+ CellWidthScale, Z) - GetHeight(X - CellWidthScale, Z), 0) );
end;

procedure TMap.ObtainCell(X, Z: Single; out CellX, CellZ: Integer);
begin
  CellX := Round((X + (Width -1) * CellWidthScale  * 0.5) / CellWidthScale);
  CellZ := Round((Z + (Height-1) * CellHeightScale * 0.5) / CellHeightScale);
end;

function TMap.TraceRay(const Origin, Dir: TVector3s; out Point: TVector3s): Boolean;
var i: Integer; Step: TVector3s;
begin
  Result := False;
  if not IsReady then Exit;
  Point := Origin;
  ScaleVector3s(Step, Dir, MinS(FCellWidthScale, FCellHeightScale) * 0.5);

  Result := True;
  Point := Origin;
  for i := 0 to 10000 do begin //Trunc(0.5 + SQRT2 * RenderPars.ZFar / Landscape.HeightMap.TileSize) do begin
    if GetHeight(Point.X, Point.Z) >= Point.Y then begin
      Exit;
    end;
    Point.X := Point.X + Step.X;
    Point.Y := Point.Y + Step.Y;
    Point.Z := Point.Z + Step.Z;
  end;
  Result := False;
end;

procedure TMap.ObtainRectHeights(const ARect: TRect; ABuf: Pointer);
var DataBuf: PByteBuffer; i, StartI, Ofs, Size: Integer;
begin
  DataBuf := Data;
  if DataBuf = nil then Exit;
  Ofs  := MaxI(0, ARect.Left);
  Size := MinI(Width-1, ARect.Right-1) - Ofs;
  StartI := MaxI(0, ARect.Top);
  for i := StartI to MinI(Height-1, ARect.Bottom-1) do
    Move(DataBuf^[(i * Width + Ofs) * FElementSize], PByteBuffer(ABuf)^[((i - StartI) * (ARect.Right-ARect.Left+1) + ARect.Left) * FElementSize], Size);
end;

procedure TMap.SwapRectHeights(const ARect: TRect; ABuf: Pointer);
var DataBuf, TempBuf: PByteBuffer; i, StartI, Ofs, Size: Integer;
begin
  DataBuf := Data;
  if DataBuf = nil then Exit;
  Ofs  := MaxI(0, ARect.Left);
  Size := MinI(Width, ARect.Right) - Ofs;
  if Size <= 0 then Exit;
  StartI := MaxI(0, ARect.Top);

  GetMem(TempBuf, Size * FElementSize);

  for i := StartI to MinI(Height-1, ARect.Bottom-1) do begin
    Move(DataBuf^[(i * Width + Ofs) * FElementSize], TempBuf^, Size);
    Move(          PByteBuffer(ABuf)^[((i - StartI) * (ARect.Right-ARect.Left) + Ofs - ARect.Left) * FElementSize], DataBuf^[(i * Width + Ofs) * FElementSize], Size);
    Move(TempBuf^, PByteBuffer(ABuf)^[((i - StartI) * (ARect.Right-ARect.Left) + Ofs - ARect.Left) * FElementSize], Size);
  end;

  FreeMem(TempBuf);
end;

procedure TMap.AddRectHeights(const ARect: TRect; ABuf: Pointer; Scale: Single);
var DataBuf: Pointer; i, j, StartI, StartJ: Integer; Value: Single;
begin
  DataBuf := Data;
  if DataBuf = nil then Exit;
  StartI := MaxI(0, ARect.Left);
  StartJ := MaxI(0, ARect.Top);
  for j := StartJ to MinI(Height-1, ARect.Bottom-1) do
    for i := StartI to MinI(Width-1, ARect.Right-1) do begin
      Value := PSingleBuffer(ABuf)^[((j - StartJ) * (ARect.Right-ARect.Left+1) + ARect.Left)] * Scale;
      case FElementSize of
        1: Inc(PByteBuffer(DataBuf)^[(j * Width + StartI + i)], Round(Value));
        2: Inc(PWordBuffer(DataBuf)^[(j * Width + StartI + i) * 2], Round(Value));
        4: Inc(PDWordBuffer(DataBuf)^[(j * Width + StartI + i) * 4], Round(Value));
      end;
    end;
end;

{ TMapEditOp }

procedure TMapEditOp.DoApply;
begin
  if not Assigned(Buffer) then Exit;
  Map.SwapRectHeights(GetRect(CellX - CursorSize div 2, CellZ - CursorSize div 2,
                              CellX - CursorSize div 2 + CursorSize, CellZ - CursorSize div 2 + CursorSize), Buffer);
  Map.SendMessage(TItemModifiedMsg.Create(Map), nil, [mfCore, mfBroadcast]);
end;

destructor TMapEditOp.Destroy;
begin
  if Assigned(Buffer) then FreeMem(Buffer);
  inherited;
end;

end.
