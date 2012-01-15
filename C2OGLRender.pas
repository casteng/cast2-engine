(*
 @Abstract(CAST Engine OpenGL render unit (incomplete) )
 (C) 2009 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains OpenGL-based renderer implementation classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2OGLRender;

interface

uses
  BaseTypes, BaseStr, Basics, Base3D, Collisions, OSUtils,
  Logger, BaseDebug,
  BaseClasses,
  C2Types, CAST2, C2Res, C2Visual, C2Render, C2Materials,
  dglOpenGL,
  {$IFDEF WINDOWS}
    Windows, Messages,
  {$ENDIF}
  SysUtils;

type
  TOGLVertexBuffer = record
    VertexSize, BufferSize: Integer;
    Static: Boolean;
    BufferID: Cardinal;
    Data: Pointer;
  end;

  TOGLIndexBuffer = record
    BufferSize: Integer;
    Static: Boolean;
    BufferID: Cardinal;
    Data: Pointer;
  end;

  // @Abstract(Simple OpenGL implementation of vertex and index buffers management class)
  TOGLBuffers = class(TAPIBuffers)
  private
    VertexBuffers: array of TOGLVertexBuffer;
    IndexBuffers: array of TOGLIndexBuffer;
  public
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

  TOGLTextures = class(C2Render.TTextures)
  private
    function GetTexture(const Index: Integer): TTexture;
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
    property Texture[const Index: Integer]: TTexture read GetTexture;
  end;

  TOGLStateWrapper = class(C2Render.TAPIStateWrapper)
  protected
    function APICreateRenderTarget(Index, Width, Height: Integer; AColorFormat, ADepthFormat: Cardinal): Boolean; override;
    procedure DestroyRenderTarget(Index: Integer); override;

    // Calls an API to set a shader constant
    procedure APISetShaderConstant(const Constant: TShaderConstant); overload; override;
    // Calls an API to set a shader constant. <b>ShaderKind</b> - kind of shader, <b>ShaderRegister</b> - index of 4-component vector register to set, <b>Vector</b> - new value of the register.
    procedure APISetShaderConstant(ShaderKind: TShaderKind; ShaderRegister: Integer; const Vector: TShaderRegisterType); overload; override;

    function CreateVertexShader(Item: TShaderResource; Declaration: TVertexDeclaration): Integer; override;
    function CreatePixelShader(Item: TShaderResource): Integer; override;

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

  TOGLRenderer = class(TRenderer)
  private
    MixedVPMode,
    LastFullScreen: Boolean;
    GLModelView1, GLWeightingState: Longword;
    {$IFDEF WINDOWS}
      OGLContext: HGLRC;                    // OpenGL rendering context
      OGLDC: HDC;
    {$ENDIF}
    {$IFDEF LINUX}
      OGLContext: GLXContext;
      OGLDrawable: GLXDrawable;
    {$ENDIF}
    procedure SetModelMatrix(MatPtr: Pointer);
  protected
    function APICheckFormat(const Format, Usage, RTFormat: Cardinal): Boolean; override;

    procedure APIApplyCamera(Camera: TCamera); override;

    procedure APIPrepareFVFStates(Item: TVisible); override;

    procedure InternalDeInit; override;
  public
    constructor Create(Manager: TItemsManager); override;

    procedure SetGamma(Gamma, Contrast, Brightness: Single); override;

    procedure CheckCaps; override;
    procedure CheckTextureFormats; override;

    function APICreateDevice(WindowHandle, AVideoMode: Cardinal; AFullScreen: Boolean): Boolean; override;
    function RestoreDevice(AVideoMode: Cardinal; AFullScreen: Boolean): Boolean; override;
    procedure CloseViewport;

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

  function ReportGLErrorDebug(const ErrorLabel: string): Cardinal; {$I inline.inc}
  function ReportGLError(const ErrorLabel: string): Cardinal; {$I inline.inc}
  procedure ReportGLShaderError(ShaderId: Integer; const ErrorLabel, ResourceName: string); {$I inline.inc}

implementation

const
  MaxTexturesAllowed = 8;
  GLTextureI: array[0..MaxTexturesAllowed-1] of Cardinal = (GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, GL_TEXTURE3, GL_TEXTURE4, GL_TEXTURE5, GL_TEXTURE6, GL_TEXTURE7);

var
  // Pixel data formats and types
  DFFormats, DTFormats: array[0..TotalPixelFormats-1] of Longword;

// Check and report to log OpenGL error only if debug mode is on
function ReportGLErrorDebug(const ErrorLabel: string): Cardinal; {$I inline.inc}
begin
  {$IFDEF DEBUGMODE}
    Result := glGetError();
    if Result <> GL_NO_ERROR then Log(ErrorLabel + ' Error #: ' + IntToStr(Result) + '(' + gluErrorString(Result) + ') at'#13#10 + GetStackTraceStr(1), lkError);
  {$ELSE}
    Result := GL_NO_ERROR;
  {$ENDIF}
end;

// Check and report to log OpenGL error
function ReportGLError(const ErrorLabel: string): Cardinal; {$I inline.inc}
begin
  {$IFDEF OGLERRORCHECK}
  Result := glGetError();
  if Result <> GL_NO_ERROR then Log(ErrorLabel + ' Error #: ' + IntToStr(Result) + '(' + gluErrorString(Result) + ')', lkError);
  {$ENDIF}
end;

// Check and report to log OpenGL error
procedure ReportGLShaderError(ShaderId: Integer; const ErrorLabel, ResourceName: string); {$I inline.inc}
const MaxInfoLength = 200;
var
  ErrorStr: PAnsiChar;
  ActualLength: Integer;
begin
  GetMem(ErrorStr, MaxInfoLength);
  glGetInfoLogARB(ShaderId, MaxInfoLength, ActualLength, ErrorStr);
  if ActualLength <> 0 then Log(ErrorLabel + ' Error assembling shader from resource "' + ResourceName + '": ' + ErrorStr, lkError);
end;

{ TOGLBuffers }

function TOGLBuffers.CreateVertexBuffer(Size: Integer; Static: Boolean): Integer;
begin
  {$IFDEF DEBUGMODE}
  Log('TOGLBuffers.CreateVertexBuffer: Creating a vertex buffer', lkDebug);
  {$ENDIF}

  SetLength(VertexBuffers, Length(VertexBuffers)+1);
  Result := High(VertexBuffers);
  VertexBuffers[Result].BufferSize := Size;
  VertexBuffers[Result].BufferID   := Result;
  VertexBuffers[Result].Static     := Static;
  GetMem(VertexBuffers[Result].Data, Size);
end;

function TOGLBuffers.CreateIndexBuffer(Size: Integer; Static: Boolean): Integer;
begin
  {$IFDEF DEBUGMODE}
  Log('TOGLBuffers.CreateIndexBuffer: Creating an index buffer', lkDebug);
  {$ENDIF}

  SetLength(IndexBuffers, Length(IndexBuffers)+1);
  Result := High(IndexBuffers);
  IndexBuffers[Result].BufferSize := Size;
  IndexBuffers[Result].BufferID   := Result;
  IndexBuffers[Result].Static     := Static;
  GetMem(IndexBuffers[Result].Data, Size);
end;

function TOGLBuffers.ResizeVertexBuffer(Index, NewSize: Integer): Boolean;
begin
  Assert((Index >= 0) and (Index <= High(VertexBuffers)), 'TOGLBuffers.ResizeVertexBuffer: Invalid bufer index');
  VertexBuffers[Index].BufferSize := NewSize;
  {$Message warn 'change to freemem/getmem'}
  ReallocMem(VertexBuffers[Index].Data, NewSize);

  Result := True;
end;

function TOGLBuffers.ResizeIndexBuffer(Index, NewSize: Integer): Boolean;
begin
  Assert((Index >= 0) and (Index <= High(IndexBuffers)), 'TOGLBuffers.ResizeIndexBuffer: Invalid bufer index');
  IndexBuffers[Index].BufferSize := NewSize;
  {$Message warn 'change to freemem/getmem'}
  ReallocMem(IndexBuffers[Index].Data, NewSize);

  Result := True;
end;

function TOGLBuffers.LockVertexBuffer(Index, Offset, Size: Integer; DiscardExisting: Boolean): Pointer;
begin
  Assert((Index >= 0) and (Index <= High(VertexBuffers)), 'TOGLBuffers.LockVertexBuffer: Invalid bufer index');
  Result := PtrOffs(VertexBuffers[Index].Data, Offset);
end;

function TOGLBuffers.LockIndexBuffer(Index, Offset, Size: Integer; DiscardExisting: Boolean): Pointer;
begin
  Assert((Index >= 0) and (Index <= High(IndexBuffers)), 'TOGLBuffers.LockIndexBuffer: Invalid bufer index');
  Result := PtrOffs(IndexBuffers[Index].Data, Offset);
end;

procedure TOGLBuffers.UnlockVertexBuffer(Index: Integer);
begin
end;

procedure TOGLBuffers.UnlockIndexBuffer(Index: Integer);
begin
end;

function TOGLBuffers.AttachVertexBuffer(Index, StreamIndex, VertexSize: Integer): Boolean;
begin
  Result := True;
end;

function TOGLBuffers.AttachIndexBuffer(Index, StartingVertex: Integer): Boolean;
begin
  Result := True;
end;

procedure TOGLBuffers.Clear;
var i: Integer;
begin
  for i := 0 to High(VertexBuffers) do FreeMem(VertexBuffers[i].Data);
  for i := 0 to High(IndexBuffers)  do FreeMem(IndexBuffers[i].Data);
  VertexBuffers := nil;
  IndexBuffers  := nil;
end;

{ TOGLTextures }

function TOGLTextures.GetTexture(const Index: Integer): TTexture;
begin
  Result := FTextures[Index];
end;

function TOGLTextures.APICreateTexture(Index: Integer): Boolean;
var
  TexID: glUint;
begin
  Result := False;
  if not Renderer.IsReady then Exit;

//  ReportGLError('test');

  glGenTextures(1, @TexID);
  ReportGLError(ClassName + '.APICreateTexture > glGenTextures:');
  FTextures[Index].Texture := Pointer(TexID);

  Result := True;
end;

procedure TOGLTextures.APIDeleteTexture(Index: Integer);
begin
  glDeleteTextures(1, @FTextures[Index].Texture);
  FTextures[Index].Texture := nil;
end;
                                           
procedure TOGLTextures.UnLoad(Index: Integer);
begin
//  inherited;
end;

function TOGLTextures.Update(Index: Integer; Src: Pointer; Rect: BaseTypes.PRect3D): Boolean;
var
  w, h, k, DataSize, DataOfs: Integer;
begin
  Result := False;
  if (Index > High(FTextures)) or IsEmpty(FTextures[Index]) then begin
    Log(ClassName + '.Update: Invalid texture index', lkError);
    Exit;
  end;
  if (Src = nil) then Exit;
  if (FTextures[Index].Texture = nil) then if not APICreateTexture(Index) then Exit;

  glBindTexture(GL_TEXTURE_2D, Cardinal(FTextures[Index].Texture));

  ReportGLError(ClassName + '.Update > glBindTexture:');

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, FTextures[Index].Levels);
  ReportGLError(ClassName + '.Update > glTexParameteri(MaxLevel):');

  w := FTextures[Index].Width;
  h := FTextures[Index].Height;
  DataOfs := 0;

  for k := 0 to FTextures[Index].Levels-1 do begin
    if (Rect <> nil) then begin
      Assert(False); //===***
    end else begin
      DataSize := w * h * GetBytesPerPixel(FTextures[Index].Format);

      glTexImage2D(GL_TEXTURE_2D, k, PFormats[FTextures[Index].Format], w, h, 0, DFFormats[FTextures[Index].Format], DTFormats[FTextures[Index].Format], PtrOffs(Src, DataOfs));
      ReportGLError(ClassName + '.Update > glTexImage2D:');
      Inc(DataOfs, DataSize);
    end;

    w := w shr 1; if w = 0 then w := 1;
    h := h shr 1; if h = 0 then h := 1;
  end;

  Result := True;
end;

function TOGLTextures.Read(Index: Integer; Dest: Pointer; Rect: BaseTypes.PRect3D): Boolean;
begin
  Result := False;
end;

procedure TOGLTextures.Apply(Stage, Index: Integer);
begin
  glActiveTexture(GLTextureI[Stage]);
  ReportGLError(ClassName + '.Apply > glActiveTexture:');
  if Assigned(FTextures[Index].Texture) or Load(Index) then begin
    glBindTexture(GL_TEXTURE_2D, Cardinal(FTextures[Index].Texture));
    ReportGLError(ClassName + '.Apply > glBindTexture:');

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LOD, FTextures[Index].Levels);
    ReportGLError(ClassName + '.Apply > glTexParameteri(Max LOD):');
  end;
