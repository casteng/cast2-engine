{Recent changes:
 * Basic MatchMesh set to True
 * Adding mesh in TActor changed to standard
}
{$Include GDefines.inc}
{$Include CDefines.inc}
unit Cast;

interface

uses
  SysUtils, Windows,
 Logger, 
  Basics, BaseCont, Base3D, Collisions, OSUtils,
{$IFDEF SCRIPTING} OTypes, OScan, OComp, ORun, {$ENDIF}
  CTypes, CTess, CRender, CMaps, CRes, CGeom, 
  Math;

const
  MaxRandomSequence = 8;

  ceUnknownResource = -100; cwUnknownResource = 100;
  weKill = 1; weExplode = 10;
  cmdCollision = cmdCastBase + 0; cmdOutOfBounds = cmdCastBase + 1;
  cmdPause = cmdCastBase + 10;
  skNone = 0; skXZAccending = 1; skXZDescending = 2; skAccending = 3; skDescending = 4; skZAccending = 5; skZDescending = 6;
//Item status
  isVisible = 1; isProcessing = 2; isUnique = 4; isSystem = 8; isPauseProcessing = 16;

  VAllocStep = 1024*32;
  VAllocMask: LongWord = not LongWord(VAllocStep-1);
  IAllocStep = 1024*4;
  IAllocMask: LongWord = not LongWord(IAllocStep-1);
  ParticlesAllocStep = 32;
  ParticleAllocMask: LongWord = not LongWord(ParticlesAllocStep-1);

  SceneFileSignature: TFileSignature  = 'CSD0';
  SceneFileSignature1: TFileSignature = 'CSD1';
  SceneFileSignature2: TFileSignature = 'CSD2';
  SceneFileSignature3: TFileSignature = 'CSD3';

  ActorFileSignature5: TFileSignature = 'AD05';
  ActorFileSignature6: TFileSignature = 'AD06';
  ActorFileSignature7: TFileSignature = 'AD07';
  MaterialLibFileSignature: TFileSignature = 'ML00';

  MaxLights = 256;
// Hit status
  hsNone = 0; hsLandscape = 1; hsItem = 2; hsVehicle = 4; hsSelf = 8;

{$IFDEF PROFILE}
  tcItemsRender = tcSpecific1; tcBuildBuffers = tcSpecific2;
  tcManagersRender = tcSpecific3; tcProcessItems = tcSpecific4;
  tcTerrainLighting = tcSpecific6;
{$ENDIF}

type
  TRenderPasses = array of TRenderPass;
  TMeshManager = class;
  TWorld = class;
  TItem = class;
  TItems = array of TItem;

  TItemRoutine = function(const Item: TItem): Boolean;

  CItem = class of TItem;
  TItem = class
    Sorting, Order, CullMode: Integer;                                          // Container's visualisation order
    ID: Integer;                                                                // Index in world's or parent's childs array
    MMIndex: Integer;                                                           // Index in mesh manager
    CompositeMode: Boolean;
    Kind, Status, TicksProcessed: Integer;
    Name: TShortName;
    Scale: TVector3s;
    Location, Orientation: TVector3s;
    UpVector, ForwardVector, RightVector: TVector3s;
    Orient: TQuaternion;
    LVelocity: TVector3s;
    AVelocity: TQuaternion;

    FHitPoints: Integer;

    LocalHeightMap: PByteBuffer;
    LHMapWidth, LHMapHeight: Integer;
    BoundingVolumes: TBoundingVolumes; TotalVolumes: Integer;
    BoundingBox, FullBoundingBox: TBoundingBox;
    Controls: array[0..3] of TVector3s;

    World: TWorld;
    Parent, Owner: TItem;
    Childs: TItems; TotalChilds: Integer;
    Meshes: array of TTesselator; TotalLODs: Integer;
    MeshClass: CTesselator;
    CurrentLOD: TTesselator;
    LODMul: Single;

    RenderPasses: TRenderPasses; TotalPasses: Integer;

    ModelMatrix: TMatrix4s;
    ModelMatrix1: TMatrix4s;
    Manager, DebugManager: TMeshManager;
    Value: Single;

    CreateEvents: Boolean;

    class function GetClass: CItem;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); virtual;
    procedure Init; virtual;
    procedure SetManager(const AManager: TMeshManager); virtual;
    procedure SetMaterial(const PassNumber: Integer; const AName: TShortName); overload; virtual;
    procedure SetMaterial(const PassNumber: Integer; const AMaterial: TMaterial); overload; virtual;
    procedure AddRenderPass(SrcBlend, DestBlend, ZFunc, AFunc, ARef: Cardinal; ZWrite, EnableFog: Boolean); virtual;
    procedure SetRenderPasses(const Passes: TRenderPasses); virtual;
    procedure RemoveRenderPass; virtual;
    procedure ClearRenderPasses; virtual;

    function NewProperty(var Properties: TProperties; const AName: TShortName; const AType: Integer; const AValue: Pointer): Integer; virtual;
    function GetProperty(const Properties: TProperties; const Name: TShortName; var ResultP: TProperty): Boolean; virtual;
    function GetPropertyValue(const Properties: TProperties; const Name: TShortName; const Default: Pointer = nil): Pointer; virtual;
    procedure ClearProperties; virtual;

    procedure SetupExternalVariables; virtual;
    function SetupScript(Source: string): Boolean; virtual;
    function SetProperties(AProperties: TProperties): Integer; virtual;
    function GetProperties: TProperties; virtual;

    procedure Hide; virtual;
    procedure Show; virtual;

    procedure CalcDimensions; virtual;
    function GetDimensions: TVector3s;

    procedure SetDetail(const AQuality, ADetail: Integer); virtual;
    procedure SetMesh; virtual;
    procedure AddLOD(AMesh: TTesselator); virtual;
    procedure ClearMeshes; virtual;
    procedure SetMeshResources(const AVerticesRes, AIndicesRes: Integer); virtual;

    function Clone: TItem; virtual;    
    function Save(Stream: TDStream): Integer; virtual;
    function Load(Stream: TDStream): Integer; virtual;
    function SaveProperties(Stream: TDStream): Integer; virtual;
    function LoadProperties(Stream: TDStream; const Version: Integer): Integer; virtual;
    function LoadResources: Integer; virtual; abstract;

    function SetChild(Index: Integer; AItem: TItem): TItem; virtual;
//    function AddChild(AName: TShortName): TItem; overload; virtual;
    function AddChild(AItem: TItem): TItem; virtual;
    function GetChildsByName(const AName: TShortName; var Items: TItems): Integer; virtual;
    function GetChildByName(const AName: TShortName; const SearchAllChilds: Boolean): TItem; virtual;
    function DeleteChild(AItem: TItem): Integer; virtual;
    function ChangeID(const NewID: Integer): Integer; virtual;

    procedure Render(Renderer: TRenderer); virtual;
    function ProcessScript: Boolean; virtual;
    function Process: Boolean; virtual;
    procedure HandleCommand(const Command: TCommand); virtual;

    procedure SetScale(AScale: TVector3s); virtual;
    procedure SetLocation(ALocation: TVector3s); virtual;
    procedure SetOrientation(AOrientation: TQuaternion); virtual;
    function GetLocation: TVector3s; virtual;

    function GetAbsLocation3s: TVector3s; virtual;
    function GetAbsLocation: TVector4s; virtual;
    function GetAbsOrientation: TQuaternion; virtual;
    function GetAbsMatrix: TMatrix4s; virtual;

    destructor Free; virtual;
// Number of vertices in most detail LOD

  protected
    PermanentKill: Boolean;
    FSystemProcessing: Boolean;
    ScriptResIndex: Integer;
{$IFDEF SCRIPTING}
    ScriptRunTime: TRTData;
{$ENDIF}
    procedure SetHitPoints(const Value: Integer); virtual;
    function GetMaxTotalVertices: Integer; virtual;
    procedure SetSystemProcessing(const Value: Boolean);

  public
    property MaxTotalVertices: Integer read GetMaxTotalVertices;
    property HitPoints: Integer read FHitPoints write SetHitPoints;
    property SystemProcessing: Boolean read FSystemProcessing write SetSystemProcessing;
  end;

  TLandscape = class(TItem)
    HeightMap: THCNMap;
    LandscapeMaxX, LandscapeMaxZ: Single;
    procedure Init(AHeightMap: THCNMap); virtual;
    procedure MakeCrater(const X, Z: Single; const Radius: Integer); virtual;
  end;

  TIslandLandcape = class(TLandscape)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Init(AHeightMap: THCNMap); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  end;

  TBigLandscape = class(TLandscape)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetDetail(const AQuality, ADetail: Integer); override;
    procedure Init(AHeightMap: THCNMap); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  end;

  TSky = class(TItem)
    SMResIndex: Integer;
    AttachedToCamera, FixedY: Boolean;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetSkyMap(ResIndex: Integer); virtual;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function GetLocation: TVector3s; override;
    procedure SetLocation(ALocation: TVector3s); override;
    procedure Render(Renderer: TRenderer); override;
  protected
    SetPlace: Boolean;
    Place: TVector3s;
  end;

  TParticleSystem = class(TItem)
    LocalCoordinates, UniformEmit, RotationSupport, FastKill, DisableEmit: Boolean;
    EmitSpace: Single;
    DefaultColor, DefaultRadius, DefaultLifetime: Longword;
    EmitRadius: Single;
    OuterForce, GlobalVelocity, EmitterVelocity, LastEmitLocation: TVector3s;
    ParticlesToEmit: Single;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Init; override;

    procedure Render(Renderer: TRenderer); override;

    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;

    procedure SetupExternalVariables; override;

    function GetParticleCount: Integer; virtual;
    procedure UpdateMesh; virtual;

    function Emit(Count: Single): Integer; virtual;
    procedure Kill(Index: Integer); virtual;
    procedure KillAll; virtual;
  end;

  TMeshManager = class
//    Events: TCommandQueue;
//    Renderer: TRenderer;
    World: TWorld;
    StreamNum: LongWord;
    TotalItems, TotalVertices, VertexCapacity, CleanCount: Integer;
    Items: array of TItem;
    SortedItems: array of Integer;
    Meshes: array of TTesselator; TotalMeshes: Integer;
    Sorting, Order: Integer;                                               // Container's visualisation order
    constructor Create(AVertexFormat, AOrder, ASorting: Integer; AWorld: TWorld); virtual;
    procedure SetSorting(const ASorting: Cardinal); virtual;
    function AddItem(const Item: TItem): TItem; virtual;
    procedure DeleteItem(const Item: TItem); virtual;
    procedure Clear; virtual;
    procedure AddMesh(const AMesh: TTesselator); virtual;
    procedure DeleteMesh(const AMesh: TTesselator); virtual;
    function MeshExists(const AMesh: TTesselator): Integer; virtual;
    procedure Process; virtual;
    procedure BuildBuffer; virtual;
    procedure Render; virtual;
  end;

  TSmartMeshManager = class(TMeshManager)
    procedure BuildBuffer; override;
  end;

  TDebugManager = class(TMeshManager)
    Items: array of Cardinal; Matrices: array of Tmatrix4s;
    DMeshes: array of TTesselator; TotalDMeshes: Integer;
    constructor Create(AVertexFormat, AOrder, ASorting: Integer; AWorld: TWorld); virtual;
    procedure AddBVolume(BVol: TBoundingVolumes; Matrix: TMatrix4s); virtual;
//    function AddMesh(const Mesh: TTesselator): TTesselator; virtual;
    function AddMesh(AName: TShortName; const AVerticesRes, AIndicesRes: Integer): TTesselator; virtual;
    procedure BuildBuffer; override;
    procedure Render; override;
  end;

  TActor = class(TItem)
    MeshClass: CMeshTesselator;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetMeshResources(const AVerticesRes, AIndicesRes: Integer); override;
    function LoadResources: Integer; override;
  end;

  TStandingActor = class(TActor)
    StandScale: TVector3s;
    ZeroLevel: Single;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function Process: Boolean; override;
  end;

  TVehicle = class(TStandingActor)
    Acceleration, VehicleTurn: Integer;
    Speed, CurrentTurnRate: Single;
//    OldQuat: TQuaternion;
    Breaks: Boolean;

    VehiclePBase, MovePBase: Integer;
    procedure Init; override;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function Process: Boolean; override;
  protected
    EnginePower, MaxTurnRate, GearFriction, BreakForce: Single;
    Mass: Single;
    RotateStopped, AllowBackward, AllowRollDown: Boolean;
  end;

  TProcessRoutine = procedure;

  CWorld = class of TWorld;

  TWorld = class
    PauseMode: Boolean;
    LastProcessMs, DefaultTimeQuantum, CurrentTimeQuantum, LightingTimeQuantum, ServerTimeQuantum, ClientSavedMs, LightingSavedMs, ServerSavedMs: Cardinal;
    CurrentTick: Cardinal;

    GlobalForce: TVector3s;
    AirReaction: Single;

    GameArea: TVector3s;
    Landscape: TLandscape;
    Items: TItems; TotalItems: Integer;
    SysItems: array of TItem; TotalSysItems: Integer;       // Items which processing system commands
    MeshManagers: array of TMeshManager; TotalMeshManagers: Integer;

    Samples: array of TItem; TotalSamples: Integer;         // Some sample items such as explosions, shells

    Events, Messages: TCommandQueue;
{$IFDEF NETSUPPORT} NetMessages: TCommandQueue; {$ENDIF}

    FRenderer: TRenderer;
    ResourceManager: TResourceManager;

    DebugMeshManager: TDebugManager;

    Meshes: array of TTesselator; TotalMeshes: Integer;
    ItemClasses: array of CItem; TotalItemClasses: Integer;
    AmbientColorCB: TColorB;
    Lights: array of TLight;
    TotalLights, TotalDirLights: Integer;

    DebugOut, EditorMode: Boolean;                                            // ToFix: Eliminate it
    DebugMaterial: TMaterial;

    ProcessRoutine, BeforeRenderProc: TProcessRoutine;

    TempData: TTempContainer;

    ClientCommandLog: TCommandQueue4;

    RandomSequence: Longword;
{$IFDEF SCRIPTING}
    VM: TOberonVM;
    Compiler: TCompiler;
{$ENDIF}
    constructor Create(ResStream: TDStream; NewIClasses: array of CItem; NewRClasses: array of CResource); virtual;
    procedure Start; virtual;
    function AddItemClass(NewClass: CItem): Integer;
    function GetItemClassIndex(const Name: TShortName): Integer;
    function GetInstanceCount(AClass: CItem): Integer;

    function InitRandomizer(Sequence, Seed, Chain: Longword): Longword;
    function Rnd(Range: Single): Single; virtual;
    function RndSymm(Range: Single): Single;
    function RndI(Range: Integer): Integer;

    function PickCell(RenderPars: TRenderParameters; var X, Z: Integer): Boolean; virtual;        // ToFix: Move it from here
    function GetVisibleObjects(const Source: TVector3s; const Radius: Single; var VisibleItems: TItems): Integer; virtual;

    function CreateActorMesh(const MeshClass: CMeshTesselator; const AVerticesRes, AIndicesRes: Integer): TTesselator; virtual;
    function AddMesh(const AMesh: TTesselator): TTesselator; virtual;
    procedure DeleteMesh(const AMesh: TTesselator); virtual;

    procedure SetAmbient(const Color: TColorB); virtual;
    function AddLight(const ALight: TLight): Integer; virtual;
    procedure ModifyLight(const Index: Integer; ALight: TLight); virtual;
    procedure DeleteLight(const Index: Integer); virtual;
    procedure ClearLights(AAmbient: Word); virtual;
    procedure DeleteLights; virtual;
    procedure CalcLights(DirProcessSpeed: Integer); virtual;

    function AddSample(const Sample: TItem): TItem; virtual;
    function GetSample(const AName: TShortName): TItem; virtual;
    procedure ClearSamples; virtual;

    function AddItem(const AItem: TItem): TItem; virtual;
    procedure ChangeItemParent(Item, DestParent: TItem); virtual;  // Changes Item's parent to DestParent
    function ChooseManager(AItem: TItem): Integer; virtual;
    function AddMeshManager(AMeshManager: TMeshManager): Integer; virtual;
    function GetItemByName(AName: TShortName; SearchAllChilds: Boolean): TItem; virtual;

    procedure RemoveItem(Item: TItem); virtual;
    procedure DeleteItem(const ID: Integer); virtual;

    procedure DoForEachItem(Routine: TItemRoutine); virtual;
    Procedure AddSysItem(const AItem: TItem); virtual;
    procedure DeleteSysItem(const AItem: TItem); virtual;

    procedure AddToKillList(const ID: TItem; Permanent: Boolean); virtual;
    procedure HandleKillList; virtual;

    function SaveScene(Stream: TDStream): Integer; virtual;
    function LoadScene(Stream: TDStream): Integer; virtual;
    function SaveAllActors(Stream: TDStream): Integer; virtual;
    function LoadAllActors(Stream: TDStream): Integer; virtual;
    procedure ClearScene; virtual;
    function LoadActor(Stream: TDStream): TItem; virtual;

    function SaveMaterials(Stream: TDStream): Integer; virtual;
    function LoadMaterials(Stream: TDStream): Integer; virtual;

    procedure SendToServer; virtual;
    procedure ProcessItems; virtual;
    procedure Process; virtual;
    procedure ProcessEvents; virtual;
    procedure ProcessClientCommand(Command: TCommand; NeedSend: Boolean = False); virtual;

    procedure HandleCommand(const Command: TCommand); virtual;

    destructor Free; virtual;

    procedure SetRenderer(const Value: TRenderer);

    property Renderer: TRenderer read FRenderer write SetRenderer;
{$IFDEF DEBUGMODE}
  public
{$ELSE}
  protected
{$ENDIF}
    RandomSeed, RandomChain: array[0..MaxRandomSequence-1] of Longword;
    KillList: array of TItem; TotalKilled: Integer;
  end;

{$IFDEF DEBUGMODE}
var
  dResizeCount, dTesselateCount, dTotalBufferSize, dActualVertices: Integer;
  DebugStr: string;
{$ENDIF}

implementation

uses CFX, CParticle, CUI;

class function TItem.GetClass: CItem;
begin
  Result := Self;
end;

constructor TItem.Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
begin
  World := AWorld;
  Name := AName;
  ID := -1;
  CompositeMode := False;
  Parent := AParent;
  Scale := GetVector3s(1, 1, 1);
  SetLength(Childs, 0); TotalChilds := 0;
  GetQuaternion(Orient, 0, GetVector3s(0, 1, 0));
  AVelocity := Orient;
  ModelMatrix := IdentityMatrix4s;
  DebugManager := nil;
  TotalVolumes := 0;
  BoundingVolumes := nil;
  CurrentLOD := nil;
  Manager := nil;
  Kind := World.GetItemClassIndex(ClassName);
  ModelMatrix1 := IdentityMatrix4s;
  LHMapWidth := 0; LHMapHeight := 0;
  LocalHeightMap := nil;
  if Assigned(World.Renderer) then AddRenderPass(bmOne, bmZero, tfLessEqual, tfAlways, 0, True, True);
  Order := 0; Sorting := skNone; CullMode := cmCCW;
  Status := isVisible or isProcessing;
  FSystemProcessing := False;
  CreateEvents := True;
  TicksProcessed := 0;
  ScriptResIndex := -1;

  ClearProperties;

  Init;
