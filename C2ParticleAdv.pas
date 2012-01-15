(*
 @Abstract(CAST II Engine advanced particle unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: 21.01.2007 <br>
 Unit contains advanced particle system classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2ParticleAdv;

interface

uses
  SysUtils,
  BaseTypes, Basics, Base3D, Props,
  BaseClasses, C2Types, CAST2, C2Visual, C2Particle;

type
  TCordTesselator = class(TParticleSystemMesh)
  private
    ParticlesVisible: Integer;
  public
    UVScale: Single;
    TryToCorrect: Boolean;
    constructor Create; override;
    function GetMaxVertices: Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TParticleCord = class(TParticleSystem)
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TRibbonTesselator = class(TParticleSystemMesh)
  private
    ParticlesVisible: Integer;
    Crosses: array of TVector3s;
  public
    UVScale: Single;
    constructor Create; override;
    destructor Destroy; override;

    function GetMaxVertices: Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TParticleRibbon = class(TParticleSystem)
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TParticleCord, TParticleRibbon]);
end;

{ TCordTesselator }

constructor TCordTesselator.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLESTRIP;
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));
  UVScale := 0.001;
end;

function TCordTesselator.GetMaxVertices: Integer;
begin
  Result := ParticleSystem.TotalParticles*2;
end;

function TCordTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  i, LastI: Integer;
  SqDist, InvDist, CurU: Single;
  CamZInModel, Cross, OldCross, P1, P2, OldP1, OldP2: TVector3s;

function GetCross(Index: Integer): TVector3s;
begin
  if Index < ParticleSystem.TotalParticles-1 then Inc(Index);
  Result := CrossProductVector3s(SubVector3s(ParticleSystem.RenderData[Index].Position, ParticleSystem.RenderData[LastI].Position), CamZInModel);
end;

begin
  TotalPrimitives   := 0;
  Result := 0;

  LastTotalVertices := Result;
  if not Assigned(ParticleSystem) or (ParticleSystem.TotalParticles < 2) then Exit;

  CamZInModel := Transform3Vector3sTransp(CutMatrix3s(ParticleSystem.Transform), Params.Camera.ForwardVector);

  ParticlesVisible := 0;
  CurU := 0;
  LastI := 0;
  OldCross := GetCross(1);

  for i := 0 to ParticleSystem.TotalParticles-1 do begin
    if i > 0 then
      Cross := GetCross(i) else
        Cross := GetCross(i+1);
//    if i < ParticleSystem.TotalParticles-1 then Cross := GetCross(i);
{    if (i > 0) and (i < ParticleSystem.TotalParticles-2) then begin
      Cross := GetCross(i-1);
      Cross2 := GetCross(i+1);
      Cross := ScaleVector3s(AddVector3s(Cross, Cross2), 0.5);
    end;}
    with ParticleSystem.RenderData[i] do begin
      SqDist := SqrMagnitude(Cross);
      InvDist := 1/Sqrt(SqDist);
      CurU := CurU + UVScale/InvDist;
      if SqDist < {epsilon}Sqr(Size*0.5) then Continue;
      ScaleVector3s(Cross, Cross, Size*InvDist);

      P1 := AddVector3s(Position, Cross);
      P2 := SubVector3s(Position, Cross);

      if TryToCorrect and (i > 0) then begin
//        if SqrMagnitude(SubVector3s(OldP1, P1)) < Sqr(Size*0.9) then P1 := OldP1;
//        if SqrMagnitude(SubVector3s(OldP2, P2)) < Sqr(Size*0.9) then P2 := OldP2;
        if not IsPointsSameSide(ParticleSystem.RenderData[LastI].Position, OldCross, P1, Position) then
          P1 := OldP1 else
            if not IsPointsSameSide(ParticleSystem.RenderData[LastI].Position, OldCross, P2, Position) then
              P2 := OldP2;
//        P1 := OldP1
      end;

      SetVertexDataC(P1,       ParticlesVisible*2, VBPTR);
      SetVertexDataUV(0, CurU, ParticlesVisible*2, VBPTR);
      SetVertexDataD(Color,    ParticlesVisible*2, VBPTR);

      SetVertexDataC(P2,       ParticlesVisible*2+1, VBPTR);
      SetVertexDataUV(1, CurU, ParticlesVisible*2+1, VBPTR);
      SetVertexDataD(Color,    ParticlesVisible*2+1, VBPTR);
    end;
    Inc(ParticlesVisible);
    OldP1 := P1;
    OldP2 := P2;
    OldCross := Cross;
    LastI := i;
  end;

