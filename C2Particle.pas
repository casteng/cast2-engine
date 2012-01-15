(*
 @Abstract(CAST II Engine particles unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains basic particle system classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Particle;

interface

uses
  SysUtils,
  BaseTypes, BaseMsg, ItemMsg, Basics, BaseCont, Props, Base3D, BaseClasses,
  C2Types, CAST2, C2Visual;

const
  ParticlesCapacityStep = 32;

type
  TPSRenderRecord = record
    Position: TVector3s;
    Size: Single;
    Color: BaseTypes.TColor;
    Angle: Single;
    Sprite: Integer;
    Temp: Single;
  end;

  TPSSimulationRecord = record
    Velocity: TVector3s;
    Age: Single;
  end;

  TPSRenderData     = array of TPSRenderRecord;
  TPSSimulationData = array of TPSSimulationRecord;

  TParticleSystem = class(TVisible)
  private
    FMaxCapacity,
    FTotalParticles: Integer;
    FRenderData: TPSRenderData;
    FSimulationData: TPSSimulationData;
//    FRotationSupport: Boolean;
    FDirectionSupport: Boolean;
    function Emit(Count: Integer): Integer;
    procedure SetMaxCapacity(const Value: Integer);
  public
    // Size of biggest particle in the system. Calculated automatically.
    MaxSize: Single;
    { When FastKill is off particles are stored in order of emitting.
      FSimulationData[i].Age >= FSimulationData[i+n].Age is true if starting age of particles is constant for the system.
      With Fastkill mode on particle order is not defined but it's faster. }
    FastKill,
    // New particles are not emitted when DisableEmit is True
    DisableEmit: Boolean;
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    function GetTesselatorClass: CTesselator; override;
    procedure Init; virtual;

    function CalcSortValue(const Camera: TCamera): Single; override;

    procedure SetMesh; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: BaseClasses.Float); override;

    procedure Kill(Index: Integer);
    procedure KillAll;

    property TotalParticles: Integer read FTotalParticles;
    // Maximum number of particles
    property MaxCapacity: Integer read FMaxCapacity write SetMaxCapacity;
    // Particles visualization data
    property RenderData: TPSRenderData read FRenderData;
    // Particles simulation data
    property SimulationData: TPSSimulationData read FSimulationData;
  end;

  TPSAffector = class(CAST2.TProcessing)
  private
    FTotalParticleSystems: Integer;
    procedure SetTotalParticleSystems(Value: Integer); virtual;
  protected
    ParticleSystem: array of TParticleSystem;
    AgeStart, AgeEnd: Single;
    procedure ResolveLinks; override;
    procedure NewParticleSystem(Index: Integer); virtual;                                         // Called when a new particle system is resolved
    procedure CalcPositionInSystem(Index: Integer; var Result: TVector3s);                        // Calculates affector position in particle system coordinates
    procedure TransformToSystem(Index: Integer; const Vector: TVector3s; out Result: TVector3s);  // Transform rthergiven vector into the particle system's frame
    property TotalParticleSystems: Integer read FTotalParticleSystems;
  public
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;
    class function IsAbstract: Boolean; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure SetupExternalVariables; virtual;
  end;

  TEmitter = class(TPSAffector)
  private
    ParticlesToEmit: Single;
    procedure SetTotalParticleSystems(Value: Integer); override;
  protected
    FCurrentTime, CycleK: Single;
    LastEmit: array of record
      Count:    Integer;
      Location: TVector3s;                      // Not guaranteed to be a real last emission location
    end;
    procedure NewParticleSystem(Index: Integer); override;
    procedure ParticleSystemEmit(Index, EmitCount: Integer);
  public
    DefaultSize, UniformInterval, EmitRate, LifeTime, InitialAge: TSampledFloats;
    EmitInLocal: Boolean;
    CycleDuration: Single;
    DefaultColor: TSampledGradient;

    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure HandleMessage(const Msg: TMessage); override;

    // Called immediately after emission of new particles. EmittedStart and EmittedEnd define range of the emitted particles.
    procedure InitParticles(Index, EmittedStart, EmittedEnd: Integer); virtual;

    procedure Emit(Count: Single);

    procedure Process(const DeltaT: BaseClasses.Float); override;
  end;

  TParticleSystemMesh = class(TTesselator)
  public
    ParticleSystem: TParticleSystem;
    constructor Create; override;
    function IsSameItem(AItem: TReferencedItem): Boolean; override;
  end;

  T2DParticlesMesh = class(TParticleSystemMesh)
  private
    ParticlesVisible: Integer;
  public
    ReverseOrder: Boolean;
    constructor Create; override;
//    procedure Init;             // ?
    function GetMaxVertices: Integer; override;
    function GetMaxIndices: Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

  T3DParticlesMesh = class(T2DParticlesMesh)
  public
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  T3DDirParticlesMesh = class(T2DParticlesMesh)
  public
    FMaxLength: Single;
    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

{  T3DAngleParticlesMesh = class(T3DParticlesMesh)
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end; }

  T2DParticleSystem = class(TParticleSystem)
  public
  end;

  T3DParticleSystem = class(TParticleSystem)
  public
    function GetTesselatorClass: CTesselator; override;
  end;
  
  TPSSmoke = class(T3DParticleSystem)
  end;

implementation

{ TParticleSystem }

function TParticleSystem.Emit(Count: Integer): Integer;
// Returns the number of actually added particles

  procedure UpdateMesh;
  var PMesh: TParticleSystemMesh;
  begin
    PMesh := CurrentTesselator as TParticleSystemMesh;
    with PMesh do begin
      TotalVertices := 4;
      TotalPrimitives := 2;
      TotalIndices := TotalParticles*0;
    end;
    CurrentTesselator.Invalidate([tbVertex, tbIndex], True);
  end;

begin
  Result := FTotalParticles;
  FTotalParticles := MinI(FTotalParticles + Count, FMaxCapacity);
  if Length(FRenderData) < FTotalParticles then begin
    SetLength(FRenderData,     GetSteppedSize(FTotalParticles, ParticlesCapacityStep));
    SetLength(FSimulationData, Length(FRenderData));
  end;

  Result := FTotalParticles - Result;

//  UpdateMesh;

  Assert(Result >= 0);
end;

procedure TParticleSystem.SetMaxCapacity(const Value: Integer);
begin
  FMaxCapacity := Value;
  FTotalParticles := MinI(FTotalParticles, FMaxCapacity);
  if Length(FRenderData) > FMaxCapacity then begin
    SetLength(FRenderData,     FMaxCapacity);
    SetLength(FSimulationData, FMaxCapacity);
  end;
end;

constructor TParticleSystem.Create(AManager: TItemsManager);
begin
  inherited;
  FastKill         := True;
  DisableEmit      := False;
  FMaxCapacity     := 2048;
  FTotalParticles  := 0;
  SetLength(FRenderData,     ParticlesCapacityStep);
  SetLength(FSimulationData, ParticlesCapacityStep);
end;

destructor TParticleSystem.Destroy;
begin
  FRenderData     := nil;
  FSimulationData := nil;
  inherited;
end;

function TParticleSystem.GetTesselatorClass: CTesselator; begin Result := T2DParticlesMesh end;

procedure TParticleSystem.Init;
var i: Integer;
begin
  inherited;
  for i := 0 to TotalChilds-1 do if Childs[i] is TParticleSystem then (Childs[i] as TParticleSystem).Init;
  DisableEmit := False;
end;

function TParticleSystem.CalcSortValue(const Camera: TCamera): Single;
var P: TVector3s;
begin
  P.X := (BoundingBox.P1.X + BoundingBox.P2.X) * 0.5;
  P.Y := (BoundingBox.P1.Y + BoundingBox.P2.Y) * 0.5;
  P.Z := (BoundingBox.P1.Z + BoundingBox.P2.Z) * 0.5;
  SortValue := SqrMagnitude(SubVector3s(Camera.GetAbsLocation, ModelToWorld(P)));
  Result    := SortValue;
end;

procedure TParticleSystem.SetMesh;
begin
  inherited;
//  if CurrentTesselator is TParticleSystemMesh then begin
  (CurrentTesselator as TParticleSystemMesh).ParticleSystem := Self;
//  end;
end;

procedure TParticleSystem.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Current',           vtNat,     [poReadonly], IntToStr(TotalParticles),   '');
  Result.Add('Max',               vtNat,     [],           IntToStr(MaxCapacity),      '');
//  Result.Add('Rotation support',  vtBoolean, [],           OnOffStr[FRotationSupport], '');
  Result.Add('Direction support', vtBoolean, [],           OnOffStr[FDirectionSupport], '');
  Result.Add('Fast killing',      vtBoolean, [],           OnOffStr[FastKill],         '');
//  Result.Add('Reverse order',     vtBoolean, [],           OnOffStr[T2DParticlesMesh(CurrentTesselator).ReverseOrder], '');   //ToDo: eliminate mesh request
end;

procedure TParticleSystem.SetProperties(Properties: Props.TProperties);
begin
  if Properties.Valid('Direction support') then begin
    FDirectionSupport := Properties.GetAsInteger('Direction support') > 0;
    SetMesh();
  end;  
  inherited;
  if Properties.Valid('Max')               then MaxCapacity := StrToIntDef(Properties['Max'], 0);
//  if Properties.Valid('Rotation support')  then FRotationSupport  := Properties.GetAsInteger('Rotation support')  > 0;
  
  if Properties.Valid('Fast killing')      then FastKill          := Properties.GetAsInteger('Fast killing')      > 0;
//  if Properties.Valid('Reverse order')     then T2DParticlesMesh(CurrentTesselator).ReverseOrder := Properties.GetAsInteger('Reverse order') > 0;
  ResetProcessedTime;
end;

procedure TParticleSystem.Kill(Index: Integer);
var i: Integer;
begin
  Assert((Index >= 0) and (Index < FTotalParticles));
  if Assigned(CurrentTesselator) then CurrentTesselator.Invalidate([tbVertex, tbIndex], False);
  Dec(FTotalParticles);
  if Index = FTotalParticles then Exit;
  if FastKill then begin
    FRenderData[Index]     := FRenderData[FTotalParticles];
    FSimulationData[Index] := FSimulationData[FTotalParticles];
  end else for i := Index+1 to FTotalParticles do begin
    FRenderData[i-1]     := FRenderData[i];
    FSimulationData[i-1] := FSimulationData[i];
  end;
end;

procedure TParticleSystem.KillAll;
begin
  if FTotalParticles = 0 then Exit;
  if Assigned(CurrentTesselator) then CurrentTesselator.Invalidate([tbVertex, tbIndex], True);
  FTotalParticles := 0;
end;

procedure TParticleSystem.Process(const DeltaT: BaseClasses.Float);
begin
  inherited;
  MaxSize := 0;
end;

{ TParticleSystemMesh }

constructor TParticleSystemMesh.Create;
begin
  inherited;
  TesselationStatus[tbVertex].TesselatorType := ttDynamic;
  TesselationStatus[tbIndex].TesselatorType  := ttDynamic;
end;

function TParticleSystemMesh.IsSameItem(AItem: TReferencedItem): Boolean;
begin
  Result := False;
end;

{ T2DParticlesMesh }

constructor T2DParticlesMesh.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLELIST;
//  PrimitiveType := ptTRIANGLESTRIP;
//  InitVertexFormat(GetVertexFormat(True, False, True, False, False, 0, [2]));
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));

  ReverseOrder := True;
