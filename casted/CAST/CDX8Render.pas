(*
 CAST Engine Direct X 8 render unit.
 (C) 2002 George "Mirage" Bakhtadze.
 Unit contains implementation of renderer based on DirectX 8.
*)
{$Include GDefines}
{$Include CDefines}
unit CDX8Render;

interface

uses
  SysUtils, Windows, {Messages, }DirectXGraphics, OSUtils,
 Logger, 
  Basics, BaseCont, Base3D, CTypes, CTess, CRes, CRender, Adv2D;

//const
//  DXLockModes: array[lmNone..lmNoOverwrite] of Longword = (0,

type
  TDX8RenderStreams = class(TRenderStreams)
    procedure Reset; override;
    function Add(VBufSize, IBufSize, AVertexFormat, AIndexSize: DWord; AStatic: Boolean): Integer; override;
    function Resize(Stream: Integer; VBufSize, IBufSize, IndexSize: DWord; AStatic: Boolean): Integer; override;

    function CreateVBuffer(Stream: DWord; BufferLength: Integer; Usage, Pool: DWord): Boolean; override;
    function FillVertexes(Stream: DWord; Source: Pointer; SourceSize: DWord; Offset: DWord = 0): Boolean; override;
    function CreateIBuffer(Stream: DWord; BufferLength: Integer; Usage, Pool: DWord): Boolean; override;
    function FillIndices(Stream: DWord; Source: Pointer; SourceSize: DWord; Offset: DWord = 0): Boolean; override;
    function LockVBuffer(Stream: DWord; const BOffset, BSize, Mode: DWord): PByte; override;
    function LockIBuffer(Stream: DWord; const BOffset, BSize, Mode: DWord): PByte; override;
    procedure UnLockVBuffer(Stream: DWord); override;
    procedure UnLockIBuffer(Stream: DWord); override;

    function Restore: Boolean; override;

    destructor Free;
  protected
    D3DVertexBuffer: array of IDirect3DVertexBuffer8;
    D3DIndexBuffer: array of IDirect3DIndexBuffer8;
  end;

  TDX8Renderer = class(TRenderer)
    Direct3D: IDirect3D8;
    Direct3DDevice: IDirect3DDevice8;
    Mat: TD3DMATERIAL8;
    constructor Initialize(AResources: TResourceManager; AEvents: TCommandQueue); override;
    procedure CheckCaps; override;
    procedure CheckTextureFormats; override;
    function CheckTextureFormat(const Format, Usage: Cardinal): Boolean; override;
    function CreateViewport(WindowHandle: HWND; ResX, ResY, BpP: Word; AFullScreen: Boolean; AZBufferDepth: Word;
                            UseHardware: Boolean = True; Refresh: Integer = 0): Integer; override;
    function RestoreViewport: Integer; override;
    function RestoreDevice: Boolean; virtual;
    procedure InitMatrices(AXFoV, AAspect: Single; AZNear, AZFar: Single); override;

    procedure BeginScene; override;
    procedure EndScene; override;

    function LoadToTexture(TextureID: Integer; Data: Pointer): Boolean; override;
    function UpdateTexture(Src: Pointer; TextureIndex: Integer; Area: TArea): Boolean; override;
    function LoadTexture(Filename: string; Width: Word = 0; Height: Word = 0; MipLevels: Word = 0; ColorKey: DWord = 0): Integer; override;
    procedure DeleteTexture(TextureID: Integer); override;

    procedure SetViewMatrix(const AMatrix: TMatrix4s); override;

    function GetFVF(CastVertexFormat: DWord): DWord; override;
    function GetBitDepth(Format: LongWord): LongWord; override;

    procedure SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single); override;
    procedure BeginStream(AStream: Cardinal); override;
    procedure EndStream; override;

    procedure SetBlending(SrcBlend, DestBlend: Cardinal); override;
    procedure SetFog(Kind: Cardinal; Color: DWord; AFogStart, AFogEnd: Single); override;
    procedure SetCullMode(CMode: DWord); override;
    procedure SetZTest(ZTestMode, TestFunc: Cardinal); override;
    procedure SetZWrite(ZWrite: Boolean); override;
    procedure SetAlphaTest(AlphaRef, TestFunc: Cardinal); override;
    procedure SetBlendOperation(BOperation: Cardinal); override;
    procedure SetColorMask(Alpha, Red, Green, Blue: Boolean); override;
    procedure SetLighting(HardLighting: Boolean); override;
    procedure SetTextureFiltering(const Stage: Integer; const MagFilter, MinFilter, MipFilter: DWord); override;
    procedure SetShading(AShadingMode: Cardinal); override;
    procedure SetDithering(ADithering: Boolean); override;
    procedure SetSpecular(ASpecular: Cardinal); override;
    procedure ApplyRenderState(State, Value: DWord); override;

    procedure ApplyLights; override;
    procedure SetAmbient(Color: LongWord); override;
    procedure SetLight(Index: Integer; ALight: TLight); override;
    procedure DeleteLight(Index: Cardinal); override;

    procedure ApplyMaterial(AMaterial: TMaterial); override;
    procedure BeginRenderPass(Pass: TRenderPass); override;
    procedure EndRenderPass(Pass: TRenderPass); override;
    procedure AddTesselator(Obj: TTesselator); override;
    procedure Clear(ClearTarget: Cardinal; Color: Cardinal; Z: Single; Stencil: Cardinal); override;
    procedure Render; override;

    procedure CloseViewport; override;
    destructor Shutdown; override;

    procedure SetFullScreen(const FScreen: Boolean); override;
  private
    D3DPP: TD3DPresent_Parameters;
  end;

implementation

{ TDX8Renderer }

constructor TDX8Renderer.Initialize(AResources: TResourceManager; AEvents: TCommandQueue);
var AID: TD3DAdapter_Identifier8;
begin
  inherited;

  Log('Starting DX8Renderer...', lkTitle);

  if D3D8DLL = 0 then begin

    Log('DirectX 8 or greater not installed', lkFatalError);

    Exit;
  end;
{$Include CDX8Init.pas}
  Direct3DDevice := nil;
  Direct3D := Direct3DCreate8(D3D_SDK_VERSION);

  if Direct3D = nil then Log('Error creating Direct3D object', lkFatalError) else begin
    Log('Direct3D object succesfully created');
    Direct3D.GetAdapterIdentifier(D3DADAPTER_DEFAULT, D3DENUM_NO_WHQL_LEVEL, AID);
    Log('Adapter information', lkTitle);
    Log('Description: '+AID.Description);
    Log('Driver: '+AID.Driver);
    Log('Driver version: Product '+IntToStr(AID.DriverVersionHighPart shr 16) + ', version ' + IntToStr(AID.DriverVersionHighPart and $FFFF) +
                          ', subversion ' + IntToStr(AID.DriverVersionLowPart shr 16) + ', build ' + IntToStr(AID.DriverVersionLowPart and $FFFF));
    Log('Vendor ID: ' + IntToStr(AID.VendorId) + ', device ID: ' + IntToStr(AID.DeviceId)+', subsystem ID: ' + IntToStr(AID.SubSysId) + ', revision: ' + IntToStr(AID.Revision));
    if AID.WHQLLevel = 0 then Log('Driver is not WHQL sertified') else Log('Driver is WHQL sertified');
  end;

  State := rsNotReady;

  SetFog(fkVertexRanged, $FF808080, 10, 65536);

  Streams := TDX8RenderStreams.Create(Self);
end;

procedure TDX8Renderer.CheckTextureFormats;
var i: Integer;
 {$IFDEF EXTLOGGING}
const FormatStr: array[0..High(CPFormats)] of string[12] =
 ('UNKNOWN', 'R8G8B8', 'A8R8G8B8', 'X8R8G8B8', 'R5G6B5',  'X1R5G5B5', 'A1R5G5B5',
  'A4R4G4B4', 'A8', 'X4R4G4B4', 'A8P8', 'P8',  'L8', 'A8L8',
  'A4L4', 'V8U8', 'L6V5U5', 'X8L8V8U8', 'Q8W8V8U8',  'V16U16', 'W11V11U10',
  'D16_LOCKABLE', 'D32', 'D15S1', 'D24S8', 'D16',  'D24X8', 'D24X4S4');
 SupportStr: array[False..True] of string[14] = ('     [ ]      ', '     [X]      ');
 {$ENDIF}
begin
 {$IFDEF EXTLOGGING}
  Log(' Texture formats supported', lkInfo);
  Log(' Format     Texture    RenderTarget   DepthStencil   Vol texture   Cube texture');

//  Log('    Video format: '+IntToStr(CPFormats[RenderPars.VideoFormat]));

  for i := 1 to High(CPFormats) do begin
    Log(Format('%-8.8s', [FormatStr[i]]) + SupportStr[CheckTextureFormat(i, fuTexture)] +
                                               SupportStr[CheckTextureFormat(i, fuRenderTarget)] +
                                               SupportStr[CheckTextureFormat(i, fuDepthStencil)] +
                                               SupportStr[CheckTextureFormat(i, fuVolumeTexture)] +
                                               SupportStr[CheckTextureFormat(i, fuCubeTexture)]);
  end;
 {$ENDIF}
end;

function TDX8Renderer.CheckTextureFormat(const Format, Usage: Cardinal): Boolean;
var Res: HResult; D3DUsage, D3DResType: Cardinal;
begin
  Result := False;
