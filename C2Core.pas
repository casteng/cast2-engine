(*
 @Abstract(CAST II Engine core unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains engine core classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Core;

interface

uses
  Logger,
  SysUtils,
  BaseTypes, Basics, BaseStr, Base3D, Timer, OSUtils, BaseClasses, BaseMsg, ItemMsg, BaseGraph, Resources,
  BaseCompiler,
  C2Types, C2Msg, C2Res, CAST2, C2Visual, C2Render, C2Materials, Input, C2Physics;

const
    // script data types
  // 4x4 matrix
  tidMatrix4x4 = 0;
  // Vector
  tidVector4 = 1;

type
  // Sorted items data structure for internal use
  TVisItem = record
    PassIndex, ItemIndex: Word;
  end;
  TSortedItems = array of TVisItem;

  // Temporary class to parse shader constant definitions. Should be replaced with fully-featured script-based implementation.
  TSimpleParser = class(TAbstractCompiler)
  public
    Variables: TIdents;
    procedure HandleMessage(const Msg: TMessage); override;
    // Simply recognizes some predefined keywords
    function Compile(const Source: AnsiString): TRTData; override;
  end;

  // Core class reference
  CCore = class of TCore;
  { @Abstract(Engine core class)
    This class manages subsystems, controls items processing and rendering.
    Its <b>Process()</b> method should be called in main application cycle. }
  TCore = class(TBaseCore)
  private
    FRenderer: C2Render.TRenderer;
    FInput: Input.TController;
    FPhysics: C2Physics.TPhysicssubsystem;

    RenderItems: TItems; TotalRenderItems: Integer;
    Lights: TItems; TotalLights: Integer;

    FPSCountEventID: TEventID;
    FFPSCountTimeout, OneOverFPSCountTimeout, LastFPSCountFrame: TTimeUnit;

    LastProcessingTime: array of TTimeUnit;

    SortedItems: TSortedItems;

    Passes: array of TRenderPass; TotalPasses: Integer;                // Sorted passes

    procedure FPSCountEvent(EventID: Integer; const ErrorDelta: TTimeUnit);
    procedure SetFPSCountTimeout(const Value: TTimeUnit);

    procedure SetInput(const Value: Input.TController);
    procedure SetPhysics(const Value: C2Physics.TPhysicsSubsystem);
    procedure SetRenderer(const Value: C2Render.TRenderer);
    
    procedure SetShaderConstants(const Pass: TRenderPass; Item: TVisible);

    procedure ResetTechnique(const AMaterial: TMaterial);

    procedure Render(const ThroughCamera, Camera: TCamera; RecursionCounter: Integer);
    function GetConstantsEnum: AnsiString;
  protected
    // Clears garbage data. Called automatically
    procedure CollectGarbage; override;
    // Performs clean-up before destruction
    procedure OnDestroy; override;
  public
    // Default material
    DefaultMaterial: TMaterial;
    // If <b>True</b> all input item generate messages not only explicitly bound ones
    CatchAllInput: Boolean;

    constructor Create; override;

    // Initializes shader constant parser engine with engine object model
    procedure InitConstantParser;

    // For internal use only.
    procedure AddPass(const Item: TItem); override;
    // For internal use only.
    procedure RemovePass(const Item: TItem); override;

    procedure HandleMessage(const Msg: TMessage); override;

    // Finds in current scene and applies first found camera with <b>Default</b> property set to <b>True</b>
    procedure ApplyDefaultCamera;

    // Clears current scene
    procedure ClearItems; override;

    // Traces the given ray with the given depth and returns a list of items hit sorted by distance <b>not implemented yet</b>
    function TraceRay(const Ray: TVector3s; Depth: Single; out Items: TItems): Integer;

    // Performs main engine cycle. Items processing, rendering, physics, input, etc. Should be called from main application cycle.
    procedure Process;

    // Renderer subsystem
    property Renderer: C2Render.TRenderer read FRenderer write SetRenderer;
    // Input subsystem
    property Input: Input.TController     read FInput    write SetInput;
    // Physics subsystem
    property Physics: C2Physics.TPhysicssubsystem read FPhysics write SetPhysics;
    // Time to average frame rate through
    property FPSCountTimeout: TTimeUnit read FFPSCountTimeout write SetFPSCountTimeout;
    //
    property ConstantsEnum: AnsiString read GetConstantsEnum;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TProcessing, TCamera, TMirrorCamera, TLookAtCamera, TLight,
                          TMaterial, TTechnique, TRenderPass]);
end;

{ TCore }

const PassesCapacityStep = 4;

