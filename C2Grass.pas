(*
 CAST II Engine grass vegetation unit
 (C) 2006-2008 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Jul 20, 2008
 Unit contains grass visualisation class
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Grass;

interface

uses
  SysUtils, Logger, Basics, BaseTypes, Base3D, Props, BaseMsg, ItemMsg, BaseClasses,
  {$IFDEF EDITORMODE} BaseGraph, C2MapEditMsg, {$ENDIF}
  C2Types, C2Visual, C2VisItems, CAST2, C2Land, C2Maps;

type
  TGrassTesselator = class(TMappedTesselator)
  private
    FDensity, FThreshold, FOscillationIrregularity: Single;
    FRandoms: TRandomGenerator;
    FHeightMap: C2Maps.TMap;
    BoundingBox: TBoundingBox;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;

    procedure Init; override;
    function GetBoundingBox: TBoundingBox; override;
    
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TGrass = class(C2Visual.TMappedItem)
  private
    FHeightMap: C2Maps.TMap;
    ShaderConsts: TShaderConstants;
    FOscillationFreq, FOscillationAmplitude: Single;
  protected
    procedure ResolveLinks; override;
    {$IFDEF EDITORMODE}
    function PickCell(Camera: TCamera; MouseX, MouseY: Integer; out CellX, CellZ: Integer): Boolean; override;
    function DrawCursor(Cursor: C2MapEditMsg.TMapCursor; Camera: TCamera; Screen: TScreen): Boolean; override;
    {$ENDIF}
    procedure InitShaderConstants;
  public
    function GetTesselatorClass: CTesselator; override;

    procedure RetrieveShaderConstants(var ConstList: TShaderConstants); override;
    procedure OnSceneLoaded; override;

    procedure HandleMessage(const Msg: TMessage); override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TRadGridGrassTesselator = class(TRadGridTesselator)
  private
    FGrassHeight, FSampleSize: Single;
  public
    procedure Init; override;
    function GetUpdatedElements(Buffer: TTesselationBuffer; const Params: TTesselationParameters): Integer; override;

    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;

    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TRadGridGrass = class(TProjectedLandscape)
  public
    function GetTesselatorClass: CTesselator; override;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TGrass, TRadGridGrass]);
end;

{ TRadGridGrassTesselator }

const VerticesPerPoint = 6;

procedure TRadGridGrassTesselator.Init;
begin
  inherited;

  if Assigned(FMap) then begin
    TotalVertices   := (FGridWidth+1)*(FGridHeight+1) * VerticesPerPoint;

    TotalIndices    := 0;//(FGridWidth+1)*2;    //  - - 89, 1 - 309-315, 2 - 85
    TotalStrips     := 1;//FGridHeight;
    TotalPrimitives := (FGridWidth+1)*(FGridHeight+1);
    StripOffset     := 0;//FGridWidth+1;
//    StripOffset     := FGridWidth+1;

    SetLength(FMipZ, FGridHeight+1);
//  0  2  4          0 1 2 3 4 5  5 1           P: ??? (w*2)*(h-1)-2 = (3*2)*3-2 = 16
//  1  3  5          1 6 3 7 5 8  8 6           V: w*h = 3*4 = 12
//  6  7  8          6 9 7 A 8 B                I: (2+(w-1)*2+2)*(h-1)-2 = 2*(w+1)*(h-1) = (2+(3-1)*2+2)*3-2 = 8*3-2 = 22
//  9  A  B

{    TotalIndices    := 2*(FGridWidth+2)*(FGridHeight);//-2
    TotalStrips     := 1;
    TotalPrimitives := 2*(FGridWidth+1)*(FGridHeight)-2;//(TotalIndices-2-2);
    StripOffset     := 0;}
  end else begin
    TotalVertices   := 0;
    TotalStrips     := 0;
    TotalIndices    := 0;
    TotalPrimitives := 0;
    StripOffset     := 0;
  end;

  ManualRender := False;

  PrimitiveType := ptTRIANGLELIST;
  TesselationStatus[tbVertex].TesselatorType := ttStatic;
  TesselationStatus[tbIndex].TesselatorType  := ttStatic;

   IndexingVertices := TotalVertices;

