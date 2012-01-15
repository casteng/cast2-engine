{$Include C2Defines}
unit C2ParticleOld;

interface

uses SysUtils, C2Types, Basics, Props, Base3D, BaseClasses, CAST2, C2Tess, C2Visual;

const
  MaxAngle = 360;
// Allocation  
  ParticlesAllocStep = 32;
  ParticleAllocMask: LongWord = not LongWord(ParticlesAllocStep-1);

type
  TPSRenderRecord = record
    Position: TVector3s;
    Radius: Single;
    Color: Longword;
    Angle, Sprite: Integer;
    Temp: Single;
  end;

  TPSSimulationRecord = record
    Velocity: TVector3s;
    Mass, FadeK: Single;
    Age, LifeTime: Longword;
  end;

  TPSRenderData     = array of TPSRenderRecord;
  TPSSimulationData = array of TPSSimulationRecord;

  TParticle = packed record
// Data needed for render
    Position, Velocity: TVector3s;
    Radius, Mass, FadeK: Single;
    Color, Age, LifeTime: Longword;
    Angle, Sprite: Integer;
// Other necessary data
// User data
  end;

  TParticleSystem = class(TVisible)
    LocalCoordinates, UniformEmit, RotationSupport, FastKill, DisableEmit: Boolean;
    DefaultRadius, EmitSpace: Single;
    DefaultColor, DefaultLifetime: Longword;
    EmitRadius: Single;
    OuterForce, GlobalVelocity, EmitterVelocity, LastEmitLocation: TVector3s;
    ParticlesToEmit: Single;
    constructor Create(AManager: TItemsManager); override;
    function GetTesselatorClass: CTesselator; override;
    procedure Init; virtual;

    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    procedure SetupExternalVariables; virtual;

    function GetParticleCount: Integer; virtual;
    procedure UpdateMesh; virtual;    //?????????????

    function Emit(Count: Single): Integer; virtual;
    procedure Kill(Index: Integer); virtual;
    procedure KillAll; virtual;
  end;

  TParticlesMesh = class(TTesselator)
    ReverseOrder: Boolean;
    Particles: TParticles;
    TotalParticles: Integer;
    MaxCapacity, Capacity: Cardinal;
    Matrix: TMatrix4s;
    constructor Create; override;
    function AddParticles(Count: Integer): Integer; virtual;
    procedure SetCapacity(const ACapacity: Integer); virtual;
    function GetMaxVertices: Integer; override;
    function GetMaxIndices: Integer; override;
    function Tesselate(Camera: TCamera; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    destructor Free; override;
  private
    ParticlesVisible: Integer;
  end;

  T3DParticlesMesh = class(TParticlesMesh)
    function Tesselate(Camera: TCamera; VBPTR: Pointer): Integer; override;
  end;

  __T3DParticlesMesh = class(TParticlesMesh)
    function Tesselate(Camera: TCamera; VBPTR: Pointer): Integer; override;
  end;

  T3DAngleParticlesMesh = class(T3DParticlesMesh)
    function Tesselate(Camera: TCamera; VBPTR: Pointer): Integer; override;
  end;

  T2DParticleSystem = class(TParticleSystem)
    procedure Process; override;
  end;

  T3DParticleSystem = class(TParticleSystem)
    OldLocation: TVector3s;
    Relocated: Boolean;
    constructor Create(AManager: TItemsManager); override;
    function GetTesselatorClass: CTesselator; override;
    procedure Init; override;
    procedure SetProperties(Properties: TProperties); override;

    procedure SetupExternalVariables; override;
    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  protected
    MaxSize: Single;
  end;

  TPSFadingIn = class(T3DParticleSystem)
    ElevationSpeed, VelocityJitter, GrowSpeed, RadiusJitter, ExpansionSpeed, SlowDown, Density: Single;
    GrowInPeriod, FadeInPeriod, FadeInShift: Cardinal;
    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  TPSFountain = class(T3DParticleSystem)
    GlobalForce: TVector3s;
    InitYSpeed: Integer;
    MaxHSpeed, Density, SizeJitter: Longword;
    constructor Create(AManager: TItemsManager); override;

    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  TPSBalls = class(TParticleSystem)
//    procedure SetMesh(const AVerticesRes, AIndicesRes: Integer); override;
    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  TPSSmoke = class(TPSFadingIn)
    RotationSpeed: Integer;
    ColoredLength, StartAgeJitter: Cardinal;
    EndColor: Longword;
    constructor Create(AManager: TItemsManager); override;

    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  TPSComet = class(T3DParticleSystem)
    Density: Integer;
    CoreRadius, RadiusJitter, GrowthSpeed, FadeSpeed, ElevationSpeed: Single;
    constructor Create(AManager: TItemsManager); override;

    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  TPSFire = class(TPSFadingIn)
    ElevationJitter, ShrinkSpeed: Single;
    ShrinkStart: Cardinal;
    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  TPSExplosion = class(TPSSmoke)
    CicleCompleteness: Single;
    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  TPSExpSmoke = class(TPSSmoke)
    SpreadAngle: Integer;
    RotationSlowdown: Single;
    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  TPSAdvSmoke = class(TPSSmoke)
    ShrinkPeriod: Cardinal;
    ShrinkAmount, RotationSlowdown: Single;
    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
  end;

  T2DFireworks = class(T2DParticleSystem)
    Slowdown, LaunchAngle, FallSpeed, ExplosionSize, FadeSpeed, GrowSpeed, RadiusJitter, Speed: Single;
    HalfPeriod, ExplosionDensity: Cardinal;
    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    function Emit(Count: Single): Integer; override;
    procedure Process; override;
    procedure Start; virtual;
  end;

implementation

{ TParticleSystem }

constructor TParticleSystem.Create(AManager: TItemsManager);
begin
  inherited;
  DefaultColor := $FF808080;
  DefaultRadius := 100;
  FastKill := True;
  OuterForce := GetVector3s(0, 0, 0);
end;

function TParticleSystem.GetTesselatorClass: CTesselator; begin Result := TParticlesMesh end;

procedure TParticleSystem.Init;
var i: Integer;
begin
  inherited;
  if Parent is TParticleSystem then OuterForce := (Parent as TParticleSystem).OuterForce;
  LastEmitLocation := GetAbsLocation;
  for i := 0 to TotalChilds-1 do if Childs[i] is TParticleSystem then (Childs[i] as TParticleSystem).Init;
  DisableEmit := False;
end;

procedure TParticleSystem.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Particles\Default\Color',     vtColor,   [], '#' +     IntToHex(DefaultColor, 8),   '');
  Result.Add('Particles\Default\Size',      vtSingle,  [],           FloatToStr(DefaultRadius),    '');
  Result.Add('Particles\Default\Lifetime',  vtNat,     [],           IntToStr(DefaultLifetime),   '');
  Result.Add('Particles\Current',           vtNat,     [poReadonly], IntToStr(TParticlesMesh(CurrentTesselator).TotalParticles), '');
  Result.Add('Particles\Max',               vtNat,     [],           IntToStr(TParticlesMesh(CurrentTesselator).MaxCapacity), '');
  Result.Add('Particles\Instant emit',      vtNat,     [],           '1', '');
  Result.Add('Emitter\Radius',              vtSingle,  [],           FloatToStr(EmitRadius),       '');
  Result.Add('Emitter\Uniform',             vtBoolean, [],           OnOffStr[UniformEmit],       '');
  Result.Add('Emitter\Uniform interval',    vtSingle,  [],           FloatToStr(EmitSpace),        '');
  Result.Add('Fixed velocity\X',            vtSingle,  [],           FloatToStr(GlobalVelocity.X), '');
  Result.Add('Fixed velocity\Y',            vtSingle,  [],           FloatToStr(GlobalVelocity.Y), '');
  Result.Add('Fixed velocity\Z',            vtSingle,  [],           FloatToStr(GlobalVelocity.Z), '');
  Result.Add('Particles\Local coordinates', vtBoolean, [],           OnOffStr[LocalCoordinates],  '');
  Result.Add('Particles\Rotation support',  vtBoolean, [],           OnOffStr[RotationSupport],   '');
  Result.Add('Particles\Fast killing',      vtBoolean, [],           OnOffStr[FastKill],          '');
  Result.Add('Particles\Reverse order',     vtBoolean, [],           OnOffStr[TParticlesMesh(CurrentTesselator).ReverseOrder], '');
end;

procedure TParticleSystem.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Particles\Default\Color')            then DefaultColor     := Longword(Properties.GetAsInteger('Particles\Default\Color'));
  if Properties.Valid('Particles\Default\Size')             then DefaultRadius    := StrToFloatDef(Properties['Particles\Default\Size'], 0);
  if Properties.Valid('Particles\Default\Lifetime')         then DefaultLifetime  := StrToIntDef(Properties['Particles\Default\Lifetime'], 0);
  if Properties.Valid('Particles\Max')            then TParticlesMesh(CurrentTesselator).MaxCapacity := StrToIntDef(Properties['Particles\Max'], 0);
  if Properties.Valid('Emitter\Radius')           then EmitRadius       := StrToFloatDef(Properties['Emitter\Radius'], 0);
  if Properties.Valid('Emitter\Uniform')          then UniformEmit      := Properties.GetAsInteger('Emitter\Uniform') > 0;
  if Properties.Valid('Emitter\Uniform interval') then EmitSpace        := StrToFloatDef(Properties['Emitter\Uniform interval'], 0);
  if Properties.Valid('Fixed velocity\X')        then GlobalVelocity.X := StrToFloatDef(Properties['Fixed velocity\X'], 0);
  if Properties.Valid('Fixed velocity\Y')        then GlobalVelocity.Y := StrToFloatDef(Properties['Fixed velocity\Y'], 0);
  if Properties.Valid('Fixed velocity\Z')        then GlobalVelocity.Z := StrToFloatDef(Properties['Fixed velocity\Z'], 0);
  if Properties.Valid('Particles\Local coordinates')        then LocalCoordinates := Properties.GetAsInteger('Particles\Local coordinates') > 0;
  if Properties.Valid('Particles\Rotation support')         then RotationSupport  := Properties.GetAsInteger('Particles\Rotation support') > 0;
  if Properties.Valid('Particles\Fast killing')             then FastKill         := Properties.GetAsInteger('Particles\Fast killing') > 0;
  if Properties.Valid('Particles\Reverse order')            then TParticlesMesh(CurrentTesselator).ReverseOrder := Properties.GetAsInteger('Particles\Reverse order') > 0;
  TimeProcessed := 0;

  if Properties.Valid('Particles\Instant emit') then Emit(StrToIntDef(Properties['Particles\Instant emit'], 1)-1);
end;

procedure TParticleSystem.SetupExternalVariables;
begin
  inherited;
{$IFDEF SCRIPTING}
  World.Compiler.ImportExternalVar('DefaultColor',    'LONGINT', @DefaultColor);
  World.Compiler.ImportExternalVar('DefaultRadius',   'SINGLE', @DefaultRadius);
  World.Compiler.ImportExternalVar('TotalParticles',  'LONGINT', @T3DParticlesMesh(CurrentTesselator).TotalParticles);
  World.Compiler.ImportExternalVar('Particles',       'TParticles', @T3DParticlesMesh(CurrentTesselator).Particles[0]);
  World.Compiler.ImportExternalVar('ParticlesToEmit', 'LONGINT', @ParticlesToEmit);
{$ENDIF}
end;

function TParticleSystem.GetParticleCount: Integer;
begin
  Result := (CurrentTesselator as TParticlesMesh).TotalParticles;
end;

procedure TParticleSystem.UpdateMesh;
var PMesh: TParticlesMesh;
begin
  PMesh := CurrentTesselator as TParticlesMesh;
  with PMesh do begin
    TotalVertices := TotalParticles*4; TotalPrimitives := TotalParticles*2;
    TotalIndices := TotalParticles*6;
  end;
  CurrentTesselator.Invalidate(True);
end;

function TParticleSystem.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := 0;
  if DisableEmit then Exit;
  ParticlesToEmit := ParticlesToEmit + Count;
  if UniformEmit then begin
    ParticlesToEmit := ParticlesToEmit + Sqrt(SqrMagnitude(SubVector3s(LastEmitLocation, GetAbsLocation)))/EmitSpace;
  end;
  Result := Trunc(ParticlesToEmit);
  ParticlesToEmit := ParticlesToEmit - Result;

  if Result > 0 then begin
    PMesh := TParticlesMesh(CurrentTesselator);

    Result := PMesh.AddParticles(Result);

    for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
      Position := GetVector3s(Random * EmitRadius, Random * EmitRadius, Random * EmitRadius);
      Velocity := EmitterVelocity;
      if UniformEmit then AddVector3s(Position, Position, ScaleVector3s(SubVector3s(LastEmitLocation, GetAbsLocation), Random));
      Radius := DefaultRadius;
      Mass := 1;
      FadeK := 0;
      Color := DefaultColor;
      Age := 0;
      LifeTime := DefaultLifeTime;
    end;

    UpdateMesh;
  end;

  LastEmitLocation := GetAbsLocation;
end;

procedure TParticleSystem.Kill(Index: Integer);
var i: Integer;
begin
  if (Index < 0) or (Index >= TParticlesMesh(CurrentTesselator).TotalParticles) then Exit;
  CurrentTesselator.Invalidate(True);
  Dec(TParticlesMesh(CurrentTesselator).TotalParticles);
  if Index = TParticlesMesh(CurrentTesselator).TotalParticles then Exit;
  if FastKill then
   TParticlesMesh(CurrentTesselator).Particles[Index] := TParticlesMesh(CurrentTesselator).Particles[TParticlesMesh(CurrentTesselator).TotalParticles] else
    for i := Index+1 to TParticlesMesh(CurrentTesselator).TotalParticles do TParticlesMesh(CurrentTesselator).Particles[i-1] := TParticlesMesh(CurrentTesselator).Particles[i];
end;

procedure TParticleSystem.KillAll;
begin
  if TParticlesMesh(CurrentTesselator).TotalParticles = 0 then Exit;
  CurrentTesselator.Invalidate(True);
  TParticlesMesh(CurrentTesselator).TotalParticles := 0;
end;

{ TParticlesMesh }

constructor TParticlesMesh.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLELIST;
//  PrimitiveType := ptTRIANGLESTRIP;
//  InitVertexFormat(GetVertexFormat(True, False, True, False, False, 0, [2]));
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));

  MaxCapacity := 2000;
  SetCapacity(ParticlesAllocStep);             // Default capaticy
  TotalParticles := 0;
  ReverseOrder := True;