procedure TCore.OnDestroy;
var i: Integer;
begin

  FreeAndNil(FTempItems);
  FreeAndNil(Compiler);
  inherited;
  if Assigned(DefaultMaterial) and not Assigned(DefaultMaterial.Parent) then begin                         // Should be destroy after shared tesselators which may use the material
    for i := 0 to DefaultMaterial.TotalTechniques-1 do begin
      DefaultMaterial.Technique[i].Passes[0].Free;
      DefaultMaterial.Technique[i].Free;
    end;
    FreeAndNil(DefaultMaterial);
  end;
end;

procedure TCore.FPSCountEvent(EventID: Integer; const ErrorDelta: TTimeUnit);
begin
  PerfProfile.FramesPerSecond := (Renderer.FramesRendered - LastFPSCountFrame) * OneOverFPSCountTimeout;
  LastFPSCountFrame := Renderer.FramesRendered;
end;

procedure TCore.SetFPSCountTimeout(const Value: TTimeUnit);
begin
  FFPSCountTimeout       := Value;
  OneOverFPSCountTimeout := 1/Value;
  if FPSCountEventID = eIDNone then
    FPSCountEventID := Timer.SetRecurringEvent(FFPSCountTimeout, FPSCountEvent, 0)
  else
    Timer.SetRecurringEventInterval(FPSCountEventID, FFPSCountTimeout);
end;

procedure TCore.SetInput(const Value: Input.TController);
begin
  if Assigned(FInput) then RemoveSubsystem(FInput);
  FInput := Value;
  if Assigned(FInput) then AddSubsystem(FInput);
end;

procedure TCore.SetPhysics(const Value: C2Physics.TPhysicsSubsystem);
begin
  if Assigned(FPhysics) then RemoveSubsystem(FPhysics);
  FPhysics := Value;
  if Assigned(FPhysics) then AddSubsystem(FPhysics);
end;

procedure TCore.SetRenderer(const Value: C2Render.TRenderer);
begin
  if Assigned(FRenderer) then RemoveSubsystem(FRenderer);
  FRenderer := Value;
  if Assigned(FRenderer) then begin
    AddSubsystem(FRenderer);
    FRenderer.SetPerfProfile(PerfProfile);

    if Assigned(FTempItems) then FreeAndNil(FTempItems);    
    FTempItems := TTemporaryVisible.Create(Self);
  end;
end;