end;

function TOGLTextures.Lock(AIndex, AMipLevel: Integer; const ARect: BaseTypes.PRect; out LockRectData: TLockedRectData; LockFlags: TLockFlags): Boolean;
begin
  Result := False;
  LockRectData.Data  := nil;
  Log('Error locking texture level # ' + IntToStr(AIndex) + '. Not implemented for OpenGL renderer yet', lkError);
end;

procedure TOGLTextures.UnLock(AIndex, AMipLevel: Integer);
begin
  if (AIndex > High(FTextures)) or IsEmpty(FTextures[AIndex]) then begin
    Log(ClassName + '.Lock: Invalid texture index (' + IntToStr(AIndex) + ')', lkError);
    Exit;
  end;
end;

{ TOGLStateWrapper }

function TOGLStateWrapper.APICreateRenderTarget(Index, Width, Height: Integer; AColorFormat, ADepthFormat: Cardinal): Boolean;
begin
  Result := False;
  // Free texture and its surface
(*  if Assigned(FRenderTargets[Index].ColorBuffer)  then IDirect3DSurface8(FRenderTargets[Index].ColorBuffer)  := nil;
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
  Result := True; *)
end;

procedure TOGLStateWrapper.DestroyRenderTarget(Index: Integer);
begin
(*  if Assigned(FRenderTargets[Index].ColorBuffer)  then IDirect3DSurface8(FRenderTargets[Index].ColorBuffer)._Release;
  if Assigned(FRenderTargets[Index].DepthBuffer)  then IDirect3DSurface8(FRenderTargets[Index].DepthBuffer)._Release;
  if Assigned(FRenderTargets[Index].ColorTexture) then IDirect3DTexture8(FRenderTargets[Index].ColorTexture)._Release;
  if Assigned(FRenderTargets[Index].DepthTexture) then IDirect3DTexture8(FRenderTargets[Index].DepthTexture)._Release;
  FRenderTargets[Index].ColorBuffer  := nil;
  FRenderTargets[Index].DepthBuffer  := nil;
  FRenderTargets[Index].ColorTexture := nil;
  FRenderTargets[Index].DepthTexture := nil;
  FRenderTargets[Index].LastUpdateFrame := -1;
  FRenderTargets[Index].IsDepthTexture:= False;*)
end;

function TOGLStateWrapper.SetRenderTarget(const Camera: TCamera; TextureTarget: Boolean): Boolean;
begin
  Result := False;
(*  if TextureTarget then begin                                         // Render to texture
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
  Result := True;  *)
end;

function TOGLStateWrapper.CreateVertexShader(Item: TShaderResource; Declaration: TVertexDeclaration): Integer;
var
  shid: Integer;
  SourceLen: Integer;
  SourcePtr: Pointer;
begin
  Result := inherited CreateVertexShader(Item, Declaration);

  if (Item.Source <> '') then begin
    shid := glCreateShaderObjectARB(GL_VERTEX_SHADER_ARB);
    SourcePtr := @Item.Source[1];
    SourceLen := Length(Item.Source);
    glShaderSourceARB(shid, 1, @SourcePtr, @SourceLen);
    glCompileShader(shid);

    if ReportGLError(ClassName + '.CreateVertexShader:') = GL_NO_ERROR then begin
      FVertexShaders[Result].Shader := shid;
    end else begin
      ReportGLShaderError(shid, ClassName + 'CreateVertexShader: ', Item.Name);
      Result := -1;
      LastError := reVertexShaderAssembleFail;
    end;
  end;
end;

function TOGLStateWrapper.CreatePixelShader(Item: TShaderResource): Integer;
var
  shid: Integer;
  SourceLen: Integer;
  SourcePtr: Pointer;
begin
  Result := inherited CreatePixelShader(Item);

  if (Item.Source <> '') then begin
    shid := glCreateShaderObjectARB(GL_FRAGMENT_SHADER_ARB);
    SourcePtr := @Item.Source[1];
    SourceLen := Length(Item.Source);
    glShaderSourceARB(shid, 1, @SourcePtr, @SourceLen);
    glCompileShader(shid);

    if ReportGLError(ClassName + '.CreatePixelShader:') = GL_NO_ERROR then begin
      FPixelShaders[Result].Shader := shid;
    end else begin
      ReportGLShaderError(shid, ClassName + 'CreatePixelShader: ', Item.Name);
      Result := -1;
      LastError := rePixelShaderAssembleFail;
    end;
  end;
end;

procedure TOGLStateWrapper.APIDestroyVertexShader(Index: Integer);
begin
  if FVertexShaders[Index].Shader > 0 then glDeleteObjectARB(FVertexShaders[Index].Shader);
end;

procedure TOGLStateWrapper.APIDestroyPixelShader(Index: Integer);
begin
  if FPixelShaders[Index].Shader > 0 then glDeleteObjectARB(FPixelShaders[Index].Shader);
end;

procedure TOGLStateWrapper.SetFog(Kind: Cardinal; Color: BaseTypes.TColor; AFogStart, AFogEnd, ADensity: Single);
const glFogModes: array[fkDEFAULT..fkTABLEEXP2] of Longword = (GL_LINEAR, GL_LINEAR, GL_LINEAR, GL_LINEAR, GL_LINEAR, GL_EXP, GL_EXP2);
//  fkDEFAULT = 0; fkNONE = 1; fkVERTEX = 2; fkVERTEXRANGED = 3; fkTABLELINEAR = 4; fkTABLEEXP = 5; fkTABLEEXP2 = 6;
var FColor: TColor4s;
begin
  if Kind <> fkNone then begin
    if Kind = fkVertex then
      glHint(GL_FOG_HINT, GL_FASTEST)
    else
      glHint(GL_FOG_HINT, GL_NICEST);
    glFogi(GL_FOG_MODE, glFogModes[Kind]);
    glFogf(GL_FOG_START, AFogStart);
    glFogf(GL_FOG_END, AFogEnd);
    glFogf(GL_FOG_DENSITY, ADensity);
    FColor := ColorTo4S(Color);
    glFogfv(GL_FOG_COLOR, @FColor);
    glEnable(GL_FOG);
  end else glDisable(GL_FOG);
  ReportGLError(ClassName + '.SetFog:');
end;

procedure TOGLStateWrapper.SetBlending(Enabled: Boolean; SrcBlend, DestBlend, AlphaRef, ATestFunc, Operation: Integer);
begin
  if Enabled then begin
    glEnable(GL_BLEND);
    glBlendFunc(BlendModes[SrcBlend], BlendModes[DestBlend]);
    glBlendEquation(BlendOps[Operation]);
  end else glDisable(GL_BLEND);
  if ATestFunc = tfAlways then glDisable(GL_ALPHA_TEST) else glEnable(GL_ALPHA_TEST);
  glAlphaFunc(TestFuncs[ATestFunc], AlphaRef * OneOver255);
  ReportGLError(ClassName + '.SetBlending:');
end;

procedure TOGLStateWrapper.SetZBuffer(ZTestFunc, ZBias: Integer; ZWrite: Boolean);
begin
  glDepthMask(ZWrite);
  if ZTestFunc = tfAlways then glDisable(GL_DEPTH_TEST) else begin
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(TestFuncs[ZTestFunc]);
  end;
  if ZBias = 0 then
    glDisable(GL_POLYGON_OFFSET_FILL)
  else begin
    glEnable(GL_POLYGON_OFFSET_FILL);
    glPolygonOffset(ZBias, ZBias);
  end;
  ReportGLError(ClassName + '.SetZBuffer:');
