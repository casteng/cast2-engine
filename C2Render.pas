(*
 @Abstract(CAST II Engine render unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains API-independent basic renderer classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Render;

interface

uses
  SysUtils,
  BaseTypes, BaseMsg, Basics, BaseStr, Base3D, OSUtils, Base2D, Resources,
  Logger,
  BaseClasses, ItemMsg, C2Types, CAST2, C2Visual, C2Materials, C2DebugTess, C2Res, C2Msg;

const
  // max X coordinate of window to consider it off-screen
  OffScreenX = -10000;
  // max Y coordinate of window to consider it off-screen
  OffScreenY = -10000;

  // Maximum number of vertex buffer with different vertex sizes
  MaxVertexBuffers = 64;
  // Size of indices
  IndicesSize = 2;

  //                                                                      Dynamic           Static
  // Default sizes of vertex and index buffers for static and dynamic cases. Renderer automatically resizes the buffers when needed.
  DefaultBufferSize: array[Boolean, TTesselationBuffer] of Integer = ((4096*4*32, 4096*4), (4096*32, 4096));
  // Maximum sizes of vertex and index buffers for static and dynamic cases. Static getometry which doesn't fit in a static buffer will not be rendered.
  MaxBufferSize: array[Boolean, TTesselationBuffer] of Integer = ((65536*32, 65536), (65536*32*16, 65536*16));

type
  { Data structure used to represent a locked rectangular area of some data
    Data  - pointer to actual data
    Pitch - offset in bytes between two rows of data }
  TLockedRectData = record
    Data:  Pointer;
    Pitch: Integer;
  end;
  // Renderer states
  TRendererState = (// Renderer is ready
                    rsOK,
                    // Renderer is in process of initialization
                    rsNotReady,
                    // Renderer has lost device and will try to restore it (DirectX-specific)
                    rsLost,
                    // Renderer has not been initialized
                    rsNotInitialized);

{  // Create viewport results
  TViewportCreateResult = (// Success
                           cvOK,
                           // Device has been lost (DirectX-specific)
                           cvLost,
                           // Error occured
                           cvError);}

  // Hardware acceleration level (DirectX only)
  THWAccelLevel = (// Software vertex processing
                  haSoftwareVP,
                  // Mixed vertex processing
                  haMixedVP,
                  // Hardware vertex processing
                  haHardwareVP,
                  // Pure device
                  haPureDevice);

  TAppRequirementsFlag = (// Use stencil buffering
                          arUseStencil,
                          // Use Z-buffering
                          arUseZBuffer,
                          // Forces vertcial syncronization on
                          arForceVSync,
                          // Forces vertcial syncronization off
                          arForceNoVSync,
                          // Tells API that it will be used from several threads
                          arMultithreadedRender,
                          // Tells API to not change FPU state within its routines
                          arPreserveFPU,
                          // Includes modes with all refresh rates in available video modes list
                          arModesUseRefresh,
                          // Tells API that backbuffer contents should not be changed or discarded between frames. May be slow on some configurations.
                          arPreserveBackBuffer,
                          // Tells API that backbuffer should be lockable
                          arLockableBackBuffer);

  { Application requirements record. These values can be changed before renderer initialization to change its behaviour. <br>
    <b>Flags</b>                - <b>[arUseStencil, arUseZBuffer]</b> by default. <br>
    <b>MinYResolution</b>       - minimal vertical resolution of modes to iclude in available video modes list. <b>480</b> by default. <br>
    <b>HWAccelerationLevel</b>  - level of hardware acceleration required. <b>haMixedVP</b> by default. <br>
    <b>TotalBackBuffers</b>     - number of back buffers required. <b>1</b> by default. }
  TAppRequirements = record
    Flags: set of TAppRequirementsFlag;
    MinYResolution: Cardinal;
    HWAccelerationLevel: THWAccelLevel;
    TotalBackBuffers: Cardinal;
  end;

  { Video mode data structure. <br>
    <b>Width, Height</b> - horizontal and vertical resolution. <br>
    <b>RefreshRate</b>   - refresh rate. <br>
    <b>Format</b>        - pixel format. }
  TVideoMode = packed record
    Width, Height: Integer;
    RefreshRate  : Integer;
    Format       : Integer;
  end;
  // Array of video modes
  TVideoModes = array of TVideoMode;

  // Gamma ramp
  TGammaRamp = record
    R, G, B: array[0..255] of Word;
  end;

  // Viewport
  TViewPort = packed record
    X, Y, Width, Height: Longword;
    MinZ, MaxZ: Single;
  end;

  // Texture option flags
  TTextureOptionFlag = (// Texture should be immediately loaded
                        toImmediateLoad,
                        // Texture is not managed by an API [b](currently unsupported)[/b]
                        toNonAPIManaged,
                        // Texture is a cube map [b](currently unsupported)[/b]
                        toCubeMap,
                        // Texture is procedurally generated at runtime
                        toProcedural);
  // Texture option set
  TTextureOptions = set of TTextureOptionFlag;
  // Texture
  TTexture = record
    Texture: Pointer;
    Format : Cardinal;
    Options: TTextureOptions;
    Width, Height, Depth, Levels: Integer;
    LastUseFrame: Integer;
    Resource: TImageResource;
  end;

  // Render target
  TRenderTarget = record
    ColorBuffer, DepthBuffer, ColorTexture, DepthTexture: Pointer;
    ColorFormat, DepthFormat, ActualColorFormat, ActualDepthFormat: Cardinal;
    Width, Height: Integer;
    LastUpdateFrame, LastUseFrame: Integer;
    IsDepthTexture: Boolean;
  end;
  TRenderTargets = array of TRenderTarget;

  // Shader
  TShader = record
    Shader: Integer;                                  // API-specific shader ID
    LastUseFrame: Integer;
    Resource: TShaderResource;
  end;
  TShaders = array of TShader;

  // Renderer errors enumeration type
  TRendererError = (// No error
                    reNone,
                    // Number of texture stages in a pass exceeding renderer capabilities (see @Link(MaxTextureStages))
                    reTooManyStages,
                    // Number of textures used in a pass exceeding renderer capabilities (see @Link(MaxTexturesPerPass))
                    reTooManyTextures,
                    // Vertex shader compilation failed
                    reVertexShaderAssembleFail,
                    // Vertex shader creation failed
                    reVertexShaderCreateFail,
                    // Pixel shader compilation failed
                    rePixelShaderAssembleFail,
                    // Pixel shader creation failed
                    rePixelShaderCreateFail,
                    // Depth textures unsupported
                    reNoDepthTextures);

  TRenderer = class;

  // API-specific vertex and index buffers management class
  TAPIBuffers = class
  protected
    // Reference to renderer object
    Renderer: TRenderer;
  public
    constructor Create(ARenderer: TRenderer);
    destructor Destroy; override;
    // Returns a flexible vrtex format code from CAST vertex format
//    function GetFVF(CastVertexFormat: Cardinal): Cardinal; virtual; abstract;
    { Creates a vertex buffer with the given size in bytes and returns its internal index or -1 if creation fails.
      If <b>Static</b> is <b>False</b> the buffer will be optimized to store dynamic geometry. }
    function CreateVertexBuffer(Size: Integer; Static: Boolean): Integer; virtual; abstract;
    { Creates an index buffer with the given size in bytes and returns its internal index or -1 if creation fails
      If <b>Static</b> is <b>False</b> the buffer will be optimized to store dynamic data. }
    function CreateIndexBuffer(Size: Integer; Static: Boolean): Integer; virtual; abstract;
    // Changes size of the given vertex buffer to the given size and returns <b>True</b> if success
    function ResizeVertexBuffer(Index: Integer; NewSize: Integer): Boolean; virtual; abstract;
    // Changes size of the given index buffer to the given size and returns <b>True</b> if success
    function ResizeIndexBuffer(Index: Integer; NewSize: Integer): Boolean; virtual; abstract;
    { Locks the given range in a vertex buffer with the given index and returns a write-only pointer to the range data or <b>nil</b> if lock fails.
      If <b>DiscardExisting</b> is <b>True</b> existing data in the buffer will be discarded to avoid stalls. }
    function LockVertexBuffer(Index: Integer; Offset, Size: Integer; DiscardExisting: Boolean): Pointer; virtual; abstract;
    { Locks the given range in a index buffer with the given index and returns a write-only pointer to the range data or <b>nil</b> if lock fails.
      If <b>DiscardExisting</b> is <b>True</b> existing data in the buffer will be discarded to avoid stalls. }
    function LockIndexBuffer(Index: Integer; Offset, Size: Integer; DiscardExisting: Boolean): Pointer; virtual; abstract;
    // Unlocks a previously locked vertex buffer
    procedure UnlockVertexBuffer(Index: Integer); virtual; abstract;
    // Unlocks a previously locked index buffer
    procedure UnlockIndexBuffer(Index: Integer); virtual; abstract;
    // Attaches a vertex buffer to the specified data stream and returns <b>True</b> if success. <b>VertexSize</b> should match the size of the data in the buffer.
    function AttachVertexBuffer(Index, StreamIndex: Integer; VertexSize: Integer): Boolean; virtual; abstract;
    // Attaches an index buffer and returns <b>True</b> if success. <b>StartingVertex</b> will be added to all indices read from the index buffer.
    function AttachIndexBuffer(Index: Integer; StartingVertex: Integer): Boolean; virtual; abstract;
    // Frees all allocated buffers. All internal indices returned before this call become invalid.
    procedure Clear; virtual; abstract;
  end;

  // API-independent buffer structure
  TBuffer = record
    Index, Size: Integer;
    Position: Integer;
    ResetCounter: Integer;
  end;
  // API independent vertex and index buffers management class
  TBuffers = class
  private
    Buffers: array[TTesselationBuffer, Boolean, 0..MaxVertexBuffers-1] of TBuffer;
    ResetCounter: Integer;
    Renderer: TRenderer;
    procedure ResetBuffers;
  public
    constructor Create(ARenderer: TRenderer);
    destructor Destroy; override;
    // Puts the given tesselator to an appropriate buffer pair
    function Put(Tesselator: TTesselator): Boolean;
    // Clears and reallocates all allocated buffers
    procedure Reset;
  end;

  TTextureArray = array of TTexture;

  TTextures = class
  private
  protected
    Renderer: TRenderer;
    FTextures: TTextureArray;
    // Returns <b>True</b> if the specified texture is not initialized
    function IsEmpty(const Element: TTexture): Boolean;
    // Deletes all textures
    procedure FreeAll;
    // Calls an API to create API-specific texture object 
    function APICreateTexture(Index: Integer): Boolean; virtual; abstract;
    // Calls an API to destroy API-specific texture object
    procedure APIDeleteTexture(Index: Integer); virtual; abstract;
  public
    destructor Destroy; override;
    // Handles some related messages
    procedure HandleMessage(const Msg: TMessage);
    // Adds a new texture entry. Does not create any API-specific objects.
    function NewTexture(Resource: TImageResource; Options: TTextureOptions): Integer;
    // Adds a new procedural texture entry. Does not create any API-specific objects.
    function NewProceduralTexture(AFormat: Cardinal; AWidth, AHeight, ADepth, ALevels: Integer; Options: TTextureOptions): Integer;
    // Loads the specified by index texture from its associated resource. Returns <b>True</b> if success.
    function Load(Index: Integer): Boolean;
    // Unloads the specified by index texture from API. <b>Currently not implemented.</b>
    procedure Unload(Index: Integer); virtual; abstract;
    // Updates the specified rectangle of the specified by index texture in API from the given pointer. Returns <b>True</b> if success.
    function Update(Index: Integer; Src: Pointer; Rect: BaseTypes.PRect3D): Boolean; virtual; abstract;
    // Reads the specified rectangle of the specified by index texture in API to the given pointer. Returns <b>True</b> if success. <b>Currently not implemented.</b>
    function Read(Index: Integer; Dest: Pointer; Rect: BaseTypes.PRect3D): Boolean; virtual; abstract;
    // Removes the specified texture
    procedure Delete(Index: Integer); 
    // Resolves a texture for the given pass. Used internally.
    function Resolve(Pass: TRenderPass; StageIndex: Integer): Boolean;
    // Applies texture with the specified index to the specified API stage
    procedure Apply(Stage, Index: Integer); virtual; abstract;
    // Locks the specified area of the specified level of the specified texture. This call should be accompanied by a corresponding @Link(Unlock) call.
    function Lock(AIndex, AMipLevel: Integer; const ARect: BaseTypes.PRect; out LockRectData: TLockedRectData; LockFlags: TLockFlags): Boolean; virtual; abstract;
    // Unlocks previously locked texture
    procedure UnLock(AIndex, AMipLevel: Integer); virtual; abstract;
  end;

  // API-dependent class which wraps render state
  TAPIStateWrapper = class
  private
    DefaultCamera: TCamera;
    function NewRenderTarget(const Camera: TCamera): Integer;
    function CreateShader(var Shaders: TShaders; Item: TShaderResource): Integer;
    procedure RemoveRenderTarget(Index: Integer);
  protected
    // Reference to renderer
    Renderer: TRenderer;
    // Last renderer error. Used for pass validation.
    LastError: TRendererError;
    //    TotalTextures: Integer;
    // Render targets
    FRenderTargets: TRenderTargets;
    // Shaders
//      public                 // ToFix: make it protected
        FVertexShaders, FPixelShaders: TShaders;
      protected

    // Current camera (same as Renderer.@Link(LastAppliedCamera))
    Camera: CAST2.TCamera;
    // True if texture matrix was set for a certain stage
    StageMatrixSet: array[0..7] of Boolean;
    // Clip planes state
    ClipPlanesState: Cardinal;

    // Performance profile
    FPerfProfile: TPerfProfile;

    // Returns <b>True</b> if the specified render target is not initialized
    function IsRenderTargetEmpty(const Element: TRenderTarget): Boolean;
    // Returns <b>True</b> if the specified shader is not initialized
    function IsShaderEmpty(const Element: TShader): Boolean;

    // Calls an API to create a render target with given parameters. DepthStencil surface will be created if <b>ADepthFormat</b> is other than @Link(pfUndefined). Returns <b>True</b> if success.
    function APICreateRenderTarget(Index, Width, Height: Integer; AColorFormat, ADepthFormat: Cardinal): Boolean; virtual; abstract;
    // Ensures that all parameters are correct and supported and calls @Link(APICreateRenderTarget). Returns <b>True</b> if a render target been created.
    function CreateRenderTarget(Index, Width, Height: Integer; AColorFormat, ADepthFormat: Cardinal; ADepthTexture: Boolean): Boolean;
    // Destroys the specified by index render target
    procedure DestroyRenderTarget(Index: Integer); virtual; abstract;
      public        // ToFix: make it protected
        // Return a render target for the given camera. If render target does not exists the function creates it.
        function FindRenderTarget(const ACamera: TCamera): Integer;
        // Returns <b>True</b> if there is no need to update render target texture associated with Camera
        function IsRenderTargetUptoDate(const ACamera: TCamera): Boolean;
      protected
    // Sets current render target to the one associated with <b>Camera</b>. Returns <b>True</b> if actual change was made.
    function SetRenderTarget(const ACamera: TCamera; TextureTarget: Boolean): Boolean; virtual; abstract;

//      public        // ToFix: make it protected
        // Resolves a vertex shader for the given pass. Used internally.
        function ResolveVertexShader(Pass: TRenderPass): Boolean;
      protected
    // Resolves a pixel shader for the given pass. Used internally.
    function ResolvePixelShader(Pass: TRenderPass): Boolean;
    // Creates a vertex shader from the resource with the given vertex declaration
    function CreateVertexShader(Item: TShaderResource; Declaration: TVertexDeclaration): Integer; virtual;    // ToFix: remove virtual
    // Creates a pixel shader from the resource
    function CreatePixelShader(Item: TShaderResource): Integer; virtual;
    // Destroys the specified by index vertex shader
    procedure APIDestroyVertexShader(Index: Integer); virtual; abstract;
    // Destroys the specified by index pixel shader
    procedure APIDestroyPixelShader(Index: Integer); virtual; abstract;

    // Calls an API to set a shader constant
    procedure APISetShaderConstant(const Constant: TShaderConstant); overload; virtual; abstract;
    // Calls an API to set a shader constant. <b>ShaderKind</b> - kind of shader, <b>ShaderRegister</b> - index of 4-component vector register to set, <b>Vector</b> - new value of the register.
    procedure APISetShaderConstant(ShaderKind: TShaderKind; ShaderRegister: Integer; const Vector: TShaderRegisterType); overload; virtual; abstract;

    { Calls an API to validate the specified pass. Returns <b>True</b> if the pass is can be handled by current hardware.
      Otherwise returns <b>False</b> and fills <b>ResultStr</b> a text representation of the error occured. }
    function APIValidatePass(const Pass: TRenderPass; out ResultStr: string): Boolean; virtual; abstract;

    // Applies texture matrix of each texture stage of the specified render pass
    procedure ApplyTextureMatrices(const Pass: TRenderPass); virtual; abstract;
    // Applies current clipping planes
    procedure ApplyClipPlanes;

    // Handle removal or replace of some item from scene
    procedure HandleItemReplace(OldItem, NewItem: TItem); virtual;
    // Handle data change of renderer-related items
    procedure HandleDataChange(Data: Pointer); virtual;
  public
    // Vertex shader usage flag. Used internally.
    VertexShaderFlag,
    // Pixel shader usage flag. Used internally.
    PixelShaderFlag: Boolean;
    constructor Create;
    destructor Destroy; override;

    // Handles some related messages
    procedure HandleMessage(const Msg: TMessage);

    // Sets fog kind, color, start/end and density
    procedure SetFog(Kind: Cardinal; Color: BaseTypes.TColor; AFogStart, AFogEnd, ADensity: Single); virtual; abstract;
    // Sets alpha blending mode and alpha test settings
    procedure SetBlending(Enabled: Boolean; SrcBlend, DestBlend, AlphaRef, ATestFunc, Operation: Integer); virtual; abstract;
    // Sets Z-buffer related values
    procedure SetZBuffer(ZTestFunc, ZBias: Integer; ZWrite: Boolean); virtual; abstract;
    // Sets culling, shading and filling modes as well as color write mask
    procedure SetCullAndFillMode(FillMode, ShadeMode, CullMode: Integer; ColorMask: Cardinal); virtual; abstract;
    // Sets stencil state
    procedure SetStencilState(SFailOp, ZFailOp, PassOp, STestFunc: Integer); virtual; abstract;
    // Sets stencil reference value and masks
    procedure SetStencilValues(SRef, SMask, SWriteMask: Integer); virtual; abstract;
    // Sets texture wrapping mode
    procedure SetTextureWrap(const CoordSet: TTWrapCoordSet); virtual; abstract;
    // Set lighting settings
    procedure SetLighting(Enable: Boolean; AAmbient: BaseTypes.TColor; SpecularMode: Integer; NormalizeNormals: Boolean); virtual; abstract;
    // Sets edge and points settings
    procedure SetEdgePoint(PointSprite, PointScale, EdgeAntialias: Boolean); virtual; abstract;
    // Sets texture factor color
    procedure SetTextureFactor(ATextureFactor: BaseTypes.TColor); virtual; abstract;
    // Sets API-level material (ambient, diffuse, specular and emissive colors and specular power)
    procedure SetMaterial(const AAmbient, ADiffuse, ASpecular, AEmissive: BaseTypes.TColor4S; APower: Single); virtual; abstract;
    // Sets points size parameters
    procedure SetPointValues(APointSize, AMinPointSize, AMaxPointSize, APointScaleA, APointScaleB, APointScaleC: Single); virtual; abstract;
    // Sets line pattern
    procedure SetLinePattern(ALinePattern: Longword); virtual; abstract;

    // Applies a clipping plane
    procedure SetClipPlane(Index: Cardinal; Plane: PPlane); virtual; abstract;

    // Sets a shader constant
    procedure SetShaderConstant(const Constant: TShaderConstant); overload;
    // Sets a shader constant. <b>ShaderKind</b> - kind of shader, <b>ShaderRegister</b> - index of 4-component vector register to set, <b>Vector</b> - new value of the register.
    procedure SetShaderConstant(ShaderKind: TShaderKind; ShaderRegister: Integer; const Vector: TShaderRegisterType); overload;

    // Validate the specified pass. Returns <b>True</b> if the pass is valid
    function ValidatePass(const Pass: TRenderPass): Boolean;

    // Applies the specified render pass
    procedure ApplyPass(const Pass: TRenderPass); virtual; abstract;
    // Applies item-specific custom texture matrix of each texture stage of the specified render pass
    procedure ApplyCustomTextureMatrices(const Pass: TRenderPass; Item: TVisible); virtual; abstract;
  end;

  { @Abstract(Renderer class)
    Contains API-independent routines and an interface fo API-dependent ones }
  TRenderer = class(TSubsystem)
  private
    procedure SetDebugOutput(const Value: Boolean);
    function GetAdapterName(Index: Cardinal): string;
    function GetVideoMode(Index: Cardinal): TVideoMode;

    function GetRenderTargetsAllocated: Integer;
  protected
    // This record passed to tesselators buffer filling methods
    TesselationParams: TTesselationParameters;
    // Performance profile
    FPerfProfile: TPerfProfile;
    // Number of frames rendered
    FFramesRendered: Integer;

    // API-specific buffer management object
    APIBuffers: TAPIBuffers;
    // API-independent buffer management object
    Buffers: TBuffers;

    // Reference to items manager
    Manager: TItemsManager;

    // Current video adapter
    FCurrentAdapter,
    // Number of video adapters in system
    FTotalAdapters: Cardinal;
    // Names of video adapters in system
    FAdapterNames: array of string;

    // Current video mode index in @Link(FVideoModes) array
    FCurrentVideoMode,
    // Number of video modes available
    FTotalVideoModes: Cardinal;
    // Video modes available
    FVideoModes: TVideoModes;
    // Current desktop video mde
    DesktopVideoMode: TVideoMode;

    // Handle of render window
    RenderWindowHandle: Cardinal;
    // Current viewport
    ViewPort: TViewPort;
    // Full screen mode state
    FFullScreen,
    // Debug output state
    FDebugOutput: Boolean;

    // Tesselators for primitives used in debug rendering
    DebugTesselators: array of TTesselator;
    // Material for debug rendering
    DebugMaterial: TMaterial;

    // Last applied camera
    FLastAppliedCamera,
    // Top-level camera through which a scene is visible for user
    FMainCamera: CAST2.TCamera;
    // Last applied camera view matrix
    FLastAppliedCameraMatrix: TMatrix4s;
    // Current gamma ramp
    GammaRamp: TGammaRamp;

    // Current renderer state
    FState: TRendererState;
    // Current depth of Z-buffer
    FCurrentZBufferDepth: Cardinal;

    // Rendering area in windowed mode
    FWindowedRect: TRect;
    // Window style in not full-screen mode
    FNormalWindowStyle: Cardinal;

    // For internal use only
    procedure InternalInit;
    // For internal use only
    procedure InternalDeInit; virtual;
    // For internal use only
    function InternalGetIndexBufferIndex(Static: Boolean; BufferIndex: Integer): Integer; {$I inline.inc}
    // For internal use only
    function InternalGetVertexBufferIndex(Static: Boolean; BufferIndex: Integer): Integer; {$I inline.inc}
    // Calls an API to initialize render device for rendering to the specified window or specified video mode
    function APICreateDevice(WindowHandle, AVideoMode: Cardinal; AFullScreen: Boolean): Boolean; virtual; abstract;

    // Calls an API to set item's transformation, some FVF-related states
    procedure APIPrepareFVFStates(Item: TVisible); virtual; abstract;

    // Calls an API to apply the specified camera
    procedure APIApplyCamera(Camera: CAST2.TCamera); virtual; abstract;

    { Returns <b>True</b> if a pixel format is available and can be used as a texture, render target or depth-stencil buffer.
      <b>RTFormat</b> is used only with depth-stencil usage to determine whether the supported depth-stencil format can be used with the given render target format. }
    function APICheckFormat(const Format, Usage, RTFormat: Cardinal): Boolean; virtual; abstract;
    // Returns CAST pixel format from an API-specific one
    function APIToPixelFormat(Format: Cardinal): Cardinal;
    // Toggles fullscreen mode
    procedure SetFullScreen(const FScreen: Boolean); virtual;
    // Prepares render window for windowed rendering
    function PrepareWindow: Boolean;
  public
    // Renderer performs rendering only if this variable is <b>True</b>. <b>Active</b> is set automatically in response on window minimization or switching to another application in fullscreen mode.
    Active: Boolean;
    // Current render window width
    RenderWidth,
    // Current render window height
    RenderHeight: Integer;
    // If set to True data existing in vertex/index buffers are always considered as valid and no tesselation will be performed
    DisableTesselation: Boolean;

    // Application requirements record. These values can be changed before renderer initialization to change its behaviour.
    AppRequirements: TAppRequirements;

      // Capabilites
    // Maximum number of light sources simultaneously handled by hardware T&L (fixed function pipeline only)
    MaxHardwareLights,
    // Maximum number of light sources which may be simultaneously set through API
    MaxAPILights: Cardinal;
    // Maximum supported texture width
    MaxTextureWidth,
    // Maximum supported texture height
    MaxTextureHeight: Integer;
    // Maximum number of textures which may be used in a pass
    MaxTexturesPerPass,
    // Maximum number of texture stages which may be used in a pass (fixed function pipeline)
    MaxTextureStages: Integer;
    // Maximum number of primitives per single API call (DIP)
    MaxPrimitiveCount,
    // Maximum index value in index buffer
    MaxVertexIndex: Integer;
    // Maximum number of user clipping planes
    MaxClipPlanes: Integer;
    // <b>True</b> if even transformed vertices are clipped by hardware (DirectX only, seems incorrect)
    HardwareClipping,
    // <b>True</b> if w-buffering is supported
    WBuffering,
    // <b>True</b> if only power of two-sized textures are supported
    Power2Textures,
    // <b>True</b> if only square textures are supported
    SquareTextures,
    // <b>True</b> if depth textures are supported
    DepthTextures: Boolean;
    // Maximum point size
    MaxPointSize: Single;

    // Major vertex shader version
    VertexShaderVersionMajor,
    // Minor vertex shader version
    VertexShaderVersionMinor,
    // Major pixel shader version
    PixelShaderVersionMajor,
    // Minor pixel shader version
    PixelShaderVersionMinor: Integer;
    // Max vertex shader constants
    MaxVertexShaderConsts: Integer;

    // Textures
    Textures: TTextures;
    // Reference to API state wrapper object
    APIState: TAPIStateWrapper;
    // Bias matrix used to remap texture coordinates for mirror and shadow map modes
    BiasMat: TMatrix4s;
    constructor Create(AManager: TItemsManager); virtual;
    destructor Destroy; override;
    // Sets performance profile
    procedure SetPerfProfile(APerfProfile: TPerfProfile); virtual;

    // Sets video adapter
    procedure SetVideoAdapter(Adapter: Cardinal);
    // Build available video modes list
    procedure BuildModeList; virtual; abstract;    {$MESSAGE 'TODO: Move here from descendant'}
    // Initializes debug tesselators and material
    procedure InitDebugRender(ADebugMaterial: TMaterial); virtual;
    // Returns <b>True</b> if the renderer is ready to render
    function IsReady: Boolean;

    // Adjusts gamma ramp
    procedure SetGamma(Gamma, Contrast, Brightness: Single); virtual;

    // Default message handling
    procedure HandleMessage(const Msg: TMessage); override;

    // Checks capabilities
    procedure CheckCaps; virtual; abstract;
    // Checks available texture formats
    procedure CheckTextureFormats; virtual; abstract;
    { Checks if the given pixel format is supported for the given usage. RTFormat is used only with depth-stencil
      usage to determine whether the supported depth-stencil format can be used with the given render target format.
      Returns False if the pixel format is unsupported. Also fills NewFormat with suggested substitue or with pfUndefined if no suitable substitution found. }
    function CheckFormat(const Format, Usage, RTFormat: Cardinal; out NewFormat: Cardinal): Boolean; virtual;

    // Validates all techniques of the given material for current hardware configuration. Returns <b>True</b> if the set of available techniques changed during validation.
    function ValidateMaterial(const Material: TMaterial): Boolean;

    // Initializes render device to render to the specified window or specified mode
    function CreateDevice(WindowHandle, AVideoMode: Cardinal; AFullScreen: Boolean): Boolean;
    // Restores render device with the specified video mode (if fullscreen)
    function RestoreDevice(AVideoMode: Cardinal; AFullScreen: Boolean): Boolean; virtual;

    // Starts a rendering cycle
    procedure StartFrame; virtual;
    // Ends a rendering cycle
    procedure FinishFrame; virtual; abstract;

    // Clear the specified parts of current render target with the specified values
    procedure Clear(Flags: TClearFlagsSet; Color: BaseTypes.TColor; Z: Single; Stencil: Cardinal); virtual; abstract;

    // Apply a light source with the specified index
    procedure ApplyLight(Index: Integer; const ALight: TLight); virtual; abstract;

    // Applies render target settings, transformations, clear settings of the given camera to the renderer
    procedure ApplyCamera(Camera: CAST2.TCamera); 

    // Projects <b>Vector</b> with @Link(MainCamera) and returns the result in <b>Projected</b>
    procedure ProjectToScreen(out Projected: TVector4s; const Vector: TVector3s);

    // Sets render viewport
    procedure SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single); virtual;

    // Performs necessary API calls to render a piece of triangles
    procedure APIRenderStrip(Tesselator: TTesselator; StripIndex: Integer); virtual; abstract;
    // Performs necessary API calls to render a piece of indexed triangles
    procedure APIRenderIndexedStrip(Tesselator: TTesselator; StripIndex: Integer); virtual; abstract;
    // Renders the specified tesselator
    procedure RenderTesselator(Tesselator: TTesselator);
    // Ensures that vertex/index buffers contains an up-to-date representation of the specified item, calls @Link(APIPrepareItem()) and renders it's tesselator
    procedure RenderItem(Item: TVisible);
    // Renders item's bounding box
    procedure RenderItemBox(Item: CAST2.TProcessing; Color: BaseTypes.TColor); virtual; abstract;
    // Renders item's debug information (currently colliding volumes if present)
    procedure RenderItemDebug(Item: CAST2.TProcessing); virtual; abstract;
    

    // Full screen mode state
    property FullScreen: Boolean read FFullScreen write SetFullScreen;
    // Debug output state
    property DebugOutput: Boolean read FDebugOutput write SetDebugOutput;

    // Number of frames rendered
    property FramesRendered: Integer read FFramesRendered;

    // Camera through which a scene is rendered. Can't be changed during frame visulization.
    property MainCamera:   CAST2.TCamera read FMainCamera write FMainCamera;
    // Currently applyed camera. May change during frame visulization (if render to texture used).
    property LastAppliedCamera: CAST2.TCamera read FLastAppliedCamera;

    // Number of video adapters in system
    property TotalAdapters: Cardinal read FTotalAdapters;
    // Current video adapter
    property CurrentAdapter: Cardinal read FCurrentAdapter;
    // Names of video adapters in system by index
    property AdapterName[Index: Cardinal]: string read GetAdapterName;

    // Number of video modes available
    property TotalVideoModes: Cardinal read FTotalVideoModes;
    // Current video mode index in @Link(FVideoModes) array
    property CurrentVideoMode: Cardinal read FCurrentVideoMode;
    // Video modes available by index
    property VideoMode[Index: Cardinal]: TVideoMode read GetVideoMode;

    // Current renderer state
    property State: TRendererState read FState;
    // Rendering area in windowed mode
    property WindowedRect: TRect read FWindowedRect;
    // Current depth of Z-buffer
    property CurrentZBufferDepth: Cardinal read FCurrentZBufferDepth;
    // Additional render targets currently allocated
    property TotalRenderTargets: Integer read GetRenderTargetsAllocated;
  end;

implementation

const
  // Debug tesselator indices
  dtiBox = 0; dtiSphere = 1;

type
  TRenderTargetEmptyDelegate = function(const Element: TRenderTarget): Boolean of object;
  TTextureEmptyDelegate      = function(const Element: TTexture): Boolean of object;
  TShaderEmptyDelegate       = function(const Element: TShader): Boolean of object;

function ResourceAdd_RenderTarget(var Elements: TRenderTargets; IsEmpty: TRenderTargetEmptyDelegate): Integer;
begin {$Include C2RenderResourceAdd.Inc} end;

function ResourceAdd_Texture(var Elements: TTextureArray; IsEmpty: TTextureEmptyDelegate): Integer;
begin {$Include C2RenderResourceAdd.Inc} end;

function ResourceAdd_Shader(var Elements: TShaders; IsEmpty: TShaderEmptyDelegate): Integer;
begin {$Include C2RenderResourceAdd.Inc} end;

{ TAPIBuffers }

constructor TAPIBuffers.Create(ARenderer: TRenderer);
begin
  Renderer := ARenderer;
end;

destructor TAPIBuffers.Destroy;
begin
  Clear;
  inherited;
end;

{ TBuffers }

procedure TBuffers.ResetBuffers;
var i: TTesselationBuffer; j: Integer;
begin
  for i := Low(TTesselationBuffer) to High(TTesselationBuffer) do for j := 0 to High(Buffers[i, True]) do begin
    Buffers[i, False, j].Index        :=-1;
    Buffers[i, False, j].Size         := 0;
    Buffers[i, False, j].Position     := 0;
    Buffers[i, False, j].ResetCounter := 0;

    Buffers[i, True, j].Index        :=-1;
    Buffers[i, True, j].Size         := 0;
    Buffers[i, True, j].Position     := 0;
    Buffers[i, True, j].ResetCounter := 0;
  end;
end;

constructor TBuffers.Create(ARenderer: TRenderer);
begin
  ResetCounter := 1;
  Renderer := ARenderer;
  ResetBuffers;
end;

destructor TBuffers.Destroy;
begin
//  Reset;
  inherited;
end;

function TBuffers.Put(Tesselator: TTesselator): Boolean;
const
  BufName: array[TTesselationBuffer] of string[6] = ('vertex',  'index');
  BufTypeName: array[Boolean]        of string[7] = ('dynamic', 'static');
var
  TesselatorMaxAmount, ElementSize: array[TTesselationBuffer] of Integer;
  PTR: PByte; BufIndex, Amount: Integer;

  function PutIntoBuffer(BufferType: TTesselationBuffer; Static: Boolean): Boolean;

    procedure ResetAndPlaceFirst;
    begin
      Buffers[BufferType, Static, BufIndex].Position := TesselatorMaxAmount[BufferType];    // Increase by max amount of elements
      Inc(Buffers[BufferType, Static, BufIndex].ResetCounter);
      Tesselator.TesselationStatus[BufferType].Offset := 0;
      Tesselator.TesselationStatus[BufferType].LastResetCounter := ResetCounter;
      Tesselator.TesselationStatus[BufferType].LastBufferResetCounter := Buffers[BufferType, Static, BufIndex].ResetCounter;
      Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].BufferResetsCount[Static]);
    end;

    function CreateBuffer: Boolean;
    begin
      case BufferType of
        tbVertex: Buffers[BufferType, Static, BufIndex].Index := Renderer.APIBuffers.CreateVertexBuffer(Buffers[BufferType, Static, BufIndex].Size, Static);
        tbIndex:  Buffers[BufferType, Static, BufIndex].Index := Renderer.APIBuffers.CreateIndexBuffer( Buffers[BufferType, Static, BufIndex].Size, Static);
      end;
      Result := Buffers[BufferType, Static, BufIndex].Index <> -1;
      if Result then Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].BufferSize[Static], Buffers[BufferType, Static, BufIndex].Size);
    end;

    function ResizeBuffer(NewBufferSize: Integer): Boolean;
    begin
      Result := False;
      case BufferType of
        tbVertex: Result := Renderer.APIBuffers.ResizeVertexBuffer(Buffers[BufferType, Static, BufIndex].Index, NewBufferSize);
        tbIndex:  Result := Renderer.APIBuffers.ResizeIndexBuffer( Buffers[BufferType, Static, BufIndex].Index, NewBufferSize);
      end;
      if Result then begin
        Dec(Renderer.FPerfProfile.BuffersProfile[BufferType].BufferSize[Static], Buffers[BufferType, Static, BufIndex].Size);
        Buffers[BufferType, Static, BufIndex].Size := NewBufferSize;
        Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].BufferSize[Static], Buffers[BufferType, Static, BufIndex].Size);
      end;
    end;

  var Discard: Boolean; NewSize: Integer;
  begin
    Result := True;
    // Check if tesselation not needed
    if ( Static and                                                                    // not needed for dynamic buffers
         (Tesselator.TesselationStatus[BufferType].Status = tsTesselated) and
         (Renderer.DisableTesselation or (Tesselator.GetUpdatedElements(BufferType, Renderer.TesselationParams) = 0)) and
         (Tesselator.TesselationStatus[BufferType].LastResetCounter >= ResetCounter) and
         (Tesselator.TesselationStatus[BufferType].LastBufferResetCounter >= Buffers[BufferType, Static, BufIndex].ResetCounter) ) then begin
         Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].TesselationsBypassed);
         Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].BytesBypassed, TesselatorMaxAmount[BufferType] * ElementSize[BufferType]);
         Exit;
       end;

    Result := False;

    // Check if the tesselator never tesselated since last reset/discard or changed its size
    if not Static or
       (Tesselator.TesselationStatus[BufferType].Status = tsMaxSizeChanged) or
       (Tesselator.TesselationStatus[BufferType].LastResetCounter < ResetCounter) or
       (Tesselator.TesselationStatus[BufferType].LastBufferResetCounter < Buffers[BufferType, Static, BufIndex].ResetCounter) then begin

      if Static and (Tesselator.TesselationStatus[BufferType].Status = tsMaxSizeChanged) then begin
        {$IFDEF DEBUGMODE}
        Log('TBuffers.Put: A size-changing tesselator "' + Tesselator.ClassName + '" placed in a static buffer. Discarding buffer contents...', lkWarning);
        {$ENDIF}
        ResetAndPlaceFirst;
        Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].TesselationsPerformed[Static]);
      end else begin
        Tesselator.TesselationStatus[BufferType].Offset           := Buffers[BufferType, Static, BufIndex].Position;
        Tesselator.TesselationStatus[BufferType].LastResetCounter := ResetCounter;
        Tesselator.TesselationStatus[BufferType].LastBufferResetCounter := Buffers[BufferType, Static, BufIndex].ResetCounter;
        Inc(Buffers[BufferType, Static, BufIndex].Position, TesselatorMaxAmount[BufferType]);                 // Increase by max amount of elements
        Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].TesselationsPerformed[Static]);
      end;
    end;

    // Allocate a buffer if needed
    if Buffers[BufferType, Static, BufIndex].Index = -1 then begin
      Buffers[BufferType, Static, BufIndex].Size := MaxI(DefaultBufferSize[Static, BufferType], TesselatorMaxAmount[BufferType]) * ElementSize[BufferType];
      if not CreateBuffer then Exit;
    end;

    Discard := False;

    // Check buffer size and remaining space
    if ((Tesselator.TesselationStatus[BufferType].Offset + TesselatorMaxAmount[BufferType]) * ElementSize[BufferType] > Buffers[BufferType, Static, BufIndex].Size) then
      if Static or (TesselatorMaxAmount[BufferType] * ElementSize[BufferType] > Buffers[BufferType, Static, BufIndex].Size) then begin
        // Resize buffer
        NewSize := (Tesselator.TesselationStatus[BufferType].Offset * Ord(Static) + TesselatorMaxAmount[BufferType]) * ElementSize[BufferType];
        Log(Format('TBuffers.Put: Insufficient %S %S buffer size: Buffer: [%D], will try to resize to %D',
                       [BufTypeName[Static], BufName[BufferType], Buffers[BufferType, Static, BufIndex].Size,
                         NewSize]), lkNotice);

        if NewSize <= MaxBufferSize[Static, BufferType] * ElementSize[BufferType] then begin
          if not ResizeBuffer(NewSize) then Exit;
          ResetAndPlaceFirst;
        end else begin
          Log(Format('TBuffers.Put: Resize failed: Maximum %S %S buffer size reached: [%D], needed: [%D]',
                         [BufTypeName[Static], BufName[BufferType], MaxBufferSize[Static, BufferType] * ElementSize[BufferType], NewSize]), lkError);
          Exit;
        end;
      end else begin
        // Reset buffer to beginning
        Discard := True;
        ResetAndPlaceFirst;
      end;

    // Lock and tesselate
    case BufferType of
      tbVertex: begin