//  if Format = pfa8r8g8b8 then Exit;
  if (Format <= 0) or (Format > High(CPFormats)) then Exit;

  case Usage of
    fuRenderTarget: begin D3DUsage := D3DUSAGE_RENDERTARGET; D3DResType := D3DRTYPE_TEXTURE; end;
    fuDepthStencil: begin
      if (Format < 21) or (Format > 27) then Exit;
      D3DUsage := D3DUSAGE_DEPTHSTENCIL; D3DResType := D3DRTYPE_TEXTURE;
    end;
    fuVolumeTexture: begin D3DUsage := 0; D3DResType := D3DRTYPE_VOLUMETEXTURE; end;
    fuCubeTexture: begin D3DUsage := 0; D3DResType := D3DRTYPE_CUBETEXTURE;  end;
    else {fuTexture:} begin D3DUsage := 0; D3DResType := D3DRTYPE_TEXTURE; end;
  end;
  Res := Direct3D.CheckDeviceFormat(D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, CPFormats[RenderPars.VideoFormat], D3DUsage, D3DResType, CPFormats[Format]);
  case Res of
    D3D_OK: Result := True;
    D3DERR_INVALIDCALL: begin
 Log('CheckTextureFormat: Invalid call', lkWarning); 
    end;
    D3DERR_NOTAVAILABLE: ;
    else  Log('CheckTextureFormat: Unknown error', lkWarning)  ;
  end;  
end;

procedure TDX8Renderer.CheckCaps;
 {$IFDEF EXTLOGGING}
const CanStr: array[False..True] of string[3] = ('[ ]', '[X]');
 {$ENDIF}
var Caps: TD3DCaps8;
begin
  if Direct3DDevice = nil then begin
 Log('CheckCaps: Direct3D device was not initialized', lkError); 
    Exit;
  end;
  Direct3DDevice.GetDeviceCaps(Caps);
 {$IFDEF EXTLOGGING}
  Log('Checking 3D device capabilites...', lkTitle);
  Log(' Driver caps', lkInfo);
  Log(CanStr[Caps.Caps and D3DCAPS_READ_SCANLINE > 0]+' Display hardware is capable of returning the current scan line', lkInfo);
  Log(CanStr[Caps.Caps2 and D3DCAPS2_CANRENDERWINDOWED > 0]+' The driver is capable of rendering in windowed mode', lkInfo);
  Log(CanStr[Caps.Caps2 and D3DDEVCAPS_HWTRANSFORMANDLIGHT > 0]+' The driver supports dynamic gamma ramp adjustment in full-screen mode', lkInfo);
  Log(' Device caps', lkInfo);
  Log(CanStr[Caps.DevCaps and D3DDEVCAPS_DRAWPRIMTLVERTEX > 0]+' Device exports a DrawPrimitive-aware hardware abstraction layer (HAL)', lkInfo);
  Log(CanStr[Caps.DevCaps and D3DDEVCAPS_HWRASTERIZATION > 0]+' Device has hardware acceleration for scene rasterization', lkInfo);
  Log(CanStr[Caps.DevCaps and D3DDEVCAPS_HWTRANSFORMANDLIGHT > 0]+' Device can support transformation and lighting in hardware', lkInfo);
  Log(CanStr[Caps.DevCaps and D3DDEVCAPS_PUREDEVICE > 0]+' Device can support rasterization, transform, lighting, and shading in hardware', lkInfo);
  Log(CanStr[Caps.DevCaps and D3DDEVCAPS_TEXTUREVIDEOMEMORY > 0]+' Device can retrieve textures from device memory', lkInfo);
  Log(CanStr[Caps.DevCaps and D3DDEVCAPS_TLVERTEXSYSTEMMEMORY > 0]+' Device can use buffers from system memory for transformed and lit vertices', lkInfo);
  Log(CanStr[Caps.DevCaps and D3DDEVCAPS_TLVERTEXVIDEOMEMORY > 0]+' Device can use buffers from video memory for transformed and lit vertices', lkInfo);
  Log(' Raster caps', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_FOGRANGE > 0]+' Device supports range-based fog', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_FOGTABLE > 0]+' Device supports table fog', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_FOGVERTEX > 0]+' Device calculates the fog value during the lighting operation, and interpolates the fog value during rasterization', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_MIPMAPLODBIAS > 0]+' Device supports level-of-detail (LOD) bias adjustments', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_STRETCHBLTMULTISAMPLE > 0]+' Device provides limited multisample support through a stretch-blt implementation', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_WBUFFER > 0]+' Device supports depth buffering using w', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_WFOG > 0]+' Device supports w-based fog', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_ZBUFFERLESSHSR > 0]+' Device can perform hidden-surface removal (HSR)', lkInfo);
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_ZFOG > 0]+' Device supports z-based fog', lkInfo);
  Log(CanStr[Caps.ShadeCaps and D3DPSHADECAPS_SPECULARGOURAUDRGB > 0]+' Device can support specular highlights in Gouraud shading in the RGB color model', lkInfo);
  Log(' Vertex processing caps', lkInfo);
  Log(CanStr[Caps.VertexProcessingCaps and D3DVTXPCAPS_TEXGEN > 0]+' Device can generate texture coordinates', lkInfo);
  Log(CanStr[Caps.VertexProcessingCaps and D3DVTXPCAPS_TWEENING > 0]+' Device supports vertex tweening', lkInfo);
  Log('Max vertex w: '+FloatToStrF(Caps.MaxVertexW, ffFixed, 10, 1), lkInfo);
  Log(CanStr[Caps.PrimitiveMiscCaps and D3DPMISCCAPS_CLIPTLVERTS > 0]+' Device clips post-transformed vertex primitives', lkInfo);
  Log('Max number of primitives: '+IntToStr(Caps.MaxPrimitiveCount), lkInfo);
  Log('Max vertex index: '+IntToStr(Caps.MaxVertexIndex), lkInfo);
  Log(' Blending operations caps', lkInfo);
  Log(CanStr[Caps.PrimitiveMiscCaps and D3DPMISCCAPS_BLENDOP  > 0]+' Device supports the alpha-blending operations (ADD, SUB, REVSUB, MIN, MAX)', lkInfo);
  Log(' Source blending caps', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_DESTALPHA > 0]+' Blend factor is (Ad, Ad, Ad, Ad)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_DESTCOLOR > 0]+' Blend factor is (Rd, Gd, Bd, Ad)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_INVDESTALPHA > 0]+' Blend factor is (1–Ad, 1–Ad, 1–Ad, 1–Ad)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_INVDESTCOLOR  > 0]+' Blend factor is (1–Rd, 1–Gd, 1–Bd, 1–Ad)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_INVSRCALPHA > 0]+' Blend factor is (1–As, 1–As, 1–As, 1–As)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_INVSRCCOLOR > 0]+' Blend factor is (1–Rd, 1–Gd, 1–Bd, 1–Ad)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_ONE > 0]+' Blend factor is (1, 1, 1, 1)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_SRCALPHA > 0]+' Blend factor is (As, As, As, As)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_SRCALPHASAT > 0]+' Blend factor is (f, f, f, 1); f = min(As, 1-Ad)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_SRCCOLOR > 0]+' Blend factor is (Rs, Gs, Bs, As)', lkInfo);
  Log(CanStr[Caps.SrcBlendCaps and D3DPBLENDCAPS_ZERO > 0]+' Blend factor is (0, 0, 0, 0)', lkInfo);
  Log(' Destination blending caps', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_DESTALPHA > 0]+' Blend factor is (Ad, Ad, Ad, Ad)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_DESTCOLOR > 0]+' Blend factor is (Rd, Gd, Bd, Ad)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_INVDESTALPHA > 0]+' Blend factor is (1–Ad, 1–Ad, 1–Ad, 1–Ad)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_INVDESTCOLOR  > 0]+' Blend factor is (1–Rd, 1–Gd, 1–Bd, 1–Ad)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_INVSRCALPHA > 0]+' Blend factor is (1–As, 1–As, 1–As, 1–As)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_INVSRCCOLOR > 0]+' Blend factor is (1–Rd, 1–Gd, 1–Bd, 1–Ad)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_ONE > 0]+' Blend factor is (1, 1, 1, 1)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_SRCALPHA > 0]+' Blend factor is (As, As, As, As)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_SRCALPHASAT > 0]+' Blend factor is (f, f, f, 1); f = min(As, 1-Ad)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_SRCCOLOR > 0]+' Blend factor is (Rs, Gs, Bs, As)', lkInfo);
  Log(CanStr[Caps.DestBlendCaps and D3DPBLENDCAPS_ZERO > 0]+' Blend factor is (0, 0, 0, 0)', lkInfo);
  Log(' Texture caps', lkInfo);
  Log('Max texture width: '+IntToStr(Caps.MaxTextureWidth), lkInfo);
  Log('Max texture height: '+IntToStr(Caps.MaxTextureHeight), lkInfo);
  Log('Max texture repeat times: '+IntToStr(Caps.MaxTextureRepeat), lkInfo);
  Log('Max texture aspect ratio: '+IntToStr(Caps.MaxTextureAspectRatio), lkInfo);
  Log('Max texture blend stages: '+IntToStr(Caps.MaxTextureBlendStages), lkInfo);
  Log('Max simultaneous textures: '+IntToStr(Caps.MaxSimultaneousTextures), lkInfo);
  Log(CanStr[Caps.PrimitiveMiscCaps and D3DPMISCCAPS_TSSARGTEMP > 0]+' Texture stage destination can be temporal register', lkInfo);
  Log(CanStr[Caps.TextureCaps and D3DPTEXTURECAPS_ALPHA > 0]+' Alpha in texture pixels is supported', lkInfo);
  Log(CanStr[Caps.TextureCaps and D3DPTEXTURECAPS_ALPHAPALETTE > 0]+' Device can draw alpha from texture palettes', lkInfo);
  Log(CanStr[Caps.TextureCaps and D3DPTEXTURECAPS_PROJECTED > 0]+' Supports the D3DTTFF_PROJECTED texture transformation flag', lkInfo);
  Log(CanStr[not (Caps.TextureCaps and D3DPTEXTURECAPS_SQUAREONLY > 0)]+' Textures can be nonsquare', lkInfo);

  CheckTextureFormats;

  Log(' Texture operation caps', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_ADD > 0]+' The D3DTOP_ADD texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_ADDSIGNED > 0]+' The D3DTOP_ADDSIGNED texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_ADDSIGNED2X > 0]+' The D3DTOP_ADDSIGNED2X texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_ADDSMOOTH > 0]+' The D3DTOP_ADDSMOOTH texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_BLENDCURRENTALPHA > 0]+' The D3DTOP_BLENDCURRENTALPHA texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_BLENDDIFFUSEALPHA > 0]+' The D3DTOP_BLENDDIFFUSEALPHA texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_BLENDFACTORALPHA > 0]+' The D3DTOP_BLENDFACTORALPHA texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_BLENDTEXTUREALPHA > 0]+' The D3DTOP_BLENDTEXTUREALPHA texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_BLENDTEXTUREALPHAPM > 0]+' The D3DTOP_BLENDTEXTUREALPHAPM texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_BUMPENVMAP > 0]+' The D3DTOP_BUMPENVMAP texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_BUMPENVMAPLUMINANCE > 0]+' The D3DTOP_BUMPENVMAPLUMINANCE texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_DISABLE > 0]+' The D3DTOP_DISABLE texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_DOTPRODUCT3 > 0]+' The D3DTOP_DOTPRODUCT3 texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_LERP > 0]+' The D3DTOP_LERP texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_MODULATE > 0]+' The D3DTOP_MODULATE texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_MODULATE2X > 0]+' The D3DTOP_MODULATE2X texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_MODULATE4X > 0]+' The D3DTOP_MODULATE4X texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_MODULATEALPHA_ADDCOLOR > 0]+' The D3DTOP_MODULATEALPHA_ADDCOLOR texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_MODULATECOLOR_ADDALPHA > 0]+' The D3DTOP_MODULATECOLOR_ADDALPHA texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_MODULATEINVALPHA_ADDCOLOR > 0]+' The D3DTOP_MODULATEINVALPHA_ADDCOLOR texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_MODULATEINVCOLOR_ADDALPHA > 0]+' The D3DTOP_MODULATEINVCOLOR_ADDALPHA texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_MULTIPLYADD > 0]+' The D3DTOP_MULTIPLYADD texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_PREMODULATE > 0]+' The D3DTOP_PREMODULATE texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_SELECTARG1 > 0]+' The D3DTOP_SELECTARG1 texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_SELECTARG2 > 0]+' The D3DTOP_SELECTARG2 texture-blending operation is supported', lkInfo);
  Log(CanStr[Caps.TextureOpCaps and D3DTEXOPCAPS_SUBTRACT > 0]+' The D3DTOP_SUBTRACT texture-blending operation is supported', lkInfo);
  Log(' Stencil buffer caps', lkInfo);
  Log(CanStr[Caps.StencilCaps and D3DSTENCILCAPS_DECR > 0]+' The D3DSTENCILOP_DECR operation is supported', lkInfo);
  Log(CanStr[Caps.StencilCaps and D3DSTENCILCAPS_DECRSAT > 0]+' The D3DSTENCILOP_DECRSAT operation is supported', lkInfo);
  Log(CanStr[Caps.StencilCaps and D3DSTENCILCAPS_INCR > 0]+' The D3DSTENCILOP_INCR operation is supported', lkInfo);
  Log(CanStr[Caps.StencilCaps and D3DSTENCILCAPS_INCRSAT > 0]+' The D3DSTENCILOP_INCRSAT operation is supported', lkInfo);
  Log(CanStr[Caps.StencilCaps and D3DSTENCILCAPS_INVERT > 0]+' The D3DSTENCILOP_INVERT operation is supported', lkInfo);
  Log(CanStr[Caps.StencilCaps and D3DSTENCILCAPS_KEEP > 0]+' The D3DSTENCILOP_KEEP operation is supported', lkInfo);
  Log(CanStr[Caps.StencilCaps and D3DSTENCILCAPS_REPLACE > 0]+' The D3DSTENCILOP_REPLACE operation is supported', lkInfo);
  Log(CanStr[Caps.StencilCaps and D3DSTENCILCAPS_ZERO > 0]+' The D3DSTENCILOP_ZERO operation is supported', lkInfo);
  Log(' Shaders', lkInfo);
  Log('Vertex shader version main: '+IntToStr((Caps.VertexShaderVersion shr 8) and $FF)+', subversion: '+IntToStr(Caps.VertexShaderVersion and $FF), lkInfo);
  Log('Vertex shader constant registers: '+IntToStr(Caps.MaxVertexShaderConst), lkInfo);
  Log('Pixel shader version main: '+IntToStr((Caps.PixelShaderVersion shr 8) and $FF)+', subversion: '+IntToStr(Caps.PixelShaderVersion and $FF), lkInfo);
  Log('Max pixel shader value: '+FloatToStrF(Caps.MaxPixelShaderValue, ffFixed, 10, 1), lkInfo);
 {$ENDIF}
  HardwareClipping := Caps.PrimitiveMiscCaps and D3DPMISCCAPS_CLIPTLVERTS > 0;  // ToFix: wrong cap!
  WBuffering := Caps.RasterCaps and D3DPRASTERCAPS_WBUFFER > 0;
  SquareTextures := Caps.TextureCaps and D3DPTEXTURECAPS_SQUAREONLY > 0;
  Power2Textures := Caps.TextureCaps and D3DPTEXTURECAPS_POW2 > 0;
  MaxTextureWidth := Caps.MaxTextureWidth;
  MaxTextureHeight := Caps.MaxTextureHeight;
  MaxTexturesByPass := Caps.MaxSimultaneousTextures;
  MaxTextureStages := Caps.MaxTextureBlendStages;
  if Caps.DevCaps and D3DDEVCAPS_HWTRANSFORMANDLIGHT > 0 then MaxHardwareLights := Caps.MaxActiveLights else MaxHardwareLights := 0;
  MaxAPILights := 8;
  MaxPrimitiveCount := Caps.MaxPrimitiveCount;
  MaxVertexIndex := Caps.MaxVertexIndex;
