{$Include GDefines}
{$Include CDefines}
unit CParticle;

interface

uses CTypes, Basics, Base3D, Cast, CTess, CRender, SysUtils, Windows;

const MaxAngle = 360;

type
  TParticle = packed record
    Position, Velocity: TVector3s;
    Radius, Mass, FadeK: Single;
    Color, Age, LifeTime: Longword;
    Angle, Sprite: Integer;
  end;

  TParticlesMesh = class(TTesselator)
    Quads, ReverseOrder: Boolean;
    Particles: array of TParticle;
    TotalParticles: Integer;
    MaxCapacity, Capacity: Cardinal;
    Location: TVector3s;
    constructor Create(const AName: TShortName); override;
    function AddParticles(Count: Integer): Integer; virtual;
    procedure SetCapacity(const ACapacity: Integer); virtual;
    function GetMaxVertices: Integer; override;
    function GetMaxIndices: Integer; override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    destructor Free;
  private
    ParticlesVisible: Integer;
  end;

  T3DParticlesMesh = class(TParticlesMesh)
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  T3DAngleParticlesMesh = class(T3DParticlesMesh)
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  T2DParticleSystem = class(TParticleSystem)
    function Process: Boolean; override;
  end;

  T3DParticleSystem = class(TParticleSystem)
    OldLocation: TVector3s;
    Relocated: Boolean;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Init; override;
    procedure SetMesh; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    procedure SetupExternalVariables; override;
    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSFadingIn = class(T3DParticleSystem)
    ElevationSpeed, VelocityJitter, GrowSpeed, RadiusJitter, ExpansionSpeed, SlowDown, Density: Single;
    GrowInPeriod, FadeInPeriod, FadeInShift: Integer;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;

    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSFountain = class(T3DParticleSystem)
    GlobalForce: TVector3s;
    InitYSpeed: Integer;
    MaxHSpeed, Density, SizeJitter: Longword;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;

    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;

    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSBalls = class(TParticleSystem)
//    procedure SetMesh(const AVerticesRes, AIndicesRes: Integer); override;
    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSSmoke = class(TPSFadingIn)
    ColoredLength, RotationSpeed, StartAgeJitter: Integer;
    EndColor: Longword;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;

    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSComet = class(T3DParticleSystem)
    Density: Integer;
    CoreRadius, RadiusJitter, GrowthSpeed, FadeSpeed, ElevationSpeed: Single;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;

    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;

    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSFire = class(TPSFadingIn)
    ElevationJitter, ShrinkSpeed: Single;
    ShrinkStart: Integer;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSExplosion = class(TPSSmoke)
    CicleCompleteness: Single;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSExpSmoke = class(TPSSmoke)
    SpreadAngle: Integer;
    RotationSlowdown: Single;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  TPSAdvSmoke = class(TPSSmoke)
    ShrinkPeriod: Integer;
    ShrinkAmount, RotationSlowdown: Single;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
  end;

  T2DFireworks = class(T2DParticleSystem)
    Slowdown, LaunchAngle, FallSpeed, ExplosionSize, FadeSpeed, GrowSpeed, RadiusJitter, Speed: Single;
    HalfPeriod, ExplosionDensity: Cardinal;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function Emit(Count: Single): Integer; override;
    function Process: Boolean; override;
    procedure Start; virtual;
  end;

implementation

{ TParticlesMesh }

constructor TParticlesMesh.Create(const AName: TShortName);
begin
  inherited;
  PrimitiveType := CPTypes[ptTRIANGLELIST];
//  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(True, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);

  MaxCapacity := 2000;
  SetCapacity(ParticlesAllocStep);             // Default capaticy
  TotalParticles := 0;
  Quads := True;
  ReverseOrder := True;
end;

function TParticlesMesh.AddParticles(Count: Integer): Integer;
var OldTP: Integer;
begin
  if Capacity < TotalParticles + Count then SetCapacity(TotalParticles + Count);
  OldTP := TotalParticles;
  TotalParticles := MinI(Capacity, TotalParticles + Count);
  Result := TotalParticles - OldTP;
end;

procedure TParticlesMesh.SetCapacity(const ACapacity: Integer);
begin
  Capacity := MinI(MaxCapacity, MaxI(0, (ACapacity-1)) and ParticleAllocMask + ParticlesAllocStep);
  SetLength(Particles, Capacity);
end;

function TParticlesMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPVertex = TTCDTVertex; TPVertexBuffer = array[0..$FFFFFF] of TPVertex;
var i: Integer; VBuf: ^TPVertexBuffer; Transformed: TVector4s; TRHW: Single;
begin
  Result := 0;
  LastTotalVertices := 0;
  Transformed := GetVector4s(0*Location.X, 0*Location.Y, Location.Z, 1); //Transform4Vector3s(RenderPars.TotalMatrix, Location);
  if Transformed.W < 0 then Exit;
  TRHW := 0.001;//1/Transformed.W;
  Transformed.X := {RenderPars.ActualWidth shr 1 + RenderPars.ActualWidth shr 1*}Transformed.X;
  Transformed.Y := {RenderPars.ActualHeight shr 1 - RenderPars.ActualHeight shr 1*}Transformed.Y;