//        Log('*** VB lock ***', lkDebug);
        PTR := Renderer.APIBuffers.LockVertexBuffer(Buffers[BufferType, Static, BufIndex].Index,
                                                    Tesselator.TesselationStatus[BufferType].Offset * ElementSize[BufferType],
                                                    TesselatorMaxAmount[BufferType] * ElementSize[BufferType],
                                                    Discard);
        if PTR = nil then Exit;

        Amount := Tesselator.Tesselate(Renderer.TesselationParams, PTR);
        Renderer.APIBuffers.UnlockVertexBuffer(Buffers[BufferType, Static, BufIndex].Index);

        Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].BytesWritten[Static], Amount * ElementSize[BufferType]);
//        Log('*** VB unlock ***', lkdebug);
        Assert(Amount <= TesselatorMaxAmount[BufferType], Format('TBuffers.Put: Tesselated amount %D is greater then maximal %D', [Amount, TesselatorMaxAmount[BufferType]]));
      end;
      tbIndex: begin
//        Log('*** IB lock ***', lkdebug);
        PTR := Renderer.APIBuffers.LockIndexBuffer(Buffers[BufferType, Static, BufIndex].Index,
                                                   Tesselator.TesselationStatus[BufferType].Offset * ElementSize[BufferType],
                                                   TesselatorMaxAmount[BufferType] * ElementSize[BufferType],
                                                   Discard);
        if PTR = nil then Exit;
        Amount := Tesselator.SetIndices(PTR);
        TesselatorMaxAmount[BufferType] := Amount;
        Renderer.APIBuffers.UnlockIndexBuffer(Buffers[BufferType, Static, BufIndex].Index);
