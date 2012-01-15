(*
 CAST Engine render unit.
 (C) 2002 George "Mirage" Bakhtadze.
 Unit contains basic classes for rendering.
*)
{$Include GDefines}
{$Include CDefines}
unit CRender;

interface

uses
  SysUtils, Windows, {Messages, }

  Logger,

  Basics, BaseCont, Base3D, Adv2D, CTypes, CTess, CRes;

const
  lmNone = 0; lmDiscard = 1; lmNoOverwrite = 2;

{$IFDEF DEBUGMODE}                             
  FullScreenWindowStyle = WS_POPUP or WS_VISIBLE{ or WS_EX_APPWINDOW};
{$ELSE}
  FullScreenWindowStyle = WS_POPUP or WS_VISIBLE or WS_EX_TOPMOST;
{$ENDIF}
  OffScreenX = -1000; OffScreenY = -1000;          

  MaxLostTime = 100;
// Clear targets
  ctRenderTarget  = $00000001;  (* Clear target surface *)
  ctZBuffer = $00000002;  (* Clear target z buffer *)
  ctStencil = $00000004;  (* Clear stencil planes *)
// Create viewport results
  cvOK = 0; cvLost = 1; cvError = 2;

  MaterialFileSignature: TFileSignature = 'MT00';
  MaterialFileSignature1: TFileSignature = 'MT01';
  MaterialFileSignature2: TFileSignature = 'MT02';
  MaterialFileSignature3: TFileSignature = 'MT03';

type
  TRenderer = class;

  TRenderStream = record
    CurVBOffset, CurIBOffset: Longword;
    Static: Boolean;
    VertexBufferSize, IndexBufferSize, IndexSize, VertexSize: Longword;
    VertexFormat, ZTestMode: Cardinal;
  end;

  TRenderStreams = class
    Streams: array of TRenderStream;
    TotalStreams, CurStream: Integer;
    constructor Create(ARenderer: TRenderer); virtual;
    procedure Reset; virtual;
    function Add(VBufSize, IBufSize, AVertexFormat, AIndexSize: DWord; AStatic: Boolean): Integer; virtual; abstract;
    function Resize(Stream: Integer; VBufSize, IBufSize, IndexSize: DWord; AStatic: Boolean): Integer; virtual; abstract;

    function CreateVBuffer(Stream: DWord; BufferLength: Integer; Usage, Pool: DWord): Boolean; virtual; abstract;
    function FillVertexes(Stream: DWord; Source: Pointer; SourceSize: DWord; Offset: DWord = 0): Boolean; virtual; abstract;
    function CreateIBuffer(Stream: DWord; BufferLength: Integer; Usage, Pool: DWord): Boolean; virtual; abstract;
    function FillIndices(Stream: DWord; Source: Pointer; SourceSize: DWord; Offset: DWord = 0): Boolean; virtual; abstract;
    function LockVBuffer(Stream: DWord; const BOffset, BSize, Mode: DWord): PByte; virtual; abstract;
    function LockIBuffer(Stream: DWord; const BOffset, BSize, Mode: DWord): PByte; virtual; abstract;
    procedure UnLockVBuffer(Stream: DWord); virtual; abstract;
    procedure UnLockIBuffer(Stream: DWord); virtual; abstract;

    function Restore: Boolean; virtual; abstract;
  protected
    Renderer: TRenderer;
  end;

  TMaterial = class
    Name: TShortName;
    Ambient, Diffuse, Specular: TColorS;
    Power: Single;
    FillMode: LongWord;
    Stages: array of TStage; TotalStages: Integer;
    Renderer: TRenderer;
    constructor Create(const AName: TShortName; ARenderer: TRenderer); virtual;
    procedure SetStage(StageIndex: Integer; AStage: TStage); virtual;
    function Save(Stream: TDStream): Integer; virtual;
    function Load(Stream: TDStream): Integer; virtual;
    destructor Free;
  end;

  TRenderPass = packed record
    SrcBlend, DestBlend: Cardinal;
    EnableFog, ZWrite: Boolean;
    ZTestFunc: Cardinal;
    ATestFunc, AlphaRef: Cardinal;
    Material: TMaterial;
  end;

  TViewPort = packed record
    X, Y, Width, Height: Longword;
    MinZ, MaxZ: Single;
  end;

  CRenderer = class of TRenderer;
  TRenderer = class // Render vertex buffer
    FogStart, FogEnd: Single; FogKind, FogColor: Cardinal;
    WorldMatrix, WorldMatrix1: TMatrix4s;
    TotalStreams: Integer;
    Resources: TResourceManager;
    Textures: array of record
      Texture: Pointer;
      Resource: Integer;
      Width, Height, Levels: Integer;
      Format: Cardinal;
    end;
    TotalTextures: Integer;

    Streams: TRenderStreams;

    RenderPars: TRenderParameters;

    AmbientColor: LongWord;
    Lights: array of TLight;
    Materials: array of TMaterial; TotalMaterials: Integer;

    LastFrame, FrameNumber: Longword;
    LostTime: Cardinal;