procedure TCore.SetShaderConstants(const Pass: TRenderPass; Item: TVisible);
var i, RegI: Integer;

  function SetConstant(ShaderKind: TShaderKind; BaseRegIndex: Integer; DataDesc: Integer): Integer;            // Dummy code to replace with fully-functional script
  const ZeroPosition: TVector4s = (X: 0; Y: 0; Z: 0; W: 1);
  const ZeroVector:   TVector4s = (X: 0; Y: 0; Z: 0; W: 0);
  var M: TMatrix4s;
  begin
    Result := 1;
    case DataDesc of
      0: begin              // Model matrix
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+0, GetVector4s(Item.Transform._11, Item.Transform._21, Item.Transform._31, Item.Transform._41));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+1, GetVector4s(Item.Transform._12, Item.Transform._22, Item.Transform._32, Item.Transform._42));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+2, GetVector4s(Item.Transform._13, Item.Transform._23, Item.Transform._33, Item.Transform._43));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+3, GetVector4s(Item.Transform._14, Item.Transform._24, Item.Transform._34, Item.Transform._44));
        Result := 4;
      end;
      1: begin              // View matrix
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+0, GetVector4s(Renderer.LastAppliedCamera.ViewMatrix._11, Renderer.LastAppliedCamera.ViewMatrix._21, Renderer.LastAppliedCamera.ViewMatrix._31, Renderer.LastAppliedCamera.ViewMatrix._41));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+1, GetVector4s(Renderer.LastAppliedCamera.ViewMatrix._12, Renderer.LastAppliedCamera.ViewMatrix._22, Renderer.LastAppliedCamera.ViewMatrix._32, Renderer.LastAppliedCamera.ViewMatrix._42));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+2, GetVector4s(Renderer.LastAppliedCamera.ViewMatrix._13, Renderer.LastAppliedCamera.ViewMatrix._23, Renderer.LastAppliedCamera.ViewMatrix._33, Renderer.LastAppliedCamera.ViewMatrix._43));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+3, GetVector4s(Renderer.LastAppliedCamera.ViewMatrix._14, Renderer.LastAppliedCamera.ViewMatrix._24, Renderer.LastAppliedCamera.ViewMatrix._34, Renderer.LastAppliedCamera.ViewMatrix._44));
        Result := 4;
      end;
      2: begin              // Projection matrix
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+0, GetVector4s(Renderer.LastAppliedCamera.ProjMatrix._11, Renderer.LastAppliedCamera.ProjMatrix._21, Renderer.LastAppliedCamera.ProjMatrix._31, Renderer.LastAppliedCamera.ProjMatrix._41));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+1, GetVector4s(Renderer.LastAppliedCamera.ProjMatrix._12, Renderer.LastAppliedCamera.ProjMatrix._22, Renderer.LastAppliedCamera.ProjMatrix._32, Renderer.LastAppliedCamera.ProjMatrix._42));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+2, GetVector4s(Renderer.LastAppliedCamera.ProjMatrix._13, Renderer.LastAppliedCamera.ProjMatrix._23, Renderer.LastAppliedCamera.ProjMatrix._33, Renderer.LastAppliedCamera.ProjMatrix._43));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+3, GetVector4s(Renderer.LastAppliedCamera.ProjMatrix._14, Renderer.LastAppliedCamera.ProjMatrix._24, Renderer.LastAppliedCamera.ProjMatrix._34, Renderer.LastAppliedCamera.ProjMatrix._44));
        Result := 4;
      end;
      3: begin              // Model*View matrix
        M := GetTransposedMatrix4s(MulMatrix4s(Item.Transform, Renderer.LastAppliedCamera.ViewMatrix));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+0, M.Rows[0]);
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+1, M.Rows[1]);
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+2, M.Rows[2]);
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+3, M.Rows[3]);
        Result := 4;
      end;
      4: begin              // Model*View*Projection matrix
        M := GetTransposedMatrix4s(MulMatrix4s(Item.Transform, Renderer.LastAppliedCamera.TotalMatrix));
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+0, M.Rows[0]);
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+1, M.Rows[1]);
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+2, M.Rows[2]);
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex+3, M.Rows[3]);
        Result := 4;
      end;

      5: if TotalLights > 0 then        // Light[0].Position
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, TLight(Lights[0]).Transform.ViewTranslate4s) else
          Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, ZeroPosition);
      6: if TotalLights > 0 then        // Light[0].Direction
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, TLight(Lights[0]).Transform.ViewForward4s) else
          Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, ZeroVector);

      7: if TotalLights > 0 then        // Light[0].Ambient
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, TLight(Lights[0]).Ambient.RGBA) else
          Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, ZeroVector);
      8: if TotalLights > 0 then        // Light[0].Diffuse
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, TLight(Lights[0]).Diffuse.RGBA) else
          Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, ZeroVector);
      9: if TotalLights > 0 then        // Light[0].Specular
        Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, TLight(Lights[0]).Specular.RGBA) else
          Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, ZeroVector);
      10: Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, Pass.Ambient.RGBA); // Material.Ambient
      11: Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, Pass.Diffuse.RGBA); // Material.Diffuse
      12: Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, Pass.Specular.RGBA); // Material.Specular

      13: Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, Renderer.LastAppliedCamera.Transform.ViewTranslate4s);
      14: Renderer.APIState.SetShaderConstant(ShaderKind, BaseRegIndex, Renderer.LastAppliedCamera.Transform.ViewForward4s);
    end;
  end;

begin
  RegI := 0;
  for i := 0 to Pass.TotalVertexShaderConstants-1 do if Assigned(Pass.CompiledVertexShaderConstants[i]) then
    Inc(RegI, SetConstant(skVertex, RegI, Pass.CompiledVertexShaderConstants[i].PIN[0]));

  RegI := 0;
  for i := 0 to Pass.TotalPixelShaderConstants-1 do if Assigned(Pass.CompiledPixelShaderConstants[i]) then
    Inc(RegI, SetConstant(skPixel, RegI, Pass.CompiledPixelShaderConstants[i].PIN[0]));
end;

