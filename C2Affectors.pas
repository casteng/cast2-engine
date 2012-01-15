(*
 @Abstract(CAST II Engine affectors unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: 08.01.2007 <br>
 Unit contains basic affectors and emitters for particle systems
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Affectors;

interface

uses
  SysUtils,
  BaseTypes, Basics, BaseCont, Props, Base3D, BaseClasses,
  CAST2, C2Particle;

type
  TPSMover = class(C2Particle.TPSAffector)
    procedure Process(const DeltaT: BaseClasses.Float); override;
  end;

  TRangedAffector = class(C2Particle.TPSAffector)
    Range: Single;
    constructor Create(AManager: TItemsManager); override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TPSAttractor = class(TRangedAffector)
    MinRange, Intensity: Single;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: BaseClasses.Float); override;
  end;

  TPSAbsorber = class(TRangedAffector)
    Intensity: Single;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: BaseClasses.Float); override;
  end;

  TPSColorInterpolator = class(C2Particle.TPSAffector)
  public
    Colors: TSampledGradient;
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: BaseClasses.Float); override;
  end;

  TPSForce = class(TRangedAffector)
    Force: TVector3s;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: BaseClasses.Float); override;
  end;

  TSphericalEmitter = class(C2Particle.TEmitter)
  public
    Tangent: Boolean;
    PhiRange ,ThetaRange,
    EmitMinRadius, EmitMaxRadius, MinSpeed, MaxSpeed: TSampledFloats;
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure InitParticles(Index, EmittedStart, EmittedEnd: Integer); override;
  end;

  TPSUniAffector = class(C2Particle.TPSAffector)
  protected
    FColor: TSampledGradient;
    FSizeModulator, FForceModulator, FSpeedModulator, FAngle: TSampledFloats;
  public
    Force: TVector3s;
    LifeTime: Single;

    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: BaseClasses.Float); override;

    property Color: TSampledGradient read FColor;
    property SizeModulator: TSampledFloats read FSizeModulator;
    property ForceModulator: TSampledFloats read FForceModulator;
    property Angle: TSampledFloats read FAngle;
  end;

  // Affector which moves partciles of affected system into places of particles of source system. This can be used to emulate sub-emitters.
  TSubEmitter = class(TSphericalEmitter)
  protected
    FSourceSystem: TParticleSystem;
    procedure ResolveLinks; override;
  public
    // Age range of source particle which should cause emit
    SrcAgeStart, SrcAgeEnd: Single;
    // Determines if need to kill source particle when emitting from it
    KillSource: Boolean;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure InitParticles(Index, EmittedStart, EmittedEnd: Integer); override;
  end;

  TPSRandomAffector = class(C2Particle.TPSAffector)
  public
    Color, Size, Coords, Speed, PAge, Angle: TSampledFloats;
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: BaseClasses.Float); override;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TParticleSystem, T2DParticleSystem, T3DParticleSystem,
                          TEmitter, TSphericalEmitter, TSubEmitter,
                          TPSAffector, TPSMover, TPSAttractor, TPSAbsorber, TPSColorInterpolator, TPSForce, TPSUniAffector, TPSRandomAffector
                          ]);
end;

{ TPSMover }

procedure TPSMover.Process(const DeltaT: BaseClasses.Float);
var Index, i: Integer;

  procedure CheckBBox(const Coord: TVector3s);
  begin
    with ParticleSystem[Index] do begin
      BoundingBox.P1.X := MinS(BoundingBox.P1.X, Coord.X - MaxSize);
      BoundingBox.P1.Y := MinS(BoundingBox.P1.Y, Coord.Y - MaxSize);
      BoundingBox.P1.Z := MinS(BoundingBox.P1.Z, Coord.Z - MaxSize);
      BoundingBox.P2.X := MaxS(BoundingBox.P2.X, Coord.X + MaxSize);
      BoundingBox.P2.Y := MaxS(BoundingBox.P2.Y, Coord.Y + MaxSize);
      BoundingBox.P2.Z := MaxS(BoundingBox.P2.Z, Coord.Z + MaxSize);
    end;
  end;

begin
  inherited;
  for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and (isProcessing in ParticleSystem[Index].State) then begin