// Parameters
    ViewPort: TViewPort;
    State, FillMode, ShadingMode, SpecularMode: Longword;
    ActualZBufferDepth, ActualColorDepth, ActualRefresh: LongWord;
    FullScreenWidth, FullScreenHeight, FullScreenColorDepth, FullScreenRefresh: LongWord;
    WindowedWidth, WindowedHeight, WindowedColorDepth, WindowedRefresh: LongWord;
    LastFullScreen, FFullScreen, HardwareMode, RenderActive, EnableTexturing: Boolean;
    ClearFrameBuffer, ClearZBuffer, ClearStencilBuffer: Boolean;
    ClearColor: Longword;
    ClearZ: Single;
    ClearStencil: Cardinal;
    Dithering: Boolean;
// Capabilites
    MaxHardwareLights, MaxAPILights, ActiveHardwareLights: Cardinal;
    MaxTextureWidth, MaxTextureHeight, MaxTexturesByPass, MaxTextureStages: Integer;
    MaxPrimitiveCount, MaxVertexIndex: Integer;
    HardwareClipping, WBuffering, Power2Textures, SquareTextures: Boolean;
// System
    Events: TCommandQueue;
    RenderWindowHandle: HWND;
    NormalWindowStyle: Cardinal;
    constructor Initialize(AResources: TResourceManager; AEvents: TCommandQueue); virtual;
    procedure CheckCaps; virtual; abstract;
    procedure CheckTextureFormats; virtual; abstract;
    function CheckTextureFormat(const Format, Usage: Cardinal): Boolean; virtual; abstract;
    function ChooseFormat(const Format, Usage: Cardinal): Cardinal; virtual;
    procedure SetMipmapGenFilter(Filter: TImageFilterFunction; Radius: Single); virtual;
    function PrepareWindow: Boolean; virtual;
    function CreateViewport(WindowHandle: HWND; ResX, ResY, BpP: Word; AFullScreen: Boolean; AZBufferDepth: Word;
                            UseHardware: Boolean = True; Refresh: Integer = 0): Integer; virtual;
    function RestoreViewport: Integer; virtual; abstract;

    procedure BeginScene; virtual; abstract;
    procedure EndScene; virtual; abstract;

    function AddTexture(ResourceID: Integer; TextureID: Integer = -1): Integer; virtual;
    procedure DeleteTexture(TextureID: Integer); virtual; 
    function LoadToTexture(TextureID: Integer; Data: Pointer): Boolean; virtual; abstract;
    function UpdateTexture(Src: Pointer; TextureIndex: Integer; Area: TArea): Boolean; virtual; abstract;

    function GetTextureResourceByIndex(TextureIndex: Integer): Integer; virtual;
    function GetTextureIndex(Tex: Pointer): Integer; virtual;

    function RestoreTextures: Boolean; virtual; 
    function LoadTexture(Filename: string; Width: Word = 0; Height: Word = 0; MipLevels: Word = 0; ColorKey: DWord = 0): Integer; virtual; abstract;
    procedure FreeTextures; virtual; 

    procedure InitMatrices(AXFoV, AAspect: Single; AZNear, AZFar: Single); virtual; 
    procedure SetCamera(ACamera: TCamera); virtual;
    procedure SetViewMatrix(const AMatrix: TMatrix4s); virtual;
    procedure ProjectToScreen(var Projected: TVector4s; const Vector: TVector3s); virtual;

    function AddMaterial(const AMaterial: TMaterial): TMaterial; virtual;
    procedure DeleteMaterial(const AName: TShortName); virtual;
    function GetMaterialByName(const AName: TShortName): TMaterial; virtual;

    function GetFVF(CastVertexFormat: DWord): DWord; virtual; abstract;
    function GetBitDepth(Format: LongWord): LongWord; virtual; abstract;

    procedure SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single); virtual;
    procedure SetAspectRatio(const Ratio: Single); virtual;

    procedure BeginStream(AStream: Cardinal); virtual; abstract;
    procedure EndStream; virtual; abstract;

    procedure SetBlending(SrcBlend, DestBlend: Cardinal); virtual; abstract;
    procedure SetBlendOperation(BOperation: Cardinal); virtual; abstract;
    procedure SetFog(Kind: Cardinal; Color: DWord; AFogStart, AFogEnd: Single); virtual; abstract;
    procedure SetCullMode(CMode: DWord); virtual; abstract;
    procedure SetZWrite(ZWrite: Boolean); virtual; abstract;
    procedure SetZTest(ZTestMode, TestFunc: Cardinal); virtual; abstract;
    procedure SetAlphaTest(AlphaRef, TestFunc: Cardinal); virtual; abstract;
    procedure SetColorMask(Alpha, Red, Green, Blue: Boolean); virtual; abstract;
    procedure SetLighting(HardLighting: Boolean); virtual; abstract;
    procedure SetTextureFiltering(const Stage: Integer; const MagFilter, MinFilter, MipFilter: DWord); virtual; abstract;
    procedure SetShading(AShadingMode: Cardinal); virtual; abstract;
    procedure SetDithering(ADithering: Boolean); virtual; abstract;
    procedure SetSpecular(ASpecular: Cardinal); virtual; 
    procedure ApplyRenderState(AState, Value: DWord); virtual; abstract;
    procedure SetClearState(const AClearFrameBuffer, AClearZBuffer, AClearStencilBuffer: Boolean; AClearColor: Longword; AClearZ: Single; AClearStencil: Cardinal); virtual;

    procedure ApplyLights; virtual; abstract;
    procedure SetAmbient(Color: LongWord); virtual; abstract;
    procedure SetLight(Index: Integer; ALight: TLight); virtual;
    procedure DeleteLight(Index: Cardinal); virtual; abstract;

    procedure ApplyMaterial(AMaterial: TMaterial); virtual; abstract;
    function BeginPasses(Obj: TTesselator): Boolean; virtual;
    procedure EndPasses; virtual;
    procedure BeginRenderPass(Pass: TRenderPass); virtual;
    procedure EndRenderPass(Pass: TRenderPass); virtual; abstract;
    procedure AddTesselator(Obj: TTesselator); virtual; abstract;
    procedure Clear(ClearTarget: Cardinal; Color: Cardinal; Z: Single; Stencil: Cardinal); virtual; abstract;
    procedure Render; virtual; abstract;

    function GetFramesRendered: DWord; virtual;

    procedure HandleCommand(const Command: TCommand); virtual;

    procedure CloseViewport; virtual;
    destructor Shutdown; virtual;

    procedure SetFullScreen(const FScreen: Boolean); virtual; abstract;

    property FullScreen: Boolean read FFullScreen write SetFullScreen;
  protected
    MipmapGenFilter: TImageFilterFunction;
    MipmapGenFilterRadius: Single;
  public
    WindowedRect: TRect;
  end;