end;

{procedure T2DParticlesMesh.Init;
begin
  if not Assigned(ParticleSystem) then Exit;
  TotalVertices   := ParticleSystem.TotalParticles*4;
  TotalPrimitives := ParticleSystem.TotalParticles*2;
  TotalIndices    := ParticleSystem.TotalParticles*6;
  Invalidate(True);
end;}

function T2DParticlesMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer; Transformed: TVector4s; TRHW: Single;
begin
  Result := 0;
  LastTotalVertices := 0;
  if not Assigned(ParticleSystem) then Exit;

  Transformed := GetVector4s(0, 0, ParticleSystem.Transform._43, 1); //Transform4Vector3s(RenderPars.TotalMatrix, Location);
  if Transformed.W < 0 then Exit;
  TRHW := 0.001;//1/Transformed.W;
  Transformed.X := {RenderPars.ActualWidth shr 1 + RenderPars.ActualWidth shr 1*}Transformed.X;
  Transformed.Y := {RenderPars.ActualHeight shr 1 - RenderPars.ActualHeight shr 1*}Transformed.Y;
//  with RenderPars do Transformed.Z := 0*(ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));
  for i := 0 to ParticleSystem.TotalParticles-1 do with ParticleSystem.FRenderData[i] do begin
    SetVertexDataCRHW(Transformed.X + (Position.X - Size*0.5), Transformed.Y - Position.Y - Size*0.5, Transformed.Z, TRHW, i*4, VBPTR);
    SetVertexDataUV(0, 0,  i*4, VBPTR);
    SetVertexDataD (Color, i*4, VBPTR);

    SetVertexDataCRHW(Transformed.X + (Position.X + Size*0.5), Transformed.Y - Position.Y - Size*0.5, Transformed.Z, TRHW, i*4+1, VBPTR);
    SetVertexDataUV(1, 0,  i*4+1, VBPTR);
    SetVertexDataD (Color, i*4+1, VBPTR);

    SetVertexDataCRHW(Transformed.X + (Position.X + Size*0.5), Transformed.Y - Position.Y + Size*0.5, Transformed.Z, TRHW, i*4+2, VBPTR);
    SetVertexDataUV(1, 1,  i*4+2, VBPTR);
    SetVertexDataD (Color, i*4+2, VBPTR);

    SetVertexDataCRHW(Transformed.X + (Position.X - Size*0.5), Transformed.Y - Position.Y + Size*0.5, Transformed.Z, TRHW, i*4+3, VBPTR);
    SetVertexDataUV(0, 1,  i*4+3, VBPTR);
    SetVertexDataD (Color, i*4+3, VBPTR);
  end;
  TotalVertices     := ParticleSystem.TotalParticles*4; TotalPrimitives := ParticleSystem.TotalParticles*2;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;
  ParticlesVisible  := ParticleSystem.TotalParticles;
  Result            := TotalVertices;
  
  TesselationStatus[tbVertex].Status := tsMaxSizeChanged;