end;

procedure TOGLStateWrapper.SetCullAndFillMode(FillMode, ShadeMode, CullMode: Integer; ColorMask: Cardinal);
begin
  if FillMode <> fmDEFAULT then
    glPolygonMode(GL_FRONT_AND_BACK, FillModes[FillMode])
  else if Camera <> nil then
    glPolygonMode(GL_FRONT_AND_BACK, FillModes[Camera.DefaultFillMode]);

  glShadeModel(ShadeModes[ShadeMode]);

  case CullMode of
    cmCAMERADEFAULT: if Camera <> nil then CullMode := Camera.DefaultCullMode;
    cmCAMERAINVERSE: if Camera <> nil then begin
      if Camera.DefaultCullMode = cmCCW then
        CullMode := cmCW
      else if Camera.DefaultCullMode = cmCW then
        CullMode := cmCCW
      else
        CullMode := cmNONE
    end;
  end;

  if CullMode <> cmNone then begin
    glEnable(GL_CULL_FACE);
    glCullFace(CullModes[CullMode]);
  end else
    glDisable(GL_CULL_FACE);

  glColorMask(ColorMask and $FF > 0, ColorMask and $FF00 > 0, ColorMask and $FF0000 > 0, ColorMask and $FF000000 > 0);
  ReportGLError(ClassName + '.SetCullAndFillMode:');
end;

procedure TOGLStateWrapper.SetStencilState(SFailOp, ZFailOp, PassOp, STestFunc: Integer);
begin
// Disable stencil if Func = Always and ZFail = PassOP = Keep
(***  if (ZFailOp = soKeep) and (PassOp = soKeep) and (STestFunc <> tfAlways) then
   Direct3DDevice.SetRenderState(D3DRS_STENCILENABLE, 0) else begin
     Direct3DDevice.SetRenderState(D3DRS_STENCILENABLE, 1);
     Direct3DDevice.SetRenderState(D3DRS_STENCILFUNC,   TestFuncs[STestFunc]);
     Direct3DDevice.SetRenderState(D3DRS_STENCILFAIL,   StencilOps[SFailOp]);
     Direct3DDevice.SetRenderState(D3DRS_STENCILZFAIL,  StencilOps[ZFailOp]);
     Direct3DDevice.SetRenderState(D3DRS_STENCILPASS,   StencilOps[PassOp]);
   end;*)
end;

procedure TOGLStateWrapper.SetStencilValues(SRef, SMask, SWriteMask: Integer);
begin
{***  Direct3DDevice.SetRenderState(D3DRS_STENCILREF,       Cardinal(SRef));
  Direct3DDevice.SetRenderState(D3DRS_STENCILMASK,      Cardinal(SMask));
  Direct3DDevice.SetRenderState(D3DRS_STENCILWRITEMASK, Cardinal(SWriteMask));}
end;

procedure TOGLStateWrapper.SetTextureWrap(const CoordSet: TTWrapCoordSet);
//const D3DRS_WRAP: array[0..7] of TD3DRenderStateType = (D3DRS_WRAP0, D3DRS_WRAP1, D3DRS_WRAP2, D3DRS_WRAP3, D3DRS_WRAP4, D3DRS_WRAP5, D3DRS_WRAP6, D3DRS_WRAP7);
//var i: Integer;
begin
{***  for i := 0 to 7 do
    Direct3DDevice.SetRenderState(D3DRS_WRAP[i], D3DWRAPCOORD_0 * Ord(CoordSet[i] and twUCoord  > 0) or
                                                 D3DWRAPCOORD_1 * Ord(CoordSet[i] and twVCoord  > 0) or
                                                 D3DWRAPCOORD_2 * Ord(CoordSet[i] and twWCoord  > 0) or
                                                 D3DWRAPCOORD_3 * Ord(CoordSet[i] and twW2Coord > 0));}
end;

procedure TOGLStateWrapper.SetLighting(Enable: Boolean; AAmbient: BaseTypes.TColor; SpecularMode: Integer; NormalizeNormals: Boolean);
var AmbientColor: TColor4s;
begin
  if Enable then
    glEnable(GL_LIGHTING)
  else
    glDisable(GL_LIGHTING);
  glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, 0);
  glLightModeli(GL_LIGHT_MODEL_LOCAL_VIEWER, Ord(SpecularMode = slAccurate));

  ColorTo4S(AmbientColor, AAmbient);
  glLightModelfv(GL_LIGHT_MODEL_AMBIENT, @AmbientColor);
  ReportGLError(ClassName + '.SetLighting:');
end;

procedure TOGLStateWrapper.SetEdgePoint(PointSprite, PointScale, EdgeAntialias: Boolean);
begin
{***  Direct3dDevice.SetRenderState(D3DRS_POINTSPRITEENABLE, Ord(PointSprite));
  Direct3DDevice.SetRenderState(D3DRS_POINTSCALEENABLE,  Ord(PointScale));
  Direct3DDevice.SetRenderState(D3DRS_EDGEANTIALIAS,     Ord(EdgeAntialias));}
end;

procedure TOGLStateWrapper.SetTextureFactor(ATextureFactor: BaseTypes.TColor);
begin
  //Direct3DDevice.SetRenderState(D3DRS_TEXTUREFACTOR, ATextureFactor.C);
end;

procedure TOGLStateWrapper.SetMaterial(const AAmbient, ADiffuse, ASpecular, AEmissive: BaseTypes.TColor4S; APower: Single);
begin
  glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, @AAmbient);
  glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, @ADiffuse);
  glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, @ASpecular);
  glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, APower);
  ReportGLError(ClassName + '.SetMaterial:');
end;

procedure TOGLStateWrapper.SetPointValues(APointSize, AMinPointSize, AMaxPointSize, APointScaleA, APointScaleB, APointScaleC: Single);
var Arr: array[0..2] of GLfloat;
begin
  AMinPointSize := MinS(AMinPointSize, AMaxPointSize);
  APointSize := MinS(MaxS(APointSIze, AMinPointSize), AMaxPointSize);
  glPointSize(APointSize);
  glPointParameterf(GL_POINT_SIZE_MIN, AMinPointSize);
  glPointParameterf(GL_POINT_SIZE_MAX, AMaxPointSize);
  Arr[0] := APointScaleA;
  Arr[1] := APointScaleB;
  Arr[2] := APointScaleC;
  glPointParameterfv(GL_POINT_DISTANCE_ATTENUATION, @Arr);
  ReportGLError(ClassName + '.SetPointValues:');
end;

procedure TOGLStateWrapper.SetLinePattern(ALinePattern: Longword);
begin
  if ALinePattern = 0 then
    glDisable(GL_LINE_STIPPLE)
  else begin
    glEnable(GL_LINE_STIPPLE);
    glLineStipple(ALinePattern shr 24, ALinePattern and $FF);
  end;
  ReportGLError(ClassName + '.SetLinePattern:');
end;