implementation

{ TMaterial }

constructor TMaterial.Create(const AName: TShortName; ARenderer: TRenderer);
begin
  Name := AName;
  Renderer := ARenderer;
  SetStage(0, GetStageAlpha(-1, toModulate2X, taDiffuse, taTexture, toDisable, taDiffuse, taTexture, taWrap, tfLinear, tfLinear, tfLinear, 0));
  Ambient := GetColorS(0.5, 0.5, 0.5, 0); Diffuse := GetColorS(0.5, 0.5, 0.5, 0); Specular := GetColorS(0.5, 0.5, 0.5, 0);
  FillMode := fmDefault;
end;

procedure TMaterial.SetStage(StageIndex: Integer; AStage: TStage);
begin
  if TotalStages < StageIndex+1 then begin
    TotalStages := StageIndex+1; SetLength(Stages, TotalStages);
  end;
  Stages[StageIndex] := AStage;
//  if Stages[StageIndex].Texture <> nil then Stages[StageIndex].Texture := Renderer.AddTexture(AStage.TextureID);
end;

destructor TMaterial.Free;
begin
  SetLength(Stages, 0); TotalStages := 0;
end;

function TMaterial.Load(Stream: TDStream): Integer;
var i, Ver, StageSize: Integer; TexName: TShortName; FileSign: TFileSignature;
begin
  Result := feCannotRead;
  if Stream.Read(FileSign, SizeOf(FileSign)) <> feOK then Exit;
  if FileSign = MaterialFileSignature then Ver := 1 else
   if FileSign = MaterialFileSignature1 then Ver := 2 else
    if FileSign = MaterialFileSignature2 then Ver := 3 else
     if FileSign = MaterialFileSignature3 then Ver := 4 else begin
       Ver := 0; Stream.Seek(Stream.Position - SizeOf(FileSign));
     end;

  if Stream.Read(Name, SizeOf(Name)) <> feOK then Exit;

  if Stream.Read(Ambient, SizeOf(Ambient)) <> feOK then Exit;
  if Stream.Read(Diffuse, SizeOf(Diffuse)) <> feOK then Exit;
  if Stream.Read(Specular, SizeOf(Specular)) <> feOK then Exit;
  if Ver >= 2 then if Stream.Read(Power, SizeOf(Power)) <> feOK then Exit;
  if Stream.Read(TotalStages, SizeOf(TotalStages)) <> feOK then Exit;
  SetLength(Stages, TotalStages);
  for i := 0 to TotalStages-1 do begin
    StageSize := SizeOf(TStage) - SizeOf(TMatrix4s);
    Stages[i].TexMatrix := ScaleMatrix4s(0, 0, 1);// IdentityMatrix4s;
    if Ver < 4 then begin
      StageSize := StageSize - SizeOf(Stages[i].TTransform) - SizeOf(Stages[i].TWrapping);
      Stages[i].TTransform := ttNone;
      Stages[i].TWrapping := twNone;
    end;
    if Ver < 3 then begin
      StageSize := StageSize - SizeOf(Stages[i].UVSource);
      Stages[i].UVSource := 0;
    end;
    if Ver < 1 then begin
      StageSize := StageSize - SizeOf(Stages[i].MagFilter) - SizeOf(Stages[i].MinFilter) - SizeOf(Stages[i].MipFilter);
      Stages[i].MagFilter := tfLinear; Stages[i].MinFilter := tfLinear; Stages[i].MipFilter := tfLinear;
    end;
    if Stream.Read(TexName, SizeOf(TexName)) <> feOK then Exit;
    if Stream.Read(Stages[i], StageSize) <> feOK then Exit;
    Stages[i].TextureRID := Renderer.Resources.IndexByName(TexName);
    Stages[i].TextureInd := -1;
  end;
  Result := feOK;
end;

