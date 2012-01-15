{$Include GDefines}
{$Include CDefines}
unit CMiscTess;

interface

uses Basics, Base3D, CTypes, CTess, CMaps;

const
//  rsCenter = 0; rsLeft = 1; rsRight = 2;
  uvtPlanar = 0; uvtRadial = 1;

type
  TWholeTreeMesh = class(TTesselator)
    LevelHeight, LevelStride, InnerRadius, OuterRadius, IRadiusStep, ORadiusStep, StrideFactor: Single;
    StemLowRadius, StemHighRadius, StemHeight, CrownStart: Single;
    StemUHeight, StemVHeight, CrownUVRadius: Single;
    Smoothing, Levels: Integer;
    RenderStem: Boolean;
    constructor Create(const AName: TShortName); override;
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    procedure SetParameters(ALevelHeight, ALevelStride, AInnerRadius, AOuterRadius, AIRadiusStep, AORadiusStep, AStrideFactor: Single;
                            AStem: Boolean;
                            AStemUHeight, AStemVHeight, ACrownUVRadius, AStemLowRadius, AStemHighRadius, AStemHeight, ACrownStart: Single;
                            ASmoothing, ALevels: Integer); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    function CalcBoundingBox: TBoundingBox; override;
  protected
    MaxY: Single;
  end;

  TColoredTreeMesh = class(TWholeTreeMesh)
    StemColor, CrownColor: Cardinal;
    constructor Create(const AName: TShortName); override;
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TGrassMesh = class(TTesselator)
    Height, Radius, Levels: Integer;
    GrassColor: Longword;
    constructor Create(const AName: TShortName);
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    procedure SetParameters(const AHeight, ARadius, ALevels: Integer; const AGrassColor: Longword); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    function CalcBoundingBox: TBoundingBox; override;
  end;

  TWholeTreeMesh2 = class(TWholeTreeMesh)
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TDomeTesselator = class(TTesselator)
    Sectors, Segments, Radius, Height: Integer;
    UVScale: Single;
    Inner: Boolean;
    Color: Longword;
    constructor Create(const AName: TShortName); override;
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    procedure SetParameters(ASectors, ASegments, ARadius, AHeight: Integer; AUVScale: Single; AColor: Longword; AInner: Boolean);
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

  TFXDomeTesselator = class(TDomeTesselator)
    CurrentTick: Cardinal;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TWaterTesselator = class(TTesselator)
    constructor Create(const AName: TShortName); override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TPlaneTesselator = class(TTesselator)
    Width, Height, TexturesWidth, TexturesHeight, UKoeff, VKoeff, UShift, VShift: Single;
    UOfs, VOfs: Single;
    Color: Longword;
    constructor Create(const AName: TShortName); override;
    procedure SetParameters(AColor: Longword; AWidth, AHeight, ATexturesWidth, ATexturesHeight, AUShift, AVShift: Single); virtual;
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TGridTesselator = class(TTesselator)
    Radius, TexturesWidth, TexturesHeight, UKoeff, VKoeff, UShift, VShift: Single;
    UOfs, VOfs: Single;
    Sectors: Integer;
    CenterColor, SideColor: Longword;
    constructor Create(const AName: TShortName); override;
    procedure SetParameters(ACenterColor, ASideColor, ASectors: Longword; ARadius, ATexturesWidth, ATexturesHeight, AUShift, AVShift: Single); virtual;
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TRingMesh = class(TTesselator)
    InnerRadius, OuterRadius, Factor: Single;
    UVFrame: TUV;
    Smoothing: Integer;
    Color1, Color2, UVMapType: Longword;
    constructor Create(const AName: TShortName); override;
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    procedure SetParameters(AInnerRadius, AOuterRadius: Single; ASmoothing: Integer; AColor1, AColor2: Longword; AFactor: Single; AUVMapType: Integer); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    function CalcBoundingBox: TBoundingBox; override;
  end;

  TWheelTraceTesselator = class(TTesselator)
    TotalPoints: Integer;
    Points: array of TVector3s;
    Bias: Single;
    Size: Integer;
    Color: Longword;
    HMap: TMap;
    constructor Create(const AName: TShortName); override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    procedure AddPoint(const APoint: TVector3s); virtual;
    procedure Clear; virtual;
  end;

  TRockTesselator = class(TTesselator)
    Angle: Single;
    Loc: TVector3s;
    HMap: TMap;
    UK: Single;
    LeftTransHeight, RightTransHeight, LeftTransLength, LeftLength, RightTransLength, RightLength: Integer;
    Points: TPath; TotalPoints: Integer;
    Color: Longword;
    constructor Create(const AName: TShortName); override;
    procedure SetParameters(ALeftTransHeight, ARightTransHeight, ALeftTransLength, ALeftLength, ARightTransLength, ARightLength: Integer; AUK: Single; AColor: Longword; ATotalPoints: Integer; APoints: Pointer);
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

  TBackgroundTesselator = class(TTesselator)
    Zoom: Single;
    Cols, Rows, Angle: Integer;
    Color: Longword;
    constructor Create(const AName: TShortName); override;
    procedure SetParameters(AColor, ACols, ARows: Longword; AAngle: Integer; AZoom: Single); virtual;
    function MatchMesh(AMesh: TTesselator): Boolean; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

implementation

{ TWholeTreeMesh }

