{$Include GDefines.inc}
{$Include CDefines.inc}
unit CTess;

interface

uses CTypes, CMaps, Basics, Adv2D, Base3D {$IFDEF DEBUGMODE}, SysUtils {$ENDIF};

type
  TesselatorStatus = (tsChanged, tsSizeChanged, tsTesselated);

  CTesselator = class of TTesselator;
  CMeshTesselator = class of TMeshTesselator;

  TTesselator = class
//    Name: TShortName;
    Index: Integer;

    VStatus, IStatus: TesselatorStatus;
    LastTotalIndices, LastTotalVertices: Integer;
    LastFrameTesselated, LastFrameVisualized: Integer;

//    Stream: Cardinal;
    CommandBlock: Integer;                              // Command block ID For render speedup. E.g. OpenGL display list ID
    CommandBlockValid: Boolean;                         // These two values must be initialized

    IBOffset, VBOffset: Integer;                        // Offsets in elements (vertices, indices), not bytes
    MeshManagerCleanCount: Integer;

    VertexFormat, VertexSize: Cardinal;
    TotalPrimitives, PrimitiveType: Integer;
    TotalVertices, TotalIndices: Integer;
    Vertices, Indices: Pointer;
    TotalStrips, StripOffset: Integer;
    IndexingVertices: Integer;

    VerticesRes, IndicesRes: Integer;

    CompositeMember: Boolean;
    CompositeOffset: ^TVector3s;

//    BoundingBox: TBoundingBox;
    FXStatus: TFXStatus;
    constructor Create(const AName: TShortName); virtual;
    procedure InitVertexFormat(Format: Cardinal); virtual;                             // Must be called after change of vertexformat
    function IncRef: Integer; virtual;
    function DecRef: Integer; virtual;
    procedure Invalidate(EntireBuffer: Boolean); virtual;
    function MatchMesh(AMesh: TTesselator): Boolean; virtual;
    function CalcBoundingBox: TBoundingBox; virtual;
    function SetIndices(IBPTR: Pointer): Integer; virtual;
    function GetMaxVertices: Integer; virtual;
    function GetMaxIndices: Integer; virtual;
    function CheckGeometry(const Camera: TCamera): Boolean; virtual;
    procedure SetVertexDataC(x, y, z: Single; Index: Integer; VBuf: Pointer);
    procedure SetVertexDataN(nx, ny, nz: Single; Index: Integer; VBuf: Pointer);
    procedure SetVertexDataW(w: Single; Index: Integer; VBuf: Pointer);
    procedure SetVertexDataD(Color: Cardinal; Index: Integer; VBuf: Pointer);
    procedure SetVertexDataS(Color: Cardinal; Index: Integer; VBuf: Pointer);
    procedure SetVertexDataUV(u, v: Single; Index: Integer; VBuf: Pointer);
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; virtual;
    destructor Free;
  private
    CoordsOfs, NormalOfs, WeightsOfs, DiffuseOfs, SpecOfs, UVOfs: Cardinal; // Vertex components offset
    OldDeltaFrame: TCamera;
    RefCount: Integer;
  end;

  TLandscapeTesselator = class(TTesselator)
    HMap: TMap;
    Map: Pointer;
    Vertices: Pointer;
    // Heightmap parameters
    CellPower: Cardinal;
    HMapWidth, HMapHeight: Integer;
    HMapPower, HeightPower: Integer;
    // Engine parameters
    TextureMag: Single;
    constructor Create(const AName: TShortName); override;
    procedure Init(const AHMap: TMap; const AMap: Pointer); virtual;
  end;

  TBigLandscapeTesselator = class(TLandscapeTesselator)
    // Engine parameters
    ScreenMinY: Integer;
    XAcc, AAcc, DepthOfView, Smooth: Cardinal;
    procedure Init(const AHMap: TMap; const AMap: Pointer); override;
    procedure SetParameters(XAccuracy, AAccuracy, ADepthOfView, ASmooth: Cardinal);
    function SetIndices(IBPTR: Pointer): Integer; override;
    function GetMaxVertices: Integer; override;
    function GetMaxIndices: Integer; override;
    function CheckGeometry(const Camera: TCamera): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TIslandTesselator = class(TLandscapeTesselator)
    IslandScaleX ,IslandScaleY, IslandScaleZ, IslandThickness: Single;
    procedure Init(const AHMap: TMap; const AMap: Pointer); override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    function GetMaxVertices: Integer; override;
    function CheckGeometry(const Camera: TCamera): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TMeshTesselator = class(TTesselator)
    constructor Create(AName: TShortName; ATotalVertices: Integer; AVertices: Pointer; ATotalIndices: Integer; AIndices: Pointer); virtual;  //ToFix: Fix to standard constructor
    constructor CreateFromFile(FileName: TFileName);
    constructor CreateFromMesh(AMesh: TTesselator);
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TScaledMeshTesselator = class(TMeshTesselator)
    Direction: TVector3s;
    constructor Create(AName: TShortName; ATotalVertices: Integer; AVertices: Pointer; ATotalIndices: Integer; AIndices: Pointer); override;  //ToFix: Fix to standard constructor
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TDiffMeshTesselator = class(TMeshTesselator)
// Any vertex format with diffuse component
    Diffuse: Longword;
    constructor Create(AName: TShortName; ATotalVertices: Integer; AVertices: Pointer; ATotalIndices: Integer; AIndices: Pointer); virtual;  //ToFix: Fix to standard constructor
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TDiffUVRotatedMeshTesselator = class(TMeshTesselator)
// Any vertex format with diffuse, U and V component
    Diffuse: Longword;
    UVAngle, UVRadius: Single;
    constructor Create(AName: TShortName; ATotalVertices: Integer; AVertices: Pointer; ATotalIndices: Integer; AIndices: Pointer); virtual;  //ToFix: Fix to standard constructor
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TTreeMesh = class(TTesselator)
    TreeHeight, TreeRadius, TreeSmoothing: Integer;
    constructor Create;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TSkyDomeTesselator = class(TTesselator)
    Sectors, Segments: Integer;
    Radius, Height, TexK: Single;
    SMWidth, SMHeight: Integer;
    SkyMap: PImageBuffer;
    TexClamp, Inner, Vertical: Boolean;
    constructor Create(const AName: TShortName); override;
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    procedure SetParameters(ASectors, ASegments: Integer; ARadius, AHeight, ATexK: Single; ATexClamp, AInner, AVertical: Boolean); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    destructor Free;
  end;