function TMaterial.Save(Stream: TDStream): Integer;
var i: Integer; TexName: TShortName;
begin
  Result := feCannotWrite;
  if Stream.Write(MaterialFileSignature3, SizeOf(MaterialFileSignature3)) <> feOK then Exit;
  if Stream.Write(Name, SizeOf(Name)) <> feOK then Exit;
  if Stream.Write(Ambient, SizeOf(Ambient)) <> feOK then Exit;
  if Stream.Write(Diffuse, SizeOf(Diffuse)) <> feOK then Exit;
  if Stream.Write(Specular, SizeOf(Specular)) <> feOK then Exit;
  if Stream.Write(Power, SizeOf(Power)) <> feOK then Exit;
  if Stream.Write(TotalStages, SizeOf(TotalStages)) <> feOK then Exit;
  for i := 0 to TotalStages-1 do begin
    if Stages[i].TextureRID <> -1 then TexName := Renderer.Resources.ResourcesInfo[Stages[i].TextureRID].Name else TexName := '';
    if Stream.Write(TexName, SizeOf(TexName)) <> feOK then Exit;
    if Stream.Write(Stages[i], SizeOf(TStage) - SizeOf(TMatrix4s)) <> feOK then Exit;
  end;
  Result := feOK;
end;

{ TRenderer }

constructor TRenderer.Initialize(AResources: TResourceManager; AEvents: TCommandQueue);
begin

  Log('Starting Renderer...', lkTitle);

  State := rsNotInitialized;

  RenderPars.AspectRatio := 1;

  Events := AEvents;

  FillMode := fmSolid;
  Resources := AResources;

  RenderPars.ZNear := 5; RenderPars.ZFar := 65536;
  EnableTexturing := True;
  MaxHardwareLights := 0; ActiveHardwareLights := 0;

  AddMaterial(TMaterial.Create('Default', Self));
  ClearColor := $FF000000; ClearZ := 1; ClearStencil := 0;
  ClearFrameBuffer := True; ClearZBuffer := True; ClearStencilBuffer := False;

  ShadingMode := smGouraud;
  Dithering := True;
  
  NormalWindowStyle := GetWindowLong(RenderWindowHandle, GWL_STYLE);

//  SetMipmapGenFilter(@ImageLanczos3Filter, DefaultFilterRadius[ifLanczos]);
  SetMipmapGenFilter(nil, DefaultFilterRadius[ifBox]);

  LastFullScreen := False;
end;

function TRenderer.ChooseFormat(const Format, Usage: Cardinal): Cardinal;
{  pfUndefined    = 0; pfR8G8B8    = 1; pfA8R8G8B8  = 2; pfX8R8G8B8  = 3;
  pfR5G6B5       = 4; pfX1R5G5B5  = 5; pfA1R5G5B5  = 6; pfA4R4G4B4  = 7;
  pfA8           = 8; pfX4R4G4B4  = 9; pfA8P8      = 10; pfP8       = 11; pfL8     = 12; pfA8L8      = 13; pfA4L4 = 14;
  pfV8U8         = 15; pfL6V5U5   = 16; pfX8L8V8U8 = 17; pfQ8W8V8U8 = 18; pfV16U16 = 19; pfW11V11U10 = 20;
  pfD16_LOCKABLE = 21; pfD32      = 22; pfD15S1    = 23; pfD24S8    = 24; pfD16    = 25; pfD24X8     = 26; pfD24X4S4 = 27;
  pfB8G8R8       = 28; pfA8B8G8R8 = 29;
  pfAuto = $FFFFFFFF;}
const
  SubstFormats = 10; SubstVariants = 7;
  FormatSubst: array[0..SubstFormats-1, 0..SubstVariants-1] of Cardinal = (
 (pfR8G8B8,   pfX8R8G8B8, pfA8B8G8R8, pfB8G8R8,   pfR5G6B5,   pfX1R5G5B5, pfA4R4G4B4),
 (pfA8R8G8B8, pfA8B8G8R8, pfA4R4G4B4, pfA1R5G5B5, pfX8R8G8B8, pfR8G8B8,   pfR5G6B5),
 (pfX8R8G8B8, pfA8R8G8B8, pfR8G8B8,   pfB8G8R8,   pfA8B8G8R8, pfR5G6B5,   pfX1R5G5B5),
 (pfR5G6B5,   pfX1R5G5B5, pfA1R5G5B5, pfX8R8G8B8, pfA8R8G8B8, pfB8G8R8,   pfA4R4G4B4),
 (pfX1R5G5B5, pfR5G6B5,   pfA1R5G5B5, pfX8R8G8B8, pfR8G8B8,   pfB8G8R8,   pfA4R4G4B4),
 (pfA1R5G5B5, pfA4R4G4B4, pfA8R8G8B8, pfA8B8G8R8, pfR5G6B5,   pfX8R8G8B8, pfR8G8B8),
 (pfA4R4G4B4, pfA1R5G5B5, pfA8R8G8B8, pfA8B8G8R8, pfR5G6B5,   pfX8R8G8B8, pfR8G8B8),
 (pfX4R4G4B4, pfR5G6B5,   pfA1R5G5B5, pfX8R8G8B8, pfR8G8B8,   pfB8G8R8,   pfA4R4G4B4),
 (pfB8G8R8,   pfA8B8G8R8, pfR8G8B8,   pfX8R8G8B8, pfR5G6B5,   pfX1R5G5B5, pfA4R4G4B4),
 (pfA8B8G8R8, pfA8R8G8B8, pfA4R4G4B4, pfA1R5G5B5, pfX8R8G8B8, pfB8G8R8,   pfR5G6B5));