//        Log('*** IB unlock ***', lkdebug);
      end;
    end;
    Inc(Renderer.FPerfProfile.BuffersProfile[BufferType].BytesWritten[Static], Amount * ElementSize[BufferType]);

    Result := TesselatorMaxAmount[BufferType] <> 0;
  end;

var i: TTesselationBuffer;

begin
  Tesselator.TesselationStatus[tbVertex].BufferIndex := Tesselator.VertexSize div 4;
  Tesselator.TesselationStatus[tbIndex].BufferIndex  := 0;//Tesselator.IndexSize div 2-1;

  ElementSize[tbVertex] := Tesselator.VertexSize;
  ElementSize[tbIndex]  := IndicesSize;

  for i := Low(TTesselationBuffer) to High(TTesselationBuffer) do begin
    BufIndex := Tesselator.TesselationStatus[i].BufferIndex;
    TesselatorMaxAmount[i] := Tesselator.GetMaxAmount(i);

    if TesselatorMaxAmount[i] <> 0 then
      Result := PutIntoBuffer(i, Tesselator.TesselationStatus[i].TesselatorType = ttStatic)
    else
      Result := (i <> tbVertex);                      // No vertices

    if not Result then Break;
  end;

  if Result then
    Renderer.APIBuffers.AttachVertexBuffer(Buffers[tbVertex, Tesselator.TesselationStatus[tbVertex].TesselatorType = ttStatic, Tesselator.TesselationStatus[tbVertex].BufferIndex].Index, 0, Tesselator.VertexSize);