end;

procedure TItem.Init;
begin
end;

procedure TItem.SetManager(const AManager: TMeshManager);
var i, j, k: Integer; 
begin
  if Manager <> nil then begin
//    Dec(Manager.TotalVertices, MaxTotalVertices);
    for i := 0 to TotalLODs-1 do Manager.DeleteMesh(Meshes[i]);

//    World.Log('Item "' + Name + '" mesh manager respecified', lkWarning);

  end;
  Manager := AManager;

  for i := 0 to TotalLODs-1 do if Manager.MeshExists(Meshes[i]) = -1 then Manager.AddMesh(Meshes[i]);
  for i := 0 to TotalChilds-1 do if (Childs[i] <> nil) and (Childs[i].Manager = nil) then Childs[i].SetManager(AManager);
end;

procedure TItem.SetMesh;
begin
end;

procedure TItem.SetMaterial(const PassNumber: Integer; const AMaterial: TMaterial);
var i: Integer;
begin
  if TotalPasses <= PassNumber then Exit;
  RenderPasses[PassNumber].Material := AMaterial;
  if RenderPasses[PassNumber].Material = nil then RenderPasses[PassNumber].Material := World.Renderer.GetMaterialByName('Default');
  for i := 0 to RenderPasses[PassNumber].Material.TotalStages-1 do
   if RenderPasses[PassNumber].Material.Stages[i].TextureRID <> -1 then
    RenderPasses[PassNumber].Material.Stages[i].TextureIND := World.FRenderer.AddTexture(RenderPasses[PassNumber].Material.Stages[i].TextureRID);
  for i := 0 to TotalChilds-1 do if (Childs[i] <> nil) then
   if (Childs[i].TotalPasses > PassNumber) and (Childs[i].RenderPasses[PassNumber].Material = nil) then Childs[i].SetMaterial(PassNumber, AMaterial);
end;

procedure TItem.SetMaterial(const PassNumber: Integer; const AName: TShortName);
begin
  SetMaterial(PassNumber, World.Renderer.GetMaterialByName(AName));
end;

procedure TItem.AddRenderPass(SrcBlend, DestBlend, ZFunc, AFunc, ARef: Cardinal; ZWrite, EnableFog: Boolean);
begin
  Inc(TotalPasses); SetLength(RenderPasses, TotalPasses);
  RenderPasses[TotalPasses-1].SrcBlend := SrcBlend;
  RenderPasses[TotalPasses-1].DestBlend := DestBlend;
  RenderPasses[TotalPasses-1].ZTestFunc := ZFunc;
  RenderPasses[TotalPasses-1].ATestFunc := AFunc;
  RenderPasses[TotalPasses-1].AlphaRef := ARef;
  RenderPasses[TotalPasses-1].ZWrite := ZWrite;
  RenderPasses[TotalPasses-1].EnableFog := EnableFog;
  SetMaterial(TotalPasses-1, World.Renderer.GetMaterialByName('Default'));
end;

procedure TItem.SetRenderPasses(const Passes: TRenderPasses);
var i: Integer;
begin
  ClearRenderPasses;
  for i := 0 to Length(Passes)-1 do begin
    AddRenderPass(Passes[i].SrcBlend, Passes[i].DestBlend, Passes[i].ZTestFunc, Passes[i].ATestFunc, Passes[i].AlphaRef, Passes[i].ZWrite, Passes[i].EnableFog);
    SetMaterial(i, Passes[i].Material);
  end;
end;

procedure TItem.RemoveRenderPass;
begin
  Dec(TotalPasses); SetLength(RenderPasses, TotalPasses);
end;

procedure TItem.ClearRenderPasses;
begin
  TotalPasses := 0; SetLength(RenderPasses, TotalPasses);
end;

function TItem.NewProperty(var Properties: TProperties; const AName: TShortName; const AType: Integer; const AValue: Pointer): Integer;
begin
  Result := Length(Properties);
  SetLength(Properties, Result+1);
  Properties[Result].Name := AName;
  Properties[Result].ValueType := AType;
  if AType = ptBoolean then begin
    if Boolean(AValue) then Properties[Result].Value := Pointer(1) else Properties[Result].Value := Pointer(0);
  end else Properties[Result].Value := AValue;
end;

function TItem.GetProperty(const Properties: TProperties; const Name: TShortName; var ResultP: TProperty): Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to Length(Properties)-1 do if Properties[i].Name = Name then begin
    Result := True; ResultP := Properties[i]; Exit;
  end;
end;

function TItem.GetPropertyValue(const Properties: TProperties; const Name: TShortName; const Default: Pointer = nil): Pointer;
var Prop: TProperty;
begin
  if GetProperty(Properties, Name, Prop) then Result := Prop.Value else Result := Default;
end;

procedure TItem.ClearProperties;
begin
//  TotalProperties := 0; SetLength(Properties, TotalProperties);
end;

procedure TItem.SetupExternalVariables;
begin
{$IFDEF SCRIPTING}
  World.Compiler.ImportExternalVar('TicksProcessed', 'LONGINT', @TicksProcessed);
  World.Compiler.ImportExternalVar('Scale', 'TVector3s', @Scale);
  World.Compiler.ImportExternalVar('Location', 'TVector3s', @Location);
  World.Compiler.ImportExternalVar('Orientation', 'TVector3s', @Orientation);
{$ENDIF}
end;

function TItem.SetupScript(Source: string): Boolean;
begin
  Result := True;
{$IFDEF SCRIPTING}
  World.Compiler := TCompiler.Create(TScaner.Create(Source));

  SetupExternalVariables;

  World.Compiler.Compile;

  if World.Compiler.CError.Number = 0 then ScriptRunTime := World.Compiler.Data else Result := False;
{$ENDIF}

//  World.Compiler.Free;
end;

function TItem.SetProperties(AProperties: TProperties): Integer;
var NewOrder, NewSorting: Integer;
begin
  Result := -1;
  NewOrder := Integer(GetPropertyValue(AProperties, 'Order'));
  CullMode := Integer(GetPropertyValue(AProperties, 'Cull mode'));
  NewSorting := Integer(GetPropertyValue(AProperties, 'Sorting (N, XZA, XZD, A, D, ZA, ZD)'));
  CompositeMode := Boolean(GetPropertyValue(AProperties, 'Composite mode'));
  ScriptResIndex := Integer(GetPropertyValue(AProperties, 'Process script'));
  if (ScriptResIndex <> -1) and
     (World.ResourceManager.Resources[ScriptResIndex] is TScriptResource) then
      SetupScript((World.ResourceManager.Resources[ScriptResIndex] as TScriptResource).GetText);
  if (NewOrder <> Order) or (NewSorting <> Sorting) then begin
    Order := NewOrder; Sorting := NewSorting;
    World.ChooseManager(Self);
  end;
  if CurrentLOD <> nil then CurrentLOD.Invalidate(False);
  Result := 0;
end;

function TItem.GetProperties: TProperties;
begin
  Result := nil;
//  skNone = 0; skXZAccending = 1; skXZDescending = 2; skAccending = 3; skDescending = 4; skZAccending = 5; skZDescending = 6;
  NewProperty(Result, 'Order', ptInt32, Pointer(Order));
  NewProperty(Result, 'Cull mode', ptInt32, Pointer(CullMode));
  NewProperty(Result, 'Sorting (N, XZA, XZD, A, D, ZA, ZD)', ptInt32, Pointer(Sorting));
  NewProperty(Result, 'Composite mode', ptBoolean, Pointer(CompositeMode));
  NewProperty(Result, 'Process script', ptResource + World.ResourceManager.GetResourceClassIndex('TScriptResource') shl 8, Pointer(ScriptResIndex));
end;

procedure TItem.CalcDimensions;
var i: Integer; tv: TVector3s;
begin
// World.Log('Calculating dimensions of item "' + Name + '"'); 
  FullBoundingBox.P1 := GetVector3s(0, 0, 0);
  FullBoundingBox.P2 := GetVector3s(0, 0, 0);
  for i := 0 to TotalVolumes-1 do begin
    tv := SubVector3s(BoundingVolumes[i].Offset, BoundingVolumes[i].Dimensions);
    FullBoundingBox.P1 := GetVector3s(MinS(FullBoundingBox.P1.X, tv.X), MinS(FullBoundingBox.P1.Y, tv.Y), MinS(FullBoundingBox.P1.Z, tv.Z));
    tv := AddVector3s(BoundingVolumes[i].Offset, BoundingVolumes[i].Dimensions);
    FullBoundingBox.P2 := GetVector3s(MaxS(FullBoundingBox.P2.X, tv.X), MaxS(FullBoundingBox.P2.Y, tv.Y), MaxS(FullBoundingBox.P2.Z, tv.Z));
  end;
  for i := 0 to TotalChilds-1 do if Childs[i] <> nil then begin                    // ToFix: take child matrices in account
    Childs[i].CalcDimensions;
    tv := AddVector3s(Childs[i].Location, Childs[i].FullBoundingBox.P1);
    FullBoundingBox.P1 := GetVector3s(MinS(FullBoundingBox.P1.X, tv.X), MinS(FullBoundingBox.P1.Y, tv.Y), MinS(FullBoundingBox.P1.Z, tv.Z));
    tv := AddVector3s(Childs[i].Location, Childs[i].FullBoundingBox.P2);
    FullBoundingBox.P2 := GetVector3s(MaxS(FullBoundingBox.P2.X, tv.X), MaxS(FullBoundingBox.P2.Y, tv.Y), MaxS(FullBoundingBox.P2.Z, tv.Z));
  end;
end;

function TItem.GetDimensions: TVector3s;
begin
  ScaleVector3s(Result, SubVector3s(FullBoundingBox.P2, FullBoundingBox.P1), 0.5);
end;

procedure TItem.AddLOD(AMesh: TTesselator);
begin
  AMesh.IncRef;
  Inc(TotalLODs); SetLength(Meshes, TotalLODs);
  Meshes[TotalLODs - 1] := AMesh;
  LODMul := TotalLODs / World.Renderer.RenderPars.ZFar;
  if CurrentLOD = nil then CurrentLOD := AMesh;
end;

procedure TItem.ClearMeshes;
var i: Integer;
begin
  for i := 0 to TotalLODs - 1 do if Assigned(Meshes[i]) then World.DeleteMesh(Meshes[i]);
  TotalLODs := 0; SetLength(Meshes, TotalLODs);
  LODMul := 0;
  CurrentLOD := nil;
end;

procedure TItem.SetMeshResources(const AVerticesRes, AIndicesRes: Integer);
begin
end;

function TItem.Clone: TItem;
var i: Integer; 
begin
//  World.Log('Cloning item "'+Name+'"');
  Result := GetClass.Create(Name{+'-c-'}, World);
  Result.Kind := Kind;
  Result.Controls := Controls;
//  for i := 0 to TotalLODs-1 do Result.AddLOD(Meshes[i]);
  Result.SetMesh;                                                       //ToFix: use SetMesh only if individual mesh
  if Result.CurrentLOD = nil then begin
    for i := 0 to TotalLODs-1 do Result.AddLOD(Meshes[i]);
//    Result.Meshes := Meshes;
//    Result.CurrentLOD := CurrentLOD;
  end;
  Result.BoundingBox := BoundingBox;

  Result.TotalVolumes := TotalVolumes;
  SetLength(Result.BoundingVolumes, Result.TotalVolumes);
  for i := 0 to TotalVolumes-1 do Result.BoundingVolumes[i] := BoundingVolumes[i];

  Result.GetProperties;
  Result.SetProperties(GetProperties);
  Result.TotalChilds := TotalChilds;
  SetLength(Result.Childs, TotalChilds);
  for i := 0 to TotalChilds-1 do Result.SetChild(i, Childs[i].Clone);

  Result.CalcDimensions;
  Result.FullBoundingBox := FullBoundingBox;

  Result.Order := Order;
  Result.Status := Status;

  Result.SetScale(Scale);
  Result.SetLocation(GetLocation);

  Result.TotalPasses := TotalPasses;
  for i := 0 to TotalPasses-1 do Result.RenderPasses[i] := RenderPasses[i];
  Result.LocalHeightMap := LocalHeightMap;
  Result.Parent := Parent;
  Result.Init;
end;

function TItem.Load(Stream: TDStream): Integer;
type
  TOldBoundingVolume = record
    VolumeKind: Cardinal;                  // тип 1 - сфера. 2 - бокс.
    Offset, Dimensions: TVector3s;         // Dimensions - радиус (только X) сферы или половина размера бокса
  end;

var
  FileVersion, i, VerticesRes, IndicesRes, CKind: Integer;
  s, ResName: TShortName; Sign: TFileSignature;
begin
  Result := feCannotRead;
  if Stream.Read(Sign, SizeOf(Sign)) <> feOK then Exit;
   if Sign = ActorFileSignature5 then FileVersion := 5 else
    if Sign = ActorFileSignature6 then FileVersion := 6 else
     if Sign = ActorFileSignature7 then FileVersion := 7 else Exit;
  if Stream.Read(s, SizeOf(s)) <> feOK then Exit;
  Kind := World.GetItemClassIndex(s);
  if Kind < 0 then Exit;
  if Stream.Read(Name, SizeOf(Name)) <> feOK then Exit;
  if FileVersion >= 6 then if Stream.Read(Status, SizeOf(Status)) <> feOK then Exit;
  if Stream.Read(Scale, SizeOf(Scale)) <> feOK then Exit;
  if Stream.Read(Location, SizeOf(Location)) <> feOK then Exit;
  if FileVersion >= 7 then begin
   if Stream.Read(Orient, SizeOf(Orient)) <> feOK then Exit;
  end else if Stream.Read(Orientation, SizeOf(Orientation)) <> feOK then Exit;
  if Stream.Read(Controls, SizeOf(Controls)) <> feOK then Exit;
  if Stream.Read(TotalChilds, SizeOf(TotalChilds)) <> feOK then Exit;
  SetLength(Childs, TotalChilds);
  with World.ResourceManager do begin
    if Stream.Read(ResName, SizeOf(ResName)) <> feOK then Exit;
    VerticesRes := IndexByName(ResName);
    if Stream.Read(ResName, SizeOf(ResName)) <> feOK then Exit;
    IndicesRes := IndexByName(ResName);
    SetMeshResources(VerticesRes, IndicesRes);
    SetMesh;
    if CurrentLOD = nil then begin

//      Log('Mesh for object "' + Name + '" of class "' + s + '" is nil', lkWarning);

//      Exit;
    end;

    if CurrentLOD <> nil then BoundingBox := Meshes[0].CalcBoundingBox;
    if Stream.Read(TotalPasses, SizeOf(TotalPasses)) <> feOK then Exit;
    SetLength(RenderPasses, TotalPasses);
    for i := 0 to TotalPasses-1 do begin                                          // Load passes
      if Stream.Read(RenderPasses[i], SizeOf(RenderPasses[i])-4) <> feOK then Exit;
      if Stream.Read(s, SizeOf(s)) <> feOK then Exit;
      SetMaterial(i, World.Renderer.GetMaterialByName(s));
    end;

    Stream.Read(TotalVolumes, SizeOf(TotalVolumes));
    SetLength(BoundingVolumes, TotalVolumes);

    for i := 0 to TotalVolumes-1 do begin
      Stream.Read(BoundingVolumes[i], SizeOf(BoundingVolumes[i]));
      if FileVersion <= 7 then if BoundingVolumes[i].VolumeKind = 2 then BoundingVolumes[i].VolumeKind := 0;
    end;  
  end;
  
  LoadProperties(Stream, FileVersion);

  for i := 0 to TotalChilds - 1 do SetChild(i, World.LoadActor(Stream));
  
  CalcDimensions;
  Controls[0].X := FullBoundingBox.P2.X; Controls[0].Y := FullBoundingBox.P1.Y-0*50; Controls[0].Z := FullBoundingBox.P2.Z;
  Controls[1].X := FullBoundingBox.P2.X; Controls[1].Y := FullBoundingBox.P1.Y-0*50; Controls[1].Z := FullBoundingBox.P1.Z;
  Controls[2].X := FullBoundingBox.P1.X; Controls[2].Y := FullBoundingBox.P1.Y-0*50; Controls[2].Z := FullBoundingBox.P2.Z;
  Controls[3].X := FullBoundingBox.P1.X; Controls[3].Y := FullBoundingBox.P1.Y-0*50; Controls[3].Z := FullBoundingBox.P1.Z;

  SetLocation(Location);
  Init;

  if Result < 0 then Result := feOK;
end;

function TItem.LoadProperties(Stream: TDStream; const Version: Integer): Integer;
var
  i, j, Ind: Integer; Props: TProperties; TotalProps: Integer; TName: TShortName;
  Strings: array of TShortName; TotalStrings: Integer;
  LongStrings: array of string; TotalLongStrings: Integer;
  s: string;
begin
  Result := feCannotRead;
  Props := GetProperties;
  if Stream.Read(TotalProps, SizeOf(TotalProps)) <> feOK then Exit;

  TotalStrings := 0; TotalLongStrings := 0;

  for i := 0 to TotalProps-1 do begin
    Ind := i;
    if Version >= 5 then begin
      if Stream.Read(TName, SizeOf(TName)) <> feOK then Exit;
      for j := 0 to Length(Props)-1 do if Props[j].Name = TName then Ind := j;
    end;

    if Stream.Read(Props[Ind].ValueType, SizeOf(Props[Ind].ValueType)) <> feOK then Exit;
    if Props[Ind].ValueType and 255 = ptString then begin                        // Fixed length string
      Inc(TotalStrings); SetLength(Strings, TotalStrings);
      if Stream.Read(Strings[TotalStrings-1], PTSizes[Props[Ind].ValueType]) <> feOK then Exit;
      Props[Ind].Value := @Strings[TotalStrings-1];
    end else if Props[Ind].ValueType and 255 = ptLongString then begin           // Any length string (up to 16M characters)
      Inc(TotalLongStrings); SetLength(LongStrings, TotalLongStrings);
      SetLength(LongStrings[TotalLongStrings-1], Props[Ind].ValueType shr 8);
      if (Props[Ind].ValueType shr 8) > 0 then begin
        if Stream.Read(LongStrings[TotalLongStrings-1][1], (Props[Ind].ValueType shr 8)*LongStringCharSize) <> feOK then Exit;
        FillLongString(Props[Ind], LongStrings[TotalLongStrings-1]);