//  with RenderPars do Transformed.Z := 0*(ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));
  VBuf := VBPTR;
  if not Quads then begin
    for i := 0 to TotalParticles-1 do with Particles[i] do begin
      with VBuf^[i*3+0] do begin
        X := Transformed.X + (Position.X - Radius*0);
        Y := Transformed.Y + (Position.Y - Radius*0.5);
        Z := Transformed.Z;
        U := 0; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[i*3+1] do begin
        X := Transformed.X + (Position.X + Radius);
        Y := Transformed.Y + (Position.Y + Radius*0.5);
        Z := Transformed.Z;
        U := 1; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[i*3+2] do begin
        X := Transformed.X + (Position.X - Radius);
        Y := Transformed.Y + (Position.Y + Radius*0.5);
        Z := Transformed.Z;
        U := 0; V := 1;
        RHW := TRHW; DColor := Color;
      end;
    end;
    TotalVertices := TotalParticles*3; TotalPrimitives := TotalParticles*1;
  end else begin
    for i := 0 to TotalParticles-1 do with Particles[i] do begin
        with VBuf^[i*4+0] do begin
          X := Transformed.X + (Position.X - Radius*0.5);
          Y := Transformed.Y - Position.Y - Radius*0.5;
          Z := Transformed.Z;
          U := 0; V := 0;
          RHW := TRHW; DColor := Color;
        end;
        with VBuf^[i*4+1] do begin
          X := Transformed.X + (Position.X + Radius*0.5);
          Y := Transformed.Y - Position.Y - Radius*0.5;
          Z := Transformed.Z;
          U := 1; V := 0;
          RHW := TRHW; DColor := Color;
        end;
        with VBuf^[i*4+2] do begin
          X := Transformed.X + (Position.X + Radius*0.5);
          Y := Transformed.Y - Position.Y + Radius*0.5;
          Z := Transformed.Z;
          U := 1; V := 1;
          RHW := TRHW; DColor := Color;
        end;
        with VBuf^[i*4+3] do begin
          X := Transformed.X + (Position.X - Radius*0.5);
          Y := Transformed.Y - Position.Y + Radius*0.5;
          Z := Transformed.Z;
          U := 0; V := 1;
          RHW := TRHW; DColor := Color;
        end;
    end;
    TotalVertices := TotalParticles*4; TotalPrimitives := TotalParticles*2;
  end;
  IndexingVertices := TotalVertices;
  LastTotalVertices := TotalVertices;
  ParticlesVisible := TotalParticles;
  Result := TotalVertices;
//  VStatus := tsTesselated;
  VStatus := tsSizeChanged;
end;

function TParticlesMesh.SetIndices(IBPTR: Pointer): Integer;
var i, Ind: Integer; IBuf: ^TWordBuffer;
begin
  Result := 0;
  if not Quads then Exit;
  IBuf := IBPTR;
  for i := 0 to ParticlesVisible-1 do begin
    if ReverseOrder then Ind := ParticlesVisible-i-1 else Ind := i;   // SetIndices must be called after Tesselate!
    IBuf^[Ind*6+0] := i*4; IBuf^[Ind*6+1] := i*4+1; IBuf^[Ind*6+2] := i*4+2;
    IBuf^[Ind*6+3] := i*4; IBuf^[Ind*6+4] := i*4+2; IBuf^[Ind*6+5] := i*4+3;
  end;
  TotalIndices := ParticlesVisible*6;
  LastTotalIndices := TotalIndices;
  IStatus := tsTesselated;
  IStatus := tsSizeChanged;
  Result := TotalIndices;
end;

destructor TParticlesMesh.Free;
begin
  Capacity := 0; TotalParticles := 0;
  SetLength(Particles, 0);
end;

function TParticlesMesh.GetMaxVertices: Integer;
begin
  if Quads then Result := TotalParticles*4 else Result := TotalParticles*3;
end;

function TParticlesMesh.GetMaxIndices: Integer; 
begin
  if Quads then Result := TotalParticles*6 else Result := 0;
end;

{ T3DParticlesMesh }

function T3DParticlesMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPVertex = TTCDTVertex; TPVertexBuffer = array[0..$FFFFFF] of TPVertex;
var i: Integer; VBuf: ^TPVertexBuffer; Transformed: TVector4s; TRHW, Size: Single;
begin
  VBuf := VBPTR;

{  if (Abs(Location.X) < 100) and (Abs(Location.Z) < 100) then begin
    VBuf := nil;
    Exit;
  end;}

//  Matrix := MulMatrix4s(RenderPars.WorldMatrix, RenderPars.TotalMatrix);
  ParticlesVisible := 0;
  if not Quads then begin
    for i := 0 to TotalParticles-1 do with Particles[i] do begin
      Transformed := Transform4Vector3s(RenderPars.TotalMatrix, AddVector3s(Location, Position));
      if Transformed.W < 0 then Continue;
      with RenderPars do Transformed.Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));          // ToFix: Optimize it
      TRHW := 1/Transformed.W;                                                                    // ToFix: And this too