//  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));
  InitVertexFormat(GetVertexFormat(False, False, False, False, False, 0, [2]));

  LastTexUpdX := 0;
  LastTexUpdZ := 0;
end;

function TRadGridGrassTesselator.GetUpdatedElements(Buffer: TTesselationBuffer; const Params: TTesselationParameters): Integer;
begin
  Result := inherited GetUpdatedElements(Buffer, Params) * VerticesPerPoint;
end;

function TRadGridGrassTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  HalfLengthX, HalfLengthZ: Single;
  VBuf: PVector3s;
  TVBuf: PVector2s;

  P, P1, P2, P1Incr, P2Incr, PIncr: TVector3s;
  OneOverCellWidthScale, OneOverCellHeightScale: Single;
  i, k, l, X1, Z1, Addr: Integer;
  Data, Data2: Pointer;
  LastY, CurY, xo, zo: Single;
//  LastLine: array[0..1023] of Single;
  OutP: TVector3s;
  DistIncr, FarDist, NearDist, TempK, Error: Single;
  FirstPartK, LastPartK, LightMapScaleX, LightMapScaleZ, MipK, MipDivider, TempX, TempZ: Single;
  MipW, MipH, MipW2, MipH2, Index: Integer;
  IndI, IndJ: Cardinal;

  type
    TData = record
      case Boolean of
        True: (a, b, c, d: Byte);
        False: (d32: Longword);
    end;
  var
    d0, d1, d2, d3: TData;
    ModelInv: TMatrix4s;
    CameraInModel: TVector3s;
    j: Integer;
    Rad, TriSize: Single;

  procedure PutStamp(P: TVector3s);
  begin
    P.X := Round(P.X) div 4 * 4;
    P.Z := Round(P.Z) div 4 * 4;

    P.Y := P.Y + Random * FGrassHeight;

    VBuf^.X := P.X-TriSize;
    VBuf^.Z := P.Z;
    VBuf^.Y := P.Y;
    Single(Pointer(Integer(VBuf) + 12)^) := 0;
    Single(Pointer(Integer(VBuf) + 16)^) := 1;
    VBuf := Pointer(Integer(VBuf) + FVertexSize);

    VBuf^.X := P.X+TriSize;
    VBuf^.Z := P.Z;
    VBuf^.Y := P.Y;
    Single(Pointer(Integer(VBuf) + 12)^) := 1;
    Single(Pointer(Integer(VBuf) + 16)^) := 1;
    VBuf := Pointer(Integer(VBuf) + FVertexSize);

    VBuf^.X := P.X;
    VBuf^.Z := P.Z;
    VBuf^.Y := P.Y+FGrassHeight;
    Single(Pointer(Integer(VBuf) + 12)^) := 0.5;
    Single(Pointer(Integer(VBuf) + 16)^) := 0;
    VBuf := Pointer(Integer(VBuf) + FVertexSize);

    VBuf^.X := P.X;
    VBuf^.Z := P.Z-TriSize;
    VBuf^.Y := P.Y;
    Single(Pointer(Integer(VBuf) + 12)^) := 0;
    Single(Pointer(Integer(VBuf) + 16)^) := 1;
    VBuf := Pointer(Integer(VBuf) + FVertexSize);

    VBuf^.X := P.X;
    VBuf^.Z := P.Z+TriSize;
    VBuf^.Y := P.Y;
    Single(Pointer(Integer(VBuf) + 12)^) := 1;
    Single(Pointer(Integer(VBuf) + 16)^) := 1;
    VBuf := Pointer(Integer(VBuf) + FVertexSize);

    VBuf^.X := P.X;
    VBuf^.Z := P.Z;
    VBuf^.Y := P.Y+FGrassHeight;
    Single(Pointer(Integer(VBuf) + 12)^) := 0.5;
    Single(Pointer(Integer(VBuf) + 16)^) := 0;
    VBuf := Pointer(Integer(VBuf) + FVertexSize);

  //          TColor(Pointer(Integer(VBuf) + 12)^).C := MipColors[k+NearMip];

  end;