//        Props[Ind].Value := Pointer(LongStrings[TotalLongStrings-1]);
      end else Props[Ind].Value := nil;
      RetrieveLongString(Props[Ind].Value, Props[Ind].ValueType shr 8, s);
    end else if Props[Ind].ValueType and 255 = ptResource then begin
      if Stream.Read(TName, SizeOf(TName)) <> feOK then Exit;
      Props[Ind].Value := Pointer(World.ResourceManager.IndexByName(TName));
    end else if Props[Ind].ValueType <= ptBoolean then begin
      if Stream.Read(Props[Ind].Value, PTSizes[Props[Ind].ValueType]) <> feOK then Exit;
    end;
  end;
  SetProperties(Props);
  SetLength(Props, 0);
  SetLength(Strings, 0); SetLength(LongStrings, 0);
  Result := feOK;
end;

function TItem.SaveProperties(Stream: TDStream): Integer;
var i: Integer; Props: TProperties; TotalProps: Integer; ResName: TShortName;
begin
  Result := feCannotWrite;
  Props := GetProperties;
  TotalProps := Length(Props);
  if Stream.Write(TotalProps, SizeOf(TotalProps)) <> feOK then Exit;
  for i := 0 to TotalProps-1 do begin
    if Stream.Write(Props[i].Name, SizeOf(Props[i].Name)) <> feOK then Exit;
    if Stream.Write(Props[i].ValueType, SizeOf(Props[i].ValueType)) <> feOK then Exit;
    if Props[i].ValueType and 255 = ptString then begin
      if Stream.Write(TShortName(Props[i].Value^), PTSizes[Props[i].ValueType]) <> feOK then Exit;
    end else if Props[i].ValueType and 255 = ptLongString then begin
      if Stream.Write(Props[i].Value^, Props[i].ValueType shr 8 * LongStringCharSize) <> feOK then Exit;
    end else if Props[i].ValueType and 255 = ptResource then begin
      if Integer(Props[i].Value) <> -1 then
       ResName := World.ResourceManager.ResourcesInfo[Integer(Props[i].Value)].Name else
        ResName := '';
      if Stream.Write(ResName, SizeOf(ResName)) <> feOK then Exit;
    end else if Props[i].ValueType <= ptBoolean then
     if Stream.Write(Props[i].Value, PTSizes[Props[i].ValueType]) <> feOK then Exit;
  end;
  SetLength(Props, 0);
  Result := feOK;
end;

function TItem.Save(Stream: TDStream): Integer;
var i, TRes: Integer; s: TShortName; Loc: TVector3s;
begin
  Result := feCannotWrite;
  if Stream.Write(ActorFileSignature7, SizeOf(ActorFileSignature7)) <> feOK then Exit;
  s := World.ItemClasses[Kind].ClassName;
  if Stream.Write(s, SizeOf(s)) <> feOK then Exit;
  if Stream.Write(Name, SizeOf(Name)) <> feOK then Exit;
  if Stream.Write(Status, SizeOf(Status)) <> feOK then Exit;
  if Stream.Write(Scale, SizeOf(Scale)) <> feOK then Exit;
  Loc := GetLocation;
  if Stream.Write(Loc, SizeOf(Location)) <> feOK then Exit;
  if Stream.Write(Orient, SizeOf(Orient)) <> feOK then Exit;
  if Stream.Write(Controls, SizeOf(Controls)) <> feOK then Exit;
  if Stream.Write(TotalChilds, SizeOf(TotalChilds)) <> feOK then Exit;
  with World.ResourceManager do begin
    s := '';
    if (CurrentLOD = nil) or (CurrentLOD.VerticesRes = -1) then begin
      if Stream.Write(s, SizeOf(TShortName)) <> feOK then Exit;
    end else begin
      if Stream.Write(ResourcesInfo[CurrentLOD.VerticesRes].Name, SizeOf(ResourcesInfo[CurrentLod.VerticesRes].Name)) <> feOK then Exit;
    end;
    if (CurrentLOD = nil) or (CurrentLOD.IndicesRes = -1) then begin
      if Stream.Write(s, SizeOf(TShortName)) <> feOK then Exit;
    end else begin
      if Stream.Write(ResourcesInfo[CurrentLOD.IndicesRes].Name, SizeOf(ResourcesInfo[CurrentLod.IndicesRes].Name)) <> feOK then Exit;
    end;
    if Stream.Write(TotalPasses, SizeOf(TotalPasses)) <> feOK then Exit;
    for i := 0 to TotalPasses-1 do begin
      if Stream.Write(RenderPasses[i], SizeOf(RenderPasses[i])-4) <> feOK then Exit;
      if Stream.Write(RenderPasses[i].Material.Name, SizeOf(RenderPasses[i].Material.Name)) <> feOK then Exit;
    end;
  end;

  Stream.Write(TotalVolumes, SizeOf(TotalVolumes));
  for i := 0 to TotalVolumes-1 do Stream.Write(BoundingVolumes[i], SizeOf(BoundingVolumes[i]));

  SaveProperties(Stream);

  for i := 0 to TotalChilds - 1 do if Assigned(Childs[i]) then if Childs[i].Save(Stream) <> feOK then Exit;
  Result := feOK;
end;

//function TActor.AddChild(AName: TShortName; AMesh: TTesselator): TActor;
(*function TItem.AddChild(AName: TShortName): TItem;
begin
  Result := nil;
{  if (AResources[0] < 0) or (AResources[0] >= World.ResourceManager.TotalResources) or
     (AResources[1] < 0) or (AResources[1] >= World.ResourceManager.TotalResources) then Exit;}
  Inc(TotalChilds); SetLength(Childs, TotalChilds);
  Result := TItem.Create(AName, World, Self);
  Childs[TotalChilds - 1] := Result;
end;*)

function TItem.SetChild(Index: Integer; AItem: TItem): TItem;
var i: Integer;
begin
  Result := nil;
  if (Index >= TotalChilds) or (AItem = nil) then Exit;
  AItem.Parent := Self; AItem.World := World;
  World.ChooseManager(AItem);
  Childs[Index] := AItem;
  Childs[Index].ID := Index;
  Result := Childs[Index];
end;

function TItem.AddChild(AItem: TItem): TItem;
begin
  Inc(TotalChilds);
  if Length(Childs) < TotalChilds then SetLength(Childs, TotalChilds);
  Result := SetChild(TotalChilds-1, AItem);
end;

function TItem.GetChildsByName(const AName: TShortName; var Items: TItems): Integer;
var i: Integer;
begin
  Result := Length(Items);
  for i := 0 to TotalChilds-1 do if (Childs[i] <> nil) then begin
    if UpperCase(Childs[i].Name) = UpperCase(AName) then begin
      Inc(Result);
      SetLength(Items, Result);
      Items[Result-1] := Childs[i];
    end;
    Result := Childs[i].GetChildsByName(AName, Items);
  end;
end;

function TItem.GetChildByName(const AName: TShortName; const SearchAllChilds: Boolean): TItem;
var i: Integer;
begin
  Result := nil;
  for i := 0 to TotalChilds-1 do if (Childs[i] <> nil) then begin
    if UpperCase(Childs[i].Name) = UpperCase(AName) then begin
      Result := Childs[i]; Exit;
    end else if SearchAllChilds then begin
      Result := Childs[i].GetChildByName(AName, True);
      if Result <> nil then Exit;
    end;
  end;
end;

function TItem.DeleteChild(AItem: TItem): Integer;
var i: Integer; MoveChilds: Boolean;
begin
  Result := -1;
  MoveChilds := False;
  i := 0;
  if AItem.PermanentKill then AItem.Free;
  while i < TotalChilds-1 do begin
    if Childs[i] = AItem then begin Result := i; MoveChilds := True; end;
    if MoveChilds then begin
      Childs[i] := Childs[i+1];
      Childs[i].ID := i;
    end;
    Inc(i);
  end;
  if not MoveChilds then if Childs[TotalChilds-1] <> AItem then Exit;
  Dec(TotalChilds);
//  SetLength(Childs, TotalChilds);
end;

function TItem.ChangeID(const NewID: Integer): Integer;
// Swaps item with item which haves NewID index in items array (or in childs array if is sibling item)
var TempItem: TItem;
begin
  Result := NewID;
  if Result < 0 then Result := 0;
  if Parent = nil then begin                                           // Item haven't parent
    if Result > World.TotalItems-1 then Result := World.TotalItems-1;
    if Result = ID then Exit;
    TempItem := World.Items[Result];
    World.Items[Result] := World.Items[ID];
    World.Items[ID] := TempItem;
    World.Items[ID].ID := ID;
    World.Items[Result].ID := Result;
  end else begin                                                       // Sibling item
    if Result > Parent.TotalChilds-1 then Result := Parent.TotalChilds-1;
    if Result = ID then Exit;
    TempItem := Parent.Childs[Result];
    Parent.Childs[Result] := Parent.Childs[ID];
    Parent.Childs[ID] := TempItem;
    Parent.Childs[ID].ID := ID;
    Parent.Childs[Result].ID := Result;
    Parent.SetChild(ID, Parent.Childs[ID]);
    Parent.SetChild(Result, Parent.Childs[Result]);
  end;
end;

procedure TItem.SetScale(AScale: TVector3s);
begin
  Scale := AScale; SetOrientation(Orient);
end;

procedure TItem.SetLocation(ALocation: TVector3s);
begin
{  if not EqualsVector3s(Location, ALocation) or not EqualsVector3s(Orientation, AOrientation) then begin
    if LocalHeightMap <> nil then
     World.Landscape.HeightMap.ClearItemHMap(Trunc(0.5+Location.X), Trunc(0.5+Location.Z), LHMapWidth, LHMapHeight, 0);
    Location := ALocation; Orientation := AOrientation;
    if LocalHeightMap <> nil then
     World.Landscape.HeightMap.ApplyItemHMap(Trunc(0.5+Location.X), Trunc(0.5+Location.Z), LHMapWidth, LHMapHeight, Trunc(0.5+Orientation.Y*180/pi), LocalHeightMap);
  end;}    // ToFix: Move object shadows casting to separate routine

{  ModelMatrix := MulMatrix4s(YRotationMatrix4s(Orientation.Y), TranslationMatrix4s(Location.X, Location.Y, Location.Z));
  ModelMatrix := MulMatrix4s(ZRotationMatrix4s(Orientation.Z), ModelMatrix);
  ModelMatrix := MulMatrix4s(XRotationMatrix4s(Orientation.X), ModelMatrix);
  ModelMatrix := MulMatrix4s(ScaleMatrix4s(Scale.X, Scale.Y, Scale.Z), ModelMatrix);}

{  ModelMatrix := MulMatrix4s(
                 MulMatrix4s(
                 MulMatrix4s( YRotationMatrix4s(Orientation.Y), ZRotationMatrix4s(Orientation.Z) ),
                              XRotationMatrix4s(Orientation.X) ),
                              TranslationMatrix4s(Location.X, Location.Y, Location.Z)
                 );}
//  ModelMatrix := MulMatrix4s(ZRotationMatrix4s(Orientation.Z), ModelMatrix);
//  ModelMatrix := MulMatrix4s(XRotationMatrix4s(Orientation.X), ModelMatrix);
  Location := ALocation; 
  SetOrientation(Orient);
end;

procedure TItem.SetOrientation(AOrientation: TQuaternion);
var i: Integer; BLoc: TVector4s;
begin
  Orient := AOrientation;
  TranslationMatrix4s(ModelMatrix, Location.X, Location.Y, Location.Z);
  Matrix4sByQuat(ModelMatrix, Orient);

  UpVector := CutVector3s(Transform4Vector4s(ModelMatrix, GetVector4s(0, 1, 0, 0)));
  ForwardVector := CutVector3s(Transform4Vector4s(ModelMatrix, GetVector4s(0, 0, 1, 0)));
  CrossProductVector3s(RightVector, UpVector, ForwardVector);

  MulMatrix4s(ModelMatrix, ScaleMatrix4s(Scale.X, Scale.Y, Scale.Z), ModelMatrix);

  if Assigned(Parent) then ModelMatrix := MulMatrix4s(ModelMatrix, Parent.ModelMatrix);

  for i := 0 to TotalChilds - 1 do Childs[i].SetLocation(Childs[i].Location);
end;

function TItem.GetLocation: TVector3s;
begin
  Result := Location;
end;

function TItem.GetAbsMatrix: TMatrix4s;
begin
  Result := ModelMatrix;
  if Parent <> nil then Result := MulMatrix4s(Parent.GetAbsMatrix, Result);
end;

function TItem.GetAbsLocation: TVector4s;
begin
  Result := Transform4Vector3s(ModelMatrix, GetVector3s(0, 0, 0));
end;

function TItem.GetAbsLocation3s: TVector3s;
begin
  with ModelMatrix do Result := GetVector3s(_41, _42, _43);
end;

function TItem.GetAbsOrientation: TQuaternion;
begin
  Result := Orient;
  if Parent <> nil then Result := MulQuaternion(Parent.GetAbsOrientation, Result);
end;

function TItem.ProcessScript: Boolean;
begin
{$IFDEF SCRIPTING}
  World.VM.Data := ScriptRunTime;
  World.VM.Run;
  SetLocation(Location);
{$ENDIF}
end;

function TItem.Process: Boolean;
var i: Integer;
begin
  Result := False;
{$IFDEF SCRIPTING}  if ScriptResIndex <> -1 then ProcessScript; {$ENDIF}
  for i := 0 to TotalChilds - 1 do
   if (Childs[i].Status and isProcessing <> 0) and (not World.PauseMode or (Childs[i].Status and isPauseProcessing > 0)) then
    Result := Childs[i].Process or Result;
  Inc(TicksProcessed);
end;

procedure TItem.HandleCommand(const Command: TCommand);
begin
end;

procedure TItem.Render(Renderer: TRenderer);
var i: Integer;
begin
//  Renderer.AddTesselator(Mesh);
  Assert(not Assigned(CurrentLOD) or Assigned(Manager), 'TItem.Render: Manager is nil');
  if CurrentLOD <> nil then Manager.AddItem(Self);
  if World.DebugOut and (World.DebugMeshManager <> nil) then World.DebugMeshManager.AddBVolume(BoundingVolumes, ModelMatrix);
  for i := 0 to TotalChilds - 1 do if Childs[i].Status and isVisible <> 0 then Childs[i].Render(Renderer);
end;

destructor TItem.Free;
var i: Integer;
begin
  for i := 0 to TotalChilds - 1 do if Assigned(Childs[i]) then begin
    Childs[i].Free; Childs[i] := nil;
  end;
  SetLength(Childs, 0); TotalChilds := 0;
  SetLength(BoundingVolumes, 0);
  BoundingVolumes := 0;
  ClearMeshes;
end;

procedure TItem.SetHitPoints(const Value: Integer);
begin
  FHitPoints := Value;
end;

function TItem.GetMaxTotalVertices: Integer;
var i: Integer;
begin
  Result := 0;
  for i := 0 to TotalLODs-1 do Inc(Result, Meshes[i].TotalVertices);
end;

//************************************

constructor TWorld.Create(ResStream: TDStream; NewIClasses: array of CItem; NewRClasses: array of CResource);
var i: Integer;
begin
  TotalItemClasses := 0;
  AddItemClass(TItem);
  AddItemClass(TActor);
  AddItemClass(TStandingActor);
  AddItemClass(TVehicle);
  AddItemClass(TSky);
  AddItemClass(TBigLandscape);
  AddItemClass(TIslandLandcape);
  for i := 0 to Length(NewIClasses)-1 do AddItemClass(NewIClasses[i]);

  TotalItems := 0;
  ClientSavedMs       := GetTickCount;
  ServerSavedMs       := GetTickCount;
  DefaultTimeQuantum  := 30;
  CurrentTimeQuantum  := DefaultTimeQuantum;
  LightingTimeQuantum := 30;
  ServerTimeQuantum   := 100;

  Events      := TCommandQueue.Create;
  Messages    := TCommandQueue.Create;
{$IFDEF NETSUPPORT}
  NetMessages := TCommandQueue.Create;
{$ENDIF}
  ResourceManager := TResourceManager.Create(ResStream, NewRClasses);
  TotalLights := 0; SetLength(Lights, 0); TotalDirLights := 0;
  DebugOut := False;
  EditorMode := False;
  PauseMode := True;
  CurrentTick := 0;
  ProcessRoutine := nil; BeforeRenderProc := nil;
{$IFDEF SCRIPTING}
  VM := TOberonVM.Create;
{$ENDIF}
  GameArea := GetVector3s(10000, 1000, 10000);

  ClientCommandLog := TCommandQueue4.Create;

  TempData := TTempContainer.Create;
end;

function TWorld.AddItemClass(NewClass: CItem): Integer;
begin
  Result := GetItemClassIndex(NewClass.ClassName);
  if Result <> -1 then Exit;
  Inc(TotalItemClasses);
  SetLength(ItemClasses, TotalItemClasses);
  ItemClasses[TotalItemClasses-1] := NewClass;
  Result := TotalItemClasses-1;
end;

function TWorld.GetItemClassIndex(const Name: TShortName): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to TotalItemClasses-1 do begin
    if ItemClasses[i].ClassName = Name then Result := i;
  end;
end;

function TWorld.GetInstanceCount(AClass: CItem): Integer;
var i: Integer;
begin
  Result := 0;
  for i := 0 to TotalItems-1 do begin
    if Items[i].GetClass = AClass then Inc(Result);
  end;
end;

function TWorld.InitRandomizer(Sequence, Seed, Chain: Longword): Longword;
begin
  RandomSeed[Sequence] := Seed; RandomChain[Sequence] := Chain;
  Result := Seed;
end;

function TWorld.Rnd(Range: Single): Single;
const RandomNorm = 1/$FFFFFFFF;
begin
{$Q-}
//  Result := 0; Exit;
  RandomSeed[RandomSequence] := 97781173 * RandomSeed[RandomSequence] + RandomChain[RandomSequence];
  Result := RandomSeed[RandomSequence] * RandomNorm * Range;
end;

function TWorld.RndSymm(Range: Single): Single;
begin
//  Result := 0; Exit;
  Result := Rnd(2*Range) - Range;
end;

function TWorld.RndI(Range: Integer): Integer;
begin
//  Result := 0; Exit;
  Result := Trunc(0.5 + Rnd(MaxI(0, Range-1)));
end;

function TWorld.PickCell(RenderPars: TRenderParameters; var X, Z: Integer): Boolean;
const SQRT2 = 1.4142135624;
var i: Integer; d: Single; Ray, TRay: TVector3s; CurX, CurY, CurZ: Single;
begin
  if Landscape = nil then Exit;
  Result := False;
    d := 0.5*RenderPars.ActualWidth / Sin(RenderPars.FoV/2)*Cos(RenderPars.FoV/2);
    Ray.X := 0.5*RenderPars.ActualWidth-X;
    Ray.Y := (0.5*RenderPars.ActualHeight-Z)*RenderPars.ActualWidth/RenderPars.ActualHeight/RenderPars.CurrentAspectRatio;
    Ray.Z := d;
    TRay := Transform3Vector3s(MulMatrix3s(XRotationMatrix3s(-RenderPars.Camera.XAngle), YRotationMatrix3s(-RenderPars.Camera.YAngle)), Ray);
    if TRay.Y = 0 then Exit;
    TRay := NormalizeVector3s(TRay);