end;

function TParticlesMesh.AddParticles(Count: Integer): Integer;
var OldTP: Integer;
begin
  if Capacity < Cardinal(TotalParticles + Count) then SetCapacity(TotalParticles + Count);
  OldTP := TotalParticles;
  TotalParticles := MinI(Capacity, TotalParticles + Count);
  Result := TotalParticles - OldTP;
end;

procedure TParticlesMesh.SetCapacity(const ACapacity: Integer);
begin
  Capacity := MinI(MaxCapacity, MaxI(0, (ACapacity-1)) and ParticleAllocMask + ParticlesAllocStep);
  SetLength(Particles, Capacity);
end;

function TParticlesMesh.Tesselate(Camera: TCamera; VBPTR: Pointer): Integer;
var i: Integer; Transformed: TVector4s; TRHW: Single;
begin
  Result := 0;
  LastTotalVertices := 0;
  Transformed := GetVector4s(0, 0, Matrix._43, 1); //Transform4Vector3s(RenderPars.TotalMatrix, Location);
  if Transformed.W < 0 then Exit;
  TRHW := 0.001;//1/Transformed.W;
  Transformed.X := {RenderPars.ActualWidth shr 1 + RenderPars.ActualWidth shr 1*}Transformed.X;
  Transformed.Y := {RenderPars.ActualHeight shr 1 - RenderPars.ActualHeight shr 1*}Transformed.Y;
