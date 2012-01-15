(*
 CAST Engine OpenGL render unit.
 (C) 2002 George "Mirage" Bakhtadze.
 Unit contains implementation of renderer based on OpenGL.

History:
 Mar 15, 2005:    Porting started from scratch
 Mar 16, 2005:    Camera, Mesh output using glBegin..glEnd
 Mar 17, 2005:    Lighting, FX
 Mar 18, 2005:    DX8 texture stages emulation with GL_COMBINER_EXT finished. Optimization needed.

*)
{$Include GDefines}
{$Include CDefines}
unit COGLRender;

interface

uses
  SysUtils, Windows, {Messages, }OpenGL12, MyOpenGL,

  Logger,

  Basics, BaseCont, Base3D, CTypes, CTess, CRes, CRender, Adv2D;

type
  TOGLRenderStreams = class(TRenderStreams)
    procedure Reset; override;
    function Add(VBufSize, IBufSize, AVertexFormat, AIndexSize: DWord; Static: Boolean): Integer; override;
    function Resize(Stream: Integer; VBufSize, IBufSize, IndexSize: DWord; Static: Boolean): Integer; override;

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
    VertexBuffer: array of Pointer;
    IndexBuffer: array of Pointer;
  end;

  TOGLRenderer = class(TRenderer)
    OGLContext: HGLRC;                    // OpenGL rendering context
    OGLDC: HDC;
    constructor Initialize(AResources: TResourceManager; AEvents: TCommandQueue); override;
    procedure CheckCaps; override;
    procedure CheckTextureFormats; override;
    function CheckTextureFormat(const Format, Usage: Cardinal): Boolean; override;
    function CreateViewport(WindowHandle: HWND; ResX, ResY, BpP: Word; AFullScreen: Boolean; AZBufferDepth: Word;
                            UseHardware: Boolean = True; Refresh: Integer = 0): Integer; override;
    function RestoreViewport: Integer; override;
    function RestoreDevice: Boolean; virtual;

    procedure BeginScene; override;
    procedure EndScene; override;

    function LoadToTexture(TextureID: Integer; Data: Pointer): Boolean; override;
    function UpdateTexture(Src: Pointer; TextureIndex: Integer; Area: TArea): Boolean; override;
    function LoadTexture(Filename: string; Width: Word = 0; Height: Word = 0; MipLevels: Word = 0; ColorKey: DWord = 0): Integer; override;
    procedure DeleteTexture(TextureID: Integer); override;

    procedure InitMatrices(AXFoV, AAspect: Single; AZNear, AZFar: Single); override;
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
    function BeginPasses(Obj: TTesselator): Boolean; override;
    procedure EndPasses; override;
    procedure BeginRenderPass(Pass: TRenderPass); override;
    procedure EndRenderPass(Pass: TRenderPass); override;
    procedure AddTesselator(Obj: TTesselator); override;
    procedure Clear(ClearTarget: Cardinal; Color: Cardinal; Z: Single; Stencil: Cardinal); override;
    procedure Render; override;

    procedure CloseViewport; override;
    destructor Shutdown; override;

    procedure SetFullScreen(const FScreen: Boolean); override;
  end;

  TOGLDispListRenderer = class(TOGLRenderer)
    function BeginPasses(Obj: TTesselator): Boolean; override;
    procedure EndPasses; override;
    procedure AddTesselator(Obj: TTesselator); override;
  end;

implementation

var
  GLModelView1, GLWeightingState: Longword;

{  glWeightbvARB: procedure(size: GLint; weights: PGLbyte); stdcall = nil;
  glWeightsvARB: procedure(size: GLint; weights: PGLshort); stdcall = nil;
  glWeightivARB: procedure(size: GLint; weights: PGLint); stdcall = nil;
  glWeightfvARB: procedure(size: GLint; weights: PGLfloat); stdcall = nil;
  glWeightdvARB: procedure(size: GLint; weights: PGLdouble); stdcall = nil;
  glWeightvARB: procedure(size: GLint; weights: PGLdouble); stdcall = nil;
  glWeightubvARB: procedure(size: GLint; weights: PGLubyte); stdcall = nil;
  glWeightusvARB: procedure(size: GLint; weights: PGLushort); stdcall = nil;
  glWeightuivARB: procedure(size: GLint; weights: PGLuint); stdcall = nil;
  glWeightPointerARB: procedure(size: GLint; _type: GLenum; stride: GLsizei; pointer: Pointer); stdcall = nil;}

  glVertexBlendARB: procedure(count: GLint); {$ifdef MSWINDOWS} stdcall; {$endif} {$ifdef LINUX} cdecl; {$endif}
  glWeightfvARB: procedure(Size: GLint; weights: PGLfloat); {$ifdef MSWINDOWS} stdcall; {$endif} {$ifdef LINUX} cdecl; {$endif}
  glWeightPointerARB: procedure(Size: TGLsizei; Atype: TGLenum; stride: TGLsizei; p: pointer); {$ifdef MSWINDOWS} stdcall; {$endif} {$ifdef LINUX} cdecl; {$endif}

procedure GLVertexWeightfvDummy(weight: PGLfloat); {$ifdef MSWINDOWS} stdcall; {$endif} {$ifdef LINUX} cdecl; {$endif}
begin
end;

procedure GLVertexWeightPointerDummy(Size: TGLsizei; Atype: TGLenum; stride: TGLsizei; p: pointer); {$ifdef MSWINDOWS} stdcall; {$endif} {$ifdef LINUX} cdecl; {$endif}
begin
end;

{ TOGLRenderStreams }

function TOGLRenderStreams.Add(VBufSize, IBufSize, AVertexFormat, AIndexSize: DWord; Static: Boolean): Integer;
var Usage, IndexFormat: DWord;
begin
  Result := -1;
  Inc(TotalStreams);

  Log('Creating render stream #' + IntToStr(TotalStreams-1), lkTitle);

  SetLength(Streams, TotalStreams);
  SetLength(VertexBuffer, TotalStreams);
  SetLength(IndexBuffer, TotalStreams);
  with Streams[TotalStreams-1] do begin
    VertexBufferSize := VBufSize;
    IndexBufferSize := IBufSize;
    VertexSize := GetVertexSize(AVertexFormat);
    IndexSize := AIndexSize;
    Static := Static;
    VertexFormat := AVertexFormat;
    ZTestMode := zbtW;
  end;
  if (AIndexSize <> 2) and (AIndexSize <> 4) then begin

    Log('Error creating stream: Invalid index size: '+IntToStr(AIndexSize), lkError);

    Exit;
  end;

  GetMem(VertexBuffer[TotalStreams-1], VBufSize * Streams[TotalStreams-1].VertexSize);
  GetMem(IndexBuffer[TotalStreams-1], IBufSize * Streams[TotalStreams-1].IndexSize);

  Result := TotalStreams - 1;
end;

function TOGLRenderStreams.Resize(Stream: Integer; VBufSize, IBufSize, IndexSize: DWord; Static: Boolean): Integer;
var Usage, IndexFormat: DWord;
begin
  Result := -1;

  Log('Resizing render stream #'+IntToStr(Stream)+'. VB/IB size: '+IntToStr(VBufSize)+'/'+IntToStr(IBufSize), lkTitle);

  if Stream >= TotalStreams then begin
//    Result := AddStream(VBufSize, IBufSize, IndexSize, Static);

    Log('Error resizing stream: Stream index out of range', lkError);

    Exit;
  end;
  Streams[Stream].VertexBufferSize := VBufSize;
  Streams[Stream].IndexBufferSize := IBufSize;
  Streams[Stream].IndexSize := IndexSize;
  Streams[Stream].Static := Static;
  if (IndexSize <> 2) and (IndexSize <> 4) then begin

    Log('Error resizing stream: Invalid index size: ' + IntToStr(IndexSize), lkError);

    Exit;
  end;

  if VertexBuffer[Stream] <> nil then FreeMem(VertexBuffer[Stream], VBufSize * Streams[Stream].VertexSize);
  if IndexBuffer[Stream] <> nil then FreeMem(IndexBuffer[Stream], IBufSize * Streams[Stream].IndexSize);
  GetMem(VertexBuffer[Stream], VBufSize * Streams[Stream].VertexSize);
  GetMem(IndexBuffer[Stream], IBufSize * Streams[Stream].IndexSize);