//    ParticleSystem[Index].BoundingBox.P1 := GetVector3s(MaxFloatValue, MaxFloatValue, MaxFloatValue);
//    ParticleSystem[Index].BoundingBox.P2 := GetVector3s(-MaxFloatValue, -MaxFloatValue, -MaxFloatValue);

    for i := ParticleSystem[Index].TotalParticles-1 downto 0 do with ParticleSystem[Index].SimulationData[i] do
      if (Age >= AgeStart) and (Age < AgeEnd) then with ParticleSystem[Index].RenderData[i] do begin
        AddVector3s(Position, Position, ScaleVector3s(Velocity, DeltaT));
        Age := Age + DeltaT;
        if ParticleSystem[Index].MaxSize < Size*0.5 then ParticleSystem[Index].MaxSize := Size*0.5;
        CheckBBox(Position);
      end;
  end;
end;

{ TPSAttractor }

procedure TPSAttractor.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Min. range',  vtSingle,  [], FloatToStr(MinRange),  '');
  Result.Add('Intensity',   vtSingle,  [], FloatToStr(Intensity), '');
end;

procedure TPSAttractor.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid('Min. range')  then MinRange    := StrToFloatDef(Properties['Min. range'],  0);
  if Properties.Valid('Intensity')   then Intensity   := StrToFloatDef(Properties['Intensity'],   0);
end;

procedure TPSAttractor.Process(const DeltaT: BaseClasses.Float);
var i, Index: Integer; SystemAffector, ParticleAffector: TVector3s; Dist: Single;
begin
  inherited;
  for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and (isProcessing in ParticleSystem[Index].State) then begin

    CalcPositionInSystem(Index, SystemAffector);

    for i := ParticleSystem[Index].TotalParticles-1 downto 0 do
      with ParticleSystem[Index].SimulationData[i] do if (Age >= AgeStart) and (Age < AgeEnd) then begin
        SubVector3s(ParticleAffector, SystemAffector, ParticleSystem[Index].RenderData[i].Position);
        Dist := MaxS(Sqr(MinRange), SqrMagnitude(ParticleAffector));
        if Dist < Sqr(Range) then begin
    //      Dist := InvSqrt(Dist);
    //      if Attenuation then AttractionPower := Intensity * Dist else AttractionPower := Intensity;
          AddVector3s(Velocity, Velocity, ScaleVector3s(ParticleAffector, Intensity * DeltaT / Dist));
        end;
      end;
  end;
end;

{ TRangedAffector }

constructor TRangedAffector.Create(AManager: TItemsManager);
begin
  inherited;
  Range := MaxFloatValue;
end;

procedure TRangedAffector.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Range', vtSingle, [], FloatToStr(Range), '');
end;

procedure TRangedAffector.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid('Range') then Range := StrToFloatDef(Properties['Range'], 0);
end;

{ TPSAbsorber }

procedure TPSAbsorber.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Intensity', vtSingle, [], FloatToStr(Intensity), '');
end;

procedure TPSAbsorber.SetProperties(Properties: Props.TProperties);
begin
  inherited;   
  if Properties.Valid('Intensity') then Intensity := StrToFloatDef(Properties['Intensity'], 0);
end;

procedure TPSAbsorber.Process(const DeltaT: BaseClasses.Float);
var i, Index: Integer; SystemAffector: TVector3s;
begin
  inherited;
  for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and (isProcessing in ParticleSystem[Index].State) then begin

    CalcPositionInSystem(Index, SystemAffector);

    for i := ParticleSystem[Index].TotalParticles-1 downto 0 do with ParticleSystem[Index].SimulationData[i] do begin
      if ( (Age >= AgeStart) and (Age < AgeEnd) ) and
         ( (Range = 0) or (SqrMagnitude(SubVector3s(SystemAffector, ParticleSystem[Index].RenderData[i].Position)) < Sqr(Range)) ) then
        ParticleSystem[Index].Kill(i);
    end;
  end;
end;

{ TPSColorInterpolator }

constructor TPSColorInterpolator.Create(AManager: TItemsManager);
begin
  inherited;
  Colors := TSampledGradient.Create;
end;

destructor TPSColorInterpolator.Destroy;
begin
  FreeAndNil(Colors);
  inherited;
end;

procedure TPSColorInterpolator.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;

  Colors.AddAsProperty(Result, 'Colors');
end;

procedure TPSColorInterpolator.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  Colors.SetFromProperty(Properties, 'Colors');
end;