//  with RenderPars do Transformed.Z := 0*(ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));
  for i := 0 to TotalParticles-1 do with Particles[i] do begin
    SetVertexDataCRHW(Transformed.X + (Position.X - Radius*0.5), Transformed.Y - Position.Y - Radius*0.5, Transformed.Z, TRHW, i*4, VBPTR);
    SetVertexDataUV(0, 0,  i*4, VBPTR);
    SetVertexDataD (Color, i*4, VBPTR);

    SetVertexDataCRHW(Transformed.X + (Position.X + Radius*0.5), Transformed.Y - Position.Y - Radius*0.5, Transformed.Z, TRHW, i*4+1, VBPTR);
    SetVertexDataUV(1, 0,  i*4+1, VBPTR);
    SetVertexDataD (Color, i*4+1, VBPTR);

    SetVertexDataCRHW(Transformed.X + (Position.X + Radius*0.5), Transformed.Y - Position.Y + Radius*0.5, Transformed.Z, TRHW, i*4+2, VBPTR);
    SetVertexDataUV(1, 1,  i*4+2, VBPTR);
    SetVertexDataD (Color, i*4+2, VBPTR);

    SetVertexDataCRHW(Transformed.X + (Position.X - Radius*0.5), Transformed.Y - Position.Y + Radius*0.5, Transformed.Z, TRHW, i*4+3, VBPTR);
    SetVertexDataUV(0, 1,  i*4+3, VBPTR);
    SetVertexDataD (Color, i*4+3, VBPTR);
  end;
  TotalVertices     := TotalParticles*4; TotalPrimitives := TotalParticles*2;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;
  ParticlesVisible  := TotalParticles;
  Result            := TotalVertices;
  VStatus           := tsSizeChanged;
end;

function TParticlesMesh.SetIndices(IBPTR: Pointer): Integer;
var i, Ind: Integer; IBuf: ^TWordBuffer;
begin
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
  Result := TotalParticles*4;
end;

function TParticlesMesh.GetMaxIndices: Integer;
begin
  Result := TotalParticles*6;
end;

{ T3DParticlesMesh }

function T3DParticlesMesh.Tesselate(Camera: TCamera; VBPTR: Pointer): Integer;
var i: Integer; TCamRight, TCamUp: TVector3s;
begin
//  Matrix := MulMatrix4s(RenderPars.WorldMatrix, RenderPars.TotalMatrix);
  ParticlesVisible := 0;
  TCamRight := Transform3Vector3sTransp(CutMatrix3s(Matrix), Camera.RightVector);
  TCamUp    := Transform3Vector3sTransp(CutMatrix3s(Matrix), Camera.UpVector);

  for i := 0 to TotalParticles-1 do with Particles[i] do begin
    SetVertexDataC(Position.X + (-TCamRight.X - TCamUp.X) * Radius,
                   Position.Y + (-TCamRight.Y - TCamUp.Y) * Radius,
                   Position.Z + (-TCamRight.Z - TCamUp.Z) * Radius,
                   ParticlesVisible*4+3, VBPTR);
    SetVertexDataUV(0, 0,  ParticlesVisible*4+3, VBPTR);
    SetVertexDataD(Color and $FF000000, ParticlesVisible*4+3, VBPTR);

    SetVertexDataC(Position.X + (TCamRight.X - TCamUp.X) * Radius,
                   Position.Y + (TCamRight.Y - TCamUp.Y) * Radius,
                   Position.Z + (TCamRight.Z - TCamUp.Z) * Radius,
                   ParticlesVisible*4+2, VBPTR);
    SetVertexDataUV(1, 0,  ParticlesVisible*4+2, VBPTR);
    SetVertexDataD(Color and $FF000000, ParticlesVisible*4+2, VBPTR);

    SetVertexDataC(Position.X + (TCamRight.X + TCamUp.X) * Radius,
                   Position.Y + (TCamRight.Y + TCamUp.Y) * Radius,
                   Position.Z + (TCamRight.Z + TCamUp.Z) * Radius,
                   ParticlesVisible*4+1, VBPTR);
    SetVertexDataUV(1, 1,  ParticlesVisible*4+1, VBPTR);
    SetVertexDataD (Color and $FF000000+$FFFFFF, ParticlesVisible*4+1, VBPTR);

    SetVertexDataC(Position.X + (-TCamRight.X + TCamUp.X) * Radius,
                   Position.Y + (-TCamRight.Y + TCamUp.Y) * Radius,
                   Position.Z + (-TCamRight.Z + TCamUp.Z) * Radius,
                   ParticlesVisible*4, VBPTR);
    SetVertexDataUV(0, 1,  ParticlesVisible*4, VBPTR);
    SetVertexDataD (Color and $FF000000+$FFFFFF, ParticlesVisible*4, VBPTR);

    Inc(ParticlesVisible);
  end;
  TotalVertices     := ParticlesVisible*4;
  TotalPrimitives   := ParticlesVisible*2;
  Result            := TotalVertices;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;
  VStatus           := tsSizeChanged;