end;

function TOGLRenderStreams.CreateVBuffer(Stream: DWord; BufferLength: Integer; Usage, Pool: DWord): Boolean;
begin
end;

function TOGLRenderStreams.CreateIBuffer(Stream: DWord; BufferLength: Integer; Usage, Pool: DWord): Boolean;
begin
end;

function TOGLRenderStreams.FillVertexes(Stream: DWord; Source: Pointer; SourceSize, Offset: DWord): Boolean;
begin
  Result := False;
  if VertexBuffer[Stream] = nil then begin

    Log('Error filling vertices in stream #' + IntToStr(Stream) + ': No vertex buffer', lkError);

    Exit;
  end;
  Move(Source^, VertexBuffer[Stream]^, SourceSize);
  Result := True;
end;

function TOGLRenderStreams.FillIndices(Stream: DWord; Source: Pointer; SourceSize, Offset: DWord): Boolean;
begin
  Result := False;
  if IndexBuffer[Stream] = nil then begin

    Log('Error filling indices in stream #' + IntToStr(Stream) + ': No index buffer', lkError);

    Exit;
  end;
  Move(Source^, IndexBuffer[Stream]^, SourceSize);
  Result := True;
end;

function TOGLRenderStreams.LockVBuffer(Stream: DWord; const BOffset, BSize, Mode: DWord): PByte;
begin
  Result := Pointer(Cardinal(@VertexBuffer[Stream]^) + BOffset);
end;

function TOGLRenderStreams.LockIBuffer(Stream: DWord; const BOffset, BSize, Mode: DWord): PByte;
begin
  Result := Pointer(Cardinal(@IndexBuffer[Stream]^) + BOffset);
end;

procedure TOGLRenderStreams.UnLockVBuffer(Stream: DWord);
begin
end;

procedure TOGLRenderStreams.UnLockIBuffer(Stream: DWord);
begin
end;

procedure TOGLRenderStreams.Reset;
var i: Integer;
begin
  for i := 0 to TotalStreams - 1 do with Streams[i] do begin
    FreeMem(VertexBuffer[i], Streams[i].VertexBufferSize * Streams[i].VertexSize);
    VertexBuffer[i] := nil;
    FreeMem(IndexBuffer[i], Streams[i].IndexBufferSize * Streams[i].IndexSize);
    IndexBuffer[i] := nil;
  end;
  inherited;
end;

function TOGLRenderStreams.Restore: Boolean;
var i: Integer; Usage: DWord;
begin

  Log('Restoring streams', lkTitle);

  Result := False;
  for i := 0 to TotalStreams - 1 do begin
    Resize(i, Streams[i].VertexBufferSize, Streams[i].IndexBufferSize, Streams[i].IndexSize, Streams[i].Static);
    Streams[i].CurVBOffset := 0; Streams[i].CurIBOffset := 0;
  end;
  Result := True;
end;

destructor TOGLRenderStreams.Free;
var i: Integer;
begin

  Log('Freeing all streams', lkInfo);

  Reset;
end;

{ TOGLRenderer }

constructor TOGLRenderer.Initialize(AResources: TResourceManager; AEvents: TCommandQueue);
begin
  inherited;

  Log('Starting OGLRenderer', lkTitle);

{$Include COGLInit.pas}
  State := rsNotReady;

  CTess.RGBA := True;

  Streams := TOGLRenderStreams.Create(Self);
end;

procedure TOGLRenderer.CheckTextureFormats;
var i: Integer;
 {$IFDEF EXTLOGGING}
const FormatStr: array[0..High(CPFormats)] of string[8] =
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
  for i := 1 to High(CPFormats) do begin
    Log(Format('%-8.8s', [FormatStr[i]]) + SupportStr[CheckTextureFormat(i, fuTexture)] +
                                               SupportStr[CheckTextureFormat(i, fuRenderTarget)] +
                                               SupportStr[CheckTextureFormat(i, fuDepthStencil)] +
                                               SupportStr[CheckTextureFormat(i, fuVolumeTexture)] +
                                               SupportStr[CheckTextureFormat(i, fuCubeTexture)]);
  end;
 {$ENDIF}
end;

function TOGLRenderer.CheckTextureFormat(const Format, Usage: Cardinal): Boolean;
begin
  Result := (Format = pfA8B8G8R8) or (Format = pfB8G8R8);
end;

procedure TOGLRenderer.CheckCaps;
 {$IFDEF EXTLOGGING}
const CanStr: array[False..True] of string[3] = ('[ ]', '[X]');
 {$ENDIF}
var
  R, G, B, A: Integer; Bool: Boolean; f: Single;
  Vf: array[0..3] of Single; Vi: array[0..3] of Integer;
begin
 {$IFDEF EXTLOGGING}
  Log('Checking OpenGL device information...', lkTitle);
  Log(' General information');
  Log('Vendor: ' + glGetString(GL_VENDOR));
  Log('Render device: ' + glGetString(GL_RENDERER));
  Log('OpenGL version: ' + glGetString(GL_VERSION));
  Log('GLU version: ' + glGetString(GLU_VERSION));

  Log(' Buffers information');
  glGetIntegerv(GL_ALPHA_BITS, @A); glGetIntegerv(GL_RED_BITS, @R);
  glGetIntegerv(GL_GREEN_BITS, @G); glGetIntegerv(GL_BLUE_BITS, @B);
  Log(Format('Color bits (R:G:B:A): %D:%D:%D:%D', [R, G, B, A]));
  glGetIntegerv(GL_ACCUM_ALPHA_BITS, @A); glGetIntegerv(GL_ACCUM_RED_BITS, @R);
  glGetIntegerv(GL_ACCUM_GREEN_BITS, @G); glGetIntegerv(GL_ACCUM_BLUE_BITS, @B);
  Log(Format('Accumulation bits (R:G:B:A): %D:%D:%D:%D', [R, G, B, A]));
  glGetIntegerv(GL_DEPTH_BITS, @A);
  Log(Format('Depth bits: %D', [A]));
  glGetIntegerv(GL_STENCIL_BITS, @A);
  Log(Format('Stencil bits: %D', [A]));
  glGetIntegerv(GL_AUX_BUFFERS, @A);
  Log(Format('Auxiliary buffers: %D', [A]));
  glGetIntegerv(GL_SUBPIXEL_BITS, @A);
  Log(Format('Subpixel accuracy: %D', [A]));
  glGetBooleanv(GL_DOUBLEBUFFER, @Bool);
  Log(CanStr[Bool] + ' Double buffering is supported');

  Log(' Rasterizer');
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, @MaxTextureWidth);
  MaxTextureHeight := MaxTextureWidth;
  Log(Format('Max texture size: %Dx%D', [MaxTextureWidth, MaxTextureHeight]));
  glGetIntegerv(GL_MAX_VIEWPORT_DIMS, @Vi);
  Log(Format('Max viewport size: %Dx%D', [Vi[0], Vi[1]]));
  glGetFloatv(GL_LINE_WIDTH_RANGE, @Vf); glGetFloatv(GL_LINE_WIDTH_GRANULARITY, @f);
  Log(Format('Antialiased lines width range/granularity: %3.3F..%3.3F / %3.3F', [Vf[0], Vf[1], f]));
  glGetFloatv(GL_POINT_SIZE_RANGE, @Vf); glGetFloatv(GL_POINT_SIZE_GRANULARITY, @f);
  Log(Format('Antialiased points size range/granularity: %3.3F..%3.3F / %3.3F', [Vf[0], Vf[1], f]));

  Log(' Stacks');
  glGetIntegerv(GL_MAX_MODELVIEW_STACK_DEPTH, @A);
  Log(Format('Modelview matrix stack size: %D', [A]));
  glGetIntegerv(GL_MAX_PROJECTION_STACK_DEPTH, @A);
  Log(Format('Projection matrix stack size: %D', [A]));
  glGetIntegerv(GL_MAX_TEXTURE_STACK_DEPTH, @A);
  Log(Format('Texture matrix stack size: %D', [A]));
  glGetIntegerv(GL_MAX_ATTRIB_STACK_DEPTH, @A);
  Log(Format('Attribute stack size: %D', [A]));
  glGetIntegerv(GL_MAX_NAME_STACK_DEPTH, @A);
  Log(Format('Name stack size: %D', [A]));
  glGetIntegerv(GL_MAX_LIST_NESTING, @A);
  Log(Format('Max nested display lists : %D', [A]));

  Log(' Geometry');
  glGetIntegerv(GL_MAX_LIGHTS, @MaxAPILights);
  Log(Format('Max lights : %D', [MaxAPILights]));
  glGetIntegerv(GL_MAX_CLIP_PLANES, @A);
  Log(Format('Max clipping planes: %D', [A]));

  Log('All extensions: [' + glGetString(GL_EXTENSIONS) + ']');
 {$ENDIF}

  HardwareClipping := True;
  WBuffering := False;
  SquareTextures := False;
  Power2Textures := True;
  MaxTexturesByPass := 2;
  MaxTextureStages := 2;