procedure TPSColorInterpolator.Process(const DeltaT: BaseClasses.Float);
var
  i, Index: Integer;
  AgeNormK, Modulator: Single;
begin
  inherited;
  AgeNormK := 1/(AgeEnd-AgeStart);
  if Colors.Enabled then for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and (isProcessing in ParticleSystem[Index].State) then begin
    
    for i := ParticleSystem[Index].TotalParticles-1 downto 0 do with ParticleSystem[Index].SimulationData[i] do
      if (Age >= AgeStart) and (Age < AgeEnd) then begin
        Modulator := (Age - AgeStart) * AgeNormK;
        ParticleSystem[Index].RenderData[i].Color := Colors.Value[Modulator];
      end;
  end;
end;

{ TPSForce }

procedure TPSForce.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  AddVector3sProperty(Result, 'Force', Force);
end;

procedure TPSForce.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  SetVector3sProperty(Properties, 'Force', Force);
end;

procedure TPSForce.Process(const DeltaT: BaseClasses.Float);
var i, Index: Integer; SystemAffector: TVector3s;
begin
  inherited;
  for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and (isProcessing in ParticleSystem[Index].State) then begin

    CalcPositionInSystem(Index, SystemAffector);

    for i := ParticleSystem[Index].TotalParticles-1 downto 0 do with ParticleSystem[Index].SimulationData[i] do
      if (Age >= AgeStart) and (Age < AgeEnd) and
         (SqrMagnitude(SubVector3s(SystemAffector, ParticleSystem[Index].RenderData[i].Position)) < Sqr(Range)) then
        AddVector3s(Velocity, Velocity, ScaleVector3s(Force, DeltaT));
  end;
end;

{ TSphericalEmitter }

constructor TSphericalEmitter.Create(AManager: TItemsManager);
begin
  inherited;
  PhiRange      := CreateSampledFloats(0, 2*pi, 2*pi);
  ThetaRange    := CreateSampledFloats(0, pi, pi);
  EmitMinRadius := CreateSampledFloats(0, 1, 0);
  EmitMaxRadius := CreateSampledFloats(0, 1, 0);

  MinSpeed   := CreateSampledFloats(0, 1, 0);
  MaxSpeed   := CreateSampledFloats(0, 1, 0);

  PhiRange.MaxY   := 2*Pi;
  ThetaRange.MaxY := Pi;
  EmitMinRadius.MaxY := 10;
  EmitMaxRadius.MaxY := 10;

  MinSpeed.MaxY   := 5;
  MaxSpeed.MaxY   := 5;
end;

destructor TSphericalEmitter.Destroy;
begin
  FreeAndNil(PhiRange);
  FreeAndNil(ThetaRange);
  FreeAndNil(EmitMinRadius);
  FreeAndNil(EmitMaxRadius);
  FreeAndNil(MinSpeed);
  FreeAndNil(MaxSpeed);
  inherited;
end;

procedure TSphericalEmitter.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;

  PhiRange.AddAsProperty(Result, 'Range\Phi');
  ThetaRange.AddAsProperty(Result, 'Range\Theta');
  EmitMinRadius.AddAsProperty(Result, 'Range\Min radius');
  EmitMaxRadius.AddAsProperty(Result, 'Range\Max radius');
  MinSpeed.AddAsProperty(Result, 'Range\Min speed');
  MaxSpeed.AddAsProperty(Result, 'Range\Max speed');

{  Result.Add('Emit min. radius', vtSingle, [], FloatToStr(EmitMinRadius), '');
  Result.Add('Emit max. radius', vtSingle, [], FloatToStr(EmitMaxRadius), '');
  Result.Add('Min. speed',       vtSingle, [], FloatToStr(MinSpeed),      '');
  Result.Add('Max. speed',       vtSingle, [], FloatToStr(MaxSpeed),      '');
  Result.Add('Phi range',        vtNat,    [],   IntToStr(PhiRange),      '');
  Result.Add('Theta range',      vtNat,    [],   IntToStr(ThetaRange),    '');}
  Result.Add('Tangent velocity', vtBoolean, [], OnOffStr[Tangent],        '');
end;