(*function TWholeTreeMesh.Tesselate(RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPVertex = TCBNTVertex; TPVertexBuffer = array[0..$FFFFFF] of TPVertex;
var i, j: Integer; VBuf: ^TPVertexBuffer; CurY, YDec: Single;
begin
  VBuf := VBPTR;
  YDec := 1; CurY := 0;
  for j := 0 to TreeLevels-1 do begin
//    YDec := YDec - 0.7/(TreeLevels+2);
    with VBuf^[j*(TreeSmoothing+1)] do begin
      X := 0; Z := 0;
//      Y := CurY + TreeHeight * (YDec-2*0.7/(TreeLevels+0));
      Y := CurY + TreeHeight*0.05 + TreeHeight * YDec * 0.7;
      W1 := 0;//1-Y/(TreeHeight*(TreeLevels-1)*0.3+TreeHeight);
      NX := 0; NY := 1; NZ := 0;
      U := 0.5; V := 0.5;
    end;
    for i := 0 to TreeSmoothing-1 do with VBuf^[j*(TreeSmoothing+1)+i+1] do begin
      U := Cos(i/180*pi*360/TreeSmoothing); V := Sin(i/180*pi*360/TreeSmoothing);
      X := U*TreeRadius*(1-j*0.2); Y := CurY; Z := -V*TreeRadius*(1-j*0.2);
      W1 := 0;//1-Y/(TreeHeight*(TreeLevels-1)*0.3);
      NX := U; NY := 0; NZ := -V;
      U := Cos((i+j*35)/180*pi*360/TreeSmoothing); V := Sin((i+j*35)/180*pi*360/TreeSmoothing);
      U := 0.5+U*0.5; V := 0.5-V*0.5;
    end;
//    CurY := CurY + TreeHeight*0.3 * YDec;

    YDec := YDec * 0.3;
//    if YDec < 0.125 then YDec := 0.125;
    CurY := CurY + TreeHeight*0.1 + TreeHeight*YDec;
  end;

  for i := 0 to TotalVertices-1 do VBuf^[i].W1 := 1 - VBuf^[i].Y / VBuf^[TotalVertices-1].Y;

//  TotalVertices := TotalParticles*12; TotalPrimitives := TotalParticles*2;
  Status := tsTesselated;
  Result := TotalVertices;
end;*)

constructor TWholeTreeMesh.Create(const AName: TShortName);
begin
  inherited;
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  InitVertexFormat(GetVertexFormat(False, True, False, False, 1, 1));
  SetParameters(200, 300, 400, 800, 80, 80, 0.9, True, 0.25, 0.25, 1, 300, 100, 1000, 200, 8, 5);
end;

function TWholeTreeMesh.MatchMesh(AMesh: TTesselator): Boolean;
var Mesh: TWholeTreeMesh;
begin
  Result := False;
  if AMesh is TWholeTreeMesh then Mesh := AMesh as TWholeTreeMesh else Exit;
  Result := (Levels = Mesh.Levels) and (Smoothing = Mesh.Smoothing) and
            (LevelHeight = Mesh.LevelHeight) and (LevelStride = Mesh.LevelStride) and
            (InnerRadius = Mesh.InnerRadius) and (OuterRadius = Mesh.OuterRadius) and
            (StrideFactor = Mesh.StrideFactor) and
            (RenderStem = Mesh.RenderStem) and
            (StemUHeight = Mesh.StemUHeight) and (StemVHeight = Mesh.StemVHeight) and
            (StemLowRadius = Mesh.StemLowRadius) and (StemHighRadius = Mesh.StemHighRadius) and
            (CrownUVRadius = Mesh.CrownUVRadius) and
            (StemHeight = Mesh.StemHeight) and (CrownStart = Mesh.CrownStart) and
            (IRadiusStep = Mesh.IRadiusStep) and (ORadiusStep = Mesh.ORadiusStep);
end;

procedure TWholeTreeMesh.SetParameters(ALevelHeight, ALevelStride, AInnerRadius, AOuterRadius, AIRadiusStep, AORadiusStep, AStrideFactor: Single;
                                       AStem: Boolean;
                                       AStemUHeight, AStemVHeight, ACrownUVRadius, AStemLowRadius, AStemHighRadius, AStemHeight, ACrownStart: Single;
                                       ASmoothing, ALevels: Integer);
var i: Integer; LStride: Single;
begin
  Smoothing := ASmoothing; Levels := ALevels;
  LevelHeight := ALevelHeight;
  LevelStride := ALevelStride;
  InnerRadius := AInnerRadius;
  OuterRadius := AOuterRadius;
  IRadiusStep := AIRadiusStep;
  ORadiusStep := AORadiusStep;
  StrideFactor := AStrideFactor;

  RenderStem := AStem;
  StemLowRadius := AStemLowRadius;
  StemHighRadius := AStemHighRadius;
  StemHeight := AStemHeight;
  CrownStart := ACrownStart;

  StemUHeight := AStemUHeight;
  StemVHeight := AStemVHeight;
  CrownUVRadius := ACrownUVRadius;

  TotalVertices := Smoothing*2*Levels + Smoothing*2 * Byte(RenderStem);
  TotalPrimitives := Smoothing*2*Levels + Smoothing*2 * Byte(RenderStem);
  TotalIndices := 3*Smoothing*2*Levels + 3*Smoothing*2 * Byte(RenderStem);

  IndexingVertices := TotalVertices;
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
// Compute max. Y
  MaxY := CrownStart;
  LStride := LevelStride;
  for i := 0 to Levels-1 do begin
    MaxY := MaxY + LStride;
    LStride := LStride * StrideFactor;
  end;
  if StemHeight > MaxY then MaxY := StemHeight;
end;

function TWholeTreeMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var
  i, j: Integer;
  CurY, CurIR, CurOR, LHeight, LStride, UVNorm: Single;
  Ofs: Cardinal;
  t1, t2: Single;
begin
// ******** Tree stem ************
  if RenderStem then begin
    for i := 0 to Smoothing-1 do begin
      t1 := Cos(i/180*pi*360/Smoothing); t2 := Sin(i/180*pi*360/Smoothing);
      SetVertexDataC(t1*StemLowRadius, 0, -t2*StemLowRadius, i, VBPTR);
      SetVertexDataW(0, i, VBPTR);

      SetVertexDataN(t1, 0, -t2, i, VBPTR);

//      U := 1-0.15+0.3*i/Smoothing;
      case i and 3 of
        0: t1 := 1 - StemUHeight;
        1: t1 := 1;
        2: t1 := 1 + StemUHeight;
        3: t1 := 1;
      end;
      t2 := 1-StemVHeight;
      SetVertexDataUV(t1, t2, i, VBPTR);
    end;
    for i := 0 to Smoothing-1 do begin
      Ofs := i+Smoothing;
      t1 := Cos(i/180*pi*360/Smoothing); t2 := Sin(i/180*pi*360/Smoothing);
      SetVertexDataC(t1*StemHighRadius, StemHeight, -t2*StemHighRadius, Ofs, VBPTR);
      SetVertexDataW(1 - StemHeight / MaxY, Ofs, VBPTR);

      SetVertexDataN(t1, 0, -t2, Ofs, VBPTR);

//      U := 1-0.15+0.3*i/Smoothing;
      case i and 3 of
        0: t1 := 1 - StemUHeight;
        1: t1 := 1;
        2: t1 := 1 + StemUHeight;
        3: t1 := 1;
      end;
      t2 := 1+StemVHeight;
      SetVertexDataUV(t1, t2, Ofs, VBPTR);
    end;
  end;

// Tree crown
  CurY := CrownStart;
  CurIR := InnerRadius; CurOR := OuterRadius;
  LHeight := LevelHeight; LStride := LevelStride;
  for j := 0 to Levels-1 do begin
    if CurIR > CurOR then begin
      if CurIR = 0 then UVNorm := 0 else UVNorm := CurOR / CurIR;
    end else begin
      if CurOR = 0 then UVNorm := 0 else UVNorm := CurIR / CurOR;
    end;

    for i := 0 to Smoothing-1 do begin              // Outer edge
      Ofs := (j+Ord(RenderStem))*2*(Smoothing)+i;
      t1 := Cos(i/180*pi*360/Smoothing + j*35/180*pi); t2 := Sin(i/180*pi*360/Smoothing + j*35/180*pi);
      SetVertexDataC(t1*CurOR, CurY, -t2*CurOR, Ofs, VBPTR);
      SetVertexDataW(1 - CurY/ MaxY, Ofs, VBPTR);

      if Abs(CurOR) < 0.001 then begin
        SetVertexDataN(0, 1, 0, Ofs, VBPTR);
      end else begin
        SetVertexDataN(t1, 0, -t2, Ofs, VBPTR);
      end;

      t1 := Cos(i/180*pi*360/Smoothing) * CrownUVRadius; t2 := Sin(i/180*pi*360/Smoothing) * CrownUVRadius;
      if CurIR > CurOR then begin
        SetVertexDataUV(0.5 + t1 * UVNorm * 0.5, 0.5 - t2 * UVNorm * 0.5, Ofs, VBPTR);
      end else begin
        SetVertexDataUV(0.5+t1*0.5, 0.5-t2*0.5, Ofs, VBPTR);
      end;
    end;

    for i := 0 to Smoothing-1 do begin          // Inner edge
      Ofs := ((j+Ord(RenderStem))*2+1)*(Smoothing)+i;
      t1 := Cos(i/180*pi*360/Smoothing + j*35/180*pi); t2 := Sin(i/180*pi*360/Smoothing + j*35/180*pi);
      SetVertexDataC(t1*CurIR, CurY + LHeight, -t2*CurIR, Ofs, VBPTR);
      SetVertexDataW(1 - (CurY + LHeight)/ MaxY, Ofs, VBPTR);

      if Abs(CurIR) < 0.001 then begin
        SetVertexDataN(0, 1, 0, Ofs, VBPTR);
      end else begin
        SetVertexDataN(t1, 0, -t2, Ofs, VBPTR);
      end;

      t1 := Cos(i/180*pi*360/Smoothing) * CrownUVRadius; t2 := Sin(i/180*pi*360/Smoothing) * CrownUVRadius;

      if CurIR < CurOR then begin                                                    // Inner edge
        SetVertexDataUV(0.5 + t1 * UVNorm * 0.5, 0.5 - t2 * UVNorm * 0.5, Ofs, VBPTR);
      end else begin                                                                 // Outer edge
        SetVertexDataUV(0.5+t1*0.5, 0.5-t2*0.5, Ofs, VBPTR);
      end;
    end;
//    YDec := YDec * (1-0.7/(Levels));
    CurY := CurY + LStride;
    CurIR := CurIR - IRadiusStep;
    CurOR := CurOR - ORadiusStep;
    LStride := LStride * StrideFactor;
    LHeight := LHeight * StrideFactor;
  end;

//  TotalVertices := TotalParticles*12; TotalPrimitives := TotalParticles*2;
  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TWholeTreeMesh.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
{  for j := 0 to Levels-1 do begin
    for i := 0 to Smoothing-1 do begin
      TWordBuffer(IBPTR^)[(j*Smoothing+i)*3] := j*(Smoothing+1);
      TWordBuffer(IBPTR^)[(j*Smoothing+i)*3+1] := j*(Smoothing+1)+i+1;
      TWordBuffer(IBPTR^)[(j*Smoothing+i)*3+2] := j*(Smoothing+1)+i+2;
    end;
    TWordBuffer(IBPTR^)[(j*Smoothing+Smoothing-1)*3+2] := j*(Smoothing+1)+1;
  end;}

  for j := 0 to Levels-Byte(not RenderStem) do begin
    for i := 0 to Smoothing-1 do begin
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+0] := (j*2+0)*(Smoothing+0)+i;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+1] := (j*2+0)*(Smoothing+0)+i+1;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+2] := (j*2+1)*(Smoothing+0)+i;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+3] := (j*2+0)*(Smoothing+0)+i+1;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+4] := (j*2+1)*(Smoothing+0)+i+1;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+5] := (j*2+1)*(Smoothing+0)+i+0;
    end;
    TWordBuffer(IBPTR^)[(j*Smoothing)*6+(Smoothing-1)*6+1] := (j*2+0)*(Smoothing+0)+0;
    TWordBuffer(IBPTR^)[(j*Smoothing)*6+(Smoothing-1)*6+3] := (j*2+0)*(Smoothing+0)+0;
    TWordBuffer(IBPTR^)[(j*Smoothing)*6+(Smoothing-1)*6+4] := (j*2+1)*(Smoothing+0)+0;
  end;

  IStatus := tsTesselated;

  Result := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