//      Transformed.X := RenderPars.ActualWidth shr 1
//      Transformed.Y := RenderPars.ActualHeight shr 1;
//      Transformed.X := 1 + Transformed.X; // * ZK;
//      Transformed.Y := 1 - Transformed.Y; //* ZK;

      with VBuf^[ParticlesVisible*3+2] do begin
        X := RenderPars.ActualWidth shr 1 + Transformed.X * (RenderPars.ActualWidth shr 1) * TRHW;
        Y := RenderPars.ActualHeight shr 1 - (Transformed.Y - Radius * 0.5) * (RenderPars.ActualHeight shr 1) * TRHW;
        Z := Transformed.Z;
        U := 0; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*3+1] do begin
        X := RenderPars.ActualWidth shr 1 + (Transformed.X + Radius) * (RenderPars.ActualWidth shr 1) * TRHW;
        Y := RenderPars.ActualHeight shr 1 - (Transformed.Y + Radius * 0.5) * (RenderPars.ActualHeight shr 1) * TRHW;
        Z := Transformed.Z;
        U := 1; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*3+0] do begin
        X := RenderPars.ActualWidth shr 1 + (Transformed.X - Radius) * (RenderPars.ActualWidth shr 1) * TRHW;
        Y := RenderPars.ActualHeight shr 1 - (Transformed.Y + Radius * 0.5) * (RenderPars.ActualHeight shr 1) * TRHW;
        Z := Transformed.Z;
        U := 0; V := 1;
        RHW := TRHW; DColor := Color;
      end;
      Inc(ParticlesVisible);
    end;
    TotalVertices := ParticlesVisible*3; TotalPrimitives := ParticlesVisible*1;
  end else begin
    for i := 0 to TotalParticles-1 do with Particles[i] do begin
      Transformed := Transform4Vector3s(RenderPars.TotalMatrix, AddVector3s(Location, Position));
      if Transformed.W < 0 then Continue;
      with RenderPars do Transformed.Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));          // ToFix: Optimize it
      TRHW := 1/Transformed.W;                                                                    // ToFix: And this too
      with VBuf^[ParticlesVisible*4+3] do begin
        X := RenderPars.ActualWidth shr 1 * (1 + (Transformed.X - Radius * 0.5) * TRHW);
        Y := RenderPars.ActualHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5) * TRHW);
        Z := Transformed.Z;
        U := 0; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*4+2] do begin
        X := RenderPars.ActualWidth shr 1 * (1 + (Transformed.X + Radius * 0.5) * TRHW);
        Y := RenderPars.ActualHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5) * TRHW);
        Z := Transformed.Z;
        U := 1; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*4+1] do begin
        X := RenderPars.ActualWidth shr 1 * (1 + (Transformed.X + Radius * 0.5) * TRHW);
        Y := RenderPars.ActualHeight shr 1 * (1 - (Transformed.Y + Radius * 0.5) * TRHW);
        Z := Transformed.Z;
        U := 1; V := 1;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*4+0] do begin
        X := RenderPars.ActualWidth shr 1 * (1 + (Transformed.X - Radius * 0.5) * TRHW);
        Y := RenderPars.ActualHeight shr 1 * (1 - (Transformed.Y + Radius * 0.5) * TRHW);
        Z := Transformed.Z;
        U := 0; V := 1;
        RHW := TRHW; DColor := Color;
      end;
      Inc(ParticlesVisible);
    end;
    TotalVertices := ParticlesVisible*4; TotalPrimitives := ParticlesVisible*2;
  end;
  Result := TotalVertices;
  IndexingVertices := TotalVertices;
  LastTotalVertices := TotalVertices;
//  VStatus := tsTesselated;
  VStatus := tsSizeChanged;
end;

{ T2DParticleSystem }

function T2DParticleSystem.Process: Boolean;
var i: Integer; LocationDiff: TVector3s;
begin
  Emit(0);                     // Emit ParticlesToEmit number of particles
  
  Result := inherited Process;
  if (DefaultRadius = 0) or (DefaultColor shr 24 = 0) then Exit;
  with TParticlesMesh(CurrentLOD) do begin
    if not LocalCoordinates then
     with ModelMatrix do TParticlesMesh(CurrentLOD).Location := GetVector3s(_41, _42, _43);
    for i := TotalParticles-1 downto 0 do with Particles[i] do begin
      if (Age >= Lifetime) or (Radius <= 0) or ((Color and $FF000000) = 0) then begin
        Kill(i)
      end else begin
        {if (Age < Lifetime-2) then }Position := AddVector3s(Position, AddVector3s(Velocity, GlobalVelocity));
        Inc(Age);
      end;
    end;
  end;

  CurrentLOD.Invalidate(True);
end;

{ T3DParticleSystem }

constructor T3DParticleSystem.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  OldLocation := GetVector3s(0, 0, 0);
  Relocated := False;
  Order := 1200;
  CullMode := cmNone;
  ParticlesToEmit := 0;
end;

procedure T3DParticleSystem.SetMesh;
begin
  ClearMeshes;
  AddLOD(T3DAngleParticlesMesh.Create(''));
  T3DParticlesMesh(CurrentLOD).Location := GetVector3s(0, 0, 0);
end;

function T3DParticleSystem.SetProperties(AProperties: TProperties): Integer;
var OldRotationSupport: Boolean;
begin
  OldRotationSupport := RotationSupport;
  Result := inherited SetProperties(AProperties);
  if OldRotationSupport <> RotationSupport then begin
    SetMesh;
    Result := inherited SetProperties(AProperties);
  end;
end;

function T3DParticleSystem.Emit(Count: Single): Integer;
var i: Integer; PMesh: T3DParticlesMesh;
begin
  Result := 0;
  if DisableEmit then Exit;
  ParticlesToEmit := ParticlesToEmit + Count;
  if UniformEmit then begin
    ParticlesToEmit := ParticlesToEmit + Sqrt(SqrMagnitude(SubVector3s(LastEmitLocation, GetAbsLocation3s)))/EmitSpace;
  end;
  Result := Trunc(ParticlesToEmit);
  ParticlesToEmit := ParticlesToEmit - Result;
  if Result > 0 then begin
    PMesh := T3DParticlesMesh(CurrentLOD);
    if PMesh.TotalParticles = 0 then with ModelMatrix do OldLocation := GetAbsLocation3s;

    Result := PMesh.AddParticles(Result);

    for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
      Position := GetVector3s((Random*2-1) * EmitRadius, (Random*2-1) * EmitRadius, (Random*2-1) * EmitRadius);
      Velocity := Position;
      if UniformEmit then AddVector3s(Position, Position, ScaleVector3s(SubVector3s(LastEmitLocation, GetAbsLocation3s), Random));
      Radius := DefaultRadius;
      Velocity := EmitterVelocity;
      Mass := 1;
      FadeK := 0;
      Color := DefaultColor;
      Age := 0;
      LifeTime := DefaultLifeTime;
    end;

    UpdateMesh;
  end;

  LastEmitLocation := GetAbsLocation3s;
end;

function T3DParticleSystem.Process: Boolean;
var i, NewCount: Integer; LocationDiff: TVector3s;
begin
  NewCount := Emit(0);

  Result := inherited Process;
  if (DefaultRadius = 0) or (DefaultColor shr 24 = 0) then Exit;
  with TParticlesMesh(CurrentLOD) do begin
    with ModelMatrix do TParticlesMesh(CurrentLOD).Location := GetAbsLocation3s;
    if not LocalCoordinates then begin
      if not EqualsVector3s(GetAbsLocation3s, OldLocation) then begin
        LocationDiff := SubVector3s(GetAbsLocation3s, OldLocation);
        Relocated := True;
        for i := TotalParticles-NewCount-1 downto 0 do with Particles[i] do begin
          Position := SubVector3s(Position, LocationDiff);
        end;
        OldLocation := GetAbsLocation3s;
      end else Relocated := False;
    end;

    for i := TotalParticles-NewCount-1 downto 0 do with Particles[i] do begin
      if (Age >= Lifetime) or (Radius <= 0) or ((Color and $FF000000) = 0) then begin
        Kill(i)
      end else begin
        {if (Age < Lifetime-2) then }Position := AddVector3s(Position, AddVector3s(Velocity, GlobalVelocity));
        AddVector3s(Velocity, Velocity, OuterForce);