procedure TSphericalEmitter.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  PhiRange.SetFromProperty(Properties, 'Range\Phi');
  ThetaRange.SetFromProperty(Properties, 'Range\Theta');
  EmitMinRadius.SetFromProperty(Properties, 'Range\Min radius');
  EmitMaxRadius.SetFromProperty(Properties, 'Range\Max radius');
  MinSpeed.SetFromProperty(Properties, 'Range\Min speed');
  MaxSpeed.SetFromProperty(Properties, 'Range\Max speed');
{  if Properties.Valid('Emit min. radius') then EmitMinRadius := StrToFloatDef(Properties['Emit min. radius'], 0);
  if Properties.Valid('Emit max. radius') then EmitMaxRadius := StrToFloatDef(Properties['Emit max. radius'], 0);
  if Properties.Valid('Min. speed')       then MinSpeed      := StrToFloatDef(Properties['Min. speed'],       0);
  if Properties.Valid('Max. speed')       then MaxSpeed      := StrToFloatDef(Properties['Max. speed'],       0);
  if Properties.Valid('Phi range')        then PhiRange      :=   StrToIntDef(Properties['Phi range'],        0);
  if Properties.Valid('Theta range')      then ThetaRange    :=   StrToIntDef(Properties['Theta range'],      0);}
  if Properties.Valid('Tangent velocity') then Tangent       := Properties.GetAsInteger('Tangent velocity') > 0;
end;

procedure TSphericalEmitter.InitParticles(Index, EmittedStart, EmittedEnd: Integer);
var
  i: Integer;
  Vec: TVector3s;
  CosPhi, SinTheta, CosTheta, SinPhi, Radius: Single; //IPhi, ITheta: Integer;
  PhiRangeValue, ThetaRangeValue, MinRadiusValue, MaxRadiusValue, MinSpeedValue, MaxSpeedValue: Single;
begin
  inherited;

  if PhiRange.Enabled      then PhiRangeValue   := PhiRange.Value[CycleK]      else PhiRangeValue   := 0;
  if ThetaRange.Enabled    then ThetaRangeValue := ThetaRange.Value[CycleK]    else ThetaRangeValue := 0;
  if EmitMinRadius.Enabled then MinRadiusValue  := EmitMinRadius.Value[CycleK] else MinRadiusValue  := 0;
  if EmitMaxRadius.Enabled then MaxRadiusValue  := EmitMaxRadius.Value[CycleK] else MaxRadiusValue  := 0;
  if MinSpeed.Enabled      then MinSpeedValue   := MinSpeed.Value[CycleK]      else MinSpeedValue   := 0;
  if MaxSpeed.Enabled      then MaxSpeedValue   := MaxSpeed.Value[CycleK]      else MaxSpeedValue   := 0;

  for i := EmittedEnd downto EmittedStart do begin       // ToDo: Make independent of data structures used
    SinCos((1-2*Random)*PhiRangeValue,   SinPhi,   CosPhi);
    SinCos((1-2*Random)*ThetaRangeValue, SinTheta, CosTheta);

    Radius   := ( MinRadiusValue + Random*(MaxRadiusValue - MinRadiusValue) );

    Vec := Transform3Vector3s(CutMatrix3s(Transform), Vec3s(CosPhi*SinTheta*Radius, SinPhi*SinTheta*Radius, CosTheta*Radius));

    AddVector3s(ParticleSystem[Index].RenderData[i].Position, ParticleSystem[Index].RenderData[i].Position, Vec);

    Radius   := MinSpeedValue + Random*(MaxSpeedValue - MinSpeedValue);
    ParticleSystem[Index].SimulationData[i].Velocity := Transform3Vector3s(CutMatrix3s(Transform), Vec3s(CosPhi*SinTheta*Radius, SinPhi*SinTheta*Radius, CosTheta*Radius));
  end;
end;

{ TPSUniAffector }

constructor TPSUniAffector.Create(AManager: TItemsManager);
begin
  inherited;
  FColor          := TSampledGradient.Create;
  FSizeModulator  := CreateSampledFloats(0, 10, 1);
  FForceModulator := CreateSampledFloats(0, 1, 0);
  FSpeedModulator := CreateSampledFloats(0, 1, 0);
  FAngle          := CreateSampledFloats(-pi, pi, 0);
  LifeTime        := 10;
end;

destructor TPSUniAffector.Destroy;
begin
  FreeAndNil(FColor);
  FreeAndNil(FSizeModulator);
  FreeAndNil(FForceModulator);
  FreeAndNil(FSpeedModulator);
  FreeAndNil(FAngle);
  inherited;