function TWholeTreeMesh.CalcBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-OuterRadius, 0, -OuterRadius);
  Result.P2 := GetVector3s(OuterRadius, LevelStride*(Levels-1) + LevelHeight, OuterRadius);
end;

{ TGrassMesh }

constructor TGrassMesh.Create(const AName: TShortName);
begin
  inherited;
  SetParameters(70, 10, 3, $FF000000 + Random($100) shl 8);
end;

function TGrassMesh.MatchMesh(AMesh: TTesselator): Boolean;
var TMesh: TGrassMesh;
begin
  Result := False;
  if AMesh is TGrassMesh then TMesh := AMesh as TGrassMesh else Exit;
  Result := (Levels = TMesh.Levels) and (Height = TMesh.Height) and (Radius = TMesh.Radius);
end;

procedure TGrassMesh.SetParameters(const AHeight, ARadius, ALevels: Integer; const AGrassColor: Longword);
begin
  Height := AHeight; Radius := ARadius; Levels := ALevels; GrassColor := AGrassColor;
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  TotalVertices := 3*Levels+1;
  TotalPrimitives := 3*2*(Levels-1)+3;
  TotalIndices := 3*(3*2*(Levels-1)+3);

  IndexingVertices := TotalVertices;
  VertexFormat := GetVertexFormat(False, False, True, False, 1, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
end;

function TGrassMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPVertex = TCBDTVertex; TPVertexBuffer = array[0..$FFFFFF] of TPVertex;
var i, j: Integer; VBuf: ^TPVertexBuffer;
begin
  VBuf := VBPTR;
  for j := 0 to Levels-1 do begin
    for i := 0 to 3-1 do with VBuf^[j*3+i] do begin
      X := Cos(i/180*pi*360/3)*Radius;
      Y := Height*j;
      Z := -Sin(i/180*pi*360/3)*Radius;
//      X := U*Radius; Y := CurY-Height*0.2; Z := -V*Radius;
      W1 := 1-j/Levels;
      DColor := GrassColor;
      U := Cos((i+j*35)/180*pi*360/3); V := Sin((i+j*35)/180*pi*360/3);
      U := 0.5+U*0.5; V := 0.5-V*0.5;
    end;
  end;

  with VBuf^[TotalVertices-1] do begin
    X := 0;
    Y := Height*Levels;
    Z := 0;
    W1 := 0;
    DColor := GrassColor;
    U := 0.5; V := 0.5;
  end;

  VStatus := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result := TotalVertices;
end;

function TGrassMesh.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
  for j := 0 to Levels-2 do begin
    for i := 0 to 3-1 do begin
      TWordBuffer(IBPTR^)[(j*3)*6+i*6+0] := (j+0)*3+i;
      TWordBuffer(IBPTR^)[(j*3)*6+i*6+1] := (j+0)*3+i+1;
      TWordBuffer(IBPTR^)[(j*3)*6+i*6+2] := (j+1)*3+i;
      TWordBuffer(IBPTR^)[(j*3)*6+i*6+3] := (j+0)*3+i+1;
      TWordBuffer(IBPTR^)[(j*3)*6+i*6+4] := (j+1)*3+i+1;
      TWordBuffer(IBPTR^)[(j*3)*6+i*6+5] := (j+1)*3+i+0;
    end;
    TWordBuffer(IBPTR^)[(j*3)*6+(3-1)*6+1] := (j+0)*3+0;
    TWordBuffer(IBPTR^)[(j*3)*6+(3-1)*6+3] := (j+0)*3+0;
    TWordBuffer(IBPTR^)[(j*3)*6+(3-1)*6+4] := (j+1)*3+0;
  end;

  for i := 0 to 3-1 do begin
    TWordBuffer(IBPTR^)[(Levels*3-3)*6+i*3+0] := (Levels-1)*3+i;
    TWordBuffer(IBPTR^)[(Levels*3-3)*6+i*3+1] := (Levels-1)*3+i+1;
    TWordBuffer(IBPTR^)[(Levels*3-3)*6+i*3+2] := Levels*3;
  end;
  TWordBuffer(IBPTR^)[(Levels*3-3)*6+(3-1)*3+1] := (Levels-1)*3+0;

  IStatus := tsTesselated;

  Result := TotalIndices;
end;

function TGrassMesh.CalcBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-Radius, 0, -Radius);
  Result.P2 := GetVector3s(Radius, Height*Levels, Radius);