var
  RGBA: Boolean;
{$IFDEF DEBUGMODE}
  DebugStr: string;
{$ENDIF}

implementation

constructor TTesselator.Create(const AName: TShortName);
begin
//  Name := AName;
  RefCount := 0;
  LastFrameTesselated := -1;
  VertexFormat := GetVertexFormat(False, True, False, False, 1, 0);
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
  LastTotalIndices := 0; LastTotalVertices := 0;
  TotalStrips := 1; StripOffset := 0;
  IBOffset := 0; VBOffset := 0;

  VerticesRes := -1; IndicesRes := -1;

  CompositeOffset := nil;
  CompositeMember := False;

  MeshManagerCleanCount := -1;
  CommandBlock := -1;
  CommandBlockValid := False;
end;

function TTesselator.IncRef: Integer;
begin
  Inc(RefCount); Result := RefCount;
end;

function TTesselator.DecRef: Integer;
begin
  Dec(RefCount);
  Result := RefCount;
  if RefCount <= 0 then Free;
end;

procedure TTesselator.Invalidate(EntireBuffer: Boolean);
begin
  if EntireBuffer then begin
    VStatus := tsSizeChanged; IStatus := tsSizeChanged;
  end else begin
    VStatus := tsChanged; IStatus := tsChanged;
  end;
  CommandBlockValid := False;
end;

function TTesselator.MatchMesh(AMesh: TTesselator): Boolean;
begin
  Result := False;
end;

function TTesselator.CalcBoundingBox: TBoundingBox;
var i: Integer;
begin
  if Vertices = nil then Exit;
  Result.P1 := GetVector3s(100000, 100000, 100000); Result.P2 := GetVector3s(-100000, -100000, -100000);
  for i := 0 to TotalVertices-1 do with TVector3s((@TByteBuffer(Vertices^)[i*Integer(VertexSize)])^), Result do begin
    if X < P1.X then P1.X := X; if Y < P1.Y then P1.Y := Y; if Z < P1.Z then P1.Z := Z;
    if X > P2.X then P2.X := X; if Y > P2.Y then P2.Y := Y; if Z > P2.Z then P2.Z := Z;
  end;
end;

function TTesselator.SetIndices(IBPTR: Pointer): Integer;
begin
  Move(TWordBuffer(Indices^)[0], TWordBuffer(IBPTR^)[0], TotalIndices*2);
  LastTotalIndices := TotalIndices;
  IStatus := tsTesselated;
  Result := TotalIndices;
end;

function TTesselator.GetMaxVertices: Integer;
begin
  Result := TotalVertices;
end;

function TTesselator.GetMaxIndices: Integer;
begin
  Result := TotalIndices;
end;

function TTesselator.CheckGeometry(const Camera: TCamera): Boolean;
begin
  Result := False;
end;

function TTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
begin
  Result := 0;
  LastTotalVertices := TotalVertices;
end;

// TBigLandscapeTesselator
procedure TBigLandscapeTesselator.Init(const AHMap: TMap; const AMap: Pointer);
begin
  inherited;
  HMapPower := HMapPower+2;
  Vertices := nil; TotalVertices := 0;
  Indices := nil; TotalIndices := 0;
  TotalPrimitives := 0;
  IndexingVertices := 0;
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
//  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  VerticesRes := -1; IndicesRes := -1;
end;

procedure TBigLandscapeTesselator.SetParameters(XAccuracy, AAccuracy, ADepthOfView, ASmooth: Cardinal);
begin
  XAcc := XAccuracy; AAcc := AAccuracy; DepthOfView := ADepthOfView; Smooth := ASmooth;
  TotalVertices := (AAcc+1)*(XAcc+1)*2;
  TotalIndices := (XAcc + 1) * 2;
  TotalStrips := AAcc - 1;
  TotalPrimitives := XAcc * 2;
  StripOffset := XAcc + 1;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
  LastTotalIndices := 0; LastTotalVertices := 0;
  IndexingVertices := TotalIndices;
//  SetLength(Vertices, (AAcc+1)*(XAcc+1)*2*24);
//  SetLength(Indices,(XAcc+1)*2);
end;

function TBigLandscapeTesselator.SetIndices(IBPTR: Pointer): Integer;
var i: Cardinal;
begin
  for i := 0 to XAcc do begin
    TWordBuffer(IBPTR^)[i * 2] := i;
    TWordBuffer(IBPTR^)[i * 2 + 1] := i + XAcc + 1;
  end;
  Result := (XAcc+1) * 2;
  IStatus := tsChanged;
  LastTotalIndices := TotalIndices;
end;

function TBigLandscapeTesselator.GetMaxVertices: Integer;
begin
  Result := (XAcc + 1) * (AAcc + 1);
end;

function TBigLandscapeTesselator.GetMaxIndices: Integer;
begin
  Result := (XAcc + 1) * 2;
end;

function TBigLandscapeTesselator.CheckGeometry(const Camera: TCamera): Boolean;
begin
  if (OldDeltaFrame.X = Camera.X) and (OldDeltaFrame.Y = Camera.Y) and (OldDeltaFrame.Z = Camera.Z) and
     (OldDeltaFrame.XAngle = Camera.XAngle) and (OldDeltaFrame.YAngle = Camera.YAngle) and (OldDeltaFrame.ZAngle = Camera.ZAngle) then begin
    Result := False;
  end else begin
    OldDeltaFrame.X := Camera.X; OldDeltaFrame.Y := Camera.Y; OldDeltaFrame.Z := Camera.Z;
    OldDeltaFrame.XAngle := Camera.XAngle; OldDeltaFrame.YAngle := Camera.YAngle; OldDeltaFrame.ZAngle := Camera.ZAngle;
//    OldDeltaFrame.DepthOfView := Camera.DepthOfView;
    Result := True;
  end;
end;

function TBigLandscapeTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var
  i, j, CameraX, CameraZ: Integer;
  MapOffset, VBOffset: Cardinal;

  EX, EZ: Single;
  // StartEZ,
  EndEZ: Single;
  XAR, SinYA, CosYA: Single;

  StripCount: Word;
  CurX, StepX, CurZ, StepZ: Integer;
  // CX, StepX, CZ, StepZ: Single;
  Dist, MinAngle, MaxAngle: Single;

  NXI, NZI, XI, ZI: Integer;

  CR, CG, CB, Alpha: Longint;
  XO, ZO: Integer;

  XI_ZI, NXI_ZI, XI_NZI, NXI_NZI: Cardinal;

  ResY: Integer;
  TextureK: Single;

  TilePower, TileSize: Cardinal;
  MapWidthMask, MapHeightMask, MapXSizeMask, MapZSizeMask, MapLengthX, MapLengthZ, MapYStepBytes: Integer;
  MapPower, LHeightPower: Cardinal;
  VBInd: Cardinal;

  ANDMaskX, ANDMaskZ: Cardinal;
  ProjAngle, StartEX, StartEZ, EndEX, StepI, AStep: Single;
  h1, h2: Single;

  VFoV: Single;
  OldColor, Smth, Col: Longword;

const MaxSI = 1; OneOver256 = 1/256;

// Idea: Cache calculated values
begin
  CameraX := Trunc(0.5+RenderPars.Camera.X);
  CameraZ := Trunc(0.5+RenderPars.Camera.Z);
  TilePower := CellPower;
  TileSize := 1 shl CellPower;

  MapWidthMask := HMapWidth - 1;                            // Masks for map cycling
  MapHeightMask := HMapHeight - 1;
  MapXSizeMask := HMapWidth * 4 - 1;
  MapZSizeMask := HMapWidth * HMapHeight * 4 - 1;
  MapYStepBytes := 4 * HMapWidth;
  MapLengthX := HMapWidth shl TilePower- 1;
  MapLengthZ := HMapHeight shl TilePower- 1;
  MapPower := HMapPower;                                    // Constant for fast multiplication
  LHeightPower := HeightPower;

  TextureK := 1 / TileSize * TextureMag;

  Smth := Smooth;

  ScreenMinY := RenderPars.ActualHeight;

  VFoV := ArcTan(Sin(RenderPars.Fov / 2)/Cos(RenderPars.Fov / 2)/RenderPars.CurrentAspectRatio);

  XAR := RenderPars.Camera.XAngle;
  MinAngle := XAR - VFoV;
  if MinAngle > -pi/2 then MinAngle := -pi/2;
  MaxAngle := XAR + VFoV;
  if MaxAngle >= 0 then begin
    EndEZ := DepthOfView*TileSize;
//    MaxAngle := ArcTan(RenderPars.Camera.Y / EndEZ);
  end else begin
    EndEZ := -RenderPars.Camera.Y * Cos(MaxAngle) / Sin(MaxAngle) + TileSize*2;
  end;
  if EndEZ > DepthOfView*TileSize then begin
    EndEZ := DepthOfView*TileSize;
//    MaxAngle := ArcTan(RenderPars.Camera.Y / EndEZ);
  end;
  Dist := Sqrt( Sqr(RenderPars.Camera.Y+0.5) + EndEZ * EndEZ);
  EndEX := Dist * Sin(RenderPars.FoV / 2) / Cos(RenderPars.FoV / 2) + TileSize * 2;
  StartEZ := -RenderPars.Camera.Y * Cos(MinAngle) / Sin(MinAngle) - TileSize;
  Dist := Sqrt( Sqr(RenderPars.Camera.Y+0.5) + StartEZ * StartEZ);
  StartEX := Dist * Sin(RenderPars.FoV / 2) / Cos(RenderPars.FoV / 2) + TileSize * 2;
//  EX := (EndEX - StartEX) / 2;
//  ProjAngle := ArcTan(EX / (EndEZ - StartEZ));

  SinYA := Sin(RenderPars.Camera.YAngle);
  CosYA := Cos(RenderPars.Camera.YAngle);

  StepI := (90+RenderPars.Camera.XAngle * 180 / pi) * (MaxSI) / 90;
//  StepI := 0.7;
  AStep := (EndEZ - StartEZ) / (AAcc-1) - (AAcc-1) * StepI;
//  if AStep < TileSize / 16 then AStep := TileSize / 16;

  StripCount := 0;
  MapOffset := Cardinal(Map);
  VBOffset := Cardinal(VBPTR);
{$IFDEF DEBUGMODE}
  DebugStr := Format('EndEZ = %6.4f, AStep = %6.4f, StepI = %4.4f', [EndEZ, AStep, StepI]);
{$ENDIF}
  for j := 0 to AAcc do begin
    EZ := StartEZ + AStep * j + StepI * sqr(j);                            // Z increment test version
    EX := StartEX *(1 - (EZ - StartEZ) / (EndEZ - StartEZ)) + EndEX *(EZ - StartEZ) / (EndEZ - StartEZ); // X increment test version
{    if EZ < TileSize * 50 then begin
      StepZ := Camera.Z div (256*8) + Round(EX * CosYA);
      StepX := Camera.X div (256*8) - Round(EX * SinYA);
      StepZ := (StepZ + HMapWidth * TileSize) and (HMapWidth - 1);
      StepX := (StepX + HMapWidth * TileSize) and (HMapWidth - 1);
      H1 := LRMap[StepZ div 8, StepX div 8];
      StepZ := Camera.Z div (256*8) + Round(EX * CosYA);
      StepX := Camera.X div (256*8) - Round(EX * SinYA);
      StepZ := (StepZ + HMapWidth * TileSize) and (HMapWidth - 1);
      StepX := (StepX + HMapWidth * TileSize) and (HMapWidth - 1);
      H1 := Min(H1, LRMap[StepZ div 8, StepX div 8]);
      if EX > (Camera.Y - h1) * 2 * Sin(FoV / 2)/ Cos(FoV / 2) then begin
        EX := EX / 2;
      end;
    end;}