end;

procedure TPSUniAffector.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  FColor.AddAsProperty(Result, 'Color');
  FSizeModulator.AddAsProperty(Result, 'Size');
  FForceModulator.AddAsProperty(Result, 'Weight');
  FSpeedModulator.AddAsProperty(Result, 'Speed');
  FAngle.AddAsProperty(Result, 'Angle');
  Result.Add('LifeTime', vtSingle, [], FloatToStr(LifeTime), '');

  AddVector3sProperty(Result, 'Force', Force);
end;

procedure TPSUniAffector.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  FColor.SetFromProperty(Properties, 'Color');
  FSizeModulator.SetFromProperty(Properties, 'Size');
  FForceModulator.SetFromProperty(Properties, 'Weight');
  FSpeedModulator.SetFromProperty(Properties, 'Speed');
  FAngle.SetFromProperty(Properties, 'Angle');
  if Properties.Valid('LifeTime') then LifeTime := StrToFloatDef(Properties['LifeTime'], 0);

  SetVector3sProperty(Properties, 'Force', Force);
end;

procedure TPSUniAffector.Process(const DeltaT: BaseClasses.Float);
var
  Index, i: Integer;
  SystemAffector: TVector3s;
  Modulator, AgeNormK: Single;

  procedure CheckBBox(const Coord: TVector3s);
  begin
    with ParticleSystem[Index] do begin
      BoundingBox.P1.X := MinS(BoundingBox.P1.X, Coord.X - MaxSize);
      BoundingBox.P1.Y := MinS(BoundingBox.P1.Y, Coord.Y - MaxSize);
      BoundingBox.P1.Z := MinS(BoundingBox.P1.Z, Coord.Z - MaxSize);
      BoundingBox.P2.X := MaxS(BoundingBox.P2.X, Coord.X + MaxSize);
      BoundingBox.P2.Y := MaxS(BoundingBox.P2.Y, Coord.Y + MaxSize);
      BoundingBox.P2.Z := MaxS(BoundingBox.P2.Z, Coord.Z + MaxSize);
    end;
  end;

begin
  inherited;
  AgeNormK := 1/(AgeEnd-AgeStart);
  for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and (isProcessing in ParticleSystem[Index].State) then begin
    ParticleSystem[Index].BoundingBox.P1 := GetVector3s( MaxFloatValue,  MaxFloatValue,  MaxFloatValue);
    ParticleSystem[Index].BoundingBox.P2 := GetVector3s(-MaxFloatValue, -MaxFloatValue, -MaxFloatValue);

    CalcPositionInSystem(Index, SystemAffector);

    for i := ParticleSystem[Index].TotalParticles-1 downto 0 do with ParticleSystem[Index].SimulationData[i] do begin
      Age := Age + DeltaT;
      if Age > LifeTime then
        ParticleSystem[Index].Kill(i)
      else begin
        if (Age >= AgeStart) and (Age < AgeEnd) then begin
          Modulator := (Age - AgeStart) * AgeNormK;
          with ParticleSystem[Index].RenderData[i] do begin
            if FSizeModulator.Enabled then Size := FSizeModulator.Value[Modulator];
            if FSpeedModulator.Enabled then
              AddVector3s(Position, Position, ScaleVector3s(Velocity, DeltaT * FSpeedModulator.Value[Modulator]))
            else
              AddVector3s(Position, Position, ScaleVector3s(Velocity, DeltaT));

            if ParticleSystem[Index].MaxSize < Size*0.5 then ParticleSystem[Index].MaxSize := Size*0.5;
            CheckBBox(Position);
            if FColor.Enabled then Color := FColor.Value[Modulator];

            if FForceModulator.Enabled then
              AddVector3s(Velocity, Velocity, ScaleVector3s(Force, DeltaT * FForceModulator.Value[Modulator]))
            else
              AddVector3s(Velocity, Velocity, ScaleVector3s(Force, DeltaT));

            if FAngle.Enabled then
              Angle := Abs(FAngle.Value[Modulator]) * Sign(Angle);
          end;
        end;
      end;
      
    end;
  end;
end;

{ TSubEmitter }

procedure TSubEmitter.ResolveLinks;
var Item: TItem;
begin
  inherited;

  ResolveLink('Source system', Item);
  if Assigned(Item) then FSourceSystem := Item as TParticleSystem;