procedure TCore.Render(const ThroughCamera, Camera: TCamera; RecursionCounter: Integer);
var PassIndex, FirstSortedPass, LastSortedPass: Integer; 

  procedure RenderItem(APass: TRenderPass; AItem: TVisible);
  var l, CurLight: Integer;
  begin
    Inc(PerfProfile.FrustumPassedItems);
    CurLight := 0;
    if APass.LightingState.Enabled and not AItem.CustomLighting then begin
      for l := 0 to TotalLights-1 do
        if TLight(Lights[l]).Enabled and (APass.Group in TLight(Lights[l]).GroupMask) and
           (Sqr(TLight(Lights[l]).Range + AItem.BoundingSphereRadius) >
            SqrMagnitude(SubVector3s(TLight(Lights[l]).GetAbsLocation, AItem.GetAbsLocation))) then begin
          Renderer.ApplyLight(CurLight, TLight(Lights[l]));
          Inc(CurLight);
          if CurLight >= SimultaneousLightSources then Break;
        end;
      for l := CurLight to Renderer.MaxAPILights-1 do Renderer.ApplyLight(l, nil);
    end else if AItem.CustomLighting then begin
      AItem.BeginLighting;
      for l := 0 to TotalLights-1 do
        if TLight(Lights[l]).Enabled and (APass.Group in TLight(Lights[l]).GroupMask) and
           (Sqr(TLight(Lights[l]).Range + AItem.BoundingSphereRadius) >
            SqrMagnitude(SubVector3s(TLight(Lights[l]).GetAbsLocation, AItem.GetAbsLocation))) then begin
          if AItem.CalculateLighting(TLight(Lights[l])) then Inc(CurLight);
          if CurLight >= SimultaneousLightSources then Break;
        end;
    end;

    Renderer.APIState.ApplyCustomTextureMatrices(APass, AItem);

    SetShaderConstants(APass, AItem);

    Renderer.RenderItem(AItem);

    Assert(isVisible in AItem.State, ClassName + '.Render: Rendering an invisible item "' + AItem.GetFullName + '"');
  end;

  procedure AddSortedPass(APass: TRenderPass);
  begin
    if FirstSortedPass < 0 then FirstSortedPass := PassIndex;
    LastSortedPass := PassIndex;
  end;

  procedure DrawSortedPasses;
  var TotalSortedItems: Integer;

    type _QSDataType = TVisItem; _QSValueType = Single;
    procedure SortItems(N: Integer; Values: TSortedItems);

      function _QSGetValue(const V: _QSDataType): _QSValueType;
      begin
        Result := TVisible(Passes[V.PassIndex].Items[V.ItemIndex]).SortValue;
      end;

    {$DEFINE COMPUTABLE}                                 // Set a sort algorithm on computable items
    {$I basics_quicksort.inc}                            // Include the quick sort algorithm
    {$IFNDEF ForCodeNavigationWork} begin end; {$ENDIF}  // Needed for code navigation features to work in Delphi 7

  var i, j: Integer;
  begin
    TotalSortedItems := 0;
    for i := FirstSortedPass to LastSortedPass do for j := 0 to Passes[i].TotalItems-1 do if TVisible(Passes[i].Items[j]).VisibilityCheck(Camera) then begin
      TVisible(Passes[i].Items[j]).CalcSortValue(Camera);
      TVisible(Passes[i].Items[j]).SortValue := TVisible(Passes[i].Items[j]).SortValue + Passes[i].SortBias;
      if Length(SortedItems) <= TotalSortedItems then SetLength(SortedItems, Length(SortedItems) + ItemsCapacityStep);
      with SortedItems[TotalSortedItems] do begin
        PassIndex := i;
        ItemIndex := j;
      end;
      Inc(TotalSortedItems);
    end else Inc(PerfProfile.FrustumCulledItems);

    SortItems(TotalSortedItems, SortedItems);

    Inc(PerfProfile.SortedItems, TotalSortedItems);

    for i := TotalSortedItems-1 downto 0 do begin
      Renderer.APIState.ApplyPass(Passes[SortedItems[i].PassIndex]);
      RenderItem(Passes[SortedItems[i].PassIndex], TVisible(Passes[SortedItems[i].PassIndex].Items[SortedItems[i].ItemIndex]));
    end;
  end;

var
  LastClearOrder, i, j: Integer;
  SortedPassesCollect: Boolean;
  ClearSettings: TClearSettings;
  StageSettings: TStagesClearSettings;
begin
  // Render visible through camera textures