//    d := RenderPars.Camera.Y/TRay.Y;
//    X := Trunc(0.5 + RenderPars.Camera.X + d*TRay.X);
//    Z := Trunc(0.5 + RenderPars.Camera.Z - d*TRay.Z);
// Lets trace it?
    CurX := RenderPars.Camera.X; CurY := RenderPars.Camera.Y; CurZ := RenderPars.Camera.Z;
    TRay.X := -TRay.X;
    for i := 0 to Trunc(0.5 + SQRT2 * RenderPars.ZFar / Landscape.HeightMap.TileSize) do begin
      if Landscape.HeightMap.GetHeight(CurX, CurZ) >= CurY then begin
        X := Trunc(0.5+CurX); Z := Trunc(0.5+CurZ);
        Result := True; Exit;
      end;
      CurX := CurX + TRay.X * Landscape.HeightMap.TileSize;
      CurY := CurY + TRay.Y * Landscape.HeightMap.TileSize;
      CurZ := CurZ + TRay.Z * Landscape.HeightMap.TileSize;
  end;
end;

function TWorld.GetVisibleObjects(const Source: TVector3s; const Radius: Single; var VisibleItems: TItems): Integer;
var i: Integer; SQRadius: Single;
begin
  Result := 0;
  for i := 0 to TotalItems-1 do if SqrMagnitude(Subvector3s(Source, Items[i].Location)) < SQRadius then begin
    Inc(Result); SetLength(VisibleItems, Result);
    VisibleItems[Result-1] := Items[i];
  end;
end;

function TWorld.CreateActorMesh(const MeshClass: CMeshTesselator; const AVerticesRes, AIndicesRes: Integer): TTesselator;
var i, TotalIndices: Integer; IndicesPTR: Pointer;
begin
  Assert(AVerticesRes <> -1, 'CreateActorMesh: Invalid vertices resource');
{  for i := 0 to TotalMeshes-1 do if (Meshes[i].ClassName = MeshClass.ClassName) and
                                    (Meshes[i].VerticesRes = AVerticesRes) and (Meshes[i].IndicesRes = AIndicesRes) then begin
    Result := Meshes[i]; Exit;
  end;}

  if AIndicesRes <> -1 then begin
    TotalIndices := TArrayResource(Renderer.Resources[AIndicesRes]).TotalElements;
    IndicesPTR := Renderer.Resources[AIndicesRes].Data;
  end else begin
    TotalIndices := 0; IndicesPTR := nil;
  end;
  Result := MeshClass.Create('', TArrayResource(Renderer.Resources[AVerticesRes]).TotalElements, Renderer.Resources[AVerticesRes].Data, TotalIndices, IndicesPTR);
  Result.VertexFormat := Renderer.Resources[AVerticesRes].Format;
  Result.VertexSize   := GetVertexSize(Result.VertexFormat);
  Result.VerticesRes  := AVerticesRes;
  Result.IndicesRes   := AIndicesRes;
end;

function TWorld.AddMesh(const AMesh: TTesselator): TTesselator;
var i: Integer;
begin
  Result := nil;
  if AMesh = nil then Exit;
  for i := 0 to TotalMeshes-1 do if (Meshes[i].ClassName = AMesh.ClassName) and                // ToFix: Add resource dependency checking
                                    Meshes[i].MatchMesh(AMesh) then begin
    Result := Meshes[i];
    AMesh.Free;
    Exit;
  end;
  Inc(TotalMeshes);
  SetLength(Meshes, TotalMeshes);
  Meshes[TotalMeshes-1] := AMesh;
  Result := AMesh;
end;

procedure TWorld.DeleteMesh(const AMesh: TTesselator);
var i: Integer;
begin
  if AMesh.DecRef <> 0 then Exit;
  for i := 0 to TotalMeshes-1 do if Meshes[i] = AMesh then begin
    Meshes[i] := Meshes[TotalMeshes-1];
    Dec(TotalMeshes); SetLength(Meshes, TotalMeshes);
    Break;
  end;
end;

procedure TWorld.Start;
//var t: TMeshManager;
begin
  DebugMeshManager := TDebugManager.Create(GetVertexFormat(False, False, True, False, 0), 10000, skNone, Self);
  AddMeshManager(DebugMeshManager);

  LastProcessMs := GetTickCount;
  ClientSavedMs := LastProcessMs;
  ServerSavedMs := LastProcessMs;

// Draw
///  AddMeshManager(TSmartMeshManager.Create(GetVertexFormat(False, False, True, False, 0), 0, Self));
///  t := TSmartMeshManager.Create(GetVertexFormat(True, False, True, False, 1), 0, Self);
///  t.Sorting := skXZDescending;
///  AddMeshManager(FX);
end;

procedure TWorld.SetAmbient(const Color: TColorB);
begin
  if Renderer <> nil then Renderer.SetAmbient(Color.R shl 16 + Color.G shl 8 + Color.B);
  AmbientColorCB := Color;
  if (Landscape <> nil) and  (Landscape.HeightMap <> nil) and (TotalDirLights > 0) then begin
    Landscape.HeightMap.SetGlobalLights(AmbientColorCB, Lights[0]);
    if Landscape <> nil then Landscape.CurrentLOD.Invalidate(False);
  end;
end;

function TWorld.AddLight(const ALight: TLight): Integer;
begin
  Result := -1;
  if TotalLights >= MaxLights then Exit;
  Inc(TotalLights); SetLength(Lights, TotalLights);
  if ALight.LightType = ltDirectional then begin
    Lights[TotalLights-1] := Lights[TotalDirLights];
    Lights[TotalDirLights] := ALight;
    Inc(TotalDirLights);
  end else begin
    Lights[TotalLights-1] := ALight;
  end;
  Result := TotalLights-1;
  Renderer.SetLight(TotalLights-1, ALight);
  if (Landscape <> nil) and (TotalLights = 1) then Landscape.HeightMap.SetGlobalLights(AmbientColorCB, Lights[0]);
end;

procedure TWorld.ModifyLight(const Index: Integer; ALight: TLight);
begin
  if Index >= TotalLights then Exit;
  if (Index < TotalDirLights) and (ALight.LightType <> ltDirectional) then begin
    Lights[Index] := Lights[TotalDirLights];
    Lights[TotalDirLights] := ALight;
    Dec(TotalDirLights);
    Renderer.SetLight(TotalDirLights, ALight);
  end;
  if (Index >= TotalDirLights) and (ALight.LightType = ltDirectional) then begin
    Inc(TotalDirLights);
    Lights[Index] := Lights[TotalDirLights];
    Lights[TotalDirLights] := ALight;
    Renderer.SetLight(TotalDirLights, ALight);
  end;
  if ALight.LightType = Lights[Index].LightType then Lights[Index] := ALight;
  Renderer.SetLight(Index, Lights[Index]);
  if (Landscape <> nil) and (Index = 0) then Landscape.HeightMap.SetGlobalLights(AmbientColorCB, Lights[0]);
end;

procedure TWorld.DeleteLight(const Index: Integer);
begin
  if Index < TotalDirLights then begin
    if Index < TotalDirLights-1 then begin
      Lights[Index] := Lights[TotalDirLights-1];
      if TotalDirLights-1 < TotalLights-1 then Lights[TotalDirLights-1] := Lights[TotalLights-1];
    end else if Index < TotalLights-1 then Lights[Index] := Lights[TotalLights-1];
    Dec(TotalDirLights);
  end else if Index < TotalLights-1 then Lights[Index] := Lights[TotalLights-1];
  Dec(TotalLights);
  SetLength(Lights, TotalLights);
  Renderer.DeleteLight(Index);
end;

procedure TWorld.ClearLights(AAmbient: Word);
begin
  TotalLights := 0; TotalDirLights := 0; SetLength(Lights, TotalLights);
  if Assigned(Renderer) then Renderer.RenderPars.Ambient := AAmbient;
end;

procedure TWorld.DeleteLights;                                    //ToFix: Eliminate it
var i: Integer;
begin
  if Landscape = nil then Exit;
  for i := TotalDirLights to TotalLights-1 do Landscape.HeightMap.DelLight(Landscape.HeightMap.LightToInt(Lights[i]));
end;

procedure TWorld.CalcLights(DirProcessSpeed: Integer);
var i, j: Integer;
begin
  if Landscape = nil then Exit;
{
case ALight.LightType of
    ltDirectional: if ALight.B + ALight.G + ALight.R = 0 then Exit;
    ltOmniDynamic: if (abs(ALight.Location.X-RenderPars.Camera.X) > ALight.Range + RenderPars.ZFar) or
                      (abs(ALight.Location.Z-RenderPars.Camera.Z) > ALight.Range + RenderPars.ZFar) or
                      (abs(ALight.Location.Y-RenderPars.Camera.Y) > ALight.Range + RenderPars.ZFar) or
                      (ALight.B + ALight.G + ALight.R = 0) then Exit;
  end;
}
{  for j := 1 to DirProcessSpeed do begin
    for i := 0 to TotalDirLights-1 do Landscape.HeightMap.CalcLight(Lights[i]);
  end;}
  for i := TotalDirLights to TotalLights-1 do Landscape.HeightMap.DelLight(Landscape.HeightMap.LightToInt(Lights[i]));
  for i := TotalDirLights to TotalLights-1 do Landscape.HeightMap.CalcLight(Lights[i]);
end;

function TWorld.AddSample(const Sample: TItem): TItem;
begin
  Result := Sample;
  if Sample = nil then Exit;
  Inc(TotalSamples); SetLength(Samples, TotalSamples);
  Samples[TotalSamples-1] := Sample;
end;

procedure TWorld.ClearSamples;
begin
  TotalSamples := 0; SetLength(Samples, TotalSamples);
end;

function TWorld.GetSample(const AName: TShortName): TItem;
var i: Integer;
begin
  Result := nil;
  for i := 0 to TotalSamples-1 do if Samples[i].Name = AName then begin
    Result := Samples[i]; Exit;
  end;

  Log('TWorld.GetSample: sample "' + AName + '" not found', lkError);

end;

function TWorld.AddItem(const AItem: TItem): TItem;
begin
  Result := AItem;
  if Result = nil then Exit;

  if AItem.SystemProcessing then AddSysItem(AItem);

  Inc(TotalItems);
  if Length(Items) < TotalItems then SetLength(Items, TotalItems);
  AItem.Parent := nil;
  AItem.ID := TotalItems-1;
  Items[TotalItems-1] := AItem;
  if AItem.CurrentLOD = nil then Exit;
  if (AItem.TotalPasses <> 0) and (AItem.RenderPasses[0].Material = nil) then AItem.SetMaterial(0, Renderer.GetMaterialByName('Default'));
  ChooseManager(AItem);
end;

procedure TWorld.ChangeItemParent(Item, DestParent: TItem);
var OldPermanentKill: Boolean;
begin
  if Item.Parent = DestParent then Exit;
  OldPermanentKill := Item.PermanentKill;
  Item.PermanentKill := False;             // To prevent item killing on remove
  RemoveItem(Item);
  Item.PermanentKill := OldPermanentKill;
  if DestParent = nil then AddItem(Item) else DestParent.AddChild(Item);
end;

function TWorld.ChooseManager(AItem: TItem): Integer;
var i: Integer;
 CReason: string[40]; 
begin
  if AItem.CurrentLOD = nil then Exit;
  Result := -1;
 CReason := 'suitable manager not found'; 
  for i := 0 to TotalMeshManagers-1 do
   if (AItem.CurrentLOD.VertexFormat = Renderer.Streams.Streams[MeshManagers[i].StreamNum].VertexFormat) and (AItem.Order = MeshManagers[i].Order) and (AItem.Sorting = MeshManagers[i].Sorting) then begin
     if (MeshManagers[i].VertexCapacity >= MeshManagers[i].TotalVertices + AItem.MaxTotalVertices) then begin
       AItem.SetManager(MeshManagers[i]);
       Result := i;
       Exit;
     end else begin
 CReason := 'suitable manager #' + IntToStr(i) + ' is out of space'; 
     end;
  end;

  Log('Creating new mesh manager #' + IntToStr(TotalMeshManagers) + ' for item "' + AItem.Name + '" due to ' + CReason);

  Result := TotalMeshManagers;
  AItem.SetManager(MeshManagers[AddMeshManager(TSmartMeshManager.Create(AItem.CurrentLOD.VertexFormat, AItem.Order, AItem.Sorting, Self))]);
end;

function TWorld.AddMeshManager(AMeshManager: TMeshManager): Integer;
var i: Integer;
begin
  Result := -1;
  if AMeshManager = nil then Exit;
  Result := TotalMeshManagers;
  for i := 0 to TotalMeshManagers-1 do if AMeshManager.Order < MeshManagers[i].Order then begin
    Result := i;
    Break;
  end;
  Inc(TotalMeshManagers); SetLength(MeshManagers, TotalMeshManagers);
  for i := TotalMeshManagers-2 downto Result do MeshManagers[i+1] := MeshManagers[i];
  MeshManagers[Result] := AMeshManager;
end;

{function TWorld.AddActor(AActor: TItem): TItem;
begin
  Result := AActor;
  if Result = nil then Exit;
  AActor.ID := TotalActors;
  Inc(TotalActors);
  SetLength(Actors, TotalActors);
  Actors[TotalActors - 1] := AActor;
end;}

procedure TWorld.RemoveItem(Item: TItem);
begin
  if Item = nil then Exit;
  if Item.Parent <> nil then
   Item.Parent.DeleteChild(Item) else
    DeleteItem(Item.ID);
end;

procedure TWorld.DeleteItem(const ID: Integer);
var i: Integer; MoveItems: Boolean;
begin
  if (ID < 0) or (ID >= TotalItems) then Exit;

  if Items[ID] = Landscape then Landscape := nil;

  if Items[ID].SystemProcessing then DeleteSysItem(Items[ID]);

  if Items[ID].PermanentKill then Items[ID].Free;

  MoveItems := False;
  i := 0;
  while i < TotalItems-1 do begin
    if i = ID then MoveItems := True;
    if MoveItems then begin
      Items[i] := Items[i+1];
      Items[i].ID := i;
    end;
    Inc(i);
  end;

  Dec(TotalItems);
//  SetLength(Items, TotalItems);
end;

procedure TWorld.DoForEachItem(Routine: TItemRoutine);

function CallRoutine(Item: TItem): Boolean;
var i: Integer;
begin
  Result := True;
  if Routine(Item) then Exit;
  for i := 0 to Item.TotalChilds-1 do if CallRoutine(Item.Childs[i]) then begin
    Result := True; Exit;
  end;
  Result := False;
end;

var i: Integer;

begin
  for i := 0 to TotalItems-1 do if CallRoutine(Items[i]) then Exit;
end;

procedure TWorld.AddToKillList(const ID: TItem; Permanent: Boolean);
var j: Integer;
begin
  if ID = nil then Exit;
  ID.PermanentKill := ID.PermanentKill or Permanent;
  for j := 0 to TotalKilled-1 do if KillList[j] = ID then Exit;
  Inc(TotalKilled);
  if Length(KillList) < TotalKilled then SetLength(KillList, TotalKilled);
  KillList[TotalKilled - 1] := ID;
end;

procedure TWorld.HandleKillList;                              // ToFix: probably bug: doesn't kill child objects         FIXED
var i: Integer;
begin
  for i := 0 to TotalKilled-1 do if KillList[i].Parent = nil then DeleteItem(KillList[i].ID) else KillList[i].Parent.DeleteChild(KillList[i]);
  TotalKilled := 0;
//  SetLength(KillList, 0);
end;

function TWorld.LoadActor(Stream: TDStream): TItem;
var Kind: Integer; Sign: TFileSignature; s: TShortName;
begin
  Result := nil;
  if Stream.Read(Sign, SizeOf(Sign)) <> feOK then Exit;
  if (Sign <> ActorFileSignature5) and (Sign <> ActorFileSignature6) and (Sign <> ActorFileSignature7) then Exit;
  if Stream.Read(s, SizeOf(s)) <> feOK then Exit;
  Stream.Seek(Stream.Position-SizeOf(s)-SizeOf(Sign));
  Kind := GetItemClassIndex(s);
  if Kind < 0 then begin

    Log('Unknown item class "' + s + '"', lkError);

    Exit;
  end;
  Result := ItemClasses[Kind].Create('', Self);
  if Result.Load(Stream) < 0 then FreeAndNil(Result);
end;

function TWorld.LoadMaterials(Stream: TDStream): Integer;
var i, OldTM: Integer; FileSign: TFileSignature;
begin
  Result := feCannotWrite;
  if Stream.Read(FileSign, SizeOf(FileSign)) <> feOK then Exit;
  if FileSign <> MaterialLibFileSignature then begin Result := feInvalidFileFormat; Exit; end;
  OldTM := Renderer.TotalMaterials;
  if Stream.Read(Renderer.TotalMaterials, SizeOf(Renderer.TotalMaterials)) <> feOK then begin
    Renderer.TotalMaterials := OldTM;
    Exit;
  end;
  if OldTM > Renderer.TotalMaterials then for i := Renderer.TotalMaterials to OldTM-1 do Renderer.Materials[i].Free;
  SetLength(Renderer.Materials, Renderer.TotalMaterials);
  if OldTM < Renderer.TotalMaterials then for i := OldTM to Renderer.TotalMaterials-1 do Renderer.Materials[i] := TMaterial.Create('', Renderer);
  for i := 0 to Renderer.TotalMaterials-1 do begin
    if Renderer.Materials[i].Load(Stream) <> feOK then Exit;
  end;
  Result := feOK;
end;

function TWorld.SaveMaterials(Stream: TDStream): Integer;
var i: Integer;
begin
  Result := feCannotWrite;
  if Stream.Write(MaterialLibFileSignature, SizeOf(MaterialLibFileSignature)) <> feOK then Exit;
  if Stream.Write(Renderer.TotalMaterials, SizeOf(Renderer.TotalMaterials)) <> feOK then Exit;
  for i := 0 to Renderer.TotalMaterials-1 do if Renderer.Materials[i].Save(Stream) <> feOK then Exit;
  Result := feOK;
end;

procedure TWorld.SendToServer;
begin
end;

procedure TWorld.ProcessItems;
var i: Integer;
begin
  Inc(CurrentTick);
  for i := 0 to TotalItems - 1 do
   if (Items[i].Status and isProcessing > 0) and (not PauseMode or (Items[i].Status and isPauseProcessing > 0)) then
    Items[i].Process;
  ProcessEvents;
  if @ProcessRoutine <> nil then ProcessRoutine;
  Inc(ClientSavedMs, CurrentTimeQuantum);