//    EX := (Dist * Sin(FoV / 2) / Cos(FoV / 2)) + TileSize * 2;
//     EX := EX - Random(256*20);
    //    EZ := j*TileSize/8;


    StepX := Round( 2 * EX * CosYA / XAcc * 256);
    StepZ := Round(-2 * EX * SinYA / XAcc * 256);

    if EZ < 100 * TileSize then begin
      ANDMaskX := Round((TileSize-1 ){ / Max(1, (EZ / 64 - 30) / 1)});
      ANDMaskZ := Round((TileSize-1 ){ / Max(1, (EZ / 64 - 30) / 1)});
    end else begin
      ANDMaskX := 0;
      ANDMaskZ := 0;
    end;
//    StepX := StepX and (not 255);
//    StepZ := StepZ and (not 255);

    CurX := Round(((CameraX + EZ * SinYA - EX * CosYA) - (CameraX and ANDMaskX){ / Max(1, EZ / 256 - 60)}{ * CosYA - (Camera.Z and 255) * SinYA})*256);
    CurZ := Round(((CameraZ + EZ * CosYA + EX * SinYA) - (CameraZ and ANDMaskZ){ / Max(1, EZ / 256 - 60)}{ * CosYA + (Camera.X and 255) * SinYA})*256);
(*    if StepX = 0 then CurX := Round(((Camera.X + EZ * SinYA - EX * CosYA) )*256); else
     CurX := Round(((Camera.X + EZ * SinYA - EX * CosYA)  - (Camera.X mod (StepX div 256)){ * CosYA - (Camera.Z and 255) * SinYA})*256);
    if StepZ = 0 then CurZ := Round(((Camera.Z + EZ * CosYA + EX * SinYA) )*256) else
     CurZ := Round(((Camera.Z + EZ * CosYA + EX * SinYA)  - (Camera.Z mod (StepZ div 256)){ * CosYA + (Camera.X and 255) * SinYA})*256);*)
    //    CX := CamX + EZ * SinYA - EX * CosYA;
    //    CZ := CamZ + EZ * CosYA + EX * SinYA;

    //    StepX :=  2*EX * CosYA /XAcc;
    //    StepZ := -2*EX * SinYA /XAcc;

    OldColor := $80808080;//(j and 1)*$FFFFFF;
//    if Smooth = 1 then Smth := Trunc(Abs(EZ)) div 256 div 64;
    for i := 0 to XAcc do begin
//{$Include CGetVertexPas.pas}
{$INCLUDE CGetVertexMMX.pas}
      CurX := CurX + StepX;
      CurZ := CurZ + StepZ;
      Inc(VBOffset, VertexSize);
//      Col := RandArr[(i+RandArr[j and 255]) and 255];
//      OldColor := OldColor + GetColor(Col, Col, Col)//Random($2) shl 16 + Random($2) shl 8 + Random($2);
    end;

    Inc(StripCount);
  end;
{$IFDEF DEBUGMODE}
  DebugStr := DebugStr + Format('MaxEZ = %6.4f', [EZ]);
{$ENDIF}
  VStatus := tsTesselated;
  VStatus := tsChanged;
  LastTotalIndices := TotalIndices;
  LastTotalVertices := StripCount * (XAcc + 1);
  Result := LastTotalVertices;
end;

(******************************************************************************)
constructor TMeshTesselator.Create(AName: TShortName; ATotalVertices: Integer; AVertices: Pointer; ATotalIndices: Integer; AIndices: Pointer);
begin
  inherited Create(AName);
  TotalVertices := ATotalVertices; Vertices := AVertices;
  TotalIndices := ATotalIndices; Indices := AIndices;
  IndexingVertices := TotalVertices;
  VertexFormat := GetVertexFormat(False, True, False, False, 1);
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  TotalPrimitives := TotalIndices div 3;
  VertexSize := GetVertexSize(VertexFormat);
  LastTotalIndices := 0; LastTotalVertices := 0;
end;

constructor TMeshTesselator.CreateFromFile(FileName: TFileName);
begin
{  VertexFormat := GetVertexFormat(False, True, True, False, 1);
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  AddTextureStage(-1, toModulate2X, taTexture, taDiffuse, taWrap);
  VertexSize := (3 + (VertexFormat shr 1) and 1 * 3 + (VertexFormat shr 2) and 1 + (VertexFormat shr 3) and 1 + (VertexFormat shr 8) and 255 * 2) shl 2;
  Status := tsSizeChanged;
  LastTotalIndexes := 0; LastTotalVertices := 0;
//  LoadObjFile(FileName, Indices, Vertices, TotalIndices, TotalVertices, VertexFormat, 2);
  LoadObjFile(FileName, Self, 250);
  TotalIndices := TotalIndices*3;
  TotalStrips := 1;
  TotalPrimitives := TotalIndices;
  StripOffset := 0;
  IBOffset := 0;
  VBOffset := 0;}
end;

constructor TMeshTesselator.CreateFromMesh(AMesh: TTesselator);
begin
  VertexFormat := AMesh.VertexFormat;
  PrimitiveType := AMesh.PrimitiveType;
//  AddTextureStage(AMesh.Stages[0].TextureID, toModulate2X, taTexture, taDiffuse, taMirror);
  VertexSize := AMesh.VertexSize;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
  LastTotalIndices := 0; LastTotalVertices := 0;
  TotalIndices := AMesh.TotalIndices;
  TotalStrips := 1;
  TotalPrimitives := AMesh.TotalPrimitives;
  StripOffset := 0;
  IBOffset := AMesh.IBOffset;
  VBOffset := AMesh.VBOffset;
end;

function TMeshTesselator.MatchMesh(AMesh: TTesselator): Boolean;
begin
  Result := (VerticesRes = AMesh.VerticesRes) and (IndicesRes = AMesh.IndicesRes);
end;

function TMeshTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i: Integer;
begin
  if not CompositeMember then begin
    Move(TWordBuffer(Vertices^)[0], TWordBuffer(VBPTR^)[0], Cardinal(TotalVertices) * VertexSize);
  end else begin
    Assert(CompositeOffset <> nil, 'Composite object''s offset is nil');
    for i := 0 to TotalVertices-1 do begin
      Move(TByteBuffer(Vertices^)[i*VertexSize + SizeOf(TCVertex)], TByteBuffer(VBPTR^)[i*VertexSize + SizeOf(TCVertex)], VertexSize - SizeOf(TCVertex));
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).X := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).X + CompositeOffset.X;
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).Y := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).Y + CompositeOffset.Y;
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).Z := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).Z + CompositeOffset.Z;
    end;
  end;

  VStatus := tsTesselated;