//            if RecursionCounter = 0 then                                         // ToDo: remove it

  for PassIndex := 0 to TotalPasses-1 do if (isVisible in Passes[PassIndex].State) and (Passes[PassIndex].Group in Camera.GroupMask) then begin
    Passes[PassIndex].State := Passes[PassIndex].State - [isVisible];                     // Do not draw this pass within its camera
    for j := 0 to Passes[PassIndex].TotalStages-1 do
      if  (Passes[PassIndex].Stages[j].TextureIndex <> tivNull) and
         ((Passes[PassIndex].Stages[j].TextureIndex <> tivUnresolved) or Renderer.Textures.Resolve(Passes[PassIndex], j)) then
        if (Passes[PassIndex].Stages[j].TextureIndex = tivRenderTarget) and
           (Passes[PassIndex].Stages[j].Camera <> Renderer.MainCamera) and (isVisible in Passes[PassIndex].Stages[j].Camera.State) and
           not Renderer.APIState.IsRenderTargetUptoDate(Passes[PassIndex].Stages[j].Camera) then begin
             Passes[PassIndex].Stages[j].Camera.RenderTargetIndex := Renderer.APIState.FindRenderTarget(Passes[PassIndex].Stages[j].Camera);
             if Passes[PassIndex].Stages[j].Camera.RenderTargetIndex <> -1 then
               Render(Camera, Passes[PassIndex].Stages[j].Camera, RecursionCounter+1);
           end;
    Passes[PassIndex].State := Passes[PassIndex].State + [isVisible];
  end;

  // Render objects by PBR
  Camera.OnApply(ThroughCamera);
  Renderer.ApplyCamera(Camera);

  StageSettings := TCASTRootItem(Root).StageSettings;
  SortedPassesCollect := False;
  FirstSortedPass := -1;
  LastSortedPass  := -2;
  LastClearOrder  := poPreprocess;
  ClearSettings.ClearFlags := [];
  for PassIndex := 0 to TotalPasses-1 do begin
    Assert(Passes[PassIndex].Order >= LastClearOrder, '');
    // Handle render stage (order) clear settings

    if (Passes[PassIndex].TotalItems > 0) and                                    // Is really need to clear and draw?
       (isVisible in Passes[PassIndex].State) and
       (Passes[PassIndex].Group in Camera.GroupMask) then begin

      for i := LastClearOrder+1 to Passes[PassIndex].Order do begin                // Collect clear settings for all passed render stages
        if ClearFrameBuffer in StageSettings[i].ClearFlags then begin
          Include(ClearSettings.ClearFlags, ClearFrameBuffer);
          ClearSettings.ClearColor   := StageSettings[i].ClearColor;
        end;
        if ClearZBuffer in StageSettings[i].ClearFlags then begin
          Include(ClearSettings.ClearFlags, ClearZBuffer);
          ClearSettings.ClearZ       := TCASTRootItem(Root).StageSettings[i].ClearZ;
        end;
        if ClearStencilBuffer in StageSettings[i].ClearFlags then begin
          Include(ClearSettings.ClearFlags, ClearStencilBuffer);
          ClearSettings.ClearStencil := TCASTRootItem(Root).StageSettings[i].ClearStencil;
        end;
      end;

      Renderer.Clear(ClearSettings.ClearFlags, ClearSettings.ClearColor, ClearSettings.ClearZ, ClearSettings.ClearStencil);
      Inc(PerfProfile.ClearCalls, Ord(ClearSettings.ClearFlags <> []));
      LastClearOrder := Passes[PassIndex].Order;
      ClearSettings.ClearFlags := [];                                            // Reset clear settings

      if Passes[PassIndex].Order = SortedPassOrder then begin                    // Sorted passes need to collect
        SortedPassesCollect := True;
        AddSortedPass(Passes[PassIndex]);
      end else begin
        Renderer.APIState.ApplyPass(Passes[PassIndex]);
        for j := 0 to Passes[PassIndex].TotalItems-1 do
          if TVisible(Passes[PassIndex].Items[j]).VisibilityCheck(Camera) then
            RenderItem(Passes[PassIndex], TVisible(Passes[PassIndex].Items[j]))
          else
            Inc(PerfProfile.FrustumCulledItems);
      end;
    end;
    // Draw all accumulated sorted items if no more
    if SortedPassesCollect and ((PassIndex >= TotalPasses-1) or (Passes[PassIndex+1].Order <> SortedPassOrder)) then begin
      DrawSortedPasses;                                                      // Draw sorted passes
      SortedPassesCollect := False;
    end;
  end;
end;

constructor TCore.Create;
begin
  inherited;

  FPSCountEventID := eIDNone;

  // Register item classes
  RegisterItemClasses(GlobalClassList.Classes);

  InitConstantParser;

  FSharedTesselators := TSharedTesselators.Create;
  FSharedTesselators.Core := Self;

  if Assigned(Screen) then AddSubsystem(Screen);

  if not Assigned(DefaultMaterial) then begin
    DefaultMaterial := TMaterial.Create(Self);
    DefaultMaterial.Name := 'Default material';
    DefaultMaterial.TotalTechniques := 1;

    DefaultMaterial.Technique[0] := TTechnique.Create(Self);
    DefaultMaterial.Technique[0].Parent := DefaultMaterial;
    DefaultMaterial.Technique[0].Name := 'Default technique';
    DefaultMaterial.Technique[0].TotalPasses := 1;
    DefaultMaterial.Technique[0].Valid := True;

    DefaultMaterial.Technique[0].Passes[0] := TRenderPass.Create(Self);
    DefaultMaterial.Technique[0].Passes[0].Parent := DefaultMaterial.Technique[0];
    DefaultMaterial.Technique[0].Passes[0].Name := 'Default pass';
    DefaultMaterial.Technique[0].Passes[0].Group         := 0;
    DefaultMaterial.Technique[0].Passes[0].ZBufferState  := GetZBufferState(False, tfAlways, 0);
    DefaultMaterial.Technique[0].Passes[0].Order         := poPostProcess;
    DefaultMaterial.Technique[0].Passes[0].LightingState := GetLightingState(slNONE, False, False, GetColor($40404040));
    DefaultMaterial.Technique[0].Passes[0].FillShadeMode := GetFillShadeMode(fmSOLID, smGOURAUD, cmNONE, $FFFFFFFF);
    DefaultMaterial.Technique[0].Passes[0].FogKind       := fkNone;
    DefaultMaterial.Technique[0].Passes[0].TotalStages   := 1;
    DefaultMaterial.Technique[0].Passes[0].Stages[0].ColorArg1 := taDIFFUSE;
    DefaultMaterial.Technique[0].Passes[0].Stages[0].ColorOp   := toARG1;
    DefaultMaterial.Technique[0].Passes[0].Stages[0].AlphaOp   := toARG1;
    DefaultMaterial.Technique[0].Passes[0].Stages[0].ColorArg1 := taDIFFUSE;
    DefaultMaterial.Technique[0].Passes[0].State := DefaultMaterial.Technique[0].Passes[0].State + [isVisible];
  end;

  CatchAllInput := False;

  FPSCountTimeout := 0.5;