end;

procedure TWorld.Process;
var
  i: Integer;
  BPTR: PByte;
  OCamera, MCamera: TCamera;
  PerfCounter: Int64;
begin
  LastProcessMs := GetTickCount;
{  if CurTick - ClientSavedTick >= ClientTimeQuantum then begin
    ClientSavedTick := CurTick;
  end;
  if CurTick - ServerSavedTick >= ServerTimeQuantum then begin
    SendToServer;
    ServerSavedTick := CurTick;
  end;}

{$IFDEF PROFILE}
    PerfCounter := GetPerformanceCounter;
{$ENDIF}

  if Landscape <> nil then if LightingSavedMs + LightingTimeQuantum < LastProcessMs then begin

    Landscape.HeightMap.ProcessCalcArea(Renderer.RenderPars.Camera);
    CalcLights(0);
    if (Landscape.HeightMap.CellsLit > 0) or (TotalLights - TotalDirLights > 0)  then Landscape.CurrentLOD.Invalidate(False);
    LightingSavedMs := LastProcessMs;
  end;

{$IFDEF PROFILE}
    TimeCounters[tcTerrainLighting] := TimeCounters[tcTerrainLighting] + GetPerformanceCounter - PerfCounter;
{$ENDIF}

  if FRenderer.RenderActive and ((FRenderer.State = rsOK) or (FRenderer.State = rsClean)) then begin

//    Renderer.BeginScene;

{$IFDEF PROFILE}
    PerfCounter := GetPerformanceCounter;
{$ENDIF}
    for i := 0 to TotalItems - 1 do if Items[i].Status and isVisible > 0 then Items[i].Render(Renderer);
{$IFDEF PROFILE}
    TimeCounters[tcItemsRender] := TimeCounters[tcItemsRender] + GetPerformanceCounter - PerfCounter;
{$ENDIF}

{$IFDEF PROFILE}
    PerfCounter := GetPerformanceCounter;
{$ENDIF}
    for i := 0 to TotalMeshManagers - 1 do MeshManagers[i].BuildBuffer;
{$IFDEF PROFILE}
    TimeCounters[tcBuildBuffers] := TimeCounters[tcBuildBuffers] + GetPerformanceCounter - PerfCounter;
{$ENDIF}

  {  FRenderer.Clear(ctZBuffer, 0, 1, 0);

    OCamera := FRenderer.RenderPars.Camera;
    MCamera := OCamera;
    MCamera.Y := -OCamera.Y;
    MCamera.XAngle := -OCamera.XAngle;
    MCamera.ZAngle := OCamera.ZAngle+pi;
    FRenderer.SetCamera(MCamera);

    FRenderer.SetCullMode(cmCCW);

    for i := 1 to TotalMeshManagers - 1 do begin
      Renderer.SetStream(MeshManagers[i].StreamNum);
      MeshManagers[i].Render;
    end;

    FRenderer.Clear(ctZBuffer, 0, 1, 0);

    FRenderer.SetCamera(OCamera);

    FRenderer.SetCullMode(cmCW); }

    if @BeforeRenderProc <> nil then BeforeRenderProc;

{$IFDEF PROFILE}
    PerfCounter := GetPerformanceCounter;
{$ENDIF}
    for i := 0 to TotalMeshManagers - 1 do begin
//      if i > 1 + 0* TotalMeshManagers - 1 then Renderer.SetViewPort(100, 100, 500, 300, 0, 1);
      Renderer.BeginStream(MeshManagers[i].StreamNum);
      MeshManagers[i].Render;
      MeshManagers[i].Clear;
//      Renderer.SetViewPort(0, 0, Renderer.RenderPars.ActualWidth, Renderer.RenderPars.ActualHeight, 0, 1);
    end;
{$IFDEF PROFILE}
    TimeCounters[tcManagersRender] := TimeCounters[tcManagersRender] + GetPerformanceCounter - PerfCounter;
{$ENDIF}

//    Renderer.EndScene;
  end;

{$IFDEF PROFILE}
    PerfCounter := GetPerformanceCounter;
{$ENDIF}
  while ClientSavedMs + CurrentTimeQuantum < LastProcessMs do ProcessItems;
{$IFDEF PROFILE}
    TimeCounters[tcProcessItems] := TimeCounters[tcProcessItems] + GetPerformanceCounter - PerfCounter;
{$ENDIF}

(*  Renderer.SetStream(MeshManager.StreamNum);
  for i := 0 to TotalActors - 1 do begin
    Actors[i].Render(Renderer);
{    if (Renderer.State = rsOK) or (Renderer.State = rsClean) then
     with Actors[i] do if (abs(Location.X-Renderer.RenderPars.Camera.X) < BoundingVolumes.Dimensions.X + Renderer.RenderPars.ZFar) and
                          (abs(Location.Z-Renderer.RenderPars.Camera.Z) < BoundingVolumes.Dimensions.Z + Renderer.RenderPars.ZFar) and
                          (abs(Location.Y-Renderer.RenderPars.Camera.Y) < BoundingVolumes.Dimensions.Y + Renderer.RenderPars.ZFar) then Render(Renderer);}
  end;

  MeshManager.Render;}*)
end;

procedure TWorld.ProcessEvents;
begin
  Events.MakeEmpty;
end;

procedure TWorld.HandleCommand(const Command: TCommand);
var i: Integer;
begin
  FRenderer.HandleCommand(Command);
  for i := 0 to TotalSysItems-1 do SysItems[i].HandleCommand(Command);
end;

procedure TWorld.SetRenderer(const Value: TRenderer);
begin
  FRenderer := Value;
end;

function TWorld.LoadScene(Stream: TDStream): Integer;
var
 i, Kind, ATotalItems, ParsSize: Integer; Sign: TFileSignature; Version: Integer;
 TempLights: array of TLight; TotLights: Integer;
begin
  Result := feCannotRead;
  if Stream.Read(Sign, SizeOf(TFileSignature)) <> feOK then Exit;

  Version := 0;
  if Sign = SceneFileSignature2 then Version := 2;
  if Sign = SceneFileSignature3 then Version := 3;

  if Version >= 2 then begin
// Renderer parameters
    if Stream.Read(ParsSize, SizeOf(ParsSize)) <> feOK then Exit;
    with Renderer do begin
      if Stream.Read(FogStart, SizeOf(FogStart)) <> feOK then Exit;
      if Stream.Read(FogEnd, SizeOf(FogEnd)) <> feOK then Exit;
      if Stream.Read(FogKind, SizeOf(FogKind)) <> feOK then Exit;
      if Stream.Read(FogColor, SizeOf(FogColor)) <> feOK then Exit;
      SetFog(FogKind, FogColor, FogStart, FogEnd);

      if Stream.Read(AmbientColor, SizeOf(AmbientColor)) <> feOK then Exit;
      SetAmbient(AmbientColor);
      Self.SetAmbient(GetColorB((AmbientColor shr 16) and 255, (AmbientColor shr 8) and 255, AmbientColor and 255, (AmbientColor shr 24) and 255));

      if Stream.Read(FillMode, SizeOf(FillMode)) <> feOK then Exit;

      if Stream.Read(ShadingMode, SizeOf(ShadingMode)) <> feOK then Exit;
      SetShading(ShadingMode);

      if Stream.Read(SpecularMode, SizeOf(SpecularMode)) <> feOK then Exit;
      SetSpecular(SpecularMode);

      if Stream.Read(ClearFrameBuffer, SizeOf(ClearFrameBuffer)) <> feOK then Exit;
      if Stream.Read(ClearColor, SizeOf(ClearColor)) <> feOK then Exit;
      if Stream.Read(ClearZBuffer, SizeOf(ClearZBuffer)) <> feOK then Exit;
      if Stream.Read(ClearZ, SizeOf(ClearZ)) <> feOK then Exit;
      if Stream.Read(ClearStencilBuffer, SizeOf(ClearStencilBuffer)) <> feOK then Exit;
      if Stream.Read(ClearStencil, SizeOf(ClearStencil)) <> feOK then Exit;
      SetClearState(ClearFrameBuffer, ClearZBuffer, ClearStencilBuffer, ClearColor, ClearZ, ClearStencil);

      if Stream.Read(RenderPars.ZNear, SizeOf(RenderPars.ZNear)) <> feOK then Exit;
      if Stream.Read(RenderPars.ZFar, SizeOf(RenderPars.ZFar)) <> feOK then Exit;
      if Stream.Read(RenderPars.FoV, SizeOf(RenderPars.FoV)) <> feOK then Exit;
      if Stream.Read(RenderPars.AspectRatio, SizeOf(RenderPars.AspectRatio)) <> feOK then Exit;
    end;
    if Stream.Read(CurrentTimeQuantum, SizeOf(CurrentTimeQuantum)) <> feOK then Exit;
//    CurrentTimeQuantum := DefaultTimeQuantum;
    if Stream.Read(GlobalForce, SizeOf(GlobalForce)) <> feOK then Exit;
  // Lights
    if Stream.Read(TotLights, SizeOf(TotalLights)) <> feOK then Exit;
    if Version >= 3 then begin
      SetLength(TempLights, TotLights);
      ClearLights(0);
      for i := 0 to TotLights-1 do begin
        if Stream.Read(TempLights[i], SizeOf(Lights[i])) <> feOK then Exit;
        AddLight(TempLights[i]);
      end;
      SetLength(TempLights, 0);
    end else begin
      Stream.Seek(Stream.Position + TotLights * SizeOf(TIntLight));
    end;
  end;

  if LoadAllActors(Stream) <> feOK then Exit;

//  LastProcessTick := GetTickCount;

  Result := feOK;
end;

function TWorld.SaveScene(Stream: TDStream): Integer;
type
  TScenePars = packed record
    FogStart, FogEnd: Single; FogKind, FogColor: Cardinal;
    AmbientColor: LongWord;
    FillMode, ShadingMode, SpecularMode: Longword;
    ClearFrameBuffer, ClearZBuffer, ClearStencilBuffer: Boolean;
    ClearColor: Longword;
    ClearZ: Single;
    ClearStencil: Cardinal;
  end;

var i, ParsSize: Integer;
begin
  Result := feCannotWrite;
  if Stream.Write(SceneFileSignature3, SizeOf(SceneFileSignature3)) <> feOK then Exit;
// Renderer parameters
  ParsSize := SizeOf(TScenePars);
  if Stream.Write(ParsSize, SizeOf(ParsSize)) <> feOK then Exit;
  with Renderer do begin
    if Stream.Write(FogStart, SizeOf(FogStart)) <> feOK then Exit;
    if Stream.Write(FogEnd, SizeOf(FogEnd)) <> feOK then Exit;
    if Stream.Write(FogKind, SizeOf(FogKind)) <> feOK then Exit;
    if Stream.Write(FogColor, SizeOf(FogColor)) <> feOK then Exit;
    if Stream.Write(AmbientColor, SizeOf(AmbientColor)) <> feOK then Exit;
    if Stream.Write(FillMode, SizeOf(FillMode)) <> feOK then Exit;
    if Stream.Write(ShadingMode, SizeOf(ShadingMode)) <> feOK then Exit;
    if Stream.Write(SpecularMode, SizeOf(SpecularMode)) <> feOK then Exit;
    if Stream.Write(ClearFrameBuffer, SizeOf(ClearFrameBuffer)) <> feOK then Exit;
    if Stream.Write(ClearColor, SizeOf(ClearColor)) <> feOK then Exit;
    if Stream.Write(ClearZBuffer, SizeOf(ClearZBuffer)) <> feOK then Exit;
    if Stream.Write(ClearZ, SizeOf(ClearZ)) <> feOK then Exit;
    if Stream.Write(ClearStencilBuffer, SizeOf(ClearStencilBuffer)) <> feOK then Exit;
    if Stream.Write(ClearStencil, SizeOf(ClearStencil)) <> feOK then Exit;

    if Stream.Write(RenderPars.ZNear, SizeOf(RenderPars.ZNear)) <> feOK then Exit;
    if Stream.Write(RenderPars.ZFar, SizeOf(RenderPars.ZFar)) <> feOK then Exit;
    if Stream.Write(RenderPars.FoV, SizeOf(RenderPars.FoV)) <> feOK then Exit;
    if Stream.Write(RenderPars.AspectRatio, SizeOf(RenderPars.AspectRatio)) <> feOK then Exit;
  end;
  if Stream.Write(CurrentTimeQuantum, SizeOf(CurrentTimeQuantum)) <> feOK then Exit;
  if Stream.Write(GlobalForce, SizeOf(GlobalForce)) <> feOK then Exit;
// Lights
  if Stream.Write(TotalLights, SizeOf(TotalLights)) <> feOK then Exit;
  for i := 0 to TotalLights-1 do if Stream.Write(Lights[i], SizeOf(Lights[i])) <> feOK then Exit;
// Objects
  if SaveAllActors(Stream) <> feOK then Exit;
  Result := feOK;
end;

function TWorld.LoadAllActors(Stream: TDStream): Integer;
var i, Kind, ATotalItems: Integer;
begin
  Result := feCannotRead;
  ClearScene;
  Start;
//  if Stream.Read(Sign, SizeOf(TFileSignature)) <> feOK then Exit;
//  if Sign <> SceneFileSignature then Exit;
  if Stream.Read(ATotalItems, SizeOf(TotalItems)) <> feOK then Exit;
  for i := 0 to ATotalItems-1 do AddItem(LoadActor(Stream));
  Result := feOK;
end;

function TWorld.SaveAllActors(Stream: TDStream): Integer;
var i: Integer;
begin
  Result := feCannotWrite;
//  if Stream.Write(SceneFileSignature, SizeOf(SceneFileSignature)) <> feOK then Exit;
  if Stream.Write(TotalItems, SizeOf(TotalItems)) <> feOK then Exit;
  for i := 0 to TotalItems-1 do if (Items[i].Status and isSystem) = 0 then if Items[i].Save(Stream) <> feOK then Exit;
  Result := feOK;
end;

procedure TWorld.ClearScene;
var i: Integer;
begin
  Landscape := nil;
  for i := 0 to TotalItems - 1 do if Assigned(Items[i]) then Items[i].Free;
  SetLength(Items, 0); TotalItems := 0;
  SetLength(SysItems, 0); TotalSysItems := 0;

  SetLength(Meshes, 0); TotalMeshes := 0;
  SetLength(MeshManagers, 0); TotalMeshManagers := 0;
  if Assigned(Renderer) then Renderer.Streams.Reset;

  if ClientCommandLog <> nil then begin
    ClientCommandLog.MakeEmpty;
  end;
//  Start;
end;

destructor TWorld.Free;
begin
{$IFDEF SCRIPTING}
  VM.Free;
{$ENDIF}
  if Assigned(ResourceManager) then ResourceManager.Free;
  ClearScene;
  TempData.Free;
  if ClientCommandLog <> nil then begin
    ClientCommandLog.Free;
    ClientCommandLog := nil;
  end;
  ClearLights(0);
{$IFDEF NETSUPPORT} NetMessages.Free; {$ENDIF}
  Messages.Free;
  Events.Free;
end;

{ TVehicle }

function TVehicle.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Mass', ptSingle, Pointer(Mass));
  NewProperty(Result, 'Move', ptGroupBegin, nil);
    NewProperty(Result, 'Engine power', ptSingle, Pointer(EnginePower));
    NewProperty(Result, 'Gear friction', ptSingle, Pointer(GearFriction));
    NewProperty(Result, 'Breaks power', ptSingle, Pointer(BreakForce));
    NewProperty(Result, 'Maneuverability', ptSingle, Pointer(MaxTurnRate));
    NewProperty(Result, 'Turn on the spot', ptBoolean, Pointer(RotateStopped));
    NewProperty(Result, 'Allow roll down slope', ptBoolean, Pointer(AllowRollDown));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TVehicle.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  Mass := Single(GetPropertyValue(AProperties, 'Mass'));

  EnginePower := Single(GetPropertyValue(AProperties, 'Engine power'));
  GearFriction := Single(GetPropertyValue(AProperties, 'Gear friction'));
  BreakForce := Single(GetPropertyValue(AProperties, 'Breaks power'));
  MaxTurnRate := Single(GetPropertyValue(AProperties, 'Maneuverability'));
  RotateStopped := Boolean(GetPropertyValue(AProperties, 'Turn on the spot'));
  AllowRollDown := Boolean(GetPropertyValue(AProperties, 'Allow roll down slope'));

  Result := 0;
end;

procedure TVehicle.Init;
begin
  inherited;
//  OldQuat[0] := 0;
  Breaks := False;
  AllowBackward := True;
end;

function TVehicle.Process: Boolean;
var Temp, MaxSpeed: Single;
begin
  MaxSpeed := 200*EnginePower;
// Speed limit
  Speed := DotProductVector3s(ForwardVector, LVelocity);
  if Abs(Speed) > MaxSpeed then SubVector3s(LVelocity, LVelocity, ScaleVector3s(ForwardVector, Speed-MaxSpeed));
// Engine accelerate
  AddVector3s(LVelocity, LVelocity, GetVector3s(ForwardVector.X*Acceleration*EnginePower, 0, ForwardVector.Z*Acceleration*EnginePower));
// Elevation accelerate
  if AllowRollDown then begin
    Temp := 3.3*DotProductVector3s(ForwardVector, GetVector3s(UpVector.X, 0, UpVector.Z));
    AddVector3s(LVelocity, LVelocity, ScaleVector3s(ForwardVector, Temp*Sqr(Sqr(Sqr(Temp)))));
  end;
// Friction and breaks decelerate
  if Breaks then begin
    if SqrMagnitude(LVelocity) < Sqr(BreakForce)*2500 then LVelocity := GetVector3s(0, 0, 0) else ScaleVector3s(LVelocity, LVelocity, 1-BreakForce);
  end else begin
//    if SqrMagnitude(LVelocity) < 2*2 then LVelocity := GetVector3s(0, 0, 0) else
    ScaleVector3s(LVelocity, LVelocity, 1-GearFriction);
  end;
// Cross velocity friction
  AddVector3s(LVelocity, LVelocity, ScaleVector3s(RightVector, -BreakForce*DotProductVector3s(RightVector, LVelocity)));

  Result := inherited Process;
end;

{ TMeshManager }

constructor TMeshManager.Create(AVertexFormat, AOrder, ASorting: Integer; AWorld: TWorld);
begin
  World := AWorld;
  VertexCapacity := World.Renderer.MaxVertexIndex;
  TotalVertices := 0;
  Order := AOrder;
  StreamNum := World.Renderer.Streams.Add(VAllocStep, IAllocStep, AVertexFormat, 2, False);
  Sorting := ASorting;
  Items := nil; SortedItems := nil; TotalItems := 0;
  Meshes := nil; TotalMeshes := 0;
  CleanCount := 0;