{  for i := 0 to ParticleSystem.TotalParticles-1 do begin
    if i < ParticleSystem.TotalParticles-1 then
      Cross := CrossProductVector3s(SubVector3s(ParticleSystem.RenderData[i+1].Position, ParticleSystem.RenderData[i].Position), CamZInModel);
    SqDist := SqrMagnitude(Cross);
    if SqDist < Sqr(ParticleSystem.RenderData[i].Size*0.1) then Continue;
    InvDist := 1/Sqrt(SqDist);
    ScaleVector3s(Cross, Cross, InvDist);
    CurU := CurU + UScale/InvDist;
    with ParticleSystem.RenderData[i] do begin
      ScaleVector3s(Cross, Cross, Size * InvSqrt(SqrMagnitude(Cross)));

      SetVertexDataC(AddVector3s(Position, Cross), ParticlesVisible*2, VBPTR);
      SetVertexDataUV(1, CurU, ParticlesVisible*2, VBPTR);
      SetVertexDataD(Color, ParticlesVisible*2, VBPTR);

      SetVertexDataC(SubVector3s(Position, Cross), ParticlesVisible*2+1, VBPTR);
      SetVertexDataUV(0, CurU, ParticlesVisible*2+1, VBPTR);
      SetVertexDataD(Color, ParticlesVisible*2+1, VBPTR);
    end;
    Inc(ParticlesVisible);
  end;}

  TotalPrimitives   := ParticlesVisible*2 - 2;
  Result            := ParticlesVisible*2;
  TotalVertices     := Result;
  LastTotalVertices := Result;
end;

{ TParticleCord }

function TParticleCord.GetTesselatorClass: CTesselator; begin Result := TCordTesselator end;

procedure TParticleCord.AddProperties(const Result: Props.TProperties);
var Mesh: TCordTesselator;
begin
  inherited;
  if not Assigned(Result) then Exit;

  if not (CurrentTesselator is TCordTesselator) then begin
    Result.Add('Error', vtString, [poReadOnly], 'Tesselator is undefined', '');
    Exit;
  end;
  Mesh := CurrentTesselator as TCordTesselator;

  Result.Add('Texture scale', vtSingle,  [], FloatToStr(Mesh.UVScale), '');
  Result.Add('Correct folds', vtBoolean, [], OnOffStr[Mesh.TryToCorrect], '');
end;

procedure TParticleCord.SetProperties(Properties: Props.TProperties);
var Mesh: TCordTesselator;
begin
  inherited;
  if not (CurrentTesselator is TCordTesselator) then Exit;
  Mesh := CurrentTesselator as TCordTesselator;
  if Properties.Valid('Texture scale') then Mesh.UVScale      := StrToFloatDef(Properties['Texture scale'], 0);
  if Properties.Valid('Correct folds') then Mesh.TryToCorrect := Properties.GetAsInteger('Correct folds') > 0;
end;

{ TParticleRibbon }

function TParticleRibbon.GetTesselatorClass: CTesselator; begin Result := TRibbonTesselator end;

procedure TParticleRibbon.AddProperties(const Result: Props.TProperties);
var Mesh: TRibbonTesselator;
begin
  inherited;
  if not Assigned(Result) then Exit;

  if not (CurrentTesselator is TRibbonTesselator) then begin
    Result.Add('Error', vtString, [poReadOnly], 'Tesselator is undefined', '');
    Exit;
  end;
  Mesh := CurrentTesselator as TRibbonTesselator;

  Result.Add('Texture scale', vtSingle,  [], FloatToStr(Mesh.UVScale), '');
end;

procedure TParticleRibbon.SetProperties(Properties: Props.TProperties);
var Mesh: TRibbonTesselator;
begin
  inherited;
  if not (CurrentTesselator is TRibbonTesselator) then Exit;
  Mesh := CurrentTesselator as TRibbonTesselator;
  if Properties.Valid('Texture scale') then Mesh.UVScale      := StrToFloatDef(Properties['Texture scale'], 0);
end;