var i, j: Integer;
begin
  Result := pfUndefined;
  if CheckTextureFormat(Format, Usage) then Result := Format else
   for i := 0 to SubstFormats-1 do if Format = FormatSubst[i, 0] then begin
     for j := 0 to SubstVariants-1 do if CheckTextureFormat(FormatSubst[i, j], Usage) then begin
       Result := FormatSubst[i, j]; Break;
     end;
     Exit;
   end;
end;

procedure TRenderer.SetMipmapGenFilter(Filter: TImageFilterFunction; Radius: Single);
begin
  MipmapGenFilter := Filter;
  MipmapGenFilterRadius := Radius;
end;

procedure TRenderer.SetLight(Index: Integer; ALight: TLight);
begin
  Assert(Index < Length(Lights), 'Light index out of range');
  Lights[Index] := ALight;
end;

function TRenderer.GetFramesRendered: DWord;
begin
  Result := FrameNumber - LastFrame;
  LastFrame := FrameNumber;
end;

function TRenderer.GetTextureResourceByIndex(TextureIndex: Integer): Integer;
var i: Integer;
begin
  Result := -1;
  Result := Textures[TextureIndex].Resource;
end;

function TRenderer.GetTextureIndex(Tex: Pointer): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to TotalTextures-1 do if Textures[i].Texture = Tex then Result := i;
end;

procedure TRenderer.HandleCommand(const Command: TCommand);
begin
  if (State <> rsNotReady) and (State <> rsNotInitialized) then case Command.CommandID of
    cmdActivated: if not RenderActive then begin
      RenderActive := True;
      ShowWindow(RenderWindowHandle, SW_SHOWDEFAULT);
      RestoreViewPort;
    end;
    cmdDeactivated: if FullScreen then begin
      RenderActive := False;
//      State := rsLost;
//      InvalidateRect(0, nil, True);
    end;
    cmdResized: if State <> rsNotReady then begin
      if Command.Arg2 <> 0 then RenderPars.CurrentAspectRatio := Command.Arg1 / Command.Arg2 * RenderPars.AspectRatio;
      if not FullScreen then begin
        GetWindowRect(RenderWindowHandle, WindowedRect);
        RestoreViewport;
//          WindowedWidth := lParam and 65535 + WindowBorderWidth;
//          WindowedHeight := lParam shr 16 + WindowBorderHeight;
      end;
    end;
    cmdMoved: if not FullScreen then GetWindowRect(RenderWindowHandle, WindowedRect);
    cmdMinimized: if RenderActive then begin
      RenderActive := False;
//      InvalidateRect(0, nil, True);
    end;  
  end;
end;

procedure TRenderer.SetCamera(ACamera: TCamera);
begin
  with ACamera do begin
    if FieldOfView <> RenderPars.Camera.FieldOfView then InitMatrices(FieldOfView, RenderPars.CurrentAspectRatio, RenderPars.ZNear, RenderPars.ZFar);
    RenderPars.ViewMatrix := MulMatrix4s(YRotationMatrix4s(-YAngle), XRotationMatrix4s(XAngle));
    RenderPars.ViewMatrix := MulMatrix4s(TranslationMatrix4s(-X, -Y, -Z), RenderPars.ViewMatrix);
    RenderPars.ViewMatrix := MulMatrix4s(RenderPars.ViewMatrix, ScaleMatrix4s(1, 1{-Byte(ACamera.ZAngle<>0)*2}, 1));
  end;
//  TransposeMatrix4s(ViewMatrix, ViewMatrix);
  SetViewMatrix(RenderPars.ViewMatrix);
  RenderPars.Camera := ACamera;
end;

procedure TRenderer.SetViewMatrix(const AMatrix: TMatrix4s);
begin
  RenderPars.ViewMatrix := AMatrix;
  RenderPars.TotalMatrix := MulMatrix4s(RenderPars.ViewMatrix, RenderPars.ProjMatrix);
end;

function TRenderer.AddMaterial(const AMaterial: TMaterial): TMaterial;
begin
  Result := GetMaterialByName(AMaterial.Name);
  if Result <> nil then Exit;
  Inc(TotalMaterials); SetLength(Materials, TotalMaterials);
  Materials[TotalMaterials - 1] := AMaterial;
  Result := AMaterial;
end;

procedure TRenderer.DeleteMaterial(const AName: TShortName);
var i: Integer; MoveMat: Boolean;
begin
  MoveMat := False;
  for i := 0 to TotalMaterials-1 do begin
    if MoveMat then Materials[i-1] := Materials[i];
    if Materials[i].Name = AName then begin
      Materials[i].Free; MoveMat := True;
    end;
  end;
  Dec(TotalMaterials); SetLength(Materials, TotalMaterials);
end;

function TRenderer.GetMaterialByName(const AName: TShortName): TMaterial;
var i: Integer;
begin
  Result := nil;
  for i := 0 to TotalMaterials-1 do if Materials[i].Name = AName then Result := Materials[i];
end;

procedure TRenderer.SetClearState(const AClearFrameBuffer, AClearZBuffer, AClearStencilBuffer: Boolean; AClearColor: Longword; AClearZ: Single; AClearStencil: Cardinal);
begin
  ClearFrameBuffer := AClearFrameBuffer;
  ClearZBuffer := AClearZBuffer;
  ClearStencilBuffer := AClearStencilBuffer;
  ClearColor := AClearColor;
  ClearZ := AClearZ;
  ClearStencil := AClearStencil;
end;

function TRenderer.BeginPasses(Obj: TTesselator): Boolean;
// Returns true if no valid command block present
begin
  Result := True;