end;

function __T3DParticlesMesh.Tesselate(Camera: TCamera; VBPTR: Pointer): Integer;
var i: Integer; Transformed: TVector4s; TRHW: Single;
begin
//  Matrix := MulMatrix4s(RenderPars.WorldMatrix, RenderPars.TotalMatrix);
  ParticlesVisible := 0;
  for i := 0 to TotalParticles-1 do with Particles[i] do begin
    Transformed := Transform4Vector3s(MulMatrix4s(Matrix, Camera.TotalMatrix), Position);
//    Transformed := GetVector4s(0, 0, 1, 1);
    if Transformed.W < 0 then Continue;
    with Camera do Transformed.Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));          // ToFix: Optimize it
    TRHW := 1/Transformed.W;                                                                    // ToFix: And this too

    SetVertexDataCRHW(Camera.ScreenWidth  shr 1 * (1 + (Transformed.X - Radius * 0.5) * TRHW),
                      Camera.ScreenHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5) * TRHW),
                      Transformed.Z, TRHW, ParticlesVisible*4+3, VBPTR);
    SetVertexDataUV(0, 0,  ParticlesVisible*4+3, VBPTR);
    SetVertexDataD (Color and $FF000000, ParticlesVisible*4+3, VBPTR);

    SetVertexDataCRHW(Camera.ScreenWidth  shr 1 * (1 + (Transformed.X + Radius * 0.5) * TRHW),
                      Camera.ScreenHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5) * TRHW),
                      Transformed.Z, TRHW, ParticlesVisible*4+2, VBPTR);
    SetVertexDataUV(1, 0,  ParticlesVisible*4+2, VBPTR);
    SetVertexDataD (Color and $FF000000, ParticlesVisible*4+2, VBPTR);

    SetVertexDataCRHW(Camera.ScreenWidth  shr 1 * (1 + (Transformed.X + Radius * 0.5) * TRHW),
                      Camera.ScreenHeight shr 1 * (1 - (Transformed.Y + Radius * 0.5) * TRHW),
                      Transformed.Z, TRHW, ParticlesVisible*4+1, VBPTR);
    SetVertexDataUV(1, 1,  ParticlesVisible*4+1, VBPTR);
    SetVertexDataD (Color and $FF000000+$FFFFFF, ParticlesVisible*4+1, VBPTR);

    SetVertexDataCRHW(Camera.ScreenWidth  shr 1 * (1 + (Transformed.X - Radius * 0.5) * TRHW),
                      Camera.ScreenHeight shr 1 * (1 - (Transformed.Y + Radius * 0.5) * TRHW),
                      Transformed.Z, TRHW, ParticlesVisible*4, VBPTR);
    SetVertexDataUV(0, 1,  ParticlesVisible*4, VBPTR);
    SetVertexDataD (Color and $FF000000+$FFFFFF, ParticlesVisible*4, VBPTR);

    Inc(ParticlesVisible);
  end;
  TotalVertices     := ParticlesVisible*4;
  TotalPrimitives   := ParticlesVisible*2;
  Result            := TotalVertices;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;
  VStatus           := tsSizeChanged;
end;

{ T2DParticleSystem }

procedure T2DParticleSystem.Process;
var i: Integer;
begin
  Emit(0);                     // Emit ParticlesToEmit number of particles
  
  inherited;
  if (DefaultRadius = 0) or (DefaultColor shr 24 = 0) then Exit;
  with TParticlesMesh(CurrentTesselator) do begin
    if not LocalCoordinates then
     with Transform do TParticlesMesh(CurrentTesselator).Matrix := Transform;
    for i := TotalParticles-1 downto 0 do with Particles[i] do begin
      if (Age >= Lifetime) or (Radius <= 0) or ((Color and $FF000000) = 0) then begin
        Kill(i)
      end else begin
        {if (Age < Lifetime-2) then }Position := AddVector3s(Position, AddVector3s(Velocity, GlobalVelocity));
        Inc(Age);
      end;
    end;
  end;

  CurrentTesselator.Invalidate(True);
end;

{ T3DParticleSystem }

constructor T3DParticleSystem.Create(AManager: TItemsManager);
begin
  inherited;
  OldLocation := GetVector3s(0, 0, 0);
  Relocated := False;
  ParticlesToEmit := 0;
end;

function T3DParticleSystem.GetTesselatorClass: CTesselator; begin Result := T3DParticlesMesh end;

procedure T3DParticleSystem.SetProperties(Properties: TProperties);
var OldRotationSupport: Boolean;
begin
  OldRotationSupport := RotationSupport;
  inherited;
  if OldRotationSupport <> RotationSupport then begin
    SetMesh;
    inherited;
  end;
end;

function T3DParticleSystem.Emit(Count: Single): Integer;
var i: Integer; PMesh: T3DParticlesMesh;
begin
  Result := 0;
  if DisableEmit then Exit;
  ParticlesToEmit := ParticlesToEmit + Count;
  if UniformEmit then
    ParticlesToEmit := ParticlesToEmit + Sqrt(SqrMagnitude(SubVector3s(LastEmitLocation, GetAbsLocation)))/EmitSpace;
  Result := Trunc(ParticlesToEmit);
  ParticlesToEmit := ParticlesToEmit - Result;
  if Result > 0 then begin
    PMesh := T3DParticlesMesh(CurrentTesselator);
    if PMesh.TotalParticles = 0 then OldLocation := GetAbsLocation;

    Result := PMesh.AddParticles(Result);

    for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
      Position := GetVector3s((Random*2-1) * EmitRadius, (Random*2-1) * EmitRadius, (Random*2-1) * EmitRadius);
      Velocity := Position;
      if UniformEmit then AddVector3s(Position, Position, ScaleVector3s(SubVector3s(LastEmitLocation, GetAbsLocation), Random));
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

  LastEmitLocation := GetAbsLocation;
end;

procedure T3DParticleSystem.Process;
var i, NewCount: Integer; LocationDiff: TVector3s;

procedure CheckBBox(const Position: TVector3s);
begin
  BoundingBox.P1.X := MinS(BoundingBox.P1.X, Position.X - MaxSize);
  BoundingBox.P1.Y := MinS(BoundingBox.P1.Y, Position.Y - MaxSize);
  BoundingBox.P1.Z := MinS(BoundingBox.P1.Z, Position.Z - MaxSize);
  BoundingBox.P2.X := MaxS(BoundingBox.P2.X, Position.X + MaxSize);
  BoundingBox.P2.Y := MaxS(BoundingBox.P2.Y, Position.Y + MaxSize);
  BoundingBox.P2.Z := MaxS(BoundingBox.P2.Z, Position.Z + MaxSize);
end;