//        ScaleVector3s(Velocity, Velocity, 0.95);
        Inc(Age);
      end;
    end;
  end;

  CurrentLOD.Invalidate(True);
end;

procedure T3DParticleSystem.SetupExternalVariables;
begin
  inherited;

end;

{ TPSFadingIn }

constructor TPSFadingIn.Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
begin
  inherited;
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, False, False);
  SetMesh;
end;

function TPSFadingIn.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Fade in length', ptInt32, Pointer(FadeInPeriod));
  NewProperty(Result, 'Grow in length', ptInt32, Pointer(GrowInPeriod));
  NewProperty(Result, 'Elevation speed', ptSingle, Pointer(ElevationSpeed));
  NewProperty(Result, 'Density', ptSingle, Pointer(Density));
  NewProperty(Result, 'Radius jitter', ptSingle, Pointer(RadiusJitter));
  NewProperty(Result, 'Grow speed', ptSingle, Pointer(GrowSpeed));
  NewProperty(Result, 'Expansion speed', ptSingle, Pointer(ExpansionSpeed));
  NewProperty(Result, 'Velocity jitter', ptSingle, Pointer(VelocityJitter));
  NewProperty(Result, 'Slowdown', ptSingle, Pointer(Slowdown));
end;

function TPSFadingIn.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  FadeInPeriod := Integer(GetPropertyValue(AProperties, 'Fade in length'));
  GrowInPeriod := Integer(GetPropertyValue(AProperties, 'Grow in length'));
  ElevationSpeed := Single(GetPropertyValue(AProperties, 'Elevation speed'));
  Density := Single(GetPropertyValue(AProperties, 'Density'));
  RadiusJitter := Single(GetPropertyValue(AProperties, 'Radius jitter'));
  GrowSpeed := Single(GetPropertyValue(AProperties, 'Grow speed'));
  ExpansionSpeed := Single(GetPropertyValue(AProperties, 'Expansion speed'));
  VelocityJitter := Single(GetPropertyValue(AProperties, 'Velocity jitter'));
  SlowDown := Single(GetPropertyValue(AProperties, 'Slowdown'));

  case FadeInPeriod of
    0, 1: FadeInShift := 0;
    2: FadeInShift := 1;
    4: FadeInShift := 2;
    8: FadeInShift := 3;
    16: FadeInShift := 4;
    32: FadeInShift := 5;
    64: FadeInShift := 6;
    128: FadeInShift := 7;
    256: FadeInShift := 8;
    else begin
      FadeInPeriod:= 8;
      FadeInShift := 3;
    end;
  end;

  Result := 0;
end;

function TPSFadingIn.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentLOD);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Velocity := AddVector3s(Velocity, GetVector3s((Random*2-1)*ExpansionSpeed, (Random*2-1)*ExpansionSpeed + Random*GlobalVelocity.Y, (Random*2-1)*ExpansionSpeed));
    FadeK := DefaultRadius * (1 + Random*RadiusJitter);
    if GrowInPeriod = 0 then Radius := DefaultRadius * (1 + Random*RadiusJitter) else begin
      Radius := 1;
    end;
    Color := $01000000;
    Sprite := 0;
    Angle := 0;
    LifeTime := DefaultLifeTime;
  end;
  UpdateMesh;
end;

function TPSFadingIn.Process: Boolean;
var i: Integer; a: Longword;
begin
  with TParticlesMesh(CurrentLOD) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
//    ScaleVector3s(Particles[i].Velocity, Particles[i].Velocity, Slowdown);

    Particles[i].Velocity.X := Particles[i].Velocity.X * Slowdown + (Random*2-1) * VelocityJitter;
    Particles[i].Velocity.Y := Particles[i].Velocity.Y * Slowdown + (Random*2-1) * VelocityJitter;
    Particles[i].Velocity.Z := Particles[i].Velocity.Z * Slowdown + (Random*2-1) * VelocityJitter;

    Particles[i].Angle := Particles[i].Angle + Particles[i].Sprite;

    IF Particles[i].Age < GrowInPeriod THEN
     Particles[i].Radius := 1+Particles[i].FadeK * Particles[i].Age / GrowInPeriod;
      Particles[i].Radius := Particles[i].Radius + Particles[i].FadeK * GrowSpeed;

    IF Particles[i].Age <= FadeInPeriod THEN
     a := 1+(Particles[i].Age*(DefaultColor shr 24)) shr FadeInShift ELSE
      a := DefaultColor shr 24;

    Particles[i].Color := DefaultColor and $FFFFFF + a shl 24;
  end;

  ParticlesToEmit := ParticlesToEmit + Density;

  Result := inherited Process;
end;

// TPSFountain

constructor TPSFountain.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmOne, tfLessEqual, tfAlways, 0, True, True);
  SetMesh;
  DefaultRadius := 50;
  InitYSpeed := 20; MaxHSpeed := 10; Density := 250;
  GlobalForce := GetVector3s(0, -10, 0);
end;

function TPSFountain.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Initial vertical speed', ptInt32, Pointer(InitYSpeed));
  NewProperty(Result, 'Max horizontal speed', ptNat32, Pointer(MaxHSpeed));
  NewProperty(Result, 'Dencity', ptNat32, Pointer(Density));
  NewProperty(Result, 'Gravity', ptSingle, Pointer(GlobalForce.Y));
  NewProperty(Result, 'Size jitter, %', ptNat32, Pointer(SizeJitter));