end;

procedure TMeshManager.SetSorting(const ASorting: Cardinal);
const MinStack = 64;
var
  i, j, L, R, Temp: Integer;
  Temp2: Single;
  Temp1: TItem;
  StackPTR: Integer;
  StackSize: Integer;
  Stack: array[0..MinStack-1] of record
    l, r: Integer;
  end;
begin
  Sorting := ASorting;
  if Sorting = skNone then Exit;

  for i := 0 to TotalItems-1 do SortedItems[i] := i;

  if TotalItems < 2 then Exit;

  StackSize := MinStack;
//  SetLength(Stack, StackSize);
  StackPTR := 0; Stack[0].l := 0; Stack[0].r := TotalItems-1;
  repeat
    L := Stack[StackPTR].l;
    R := Stack[StackPTR].r;
    Dec(StackPTR);
    repeat
      i := L; j := R;
      Temp2 := Items[SortedItems[(L + R) shr 1]].Value;
      repeat
        if (Sorting = skAccending) or (Sorting = skXZAccending) or (Sorting = skZAccending) then begin
          while Temp2 > Items[SortedItems[i]].Value do Inc(i);
          while Temp2 < Items[SortedItems[j]].Value do Dec(j);
        end;
        if (Sorting = skDescending) or (Sorting = skXZDescending) or (Sorting = skZDescending) then begin
          while Temp2 < Items[SortedItems[i]].Value do Inc(i);
          while Temp2 > Items[SortedItems[j]].Value do Dec(j);
        end;
        if i <= j then begin
          Temp := SortedItems[i];
          SortedItems[i] := SortedItems[j];
          SortedItems[j] := Temp;
{          Temp1 := Items[i];
          Items[i] := Items[j];
          Items[j] := Temp1;
          Items[i].MMIndex := i;
          Items[j].MMIndex := j;}
          Inc(i); Dec(j);
        end;
      until i > j;
      if i < R then begin
        Inc(StackPTR);
        if StackPTR >= StackSize then begin
          Inc(StackSize, MinStack);
//          SetLength(Stack, StackSize);
        end;
        Stack[StackPTR].l := i;
        Stack[StackPTR].r := R;
      end;
      R := j;
    until L >= R;
  until StackPTR < 0;
//  Stack := nil;
end;

function TMeshManager.AddItem(const Item: TItem): TItem;
var AbsLoc: TVector4s;
begin
  Inc(TotalItems);
  if Length(Items) < TotalItems then begin
    SetLength(Items, TotalItems);
    SetLength(SortedItems, TotalItems);
  end;
  Items[TotalItems - 1] := Item;
  Items[TotalItems - 1].MMIndex := TotalItems - 1;
  if Sorting <> skNone then AbsLoc := Item.GetAbsLocation;
  with World.Renderer.RenderPars do case Sorting of
    skNone: ;
    skXZAccending, skXZDescending: Item.Value :=Abs(AbsLoc.X-Camera.X)+Abs(AbsLoc.Z-Camera.Z);
    skAccending, skDescending: Item.Value := Abs(AbsLoc.X-Camera.X)+Abs(AbsLoc.Y-Camera.Y)+Abs(AbsLoc.Z-Camera.Z);
    skZAccending, skZDescending: Item.Value := Abs(AbsLoc.Z-Camera.Z);
  end;

//  SetSorting(Sorting);                                    // ToFix: Move it to buldbuffer method

  Result := Item;
end;

procedure TMeshManager.DeleteItem(const Item: TItem);
begin
  if not (Item.MMIndex <= TotalItems) then begin
    Assert(Item.MMIndex <= TotalItems, 'TFXManager.DeleteItem: Index out of bounds');
  end;
  Dec(TotalItems);
  if Item.MMIndex < TotalItems then begin
    if Items[Item.MMIndex].CurrentLOD.TotalVertices = Items[TotalItems].CurrentLOD.TotalVertices then Items[TotalItems].CurrentLOD.Invalidate(False) else Items[TotalItems].CurrentLOD.Invalidate(True);
    if Items[Item.MMIndex].CurrentLOD.TotalIndices = Items[TotalItems].CurrentLOD.TotalIndices then Items[TotalItems].CurrentLOD.Invalidate(False) else Items[TotalItems].CurrentLOD.Invalidate(True);
    Items[Item.MMIndex] := Items[TotalItems];
    Items[Item.MMIndex].MMIndex := Item.MMIndex;
  end;
//  SetLength(Items, TotalItems);
  Item.MMIndex := -1;
end;

procedure TMeshManager.Clear;
begin
  TotalItems := 0;
//  SetLength(Items, TotalItems);
end;

procedure TMeshManager.Process;
begin
//  for i := 0 to TotalItems - 1 do Items[i].Process;
end;

procedure TMeshManager.BuildBuffer;
var i: Integer; VBuf, IBuf: PByte; RepeatRender: Boolean;
begin
  if (World.Renderer.State <> rsOK) and (World.Renderer.State <> rsClean) then Exit;        // ToFix: Where device lost test must be ?
//  if (Obj.Status <> tsStatic) and (Obj.CheckGeometry(RenderPars.Camera) or (State = rsClean) or (Obj.Status = tsSizeChanged) or (Obj.Status = tsChanged)) then begin

  repeat
    with World.Renderer.Streams do begin
//      Assert(Streams[StreamNum].VertexBuffer <> nil, 'VB of Stream is nil');
      VBuf := LockVBuffer(StreamNum, 0, Streams[StreamNum].VertexBufferSize, 0*lmNoOverwrite);
      if Streams[StreamNum].IndexBufferSize > 0 then IBuf := LockIBuffer(StreamNum, 0, Streams[StreamNum].IndexBufferSize, 0*lmNoOverwrite);
    end;

    World.Renderer.Streams.Streams[StreamNum].CurVBOffset := 0;
    World.Renderer.Streams.Streams[StreamNum].CurIBOffset := 0;

    RepeatRender := False;

    for i := 0 to TotalItems-1 do with World.Renderer, Streams, Streams[StreamNum] do begin
      if (VertexBufferSize <= (CurVBOffset + Items[i].CurrentLod.TotalVertices)*Items[i].CurrentLod.VertexSize) or
         ( IndexBufferSize <= (CurIBOffset + Items[i].CurrentLod.TotalIndices)*IndexSize) then begin
{$IFDEF DEBUGMODE} Inc(dResizeCount); {$ENDIF}
        if IndexBufferSize > 0 then World.Renderer.Streams.UnLockIBuffer(StreamNum);
        World.Renderer.Streams.UnLockVBuffer(StreamNum);
        World.Renderer.Streams.Resize(StreamNum, (((CurVBOffset + Items[i].CurrentLod.TotalVertices)*Items[i].CurrentLod.VertexSize) and VAllocMask + VAllocStep),
                                                 (((CurIBOffset + Items[i].CurrentLod.TotalIndices)*2) and IAllocMask + IAllocStep), 2, Static);
//        World.Renderer.BeginStream(StreamNum);
        RepeatRender := True;
        Break;
      end;
{$IFDEF DEBUGMODE} Inc(dTesselateCount); {$ENDIF}
      Items[i].CurrentLod.LastFrameTesselated := World.Renderer.FrameNumber;
      Items[i].CurrentLod.VBOffset := Streams[StreamNum].CurVBOffset;
//      Inc(Streams[StreamNum].CurVBOffset, Items[i].CurrentLod.Tesselate(RenderPars, Pointer(Cardinal(VBuf)+Streams[StreamNum].CurVBOffset)) * Items[i].CurrentLod.VertexSize);
      Streams[StreamNum].CurVBOffset := Streams[StreamNum].CurVBOffset + Items[i].CurrentLod.Tesselate(RenderPars, Pointer(Cardinal(VBuf)+Streams[StreamNum].CurVBOffset*Streams[StreamNum].VertexSize));
      if Items[i].CurrentLod.TotalIndices > 0 then begin
        Items[i].CurrentLod.IBOffset := Streams[StreamNum].CurIBOffset;
//        Inc(Streams[StreamNum].CurIBOffset, Items[i].CurrentLod.SetIndices(Pointer(Cardinal(IBuf)+Streams[StreamNum].CurIBOffset)) * Streams[StreamNum].IndexSize);
        Streams[StreamNum].CurIBOffset := Streams[StreamNum].CurIBOffset + Items[i].CurrentLod.SetIndices(Pointer(Cardinal(IBuf)+Streams[StreamNum].CurIBOffset*2));
      end;
    end;
  until not RepeatRender;

  if World.Renderer.Streams.Streams[StreamNum].IndexBufferSize > 0 then World.Renderer.Streams.UnLockIBuffer(StreamNum);
  World.Renderer.Streams.UnLockVBuffer(StreamNum);