end;

{ TDomeTesselator }

constructor TDomeTesselator.Create(const AName: TShortName);
begin
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;
end;

function TDomeTesselator.MatchMesh(AMesh: TTesselator): Boolean;
var TMesh: TDomeTesselator;
begin
  Result := False;
  if AMesh is TDomeTesselator then TMesh := AMesh as TDomeTesselator else Exit;
  Result := (Sectors = TMesh.Sectors) and (Segments = TMesh.Segments) and
            (Height = TMesh.Height) and (Radius = TMesh.Radius) and
            (Color = TMesh.Color) and (Inner = TMesh.Inner);
end;

procedure TDomeTesselator.SetParameters(ASectors, ASegments, ARadius, AHeight: Integer; AUVScale: Single; AColor: Longword; AInner: Boolean);
begin
  Sectors := ASectors; Segments := ASegments;
  Radius := ARadius; Height := AHeight;
  UVScale := AUVScale;
  Color := AColor;
  Inner := AInner;
  TotalVertices := (Segments+1)*(Sectors+1);
  TotalIndices := (Segments)*(Sectors)*2*3;
  TotalPrimitives := (Segments)*(Sectors)*2+0*2*(Segments-1);
  IndexingVertices := TotalVertices;
end;

function TDomeTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TSkyVertex = TCDTVertex; TSkyBuffer = array[0..$FFFF] of TSkyVertex;
var i, j, si, sj: Integer; SkyBuf: ^TSkyBuffer; Normal: TVector3s;
begin
  Result := 0;
  if Segments = 0 then Exit;
  SkyBuf := VBPTR;
  for j := 0 to Segments do for i := 0 to Sectors do with SkyBuf[j*(Sectors+1)+i] do begin
//    X := Radius*Cos(i/Sectors*2*pi)*Cos(j/(Segments)*pi/2);
    si := i*(SinTableSize) div Sectors;
    sj := j*(SinTableSize) div Segments shr 2;
    X := Radius*SinTable[si+CosTabOffs]*SinTable[sj+CosTabOffs];
//    if j < Segments then Y := j * Height / Segments else Y := (j-1) * Height / Segments;
    Y := SinTable[sj] * Height;
    Z := Radius*SinTable[si] * SinTable[sj + CosTabOffs];
{    if Inner then
     Z := -Radius*SinTable[si]*SinTable[sj+CosTabOffs] else
      Z := Radius*SinTable[si]*SinTable[sj+CosTabOffs];}
    U := 0.5 + 0.5*(Segments-j)/Segments*SinTable[si + CosTabOffs]*UVScale;
    V := 0.5 + 0.5*(Segments-j)/Segments*SinTable[si]*UVScale;
//    Normal := NormalizeVector3s(GetVector3s(X, Y, Z));
    DColor := Color;
  end;
  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TDomeTesselator.SetIndices(IBPTR: Pointer): Integer;
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
  end;
  IStatus := tsTesselated;
  Result := TotalIndices;
end;

{ TWaterTesselator }

constructor TWaterTesselator.Create(const AName: TShortName);
begin
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(False, False, True, False, 0);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;
  TotalVertices := 4;
  TotalIndices := 0;
  TotalPrimitives := 2;
  IndexingVertices := 0;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
end;

function TWaterTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TWaterVertex = TCDVertex; TWaterBuffer = array[0..$FFFF] of TWaterVertex;
var Buf: ^TWaterBuffer;
begin
  Buf := VBPTR;
  Buf^[0].X := -1024; Buf^[0].Y := 0; Buf^[0].Z := 1024; Buf^[0].DColor := $80000080;
  Buf^[1].X := 1024; Buf^[1].Y := 0; Buf^[1].Z := 1024; Buf^[1].DColor := $80000080;
  Buf^[2].X := -1024; Buf^[2].Y := 0; Buf^[2].Z := -1024; Buf^[2].DColor := $80000080;
  Buf^[3].X := 1024; Buf^[3].Y := 0; Buf^[3].Z := -1024; Buf^[3].DColor := $80000080;
  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

{ TPlaneTesselator }

constructor TPlaneTesselator.Create(const AName: TShortName);
begin
  inherited;
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1;
  StripOffset := 0;
  TotalVertices := 4;
  TotalIndices := 0;
  TotalPrimitives := 2;
  IndexingVertices := 0;
  UOfs := 0; VOfs := 0;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
  SetParameters($80808080, 1000, 1000, 1, 1, 0, 0);
end;

function TPlaneTesselator.MatchMesh(AMesh: TTesselator): Boolean;
var TMesh: TPlaneTesselator;
begin
  Result := False; Exit;
  if AMesh is TPlaneTesselator then TMesh := AMesh as TPlaneTesselator else Exit;
  Result := (Color = TMesh.Color) and (Width = TMesh.Width) and (Height = TMesh.Height) and
            (UKoeff = TMesh.UKoeff) and (VKoeff = TMesh.VKoeff) and (UShift = TMesh.UShift) and (VShift = TMesh.VShift);
end;

procedure TPlaneTesselator.SetParameters(AColor: Longword; AWidth, AHeight, ATexturesWidth, ATexturesHeight, AUShift, AVShift: Single);
begin
  Color := AColor;
  Width := AWidth;
  Height := AHeight;
  TexturesWidth := ATexturesWidth;
  TexturesHeight := ATexturesHeight;
  if ATexturesWidth <> 0 then UKoeff := ATexturesWidth/(2*Width) else UKoeff := 0;
  if ATexturesHeight <> 0 then VKoeff := ATexturesHeight/(2*Height) else VKoeff := 0;
  UShift := AUShift;
  VShift := AVShift;
  UOfs := 0.5; VOfs := 0.5;
  VStatus := tsChanged;
end;

function TPlaneTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPlaneVertex = TCDTVertex; TPlaneBuffer = array[0..$FFFF] of TPlaneVertex;
var Buf: ^TPlaneBuffer;
begin
  Buf := VBPTR;
  Buf^[0].X := -Width; Buf^[0].Y := 0; Buf^[0].Z := Height;
  Buf^[0].U := UOfs - Width * UKoeff; Buf^[0].V := VOfs + Height*VKoeff;
  Buf^[0].DColor := Color;
  Buf^[1].X := Width; Buf^[1].Y := 0; Buf^[1].Z := Height;
  Buf^[1].U := UOfs + Width * UKoeff; Buf^[1].V := VOfs + Height*VKoeff;
  Buf^[1].DColor := Color;
  Buf^[2].X := -Width; Buf^[2].Y := 0; Buf^[2].Z := -Height;
  Buf^[2].U := UOfs - Width * UKoeff; Buf^[2].V := VOfs - Height*VKoeff;
  Buf^[2].DColor := Color;
  Buf^[3].X := Width; Buf^[3].Y := 0; Buf^[3].Z := -Height;
  Buf^[3].U := UOfs + Width * UKoeff; Buf^[3].V := VOfs - Height*VKoeff;
  Buf^[3].DColor := Color;
  VStatus := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result := TotalVertices;