end;

procedure TRenderer.EndPasses;
begin
end;

procedure TRenderer.BeginRenderPass(Pass: TRenderPass);
begin
  ApplyMaterial(Pass.Material);
end;

procedure TRenderer.SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single);
begin
  ViewPort.X := X; ViewPort.Y := Y;
  ViewPort.Width := Width; ViewPort.Height := Height;
  ViewPort.MinZ := MinZ; ViewPort.MaxZ := MaxZ;
end;

procedure TRenderer.SetSpecular(ASpecular: Cardinal);
begin
  SpecularMode := ASpecular;
end;

procedure TRenderer.ProjectToScreen(var Projected: TVector4s; const Vector: TVector3s);
var TRHW: Single;
begin
  Projected := Transform4Vector3s(RenderPars.TotalMatrix, Vector);

  if Projected.W = 0 then Projected.W := -0.000001;

  TRHW := 1/Projected.W;
  Projected.X := RenderPars.ActualWidth shr 1 + RenderPars.ActualWidth shr 1*Projected.X * TRHW;
  Projected.Y := RenderPars.ActualHeight shr 1 - RenderPars.ActualHeight shr 1*Projected.Y * TRHW;
end;

procedure TRenderer.SetAspectRatio(const Ratio: Single);
begin
  if RenderPars.AspectRatio <> 0 then RenderPars.CurrentAspectRatio := RenderPars.CurrentAspectRatio/RenderPars.AspectRatio;
  RenderPars.AspectRatio := Ratio;
  RenderPars.CurrentAspectRatio := RenderPars.CurrentAspectRatio * RenderPars.AspectRatio;
end;

function TRenderer.PrepareWindow: Boolean;
var ClientRect: TRect;
begin
  Result := False;
  if (WindowedRect.Left = WindowedRect.Right) or (WindowedRect.Top = WindowedRect.Bottom) then begin
    GetWindowRect(RenderWindowHandle, WindowedRect);
  end;
  if (WindowedRect.Left < OffScreenX) and (WindowedRect.Right < OffScreenX) or (WindowedRect.Top < OffScreenY) and (WindowedRect.Bottom < OffScreenY) then begin

    Log('Windowed viewport is off-screen', lkError);

    State := rsTryToRestore;
    Exit;
  end;

{$IFNDEF DEBUGMODE}
  SetWindowLong(RenderWindowHandle, GWL_STYLE, NormalWindowStyle);
{$ENDIF}
  SetWindowPos(RenderWindowHandle, HWND_NOTOPMOST, WindowedRect.Left, WindowedRect.Top, WindowedRect.Right-WindowedRect.Left, WindowedRect.Bottom-WindowedRect.Top, SWP_DRAWFRAME or SWP_NOACTIVATE or SWP_NOSIZE or SWP_NOMOVE);

//  SetWindowLong(RenderWindowHandle, GWL_EXSTYLE, WS_EX_STATICEDGE or WS_EX_WINDOWEDGE);

  GetClientRect(RenderWindowHandle, ClientRect);

  if (ClientRect.Right - ClientRect.Left <= 0) or (ClientRect.Bottom - ClientRect.Top <= 0) then begin

    Log('Windowed viewport''s client area is missing', lkFatalError);

//      State := rsTryToRestore;
    Exit;
  end;

//  WindowBorderWidth := ClientRect.Left - WindowedRect.Left + (WindowedRect.Right - ClientRect.Right);
//  WindowBorderHeight := ClientRect.Top - WindowedRect.Top + (WindowedRect.Bottom - ClientRect.Bottom);
  WindowedWidth := ClientRect.Right;
  WindowedHeight := ClientRect.Bottom;

  RenderPars.ActualWidth := ClientRect.Right - ClientRect.Left;
  RenderPars.ActualHeight := ClientRect.Bottom - ClientRect.Top;

  Result := True;  
end;

function TRenderer.CreateViewport(WindowHandle: HWND; ResX, ResY, BpP: Word; AFullScreen: Boolean; AZBufferDepth: Word; UseHardware: Boolean; Refresh: Integer): Integer;
var i: Integer;
begin
  CheckCaps;
  if Length(Lights) <> MaxAPILights then begin
    SetLength(Lights, MaxAPILights);
    for i := 0 to MaxAPILights-1 do Lights[i].LightOn := False;
  end;
end;

procedure TRenderer.CloseViewport;
begin

  Log('Closing viewport');

  Streams.Reset;
end;

destructor TRenderer.Shutdown;
begin

  Log('Shutting down Direct3D', lkTitle);

  FreeTextures; 
  CloseViewPort;
  Streams.Free;
//  SetLength(Lights, 0);
  inherited Destroy;
end;

function TRenderer.RestoreTextures: Boolean;
var i: Integer;
begin

  Log('Restoring textures', lkTitle);

  Result := False;
  for i := 0 to TotalTextures - 1 do AddTexture(Textures[i].Resource, i); // ToDo: possibility to clear textures which will never used
  Result := True;
end;

procedure TRenderer.InitMatrices(AXFoV, AAspect, AZNear, AZFar: Single);
var w, h, q: Single;
begin
  RenderPars.ZNear := AZNear; RenderPars.ZFar := AZFar;
  RenderPars.FoV := AXFoV; RenderPars.CurrentAspectRatio := AAspect;