//  if Caps.DevCaps and D3DDEVCAPS_HWTRANSFORMANDLIGHT > 0 then MaxHardwareLights := Caps.MaxActiveLights else MaxHardwareLights := 0;
  MaxPrimitiveCount := 65536;
  MaxVertexIndex := 65536;

  if GL_ARB_vertex_blend then begin
    GLModelView1 := GL_MODELVIEW1_ARB;
    GLWeightingState := GL_VERTEX_BLEND_ARB;

{    glWeightbvARB := wglGetProcAddress('glWeightbvARB');
    glWeightsvARB := wglGetProcAddress('glWeightsvARB');
    glWeightivARB := wglGetProcAddress('glWeightivARB');}
    glWeightfvARB := wglGetProcAddress('glWeightfvARB');
{    glWeightdvARB := wglGetProcAddress('glWeightdvARB');
    glWeightubvARB := wglGetProcAddress('glWeightubvARB');
    glWeightusvARB := wglGetProcAddress('glWeightusvARB');
    glWeightuivARB := wglGetProcAddress('glWeightuivARB');}
    glWeightPointerARB := wglGetProcAddress('glWeightPointerARB');
    glVertexBlendARB := wglGetProcAddress('glVertexBlendARB');

//    glWeightfvARB := wglGetProcAddress('glWeightfvARB');
//    glWeightPointerARB := wglGetProcAddress('glWeightPointerARB');
  end else;
  if GL_EXT_vertex_weighting then begin
    GLModelView1 := GL_MODELVIEW1_EXT;
    GLWeightingState := GL_VERTEX_WEIGHTING_EXT;
  end else begin
    GLModelView1 := GL_MODELVIEW1_EXT;
    GLWeightingState := GL_VERTEX_WEIGHTING_EXT;
  end;


end;

function TOGLRenderer.CreateViewport(WindowHandle: HWND; ResX, ResY, BpP: Word; AFullScreen: Boolean; AZBufferDepth: Word; UseHardware: Boolean = True; Refresh: Integer = 0): Integer;
var
 ScreenStat: string[30]; 
  Dummy: HPalette;
begin
  State := rsNotReady;
  Result := cvError;
 Log('TOGLRenderer.CreateViewport: Creating viewport', lkTitle); 
//  FrameNumber := 0;
  LastFrame := 0;

  RenderWindowHandle := WindowHandle;

  if not AFullScreen then begin
    if not PrepareWindow then begin

      Log('TOGLRenderer.CreateViewport: Error creating windowed viewport', lkError);

      Exit;
    end;


    ScreenStat := 'Windowed ' + IntToStr(WindowedWidth) + 'x' + IntToStr(WindowedHeight);

  end;

  if HasActiveContext then begin
 Log('TOGLRenderer.CreateViewport: Context already activated. Reactivating...', lkWarning); 
    CloseViewport;
  end;

  OGLDC := GetDC(RenderWindowHandle);
  if (OGLDC = 0) then begin
 Log('TOGLRenderer.CreateViewport: Unable to get a device context', lkFatalError); 
    Exit;
  end;

//  if not HasActiveContext then begin
  ClearExtensions;

  OGLContext := CreateRenderingContext(OGLDC, [opDoubleBuffered], 16, 0, 0, 0, 0, Dummy);
  ActivateRenderingContext(OGLDC, OGLContext);
  MyOpenGLInit;

  Streams.Restore;
  RestoreTextures;

//  end;

// Settings to ensure that the window is the topmost window
  ShowWindow(RenderWindowHandle, SW_SHOW);
  SetForegroundWindow(RenderWindowHandle);
  SetFocus(RenderWindowHandle);

//  WindowedColorDepth := GetBitDepth(D3DDM.Format);


  if OGLContext = 0 then Log('Creating viewport: ' + ScreenStat) else Log('Resetting viewport settings to ' + ScreenStat);

  FFullScreen := AFullScreen;
  HardwareMode := UseHardware;

  ActualZBufferDepth := AZBufferDepth;
  FullScreenWidth := ResX; FullScreenHeight := ResY; FullScreenColorDepth := BpP;
  FullScreenRefresh := Refresh;


  Log('Viewport succesfully created');


  State := rsClean;

//  Events.Add(cmdRendererReady, []);

//  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);   //Realy Nice perspective calculations
  glEnable(GL_TEXTURE_2D);                 // Enable Texture Mapping
  glDisable(GL_COLOR_MATERIAL);