end;

procedure TCore.InitConstantParser;
var Parser: TSimpleParser;
begin
  Parser := TSimpleParser.Create;
  Compiler := Parser;
  SetLength(Parser.Variables, 15);
  Parser.Variables[0].Name   := 'Model';
  Parser.Variables[0].TypeID := tidMatrix4x4;
  Parser.Variables[1].Name   := 'View';
  Parser.Variables[1].TypeID := tidMatrix4x4;
  Parser.Variables[2].Name   := 'Projection';
  Parser.Variables[2].TypeID := tidMatrix4x4;
  Parser.Variables[3].Name   := 'ModelView';
  Parser.Variables[3].TypeID := tidMatrix4x4;
  Parser.Variables[4].Name   := 'MVP';
  Parser.Variables[4].TypeID := tidMatrix4x4;

  Parser.Variables[5].Name   := 'Light[0].Position';
  Parser.Variables[5].TypeID := tidVector4;
  Parser.Variables[6].Name   := 'Light[0].Direction';
  Parser.Variables[6].TypeID := tidVector4;
  Parser.Variables[7].Name   := 'Light[0].Ambient';
  Parser.Variables[7].TypeID := tidVector4;
  Parser.Variables[8].Name   := 'Light[0].Diffuse';
  Parser.Variables[8].TypeID := tidVector4;
  Parser.Variables[9].Name   := 'Light[0].Specular';
  Parser.Variables[9].TypeID := tidVector4;

  Parser.Variables[10].Name   := 'Material.Ambient';
  Parser.Variables[10].TypeID := tidVector4;
  Parser.Variables[11].Name   := 'Material.Diffuse';
  Parser.Variables[11].TypeID := tidVector4;
  Parser.Variables[12].Name   := 'Material.Specular';
  Parser.Variables[12].TypeID := tidVector4;

  Parser.Variables[13].Name   := 'View.Position';
  Parser.Variables[13].TypeID := tidVector4;
  Parser.Variables[14].Name   := 'View.Direction';
  Parser.Variables[14].TypeID := tidVector4;
end;

procedure TCore.AddPass(const Item: TItem);
var i: Integer;
begin
  Assert(Item is TRenderPass, Format('%S.%S: Item "%S" of class "%S" is not a render pass', [ClassName, 'AddPass', Item.Name, Item.ClassName]));
  Inc(TotalPasses);
  if Length(Passes) < TotalPasses then SetLength(Passes, Length(Passes) + PassesCapacityStep);

  i := TotalPasses-1;
  while i > 0 do begin
    if TRenderPass(Item).Order >= Passes[i-1].Order then Break;
    Passes[i] := Passes[i-1];
    Dec(i);
  end;
  Passes[i] := TRenderPass(Item);
end;

procedure TCore.RemovePass(const Item: TItem);
var i, RemovedCount: Integer;
begin
  RemovedCount := 0;
  for i := 0 to TotalPasses-1 do begin
    if Passes[i] = Item then Inc(RemovedCount);
    if (RemovedCount > 0) and (i < TotalPasses-1) then Passes[i] := Passes[i + RemovedCount];
  end;
  Dec(TotalPasses, RemovedCount);

  Assert(RemovedCount > 0, ClassName + '.RemovePass: Pass not found');
end;

procedure TCore.HandleMessage(const Msg: TMessage);
begin
  if Msg = nil then begin        //====***
    Process();
    Exit;
  end;
//  if Msg = nil then Exit;
  inherited;
//  if Assigned(Screen)   then Screen.HandleMessage(Msg);
//  if Assigned(Renderer) then Renderer.HandleMessage(Msg);
//  if Assigned(Input)    then Input.HandleMessage(Msg);

  if Msg.ClassType = ItemMsg.TReplaceMsg then with ItemMsg.TReplaceMsg(Msg) do begin
//    if (OldItem is TVisible) and (TVisible(OldItem).Colliding <> nil) then Collidings.Remove(TProcessing(OldItem).Colliding);
  end else if Msg.ClassType = TRequestValidationMsg then begin
    Assert(TRequestValidationMsg(Msg).Item is TMaterial);
    if Assigned(Renderer) and Renderer.ValidateMaterial(TRequestValidationMsg(Msg).Item as TMaterial) then begin