//  Status := tsChanged;
  LastTotalIndices := TotalIndices*1;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

destructor TTesselator.Free;
begin
end;

{ TTreeMesh }
constructor TTreeMesh.Create;
begin
  LastFrameTesselated := -1;
  TreeHeight := 1000; TreeRadius := 700; TreeSmoothing := 30;
  PrimitiveType := CPTypes[ptTRIANGLEFAN];
  TotalVertices := TreeSmoothing+2; TotalPrimitives := TreeSmoothing; TotalIndices := 0;
  VertexFormat := GetVertexFormat(False, True, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  LastTotalIndices := 0; LastTotalVertices := 0;
  VerticesRes := -1; IndicesRes := -1;
  TotalStrips := 1;
  StripOffset := 0;
  IBOffset := 0; VBOffset := 0;
  IndexingVertices := TotalVertices;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
end;

function TTreeMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPVertex = TCNDTVertex; TPVertexBuffer = array[0..$FFFFFF] of TPVertex;
var
  i: Integer; VBuf: ^TPVertexBuffer;
begin
  VBuf := VBPTR;
  with VBuf^[0] do begin
    X := 0; Y := TreeHeight; Z := 0;
    NX := 0; NY := 1; NZ := 0;
    U := 0.5; V := 0.5;
    DColor := $FFFFFFFF;
  end;
  for i := 0 to TreeSmoothing do with VBuf^[1+i] do begin
    U := Cos(i/180*pi*360/TreeSmoothing);
    V := Sin(i/180*pi*360/TreeSmoothing);
    X := U*TreeRadius;
    Y := 0;
    Z := -V*TreeRadius;
    NX := U;
    NY := 0;
    NZ := -V;
    U := 0.5+U*0.5;
    V := 0.5-V*0.5;
    DColor := $FF808080;
  end;
//  TotalVertices := TotalParticles*12; TotalPrimitives := TotalParticles*2;
  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

{ TSkyDomeTesselator }

constructor TSkyDomeTesselator.Create(const AName: TShortName);
begin
//  SetParameters(16, 8, 65536, 35000, $80A0FF*1+$FF000000, $FF808080);
  inherited;
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1;
  StripOffset := 0;
  GetMem(SkyMap, 32*32*4);
  SMWidth := 32; SMHeight := 32;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
end;

function TSkyDomeTesselator.MatchMesh(AMesh: TTesselator): Boolean;
begin
  Result := inherited MatchMesh(AMesh) and (AMesh is TSkyDomeTesselator) and
                      (Sectors = (AMesh as TSkyDomeTesselator).Sectors) and
                      (Segments = (AMesh as TSkyDomeTesselator).Segments) and
                      (Radius = (AMesh as TSkyDomeTesselator).Radius) and
                      (Height = (AMesh as TSkyDomeTesselator).Height) and
                      (TexK = (AMesh as TSkyDomeTesselator).TexK) and
                      (SMWidth = (AMesh as TSkyDomeTesselator).SMWidth) and
                      (SMHeight = (AMesh as TSkyDomeTesselator).SMHeight) and
                      (SkyMap = (AMesh as TSkyDomeTesselator).SkyMap) and
                      (TexClamp = (AMesh as TSkyDomeTesselator).TexClamp) and
                      (Inner = (AMesh as TSkyDomeTesselator).Inner) and
                      (Vertical = (AMesh as TSkyDomeTesselator).Vertical);
end;

procedure TSkyDomeTesselator.SetParameters(ASectors, ASegments: Integer; ARadius, AHeight, ATexK: Single; ATexClamp, AInner, AVertical: Boolean);
begin
  Sectors := ASectors; Segments := ASegments-1;
  Radius := ARadius; Height := AHeight;
  TexK := ATexK; TexClamp := ATexClamp;
  Inner := AInner; Vertical := AVertical;
  TotalVertices := (Segments+1)*(Sectors+1);
  TotalIndices := (Segments)*(Sectors)*2*3;
  TotalPrimitives := (Segments)*(Sectors)*2+0*2*(Segments-1);
  IndexingVertices := TotalVertices;
end;

function TSkyDomeTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TSkyVertex = TCDTVertex; TSkyBuffer = array[0..$FFFF] of TSkyVertex;
var i, j, SMXI, SMYI: Integer; SMXO, SMYO: Single; SkyBuf: ^TSkyBuffer; ClampNext: Boolean;
begin
  Result := 0;
  if Segments = 0 then Exit;
  SkyBuf := VBPTR;

  ClampNext := False;

  for j := Segments downto 0 do begin
    for i := 0 to Sectors do with SkyBuf[j*(Sectors+1)+i] do begin
      if Vertical then begin
        X := Radius*Cos(i/Sectors*2*pi)*Cos(j/(Segments)*pi/2);
        Y := Height * {j / Segments * }Sin(j/Segments * pi/2);
      end else begin
        Y := -Radius*Cos(i/Sectors*2*pi)*Cos(j/(Segments)*pi/2);
        X := Height * {j / Segments * }Sin(j/Segments * pi/2);
      end;
      if Inner then Z := -Radius*Sin(i/Sectors*2*pi)*Cos(j/(Segments)*pi/2) else Z := Radius*Sin(i/Sectors*2*pi)*Cos(j/(Segments)*pi/2);
  //    U := 4*i/Sectors; V := 1-j/Segments;
      U := 0.5 + 0.5*(Segments-j)/Segments*Cos(i/Sectors*2*pi*1);
      V := 0.5 + 0.5*(Segments-j)/Segments*Sin(i/Sectors*2*pi*1);
      SMXI := Trunc(U * (SMWidth-1));
      SMXO := Frac(U * (SMWidth-1));
      SMYI := Trunc(V * (SMHeight-1));
      SMYO := Frac(V * (SMHeight-1));
  //    DColor := BlendColor(SkyMap[SMYI*8+SMXI], SkyMap[SMYI*8+(SMXI+1) and 7], SMXO);
  //    DColor := BlendColor(SkyMap[SMYI*SMWidth+SMXI], SkyMap[SMYI*SMWidth+(SMXI+1) and (SMWidth-1)], 1-SMXO);
      DColor := BlendColor(BlendColor(SkyMap[SMYI*SMWidth+SMXI], SkyMap[((SMYI+1) and (SMHeight-1))*SMWidth+SMXI], SMYO),
                           BlendColor(SkyMap[SMYI*SMWidth+(SMXI+1) and (SMWidth-1)], SkyMap[((SMYI+1) and (SMHeight-1))*SMWidth+(SMXI+1) and (SMWidth-1)], SMYO),
                           SMXO);

      if ClampNext then begin
        U := 0.5 + 0.5*Cos(i/Sectors*2*pi*1);
        V := 0.5 + 0.5*Sin(i/Sectors*2*pi*1);
      end else begin
        U := 0.5 + (U-0.5) * TexK;
        V := 0.5 + (V-0.5) * TexK;
      end;
    end;
    if TexClamp and ((Segments-j)/Segments * TexK > 0.5) then ClampNext := True;
  end;
  VStatus := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result := TotalVertices;
end;

function TSkyDomeTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
  for j := 0 to Segments-1 do begin
    for i := 0 to Sectors-1 do begin
      TWordBuffer(IBPTR^)[(j*(Sectors+0)+i)*6+0] := (j+0)*(Sectors+1)+i;
      TWordBuffer(IBPTR^)[(j*(Sectors+0)+i)*6+1] := (j+1)*(Sectors+1)+i;
      TWordBuffer(IBPTR^)[(j*(Sectors+0)+i)*6+2] := (j+0)*(Sectors+1)+i+1;
      TWordBuffer(IBPTR^)[(j*(Sectors+0)+i)*6+3] := (j+1)*(Sectors+1)+i;
      TWordBuffer(IBPTR^)[(j*(Sectors+0)+i)*6+4] := (j+1)*(Sectors+1)+i+1;
      TWordBuffer(IBPTR^)[(j*(Sectors+0)+i)*6+5] := (j+0)*(Sectors+1)+i+1
    end;
{    TWordBuffer(IBPTR^)[(j*(Sectors+1)+Sectors-1)*6+2] := (j+0)*(Sectors);
    TWordBuffer(IBPTR^)[(j*(Sectors+1)+Sectors-1)*6+4] := (j+1)*(Sectors);
    TWordBuffer(IBPTR^)[(j*(Sectors+1)+Sectors-1)*6+5] := (j+0)*(Sectors);}
//    TWordBuffer(IBPTR^)[(j*(Sectors+1)+Sectors)*6] := (j+0)*(Sectors);
//    TWordBuffer(IBPTR^)[(j*(Sectors+1)+Sectors)*6+1] := (j+1)*(Sectors);
  end;
  IStatus := tsTesselated;
  Result := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

destructor TSkyDomeTesselator.Free;
begin
  FreeMem(SkyMap);
end;

{ TIslandTesselator }
function TIslandTesselator.CheckGeometry(const Camera: TCamera): Boolean;
begin
  Result := False;
end;

function TIslandTesselator.GetMaxVertices: Integer;
begin
  Result := (HMapWidth) * (HMapHeight);
end;

function TIslandTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Cardinal; y11, y12, y21, y22, Points: Integer;
begin
{
  * *     * * * * * * * *
  * * * * *     * * * * *
  * * * * *     * *   * *
  * * * * * * * * * * * *
}
  TotalPrimitives := 0;
  for j := 0 to HMapHeight-2 do for i := 0 to HMapWidth-2 do begin
    y11 := HMap.GetCellHeight(i, j);
    y12 := HMap.GetCellHeight(i, j+1);
    y21 := HMap.GetCellHeight(i+1, j);
    y22 := HMap.GetCellHeight(i+1, j+1);
//                  8                      4                    2                    1
    Points := Byte(y11 > 0) shl 3 + Byte(y12 > 0) shl 2 + Byte(y21 > 0) shl 1 + Byte(y22 > 0);
    case Points of
      7: begin                           // y11 zero
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] := (j+1) * HMapWidth + i;         //  *
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * HMapWidth + i+1;       // **
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] := j * HMapWidth + i+1;
        Inc(TotalPrimitives);
      end;
      11: begin                           // y12 zero
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] := j * HMapWidth + i;             // **
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * HMapWidth + i+1;       //  *
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] := j * HMapWidth + i + 1;
        Inc(TotalPrimitives);
      end;
      13: begin                           // y21 zero
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] := j * HMapWidth + i;             // *
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * HMapWidth + i;         // **
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] := (j+1) * HMapWidth + i+1;
        Inc(TotalPrimitives);
      end;
      14: begin                           // y22 zero
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] := j * HMapWidth + i;             // **
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * HMapWidth + i;         // *
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] := j * HMapWidth + i+1;
        Inc(TotalPrimitives);
      end;
      15: begin                           // All points
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] := j * HMapWidth + i;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * HMapWidth + i;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] := (j+1) * HMapWidth + i+1;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+3] := j * HMapWidth + i;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+4] := (j+1) * HMapWidth + i+1;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+5] := j * HMapWidth + i+1;
        Inc(TotalPrimitives, 2);
      end;
    end;
  end;
  IStatus := tsTesselated;
  Result := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

function TIslandTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TLandVertex = TCDTVertex; TLandBuffer = array[0..$FFFFFF] of TLandVertex; TMapBuf = array[0..$FFFFFF] of Byte;
var i, j: Integer; LandBuf: ^TLandBuffer; HalfLengthX, HalfLengthZ: Single;
begin
  Result := 0;
  if (HMapWidth = 0) or (HMapHeight = 0) then Exit;
  LandBuf := VBPTR;

  HalfLengthX := (HMapWidth-1) * IslandScaleX * 0.5;
  HalfLengthZ := (HMapHeight-1) * IslandScaleZ * 0.5;

  for j := 0 to HMapHeight-1 do for i := 0 to HMapWidth-1 do begin
    LandBuf[j * HMapWidth + i].X := i * IslandScaleX - HalfLengthX;
    LandBuf[j * HMapWidth + i].Z := j * IslandScaleZ - HalfLengthZ;
    LandBuf[j * HMapWidth + i].DColor := HMap.GetCellColor(i, j) or $FF000000;
    LandBuf[j * HMapWidth + i].U := i * TextureMag;
    LandBuf[j * HMapWidth + i].V := j * TextureMag;
    if (i = 0) or (j = 0) or (i = HMap.MapWidth-1)  or (j = HMap.MapHeight-1) or