begin
  Result := 0;
  if not Assigned(FMap) or not FMap.IsReady then Exit;

  OldCameraMatrix := Params.Camera.Transform;

  ModelInv := InvertAffineMatrix4s(Params.ModelMatrix);
  Transform4Vector33s(CameraInModel, ModelInv, Params.Camera.GetAbsLocation);

  CamOfsX := CameraInModel.X;
  CamOfsZ := CameraInModel.Z;

  HalfLengthX := (FMap.Width-1)  * FMap.CellWidthScale  * 0.5;
  HalfLengthZ := (FMap.Height-1) * FMap.CellHeightScale * 0.5;
  LightMapScaleX := 0.5/HalfLengthX;
  LightMapScaleZ := 0.5/HalfLengthZ;
  OneOverCellWidthScale  := 1/FMap.CellWidthScale;
  OneOverCellHeightScale := 1/FMap.CellHeightScale;

  Rad := 0;
  NearDist := 2*pi * Rad;
  FarDist  := 2*pi * (ViewDepth + 1*ExcessDist);

  DistIncr := FarDist - NearDist;
  if DistIncr < 0 then Exit;

  NearMip := 0;
  while (NearMip < THeightMap(FMap).Image.SuggestedLevels-1) and
        (2*pi*FMap.CellWidthScale * (FGridWidth+1) * (1 shl NearMip) * MipScale <= NearDist) do
    Inc(NearMip);

  FarMip := 0;
  while (FarMip < THeightMap(FMap).Image.SuggestedLevels-1) and
        (2*pi*FMap.CellWidthScale * (FGridWidth+1) * (1 shl FarMip) * MipScale <= FarDist) do
    Inc(FarMip);

  for i := NearMip to FarMip do MipStart[i-NearMip+1] := (FMap.CellWidthScale * (FGridWidth+1) * (1 shl i) * MipScale-NearDist) / DistIncr;
  if MipStart[FarMip-NearMip+1] < 1 then begin
//    Assert(MipStart[FarMip-NearMip+1] >= 1);
  end;
  if FarMip-NearMip >= 1 then begin
    MipStart[0] := -(MipStart[2] - 3*MipStart[1])/2;
    FirstPartK  := MipStart[1]/(MipStart[1] - MipStart[0]);
    LastPartK   := (1-MipStart[FarMip-NearMip])/(MipStart[FarMip-NearMip+1] - MipStart[FarMip-NearMip]);
    TempK := 1/(FirstPartK + FarMip - NearMip - 1 + LastPartK);
    MipDetail[0] := Round(FirstPartK * TempK * (FGridHeight+1));
    Error := FirstPartK * TempK * (FGridHeight+1) - MipDetail[0];
    for i := NearMip+1 to FarMip-1 do begin
      MipDetail[i-NearMip] := Round(TempK * (FGridHeight+1) + Error);
      Error := (TempK * (FGridHeight+1) + Error) - MipDetail[i-NearMip];
    end;
    MipDetail[FarMip-NearMip] := Round(LastPartK * TempK * (FGridHeight+1) + Error);
    Error := (LastPartK * TempK * (FGridHeight+1) + Error) - MipDetail[FarMip-NearMip];
    if Error >= 0.5 then Inc(MipDetail[0]);

    if MipDetail[FarMip-NearMip] <= 1 then begin
      Inc(MipDetail[FarMip-NearMip-1], MipDetail[FarMip-NearMip]);
      Dec(FarMip);
    end;

    Error := 0;
    for i := 0 to FarMip-NearMip do Error := Error + MipDetail[i];
    Assert(Error = (FGridHeight+1));
  end else begin
    MipDetail[0] := (FGridHeight+1);
  end;

  MipStart[0] := 0;
  MipStart[FarMip-NearMip+1] := 1;

  VBuf := VBPTR;
  TVBuf := @FGrid[0];

  j := 0;

  for k := 0 to FarMip-NearMip do begin
    Data  := PtrOffs(FMap.Data, THeightMap(FMap).Image.LevelInfo[k + NearMip].Offset);
    Data2 := PtrOffs(FMap.Data, THeightMap(FMap).Image.LevelInfo[k + NearMip+1].Offset);

    MipDivider := 1/(1 shl (k + NearMip));
    MipW  := FMap.Width  shr (k + NearMip);
    MipH  := FMap.Height shr (k + NearMip);
    MipW2 := FMap.Width  shr (k + NearMip+1);
    MipH2 := FMap.Height shr (k + NearMip+1);

    for l := 0 to MipDetail[k]-1 do begin