end;

function TPSFountain.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  InitYSpeed := Integer(GetPropertyValue(AProperties, 'Initial vertical speed'));
  MaxHSpeed := Longword(GetPropertyValue(AProperties, 'Max horizontal speed'));
  Density := Longword(GetPropertyValue(AProperties, 'Dencity'));
  GlobalForce.Y := Single(GetPropertyValue(AProperties, 'Gravity'));
  SizeJitter := Longword(GetPropertyValue(AProperties, 'Size jitter, %'));

  Result := Result + 5;
end;

function TPSFountain.Emit(Count: Single): Integer;
var i: Integer; PMesh: T3DParticlesMesh; Phi, Theta: Single;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentLOD);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Radius := DefaultRadius+(1-Random)*DefaultRadius*SizeJitter/100;
    Phi := Random*Pi*2; Theta := Random*Pi;
    Velocity := GetVector3s(100*Cos(Phi)*Sin(Theta)*MaxHSpeed/Radius, 100*Sin(Theta)*InitYSpeed/Radius, 100*Sin(Phi)*Sin(Theta)*MaxHSpeed/Radius);
    Position := Velocity;
  end;
  UpdateMesh;
end;

function TPSFountain.Process: Boolean;
var i, TotalKilled: Integer;
begin
  Result := inherited Process;
//  with ModelMatrix do TParticlesMesh(CurrentLOD).Location := GetVector3s(_41, _42, _43);
  TotalKilled := 0;
  with TParticlesMesh(CurrentLOD) do for i := TotalParticles-1 downto 0 do begin
    Particles[i].Position := AddVector3s(Particles[i].Position, Particles[i].Velocity);
    Particles[i].Velocity := AddVector3s(Particles[i].Velocity, GlobalForce);
    if (Particles[i].Position.Y <= 0) and (Particles[i].Velocity.Y < 0) then begin
      Kill(i); Inc(TotalKilled);
    end;
  end;
  ParticlesToEmit := ParticlesToEmit + Density-TParticlesMesh(CurrentLOD).TotalParticles;
//  T3DParticlesMesh(CurrentLOD).Location := GetVector3s(0, 0, 0);
end;

procedure T3DParticleSystem.Init;
begin
  inherited;
  OldLocation := GetAbsLocation3s;
end;

{ TPSBalls }

function TPSBalls.Emit(Count: Single): Integer;
var i: Integer; Col: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := TParticlesMesh(Meshes[0]);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Position := GetVector3s(Random(300)-150, Random(40)-20, 0);
    Velocity := GetVector3s(Random*20-10, Random*6-3, 0);
    Radius := 5+Random(6)*5;
    Col := Random(512);
    Color := $80FF0000 + MinI(255, Col)*$100 + Col shr 1;
  end;
  UpdateMesh;
end;

function TPSBalls.Process: Boolean;
var i: Integer;
begin
  Result := False;
  with TParticlesMesh(Meshes[0]) do for i := TotalParticles-1 downto 0 do begin
    Particles[i].Position := AddVector3s(Particles[i].Position, Particles[i].Velocity);
    if (Particles[i].Position.X < -150) and (Particles[i].Velocity.X < 0) or
       (Particles[i].Position.X > 150) and (Particles[i].Velocity.X > 0) then Particles[i].Velocity.X := -Particles[i].Velocity.X;
    if (Particles[i].Position.Y < -20) and (Particles[i].Velocity.Y < 0) or
       (Particles[i].Position.Y > 20) and (Particles[i].Velocity.Y > 0) then Particles[i].Velocity.Y := -Particles[i].Velocity.Y;
  end;
end;

{ TPSSmoke }

constructor TPSSmoke.Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
begin
  inherited;
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, False, False);
  SetMesh;
end;

function TPSSmoke.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'End color', ptColor32, Pointer(EndColor));
  NewProperty(Result, 'Colored length', ptInt32, Pointer(ColoredLength));
  NewProperty(Result, 'Rotation speed', ptInt32, Pointer(RotationSpeed));
  NewProperty(Result, 'Start age jitter', ptInt32, Pointer(StartAgeJitter));
end;

function TPSSmoke.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  EndColor := Longword(GetPropertyValue(AProperties, 'End color'));
  ColoredLength := Integer(GetPropertyValue(AProperties, 'Colored length'));
  RotationSpeed := Integer(GetPropertyValue(AProperties, 'Rotation speed'));
  StartAgeJitter := Integer(GetPropertyValue(AProperties, 'Start age jitter'));

  Result := 0;
end;

function TPSSmoke.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentLOD);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    if RotationSpeed >= 0 then Sprite := (Random(RotationSpeed+1)) else Sprite := Trunc(0.5 + (Random*2-1)*RotationSpeed);
    Angle := Random(MaxAngle);
    LifeTime := MaxI(0, DefaultLifeTime - Random(StartAgeJitter));
  end;
  UpdateMesh;
end;

function TPSSmoke.Process: Boolean;
var i: Integer; a: Longword; c: Single;
begin
  Result := inherited Process;

  with TParticlesMesh(CurrentLOD) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
    Particles[i].Angle := Particles[i].Angle + Particles[i].Sprite;

    IF Particles[i].Age <= FadeInPeriod THEN
     a := 1+(Particles[i].Age*(DefaultColor shr 24)) shr FadeInShift ELSE
      a := DefaultColor shr 24;

    if (Particles[i].Age) < (ColoredLength) then begin
      c := (Particles[i].Age)/(ColoredLength);
      Particles[i].Color := BlendColor(DefaultColor and $FFFFFF + a shl 24, EndColor, c);
    end else begin
      c := (Particles[i].Age - ColoredLength)/(Particles[i].Lifetime - ColoredLength);
      Particles[i].Color := BlendColor(EndColor, EndColor and $FFFFFF, c);
    end;
  end;  
end;

{ TPSComet }