end;

procedure TBuffers.Reset;
begin
  Inc(ResetCounter);
  ResetBuffers;
  Renderer.FPerfProfile.OnBuffersReset;
  Renderer.APIBuffers.Clear;
end;

{ TAPIStateWrapper }

function TAPIStateWrapper.CreateShader(var Shaders: TShaders; Item: TShaderResource): Integer;
begin
  Result := tivUnresolved;
  // Check if resource is valid
  if Item = nil then begin
     Log('TRenderer.CreateShader: no resource specified', lkError); 
    Exit;
  end;

  Result := High(Shaders);
  while (Result >= 0) and (Shaders[Result].Resource <> Item) do Dec(Result);

  if Result >= 0 then Exit;                            // A shader from the given resource already created

  SetLength(Shaders, Length(Shaders) + 1);
  Result := High(Shaders);

  Shaders[Result].Shader   := tivUnresolved;
  Shaders[Result].Resource := Item;
end;

function TAPIStateWrapper.IsRenderTargetEmpty(const Element: TRenderTarget): Boolean;
begin Result := not Assigned(Element.ColorBuffer) and not Assigned(Element.DepthBuffer); end;

function TAPIStateWrapper.IsShaderEmpty(const Element: TShader): Boolean;
begin Result := not Assigned(Element.Resource); end;