//      Rad := (ViewDepth + ExcessDist) * (MipStart[k] + l*(MipStart[k+1] - MipStart[k])/(MipDetail[k]-Ord(k = FarMip-NearMip)));
//      FMipZ[j] := Rad;
//      Sqrt(SqrMagnitude(GetVector3s(P1.X - CamOfsX, 0, P1.Z - CamOfsZ)));
      TriSize := (1+FMipZ[j])*FSampleSize;
      Inc(j);

//      ScaleVector3s(PIncr, SubVector3s(P2, P1), 1 / FGridWidth);
//      P := P1;

      MipK := MaxS(0, l/MipDetail[k] - (1-TrilinearRange))/TrilinearRange;

      if MipK < epsilon then begin
        for i := 0 to FGridWidth do begin
          P.X := CamOfsX - TVBuf^.X;
          P.Z := CamOfsZ + TVBuf^.Y;

          TempX := (ClampS(P.X, -HalfLengthX, HalfLengthX) + HalfLengthX) * OneOverCellWidthScale  * MipDivider;
          TempZ := (ClampS(P.Z, -HalfLengthZ, HalfLengthZ) + HalfLengthZ) * OneOverCellHeightScale * MipDivider;

          X1 := FastTrunc(TempX);
          Z1 := FastTrunc(TempZ);

          xo := (TempX - X1);// * Ord(X1 >= 0) * Ord(X1 < MipW);
          zo := (TempZ - Z1);// * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          X1 := X1 * Ord(X1 >= 0) * Ord(X1 < MipW);
          Z1 := Z1 * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          Addr := Z1 * MipW + X1;
          // May read 2 bytes outside texture data. It's safe because these 2 bytes will go from next mipmap.
          d0.d32 := PLongword(Integer(Data) + Addr - MipW * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1))^;
          d3.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1) + MipW * Ord(Z1 < MipH-2))^;

          P.Y := ((1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo)) * FMap.DepthScale * 0.25;

          PutStamp(P);

          TVBuf := Pointer(Integer(TVBuf) + SizeOf(TVector2s));
        end;
      end else begin
        for i := 0 to FGridWidth do begin
          P.X := CamOfsX - TVBuf^.X;
          P.Z := CamOfsZ + TVBuf^.Y;

          TempX := (ClampS(P.X, -HalfLengthX, HalfLengthX) + HalfLengthX) * OneOverCellWidthScale  * MipDivider;
          TempZ := (ClampS(P.Z, -HalfLengthZ, HalfLengthZ) + HalfLengthZ) * OneOverCellHeightScale * MipDivider;

          X1 := FastTrunc(TempX);
          Z1 := FastTrunc(TempZ);

          xo := (TempX - X1){ * Ord(X1 >= 0) * Ord(X1 < MipW)};
          zo := (TempZ - Z1){ * Ord(Z1 >= 0) * Ord(Z1 < MipH)};

          X1 := X1 * Ord(X1 >= 0) * Ord(X1 < MipW);
          Z1 := Z1 * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          Addr := Z1 * MipW + X1;
          d0.d32 := PLongword(Integer(Data) + Addr - MipW * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1))^;
          d3.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1) + MipW * Ord(Z1 < MipH-2))^;

          P.Y := ((1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo));
          // Second mip
          xo := (xo + X1 and 1)*0.5;
          zo := (zo + Z1 and 1)*0.5;
          X1 := X1 shr 1;
          Z1 := Z1 shr 1;

          Addr := Z1 * MipW2 + X1;

          d0.d32 := PLongword(Integer(Data2) + Addr - MipW2 * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0) + MipW2 * Ord(Z1 < MipH2-1))^;
          d3.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0) + MipW2 * Ord(Z1 < MipH2-1) + MipW2 * Ord(Z1 < MipH2-2))^;

          P.Y := 0.25*(P.Y * (1 - MipK) + MipK * (
                  (1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo)) ) * FMap.DepthScale;

          PutStamp(P);

          TVBuf := Pointer(Integer(TVBuf) + SizeOf(TVector2s));
        end;
      end;
    end;
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
//  TesselationStatus[tbVertex].Status := tsChanged;
  Result  := TotalVertices;