//  D3DXMatrixPerspectiveFovLH(ProjMat, FoV/180*pi, 1.0, ZNear, ZFar);
  FillChar(RenderPars.ProjMatrix, SizeOf(RenderPars.ProjMatrix), 0);
  w := Cos(AXFov * 0.5) / Sin(AXFov * 0.5);
  h := Cos(AXFov * 0.5) / Sin(AXFov * 0.5) * AAspect;
  q := AZFar / (AZFar - AZNear);
  RenderPars.ProjMatrix.m[0, 0] := w; RenderPars.ProjMatrix.m[1, 1] := h; RenderPars.ProjMatrix.m[2, 2] := q;
  RenderPars.ProjMatrix.m[3, 2] := -q*AZNear; RenderPars.ProjMatrix.m[2, 3] := 1;
//  Direct3DDevice.SetTransform(D3DTS_PROJECTION, TD3DMatrix(ProjMatrix));
  RenderPars.TotalMatrix := MulMatrix4s(RenderPars.ViewMatrix, RenderPars.ProjMatrix);
end;

function TRenderer.AddTexture(ResourceID: Integer; TextureID: Integer = -1): Integer;
const
  ProcesingFormat = pfA8R8G8B8; ProcesingFormatBpP = 4;
var
  i, j, k, OWidth, OHeight, Width, Height, MaxDim, w, h: Integer;
  FData, CData: Pointer; DataSize, DataOfs, TextureDataOfs: Cardinal;
  TargetFormat: Cardinal;
  Resized: Boolean;
begin
  Result := -1;
// Check if resource is valid
  if (ResourceID < 0) or (ResourceID >= Resources.TotalResources) then begin
 Log('TRenderer.AddTexture: ResourceID is out of range', lkError); 
    Exit;
  end;
  if (not (Resources.Resources[ResourceID] is TImageResource)) or
     ((Resources.Resources[ResourceID] as TImageResource).Width <= 0) or
     ((Resources.Resources[ResourceID] as TImageResource).Height <= 0) then begin
 Log(Format('TRenderer.AddTexture: Resource #%D "%s" is not an image', [ResourceID, Resources.ResourcesInfo[ResourceID].Name]), lkError); 
    Exit;
  end;
  for i := 0 to TotalTextures-1 do if (Textures[i].Resource = ResourceID) and (Textures[i].Texture <> nil) then begin Result := i; Exit; end;

  Log('TRenderer.AddTexture: Loading resource "' + Resources.ResourcesInfo[ResourceID].Name + '" as texture');


  if TextureID = -1 then begin
    Inc(TotalTextures); SetLength(Textures, TotalTextures);
    TextureID := TotalTextures-1;
  end else begin
    if Textures[TextureID].Texture <> nil then DeleteTexture(TextureID);
  end;

// Now check if texture with such dimensions is supported
  OWidth := (Resources.Resources[ResourceID] as TImageResource).Width;
  OHeight := (Resources.Resources[ResourceID] as TImageResource).Height;
  Width := MinI(MaxTextureWidth, OWidth);
  Height := MinI(MaxTextureHeight, OHeight);
  if SquareTextures then begin
    Width := MaxI(Width, Height);
    Height := Width;
  end;
// Compute total size of the texture with mipmaps
  w := OWidth; h := OHeight;
  DataSize := w * h;
  MaxDim := MaxI(OWidth, OHeight);
  Textures[TextureID].Levels := 1;
  while MaxDim > 1 do begin
    MaxDim := MaxDim div 2; Inc(Textures[TextureID].Levels);
    w := w div 2; h := h div 2;
    if w = 0 then w := 1; if h = 0 then h := 1;
    Inc(DataSize, w * h);
  end;
  GetMem(CData, DataSize * ProcesingFormatBpP);
// Convert the image to A8R8G8B8 for resizing
  ConvertImage(Resources.Resources[ResourceID].Format, ProcesingFormat,
               OWidth*OHeight, Resources.Resources[ResourceID].Data, 0, nil, CData);
// Generate mipmaps
  w := OWidth; h := OHeight;
  TextureDataOfs := 0;
  DataOfs := w * h;
  for k := 0 to Textures[TextureID].Levels-2 do begin
    if (w > MaxTextureWidth) or (h > MaxTextureHeight) then begin
      Width := w div 2; Height := h div 2;
      TextureDataOfs := DataOfs;
    end;
    w := w div 2; h := h div 2;
    if @MipmapGenFilter <> nil then
     StretchImage(MipmapGenFilter, MipmapGenFilterRadius, CData, GetArea(0, 0, OWidth, OHeight), OWidth,
                  Pointer(Cardinal(CData) + DataOfs * ProcesingFormatBpP), GetArea(0, 0, w, h), w) else begin
       for i := 0 to w-1 do for j := 0 to h-1 do
        TDWordBuffer(Pointer(Cardinal(CData))^)[DataOfs + j*w+i] := TDWordBuffer(CData^)[(j*OHeight div h) * OWidth + (i*OWidth div w)];
     end;
    DataOfs := DataOfs + w * h;
  end;