function TAPIStateWrapper.ResolveVertexShader(Pass: TRenderPass): Boolean;
var ShaderResource: TShaderResource;
begin
  Pass.ResolveVertexShader(ShaderResource);
  if (Pass.VertexShaderIndex = sivUnresolved) and Assigned(ShaderResource) then
    Pass.VertexShaderIndex := CreateVertexShader(ShaderResource, Pass.VertexDeclaration);
  Result := Pass.VertexShaderIndex <> tivUnresolved;
end;

function TAPIStateWrapper.ResolvePixelShader(Pass: TRenderPass): Boolean;
var ShaderResource: TShaderResource;
begin
  Pass.ResolvePixelShader(ShaderResource);
  if (Pass.PixelShaderIndex = sivUnresolved) and Assigned(ShaderResource) then
    Pass.PixelShaderIndex := CreatePixelShader(ShaderResource);
  Result := Pass.PixelShaderIndex <> tivUnresolved;
end;

function TAPIStateWrapper.CreateVertexShader(Item: TShaderResource; Declaration: TVertexDeclaration): Integer;
begin
  Result := CreateShader(FVertexShaders, Item);
end;

function TAPIStateWrapper.CreatePixelShader(Item: TShaderResource): Integer;
begin
  Result := CreateShader(FPixelShaders, Item);
end;

procedure TAPIStateWrapper.ApplyClipPlanes;
var i: Integer; m: TMatrix4s; Plane: TPlane;
begin
  if VertexShaderFlag then begin                           // Transform clip planes if programmable vertex pipeline used
    for i := 0 to MaxClipPlanes-1 do
      if Assigned(Renderer.LastAppliedCamera) and Assigned(Renderer.LastAppliedCamera.ClipPlanes[i]) then begin
        Plane := Camera.ClipPlanes[i]^;

        m := Camera.TotalMatrix;

        m := InvertMatrix4s(m);
        m := GetTransposedMatrix4s(m);
        Plane.V := Transform4Vector4s(m, Plane.V);

        SetClipPlane(i, @Plane);
      end else SetClipPlane(i, nil);
  end else if Assigned(Camera) then for i := 0 to MaxClipPlanes-1 do SetClipPlane(i, Camera.ClipPlanes[i]);
end;

procedure TAPIStateWrapper.HandleItemReplace(OldItem, NewItem: TItem);
var i: Integer;
begin
  if not Assigned(OldItem) then Exit;
  for i := High(FVertexShaders) downto 0 do if FVertexShaders[i].Resource = OldItem then FVertexShaders[i].Resource := NewItem as TShaderResource;
  for i := High(FPixelShaders)  downto 0 do if FPixelShaders[i].Resource  = OldItem then FPixelShaders[i].Resource  := NewItem as TShaderResource;
  if OldItem = Camera then if Assigned(NewItem) then Camera := NewItem as TCamera else Camera := DefaultCamera;
end;

procedure TAPIStateWrapper.HandleDataChange(Data: Pointer);
var i: Integer;
begin
  for i := 0 to High(FVertexShaders) do if FVertexShaders[i].Resource = TShaderResource(Data) then
end;

constructor TAPIStateWrapper.Create;
begin
  inherited;
  DefaultCamera := TCamera.Create(nil);
  DefaultCamera.DefaultFillMode := fmSOLID;
  DefaultCamera.DefaultCullMode := cmCCW;
end;

destructor TAPIStateWrapper.Destroy;
var i: Integer;
begin
  for i := 0 to High(FRenderTargets) do DestroyRenderTarget(i);
  for i := 0 to High(FVertexShaders) do APIDestroyVertexShader(i);
  for i := 0 to High(FPixelShaders)  do APIDestroyPixelShader(i);
  FreeAndNil(DefaultCamera);
  inherited;
end;

procedure TAPIStateWrapper.HandleMessage(const Msg: TMessage);
begin
  if (Msg.ClassType = TSceneClearMsg) then begin
    Camera := DefaultCamera;
  end else if Msg.ClassType = TDataModifyMsg then begin
    HandleDataChange(TDataModifyMsg(Msg).Data);
  end else if (Msg.ClassType = TRemoveFromSceneMsg) or (Msg.ClassType = TDestroyMsg) then HandleItemReplace(TItemNotificationMessage(Msg).Item, nil);
end;

procedure TAPIStateWrapper.SetShaderConstant(const Constant: TShaderConstant);
begin
  APISetShaderConstant(Constant);
end;

procedure TAPIStateWrapper.SetShaderConstant(ShaderKind: TShaderKind; ShaderRegister: Integer; const Vector: TShaderRegisterType);
begin
  APISetShaderConstant(ShaderKind, ShaderRegister, Vector); 
end;

function TAPIStateWrapper.ValidatePass(const Pass: TRenderPass): Boolean;
const ResultID: array[Boolean] of string[4] = ('Fail', 'OK');
var ResultStr: string;
begin
  Result := True;
  if not Assigned(Pass) then Exit;
  ResultStr := '';
  {$IFDEF DEBUGMODE}
  Log('  Validating pass "' + Pass.Name + '"...');
  {$ENDIF}
  LastError := reNone;
  ApplyPass(Pass);
  if LastError <> reNone then begin
    case LastError of
      reTooManyStages:   ResultStr := ' (too many stages)';
      reTooManyTextures: ResultStr := ' (too many textures)';
      reVertexShaderAssembleFail: ResultStr := ' (failed to assemble vertex shader)';
      reVertexShaderCreateFail:   ResultStr := ' (failed to create vertex shader)';
      rePixelShaderAssembleFail:  ResultStr := ' (failed to assemble pixel shader)';
      rePixelShaderCreateFail:    ResultStr := ' (failed to create pixel shader)';
      reNoDepthTextures:          ResultStr := ' (depth textures are not supported)';
    end;
    Result := False;
  end else Result := APIValidatePass(Pass, ResultStr);

  Log('  Pass validation result: ' + ResultID[Result] + ResultStr);
end;

{ TRenderer }

function TRenderer.GetAdapterName(Index: Cardinal): string;
begin
  Result := '';
  if Index < FTotalAdapters then Result := FAdapterNames[Index];
end;

function TRenderer.GetVideoMode(Index: Cardinal): TVideoMode;
begin
  Assert(Index < FTotalVideoModes, ClassName + '.GetVideoMode: Invalid index');
//  if Index < FTotalVideoModes then
  Result := FVideoModes[Index];
//   else Result := DesktopVideoMode;
end;

// Render target operations

function TAPIStateWrapper.NewRenderTarget(const Camera: TCamera): Integer;
begin
  Result := ResourceAdd_RenderTarget(FRenderTargets, {$IFDEF OBJFPCEnable}@{$ENDIF}IsRenderTargetEmpty);

  if CreateRenderTarget(Result, Camera.RenderTargetWidth, Camera.RenderTargetHeight, Camera.RTColorFormat, Camera.RTDepthFormat, Camera.IsDepthTexture) then begin
    Camera.ColorFormat := FRenderTargets[Result].ActualColorFormat;
    Camera.DepthFormat := FRenderTargets[Result].ActualDepthFormat;
  end else Result := -1; 
end;

procedure TAPIStateWrapper.RemoveRenderTarget(Index: Integer);
begin
  Assert((Index >= 0) and (Index <= High(FRenderTargets)));
  DestroyRenderTarget(Index);
  FRenderTargets[Index].ColorBuffer  := nil;
  FRenderTargets[Index].DepthBuffer  := nil;
  FRenderTargets[Index].ColorTexture := nil;
  FRenderTargets[Index].DepthTexture := nil;
  FRenderTargets[Index].LastUpdateFrame := -1;
  FRenderTargets[Index].IsDepthTexture := False;