end;

function TDX8Renderer.CreateViewport(WindowHandle: HWND; ResX, ResY, BpP: Word; AFullScreen: Boolean; AZBufferDepth: Word; UseHardware: Boolean = True; Refresh: Integer = 0): Integer;
var
  i: Integer;
  D3DDM: TD3DDisplayMode;
  ClientRect: TRect;
  Res: HResult;

  ScreenStat: string[30];

begin
  Result := cvError;
 Log('Creating viewport', lkTitle); 
//  FrameNumber := 0;
  LastFrame := 0;
  if Direct3D = nil then begin
 Log('Error creating viewport: Direct3D object was not initialized', lkFatalError); 
    Exit;
  end;

  State := rsNotReady;

  RenderWindowHandle := WindowHandle;

  if not AFullScreen then begin
    if LastFullScreen then SetWindowLong(RenderWindowHandle, GWL_STYLE, NormalWindowStyle);
    if not PrepareWindow then begin

      Log('Error creating windowed viewport', lkError);

      Exit;
    end;
    if LastFullScreen then SetWindowLong(RenderWindowHandle, GWL_STYLE, NormalWindowStyle);

    WindowedColorDepth := GetBitDepth(D3DDM.Format);
    WindowedRefresh := D3DDM.RefreshRate;


    ScreenStat := 'Windowed ' + IntToStr(WindowedWidth) + 'x' + IntToStr(WindowedHeight);

  end else begin
    if Direct3dDevice = nil then begin
      GetWindowRect(RenderWindowHandle, WindowedRect);
    end;
    RenderPars.ActualWidth := ResX; RenderPars.ActualHeight := ResY; ActualColorDepth := BpP;
    ActualRefresh := Refresh;
    SetWindowLong(RenderWindowHandle, GWL_STYLE, Integer(FullScreenWindowStyle));