//      ResetTechnique(TMaterial(TRequestValidationMsg(Msg).Item));
      SendMessage(TValidationResultChangedMsg.Create(TRequestValidationMsg(Msg).Item), nil, [mfBroadcast]);
    end;

  end else if Msg.ClassType = ItemMsg.TAddToSceneMsg then begin
    if Assigned(Renderer) and (ItemMsg.TAddToSceneMsg(Msg).Item is TCamera) then
      if not Assigned(Renderer.MainCamera) then Renderer.MainCamera := ItemMsg.TAddToSceneMsg(Msg).Item as TCamera;
  end;
end;

procedure TCore.ClearItems;
begin
  Lights    := nil;
  RenderItems        := nil;
  LastProcessingTime := nil;
  inherited;
  Passes := nil; TotalPasses := 0;
end;

function TCore.TraceRay(const Ray: TVector3s; Depth: Single; out Items: TItems): Integer;
begin
  Result := 0;
end;

procedure TCore.Process;
var i: Integer; CASTRoot: TCASTRootItem; LDeltaTime: TTimeUnit;
begin
  {$IFDEF PROFILE}
  PerfProfile.BeginTiming(Timer, ptFrame);
  {$ENDIF}

  if Assigned(Root) then begin
    Assert(Root is TCASTRootItem, ClassName + '.Process: Root should be an instance of TCASTRootItem or one of its descendants');
    CastRoot := TCASTRootItem(Root);
// Input
    if Assigned(Input) then begin
      if CatchAllInput then begin
        Input.ProcessInput([ifBound, ifNotBound]);
        Input.InputEventsToMessages;
      end else Input.ProcessInput([ifBound]);
    end;  
  // Processing
    {$IFDEF PROFILE} PerfProfile.BeginTiming(Timer, ptProcessing); {$ENDIF}

    TotalProcessingItems := Root.ExtractByMask([isProcessing], True, ProcessingItems);
    Timer.Process();
    LDeltaTime := Timer.GetInterval(DeltaTimeBasedTimeMark, True) * TimeScale;
    ProcessDeltaTimeBased(LDeltaTime);
{    l := Length(LastProcessingTime);
    if l < Length(ProcessingClasses) then begin
      SetLength(LastProcessingTime, Length(ProcessingClasses));
      for i := l to Length(ProcessingClasses)-1 do LastProcessingTime[i] := LastProcessTime;
    end;

    for i := 0 to Length(ProcessingClasses)-1 do if not Paused or (pfIgnorePause in ProcessingClasses[i].Flags) then begin
      if pfDeltaTimeBased in ProcessingClasses[i].Flags then begin
        for j := 0 to TotalProcessingItems-1 do begin
          Assert(ProcessingItems[j] is TBaseProcessing, ProcessingItems[j].Name + ' is not a descendant of TBaseProcessing');
          if TBaseProcessing(ProcessingItems[j]).ProcessingClass = i then
            TBaseProcessing(ProcessingItems[j]).Process(Timer.LastTime - LastProcessTime);
        end;
      end else begin
        if ThisProcessTime - LastProcessingTime[i] > MaxInterval then LastProcessingTime[i] := ThisProcessTime - MaxInterval;

        while LastProcessingTime[i] + ProcessingClasses[i].Interval <= ThisProcessTime do begin
          for j := 0 to TotalProcessingItems-1 do if ProcessingItems[j] is TBaseProcessing then begin
            Assert(ProcessingItems[j] is TBaseProcessing, ProcessingItems[j].Name + ' is not a descendant of TBaseProcessing');
            if TBaseProcessing(ProcessingItems[j]).ProcessingClass = i then
              TBaseProcessing(ProcessingItems[j]).Process(ProcessingClasses[i].Interval);
          end;
          LastProcessingTime[i] := LastProcessingTime[i] + ProcessingClasses[i].Interval;
        end;
      end;
    end else LastProcessingTime[i] := ThisProcessTime;}

    {$IFDEF PROFILE} PerfProfile.EndTiming(Timer, ptProcessing); {$ENDIF}

  // Collision
    {$IFDEF PROFILE} PerfProfile.BeginTiming(Timer, ptCollision); {$ENDIF}
    if Assigned(Physics) and not Paused then Physics.Process(LDeltaTime);
    {$IFDEF PROFILE} PerfProfile.EndTiming(Timer, ptCollision); {$ENDIF}

  // Render
    {$IFDEF PROFILE} PerfProfile.BeginTiming(Timer, ptRender); {$ENDIF}
    if Assigned(Renderer) and Assigned(Renderer.MainCamera) and Renderer.Active then begin

      // Prepare lights
      if SimultaneousLightSources > 0 then
        TotalLights := Root.ExtractByClass(TLight, Lights)
      else
        TotalLights := 0;
  //    SimultaneousLightSources := MinI(SimultaneousLightSources, Renderer.MaxAPILights);

      Renderer.StartFrame;
      // Render shared tesselator
      SharedTesselators.Render;
      Render(nil, Renderer.MainCamera, 0);
      SharedTesselators.Reset;
  //    if Screen <> nil then Screen.Render(Renderer);
  {    TotalRenderItems := Root.Extract([tmRender], RenderItems);
      for i := 0 to TotalRenderItems-1 do begin
        (RenderItems[i] as TVisible).OnRender(Renderer.LastAppliedCamera);
        Renderer.RenderItem(RenderItems[i] as TVisible);
      end;}
      if Renderer.DebugOutput then begin
        // Render bounding volumes
        TotalRenderItems := Root.ExtractByMask([isDrawVolumes], False, RenderItems);
        for i := 0 to TotalRenderItems-1 do if RenderItems[i] is TProcessing then begin
          Renderer.RenderItemBox(TProcessing(RenderItems[i]), GetColor($FFFF0000));
          Renderer.RenderItemDebug(TProcessing(RenderItems[i]));
        end;
        // Render picked objects boxes
        TotalRenderItems := Root.ExtractByMask([isPicked], False, RenderItems);
        for i := 0 to TotalRenderItems-1 do if RenderItems[i] is TProcessing then
         Renderer.RenderItemBox(TProcessing(RenderItems[i]), GetColor($FFFFFF00));
      end;

      Renderer.FinishFrame;
    end;
    {$IFDEF PROFILE} PerfProfile.EndTiming(Timer, ptRender); {$ENDIF}
  end;

  ProcessAsyncMessages;

  if Assigned(Root) then CollectGarbage;

  {$IFDEF PROFILE} PerfProfile.EndTiming(Timer, ptFrame); {$ENDIF}