procedure TOGLStateWrapper.SetClipPlane(Index: Cardinal; Plane: PPlane);
begin
(*  ClipPlanesState := ClipPlanesState and not (1 shl Index) or Cardinal(Ord(Assigned(Plane)) shl Index);
  Direct3DDevice.SetRenderState(D3DRS_CLIPPLANEENABLE, ClipPlanesState);
  if Assigned(Plane) then begin
    Res := Direct3DDevice.SetClipPlane(Index, PSingle(Plane));
    {$IFDEF DEBUGMODE}
    if Failed(Res) then
      Log('Error setting clip plane. Error code: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkError);
    {$ENDIF}
  end;*)
end;

procedure TOGLStateWrapper.ApplyPass(const Pass: TRenderPass);

  procedure UseCombineExt(const Stage: TStage);
  { toDISABLE = 0; toARG1 = 1; toARG2 = 2;
    toMODULATE = 3; toMODULATE2X = 4; toMODULATE4X = 5;
    toADD = 6; toSIGNEDADD = 7; toSIGNEDADD2X = 8;
    toSUB = 9; toSMOOTHADD = 10;
    toBLENDDIFFUSEALPHA = 11; toBLENDTEXTUREALPHA = 12; toBLENDFACTORALPHA = 13;
    toBLENDTEXTUREALPHAPM = 14; toBLENDCURRENTALPHA = 15;
    toPREMODULATE = 16;

    toDOTPRODUCT3 = 17;
    toMULTIPLYADD = 18; toLERP = 19;
    toMODULATEALPHA_ADDCOLOR = 20; toMODULATECOLOR_ADDALPHA = 21;
    toMODULATEINVALPHA_ADDCOLOR = 22; toMODULATEINVCOLOR_ADDALPHA = 23;
    toBUMPENV = 24; toBUMPENVLUM = 25;
    }
  const GLOp: array[toDISABLE..toBUMPENVLUM] of Cardinal = (GL_REPLACE, GL_REPLACE, GL_REPLACE,
                                                            GL_MODULATE, GL_MODULATE, GL_MODULATE,
                                                            GL_ADD, GL_ADD_SIGNED, GL_ADD_SIGNED,
                                                            GL_ADD, GL_ADD,
                                                            GL_INTERPOLATE, GL_INTERPOLATE, GL_INTERPOLATE,
                                                            GL_INTERPOLATE, GL_INTERPOLATE,
                                                            GL_MODULATE,

                                                            GL_DOT3_RGB,
                                                            GL_MODULATE,
                                                            GL_INTERPOLATE,

                                                            GL_INTERPOLATE, GL_INTERPOLATE,
                                                            GL_INTERPOLATE, GL_INTERPOLATE,
                                                            GL_MODULATE, GL_MODULATE);
  // taDiffuse = 0; taCurrent = 1; taTexture = 2; taSpecular = 3;

  procedure StageToCombinerExt(Alpha: Boolean; StageOp, StageArg1, StageArg2: Longword; var Op, Arg0, Arg1, Arg2, Op0, Op1, Op2, Scale: Longword);
//  taDIFFUSE  = 0; taCURRENT  = 1; taTEXTURE  = 2; taSPECULAR = 3; taTEMP     = 4; taTFactor  = 5; taALPHAREPLICATE = 6;

  const GLArg: array[taDiffuse..taTexture] of Longword = (GL_PRIMARY_COLOR, GL_PREVIOUS, GL_TEXTURE);
  begin
    if Alpha then begin
      Op0 := GL_SRC_ALPHA; Op1 := GL_SRC_ALPHA; Op2 := GL_SRC_ALPHA;
    end else begin
      Op0 := GL_SRC_COLOR; Op1 := GL_SRC_COLOR; Op2 := GL_SRC_COLOR;
    end;

    if StageArg1 = taTemp then StageArg1 := taCurrent;
    if StageArg2 = taTemp then StageArg2 := taCurrent;
    if StageArg1 = taSpecular then StageArg1 := taDiffuse;
    if StageArg2 = taSpecular then StageArg2 := taDiffuse;
    Op := GL_MODULATE; Arg0 := GL_PRIMARY_COLOR; Arg1 := GL_TEXTURE; Arg2 := GL_PRIMARY_COLOR;
    Scale := 1;
    if StageOp = toDisable then
      Op := GL_MODULATE
    else case StageOp*9 + StageArg1*3 + StageArg2 of
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
        Op := GL_ADD_SIGNED; Arg0 := GLArg[StageArg1]; Arg1 := GLArg[StageArg2];
      end;
      toSignedAdd2X*9 + taDiffuse*3 + taDiffuse..toSignedAdd2X*9 + taTexture*3 + taTexture: begin
        Op := GL_ADD_SIGNED; Arg0 := GLArg[StageArg1]; Arg1 := GLArg[StageArg2]; Scale := 2;
      end;
    end;
  end;

  var Op, Arg0, Arg1, Arg2, Op0, Op1, Op2, Scale: Longword;

  begin
  //  glActiveTextureARB(GL_TEXTURE0_ARB);

    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);

    StageToCombinerExt(False, Stage.ColorOp, Stage.ColorArg1, Stage.ColorArg2, Op, Arg0, Arg1, Arg2, Op0, Op1, Op2, Scale);

    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, Op);
    glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, Arg0);
    glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, Arg1);
    glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB, Arg2);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, Op0);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, Op1);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_RGB, Op2);
    glTexEnvi(GL_TEXTURE_ENV, GL_RGB_SCALE, Scale);

    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, color:');

    StageToCombinerExt(True, Stage.AlphaOp, Stage.AlphaArg1, Stage.AlphaArg2, Op, Arg0, Arg1, Arg2, Op0, Op1, Op2, Scale);

    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA, Op);
    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, alpha1:');
    glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_ALPHA, Arg0);
    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, alpha2:');
    glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_ALPHA, Arg1);
    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, alpha3:');
    glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA, Arg2);
    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, alpha4:');
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, Op0);
    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, alpha5:');
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA, Op1);
    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, alpha6:');
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_ALPHA, Op2);
    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, alpha7:');
    glTexEnvi(GL_TEXTURE_ENV, GL_ALPHA_SCALE, Scale);

    ReportGLError(ClassName + '.ApplyPass > glTexEnvi, alpha:');
  end;

var
  i, TexCount, prid: Integer;
  Stage: ^TStage;
  MipFilter: Cardinal;
begin
  Assert(Assigned(Pass), ClassName + '.ApplyPass: Invalid pass');

  if (Pass.VertexShaderIndex <> sivNull) then begin                                // Try to resolve vertex shader
    if Pass.VertexShaderIndex = sivUnresolved then ResolveVertexShader(Pass);
    VertexShaderFlag := Pass.VertexShaderIndex <> sivUnresolved;
  end else VertexShaderFlag := False;

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

(*  if VertexShaderFlag then begin
    Res := Direct3DDevice.SetVertexShader(Cardinal(FVertexShaders[Pass.VertexShaderIndex].Shader));
    {$IFDEF DEBUGMODE} if Res <> D3D_OK then begin Log('TOGLStateWrapper.ApplyPass: Error setting vertex shader: ' +  HResultToStr(Res), lkError); end; {$ENDIF}
  end;*)  

  if (Pass.PixelShaderIndex <> sivNull) then begin                                 // Try to resolve pixel shader
    if Pass.PixelShaderIndex = sivUnresolved then ResolvePixelShader(Pass);
    PixelShaderFlag := Pass.PixelShaderIndex <> sivUnresolved;
  end else PixelShaderFlag := False;

  // If shaders used create and link a program object
  if (Pass.VertexShaderIndex <> sivNull) or (Pass.PixelShaderIndex <> sivNull) then begin
    prid := glCreateProgramObjectARB();

    if Pass.VertexShaderIndex <> sivNull then glAttachObjectARB(prid, FVertexShaders[Pass.VertexShaderIndex].Shader);
    if Pass.PixelShaderIndex  <> sivNull then glAttachObjectARB(prid, FPixelShaders[Pass.PixelShaderIndex].Shader);

    glLinkProgramARB(prid);

    glUseProgramObjectARB(prid);
  end;



(*  if PixelShaderFlag then
    Res := Direct3DDevice.SetPixelShader(Cardinal(FPixelShaders[Pass.PixelShaderIndex].Shader)) else
      Res := Direct3DDevice.SetPixelShader(0);

  {$IFDEF DEBUGMODE} if Res <> D3D_OK then begin Log('TOGLStateWrapper.ApplyPass: Error setting pixel shader: ' +  HResultToStr(Res), lkError); end; {$ENDIF}*)

  if (LastError = reNone) and (Pass.TotalStages > Renderer.MaxTextureStages) then LastError := reTooManyStages;

  TexCount := 0;

  for i := 0 to MinI(Pass.TotalStages-1, Renderer.MaxTextureStages-1) do begin
    Stage := @Pass.Stages[i];
//    Assert(Stage.TextureIndex <> -1, ClassName + '.ApplyPass: ');

    if (Stage.TextureIndex <> tivNull) and
//      ((Stage.TextureIndex <> tivRenderTarget) or (Stage.Camera.RenderTargetIndex <> -1)) and
      ((Stage.TextureIndex <> tivUnresolved) or Renderer.Textures.Resolve(Pass, i)) then begin
      if (Stage.TextureIndex <> tivRenderTarget) then begin
        Renderer.Textures.Apply(i, Stage.TextureIndex);
        Inc(TexCount);
      end else begin
        if Stage.Camera.IsDepthTexture and not Renderer.DepthTextures then begin
          LastError := reNoDepthTextures;
        end else if Stage.Camera.RenderTargetIndex <> -1 then begin
{***          if Stage.Camera.IsDepthTexture then
            Res := Direct3DDevice.SetTexture(i, IDirect3DTexture8(FRenderTargets[Stage.Camera.RenderTargetIndex].DepthTexture))
          else
            Res := Direct3DDevice.SetTexture(i, IDirect3DTexture8(FRenderTargets[Stage.Camera.RenderTargetIndex].ColorTexture));**}
        end else
          glBindTexture(GL_TEXTURE_2D, 0);
      end;

      ReportGLError('TOGLStateWrapper.ApplyPass: Error setting texture.');

      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, TexAddressing[Stage.TAddressing and $00F]);
      ReportGLError(ClassName + '.ApplyPass > glTexParameteri1:');
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, TexAddressing[(Stage.TAddressing shr 4) and $00F]);
      ReportGLError(ClassName + '.ApplyPass > glTexParameteri2:');
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, TexAddressing[(Stage.TAddressing shr 8) and $00F]);
      ReportGLError(ClassName + '.ApplyPass > glTexParameteri3:');

      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, Integer(Stage.TextureBorder.C));
      ReportGLError(ClassName + '.ApplyPass > glTexParameteri4:');

      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, TexFilters[(Stage.Filtering shr 4) and $00F]); // only first three values of TexFilters are allowed

      ReportGLError(ClassName + '.ApplyPass > glTexParameteri5:');

      MipFilter := MinI(tfLINEAR, (Stage.Filtering shr 8) and $00F);     // Range: [0..1]
      if (MipFilter = tfNone) or (Stage.TextureIndex = tivRenderTarget) or (TOGLTextures(Renderer.Textures).Texture[Stage.TextureIndex].Levels = 1) then
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, TexFilters[MinI(tfLinear, Stage.Filtering and $00F)])
      else
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, TexFilters[tfLASTINDEX + ClampI(Stage.Filtering and $00F, tfPOINT, tfLINEAR) + Ord(MipFilter <> tfPOINT)*2]);

      ReportGLError(ClassName + '.ApplyPass > glTexParameteri:');

      if not VertexShaderFlag then begin
        if Stage.UVSource shr 4 = tcgNone then begin
          glDisable(GL_TEXTURE_GEN_S);
          glDisable(GL_TEXTURE_GEN_T);
          glDisable(GL_TEXTURE_GEN_R);
          //glDisable(GL_TEXTURE_GEN_Q);
        end else begin
          glEnable(GL_TEXTURE_GEN_S);
          glEnable(GL_TEXTURE_GEN_T);
          glEnable(GL_TEXTURE_GEN_R);
          //glEnable(GL_TEXTURE_GEN_Q);
          glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, TexCoordSources[Stage.UVSource shr 4]);
          glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, TexCoordSources[Stage.UVSource shr 4]);
          glTexGeni(GL_R, GL_TEXTURE_GEN_MODE, TexCoordSources[Stage.UVSource shr 4]);
          //glTexGeni(GL_Q, GL_TEXTURE_GEN_MODE, TexCoordSources[Stage.UVSource shr 4]);
        end;
        ReportGLError(ClassName + '.ApplyPass > glTexGeni:');
      end;

      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, Stage.MaxMipLevel); //?
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LOD, Stage.MaxMipLevel); //?

      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, Stage.MaxAnisotropy);

      ReportGLError(ClassName + '.ApplyPass > glTexParameteri2:');
    end else
      glBindTexture(GL_TEXTURE_2D, 0);

    if Pass.PixelShaderIndex < 0 then begin
      UseCombineExt(Stage^);