end;

procedure TSubEmitter.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  
  if Assigned(Result) then begin
    Result.Add('Source system\Starting age',    vtSingle,  [], FloatToStr(SrcAgeStart), '');
    Result.Add('Source system\Ending age',      vtSingle,  [], FloatToStr(SrcAgeEnd),   '');
    Result.Add('Source system\Kill after emit', vtBoolean, [], OnOffStr[KillSource],   '');
  end;

  AddItemLink(Result, 'Source system', [], 'TParticleSystem');
end;

procedure TSubEmitter.SetProperties(Properties: Props.TProperties);
begin
  inherited;

  if Properties.Valid('Source system') then SetLinkProperty('Source system', Properties['Source system']);

  ResolveLinks;

  if Properties.Valid('Source system\Starting age')    then SrcAgeStart := StrToFloatDef(Properties['Source system\Starting age'], 0);
  if Properties.Valid('Source system\Ending age')      then SrcAgeEnd   := StrToFloatDef(Properties['Source system\Ending age'],   0);
  if Properties.Valid('Source system\Kill after emit') then KillSource  := Properties.GetAsInteger('Source system\Kill after emit') > 0;
end;

{procedure TSubEmitter.Emit(Count: Single);
var Index, i: Integer;
begin
  inherited;

  for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and
       not ParticleSystem[Index].DisableEmit and (isProcessing in ParticleSystem[Index].State) then begin

    for i := ParticleSystem[Index].TotalParticles-LastEmit[Index].Count to ParticleSystem[Index].TotalParticles-1 do begin       // ToDo: Make independent of data structures used
      SinCos((1-2*Random)*PhiRangeValue,   SinPhi,   CosPhi);
      SinCos((1-2*Random)*ThetaRangeValue, SinTheta, CosTheta);

      Size   := ( MinRadiusValue + Random*(MaxRadiusValue - MinRadiusValue) );
      Vec.X := CosPhi*SinTheta*Radius;
      Vec.Y := SinPhi*SinTheta*Radius;
      Vec.Z := CosTheta*Radius;

      AddVector3s(ParticleSystem[Index].RenderData[i].Position, ParticleSystem[Index].RenderData[i].Position, Vec);

      Radius   := MinSpeedValue + Random*(MaxSpeedValue - MinSpeedValue);
      ParticleSystem[Index].SimulationData[i].Velocity := GetVector3s(CosPhi*SinTheta*Radius, SinPhi*SinTheta*Radius, CosTheta*Radius);
    end;
  end;
end;  }

procedure TSubEmitter.InitParticles(Index, EmittedStart, EmittedEnd: Integer);
const MaxSourceParticles = 1024;
var
  i: Integer;
  SrcCoords: array[0..MaxSourceParticles-1] of TVector3s;
  MaxCoordIndex, CoordIndex: Integer;
begin
  MaxCoordIndex := 0;
  if Assigned(FSourceSystem) then
    for i := MinI(MaxSourceParticles, MinI(ParticleSystem[Index].TotalParticles, FSourceSystem.TotalParticles))-1 downto 0 do
      with FSourceSystem.SimulationData[i] do
        if (Age >= SrcAgeStart) and (Age < SrcAgeEnd) then begin
          SrcCoords[MaxCoordIndex] := FSourceSystem.RenderData[i].Position;
          if KillSource then FSourceSystem.Kill(i);

          Inc(MaxCoordIndex);
        end;

  Dec(MaxCoordIndex);
  CoordIndex := 0;
  if MaxCoordIndex >= 0 then begin
    for i := EmittedEnd downto EmittedStart do with ParticleSystem[Index].SimulationData[i] do
      if (Age >= AgeStart) and (Age < AgeEnd) then with ParticleSystem[Index].RenderData[i] do begin
        Position := SrcCoords[CoordIndex];
        CoordIndex := (CoordIndex + 1) * Ord(CoordIndex < MaxCoordIndex);
      end;
  end else begin
    for i := EmittedEnd downto EmittedStart do ParticleSystem[Index].Kill(i);
  end;

  inherited;
end;

{ TPSRandomAffector }