//       (HMap.GetCellHeight(i-1, j-1) = 0) or (HMap.GetCellHeight(i+1, j-1) = 0) or
//       (HMap.GetCellHeight(i-1, j+1) = 0) or (HMap.GetCellHeight(i+1, j+1) = 0) or
       (HMap.GetCellHeight(i-1, j) = 0) or (HMap.GetCellHeight(i+1, j) = 0) or
       (HMap.GetCellHeight(i, j-1) = 0) or (HMap.GetCellHeight(i, j+1) = 0) then begin
      LandBuf[j * HMapWidth + i].Y := -IslandThickness * IslandScaleY;
      LandBuf[j * HMapWidth + i].DColor := HMap.GetCellColor(i, j) and $FFFFFF;
      LandBuf[j * HMapWidth + i].U := i * TextureMag;
      LandBuf[j * HMapWidth + i].V := j * TextureMag;
    end else LandBuf[j * HMapWidth + i].Y := HMap.GetCellHeight(i, j) * IslandScaleY;
  end;
  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

procedure TIslandTesselator.Init(const AHMap: TMap; const AMap: Pointer);
begin
  inherited;
  if HMap <> nil then HMap.MinHeight := 1;
  Vertices := nil; TotalVertices := HMapWidth*HMapHeight;
  Indices := nil; TotalIndices := MaxI(0, (HMapWidth-1)) * MaxI(0, (HMapHeight-1)) * 6;
  IndexingVertices := TotalVertices;
  TotalPrimitives := MaxI(0, (HMapWidth-1)) * MaxI(0, (HMapHeight-1)) * 2;
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  VerticesRes := -1; IndicesRes := -1;
  TotalStrips := 1;
  StripOffset := 0;
  LastTotalIndices := 0; LastTotalVertices := 0;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
  IslandScaleX := 256; IslandScaleY := 1; IslandScaleZ := 256; IslandThickness := 8*256;
end;

{ TLandscapeTesselator }

constructor TLandscapeTesselator.Create(const AName: TShortName);
begin
  inherited;
  Init(nil, nil);
  TextureMag := 0.1;
end;

procedure TLandscapeTesselator.Init(const AHMap: TMap; const AMap: Pointer);
begin
  HMap := AHMap; Map := AMap;
  if AHMap <> nil then begin
    CellPower := AHMap.TilePower;
    HMapWidth := AHMap.MapWidth;
    HMapHeight := AHMap.MapHeight;
    HeightPower := AHMap.HeightPower;
    HMapPower := AHMap.MapPower;
  end else begin
    HMapWidth := 0; HMapHeight := 0;
  end;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
end;

{ TDiffMeshTesselator }

constructor TDiffMeshTesselator.Create(AName: TShortName; ATotalVertices: Integer; AVertices: Pointer; ATotalIndices: Integer; AIndices: Pointer);
begin
  inherited;
  VertexFormat := GetVertexFormat(False, True, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  Diffuse := $80808080;
end;

function TDiffMeshTesselator.MatchMesh(AMesh: TTesselator): Boolean;
begin
  Result := inherited MatchMesh(AMesh);
  Result := Result and (AMesh is TDiffMeshTesselator) and (Diffuse = (AMesh as TDiffMeshTesselator).Diffuse);
end;

function TDiffMeshTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i, MoveOffset, DiffOffset: Integer;
begin
  DiffOffset := GetVertexElementOffset(VertexFormat, vfiDiff);
  if not CompositeMember then MoveOffset := 0 else begin
    MoveOffset := SizeOf(TCVertex);
    Assert(CompositeOffset <> nil, 'Composite object''s offset is nil');
  end;
  for i := 0 to TotalVertices-1 do begin
    Move(TByteBuffer(Vertices^)[i*VertexSize + MoveOffset], TByteBuffer(VBPTR^)[i*VertexSize + MoveOffset], VertexSize - MoveOffset);
    if CompositeMember then begin
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).X := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).X + CompositeOffset.X;
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).Y := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).Y + CompositeOffset.Y;
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).Z := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).Z + CompositeOffset.Z;
    end;
    Longword((@TByteBuffer(VBPTR^)[i*VertexSize + DiffOffset])^) := Diffuse;
  end;

  VStatus := tsTesselated;
//  Status := tsChanged;
  LastTotalIndices := TotalIndices*1;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ TDiffUVRotatedMeshTesselator }

constructor TDiffUVRotatedMeshTesselator.Create(AName: TShortName; ATotalVertices: Integer; AVertices: Pointer; ATotalIndices: Integer; AIndices: Pointer);
begin
  inherited;
  VertexFormat := GetVertexFormat(False, True, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  UVAngle := 0; Diffuse := $80808080;
end;

function TDiffUVRotatedMeshTesselator.MatchMesh(AMesh: TTesselator): Boolean;
begin
  Result := inherited MatchMesh(AMesh);
  Result := Result and (AMesh is TDiffUVRotatedMeshTesselator) and
            (Diffuse = (AMesh as TDiffMeshTesselator).Diffuse) and (UVAngle = (AMesh as TDiffUVRotatedMeshTesselator).UVAngle);
end;

function TDiffUVRotatedMeshTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i, MoveOffset, DiffOffset, UVOffset: Integer; U, V: Single;
begin
  DiffOffset := GetVertexElementOffset(VertexFormat, vfiDiff);
  UVOffset := GetVertexElementOffset(VertexFormat, vfiTex);
  if not CompositeMember then MoveOffset := 0 else begin
    MoveOffset := SizeOf(TCVertex);
    Assert(CompositeOffset <> nil, 'Composite object''s offset is nil');
  end;
  for i := 0 to TotalVertices-1 do begin
    Move(TByteBuffer(Vertices^)[i*VertexSize + MoveOffset], TByteBuffer(VBPTR^)[i*VertexSize + MoveOffset], VertexSize - MoveOffset);
    if CompositeMember then begin
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).X := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).X + CompositeOffset.X;
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).Y := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).Y + CompositeOffset.Y;
      TCVertex((@TByteBuffer(VBPTR^)[i*VertexSize])^).Z := TCVertex((@TByteBuffer(Vertices^)[i*VertexSize])^).Z + CompositeOffset.Z;
    end;
    Longword((@TByteBuffer(VBPTR^)[i*VertexSize + DiffOffset])^) := Diffuse;
    U := Single((@TByteBuffer(Vertices^)[i*VertexSize + UVOffset])^);
    V := Single((@TByteBuffer(Vertices^)[i*VertexSize + UVOffset + 4])^);
    Single((@TByteBuffer(VBPTR^)[i*VertexSize + UVOffset])^) :=
     U * Cos(UVAngle) - V * Sin(UVAngle);
    Single((@TByteBuffer(VBPTR^)[i*VertexSize + UVOffset + 4])^) :=
     V * Cos(UVAngle) + U * Sin(UVAngle);
  end;

  VStatus := tsTesselated;