{      if Stage.StoreToTemp then
        Direct3DDevice.SetTextureStageState(i, D3DTSS_RESULTARG, D3DTA_TEMP)
      else
        Direct3DDevice.SetTextureStageState(i, D3DTSS_RESULTARG, D3DTA_CURRENT);}
    end;
  end;

  if (LastError = reNone) and (TexCount > Renderer.MaxTexturesPerPass) then LastError := reTooManyTextures;

  if (Pass.TotalStages < Integer(Renderer.MaxTextureStages)) then begin
    if (Pass.PixelShaderIndex < 0) then begin
      glActiveTexture(GLTextureI[Pass.TotalStages]);
    end;
  end;
  ApplyClipPlanes;    
end;

procedure TOGLStateWrapper.ApplyTextureMatrices(const Pass: TRenderPass);
var i: Integer; Mat: TMatrix4s;
begin
  for i := 0 to MinI(Pass.TotalStages-1, Renderer.MaxTextureStages-1) do begin
        glActiveTexture(GLTextureI[i]);
        glMatrixMode(GL_TEXTURE);
        case Pass.Stages[i].TextureMatrixType of
          tmNone: if VertexShaderFlag then begin
              if StageMatrixSet[i] then begin
                glLoadMatrixf(@IdentityMatrix4s.m);
                StageMatrixSet[i] := False;
              end;
            end else begin
              if StageMatrixSet[i] then begin
                glLoadMatrixf(@IdentityMatrix4s.m);
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
//      Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXTURETRANSFORMFLAGS, Cardinal(D3DTTFF_PROJECTED * Ord(Pass.Stages[i].TTransform and $80 > 0)));
      TransposeMatrix4s(Mat);     {$MESSAGE 'Remove this stub'}
      APISetShaderConstant(skVertex, 32, Mat.Rows[0]);
      APISetShaderConstant(skVertex, 33, Mat.Rows[1]);
      APISetShaderConstant(skVertex, 34, Mat.Rows[2]);
      APISetShaderConstant(skVertex, 35, Mat.Rows[3]);
    end else begin
//      Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXTURETRANSFORMFLAGS, TexTransformFlags[Pass.Stages[i].TTransform and $0F] or Cardinal(D3DTTFF_PROJECTED * Ord(Pass.Stages[i].TTransform and $80 > 0)));
      glLoadMatrixf(@Mat.m);
    end;
  end;
  ReportGLError(ClassName + '.ApplyPass > ApplyTextureMatrices:');
end;

procedure TOGLStateWrapper.ApplyCustomTextureMatrices(const Pass: TRenderPass; Item: TVisible);
var i: Integer; Mat: TMatrix4s;
begin
  for i := 0 to MinI(Pass.TotalStages-1, Renderer.MaxTextureStages-1) do
    if Pass.Stages[i].TextureMatrixType = tmCustom then begin
      //Direct3DDevice.SetTextureStageState(i, D3DTSS_TEXTURETRANSFORMFLAGS, TexTransformFlags[Pass.Stages[i].TTransform and $0F] or Cardinal(D3DTTFF_PROJECTED * Ord(Pass.Stages[i].TTransform and $80 > 0)));

      if Assigned(Item.RetrieveTextureMatrix) then Item.RetrieveTextureMatrix(i, Mat) else Mat := IdentityMatrix4s;
      glActiveTexture(GLTextureI[i]);
      glMatrixMode(GL_TEXTURE);
      glLoadMatrixf(@Mat.m);

      StageMatrixSet[i] := True;
    end;
  ReportGLError(ClassName + '.ApplyCustomTextureMatrices:');
end;

procedure TOGLStateWrapper.ObtainRenderTargetSurfaces;
begin
{  Direct3DDevice.GetRenderTarget(MainRenderTarget);
  Direct3DDevice.GetDepthStencilSurface(MainDepthStencil);
  CurrentRenderTarget := MainRenderTarget;
  CurrentDepthStencil := MainDepthStencil;}
end;

procedure TOGLStateWrapper.CleanUpNonManaged;
var i: Integer;
begin
  for i := 0 to High(FRenderTargets) do DestroyRenderTarget(i);
end;

procedure TOGLStateWrapper.RestoreNonManaged;
var i: Integer;
begin
  for i := 0 to High(FRenderTargets) do CreateRenderTarget(i, FRenderTargets[i].Width, FRenderTargets[i].Height, FRenderTargets[i].ActualColorFormat, FRenderTargets[i].ActualDepthFormat, FRenderTargets[i].IsDepthTexture);
  ObtainRenderTargetSurfaces;
end;

procedure TOGLStateWrapper.APISetShaderConstant(ShaderKind: TShaderKind; ShaderRegister: Integer; const Vector: TShaderRegisterType);
begin
//  case ShaderKind of
//    skVertex: Direct3DDevice.SetVertexShaderConstant(ShaderRegister, Vector, 1);
//    skPixel:  Direct3DDevice.SetPixelShaderConstant(ShaderRegister, Vector, 1);
//  end;
end;

procedure TOGLStateWrapper.APISetShaderConstant(const Constant: TShaderConstant);
begin
//  with Constant do case ShaderKind of
//    skVertex: Direct3DDevice.SetVertexShaderConstant(ShaderRegister, Value, 1);
//    skPixel:  Direct3DDevice.SetPixelShaderConstant(ShaderRegister, Value, 1);
//  end;
end;

function TOGLStateWrapper.APIValidatePass(const Pass: TRenderPass; out ResultStr: string): Boolean;
begin
  Result := true;//(Pass.VertexShaderIndex = sivNull) and (Pass.PixelShaderIndex = sivNull);
end;

{ TOGLRenderer }

constructor TOGLRenderer.Create(Manager: TItemsManager);
begin
  InitOpenGL();
  {$Include C2OGLInit.inc}
  inherited;
  Log('Starting OGLRenderer...', lkNotice);

  if not InitOpenGL() then begin
    Log('Error initializing OpenGL', lkFatalError);
    Exit;
  end;

  C2Visual.RGBA := True;

  Textures   := TOGLTextures.Create;
  APIState   := TOGLStateWrapper.Create;
  APIBuffers := TOGLBuffers.Create(Self);
  InternalInit;

  Log('OGLRenderer started', lkNotice);
end;

procedure TOGLRenderer.SetModelMatrix(MatPtr: Pointer);
begin
  glMatrixMode(GL_MODELVIEW);
  glLoadMatrixf(@FLastAppliedCameraMatrix.m);
  glMultMatrixf(MatPtr);
end;


function TOGLRenderer.APICheckFormat(const Format, Usage, RTFormat: Cardinal): Boolean;
//  fuTEXTURE = 0; fuRENDERTARGET = 1; fuDEPTHSTENCIL = 2; fuVOLUMETEXTURE = 3; fuCUBETEXTURE = 4; fuDEPTHTEXTURE = 5;
//const glUsages: array[fuTEXTURE..fuDEPTHTEXTURE] of Cardinal = (GL_TEXTURE_2D, )
var ResWidth: Integer;
begin
  Result := False;
  ResWidth := 0;

  Assert((Format < TotalPixelFormats));
  if (Format <= 0) or (Format >= TotalPixelFormats) or
     (PFormats[Format] = Cardinal(GL_NONE)) or (DFFormats[Format] = Cardinal(GL_NONE)) or (DTFormats[Format] = Cardinal(GL_NONE)) then Exit;

  case Usage of

    fuTEXTURE: begin
      glTexImage2D(GL_PROXY_TEXTURE_2D, 0, PFormats[Format], 64, 64, 0, DFFormats[Format], DTFormats[Format], nil);
      glGetTexLevelParameteriv(GL_PROXY_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, @ResWidth);
    end;
    fuRENDERTARGET: begin
      ResWidth := 0;                          {$MESSAGE 'temporary'}
    end;
    fuDEPTHSTENCIL, fuDEPTHTEXTURE: begin
      if IsDepthFormat(Format) then begin
        ResWidth := 64;                        {$MESSAGE 'temporary'}
      end;
    end;
    fuVOLUMETEXTURE: begin
      glTexImage3D(GL_PROXY_TEXTURE_3D, 0, PFormats[Format], 64, 64, 1, 0, DFFormats[Format], DTFormats[Format], nil);
      glGetTexLevelParameteriv(GL_PROXY_TEXTURE_3D, 0, GL_TEXTURE_WIDTH, @ResWidth);
    end;
    fuCUBETEXTURE: begin
      glTexImage2D(GL_PROXY_TEXTURE_CUBE_MAP, 0, PFormats[Format], 64, 64, 0, DFFormats[Format], DTFormats[Format], nil);
      glGetTexLevelParameteriv(GL_PROXY_TEXTURE_CUBE_MAP, 0, GL_TEXTURE_WIDTH, @ResWidth);
    end;
    else Assert(False);
  end;
  Result := (glGetError() = GL_NO_ERROR) and (ResWidth <> 0);
end;

procedure TOGLRenderer.APIPrepareFVFStates(Item: TVisible);
//const D3DTS_AdditionalWorld: array[0..2] of TD3DTransformStateType = (D3DTS_World1, D3DTS_World2, D3DTS_World3);
//var i: Integer;
begin
  //*** Direct3DDevice.SetVertexShader(TOGLBuffers(APIBuffers).GetFVF(Item.CurrentTesselator.VertexFormat));
  // Item matrices setting

  if Item.CurrentTesselator.VertexFormat and vfTRANSFORMED > 0 then begin
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity;
    glTranslatef(0.375, 0.375 - RenderHeight, 0);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, RenderWidth, 0, RenderHeight, -1, 1);
    glScalef(1, -1, 1);
  end else begin
    APIApplyCamera(FLastAppliedCamera);
    SetModelMatrix(Item.TransformPtr);
  end;

//  for i := 0 to Length(Item.BlendMatrices)-1 do
//    Direct3DDevice.SetTransform(D3DTS_WORLDMATRIX(i), TD3DMatrix(Item.BlendMatrices[i]));

  {$MESSAGE 'Move to material settings'}