//  glLightModeli(GL_LIGHT_MODEL_COLOR_CONTROL, GL_SEPARATE_SPECULAR_COLOR{ {GL_SINGLE_COLOR});
  glLightModeli(GL_LIGHT_MODEL_COLOR_CONTROL_EXT, GL_SEPARATE_SPECULAR_COLOR_EXT{ {GL_SINGLE_COLOR});
//  glEnable(GL_NORMALIZE);

  inherited CreateViewPort(WindowHandle, ResX, ResY, BpP, AFullScreen, AZBufferDepth, UseHardware, Refresh);

  RenderActive := True;
  Result := cvOK;
end;

function TOGLRenderer.RestoreViewport: Integer;
var i: Integer;
begin
  Result := cvError;

  Log('Restoring viewport', lkTitle);


//  if not HasActiveContext then begin
    Result := CreateViewport(RenderWindowHandle, FullScreenWidth, FullScreenHeight, FullScreenColorDepth, FFullScreen, ActualZBufferDepth, HardwareMode, FullScreenRefresh);
(*    if Result = cvOK  then begin
      if Streams.Restore then begin

        Log('Streams restored');

        if RestoreTextures then begin

          Log('Textures restored');

        end else begin

          Log('Error restoring textures', lkError);

          Exit;
        end;
      end else begin

        Log('Error restoring streams', lkError);

        Exit;
      end;
    end;*)
//  end else PrepareWindow;

  SetViewPort(0, 0, RenderPars.ActualWidth, RenderPars.ActualHeight, 0, 1);
  SetViewMatrix(IdentityMatrix4s);

  if RenderPars.ActualHeight <> 0 then RenderPars.CurrentAspectRatio := RenderPars.ActualWidth/RenderPars.ActualHeight * RenderPars.AspectRatio else RenderPars.CurrentAspectRatio := RenderPars.AspectRatio;
  InitMatrices(RenderPars.FoV, RenderPars.CurrentAspectRatio, RenderPars.ZNear, RenderPars.ZFar);
  SetFog(FogKind, FogColor, FogStart, FogEnd);
  SetShading(ShadingMode);
  SetDithering(Dithering);
  SetClearState(ClearFrameBuffer, ClearZBuffer, ClearStencilBuffer, ClearColor, ClearZ, ClearStencil);
  SetSpecular(SpecularMode);

  for i := 0 to Length(Textures)-1 do DeleteTexture(i);
  RestoreTextures;

  Result := cvOK;
end;

procedure TOGLRenderer.InitMatrices(AXFoV, AAspect: Single; AZNear, AZFar: Single);
begin
  inherited;
  glMatrixMode(GL_PROJECTION);        // Change Matrix Mode to Projection
  glLoadMatrixf(@RenderPars.ProjMatrix);         // Reset View
end;

procedure TOGLRenderer.BeginScene;
begin
  ApplyLights;
end;

procedure TOGLRenderer.EndScene;
begin
end;

{------------------------------------------------------------------}
{  Function to make a texture from the pixel data                  }
{------------------------------------------------------------------}
//procedure glBindTexture(target: GLenum; texture: GLuint); stdcall; external opengl32;
//procedure glGenTextures(n: GLsizei; var textures: GLuint); stdcall; external opengl32;

function TOGLRenderer.LoadToTexture(TextureID: Integer; Data: Pointer): Boolean;
var
  w, h, i, j, Level, LevelsGenerated: Integer; Ofs: Cardinal;
  Tex : glUint;
begin
  Result := False;

//  glPixelStorei(GL_UNPACK_SWAP_BYTES, 1);
//  glPixelStorei(GL_UNPACK_LSB_FIRST, 0);

  glGenTextures(1, @Tex);
  glBindTexture(GL_TEXTURE_2D, Tex);

  LevelsGenerated := 1;

  w := Textures[TextureID].Width; h:= Textures[TextureID].Height;
  Ofs := 0;
  for Level := 0 to LevelsGenerated-1 do begin
    glTexImage2D(GL_TEXTURE_2D, Level, 4, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, Ptr(Cardinal(Data) + Ofs));

    Inc(Ofs, w * h * 4);

    w := w shr 1; if w = 0 then if h = 1 then Break else w := 1;
    h := h shr 1; if h = 0 then h := 1;
  end;

  Textures[TextureID].Texture := Pointer(Tex);

  Textures[TextureID].Levels := LevelsGenerated;

  Result := True;
end;

function TOGLRenderer.UpdateTexture(Src: Pointer; TextureIndex: Integer; Area: TArea): Boolean;
var
  w, h, i, j, k, Level: Integer;
  Res: HResult;
  Rect: TRect;
begin
  Result := False;

  Log('Updating texture', lkTitle);

  if (Src = nil) or (Textures[TextureIndex].Texture = nil) or (TextureIndex = -1) then Exit;

(*  Tex := IDirect3DTexture8(Texture);
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
  end;*)
//  Textures[TextureID].Resource := -1;
  Result := True;
end;

procedure TOGLRenderer.SetViewMatrix(const AMatrix: TMatrix4s);
begin
  if ((State <> rsOK) and (State <> rsClean)) then Exit;

  glMatrixMode(GL_MODELVIEW);
  glLoadMatrixf(@RenderPars.ViewMatrix.m);
  inherited;
end;

function TOGLRenderer.LoadTexture(Filename: string; Width: Word = 0; Height: Word = 0; MipLevels: Word = 0; ColorKey: DWord = 0): Integer;
begin
end;

procedure TOGLRenderer.DeleteTexture(TextureID: Integer);
begin
  glDeleteTextures(1, @Textures[TextureID].Texture);
  inherited;
end;

function TOGLRenderer.GetFVF(CastVertexFormat: DWord): DWord;
begin
end;

function TOGLRenderer.GetBitDepth(Format: LongWord): LongWord;
begin
end;

procedure TOGLRenderer.SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single);
begin
  inherited;
  glViewport(ViewPort.X, ViewPort.Y, ViewPort.Width, ViewPort.Height);    // Set the viewport for the OpenGL window
  glDepthRange(ViewPort.MinZ, ViewPort.MaxZ);
end;

procedure TOGLRenderer.BeginStream(AStream: Cardinal);
begin
  Streams.CurStream := AStream;
  SetLighting(Streams.Streams[Streams.CurStream].VertexFormat and 2 > 0);
  if Streams.Streams[Streams.CurStream].VertexFormat and vfTransformed > 0 then begin  // Set orthogonal projection matrix
    glLoadIdentity;
    glTranslatef(0.375, 0.375 - RenderPars.ActualHeight, 0);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, RenderPars.ActualWidth, 0, RenderPars.ActualHeight, -1, 1);
    glScalef(1, -1, 1);
    glMatrixMode(GL_MODELVIEW);
  end else begin                                                                       // Set perspective projection matrix
    glMatrixMode(GL_PROJECTION);
    glLoadMatrixf(@RenderPars.ProjMatrix);
    glMatrixMode(GL_MODELVIEW);
  end;
  inherited;
end;

procedure TOGLRenderer.EndStream;
begin
  if Streams.Streams[Streams.CurStream].VertexFormat and vfTransformed > 0 then begin
//    glMatrixMode(GL_PROJECTION);  // Change Matrix Mode to Projection
//    glPopMatrix;
//    glMatrixMode(GL_MODELVIEW);   // Change Projection to Matrix Mode
  end;
  inherited;
end;

procedure TOGLRenderer.SetBlending(SrcBlend, DestBlend: Cardinal);
begin
  if (SrcBlend = bmOne) and (DestBlend = bmZero) then glDisable(GL_BLEND) else begin
    glEnable(GL_BLEND);
    glBlendFunc(BlendModes[SrcBlend-1], BlendModes[DestBlend-1]);
  end;
end;

procedure TOGLRenderer.SetFog(Kind: Cardinal; Color: DWord; AFogStart, AFogEnd: Single);
// fkVertex = 1; fkVertexRanged = 2; fkTable = 3;
const glFogModes: array[fkVertex..fkTable] of Longword = (GL_LINEAR, GL_EXP, GL_EXP2);
var FColor: TColorS;
begin
  FogColor := Color;
  FogStart := AFogStart; FogEnd := AFogEnd;
  FogKind := Kind;
  if FogKind <> fkNone then begin
    if FogKind = fkVertex then glHint(GL_FOG_HINT, GL_FASTEST) else glHint(GL_FOG_HINT, GL_NICEST);
    glFogi(GL_FOG_MODE, glFogModes[1{+0*Kind}]);
    glFogf(GL_FOG_START, FogStart);
    glFogf(GL_FOG_END, FogEnd);
    FColor := ColorDToS(FogColor);
    glFogfv(GL_FOG_COLOR, @FColor);
    glEnable(GL_FOG);
  end else glDisable(GL_FOG);
end;

procedure TOGLRenderer.SetCullMode(CMode: DWord);
begin
  glCullFace(CCullModes[CMode]);
  if CMode = cmNone then glDisable(GL_CULL_FACE) else glEnable(GL_CULL_FACE);
end;

procedure TOGLRenderer.SetZTest(ZTestMode, TestFunc: Cardinal);
begin
  if TestFunc = tfAlways then glDisable(GL_DEPTH_TEST) else begin
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(TestFuncs[TestFunc]);
  end;
end;

procedure TOGLRenderer.SetAlphaTest(AlphaRef, TestFunc: Cardinal);
begin
  if TestFunc = tfAlways then glDisable(GL_ALPHA_TEST) else glEnable(GL_ALPHA_TEST);
  glAlphaFunc(TestFuncs[TestFunc], AlphaRef * OneOver255);
end;

procedure TOGLRenderer.SetZWrite(ZWrite: Boolean);
begin
  glDepthMask(ZWrite);
end;

procedure TOGLRenderer.SetBlendOperation(BOperation: Cardinal);
const BlendEqs: array[boADD..boMAX] of Cardinal = (GL_FUNC_ADD, GL_FUNC_SUBTRACT, GL_FUNC_REVERSE_SUBTRACT, GL_MIN, GL_MAX);
begin
  glBlendEquation(BlendEqs[BOperation]);