end;

function T2DParticlesMesh.SetIndices(IBPTR: Pointer): Integer;
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
  TesselationStatus[tbIndex].Status := tsTesselated;
  TesselationStatus[tbIndex].Status := tsMaxSizeChanged;
  Result := TotalIndices;
end;

function T2DParticlesMesh.GetMaxVertices: Integer;
begin
//  Result := MaxI(1, TotalVertices);
  Result := ParticleSystem.TotalParticles*4;
end;

function T2DParticlesMesh.GetMaxIndices: Integer;
begin
//  Result := TotalIndices;
  Result := ParticleSystem.TotalParticles*6;
end;

{ T3DParticlesMesh }

function T3DParticlesMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer; TCamRight, TCamUp, OTCamRight, OTCamUp: TVector3s; Rotation: TMatrix3s;
begin
  Result := 0;
  LastTotalVertices := 0;
  if not Assigned(ParticleSystem) then Exit;
//  Matrix := MulMatrix4s(RenderPars.WorldMatrix, RenderPars.TotalMatrix);
  ParticlesVisible := 0;
  Rotation := CutMatrix3s(ParticleSystem.Transform);
  OTCamRight := Transform3Vector3sTransp(Rotation, Params.Camera.RightVector);
  OTCamUp    := Transform3Vector3sTransp(Rotation, Params.Camera.UpVector);

  for i := 0 to ParticleSystem.TotalParticles-1 do with ParticleSystem.FRenderData[i] do begin
        // Temporary implementation
        OTCamRight := Transform3Vector3s(ZRotationMatrix3s(Angle), Vec3s(1, 0, 0));
        OTCamUp    := Transform3Vector3s(ZRotationMatrix3s(Angle), Vec3s(0, 1, 0));

        TCamRight := Transform3Vector3s(GetTransposedMatrix3s(CutMatrix3s(Params.Camera.ViewMatrix)), OTCamRight);
        TCamUp    := Transform3Vector3s(GetTransposedMatrix3s(CutMatrix3s(Params.Camera.ViewMatrix)), OTCamUp);

        TCamRight := Transform3Vector3sTransp(Rotation, TCamRight);
        TCamUp    := Transform3Vector3sTransp(Rotation, TCamUp);

    SetVertexDataC(Position.X + (-TCamRight.X - TCamUp.X) * Size,
                   Position.Y + (-TCamRight.Y - TCamUp.Y) * Size,
                   Position.Z + (-TCamRight.Z - TCamUp.Z) * Size,
                   ParticlesVisible*4+3, VBPTR);
    SetVertexDataUV(0, 0, ParticlesVisible*4+3, VBPTR);
    SetVertexDataD(Color, ParticlesVisible*4+3, VBPTR);

    SetVertexDataC(Position.X + (TCamRight.X - TCamUp.X) * Size,
                   Position.Y + (TCamRight.Y - TCamUp.Y) * Size,
                   Position.Z + (TCamRight.Z - TCamUp.Z) * Size,
                   ParticlesVisible*4+2, VBPTR);
    SetVertexDataUV(1, 0, ParticlesVisible*4+2, VBPTR);
    SetVertexDataD(Color, ParticlesVisible*4+2, VBPTR);

    SetVertexDataC(Position.X + (TCamRight.X + TCamUp.X) * Size,
                   Position.Y + (TCamRight.Y + TCamUp.Y) * Size,
                   Position.Z + (TCamRight.Z + TCamUp.Z) * Size,
                   ParticlesVisible*4+1, VBPTR);
    SetVertexDataUV(1, 1, ParticlesVisible*4+1, VBPTR);
    SetVertexDataD(Color, ParticlesVisible*4+1, VBPTR);

    SetVertexDataC(Position.X + (-TCamRight.X + TCamUp.X) * Size,
                   Position.Y + (-TCamRight.Y + TCamUp.Y) * Size,
                   Position.Z + (-TCamRight.Z + TCamUp.Z) * Size,
                   ParticlesVisible*4, VBPTR);
    SetVertexDataUV(0, 1, ParticlesVisible*4, VBPTR);
    SetVertexDataD(Color, ParticlesVisible*4, VBPTR);

    Inc(ParticlesVisible);
  end;
  TotalVertices     := ParticlesVisible*4;
  TotalPrimitives   := ParticlesVisible*2;
  Result            := TotalVertices;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;

  TesselationStatus[tbVertex].Status := tsMaxSizeChanged;