//    SetWindowLong(RenderWindowHandle, GWL_STYLE, Integer(NormalWindowStyle));

    ScreenStat := 'Fullscreen ' + IntToStr(ResX) + 'x' + IntToStr(ResY) + 'x' + IntToStr(BpP);

  end;

  if Direct3DDevice = nil then Log('Creating viewport: ' + ScreenStat) else Log('Resetting viewport settings to ' + ScreenStat);

  FFullScreen := AFullScreen;
  LastFullScreen := AFullScreen;
  HardwareMode := UseHardware;

  ActualZBufferDepth := AZBufferDepth;
  FullScreenWidth := ResX; FullScreenHeight := ResY; FullScreenColorDepth := BpP;
  FullScreenRefresh := Refresh;

  Fillchar(D3DPP, SizeOf(D3DPP), 0);
  with D3DPP do begin
    if AFullScreen then begin
      BackBufferWidth := ResX; BackBufferHeight := ResY;
      FullScreen_RefreshRateInHz := Refresh + D3DPRESENT_RATE_UNLIMITED*0;
      FullScreen_PresentationInterval  := D3DPRESENT_INTERVAL_IMMEDIATE;
      case BpP of
        15: BackBufferFormat := D3DFMT_X1R5G5B5;
        16: BackBufferFormat := D3DFMT_R5G6B5;
        24: BackBufferFormat := D3DFMT_X8R8G8B8;
        32: BackBufferFormat := D3DFMT_X8R8G8B8;
        else begin

          Log('Unsupported back buffer bit depth: ' + IntToStr(BpP), lkFatalError);

          Exit;
        end;
      end;
      BackBufferCount := 0;
      SwapEffect := {D3DSWAPEFFECT_FLIP*1 + 1*}D3DSWAPEFFECT_DISCARD;
    end else begin
      Res := Direct3D.GetAdapterDisplayMode(D3DADAPTER_DEFAULT, D3DDM);
      if Failed(Res) then begin

        Log('Error obtaining display mode. Result: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

        Exit;
      end;
      D3DPP.BackBufferFormat := D3DDM.Format;
      ActualColorDepth := D3DDM.Format;
      ActualRefresh := D3DDM.RefreshRate;
      SwapEffect := D3DSWAPEFFECT_FLIP*1 + 0*D3DSWAPEFFECT_DISCARD;
      BackBufferFormat := D3DDM.Format;
    end;
    Flags := 0;
    Windowed := not FFullScreen;
    hDeviceWindow := WindowHandle;
    if AZBufferDepth > 0 then begin
      EnableAutoDepthStencil := True;
      case AZBufferDepth of
        16: AutoDepthStencilFormat := D3DFMT_D16;
        24: AutoDepthStencilFormat := D3DFMT_D24S8;
        32: AutoDepthStencilFormat := D3DFMT_D32;
        else begin

          Log('Unsupported Z-buffer bit depth: ' + IntToStr(AZBufferDepth), lkFatalError);

          Exit;
        end;
      end;
    end;
  end;

  Res := D3DERR_INVALIDCALL;
  if Direct3dDevice = nil then begin
    if UseHardware then begin
      Res := Direct3D.CreateDevice(D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, WindowHandle,
{$IFDEF DEBUG}                     D3DCREATE_FPU_PRESERVE or D3DCREATE_MULTITHREADED or {$ENDIF}
                                   D3DCREATE_MIXED_VERTEXPROCESSING, D3DPP, Direct3DDevice);
      if Failed(Res) then begin
        Res := Direct3D.CreateDevice(D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, WindowHandle,
                                     D3DCREATE_SOFTWARE_VERTEXPROCESSING, D3DPP, Direct3DDevice);

        if not Failed(Res) then Log('Hardware vertex processing not supported. Switching to software vertex processing', lkWarning);

      end;
    end else Res := Direct3D.CreateDevice(D3DADAPTER_DEFAULT, D3DDEVTYPE_REF, WindowHandle,
                                          D3DCREATE_SOFTWARE_VERTEXPROCESSING, D3DPP, Direct3DDevice);
  end else begin
    Res := Direct3DDevice.Reset(D3DPP);
    if Failed(Res) then begin

      Log('Error resetting viewport. Result: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

      State := rsTryToRestore; Result := cvLost; Exit;
    end;
  end;
  if Failed(Res) then begin

    Log('Error creating Direct3D device. Result: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkFatalError);

    Exit;
  end;

  if not AFullScreen then ShowWindow(RenderWindowHandle, SW_SHOW);


  Log('Viewport succesfully created');


  State := rsClean;

  for i := 0 to High(CPFormats) do if CPFormats[i] = D3DPP.BackBufferFormat then RenderPars.VideoFormat := i;

  inherited CreateViewPort(WindowHandle, ResX, ResY, BpP, AFullScreen, AZBufferDepth, UseHardware, Refresh);

  Res := Direct3dDevice.SetRenderState(D3DRS_NORMALIZENORMALS, 1);
  Res := Direct3dDevice.SetRenderState(D3DRS_DITHERENABLE, 1);
  Res := Direct3DDevice.SetRenderState(D3DRS_CLIPPING, 1);
  Res := Direct3DDevice.SetRenderState(D3DRS_AMBIENTMATERIALSOURCE, D3DMCS_MATERIAL);
{  Mat.Diffuse.A := 0;
  Mat.Ambient.R := 1; Mat.Ambient.G := 1; Mat.Ambient.B := 1; Mat.Ambient.A := 0;
  Mat.Emissive.R := 0; Mat.Emissive.G := 0; Mat.Emissive.B := 0; Mat.Emissive.A := 0;
  Mat.Specular.A := 0;
  Mat.Power := 8;
  Res := Direct3DDevice.SetMaterial(Mat);}
//  Events.Add(cmdRendererReady, []);
  RenderActive := True;
  Result := cvOK;
end;

function TDX8Renderer.RestoreViewport: Integer;
var i: Integer;
begin
  Result := cvError;

  Log('Restoring viewport', lkTitle);

(*  if ((State = rsLost) or (State = rsTryToRestore)) and (Direct3dDevice.TestCooperativeLevel <> D3DERR_DEVICENOTRESET) then begin

    Log('No reason to call reset: Device not ready', lkInfo);

    State := rsTryToRestore; Sleep(1); Result := True; Exit;
  end;*)
//  for i := 0 to Length(Textures)-1 do IDirect3DTexture8(Textures[i].Texture) := nil;

  Streams.Reset;

  Result := CreateViewport(RenderWindowHandle, FullScreenWidth, FullScreenHeight, FullScreenColorDepth, FFullScreen, ActualZBufferDepth, HardwareMode, FullScreenRefresh);
  if Result = cvOK  then begin
    if Streams.Restore then begin

      Log('Streams restored');

//      if RestoreTextures then begin

//        Log('Textures restored');

//      end else begin

//        Log('Error restoring textures', lkError);

//        Exit;
//      end;
    end else begin

      Log('Error restoring streams', lkError);

      Exit;
    end;
  end else begin

    if Result = cvLost then
     Log('Device restoration impossible due to device lost', lkFatalError) else
      Log('Device restoration failed', lkFatalError);

    Exit;
  end;
  if RenderPars.ActualHeight <> 0 then RenderPars.CurrentAspectRatio := RenderPars.ActualWidth/RenderPars.ActualHeight * RenderPars.AspectRatio else RenderPars.CurrentAspectRatio := RenderPars.AspectRatio;
  InitMatrices(RenderPars.FoV, RenderPars.CurrentAspectRatio, RenderPars.ZNear, RenderPars.ZFar);
  SetFog(FogKind, FogColor, FogStart, FogEnd);
  SetShading(ShadingMode);
  SetDithering(Dithering);
  SetClearState(ClearFrameBuffer, ClearZBuffer, ClearStencilBuffer, ClearColor, ClearZ, ClearStencil);
//  SetTextureFiltering(tfLinear, tfLinear, tfLinear);
  ApplyLights;
//  State := rsClean;
  if WBuffering then
   Direct3dDevice.SetRenderState(D3DRS_ZENABLE, D3DZB_USEW) else
    Direct3dDevice.SetRenderState(D3DRS_ZENABLE, D3DZB_TRUE);
//  SetDithering(True);
  Direct3dDevice.SetRenderState(D3DRS_ZWRITEENABLE, 1);
  Direct3DDevice.SetRenderState(D3DRS_CLIPPING, 1);
//  Direct3DDevice.SetRenderState(D3DRS_POINTSIZE, 8);
  SetSpecular(SpecularMode);

//  for i := 0 to Length(Textures)-1 do DeleteTexture(i);
  RestoreTextures;

  Result := cvOK;
end;

procedure TDX8Renderer.InitMatrices(AXFoV, AAspect: Single; AZNear, AZFar: Single);
begin
  inherited;
  if Direct3DDevice = nil then Exit;
  Direct3DDevice.SetTransform(D3DTS_PROJECTION, TD3DMatrix(RenderPars.ProjMatrix));
end;

procedure TDX8Renderer.BeginScene;
begin
  Direct3DDevice.BeginScene;
end;

procedure TDX8Renderer.EndScene;
begin
  Direct3DDevice.EndScene;
end;

function TDX8Renderer.LoadToTexture(TextureID: Integer; Data: Pointer): Boolean;
var
  LockedRect: TD3DLocked_Rect;
  w, h, Level, LevelsGenerated, BpP: Integer; Ofs: Cardinal;
  Res: HResult;
begin
  Result := False;
  with Textures[TextureID] do Res := Direct3DDevice.CreateTexture(Width, Height, Ord(Levels=1), 0, CPFormats[Format], D3DPOOL_MANAGED, IDirect3DTexture8(Texture));
  if Failed(Res) then begin

    Log('Error creating Direct3DTexture object: Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);
    Log('  Call parameters: Dimensions: ' + IntToStr(Textures[TextureID].Width) + 'x' + IntToStr(Textures[TextureID].Height) +
            ' MipLevels: ' + IntToStr(Textures[TextureID].Levels) + ' Format: ' + IntToStr(Textures[TextureID].Format));

    Exit;
  end;

  LevelsGenerated := IDirect3DTexture8(Textures[TextureID].Texture).GetLevelCount;
  if LevelsGenerated <> Textures[TextureID].Levels then begin

    Log('TDX8Renderer.LoadToTexture: Unexpected count of mipmap levels generated', lkWarning);

    LevelsGenerated := MinI(LevelsGenerated, Textures[TextureID].Levels);
  end;

  w := Textures[TextureID].Width; h:= Textures[TextureID].Height;
  Ofs := 0;
  for Level := 0 to LevelsGenerated-1 do begin
    Res := IDirect3DTexture8(Textures[TextureID].Texture).LockRect(Level, LockedRect, nil, 0);
    if Failed(Res) then begin

      Log('Error locking texture level# ' + IntToStr(Level) + '. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

      Exit;
    end;

    Move(Pointer(Cardinal(Data) + Ofs)^, LockedRect.pBits^, w * h * GetBytesPerPixel(Textures[TextureID].Format));

    Inc(Ofs, w * h * GetBytesPerPixel(Textures[TextureID].Format));

    IDirect3DTexture8(Textures[TextureID].Texture).UnLockRect(Level);
    w := w shr 1; if w = 0 then if h = 1 then Break else w := 1;
    h := h shr 1; if h = 0 then h := 1;
  end;

  Textures[TextureID].Levels := LevelsGenerated;

  Result := True;
end;

function TDX8Renderer.UpdateTexture(Src: Pointer; TextureIndex: Integer; Area: TArea): Boolean;
var
  LockedRect: TD3DLocked_Rect;
  w, h, i, j, k, Level: Integer;
  Res: HResult;
  Tex: IDirect3DTexture8;
  LDesc: TD3DSurface_Desc;
  Rect: TRect;
begin
  Result := False;

  Log('Updating texture', lkTitle);

  if (Src = nil) or (TextureIndex = -1) or (Textures[TextureIndex].Texture = nil) then Exit;
  Tex := IDirect3DTexture8(Textures[TextureIndex].Texture);
  Tex.GetLevelDesc(0, LDesc);
  Level := Tex.GetLevelCount;
  w := LDesc.Width; h:= LDesc.Height;
  for k := 0 to Tex.GetLevelCount-1 do begin
    Res := Tex.LockRect(k, LockedRect, nil, 0);                   //ToFix: Optimize it
    if Failed(Res) then begin

      Log('Error locking texture level# ' + IntToStr(Level) + '. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

      Exit;
    end;
//    for i := 0 to w-1 do for j := 0 to h-1 do TDWordBuffer(LockedRect.pBits^)[j*w+i] := TDWordBuffer(Src^)[(j*LDesc.Height div h) * LDesc.Width + (i*LDesc.Width div w)];
    for i := Area.Left to Area.Right do for j := Area.Top to Area.Bottom do
     TDWordBuffer(LockedRect.pBits^)[j*w+i] :=
      TDWordBuffer(Src^)[(j*LDesc.Height div h) * LDesc.Width + (i*LDesc.Width div w)];

    Tex.UnLockRect(k);

    w := w shr 1; if w = 0 then w := 1;
    h := h shr 1; if h = 0 then h := 1;
    Area.Left := Area.Left div 2;
    Area.Right := Area.Right div 2;
    Area.Top := Area.Top div 2;
    Area.Bottom := Area.Bottom div 2;
  end;
//  Textures[TextureID].Resource := -1;
  Result := True;
end;

procedure TDX8Renderer.SetViewMatrix(const AMatrix: TMatrix4s);
begin
  inherited;
  if (Direct3DDevice = nil) or ((State <> rsOK) and (State <> rsClean)) then Exit;
  Direct3DDevice.SetTransform(D3DTS_VIEW, TD3DMatrix(RenderPars.ViewMatrix));
end;

function TDX8Renderer.LoadTexture(Filename: string; Width: Word = 0; Height: Word = 0; MipLevels: Word = 0; ColorKey: DWord = 0): Integer;
var Res: HResult;
begin
{  Result := -1;
  if FileName = '' then Exit;
  if Direct3DDevice = nil then begin
    if Logging then Log('Loading texture from file ' + Filename, 'Direct3D device not found');
    Exit;
  end;
//  Res := D3DXCreateTextureFromFileA(Direct3DDevice, PChar(Filename), Texture);
  Inc(TotalTextures);
  SetLength(Textures, TotalTextures);
  Res := D3DXCreateTextureFromFileExA(Direct3DDevice, PChar(Filename), Width, Height, MipLevels, 0, 0, D3DPOOL_DEFAULT, D3DX_FILTER_TRIANGLE, D3DX_FILTER_BOX, ColorKey, nil, nil, Textures[TotalTextures-1].Texture);
  if Failed(Res) then begin
    Dec(TotalTexturs);
    SetLength(Textures, TotalTextures);
    if Logging then
     Log('Can''t load texture from file ' + Filename, 'Error code: ' + IntToStr(Res) + ' ' + IntToStr(Res - MAKE_D3DHRESULT));
    exit;
  end;
  Textures[TotalTextures - 1].Filename := Filename;
  Textures[TotalTextures - 1].Width := Width; Textures[TotalTextures - 1].Height := Height;
  Textures[TotalTextures - 1].MipLevels := MipLevels; Textures[TotalTextures - 1].ColorKey := ColorKey;
  Result := TotalTextures - 1;
  if Logging then Log('Loading texture from file ' + Filename, 'OK');}
end;

function TDX8Renderer.GetFVF(CastVertexFormat: DWord): DWord;
var t: Integer;
begin
  Result := CVFormatsLow[CastVertexFormat and 255];
  Result := Result + ((CastVertexFormat shr 8) and 255) shl D3DFVF_TEXCOUNT_SHIFT;
  t := (CastVertexFormat shr 16) and 255;
  case t of
    1: Result := Result or D3DFVF_XYZB1;
    2: Result := Result or D3DFVF_XYZB2;
    3: Result := Result or D3DFVF_XYZB3;
    4: Result := Result or D3DFVF_XYZB4;
    5: Result := Result or D3DFVF_XYZB5;
  end;
//  if ((CastVertexFormat shr 16) and 255) > 0 then
//   Result := Result + ((CastVertexFormat shr 8) and 255);
end;

function TDX8Renderer.GetBitDepth(Format: LongWord): LongWord;
begin
  case Format of
    D3DFMT_R8G8B8: Result := 24;
    D3DFMT_A8R8G8B8, D3DFMT_X8R8G8B8: Result := 32;
    D3DFMT_R5G6B5, D3DFMT_A1R5G5B5, D3DFMT_A4R4G4B4, D3DFMT_A8R3G3B2, D3DFMT_X4R4G4B4, D3DFMT_A8P8, D3DFMT_A8L8: Result := 16;
    D3DFMT_X1R5G5B5: Result := 15;
    D3DFMT_R3G3B2, D3DFMT_A8, D3DFMT_P8, D3DFMT_L8, D3DFMT_A4L4: Result := 8;
    else Result := 0;
  end;
end;

procedure TDX8Renderer.SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single);
begin
  inherited;
  Direct3DDevice.SetViewport(TD3DViewport8(ViewPort));
end;

procedure TDX8Renderer.BeginStream(AStream: Cardinal);
begin
//  inherited;
  Streams.CurStream := AStream;
  with Streams.Streams[Streams.CurStream] do begin
    Direct3DDevice.SetStreamSource(0, (Streams as TDX8RenderStreams).D3DVertexBuffer[Streams.CurStream], VertexSize);
    Direct3DDevice.SetVertexShader(GetFVF(VertexFormat));
    SetLighting(VertexFormat and 2 > 0);
    Direct3DDevice.SetRenderState(D3DRS_VERTEXBLEND, VertexFormat shr 16);
    Direct3DDevice.SetRenderState(D3DRS_COLORVERTEX, (VertexFormat shr 2) and 1);
    if VertexFormat and 4 > 0 then
     Direct3DDevice.SetRenderState(D3DRS_DIFFUSEMATERIALSOURCE, D3DMCS_COLOR1) else
      Direct3DDevice.SetRenderState(D3DRS_DIFFUSEMATERIALSOURCE, D3DMCS_MATERIAL);
    if VertexFormat and 8 > 0 then
     Direct3DDevice.SetRenderState(D3DRS_SPECULARMATERIALSOURCE, D3DMCS_COLOR2) else
      Direct3DDevice.SetRenderState(D3DRS_SPECULARMATERIALSOURCE, D3DMCS_MATERIAL);
  end;
end;

procedure TDX8Renderer.EndStream;
begin
//  inherited;
end;

procedure TDX8Renderer.SetBlending(SrcBlend, DestBlend: Cardinal);
begin
  if Direct3DDevice = nil then Exit;
  if (SrcBlend = bmOne) and (DestBlend = bmZero) then Direct3DDevice.SetRenderState(D3DRS_ALPHABLENDENABLE, 0) else begin
    Direct3DDevice.SetRenderState(D3DRS_ALPHABLENDENABLE, 1);
    Direct3DDevice.SetRenderState(D3DRS_SRCBLEND, BlendModes[SrcBlend-1]);
    Direct3DDevice.SetRenderState(D3DRS_DESTBLEND, BlendModes[DestBlend-1]);
  end;
end;

procedure TDX8Renderer.SetFog(Kind: Cardinal; Color: DWord; AFogStart, AFogEnd: Single);
begin
  if Direct3DDevice = nil then Exit;
  FogColor := Color;
  FogStart := AFogStart; FogEnd := AFogEnd;
  FogKind := Kind;
  if FogKind <> fkNone then begin
    Direct3DDevice.SetRenderState(D3DRS_FOGENABLE, Ord(True));
    Direct3DDevice.SetRenderState(D3DRS_FOGCOLOR, Color);
    case Kind of
      fkVertex: begin
        Direct3DDevice.SetRenderState(D3DRS_FOGVERTEXMODE, D3DFOG_LINEAR);
        Direct3DDevice.SetRenderState(D3DRS_RANGEFOGENABLE , 0);
        Direct3DDevice.SetRenderState(D3DRS_FOGTABLEMODE, D3DFOG_NONE);
      end;
      fkVertexRanged: begin
        Direct3DDevice.SetRenderState(D3DRS_RANGEFOGENABLE , 1);
        Direct3DDevice.SetRenderState(D3DRS_FOGVERTEXMODE, D3DFOG_LINEAR);
        Direct3DDevice.SetRenderState(D3DRS_FOGTABLEMODE, D3DFOG_NONE);
      end;
      fkTable: begin
        Direct3DDevice.SetRenderState(D3DRS_FOGTABLEMODE, D3DFOG_LINEAR);
        Direct3DDevice.SetRenderState(D3DRS_RANGEFOGENABLE , 0);
        Direct3DDevice.SetRenderState(D3DRS_FOGVERTEXMODE, D3DFOG_NONE);
      end;
    end;
    Direct3DDevice.SetRenderState(D3DRS_FOGSTART, DWord((@FogStart)^));
    Direct3DDevice.SetRenderState(D3DRS_FOGEND, DWord((@FogEnd)^));
  end else Direct3DDevice.SetRenderState(D3DRS_FOGENABLE, Ord(False));
end;

procedure TDX8Renderer.SetCullMode(CMode: DWord);
begin
  Direct3DDevice.SetRenderState(D3DRS_CULLMODE, CCullModes[CMode]);
end;

procedure TDX8Renderer.SetZTest(ZTestMode, TestFunc: Cardinal);
begin
  Direct3DDevice.SetRenderState(D3DRS_ZENABLE, ZTestMode);
  Direct3DDevice.SetRenderState(D3DRS_ZFUNC, TestFuncs[TestFunc]);
end;

procedure TDX8Renderer.SetAlphaTest(AlphaRef, TestFunc: Cardinal);
begin
  if TestFunc = tfAlways then Direct3DDevice.SetRenderState(D3DRS_ALPHATESTENABLE, 0) else begin
    Direct3DDevice.SetRenderState(D3DRS_ALPHATESTENABLE, 1);
    Direct3DDevice.SetRenderState(D3DRS_ALPHAFUNC, TestFuncs[TestFunc]);
  end;
  Direct3DDevice.SetRenderState(D3DRS_ALPHAREF, AlphaRef);
end;

procedure TDX8Renderer.SetZWrite(ZWrite: Boolean);
begin
  Direct3DDevice.SetRenderState(D3DRS_ZWRITEENABLE, Ord(ZWrite));
end;

procedure TDX8Renderer.SetBlendOperation(BOperation: Cardinal); 
begin
  Direct3DDevice.SetRenderState(D3DRS_BLENDOP, BlendOps[BOperation]);
end;

procedure TDX8Renderer.SetColorMask(Alpha, Red, Green, Blue: Boolean);
begin
  Direct3DDevice.SetRenderState(D3DRS_COLORWRITEENABLE, D3DCOLORWRITEENABLE_ALPHA*Ord(Alpha) + D3DCOLORWRITEENABLE_RED*Ord(Red) + D3DCOLORWRITEENABLE_GREEN*Ord(Green) + D3DCOLORWRITEENABLE_BLUE*Ord(Blue));
end;

procedure TDX8Renderer.SetLighting(HardLighting: Boolean);
begin
  Direct3DDevice.SetRenderState(D3DRS_LIGHTING, Ord(HardLighting));
end;

procedure TDX8Renderer.SetTextureFiltering(const Stage: Integer; const MagFilter, MinFilter, MipFilter: DWord);
begin
  Direct3DDevice.SetTextureStageState(Stage, D3DTSS_MAGFILTER, CTFilters[MagFilter]);
  Direct3DDevice.SetTextureStageState(Stage, D3DTSS_MINFILTER, CTFilters[MinFilter]);
  Direct3DDevice.SetTextureStageState(Stage, D3DTSS_MIPFILTER, CTFilters[MipFilter]);
end;

procedure TDX8Renderer.SetShading(AShadingMode: Cardinal); 
begin
  ShadingMode := AShadingMode;
  Direct3dDevice.SetRenderState(D3DRS_SHADEMODE, ShadingMode);
end;

procedure TDX8Renderer.SetDithering(ADithering: Boolean);
begin
  Dithering := ADithering;
  Direct3dDevice.SetRenderState(D3DRS_DITHERENABLE, Ord(Dithering));
end;

procedure TDX8Renderer.SetSpecular(ASpecular: Cardinal);
begin
  inherited;
  Direct3dDevice.SetRenderState(D3DRS_SPECULARENABLE, Ord(SpecularMode <> slNone));
  Direct3dDevice.SetRenderState(D3DRS_LOCALVIEWER, Ord(SpecularMode = slQuality));
//  Direct3dDevice.SetRenderState(D3DRS_SPECULARMATERIALSOURCE, Ord(Specular));
end;

procedure TDX8Renderer.ApplyRenderState(State, Value: DWord);
begin
  Direct3DDevice.SetRenderState(State, Value);
end;

procedure TDX8Renderer.ApplyLights;
var HLight: TD3DLIGHT8; i: Integer;
begin
  SetAmbient(AmbientColor);
  ActiveHardwareLights := 0;
  for i := 0 to Length(Lights)-1 do with HLight do if Lights[i].LightOn then begin
    case Lights[i].LightType of
      ltDirectional: _Type := D3DLIGHT_DIRECTIONAL;
      ltOmniNoShadow: _Type := D3DLIGHT_POINT;
      ltSpotNoShadow: _Type := D3DLIGHT_SPOT;
    end;

    Diffuse.r := Lights[i].Diffuse.R; Diffuse.g := Lights[i].Diffuse.G; Diffuse.b := Lights[i].Diffuse.B; Diffuse.a := Lights[i].Diffuse.A;
    Specular.r := Lights[i].Specular.R; Specular.g := Lights[i].Specular.G; Specular.b := Lights[i].Specular.B; Specular.a := Lights[i].Specular.A;
    Ambient.r := Lights[i].Ambient.R; Ambient.g := Lights[i].Ambient.G; Ambient.b := Lights[i].Ambient.B; Ambient.a := Lights[i].Ambient.A;
    Direction.X := Lights[i].Direction.X; Direction.Y := Lights[i].Direction.Y; Direction.Z := Lights[i].Direction.Z;
    Position.X := Lights[i].Location.X; Position.Y := Lights[i].Location.Y; Position.Z := Lights[i].Location.Z;

    Range := Lights[i].Range;
    Falloff := Lights[i].Falloff;

    Attenuation0 := Lights[i].Attenuation0;
    Attenuation1 := Lights[i].Attenuation1;
    Attenuation2 := Lights[i].Attenuation2;

    Theta := Lights[i].Theta;
    Phi := Lights[i].Phi;

    Direct3dDevice.SetLight(i, HLight);
    Direct3dDevice.LightEnable(i, True);
    Inc(ActiveHardwareLights);
  end else Direct3dDevice.LightEnable(i, False);
end;

procedure TDX8Renderer.SetLight(Index: Integer; ALight: TLight);
var HLight: TD3DLIGHT8;
begin
  if not Lights[Index].LightOn then Inc(ActiveHardwareLights);                    // Increase if old light was off
  inherited;
  if (State <> rsOK) and (State <> rsClean) then Exit;
  with HLight do begin
    case ALight.LightType of
      ltDirectional: _Type := D3DLIGHT_DIRECTIONAL;
      ltOmniNoShadow: _Type := D3DLIGHT_POINT;
      ltSpotNoShadow: _Type := D3DLIGHT_SPOT;
    end;

    Diffuse.r := ALight.Diffuse.R; Diffuse.g := ALight.Diffuse.G; Diffuse.b := ALight.Diffuse.B; Diffuse.a := ALight.Diffuse.A;
    Specular.r := ALight.Specular.R; Specular.g := ALight.Specular.G; Specular.b := ALight.Specular.B; Specular.a := ALight.Specular.A;
    Ambient.r := ALight.Ambient.R; Ambient.g := ALight.Ambient.G; Ambient.b := ALight.Ambient.B; Ambient.a := ALight.Ambient.A;
    Direction.X := ALight.Direction.X; Direction.Y := ALight.Direction.Y; Direction.Z := ALight.Direction.Z;
    Position.X := ALight.Location.X; Position.Y := ALight.Location.Y; Position.Z := ALight.Location.Z;

    Range := ALight.Range;
    Falloff := ALight.Falloff;

    Attenuation0 := ALight.Attenuation0;
    Attenuation1 := ALight.Attenuation1;
    Attenuation2 := ALight.Attenuation2;

    Theta := ALight.Theta;
    Phi := ALight.Phi;
  end;
  Direct3dDevice.SetLight(Index, HLight);
  Direct3dDevice.LightEnable(Index, True);
  Lights[Index].LightOn := True;
end;

procedure TDX8Renderer.SetAmbient(Color: LongWord);
begin
  AmbientColor := Color;
  Direct3DDevice.SetRenderState(D3DRS_AMBIENT, Color);
end;

procedure TDX8Renderer.DeleteLight(Index: Cardinal);
begin
  if Lights[Index].LightOn then Dec(ActiveHardwareLights);
  Direct3dDevice.LightEnable(Index, False);
  Lights[Index].LightOn := False;
end;

procedure TDX8Renderer.ApplyMaterial(AMaterial: TMaterial);
const D3DTS_TEXTURE: array[0..7] of Longword =
      (D3DTS_TEXTURE0, D3DTS_TEXTURE1, D3DTS_TEXTURE2, D3DTS_TEXTURE3,
       D3DTS_TEXTURE4, D3DTS_TEXTURE5, D3DTS_TEXTURE6, D3DTS_TEXTURE7);
      D3DRS_WRAP: array[0..7] of Longword =
      (D3DRS_WRAP0, D3DRS_WRAP1, D3DRS_WRAP2, D3DRS_WRAP3, D3DRS_WRAP4, D3DRS_WRAP5, D3DRS_WRAP6, D3DRS_WRAP7);
var i: Integer;
begin
  if AMaterial.FillMode = fmDefault then
   Direct3DDevice.SetRenderState(D3DRS_FILLMODE, FillMode) else begin
     Direct3DDevice.SetRenderState(D3DRS_FILLMODE, AMaterial.FillMode);
   end;
//  AMaterial.Diffuse.A := 0; AMaterial.Specular.A := 0;AMaterial.Ambient.A := 0;

  Mat.Ambient := TD3DColorValue(AMaterial.Ambient);
  Mat.Diffuse := TD3DColorValue(AMaterial.Diffuse);
  Mat.Specular := TD3DColorValue(AMaterial.Specular);
  Mat.Power := AMaterial.Power;
{  Mat.Diffuse.r := 1;
  Mat.Diffuse.g := 0;
  Mat.Diffuse.b := 0;
  Mat.Diffuse.a := 0;}
  Direct3DDevice.SetMaterial(Mat);
  for i := 0 to AMaterial.TotalStages-1 do with AMaterial.Stages[i] do begin
    if (EnableTexturing) and (TextureIND <> -1) and (Textures[TextureInd].Texture <> nil) then begin
      Direct3DDevice.SetTexture(i, IDirect3DTexture8(Textures[TextureInd].Texture));
      Direct3DDevice.SetTextureStageState(i, D3DTSS_ADDRESSU, CTAddressing[TAddressing]);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_ADDRESSV, CTAddressing[TAddressing]);
      SetTextureFiltering(i, MagFilter, MinFilter, MipFilter);
    end else Direct3DDevice.SetTexture(i, nil);
    Direct3DDevice.SetTextureStageState(i, D3DTSS_COLOROP, CTOperation[ColorOp]);
    Direct3DDevice.SetTextureStageState(i, D3DTSS_COLORARG1, ColorArg1);
    Direct3DDevice.SetTextureStageState(i, D3DTSS_COLORARG2, ColorArg2);
    Direct3DDevice.SetTextureStageState(i, D3DTSS_ALPHAOP, CTOperation[AlphaOp]);
    Direct3DDevice.SetTextureStageState(i, D3DTSS_AlphaARG1, AlphaArg1);
    Direct3DDevice.SetTextureStageState(i, D3DTSS_AlphaARG2, AlphaArg2);
    Direct3DDevice.SetTextureStageState(i, D3DTSS_RESULTARG, Destination);
    Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXCOORDINDEX, UVSource and $FF or TexCoordSources[UVSource shr 8]);

    Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXTURETRANSFORMFLAGS, TTransformFlags[TTransform and $FF] or (D3DTTFF_PROJECTED * Cardinal(Ord(TTransform and $100 > 0))));
    if TTransform <> ttNone then Direct3DDevice.SetTransform(D3DTS_TEXTURE[i], TD3DMatrix(TexMatrix));

    Direct3DDevice.SetRenderState(D3DRS_WRAP[i], D3DWRAPCOORD_0 * Ord(TWrapping and twUCoord  > 0) or
                                                 D3DWRAPCOORD_1 * Ord(TWrapping and twVCoord  > 0) or
                                                 D3DWRAPCOORD_2 * Ord(TWrapping and twWCoord  > 0) or
                                                 D3DWRAPCOORD_3 * Ord(TWrapping and twW2Coord > 0));
  end;
  if AMaterial.TotalStages < MaxTextureStages then begin
    Direct3DDevice.SetTexture(AMaterial.TotalStages, nil);
    Direct3DDevice.SetTextureStageState(AMaterial.TotalStages, D3DTSS_COLOROP, CTOperation[toDisable]);
    Direct3DDevice.SetTextureStageState(AMaterial.TotalStages, D3DTSS_ALPHAOP, CTOperation[toDisable]);
  end;
end;

procedure TDX8Renderer.BeginRenderPass(Pass: TRenderPass);
begin
  inherited;
  Direct3DDevice.SetRenderState(D3DRS_FOGENABLE, Byte(Pass.EnableFog and (FogKind <> fkNone)));
  SetBlending(Pass.SrcBlend, Pass.DestBlend);
  Direct3DDevice.SetRenderState(D3DRS_ZFUNC, TestFuncs[Pass.ZTestFunc]);
  SetZWrite(Pass.ZWrite);
  SetAlphaTest(Pass.AlphaRef, Pass.ATestFunc);
end;

procedure TDX8Renderer.EndRenderPass(Pass: TRenderPass);
begin
  inherited;
end;

procedure TDX8Renderer.AddTesselator(Obj: TTesselator);
var i: Integer;
begin
//  if not Enabled then Exit;                // ToFix: Move render state checking to CAST main unit
  if (State <> rsOK) and (State <> rsClean) then Exit;
  if Obj.TotalVertices = 0 then Exit;
  Direct3DDevice.SetTransform(D3DTS_World, TD3DMatrix(WorldMatrix));
  Direct3DDevice.SetTransform(D3DTS_World1, TD3DMatrix(WorldMatrix1));

  if Obj.TotalIndices > 0 then begin
    for i := Obj.TotalStrips - 1 downto 0 do begin
      Direct3DDevice.SetIndices((Streams as TDX8RenderStreams).D3DIndexBuffer[Streams.CurStream], (Obj.VBOffset + i * Obj.StripOffset));
      Direct3DDevice.DrawIndexedPrimitive(Obj.PrimitiveType, 0, Obj.IndexingVertices, Obj.IBOffset, Obj.TotalPrimitives);
    end;
  end else for i := Obj.TotalStrips - 1 downto 0 do Direct3DDevice.DrawPrimitive(Obj.PrimitiveType, Obj.VBOffset, Obj.TotalPrimitives);
end;

procedure TDX8Renderer.Clear(ClearTarget: Cardinal; Color: Cardinal; Z: Single; Stencil: Cardinal);
var Res: HResult; i: Integer;
begin
  if (State = rsLost) and (GetTickCount - LostTime > MaxLostTime) then begin
    State := rsTryToRestore;

    Log('No device restoration attempts in ' + IntToStr(MaxLostTime) + ' millisecondss. Forcing restoration', lkWarning);

  end;
  if (State <> rsOK) and (State <> rsClean) then Exit;
//  if State = rsTryToRestore then begin RestoreViewport; Exit; end;

  Direct3DDevice.Clear(0, nil, ClearTarget, Color, Z, Stencil);
end;

procedure TDX8Renderer.Render;
var Res: HResult; i: Integer;
begin
  if (State = rsLost) and (GetTickCount - LostTime > MaxLostTime) and RenderActive then begin
    State := rsTryToRestore;

    Log('No device restoration attempts in ' + IntToStr(MaxLostTime) + ' millisecondss. Forcing restoration', lkWarning);

  end;
  if (State = rsTryToRestore) then begin
    if RestoreViewport <> cvOK then Sleep(1);
    Exit;
  end;

  if (State <> rsOK) and (State <> rsClean){ or not RenderActive} then begin Sleep(1); Exit; end;

  Res := 0;

  if RenderActive then begin
    Res := Direct3DDevice.Present(nil, nil, 0, nil);
    Clear(D3DCLEAR_TARGET*Byte(ClearFrameBuffer) or D3DCLEAR_ZBUFFER*Byte(ClearZBuffer) or D3DCLEAR_STENCIL*Byte(ClearStencilBuffer), ClearColor, ClearZ, ClearStencil);
  end else Res := Direct3DDevice.TestCooperativeLevel;

//  Delay(4000);
//  Sleep(4);

  if Res = D3DERR_DEVICELOST then begin
//    RestoreDevice;
    State := rsLost; LostTime := GetTickCount;

    Log('Render: Device lost. Need to restore', lkWarning);

    Sleep(5);
    Exit;
  end;

  if not RenderActive then begin
    State := rsLost;
    Sleep(1);
    Exit;
  end;

  State := rsOK;

  for i := 0 to TotalStreams - 1 do with Streams.Streams[i] do begin
    CurVBOffset := 0; CurIBOffset := 0;
  end;

  Inc(FrameNumber);
end;

procedure TDX8Renderer.CloseViewport;
var i: Integer;
begin
  FreeTextures;
  inherited;
  if Assigned(Direct3DDevice) then Direct3DDevice := nil else begin

    Log('Viewport was not opened', lkWarning);

    Exit;
  end;
end;

destructor TDX8Renderer.Shutdown;
begin
  inherited;
  if Assigned(Direct3D) then Direct3D := nil;
//  SetLength(Lights, 0);
end;


procedure TDX8Renderer.SetFullScreen(const FScreen: Boolean);
begin
  if FFullScreen = FScreen then Exit;
//  State := rsNotReady;

{  if not FFullScreen then begin
    GetWindowRect(RenderWindowHandle, WindowedRect);
  end else
    SetWindowPos(RenderWindowHandle, HWND_NOTOPMOST, WindowedRect.Left, WindowedRect.Top, WindowedRect.Right, WindowedRect.Bottom, SWP_NOREPOSITION or SWP_DRAWFRAME);}

  FFullScreen := FScreen;

  RestoreViewport;

//  SetWindowPlacement()
end;

function TDX8Renderer.RestoreDevice: Boolean;
var i: Integer; Res: HResult;
begin
  Result := False;
  if (Direct3dDevice.TestCooperativeLevel <> D3DERR_DEVICENOTRESET) then begin

    Log('No reason to call reset: Device not ready', lkInfo);

    State := rsTryToRestore; Sleep(1); Exit;
  end;
// Destroing vertex buffers
  Streams.Reset;
  Res := Direct3DDevice.Reset(D3DPP);
  if Failed(Res) then begin

    Log('Error resetting device. Result: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

    State := rsTryToRestore; Exit;
  end else begin
    if Streams.Restore then begin

      Log('Streams restored');

    end else begin

      Log('Error restoring streams', lkError);

      Exit;
    end;
  end;
  Result := True;
end;

procedure TDX8Renderer.DeleteTexture(TextureID: Integer);
var i: Integer; Tex: IDirect3DBaseTexture8;
begin
  for i := 0 to MaxTextureStages-1 do begin
    Direct3DDevice.GetTexture(i, Tex);
    if Pointer(Tex) = Textures[TextureID].Texture then Direct3DDevice.SetTexture(i, nil);
  end;
  IDirect3DTexture8(Textures[TextureID].Texture) := nil;
  inherited;
end;

{ TDX8RenderStreams }

function TDX8RenderStreams.Add(VBufSize, IBufSize, AVertexFormat, AIndexSize: DWord; AStatic: Boolean): Integer;
var Usage, IndexFormat: DWord;
begin
  Result := -1;
  Inc(TotalStreams);

  Log('Creating render stream #' + IntToStr(TotalStreams-1), lkTitle);

  SetLength(Streams, TotalStreams);
  SetLength(D3DVertexBuffer, TotalStreams);
  SetLength(D3DIndexBuffer, TotalStreams);
  with Streams[TotalStreams-1] do begin
    VertexBufferSize := VBufSize;
    IndexBufferSize := IBufSize;
    VertexSize := GetVertexSize(AVertexFormat);
    IndexSize := AIndexSize;
    Static := AStatic;
    VertexFormat := AVertexFormat;
    ZTestMode := zbtW;
  end;
  if (AIndexSize <> 2) and (AIndexSize <> 4) then begin

    Log('Error creating stream: Invalid index size: '+IntToStr(AIndexSize), lkError);

    Exit;
  end;
  if AStatic then Usage := D3DUSAGE_WRITEONLY else Usage := D3DUSAGE_DYNAMIC or D3DUSAGE_WRITEONLY;
  if not ( CreateVBuffer(TotalStreams-1, VBufSize, Usage, D3DPOOL_DEFAULT) and
          (CreateIBuffer(TotalStreams-1, IBufSize, Usage, D3DPOOL_DEFAULT) or (IBufSize = 0)) ) then begin
    Dec(TotalStreams); SetLength(Streams, TotalStreams-1);

    Log('Error creating stream: Creation of VB or IB failed', lkError);

    Exit;
  end;
  Result := TotalStreams - 1;
end;

function TDX8RenderStreams.Resize(Stream: Integer; VBufSize, IBufSize, IndexSize: DWord; AStatic: Boolean): Integer;
var Usage, IndexFormat: DWord;
begin
  Result := -1;

  Log('Resizing render stream #' + IntToStr(Stream), lkTitle);

  if Stream >= TotalStreams then begin
//    Result := AddStream(VBufSize, IBufSize, IndexSize, Static);

    Log('Error resizing stream: Stream index out of range', lkError);

    Exit;
  end;
  Streams[Stream].VertexBufferSize := VBufSize;
  Streams[Stream].IndexBufferSize := IBufSize;
  Streams[Stream].IndexSize := IndexSize;
  Streams[Stream].Static := AStatic;
  if (IndexSize <> 2) and (IndexSize <> 4) then begin

    Log('Error resizing stream: Invalid index size: ' + IntToStr(IndexSize), lkError);

    Exit;
  end;
  if AStatic then Usage := D3DUSAGE_WRITEONLY else Usage := D3DUSAGE_DYNAMIC or D3DUSAGE_WRITEONLY;
  if not ( CreateVBuffer(Stream, VBufSize, Usage, D3DPOOL_DEFAULT) and
          (CreateIBuffer(Stream, IBufSize, Usage, D3DPOOL_DEFAULT) or (IBufSize = 0)) ) then begin
    Result := Stream;

    Log('Error resizing stream: Creation of VB or IB failed', lkError);

  end;
//  Streams[Stream].VertexBuffer.PreLoad;
//  Streams[Stream].IndexBuffer.PreLoad;
end;

function TDX8RenderStreams.CreateVBuffer(Stream: DWord; BufferLength: Integer; Usage, Pool: DWord): Boolean;
var Res: HResult;
begin
  Result := False;

  Log('Creating vertex buffer. Size: ' + IntToStr(BufferLength), lkTitle);

  D3DVertexBuffer[Stream] := nil;

  if BufferLength = 0 then Exit;

  Res := (Renderer as TDX8Renderer).Direct3DDevice.CreateVertexBuffer(BufferLength, Usage, Renderer.GetFVF(Streams[Stream].VertexFormat), Pool, D3DVertexBuffer[Stream]);
  if Failed(Res) then begin

    Log('Error creating vertex buffer. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

    Exit;
  end;
  Result := True;
end;

function TDX8RenderStreams.CreateIBuffer(Stream: DWord; BufferLength: Integer; Usage, Pool: DWord): Boolean;
var Res: HResult; IndexFormat: DWord;
begin
  Result := False;

  Log('Creating index buffer. Size: '+IntToStr(BufferLength), lkInfo);

  D3DIndexBuffer[Stream] := nil;

  if BufferLength = 0 then Exit;

  case Streams[Stream].IndexSize of
    2: IndexFormat := D3DFMT_INDEX16;
    4: IndexFormat := D3DFMT_INDEX32;
    else begin

      Log('Error creating index buffer: Invalid index size: '+IntToStr(Streams[Stream].IndexSize), lkError);

      Exit;
    end;
  end;
  Res := (Renderer as TDX8Renderer).Direct3DDevice.CreateIndexBuffer(BufferLength, Usage, IndexFormat, Pool, D3DIndexBuffer[Stream]);
  if Failed(Res) then begin

    Log('Error creating index buffer. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

    Exit;
  end;
  Result := True;
end;

function TDX8RenderStreams.FillVertexes(Stream: DWord; Source: Pointer; SourceSize, Offset: DWord): Boolean;
var Res: HResult; PTR: PByte;
begin
  Result := False;
  if D3DVertexBuffer[Stream] = nil then begin

    Log('Error filling vertices in stream #' + IntToStr(Stream) + ': No vertex buffer', lkError);

    Exit;
  end;
  Res := D3DVertexBuffer[Stream].Lock(Offset, SourceSize, PTR, 0);
  if Failed(Res) then begin

    Log('FillVertexes: Error locking vertex buffer. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);
    Log(Format('  Call parameters: Stream #: %D, Ofset: %D, Size: %D', [Stream, Offset, SourceSize]), lkInfo);

    Exit;
  end;
  Move(Source^, PTR^, SourceSize);
  D3DVertexBuffer[Stream].Unlock;
  Result := True;
end;

function TDX8RenderStreams.FillIndices(Stream: DWord; Source: Pointer; SourceSize, Offset: DWord): Boolean;
var Res: HResult; PTR: PByte;
begin
  Result := False;
  if D3DIndexBuffer[Stream] = nil then begin

    Log('Error filling indices in stream #' + IntToStr(Stream) + ': No index buffer', lkError);

    Exit;
  end;
  Res := D3DIndexBuffer[Stream].Lock(Offset, SourceSize, PTR, 0);
  if Failed(Res) then begin

    Log('FillIndices: Error locking index buffer. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

    Exit;
  end;
  Move(Source^, PTR^, SourceSize);
  D3DIndexBuffer[Stream].Unlock;
  Result := True;
end;

function TDX8RenderStreams.LockVBuffer(Stream: DWord; const BOffset, BSize, Mode: DWord): PByte;
var Res: HResult;
begin
  Res := D3DVertexBuffer[Stream].Lock(BOffset, BSize, Result, LockModes[Mode]);

  if Failed(Res) then begin
    Log('LockVBuffer: Error locking vertex buffer. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);
    Log(Format('  Call parameters: Stream #: %D, Ofset: %D, Size: %D, Mode: %D', [Stream, BOffset, BSize, Mode]), lkInfo);
  end;

end;

function TDX8RenderStreams.LockIBuffer(Stream: DWord; const BOffset, BSize, Mode: DWord): PByte;
var Res: HResult;
begin
  Res := D3DIndexBuffer[Stream].Lock(BOffset, BSize, Result, LockModes[Mode]);

  if Failed(Res) then begin
    Log('LockIBuffer: Error locking index buffer. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);
    Log(Format('  Call parameters: Stream #: %D, Ofset: %D, Size: %D, Mode: %D', [Stream, BOffset, BSize, Mode]), lkInfo);
  end;

end;

procedure TDX8RenderStreams.UnLockVBuffer(Stream: DWord);
var Res: HResult;
begin
  Res := D3DVertexBuffer[Stream].UnLock;

  if Failed(Res) then Log('Error unlocking vertex buffer. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

end;

procedure TDX8RenderStreams.UnLockIBuffer(Stream: DWord);
var Res: HResult;
begin
  Res := D3DIndexBuffer[Stream].UnLock;

  if Failed(Res) then Log('Error unlocking index buffer. Error code: ' + IntToStr(Res) + ' "' + DXGErrorString(Res) + '"', lkError);

end;

procedure TDX8RenderStreams.Reset;
var i: Integer;
begin
  for i := 0 to TotalStreams - 1 do with Streams[i] do begin
    D3DVertexBuffer[i] := nil;
    D3DIndexBuffer[i] := nil;
  end;
  inherited;
end;

function TDX8RenderStreams.Restore: Boolean;
var i: Integer; Usage: DWord;
begin

  Log('Restoring streams', lkTitle);

  Result := False;
  for i := 0 to TotalStreams - 1 do with Streams[i] do begin

    Log('Index buffer size: '+IntToStr(IndexBufferSize), lkInfo);

    CurVBOffset := 0; CurIBOffset := 0;
    if Static then Usage := D3DUSAGE_WRITEONLY else Usage := D3DUSAGE_DYNAMIC or D3DUSAGE_WRITEONLY;
    if not ( CreateVBuffer(i, VertexBufferSize, Usage, D3DPOOL_DEFAULT) and
            (CreateIBuffer(i, IndexBufferSize, Usage, D3DPOOL_DEFAULT) or (IndexBufferSize = 0)) ) then begin
      Exit;
    end;
  end;
  Result := True;
end;

destructor TDX8RenderStreams.Free;
var i: Integer;
begin

  Log('Freeing all streams', lkInfo);

  Reset;
end;

end.