end;

{ TGridTesselator }

constructor TGridTesselator.Create(const AName: TShortName);
begin
  PrimitiveType := CPTypes[ptTRIANGLEFAN];
  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;
  TotalIndices := 0; IndexingVertices := 0;
  UOfs := 0; VOfs := 0;
  VStatus := tsSizeChanged; IStatus := tsTesselated;
  SetParameters($80808080, $80808080, 1000, 1000, 1, 1, 0, 0);
end;

function TGridTesselator.MatchMesh(AMesh: TTesselator): Boolean;
var TMesh: TGridTesselator;
begin
  Result := False;
  if AMesh is TGridTesselator then TMesh := AMesh as TGridTesselator else Exit;
  Result := (Sectors = TMesh.Sectors) and (Radius = TMesh.Radius) and (UKoeff = TMesh.UKoeff) and (VKoeff = TMesh.VKoeff);
end;

procedure TGridTesselator.SetParameters(ACenterColor, ASideColor, ASectors: Longword; ARadius, ATexturesWidth, ATexturesHeight, AUShift, AVShift: Single);
begin
  CenterColor := ACenterColor; SideColor := ASideColor;
  Sectors := ASectors;
  Radius := ARadius;
  TexturesWidth := ATexturesWidth;
  TexturesHeight := ATexturesHeight;
  if ATexturesWidth <> 0 then UKoeff := ATexturesWidth/(2*Radius) else UKoeff := 0;
  if ATexturesHeight <> 0 then VKoeff := ATexturesHeight/(2*Radius) else VKoeff := 0;
  UShift := AUShift; VShift := AVShift;
  TotalVertices := 1+Sectors+1;
  TotalPrimitives := Sectors;
  VStatus := tsSizeChanged;
end;

function TGridTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TGridVertex = TCDTVertex; TGridBuffer = array[0..$FFFF] of TGridVertex;
var Buf: ^TGridBuffer; i: Integer;
begin
  Buf := VBPTR;
  Buf^[0].X := 0; Buf^[0].Y := 0; Buf^[0].Z := 0;
  Buf^[0].U := UOfs + 0.5; Buf^[0].V := VOfs + 0.5;
  Buf^[0].DColor := CenterColor;

  for i := 0 to Sectors do with Buf[1+i] do begin
    X := Radius*Cos(i/Sectors*2*pi);
    Y := 0;
    Z := Radius*Sin(i/Sectors*2*pi);
    U := UOfs + 0.5 + 0.5*Cos(i/Sectors*2*pi*1) * TexturesWidth;
    V := VOfs + 0.5 + 0.5*Sin(i/Sectors*2*pi*1) * TexturesHeight;
    DColor := SideColor;
  end;

  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

{ TWheelTraceTesselator }

procedure TWheelTraceTesselator.AddPoint(const APoint: TVector3s);
begin
  Inc(TotalPoints); SetLength(Points, TotalPoints);
  Points[TotalPoints - 1] := APoint;
  Inc(TotalVertices, 2); TotalPrimitives := TotalVertices - 2;
  VStatus := tsSizeChanged;
end;

procedure TWheelTraceTesselator.Clear;
begin
  TotalVertices := 0; TotalPrimitives := 0;
  TotalPoints := 0; SetLength(Points, TotalPoints);
  vStatus := tsSizeChanged;
end;

constructor TWheelTraceTesselator.Create(const AName: TShortName);
begin
  inherited;
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1; StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;
  TotalVertices := 0; TotalIndices := 0;
  TotalPrimitives := 0; IndexingVertices := 0;
  Size := 256; Color := $FFFFFFFF; Bias := 10;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
end;

function TWheelTraceTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var
  i: Integer;
  VX, VZ, VL, PX, PZ, OPX, OPZ, TPX, TPZ, LastX, LastZ, Len: Single; l: Single;
begin
  Result := 0;
  if TotalPoints <= 1 then Exit;
  Len := 0;
  for i := 0 to TotalPoints - 1 do begin             // Fill UV's
    with TCDTBuffer(VBPTR^)[i*2] do begin
      if i > 0 then begin
        l := Sqrt( Sqr(Points[i].X-Points[i-1].X) + Sqr(Points[i].Z-Points[i-1].Z) );
        Len := Len + l;
      end;
      U := Len/4/Size/2;
      TCDTBuffer(VBPTR^)[i*2+1].U := U;
      V := 0
    end;
  end;
//  OPX := 0; OPY := 0;

  with TCDTBuffer(VBPTR^)[0] do begin
    VX := Points[1].X - Points[0].X; VZ := Points[1].Z - Points[0].Z;
    VL := InvSqrt(VX*VX + VZ*VZ);
    Len := 1/VL;
    PX := -VL*(VX * 0 - VZ * 1); PZ := -VL*(VX * 1 + VZ * 0);

    TCDTBuffer(VBPTR^)[1].X := Points[0].X - PX*Size;
    TCDTBuffer(VBPTR^)[1].Z := Points[0].Z - PZ*Size;
    TCDTBuffer(VBPTR^)[1].Y := HMap.GetHeight(Points[0].X - PX*Size, Points[0].Z - PZ*Size) + Bias;
    TCDTBuffer(VBPTR^)[1].DColor := Color;
//    TCDTBuffer(VBPTR^)[1].U := 0;
    TCDTBuffer(VBPTR^)[1].V := 1;

    X := Points[0].X + PX*Size; Z := Points[0].Z + PZ*Size;
    Y := HMap.GetHeight(Points[0].X + PX*Size, Points[0].Z + PZ*Size) + Bias;
    DColor := Color;
    OPX := PX; OPZ := PZ;
  end;

  for i := 1 to TotalPoints - 2 do begin
    with TCDTBuffer(VBPTR^)[i*2] do begin
      VX := Points[i+1].X - Points[i].X; VZ := Points[i+1].Z - Points[i].Z;
      VL := InvSqrt(VX*VX + VZ*VZ);
      Len := Len + 1/VL;
      TPX := -VL*(VX * 0 - VZ * 1); TPZ := -VL*(VX * 1 + VZ * 0);
      PX := (OPX + TPX) * 0.5; PZ := (OPZ + TPZ) * 0.5;

      TCDTBuffer(VBPTR^)[i*2+1].X := Points[i].X - PX*Size;
      TCDTBuffer(VBPTR^)[i*2+1].Z := Points[i].Z - PZ*Size;
      TCDTBuffer(VBPTR^)[i*2+1].Y := HMap.GetHeight(Points[i].X - PX*Size, Points[i].Z - PZ*Size) + Bias;
      TCDTBuffer(VBPTR^)[i*2+1].DColor := Color;