begin
  NewCount := Emit(0);

  inherited;
  if (DefaultRadius = 0) or (DefaultColor shr 24 = 0) then Exit;
  with TParticlesMesh(CurrentTesselator) do begin
    TParticlesMesh(CurrentTesselator).Matrix := Transform;
    if not LocalCoordinates then begin
      if not EqualsVector3s(GetAbsLocation, OldLocation) then begin
        LocationDiff := SubVector3s(GetAbsLocation, OldLocation);
        Relocated := True;
        for i := TotalParticles-NewCount-1 downto 0 do with Particles[i] do begin
          Position := SubVector3s(Position, LocationDiff);
        end;
        OldLocation := GetAbsLocation;
      end else Relocated := False;
    end;

    BoundingBox.P1 := GetVector3s(0, 0, 0);
    BoundingBox.P2 := BoundingBox.P1;

    for i := TotalParticles-NewCount-1 downto 0 do with Particles[i] do begin
      if (Age >= Lifetime) or (Radius <= 0) or ((Color and $FF000000) = 0) then begin
        Kill(i)
      end else begin
        {if (Age < Lifetime-2) then }Position := AddVector3s(Position, AddVector3s(Velocity, GlobalVelocity));
        AddVector3s(Velocity, Velocity, OuterForce);
//        ScaleVector3s(Velocity, Velocity, 0.95);
        Inc(Age);
        if MaxSize < Radius*0.5 then MaxSize := Radius*0.5;
        CheckBBox(Position);
      end;
    end;
  end;

  CurrentTesselator.Invalidate(True);
end;

procedure T3DParticleSystem.SetupExternalVariables;
begin
  inherited;
end;

{ TPSFadingIn }

procedure TPSFadingIn.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Variation\Fade in period',  vtNat,    [], IntToStr(FadeInPeriod),    '');
  Result.Add('Variation\Grow\period',     vtNat,    [], IntToStr(GrowInPeriod),    '');
  Result.Add('Move\Elevation speed',      vtSingle, [], FloatToStr(ElevationSpeed), '');
  Result.Add('Emitter\Density',           vtSingle, [], FloatToStr(Density),        '');
  Result.Add('Emitter\Radius jitter',     vtSingle, [], FloatToStr(RadiusJitter),   '');
  Result.Add('Variation\Grow\Speed',      vtSingle, [], FloatToStr(GrowSpeed),      '');
  Result.Add('Move\Expansion speed',      vtSingle, [], FloatToStr(ExpansionSpeed), '');
  Result.Add('Move\Velocity jitter',      vtSingle, [], FloatToStr(VelocityJitter), '');
  Result.Add('Move\Slowdown',             vtSingle, [], FloatToStr(Slowdown),       '');
end;

procedure TPSFadingIn.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Variation\Fade in period')  then FadeInPeriod   := StrToIntDef (Properties['Variation\Fade in period'], 0);
  if Properties.Valid('Variation\Grow\period')     then GrowInPeriod   := StrToIntDef (Properties['Variation\Grow\period'],    0);
  if Properties.Valid('Move\Elevation speed')      then ElevationSpeed := StrToFloatDef(Properties['Move\Elevation speed'],     0);
  if Properties.Valid('Emitter\Density')           then Density        := StrToFloatDef(Properties['Emitter\Density'],          0);
  if Properties.Valid('Emitter\Radius jitter')     then RadiusJitter   := StrToFloatDef(Properties['Emitter\Radius jitter'],    0);
  if Properties.Valid('Variation\Grow\Speed')      then GrowSpeed      := StrToFloatDef(Properties['Variation\Grow\Speed'],     0);
  if Properties.Valid('Move\Expansion speed')      then ExpansionSpeed := StrToFloatDef(Properties['Move\Expansion speed'],     0);
  if Properties.Valid('Move\Velocity jitter')      then VelocityJitter := StrToFloatDef(Properties['Move\Velocity jitter'],     0);
  if Properties.Valid('Move\Slowdown')             then Slowdown       := StrToFloatDef(Properties['Move\Slowdown'],            0);
  case FadeInPeriod of
    0, 1: FadeInShift := 0;
    2:    FadeInShift := 1;
    4:    FadeInShift := 2;
    8:    FadeInShift := 3;
    16:   FadeInShift := 4;
    32:   FadeInShift := 5;
    64:   FadeInShift := 6;
    128:  FadeInShift := 7;
    256:  FadeInShift := 8;
    else begin
      FadeInPeriod := 8;
      FadeInShift  := 3;
    end;
  end;
end;

function TPSFadingIn.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentTesselator);
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

procedure TPSFadingIn.Process;
var i: Integer; a: Longword;
begin
  with TParticlesMesh(CurrentTesselator) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
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

  inherited;
end;

// TPSFountain

constructor TPSFountain.Create(AManager: TItemsManager);
begin
  inherited;
  SetMesh;
  DefaultRadius := 50;
  InitYSpeed := 20; MaxHSpeed := 10; Density := 250;
  GlobalForce := GetVector3s(0, -10, 0);
end;

procedure TPSFountain.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Move\Initial vertical speed', vtInt,    [], IntToStr(InitYSpeed),      '');
  Result.Add('Move\Max horizontal speed',   vtNat,    [], IntToStr(MaxHSpeed),       '');
  Result.Add('Emitter\Density',             vtNat,    [], IntToStr(Density),         '');
  Result.Add('Move\Gravity',                vtSingle, [], FloatToStr(GlobalForce.Y),  '');
  Result.Add('Emitter\Size jitter, %',      vtInt,    [], IntToStr(SizeJitter),      '');
end;

procedure TPSFountain.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Move\Initial vertical speed')    then InitYSpeed    := StrToIntDef(Properties['Move\Initial vertical speed'], 0);
  if Properties.Valid('Move\Max horizontal speed')      then MaxHSpeed     := StrToIntDef(Properties['Move\Max horizontal speed'],   0);
  if Properties.Valid('Emitter\Density')                then Density       := StrToIntDef(Properties['Emitter\Density'],             0);
  if Properties.Valid('Move\Gravity')                   then GlobalForce.Y := StrToFloatDef(Properties['Move\Gravity'],               0);
  if Properties.Valid('Emitter\Size jitter, %')         then SizeJitter    := StrToIntDef(Properties['Emitter\Size jitter, %'],      0);
end;

function TPSFountain.Emit(Count: Single): Integer;
var i: Integer; PMesh: T3DParticlesMesh; Phi, Theta: Single;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentTesselator);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Radius := DefaultRadius+(1-Random)*DefaultRadius*SizeJitter/100;
    Phi := Random*Pi*2; Theta := Random*Pi;
    Velocity := GetVector3s(100*Cos(Phi)*Sin(Theta)*MaxHSpeed/Radius, 100*Sin(Theta)*InitYSpeed/Radius, 100*Sin(Phi)*Sin(Theta)*MaxHSpeed/Radius);
    Position := Velocity;
  end;
  UpdateMesh;