{ TRibbonTesselator }

constructor TRibbonTesselator.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLESTRIP;
  InitVertexFormat(GetVertexFormat(False, True, True, False, False, 0, [2]));
  UVScale := 0.001;
end;

destructor TRibbonTesselator.Destroy;
begin
  Crosses := nil;
  inherited;
end;

function TRibbonTesselator.GetMaxVertices: Integer;
begin
  Result := ParticleSystem.TotalParticles*2;
end;

function TRibbonTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;

function GetNormal(Index: Integer): TVector3s;
var I2, I1: Integer;
begin
  if Index > 0 then I1 := Index-1 else I1 := 0;
  if Index < ParticleSystem.TotalParticles-1 then I2 := Index+1 else I2 := ParticleSystem.TotalParticles-1;
  CrossProductVector3s(Result, SubVector3s(ParticleSystem.RenderData[I2].Position, ParticleSystem.RenderData[I1].Position), Crosses[Index]);
end;

var
  i, j, LastIndex: Integer;
  CurNorm, OldNorm: TVector3s;
  CurU, InvDist: Single;

begin
  TotalPrimitives := 0;
  Result := 0;

  LastTotalVertices := Result;
  if not Assigned(ParticleSystem) or (ParticleSystem.TotalParticles < 2) then Exit;

  if Length(Crosses) < ParticleSystem.TotalParticles then SetLength(Crosses, ParticleSystem.TotalParticles);
// Crosses calculation
  LastIndex := -1;
  CrossProductVector3s(CurNorm, GetVector3s(0, 1, 0), SubVector3s(ParticleSystem.RenderData[1].Position, ParticleSystem.RenderData[0].Position));
  if SqrMagnitude(CurNorm) < epsilon then CurNorm := GetVector3s(1, 0, 0);
  Crosses[0] := CurNorm;
  for i := 1 to ParticleSystem.TotalParticles-2 do begin
    CrossProductVector3s(OldNorm, SubVector3s(ParticleSystem.RenderData[i].Position, ParticleSystem.RenderData[i-1].Position),
                                  SubVector3s(ParticleSystem.RenderData[i+1].Position, ParticleSystem.RenderData[i].Position));
    if SqrMagnitude(OldNorm) > epsilon then begin
      if LastIndex <> -1 then begin
        if DotProductVector3s(OldNorm, CurNorm) < 0 then
          ScaleVector3s(OldNorm, -1);
      end else for j := i-1 downto 0 do Crosses[j] := OldNorm;
      CurNorm := OldNorm;
      LastIndex := i;
    end;
    Crosses[i] := CurNorm;
  end;

  Crosses[ParticleSystem.TotalParticles-1] := Crosses[ParticleSystem.TotalParticles-2];

  ParticlesVisible := 0;
  CurU             := 0;

  for i := 0 to ParticleSystem.TotalParticles-1 do begin
    with ParticleSystem.RenderData[i] do begin
      CurNorm := GetNormal(i);
      InvDist := 1/Sqrt(SqrMagnitude(Crosses[i]));
      ScaleVector3s(Crosses[i], Crosses[i], Size*InvDist);
      CurU := CurU + UVScale/InvDist;

      SetVertexDataC(AddVector3s(Position, Crosses[i]), ParticlesVisible*2, VBPTR);
      SetVertexDataN(CurNorm,  ParticlesVisible*2, VBPTR);
      SetVertexDataUV(0, CurU, ParticlesVisible*2, VBPTR);
      SetVertexDataD(Color,    ParticlesVisible*2, VBPTR);

      SetVertexDataC(SubVector3s(Position, Crosses[i]), ParticlesVisible*2+1, VBPTR);
      SetVertexDataN(CurNorm,  ParticlesVisible*2+1, VBPTR);
      SetVertexDataUV(1, CurU, ParticlesVisible*2+1, VBPTR);
      SetVertexDataD(Color,    ParticlesVisible*2+1, VBPTR);
    end;
    Inc(ParticlesVisible);
  end;

  TotalPrimitives   := ParticlesVisible*2 - 2;
  Result            := ParticlesVisible*2;
  TotalVertices     := Result;
  LastTotalVertices := Result;
end;

begin
  GlobalClassList.Add('C2ParticleAdv', GetUnitClassList);
end.