end;

procedure TOGLRenderer.SetColorMask(Alpha, Red, Green, Blue: Boolean);
begin
  glColorMask(Red, Green, Blue, Alpha);
end;

procedure TOGLRenderer.SetLighting(HardLighting: Boolean);
begin
  if HardLighting then glEnable(GL_LIGHTING) else glDisable(GL_LIGHTING);
  glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, 0);
end;

procedure TOGLRenderer.SetTextureFiltering(const Stage: Integer; const MagFilter, MinFilter, MipFilter: DWord);
var MinFil: Cardinal;
begin
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, CTFilters[MagFilter]); { only first two can be used }
  if {(Textures[AMaterial.Stages[Stage].TextureID].Levels > 0) and }(MipFilter = tfNone) then MinFil := CTFilters[MinFilter] else begin
//  tfNone, tfPoint, tfLinear, tfAnisotropic
    case MinI(tfLinear, MipFilter*2) + MaxI(tfPoint, MinI(tfLinear, MinFilter)) of
      tfPoint*2 + tfPoint: MinFil := GL_NEAREST_MIPMAP_NEAREST;
      tfPoint*2 + tfLinear: MinFil := GL_LINEAR_MIPMAP_NEAREST;
      tfLinear*2 + tfPoint: MinFil := GL_NEAREST_MIPMAP_LINEAR;
      tfLinear*2 + tfLinear: MinFil := GL_LINEAR_MIPMAP_LINEAR;
    end;
  end;
  MinFil := GL_Linear;
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, MinFil);
end;

procedure TOGLRenderer.SetShading(AShadingMode: Cardinal);
begin
  ShadingMode := AShadingMode;
  if ShadingMode = smFlat then glShadeModel(GL_FLAT) else glShadeModel(GL_SMOOTH);
end;

procedure TOGLRenderer.SetDithering(ADithering: Boolean);
begin
  if ADithering then glEnable(GL_DITHER) else glDisable(GL_DITHER);
end;

procedure TOGLRenderer.SetSpecular(ASpecular: Cardinal);
begin
  inherited;
  glLightModeli(GL_LIGHT_MODEL_LOCAL_VIEWER, Ord(SpecularMode = slQuality));
end;

procedure TOGLRenderer.ApplyRenderState(State, Value: DWord);
begin
end;

procedure TOGLRenderer.ApplyLights;
var i: Integer;
begin
  SetAmbient(AmbientColor);
  ActiveHardwareLights := 0;
  for i := 0 to Length(Lights)-1 do if Lights[i].LightOn then begin
{    case Lights[i].LightType of
      ltDirectional: _Type := D3DLIGHT_DIRECTIONAL;
      ltOmniNoShadow: _Type := D3DLIGHT_POINT;
      ltSpotNoShadow: _Type := D3DLIGHT_SPOT;
    end;}

    SetLight(i, Lights[i]);
  end else glDisable(GL_LIGHT0+i);
end;

procedure TOGLRenderer.SetLight(Index: Integer; ALight: TLight);
var Pos: TVector4s;
begin
//  if Index >= MaxAPILights then Exit;
  if not Lights[Index].LightOn then Inc(ActiveHardwareLights);                    // Increase if old light was off
  inherited;

  if (State <> rsOK) and (State <> rsClean) then Exit;

//  ALight.Diffuse.R := 0;
  glLightfv(GL_LIGHT0+Index, GL_AMBIENT, @ALight.Ambient);
  glLightfv(GL_LIGHT0+Index, GL_DIFFUSE, @ALight.Diffuse);
  glLightfv(GL_LIGHT0+Index, GL_SPECULAR, @ALight.Specular);

  if ALight.LightType = ltDirectional then
   Pos := GetVector4s(-ALight.Location.X, -ALight.Location.Y, -ALight.Location.Z, 0) else
    Pos := GetVector4s(ALight.Location.X, ALight.Location.Y, ALight.Location.Z, 1);

  glLightfv(GL_LIGHT0+Index, GL_POSITION, @Pos);
  glLightfv(GL_LIGHT0+Index, GL_SPOT_DIRECTION, @ALight.Direction);

//    Range := Lights[i].Range;
//    Falloff := Lights[i].Falloff;

  glLightf(GL_LIGHT0+Index, GL_CONSTANT_ATTENUATION, ALight.Attenuation0);
  glLightf(GL_LIGHT0+Index, GL_LINEAR_ATTENUATION, ALight.Attenuation1);
  glLightf(GL_LIGHT0+Index, GL_QUADRATIC_ATTENUATION, ALight.Attenuation2);

//    Theta := Lights[i].Theta;
//    Phi := Lights[i].Phi;

  glEnable(GL_LIGHT0+Index);
  Lights[Index].LightOn := True;
end;

procedure TOGLRenderer.SetAmbient(Color: Longword);
var SAmbient: TColors;
begin
  AmbientColor := Color;
  SAmbient := ColorDToS(AmbientColor);
  glLightModelfv(GL_LIGHT_MODEL_AMBIENT, @SAmbient);
end;

procedure TOGLRenderer.DeleteLight(Index: Cardinal);
begin
  if Lights[Index].LightOn then Dec(ActiveHardwareLights);
  Lights[Index].LightOn := False;
  glDisable(GL_LIGHT0+Index);
end;

procedure TOGLRenderer.ApplyMaterial(AMaterial: TMaterial);

procedure UseCombineExt(Stage: TStage);
{ toDisable = 0; toARG1 = 1; toARG2 = 2;
  toModulate = 3; toModulate2X = 4; toModulate4X = 5;
  toAdd = 6; toSignedAdd = 7; toSignedAdd2X = 8;
  toSub = 9; toSmoothAdd = 10;
  toBlendDiffuseAlpha = 11; toBlendTextureAlpha = 12; toBlendFactorAlpha = 13;
  toBlendTextureAlphaPM = 14; toBlendCurrentAlphaPM = 15;
  toPremodulate = 16;
  toModulateAlpha_AddColor = 17; toModulateColor_AddAlpha = 18;
  toModulateInvAlpha_AddColor = 19; toModulateInvColor_AddAlpha = 20;
  toBumpEnv = 21; toBumpEnvLum = 22;
  toDotproduct3 = 23;
  toMultiplyAdd = 24; toLERP = 25;}
const GLOp: array[toDisable..toLerp] of Cardinal = (GL_REPLACE, GL_REPLACE, GL_REPLACE,
                                                    GL_MODULATE, GL_MODULATE, GL_MODULATE,
                                                    GL_ADD, GL_ADD_SIGNED_EXT, GL_ADD_SIGNED_EXT,
                                                    GL_ADD, GL_ADD,
                                                    GL_INTERPOLATE_EXT, GL_INTERPOLATE_EXT, GL_INTERPOLATE_EXT,
                                                    GL_INTERPOLATE_EXT, GL_INTERPOLATE_EXT,
                                                    GL_MODULATE,
                                                    GL_INTERPOLATE_EXT, GL_INTERPOLATE_EXT,
                                                    GL_INTERPOLATE_EXT, GL_INTERPOLATE_EXT,
                                                    GL_MODULATE, GL_MODULATE,
                                                    GL_DOT3,
                                                    GL_MODULATE,
                                                    GL_INTERPOLATE_EXT);
// taDiffuse = 0; taCurrent = 1; taTexture = 2; taSpecular = 3;