end;

function TAPIStateWrapper.FindRenderTarget(const ACamera: TCamera): Integer;
begin
  Result := ACamera.RenderTargetIndex;
  if (Result <> -1) and
    ((ACamera.RenderTargetWidth <> FRenderTargets[Result].Width)   or (ACamera.RenderTargetHeight <> FRenderTargets[Result].Height) or
     (ACamera.RTColorFormat <> FRenderTargets[Result].ColorFormat) or (ACamera.RTDepthFormat <> FRenderTargets[Result].DepthFormat)) then begin
    RemoveRenderTarget(Result);
    Result := -1;
  end;                                           
  if Result = -1 then Result := NewRenderTarget(ACamera);
end;

function TAPIStateWrapper.IsRenderTargetUptoDate(const ACamera: TCamera): Boolean;
begin
  Result := (ACamera.RenderTargetIndex >= 0) and (ACamera.RenderTargetIndex <= High(FRenderTargets)) and
            (Renderer.FramesRendered - FRenderTargets[ACamera.RenderTargetIndex].LastUpdateFrame <= ACamera.FrameSkip);
end;

function TRenderer.GetRenderTargetsAllocated: Integer;
begin
  if Assigned(APIState) then Result := Length(APIState.FRenderTargets) else Result := 0;
end;

procedure TRenderer.InternalDeInit;
var i: Integer;
begin
  
  Log('Shutting down ' + ClassName, lkNotice);
  
  for i := 0 to Length(DebugTesselators)-1 do DebugTesselators[i].Free;
  DebugTesselators := nil;
  FreeAndNil(Buffers);
  FreeAndNil(Textures);
  FreeAndNil(APIState);
end;

function TRenderer.InternalGetIndexBufferIndex(Static: Boolean; BufferIndex: Integer): Integer;
begin
  Result := Buffers.Buffers[tbIndex, Static, BufferIndex].Index;
end;

function TRenderer.InternalGetVertexBufferIndex(Static: Boolean; BufferIndex: Integer): Integer;
begin
  Result := Buffers.Buffers[tbVertex, Static, BufferIndex].Index;
end;

procedure TRenderer.SetDebugOutput(const Value: Boolean);
begin
  FDebugOutput := Value;
  if FDebugOutput then begin
    if (DebugTesselators = nil) or (DebugMaterial = nil) then begin
      FDebugOutput := False;
      ErrorHandler(TError.Create(ClassName + '.SetDebugOutput: Debug render has not been initialized'));
    end;
  end;
end;

function TRenderer.APIToPixelFormat(Format: Cardinal): Cardinal;
var i: Integer;
begin
  Result := pfUndefined;
  for i := 0 to High(PFormats) do if PFormats[i] = Format then begin
    Result := i;
    Exit;
  end;
end;

procedure TRenderer.SetFullScreen(const FScreen: Boolean);
begin
  if FFullScreen = FScreen then Exit;
  if State <> rsNotReady then RestoreDevice(FCurrentVideoMode, FScreen);
end;

constructor TRenderer.Create(AManager: TItemsManager);
begin
  Assert(Assigned(AManager), Format('%S.%S: AManager should be assigned', [ClassName, 'Create']));
  Manager := AManager;

  AppRequirements.MinYResolution       := 480;
  AppRequirements.HWAccelerationLevel  := haMixedVP;
  AppRequirements.TotalBackBuffers     := 1;
  AppRequirements.Flags                := [arUseStencil, arUseZBuffer];

  FCurrentVideoMode := $FFFFFFFF;
  FFramesRendered   := 0;

  BiasMat._11 := 0.5; BiasMat._12 := 0.0; BiasMat._13 := 0.0;        BiasMat._14 := 0.0;
  BiasMat._21 := 0.0; BiasMat._22 :=-0.5; BiasMat._23 := 0.0;        BiasMat._24 := 0.0;
  BiasMat._31 := 0.0; BiasMat._32 := 0.0; BiasMat._33 := 1 shl 24-1; BiasMat._34 := 0.0;
  BiasMat._41 := 0.0; BiasMat._42 := 0.0; BiasMat._43 := 0.0;        BiasMat._44 := 1.0;

  Buffers := TBuffers.Create(Self);
end;

procedure TRenderer.SetVideoAdapter(Adapter: Cardinal);
begin
  if Adapter >= FTotalAdapters then Exit;                  // ToDo: make error handling
  FCurrentAdapter := Adapter;
  BuildModeList;
  FState          := rsNotReady;
end;

procedure TRenderer.InitDebugRender(ADebugMaterial: TMaterial);
begin
  SetLength(DebugTesselators, 2);
  DebugTesselators[dtiBox]    := TBoxTesselator.Create;
  DebugTesselators[dtiSphere] := TSphereTesselator.Create;

  DebugMaterial := ADebugMaterial;

  FDebugOutput := True;
end;

function TRenderer.IsReady: Boolean;
begin
  Result := State = rsOK;
end;

procedure TRenderer.SetGamma(Gamma, Contrast, Brightness: Single);
var i: Integer; k: Single; Value: Word;
begin
  
  if (Abs(Gamma - 1) > 0.7) or (Abs(Contrast - 1) > 0.7) or (Abs(Brightness - 1) > 0.7) then
    Log(Format('%S.SetGamma: Extreme values: Gamma - %F, Contrast - %F, Brightness - %F', [ClassName, Gamma, Contrast, Brightness]), lkWarning);
  
  for i := 0 to 255 do begin
    k := i/255.0;
    if i > 0 then k := Basics.Power(k, 1/Basics.MaxS(BaseTypes.Epsilon, Gamma));
    Value := Trunc(0.5 + MinS(65535, MaxS(0, (k*Contrast+(Brightness-1))*65535)));

    GammaRamp.R[i] := Value;
    GammaRamp.G[i] := Value;
    GammaRamp.B[i] := Value;
  end;
end;

procedure TRenderer.HandleMessage(const Msg: TMessage);
begin
  if (State = rsNotReady) or (State = rsNotInitialized) then Exit;
  if Msg.ClassType = TWindowActivateMsg then begin
    if not Active then begin
      Active := True;
//      ShowWindow(RenderWindowHandle, SW_SHOWDEFAULT);
      RestoreDevice(FCurrentVideoMode, FFullScreen);
    end;
  end else if Msg.ClassType = TWindowDeactivateMsg then begin
    if FullScreen then Active := False;
  end else if Msg.ClassType = TWindowResizeMsg then with TWindowResizeMsg(Msg) do begin
    if (State <> rsNotReady) then begin
      if RenderWindowHandle = 0 then begin
        RenderWidth  := Round(NewWidth);
        RenderHeight := Round(NewHeight);
      end;
      if not Active then begin
        Active := True;
        RestoreDevice(FCurrentVideoMode, FFullScreen);
      end else if not FullScreen then begin
        {if Active then }RestoreDevice(FCurrentVideoMode, FFullScreen)
//         else PrepareWindow;
      end;
      if Assigned(MainCamera) and (NewHeight <> 0) then
        MainCamera.SetScreenDimensions(Round(NewWidth), Round(NewHeight), True);
    end;
  end else if Msg.ClassType = TWindowMoveMsg then begin
    if not FullScreen then PrepareWindow;
  end else if Msg.ClassType = TWindowMinimizeMsg then begin
    Active := False;
  end else if (Msg.ClassType = TSceneClearMsg) then begin
    MainCamera := nil;
    FLastAppliedCamera := nil;
  end else begin
    if (Msg.ClassType = TRemoveFromSceneMsg) or (Msg.ClassType = TDestroyMsg) then with TItemNotificationMessage(Msg) do if Item = MainCamera then MainCamera := nil;
  end;

  APIState.HandleMessage(Msg);
  Textures.HandleMessage(Msg);
end;

function TRenderer.CheckFormat(const Format, Usage, RTFormat: Cardinal; out NewFormat: Cardinal): Boolean;
{  pfUndefined    = 0; pfR8G8B8    = 1; pfA8R8G8B8  = 2; pfX8R8G8B8  = 3;
  pfR5G6B5       = 4; pfX1R5G5B5  = 5; pfA1R5G5B5  = 6; pfA4R4G4B4  = 7;
  pfA8           = 8; pfX4R4G4B4  = 9; pfA8P8      = 10; pfP8       = 11; pfL8     = 12; pfA8L8      = 13; pfA4L4 = 14;
  pfV8U8         = 15; pfL6V5U5   = 16; pfX8L8V8U8 = 17; pfQ8W8V8U8 = 18; pfV16U16 = 19; pfW11V11U10 = 20;
  pfD16_LOCKABLE = 21; pfD32      = 22; pfD15S1    = 23; pfD24S8    = 24; pfD16    = 25; pfD24X8     = 26; pfD24X4S4 = 27;
  pfB8G8R8       = 28; pfR8G8B8A8 = 29;
  pfAuto = $FFFFFFFF;}