end;

{ T3DDirParticlesMesh }

procedure T3DDirParticlesMesh.AddProperties(const Result: TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  Result.Add(PropNamePrefix + 'Max length', vtSingle, [], FloatToStr(FMaxLength), '1-20');
end;

procedure T3DDirParticlesMesh.SetProperties(Properties: TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid(PropNamePrefix + 'Max length') then FMaxLength := StrToFloatDef(Properties[PropNamePrefix + 'Max length'], 1);
end;

function T3DDirParticlesMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  i: Integer;
  Trans1, Trans2: TVector4s;
  V, N, Cam: TVector3s;
  l: Single;
  Point1, Point2: TVector4s;
begin
  Result := 0;
  LastTotalVertices := 0;
  if not Assigned(ParticleSystem) then Exit;

  ParticlesVisible := 0;

  for i := 0 to ParticleSystem.TotalParticles-1 do with ParticleSystem.FRenderData[i] do begin
    Cam := Params.Camera.GetAbsLocation;

    l := SqrMagnitude(ParticleSystem.FSimulationData[i].Velocity);
    if l > Sqr(FMaxLength) then l := FMaxLength*InvSqrt(l) else l := 1;

    Point1 := ExpandVector3s(Position);
//    Point2 := ExpandVector3s(ParticleSystem.FRenderData[MinI(ParticleSystem.TotalParticles-1, i+1)].Position);
    Point2 := ExpandVector3s(AddVector3s(Position, ScaleVector3s(ParticleSystem.FSimulationData[i].Velocity, l)));
    Trans1 := Transform4Vector4s(Params.ModelMatrix, Point1);
    Trans2 := Transform4Vector4s(Params.ModelMatrix, Point2);

    N := SubVector4s(Trans2, Trans1).XYZ;                                   // Line vector in world
    V := GetVector3s(- Trans1.X + Cam.X, - Trans1.Y + Cam.Y, - Trans1.Z + Cam.Z);    // From Point1 to camera
    N := CrossProductVector3s(V, N);
    l := SqrMagnitude(N);
//    N :=
    N := Transform3Vector3s(InvertMatrix3s(CutMatrix3s(Params.ModelMatrix)), N);
    l := InvSqrt(l);

    SetVertexDataC(Point1.X - N.X * l * Size, Point1.Y - N.Y * l * Size, Point1.Z - N.Z * l * Size, ParticlesVisible*4+0, VBPtr);
    SetVertexDataD(Color, ParticlesVisible*4+0, VBPtr);
    SetVertexDataUV(0, 0, ParticlesVisible*4+0, VBPtr);

    SetVertexDataC(Point2.X - N.X * l * Size, Point2.Y - N.Y * l * Size, Point2.Z - N.Z * l * Size, ParticlesVisible*4+1, VBPtr);
    SetVertexDataD(Color, ParticlesVisible*4+1, VBPtr);
    SetVertexDataUV(1, 0, ParticlesVisible*4+1, VBPtr);

    SetVertexDataC(Point2.X + N.X * l * Size, Point2.Y + N.Y * l * Size, Point2.Z + N.Z * l * Size, ParticlesVisible*4+2, VBPtr);
    SetVertexDataD(Color, ParticlesVisible*4+2, VBPtr);
    SetVertexDataUV(1, 1, ParticlesVisible*4+2, VBPtr);

    SetVertexDataC(Point1.X + N.X * l * Size, Point1.Y + N.Y * l * Size, Point1.Z + N.Z * l * Size, ParticlesVisible*4+3, VBPtr);
    SetVertexDataD(Color, ParticlesVisible*4+3, VBPtr);
    SetVertexDataUV(0, 1, ParticlesVisible*4+3, VBPtr);

    Inc(ParticlesVisible);
  end;

  TotalVertices     := ParticlesVisible*4;
  TotalPrimitives   := ParticlesVisible*2;
  Result            := TotalVertices;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;

  TesselationStatus[tbVertex].Status := tsMaxSizeChanged;
end;

{ T2DParticleSystem }

{ T3DParticleSystem }

function T3DParticleSystem.GetTesselatorClass: CTesselator;
begin
  if FDirectionSupport then
    Result := T3DDirParticlesMesh
  else
    Result := T3DParticlesMesh
end;

{ TPSAffector }

procedure TPSAffector.NewParticleSystem(Index: Integer);
begin
end;

procedure TPSAffector.SetTotalParticleSystems(Value: Integer);
begin
  FTotalParticleSystems := Value;
  if Length(ParticleSystem) < FTotalParticleSystems then
    SetLength(ParticleSystem, FTotalParticleSystems);
  BuildItemLinks;
end;

destructor TPSAffector.Destroy;
begin
  SetLength(ParticleSystem, 0);
  inherited;
end;

class function TPSAffector.IsAbstract: Boolean;
begin
  Result := Self = TPSAffector;
end;

procedure TPSAffector.ResolveLinks;
var i: Integer; Item: TItem;
begin
  inherited;

  for i := 0 to FTotalParticleSystems-1 do begin
    ResolveLink(Format('System #%D', [i]), Item);
    if Assigned(Item) then begin
      ParticleSystem[i] := Item as TParticleSystem;
      NewParticleSystem(i);
    end;
  end;
end;

procedure TPSAffector.CalcPositionInSystem(Index: Integer; var Result: TVector3s);
begin   
  Assert((Index >= 0) and (Index < FTotalParticleSystems) and Assigned(ParticleSystem[Index]), ClassName + '.CalcPositionInSystem: Invalid particle system');
  SubVector3s(Result, GetAbsLocation, ParticleSystem[Index].GetAbsLocation);
  Result := Transform3Vector3sTransp(CutMatrix3s(ParticleSystem[Index].Transform), Result);
end;

procedure TPSAffector.TransformToSystem(Index: Integer; const Vector: TVector3s; out Result: TVector3s);
begin
  Assert((Index >= 0) and (Index < FTotalParticleSystems) and Assigned(ParticleSystem[Index]), ClassName + '.CalcPositionInSystem: Invalid particle system');
  Transform4Vector33s(Result, MulMatrix4s(Transform, InvertRotTransMatrix(ParticleSystem[Index].Transform)), Vector);
end;

constructor TPSAffector.Create(AManager: TItemsManager);
begin
  inherited;
  AgeEnd := MaxFloatValue;
end;

procedure TPSAffector.AddProperties(const Result: Props.TProperties);
var i: Integer;
begin
  inherited;

  if Assigned(Result) then begin
    Result.Add('Systems affected', vtInt,    [], IntToStr(FTotalParticleSystems), '');
    Result.Add('Starting age',     vtSingle, [], FloatToStr(AgeStart),            '');
    Result.Add('Ending age',       vtSingle, [], FloatToStr(AgeEnd),              '');
  end;

  for i := 0 to FTotalParticleSystems-1 do
    AddItemLink(Result, Format('System #%D', [i]), [], 'TParticleSystem');
end;

procedure TPSAffector.SetProperties(Properties: Props.TProperties);
var i: Integer;
begin
  inherited;

  if Properties.Valid('Systems affected') then SetTotalParticleSystems(StrToIntDef(Properties['Systems affected'], 0));

  for i := 0 to FTotalParticleSystems-1 do if Properties.Valid(Format('System #%D', [i])) then
    SetLinkProperty(Format('System #%D', [i]), Properties[Format('System #%D', [i])]);

  ResolveLinks;

  if Properties.Valid('Starting age') then AgeStart := StrToFloatDef(Properties['Starting age'], 0);
  if Properties.Valid('Ending age')   then AgeEnd   := StrToFloatDef(Properties['Ending age'],   0);
end;

procedure TPSAffector.SetupExternalVariables;
begin
  inherited;
{$IFDEF SCRIPTING}
  World.Compiler.ImportExternalVar('DefaultColor',    'LONGINT',    @DefaultColor);
  World.Compiler.ImportExternalVar('DefaultRadius',   'SINGLE',     @DefaultRadius);
  World.Compiler.ImportExternalVar('TotalParticles',  'LONGINT',    @T3DParticlesMesh(CurrentTesselator).TotalParticles);
  World.Compiler.ImportExternalVar('Particles',       'TParticles', @T3DParticlesMesh(CurrentTesselator).Particles[0]);
  World.Compiler.ImportExternalVar('ParticlesToEmit', 'LONGINT',    @ParticlesToEmit);
{$ENDIF}
end;

{ TEmitter }

procedure TEmitter.SetTotalParticleSystems(Value: Integer);
begin
  inherited;
  if Length(LastEmit) < FTotalParticleSystems then SetLength(LastEmit, FTotalParticleSystems);
end;

procedure TEmitter.NewParticleSystem(Index: Integer);
begin
  inherited;
  LastEmit[Index].Count := 0;
  CalcPositionInSystem(Index, LastEmit[Index].Location);
end;

procedure TEmitter.ParticleSystemEmit(Index, EmitCount: Integer);
begin
  if not Assigned(ParticleSystem[Index]) or ParticleSystem[Index].DisableEmit or
     not (isProcessing in ParticleSystem[Index].State) then Exit;

//  {$IFDEF DEBUGMODE} Assert(LastEmit[Index].Count = 0, ClassName + '.ParticleSystemEmit: Duplicate ParticleSystemEmit() call'); {$ENDIF}
  LastEmit[Index].Count := 0;
  if EmitCount > 0 then LastEmit[Index].Count := ParticleSystem[Index].Emit(EmitCount);
end;

constructor TEmitter.Create(AManager: TItemsManager);
begin
  inherited;

  DefaultColor := TSampledGradient.Create;

  DefaultSize     := TSampledFloats.Create;
  UniformInterval := TSampledFloats.Create;
  EmitRate        := TSampledFloats.Create;
  LifeTime        := TSampledFloats.Create;
  InitialAge      := TSampledFloats.Create;

  DefaultSize.MaxY := 1000;
  EmitRate.MaxY    := 1000;
  LifeTime.MaxY    := 100;
  InitialAge.MaxY  := 60;

  DefaultSize.DefaultValue := 1;
  DefaultSize.Reset();
  UniformInterval.DefaultValue := 0.1;
  UniformInterval.Reset();
  EmitRate.DefaultValue := 10;
  EmitRate.Reset();
  LifeTime.DefaultValue := 10;
  LifeTime.Reset();
  InitialAge.DefaultValue := 0;
  InitialAge.Reset();

  CycleDuration := 2;
end;

destructor TEmitter.Destroy;
begin
  SetLength(LastEmit, 0);
  FreeAndNil(DefaultColor);
  FreeAndNil(DefaultSize);
  FreeAndNil(UniformInterval);
  FreeAndNil(EmitRate);
  FreeAndNil(LifeTime);
  FreeAndNil(InitialAge);
  inherited;
end;

procedure TEmitter.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
//  AddColorProperty(Result, 'Default\Color', DefaultColor);

  Result.Add('Cycle duration',    vtSingle, [],       FloatToStr(CycleDuration),   '');

//  Result.Add('Default\Size',      vtSingle, [],       FloatToStr(DefaultRadius),   '');
//  Result.Add('Default\Lifetime',  vtNat,    [],       IntToStr(DefaultLifetime),   '');

  Result.Add('Local coordinates', vtBoolean, [], OnOffStr[EmitInLocal], '');

  Result.Add('Instant emit',      vtNat,     [], '1',                       '');
//  Result.Add('Rate',              vtSingle,  [], FloatToStr(Rate),          '');
//  Result.Add('Uniform',           vtBoolean, [], OnOffStr[UniformEmit],     '');

  DefaultColor.AddAsProperty(Result, 'Default\Color');

  EmitRate.       AddAsProperty(Result, 'Rate');
  DefaultSize.    AddAsProperty(Result, 'Default\Size');
//  LifeTime.       AddAsProperty(Result, 'Default\Lifetime');
  InitialAge.     AddAsProperty(Result, 'Initial age');
  UniformInterval.AddAsProperty(Result, 'Uniform\Interval');
end;

procedure TEmitter.SetProperties(Properties: Props.TProperties);
begin
  inherited;

  if Properties.Valid('Cycle duration') then CycleDuration := StrToFloatDef(Properties['Cycle duration'], 0);

//  SetColorProperty(Properties, 'Default\Color', DefaultColor);
//  if Properties.Valid('')      then DefaultRadius    := StrToFloatDef(Properties['Default\Size'],   0);
//  if Properties.Valid('Default\Lifetime')  then DefaultLifetime  := StrToIntDef(Properties['Default\Lifetime'], 0);

  if Properties.Valid('Local coordinates') then EmitInLocal := Properties.GetAsInteger('Local coordinates') > 0;

//  if Properties.Valid('Rate')              then Rate          := StrToFloatDef(Properties['Rate'], 0);
//  if Properties.Valid('Uniform')           then UniformEmit   := Properties.GetAsInteger('Uniform') > 0;

  if Properties.Valid('Instant emit')      then Emit(StrToIntDef(Properties['Instant emit'], 0));

  DefaultColor.SetFromProperty(Properties, 'Default\Color');

  EmitRate.SetFromProperty(Properties, 'Rate');
  DefaultSize.SetFromProperty(Properties, 'Default\Size');
//  LifeTime.SetFromProperty(Properties, 'Default\Lifetime');
  InitialAge.SetFromProperty(Properties, 'Initial age');
  UniformInterval.SetFromProperty(Properties, 'Uniform\Interval');
end;

procedure TEmitter.HandleMessage(const Msg: TMessage);
begin
  inherited;
  if Msg.ClassType = TSyncTimeMsg then
    FCurrentTime := 0;
end;

procedure TEmitter.InitParticles(Index, EmittedStart, EmittedEnd: Integer);
var
  i: Integer;
  DefSize: Single;
  DefColor: TColor;
begin
  if DefaultSize.Enabled then
    DefSize := DefaultSize.Value[CycleK]
  else
    DefSize := DefaultSize.DefaultValue;

  if DefaultColor.Enabled then
    DefColor := DefaultColor.Value[CycleK]
  else
    DefColor.C := $80808080;

  for i := EmittedEnd downto EmittedStart do begin       // ToDo: Make independent of data structures used
    with ParticleSystem[Index].FRenderData[i] do begin
//      Position := EmitterInSystem;
      Size   := DefSize;
      Color    := DefColor;
      Angle    := 0;
      Sprite   := 0;
    end;
    if InitialAge.Enabled then ParticleSystem[Index].FSimulationData[i].Age := InitialAge.Value[CycleK];
  end;
end;

procedure TEmitter.Emit(Count: Single);
var
  i, Index, EmitCount: Integer;
  EmitterInSystem, UniformPath: TVector3s;
  UniformEmitCount, K, KIncr, InvUniformRadius: Single;
  UniformEmit: Boolean;

begin
  ParticlesToEmit := ParticlesToEmit + Count;

  InvUniformRadius := UniformInterval.Value[CycleK];
  if Abs(InvUniformRadius) > epsilon then InvUniformRadius := 1/InvUniformRadius else InvUniformRadius := MaxFloatValue;

  UniformEmit := UniformInterval.Enabled;

  for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and //(ParticleSystem[Index].FTotalParticles > 0) and
       not ParticleSystem[Index].DisableEmit and (isProcessing in ParticleSystem[Index].State) then begin

      if EmitInLocal then EmitterInSystem := GetVector3s(0, 0, 0) else CalcPositionInSystem(Index, EmitterInSystem);

      if UniformEmit then begin
        UniformEmitCount := Sqrt(SqrMagnitude(SubVector3s(EmitterInSystem, LastEmit[Index].Location))) * InvUniformRadius;
        EmitCount := Trunc(MinS(ParticleSystem[Index].MaxCapacity, MaxS(ParticlesToEmit, UniformEmitCount)));

        SubVector3s(UniformPath, EmitterInSystem, LastEmit[Index].Location);
        if UniformEmitCount < 1 then
          LastEmit[Index].Location := SubVector3s(LastEmit[Index].Location, SubVector3s(EmitterInSystem, LastEmit[Index].Location))
        else
          LastEmit[Index].Location := EmitterInSystem;
      end else EmitCount := Trunc(ParticlesToEmit);

      ParticleSystemEmit(Index, EmitCount);
      if LastEmit[Index].Count > 0 then begin
        K := 0;
        KIncr := 1 / LastEmit[Index].Count;
        for i := ParticleSystem[Index].TotalParticles-1 downto ParticleSystem[Index].TotalParticles-LastEmit[Index].Count do begin       // ToDo: Make independent of data structures used
          with ParticleSystem[Index].FRenderData[i] do begin
            Position := EmitterInSystem;
            Size   := 0;
            Color.C  := 0;
            Angle    := 0;
            Sprite   := 0;
            if UniformEmit then SubVector3s(Position, Position, ScaleVector3s(UniformPath, K));
            K := K + KIncr;
          end;
          ParticleSystem[Index].FSimulationData[i].Age := 0;
        end;
        InitParticles(Index, ParticleSystem[Index].TotalParticles-LastEmit[Index].Count, ParticleSystem[Index].TotalParticles-1);
      end;
//      if LastEmit[Index].Count > 0 then
//        FillChar(ParticleSystem[Index].FSimulationData[ParticleSystem[Index].TotalParticles-LastEmit[Index].Count], LastEmit[Index].Count * SizeOf(TPSSimulationRecord), 0);
  end;

  ParticlesToEmit := ParticlesToEmit - Trunc(ParticlesToEmit);
end;

procedure TEmitter.Process(const DeltaT: BaseClasses.Float);
{$IFDEF DEBUGMODE} var Index: Integer; {$ENDIF}
begin
  inherited;

  FCurrentTime := FCurrentTime + DeltaT;
  if FCurrentTime > CycleDuration then
    FCurrentTime := FCurrentTime - CycleDuration;

  if CycleDuration > epsilon then
    CycleK := FCurrentTime / CycleDuration
  else
    CycleK := 0;

  if EmitRate.Enabled then Emit(EmitRate.Value[CycleK] * DeltaT);   // Emit ParticlesToEmit number of particles
  {$IFDEF DEBUGMODE}                                                // Zero out last emit counter to avoid emit duplication errors
  for Index := 0 to TotalParticleSystems-1 do LastEmit[Index].Count := 0;
  {$ENDIF}
end;

end.