end;

procedure TPSFountain.Process;
var i: Integer;
begin
  inherited;
//  with ModelMatrix do TParticlesMesh(CurrentTesselator).Location := GetVector3s(_41, _42, _43);
  with TParticlesMesh(CurrentTesselator) do for i := TotalParticles-1 downto 0 do begin
    Particles[i].Position := AddVector3s(Particles[i].Position, Particles[i].Velocity);
    Particles[i].Velocity := AddVector3s(Particles[i].Velocity, GlobalForce);
    if (Particles[i].Position.Y <= 0) and (Particles[i].Velocity.Y < 0) then begin
      Kill(i);
    end;
  end;
  ParticlesToEmit := ParticlesToEmit + Density-TParticlesMesh(CurrentTesselator).TotalParticles;
//  T3DParticlesMesh(CurrentTesselator).Location := GetVector3s(0, 0, 0);
end;

procedure T3DParticleSystem.Init;
begin
  inherited;
  OldLocation := GetAbsLocation;
  MaxSize     := 0;
end;

{ TPSBalls }

function TPSBalls.Emit(Count: Single): Integer;
var i: Integer; Col: Cardinal; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := TParticlesMesh(CurrentTesselator);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Position := GetVector3s(Random(300)-150, Random(40)-20, 0);
    Velocity := GetVector3s(Random*20-10, Random*6-3, 0);
    Radius := 5+Random(6)*5;
    Col := Random(512);
    Color := $80FF0000 + Cardinal(MinI(255, Col))*$100 + Col shr 1;
  end;
  UpdateMesh;
end;

procedure TPSBalls.Process;
var i: Integer;
begin
  with TParticlesMesh(CurrentTesselator) do for i := TotalParticles-1 downto 0 do begin
    Particles[i].Position := AddVector3s(Particles[i].Position, Particles[i].Velocity);
    if (Particles[i].Position.X < -150) and (Particles[i].Velocity.X < 0) or
       (Particles[i].Position.X > 150) and (Particles[i].Velocity.X > 0) then Particles[i].Velocity.X := -Particles[i].Velocity.X;
    if (Particles[i].Position.Y < -20) and (Particles[i].Velocity.Y < 0) or
       (Particles[i].Position.Y > 20) and (Particles[i].Velocity.Y > 0) then Particles[i].Velocity.Y := -Particles[i].Velocity.Y;
  end;

  inherited;
end;

{ TPSSmoke }

constructor TPSSmoke.Create(AManager: TItemsManager);
begin
  inherited;
  SetMesh;
end;

procedure TPSSmoke.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Variation\Final color',    vtColor, [], '#' + IntToHex(EndColor, 8),    '');
  Result.Add('Variation\Colored length', vtNat,   [],       IntToStr(ColoredLength),  '');
  Result.Add('Variation\Rotation speed', vtInt,   [],       IntToStr(RotationSpeed),  '');
  Result.Add('Emitter\Start age jitter', vtNat,   [],       IntToStr(StartAgeJitter), '');
end;

procedure TPSSmoke.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Variation\Final color')        then EndColor       := Longword(Properties.GetAsInteger('Variation\Final color'));
  if Properties.Valid('Variation\Colored length')   then ColoredLength  := StrToIntDef(Properties['Variation\Colored length'],   0);
  if Properties.Valid('Variation\Rotation speed')   then RotationSpeed  := StrToIntDef(Properties['Variation\Rotation speed'],   0);
  if Properties.Valid('Emitter\Start age jitter')   then StartAgeJitter := StrToIntDef(Properties['Emitter\Start age jitter'],   0);
end;

function TPSSmoke.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentTesselator);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    if RotationSpeed >= 0 then Sprite := (Random(RotationSpeed+1)) else Sprite := Trunc(0.5 + (Random*2-1)*RotationSpeed);
    Angle := Random(MaxAngle);
    LifeTime := MaxC(0, DefaultLifeTime - Cardinal(Random(StartAgeJitter)));
  end;
  UpdateMesh;
end;

procedure TPSSmoke.Process;
var i: Integer; a: Longword; c: Single;
begin
  inherited;

  with TParticlesMesh(CurrentTesselator) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
    Particles[i].Angle := Particles[i].Angle + Particles[i].Sprite;

    IF Particles[i].Age <= FadeInPeriod THEN
     a := 1+(Particles[i].Age*(DefaultColor shr 24)) shr FadeInShift ELSE
      a := DefaultColor shr 24;

    if Particles[i].Age < ColoredLength then begin
      c := Particles[i].Age/ColoredLength;
      Particles[i].Color := BlendColor(DefaultColor and $FFFFFF + a shl 24, EndColor, c);
    end else begin
      c := (Particles[i].Age - ColoredLength)/(Particles[i].Lifetime - ColoredLength);
      Particles[i].Color := BlendColor(EndColor, EndColor and $FFFFFF, c);
    end;
  end;
end;

{ TPSComet }

constructor TPSComet.Create(AManager: TItemsManager);
begin
  inherited;
  SetMesh;
  DefaultRadius := 500; Density := 6; FadeSpeed := 0.001;
  CoreRadius := 500; RadiusJitter := 0.5; GrowthSpeed := -0.001;
end;

procedure TPSComet.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Emitter\Core radius',     vtSingle, [], FloatToStr(CoreRadius),     '');
  Result.Add('Emitter\Radius jitter',   vtSingle, [], FloatToStr(RadiusJitter),   '');
  Result.Add('Emitter\Density',         vtInt,    [], IntToStr(Density),         '');
  Result.Add('Variation\Growth speed',  vtSingle, [], FloatToStr(GrowthSpeed),    '');
  Result.Add('Variation\Fade speed',    vtSingle, [], FloatToStr(FadeSpeed),      '');
  Result.Add('Move\Elevation speed',    vtSingle, [], FloatToStr(ElevationSpeed), '');
end;

procedure TPSComet.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Emitter\Core radius')    then CoreRadius     := StrToFloatDef(Properties['Emitter\Core radius'],    0);
  if Properties.Valid('Emitter\Radius jitter')  then RadiusJitter   := StrToFloatDef(Properties['Emitter\Radius jitter'],  0);
  if Properties.Valid('Emitter\Density')        then Density        := StrToIntDef(Properties['Emitter\Density'],         0);
  if Properties.Valid('Variation\Growth speed') then GrowthSpeed    := StrToFloatDef(Properties['Variation\Growth speed'], 0);
  if Properties.Valid('Variation\Fade speed')   then FadeSpeed      := StrToFloatDef(Properties['Variation\Fade speed'],   0);
  if Properties.Valid('Move\Elevation speed')   then ElevationSpeed := StrToFloatDef(Properties['Move\Elevation speed'],   0);
end;