procedure StageToCombinerExt(Alpha: Boolean; StageOp, StageArg1, StageArg2: Longword; var Op, Arg0, Arg1, Arg2, Op0, Op1, Op2, Scale: Longword);
const GLArg: array[taDiffuse..taTexture] of Longword = (GL_PRIMARY_COLOR_EXT, GL_PREVIOUS_EXT, GL_TEXTURE);
begin
  if StageOp = toDisable then begin Op := GL_MODULATE; Scale := 1; Exit; end;
  if StageArg1 = taTemp then StageArg1 := taCurrent;
  if StageArg2 = taTemp then StageArg2 := taCurrent;
  if StageArg1 = taSpecular then StageArg1 := taDiffuse;
  if StageArg2 = taSpecular then StageArg2 := taDiffuse;
  Op := GL_MODULATE; Arg0 := GL_PRIMARY_COLOR_EXT; Arg1 := GL_TEXTURE; Arg2 := GL_PRIMARY_COLOR_EXT;
  Scale := 1;
  if Alpha then begin
    Op0 := GL_SRC_ALPHA; Op1 := GL_SRC_ALPHA; Op2 := GL_SRC_ALPHA;
  end else begin
    Op0 := GL_SRC_COLOR; Op1 := GL_SRC_COLOR; Op2 := GL_SRC_COLOR;
  end;
  case StageOp*9 + StageArg1*3 + StageArg2 of
    toARG1*9 + taDiffuse*3 + taDiffuse..toARG1*9 + taTexture*3 + taTexture: begin
      Op := GL_REPLACE; Arg0 := GLArg[StageArg1];
    end;
    toARG2*9 + taDiffuse*3 + taDiffuse..toARG2*9 + taTexture*3 + taTexture: begin
      Op := GL_REPLACE; Arg0 := GLArg[StageArg2];
    end;
    toModulate*9 + taDiffuse*3 + taDiffuse..toModulate*9 + taTexture*3 + taTexture: begin
      Op := GL_MODULATE; Arg0 := GLArg[StageArg1]; Arg1 := GLArg[StageArg2];
    end;
    toModulate2X*9 + taDiffuse*3 + taDiffuse..toModulate2X*9 + taTexture*3 + taTexture: begin
      Op := GL_MODULATE; Arg0 := GLArg[StageArg1]; Arg1 := GLArg[StageArg2]; Scale := 2;
    end;
    toModulate4X*9 + taDiffuse*3 + taDiffuse..toModulate4X*9 + taTexture*3 + taTexture: begin
      Op := GL_MODULATE; Arg0 := GLArg[StageArg1]; Arg1 := GLArg[StageArg2]; Scale := 4;
    end;
    toAdd*9 + taDiffuse*3 + taDiffuse..toAdd*9 + taTexture*3 + taTexture: begin
      Op := GL_ADD; Arg0 := GLArg[StageArg1]; Arg1 := GLArg[StageArg2];
    end;
    toSignedAdd*9 + taDiffuse*3 + taDiffuse..toSignedAdd*9 + taTexture*3 + taTexture: begin
      Op := GL_ADD_SIGNED_EXT; Arg0 := GLArg[StageArg1]; Arg1 := GLArg[StageArg2];
    end;
    toSignedAdd2X*9 + taDiffuse*3 + taDiffuse..toSignedAdd2X*9 + taTexture*3 + taTexture: begin
      Op := GL_ADD_SIGNED_EXT; Arg0 := GLArg[StageArg1]; Arg1 := GLArg[StageArg2]; Scale := 2;
    end;
  end;
end;

var Op, Arg0, Arg1, Arg2, Op0, Op1, Op2, Scale: Longword;

begin
//  glActiveTextureARB(GL_TEXTURE0_ARB);

  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE_EXT);

  StageToCombinerExt(False, Stage.ColorOp, Stage.ColorArg1, Stage.ColorArg2, Op, Arg0, Arg1, Arg2, Op0, Op1, Op2, Scale);

  glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB_EXT, Op);
  glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB_EXT, Arg0);
  glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB_EXT, Arg1);
  glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB_EXT, Arg2);
  glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB_EXT, Op0);
  glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB_EXT, Op1);
  glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_RGB_EXT, Op2);
  glTexEnvi(GL_TEXTURE_ENV, GL_RGB_SCALE_EXT, Scale);


  StageToCombinerExt(True, Stage.AlphaOp, Stage.AlphaArg1, Stage.AlphaArg2, Op, Arg0, Arg1, Arg2, Op0, Op1, Op2, Scale);

  glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA_EXT, Op);
  glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_ALPHA_EXT, Arg0);
  glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_ALPHA_EXT, Arg1);
  glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA_EXT, Arg2);
  glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA_EXT, Op0);
  glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA_EXT, Op1);
  glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_ALPHA_EXT, Op2);
  glTexEnvi(GL_TEXTURE_ENV, GL_ALPHA_SCALE, Scale);

end;

begin
  if AMaterial.FillMode = fmDefault then
   glPolygonMode(GL_FRONT_AND_BACK, FillModes[FillMode]) else
    glPolygonMode(GL_FRONT_AND_BACK, FillModes[AMaterial.FillMode]);
//  AMaterial.Diffuse.A := 0; AMaterial.Specular.A := 0;AMaterial.Ambient.A := 0;

  glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, @AMaterial.Ambient);
  glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, @AMaterial.Diffuse);
//  AMaterial.Specular.R := 0;
  glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, @AMaterial.Specular);

  glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, AMaterial.Power);

  glBindTexture(GL_TEXTURE_2D, Cardinal(Textures[AMaterial.Stages[0].TextureInd].Texture));

  UseCombineExt(AMaterial.Stages[0]);

  SetTextureFiltering(0, AMaterial.Stages[0].MagFilter, AMaterial.Stages[0].MinFilter, AMaterial.Stages[0].MipFilter);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, CTAddressing[AMaterial.Stages[0].TAddressing]);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, CTAddressing[AMaterial.Stages[0].TAddressing]);
end;

function TOGLRenderer.BeginPasses(Obj: TTesselator): Boolean;

procedure InitVertexWeighting;
begin
  if GL_ARB_vertex_blend then begin
    glEnable(GL_WEIGHT_SUM_UNITY_ARB);
    glVertexBlendARB(Obj.VertexFormat shr 16+1);
  end;

  glMatrixMode(GLModelView1);
  glLoadMatrixf(@RenderPars.ViewMatrix);
  glMultMatrixf(@WorldMatrix1);
  glEnable(GLWeightingState);
end;

begin
  Result := inherited BeginPasses(Obj);

  if Obj.VertexFormat and vfTransformed = 0 then begin
    if Obj.VertexFormat shr 16 > 0 then begin           // Weights included
      InitVertexWeighting;
    end else begin
      glDisable(GLWeightingState);
    end;
    glMatrixMode(GL_MODELVIEW);
    glLoadMatrixf(@RenderPars.ViewMatrix);
    glMultMatrixf(@WorldMatrix);
  end;
end;

procedure TOGLRenderer.EndPasses;
begin
  inherited;
end;

procedure TOGLRenderer.BeginRenderPass(Pass: TRenderPass);
begin
  inherited;
  SetBlending(Pass.SrcBlend, Pass.DestBlend);
  SetAlphaTest(Pass.AlphaRef, Pass.ATestFunc);
  SetZTest(0, Pass.ZTestFunc);
  SetZWrite(Pass.ZWrite);
end;

procedure TOGLRenderer.EndRenderPass(Pass: TRenderPass);
begin
  inherited;
end;

procedure TOGLRenderer.AddTesselator(Obj: TTesselator);
const Strips = 24;
var
  i, j, Strip, Ind, VCount: Integer; Offset, EOffset: Cardinal; Point: TVector3s;