const
  SubstFormats = 19; SubstVariants = 7;
  FormatSubst: array[0..SubstFormats-1, 0..SubstVariants-1] of Cardinal = (
 (pfR8G8B8,       pfX8R8G8B8, pfR8G8B8A8, pfB8G8R8,   pfR5G6B5,   pfX1R5G5B5, pfA4R4G4B4),
 (pfA8R8G8B8,     pfR8G8B8A8, pfA4R4G4B4, pfA1R5G5B5, pfX8R8G8B8, pfR8G8B8,   pfR5G6B5),
 (pfX8R8G8B8,     pfA8R8G8B8, pfR8G8B8,   pfB8G8R8,   pfR8G8B8A8, pfR5G6B5,   pfX1R5G5B5),
 (pfR5G6B5,       pfX1R5G5B5, pfA1R5G5B5, pfX8R8G8B8, pfA8R8G8B8, pfB8G8R8,   pfA4R4G4B4),
 (pfX1R5G5B5,     pfR5G6B5,   pfA1R5G5B5, pfX8R8G8B8, pfR8G8B8,   pfB8G8R8,   pfA4R4G4B4),
 (pfA1R5G5B5,     pfA4R4G4B4, pfA8R8G8B8, pfR8G8B8A8, pfR5G6B5,   pfX8R8G8B8, pfR8G8B8),
 (pfA4R4G4B4,     pfA1R5G5B5, pfA8R8G8B8, pfR8G8B8A8, pfR5G6B5,   pfX8R8G8B8, pfR8G8B8),
 (pfX4R4G4B4,     pfR5G6B5,   pfA1R5G5B5, pfX8R8G8B8, pfR8G8B8,   pfB8G8R8,   pfA4R4G4B4),
 (pfB8G8R8,       pfR8G8B8A8, pfR8G8B8,   pfX8R8G8B8, pfR5G6B5,   pfX1R5G5B5, pfA4R4G4B4),
 (pfR8G8B8A8,     pfA8R8G8B8, pfA4R4G4B4, pfA1R5G5B5, pfX8R8G8B8, pfB8G8R8,   pfR5G6B5),

 (pfA8,           pfL8,       pfA8L8,     pfA8P8,     pfA8R8G8B8, pfR8G8B8A8, pfA4R4G4B4),
 (pfL8,           pfA8,       pfA8L8,     pfA8P8,     pfR8G8B8,   pfB8G8R8,   pfR5G6B5),

 (pfD16_LOCKABLE, pfD16,      pfATIDF16,  pfD24X8,    pfD24X4S4,  pfD32,      pfD24S8),
 (pfD32,          pfD24X8,    pfATIDF24,  pfD24S8,    pfD16,      pfATIDF16,  pfD16_LOCKABLE),
 (pfD15S1,        pfD24X4S4,  pfD24S8,    pfD16,      pfATIDF16,  pfD24X8,    pfD16_LOCKABLE),
 (pfD24S8,        pfD24X4S4,  pfD15S1,    pfD32,      pfATIDF24,  pfD16,      pfATIDF16),
 (pfD16,          pfD15S1,    pfD24X8,    pfATIDF16,  pfD32,      pfD24S8,    pfD16_LOCKABLE),
 (pfD24X8,        pfD32,      pfD24X4S4,  pfD24S8,    pfD16,      pfATIDF24,  pfD15S1),
 (pfD24X4S4,      pfD24S8,    pfATIDF24,  pfD32,      pfD24X8,    pfD16,      pfD15S1)
 );
var i, j: Integer;
begin
  NewFormat := Format;
  Result := APICheckFormat(NewFormat, Usage, RTFormat);
  if Result then Exit;

  NewFormat := pfUndefined;

  i := SubstFormats-1;
  while (i >= 0) and not (Format = FormatSubst[i, 0]) do Dec(i);
  if i < 0 then Exit;

  j := 0;
  while (j < SubstVariants) and not APICheckFormat(FormatSubst[i, j], Usage, RTFormat) do Inc(j);
  if j < SubstVariants then NewFormat := FormatSubst[i, j];
end;

function TRenderer.ValidateMaterial(const Material: TMaterial): Boolean;

  function ValidateTechnique(const Technique: TTechnique): Boolean;
  var i: Integer;
  begin
    i := Technique.TotalPasses-1;
    while (i >= 0) and APIState.ValidatePass(Technique.Passes[i]) do Dec(i);
    Result := i < 0;
    Technique.Valid := Result and (isVisible in Technique.State);
  end;

var i: Integer; OldValid: Boolean;
begin
  Result := False;
  Log('Validating material "' + Material.Name + '"...');
  for i := 0 to Material.TotalTechniques-1 do if Assigned(Material.Technique[i]) then begin
    OldValid := Material.Technique[i].Valid;
    if not ValidateTechnique(Material.Technique[i]) then
      Log('Technique "' + Material.Technique[i].Name + '" did not pass validation', lkWarning);
    Result := Result or (OldValid <> Material.Technique[i].Valid);
  end;
end;

function TRenderer.PrepareWindow: Boolean;
var TempRect: OSUtils.TRect;
begin
  Assert(not FFullScreen, ClassName + '.PrepareWindow: FullScreen # False');

  Result := True;
  if RenderWindowHandle = 0 then Exit;

  Result := False;
//  if (WindowedRect.Left = WindowedRect.Right) or (WindowedRect.Top = WindowedRect.Bottom) then
  // Get window rect if applicable
  GetWindowRect(RenderWindowHandle, TempRect);

  if (TempRect.Left < OffScreenX) and (TempRect.Right < OffScreenX) or (TempRect.Top < OffScreenY) and (TempRect.Bottom < OffScreenY) then begin
     Log(ClassName + '.PrepareWindow: Windowed viewport is off-screen', lkError); 
    FState := rsLost;
    Exit;
  end;
  FWindowedRect := TempRect;

  {$IFNDEF DEBUGMODE}
//  SetWindowLong(RenderWindowHandle, GWL_STYLE, FNormalWindowStyle);
  {$ENDIF}
//  SetWindowPos(RenderWindowHandle, HWND_NOTOPMOST, WindowedRect.Left, WindowedRect.Top, WindowedRect.Right-WindowedRect.Left, WindowedRect.Bottom-WindowedRect.Top, SWP_DRAWFRAME or SWP_NOACTIVATE or SWP_NOSIZE or SWP_NOMOVE);

  GetClientRect(RenderWindowHandle, TempRect);

  if (TempRect.Right - TempRect.Left <= 0) or (TempRect.Bottom - TempRect.Top <= 0) then begin
    
    Log(ClassName + '.PrepareWindow: Viewport''s client area is missing', lkError);
    
//      State := rsTryToRestore;
    Exit;
  end;

//  WindowBorderWidth := ClientRect.Left - WindowedRect.Left + (WindowedRect.Right - ClientRect.Right);
//  WindowBorderHeight := ClientRect.Top - WindowedRect.Top + (WindowedRect.Bottom - ClientRect.Bottom);
  RenderWidth  := TempRect.Right;
  RenderHeight := TempRect.Bottom;

  if Assigned(MainCamera) then MainCamera.SetScreenDimensions(RenderWidth, RenderHeight, True);

  Result := True;
end;

function TRenderer.CreateDevice(WindowHandle, AVideoMode: Cardinal; AFullScreen: Boolean): Boolean;
begin
  Log('Render device creation', lkNotice);
  if APICreateDevice(WindowHandle, AVideoMode, AFullScreen) then begin
    Log('Render device succesfully created');
    CheckCaps;
    Result := True;
    Manager.SendMessage(TRenderReinitMsg.Create, nil, [mfCore, mfBroadcast]);
    Manager.SendMessage(TWindowResizeMsg.Create(0, 0, RenderWidth, RenderHeight), nil, [mfCore]);   // For correct screen and GUI subsystems initialization
  end else begin
    Log('Render device creation failed', lkError);
    Result := False;
  end;
end;

function TRenderer.RestoreDevice(AVideoMode: Cardinal; AFullScreen: Boolean): Boolean;
begin
  Result := True;
  if Assigned(Manager.Root) then Manager.SendMessage(TRenderReinitMsg.Create, nil, [mfCore, mfBroadcast]);
end;

procedure TRenderer.ApplyCamera(Camera: CAST2.TCamera);
begin
  if Camera <> FLastAppliedCamera then begin
    APIState.SetRenderTarget(Camera, Camera <> MainCamera);
    if Camera <> MainCamera then begin
      Camera.SetScreenDimensions(Camera.RenderTargetWidth, Camera.RenderTargetHeight, False);
//    Camera.ColorFormat := Camera.RTColorFormat;
//    Camera.DepthFormat := Camera.RTDepthFormat;
    end;
  end;
  FLastAppliedCamera := Camera;
  FLastAppliedCameraMatrix := Camera.ViewMatrix;
  TesselationParams.Camera := FLastAppliedCamera;
  if Assigned(APIState) then begin
    APIState.Camera := Camera;
    APIState.ApplyClipPlanes;
  end;
  if Assigned(Camera) then Clear(Camera.ClearSettings.ClearFlags, Camera.ClearSettings.ClearColor, Camera.ClearSettings.ClearZ, Camera.ClearSettings.ClearStencil);
  APIApplyCamera(Camera);
end;

procedure TRenderer.ProjectToScreen(out Projected: TVector4s; const Vector: TVector3s);
var TRHW: Single;
begin
  if not Assigned(MainCamera) then Exit;

  Projected := Transform4Vector3s(MainCamera.TotalMatrix, Vector);

  if Projected.W = 0 then Projected.W := -0.000001;

  TRHW := 1/Projected.W;
  Projected.X := MainCamera.RenderWidth  shr 1 + MainCamera.RenderWidth  shr 1*Projected.X * TRHW;
  Projected.Y := MainCamera.RenderHeight shr 1 - MainCamera.RenderHeight shr 1*Projected.Y * TRHW;
end;

procedure TRenderer.SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single);
begin
  ViewPort.X := X; ViewPort.Y := Y;
  ViewPort.Width := Width; ViewPort.Height := Height;
  ViewPort.MinZ := MinZ; ViewPort.MaxZ := MaxZ;
end;

procedure TRenderer.RenderTesselator(Tesselator: TTesselator);
var i: Integer;
begin
  if Tesselator.TotalIndices > 0 then begin
    for i := Tesselator.TotalStrips - 1 downto 0 do APIRenderIndexedStrip(Tesselator, i);
  end else for i := Tesselator.TotalStrips - 1 downto 0 do APIRenderStrip(Tesselator, i);
end;

destructor TRenderer.Destroy;
begin
  InternalDeInit;
  inherited;
end;

function TAPIStateWrapper.CreateRenderTarget(Index, Width, Height: Integer; AColorFormat, ADepthFormat: Cardinal; ADepthTexture: Boolean): Boolean;
const Usage: array[False..True] of Cardinal = (fuDEPTHSTENCIL, fuDEPTHTEXTURE);
begin
  Result := True;

  FRenderTargets[Index].Width           := Width;
  FRenderTargets[Index].Height          := Height;
  FRenderTargets[Index].LastUseFrame    := Renderer.FramesRendered;
  FRenderTargets[Index].LastUpdateFrame := -1;
  FRenderTargets[Index].ColorFormat     := AColorFormat;
  FRenderTargets[Index].DepthFormat     := ADepthFormat;
  FRenderTargets[Index].IsDepthTexture  := ADepthTexture;

  // Check pixel format
  if not Renderer.CheckFormat(FRenderTargets[Index].ColorFormat, fuRENDERTARGET, pfUndefined, FRenderTargets[Index].ActualColorFormat) then begin
    if FRenderTargets[Index].ActualColorFormat = pfUndefined then begin
      Log('TAPIStateWrapper.AddRenderTarget: Can''t find an appropriate pixel format for render target (initial format "'  + PixelFormatToStr(FRenderTargets[Index].ColorFormat) + '")', lkError);
      Result := False;
    end else
      Log('TAPIStateWrapper.AddRenderTarget: Unsupported pixel format "' + PixelFormatToStr(FRenderTargets[Index].ColorFormat) +
              '" of a render target. Switching to format "' + PixelFormatToStr(FRenderTargets[Index].ActualColorFormat) + '".', lkWarning);
  end;
  // Check depth format
  if not Renderer.CheckFormat(FRenderTargets[Index].DepthFormat, Usage[ADepthTexture], FRenderTargets[Index].ActualColorFormat, FRenderTargets[Index].ActualDepthFormat) then begin
    if FRenderTargets[Index].ActualDepthFormat = pfUndefined then begin
      Log('TAPIStateWrapper.AddRenderTarget: Can''t find an appropriate depth-stencil surface format for render target (initial format "'  + PixelFormatToStr(FRenderTargets[Index].DepthFormat) + '")', lkError);
    end else
      Log('TAPIStateWrapper.AddRenderTarget: Unsupported depth-stencil surface format "' + PixelFormatToStr(FRenderTargets[Index].DepthFormat) +
              '" of a render target. Switching to format "' + PixelFormatToStr(FRenderTargets[Index].ActualDepthFormat) + '".', lkWarning);
  end;

  if not Result or not APICreateRenderTarget(Index, FRenderTargets[Index].Width, FRenderTargets[Index].Height, FRenderTargets[Index].ActualColorFormat, FRenderTargets[Index].ActualDepthFormat) then begin
    Result := False;
    RemoveRenderTarget(Index);
  end;// else Log('****************: Created depth-stencil surface format "' + PixelFormatToStr(FRenderTargets[Index].ActualDepthFormat));