end;

function TCore.GetConstantsEnum: AnsiString;
var i: Integer;
begin
  if Compiler is TSimpleParser then with TSimpleParser(Compiler) do
    for i := 0 to High(Variables) do begin
      if i > 0 then Result := Result + StringDelimiter;
      Result := Result + Variables[i].Name;      
    end;
end;

procedure TCore.CollectGarbage;
begin
  Assert(TempItems is TTemporaryVisible);
  TTemporaryVisible(TempItems).Clear;
  inherited;
end;

procedure TCore.ApplyDefaultCamera;
var i, Count: Integer; Cameras: TItems;
begin
  if Renderer = nil then Exit;
  Count := Root.ExtractByClass(TCamera, Cameras);
  i := 0;
  while (i < Count){ and not (Cameras[i] as TCamera).Default} do Inc(i);
  if i < Count then
    Renderer.MainCamera := Cameras[i] as TCamera
  else if Cameras <> nil then
    Renderer.MainCamera := Cameras[0] as TCamera;
end;

procedure TCore.ResetTechnique(const AMaterial: TMaterial);
var i, j, OldTotalPasses, OldTotalItems: Integer;
begin
  i := 0;
  OldTotalPasses := TotalPasses;
  while i < TotalPasses do begin
    j := 0;
    OldTotalItems := Passes[i].TotalItems;
    while j < Passes[i].TotalItems do begin
      if TVIsible(Passes[i].Items[j]).Material = AMaterial then
        TVIsible(Passes[i].Items[j]).CurrentLOD := TVIsible(Passes[i].Items[j]).CurrentLOD;     // To reset current technique

      if Passes[i].TotalItems < OldTotalItems then begin                  // Some items has been removed from the pass
        j := MaxI(0, j - (OldTotalItems - Passes[i].TotalItems));
        OldTotalItems := Passes[i].TotalItems;
      end;
      Inc(j);

    end;
    if TotalPasses < OldTotalPasses then begin                  // Some passes has been removed
      i := MaxI(0, i - (OldTotalPasses - TotalPasses));
      OldTotalPasses := TotalPasses;
    end;
    Inc(i);
  end;
end;

{ TSimpleParser }

procedure TSimpleParser.HandleMessage(const Msg: TMessage);
begin
end;

function TSimpleParser.Compile(const Source: AnsiString): TRTData;
begin
  Result := TRTData.Create;

  Result.Variables := Variables;
  SetLength(Result.PIN, 1);

  Result.PIN[0] := High(Result.Variables);
  while (Result.PIN[0] >= 0) and (Source <> Result.Variables[Result.PIN[0]].Name) do Dec(Result.PIN[0]);
  if Result.PIN[0] < 0 then begin
    FreeAndNil(Result);
    LastError := 'Unknown identifier: ' + Source;
    Log(Format('%S.%S: The following error occured while compiling mini-script: "%S"', [ClassName, 'Compile', LastError]), lkError);
  end;
end;

begin
  GlobalClassList.Add('C2Core', GetUnitClassList);
end.