constructor TPSComet.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, False, False);
  SetMesh;
  DefaultRadius := 500; Density := 6; FadeSpeed := 0.001;
  CoreRadius := 500; RadiusJitter := 0.5; GrowthSpeed := -0.001;
end;

function TPSComet.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Core radius', ptSingle, Pointer(CoreRadius));
  NewProperty(Result, 'Radius jitter', ptSingle, Pointer(RadiusJitter));
  NewProperty(Result, 'Density', ptInt32, Pointer(Density));
  NewProperty(Result, 'Growth speed', ptSingle, Pointer(GrowthSpeed));
  NewProperty(Result, 'Fade speed', ptSingle, Pointer(FadeSpeed));
  NewProperty(Result, 'Elevation speed', ptSingle, Pointer(ElevationSpeed));
end;

function TPSComet.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  CoreRadius := Single(GetPropertyValue(AProperties, 'Core radius'));
  RadiusJitter := Single(GetPropertyValue(AProperties, 'Radius jitter'));
  Density := Integer(GetPropertyValue(AProperties, 'Density'));
  GrowthSpeed := Single(GetPropertyValue(AProperties, 'Growth speed'));
  FadeSpeed := Single(GetPropertyValue(AProperties, 'Fade speed'));
  ElevationSpeed := Single(GetPropertyValue(AProperties, 'Elevation speed'));
  Result := 0;
end;

function TPSComet.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentLOD);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
//    Position := AddVector3s(Position, GetVector3s((Random*2-1)*CoreRadius, (Random*2-1)*CoreRadius, (Random*2-1)*CoreRadius));
    Velocity := GetVector3s((Random*2-1)*CoreRadius*0.2, (Random*2-1)*CoreRadius*0.2 + ElevationSpeed, (Random*2-1)*CoreRadius*0.2);
    Radius := DefaultRadius * (1 + Random * RadiusJitter);
//    Color := Self.DefaultColor and $FFFFFF;
    FadeK := 1;
  end;
  UpdateMesh;
end;

function TPSComet.Process: Boolean;
var i: Integer; 
begin
  with TParticlesMesh(Meshes[0]) do for i := TotalParticles-1 downto 0 do begin
    if Particles[i].Radius > 1 then Particles[i].Radius := Particles[i].Radius * (1+GrowthSpeed) else Kill(i);
    if Particles[i].FadeK > FadeSpeed then begin
      Particles[i].FadeK := Particles[i].FadeK - FadeSpeed;
      Particles[i].Color := Trunc((DefaultColor shr 24)*Particles[i].FadeK) shl 24 or (Particles[i].Color and $FFFFFF);
    end else Kill(i);
  end;
  ParticlesToEmit := ParticlesToEmit + Density / DefaultRadius;

  Result := inherited Process;
end;

{ TPSFire }

function TPSFire.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Elevation jitter', ptSingle, Pointer(ElevationJitter));
  NewProperty(Result, 'Shrink speed', ptSingle, Pointer(ShrinkSpeed));
  NewProperty(Result, 'Shrink start', ptInt32, Pointer(ShrinkStart));
end;

function TPSFire.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  ElevationJitter := Single(GetPropertyValue(AProperties, 'Elevation jitter'));
  ShrinkSpeed := Single(GetPropertyValue(AProperties, 'Shrink speed'));
  ShrinkStart := Integer(GetPropertyValue(AProperties, 'Shrink start'));
  Result := 0;
end;

function TPSFire.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentLOD);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Velocity := GetVector3s(Velocity.X, ElevationSpeed+Random*ElevationJitter, Velocity.Z);
  end;

  UpdateMesh;
end;

function TPSFire.Process: Boolean;
var i: Integer; c: Single;
begin
  with TParticlesMesh(CurrentLOD) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
    Particles[i].Velocity.x := Particles[i].Velocity.x + (Random*2.0-1)*1.0;
    Particles[i].Velocity.z := Particles[i].Velocity.z + (Random*2.0-1)*1.0;

    if Particles[i].Age >= ShrinkStart then begin
      c := (Particles[i].Age - ShrinkStart)/(Particles[i].LifeTime - ShrinkStart);
      Particles[i].Radius := Particles[i].FadeK * (1-c);
    end;  
  end;

  Result := inherited Process;
end;

{ T3DAngleParticlesMesh }

function T3DAngleParticlesMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPVertex = TTCDTVertex; TPVertexBuffer = array[0..$FFFFFF] of TPVertex;
var i: Integer; VBuf: ^TPVertexBuffer; Transformed: TVector4s; TRHW: Single;
begin
  VBuf := VBPTR;

//  Matrix := MulMatrix4s(RenderPars.WorldMatrix, RenderPars.TotalMatrix);
  ParticlesVisible := 0;
  if not Quads then begin
    for i := 0 to TotalParticles-1 do with Particles[i] do begin
      Transform4Vector3s(Transformed, RenderPars.TotalMatrix, AddVector3s(Location, Position));
      if Transformed.W < 0 then Continue;
      with RenderPars do Transformed.Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));          // ToFix: Optimize it
      TRHW := 1/Transformed.W;                                                                    // ToFix: And this too