//      TCDTBuffer(VBPTR^)[i*2+1].U := Len/128;
//      TCDTBuffer(VBPTR^)[i*2].U := TTCDTBuffer(VBPTR^)[i*2+1].U;
      TCDTBuffer(VBPTR^)[i*2+1].V := 1;
      X := Points[i].X + PX*Size; Z := Points[i].Z + PZ*Size;
      Y := HMap.GetHeight(Points[i].X + PX*Size, Points[i].Z + PZ*Size) + Bias;
      DColor := Color;
      OPX := 0*PX + TPX; OPZ := 0*PZ + TPZ;
    end;
  end;

  with TCDTBuffer(VBPTR^)[TotalPoints*2-2] do begin
    VX := Points[TotalPoints-1].X - Points[TotalPoints-2].X; VZ := Points[TotalPoints-1].Z - Points[TotalPoints-2].Z;
    VL := InvSqrt(VX*VX + VZ*VZ);
    Len := Len + 1/VL;
    PX := -VL*(VX * 0 - VZ * 1); PZ := -VL*(VX * 1 + VZ * 0);
    TCDTBuffer(VBPTR^)[TotalPoints*2-1].X := Points[TotalPoints-1].X - PX*Size;
    TCDTBuffer(VBPTR^)[TotalPoints*2-1].Z := Points[TotalPoints-1].Z - PZ*Size;
    TCDTBuffer(VBPTR^)[TotalPoints*2-1].Y := HMap.GetHeight(Points[TotalPoints-1].X - PX*Size, Points[TotalPoints-1].Z - PZ*Size) + Bias;
    TCDTBuffer(VBPTR^)[TotalPoints*2-1].DColor := Color;
//    TTCDTBuffer(VBPTR^)[TotalPoints*2-1].U := Len/128;
//    TTCDTBuffer(VBPTR^)[TotalPoints*2-2].U := TTCDTBuffer(VBPTR^)[TotalPoints*2-1].U;
    TCDTBuffer(VBPTR^)[TotalPoints*2-1].V := 1;
    LastX := Points[TotalPoints-1].X + PX*Size; LastZ := Points[TotalPoints-1].Z + PZ*Size;
    Y := HMap.GetHeight(Points[TotalPoints-1].X + PX*Size, Points[TotalPoints-1].Z + PZ*Size) + Bias;
    DColor := Color;
  end;

  TCDTBuffer(VBPTR^)[TotalPoints*2-2].X := LastX; TCDTBuffer(VBPTR^)[TotalPoints*2-2].Z := LastZ;
  VStatus := tsTesselated;
  LastTotalIndices := 0;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ TRockTesselator }