// Check if texture with such format is supported
  TargetFormat := Resources.Resources[ResourceID].Format;
  if not CheckTextureFormat(TargetFormat, fuTexture) then begin
    TargetFormat := ChooseFormat(Resources.Resources[ResourceID].Format, fuTexture);
 Log('TRenderer.AddTexture: Unsupported image format. Switching to another...'+IntToStr(TargetFormat), lkWarning); 
  end;

  GetMem(FData, DataSize * GetBytesPerPixel(TargetFormat));
  if TargetFormat <> ProcesingFormat then begin
    ConvertImage(ProcesingFormat, TargetFormat, DataSize - TextureDataOfs, Pointer(Cardinal(CData) + TextureDataOfs*ProcesingFormatBpP), 0, nil, FData);
    FreeMem(CData);
  end else begin
    if TextureDataOfs = 0 then begin
      FreeMem(FData);
      FData := CData;
    end else begin
      Move(Pointer(Cardinal(CData) + TextureDataOfs*ProcesingFormatBpP)^, FData^, (DataSize - TextureDataOfs)*ProcesingFormatBpP);
      FreeMem(CData);
    end;
  end;

  Textures[TextureID].Width := Width;
  Textures[TextureID].Height := Height;
  Textures[TextureID].Resource := ResourceID;
  Textures[TextureID].Format := TargetFormat;
  Resources.Resources[ResourceID].Owner.ResourceStatus[ResourceID] := rsInUse;

(*  if Resources.Resources[ResourceID] is TTextureResource then begin
    with (Resources.Resources[ResourceID] as TTextureResource) do begin
      Textures[TextureID].Width := Width;
      Textures[TextureID].Height := Height;
      Res := Direct3DDevice.CreateTexture(Width, Height, Ord(MipLevels=0), 0, CPFormats[Format], D3DPOOL_MANAGED, IDirect3DTexture8(Textures[TextureID].Texture));
      if Failed(Res) then begin

        Log('Error creating Direct3DTexture object: Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);
        Log('Call parameters: Width' + IntToStr(Width) + ' Height' + IntToStr(Height) +
                ' MipLevels' + IntToStr(MipLevels) + ' Format' + IntToStr(Format),
        lkError);

        Exit;
      end;
      Res := IDirect3DTexture8(Textures[TextureID].Texture).LockRect(0, LockedRect, nil, 0);
      if Failed(Res) then begin

        Log('Error locking texture. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

        Exit;
      end;
      Move(Data^, LockedRect.pBits^, Size);
      IDirect3DTexture8(Textures[TextureID].Texture).UnLockRect(0);

      Textures[TextureID].Levels := 0;
      i := MaxI(Width, Height);
      while i > 1 do begin
        Inc(Textures[TextureID].Levels);
        i := i div 2;
      end;
    end;
  end else with (Resources.Resources[ResourceID] as TImageResource) do begin
    Textures[TextureID].Width := Width;
    Textures[TextureID].Height := Height;
    Res := Direct3DDevice.CreateTexture(Width, Height, 0, 0, CPFormats[Format], D3DPOOL_MANAGED, IDirect3DTexture8(Textures[TextureID].Texture));
    if Failed(Res) then begin

      Log('Error creating Direct3DTexture object: Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

      Exit;
    end;
    Level := 0; w := Width; h:= Height;
    while True do begin
      Res := IDirect3DTexture8(Textures[TextureID].Texture).LockRect(Level, LockedRect, nil, 0);
      if Failed(Res) then begin

        Log('Error locking texture level# ' + IntToStr(Level) + '. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

        Exit;
      end;
      IData := Data;
//      Move(IData^, LockedRect.pBits^, w*h*4);                                                                    // ToFix: Replace 4 by BytesPerPixel

      BpP := GetBitDepth(CPFormats[Format]);
      case BpP of
        8: for i := 0 to w-1 do for j := 0 to h-1 do TByteBuffer(LockedRect.pBits^)[j*w+i] := TByteBuffer(IData^)[(j*Height div h) * Width + (i*Width div w)];
        15, 16: for i := 0 to w-1 do for j := 0 to h-1 do TWordBuffer(LockedRect.pBits^)[j*w+i] := TWordBuffer(IData^)[(j*Height div h) * Width + (i*Width div w)];
        24, 32: for i := 0 to w-1 do for j := 0 to h-1 do TDWordBuffer(LockedRect.pBits^)[j*w+i] := TDWordBuffer(IData^)[(j*Height div h) * Width + (i*Width div w)];
      end;

      IDirect3DTexture8(Textures[TextureID].Texture).UnLockRect(Level);

      w := w shr 1; if w = 0 then if h = 1 then Break else w := 1;
      h := h shr 1; if h = 0 then h := 1;

      Inc(Level);
    end;
    Textures[TextureID].Levels := Level;
  end;*)

  if not LoadToTexture(TextureID, FData) then begin
    Dec(TotalTextures); SetLength(Textures, TotalTextures);
  end else Result := TextureID;
  FreeMem(FData);
end;

procedure TRenderer.DeleteTexture(TextureID: Integer);
begin
  Textures[TextureID].Texture := nil;
end;

procedure TRenderer.FreeTextures;
var i: Integer;
begin

  Log('Freeing all textures', lkInfo);

  for i := 0 to Length(Textures)-1 do DeleteTexture(i);
  SetLength(Textures, 0); TotalTextures := 0;
end;

{ TRenderStreams }

constructor TRenderStreams.Create(ARenderer: TRenderer);
begin
  Renderer := ARenderer;
  Reset;
end;

procedure TRenderStreams.Reset;
begin
//  SetLength(Streams, 0); TotalStreams := 0;
end;

end.