//      Transformed.X := RenderPars.ActualWidth shr 1
//      Transformed.Y := RenderPars.ActualHeight shr 1;
//      Transformed.X := 1 + Transformed.X; // * ZK;
//      Transformed.Y := 1 - Transformed.Y; //* ZK;

      with VBuf^[ParticlesVisible*3+2] do begin
        X := RenderPars.ActualWidth shr 1 + Transformed.X * (RenderPars.ActualWidth shr 1) * TRHW;
        Y := RenderPars.ActualHeight shr 1 - (Transformed.Y - Radius * 0.5) * (RenderPars.ActualHeight shr 1) * TRHW;
        Z := Transformed.Z;
        U := 0; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*3+1] do begin
        X := RenderPars.ActualWidth shr 1 + (Transformed.X + Radius) * (RenderPars.ActualWidth shr 1) * TRHW;
        Y := RenderPars.ActualHeight shr 1 - (Transformed.Y + Radius * 0.5) * (RenderPars.ActualHeight shr 1) * TRHW;
        Z := Transformed.Z;
        U := 1; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*3+0] do begin
        X := RenderPars.ActualWidth shr 1 + (Transformed.X - Radius) * (RenderPars.ActualWidth shr 1) * TRHW;
        Y := RenderPars.ActualHeight shr 1 - (Transformed.Y + Radius * 0.5) * (RenderPars.ActualHeight shr 1) * TRHW;
        Z := Transformed.Z;
        U := 0; V := 1;
        RHW := TRHW; DColor := Color;
      end;
      Inc(ParticlesVisible);
    end;
    TotalVertices := ParticlesVisible*3; TotalPrimitives := ParticlesVisible*1;
  end else begin
    for i := 0 to TotalParticles-1 do with Particles[i] do begin
      Transformed := Transform4Vector3s(RenderPars.TotalMatrix, AddVector3s(Location, Position));
      if Transformed.W < 0 then Continue;
      with RenderPars do Transformed.Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));          // ToFix: Optimize it
      TRHW := 1/Transformed.W;                                                                    // ToFix: And this too
      with VBuf^[ParticlesVisible*4+3] do begin
        X := RenderPars.ActualWidth shr 1 * (1 + (Transformed.X + Radius * 0.5 * Cos((Angle+45)/180*pi)) * TRHW);
        Y := RenderPars.ActualHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5 * Sin((Angle+45)/180*pi)) * TRHW);
        Z := Transformed.Z;
        U := 0; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*4+2] do begin
        X := RenderPars.ActualWidth shr 1 * (1 + (Transformed.X + Radius * 0.5 * Cos((Angle+135)/180*pi)) * TRHW);
        Y := RenderPars.ActualHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5 * Sin((Angle+135)/180*pi)) * TRHW);
        Z := Transformed.Z;
        U := 1; V := 0;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*4+1] do begin
        X := RenderPars.ActualWidth shr 1 * (1 + (Transformed.X + Radius * 0.5 * Cos((Angle+225)/180*pi)) * TRHW);
        Y := RenderPars.ActualHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5 * Sin((Angle+225)/180*pi)) * TRHW);
        Z := Transformed.Z;
        U := 1; V := 1;
        RHW := TRHW; DColor := Color;
      end;
      with VBuf^[ParticlesVisible*4+0] do begin
        X := RenderPars.ActualWidth shr 1 * (1 + (Transformed.X + Radius * 0.5 * Cos((Angle+315)/180*pi)) * TRHW);
        Y := RenderPars.ActualHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5 * Sin((Angle+315)/180*pi)) * TRHW);
        Z := Transformed.Z;
        U := 0; V := 1;
        RHW := TRHW; DColor := Color;
      end;
      Inc(ParticlesVisible);
    end;
    TotalVertices := ParticlesVisible*4; TotalPrimitives := ParticlesVisible*2;
  end;
  Result := TotalVertices;
  IndexingVertices := TotalVertices;
  LastTotalVertices := TotalVertices;
  VStatus := tsTesselated;
  VStatus := tsSizeChanged;
end;

{ TPSExplosion }

function TPSExplosion.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Cicle completeness', ptSingle, Pointer(CicleCompleteness));
end;

function TPSExplosion.SetProperties(AProperties: TProperties): Integer;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;
  CicleCompleteness := Single(GetPropertyValue(AProperties, 'Cicle completeness'));
end;

function TPSExplosion.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentLOD);
//  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
//  end;

  UpdateMesh;
end;

function TPSExplosion.Process: Boolean;
var i: Integer; c: Single;
begin
  with TParticlesMesh(CurrentLOD) do for i := 0 to TotalParticles-1 do with Particles[i] do begin
    c := SIN((Particles[i].Age+1)/Particles[i].LifeTime*pi*CicleCompleteness);
    Particles[i].Radius := c*DefaultRadius;
  end;

  Result := inherited Process;
end;

{ TPSExpSmoke }

function TPSExpSmoke.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Spread angle', ptInt32, Pointer(SpreadAngle));
  NewProperty(Result, 'Rotation slowdown', ptSingle, Pointer(RotationSlowdown));
end;

function TPSExpSmoke.SetProperties(AProperties: TProperties): Integer;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;
  SpreadAngle := Integer(GetPropertyValue(AProperties, 'Spread angle'));
  RotationSlowdown := Single(GetPropertyValue(AProperties, 'Rotation slowdown'));
end;

function TPSExpSmoke.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh; phi, theta: Single;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentLOD);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    phi := Random*pi*2;
    theta := pi/2 - Random*SpreadAngle/360*pi;
    IF SpreadAngle > 180 THEN theta := pi/2 - theta; 

    Velocity.x := COS(phi) * SIN(theta);
    Velocity.z := SIN(phi) * SIN(theta);
    Velocity.y := COS(theta);

{    Position.x := Velocity.x * EmitRadius;
    Position.y := Velocity.y * EmitRadius;
    Position.z := Velocity.z * EmitRadius;}

    Velocity.x := Velocity.x * ExpansionSpeed;
    Velocity.y := Velocity.y * ExpansionSpeed;
    Velocity.z := Velocity.z * ExpansionSpeed;

    Color := DefaultColor and $00FFFFFF or $01000000;

    Sprite := 0;
    Mass := (Random(2)*2-1) * RotationSpeed * (1 + Random);
  end;

  UpdateMesh;
end;

function TPSExpSmoke.Process: Boolean;
var i: Integer;
begin
  with TParticlesMesh(CurrentLOD) do for i := 0 to TotalParticles-1 do with Particles[i] do begin
    Particles[i].Angle := Particles[i].Angle + Trunc(0.5 + Particles[i].Mass);
    Particles[i].Mass := Particles[i].Mass * RotationSlowdown;
  end;

  Result := inherited Process;
end;

{ T2DFireworks }