//  Status := tsChanged;
  LastTotalIndices := TotalIndices*1;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

procedure TTesselator.InitVertexFormat(Format: Cardinal);
begin
  VertexFormat := Format;
  VertexSize := GetVertexSize(VertexFormat);
  CoordsOfs := 0;
  NormalOfs := GetVertexElementOffset(VertexFormat, vfiNorm);
  WeightsOfs := GetVertexElementOffset(VertexFormat, vfiWeight);
  DiffuseOfs := GetVertexElementOffset(VertexFormat, vfiDiff);
  SpecOfs := GetVertexElementOffset(VertexFormat, vfiSpec);
  UVOfs := GetVertexElementOffset(VertexFormat, vfiTex);
end;

procedure TTesselator.SetVertexDataC(x, y, z: Single; Index: Integer; VBuf: Pointer);
begin
  TVector3s(Pointer(Cardinal(VBuf) + Index * VertexSize)^).X := x;
  TVector3s(Pointer(Cardinal(VBuf) + Index * VertexSize)^).Y := y;
  TVector3s(Pointer(Cardinal(VBuf) + Index * VertexSize)^).Z := z;
end;

procedure TTesselator.SetVertexDataD(Color: Cardinal; Index: Integer; VBuf: Pointer);
begin
  if RGBA then asm        // Swap R and B components in Color
  end;
  Cardinal(Pointer(Cardinal(VBuf) + Index * VertexSize + DiffuseOfs)^) := Color;
end;

procedure TTesselator.SetVertexDataN(nx, ny, nz: Single; Index: Integer; VBuf: Pointer);
begin
  TVector3s(Pointer(Cardinal(VBuf) + Index * VertexSize + NormalOfs)^).X := nx;
  TVector3s(Pointer(Cardinal(VBuf) + Index * VertexSize + NormalOfs)^).Y := ny;
  TVector3s(Pointer(Cardinal(VBuf) + Index * VertexSize + NormalOfs)^).Z := nz;
end;

procedure TTesselator.SetVertexDataS(Color: Cardinal; Index: Integer; VBuf: Pointer);
begin
  if RGBA then asm        // Swap R and B components in Color
  end;
  Cardinal(Pointer(Cardinal(VBuf) + Index * VertexSize + SpecOfs)^) := Color;
end;

procedure TTesselator.SetVertexDataUV(u, v: Single; Index: Integer; VBuf: Pointer);
begin
  Single(Pointer(Cardinal(VBuf) + Index * VertexSize + UVOfs)^) := u;
  Single(Pointer(Cardinal(VBuf) + Index * VertexSize + UVOfs + 4)^) := v;
end;

procedure TTesselator.SetVertexDataW(w: Single; Index: Integer; VBuf: Pointer);
begin
  Single(Pointer(Cardinal(VBuf) + Index * VertexSize + WeightsOfs)^) := w;
end;

{ TScaledMeshTesselator }

constructor TScaledMeshTesselator.Create(AName: TShortName; ATotalVertices: Integer; AVertices: Pointer; ATotalIndices: Integer; AIndices: Pointer);
begin
  inherited;
  Direction := GetVector3s(0, 0, 1);
end;

function TScaledMeshTesselator.MatchMesh(AMesh: TTesselator): Boolean;
begin
  Result := False;//inherited MatchMesh(AMesh) and (SqrMagnitude(SubVector3s((AMesh as TScaledMeshTesselator).Direction, Direction)) < epsilon);
end;

function TScaledMeshTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i: Integer; DirP: Single;
begin
  if not CompositeMember then begin
    for i := 0 to TotalVertices-1 do begin

      DirP := DotProductVector3s(TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^), Direction);

      TVector3s((@TByteBuffer(VBPTR^)[i*VertexSize])^) := SubVector3s(TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^), ScaleVector3s(Direction, DirP));

      Move(TByteBuffer(Vertices^)[i*VertexSize + SizeOf(TCVertex)], TByteBuffer(VBPTR^)[i*VertexSize + SizeOf(TCVertex)], VertexSize - SizeOf(TCVertex));
    end;
  end else begin
    Assert(CompositeOffset <> nil, 'Composite object''s offset is nil');
    for i := 0 to TotalVertices-1 do begin
      
      TVector3s((@TByteBuffer(VBPTR^)[i*VertexSize])^).X := TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^).X + CompositeOffset.X;
      TVector3s((@TByteBuffer(VBPTR^)[i*VertexSize])^).Y := TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^).Y + CompositeOffset.Y;
      TVector3s((@TByteBuffer(VBPTR^)[i*VertexSize])^).Z := TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^).Z + CompositeOffset.Z;

      Move(TByteBuffer(Vertices^)[i*VertexSize + SizeOf(TCVertex)], TByteBuffer(VBPTR^)[i*VertexSize + SizeOf(TCVertex)], VertexSize - SizeOf(TCVertex));
    end;
  end;

//  VStatus := tsTesselated;
  VStatus := tsChanged;
  LastTotalIndices := TotalIndices*1;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

initialization
  RGBA := False;
end.