//  Assert((FGridWidth+1)*jj = Result);
  LastTotalVertices := TotalVertices;
end;

procedure TRadGridGrassTesselator.AddProperties(const Result: TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Assigned(Result) then begin
    Result.Add(PropNamePrefix + 'Height',      vtSingle, [], FloatToStr(FGrassHeight), '0.1-4');
    Result.Add(PropNamePrefix + 'Sample size', vtSingle, [], FloatToStr(FSampleSize),  '0.03-3');
  end;
end;

procedure TRadGridGrassTesselator.SetProperties(Properties: TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid(PropNamePrefix + 'Height')      then FGrassHeight := StrToFloatDef(Properties[PropNamePrefix + 'Height'], 1);
  if Properties.Valid(PropNamePrefix + 'Sample size') then FSampleSize  := StrToFloatDef(Properties[PropNamePrefix + 'Sample size'], 0.1);
end;

{ TRadGridGrass }

function TRadGridGrass.GetTesselatorClass: CTesselator; begin Result := TRadGridGrassTesselator; end;

{ TGrass }

procedure TGrass.ResolveLinks;
var Item: TItem;
begin
  inherited;

  if CurrentTesselator is TGrassTesselator then begin
    ResolveLink('Height map', Item);
    if Assigned(Item) then begin
      FHeightMap := Item as C2Maps.TMap;
      (CurrentTesselator as TGrassTesselator).FHeightMap := FHeightMap;
      CurrentTesselator.Init;
    end;
  end;
end;

{$IFDEF EDITORMODE}
function TGrass.PickCell(Camera: TCamera; MouseX, MouseY: Integer; out CellX, CellZ: Integer): Boolean;
var CameraPos, PickRay, PickPos: TVector3s; M: TMatrix4s;
begin
  Result := False;
  if not Assigned(FHeightMap) then Exit;
  // Transform camera position and pick ray to model space
  M := InvertMatrix4s(Transform);
  CameraPos := Transform4Vector33s(M, Camera.Position);
  PickRay := Camera.GetPickRay(MouseX, MouseY);
  PickRay := Transform3Vector3s(CutMatrix3s(InvertAffineMatrix4s(Camera.ViewMatrix)), PickRay);
  PickRay.Y := PickRay.Y;
  PickRay := NormalizeVector3s(Transform3Vector3s(CutMatrix3s(M), PickRay));
  Result := FHeightMap.TraceRay(CameraPos, PickRay, PickPos);
  if Result then Map.ObtainCell(PickPos.X, PickPos.Z, CellX, CellZ);
end;

function TGrass.DrawCursor(Cursor: TMapCursor; Camera: TCamera; Screen: TScreen): Boolean;

  procedure DrawCell(CellX, CellZ: Integer);
  var v: TVector3s;
  begin
    if (CellX < 1) or (CellZ < 1) or (CellX > FMap.Width-2) or (CellZ > FMap.Height-2) then Exit;

    v.x := (CellX - (FMap.Width -1) * 0.5) * FMap.CellWidthScale;
    v.z := (CellZ - (FMap.Height-1) * 0.5) * FMap.CellHeightScale;
    v.y := FHeightMap.GetHeight(v.x, v.z);
    Screen.MoveToVec(Camera.Project(Transform4Vector33s(Transform, v)).xyz);
    v.y := v.y + (FMap[CellX, CellZ]+1) * FMap.DepthScale * 0.5;
    Screen.LineToVec(Camera.Project(Transform4Vector33s(Transform, v)).xyz);
  end;

  procedure DrawCursorAt(CellX, CellZ, Size: Integer);
  var i, j: Integer;
  begin
//    Screen.MoveTo(0, 0);
//    Screen.LineTo(0, 0);
    for i := CellX - Size div 2 to CellX + Size div 2 do
      for j := CellZ - Size div 2 to CellZ + Size div 2 do DrawCell(i, j);
  end;

begin
  Result := False;
  if not EditMode and not PickCell(Camera, Cursor.MouseX, Cursor.MouseY, EditCellX, EditCellZ) then Exit;

  DrawCursorAt(EditCellX, EditCellZ, Cursor.Params.GetAsInteger('Size'));

  Result := True;
end;
{$ENDIF}

procedure TGrass.InitShaderConstants;
begin
  SetLength(ShaderConsts, 2);
  ShaderConsts[0].ShaderKind     := skVertex;
  ShaderConsts[0].ShaderRegister := 8;
  ShaderConsts[0].Value          := Vec4s(FOscillationAmplitude * Sin(TimeProcessed*FOscillationFreq*2*pi),      FOscillationAmplitude * Sin(TimeProcessed*FOscillationFreq*2*pi+pi/4),
                                          FOscillationAmplitude * Sin(TimeProcessed*FOscillationFreq*2*pi+pi/2), FOscillationAmplitude * Sin(TimeProcessed*FOscillationFreq*2*pi+3*pi/4));
  ShaderConsts[1].ShaderKind     := skVertex;
  ShaderConsts[1].ShaderRegister := 9;
  ShaderConsts[1].Value          := Vec4s(1/(FHeightMap.Width*FHeightMap.CellWidthScale), 1/(FHeightMap.Height*FHeightMap.CellHeightScale), 0.5*FHeightMap.Width*FHeightMap.CellWidthScale, 0.5*FHeightMap.Height*FHeightMap.CellHeightScale);
end;

function TGrass.GetTesselatorClass: CTesselator; begin Result := TGrassTesselator; end;

procedure TGrass.RetrieveShaderConstants(var ConstList: TShaderConstants);
begin
  ShaderConsts[0].Value := Vec4s(FOscillationAmplitude * Sin(TimeProcessed*FOscillationFreq*2*pi),      FOscillationAmplitude * Sin(TimeProcessed*FOscillationFreq*2*pi+pi/4),
                                 FOscillationAmplitude * Sin(TimeProcessed*FOscillationFreq*2*pi+pi/2), FOscillationAmplitude * Sin(TimeProcessed*FOscillationFreq*2*pi+3*pi/4));
  ShaderConsts[1].Value := Vec4s(1/(FHeightMap.Width*FHeightMap.CellWidthScale), 1/(FHeightMap.Height*FHeightMap.CellHeightScale), 0.5*FHeightMap.Width*FHeightMap.CellWidthScale, 0.5*FHeightMap.Height*FHeightMap.CellHeightScale);
  ConstList := ShaderConsts;
end;

procedure TGrass.OnSceneLoaded;
begin
  InitShaderConstants;
end;

procedure TGrass.AddProperties(const Result: TProperties);
begin
  inherited;
  AddItemLink(Result, 'Height map', [], 'TMap');
  if Result <> nil then begin
    Result.Add('Oscillation frequency',    vtSingle, [], FloatToStr(FOscillationFreq),         '0.1-2');
    Result.Add('Oscillation amplitude',    vtSingle, [], FloatToStr(FOscillationAmplitude),    '0.1-2');
  end;
end;

procedure TGrass.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Height map') then SetLinkProperty('Height map', Properties['Height map']);
  if Properties.Valid('Oscillation frequency')    then FOscillationFreq         := StrToFloatDef(Properties['Oscillation frequency'], 0.1);
  if Properties.Valid('Oscillation amplitude')    then FOscillationAmplitude    := StrToFloatDef(Properties['Oscillation amplitude'], 0.1);

  ResolveLinks;
end;

procedure TGrass.HandleMessage(const Msg: TMessage);
begin
  inherited;
  if (Msg.ClassType = TItemModifiedMsg) and (TItemModifiedMsg(Msg).Item = FHeightMap) and Assigned(FCurrentTesselator) then
    FCurrentTesselator.Invalidate([tbVertex, tbIndex], False);
end;

{ TGrassTesselator }

constructor TGrassTesselator.Create;
begin
  inherited;
  FRandoms := TRandomGenerator.Create;
  FRandoms.InitSequence(0, 195);
end;

destructor TGrassTesselator.Destroy;
begin
  FreeAndNil(FRandoms);
  inherited;
end;

procedure TGrassTesselator.AddProperties(const Result: TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Assigned(Result) then begin
    Result.Add(PropNamePrefix + 'Density',   vtSingle, [], FloatToStr(FDensity),     '0.05-10');
    Result.Add(PropNamePrefix + 'Threshold', vtSingle, [], FloatToStr(FThreshold),   '0.01-1');

    Result.Add(PropNamePrefix + 'Oscillation irregularity', vtSingle, [], FloatToStr(FOscillationIrregularity), '0-1');
  end;
end;

procedure TGrassTesselator.SetProperties(Properties: TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid(PropNamePrefix + 'Density')   then FDensity     := StrToFloatDef(Properties[PropNamePrefix + 'Density'], 1);
  if Properties.Valid(PropNamePrefix + 'Threshold') then FThreshold   := StrToFloatDef(Properties[PropNamePrefix + 'Threshold'], 0.1);

  if Properties.Valid(PropNamePrefix + 'Oscillation irregularity') then FOscillationIrregularity := StrToFloatDef(Properties[PropNamePrefix + 'Oscillation irregularity'], 0.5);
  Init;
end;

procedure TGrassTesselator.Init;
begin
  inherited;
  if Assigned(FMap) then begin
    TotalVertices   := FMap.Width*FMap.Height*2*3*2;
//    TotalIndices    := MaxI(0, (FMap.Width-1)) * MaxI(0, (FMap.Height-1)) * 6;
    TotalPrimitives := FMap.Width * FMap.Height * 2*2;
  end else begin
    TotalVertices   := 0;
    TotalIndices    := 0;
    TotalPrimitives := 0;
  end;
  IndexingVertices := TotalVertices;
  PrimitiveType    := ptTRIANGLELIST;
  InitVertexFormat(GetVertexFormat(False, False, False, False, False, 0, [3]));
  BoundingBox := EmptyBoundingBox;
end;

function TGrassTesselator.GetBoundingBox: TBoundingBox;
begin
  Result := BoundingBox;
{  Result.P2 := ZeroVector3s;
  if not Assigned(FMap) or (FMap.Width = 0) or (FMap.Height = 0) then Exit;
  Result.P1 := GetVector3s(-(FMap.Width-1)  * FMap.CellWidthScale * 0.5,
                            0,
                           -(FMap.Height-1) * FMap.CellHeightScale * 0.5);
  Result.P2 := GetVector3s( (FMap.Width-1)  * FMap.CellWidthScale * 0.5,
                            FMap.MaxHeight * FMap.DepthScale,
                            (FMap.Height-1) * FMap.CellHeightScale * 0.5);

  if Assigned(FHeightMap) then Result.P2.Y := Result.P2.Y + FHeightMap.MaxHeight * FHeightMap.DepthScale;}
end;

function TGrassTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
const RndOffs: array[0..15] of Single =
  (0.00, 0.05, 0.01, 0.15,
   0.02, 0.25, 0.03, 0.35,
   0.65, 0.70, 0.75, 0.80,
   0.85, 0.90, 0.95, 1.0);

var
  VBuf: PVector3s;
  Scattering: Single;

  procedure PutStamp(PX, PZ, H: Single);
  var d, u1, u2, y: Single; Osc: Cardinal;
    procedure AddVertex(X, Y, Z, U, V: Single);
    begin
      VBuf^.X := X;
      VBuf^.Z := Z;
      VBuf^.Y := Y;
      Single(Pointer(Integer(VBuf) + 12)^) := U*0.25;
      Single(Pointer(Integer(VBuf) + 16)^) := V;
      Single(Pointer(Integer(VBuf) + 20)^) := RndOffs[Osc];
      VBuf := Pointer(Integer(VBuf) + FVertexSize);
      Inc(Result);
    end;
  begin
//    P.X := Round(P.X) div 4 * 4;
//    P.Z := Round(P.Z) div 4 * 4;            //  (0,0) l /l (1,0)
//    P.Y := P.Y + Random * FGrassHeight;     //  (0,1) l/_l (1,1)

    u1 := FRandoms.RndI(4);
    u2 := FRandoms.RndI(4);
    Osc := FRandoms.RndI(1+Round(High(RndOffs)*FOscillationIrregularity));

//    if u1 = 1 then u1 := 2;
//    if u2 = 1 then u2 := 0;
//    if FRandoms.RndI(30)=0 then u1 := 1;

    d := Scattering * (0.5 + FRandoms.Rnd(1));

    if h < FThreshold*255 then Exit;

    h := h * FMap.DepthScale;

    y := FHeightMap.GetHeight(PX, PZ);

    ExpandBBox(BoundingBox, PX, y+h, PZ);

    AddVertex(PX-d, y,   PZ, u1,   1);
    AddVertex(PX+d, y,   PZ, u1+1, 1);
    AddVertex(PX+d, y+h, PZ, u1+1, 0);
    AddVertex(PX-d, y,   PZ, u1,   1);
    AddVertex(PX+d, y+h, PZ, u1+1, 0);
    AddVertex(PX-d, y+h, PZ, u1,   0);

    AddVertex(PX, y,   PZ-d, u2,   1);
    AddVertex(PX, y,   PZ+d, u2+1, 1);
    AddVertex(PX, y+h, PZ+d, u2+1, 0);
    AddVertex(PX, y,   PZ-d, u2,   1);
    AddVertex(PX, y+h, PZ+d, u2+1, 0);
    AddVertex(PX, y+h, PZ-d, u2,   0);
  end;

var i, j: Integer;
begin
  Result := 0;
  if not Assigned(FMap) or not Assigned(FHeightMap) or not FMap.IsReady then Exit;

  BoundingBox := EmptyBoundingBox;
  BoundingBox.P1.Y := BoundingBox.P1.Y + FHeightMap.MaxHeight * FHeightMap.DepthScale;

  FRandoms.InitSequence(0, 195);

  Scattering := 1/Sqrt(FDensity);

  FMap.CellWidthScale  := Scattering;
  FMap.CellHeightScale := Scattering;

  VBuf := VBPTR;

  for i := 0 to FMap.Width-1 do
    for j := 0 to FMap.Height-1 do
      PutStamp((i-FMap.Width *0.5 + FRandoms.RndSymm(0.5))*Scattering,
               (j-FMap.Height*0.5 + FRandoms.RndSymm(0.5))*Scattering, FMap[i, j]);

  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalVertices := Result;
  TotalPrimitives := Result div 3;
  InvalidateBoundingBox
end;

begin
  GlobalClassList.Add('C2Grass', GetUnitClassList);
end.