//  Direct3DDevice.SetRenderState(D3DRS_VERTEXBLEND, (Item.CurrentTesselator.VertexFormat shr 28) and $7);        // Turn on vertex blending if weights present
//  Direct3DDevice.SetRenderState(D3DRS_INDEXEDVERTEXBLENDENABLE, Ord((Item.CurrentTesselator.VertexFormat shr 28) and vwIndexedBlending = vwIndexedBlending));
//  Direct3DDevice.SetRenderState(D3DRS_COLORVERTEX, Ord(Item.CurrentTesselator.VertexFormat and vfDiffuse > 0));   // Turn on vertex coloring if diffuse present

{  if Item.CurrentTesselator.VertexFormat and vfDiffuse > 0 then
    Direct3DDevice.SetRenderState(D3DRS_DIFFUSEMATERIALSOURCE, D3DMCS_COLOR1) else
      Direct3DDevice.SetRenderState(D3DRS_DIFFUSEMATERIALSOURCE, D3DMCS_MATERIAL);

  if Item.CurrentTesselator.VertexFormat and vfSpecular > 0 then
    Direct3DDevice.SetRenderState(D3DRS_SPECULARMATERIALSOURCE, D3DMCS_COLOR2) else
      Direct3DDevice.SetRenderState(D3DRS_SPECULARMATERIALSOURCE, D3DMCS_MATERIAL);}

  ReportGLError(ClassName + '.APIPrepareFVFStates:');
end;

procedure TOGLRenderer.InternalDeInit;
begin
  FreeAndNil(APIBuffers);
  FAdapterNames := nil;
  FVideoModes   := nil;
  inherited;
end;

procedure TOGLRenderer.SetGamma(Gamma, Contrast, Brightness: Single);
begin
  inherited;
  if IsReady then
    ; {$MESSAGE 'TODO: implement'}
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
  Log('Checking OpenGL device information...', lkNotice);
  Log('----------', lkInfo);
  Log('  General information');
  Log('Vendor: ' + glGetString(GL_VENDOR));
  Log('Render device: ' + glGetString(GL_RENDERER));
  Log('OpenGL version: ' + glGetString(GL_VERSION));
  Log('SHading language version: ' + glGetString(GL_SHADING_LANGUAGE_VERSION_ARB));
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
  Log(Format('Max texture dimensions: %Dx%D', [MaxTextureWidth, MaxTextureHeight]));
  glGetIntegerv(GL_MAX_3D_TEXTURE_SIZE, @A);
  Log(Format('Max 3D texture dimensions: %Dx%Dx%D', [A, A, A]));
  glGetIntegerv(GL_MAX_CUBE_MAP_TEXTURE_SIZE, @A);
  Log(Format('Max cube texture dimensions: %Dx%D', [A, A]));
  glGetIntegerv(GL_MAX_VIEWPORT_DIMS, @Vi);
  Log(Format('Max viewport size: %Dx%D', [Vi[0], Vi[1]]));

  glGetIntegerv(GL_MAX_TEXTURE_COORDS_ARB, @A);
  Log(Format('Max texture coords: %D', [A]));

  glGetFloatv(GL_LINE_WIDTH_RANGE, @Vf); glGetFloatv(GL_LINE_WIDTH_GRANULARITY, @f);
  Log(Format('Antialiased lines width range/granularity: %3.3F..%3.3F / %3.3F', [Vf[0], Vf[1], f]));
  glGetFloatv(GL_POINT_SIZE_RANGE, @Vf); glGetFloatv(GL_POINT_SIZE_GRANULARITY, @f);
  MaxPointSize := Vf[1];
  Log(Format('Antialiased points size range/granularity: %3.3F..%3.3F / %3.3F', [Vf[0], Vf[1], f]));

  glGetIntegerv(GL_MAX_TEXTURE_UNITS, @MaxTextureStages);
  Log(Format('Max FFP texture units: %D', [MaxTextureStages]));
  glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS_ARB, @A);
  Log(Format('Max texture units: %D', [A]));
  glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS_ARB, @A);
  Log(Format('Max combined texture units: %D', [A]));

  glGetIntegerv(GL_MAX_DRAW_BUFFERS_ARB, @A);
  Log(Format('Max draw buffers: %D', [A]));

  glGetIntegerv(GL_MAX_VERTEX_UNIFORM_COMPONENTS_ARB, @A);
  Log(Format('Max vertex uniforms: %D', [A]));
  glGetIntegerv(GL_MAX_FRAGMENT_UNIFORM_COMPONENTS_ARB, @A);
  Log(Format('Max fragment uniforms: %D', [A]));
  glGetIntegerv(GL_MAX_VARYING_FLOATS_ARB, @A);
  Log(Format('Max varying interpolators: %D', [A]));

  glGetIntegerv(GL_MAX_VERTEX_ATTRIBS_ARB, @A);
  Log(Format('Max vertex attributes: %D', [A]));

  glGetIntegerv(GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS_ARB, @A);
  Log(Format('Max vertex texture units: %D', [A]));

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
  glGetIntegerv(GL_MAX_CLIP_PLANES, @MaxClipPlanes);
  Log(Format('Max clipping planes: %D', [MaxClipPlanes]));
  glGetIntegerv(GL_MAX_ELEMENTS_VERTICES, @MaxVertexIndex);
  Log(Format('Max number of vertices: %D', [MaxVertexIndex]));
  glGetIntegerv(GL_MAX_ELEMENTS_INDICES, @A);
  Log(Format('Max number of indices: %D', [A]));

  Log('All extensions: [' + glGetString(GL_EXTENSIONS) + ']');
  {$ENDIF}

  Log('----------', lkInfo);

  CheckTextureFormats;

  HardwareClipping   := True;
  WBuffering         := False;
  SquareTextures     := False;
  Power2Textures     := True;
  MaxTexturesPerPass := MaxTextureStages;
  MaxPrimitiveCount  := 65536*256;            // ===***
  MaxAPILights       := 8;

  if GL_ARB_vertex_blend then begin
    GLModelView1     := GL_MODELVIEW1_ARB;
    GLWeightingState := GL_VERTEX_BLEND_ARB;

{    glWeightbvARB := wglGetProcAddress('glWeightbvARB');
    glWeightsvARB := wglGetProcAddress('glWeightsvARB');
    glWeightivARB := wglGetProcAddress('glWeightivARB');}
//    glWeightfvARB := wglGetProcAddress('glWeightfvARB');
{    glWeightdvARB := wglGetProcAddress('glWeightdvARB');
    glWeightubvARB := wglGetProcAddress('glWeightubvARB');
    glWeightusvARB := wglGetProcAddress('glWeightusvARB');
    glWeightuivARB := wglGetProcAddress('glWeightuivARB');}
//    glWeightPointerARB := wglGetProcAddress('glWeightPointerARB');
//    glVertexBlendARB := wglGetProcAddress('glVertexBlendARB');

//    glWeightfvARB := wglGetProcAddress('glWeightfvARB');
//    glWeightPointerARB := wglGetProcAddress('glWeightPointerARB');
  end else begin
    GLModelView1     := GL_MODELVIEW1_EXT;
    GLWeightingState := GL_VERTEX_WEIGHTING_EXT;
  end;

  MixedVPMode := false;
  if MixedVPMode then Log('Hardware transform and lighting with software vertex shader emulation used', lkWarning);
  ReportGLError(ClassName + '.CheckCaps:');
end;

procedure TOGLRenderer.CheckTextureFormats;
var i: Integer;
{$IFDEF EXTLOGGING}
const SupportStr: array[False..True] of string[14] = ('     [ ]      ', '     [X]      ');
{$ENDIF}
begin
  {$IFDEF EXTLOGGING}
  Log(' Texture formats supported', lkInfo);
  Log(' Format     Texture    RenderTarget   DepthStencil   Vol texture   Cube texture  Depth texture');

//  Log('    Video format: '+IntToStr(CPFormats[RenderPars.VideoFormat]));

  for i := 0 to High(PFormats) do if PFormats[i] <> Cardinal(GL_NONE) then begin
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
        not ((PFormats[i] <> Cardinal(GL_NONE)) and APICheckFormat(i, fuDEPTHTEXTURE,  pfUndefined)) do
    Dec(i);
  DepthTextures := (i >= 0);
end;

function TOGLRenderer.APICreateDevice(WindowHandle, AVideoMode: Cardinal; AFullScreen: Boolean): Boolean;
var
   ScreenStat: string[30]; 
  Dummy: LongWord;
begin
  Result := False;
  Dummy  := 0;
   Log('TOGLRenderer.CreateViewport: Creating viewport', lkInfo); 

  FCurrentVideoMode := AVideoMode;
  FFullScreen := AFullScreen;           // Use windowed mode if current video mode is invalid

  RenderWindowHandle := WindowHandle;
  {$IFDEF USEGLUT}
    {$IFDEF FPC}
      RenderWindowHandle := 0;
    {$ENDIF}
  {$ENDIF}

  // If  RenderWindowHandle is 0 assume that an OpenGL context already properly initialized and activated
  if (RenderWindowHandle <> 0) then begin
    {$IFDEF WINDOWS}
      FNormalWindowStyle := GetWindowLong(RenderWindowHandle, GWL_STYLE);
      if FNormalWindowStyle = 0 then
        FNormalWindowStyle := WS_OVERLAPPED or WS_CAPTION or WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX or WS_SIZEBOX or WS_SYSMENU;
    {$ENDIF}

    if not AFullScreen then begin
      if not PrepareWindow then begin
        Log('TOGLRenderer.CreateViewport: Error creating windowed viewport', lkError);
        Exit;
      end;

      ScreenStat := 'Windowed ' + IntToStr(RenderWidth) + 'x' + IntToStr(RenderHeight);
    end;

//    if HasActiveContext then begin
      Log('TOGLRenderer.CreateViewport: Context already activated. Reactivating...', lkWarning);
      CloseViewport;