constructor TRockTesselator.Create(const AName: TShortName);
begin
  inherited;
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(False, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;

  SetParameters(30, 30, 100, 500, 100, 500, 1, $FF808080, 0, nil);
end;

procedure TRockTesselator.SetParameters(ALeftTransHeight, ARightTransHeight, ALeftTransLength, ALeftLength, ARightTransLength, ARightLength: Integer; AUK: Single; AColor: Longword; ATotalPoints: Integer; APoints: Pointer);
begin
  TotalPoints := ATotalPoints;
  Points := APoints;
  LeftTransHeight := ALeftTransHeight; RightTransHeight := ARightTransHeight;
  LeftTransLength := ALeftTransLength; LeftLength := ALeftLength;
  RightTransLength := ARightTransLength; RightLength := ARightLength;
  UK := AUK;
  Color := AColor;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
  TotalVertices := (TotalPoints-3)*5;
  TotalIndices := MaxI(0, (TotalPoints-3)*5*2);
//  TotalPrimitives := MaxI(0, (TotalPoints-3)*4*2 + (TotalPoints-4)*2);
  TotalPrimitives := MaxI(0, (TotalPoints-4)*5*2);
  IndexingVertices := TotalVertices;
end;

function TRockTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TVBuffer = array[0..$FFFF] of TCDTVertex;
var
  i: Integer; Buf: ^TVBuffer; PLoc: TVector3s; Mat: TMatrix3s;
  VX, VZ, VL, TPX, TPZ, PX, PZ, OPX, OPZ, K, TotalLen: Single;
{
  # 1. Make grid
  # 2. Handle direction
  # 3. Handle lighting
}
begin
  Result := 0;

  if (TotalPoints < 3+3) or (Points = nil) then Exit;
  Mat := YRotationMatrix3s(Angle);
  
  Buf := VBPTR;

  OPX := 0; OPZ := 0;
  for i := 1 to TotalPoints-3 do begin
    TotalLen := LeftTransLength + LeftLength + Points[i].Y + RightLength + RightTransLength;
    if i < TotalPoints-3 then begin
      VX := Points[(i+1)].X - Points[i].X;
      VZ := Points[(i+1)].Z - Points[i].Z;
    end else begin
      VX := Points[i].X - Points[(i-1)].X;
      VZ := Points[i].Z - Points[(i-1)].Z;
    end;
    if i = 1 then K := 1 else K := 0.5;
    VL := InvSqrt(Sqr(VX) + Sqr(VZ));
    TPX := VL*(VX * 0 - VZ * 1); TPZ := VL*(VX * 1 + VZ * 0);
    PX := (OPX + TPX) * K; PZ := (OPZ + TPZ) * K;
    OPX := TPX; OPZ := TPZ;

    with Buf^[i*4+i-5] do begin
      VZ := LeftTransLength + LeftLength;
      X := Points[i].X+PX*VZ; Z := Points[i].Z+PZ*VZ;
      PLoc := AddVector3s(Transform3Vector3s(Mat, GetVector3s(Points[i].X+PX*VZ, 0, Points[i].Z+PZ*VZ)), Loc);
      Y := HMap.GetHeight(PLoc.X, PLoc.Z);
      DColor := HMap.GetColor(PLoc.X, PLoc.Z) and $FFFFFF;
      U := UK*(i-1)/(TotalPoints-4); V := 1;
    end;

    with Buf^[i*4+i-5+1] do begin
      X := Points[i].X+PX*LeftLength; Z := Points[i].Z+PZ*LeftLength;
      PLoc := AddVector3s(Transform3Vector3s(Mat, GetVector3s(Points[i].X+PX*LeftLength, 0, Points[i].Z+PZ*LeftLength)), Loc);
      if (i = 1) or (i = TotalPoints-3) then begin
        Y := HMap.GetHeight(PLoc.X, PLoc.Z);
        DColor := HMap.GetColor(PLoc.X, PLoc.Z) and $FFFFFF;
      end else begin
        Y := HMap.GetHeight(PLoc.X, PLoc.Z) + LeftTransHeight;
        DColor := HMap.GetColor(PLoc.X, PLoc.Z) or (Color and ($FF shl 24));
      end;
      U := UK*(i-1)/(TotalPoints-4); V := 1-LeftTransLength/TotalLen;
    end;

    with Buf^[i*4+i-5+2] do begin
      X := Points[i].X; Z := Points[i].Z;
      PLoc := AddVector3s(Transform3Vector3s(Mat, GetVector3s(Points[i].X, 0, Points[i].Z)), Loc);
      if (i = 1) or (i = TotalPoints-3) then begin
        Y := HMap.GetHeight(PLoc.X, PLoc.Z);
        DColor := HMap.GetColor(PLoc.X, PLoc.Z) and $FFFFFF;
      end else begin
        Y := LeftTransHeight + Points[i].Y;
        DColor := HMap.GetColor(PLoc.X, PLoc.Z) or (Color and ($FF shl 24));
      end;
      U := UK*(i-1)/(TotalPoints-4); V := 0.5;
    end;

    with Buf^[i*4+i-5+3] do begin
      X := Points[i].X-PX*RightLength; Z := Points[i].Z-PZ*RightLength;
      PLoc := AddVector3s(Transform3Vector3s(Mat, GetVector3s(Points[i].X-PX*RightLength, 0, Points[i].Z-PZ*RightLength)), Loc);
      if (i = 1) or (i = TotalPoints-3) then begin
        Y := HMap.GetHeight(PLoc.X, PLoc.Z);
        DColor := HMap.GetColor(PLoc.X, PLoc.Z) and $FFFFFF;
      end else begin
        Y := HMap.GetHeight(PLoc.X, PLoc.Z) + RightTransHeight;
        DColor := HMap.GetColor(PLoc.X, PLoc.Z) or (Color and ($FF shl 24));
      end;
      U := UK*(i-1)/(TotalPoints-4); V := RightTransHeight/TotalLen;
    end;

    with Buf^[i*4+i-5+4] do begin
      VZ := RightTransLength + RightLength;
      X := Points[i].X-PX*VZ; Z := Points[i].Z-PZ*VZ;
      PLoc := AddVector3s(Transform3Vector3s(Mat, GetVector3s(Points[i].X-PX*VZ, 0, Points[i].Z-PZ*VZ)), Loc);
      Y := HMap.GetHeight(PLoc.X, PLoc.Z);
      DColor := HMap.GetColor(PLoc.X, PLoc.Z) and $FFFFFF;
      U := UK*(i-1)/(TotalPoints-4); V := 0;
    end;
  end;

  VStatus := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result := TotalVertices;
end;

function TRockTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
  for j := 0 to TotalPoints-2-3 do for i := 0 to 4 do begin
    TWordBuffer(IBPTR^)[(j*5+i)*2] := j*5+i;
    TWordBuffer(IBPTR^)[(j*5+i)*2+1] := j*5+i+5;
  end;
  IStatus := tsTesselated;
  Result := TotalIndices;
end;

{ TWholeTreeMesh2 }

function TWholeTreeMesh2.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPVertex = TCBNTVertex; TPVertexBuffer = array[0..$FFFFFF] of TPVertex;
var i, j: Integer; VBuf: ^TPVertexBuffer; CurY, YDec: Single;
begin
{  VBuf := VBPTR;
  YDec := 1; CurY := 0;
  for j := 0 to Levels-1 do begin
    for i := 0 to Smoothing-1 do with VBuf^[j*2*(Smoothing)+i] do begin
      U := Cos(i/180*pi*360/Smoothing); V := Sin(i/180*pi*360/Smoothing);
      X := U*Radius*(1-(j+1)/(Levels+1)*0.8);
//      Y := CurY-Height*0.0*(1-j/(Levels)*0.5);
      Y := CurY + Height*0.5 * YDec;
      Z := V*Radius*(1-(j+1)/(Levels+1)*0.8);
//      X := U*Radius; Y := CurY-Height*0.2; Z := -V*Radius;
      W1 := 0;//1-Y/(Height*(Levels-1)*0.3);
      NX := U; NY := 0; NZ := -V;
      U := Cos((i+j*35)/180*pi*360/Smoothing); V := Sin((i+j*35)/180*pi*360/Smoothing);
      U := 0.5+U*0.5; V := 0.5-V*0.5;
    end;
    YDec := YDec * (1-0.7/(Levels));
    for i := 0 to Smoothing-1 do with VBuf^[(j*2+1)*(Smoothing)+i] do begin
      U := Cos(i/180*pi*360/Smoothing)*0.5; V := Sin(i/180*pi*360/Smoothing)*0.5;
      X := U*Radius*(1-(j+1)/(Levels+0));
//      Y := CurY + Height*0.5 * YDec;
      Y := CurY-Height*0.0*(1-j/(Levels)*0.5);
      Z := V*Radius*(1-(j+1)/(Levels+0));
      W1 := 0;//1-Y/(Height*(Levels-1)*0.3);
      NX := U; NY := 0; NZ := -V;

      U := Cos((i+j*35)/180*pi*360/Smoothing); V := Sin((i+j*35)/180*pi*360/Smoothing);
      U := 0.5+U*0.25*(1-(j+1)/(Levels)); V := 0.5-V*0.25*(1-(j+1)/(Levels));
    end;
//    YDec := YDec * (1-0.7/(Levels));
    CurY := CurY + Height*0.3 * YDec;
  end;
  for i := 0 to TotalVertices-1 do VBuf^[i].W1 := 1 - VBuf^[i].Y / VBuf^[TotalVertices-1].Y;

  Status := tsTesselated;
  Result := TotalVertices;}
end;

{ TFXDomeTesselator }

function TFXDomeTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TSkyVertex = TCDTVertex; TSkyBuffer = array[0..$FFFF] of TSkyVertex;
var i, j, si, sj: Integer; SkyBuf: ^TSkyBuffer; Normal: TVector3s;
begin
  Result := 0;
  if Segments = 0 then Exit;
  SkyBuf := VBPTR;
  for j := 0 to Segments do for i := 0 to Sectors do with SkyBuf[j*(Sectors+1)+i] do begin
//    X := Radius*Cos(i/Sectors*2*pi)*Cos(j/(Segments)*pi/2);
    si := i*(SinTableSize) div Sectors;
    sj := j*(SinTableSize) div Segments shr 2;
    X := Radius*SinTable[si+CosTabOffs]*SinTable[sj+CosTabOffs];
//    if j < Segments then Y := j * Height / Segments else Y := (j-1) * Height / Segments;
    Y := SinTable[sj] * Height;
    Z := Radius*SinTable[si] * SinTable[sj + CosTabOffs];
{    if Inner then
     Z := -Radius*SinTable[si]*SinTable[sj+CosTabOffs] else
      Z := Radius*SinTable[si]*SinTable[sj+CosTabOffs];}
    U := 0.5 + 0.5*(Segments-j)/Segments*SinTable[si + CosTabOffs]*Sin(CurrentTick/180*pi*10)*UVScale;
    V := 0.5 + 0.5*(Segments-j)/Segments*SinTable[si]*Cos(CurrentTick/180*pi*10)*UVScale;
//    Normal := NormalizeVector3s(GetVector3s(X, Y, Z));
    DColor := Color;
  end;
  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

{ TBackgroundTesselator }

constructor TBackgroundTesselator.Create(const AName: TShortName);
begin
  PrimitiveType := CPTypes[ptTRIANGLELIST];
  VertexFormat := GetVertexFormat(True, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;
  SetParameters($80808080, 2, 2, 0, 1);
end;

function TBackgroundTesselator.MatchMesh(AMesh: TTesselator): Boolean;
var TMesh: TBackgroundTesselator;
begin
  Result := False;
  if AMesh is TBackgroundTesselator then TMesh := AMesh as TBackgroundTesselator else Exit;
  Result := (Color = TMesh.Color) and
            (Cols = TMesh.Cols) and (Rows = TMesh.Rows) and
            (Angle = TMesh.Angle) and (Zoom = TMesh.Zoom);
end;

procedure TBackgroundTesselator.SetParameters(AColor, ACols, ARows: Longword; AAngle: Integer; AZoom: Single);
begin
  Color := AColor;
  Cols := ACols; Rows := ARows;
  Angle := AAngle; Zoom := AZoom;

  TotalVertices := (Cols)*(Rows);
  TotalIndices := (Rows-1)*(Cols-1)*2*3;
  TotalPrimitives := (Rows-1)*(Cols-1)*2;
  IndexingVertices := TotalVertices;

  Invalidate(True);
end;

function TBackgroundTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
  for j := 0 to Rows-2 do begin
    for i := 0 to Cols-2 do begin
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+0] := (j+0)*(Cols)+i;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+1] := (j+1)*(Cols)+i;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+2] := (j+0)*(Cols)+i+1;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+3] := (j+1)*(Cols)+i;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+4] := (j+1)*(Cols)+i+1;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+5] := (j+0)*(Cols)+i+1
    end;
  end;
  IStatus := tsTesselated;
  Result := TotalIndices;