{$IFDEF DEBUGMODE}
  dTotalBufferSize := {PopupIndex;//}World.Renderer.Streams.Streams[StreamNum].VertexBufferSize{ div Items[0].VertexSize};
{$ENDIF}
end;

procedure TMeshManager.Render;
var i, Ind, j: Integer;
begin
  SetSorting(Sorting);
  for Ind := 0 to TotalItems-1 do begin
    if Sorting = skNone then i := Ind else i := SortedItems[Ind];
//    Assert(Items[i].MMIndex = i, 'MeshManager.Render: Item "' + Items[i].Name + '" index mismatch');

    World.Renderer.SetCullMode(Items[i].CullMode);     // ToFix: move cullmode to render pass settings

    World.Renderer.WorldMatrix := Items[i].ModelMatrix;
    World.Renderer.WorldMatrix1 := Items[i].ModelMatrix1;

    if World.Renderer.BeginPasses(Items[i].CurrentLOD) then
     for j := 0 to Items[i].TotalPasses-1 do begin
       World.Renderer.BeginRenderPass(Items[i].RenderPasses[j]);
       World.Renderer.AddTesselator(Items[i].CurrentLod);
       World.Renderer.EndRenderPass(Items[i].RenderPasses[j]);
     end;
    World.Renderer.EndPasses;
    Items[i].CurrentLOD.CommandBlockValid := True;
  end;
end;

procedure TSmartMeshManager.BuildBuffer;
var
  i, PopupIndex, DiscardOffset, CurFrame, TesselatedItems: Integer;
  RepeatRender: Boolean;
  VBuf, IBuf: PByte;
begin
  if (World.Renderer.State <> rsOK) and (World.Renderer.State <> rsClean) then Exit;        // ToFix: Where device lost test must be ?
//  if (Obj.Status <> tsStatic) and (Obj.CheckGeometry(RenderPars.Camera) or (State = rsClean) or (Obj.Status = tsSizeChanged) or (Obj.Status = tsChanged)) then begin

  CurFrame := World.Renderer.FrameNumber;

  repeat
    with World.Renderer.Streams do begin
//      Assert(Streams[StreamNum].VertexBuffer <> nil, 'VB of Stream is nil');
      VBuf := LockVBuffer(StreamNum, 0, Streams[StreamNum].VertexBufferSize, {lmDiscard);//}0*lmNoOverwrite);
      if Streams[StreamNum].IndexBufferSize > 0 then IBuf := LockIBuffer(StreamNum, 0, Streams[StreamNum].IndexBufferSize, {lmDiscard);//}0*lmNoOverwrite);
    end;

    PopupIndex := -1;
    DiscardOffset := 0;
    i := 0;
    World.Renderer.Streams.Streams[StreamNum].CurVBOffset := 0;
    World.Renderer.Streams.Streams[StreamNum].CurIBOffset := 0;
    RepeatRender := False;
    if World.Renderer.State = rsClean then Inc(CleanCount) else while (i < TotalItems) do begin
// Discard the rest of buffer if mesh's size is changed or not tesselated after rsClean state
      if (Items[i].CurrentLOD.MeshManagerCleanCount <> CleanCount) or
         (Items[i].CurrentLOD.VBOffset <> World.Renderer.Streams.Streams[StreamNum].CurVBOffset) or   // Last tesselated into another place
         (Items[i].CurrentLOD.LastFrameVisualized < CurFrame-1) or
         (Items[i].CurrentLOD.VStatus = tsSizeChanged) or
         ((Items[i].CurrentLOD.TotalIndices > 0) and (Items[i].CurrentLOD.IStatus = tsSizeChanged)) then begin
        PopupIndex := i;
        DiscardOffset := World.Renderer.Streams.Streams[StreamNum].CurVBOffset;
        Break;
      end;
// Skip rendered and not changed meshes
      if Items[i].CurrentLOD.VStatus = tsTesselated then Inc(World.Renderer.Streams.Streams[StreamNum].CurVBOffset, Items[i].CurrentLod.LastTotalVertices);
      if Items[i].CurrentLOD.IStatus = tsTesselated then Inc(World.Renderer.Streams.Streams[StreamNum].CurIBOffset, Items[i].CurrentLod.LastTotalIndices);
// Tesselate changed meshes
      if Items[i].CurrentLOD.VStatus = tsChanged then begin
{$IFDEF DEBUGMODE} Inc(dTesselateCount); {$ENDIF}
        Items[i].CurrentLod.LastFrameTesselated := CurFrame;                                    // ToFix: make separate variable for vertices and indices
        Items[i].CurrentLod.VBOffset := World.Renderer.Streams.Streams[StreamNum].CurVBOffset;

        Assert(World.Renderer.Streams.Streams[StreamNum].VertexBufferSize >=
               (World.Renderer.Streams.Streams[StreamNum].CurVBOffset + Items[i].CurrentLod.GetMaxVertices)*Items[i].CurrentLod.VertexSize,
               'TSmartMeshManager.BuildBuffer: vertices tesselated exceeds buffer');
        Inc(World.Renderer.Streams.Streams[StreamNum].CurVBOffset, Items[i].CurrentLod.Tesselate(World.Renderer.RenderPars, Pointer(Cardinal(VBuf)+World.Renderer.Streams.Streams[StreamNum].CurVBOffset*Items[i].CurrentLod.VertexSize)));
      end;
      if (Items[i].CurrentLod.TotalIndices > 0) and (Items[i].CurrentLOD.IStatus = tsChanged) then begin
        Items[i].CurrentLod.IBOffset := World.Renderer.Streams.Streams[StreamNum].CurIBOffset;
        Inc(World.Renderer.Streams.Streams[StreamNum].CurIBOffset, Items[i].CurrentLod.SetIndices(Pointer(Cardinal(IBuf)+World.Renderer.Streams.Streams[StreamNum].CurIBOffset * World.Renderer.Streams.Streams[StreamNum].IndexSize)));
      end;
      Items[i].CurrentLOD.LastFrameVisualized := CurFrame;
      Inc(i);
    end;

    while (i < TotalItems) do with World.Renderer.Streams do begin                              // ToFix: eliminate next "if" (?)
      Items[i].CurrentLOD.LastFrameVisualized := CurFrame;
      if (Items[i].CurrentLod.VStatus <> tsTesselated) or ((Items[i].CurrentLod.IStatus <> tsTesselated) and (Items[i].CurrentLod.GetMaxIndices > 0)) or
         ( ((Streams[StreamNum].CurVBOffset {Items[i].CurrentLod.VBOffset} >= DiscardOffset){ or (World.Renderer.State = rsClean)}) and
           (Items[i].CurrentLod.LastFrameTesselated <> CurFrame) ) or
         (Items[i].CurrentLod.MeshManagerCleanCount <> CleanCount) then begin
        with Streams[StreamNum] do begin
          if (VertexBufferSize <= (CurVBOffset + Items[i].CurrentLod.GetMaxVertices)*Items[i].CurrentLod.VertexSize) or
             ( IndexBufferSize <= (CurIBOffset + Items[i].CurrentLod.GetMaxIndices)*IndexSize) then begin
{$IFDEF DEBUGMODE} Inc(dResizeCount); {$ENDIF}
            if IndexBufferSize > 0 then UnLockIBuffer(StreamNum);
            UnLockVBuffer(StreamNum);
            Resize(StreamNum, MaxI(VertexBufferSize, (((CurVBOffset + Items[i].CurrentLod.GetMaxVertices)*Items[i].CurrentLod.VertexSize) and VAllocMask + VAllocStep)),
                              MaxI(IndexBufferSize,  (((CurIBOffset + Items[i].CurrentLod.GetMaxIndices)*IndexSize) and IAllocMask + IAllocStep)), IndexSize, Static);
//            World.Renderer.BeginStream(StreamNum);
            Inc(CleanCount);
//            Items[0].CurrentLod.VStatus := tsSizeChanged; Items[0].CurrentLod.IStatus := tsSizeChanged;
            RepeatRender := True;
            Dec(CurFrame);
            Break;
          end;
        end;
    {$IFDEF DEBUGMODE} Inc(dTesselateCount); {$ENDIF}
        if not RepeatRender then begin                                               // Tesselate model
          Items[i].CurrentLod.MeshManagerCleanCount := CleanCount;
          Items[i].CurrentLod.LastFrameTesselated := CurFrame;
          Items[i].CurrentLod.VBOffset := Streams[StreamNum].CurVBOffset;
          TesselatedItems := Items[i].CurrentLod.Tesselate(World.Renderer.RenderPars, Pointer(Cardinal(VBuf)+Streams[StreamNum].CurVBOffset * Items[i].CurrentLod.VertexSize));
          Inc(Streams[StreamNum].CurVBOffset, TesselatedItems);
          Assert(TesselatedItems <= Items[i].CurrentLod.GetMaxVertices, 'TSmartMeshManager.BuildBuffer: vertices tesselated exceeds maximum');
          if Items[i].CurrentLod.GetMaxIndices > 0 then begin
            Items[i].CurrentLod.IBOffset := Streams[StreamNum].CurIBOffset;
            TesselatedItems := Items[i].CurrentLod.SetIndices(Pointer(Cardinal(IBuf)+Streams[StreamNum].CurIBOffset * Streams[StreamNum].IndexSize));
            Inc(Streams[StreamNum].CurIBOffset, TesselatedItems);
            Assert(TesselatedItems <= Items[i].CurrentLod.GetMaxIndices, 'TSmartMeshManager.BuildBuffer: indices tesselated exceeds maximum');
          end;
        end;
      end;
      Inc(i);
    end;
  until not RepeatRender;

  if World.Renderer.Streams.Streams[StreamNum].IndexBufferSize > 0 then World.Renderer.Streams.UnLockIBuffer(StreamNum);
  World.Renderer.Streams.UnLockVBuffer(StreamNum);

{$IFDEF DEBUGMODE} dTotalBufferSize := {PopupIndex;//}World.Renderer.Streams.Streams[StreamNum].VertexBufferSize{ div Items[0].VertexSize}; {$ENDIF}
{  if (PopupIndex >= 0) and (PopupIndex < TotalItems - 1) then begin
    Temp := Items[PopupIndex];
    for i := PopupIndex + 1 to TotalItems - 1 do begin
      Items[i-1] := Items[i];
      Items[i-1].Index := i-1;
    end;
//    Items[PopupIndex] := Items[TotalItems - 1];
    Items[TotalItems - 1] := Temp;
    Items[TotalItems - 1].Index := TotalItems - 1;
    Items[PopupIndex].Index := PopupIndex;
    Items[PopupIndex].CurrentLod.Status := tsMoved;
  end;}
end;

// TActor                      

constructor TActor.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  MeshClass := TMeshTesselator;
end;

function TActor.LoadResources: Integer;
begin
  { TODO: Resources dynamic loading}
//  CurrentLOD.Material.Stages[0].TextureID := World.FRenderer.AddTexture(TextureRes);
end;

procedure TActor.SetMeshResources(const AVerticesRes, AIndicesRes: Integer);
begin
  inherited;
  ClearMeshes;
  with World.ResourceManager do begin
    if (AVerticesRes >= 0) and (AVerticesRes < TotalResources) or (AIndicesRes >= 0) and (AIndicesRes < TotalResources) then 
     AddLOD(World.AddMesh(World.CreateActorMesh(MeshClass, AVerticesRes, AIndicesRes)));
  end;
  if CurrentLOD <> nil then begin
    BoundingBox := Meshes[0].CalcBoundingBox;
  end else begin
    BoundingBox.P1 := GetVector3s(0, 0, 0);
    BoundingBox.P2 := GetVector3s(0, 0, 0);
  end;
{  CalcDimensions;
  with BoundingBox do begin
    Controls[0].X := P2.X; Controls[0].Y := P1.Y; Controls[0].Z := P1.Z;
    Controls[1].X := P2.X; Controls[1].Y := P1.Y; Controls[1].Z := P2.Z;
    Controls[2].X := P1.X; Controls[2].Y := P1.Y; Controls[2].Z := P1.Z;
    Controls[3].X := P1.X; Controls[3].Y := P1.Y; Controls[3].Z := P2.Z;
  end;}
end;

procedure TMeshManager.AddMesh(const AMesh: TTesselator);
begin
  Inc(TotalMeshes); SetLength(Meshes, TotalMeshes);
  Meshes[TotalMeshes-1] := AMesh;
  Inc(TotalVertices, AMesh.TotalVertices);
end;

procedure TMeshManager.DeleteMesh(const AMesh: TTesselator);
var Index: Integer;
begin
  Index := MeshExists(AMesh);
  if Index = -1 then Exit;
  for Index := Index to TotalMeshes-2 do Meshes[Index] := Meshes[Index+1];
  Dec(TotalMeshes); SetLength(Meshes, TotalMeshes);
  Dec(TotalVertices, AMesh.TotalVertices);
end;

function TMeshManager.MeshExists(const AMesh: TTesselator): Integer;
begin
  for Result := 0 to TotalMeshes-1 do if Meshes[Result] = AMesh then Exit;
  Result := -1;
end;

{ TDebugManager }

constructor TDebugManager.Create(AVertexFormat, AOrder, ASorting: Integer; AWorld: TWorld);
var i, VBSize, IBSize: Integer;
begin
  inherited;
  TotalDMeshes := 2; SetLength(DMeshes, TotalDMeshes);
  with World.ResourceManager do begin
//    TMeshTesselator(DMeshes[0]) := CreateSphereMesh(ResourceByName('Ver_Sphere') as TArrayResource, ResourceByName('Ind_Sphere') as TArrayResource);
//    if DMeshes[0] = nil then TMeshTesselator(DMeshes[0]) := CreateBoxMesh;
    DMeshes[0] := GetSphereMesh(GetVector3s(0, 0, 0), 1, $FF00FF00, $FFFF0000);
    DMeshes[1] := GetBoxMesh(GetVector3s(1, 1, 1), GetVector3s(-1, -1, -1), $FFFFFF00);
  end;
//  TMeshTesselator(DMeshes[1]) := CreateBoxMesh;
  World.DebugMaterial := TMaterial.Create('Debug default', World.Renderer);
  World.DebugMaterial.SetStage(0, GetStage(-1, toArg1, taDiffuse, taDiffuse, taWrap, tfLinear, tfLinear, tfLinear, 0));
//  World.DebugMaterial.FillMode := fmWire;

  VBSize := 0; IBSize := 0;
  for i := 0 to TotalDMeshes-1 do begin
    Inc(VBSize, DMeshes[i].TotalVertices*DMeshes[i].VertexSize);
    Inc(IBSize, DMeshes[i].TotalIndices*World.Renderer.Streams.Streams[StreamNum].IndexSize);
  end;

  World.Renderer.Streams.Resize(StreamNum, VBSize, IBSize, World.Renderer.Streams.Streams[StreamNum].IndexSize, World.Renderer.Streams.Streams[StreamNum].Static);
end;

procedure TDebugManager.AddBVolume(BVol: TBoundingVolumes; Matrix: TMatrix4s);
var i: Integer; Temp: TMatrix4s;
begin
  for i := 0 to High(BVol) do begin
    Inc(TotalItems); SetLength(Items, TotalItems); SetLength(Matrices, TotalItems);
    Items[TotalItems-1] := 1-BVol[i].VolumeKind;
    Matrices[TotalItems-1] := Matrix;
    Temp := TranslationMatrix4s(BVol[i].Offset.X, BVol[i].Offset.Y, BVol[i].Offset.Z);
    Matrices[TotalItems-1] := MulMatrix4s(Temp, Matrices[TotalItems-1]);
    if BVol[i].VolumeKind = bvSphere then
     Temp := ScaleMatrix4s(BVol[i].Dimensions.X, BVol[i].Dimensions.X, BVol[i].Dimensions.X) else
      Temp := ScaleMatrix4s(BVol[i].Dimensions.X, BVol[i].Dimensions.Y, BVol[i].Dimensions.Z);
    Matrices[TotalItems-1] := MulMatrix4s(Temp, Matrices[TotalItems-1]);
    with Matrices[TotalItems-1] do begin
//      _11 := _11 * BVolume.Dimensions.X / 1; _22 := _22 * BVolume.Dimensions.Y / 1; _33 := _33 * BVolume.Dimensions.Z / 1;
    end;
  end;
end;

//function TDebugManager.AddMesh(const Mesh: TTesselator): TTesselator;
function TDebugManager.AddMesh(AName: TShortName; const AVerticesRes, AIndicesRes: Integer): TTesselator;
var i: Integer;
begin
  Result := nil;
  if (AVerticesRes >= World.Renderer.Resources.TotalResources) or (AVerticesRes < 0) or
   (AIndicesRes >= World.Renderer.Resources.TotalResources) or (AIndicesRes < 0) then Exit;
  for i := 0 to TotalItems-1 do if (AVerticesRes = DMeshes[i].VerticesRes) and (AIndicesRes = DMeshes[i].IndicesRes) then begin
    Result := DMeshes[i]; Exit;
  end;
  Result := TMeshTesselator.Create(AName, TArrayResource(World.Renderer.Resources[AVerticesRes]).TotalElements, nil,
                                          TArrayResource(World.Renderer.Resources[AIndicesRes]).TotalElements, World.Renderer.Resources[AIndicesRes].Data);
  with Result do begin
    VertexFormat := GetVertexFormat(False, False, True, False, 0);
    VertexSize := GetVertexSize(VertexFormat);
  end;
  GetMem(Result.Vertices, Result.TotalVertices*Result.VertexSize);
  for i := 0 to Result.TotalVertices-1 do with TCDBufferType(Result.Vertices^)[i] do begin
    X := TCNDTBufferType(World.Renderer.Resources[AVerticesRes].Data^)[i].X;
    Y := TCNDTBufferType(World.Renderer.Resources[AVerticesRes].Data^)[i].Y;
    Z := TCNDTBufferType(World.Renderer.Resources[AVerticesRes].Data^)[i].Z;
    DColor := $FF00FF00;
  end;
  Inc(TotalDMeshes); SetLength(DMeshes, TotalDMeshes);
  DMeshes[TotalDMeshes-1] := Result;
end;

procedure TDebugManager.BuildBuffer;
var i: Integer; Changed, RepeatRender: Boolean; Temp: Pointer; Res: HResult; VBuf, IBuf: PByte;
begin
  if (World.Renderer.State <> rsOK) and (World.Renderer.State <> rsClean) then Exit;        // ToFix: Where device lost test must be ?
//  if World.Renderer.State = rsClean then for i := 0 to TotalDMeshes-1 do DMeshes[i].Status := tsChanged;
  with World.Renderer.Streams do begin
//    Assert(Streams[StreamNum].VertexBuffer <> nil, 'VB of Stream is nil');
    VBuf := LockVBuffer(StreamNum, 0, Streams[StreamNum].VertexBufferSize, lmNone);
    if Streams[StreamNum].IndexBufferSize > 0 then IBuf := LockIBuffer(StreamNum, 0, Streams[StreamNum].IndexBufferSize, 0);

    Streams[StreamNum].CurVBOffset := 0; Streams[StreamNum].CurIBOffset := 0;
    for i := 0 to TotalDMeshes - 1 do begin
      DMeshes[i].VBOffset := Streams[StreamNum].CurVBOffset div DMeshes[i].VertexSize;
      Inc(Streams[StreamNum].CurVBOffset, DMeshes[i].Tesselate(World.Renderer.RenderPars, Pointer(Cardinal(VBuf)+Streams[StreamNum].CurVBOffset)) * DMeshes[i].VertexSize);
      if DMeshes[i].TotalIndices > 0 then begin
        DMeshes[i].IBOffset := Streams[StreamNum].CurIBOffset shr 1;
        Inc(Streams[StreamNum].CurIBOffset, DMeshes[i].SetIndices(Pointer(Cardinal(IBuf)+Streams[StreamNum].CurIBOffset)) * Streams[StreamNum].IndexSize);
      end;
    end;
  end;  
  if World.Renderer.Streams.Streams[StreamNum].IndexBufferSize > 0 then World.Renderer.Streams.UnLockIBuffer(StreamNum);
  World.Renderer.Streams.UnLockVBuffer(StreamNum);
end;

procedure TDebugManager.Render;
var i: Integer;
begin
  for i := 0 to TotalItems-1 do begin
    World.Renderer.WorldMatrix := Matrices[i];
    World.Renderer.ApplyMaterial(World.DebugMaterial);
    World.Renderer.AddTesselator(DMeshes[Items[i]]);
  end;
end;

{ TBaseParticleItem }

constructor TParticleSystem.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited Create(AName, AWorld, AParent);
  AddLOD(TParticlesMesh.Create(''));
  DefaultColor := $FF808080;
  DefaultRadius := 1000;
  FastKill := True;
  OuterForce := GetVector3s(0, 0, 0);
end;

function TParticleSystem.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Particles default color', ptColor32, Pointer(DefaultColor));
  NewProperty(Result, 'Particles default size', ptNat32, Pointer(DefaultRadius));
  NewProperty(Result, 'Particles default lifetime', ptNat32, Pointer(DefaultLifetime));
  NewProperty(Result, 'Max particles', ptNat32, Pointer(TParticlesMesh(CurrentLOD).MaxCapacity));
  NewProperty(Result, 'Emitter radius', ptSingle, Pointer(EmitRadius));
  NewProperty(Result, 'Global velocity X', ptSingle, Pointer(GlobalVelocity.X));
  NewProperty(Result, 'Global velocity Y', ptSingle, Pointer(GlobalVelocity.Y));
  NewProperty(Result, 'Global velocity Z', ptSingle, Pointer(GlobalVelocity.Z));
  NewProperty(Result, 'Local coordinates', ptBoolean, Pointer(LocalCoordinates));
  NewProperty(Result, 'Uniform emit', ptBoolean, Pointer(UniformEmit));
  NewProperty(Result, 'Uniform emit space', ptSingle, Pointer(EmitSpace));
  NewProperty(Result, 'Rotation support', ptBoolean, Pointer(RotationSupport));
  NewProperty(Result, 'Fast killing', ptBoolean, Pointer(FastKill));
  NewProperty(Result, 'Reverse order', ptBoolean, Pointer(TParticlesMesh(CurrentLOD).ReverseOrder));
end;

function TParticleSystem.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  DefaultColor := Longword(GetPropertyValue(AProperties, 'Particles default color'));
  DefaultRadius := Cardinal(GetPropertyValue(AProperties, 'Particles default size'));
  DefaultLifetime := Cardinal(GetPropertyValue(AProperties, 'Particles default lifetime'));
  TParticlesMesh(CurrentLOD).MaxCapacity := Cardinal(GetPropertyValue(AProperties, 'Max particles'));
  EmitRadius := Single(GetPropertyValue(AProperties, 'Emitter radius'));
  GlobalVelocity.X := Single(GetPropertyValue(AProperties, 'Global velocity X'));
  GlobalVelocity.Y := Single(GetPropertyValue(AProperties, 'Global velocity Y'));
  GlobalVelocity.Z := Single(GetPropertyValue(AProperties, 'Global velocity Z'));
  LocalCoordinates := Boolean(GetPropertyValue(AProperties, 'Local coordinates'));
  UniformEmit := Boolean(GetPropertyValue(AProperties, 'Uniform emit'));
  EmitSpace := Single(GetPropertyValue(AProperties, 'Uniform emit space'));
  RotationSupport := Boolean(GetPropertyValue(AProperties, 'Rotation support'));
  FastKill := Boolean(GetPropertyValue(AProperties, 'Fast killing'));
  TParticlesMesh(CurrentLOD).ReverseOrder := Boolean(GetPropertyValue(AProperties, 'Reverse order'));

  TicksProcessed := 0;

  Result := 1;
end;

procedure TParticleSystem.SetupExternalVariables;
begin
  inherited;
{$IFDEF SCRIPTING}
  World.Compiler.ImportExternalVar('DefaultColor', 'LONGINT', @DefaultColor);
  World.Compiler.ImportExternalVar('DefaultRadius', 'LONGINT', @DefaultRadius);
  World.Compiler.ImportExternalVar('TotalParticles', 'LONGINT', @T3DParticlesMesh(CurrentLOD).TotalParticles);
  World.Compiler.ImportExternalVar('Particles', 'TParticles', @T3DParticlesMesh(CurrentLOD).Particles[0]);
  World.Compiler.ImportExternalVar('ParticlesToEmit', 'LONGINT', @ParticlesToEmit);
{$ENDIF}
end;

function TParticleSystem.Emit(Count: Single): Integer;
var i: Integer; PMesh: TParticlesMesh;
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
    PMesh := TParticlesMesh(CurrentLOD);

    Result := PMesh.AddParticles(Result);

    for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
      Position := GetVector3s(Random * EmitRadius, Random * EmitRadius, Random * EmitRadius);
      Velocity := EmitterVelocity;
      if UniformEmit then AddVector3s(Position, Position, ScaleVector3s(SubVector3s(LastEmitLocation, GetAbsLocation3s), Random));
      Radius := DefaultRadius;
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

procedure TParticleSystem.Kill(Index: Integer);
var i: Integer;
begin
  if (Index < 0) or (Index >= TParticlesMesh(CurrentLOD).TotalParticles) then Exit;
  CurrentLOD.Invalidate(True);
  Dec(TParticlesMesh(CurrentLOD).TotalParticles);
  if Index = TParticlesMesh(CurrentLOD).TotalParticles then Exit;
  if FastKill then
   TParticlesMesh(CurrentLOD).Particles[Index] := TParticlesMesh(CurrentLOD).Particles[TParticlesMesh(CurrentLOD).TotalParticles] else
    for i := Index+1 to TParticlesMesh(CurrentLOD).TotalParticles do TParticlesMesh(CurrentLOD).Particles[i-1] := TParticlesMesh(CurrentLOD).Particles[i];
end;

procedure TParticleSystem.KillAll;
begin
  if TParticlesMesh(CurrentLOD).TotalParticles = 0 then Exit;
  CurrentLOD.Invalidate(True);
  TParticlesMesh(CurrentLOD).TotalParticles := 0;
end;

{ TSky }

constructor TSky.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited Create(AName, AWorld, AParent);
  AddLOD(TSkyDomeTesselator.Create('SkyMesh'));
  ClearRenderPasses;
  AddRenderPass(bmOne, bmZero, tfAlways, tfAlways, 0, False, False);
  SetMaterial(0, 'Sky');
  SMResIndex := -1;
  Order := -300;
  TSkyDomeTesselator(CurrentLOD).SetParameters(16, 32, 65536, 65536, 1, False, True, True);
//  Status := Status or isUnique;
  SetPlace := True;
  AttachedToCamera := True; FixedY := True;
  Place := GetVector3s(0, 0, 0);
end;

function TSky.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Attached to camera', ptBoolean, Pointer(AttachedToCamera));
  NewProperty(Result, 'Fixed Y', ptBoolean, Pointer(FixedY));
  NewProperty(Result, 'Vertical', ptBoolean, Pointer(TSkyDomeTesselator(CurrentLOD).Vertical));
  NewProperty(Result, 'Geometry', ptGroupBegin, nil);
    NewProperty(Result, 'Sectors', ptInt32, Pointer(TSkyDomeTesselator(CurrentLOD).Sectors));
    NewProperty(Result, 'Segments', ptInt32, Pointer(TSkyDomeTesselator(CurrentLOD).Segments+1));
    NewProperty(Result, 'Radius', ptSingle, Pointer(TSkyDomeTesselator(CurrentLOD).Radius));
    NewProperty(Result, 'Height', ptSingle, Pointer(TSkyDomeTesselator(CurrentLOD).Height));
    NewProperty(Result, 'Inner dome surface', ptBoolean, Pointer(TSkyDomeTesselator(CurrentLOD).Inner));
  NewProperty(Result, '', ptGroupEnd, nil);
  NewProperty(Result, 'Texture scale', ptSingle, Pointer(TSkyDomeTesselator(CurrentLOD).TexK));
  NewProperty(Result, 'Clamp texture', ptBoolean, Pointer(TSkyDomeTesselator(CurrentLOD).TexClamp));
  NewProperty(Result, 'Sky map', ptResource + World.ResourceManager.GetResourceClassIndex('TImageResource') shl 8, Pointer(SMResIndex));
end;

function TSky.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  AttachedToCamera := Boolean(GetPropertyValue(AProperties, 'Attached to camera'));
  FixedY := Boolean(GetPropertyValue(AProperties, 'Fixed Y'));

  TSkyDomeTesselator(CurrentLOD).SetParameters(Integer(GetPropertyValue(AProperties, 'Sectors')), Integer(GetPropertyValue(AProperties, 'Segments')),
                                               Single(GetPropertyValue(AProperties, 'Radius')), Single(GetPropertyValue(AProperties, 'Height')),
                                               Single(GetPropertyValue(AProperties, 'Texture scale')), Boolean(GetPropertyValue(AProperties, 'Clamp texture')),
                                               Boolean(GetPropertyValue(AProperties, 'Inner dome surface')), Boolean(GetPropertyValue(AProperties, 'Vertical')));
  SetSkyMap(Integer(GetPropertyValue(AProperties, 'Sky map')));

  Result := 0;
end;

procedure TSky.Render(Renderer: TRenderer);
begin
  SetPlace := False;
  if AttachedToCamera then
   SetLocation(GetVector3s(Place.X + World.Renderer.RenderPars.Camera.X, Place.Y + Byte(not FixedY)*World.Renderer.RenderPars.Camera.Y, Place.Z + World.Renderer.RenderPars.Camera.Z));
  SetPlace := True;
  inherited;
end;

procedure TSky.SetSkyMap(ResIndex: Integer);
begin
  if not (World.ResourceManager.Resources[ResIndex] is TImageResource) then Exit;
  SMResIndex := ResIndex;
  with TSkyDomeTesselator(CurrentLOD) do begin
    SkyMap := World.ResourceManager.Resources[ResIndex].Data;
    SMWidth := TImageResource(World.ResourceManager.Resources[ResIndex]).Width;
    SMHeight := TImageResource(World.ResourceManager.Resources[ResIndex]).Height;
    Invalidate(False);
  end;
end;

procedure TSky.SetLocation(ALocation: TVector3s);
begin
  inherited;
  if SetPlace then Place := Location;
end;

function TSky.GetLocation: TVector3s;
begin
  Result := Place;
end;

{ TLandscape }

constructor TBigLandscape.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited Create(AName, AWorld, AParent);
  Status := Status or isUnique;
  AddLOD(TBigLandscapeTesselator.Create('LandMesh'));
  TBigLandscapeTesselator(CurrentLOD).SetParameters(100, 100, 256, 0);
  Order := -100;
end;

procedure TBigLandscape.Init(AHeightMap: THCNMap);
var Props: TProperties;
begin
  inherited;
  if CurrentLOD <> nil then Props := GetProperties;                     //ToFix: Bug here ? (Props might not be initialized)
//  ClearMeshes;
//  AddLOD(TLandscapeTesselator.Create('LandMesh', HeightMap.TilePower, HeightMap.MapWidth, HeightMap.MapHeight, HeightMap.MapPower, HeightMap.LitMap));

  TBigLandscapeTesselator(CurrentLOD).Init(AHeightMap, AHeightMap.LitMap);
  SetProperties(Props);
end;

function TBigLandscape.GetProperties: TProperties;
var OldLen: Integer;
begin
  Result := inherited GetProperties;
  OldLen := Length(Result);
  SetLength(Result, OldLen + 5);

  Result[OldLen + 0].Name := 'X accuracy';
  Result[OldLen + 0].ValueType := ptInt32;
  Result[OldLen + 0].Value := Pointer(TBigLandscapeTesselator(CurrentLOD).XAcc);

  Result[OldLen + 1].Name := 'Z accuracy';
  Result[OldLen + 1].ValueType := ptInt32;
  Result[OldLen + 1].Value := Pointer(TBigLandscapeTesselator(CurrentLOD).AAcc);

  Result[OldLen + 2].Name := 'Texture magnify factor';
  Result[OldLen + 2].ValueType := ptSingle;
  Result[OldLen + 2].Value := Pointer(TBigLandscapeTesselator(CurrentLOD).TextureMag);

  Result[OldLen + 3].Name := 'Depth of view';
  Result[OldLen + 3].ValueType := ptNat32;
  Result[OldLen + 3].Value := Pointer(TBigLandscapeTesselator(CurrentLOD).DepthOfView);

  Result[OldLen + 4].Name := 'Smooth amount';
  Result[OldLen + 4].ValueType := ptNat32;
  Result[OldLen + 4].Value := Pointer(TBigLandscapeTesselator(CurrentLOD).Smooth);
end;

function TBigLandscape.SetProperties(AProperties: TProperties): Integer;
var OldLen: Integer;
begin
  Result := -1;
  OldLen := inherited SetProperties(AProperties);
  if OldLen < 0 then Exit;
  if Length(AProperties) - OldLen < 5 then Exit;
  if AProperties[OldLen + 0].ValueType <> ptInt32 then Exit;
  if AProperties[OldLen + 1].ValueType <> ptInt32 then Exit;
  if AProperties[OldLen + 2].ValueType <> ptSingle then Exit;
  if AProperties[OldLen + 3].ValueType <> ptNat32 then Exit;
  if AProperties[OldLen + 4].ValueType <> ptNat32 then Exit;

  with TBigLandscapeTesselator(CurrentLOD) do begin
    SetParameters(LongWord(AProperties[OldLen + 0].Value), LongWord(AProperties[OldLen + 1].Value), LongWord(AProperties[OldLen + 3].Value), LongWord(AProperties[OldLen + 4].Value));
    TextureMag := Single(AProperties[OldLen + 2].Value);
  end;

  Result := OldLen + 5;
end;

procedure TBigLandscape.SetDetail(const AQuality, ADetail: Integer);
begin
  TBigLandscapeTesselator(CurrentLOD).SetParameters(AQuality, ADetail, TBigLandscapeTesselator(CurrentLOD).DepthOfView, TBigLandscapeTesselator(CurrentLOD).Smooth);        //ToFix: make it via parameters
end;

{ TLandscape }

procedure TLandscape.Init(AHeightMap: THCNMap);
var i: Integer;
begin
  HeightMap := AHeightMap;
  LandscapeMaxX := HeightMap.MapWidth * HeightMap.TileSize - HeightMap.MapHalfWidth;
  LandscapeMaxZ := HeightMap.MapHeight * HeightMap.TileSize - HeightMap.MapHalfHeight;
  for i := 0 to World.TotalLights-1 do World.ModifyLight(i, World.Lights[i]);
end;

procedure TLandscape.MakeCrater(const X, Z: Single; const Radius: Integer);
begin
  CurrentLOD.Invalidate(True);
  HeightMap.MakeCrater(X, Z, Radius);
end;

{ TIslandLandcape }

constructor TIslandLandcape.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited Create(AName, AWorld, AParent);
  AddLOD(TIslandTesselator.Create('IslandMesh'));
  Order := -100;
end;

function TIslandLandcape.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Island X scale', ptSingle, Pointer(TIslandTesselator(CurrentLOD).IslandScaleX));
  NewProperty(Result, 'Island Y scale', ptSingle, Pointer(TIslandTesselator(CurrentLOD).IslandScaleY));
  NewProperty(Result, 'Island Z scale', ptSingle, Pointer(TIslandTesselator(CurrentLOD).IslandScaleZ));
  NewProperty(Result, 'Texture scale', ptSingle, Pointer(TIslandTesselator(CurrentLOD).TextureMag));
  NewProperty(Result, 'Island thickness', ptSingle, Pointer(TIslandTesselator(CurrentLOD).IslandThickness));
end;

function TIslandLandcape.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  TIslandTesselator(CurrentLOD).IslandScaleX := Single(GetPropertyValue(AProperties, 'Island X scale'));
  TIslandTesselator(CurrentLOD).IslandScaleY := Single(GetPropertyValue(AProperties, 'Island Y scale'));
  TIslandTesselator(CurrentLOD).IslandScaleZ := Single(GetPropertyValue(AProperties, 'Island Z scale'));
  TIslandTesselator(CurrentLOD).TextureMag := Single(GetPropertyValue(AProperties, 'Texture scale'));
  TIslandTesselator(CurrentLOD).IslandThickness := Single(GetPropertyValue(AProperties, 'Island thickness'));
  CurrentLOD.Invalidate(False);

  if HeightMap <> nil then HeightMap.BreakHeight := Single(GetPropertyValue(AProperties, 'Island thickness'));

  Result := 0;
end;

procedure TIslandLandcape.Init(AHeightMap: THCNMap);
var Props: TProperties;
begin
  inherited;
  if CurrentLOD <> nil then Props := GetProperties;                     //ToFix: Bug here ? (Props might not be initialized)
//  ClearMeshes;
//  AddLOD(TIslandTesselator.Create('IslandMesh', AHeightMap, AHeightMap.LitMap));
  TIslandTesselator(CurrentLOD).Init(AHeightMap, AHeightMap.LitMap);
  SetProperties(Props);
end;

procedure TItem.SetDetail(const AQuality, ADetail: Integer);
begin
end;

procedure TItem.SetSystemProcessing(const Value: Boolean);
begin
  if (FSystemProcessing = False) and (Value = True) then World.AddSysItem(Self);
  if (FSystemProcessing = True) and (Value = False) then World.DeleteSysItem(Self);
  FSystemProcessing := Value;
end;

procedure TWorld.AddSysItem(const AItem: TItem);
var i: Integer;
begin
  for i := 0 to TotalSysItems-1 do if SysItems[i] = AItem then Exit;
  Inc(TotalSysItems);
  SetLength(SysItems, TotalSysItems);
  SysItems[TotalSysItems-1] := AItem;
end;

procedure TWorld.DeleteSysItem(const AItem: TItem);
var i: Integer;
begin
  for i := 0 to TotalSysItems-1 do if SysItems[i] = AItem then begin
    if i < TotalSysItems-1 then begin
      SysItems[i] := SysItems[TotalSysItems-1];
    end;
    Dec(TotalSysItems); SetLength(SysItems, TotalSysItems);
    Break;
  end;
end;

procedure TItem.Hide;
begin
  Status := Status and not isVisible;
end;

procedure TItem.Show;
begin
  Status := Status or isVisible;
  if CurrentLOD <> nil then begin
    CurrentLOD.VStatus := tsSizeChanged;
    CurrentLOD.IStatus := tsSizeChanged;
  end;
end;

function TParticleSystem.GetParticleCount: Integer;
begin
  Result := (CurrentLOD as TParticlesMesh).TotalParticles;
end;

procedure TParticleSystem.UpdateMesh;
var PMesh: TParticlesMesh;
begin
  PMesh := CurrentLOD as TParticlesMesh;
  with PMesh do begin
    if Quads then begin
      TotalVertices := TotalParticles*4; TotalPrimitives := TotalParticles*2;
      TotalIndices := TotalParticles*6;
    end else begin
      TotalVertices := TotalParticles*3; TotalPrimitives := TotalParticles*1;
      TotalIndices := 0;
    end;
  end;
  CurrentLOD.Invalidate(True);
end;

procedure TWorld.ProcessClientCommand(Command: TCommand; NeedSend: Boolean = False);
begin
  ClientCommandLog.Add(CommandTo4(Command, CurrentTick));
end;

function TWorld.GetItemByName(AName: TShortName; SearchAllChilds: Boolean): TItem;
var i: Integer;
begin
  AName := UpperCase(AName);
  Result := nil;
  for i := 0 to TotalItems-1 do if (Items[i] <> nil) then begin
    if UpperCase(Items[i].Name) = AName then begin
      Result := Items[i]; Exit;
    end else if SearchAllChilds then begin
      Result := Items[i].GetChildByName(AName, True);
      if Result <> nil then Exit;
    end;
  end;
end;

{ TStandingActor }

constructor TStandingActor.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  ZeroLevel := 0;
  StandScale := GetVector3s(1, 1, 1);
end;

function TStandingActor.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Zero level bias', ptSingle, Pointer(ZeroLevel));
  NewProperty(Result, 'Standing box scale X', ptSingle, Pointer(StandScale.X));
  NewProperty(Result, 'Standing box scale Y', ptSingle, Pointer(StandScale.Y));
  NewProperty(Result, 'Standing box scale Z', ptSingle, Pointer(StandScale.Z));
end;

function TStandingActor.SetProperties(AProperties: TProperties): Integer;
const One: Single = 1.0;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  ZeroLevel := Single(GetPropertyValue(AProperties, 'Zero level bias'));
  StandScale := GetVector3s(Single(GetPropertyValue(AProperties, 'Standing box scale X', Pointer((@One)^))),
                            Single(GetPropertyValue(AProperties, 'Standing box scale Y', Pointer((@One)^))),
                            Single(GetPropertyValue(AProperties, 'Standing box scale Z', Pointer((@One)^))) );
  Result := 0;
end;

function TStandingActor.Process: Boolean;
const HDiffError = 64.0; E1 = 128; Iterations = 20;
var
  i, j, StandPoints, MinHI, Iteration: Integer;
  TransCP: array[0..3] of TVector4s;
  TouchP:  array[0..1] of Integer;
  HDiff: array[0..3] of Single;
//  Temp1: TMatrix4s;
  MinHDiff, MaxHDiff: Single;
  Axis: TVector3s;
  Diff: TVector3s;
  Quat: TQuaternion;
  Temp, OldY: Single;

  GForce: TVector3s;
  FinalUp: TVector3s;

procedure GetHDiffs;
var i: Integer;
begin
  StandPoints := 0;
  MinHDiff := 1E38; MaxHDiff := -1E38;

  for i := 0 to 3 do begin
    TransCP[i] := Transform4Vector3s(ModelMatrix, CartesianProductVector3s(Controls[i], StandScale));
    HDiff[i] := TransCP[i].Y - World.Landscape.HeightMap.GetHeight(TransCP[i].X, TransCP[i].Z) + ZeroLevel;
    if HDiff[i] <= HDiffError then begin
      if StandPoints < 2 then TouchP[StandPoints] := i;
      Inc(StandPoints);
    end else begin
//      if HDiff[i] > NonTouchH then NonTouchH := HDiff[i];
    end;
    if HDiff[i] < MinHDiff then begin MinHDiff := HDiff[i]; MinHI := i; end;
    if HDiff[i] > MaxHDiff then MaxHDiff := HDiff[i];
  end;
end;

begin
  Result := inherited Process;

  AddVector3s(Location, Location, LVelocity);
  if Location.X < -World.Landscape.LandscapeMaxX + FullBoundingBox.P2.Z then begin
    Location.X := -World.Landscape.LandscapeMaxX + FullBoundingBox.P2.Z;
    LVelocity.X := - LVelocity.X;
  end;
  if Location.X > World.Landscape.LandscapeMaxX + FullBoundingBox.P1.Z then begin
    Location.X := World.Landscape.LandscapeMaxX + FullBoundingBox.P1.Z;
    LVelocity.X := - LVelocity.X;
  end;
  if Location.Z < -World.Landscape.LandscapeMaxZ + FullBoundingBox.P2.Z then begin
    Location.Z := -World.Landscape.LandscapeMaxZ  + FullBoundingBox.P2.Z;
    LVelocity.Z := - LVelocity.Z;
  end;
  if Location.Z > World.Landscape.LandscapeMaxZ + FullBoundingBox.P1.Z then begin
    Location.Z := World.Landscape.LandscapeMaxZ + FullBoundingBox.P1.Z;
    LVelocity.Z := - LVelocity.Z;
  end;

  SetLocation(Location);

  if World.Landscape = nil then Exit;

  Result := True;

  GetHDiffs;
  if StandPoints = 0 then begin
    AddVector3s(LVelocity, LVelocity, World.GlobalForce);
//    if LVelocity.Y > MinHDiff then LVelocity.Y := MinHDiff;
  end else begin
    LVelocity.Y := 0;

    FinalUp := World.Landscape.HeightMap.GetNormal(Location.X, Location.Z);
    CrossProductVector3s(Axis, UpVector, FinalUp);

    if SqrMagnitude(Axis) < 0.001 then MulQuaternion(Orient, GetQuaternion(0, GetVector3s(0, 1, 0)), Orient) else begin
      Quat[0] := ArcCos(DotProductVector3s(NormalizeVector3s(UpVector), NormalizeVector3s(FinalUp)));
      if Quat[0] > pi then begin
        Quat[0] := 0;
      end;
      if Quat[0] < -1/180*pi then Quat[0] := -1/180*pi;
      if Quat[0] > 1/180*pi then Quat[0] := 1/180*pi;
      MulQuaternion(Orient, GetQuaternion(Quat[0], Axis), Orient);
    end;

    NormalizeQuaternion(Orient, Orient);
    SetLocation(Location);

    GetHDiffs;

    Iteration := 0;

    while (StandPoints < 3) and (Iteration < Iterations) do begin
      case StandPoints of
        0:;
        1: begin
          CrossProductVector3s(Axis, GetVector3s(Location.X-TransCP[TouchP[0]].X, Location.Y-TransCP[TouchP[0]].Y, Location.Z-TransCP[TouchP[0]].Z), World.GlobalForce);
          if SqrMagnitude(Axis) > 0*500*500*150*Sin(1/180*pi)*150 then begin    // ToFix: eliminate constants
            Quat[0] := 0.2/180*pi;
            GetQuaternion(Quat, Quat[0], Axis);
            MulQuaternion(Orient, Quat, Orient);

            OldY := TransCP[TouchP[0]].Y;

            NormalizeQuaternion(Orient, Orient);
            SetLocation(Location);
              SetOrientation(Orient);

            TransCP[TouchP[0]] := Transform4Vector3s(ModelMatrix, CartesianProductVector3s(Controls[TouchP[0]], StandScale));

            Location.Y := Location.Y + OldY - TransCP[TouchP[0]].Y;
          end;
        end;
        2: begin
          Axis := GetVector3s((TransCP[TouchP[1]].X-TransCP[TouchP[0]].X), (TransCP[TouchP[1]].Y-TransCP[TouchP[0]].Y), (TransCP[TouchP[1]].Z-TransCP[TouchP[0]].Z));
          Temp := CrossProductVector3s(GetVector3s(Axis.X, 0, Axis.Z), GetVector3s(Location.X-TransCP[TouchP[0]].X, 0, Location.Z-TransCP[TouchP[0]].Z)).Y;
          if Temp > 0 then Quat[0] := -0.2/180*pi else Quat[0] := 0.2/180*pi;
          GetQuaternion(Quat, Quat[0], Axis);
          MulQuaternion(Orient, Quat, Orient);

          OldY := TransCP[TouchP[0]].Y;

          NormalizeQuaternion(Orient, Orient);
          SetLocation(Location);
            SetOrientation(Orient);

          TransCP[TouchP[0]] := Transform4Vector3s(ModelMatrix, CartesianProductVector3s(Controls[TouchP[0]], StandScale));

          Location.Y := Location.Y + OldY - TransCP[TouchP[0]].Y;
        end;
      end;

//      NormalizeQuaternion(Orient, Orient);
      SetLocation(Location);

      GetHDiffs;

      Inc(Iteration);
    end;
    if MinHDiff < 0 then AddVector3s(Location, Location, GetVector3s(0, -MinHDiff, 0));
  end;
end;

procedure TParticleSystem.Init;
var i: Integer;
begin
  inherited;
  if Parent is TParticleSystem then OuterForce := (Parent as TParticleSystem).OuterForce;
  LastEmitLocation := GetAbsLocation3s;
  for i := 0 to TotalChilds-1 do if Childs[i] is TParticleSystem then Childs[i].Init;
  DisableEmit := False;
end;

procedure TParticleSystem.Render(Renderer: TRenderer);
begin
//  if World.PauseMode then
  CurrentLOD.Invalidate(True);
  inherited;
end;

end.