//    end;

    {$IFDEF WINDOWS}
      OGLDC := GetDC(RenderWindowHandle);
      if (OGLDC = 0) then begin
        Log('TOGLRenderer.CreateViewport: Unable to get a device context', lkFatalError);
        Exit;
      end;

  //  if not HasActiveContext then begin
    //ClearExtensions;

      if OGLContext = 0 then
        Log('Creating viewport: ' + ScreenStat)
      else
        Log('Resetting viewport settings to ' + ScreenStat);

      OGLContext := CreateRenderingContext(OGLDC, [opDoubleBuffered], 24, 16, 0, 0, 0, Dummy);

      if OGLContext = 0 then begin
        Log(ClassName + 'APICreateDevice: Error initializing render device', lkFatalError);
        Exit;
      end;
    {$ENDIF}

    Log('Viewport succesfully created');

    {$IFDEF WINDOWS}
      ActivateRenderingContext(OGLDC, OGLContext);
    {$ENDIF}
    ReportGLError(ClassName + '.APICreateDevice( > ActivateRenderingContext:');
  end else begin
    {$IFDEF WINDOWS}
      OGLContext := wglGetCurrentContext();
      OGLDC := wglGetCurrentDC();
      ActivateRenderingContext(OGLDC, OGLContext);
    {$ENDIF}
    {$IFDEF LINUX}
      OGLContext := glxGetCurrentContext();
      OGLDrawable := glXGetCurrentDrawable();
      ReadExtensions();
      //glXMakeCurrent(OSUtils.GetXDisplay, OGLDrawable, OGLContext);
    {$ENDIF}

    Log('OpenGL renderer initialized without window ID', lkNotice);
  end;

  glEnable(GL_TEXTURE_2D);                 // Enable Texture Mapping

  glDisable(GL_COLOR_MATERIAL);
  glLightModeli(GL_LIGHT_MODEL_COLOR_CONTROL_EXT, GL_SEPARATE_SPECULAR_COLOR_EXT{ {GL_SINGLE_COLOR});  
  ReportGLError(ClassName + '.APICreateDevice( > glLightModeli:');

  TOGLStateWrapper(APIState).ObtainRenderTargetSurfaces;

  FState := rsOK;
  Active := True;
  Result := True;
end;

function TOGLRenderer.RestoreDevice(AVideoMode: Cardinal; AFullScreen: Boolean): Boolean;
var ChangeWindowed: Boolean;
begin
  Log('Restoring viewport', lkNotice);
  FState := rsLost;

  ChangeWindowed := FFullScreen <> AFullScreen;

  if ChangeWindowed and (RenderWindowHandle <> 0) then begin
    if AFullScreen then begin                                           // We're going fullscreen
      RestoreWindow(RenderWindowHandle);
      GetWindowRect(RenderWindowHandle, FWindowedRect);
      {$IFDEF WINDOWS}
        SetWindowLong(RenderWindowHandle, GWL_EXSTYLE, WS_EX_TOPMOST);
      {$ENDIF}
    end else                                                            // We're going windowed
      {$IFDEF WINDOWS}
        if not SetWindowPos(RenderWindowHandle, HWND_NOTOPMOST, WindowedRect.Left, WindowedRect.Top,
                            WindowedRect.Right - WindowedRect.Left, WindowedRect.Bottom - WindowedRect.Top,
                            SWP_DRAWFRAME or SWP_NOCOPYBITS or SWP_SHOWWINDOW) then begin
          Log(ClassName + '.RestoreDevice: Can''t set window position (1)', lkError);
        end;
      {$ENDIF}
  end;

  FCurrentVideoMode := AVideoMode;
  FFullScreen       := AFullScreen;

  // actual restore code
  APICreateDevice(RenderWindowHandle, AVideoMode, AFullScreen);
//  CheckCaps;
//  SetViewPort(ViewPort.X, ViewPort.Y, ViewPort.Width, ViewPort.Height, ViewPort.MinZ, ViewPort.MaxZ);
  SetViewPort(0, 0, RenderWidth, RenderHeight, 0, 1);
  if Assigned(LastAppliedCamera) then APIApplyCamera(LastAppliedCamera);

  APIState.SetFog(fkNONE, GetColor(0), 0, 0, 0);

  if ChangeWindowed and (RenderWindowHandle <> 0) then
    if not AFullScreen then begin                      // We're become windowed
      {$IFDEF WINDOWS}
        if not SetWindowPos(RenderWindowHandle, HWND_NOTOPMOST, WindowedRect.Left, WindowedRect.Top,
                            WindowedRect.Right - WindowedRect.Left, WindowedRect.Bottom - WindowedRect.Top,
                            SWP_DRAWFRAME or SWP_NOCOPYBITS or SWP_SHOWWINDOW or SWP_NOMOVE or SWP_NOSIZE) then begin
          Log(ClassName + '.RestoreDevice: Can''t set window position (2)', lkError);
        end;
      {$ENDIF}
    end else begin
//      ShowWindow(RenderWindowHandle, SW_MAXIMIZE);
      {$IFDEF WINDOWS}
        PostMessage(RenderWindowHandle, WM_SIZE, 0, RenderHeight * 65536 + RenderWidth);    // To notify the application about render window resizing
      {$ENDIF}
    end;

  glEnable(GL_TEXTURE_2D);                 // Enable Texture Mapping
  glDisable(GL_COLOR_MATERIAL);
  glLightModeli(GL_LIGHT_MODEL_COLOR_CONTROL_EXT, GL_SEPARATE_SPECULAR_COLOR_EXT{ {GL_SINGLE_COLOR});

  inherited RestoreDevice(AVideoMode, AFullScreen);

  ReportGLError(ClassName + '.RestoreDevice:');

  FState := rsOK;
  Result := True;
end;

procedure TOGLRenderer.CloseViewport;
begin
  inherited;
  {$IFDEF WINDOWS}
    if OGLContext = 0 then Log('TOGLRenderer.CloseViewport: Viewport was not opened', lkWarning);

    DeactivateRenderingContext();
    DestroyRenderingContext(OGLContext);

    OGLContext := 0;

    // Attemps to release the device context
    ReleaseDC(RenderWindowHandle, OGLDC);
    OGLDC := 0;
  {$ENDIF}  
end;

procedure TOGLRenderer.StartFrame;
begin
  inherited;
  if not IsReady then Exit;

  if Active then begin
    //    glFlush;
    {$IFDEF WINDOWS}
      SwapBuffers(OGLDC);                  // Display the scene
    {$ENDIF}
  end;
end;

procedure TOGLRenderer.FinishFrame;
begin
  if (State = rsLost) then begin
    if not RestoreDevice(FCurrentVideoMode, FFullScreen) then Sleep(0);
    Exit;
  end;

  if not IsReady then begin Sleep(0); Exit; end;

  if not Active then begin FState := rsLost; Sleep(0); Exit; end;

  FState := rsOK;

  Inc(FFramesRendered);
end;

procedure TOGLRenderer.ApplyLight(Index: Integer; const ALight: TLight);
var Pos: TVector4s;
begin
  if not IsReady then Exit;
  inherited;
  if ALight = nil then
    glDisable(GL_LIGHT0+Index)
  else begin
    SetModelMatrix(ALight.TransformPtr);

    Pos := GetVector4s(0, 0, -1, 0);
    glLightfv(GL_LIGHT0+Index, GL_SPOT_DIRECTION, @Pos);

    if ALight.Kind <> ltDirectional then
      Pos := ExpandVector3s(ALight.Position);

    glLightfv(GL_LIGHT0+Index, GL_POSITION, @Pos);

    glLightfv(GL_LIGHT0+Index, GL_AMBIENT,  @ALight.Ambient);
    glLightfv(GL_LIGHT0+Index, GL_DIFFUSE,  @ALight.Diffuse);
    glLightfv(GL_LIGHT0+Index, GL_SPECULAR, @ALight.Specular);

    glLightf(GL_LIGHT0+Index, GL_CONSTANT_ATTENUATION,  ALight.Attenuation0);
    glLightf(GL_LIGHT0+Index, GL_LINEAR_ATTENUATION,    ALight.Attenuation1);
    glLightf(GL_LIGHT0+Index, GL_QUADRATIC_ATTENUATION, ALight.Attenuation2);

    glEnable(GL_LIGHT0+Index);

    ReportGLError(ClassName + '.ApplyLight:');
  end;
end;

procedure TOGLRenderer.APIApplyCamera(Camera: TCamera);
begin
  if not IsReady or (Camera = nil) then Exit;

  //glMatrixMode(GL_MODELVIEW);
  //glLoadMatrixf(PGLfloat(Camera.ViewMatrixPtr));
  glMatrixMode(GL_PROJECTION);        // Change Matrix Mode to Projection
  glLoadMatrixf(PGLFloat(Camera.ProjMatrixPtr));         // Reset View

  ReportGLError(ClassName + '.ApplyCamera:');
end;

procedure TOGLRenderer.SetViewPort(const X, Y, Width, Height: Integer; const MinZ, MaxZ: Single);
begin
  inherited;
  if not IsReady then Exit;
  glViewport(ViewPort.X, ViewPort.Y, ViewPort.Width, ViewPort.Height);    // Set the viewport for the OpenGL window
  glDepthRange(ViewPort.MinZ, ViewPort.MaxZ);

  ReportGLError(ClassName + '.SetViewPort:');
end;

function GetOGLElementCount(PrimitiveType: TPrimitiveType; TotalPrimitives: Integer): Integer; {$I inline.inc}
begin
  case CPTypes[PrimitiveType] of
    GL_POINTS: Result := TotalPrimitives;
    GL_LINES: Result := TotalPrimitives*2;
    GL_LINE_STRIP: Result := TotalPrimitives+1;
    GL_TRIANGLES: Result := TotalPrimitives*3;
    GL_TRIANGLE_STRIP: Result := TotalPrimitives+2;
    GL_TRIANGLE_FAN: Result := TotalPrimitives+2;
    GL_QUADS: Result := TotalPrimitives*4;
    GL_QUAD_STRIP: Result := TotalPrimitives*2+2;
//    GL_POLYGON: Result := TotalVertices;
    else Result := 0;
  end;
end;

procedure TOGLRenderer.APIRenderIndexedStrip(Tesselator: TTesselator; StripIndex: Integer);
var
  GLBuffers: TOGLBuffers;
  IBuf, VBuf: Pointer;
  VCount: Integer;
begin
  GLBuffers := TOGLBuffers(APIBuffers);

  VCount := GetOGLElementCount(Tesselator.PrimitiveType, Tesselator.TotalPrimitives);

  IBuf := GLBuffers.IndexBuffers[InternalGetIndexBufferIndex(Tesselator.TesselationStatus[tbIndex].TesselatorType = ttStatic,
                                                             Tesselator.TesselationStatus[tbIndex].BufferIndex)].Data;
  IBuf := PtrOffs(IBuf, Tesselator.TesselationStatus[tbIndex].Offset * 2);

  VBuf := GLBuffers.VertexBuffers[InternalGetVertexBufferIndex(Tesselator.TesselationStatus[tbVertex].TesselatorType = ttStatic,
                                                               Tesselator.TesselationStatus[tbVertex].BufferIndex)].Data;
  VBuf := PtrOffs(VBuf, (Tesselator.TesselationStatus[tbVertex].Offset + StripIndex * Tesselator.StripOffset) * Tesselator.VertexSize);

  glEnableClientState(GL_VERTEX_ARRAY);

  if GetVertexWeightsCount(Tesselator.VertexFormat) > 0 then begin           // Weights included
    if GL_ARB_vertex_blend then begin
      glEnableClientState(GL_WEIGHT_ARRAY_ARB);
      glWeightPointerARB(1, GL_FLOAT, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiWEIGHT1)));
    end else if GL_EXT_vertex_weighting then begin
      glEnableClientState(GL_VERTEX_WEIGHT_ARRAY_EXT);
      glVertexWeightPointerEXT(1, GL_FLOAT, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiWEIGHT1)))
    end;
  end else begin
    if GL_ARB_vertex_blend then glDisableClientState(GL_WEIGHT_ARRAY_ARB);
    if GL_EXT_vertex_weighting then glDisableClientState(GL_VERTEX_WEIGHT_ARRAY_EXT);
  end;
  ReportGLError('1: ');

  if VertexContains(Tesselator.VertexFormat, vfNORMALS) then begin
    glEnableClientState(GL_NORMAL_ARRAY);
    glNormalPointer(GL_FLOAT, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiNorm)));
  end else
    glDisableClientState(GL_NORMAL_ARRAY);
  ReportGLError('SetOGLClientState: ');

  if VertexContains(Tesselator.VertexFormat, vfDIFFUSE) then begin
    glEnableClientState(GL_COLOR_ARRAY);
    glColorPointer(4, GL_UNSIGNED_BYTE, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiDiff)));
  end else
    glDisableClientState(GL_COLOR_ARRAY);

  if GetVertexTextureSetsCount(Tesselator.VertexFormat) > 0 then begin
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glTexCoordPointer(2, GL_FLOAT, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiTEX0)));
  end else
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);

  ReportGLError('SetOGLClientState: ');

  glVertexPointer(3, GL_FLOAT, Tesselator.VertexSize, VBuf);
  ReportGLError(ClassName + 'APIRenderIndexedStrip: glVertexPointer');

  glLockArraysEXT(0, Tesselator.IndexingVertices);    //===***
  ReportGLError(ClassName + 'APIRenderIndexedStrip: glLockArraysEXT');

  glDrawElements(CPTypes[Tesselator.PrimitiveType], VCount, GL_UNSIGNED_SHORT, IBuf);
  ReportGLError(ClassName + 'APIRenderIndexedStrip: glDrawElements');

  glUnlockArraysEXT();

  Inc(FPerfProfile.DrawCalls);
  Inc(FPerfProfile.PrimitivesRendered, Tesselator.TotalPrimitives);

  ReportGLError(ClassName + '.APIRenderIndexedStrip:');