function TPSComet.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentTesselator);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
//    Position := AddVector3s(Position, GetVector3s((Random*2-1)*CoreRadius, (Random*2-1)*CoreRadius, (Random*2-1)*CoreRadius));
    Velocity := GetVector3s((Random*2-1)*CoreRadius*0.2, (Random*2-1)*CoreRadius*0.2 + ElevationSpeed, (Random*2-1)*CoreRadius*0.2);
    Radius := DefaultRadius * (1 + Random * RadiusJitter);
//    Color := Self.DefaultColor and $FFFFFF;
    FadeK := 1;
  end;
  UpdateMesh;
end;

procedure TPSComet.Process;
var i: Integer; 
begin
  with TParticlesMesh(CurrentTesselator) do for i := TotalParticles-1 downto 0 do begin
    if Particles[i].Radius > 1 then Particles[i].Radius := Particles[i].Radius * (1+GrowthSpeed) else Kill(i);
    if Particles[i].FadeK > FadeSpeed then begin
      Particles[i].FadeK := Particles[i].FadeK - FadeSpeed;
      Particles[i].Color := Trunc((DefaultColor shr 24)*Particles[i].FadeK) shl 24 or (Particles[i].Color and $FFFFFF);
    end else Kill(i);
  end;
  ParticlesToEmit := ParticlesToEmit + Density / DefaultRadius;

  inherited;
end;

{ TPSFire }

procedure TPSFire.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Move\Elevation jitter',  vtSingle, [], FloatToStr(ElevationJitter), '');
  Result.Add('Variation\Shrink speed', vtSingle, [], FloatToStr(ShrinkSpeed),     '');
  Result.Add('Variation\Shrink start', vtNat,    [], IntToStr(ShrinkStart),      '');
end;

procedure TPSFire.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Move\Elevation jitter')  then ElevationJitter := StrToFloatDef(Properties['Move\Elevation jitter'],  0);
  if Properties.Valid('Variation\Shrink speed') then ShrinkSpeed     := StrToFloatDef(Properties['Variation\Shrink speed'], 0);
  if Properties.Valid('Variation\Shrink start') then ShrinkStart     := StrToIntDef(Properties['Variation\Shrink start'],  0);
end;

function TPSFire.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentTesselator);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Velocity := GetVector3s(Velocity.X, ElevationSpeed+Random*ElevationJitter, Velocity.Z);
  end;

  UpdateMesh;
end;

procedure TPSFire.Process;
var i: Integer; c: Single;
begin
  with TParticlesMesh(CurrentTesselator) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
    Particles[i].Velocity.x := Particles[i].Velocity.x + (Random*2.0-1)*1.0;
    Particles[i].Velocity.z := Particles[i].Velocity.z + (Random*2.0-1)*1.0;

    if Particles[i].Age >= ShrinkStart then begin
      c := (Particles[i].Age - ShrinkStart)/(Particles[i].LifeTime - ShrinkStart);
      Particles[i].Radius := Particles[i].FadeK * (1-c);
    end;  
  end;

  inherited;
end;

{ T3DAngleParticlesMesh }

function T3DAngleParticlesMesh.Tesselate(Camera: TCamera; VBPTR: Pointer): Integer;
var i: Integer; Transformed: TVector4s; TRHW: Single;
begin
//  Matrix := MulMatrix4s(RenderPars.WorldMatrix, RenderPars.TotalMatrix);
  ParticlesVisible := 0;

  for i := 0 to TotalParticles-1 do with Particles[i] do begin
    Transformed := Transform4Vector3s(MulMatrix4s(Matrix, Camera.TotalMatrix), Position);
    if Transformed.W < 0 then Continue;
    with Camera do Transformed.Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));          // ToFix: Optimize it
    TRHW := 1/Transformed.W;                                                                    // ToFix: And this too

    SetVertexDataCRHW(Camera.ScreenWidth  shr 1 * (1 + (Transformed.X + Radius * 0.5 * Cos((Angle+45)/180*pi)) * TRHW),
                      Camera.ScreenHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5 * Sin((Angle+45)/180*pi)) * TRHW),
                      Transformed.Z, TRHW, ParticlesVisible*4+3, VBPTR);
    SetVertexDataUV(0, 0, ParticlesVisible*4+3, VBPTR);
    SetVertexDataD(Color, ParticlesVisible*4+3, VBPTR);

    SetVertexDataCRHW(Camera.ScreenWidth  shr 1 * (1 + (Transformed.X + Radius * 0.5 * Cos((Angle+135)/180*pi)) * TRHW),
                      Camera.ScreenHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5 * Sin((Angle+135)/180*pi)) * TRHW),
                      Transformed.Z, TRHW, ParticlesVisible*4+2, VBPTR);
    SetVertexDataUV(1, 0, ParticlesVisible*4+2, VBPTR);
    SetVertexDataD(Color, ParticlesVisible*4+2, VBPTR);

    SetVertexDataCRHW(Camera.ScreenWidth  shr 1 * (1 + (Transformed.X + Radius * 0.5 * Cos((Angle+225)/180*pi)) * TRHW),
                      Camera.ScreenHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5 * Sin((Angle+225)/180*pi)) * TRHW),
                      Transformed.Z, TRHW, ParticlesVisible*4+1, VBPTR);
    SetVertexDataUV(1, 1, ParticlesVisible*4+1, VBPTR);
    SetVertexDataD(Color, ParticlesVisible*4+1, VBPTR);

    SetVertexDataCRHW(Camera.ScreenWidth  shr 1 * (1 + (Transformed.X + Radius * 0.5 * Cos((Angle+315)/180*pi)) * TRHW),
                      Camera.ScreenHeight shr 1 * (1 - (Transformed.Y - Radius * 0.5 * Sin((Angle+315)/180*pi)) * TRHW),
                      Transformed.Z, TRHW, ParticlesVisible*4, VBPTR);
    SetVertexDataUV(0, 1, ParticlesVisible*4, VBPTR);
    SetVertexDataD(Color, ParticlesVisible*4, VBPTR);

    Inc(ParticlesVisible);
  end;
  TotalVertices     := ParticlesVisible*4;
  TotalPrimitives   := ParticlesVisible*2;
  Result            := TotalVertices;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;
  VStatus           := tsSizeChanged;
end;

{ TPSExplosion }

procedure TPSExplosion.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Variation\Cicle completeness', vtSingle, [], FloatToStr(CicleCompleteness), '');
end;

procedure TPSExplosion.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Variation\Cicle completeness') then CicleCompleteness := StrToFloatDef(Properties['Cicle completeness'], 0);
end;

function TPSExplosion.Emit(Count: Single): Integer;
begin
  Result := inherited Emit(Count);
end;

procedure TPSExplosion.Process;
var i: Integer; c: Single;
begin
  with TParticlesMesh(CurrentTesselator) do for i := 0 to TotalParticles-1 do with Particles[i] do begin
    c := SIN((Particles[i].Age+1)/Particles[i].LifeTime*pi*CicleCompleteness);
    Particles[i].Radius := c*DefaultRadius;
  end;

  inherited;
end;

{ TPSExpSmoke }