function T2DFireworks.GetProperties: TProperties;
var Ang: Integer;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Half period', ptInt32, Pointer(HalfPeriod));
  Ang := Trunc(LaunchAngle/pi*180);
  NewProperty(Result, 'Launch angle', ptInt32, Pointer(Ang));
  NewProperty(Result, 'Slowdown', ptSingle, Pointer(Slowdown));
  NewProperty(Result, 'Fall speed', ptSingle, Pointer(FallSpeed));
  NewProperty(Result, 'Grow speed', ptSingle, Pointer(GrowSpeed));
  NewProperty(Result, 'Fade speed', ptSingle, Pointer(FadeSpeed));
  NewProperty(Result, 'Explosion size', ptSingle, Pointer(ExplosionSize));
  NewProperty(Result, 'Explosion density', ptInt32, Pointer(ExplosionDensity));
  NewProperty(Result, 'Radius jitter', ptSingle, Pointer(RadiusJitter));
  NewProperty(Result, 'Speed', ptSingle, Pointer(Speed));
end;

function T2DFireworks.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  HalfPeriod := Integer(GetPropertyValue(AProperties, 'Half period'));
  LaunchAngle := Integer(GetPropertyValue(AProperties, 'Launch angle'))/180*pi;
  Slowdown := Single(GetPropertyValue(AProperties, 'Slowdown'));
  FallSpeed := Single(GetPropertyValue(AProperties, 'Fall speed'));
  GrowSpeed := Single(GetPropertyValue(AProperties, 'Grow speed'));
  FadeSpeed := Single(GetPropertyValue(AProperties, 'Fade speed'));
  ExplosionSize := Single(GetPropertyValue(AProperties, 'Explosion size'));
  ExplosionDensity := Integer(GetPropertyValue(AProperties, 'Explosion density'));
  RadiusJitter := Single(GetPropertyValue(AProperties, 'Radius jitter'));
  Speed := Single(GetPropertyValue(AProperties, 'Speed'));
  Result := 0;
end;

function T2DFireworks.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh; rad, theta: Single;
begin
  Result := inherited Emit(Count);

  PMesh := TParticlesMesh(CurrentLOD);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Position.x := GetAbsLocation.x + TicksProcessed*Speed*COS(LaunchAngle)*0.5;
    Position.y := GetAbsLocation.y - TicksProcessed*Speed*SIN(LaunchAngle)*0.5 - (TicksProcessed*TicksProcessed - TicksProcessed*20) * FallSpeed;

    IF TicksProcessed < HalfPeriod THEN Sprite := 0 ELSE begin    // If Sprite = 0 particle belongs to tale or to explosion otherwise
      rad := Random * ExplosionSize;
      Radius := DefaultRadius + Random * RadiusJitter;
      theta := Random * pi*2;
      Sprite := 1;
      Velocity.x := COS(theta) * rad;
      Velocity.y := SIN(theta) * rad;
    END;

    Mass := 1.0;

    Color := DefaultColor and $00FFFFFF or $01000000;
  end;

  UpdateMesh;
end;

function T2DFireworks.Process: Boolean;
var i: Integer; a: Cardinal;
begin
  with TParticlesMesh(CurrentLOD) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
    IF Particles[i].Sprite = 0 THEN
     Particles[i].Radius := Particles[i].Radius * GrowSpeed else begin
       ScaleVector3s(Particles[i].Velocity, Particles[i].Velocity, Slowdown);
       Particles[i].Velocity.Y := Particles[i].Velocity.Y - FallSpeed*4;
     END;
    
    Particles[i].Mass := Particles[i].Mass*FadeSpeed;

    a := Trunc(0.5 + Particles[i].Mass * (DefaultColor shr 24));

    IF a < 2 THEN a := 0;

    Particles[i].Color := (DefaultColor AND $0FFFFFF) OR (a shl 24);
  end;

  IF TicksProcessed < HalfPeriod THEN ParticlesToEmit := 1 else
   if TicksProcessed = HalfPeriod THEN ParticlesToEmit := ExplosionDensity else
    ParticlesToEmit := 0;

  Result := inherited Process;
end;

procedure T2DFireworks.Start;
begin
  TicksProcessed := 0;
end;

{ TPSAdvSmoke }

function TPSAdvSmoke.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Shrink length', ptInt32, Pointer(ShrinkPeriod));
  NewProperty(Result, 'Shrink K', ptSingle, Pointer(ShrinkAmount));
  NewProperty(Result, 'Rotation slowdown', ptSingle, Pointer(RotationSlowdown));
end;

function TPSAdvSmoke.SetProperties(AProperties: TProperties): Integer;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;
  ShrinkPeriod := Integer(GetPropertyValue(AProperties, 'Shrink length'));
  ShrinkAmount := Single(GetPropertyValue(AProperties, 'Shrink K'));
  RotationSlowdown := Single(GetPropertyValue(AProperties, 'Rotation slowdown'));
end;

function TPSAdvSmoke.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentLOD);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
//    Velocity.y := 0;
    Mass := RotationSpeed * (1 + Random);
    Sprite := 0;
  end;

  UpdateMesh;
end;

function TPSAdvSmoke.Process: Boolean;
var i: Integer; c: Single;
begin
  with TParticlesMesh(CurrentLOD) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
    Particles[i].Angle := Particles[i].Angle + Trunc(0.5 + Particles[i].Mass);
    Particles[i].Mass := Particles[i].Mass * RotationSlowdown;

    if (Particles[i].Age < GrowInPeriod + ShrinkPeriod) then begin
      if (Particles[i].Age >= GrowInPeriod) then begin
        c := (Particles[i].Age - GrowInPeriod + 1) / ShrinkPeriod;
        Particles[i].Radius := Particles[i].FadeK * (1-c) + Particles[i].FadeK * ShrinkAmount * c;
      end;
    end else Particles[i].Velocity.y := Particles[i].Velocity.y + ElevationSpeed * (1 + 0.3*Random);
  end;

  Result := inherited Process;
end;

end.