constructor TPSRandomAffector.Create(AManager: TItemsManager);
begin
  inherited;
  Color  := CreateSampledFloats(-5, 5, -5);
  Size   := CreateSampledFloats(-2, 2, -2);
  Coords := CreateSampledFloats(-2, 2, -2);
  Speed  := CreateSampledFloats(-2, 2, -2);
  PAge   := CreateSampledFloats(-3, 3, -3);
  Angle  := CreateSampledFloats(-pi, pi, -pi);
end;

destructor TPSRandomAffector.Destroy;
begin
  FreeAndNil(Color);
  FreeAndNil(Size);
  FreeAndNil(Coords);
  FreeAndNil(Speed);
  FreeAndNil(PAge);
  FreeAndNil(Angle);
  inherited;
end;

procedure TPSRandomAffector.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;

  Color.AddAsProperty(Result,  'Colors');
  Size.AddAsProperty(Result,   'Size');
  Coords.AddAsProperty(Result, 'Position');
  Speed.AddAsProperty(Result,  'Speed');
  PAge.AddAsProperty(Result,   'Age');
  Angle.AddAsProperty(Result,  'Angle');
end;

procedure TPSRandomAffector.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  Color.SetFromProperty(Properties,  'Colors');
  Size.SetFromProperty(Properties,   'Size');
  Coords.SetFromProperty(Properties, 'Position');
  Speed.SetFromProperty(Properties,  'Speed');
  PAge.SetFromProperty(Properties,   'Age');
  Angle.SetFromProperty(Properties,  'Angle');
end;

procedure TPSRandomAffector.Process(const DeltaT: BaseClasses.Float);
var
  i, Index: Integer;
  AgeNormK, Modulator, Temp: Single;
begin
  inherited;
  AgeNormK := 1/(AgeEnd-AgeStart);

  for Index := 0 to TotalParticleSystems-1 do
    if Assigned(ParticleSystem[Index]) and (isProcessing in ParticleSystem[Index].State) then begin
      for i := ParticleSystem[Index].TotalParticles-1 downto 0 do with ParticleSystem[Index].SimulationData[i] do
        if (Age >= AgeStart) and (Age < AgeEnd) then begin
          Modulator := (Age - AgeStart) * AgeNormK;
          if Color.Enabled then with Color do begin
            ParticleSystem[Index].RenderData[i].Color.A := ClampI(ParticleSystem[Index].RenderData[i].Color.A + Round((MinY + Random * Range) * (Value[Modulator] - MinY)), 0, 255);
            ParticleSystem[Index].RenderData[i].Color.R := ClampI(ParticleSystem[Index].RenderData[i].Color.R + Round((MinY + Random * Range) * (Value[Modulator] - MinY)), 0, 255);
            ParticleSystem[Index].RenderData[i].Color.G := ClampI(ParticleSystem[Index].RenderData[i].Color.G + Round((MinY + Random * Range) * (Value[Modulator] - MinY)), 0, 255);
            ParticleSystem[Index].RenderData[i].Color.B := ClampI(ParticleSystem[Index].RenderData[i].Color.B + Round((MinY + Random * Range) * (Value[Modulator] - MinY)), 0, 255);
          end;
          if Size.Enabled then with Size do begin
            Temp := (MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv;
            ParticleSystem[Index].RenderData[i].Size := ParticleSystem[Index].RenderData[i].Size + Temp;
          end;
          if Coords.Enabled then with Coords do begin
            AddVector3s(ParticleSystem[Index].RenderData[i].Position,
                        ParticleSystem[Index].RenderData[i].Position,
                        Vec3s((MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv,
                              (MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv,
                              (MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv));
          end;
          if Speed.Enabled then with Speed do begin
            AddVector3s(ParticleSystem[Index].SimulationData[i].Velocity,
                        ParticleSystem[Index].SimulationData[i].Velocity,
                        Vec3s((MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv, (MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv, (MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv));
          end;
          if PAge.Enabled then with PAge do begin
            Temp := (MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv;
            ParticleSystem[Index].SimulationData[i].Age := ParticleSystem[Index].SimulationData[i].Age + Temp;
          end;
          if Angle.Enabled then with Angle do begin
            Temp := (MinY + Random * Range) * (Value[Modulator] - MinY) * RangeInv;
            ParticleSystem[Index].RenderData[i].Angle := ParticleSystem[Index].RenderData[i].Angle + Temp;
          end;
        end;
    end;
end;

begin
  GlobalClassList.Add('C2Affectors', GetUnitClassList);                     
end.
