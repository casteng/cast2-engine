(*
 @Abstract(CAST Engine DirectX 8 render unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains DirectX 8-based renderer implementation classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2DX8Render;

interface

uses
  BaseTypes, Basics, BaseStr, Base3D, Collisions, OSUtils,
  Logger,
  BaseClasses,
  C2Types, CAST2, C2Res, C2Visual, C2Render, C2Materials,
  Direct3D8, 
  {$IFDEF USED3DX8}
    D3DX8,
  {$ENDIF}
  {$IFDEF DX8ERRORSTR}
    DXErr8,
  {$ENDIF}
  SysUtils, Windows, Messages;

const
    // Device types
  // Hardware accelerated layer
  dtHAL = 0;
  // Reference software rasterizer
  dtREF = 1;
  // Software rasterizer
  dtSW  = 2;
  // Device types string enumeration
  DeviceTypesEnum = 'Hardware\&Reference\&Software';
{$IFDEF DEBUGMODE}
  FullScreenWindowStyle = WS_POPUP or WS_VISIBLE{ or WS_EX_APPWINDOW};
//  FullScreenWindowStyle = WS_OVERLAPPED or WS_CAPTION or WS_THICKFRAME or 0*WS_MINIMIZEBOX or WS_MAXIMIZEBOX or WS_SIZEBOX or WS_SYSMENU;
{$ELSE}
  FullScreenWindowStyle = WS_POPUP or WS_VISIBLE;
{$ENDIF}

  // Usage flags for dynamic and static vertex buffers
  BufferUsage: array[Boolean] of Cardinal = (D3DUSAGE_DYNAMIC or D3DUSAGE_WRITEONLY,         // Dynamic buffer usage
                                             D3DUSAGE_WRITEONLY);                            // Static buffer usage

  // Pool flags for vertex buffers with fully hardware vertex processing and hardware T&L with software shader emulation
  BufferPool: array[Boolean] of TD3DPool = (D3DPOOL_DEFAULT, D3DPOOL_SYSTEMMEM);

  // Flags for dynamic and static vertex buffers lock with keeping contents or without
  BufferLockFlags: array[Boolean, Boolean] of Cardinal =
   ((D3DLOCK_NOOVERWRITE*1 or 0*D3DLOCK_DISCARD or 0*D3DLOCK_NOSYSLOCK,   // Dynamic non-discard lock
     D3DLOCK_DISCARD*1 or 0*D3DLOCK_NOSYSLOCK),                           // Dynamic discard lock
     (D3DLOCK_NOOVERWRITE*0, 1*D3DLOCK_DISCARD));                         // Static non-discard and discard lock

  VertexDataTypeToD3DVSDT: array[vdtFloat1..vdtInt16_4] of Cardinal =
    (D3DVSDT_FLOAT1, D3DVSDT_FLOAT2, D3DVSDT_FLOAT3, D3DVSDT_FLOAT4, D3DVSDT_D3DCOLOR, D3DVSDT_UBYTE4, D3DVSDT_SHORT2, D3DVSDT_SHORT4);
//     D3DVSDT_UBYTE4, D3DVSDT_FLOAT1, D3DVSDT_FLOAT2);           // Unsupported by DX8

type
  TDX8VertexDeclaration = array[0..$FFFF] of Cardinal;
  PDX8VertexDeclaration = ^TDX8VertexDeclaration;

  TDX8VertexBuffer = record
    VertexSize, BufferSize: Integer;
    Static: Boolean;
    Buffer: IDirect3DVertexBuffer8;
  end;

  TDX8IndexBuffer = record
    BufferSize: Integer;
    Static: Boolean;
    Buffer: IDirect3DIndexBuffer8;
  end;

  // @Abstract(Direct X 8 implementation of vertex and index buffers management class)
  TDX8Buffers = class(TAPIBuffers)
  private
    VertexBuffers: array of TDX8VertexBuffer;
    IndexBuffers: array of TDX8IndexBuffer;
  public
//    destructor Destroy; override;
    // Returns a flexible vertex format code from CAST vertex format
    function GetFVF(CastVertexFormat: Cardinal): Cardinal;
    { Creates a vertex buffer with the given size in bytes and returns its internal index or -1 if creation fails.
      If <b>Static</b> is <b>False</b> the buffer will be optimized to store dynamic geometry. }
    function CreateVertexBuffer(Size: Integer; Static: Boolean): Integer; override;
    { Creates an index buffer with the given size in bytes and returns its internal index or -1 if creation fails
      If <b>Static</b> is <b>False</b> the buffer will be optimized to store dynamic data. }
    function CreateIndexBuffer(Size: Integer; Static: Boolean): Integer; override;
    // Changes size of the given vertex buffer to the given size and returns <b>True</b> if success
    function ResizeVertexBuffer(Index: Integer; NewSize: Integer): Boolean; override;
    // Changes size of the given index buffer to the given size and returns <b>True</b> if success
    function ResizeIndexBuffer(Index: Integer; NewSize: Integer): Boolean; override;
    { Locks the given range in a vertex buffer with the given index and returns a write-only pointer to the range data or <b>nil</b> if lock fails.
      If <b>DiscardExisting</b> is <b>True</b> existing data in the buffer will be discarded to avoid stalls. }
    function LockVertexBuffer(Index: Integer; Offset, Size: Integer; DiscardExisting: Boolean): Pointer; override;
    { Locks the given range in a index buffer with the given index and returns a write-only pointer to the range data or <b>nil</b> if lock fails.
      If <b>DiscardExisting</b> is <b>True</b> existing data in the buffer will be discarded to avoid stalls. }
    function LockIndexBuffer(Index: Integer; Offset, Size: Integer; DiscardExisting: Boolean): Pointer; override;
    // Unlocks a previously locked vertex buffer
    procedure UnlockVertexBuffer(Index: Integer); override;
    // Unlocks a previously locked index buffer
    procedure UnlockIndexBuffer(Index: Integer); override;
    // Attaches a vertex buffer to the specified data stream and returns <b>True</b> if success. <b>VertexSize</b> should match the size of the data in the buffer.
    function AttachVertexBuffer(Index, StreamIndex: Integer; VertexSize: Integer): Boolean; override;
    // Attaches an index buffer and returns <b>True</b> if success. <b>StartingVertex</b> will be added to all indices read from the index buffer.
    function AttachIndexBuffer(Index: Integer; StartingVertex: Integer): Boolean; override;
    // Frees all allocated buffers. All internal indices returned before this call become invalid.
    procedure Clear; override;
  end;

  TDX8Textures = class(C2Render.TTextures)
  private
    Direct3DDevice: IDirect3DDevice8;
//    APITextures: array of IDirect3DTexture8;
  protected  
    function APICreateTexture(Index: Integer): Boolean; override;
    procedure APIDeleteTexture(Index: Integer); override;
  public
    procedure Unload(Index: Integer); override;
    function Update(Index: Integer; Src: Pointer; Rect: BaseTypes.PRect3D): Boolean; override;
    function Read(Index: Integer; Dest: Pointer; Rect: BaseTypes.PRect3D): Boolean; override;
    procedure Apply(Stage, Index: Integer); override;
    function Lock(AIndex, AMipLevel: Integer; const ARect: BaseTypes.PRect; out LockRectData: TLockedRectData; LockFlags: TLockFlags): Boolean; override;
    procedure UnLock(AIndex, AMipLevel: Integer); override;
  end;

  TDX8StateWrapper = class(C2Render.TAPIStateWrapper)
  private
    Direct3DDevice: IDirect3DDevice8;
    CurrentRenderTarget, CurrentDepthStencil, MainRenderTarget, MainDepthStencil: IDirect3DSurface8;
    // Converts an FVF vertex format to a DX8 vertex declaration. Result should be allocated by caller
    procedure FVFToDeclaration(VertexFormat: Cardinal; var Result: PDX8VertexDeclaration);
    procedure DeclarationToAPI(Declaration: TVertexDeclaration; ConstantsData: Pointer; ConstantsSize: Integer; var Result: PDX8VertexDeclaration);
  protected
    function APICreateRenderTarget(Index, Width, Height: Integer; AColorFormat, ADepthFormat: Cardinal): Boolean; override;
    procedure DestroyRenderTarget(Index: Integer); override;

    // Calls an API to set a shader constant
    procedure APISetShaderConstant(const Constant: TShaderConstant); overload; override;
    // Calls an API to set a shader constant. <b>ShaderKind</b> - kind of shader, <b>ShaderRegister</b> - index of 4-component vector register to set, <b>Vector</b> - new value of the register.
    procedure APISetShaderConstant(ShaderKind: TShaderKind; ShaderRegister: Integer; const Vector: TShaderRegisterType); overload; override;
    // Destroys the specified by index vertex shader
    procedure APIDestroyVertexShader(Index: Integer); override;
    // Destroys the specified by index pixel shader
    procedure APIDestroyPixelShader(Index: Integer); override;

    function APIValidatePass(const Pass: TRenderPass; out ResultStr: string): Boolean; override;

    procedure ApplyTextureMatrices(const Pass: TRenderPass); override;

    procedure CleanUpNonManaged;
    procedure RestoreNonManaged;
    procedure ObtainRenderTargetSurfaces;
  public
    function SetRenderTarget(const Camera: TCamera; TextureTarget: Boolean): Boolean; override;

    function CreateVertexShader(Item: TShaderResource; Declaration: TVertexDeclaration): Integer; override;
    function CreatePixelShader(Item: TShaderResource): Integer; override;

    procedure SetFog(Kind: Cardinal; Color: BaseTypes.TColor; AFogStart, AFogEnd, ADensity: Single); override;
    procedure SetBlending(Enabled: Boolean; SrcBlend, DestBlend, AlphaRef, ATestFunc, Operation: Integer); override;
    procedure SetZBuffer(ZTestFunc, ZBias: Integer; ZWrite: Boolean); override;
    procedure SetCullAndFillMode(FillMode, ShadeMode, CullMode: Integer; ColorMask: Cardinal); override;
    procedure SetStencilState(SFailOp, ZFailOp, PassOp, STestFunc: Integer); override;
    procedure SetStencilValues(SRef, SMask, SWriteMask: Integer); override;
    procedure SetTextureWrap(const CoordSet: TTWrapCoordSet); override;
    procedure SetLighting(Enable: Boolean; AAmbient: BaseTypes.TColor; SpecularMode: Integer; NormalizeNormals: Boolean); override;
    procedure SetEdgePoint(PointSprite, PointScale, EdgeAntialias: Boolean); override;
    procedure SetTextureFactor(ATextureFactor: BaseTypes.TColor); override;
    procedure SetMaterial(const AAmbient, ADiffuse, ASpecular, AEmissive: BaseTypes.TColor4S; APower: Single); override;
    procedure SetPointValues(APointSize, AMinPointSize, AMaxPointSize, APointScaleA, APointScaleB, APointScaleC: Single); override;
    procedure SetLinePattern(ALinePattern: Longword); override;

    procedure SetClipPlane(Index: Cardinal; Plane: PPlane); override;

    procedure ApplyPass(const Pass: TRenderPass); override;
    procedure ApplyCustomTextureMatrices(const Pass: TRenderPass; Item: TVisible); override;
  end;

  TDX8Renderer = class(TRenderer)
  private
    MixedVPMode,
    LastFullScreen: Boolean;
    CurrentDeviceType: TD3DDevType;
    function FindDepthStencilFormat(iAdapter: Word; DeviceType: TD3DDEVTYPE; TargetFormat: TD3DFORMAT; var DepthStencilFormat: TD3DFORMAT) : Boolean;
    function FillPresentPars(var D3DPP: TD3DPresent_Parameters): Boolean;
    // Clean up non-managed resources
    procedure CleanUpNonManaged;
    // Restore non-managed resources after device restoration
    procedure RestoreNonManaged;

    // Converts a general vertex declaration to API-specific vartex declaration. Result should be allocated by caller
    procedure GetAPIDeclaration(Declaration: TVertexDeclaration; Result: PDX8VertexDeclaration);
  protected
    function APICheckFormat(const Format, Usage, RTFormat: Cardinal): Boolean; override;

    procedure APIPrepareFVFStates(Item: TVisible); override;

    procedure APIApplyCamera(Camera: TCamera); override;

    procedure InternalDeInit; override;
  public
    DXRenderTargetTexture: IDirect3DTexture8;

    Direct3D: IDirect3D8;
    Direct3DDevice: IDirect3DDevice8;
    Mat: TD3DMATERIAL8;
    constructor Create(Manager: TItemsManager); override;

    procedure SetDeviceType(DevType: Cardinal);
    procedure BuildModeList; override;

    procedure SetGamma(Gamma, Contrast, Brightness: Single); override;

    procedure CheckCaps; override;
    procedure CheckTextureFormats; override;

    function APICreateDevice(WindowHandle, AVideoMode: Cardinal; AFullScreen: Boolean): Boolean; override;
    function RestoreDevice(AVideoMode: Cardinal; AFullScreen: Boolean): Boolean; override;

    procedure StartFrame; override;
    procedure FinishFrame; override;

    procedure Clear(Flags: TClearFlagsSet; Color: BaseTypes.TColor; Z: Single; Stencil: Cardinal); override;

    procedure ApplyLight(Index: Integer; const ALight: TLight); override;

    procedure SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single); override;

    procedure APIRenderStrip(Tesselator: TTesselator; StripIndex: Integer); override;
    procedure APIRenderIndexedStrip(Tesselator: TTesselator; StripIndex: Integer); override;

    procedure RenderItemBox(Item: TProcessing; Color: BaseTypes.TColor); override;
    procedure RenderItemDebug(Item: TProcessing); override;
  end;

  function HResultToStr(Res: HResult): string;
  function FVFToVertexFormat(FVF: Cardinal): Cardinal;

implementation

function Failed(Res: HResult): Boolean;
begin
  Result := Res and HRESULT($80000000) <> 0;
end;

function FVFToVertexFormat(FVF: Cardinal): Cardinal;
var i, WeightsNum: Integer; TextureSets: array of Integer;
begin
  WeightsNum := 0;
  case FVF and D3DFVF_POSITION_MASK of
    D3DFVF_XYZ, D3DFVF_XYZRHW: ;
    D3DFVF_XYZB1: WeightsNum := 1;
    D3DFVF_XYZB2: WeightsNum := 2;
    D3DFVF_XYZB3: WeightsNum := 3;
    D3DFVF_XYZB4: WeightsNum := 4;
    D3DFVF_XYZB5: WeightsNum := 5;
  end;
  if FVF and D3DFVF_LASTBETA_UBYTE4 = D3DFVF_LASTBETA_UBYTE4 then
    WeightsNum := (WeightsNum - 1) or vwIndexedBlending;

  SetLength(TextureSets, (FVF and D3DFVF_TEXCOUNT_MASK) shr D3DFVF_TEXCOUNT_SHIFT);
  for i := 0 to High(TextureSets) do case FVF shr (i * 2 + 16) of
    D3DFVF_TEXTUREFORMAT1: TextureSets[i] := 1;
    D3DFVF_TEXTUREFORMAT2: TextureSets[i] := 2;
    D3DFVF_TEXTUREFORMAT3: TextureSets[i] := 3;
    D3DFVF_TEXTUREFORMAT4: TextureSets[i] := 4;
    else Assert(False, Format('%S: Invalid FVF: %D', ['FVFToVertexFormat', FVF]));
  end;

  Result := GetVertexFormat(FVF and D3DFVF_POSITION_MASK = D3DFVF_XYZRHW,
                            FVF and D3DFVF_NORMAL   = D3DFVF_NORMAL,
                            FVF and D3DFVF_DIFFUSE  = D3DFVF_DIFFUSE,
                            FVF and D3DFVF_SPECULAR = D3DFVF_SPECULAR,
                            FVF and D3DFVF_PSIZE    = D3DFVF_PSIZE, WeightsNum, TextureSets);
end;



function HResultToStr(Res: HResult): string;
begin
  {$IFDEF DX8ERRORSTR}
  Result := DXGetErrorString8(Res);
  {$ELSE}
  Result := 'DirectX error details are disabled';
  {$ENDIF}
end;

{ TDX8Buffers }

function TDX8Buffers.GetFVF(CastVertexFormat: Cardinal): Cardinal;
var i, TexCount, TextureBits: Integer;
begin
  Result := D3DFVF_XYZ;
  if CastVertexFormat and vfTRANSFORMED > 0 then
    Result := D3DFVF_XYZRHW
  else case GetVertexWeightsCount(CastVertexFormat) + Ord(GetVertexIndexedBlending(CastVertexFormat)) of
    0: Result := D3DFVF_XYZ;
    1: Result := D3DFVF_XYZB1;
    2: Result := D3DFVF_XYZB2;
    3: Result := D3DFVF_XYZB3;
    4: Result := D3DFVF_XYZB4;
    5: Result := D3DFVF_XYZB5;
    else Assert(False, Format('%S.%S: Invalid vertex format. Weight count = %D', [ClassName, 'GetFVF', (CastVertexFormat shr 28) and $F]));
  end;

  Result := Result or Cardinal(
            D3DFVF_NORMAL   * Ord(CastVertexFormat and vfNORMALS   > 0) or
            D3DFVF_DIFFUSE  * Ord(CastVertexFormat and vfDIFFUSE   > 0) or
            D3DFVF_SPECULAR * Ord(CastVertexFormat and vfSPECULAR  > 0) or
            D3DFVF_PSIZE    * Ord(CastVertexFormat and vfPOINTSIZE > 0));

//  Result := CVFormatsLow[CastVertexFormat and $FF];

  if GetVertexIndexedBlending(CastVertexFormat) then Result := Result or D3DFVF_LASTBETA_UBYTE4;

  TexCount := (CastVertexFormat shr 24) and $F;
  Result := Result or Cardinal(TexCount) shl D3DFVF_TEXCOUNT_SHIFT;
  TextureBits := (CastVertexFormat shr 8) and $FFFF;
  for i := 0 to TexCount-1 do case TextureBits shr (i*2) and 3 of
    0: Result := Result or D3DFVF_TEXTUREFORMAT1 shl (i * 2 + 16);
    1: Result := Result or D3DFVF_TEXTUREFORMAT2 shl (i * 2 + 16);
    2: Result := Result or D3DFVF_TEXTUREFORMAT3 shl (i * 2 + 16);
    3: Result := Result or D3DFVF_TEXTUREFORMAT4 shl (i * 2 + 16);
    else Assert(False, Format('%S.%S: Invalid vertex format. Number of texture sets = %D', [ClassName, 'GetFVF', TextureBits shr (i*2) and 3]));
  end;

//  if ((CastVertexFormat shr 16) and 255) > 0 then
//   Result := Result + ((CastVertexFormat shr 8) and 255);
end;

function TDX8Buffers.CreateVertexBuffer(Size: Integer; Static: Boolean): Integer;
var Res: HResult; D3DBuf: IDirect3DVertexBuffer8;
begin
  Result := -1;

  {$IFDEF DEBUGMODE}
  Log('TDX8Buffers.CreateVertexBuffer: Creating a vertex buffer', lkDebug);
  {$ENDIF}
  Res := (Renderer as TDX8Renderer).Direct3DDevice.CreateVertexBuffer(Size, BufferUsage[Static], 0, BufferPool[(Renderer as TDX8Renderer).MixedVPMode], D3DBuf);
  if Failed(Res) then begin
    Log('TDX8Buffers.CreateVertexBuffer: Error creating vertex buffer. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Exit;
  end;

  SetLength(VertexBuffers, Length(VertexBuffers)+1);
  Result := High(VertexBuffers);
  VertexBuffers[Result].BufferSize := Size;
  VertexBuffers[Result].Buffer     := D3DBuf;
  VertexBuffers[Result].Static     := Static;
end;

function TDX8Buffers.CreateIndexBuffer(Size: Integer; Static: Boolean): Integer;
var Res: HResult; D3DBuf: IDirect3DIndexBuffer8;
begin
  Result := -1;

  {$IFDEF DEBUGMODE}
  Log('TDX8Buffers.CreateIndexBuffer: Creating an index buffer', lkDebug);
  {$ENDIF}                                              
  Res := (Renderer as TDX8Renderer).Direct3DDevice.CreateIndexBuffer(Size, BufferUsage[Static], D3DFMT_INDEX16, BufferPool[(Renderer as TDX8Renderer).MixedVPMode], D3DBuf);
  if Failed(Res) then begin
    Log('TDX8Buffers.CreateIndexBuffer: Error creating index buffer. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Exit;
  end;

  SetLength(IndexBuffers, Length(IndexBuffers)+1);
  Result := High(IndexBuffers);
  IndexBuffers[Result].BufferSize := Size;
  IndexBuffers[Result].Buffer     := D3DBuf;
  IndexBuffers[Result].Static     := Static;
end;

function TDX8Buffers.ResizeVertexBuffer(Index, NewSize: Integer): Boolean;
var Res: HResult; D3DBuf: IDirect3DVertexBuffer8;
begin
  Assert((Index >= 0) and (Index <= High(VertexBuffers)), 'TDX8Buffers.ResizeVertexBuffer: Invalid bufer index');
  Result := False;

  Res := (Renderer as TDX8Renderer).Direct3DDevice.CreateVertexBuffer(NewSize, BufferUsage[VertexBuffers[Index].Static], 0, BufferPool[(Renderer as TDX8Renderer).MixedVPMode], D3DBuf);
  if Failed(Res) then begin
    Log('TDX8Buffers.ResizeVertexBuffer: Error resizing vertex buffer. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Exit;
  end;

  VertexBuffers[Index].Buffer     := nil;
  VertexBuffers[Index].Buffer     := D3DBuf;
  VertexBuffers[Index].BufferSize := NewSize;

  Result := True;
end;

function TDX8Buffers.ResizeIndexBuffer(Index, NewSize: Integer): Boolean;
var Res: HResult; D3DBuf: IDirect3DIndexBuffer8;
begin
  Assert((Index >= 0) and (Index <= High(IndexBuffers)), 'TDX8Buffers.ResizeIndexBuffer: Invalid bufer index');
  Result := False;

  Res := (Renderer as TDX8Renderer).Direct3DDevice.CreateIndexBuffer(NewSize, BufferUsage[IndexBuffers[Index].Static], D3DFMT_INDEX16, BufferPool[(Renderer as TDX8Renderer).MixedVPMode], D3DBuf);
  if Failed(Res) then begin
    Log('TDX8Buffers.ResizeIndexBuffer: Error resizing Index buffer. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Exit;
  end;

  IndexBuffers[Index].Buffer     := nil;
  IndexBuffers[Index].Buffer     := D3DBuf;
  IndexBuffers[Index].BufferSize := NewSize;

  Result := True;
end;

function TDX8Buffers.LockVertexBuffer(Index, Offset, Size: Integer; DiscardExisting: Boolean): Pointer;
var Res: HResult; Data: PByte;
begin
  Assert((Index >= 0) and (Index <= High(VertexBuffers)), 'TDX8Buffers.LockVertexBuffer: Invalid bufer index');
  Result := nil;
  Res := VertexBuffers[Index].Buffer.Lock(Offset, Size, Data, BufferLockFlags[VertexBuffers[Index].Static, DiscardExisting]);
  if Failed(Res) then begin
    Log('TDX8Buffers.LockVertexBuffer: Error locking vertex buffer. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Exit;
  end;
  Result := Data;
end;

function TDX8Buffers.LockIndexBuffer(Index, Offset, Size: Integer; DiscardExisting: Boolean): Pointer;
var Res: HResult; Data: PByte;
begin
  Assert((Index >= 0) and (Index <= High(IndexBuffers)), 'TDX8Buffers.LockIndexBuffer: Invalid bufer index');
  Result := nil;
  Res := IndexBuffers[Index].Buffer.Lock(Offset, Size, Data, BufferLockFlags[IndexBuffers[Index].Static, DiscardExisting]);
  if Failed(Res) then begin
    Log('TDX8Buffers.LockIndexBuffer: Error locking index buffer. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Exit;
  end;
  Result := Data;
end;

procedure TDX8Buffers.UnlockVertexBuffer(Index: Integer);
begin
  Assert((Index >= 0) and (Index <= High(VertexBuffers)), 'TDX8Buffers.UnlockVertexBuffer: Invalid bufer index');
  VertexBuffers[Index].Buffer.UnLock;
end;

procedure TDX8Buffers.UnlockIndexBuffer(Index: Integer);
begin
  Assert((Index >= 0) and (Index <= High(IndexBuffers)), 'TDX8Buffers.UnlockIndexBuffer: Invalid bufer index');
  IndexBuffers[Index].Buffer.UnLock;
end;

function TDX8Buffers.AttachVertexBuffer(Index, StreamIndex, VertexSize: Integer): Boolean;
var Res: HResult;
begin
  Result := False;
  Assert((Index >= 0) and (Index <= High(VertexBuffers)), 'TDX8Buffers.AttachVertexBuffer: Invalid bufer index');
  Res := TDX8Renderer(Renderer).Direct3DDevice.SetStreamSource(StreamIndex, VertexBuffers[Index].Buffer, VertexSize);
  if Failed(Res) then begin
    Log('TDX8Buffers.AttachVertexBuffer: Error attaching vertex buffer. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Exit;
  end;
  Result := True;
end;

function TDX8Buffers.AttachIndexBuffer(Index, StartingVertex: Integer): Boolean;
var Res: HResult;
begin
  Result := False;
  Assert((Index >= 0) and (Index <= High(IndexBuffers)), 'TDX8Buffers.AttachIndexBuffer: Invalid bufer index');
  Res := TDX8Renderer(Renderer).Direct3DDevice.SetIndices(IndexBuffers[Index].Buffer, StartingVertex);
  if Failed(Res) then begin
    Log('TDX8Buffers.AttachIndexBuffer: Error attaching vertex buffer. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Exit;
  end;
  Result := True;
end;

procedure TDX8Buffers.Clear;
var i: Integer;
begin
//  Assert(False, 'Are buffers released?');
  for i := 0 to High(VertexBuffers) do VertexBuffers[i].Buffer := nil;
  for i := 0 to High(IndexBuffers)  do IndexBuffers[i].Buffer  := nil;
  VertexBuffers := nil;
  IndexBuffers  := nil;
end;

{ TDX8StateWrapper }

function TDX8StateWrapper.APICreateRenderTarget(Index, Width, Height: Integer; AColorFormat, ADepthFormat: Cardinal): Boolean;
var Res: HResult;
begin
  Result := False;
  // Free texture and its surface
  if Assigned(FRenderTargets[Index].ColorBuffer)  then IDirect3DSurface8(FRenderTargets[Index].ColorBuffer)  := nil;
  if Assigned(FRenderTargets[Index].ColorTexture) then IDirect3DTexture8(FRenderTargets[Index].ColorTexture) := nil;
  // Create texture
  Res := Direct3DDevice.CreateTexture(Width, Height, 1, D3DUSAGE_RENDERTARGET, TD3DFormat(PFormats[AColorFormat]), D3DPOOL_DEFAULT, IDirect3DTexture8(FRenderTargets[Index].ColorTexture));
  if Failed(Res) then begin
    
    Log(ClassName + '.APICreateRenderTarget: Error creating render target texture: Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    
    Exit;
  end;
  // Obtain surface
  Res := IDirect3DTexture8(FRenderTargets[Index].ColorTexture).GetSurfaceLevel(0, IDirect3DSurface8(FRenderTargets[Index].ColorBuffer));
  if Failed(Res) then begin
    
    Log(Format('Error obtaining surface of a render target texture of camera "%S". Error code: %D "%S"', [Camera.Name, Res, HResultToStr(Res)]), lkError);
    
    Exit;
  end;

  if ADepthFormat = pfUndefined then
    FRenderTargets[Index].DepthBuffer := nil else begin
      // Free depth texture and its surface
      if Assigned(FRenderTargets[Index].DepthBuffer)  then IDirect3DSurface8(FRenderTargets[Index].DepthBuffer)  := nil;
      if Assigned(FRenderTargets[Index].DepthTexture) then IDirect3DTexture8(FRenderTargets[Index].DepthTexture) := nil;

      Res := Direct3DDevice.CreateTexture(Width, Height, 1, D3DUSAGE_DEPTHSTENCIL, TD3DFormat(PFormats[ADepthFormat]), D3DPOOL_DEFAULT, IDirect3DTexture8(FRenderTargets[Index].DepthTexture));
      if Failed(Res) then begin
        Res:= Direct3DDevice.CreateDepthStencilSurface(Width, Height, TD3DFormat(PFormats[ADepthFormat]), D3DMULTISAMPLE_NONE, IDirect3DSurface8(FRenderTargets[Index].DepthBuffer));
        if Failed(Res) then begin
          
          Log(Format('%S.APICreateRenderTarget: Error creating depth surface for render target of camera "%S". Error code: %D "%S"', [ClassName, Camera.Name, Res, HResultToStr(Res)]), lkError);
          
          Exit;
        end;
      end else begin
        Res := IDirect3DTexture8(FRenderTargets[Index].DepthTexture).GetSurfaceLevel(0, IDirect3DSurface8(FRenderTargets[Index].DepthBuffer));
        if Failed(Res) then begin
          
          Log(Format('Error obtaining surface of a depth surface for render target of camera "%S". Error code: %D "%S"', [Camera.Name, Res, HResultToStr(Res)]), lkError);
          
          Exit;
        end;
      end;
    end;
  Result := True;
end;

procedure TDX8StateWrapper.DestroyRenderTarget(Index: Integer);
begin
  if Assigned(FRenderTargets[Index].ColorBuffer)  then IDirect3DSurface8(FRenderTargets[Index].ColorBuffer)._Release;
  if Assigned(FRenderTargets[Index].DepthBuffer)  then IDirect3DSurface8(FRenderTargets[Index].DepthBuffer)._Release;
  if Assigned(FRenderTargets[Index].ColorTexture) then IDirect3DTexture8(FRenderTargets[Index].ColorTexture)._Release;
  if Assigned(FRenderTargets[Index].DepthTexture) then IDirect3DTexture8(FRenderTargets[Index].DepthTexture)._Release;
  FRenderTargets[Index].ColorBuffer  := nil;
  FRenderTargets[Index].DepthBuffer  := nil;
  FRenderTargets[Index].ColorTexture := nil;
  FRenderTargets[Index].DepthTexture := nil;
  FRenderTargets[Index].LastUpdateFrame := -1;
  FRenderTargets[Index].IsDepthTexture:= False;
end;

function TDX8StateWrapper.SetRenderTarget(const Camera: TCamera; TextureTarget: Boolean): Boolean;
var Res: HResult;
begin
  Result := False;
  if TextureTarget then begin                                         // Render to texture
    if Camera.RenderTargetIndex <> -1 then begin
      FRenderTargets[Camera.RenderTargetIndex].LastUpdateFrame := Renderer.FramesRendered;

      CurrentRenderTarget := IDirect3DSurface8(FRenderTargets[Camera.RenderTargetIndex].ColorBuffer);
      CurrentDepthStencil := IDirect3DSurface8(FRenderTargets[Camera.RenderTargetIndex].DepthBuffer);

      Res := Direct3DDevice.SetRenderTarget(CurrentRenderTarget, CurrentDepthStencil);
      if Failed(Res) then begin
        
        Log(Format('Error setting render target to texture of camera "%S". Error code: %D "%S"', [Camera.Name, Res, HResultToStr(Res)]), lkError);
        
        CurrentDepthStencil := nil;
        Exit;
      end;
      
    end;
  end else begin
    Res := Direct3DDevice.SetRenderTarget(MainRenderTarget, MainDepthStencil);
    CurrentRenderTarget := MainRenderTarget;
    CurrentDepthStencil := MainDepthStencil;
    if Failed(Res) then begin
      
      Log('Error restoring render target. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
      
      Exit;
    end;
  end;
  Inc(FPerfProfile.RenderTargetChanges);
  Result := True;
end;

function TDX8StateWrapper.CreateVertexShader(Item: TShaderResource; Declaration: TVertexDeclaration): Integer;
var
  Res: HResult;
  {$IFDEF USED3DX8}
  Data, Constants: ID3DXBuffer;
  {$ENDIF}
  VDecl: PDX8VertexDeclaration; ConstsSize: Integer;
begin
  Result := inherited CreateVertexShader(Item, Declaration);
  {$IFDEF USED3DX8}
  if not Assigned(Item.Data) and (Item.Source <> '') then begin
    Data := nil;
    Constants := nil;
    Res := D3DXAssembleShader(Item.Source[1], Length(Item.Source), D3DXASM_SKIPVALIDATION*0, @Constants, @Data, nil);
    if Failed(Res) then begin
      Log('Error assembling vertex shader from resource "' + Item.Name + '". Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
      Result := -1;
      LastError := reVertexShaderAssembleFail;
      Exit;
    end;
    Assert(Assigned(Data));
    // Fill resource with compiled code and constants data
    Item.Allocate(Data.GetBufferSize + Constants.GetBufferSize);
    Move(Data.GetBufferPointer^, Item.Data^, Data.GetBufferSize);
    Move(Constants.GetBufferPointer^, PtrOffs(Item.Data, Data.GetBufferSize)^, Constants.GetBufferSize);
    Item.SetCodeSize(Data.GetBufferSize);
  end;
  {$ENDIF}

  ConstsSize := (Item.DataSize - Item.CodeSize) * Ord(Assigned(Item.Data) and (Item.CodeSize <> 0));

  GetMem(VDecl, (Length(Declaration)+2) * SizeOf(Cardinal) + ConstsSize);
  DeclarationToAPI(Declaration, Pointer(Integer(Item.Data) + Item.CodeSize), ConstsSize, VDecl);

  Res := Direct3DDevice.CreateVertexShader(Pointer(VDecl), Item.Data, Cardinal(FVertexShaders[Result].Shader), D3DUSAGE_SOFTWAREPROCESSING * Ord(TDX8Renderer(Renderer).MixedVPMode));

  FreeMem(VDecl);

  if Failed(Res) then begin
    
    Log('Error creating vertex shader from resource "' + Item.Name + '". Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    
    Result := -1;
    LastError := reVertexShaderCreateFail;
    Exit;
  end;
end;

function TDX8StateWrapper.CreatePixelShader(Item: TShaderResource): Integer;
var Res: HResult; {$IFDEF USED3DX8} Data: ID3DXBuffer; {$ENDIF}
begin
  Result := inherited CreatePixelShader(Item);
  {$IFDEF USED3DX8}
  if not Assigned(Item.Data) and (Item.Source <> '') then begin
    Data := nil;
    Res := D3DXAssembleShader(Item.Source[1], Length(Item.Source), D3DXASM_SKIPVALIDATION*0, nil, @Data, nil);
//    Res := D3DXAssembleShaderFromFileA(PChar(Item.Source), D3DXASM_SKIPVALIDATION , nil, @Data, nil);
    if Failed(Res) then begin
      Log('Error assembling pixel shader from resource "' + Item.Name + '". Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
      Result := -1;
      LastError := rePixelShaderAssembleFail;
      Exit;
    end;
    Assert(Assigned(Data));
    Item.Allocate(Data.GetBufferSize);
    Move(Data.GetBufferPointer^, Item.Data^, Item.DataSize);
  end;
  {$ENDIF}
  Res := Direct3DDevice.CreatePixelShader(Item.Data, Cardinal(FPixelShaders[Result].Shader));
  if Failed(Res) then begin
    
    Log('Error creating pixel shader from resource "' + Item.Name + '". Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    
    Result := -1;
    LastError := rePixelShaderCreateFail;
    Exit;
  end;
end;

procedure TDX8StateWrapper.SetFog(Kind: Cardinal; Color: BaseTypes.TColor; AFogStart, AFogEnd, ADensity: Single);
begin
  if Kind <> fkNone then begin
    Direct3DDevice.SetRenderState(D3DRS_FOGENABLE, Ord(True));
    Direct3DDevice.SetRenderState(D3DRS_FOGCOLOR,  Color.C);
    case Kind of
      fkVertex: begin
        Direct3DDevice.SetRenderState(D3DRS_FOGVERTEXMODE,   D3DFOG_LINEAR);
        Direct3DDevice.SetRenderState(D3DRS_RANGEFOGENABLE , 0);
        Direct3DDevice.SetRenderState(D3DRS_FOGTABLEMODE,    D3DFOG_NONE);
      end;
      fkVertexRanged: begin
        Direct3DDevice.SetRenderState(D3DRS_RANGEFOGENABLE , 1);
        Direct3DDevice.SetRenderState(D3DRS_FOGVERTEXMODE,   D3DFOG_LINEAR);
        Direct3DDevice.SetRenderState(D3DRS_FOGTABLEMODE,    D3DFOG_NONE);
      end;
      fkTableLinear: begin
        Direct3DDevice.SetRenderState(D3DRS_FOGTABLEMODE,    D3DFOG_LINEAR);
        Direct3DDevice.SetRenderState(D3DRS_RANGEFOGENABLE , 0);
        Direct3DDevice.SetRenderState(D3DRS_FOGVERTEXMODE,   D3DFOG_NONE);
      end;
      fkTABLEEXP: begin
        Direct3DDevice.SetRenderState(D3DRS_FOGTABLEMODE,    D3DFOG_EXP);
        Direct3DDevice.SetRenderState(D3DRS_FOGDENSITY,      Cardinal((@ADensity)^));
        Direct3DDevice.SetRenderState(D3DRS_RANGEFOGENABLE , 0);
        Direct3DDevice.SetRenderState(D3DRS_FOGVERTEXMODE,   D3DFOG_NONE);
      end;
      fkTABLEEXP2: begin
        Direct3DDevice.SetRenderState(D3DRS_FOGTABLEMODE,    D3DFOG_EXP2);
        Direct3DDevice.SetRenderState(D3DRS_FOGDENSITY,      Cardinal((@ADensity)^));
        Direct3DDevice.SetRenderState(D3DRS_RANGEFOGENABLE , 0);
        Direct3DDevice.SetRenderState(D3DRS_FOGVERTEXMODE,   D3DFOG_NONE);
      end;
    end;
    Direct3DDevice.SetRenderState(D3DRS_FOGSTART, Cardinal((@AFogStart)^));
    Direct3DDevice.SetRenderState(D3DRS_FOGEND,   Cardinal((@AFogEnd)^));
  end else Direct3DDevice.SetRenderState(D3DRS_FOGENABLE, Ord(False));
end;

procedure TDX8StateWrapper.SetBlending(Enabled: Boolean; SrcBlend, DestBlend, AlphaRef, ATestFunc, Operation: Integer);
begin
  if Enabled then begin
    Direct3DDevice.SetRenderState(D3DRS_ALPHABLENDENABLE, 1);
    Direct3DDevice.SetRenderState(D3DRS_SRCBLEND,         BlendModes[SrcBlend]);
    Direct3DDevice.SetRenderState(D3DRS_DESTBLEND,        BlendModes[DestBlend]);
    Direct3DDevice.SetRenderState(D3DRS_BLENDOP,          BlendOps[Operation]);
  end else Direct3DDevice.SetRenderState(D3DRS_ALPHABLENDENABLE, 0);
  Direct3DDevice.SetRenderState(D3DRS_ALPHATESTENABLE, Ord(ATestFunc <> tfAlways));
  Direct3DDevice.SetRenderState(D3DRS_ALPHAFUNC,       TestFuncs[ATestFunc]);
  Direct3DDevice.SetRenderState(D3DRS_ALPHAREF,        AlphaRef);
end;

procedure TDX8StateWrapper.SetZBuffer(ZTestFunc, ZBias: Integer; ZWrite: Boolean);
begin
//  Direct3DDevice.SetRenderState(D3DRS_ZE-NABLE, );
  Direct3DDevice.SetRenderState(D3DRS_ZFUNC,        TestFuncs[ZTestFunc]);
  Direct3DDevice.SetRenderState(D3DRS_ZBIAS,        ZBias);
  Direct3DDevice.SetRenderState(D3DRS_ZWRITEENABLE, Ord(ZWrite));
end;

procedure TDX8StateWrapper.SetCullAndFillMode(FillMode, ShadeMode, CullMode: Integer; ColorMask: Cardinal);
begin
  if FillMode <> fmDEFAULT then
    Direct3DDevice.SetRenderState(D3DRS_FILLMODE, FillModes[FillMode]) else if Camera <> nil then
      Direct3DDevice.SetRenderState(D3DRS_FILLMODE, FillModes[Camera.DefaultFillMode]);
  Direct3DDevice.SetRenderState(D3DRS_SHADEMODE, ShadeModes[ShadeMode]);
  case CullMode of
    cmCAMERADEFAULT: if Camera <> nil then Direct3DDevice.SetRenderState(D3DRS_CULLMODE, CullModes[Camera.DefaultCullMode]);
    cmCAMERAINVERSE: if Camera <> nil then begin
      if Camera.DefaultCullMode = cmCCW then
       Direct3DDevice.SetRenderState(D3DRS_CULLMODE, D3DCULL_CW) else
        if Camera.DefaultCullMode = cmCW then Direct3DDevice.SetRenderState(D3DRS_CULLMODE, D3DCULL_CCW) else
         Direct3DDevice.SetRenderState(D3DRS_CULLMODE, D3DCULL_NONE);
    end;
    else Direct3DDevice.SetRenderState(D3DRS_CULLMODE, CullModes[CullMode]);
  end;
  ColorMask := Ord(ColorMask and $FF > 0) or Ord(ColorMask and $FF00 > 0) shl 1 or Ord(ColorMask and $FF0000 > 0) shl 2 or Ord(ColorMask and $FF000000 > 0)  shl 3;
  Direct3DDevice.SetRenderState(D3DRS_COLORWRITEENABLE, ColorMask);
end;

procedure TDX8StateWrapper.SetStencilState(SFailOp, ZFailOp, PassOp, STestFunc: Integer);
begin
// Disable stencil if Func = Always and ZFail = PassOP = Keep
  if (ZFailOp = soKeep) and (PassOp = soKeep) and (STestFunc <> tfAlways) then
   Direct3DDevice.SetRenderState(D3DRS_STENCILENABLE, 0) else begin
     Direct3DDevice.SetRenderState(D3DRS_STENCILENABLE, 1);
     Direct3DDevice.SetRenderState(D3DRS_STENCILFUNC,   TestFuncs[STestFunc]);
     Direct3DDevice.SetRenderState(D3DRS_STENCILFAIL,   StencilOps[SFailOp]);
     Direct3DDevice.SetRenderState(D3DRS_STENCILZFAIL,  StencilOps[ZFailOp]);
     Direct3DDevice.SetRenderState(D3DRS_STENCILPASS,   StencilOps[PassOp]);
   end;
end;

procedure TDX8StateWrapper.SetStencilValues(SRef, SMask, SWriteMask: Integer);
begin
  Direct3DDevice.SetRenderState(D3DRS_STENCILREF,       Cardinal(SRef));
  Direct3DDevice.SetRenderState(D3DRS_STENCILMASK,      Cardinal(SMask));
  Direct3DDevice.SetRenderState(D3DRS_STENCILWRITEMASK, Cardinal(SWriteMask));
end;

procedure TDX8StateWrapper.SetTextureWrap(const CoordSet: TTWrapCoordSet);
const D3DRS_WRAP: array[0..7] of TD3DRenderStateType = (D3DRS_WRAP0, D3DRS_WRAP1, D3DRS_WRAP2, D3DRS_WRAP3, D3DRS_WRAP4, D3DRS_WRAP5, D3DRS_WRAP6, D3DRS_WRAP7);
var i: Integer;
begin
  for i := 0 to 7 do
    Direct3DDevice.SetRenderState(D3DRS_WRAP[i], D3DWRAPCOORD_0 * Ord(CoordSet[i] and twUCoord  > 0) or
                                                 D3DWRAPCOORD_1 * Ord(CoordSet[i] and twVCoord  > 0) or
                                                 D3DWRAPCOORD_2 * Ord(CoordSet[i] and twWCoord  > 0) or
                                                 D3DWRAPCOORD_3 * Ord(CoordSet[i] and twW2Coord > 0));
end;

procedure TDX8StateWrapper.SetLighting(Enable: Boolean; AAmbient: BaseTypes.TColor; SpecularMode: Integer; NormalizeNormals: Boolean);
begin
  Direct3dDevice.SetRenderState(D3DRS_SPECULARENABLE,   Ord(SpecularMode <> slNone));
  Direct3dDevice.SetRenderState(D3DRS_LOCALVIEWER,      Ord(SpecularMode = slAccurate));
  Direct3DDevice.SetRenderState(D3DRS_NORMALIZENORMALS, Ord(NormalizeNormals));
  Direct3DDevice.SetRenderState(D3DRS_LIGHTING,         Ord(Enable));
  Direct3DDevice.SetRenderState(D3DRS_AMBIENT,          AAmbient.C);
end;

procedure TDX8StateWrapper.SetEdgePoint(PointSprite, PointScale, EdgeAntialias: Boolean);
begin
  Direct3dDevice.SetRenderState(D3DRS_POINTSPRITEENABLE, Ord(PointSprite));
  Direct3DDevice.SetRenderState(D3DRS_POINTSCALEENABLE,  Ord(PointScale));
  Direct3DDevice.SetRenderState(D3DRS_EDGEANTIALIAS,     Ord(EdgeAntialias));
end;

procedure TDX8StateWrapper.SetTextureFactor(ATextureFactor: BaseTypes.TColor);
begin
  Direct3DDevice.SetRenderState(D3DRS_TEXTUREFACTOR, ATextureFactor.C);
end;

procedure TDX8StateWrapper.SetMaterial(const AAmbient, ADiffuse, ASpecular, AEmissive: BaseTypes.TColor4S; APower: Single);
var Mat: TD3DMATERIAL8; Res: HResult;
begin
  Mat.Ambient  := TD3DColorValue(AAmbient);
  Mat.Diffuse  := TD3DColorValue(ADiffuse);
  Mat.Specular := TD3DColorValue(ASpecular);
  Mat.Emissive := TD3DColorValue(AEmissive);
  Mat.Power    := APower;
  Res := Direct3DDevice.SetMaterial(Mat);
  if Failed(Res) then Log('***Error', lkError);
end;

procedure TDX8StateWrapper.SetPointValues(APointSize, AMinPointSize, AMaxPointSize, APointScaleA, APointScaleB, APointScaleC: Single);
begin
//  AMaxPointSize := MinS(AMaxPointSize, Renderer.MaxPointSize);
  AMinPointSize := MinS(AMinPointSize, AMaxPointSize);
  APointSize := MinS(MaxS(APointSIze, AMinPointSize), AMaxPointSize);
  Direct3DDevice.SetRenderState(D3DRS_POINTSIZE,     Cardinal((@APointSize)^));
  Direct3DDevice.SetRenderState(D3DRS_POINTSIZE_MIN, Cardinal((@AMinPointSize)^));
  Direct3DDevice.SetRenderState(D3DRS_POINTSIZE_MAX, Cardinal((@AMaxPointSize)^));
  Direct3DDevice.SetRenderState(D3DRS_POINTSCALE_A,  Cardinal((@APointScaleA)^));
  Direct3DDevice.SetRenderState(D3DRS_POINTSCALE_B,  Cardinal((@APointScaleB)^));
  Direct3DDevice.SetRenderState(D3DRS_POINTSCALE_C,  Cardinal((@APointScaleC)^));
end;

procedure TDX8StateWrapper.SetLinePattern(ALinePattern: Longword);
begin
  Direct3DDevice.SetRenderState(D3DRS_LINEPATTERN, ALinePattern);
end;

procedure TDX8StateWrapper.SetClipPlane(Index: Cardinal; Plane: PPlane);
var Res: HResult;
begin
  ClipPlanesState := ClipPlanesState and not (1 shl Index) or Cardinal(Ord(Assigned(Plane)) shl Index);
  Direct3DDevice.SetRenderState(D3DRS_CLIPPLANEENABLE, ClipPlanesState);
  if Assigned(Plane) then begin
    Res := Direct3DDevice.SetClipPlane(Index, PSingle(Plane));
    {$IFDEF DEBUGMODE}
    if Failed(Res) then
      Log('Error setting clip plane. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    {$ENDIF} 
  end;
end;

procedure TDX8StateWrapper.ApplyPass(const Pass: TRenderPass);
var i, TexCount: Integer; Stage: ^TStage; Res: HResult;
begin
  Assert(Assigned(Pass), ClassName + '.ApplyPass: Invalid pass');

  if (Pass.VertexShaderIndex <> sivNull) then begin                                // Try to resolve vertex shader
    if Pass.VertexShaderIndex = sivUnresolved then ResolveVertexShader(Pass);
    VertexShaderFlag := Pass.VertexShaderIndex <> sivUnresolved;
  end else VertexShaderFlag := False;

  if TDX8Renderer(Renderer).MixedVPMode then TDX8Renderer(Renderer).Direct3dDevice.SetRenderState(D3DRS_SOFTWAREVERTEXPROCESSING, Ord(VertexShaderFlag));

  SetFog(Pass.FogKind, Pass.FogColor, Pass.FogStart, Pass.FogEnd, Pass.FogDensity);
//  SetPointValues(Pass.PointSize, Pass.MinPointSize, Pass.MaxPointSize, Pass.PointScaleA, Pass.PointScaleB, Pass.PointScaleC);
//  SetLinePattern(Pass.LinePattern);
  SetBlending(Pass.BlendingState.Enabled, Pass.BlendingState.SrcBlend, Pass.BlendingState.DestBlend, Pass.BlendingState.AlphaRef, Pass.BlendingState.ATestFunc, Pass.BlendingState.Operation);
  SetZBuffer(Pass.ZBufferState.ZTestFunc, Pass.ZBufferState.ZBias, Pass.ZBufferState.ZWrite);
  SetCullAndFillMode(Pass.FillShadeMode.FillMode, Pass.FillShadeMode.ShadeMode, Pass.FillShadeMode.CullMode, Pass.FillShadeMode.ColorMask);
  SetStencilState(Pass.StencilState.SFailOp, Pass.StencilState.ZFailOp, Pass.StencilState.PassOp, Pass.StencilState.STestFunc);
  SetStencilValues(Pass.StencilRef, Pass.StencilMask, Pass.StencilWriteMask);
  SetTextureWrap(Pass.TextureWrap.CoordSet);
  SetLighting(Pass.LightingState.Enabled, Pass.LightingState.GlobalAmbient, Pass.LightingState.SpecularMode, Pass.LightingState.NormalizeNormals);
  SetEdgePoint(Pass.PointEdgeState.PointSprite, Pass.PointEdgeState.PointScale, Pass.PointEdgeState.EdgeAntialias);
  SetTextureFactor(Pass.TextureFactor);
  ApplyTextureMatrices(Pass);
  SetMaterial(Pass.Ambient, Pass.Diffuse, Pass.Specular, Pass.Emissive, Pass.Power);

  if VertexShaderFlag then begin
    Res := Direct3DDevice.SetVertexShader(Cardinal(FVertexShaders[Pass.VertexShaderIndex].Shader));
    {$IFDEF DEBUGMODE} if Res <> D3D_OK then begin Log('TDX8StateWrapper.ApplyPass: Error setting vertex shader: ' +  HResultToStr(Res), lkError); end; {$ENDIF}
  end;  

  if (Pass.PixelShaderIndex <> sivNull) then begin                                 // Try to resolve pixel shader
    if Pass.PixelShaderIndex = sivUnresolved then ResolvePixelShader(Pass);
    PixelShaderFlag := Pass.PixelShaderIndex <> sivUnresolved;
  end else PixelShaderFlag := False;

  if PixelShaderFlag then
    Res := Direct3DDevice.SetPixelShader(Cardinal(FPixelShaders[Pass.PixelShaderIndex].Shader)) else
      Res := Direct3DDevice.SetPixelShader(0);

  {$IFDEF DEBUGMODE} if Res <> D3D_OK then begin Log('TDX8StateWrapper.ApplyPass: Error setting pixel shader: ' +  HResultToStr(Res), lkError); end; {$ENDIF}

  if (LastError = reNone) and (Pass.TotalStages > Renderer.MaxTextureStages) then LastError := reTooManyStages;

  TexCount := 0;

  for i := 0 to MinI(Pass.TotalStages-1, Renderer.MaxTextureStages-1) do begin
    Stage := @Pass.Stages[i];
//    Assert(Stage.TextureIndex <> -1, ClassName + '.ApplyPass: ');

    if (Stage.TextureIndex <> tivNull) and
//      ((Stage.TextureIndex <> tivRenderTarget) or (Stage.Camera.RenderTargetIndex <> -1)) and
      ((Stage.TextureIndex <> tivUnresolved) or Renderer.Textures.Resolve(Pass, i)) then begin
      if (Stage.TextureIndex <> tivRenderTarget) then begin
        {$IFDEF DEBUGMODE} Res := D3D_OK; {$ENDIF}
        Renderer.Textures.Apply(i, Stage.TextureIndex);
        Inc(TexCount);
      end else begin
        if Stage.Camera.IsDepthTexture and not Renderer.DepthTextures then begin
          LastError := reNoDepthTextures;
        end else if Stage.Camera.RenderTargetIndex <> -1 then begin
          if Stage.Camera.IsDepthTexture then
            Res := Direct3DDevice.SetTexture(i, IDirect3DTexture8(FRenderTargets[Stage.Camera.RenderTargetIndex].DepthTexture))
          else
            Res := Direct3DDevice.SetTexture(i, IDirect3DTexture8(FRenderTargets[Stage.Camera.RenderTargetIndex].ColorTexture));
        end else
          Res := Direct3DDevice.SetTexture(i, nil);
      end;
      
      {$IFDEF DEBUGMODE} if Res <> D3D_OK then begin Log('TDX8StateWrapper.ApplyPass: Error setting texture: ' +  HResultToStr(Res), lkError); end; {$ENDIF}

      Direct3DDevice.SetTextureStageState(i, D3DTSS_ADDRESSU, TexAddressing[Stage.TAddressing and $00F]);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_ADDRESSV, TexAddressing[(Stage.TAddressing shr 4) and $00F]);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_ADDRESSW, TexAddressing[(Stage.TAddressing shr 8) and $00F]);

      Direct3DDevice.SetTextureStageState(i, D3DTSS_MINFILTER, TexFilters[Stage.Filtering and $00F]);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_MAGFILTER, TexFilters[(Stage.Filtering shr 4) and $00F]);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_MIPFILTER, TexFilters[(Stage.Filtering shr 8) and $00F]);

      Direct3DDevice.SetTextureStageState(i, D3DTSS_BORDERCOLOR, Stage.TextureBorder.C);

      if VertexShaderFlag then
        Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXCOORDINDEX, i)
      else
        Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXCOORDINDEX, Stage.UVSource and $0F or TexCoordSources[Stage.UVSource shr 4]);

      Direct3DDevice.SetTextureStageState(i, D3DTSS_MIPMAPLODBIAS, Stage.MaxMipLevel);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_MAXMIPLEVEL,   Stage.MaxMipLevel);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_MAXANISOTROPY, Stage.MaxAnisotropy);
    end else Direct3DDevice.SetTexture(i, nil);

    if Pass.PixelShaderIndex < 0 then begin
      Direct3DDevice.SetTextureStageState(i, D3DTSS_COLOROP,   TexOperation[Stage.ColorOp]);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_COLORARG1, TexArgument[Stage.ColorArg1] or Cardinal(D3DTA_COMPLEMENT * Ord(Stage.InvertColorArg1)));
      Direct3DDevice.SetTextureStageState(i, D3DTSS_COLORARG2, TexArgument[Stage.ColorArg2] or Cardinal(D3DTA_COMPLEMENT * Ord(Stage.InvertColorArg2)));
      Direct3DDevice.SetTextureStageState(i, D3DTSS_ALPHAOP,   TexOperation[Stage.AlphaOp]);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_AlphaARG1, TexArgument[Stage.AlphaArg1] or Cardinal(D3DTA_COMPLEMENT * Ord(Stage.InvertAlphaArg1)));
      Direct3DDevice.SetTextureStageState(i, D3DTSS_AlphaARG2, TexArgument[Stage.AlphaArg2] or Cardinal(D3DTA_COMPLEMENT * Ord(Stage.InvertAlphaArg2)));

      if Stage.StoreToTemp then
        Direct3DDevice.SetTextureStageState(i, D3DTSS_RESULTARG, D3DTA_TEMP)
      else
        Direct3DDevice.SetTextureStageState(i, D3DTSS_RESULTARG, D3DTA_CURRENT);
    end;
  end;

  if (LastError = reNone) and (TexCount > Renderer.MaxTexturesPerPass) then LastError := reTooManyTextures;

  if (Pass.TotalStages < Integer(Renderer.MaxTextureStages)) then begin
    if (Pass.PixelShaderIndex < 0) then begin
      Direct3DDevice.SetTexture(Pass.TotalStages, nil);
      Direct3DDevice.SetTextureStageState(Pass.TotalStages, D3DTSS_COLOROP, TexOperation[toDisable]);
      Direct3DDevice.SetTextureStageState(Pass.TotalStages, D3DTSS_ALPHAOP, TexOperation[toDisable]);
    end;
    Direct3DDevice.SetTextureStageState(Pass.TotalStages, D3DTSS_TEXCOORDINDEX, Pass.TotalStages);
    Direct3DDevice.SetTextureStageState(Pass.TotalStages, D3DTSS_TEXTURETRANSFORMFLAGS, D3DTTFF_DISABLE);
  end;
  ApplyClipPlanes;
end;

const D3DTS_TEXTURE: array[0..7] of TD3DTransformStateType =
      (D3DTS_TEXTURE0, D3DTS_TEXTURE1, D3DTS_TEXTURE2, D3DTS_TEXTURE3,
       D3DTS_TEXTURE4, D3DTS_TEXTURE5, D3DTS_TEXTURE6, D3DTS_TEXTURE7);

procedure TDX8StateWrapper.ApplyTextureMatrices(const Pass: TRenderPass);
var i: Integer; Mat: TMatrix4s;
begin
  for i := 0 to MinI(Pass.TotalStages-1, Renderer.MaxTextureStages-1) do begin
        case Pass.Stages[i].TextureMatrixType of
          tmNone: if VertexShaderFlag then begin
              if StageMatrixSet[i] then begin
                Direct3DDevice.SetTransform(D3DTS_TEXTURE[i], TD3DMatrix(IdentityMatrix4s));
                StageMatrixSet[i] := False;
              end;
            end else begin
              if StageMatrixSet[i] then begin
                Direct3DDevice.SetTransform(D3DTS_TEXTURE[i], TD3DMatrix(IdentityMatrix4s));
                StageMatrixSet[i] := False;
              end;
              Mat := IdentityMatrix4s;
            end;
          tmCameraInverse: if Assigned(Renderer.LastAppliedCamera) then begin
              MulMatrix4s(Mat, InvertAffineMatrix4s(Renderer.LastAppliedCamera.ViewMatrix),
                               ScaleMatrix4s(Pass.Stages[i].TextureMatrixBias, Pass.Stages[i].TextureMatrixBias, Pass.Stages[i].TextureMatrixBias));
              StageMatrixSet[i] := True;
            end;
          tmMirror: begin
            Mat := IdentityMatrix4s;
            if Assigned(Renderer.LastAppliedCamera) then
              Mat := MulMatrix4s(Mat, InvertAffineMatrix4s(Renderer.LastAppliedCamera.ViewMatrix));

            if Assigned(Pass.Stages[i].Camera) then begin
              Mat := MulMatrix4s(Mat, Pass.Stages[i].Camera.TotalMatrix);
            end;

            Renderer.BiasMat._41 := 0.5;
            Renderer.BiasMat._42 := 0.5 + Pass.Stages[i].TextureMatrixBias;
            Renderer.BiasMat._43 := 0;

            Mat := MulMatrix4s(Mat, Renderer.BiasMat);

            StageMatrixSet[i] := True;
          end;
          tmShadowMap: if Assigned(Pass.Stages[i].Camera) then begin
//            mat := IdentityMatrix4s;
            Mat := InvertAffineMatrix4s(Camera.ViewMatrix);
            Mat := MulMatrix4s(Mat, Pass.Stages[i].Camera.ViewMatrix);

            Mat := MulMatrix4s(Mat, Pass.Stages[i].Camera.ProjMatrix);

            Renderer.BiasMat._41 := 0.5 + (0.5 / Pass.Stages[i].Camera.RenderTargetWidth);
            Renderer.BiasMat._42 := 0.5 + (0.5 / Pass.Stages[i].Camera.RenderTargetHeight);
            Renderer.BiasMat._43 := Pass.Stages[i].TextureMatrixBias;

            Mat := MulMatrix4s(Mat, Renderer.BiasMat);

            StageMatrixSet[i] := True;
          end;
          tmScale: begin
            Mat := ScaleMatrix4s(Pass.Stages[i].TextureMatrixBias, Pass.Stages[i].TextureMatrixBias, Pass.Stages[i].TextureMatrixBias);
            StageMatrixSet[i] := True;
          end;
          tmCustom: ;
          else Assert(False);
        end;

    if VertexShaderFlag then begin
//      Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXTURETRANSFORMFLAGS, D3DTTFF_DISABLE);
      Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXTURETRANSFORMFLAGS, Cardinal(D3DTTFF_PROJECTED * Ord(Pass.Stages[i].TTransform and $80 > 0)));
      TransposeMatrix4s(Mat);           {$MESSAGE 'Remove this stub'}
      APISetShaderConstant(skVertex, 32, Mat.Rows[0]);
      APISetShaderConstant(skVertex, 33, Mat.Rows[1]);
      APISetShaderConstant(skVertex, 34, Mat.Rows[2]);
      APISetShaderConstant(skVertex, 35, Mat.Rows[3]);
    end else begin
      Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXTURETRANSFORMFLAGS, TexTransformFlags[Pass.Stages[i].TTransform and $0F] or Cardinal(D3DTTFF_PROJECTED * Ord(Pass.Stages[i].TTransform and $80 > 0)));
      Direct3DDevice.SetTransform(D3DTS_TEXTURE[i], TD3DMatrix(Mat));
    end;
  end;
end;

procedure TDX8StateWrapper.ApplyCustomTextureMatrices(const Pass: TRenderPass; Item: TVisible);
var i: Integer; Mat: TMatrix4s;
begin
  for i := 0 to MinI(Pass.TotalStages-1, Renderer.MaxTextureStages-1) do
    if Pass.Stages[i].TextureMatrixType = tmCustom then begin
      Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXTURETRANSFORMFLAGS, TexTransformFlags[Pass.Stages[i].TTransform and $0F] or Cardinal(D3DTTFF_PROJECTED * Ord(Pass.Stages[i].TTransform and $80 > 0)));

      if Assigned(Item.RetrieveTextureMatrix) then Item.RetrieveTextureMatrix(i, Mat) else Mat := IdentityMatrix4s;

      Direct3DDevice.SetTransform(D3DTS_TEXTURE[i], TD3DMatrix(Mat));

      StageMatrixSet[i] := True;
    end;
end;

procedure TDX8StateWrapper.ObtainRenderTargetSurfaces;
begin
  Direct3DDevice.GetRenderTarget(MainRenderTarget);
  Direct3DDevice.GetDepthStencilSurface(MainDepthStencil);
  CurrentRenderTarget := MainRenderTarget;
  CurrentDepthStencil := MainDepthStencil;
end;

procedure TDX8StateWrapper.CleanUpNonManaged;
var i: Integer;
begin
  for i := 0 to High(FRenderTargets) do DestroyRenderTarget(i);
  MainRenderTarget := nil;
  MainDepthStencil := nil;
  CurrentRenderTarget := nil;
  CurrentDepthStencil := nil;
end;

procedure TDX8StateWrapper.RestoreNonManaged;
var i: Integer;
begin
  for i := 0 to High(FRenderTargets) do CreateRenderTarget(i, FRenderTargets[i].Width, FRenderTargets[i].Height, FRenderTargets[i].ActualColorFormat, FRenderTargets[i].ActualDepthFormat, FRenderTargets[i].IsDepthTexture);
  ObtainRenderTargetSurfaces;
end;

procedure TDX8StateWrapper.FVFToDeclaration(VertexFormat: Cardinal; var Result: PDX8VertexDeclaration);
const Floats: array[1..4] of Longword = (D3DVSDT_FLOAT1, D3DVSDT_FLOAT2, D3DVSDT_FLOAT3, D3DVSDT_FLOAT4);
var Ind, i: Integer; ErrorStr: string;
begin
  ErrorStr := Format('%S.%S: FVF containing transformed verticed can not be conveted to vertex declaration', [ClassName, 'FVFToDeclaration']);
  Assert(not VertexContains(VertexFormat, vfTRANSFORMED), ErrorStr);
  if VertexContains(VertexFormat, vfTRANSFORMED) then begin
     Log(ErrorStr, lkError); 
    Exit;
  end;

{  Size := 3;
  if GetVertexWeightsCount(VertexFormat) > 0   then Inc(Size);
  if VertexContains(VertexFormat, vfNORMALS)   then Inc(Size);
  if VertexContains(VertexFormat, vfPOINTSIZE) then Inc(Size);
  if VertexContains(VertexFormat, vfDIFFUSE)   then Inc(Size);
  if VertexContains(VertexFormat, vfSPECULAR)  then Inc(Size);
  Inc(Size, GetVertexTextureSetsCount(VertexFormat));
}
  Ind := 0;

  Result^[Ind] := D3DVSD_STREAM(0);
  Inc(Ind);
  Result^[Ind] := D3DVSD_REG(0, D3DVSDT_FLOAT3);                                        // Position
  Inc(Ind);
  if GetVertexWeightsCount(VertexFormat) > 0 then begin
    Result^[Ind] := D3DVSD_REG(1, Floats[GetVertexWeightsCount(VertexFormat) +          // Blending weights
                                         Ord(GetVertexIndexedBlending(VertexFormat))]);
    Inc(Ind);
  end;
  if VertexContains(VertexFormat, vfNORMALS) then begin
    Result^[Ind] := D3DVSD_REG(2, D3DVSDT_FLOAT3);                                      // Normals
    Inc(Ind);
  end;
  if VertexContains(VertexFormat, vfPOINTSIZE) then begin
    Result^[Ind] := D3DVSD_REG(3, D3DVSDT_FLOAT1);                                      // Point size
    Inc(Ind);
  end;
  if VertexContains(VertexFormat, vfDIFFUSE) then begin
    Result^[Ind] := D3DVSD_REG(4, D3DVSDT_D3DCOLOR);                                    // Diffuse color
    Inc(Ind);
  end;
  if VertexContains(VertexFormat, vfSPECULAR) then begin
    Result^[Ind] := D3DVSD_REG(5, D3DVSDT_D3DCOLOR);                                    // Specular color
    Inc(Ind);
  end;
  for i := 0 to GetVertexTextureSetsCount(VertexFormat)-1 do begin
    Result^[Ind] := D3DVSD_REG(6+i, Floats[GetVertexTextureCoordsCount(VertexFormat, i)]);       // Texture coordinates set i
    Inc(Ind);
  end;
  Result^[Ind] := D3DVSD_END;
end;

procedure TDX8StateWrapper.DeclarationToAPI(Declaration: TVertexDeclaration; ConstantsData: Pointer; ConstantsSize: Integer; var Result: PDX8VertexDeclaration);
const ErrorStr = '.DeclarationToAPI: Invalid vertex declaration';
var i, ConstantTokens: Integer;
begin
  if ConstantsSize <> 0 then begin
    ConstantTokens := ConstantsSize div SizeOf(Result^[0]);
    Assert(ConstantsSize mod SizeOf(Result^[0]) = 0);
    Move(ConstantsData^, Result^, ConstantsSize);
  end else ConstantTokens := 0;
  Result^[ConstantTokens] := D3DVSD_STREAM(0);
  for i := 0 to High(Declaration) do case Declaration[i] of
    vdtFloat1:  Result^[i+1+ConstantTokens] := D3DVSD_REG(i, D3DVSDT_FLOAT1);
    vdtFloat2:  Result^[i+1+ConstantTokens] := D3DVSD_REG(i, D3DVSDT_FLOAT2);
    vdtFloat3:  Result^[i+1+ConstantTokens] := D3DVSD_REG(i, D3DVSDT_FLOAT3);
    vdtFloat4:  Result^[i+1+ConstantTokens] := D3DVSD_REG(i, D3DVSDT_FLOAT4);
    vdtColor:   Result^[i+1+ConstantTokens] := D3DVSD_REG(i, D3DVSDT_D3DCOLOR);
    vdtByte4:   Result^[i+1+ConstantTokens] := D3DVSD_REG(i, D3DVSDT_UBYTE4);
    vdtInt16_2: Result^[i+1+ConstantTokens] := D3DVSD_REG(i, D3DVSDT_SHORT2);
    vdtInt16_4: Result^[i+1+ConstantTokens] := D3DVSD_REG(i, D3DVSDT_SHORT4);
    vdtNothing: Result^[i+1+ConstantTokens] := D3DVSD_NOP;
    else begin
      Assert(False, ClassName + ErrorStr);
       Log(ClassName + ErrorStr, lkError); 
    end;
  end;
  Result[High(Declaration)+ConstantTokens+2] := D3DVSD_END;
end;

procedure TDX8StateWrapper.APISetShaderConstant(ShaderKind: TShaderKind; ShaderRegister: Integer; const Vector: TShaderRegisterType);
begin
  case ShaderKind of
    skVertex: Direct3DDevice.SetVertexShaderConstant(ShaderRegister, Vector, 1);
    skPixel:  Direct3DDevice.SetPixelShaderConstant(ShaderRegister, Vector, 1);
  end;
end;

procedure TDX8StateWrapper.APISetShaderConstant(const Constant: TShaderConstant);
begin
  with Constant do case ShaderKind of
    skVertex: Direct3DDevice.SetVertexShaderConstant(ShaderRegister, Value, 1);
    skPixel:  Direct3DDevice.SetPixelShaderConstant(ShaderRegister, Value, 1);
  end;
end;

procedure TDX8StateWrapper.APIDestroyPixelShader(Index: Integer);
begin
end;

procedure TDX8StateWrapper.APIDestroyVertexShader(Index: Integer);
begin
end;

function TDX8StateWrapper.APIValidatePass(const Pass: TRenderPass; out ResultStr: string): Boolean;
var Res: HResult; NumPasses: Cardinal;
begin
  Res := Direct3DDevice.ValidateDevice(NumPasses);
  case Res of
    D3D_OK, D3DERR_CONFLICTINGTEXTUREFILTER, D3DERR_UNSUPPORTEDTEXTUREFILTER: Result := True;
    else Result := False;
  end;
  if Res <> D3D_OK then ResultStr := ' (' + HResultToStr(Res) + ')' else ResultStr := '';
end;

{ TDX8Renderer }

constructor TDX8Renderer.Create(Manager: TItemsManager);
var i: Integer; AID: TD3DAdapter_Identifier8;
begin
  {$Include C2DX8Init.inc}
  inherited;
  Log('Starting DX8Renderer...', lkNotice);
  if not LoadDirect3D8 then begin
    Log('DirectX 8 or greater not installed', lkFatalError);
    Exit;
  end;
  Direct3DDevice := nil;

  FillChar(AID, SizeOf(AID), 0);
  Direct3D := Direct3DCreate8(D3D_SDK_VERSION);
//  if Direct3D <> nil then i := Direct3D._Release;
  if Direct3D = nil then begin
    Log(ClassName + '.Create: Error creating Direct3D object', lkFatalError);
  end else begin
    Log(ClassName + '.Create: Direct3D object succesfully Create');

    FTotalAdapters := Direct3D.GetAdapterCount;
    SetLength(FAdapterNames, TotalAdapters);
    for i := 0 to TotalAdapters - 1 do begin
      // Fill in adapter info
      Direct3D.GetAdapterIdentifier(i, D3DENUM_NO_WHQL_LEVEL, AID);
      FAdapterNames[i] := AID.Description;
      
      Log('Found video adapter "'+AID.Description+'"');
      Log('  Driver: ' + AID.Driver);
      Log('  Driver version: Product ' + IntToStr((Int64(AID.DriverVersion) shr 48) and $FFFF) + ', version ' + IntToStr((Int64(AID.DriverVersion) shr 32) and $FFFF) +
              ', subversion ' + IntToStr((Int64(AID.DriverVersion) shr 16) and $FFFF) + ', build ' + IntToStr(Int64(AID.DriverVersion) and $FFFF));
      Log('  Vendor ID: ' + IntToStr(AID.VendorId) + ', device ID: ' + IntToStr(AID.DeviceId)+', subsystem ID: ' + IntToStr(AID.SubSysId) + ', revision: ' + IntToStr(AID.Revision));
//      if AID.WHQLLevel = 0 then Log('Driver is not WHQL certified') else Log('Driver is WHQL certified');
      
    end;
  end;

  FCurrentAdapter := D3DADAPTER_DEFAULT;
  SetDeviceType(dtHAL);

  Textures   := TDX8Textures.Create;
  APIState   := TDX8StateWrapper.Create;
  APIBuffers := TDX8Buffers.Create(Self);
  InternalInit;
end;

function TDX8Renderer.APICheckFormat(const Format, Usage, RTFormat: Cardinal): Boolean;
var Res: HResult; D3DUsage, AdapterFormat: Cardinal; D3DResType: TD3DResourceType;
begin
  Result := False;
//  if Format = pfa8r8g8b8 then Exit;
  Assert((Format < TotalPixelFormats));
  if (Format <= 0) or (Format >= TotalPixelFormats) or (PFormats[Format] = Cardinal(D3DFMT_UNKNOWN)) then Exit;

  case Usage of
    fuRenderTarget: begin D3DUsage := D3DUSAGE_RENDERTARGET; D3DResType := D3DRTYPE_TEXTURE; end;
    fuDepthStencil, fuDEPTHTEXTURE: begin
      if not IsDepthFormat(Format) then Exit;
      D3DUsage := D3DUSAGE_DEPTHSTENCIL;
      if Usage = fuDepthStencil then
        D3DResType := D3DRTYPE_SURFACE else
          D3DResType := D3DRTYPE_TEXTURE;
    end;
    fuVolumeTexture:  begin D3DUsage := 0; D3DResType := D3DRTYPE_VOLUMETEXTURE; end;
    fuCubeTexture:    begin D3DUsage := 0; D3DResType := D3DRTYPE_CUBETEXTURE;  end;
    else {fuTexture:} begin D3DUsage := 0; D3DResType := D3DRTYPE_TEXTURE; end;
  end;

  if FFullScreen then
    AdapterFormat := PFormats[VideoMode[CurrentVideoMode].Format]
  else
    AdapterFormat := PFormats[DesktopVideoMode.Format];

  Res := Direct3D.CheckDeviceFormat(FCurrentAdapter, CurrentDeviceType, TD3DFormat(AdapterFormat), D3DUsage, D3DResType, TD3DFormat(PFormats[Format]));
  case Res of
    D3D_OK: Result := True;
    D3DERR_INVALIDCALL: {$IFDEF DEBUGMODE}  Log(ClassName + 'CheckTextureFormat: Invalid call', lkWarning)   {$ENDIF} ;
    D3DERR_NOTAVAILABLE: ;
    else  Log(ClassName + 'CheckTextureFormat: Unknown error', lkWarning)  ;
  end;
  // Check if depth-stencil is compatible with a render target format
  if Result and ((Usage = fuDepthStencil) or (Usage = fuDEPTHTEXTURE)) and (RTFormat <> pfUndefined) then begin
    Result := False;
    Res := Direct3D.CheckDepthStencilMatch(FCurrentAdapter, CurrentDeviceType, TD3DFormat(AdapterFormat), TD3DFormat(PFormats[RTFormat]), TD3DFormat(PFormats[Format]));
    case Res of
      D3D_OK: Result := True;
      D3DERR_INVALIDCALL:  Log(ClassName + 'CheckDepthStencilMatch: Invalid call', lkWarning)  ;
      D3DERR_NOTAVAILABLE: ;
      else  Log(ClassName + 'CheckDepthStencilMatch: Unknown error', lkWarning)  ;
    end;
  end;
end;

procedure TDX8Renderer.APIPrepareFVFStates(Item: TVisible);
//const D3DTS_AdditionalWorld: array[0..2] of TD3DTransformStateType = (D3DTS_World1, D3DTS_World2, D3DTS_World3);
var i: Integer;
begin
  Direct3DDevice.SetVertexShader(TDX8Buffers(APIBuffers).GetFVF(Item.CurrentTesselator.VertexFormat));
  // Item matrices setting
  Direct3DDevice.SetTransform(D3DTS_World, TD3DMatrix(Item.Transform));
  for i := 0 to Length(Item.BlendMatrices)-1 do
    Direct3DDevice.SetTransform(D3DTS_WORLDMATRIX(i), TD3DMatrix(Item.BlendMatrices[i]));

  //           * Move to material settings *
  Direct3DDevice.SetRenderState(D3DRS_VERTEXBLEND, (Item.CurrentTesselator.VertexFormat shr 28) and $7);        // Turn on vertex blending if weights present
  Direct3DDevice.SetRenderState(D3DRS_INDEXEDVERTEXBLENDENABLE, Ord((Item.CurrentTesselator.VertexFormat shr 28) and vwIndexedBlending = vwIndexedBlending));
  Direct3DDevice.SetRenderState(D3DRS_COLORVERTEX, Ord(Item.CurrentTesselator.VertexFormat and vfDiffuse > 0));   // Turn on vertex coloring if diffuse present

  if Item.CurrentTesselator.VertexFormat and vfDiffuse > 0 then
    Direct3DDevice.SetRenderState(D3DRS_DIFFUSEMATERIALSOURCE, D3DMCS_COLOR1) else
      Direct3DDevice.SetRenderState(D3DRS_DIFFUSEMATERIALSOURCE, D3DMCS_MATERIAL);

  if Item.CurrentTesselator.VertexFormat and vfSpecular > 0 then
    Direct3DDevice.SetRenderState(D3DRS_SPECULARMATERIALSOURCE, D3DMCS_COLOR2) else
      Direct3DDevice.SetRenderState(D3DRS_SPECULARMATERIALSOURCE, D3DMCS_MATERIAL);
end;

procedure TDX8Renderer.InternalDeInit;
begin
  CleanUpNonManaged;
  FreeAndNil(APIBuffers);
  FAdapterNames := nil;
  FVideoModes   := nil;
//  i := Direct3DDevice._Release;
  Direct3DDevice := nil;
  if Assigned(Direct3D) then begin
//    i := Direct3D._Release;
    Direct3D := nil;
  end;
  inherited;
end;

procedure TDX8Renderer.SetDeviceType(DevType: Cardinal);
const DXDeviceTypes: array[0..2] of TD3DDEVTYPE = (D3DDEVTYPE_HAL, D3DDEVTYPE_REF, D3DDEVTYPE_SW);
begin
  if DevType > 2 then Exit;
  CurrentDeviceType := DXDeviceTypes[DevType];
  SetVideoAdapter(FCurrentAdapter);  
end;

function TDX8Renderer.FindDepthStencilFormat(iAdapter: Word; DeviceType: TD3DDEVTYPE; TargetFormat: TD3DFORMAT; var DepthStencilFormat: TD3DFORMAT) : Boolean;
const
  TotalDepthFormats = 6;
  DepthFormats: array[False..True, 0..TotalDepthFormats-1] of TD3DFORMAT = (
  (D3DFMT_D32,   D3DFMT_D24X8,   D3DFMT_D24S8, D3DFMT_D24X4S4, D3DFMT_D16,   D3DFMT_D15S1),
  (D3DFMT_D24S8, D3DFMT_D24X4S4, D3DFMT_D15S1, D3DFMT_D32,     D3DFMT_D24X8, D3DFMT_D16));
var i: Integer;
begin
  Result := True;

  for i := 0 to TotalDepthFormats-1 do
    if not Failed(Direct3D.CheckDeviceFormat(iAdapter, DeviceType, TargetFormat, D3DUSAGE_DEPTHSTENCIL, D3DRTYPE_SURFACE, DepthFormats[arUseStencil in AppRequirements.Flags, i])) then
      if not Failed(Direct3D.CheckDepthStencilMatch(iAdapter, DeviceType, TargetFormat, TargetFormat, DepthFormats[arUseStencil in AppRequirements.Flags, i])) then begin
        DepthStencilFormat := DepthFormats[arUseStencil in AppRequirements.Flags, i];
        Exit;
      end;

  Result := False;
end;

procedure TDX8Renderer.BuildModeList;
var
  iMode: Integer;
  dwNumModes: Longword;
  DisplayMode : TD3DDISPLAYMODE;
  m : Longword;

  procedure SortModes(N: Integer; Values: TVideoModes);
  type _QSDataType = TVideoMode;

    function _QSCompare(const V1, V2: _QSDataType): Integer;
    begin
      Result := Integer(GetBytesPerPixel(V1.Format)) - Integer(GetBytesPerPixel(V2.Format));
      if Result = 0 then
        Result := (V1.Width shl 16 + V1.Height) -
                  (V2.Width shl 16 + V2.Height);
      if Result = 0 then Result := V1.RefreshRate - V2.RefreshRate;
    end;

  {$I basics_quicksort.inc}              // Include the quick sort algorithm
  {$IFNDEF ForCodeNavigationWork} begin end; {$ENDIF}

begin
  // Enumerate all display modes on this adapter
  FTotalVideoModes := Direct3D.GetAdapterModeCount(FCurrentAdapter);

  SetLength(FVideoModes, FTotalVideoModes);

  dwNumModes := 0;
  for iMode := 0 to FTotalVideoModes - 1 do begin
    // Get the display mode attributes
    Direct3D.EnumAdapterModes(FCurrentAdapter, iMode, DisplayMode);
    // Filter out low-resolution modes
    if DisplayMode.Height < AppRequirements.MinYResolution then Continue;
    // Filter out unsupported with chosen device type modes
    if Failed(Direct3D.CheckDeviceType(FCurrentAdapter, CurrentDeviceType, DisplayMode.Format, DisplayMode.Format, False)) and
       Failed(Direct3D.CheckDeviceType(FCurrentAdapter, CurrentDeviceType, DisplayMode.Format, DisplayMode.Format, True)) then
      Continue;
    // Check if the mode already exists (to filter out refresh rates)
    m := 0;
    while m < dwNumModes do begin
      if not (arModesUseRefresh in AppRequirements.Flags) and
         (FVideoModes[m].Width  = Integer(DisplayMode.Width) ) and
         (FVideoModes[m].Height = Integer(DisplayMode.Height)) and
         (PFormats[FVideoModes[m].Format] = Cardinal(DisplayMode.Format)) then Break;
      Inc(m);
    end;

    // If we found a new mode, add it to the list of modes
    if m = dwNumModes then begin
      FVideoModes[dwNumModes].Width       := DisplayMode.Width;
      FVideoModes[dwNumModes].Height      := DisplayMode.Height;
      FVideoModes[dwNumModes].Format      := APIToPixelFormat(Cardinal(DisplayMode.Format));
      FVideoModes[dwNumModes].RefreshRate := DisplayMode.RefreshRate;
      Inc(dwNumModes);
    end;
  end;

  FTotalVideoModes := dwNumModes;
  SetLength(FVideoModes, FTotalVideoModes);
  // Sort the list of display modes (by format, then width, then height, then refresh)
  SortModes(FTotalVideoModes, FVideoModes);

   {$IFDEF EXTLOGGING}
//  for i := 0 to FTotalVideoModes-1 do begin
//    Log(Format('Video mode: [%Dx%Dx%D, %DHz', [FVideoModes[i].Width, FVideoModes[i].Height, GetBitDepth(FVideoModes[i].Format), FVideoModes[i].RefreshRate]));
//  end;
   {$ENDIF}
end;

procedure TDX8Renderer.SetGamma(Gamma, Contrast, Brightness: Single);
begin
  inherited;
  if IsReady then
    Direct3DDevice.SetGammaRamp(D3DSGR_NO_CALIBRATION, TD3DGammaRamp(GammaRamp));
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
  Log('Checking 3D device capabilites...', lkNotice);
  Log('----------', lkInfo);
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
  Log(CanStr[Caps.RasterCaps and D3DPRASTERCAPS_PAT > 0]+' Device supports patterned drawing', lkInfo);
  Log(CanStr[Caps.ShadeCaps and D3DPSHADECAPS_SPECULARGOURAUDRGB > 0]+' Device can support specular highlights in Gouraud shading in the RGB color model', lkInfo);
  Log(' Vertex processing caps', lkInfo);
  Log('Max clip planes: ' + IntToStr(Caps.MaxUserClipPlanes), lkInfo);
  Log(CanStr[Caps.VertexProcessingCaps and D3DVTXPCAPS_TEXGEN > 0]+' Device can generate texture coordinates', lkInfo);
  Log(CanStr[Caps.VertexProcessingCaps and D3DVTXPCAPS_TWEENING > 0]+' Device supports vertex tweening', lkInfo);
  Log(CanStr[Caps.VertexProcessingCaps and D3DVTXPCAPS_MATERIALSOURCE7 > 0]+' Device supports selectable vertex color sources', lkInfo);
  Log('Max vertex w: '+FloatToStrF(Caps.MaxVertexW, ffFixed, 10, 1), lkInfo);
  Log(CanStr[Caps.PrimitiveMiscCaps and D3DPMISCCAPS_CLIPTLVERTS > 0]+' Device clips post-transformed vertex primitives', lkInfo);
  Log('Max number of primitives: '+IntToStr(Caps.MaxPrimitiveCount), lkInfo);
  Log('Max vertex index: '+IntToStr(Caps.MaxVertexIndex), lkInfo);
  Log(' Blending operations caps', lkInfo);
  Log(CanStr[Caps.PrimitiveMiscCaps and D3DPMISCCAPS_BLENDOP  > 0]+' Device supports all the alpha-blending operations (ADD, SUB, REVSUB, MIN, MAX)', lkInfo);
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
  {$ENDIF}
  CheckTextureFormats;
  {$IFDEF EXTLOGGING}
  Log(CanStr[DepthTextures]+' Depth textures support', lkInfo);
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
  Log('Vertex shader version: ' + IntToStr((Caps.VertexShaderVersion shr 8) and $FF)+'.'+ IntToStr(Caps.VertexShaderVersion and $FF), lkInfo);
  Log('Vertex shader constant registers: '+IntToStr(Caps.MaxVertexShaderConst), lkInfo);
  Log('Pixel shader version: ' + IntToStr((Caps.PixelShaderVersion shr 8) and $FF)+'.' + IntToStr(Caps.PixelShaderVersion and $FF), lkInfo);
  Log('Max pixel shader value: ' + FloatToStrF(Caps.MaxPixelShaderValue, ffFixed, 10, 1), lkInfo);
  Log('----------', lkInfo);
  {$ENDIF}
  HardwareClipping   := Caps.PrimitiveMiscCaps and D3DPMISCCAPS_CLIPTLVERTS > 0;  // ToDo: wrong cap!
  WBuffering         := Caps.RasterCaps and D3DPRASTERCAPS_WBUFFER > 0;
  SquareTextures     := Caps.TextureCaps and D3DPTEXTURECAPS_SQUAREONLY > 0;
  Power2Textures     := Caps.TextureCaps and D3DPTEXTURECAPS_POW2 > 0;
  MaxClipPlanes      := Caps.MaxUserClipPlanes;
  MaxTextureWidth    := Caps.MaxTextureWidth;
  MaxTextureHeight   := Caps.MaxTextureHeight;
  MaxTexturesPerPass := Caps.MaxSimultaneousTextures;
  MaxTextureStages   := Caps.MaxTextureBlendStages;
  MaxPointSize       := Caps.MaxPointSize;
  if Caps.DevCaps and D3DDEVCAPS_HWTRANSFORMANDLIGHT > 0 then MaxHardwareLights := Caps.MaxActiveLights else MaxHardwareLights := 0;
  MaxAPILights       := 8;
  MaxPrimitiveCount  := Caps.MaxPrimitiveCount;
  MaxVertexIndex     := Caps.MaxVertexIndex;

  VertexShaderVersionMajor := (Caps.VertexShaderVersion shr 8) and $FF;
  VertexShaderVersionMinor := Caps.VertexShaderVersion and $FF;
  PixelShaderVersionMajor  := (Caps.PixelShaderVersion shr 8) and $FF;
  PixelShaderVersionMinor  := Caps.PixelShaderVersion and $FF;
  MaxVertexShaderConsts    := Caps.MaxVertexShaderConst;

  MixedVPMode := MixedVPMode and (VertexShaderVersionMajor = 0) and (VertexShaderVersionMinor = 0);
  if MixedVPMode then Log('Hardware transform and lighting with software vertex shader emulation used', lkWarning); 
end;

procedure TDX8Renderer.CheckTextureFormats;
var i: Integer;
{$IFDEF EXTLOGGING}
const SupportStr: array[False..True] of string[14] = ('     [ ]      ', '     [X]      ');
{$ENDIF}
begin
  {$IFDEF EXTLOGGING}
  Log(' Texture formats supported', lkInfo);
  Log(' Format     Texture    RenderTarget   DepthStencil   Vol texture   Cube texture  Depth texture');

//  Log('    Video format: '+IntToStr(CPFormats[RenderPars.VideoFormat]));

  for i := 0 to High(PFormats) do if PFormats[i] <> Cardinal(D3DFMT_UNKNOWN) then begin
    Log(Format('%-8.8s', [PixelFormatToStr(i)]) + SupportStr[APICheckFormat(i, fuTexture,       pfUndefined)] +
                                                      SupportStr[APICheckFormat(i, fuRenderTarget,  pfUndefined)] +
                                                      SupportStr[APICheckFormat(i, fuDepthStencil,  pfUndefined)] +
                                                      SupportStr[APICheckFormat(i, fuVolumeTexture, pfUndefined)] +
                                                      SupportStr[APICheckFormat(i, fuCubeTexture,   pfUndefined)] +
                                                      SupportStr[APICheckFormat(i, fuDEPTHTEXTURE,  pfUndefined)]
                                                      );
  end;
  {$ENDIF}
  i := High(PFormats);
  while (i >= 0) and
        not ((PFormats[i] <> Cardinal(D3DFMT_UNKNOWN)) and APICheckFormat(i, fuDEPTHTEXTURE,  pfUndefined)) do
    Dec(i);
  DepthTextures := (i >= 0);
end;

function TDX8Renderer.FillPresentPars(var D3DPP: TD3DPresent_Parameters): Boolean;
var D3DDM: TD3DDisplayMode; Res: HResult;
begin
  Result := False;

  if not LastFullScreen then begin
    Res := Direct3D.GetAdapterDisplayMode(FCurrentAdapter, D3DDM);
    if Failed(Res) then begin
       Log(ClassName + 'FillPresentPars: Error obtaining display mode. Result: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError); 
      Exit;
    end;
    DesktopVideoMode.Width       := D3DDM.Width;
    DesktopVideoMode.Height      := D3DDM.Height;
    DesktopVideoMode.RefreshRate := D3DDM.RefreshRate;
    DesktopVideoMode.Format      := APIToPixelFormat(Cardinal(D3DDM.Format));
  end;

  FillChar(D3DPP, SizeOf(D3DPP), 0);

  if not FFullScreen then begin
    if LastFullScreen then SetWindowLong(RenderWindowHandle, GWL_STYLE, FNormalWindowStyle);
    if not PrepareWindow then begin
       Log(ClassName + 'FillPresentPars: Error creating windowed viewport', lkError); 
      Exit;
    end;
    if LastFullScreen then SetWindowLong(RenderWindowHandle, GWL_STYLE, FNormalWindowStyle);
     Log(Format('  Viewport: Windowed %Dx%Dx%D', [RenderWidth, RenderHeight, GetBitsPerPixel(DesktopVideoMode.Format)])); 
    D3DPP.BackBufferFormat := TD3DFormat(PFormats[DesktopVideoMode.Format]);
  end else begin
    if Direct3dDevice = nil then begin
      GetWindowRect(RenderWindowHandle, FWindowedRect);
    end;
    RenderWidth  := VideoMode[CurrentVideoMode].Width;
    RenderHeight := VideoMode[CurrentVideoMode].Height;

    D3DPP.BackBufferFormat := TD3DFormat(PFormats[VideoMode[CurrentVideoMode].Format]);
    D3DPP.FullScreen_RefreshRateInHz := D3DPRESENT_RATE_DEFAULT;

    if arForceNoVSync in AppRequirements.Flags then D3DPP.FullScreen_PresentationInterval := D3DPRESENT_INTERVAL_IMMEDIATE else
      if arForceVSync in AppRequirements.Flags then D3DPP.FullScreen_PresentationInterval := D3DPRESENT_INTERVAL_ONE else
        D3DPP.FullScreen_PresentationInterval := D3DPRESENT_INTERVAL_DEFAULT;

    SetWindowLong(RenderWindowHandle, GWL_STYLE, Integer(FullScreenWindowStyle));
    SetWindowLong(RenderWindowHandle, GWL_EXSTYLE, WS_EX_TOPMOST);
     Log(Format('  Viewport: Fullscreen %Dx%Dx%D', [RenderWidth, RenderHeight, GetBitsPerPixel(VideoMode[CurrentVideoMode].Format)])); 
  end;

  D3DPP.BackBufferWidth  := RenderWidth;
  D3DPP.BackBufferHeight := RenderHeight;

  D3DPP.BackBufferCount := AppRequirements.TotalBackBuffers;
  D3DPP.MultiSampleType := D3DMULTISAMPLE_NONE;

  if arPreserveBackBuffer in AppRequirements.Flags then D3DPP.SwapEffect := D3DSWAPEFFECT_FLIP else D3DPP.SwapEffect := D3DSWAPEFFECT_DISCARD;

  D3DPP.hDeviceWindow := RenderWindowHandle;
  D3DPP.Windowed      := not FFullScreen;

  D3DPP.EnableAutoDepthStencil := (arUseZBuffer in AppRequirements.Flags) or (arUseStencil in AppRequirements.Flags);
//  D3DPP.AutoDepthStencilFormat := ge
  D3DPP.Flags := D3DPRESENTFLAG_LOCKABLE_BACKBUFFER * Ord(arLockableBackBuffer in AppRequirements.Flags);

  if D3DPP.EnableAutoDepthStencil and not FindDepthStencilFormat(FCurrentAdapter, CurrentDeviceType, D3DPP.BackBufferFormat, D3DPP.AutoDepthStencilFormat) then begin
    
    Log(ClassName + 'Viewport: Suitable depth buffer format not found. Depth testing disabled', lkError);
    
    D3DPP.EnableAutoDepthStencil := False;
  end;

  LastFullScreen := FFullScreen;

  Result := True;
end;

procedure TDX8Renderer.CleanUpNonManaged;
begin
  Buffers.Reset;
  (APIState as TDX8StateWrapper).CleanUpNonManaged;
end;

procedure TDX8Renderer.RestoreNonManaged;
begin
  Assert(Assigned(Direct3DDevice));
  (APIState as TDX8StateWrapper).RestoreNonManaged;
end;

procedure TDX8Renderer.GetAPIDeclaration(Declaration: TVertexDeclaration; Result: PDX8VertexDeclaration);
var i: Integer;
begin
  Result^[0] := D3DVSD_STREAM(0);
  for i := 0 to High(Declaration) do
    Result^[i+1] := D3DVSD_REG(i, VertexDataTypeToD3DVSDT[Declaration[i]]);

  Result^[High(Declaration) + 2] := D3DVSD_END;
end;

function TDX8Renderer.APICreateDevice(WindowHandle, AVideoMode: Cardinal; AFullScreen: Boolean): Boolean;

  procedure SetLight;
  var HLight: TD3DLIGHT8;
  begin
    with HLight do begin
      _Type := D3DLIGHT_DIRECTIONAL;

      Diffuse.r  := 0.5; Diffuse.g  := 0.5; Diffuse.b  := 0.5; Diffuse.a  := 0.5;
      Specular.r := 0.0; Specular.g := 0.0; Specular.b := 0.0; Specular.a := 0.0;
      Ambient.r  := 0.5; Ambient.g  := 0.5; Ambient.b  := 0.5; Ambient.a  := 0.5;
      Direction.X := 0; Direction.Y := -1; Direction.Z := 0;
    end;
    Direct3dDevice.SetLight(0, HLight);
    Direct3dDevice.LightEnable(0, True);
  end;

var
  D3DPP:   TD3DPresent_Parameters;
  D3DCaps: TD3DCaps8;
  DCFlags: Cardinal;
  Res: HResult;

  function TryHardwareVP(Flag: Cardinal): Boolean;
  begin
    Result := (D3DCaps.DevCaps and D3DDEVCAPS_HWTRANSFORMANDLIGHT) = D3DDEVCAPS_HWTRANSFORMANDLIGHT;
    if Result then DCFlags := Flag else begin
       Log(ClassName + '.APICreateDevice: Hardware vertex processing not supported. Switching to software vertex processing', lkWarning); 
    end;
  end;

//  var i, j, k: Integer; m, mi: tmatrix4s; dm, dmi: td3dmatrix; Det: Single; quat: TQuaternion;

begin
  Result := False;
  
  if Direct3D = nil then begin
     Log(ClassName + '.APICreateDevice: Direct3D object was not initialized', lkFatalError); 
    Exit;
  end;
  FState := rsNotReady;

  Res := Direct3D.GetDeviceCaps(FCurrentAdapter, CurrentDeviceType, D3DCaps);
  if Failed(Res) then begin
     Log(ClassName + '.APICreateDevice: Error obtaining device capabilities. Result: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError); 
    Exit;
  end;

  FCurrentVideoMode := AVideoMode;
  FFullScreen := AFullScreen;           // Use windowed mode if current video mode is invalid

  if FFullScreen then if (D3DCaps.Caps2 and D3DCAPS2_CANRENDERWINDOWED = 0) then begin     // Device does not support windowed mode
    FCurrentVideoMode := 0;
    FFullScreen := False;
     Log(ClassName + 'APICreateDevice: Windowed rendering is not supported', lkError); 
  end;

  RenderWindowHandle := WindowHandle;
  FNormalWindowStyle := GetWindowLong(RenderWindowHandle, GWL_STYLE);
  if FNormalWindowStyle = 0 then
    FNormalWindowStyle := WS_OVERLAPPED or WS_CAPTION or WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX or WS_SIZEBOX or WS_SYSMENU;

  if not FillPresentPars(D3DPP) then Exit;
// Set device creation flags
  DCFlags := D3DCREATE_SOFTWARE_VERTEXPROCESSING;
  case AppRequirements.HWAccelerationLevel of
    haMixedVP:    TryHardwareVP(D3DCREATE_MIXED_VERTEXPROCESSING);
    haHardwareVP: TryHardwareVP(D3DCREATE_HARDWARE_VERTEXPROCESSING);
    haPureDevice: if TryHardwareVP(D3DCREATE_HARDWARE_VERTEXPROCESSING) then
      if (D3DCaps.DevCaps and D3DDEVCAPS_PUREDEVICE) = D3DDEVCAPS_PUREDEVICE then begin
        DCFlags := DCFlags or D3DCREATE_PUREDEVICE;
        Log('  ' + ClassName + '.APICreateDevice: Pure device');
      end else begin
        Log(ClassName + '.APICreateDevice: Pure device is not supported', lkWarning);
      end;
  end;

  MixedVPMode := DCFlags = D3DCREATE_MIXED_VERTEXPROCESSING;
  if arPreserveFPU in AppRequirements.Flags then DCFlags := DCFlags or D3DCREATE_FPU_PRESERVE;
  if arMultithreadedRender in AppRequirements.Flags then DCFlags := DCFlags or D3DCREATE_MULTITHREADED;

  if Direct3dDevice <> nil then Direct3dDevice := nil;

  repeat
    Res := Direct3D.CreateDevice(D3DADAPTER_DEFAULT, CurrentDeviceType, WindowHandle, DCFlags, D3DPP, Direct3DDevice);
  until not Failed(Res) or (D3DPP.BackBufferCount = AppRequirements.TotalBackBuffers);

  if Failed(Res) then begin
    Log(ClassName + 'APICreateDevice: Error creating Direct3D device. Result: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkFatalError);
    Exit;
  end;

//  if not AFullScreen then ShowWindow(RenderWindowHandle, SW_SHOW);

  (APIState as TDX8StateWrapper).Direct3dDevice := Direct3dDevice;
  (Textures as TDX8Textures).Direct3dDevice     := Direct3dDevice;

  Direct3dDevice.SetRenderState(D3DRS_DITHERENABLE, 1);
  Direct3DDevice.SetRenderState(D3DRS_CLIPPING, 1);
  Direct3DDevice.SetRenderState(D3DRS_AMBIENTMATERIALSOURCE, D3DMCS_MATERIAL);

  SetLight;

  TDX8StateWrapper(APIState).ObtainRenderTargetSurfaces;

  FState := rsOK;
  Active := True;
  Result := True;
end;

function TDX8Renderer.RestoreDevice(AVideoMode: Cardinal; AFullScreen: Boolean): Boolean;
var D3DPP: TD3DPresent_Parameters; Res: HResult; ChangeWindowed: Boolean;
begin
  
  Log('Restoring viewport', lkNotice);
  
  Result := False;
  FState := rsLost;

  ChangeWindowed := FFullScreen <> AFullScreen;

  if ChangeWindowed then begin
    if AFullScreen then begin                                           // We're going fullscreen
      ShowWindow(RenderWindowHandle, SW_RESTORE);
      GetWindowRect(RenderWindowHandle, FWindowedRect);
      SetWindowLong(RenderWindowHandle, GWL_EXSTYLE, WS_EX_TOPMOST);
    end else                                                            // We're going windowed
      if not SetWindowPos(RenderWindowHandle, HWND_NOTOPMOST, WindowedRect.Left, WindowedRect.Top,
                          WindowedRect.Right - WindowedRect.Left, WindowedRect.Bottom - WindowedRect.Top,
                          SWP_DRAWFRAME or SWP_NOCOPYBITS or SWP_SHOWWINDOW) then begin
         Log(ClassName + '.RestoreDevice: Can''t set window position (1)', lkError); 
      end;
  end;

  FCurrentVideoMode := AVideoMode;
  FFullScreen       := AFullScreen;

  if not FillPresentPars(D3DPP) then Exit;

  CleanUpNonManaged;

  Res := Direct3DDevice.Reset(D3DPP);
  if Failed(Res) then begin
    
    Log('Error resetting viewport. Result: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    
    FState := rsLost;
    Exit;
  end;

  if ChangeWindowed then
    if not AFullScreen then begin                      // We're become windowed
      if not SetWindowPos(RenderWindowHandle, HWND_NOTOPMOST, WindowedRect.Left, WindowedRect.Top,
                          WindowedRect.Right - WindowedRect.Left, WindowedRect.Bottom - WindowedRect.Top,
                          SWP_DRAWFRAME or SWP_NOCOPYBITS or SWP_SHOWWINDOW or SWP_NOMOVE or SWP_NOSIZE) then begin
         Log(ClassName + '.RestoreDevice: Can''t set window position (2)', lkError); 
      end;
    end else begin
//      ShowWindow(RenderWindowHandle, SW_MAXIMIZE);
      PostMessage(RenderWindowHandle, WM_SIZE, 0, RenderHeight * 65536 + RenderWidth);    // To notify the application about render window resizing
    end;

  RestoreNonManaged;

{  if WBuffering then
   Direct3dDevice.SetRenderState(D3DRS_ZENABLE, D3DZB_USEW) else
    Direct3dDevice.SetRenderState(D3DRS_ZENABLE, D3DZB_TRUE);}

  Direct3dDevice.SetRenderState(D3DRS_DITHERENABLE, 1);
  Direct3DDevice.SetRenderState(D3DRS_CLIPPING, 1);
  Direct3DDevice.SetRenderState(D3DRS_AMBIENTMATERIALSOURCE, D3DMCS_MATERIAL);

//  f := 2.0;
//  Direct3DDevice.SetRenderState(D3DRS_PATCHSEGMENTS, Cardinal((@f)^));
//  Direct3DDevice.SetRenderState(D3DRS_PATCHEDGESTYLE, D3DPATCHEDGE_CONTINUOUS);

  inherited RestoreDevice(AVideoMode, AFullScreen);

  FState := rsOK;
  Result := True;
end;

procedure TDX8Renderer.StartFrame;
var Res: HResult;
begin
  inherited;
  if not IsReady then Exit;

  if Active then Res := Direct3DDevice.Present(nil, nil, 0, nil) else Res := Direct3DDevice.TestCooperativeLevel;

  if Res = D3DERR_DEVICELOST then begin
    FState := rsLost;
//    LostTime := Globals.CurrentTime;
    
    Log('Render: Device lost. Need to restore', lkWarning);
    
    Sleep(0);
    Exit;
  end;

  Direct3DDevice.BeginScene;
end;

procedure TDX8Renderer.FinishFrame;
begin
(*  if (State = rsLost) and (Timer.Time - LostTime > MaxLostTime) and Active then begin
    FState := rsTryToRestore;
    
    Log('No device restoration attempts in last ' + IntToStr(MaxLostTime) + ' milliseconds. Forcing restoration', lkWarning);
    
  end;*)
  if (State = rsLost) then begin
    if not RestoreDevice(FCurrentVideoMode, FFullScreen) then Sleep(0);
    Exit;
  end;

  if not IsReady then begin Sleep(0); Exit; end;

  Direct3DDevice.EndScene;

  if not Active then begin FState := rsLost; Sleep(0); Exit; end;

  FState := rsOK;

  Inc(FFramesRendered);
end;

procedure TDX8Renderer.ApplyLight(Index: Integer; const ALight: TLight);
var HLight: TD3DLIGHT8;
begin
  if not IsReady then Exit;
  inherited;
  if ALight = nil then Direct3dDevice.LightEnable(Index, False) else begin
    with HLight do begin
      case ALight.Kind of
        ltDirectional:  _Type := D3DLIGHT_DIRECTIONAL;
        ltPoint:        _Type := D3DLIGHT_POINT;
        ltSpot:         _Type := D3DLIGHT_SPOT;
      end;

      Diffuse  := TD3DColorValue(ALight.Diffuse);
      Specular := TD3DColorValue(ALight.Specular);
      Ambient  := TD3DColorValue(ALight.Ambient);

      TVector3s(Direction) := ALight.ForwardVector;
      TVector3s(Position)  := ALight.GetAbsLocation;

      Range := ALight.Range;
      Falloff := ALight.Falloff;

      Attenuation0 := ALight.Attenuation0;
      Attenuation1 := ALight.Attenuation1;
      Attenuation2 := ALight.Attenuation2;

      Theta := ALight.Theta;
      Phi   := ALight.Phi;
    end;
    Direct3dDevice.SetLight(Index, HLight);
    Direct3dDevice.LightEnable(Index, True);
  end;
end;

procedure TDX8Renderer.APIApplyCamera(Camera: TCamera);
begin
  inherited;
  if not IsReady or (Camera = nil) or (Direct3DDevice = nil) then Exit;
  Direct3DDevice.SetTransform(D3DTS_VIEW, TD3DMatrix(Camera.ViewMatrix));
  Direct3DDevice.SetTransform(D3DTS_PROJECTION, TD3DMatrix(Camera.ProjMatrix));
end;

procedure TDX8Renderer.SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single);
begin
  inherited;
  if not IsReady then Exit;
  Direct3DDevice.SetViewport(TD3DViewport8(ViewPort));
end;

procedure TDX8Renderer.APIRenderIndexedStrip(Tesselator: TTesselator; StripIndex: Integer);
var Res: HResult;
begin
  APIBuffers.AttachIndexBuffer(InternalGetIndexBufferIndex(Tesselator.TesselationStatus[tbIndex].TesselatorType = ttStatic,
                                                           Tesselator.TesselationStatus[tbIndex].BufferIndex),
                               (Tesselator.TesselationStatus[tbVertex].Offset + StripIndex * Tesselator.StripOffset));
  Res := Direct3DDevice.DrawIndexedPrimitive(TD3DPrimitiveType(CPTypes[Tesselator.PrimitiveType]), 0,
                                             Tesselator.IndexingVertices, Tesselator.TesselationStatus[tbIndex].Offset, Tesselator.TotalPrimitives);
  {$IFDEF DEBUGMODE}
  if Res <> D3D_OK then Log(ClassName + '.APIRenderIndexedStrip: DrawIndexedPrimitive returned "Invalid call" error ', lkError);
  {$ENDIF}
  Inc(FPerfProfile.DrawCalls);
  Inc(FPerfProfile.PrimitivesRendered, Tesselator.TotalPrimitives);
end;

procedure TDX8Renderer.APIRenderStrip(Tesselator: TTesselator; StripIndex: Integer);
var Res: HResult;
begin
  Res := Direct3DDevice.DrawPrimitive(TD3DPrimitiveType(CPTypes[Tesselator.PrimitiveType]), Tesselator.TesselationStatus[tbVertex].Offset, Tesselator.TotalPrimitives);
  {$IFDEF DEBUGMODE}
  if Res <> D3D_OK then Log(ClassName + '.APIRenderStrip: DrawPrimitive returned "Invalid call" error ', lkError);
  {$ENDIF}
  Inc(FPerfProfile.DrawCalls);
  Inc(FPerfProfile.PrimitivesRendered, Tesselator.TotalPrimitives);
end;

procedure TDX8Renderer.RenderItemBox(Item: TProcessing; Color: BaseTypes.TColor);
var Tess: TTesselator; Mat: TMatrix4s; Temp: TVector3s; DPass: TRenderPass;
begin
  if not IsReady then Exit;
//                * Move to material settings *
  Direct3DDevice.SetRenderState(D3DRS_VERTEXBLEND, 0);
  Direct3DDevice.SetRenderState(D3DRS_COLORVERTEX, 0);
  Direct3DDevice.SetRenderState(D3DRS_AMBIENTMATERIALSOURCE, D3DMCS_MATERIAL);
  Direct3DDevice.SetRenderState(D3DRS_DIFFUSEMATERIALSOURCE, D3DMCS_MATERIAL);

  Mat  := Item.Transform;
  Temp := Transform3Vector3s(CutMatrix3s(Mat), AddVector3s(Item.BoundingBox.P2, Item.BoundingBox.P1));
  Mat._41 := Mat._41 + Temp.X*0.5;
  Mat._42 := Mat._42 + Temp.Y*0.5;
  Mat._43 := Mat._43 + Temp.Z*0.5;

  Temp := SubVector3s(Item.BoundingBox.P2, Item.BoundingBox.P1);
  Mat  := MulMatrix4s(ScaleMatrix4s(Temp.X*0.5, Temp.Y*0.5, Temp.Z*0.5), Mat);

  Direct3DDevice.SetTransform(D3DTS_World, TD3DMatrix(Mat));

  Tess := DebugTesselators[Ord(bvkOOBB)];
  if not Buffers.Put(Tess) then Exit;

  Direct3DDevice.SetVertexShader(TDX8Buffers(APIBuffers).GetFVF(Tess.VertexFormat));
  if Assigned(DebugMaterial) and (DebugMaterial.TotalTechniques > 0) then begin
    DPass := DebugMaterial[0].Passes[0];
    DPass.Ambient  := ColorTo4S(Color);
    DPass.Diffuse  := ColorTo4S(Color);
    DPass.Specular := ColorTo4S(Color);
    APIState.ApplyPass(DPass);
    RenderTesselator(Tess);
  end;
end;

procedure TDX8Renderer.RenderItemDebug(Item: TProcessing);
var CurPass, i: Integer; Tess: TTesselator; Mat: TMatrix4s; Offset: TVector3s;
begin
  if not IsReady then Exit;

//                * Move to material settings *
  Direct3DDevice.SetRenderState(D3DRS_VERTEXBLEND, 0);
  Direct3DDevice.SetRenderState(D3DRS_COLORVERTEX, 0);
  Direct3DDevice.SetRenderState(D3DRS_AMBIENTMATERIALSOURCE,  D3DMCS_MATERIAL);
  Direct3DDevice.SetRenderState(D3DRS_DIFFUSEMATERIALSOURCE,  D3DMCS_MATERIAL);
  Direct3DDevice.SetRenderState(D3DRS_SPECULARMATERIALSOURCE, D3DMCS_MATERIAL);
  DebugMaterial[0].Passes[0].Ambient  := GetColor4S(0, 1, 0, 1);// ColorTo4S(Globals.DebugColor);
  DebugMaterial[0].Passes[0].Diffuse  := GetColor4S(0, 1, 0, 1);// ColorTo4S(Globals.DebugColor);
  DebugMaterial[0].Passes[0].Specular := GetColor4S(0, 1, 0, 1);// ColorTo4S(Globals.DebugColor);

  for i := 0 to Length(Item.Colliding.Volumes)-1 do begin
    Mat := Item.Transform;
    Transform3Vector3s(Offset, CutMatrix3s(Mat), Item.Colliding.Volumes[i].Offset);
    Mat._41 := Mat._41 + Offset.X;
    Mat._42 := Mat._42 + Offset.Y;
    Mat._43 := Mat._43 + Offset.Z;
    Mat := MulMatrix4s(ScaleMatrix4s(Item.Colliding.Volumes[i].Dimensions.X, Item.Colliding.Volumes[i].Dimensions.Y, Item.Colliding.Volumes[i].Dimensions.Z), Mat);

    Direct3DDevice.SetTransform(D3DTS_World, TD3DMatrix(Mat));

    Tess := DebugTesselators[Ord(Item.Colliding.Volumes[i].VolumeKind) * Ord(Ord(Item.Colliding.Volumes[i].VolumeKind) <= High(DebugTesselators))];
    if not Buffers.Put(Tess) then Exit;

    Direct3DDevice.SetVertexShader(TDX8Buffers(APIBuffers).GetFVF(Tess.VertexFormat));
    if Assigned(DebugMaterial) and (DebugMaterial.TotalTechniques > 0) then
      if Assigned(DebugMaterial.Technique[0]) then
        for CurPass := 0 to DebugMaterial[0].TotalPasses-1 do if DebugMaterial[0].Passes[CurPass] <> nil then begin
          APIState.ApplyPass(DebugMaterial[0].Passes[CurPass]);
          RenderTesselator(Tess);
        end;
  end;
end;

procedure TDX8Renderer.Clear(Flags: TClearFlagsSet; Color: BaseTypes.TColor; Z: Single; Stencil: Cardinal);
begin
  if (Flags = []) or not IsReady then Exit;
//  if State = rsTryToRestore then begin RestoreDevice; Exit; end;
  Direct3DDevice.Clear(0, nil, D3DCLEAR_TARGET  * Ord((ClearFrameBuffer in Flags) and Assigned(TDX8StateWrapper(APIState).CurrentRenderTarget)) or
                              (D3DCLEAR_ZBUFFER * Ord(ClearZBuffer in Flags) or
                               D3DCLEAR_STENCIL * Ord(ClearStencilBuffer in Flags)) * Ord(Assigned(TDX8StateWrapper(APIState).CurrentDepthStencil)),
                               Color.C, Z, Stencil);
end;

{ TDX8Textures }

function TDX8Textures.APICreateTexture(Index: Integer): Boolean;
var
  LevelsGenerated: Integer;
  Res: HResult;
begin
  Result := False;
  if not Renderer.IsReady then Exit;
  Res := Direct3DDevice.CreateTexture(FTextures[Index].Width, FTextures[Index].Height, FTextures[Index].Levels, 0, TD3DFormat(PFormats[FTextures[Index].Format]), D3DPOOL_MANAGED, IDirect3DTexture8(FTextures[Index].Texture));

  if Failed(Res) then begin
    Log(ClassName + '.CreateDX8Texture: Error creating texture object: Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    Log(Format('  Call parameters: Dimensions: %Dx%D, Levels: %D, Format: %S', [FTextures[Index].Width, FTextures[Index].Height, FTextures[Index].Levels, PixelFormatToStr(FTextures[Index].Format)]), lkError);
    Exit;
  end;

  LevelsGenerated := IDirect3DTexture8(FTextures[Index].Texture).GetLevelCount;
  if LevelsGenerated <> FTextures[Index].Levels then begin
    Log(Format('%S.CreateDX8Texture: Unexpected number of mipmap levels generated: %D instead of %D', [ClassName, LevelsGenerated, FTextures[Index].Levels]), lkWarning);
    FTextures[Index].Levels := MinI(LevelsGenerated, FTextures[Index].Levels);
  end;

  Result := True;
end;

procedure TDX8Textures.APIDeleteTexture(Index: Integer);
begin
  if Assigned(FTextures[Index].Texture) then IDirect3DTexture8(FTextures[Index].Texture)._Release;
  FTextures[Index].Texture := nil;
end;

procedure TDX8Textures.UnLoad(Index: Integer);
begin
//  inherited;
end;

function TDX8Textures.Update(Index: Integer; Src: Pointer; Rect: BaseTypes.PRect3D): Boolean;
var
  w, h, i, j, k, DataSize, DataOfs: Integer;
  Tex: IDirect3DTexture8;
  LDesc: TD3DSurface_Desc;
  LockedRect: TLockedRectData;
begin
  Result := False;
  if (Index > High(FTextures)) or IsEmpty(FTextures[Index]) then begin
    Log(ClassName + '.Update: Invalid texture index', lkError);
    Exit;
  end;
  if (Src = nil) then Exit;
  if (FTextures[Index].Texture = nil) then if not APICreateTexture(Index) then Exit;

  Tex := IDirect3DTexture8(FTextures[Index].Texture);
  Tex.GetLevelDesc(0, LDesc);
  w := LDesc.Width; h:= LDesc.Height;
  DataOfs := 0;
  for k := 0 to FTextures[Index].Levels-1 do begin
    if not Lock(Index, k, nil, LockedRect, []) then Exit;
//    for i := 0 to w-1 do for j := 0 to h-1 do TDWordBuffer(LockedRect.pBits^)[j*w+i] := TDWordBuffer(Src^)[(j*LDesc.Height div h) * LDesc.Width + (i*LDesc.Width div w)];

    if Rect <> nil then begin                   //    ToDo -cBugfix: only 32bit case
      for i := Rect.Left to Rect.Right do for j := Rect.Top to Rect.Bottom do
        TDWordBuffer(LockedRect.Data^)[j*w+i] :=
          TDWordBuffer(Src^)[(j*Integer(LDesc.Height) div h) * Integer(LDesc.Width) + (i*Integer(LDesc.Width) div w)];
      Rect.Left := Rect.Left div 2;
      Rect.Right := Rect.Right div 2;
      Rect.Top := Rect.Top div 2;
      Rect.Bottom := Rect.Bottom div 2;
    end else begin
      DataSize := w * h * GetBytesPerPixel(FTextures[Index].Format);
      Move(PtrOffs(Src, DataOfs)^, LockedRect.Data^, DataSize);
      Inc(DataOfs, DataSize);
    end;

    Unlock(Index, k);

    w := w shr 1; if w = 0 then w := 1;
    h := h shr 1; if h = 0 then h := 1;
  end;
//  Textures[TextureID].Resource := -1;
  Result := True;
end;

function TDX8Textures.Read(Index: Integer; Dest: Pointer; Rect: BaseTypes.PRect3D): Boolean;
begin
  Result := False;
end;

procedure TDX8Textures.Apply(Stage, Index: Integer);
var Res: HResult;
begin
  if Assigned(FTextures[Index].Texture) or Load(Index) then begin
    Res := Direct3DDevice.SetTexture(Stage, IDirect3DTexture8(FTextures[Index].Texture));
    {$IFDEF DEBUGMODE} if Res <> D3D_OK then Log(Format('TDX8Textures.ApplyTexture: Error setting stage''s %D texture with resource "%S". Error "%S"', [Stage, FTextures[Index].Resource.GetFullName, HResultToStr(Res)]), lkError); {$ENDIF}
  end;  
end;

function TDX8Textures.Lock(AIndex, AMipLevel: Integer; const ARect: BaseTypes.PRect; out LockRectData: TLockedRectData; LockFlags: TLockFlags): Boolean;
var
  LockedRect: TD3DLocked_Rect;
  Res: HResult;
  Tex: IDirect3DTexture8;
  Flags: DWord;
begin
  Result := False;
  if (AIndex > High(FTextures)) or IsEmpty(FTextures[AIndex]) then begin
    Log(ClassName + '.Lock: Invalid texture index (' + IntToStr(AIndex) + ')', lkError);
    Exit;
  end;

  Tex := IDirect3DTexture8(FTextures[AIndex].Texture);
  Flags := 0;
  if lfDiscard     in LockFlags then Flags := Flags or D3DLOCK_DISCARD;
  if lfReadOnly    in LockFlags then Flags := Flags or D3DLOCK_READONLY;
  if lfNoOverwrite in LockFlags then Flags := Flags or D3DLOCK_NOOVERWRITE;

  Res := Tex.LockRect(AMipLevel, LockedRect, @ARect^, Flags);
  if Succeeded(Res) then begin
    LockRectData.Data  := LockedRect.pBits;
    LockRectData.Pitch := LockedRect.Pitch;
    Result := True;
  end else begin
    LockRectData.Data  := nil;
    Log('Error locking texture level # ' + IntToStr(AIndex) + '. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
  end;
end;

procedure TDX8Textures.UnLock(AIndex, AMipLevel: Integer);
var Tex: IDirect3DTexture8;
begin
  if (AIndex > High(FTextures)) or IsEmpty(FTextures[AIndex]) then begin
    Log(ClassName + '.Lock: Invalid texture index (' + IntToStr(AIndex) + ')', lkError);
    Exit;
  end;
  Tex := IDirect3DTexture8(FTextures[AIndex].Texture);
  Tex.UnlockRect(AMipLevel);
end;

end.