begin
//  if not Enabled then Exit;                // ToFix: Move render state checking to CAST main unit
  if (State <> rsOK) and (State <> rsClean) then Exit;
  if Obj.TotalVertices = 0 then Exit;

  glEnableClientState(GL_VERTEX_ARRAY);
  if Obj.VertexFormat shr 16 > 0 then begin           // Weights included
    GetVertexElementOffset(Obj.VertexFormat, vfiWeight);
    if GL_ARB_vertex_blend then
     glEnableClientState(GL_WEIGHT_ARRAY_ARB) else
      if GL_EXT_vertex_weighting then
       glEnableClientState(GL_VERTEX_WEIGHT_ARRAY_EXT);
  end;
  if Obj.VertexFormat and vfNormals > 0 then begin
    glEnableClientState(GL_NORMAL_ARRAY);
  end else glDisableClientState(GL_NORMAL_ARRAY);
  if Obj.VertexFormat and vfDiffuse > 0 then begin
    glEnableClientState(GL_COLOR_ARRAY);
  end else glDisableClientState(GL_COLOR_ARRAY);
  if (Integer(Obj.VertexFormat) shr 8) and 255 > 0 then begin
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
  end else glDisableClientState(GL_TEXTURE_COORD_ARRAY);

  if Obj.TotalIndices > 0 then VCount := Obj.TotalIndices else case Obj.PrimitiveType of
    GL_POINTS: VCount := Obj.TotalPrimitives;
    GL_LINES: VCount := Obj.TotalPrimitives*2;
    GL_LINE_STRIP: VCount := Obj.TotalPrimitives+1;
    GL_TRIANGLES: VCount := Obj.TotalPrimitives*3;
    GL_TRIANGLE_STRIP: VCount := Obj.TotalPrimitives+2;
    GL_TRIANGLE_FAN: VCount := Obj.TotalPrimitives+2;
    GL_QUADS: VCount := Obj.TotalPrimitives*4;
    GL_QUAD_STRIP: VCount := Obj.TotalPrimitives+2;
    GL_POLYGON: VCount := Obj.TotalVertices;
  end;

  for Strip := 0 to Obj.TotalStrips-1 do begin
    Offset := Cardinal((Streams as TOGLRenderStreams).VertexBuffer[Streams.CurStream]) +
                       (Obj.VBOffset) * Streams.Streams[Streams.CurStream].VertexSize + Strip * Obj.StripOffset;
//    glInterleavedArrays(GL_T2F_C4UB_V3F, 0*Obj.VertexSize, PTR(Offset));

    if (Integer(Obj.VertexFormat) shr 16) and 255 > 0 then if GL_ARB_vertex_blend then
     glWeightPointerARB(1, GL_FLOAT, Obj.VertexSize, PTR(Offset + GetVertexElementOffset(Obj.VertexFormat, vfiTex))) else
      if GL_EXT_vertex_weighting then
       glVertexWeightPointerEXT(1, GL_FLOAT, Obj.VertexSize, PTR(Offset + GetVertexElementOffset(Obj.VertexFormat, vfiTex)));
    if Obj.VertexFormat and vfNormals > 0 then glNormalPointer(GL_FLOAT, Obj.VertexSize, PTR(Offset + GetVertexElementOffset(Obj.VertexFormat, vfiNorm)));
    if Obj.VertexFormat and vfDiffuse > 0 then glColorPointer(4, GL_UNSIGNED_BYTE, Obj.VertexSize, PTR(Offset + GetVertexElementOffset(Obj.VertexFormat, vfiDiff)));
    if (Integer(Obj.VertexFormat) shr 8) and 255 > 0 then glTexCoordPointer(2, GL_FLOAT, Obj.VertexSize, PTR(Offset + GetVertexElementOffset(Obj.VertexFormat, vfiTex)));

    glVertexPointer(3, GL_FLOAT, Obj.VertexSize, PTR(Offset));
    glLockArraysEXT(0, VCount);

    if Obj.TotalIndices > 0 then begin
      glDrawElements(Obj.PrimitiveType, VCount, GL_UNSIGNED_SHORT, PTR(Cardinal((Streams as TOGLRenderStreams).IndexBuffer[Streams.CurStream]) + Obj.IBOffset*2))
//      for i := 0 to Strips-1 do
//       glDrawRangeElementsEXT(Obj.PrimitiveType, 0, 4096, VCount div Strips, GL_UNSIGNED_SHORT, PTR(Cardinal((Streams as TOGLRenderStreams).IndexBuffer[Streams.CurStream]) + Obj.IBOffset*2 + i*VCount div Strips div 2))
//      glDrawRangeElementsEXT(Obj.PrimitiveType, 0, 4096, 3*Obj.TotalPrimitives, GL_UNSIGNED_SHORT, PTR(Cardinal((Streams as TOGLRenderStreams).IndexBuffer[Streams.CurStream]) + Obj.IBOffset*2))
    end else begin
//       glBegin(Obj.PrimitiveType);
       glDrawArrays(Obj.PrimitiveType, 0, VCount);
//       glEnd;
     end;

    glUnlockArraysEXT;
  end;
end;

procedure TOGLRenderer.Clear(ClearTarget: Cardinal; Color: Cardinal; Z: Single; Stencil: Cardinal);
var Res: HResult; i: Integer;
begin
  if (State = rsLost) and (GetTickCount - LostTime > MaxLostTime) then begin
    State := rsTryToRestore;

    Log('No device restoration attempts in ' + IntToStr(MaxLostTime) + ' millisecondss. Forcing restoration', lkWarning);

  end;
  if (State <> rsOK) and (State <> rsClean) then Exit;
//  if State = rsTryToRestore then begin RestoreViewport; Exit; end;

  if ClearZBuffer then SetZWrite(True);
  glClearColor(((Color shr 16) and $FF)*OneOver255, ((Color shr 8) and $FF)*OneOver255, (Color and $FF)*OneOver255, ((ClearColor shr 24) and $FF)*OneOver255);
  glClearDepth(Z);
  glClearStencil(Stencil);
  glClear(GL_COLOR_BUFFER_BIT*Ord(ClearFrameBuffer) or GL_DEPTH_BUFFER_BIT*Ord(ClearZBuffer) or GL_STENCIL_BITS*Ord(ClearStencilBuffer));
end;

procedure TOGLRenderer.Render;
var Res: HResult; i: Integer;

procedure Box(X, Y, Z, Dim: Single);
begin
  glBegin(GL_QUADS);
//  glColor3f(1, 1, 1);
  // Front Face
  glNormal3f( 0.0, 0.0, 1.0);
  glTexCoord2f(0.0, 0.0);
  glVertex3f(X-Dim, Y-Dim, Z+ Dim);
  glTexCoord2f(1.0, 0.0);
  glVertex3f(X+ Dim, Y-Dim, Z+ Dim);
  glTexCoord2f(1.0, 1.0);
  glVertex3f(X+ Dim, Y+ Dim, Z+ Dim);
  glTexCoord2f(0.0, 1.0);
  glVertex3f(X-Dim, Y+ Dim, Z+ Dim);
  // Back Face
//  glColor3f(1, 1, 0);
  glNormal3f( 0.0, 0.0,-1.0);
  glTexCoord2f(1.0, 0.0);
  glVertex3f(X-Dim, Y-Dim, Z-Dim);
  glTexCoord2f(1.0, 1.0);
  glVertex3f(X-Dim, Y+ Dim, Z-Dim);
  glTexCoord2f(0.0, 1.0);
  glVertex3f(X+ Dim, Y+ Dim, Z-Dim);
  glTexCoord2f(0.0, 0.0);
  glVertex3f(X+ Dim, Y-Dim, Z-Dim);
  // Top Face
//  glColor3f(1, 0, 0);
  glNormal3f( 0.0, 1.0, 0.0);
  glTexCoord2f(0.0, 0.0);
  glVertex3f(X-Dim, Y+ Dim, Z-Dim);
  glTexCoord2f(1.0, 0.0);
  glVertex3f(X-Dim, Y+ Dim, Z+ Dim);
  glTexCoord2f(1.0, 1.0);
  glVertex3f(X+ Dim, Y+ Dim, Z+ Dim);
  glTexCoord2f(0.0, 1.0);
  glVertex3f(X+ Dim, Y+ Dim, Z-Dim);
  // Bottom Face
//  glColor3f(1, 0, 1);
  glNormal3f( 0.0,-1.0, 0.0);
  glTexCoord2f(1.0, 0.0);
  glVertex3f(X-Dim, Y-Dim, Z-Dim);
  glTexCoord2f(0.0, 0.0);
  glVertex3f(X+ Dim, Y-Dim, Z-Dim);
  glTexCoord2f(0.0, 1.0);
  glVertex3f(X+ Dim, Y-Dim, Z+ Dim);
  glTexCoord2f(1.0, 1.0);
  glVertex3f(X-Dim, Y-Dim, Z+Dim);
  // Right face