procedure TPSExpSmoke.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Move\Spread angle',      vtInt,    [], IntToStr(SpreadAngle),       '');
  Result.Add('Variation\Rotation slowdown', vtSingle, [], FloatToStr(RotationSlowdown), '');
end;

procedure TPSExpSmoke.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Move\Spread angle')           then SpreadAngle      := StrToIntDef(Properties['Move\Spread angle'],            0);
  if Properties.Valid('Variation\Rotation slowdown') then RotationSlowdown := StrToFloatDef(Properties['Variation\Rotation slowdown'], 0);
end;

function TPSExpSmoke.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh; phi, theta: Single;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentTesselator);
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

procedure TPSExpSmoke.Process;
var i: Integer;
begin
  with TParticlesMesh(CurrentTesselator) do for i := 0 to TotalParticles-1 do with Particles[i] do begin
    Particles[i].Angle := Particles[i].Angle + Trunc(0.5 + Particles[i].Mass);
    Particles[i].Mass := Particles[i].Mass * RotationSlowdown;
  end;

  inherited;
end;

{ T2DFireworks }

procedure T2DFireworks.AddProperties(const Result: TProperties);
var Ang: Integer;
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Explosion\Timeout',     vtInt,    [], IntToStr(HalfPeriod),       '');
  Ang := Trunc(LaunchAngle/pi*180);
  Result.Add('Move\Launch angle',     vtInt,    [], IntToStr(Ang),              '');
  Result.Add('Move\Slowdown',         vtSingle, [], FloatToStr(Slowdown),        '');
  Result.Add('Move\Fall speed',       vtSingle, [], FloatToStr(FallSpeed),       '');
  Result.Add('Variation\Grow speed',  vtSingle, [], FloatToStr(GrowSpeed),       '');
  Result.Add('Variation\Fade speed',  vtSingle, [], FloatToStr(FadeSpeed),       '');
  Result.Add('Explosion\Size',        vtSingle, [], FloatToStr(ExplosionSize),   '');
  Result.Add('Explosion\Density',     vtInt,    [], IntToStr(ExplosionDensity), '');
  Result.Add('Emitter\Radius jitter', vtSingle, [], FloatToStr(RadiusJitter),    '');
  Result.Add('Move\Speed',            vtSingle, [], FloatToStr(Speed),           '');
end;

procedure T2DFireworks.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Explosion\Timeout')     then HalfPeriod       := StrToIntDef(Properties['Explosion\Timeout'],      0);
  if Properties.Valid('Move\Launch angle')     then LaunchAngle      := StrToIntDef(Properties['Move\Launch angle'],      0)/180*pi;
  if Properties.Valid('Move\Slowdown')         then Slowdown         := StrToFloatDef(Properties['Move\Slowdown'],         0);
  if Properties.Valid('Move\Fall speed')       then FallSpeed        := StrToFloatDef(Properties['Move\Fall speed'],       0);
  if Properties.Valid('Variation\Grow speed')  then GrowSpeed        := StrToFloatDef(Properties['Variation\Grow speed'],  0);
  if Properties.Valid('Variation\Fade speed')  then FadeSpeed        := StrToFloatDef(Properties['Variation\Fade speed'],  0);
  if Properties.Valid('Explosion\Size')        then ExplosionSize    := StrToFloatDef(Properties['Explosion\Size'],        0);
  if Properties.Valid('Explosion\Density')     then ExplosionDensity := StrToIntDef(Properties['Explosion\Density'],      0);
  if Properties.Valid('Emitter\Radius jitter') then RadiusJitter     := StrToFloatDef(Properties['Emitter\Radius jitter'], 0);
  if Properties.Valid('Move\Speed')            then Speed            := StrToFloatDef(Properties['Move\Speed'],            0);
end;

function T2DFireworks.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh; rad, theta: Single;
begin
  Result := inherited Emit(Count);

  PMesh := TParticlesMesh(CurrentTesselator);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Position.x := GetAbsLocation.x + TimeProcessed*Speed*COS(LaunchAngle)*0.5;
    Position.y := GetAbsLocation.y - TimeProcessed*Speed*SIN(LaunchAngle)*0.5 - (TimeProcessed*TimeProcessed - TimeProcessed*20) * FallSpeed;

    IF TimeProcessed < HalfPeriod THEN Sprite := 0 ELSE begin    // If Sprite = 0 particle belongs to tale or to explosion otherwise
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

procedure T2DFireworks.Process;
var i: Integer; a: Cardinal;
begin
  with TParticlesMesh(CurrentTesselator) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
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

  IF TimeProcessed < HalfPeriod THEN ParticlesToEmit := 1 else
   if TimeProcessed = HalfPeriod THEN ParticlesToEmit := ExplosionDensity else
    ParticlesToEmit := 0;

  inherited;
end;

procedure T2DFireworks.Start;
begin
  TimeProcessed := 0;
end;

{ TPSAdvSmoke }

procedure TPSAdvSmoke.AddProperties(const Result: TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Variation\Shrink length',     vtNat,    [], IntToStr(ShrinkPeriod),      '');
  Result.Add('Variation\Shrink K',          vtSingle, [], FloatToStr(ShrinkAmount),     '');
  Result.Add('Variation\Rotation slowdown', vtSingle, [], FloatToStr(RotationSlowdown), '');
end;

procedure TPSAdvSmoke.SetProperties(Properties: TProperties);
begin
  inherited;
  if Properties.Valid('Variation\Shrink length')     then ShrinkPeriod     := StrToIntDef(Properties['Variation\Shrink length'],      0);
  if Properties.Valid('Variation\Shrink K')          then ShrinkAmount     := StrToFloatDef(Properties['Variation\Shrink K'],          0);
  if Properties.Valid('Variation\Rotation slowdown') then RotationSlowdown := StrToFloatDef(Properties['Variation\Rotation slowdown'], 0);
end;

function TPSAdvSmoke.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
begin
  Result := inherited Emit(Count);

  PMesh := T3DParticlesMesh(CurrentTesselator);
  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
//    Velocity.y := 0;
    Mass := RotationSpeed * (1 + Random);
    Sprite := 0;
  end;

  UpdateMesh;
end;

procedure TPSAdvSmoke.Process;
var i: Integer; c: Single;
begin
  with TParticlesMesh(CurrentTesselator) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
    Particles[i].Angle := Particles[i].Angle + Trunc(0.5 + Particles[i].Mass);
    Particles[i].Mass := Particles[i].Mass * RotationSlowdown;

    if (Particles[i].Age < GrowInPeriod + ShrinkPeriod) then begin
      if (Particles[i].Age >= GrowInPeriod) then begin
        c := (Particles[i].Age - GrowInPeriod + 1) / ShrinkPeriod;
        Particles[i].Radius := Particles[i].FadeK * (1-c) + Particles[i].FadeK * ShrinkAmount * c;
      end;
    end else Particles[i].Velocity.y := Particles[i].Velocity.y + ElevationSpeed * (1 + 0.3*Random);
  end;

  inherited;
end;

end.