end;

procedure TOGLRenderer.APIRenderStrip(Tesselator: TTesselator; StripIndex: Integer);
var
  VCount: Integer;
  GLBuffers: TOGLBuffers;
  VBuf: Pointer;
begin
  GLBuffers := TOGLBuffers(APIBuffers);

  VCount := GetOGLElementCount(Tesselator.PrimitiveType, Tesselator.TotalPrimitives);

  VBuf := GLBuffers.VertexBuffers[InternalGetVertexBufferIndex(Tesselator.TesselationStatus[tbVertex].TesselatorType = ttStatic,
                                                               Tesselator.TesselationStatus[tbVertex].BufferIndex)].Data;
  VBuf := PtrOffs(VBuf, (Tesselator.TesselationStatus[tbVertex].Offset + StripIndex * Tesselator.StripOffset) * Tesselator.VertexSize);

  glEnableClientState(GL_VERTEX_ARRAY);

  if VertexContains(Tesselator.VertexFormat, vfiWEIGHT1) then begin           // Weights included
    if GL_ARB_vertex_blend then begin
      glEnableClientState(GL_WEIGHT_ARRAY_ARB);
      glWeightPointerARB(1, GL_FLOAT, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiWEIGHT1)));
    end else if GL_EXT_vertex_weighting then begin
      glEnableClientState(GL_VERTEX_WEIGHT_ARRAY_EXT);
      glVertexWeightPointerEXT(1, GL_FLOAT, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiWEIGHT1)))
    end;
  end;

  if VertexContains(Tesselator.VertexFormat, vfiNORM) then begin
    glEnableClientState(GL_NORMAL_ARRAY);
    glNormalPointer(GL_FLOAT, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiNorm)));
  end else
    glDisableClientState(GL_NORMAL_ARRAY);

  if VertexContains(Tesselator.VertexFormat, vfiDIFF) then begin
    glEnableClientState(GL_COLOR_ARRAY);
    glColorPointer(4, GL_UNSIGNED_BYTE, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiDiff)));
  end else
    glDisableClientState(GL_COLOR_ARRAY);

  if VertexContains(Tesselator.VertexFormat, vfiTEX0) then begin
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glTexCoordPointer(2, GL_FLOAT, Tesselator.VertexSize, PtrOffs(VBuf, GetVertexElementOffset(Tesselator.VertexFormat, vfiTEX0)));
  end else
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);

//  ReportGLError('SetOGLClientState: ');

  glVertexPointer(3, GL_FLOAT, Tesselator.VertexSize, VBuf);
  glLockArraysEXT(0, VCount);

  glDrawArrays(CPTypes[Tesselator.PrimitiveType], 0, VCount);
//  ReportGLError('glDrawArrays: ');

  glUnlockArraysEXT;

  Inc(FPerfProfile.DrawCalls);
  Inc(FPerfProfile.PrimitivesRendered, Tesselator.TotalPrimitives);

//  ReportGLError(ClassName + '.APIRenderStrip:');
end;

procedure TOGLRenderer.RenderItemBox(Item: TProcessing; Color: BaseTypes.TColor);
var Tess: TTesselator; Mat: TMatrix4s; Temp: TVector3s; DPass: TRenderPass;
begin
  if not IsReady then Exit;
//                * Move to material settings *

  glEnable(GL_COLOR_MATERIAL);

  Mat  := Item.Transform;
  Temp := Transform3Vector3s(CutMatrix3s(Mat), AddVector3s(Item.BoundingBox.P2, Item.BoundingBox.P1));
  Mat._41 := Mat._41 + Temp.X*0.5;
  Mat._42 := Mat._42 + Temp.Y*0.5;
  Mat._43 := Mat._43 + Temp.Z*0.5;

  Temp := SubVector3s(Item.BoundingBox.P2, Item.BoundingBox.P1);
  Mat  := MulMatrix4s(ScaleMatrix4s(Temp.X*0.5, Temp.Y*0.5, Temp.Z*0.5), Mat);

  SetModelMatrix(@Mat);

  Tess := DebugTesselators[Ord(bvkOOBB)];
  if not Buffers.Put(Tess) then Exit;

  if Assigned(DebugMaterial) and (DebugMaterial.TotalTechniques > 0) then begin
    DPass := DebugMaterial[0].Passes[0];
    DPass.Ambient  := ColorTo4S(Color);
    DPass.Diffuse  := ColorTo4S(Color);
    DPass.Specular := ColorTo4S(Color);
    APIState.ApplyPass(DPass);
    RenderTesselator(Tess);
  end;
end;

procedure TOGLRenderer.RenderItemDebug(Item: TProcessing);
var CurPass, i: Integer; Tess: TTesselator; Mat: TMatrix4s; Offset: TVector3s;
begin
 if not IsReady then Exit;

//                * Move to material settings *
  glEnable(GL_COLOR_MATERIAL);
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

    SetModelMatrix(@Mat);

    Tess := DebugTesselators[Ord(Item.Colliding.Volumes[i].VolumeKind) * Ord(Ord(Item.Colliding.Volumes[i].VolumeKind) <= High(DebugTesselators))];
    if not Buffers.Put(Tess) then Exit;

    if Assigned(DebugMaterial) and (DebugMaterial.TotalTechniques > 0) then
      if Assigned(DebugMaterial.Technique[0]) then
        for CurPass := 0 to DebugMaterial[0].TotalPasses-1 do if DebugMaterial[0].Passes[CurPass] <> nil then begin
          APIState.ApplyPass(DebugMaterial[0].Passes[CurPass]);
          RenderTesselator(Tess);
        end;
  end;
end;

procedure TOGLRenderer.Clear(Flags: TClearFlagsSet; Color: BaseTypes.TColor; Z: Single; Stencil: Cardinal);
begin
  if (Flags = []) or not IsReady then Exit;

  glDepthMask(True);
  glClearColor(((Color.C shr 16) and $FF)*OneOver255, ((Color.C shr 8) and $FF)*OneOver255, (Color.C and $FF)*OneOver255, ((Color.C shr 24) and $FF)*OneOver255);
  glClearDepth(Z);
  glClearStencil(Stencil);

  glClear(GL_COLOR_BUFFER_BIT*Ord(ClearFrameBuffer in Flags) or GL_DEPTH_BUFFER_BIT*Ord(ClearZBuffer in Flags) or GL_STENCIL_BITS*Ord(ClearStencilBuffer in Flags));

  ReportGLError(ClassName + '.Clear:');
end;

end.