end;

procedure TRenderer.StartFrame;
begin
  Assert(Assigned(MainCamera), 'TRenderer.StartFrame: MainCamera is undefined');
  MainCamera.SetScreenDimensions(RenderWidth, RenderHeight, True);                         // ToDo: Remove
  // Zero out statistics
  Assert(Assigned(FPerfProfile), Format('%S.%S: FPerfProfile should be assigned', [ClassName, 'StartFrame']));
  FPerfProfile.OnFrameStart;
//  MainCamera.ColorFormat := FCurrentZBufferDepth
end;

procedure TRenderer.InternalInit;
begin
  APIState.Renderer := Self;
  Textures.Renderer := Self;
end;

procedure TRenderer.SetPerfProfile(APerfProfile: TPerfProfile);
begin
  FPerfProfile := APerfProfile;
  Assert(Assigned(APIState), Format('%S.%S: APIState should be assigned for this call', [ClassName, 'SetPerfProfile']));
  APIState.FPerfProfile := APerfProfile;
end;

procedure TRenderer.RenderItem(Item: TVisible);
var i: Integer; ItemShaderConstants: TShaderConstants;
begin
  if not IsReady then Exit;
  if not Assigned(Item.CurrentTesselator) or not Assigned(Item.CurTechnique) or (Item.CurTechnique.TotalPasses = 0) then Exit;

  TesselationParams.ModelMatrix := Item.Transform;

  // Buffers switching and setting
  if not Buffers.Put(Item.CurrentTesselator) or (Item.CurrentTesselator.TotalPrimitives = 0) then Exit;

  if not APIState.VertexShaderFlag then APIPrepareFVFStates(Item);
  if APIState.VertexShaderFlag or APIState.PixelShaderFlag then begin
    Item.RetrieveShaderConstants(ItemShaderConstants);
    if Assigned(ItemShaderConstants) then
      for i := 0 to High(ItemShaderConstants) do
        APIState.SetShaderConstant(ItemShaderConstants[i]);
  end;

  if not Item.CurrentTesselator.ManualRender then
    RenderTesselator(Item.CurrentTesselator)
  else
    Item.CurrentTesselator.DoManualRender(Item);
end;

{ TTextures }

function TTextures.IsEmpty(const Element: TTexture): Boolean;
begin Result := Element.Format = pfUndefined; end;// not Assigned(Element.Resource); end;

function TTextures.NewTexture(Resource: TImageResource; Options: TTextureOptions): Integer;
begin
  Result := tivUnresolved;
  // Check if the resource is valid
  if not Assigned(Resource) or (Resource.Format = pfUndefined) then begin
    Log('TTextures.NewTexture: invalid or no resource specified', lkError);
    Exit;
  end;

  if (toProcedural in Options) then begin
    Log('TTextures.NewTexture: for procedural textures NewProceduralTexture() should be used', lkError);
    Exit;
  end;

  if Assigned(Resource) then begin                                      // Check if the resource already loaded as a texture
    Result := High(FTextures);
    while (Result >= 0) and (FTextures[Result].Resource <> Resource) do Dec(Result);

    if Result >= 0 then Exit;

    {$IFDEF DEBUG}
    Log('TRenderer.AddTexture: Loading resource "' + Resource.GetFullName + '" as a texture', lkDebug);
    {$ENDIF}
  end;

  Result := ResourceAdd_Texture(FTextures, {$IFDEF OBJFPCEnable}@{$ENDIF}IsEmpty);

  FTextures[Result].Format   := Resource.Format;            
  FTextures[Result].Resource := Resource;
  FTextures[Result].Options  := Options;
  FTextures[Result].Texture  := nil;

  if (toImmediateLoad in Options) and not Load(Result) then begin
    FTextures[Result].Resource := nil;
    FTextures[Result].Format   := pfUndefined;
  end;
end;

function TTextures.NewProceduralTexture(AFormat: Cardinal; AWidth, AHeight, ADepth, ALevels: Integer; Options: TTextureOptions): Integer;
begin
  Result := ResourceAdd_Texture(FTextures, {$IFDEF OBJFPCEnable}@{$ENDIF}IsEmpty);

  FTextures[Result].Resource := nil;
  FTextures[Result].Texture  := nil;
  FTextures[Result].Options  := Options + [toProcedural];
  FTextures[Result].Format   := AFormat;
  FTextures[Result].Width    := AWidth;
  FTextures[Result].Height   := AHeight;
  FTextures[Result].Depth    := ADepth;
  FTextures[Result].Levels   := ALevels;

  if not APICreateTexture(Result) then Result := tivNull;
end;

procedure TTextures.Delete(Index: Integer);
begin
//  Dec(TotalTextures);
  FTextures[Index].Resource := nil;
  FTextures[Index].Format   := pfUndefined;
//  if Index < TotalTextures then FTextures[Index] := FTextures[TotalTextures]
end;

procedure TTextures.FreeAll;
var i: Integer;
begin
  for i := High(FTextures) downto 0 do if not IsEmpty(FTextures[i]) then Delete(i);
end;

destructor TTextures.Destroy;
begin
  FreeAll;
  inherited;
end;

procedure TTextures.HandleMessage(const Msg: TMessage);
var i: Integer;
begin
  if (Msg.ClassType = TResourceModifyMsg) then begin
    for i := 0 to High(FTextures) do if FTextures[i].Resource = TResourceModifyMsg(Msg).Resource then Load(i);
  end else if (Msg.ClassType = TRemoveFromSceneMsg) or (Msg.ClassType = TDestroyMsg) then
    for i := High(FTextures) downto 0 do if FTextures[i].Resource = TItemNotificationMessage(Msg).Item then
      FTextures[i].Resource := nil;
//  HandleItemReplace(TItemNotificationMessage(Msg).Item, nil);
end;

function TTextures.Load(Index: Integer): Boolean;
var
{  i, j, k, w, h: Integer;
  FData, CData: Pointer; DataSize, DataOfs, TextureDataOfs: Integer;
  MipmapGenFilter: TImageFilterFunction;}

  Image: TImageResource;
  Width, Height: Integer;
  TotalPixels: Integer;
  TargetFormat: Cardinal;
  Data: Pointer;
begin
  Result := False;
  // * check dimensions
  // * check format
  Image := FTextures[Index].Resource;
  if not Assigned(Image) or not Assigned(Image.Data) then begin
    Log(Format('%S.%S: Resource of texture #%D is not assigned', [ClassName, 'Load', Index]));
    Exit;
  end;

  // Now check if texture with such dimensions is supported
  Width  := MinI(Renderer.MaxTextureWidth,  Image.Width);
  Height := MinI(Renderer.MaxTextureHeight, Image.Height);
  if Renderer.SquareTextures then begin
    Width  := MaxI(Width, Height);
    Height := Width;
  end;
  // Compute total size of the texture with mipmaps
  Assert((Image.DataSize mod GetBytesPerPixel(Image.Format)) = 0);
  TotalPixels := Image.DataSize div GetBytesPerPixel(Image.Format);

  // Check if texture with such format is supported
  if not Renderer.CheckFormat(Image.Format, fuTexture, pfUndefined, TargetFormat) then begin
    if TargetFormat = pfUndefined then begin
      Log(Format('%S.%S: Can''t find appropriate texture format (initial format "%S") for resource "%S"',
                     [ClassName, 'LoadTexture', PixelFormatToStr(Image.Format), Image.GetFullName]), lkError);
//      if Assigned(CData) then FreeMem(CData);
      Exit;
    end else if TargetFormat <> Image.Format then begin
      Log(Format('%S.%S: Unsupported image format "%S" of resource "%S". Switching to format "%S",',
                     [ClassName, 'LoadTexture', PixelFormatToStr(Image.Format), Image.GetFullName, PixelFormatToStr(TargetFormat)]), lkWarning);
    end;
  end;

  if Assigned(FTextures[Index].Texture) and                           // Allocated API texture
   ((FTextures[Index].Width <> Width) or (FTextures[Index].Height <> Height) or
    (FTextures[Index].Levels <> Image.ActualLevels) or
    (GetBytesPerPixel(FTextures[Index].Format) <> GetBytesPerPixel(TargetFormat))) then begin
      Log(Format('%S.%S: Image resource changed. Recreating API texture.',
                     [ClassName, 'LoadTexture']), lkWarning);
      APIDeleteTexture(Index);
    end;

  FTextures[Index].Width  := Width;
  FTextures[Index].Height := Height;
  FTextures[Index].Format := TargetFormat;
  FTextures[Index].Levels := Image.ActualLevels; 

  if TargetFormat <> Image.Format then begin
    GetMem(Data, TotalPixels * GetBytesPerPixel(TargetFormat));
    ConvertImage(Image.Format, TargetFormat, TotalPixels, Image.Data, 0, nil, Data);
    Update(Index, Data, nil);
    FreeMem(Data);
  end else Update(Index, Image.Data, nil);

  Result := True;
end;

function TTextures.Resolve(Pass: TRenderPass; StageIndex: Integer): Boolean;
var TextureResource: TImageResource;
begin
  Result := False;
  if Pass.ResolveTexture(StageIndex, TextureResource) then begin
    if Pass.Stages[StageIndex].TextureIndex = tivUnresolved then
      Pass.Stages[StageIndex].TextureIndex := NewTexture(TextureResource, []);
    Result := Pass.Stages[StageIndex].TextureIndex <> tivUnresolved;
  end;
end;

end.