end;

function TBackgroundTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type T2DVertex = TTCDTVertex; T2DVBuffer = array[0..$FFFF] of T2DVertex;
var
  i, j: Integer; Buf: ^T2DVBuffer;
  OOZoom, OOCols, OORows: Single;
begin
  Result := 0;
  if (Cols < 2) or (Rows < 2) then Exit;
  OOZoom := 1/Zoom; OOCols := 1/(Cols-1); OORows := 1/(Rows-1);     // Some optimizations
  Buf := VBPTR;
  for j := 0 to Rows-1 do for i := 0 to Cols-1 do with Buf[j*Cols+i] do begin
    X := (i * OOCols) * RenderPars.ActualWidth;
    Y := (j * OORows) * RenderPars.ActualHeight;
    Z := 0;
    RHW := 0.001;
    DColor := Color;
    U := ( (i * OOCols) * SinTable[(Angle + CosTabOffs) and (SinTableSize-1)] +
           (j * OORows) * SinTable[(Angle) and (SinTableSize-1)] ) * OOZoom;
    V := ( (j * OORows) * SinTable[(Angle + CosTabOffs) and (SinTableSize-1)] -
           (i * OOCols) * SinTable[(Angle) and (SinTableSize-1)] ) * OOZoom;
  end;
  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

{ TColoredTreeMesh }

constructor TColoredTreeMesh.Create(const AName: TShortName);
begin
  inherited;
  InitVertexFormat(GetVertexFormat(False, True, True, False, 1, 1));
  SetParameters(200, 300, 400, 800, 80, 80, 0.9, True, 0.25, 0.25, 1, 300, 100, 1000, 200, 8, 5);
  StemColor := $C08040FF;
  CrownColor := $80FF8080;
end;

function TColoredTreeMesh.MatchMesh(AMesh: TTesselator): Boolean;
begin
  Result := inherited MatchMesh(AMesh) and (AMesh is TColoredTreeMesh) and
           (StemColor = (AMesh as TColoredTreeMesh).StemColor) and
           (CrownColor = (AMesh as TColoredTreeMesh).CrownColor);
end;

function TColoredTreeMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i: Integer;
begin
  Result := inherited Tesselate(RenderPars, VBPTR);
  if RenderStem then for i := 0 to Smoothing*2-1 do
   SetVertexDataD(StemColor, i, VBPTR);
  for i := Ord(RenderStem)*Smoothing*2 to TotalVertices-1 do SetVertexDataD(CrownColor, i, VBPTR);
end;

{ TRingMesh }

constructor TRingMesh.Create(const AName: TShortName);
begin
  inherited;
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  InitVertexFormat(GetVertexFormat(False, False, True, False, 1, 0));
  UVFrame.U := 0; UVFrame.V := 0; UVFrame.W := 1; UVFrame.H := 1;
  SetParameters(200, 500, 8, $80808080, $FFFFFFFF, 1, uvtPlanar);
end;

function TRingMesh.MatchMesh(AMesh: TTesselator): Boolean;
var Mesh: TRingMesh;
begin
  Result := False;
  if AMesh is TRingMesh then Mesh := AMesh as TRingMesh else Exit;
  Result := (UVMapType = Mesh.UVMapType) and (Smoothing = Mesh.Smoothing) and
            (InnerRadius = Mesh.InnerRadius) and (OuterRadius = Mesh.OuterRadius) and
            (Color1 = Mesh.Color1) and (Color2 = Mesh.Color2) and (Factor = Mesh.Factor) and
            (UVFrame.U = Mesh.UVFrame.U) and (UVFrame.V = Mesh.UVFrame.V) and
            (UVFrame.W = Mesh.UVFrame.W) and (UVFrame.H = Mesh.UVFrame.H);
end;

procedure TRingMesh.SetParameters(AInnerRadius, AOuterRadius: Single; ASmoothing: Integer; AColor1, AColor2: Longword; AFactor: Single; AUVMapType: Integer);
begin
  Smoothing   := ASmoothing;
  InnerRadius := AInnerRadius;
  OuterRadius := AOuterRadius;
  UVMapType   := AUVMapType;
  Color1      := AColor1;
  Color2      := AColor2;
  Factor      := AFactor;

  TotalVertices   := (Smoothing+1)*2;
  TotalPrimitives := Smoothing*2;
  TotalIndices    := 0;//3*Smoothing*2*Levels + 3*Smoothing*2 * Byte(RenderStem);

  IndexingVertices := TotalVertices;
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;
  VStatus := tsSizeChanged; IStatus := tsSizeChanged;
end;

function TRingMesh.SetIndices(IBPTR: Pointer): Integer;
begin

end;

function TRingMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i: Integer; t, t1, t2, w, oos, sw, f: Single; Col: Longword;
begin
  oos := 1/Smoothing;
  if Factor < 1 then begin
    sw := 1 - Factor;
    f  := 1 / Factor;
  end else begin
    sw := 0;
    f  := Factor;
  end;
  if Abs(OuterRadius) > Epsilon then t := 0.5 / OuterRadius else t := 0;
  for i := 0 to Smoothing do begin              // Outer edge
//    w := Abs(Smoothing*0.5 - i)*2*oos * Factor;
    w := (Abs(Smoothing*0.5 - i)*2*oos  - sw) * f;
    Col := BlendColor(Color2, Color1, w);
//   c1 --------- c2 --------- c1
    t1 := Cos(i/180*pi*360*oos); t2 := Sin(i/180*pi*360*oos);
    SetVertexDataC(t1*OuterRadius, 0, t2*OuterRadius, i*2, VBPTR);
    SetVertexDataD(Col, i*2, VBPTR);

    SetVertexDataC(t1*InnerRadius, 0, t2*InnerRadius, i*2+1, VBPTR);
    SetVertexDataD(Col, i*2+1, VBPTR);

    if UVMapType = uvtPlanar then begin
      SetVertexDataUV(UVFrame.U + (i * oos) * UVFrame.W, UVFrame.V, i*2, VBPTR);
      SetVertexDataUV(UVFrame.U + (i * oos) * UVFrame.W, UVFrame.V + UVFrame.H, i*2+1, VBPTR);
    end else begin
      SetVertexDataUV(0.5 + t1 * OuterRadius * t, 0.5 - t2 * OuterRadius * t, i*2, VBPTR);
      SetVertexDataUV(0.5 + t1 * InnerRadius * t, 0.5 - t2 * InnerRadius * t, i*2+1, VBPTR);
    end;
  end;

  VStatus := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TRingMesh.CalcBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-OuterRadius, 0, -OuterRadius);
  Result.P2 := GetVector3s( OuterRadius, 0,  OuterRadius);
end;

end.