//  glColor3f(0, 0, 1);
  glNormal3f( 1.0, 0.0, 0.0);
  glTexCoord2f(1.0, 0.0);
  glVertex3f(X+ Dim, Y-Dim, Z-Dim);
  glTexCoord2f(1.0, 1.0);
  glVertex3f(X+ Dim, Y+ Dim, Z-Dim);
  glTexCoord2f(0.0, 1.0);
  glVertex3f(X+ Dim, Y+ Dim, Z+ Dim);
  glTexCoord2f(0.0, 0.0);
  glVertex3f(X+ Dim, Y-Dim, Z+ Dim);
  // Left Face
//  glColor3f(0, 1, 1);
  glNormal3f(-1.0, 0.0, 0.0);
  glTexCoord2f(0.0, 0.0);
  glVertex3f(X-Dim, Y-Dim, Z-Dim);
  glTexCoord2f(1.0, 0.0);
  glVertex3f(X-Dim, Y-Dim, Z+ Dim);
  glTexCoord2f(1.0, 1.0);
  glVertex3f(X-Dim, Y+ Dim, Z+ Dim);
  glTexCoord2f(0.0, 1.0);
  glVertex3f(X-Dim, Y+ Dim, Z-Dim);
  glEnd();
end;

var Pattern: array[0..4*32-1] of Longword;

begin
//  Box(0, 0, 0, 1000);
//  FillChar(Pattern, 4*32, 0);
//  for i := 0 to 100 do Pattern[Random(32*4)] := $FFFFFFFF;
//  glEnable(GL_POLYGON_STIPPLE);
//  glPolygonStipple(@Pattern);

  if (State <> rsOK) and (State <> rsClean){ or not RenderActive} then begin Sleep(1); Exit; end;

  if RenderActive then begin
//    glFlush;
    SwapBuffers(OGLDC);                  // Display the scene
  end;  


  if not RenderActive then begin Sleep(1); Exit; end;

  State := rsOK;

  Clear($FFFFFFFF, ClearColor, ClearZ, ClearStencil);
  for i := 0 to TotalStreams - 1 do with Streams.Streams[i] do begin
    CurVBOffset := 0; CurIBOffset := 0;
  end;

  Inc(FrameNumber);
end;

procedure TOGLRenderer.CloseViewport;
var i: Integer;
begin
  inherited;

  if OGLContext = 0 then Log('TOGLRenderer.CloseViewport: Viewport was not opened', lkWarning);


  DeactivateRenderingContext;
  DestroyRenderingContext(OGLContext);

  OGLContext := 0;

  // Attemps to release the device context
  ReleaseDC(RenderWindowHandle, OGLDC);
  OGLDC := 0;
end;

destructor TOGLRenderer.Shutdown;
begin
  inherited;
  CloseOpenGL;
end;

procedure TOGLRenderer.SetFullScreen(const FScreen: Boolean);
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

function TOGLRenderer.RestoreDevice: Boolean;
begin
end;

{ TOGLDispListRenderer }

procedure TOGLDispListRenderer.AddTesselator(Obj: TTesselator);
var
  i, j, Strip, Ind, VCount: Integer; Offset, EOffset: Cardinal; Point: TVector3s;
  c: packed record R, G, B, A: Byte; end;
begin
//  inherited;
//  if not Enabled then Exit;                // ToFix: Move render state checking to CAST main unit
  if (State <> rsOK) and (State <> rsClean) then Exit;
  if Obj.TotalVertices = 0 then Exit;

  for Strip := 0 to Obj.TotalStrips-1 do begin
    glBegin(Obj.PrimitiveType);
    case Obj.PrimitiveType of
      GL_POINTS: VCount := Obj.TotalPrimitives;
      GL_LINES: VCount := Obj.TotalPrimitives*2;
      GL_LINE_STRIP: VCount := Obj.TotalPrimitives+1;
      GL_TRIANGLES: VCount := Obj.TotalPrimitives*3;
      GL_TRIANGLE_STRIP: VCount := Obj.TotalPrimitives+2;
      GL_TRIANGLE_FAN: VCount := Obj.TotalPrimitives+2;
      GL_QUADS: VCount := Obj.TotalPrimitives*4;
      GL_QUAD_STRIP: VCount := Obj.TotalPrimitives+2;
      GL_POLYGON: if Obj.TotalIndices > 0 then VCount := Obj.TotalIndices else VCount := Obj.TotalVertices;
    end;

    for i := 0 to VCount-1 do begin
      if Obj.TotalIndices > 0 then
       Ind := TWordBuffer((Streams as TOGLRenderStreams).IndexBuffer[Streams.CurStream]^)[Obj.IBOffset + i] else
        Ind := i;
      Offset := Cardinal((Streams as TOGLRenderStreams).VertexBuffer[Streams.CurStream]) +
               (Obj.VBOffset + Ind) * Streams.Streams[Streams.CurStream].VertexSize + Strip * Obj.StripOffset;

  //  vfiNorm = 1; vfiDiff = 2; vfiSpec = 3; vfiTex = 4; vfiWeight = 5;
  // vfTransformed = 1; vfNormals = 2; vfDiffuse = 4; vfSpecular = 8;
      if Obj.VertexFormat shr 16 > 0 then begin           // Weights included
        EOffset := Offset + GetVertexElementOffset(Obj.VertexFormat, vfiWeight);
        if GL_ARB_vertex_blend then
         glWeightfvARB(Obj.VertexFormat shr 16, PTR(EOffset)) else
          if GL_EXT_vertex_weighting then
           glVertexWeightfvEXT(PTR(EOffset));
      end;
      if Obj.VertexFormat and vfNormals > 0 then begin
//        Point := TVector3s(Ptr(Offset + GetVertexElementOffset(Obj.VertexFormat, vfiNorm))^);
        EOffset := Offset + GetVertexElementOffset(Obj.VertexFormat, vfiNorm);
        glNormal3fv(PTR(EOffset));
      end;
      if Obj.VertexFormat and vfDiffuse > 0 then begin
        EOffset := Offset + GetVertexElementOffset(Obj.VertexFormat, vfiDiff);
        glColor4ubv(PTR(EOffset));
//        c.R := $FF; c.G := $C0; c.B := $0; c.A := $FF;
//        glColor4ubv(@c);
//        glColor4ub(PByte(EOffset+2)^, PByte(EOffset+1)^, PByte(EOffset+0)^, PByte(EOffset+3)^);
      end;
      for j := 0 to (Integer(Obj.VertexFormat) shr 8) and 255-1 do begin
        EOffset := Offset + GetVertexElementOffset(Obj.VertexFormat, vfiTex) + j * 8;
        glTexCoord2fv(PTR(EOffset));
      end;
//      Point := TVector3s(Ptr(Offset)^);
//      if Obj.VertexFormat and vfTransformed > 0 then Point.Y := RenderPars.ActualHeight-Point.Y;
//      glVertex3f(Point.X, Point.Y, Point.Z);
      glVertex3fv(PTR(Offset));
    end;
    glEnd;
  end;
end;

function TOGLDispListRenderer.BeginPasses(Obj: TTesselator): Boolean;
begin
  inherited BeginPasses(Obj);

  Result := False;
  if (Obj.CommandBlock <= 0) or not glIsList(Obj.CommandBlock) then begin
    Obj.CommandBlock := glGenLists(1);
    Result := True;
  end;
  Result := Result or not Obj.CommandBlockValid;
  if Result then glNewList(Obj.CommandBlock, GL_COMPILE_AND_EXECUTE) else glCallList(Obj.CommandBlock);

// Result := True;
end;

procedure TOGLDispListRenderer.EndPasses;
begin
  inherited;
  glEndList;
end;

end.
