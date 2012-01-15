(*
 CAST II Engine landscape demo main unit
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 (C) 2007 George "Mirage" Bakhtadze
*)
{$I GDefines.inc}
{$I C2Defines.inc}
unit LandMain;

interface

uses
  SysUtils,
  Logger, Basics, AppsInit, Props, OSUtils, Base2D,

  Resources, BaseGraph, BaseTypes, BaseMsg, Base3D, BaseClasses,
  CAST2, C2Visual, C2Res, C2VisItems, C2Anim, C22D, C2FX, C2Land, C2TileMaps, C2Flora,
  ACS, ACSAdv, C2GUI,

  C2Affectors, C2ParticleAdv,
  C2Grass,

  C2Render, {$IFDEF DIRECT3D8} C2DX8Render, {$ENDIF}
  Input, WInput,
  C2Core,
  Timer;

const
  // These constants can be adjusted
  RunFullScreen = False;                      // Fullscreen mode
  SceneFileName = 'Land.cbf';                 // Scene to load
  CameraRotateSpeed = 0.003;                  // Camera rotation sensitivity
  CameraMoveAccel   = 0.0200;                 // Camera movement sensitivity
  MinCameraAlt      = 7.0;                    // Min camera altitude
  BreakFactor       = 0.90;
  CameraMoveRadius  = 2000;                   // How far camera can move
  TimerDelay        = 1/60;                   // Delay between timer events
  LightRotateSpeed  = 0.0;                    // How fast light direction changes

  DetailLowXStr        = '100';                  // Landscape grid X resolution for low detail
  DetailLowYZStr       = '120';                  // Landscape grid YZ resolution for low detail
  DetailLowClipMapStr  = '256';                  // Landscape megatexture clipmap size for low detail
  DetailLowSMRes       = 512;                    // Shadow map resolution for low detail

  DetailMedXStr        = '180';                  // Landscape grid X resolution for medium detail
  DetailMedYZStr       = '350';                  // Landscape grid YZ resolution for medium detail
  DetailMedClipMapStr  = '512';                  // Landscape megatexture clipmap size for medium detail
  DetailMedSMRes       = 1024;                   // Shadow map resolution for medium detail

  DetailHighXStr       = '300';                  // Landscape grid X resolution for high detail
  DetailHighYZStr      = '600';                  // Landscape grid YZ resolution for high detail
  DetailHighClipMapStr = '1024';                 // Landscape megatexture clipmap size for high detail
  DetailHighSMRes      = 2048;                   // Shadow map resolution for high detail

  BaseDetail = 500.0;

  KeyLeftBind    = 'A';                       // Key binding to move camera left
  KeyRightBind   = 'D';                       // Key binding to move camera right
  KeyUpBind      = 'Q';                       // Key binding to move camera up
  KeyDownBind    = 'E';                       // Key binding to move camera down
  KeyBackBind    = 'W';                       // Key binding to move camera back
  KeyForwardBind = 'S';                       // Key binding to move camera forward
  KeyBoostBind   = 'Shift';                   // Key binding to boost movement

  // Do not change
  keyLeft    = 0;                             // Left key
  keyRight   = 1;                             // Right key
  keyUp      = 2;                             // Up key
  keyDown    = 3;                             // Down key
  keyBack    = 4;                             // Back key
  keyForward = 5;                             // Forward key
  keyBoost   = 6;                             // Boost key
  keyMax     = 6;                             // Max key index

type
  // Message class for detail switching
  TDetailLowMsg = class(TMessage)
  end;
  // Message class for detail switching
  TDetailMedMsg = class(TMessage)
  end;
  // Message class for detail switching
  TDetailHighMsg = class(TMessage)
  end;

  TLandDemo = class
  private
    OldFramesRendered: Integer;
    VideoMode: Integer;

    KeyPressed: array[0..keyMax] of Boolean;  // Bound keys current state
    Velocity: TVector3s;                      // Current movement speed
    Core: TCore;
    Landscape: TMappedItem;
    FPSLabel: TLabel;
    MainCamera, PostProcessCamera, BloomCamera, ShadowCamera: TCamera;
    Light: TLight;
    LightOrigOrient: TQuaternion;
    function LoadScene(const FileName: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Process;
    procedure ToggleBloom(EventData: Integer; CustomData: SmallInt);
    procedure HandleMouse(EventData: Integer; CustomData: SmallInt);
    procedure HandleTimer(EventID: Integer; const ErrorDelta: TTimeUnit);     // Timer event
    procedure HandleMessage(const Msg: TMessage);                             // Message handler
    procedure HandleKeys(EventData: Integer; CustomData: Smallint);           // Keys handle delegate
  end;

var
  Starter: TAppStarter;                                        // Application starter

implementation

function TLandDemo.LoadScene(const FileName: string): Boolean;

  function FindItem(const ItemName: string; ItemClass: CItem; Mandatory: Boolean): TItem;
  const LogFlag: array[Boolean] of TLogLevel = (lkWarning, lkFatalError);
  begin
    Result := Core.Root.GetChildByName(ItemName, True);
    if not (Result is ItemClass) then begin
      Starter.PrintError('Item "' + ItemName + '" not found in scene', LogFlag[Mandatory]);
      Exit;
    end;
  end;

  function PrepareMegatexture: Boolean;
  const RandomCount = 5;     // number of random pictures placed on megatexture
  var
    i, x, y: Integer;
    MT: TMegaImageResource;
    Stream: TFileStream;
    Header: TImageHeader;
    CData: Pointer;
  begin
    Result := False;
    // Retrieve and setup items related to megatexturing
    MT := FindItem('MegaTexture', TMegaImageResource, True) as TMegaImageResource;
    if not Assigned(MT) then Exit;

    if FileExists('mega.bmp') then begin
      Stream := TFileStream.Create('mega.bmp');
      if LoadBitmapHeader(Stream, Header) then
        MT.SetDimensions(Header.Width, Header.Height);
      Stream.Free;

    end;
    if not FileExists('mega.dat') then begin
      Log('No megatexture data stream found. Creating...');
      MT.SetProperty('Reinit\Source file', 'mega.bmp');
      MT.SetProperty('Store file', 'mega.dat');
      MT.SetProperty('Reinit', OnOffStr[True]);
    end;
    MT.SetProperty('Store file', 'mega.dat');
    Landscape.SetProperty('Texture\Diffuse scale', FloatToStr(MT.Width/(Landscape.Map.Width * Landscape.Map.CellWidthScale)));

    // Place a random picture on megatexture several times
    if FileExists('random.bmp') then begin
      Stream := TFileStream.Create('random.bmp');
      Base2D.LoadBitmap(Stream, Header);
      Stream.Free;
      GetMem(CData, Header.Width * Header.Height * GetBytesPerPixel(MT.Format));
      ConvertImage(Header.Format, MT.Format, Header.Width * Header.Height, Header.Data, Header.PaletteSize, Header.Palette, CData);
      if Assigned(Header.Data) then FreeMem(Header.Data);
      if Assigned(Header.Palette) then FreeMem(Header.Palette);
      for i := 0 to RandomCount-1 do begin
        x := Random(MT.Width  - Header.Width);
        y := Random(MT.Height - Header.Height);
        MT.SaveRect(GetRectWH(x, y, Header.Width, Header.Height), 0, CData, Header.Width, True);
      end;
      if Assigned(CData) then FreeMem(CData);
    end;
    
    Result := True;
  end;

var Stream: TFileStream;
begin
  Stream := TFileStream.Create(Filename);
  Result := Core.LoadScene(Stream);
  Stream.Free;
  if Result then begin
    MainCamera := Core.Renderer.MainCamera;
    if Assigned(MainCamera) then begin
      // Retrieve some needed items
      Landscape   := FindItem('Landscape',   TMappedItem, True)  as TMappedItem;
      FPSLabel    := FindItem('FPSCounter',  TLabel,      False) as TLabel;
      Light       := FindItem('Light',       TLight,      False) as TLight;
      // Camera of light source for shadow mapping
      ShadowCamera := FindItem('ShadowCamera', TCamera,     False) as TCamera;
      // Camera through which a quad with bloom effect is rendered
      BloomCamera := FindItem('BloomCamera', TCamera,     False) as TCamera;
      // Camera which used to render scene for post processing in case of main camera can not be used for this
      PostProcessCamera := FindItem('PostProcessCamera', TCamera, False) as TCamera;

      if Assigned(PostProcessCamera) then begin
        PostProcessCamera.Position    := MainCamera.Position;
        PostProcessCamera.Orientation := MainCamera.Orientation;
      end;  

      if Assigned(Light) then LightOrigOrient := Light.Orientation;

      PrepareMegatexture;
    end else begin
      Starter.PrintError('Camera not found', lkError);
      Result := False;
    end;
  end;
end;

constructor TLandDemo.Create;
var HandleKeysProc: TInputDelegate; 
begin
  Starter.Terminated := True;                                      // Terminate the application if an error occurs

  VideoMode := StrToIntDef(ParamStr(1), -1);

  // Create engine core
  Core := TCore.Create;

  Core.RegisterItemClass(TGrass);

  Core.MessageHandler    := HandleMessage;      // Set message handler
  Starter.MessageHandler := Core.HandleMessage; // Redirect window messages to engine
  // Create renderer
  {$IFDEF DIRECT3D8}
  Core.Renderer := TDX8Renderer.Create(Core);
  Core.Renderer.AppRequirements.HWAccelerationLevel := haPureDevice; 

  {$ENDIF}

  if not Assigned(Core.Renderer) or (Core.Renderer.State = rsNotInitialized) then begin             // Error
    Starter.PrintError('Can''t start renderer', lkFatalError);
    Exit;
  end;

  ActivateWindow(Starter.WindowHandle);                            // Bring the application to foreground

  // Initialize render device
  if not Core.Renderer.CreateDevice(Starter.WindowHandle, MaxI(0, VideoMode), VideoMode <> -1) then begin
    Starter.PrintError('Failed to initiaize render device', lkFatalError);
    Exit;
  end;

  // Initialize input subsystem
  Core.Input := TOSController.Create(Starter.WindowHandle, {$IFDEF OBJFPCEnable}@{$ENDIF}Core.HandleMessage);
  Core.Input.BindCommand('ESC',   TForceQuitMsg);                  // Bind exit to ESC key
  Core.Input.BindCommand('ALT+Q', TForceQuitMsg);                  // Bind exit to ALT+Q key combination
  Core.Input.BindCommand('RMB+MouseStrokeDown^MouseStrokeRight^RMB-', TForceQuitMsg);      // Bind exit to mouse gesture like in Opera browser

  Core.Input.BindCommand('1', TDetailLowMsg);                      // Bind "1" key to switch to low detail
  Core.Input.BindCommand('2', TDetailMedMsg);                      // Bind "1" key to switch to medium detail
  Core.Input.BindCommand('3', TDetailHighMsg);                     // Bind "1" key to switch to high detail

  Core.Input.BindDelegate('B', ToggleBloom, 0);

  Core.Input.BindPointer('F1', atBooleanToggle, @Core.Renderer.DisableTesselation);
  // Bind movements keys to delegate supplying in custom data key index with set 8-th bit if key was pressed down.
  HandleKeysProc := {$IFDEF OBJFPCEnable}@{$ENDIF}HandleKeys;
  Core.Input.BindDelegate(KeyLeftBind  + '+', HandleKeysProc, keyLeft  or $100);
  Core.Input.BindDelegate(KeyLeftBind  + '-', HandleKeysProc, keyLeft);
  Core.Input.BindDelegate(KeyRightBind + '+', HandleKeysProc, keyRight or $100);
  Core.Input.BindDelegate(KeyRightBind + '-', HandleKeysProc, keyRight);

  Core.Input.BindDelegate(KeyUpBind   + '+', HandleKeysProc, keyUp   or $100);
  Core.Input.BindDelegate(KeyUpBind   + '-', HandleKeysProc, keyUp);
  Core.Input.BindDelegate(KeyDownBind + '+', HandleKeysProc, keyDown or $100);
  Core.Input.BindDelegate(KeyDownBind + '-', HandleKeysProc, keyDown);

  Core.Input.BindDelegate(KeyBackBind    + '+', HandleKeysProc, keyBack    or $100);
  Core.Input.BindDelegate(KeyBackBind    + '-', HandleKeysProc, keyBack);
  Core.Input.BindDelegate(KeyForwardBind + '+', HandleKeysProc, keyForward or $100);
  Core.Input.BindDelegate(KeyForwardBind + '-', HandleKeysProc, keyForward);

  Core.Input.BindDelegate(KeyBoostBind + '+', HandleKeysProc, keyBoost or $100);
  Core.Input.BindDelegate(KeyBoostBind + '-', HandleKeysProc, keyBoost);

  Core.Input.MouseCapture := True;

//  Core.CatchAllInput := True;

  Core.Input.BindDelegate('MouseMove^', {$IFDEF OBJFPCEnable}@{$ENDIF}HandleMouse, 0);

  Log('******Loading scene');
  // Load scene
  if not LoadScene(Starter.ProgramExeDir + SceneFileName) then begin
    Starter.PrintError('Error loading scene from file "' + SceneFileName + '"', lkFatalError);
    Exit;
  end;

  Log('******Loaded scene');

  Starter.Terminated := False;                                     // No errors

  Core.Timer.SetEvent(TimerDelay, {$IFDEF OBJFPCEnable}@{$ENDIF}HandleTimer, 0);                 // Launch timer events chain
  Log('******Init OK');
end;

destructor TLandDemo.Destroy;
var SubSystem: TSubSystem;
begin
  SubSystem := Core.Input;
  Core.Input := nil;
  FreeAndNil(SubSystem);
  SubSystem := Core.Renderer;
  Core.Renderer := nil;
  FreeAndNil(SubSystem);
  FreeAndNil(Core);
  inherited;
end;

// PerfHUD
const
  Stride = 4;
  Width = 100 * Stride; Height = 100;
  X = -Width; Y = -Height;
  viFrame = 0; viRender = 1;
var
  Ofs: Integer = 0;
  MaxValue: Single = epsilon;
  Values: array[0..3, 0..Width-1] of Single;
  Count: Integer = 0;

procedure TLandDemo.Process;

  procedure DrawPerfHUD;
  var i: Integer;
  begin
    if Count >= Width div Stride then begin
      Count := 0;
      MaxValue := epsilon;
    end;

    Values[viFrame, Count]  := Core.PerfProfile.Times[ptFrame];
    Values[viRender, Count] := Core.PerfProfile.Times[ptRender];
    if Values[viFrame, Count] > MaxValue then MaxValue := Values[viFrame, Count];
    Inc(Count);
    Screen.ResetViewport;
    Screen.Clear;
  //  Screen.MoveTo(Scree, 0);
  //  Screen.LineTo(100, 100);
  //  Screen.LineTo(100, 200);
    Screen.Color.C := $40000080;
    Screen.Bar(Screen.Width + X, Screen.Height + Y, Screen.Width + X + Width, Screen.Height + Y + Height);
    Screen.Color.C := $40F00000;
    for i := 0 to Count-1 do Screen.Bar(Screen.Width + X+i*Stride, Screen.Height + Y + Height,
                                        Screen.Width + X+i*Stride+Stride-1, Screen.Height + Y + Height - Values[viRender, i]/MaxValue*Height);
    Screen.Color.C := $4000F000;
    for i := 0 to Count-1 do Screen.Bar(Screen.Width + X+i*Stride, Screen.Height + Y + Height - Values[viRender, i]/MaxValue*Height,
                                        Screen.Width + X+i*Stride+Stride-1, Screen.Height + Y + Height - Values[viFrame, i]/MaxValue*Height);
  end;

begin
  Core.Process;
//  DrawPerfHUD;
end;

procedure TLandDemo.HandleMessage(const Msg: TMessage);
var CapMX, CapMY: Integer;
begin
  ObtainCursorPos(CapMX, CapMY);
  if Msg.ClassType = TForceQuitMsg then Starter.Terminate else
  if Msg.ClassType = TDetailLowMsg then begin
    Landscape.SetProperty('X resolution',  DetailLowXStr);
    Landscape.SetProperty('YZ resolution', DetailLowYZStr);
    Landscape.SetProperty('Mip scale', FloatToStr(BaseDetail/StrToFloatDef(DetailLowXStr, BaseDetail)));
    Landscape.SetProperty('Texture\Clipmap size', DetailLowClipMapStr);
    ShadowCamera.RenderTargetWidth  := DetailLowSMRes;
    ShadowCamera.RenderTargetHeight := DetailLowSMRes;
  end;
  if Msg.ClassType = TDetailMedMsg then begin
    Landscape.SetProperty('X resolution',  DetailMedXStr);
    Landscape.SetProperty('YZ resolution', DetailMedYZStr);
    Landscape.SetProperty('Mip scale', FloatToStr(BaseDetail/StrToFloatDef(DetailMedXStr, BaseDetail)));
    Landscape.SetProperty('Texture\Clipmap size', DetailMedClipMapStr);
    ShadowCamera.RenderTargetWidth  := DetailMedSMRes;
    ShadowCamera.RenderTargetHeight := DetailMedSMRes;
  end;
  if Msg.ClassType = TDetailHighMsg then begin
    Landscape.SetProperty('X resolution',  DetailHighXStr);
    Landscape.SetProperty('YZ resolution', DetailHighYZStr);
    Landscape.SetProperty('Mip scale', FloatToStr(BaseDetail/StrToFloatDef(DetailHighXStr, BaseDetail)));
    Landscape.SetProperty('Texture\Clipmap size', DetailHighClipMapStr);
    ShadowCamera.RenderTargetWidth  := DetailHighSMRes;
    ShadowCamera.RenderTargetHeight := DetailHighSMRes;
  end;
end;

procedure TLandDemo.HandleKeys(EventData: Integer; CustomData: Smallint);
begin
  KeyPressed[CustomData and $FF] := CustomData and $100 > 0;
end;

procedure TLandDemo.HandleTimer(EventID: Integer; const ErrorDelta: TTimeUnit);
var Scale, h, t: Single; CameraPos, CameraInLand: TVector3s; Items: TItems; TotalItems: Integer;

  procedure InitShadowCamera;
  const
    ShadowMaxDist = 500;
  var
    Pnts, TPnts: TQuadPoints;
    i: Integer;
    MinP, MaxP: TVector3s;
    M: TMatrix4s;
    d: Single;
  begin
    if Landscape is TProjectedLandscape then TProjectedLandscape(Landscape).ProjectGrid(MainCamera, Pnts);

    M := IdentityMatrix4s;
    Matrix4sByQuat(M, Light.Orientation);
    M := InvertAffineMatrix4s(M);

    ShadowCamera.Orientation := Light.Orientation;

    ShadowCamera.Position := GetVector3s(0, 0, 0);
    for i := 0 to 3 do begin

      d := Sqr(Pnts[i].X - MainCamera.Position.X) + Sqr(Pnts[i].Z - MainCamera.Position.Z);
      if d > Sqr(ShadowMaxDist) then begin
        Pnts[i].X := MainCamera.Position.X + (Pnts[i].X - MainCamera.Position.X)/Sqrt(d) * ShadowMaxDist;
        Pnts[i].Z := MainCamera.Position.Z + (Pnts[i].Z - MainCamera.Position.Z)/Sqrt(d) * ShadowMaxDist;
      end;


//      Pnts[i].Y := 0;
      Transform4Vector33s(TPnts[i], M, Pnts[i]);
    end;

    MinP := TPnts[0];
    MaxP := TPnts[0];
    for i := 1 to 3 do begin
      MinP.X := MinS(MinP.X, TPnts[i].X);
      MinP.Y := MinS(MinP.Y, TPnts[i].Y);
      MinP.Z := MinS(MinP.Z, TPnts[i].Z);
      MaxP.X := MaxS(MaxP.X, TPnts[i].X);
      MaxP.Y := MaxS(MaxP.Y, TPnts[i].Y);
      MaxP.Z := MaxS(MaxP.Z, TPnts[i].Z);
    end;
    ShadowCamera.InitOrthoProjMatrix(0.1, MaxS(4000, (100+MaxP.Z-MinP.Z)*2), MaxS(MaxP.X-MinP.X, MaxP.Y-MinP.Y), 1);

    MulMatrix4s(M, M, TranslationMatrix4s(-(MinP.X+MaxP.X)*0.5, -(Minp.Y+MaxP.Y)*0.5, -MinP.Z+100));
    ShadowCamera.ViewMatrix := M;

    for i := 0 to 3 do begin
      Transform4Vector33s(TPnts[i], M, Pnts[i]);
    end;
    MinP := TPnts[0];
    MaxP := TPnts[0];
    for i := 1 to 3 do begin
      MinP.X := MinS(MinP.X, TPnts[i].X);
      MinP.Y := MinS(MinP.Y, TPnts[i].Y);
      MinP.Z := MinS(MinP.Z, TPnts[i].Z);
      MaxP.X := MaxS(MaxP.X, TPnts[i].X);
      MaxP.Y := MaxS(MaxP.Y, TPnts[i].Y);
      MaxP.Z := MaxS(MaxP.Z, TPnts[i].Z);
    end;
  end;

  procedure InitShadowCamera2;
  var
    i: Integer;
    MinP, MaxP, TPnt: TVector3s;
    M: TMatrix4s;
    d: Single;
  begin
    TotalItems := TCASTRootItem(Core.Root).ExtractByMaskClassInCamera([isVisible], TMesh, Items, MainCamera);

    M := IdentityMatrix4s;
    Matrix4sByQuat(M, Light.Orientation);
    M := InvertAffineMatrix4s(M);

    ShadowCamera.Orientation := Light.Orientation;

    ShadowCamera.Position := GetVector3s(0, 0, 0);

    for i := 0 to TotalItems-1 do if TVisible(Items[i]).Material.Technique[0].Passes[0].Group = 1 then begin
      d := TVisible(Items[i]).BoundingSphereRadius;
      Transform4Vector33s(TPnt, M, TProcessing(Items[i]).GetAbsLocation);
      if i = 0 then begin
        MinP := SubVector3s(TPnt, GetVector3s(d, d, d));
        MaxP := AddVector3s(TPnt, GetVector3s(d, d, d));
      end else begin
        MinP.X := MinS(MinP.X, TPnt.X-d);
        MinP.Y := MinS(MinP.Y, TPnt.Y-d);
        MinP.Z := MinS(MinP.Z, TPnt.Z-d);
        MaxP.X := MaxS(MaxP.X, TPnt.X+d);
        MaxP.Y := MaxS(MaxP.Y, TPnt.Y+d);
        MaxP.Z := MaxS(MaxP.Z, TPnt.Z+d);
      end;
    end;

    ShadowCamera.InitOrthoProjMatrix(0.1, MaxS(4000, (100+MaxP.Z-MinP.Z)*2), MaxS(MaxP.X-MinP.X, MaxP.Y-MinP.Y), 1);

    MulMatrix4s(M, M, TranslationMatrix4s(-(MinP.X+MaxP.X)*0.5, -(Minp.Y+MaxP.Y)*0.5, -MinP.Z+200));
    ShadowCamera.ViewMatrix := M;
  end;

  procedure InitShadowCamera3;
  const
    ShadowMaxDist = 500;
  var
    Pnts, TPnts: array[0..7] of TVector3s;
    i: Integer;
    MinP, MaxP: TVector3s;
    M: TMatrix4s;
    zf: Single;
  begin
    zf := 500;//MainCamera.ZFar*0.01;
    Pnts[0].x := -2 * (Sin(MainCamera.HFoV / 2)/Cos(MainCamera.HFoV / 2)) * MainCamera.ZNear;
    Pnts[0].y := Pnts[0].X * MainCamera.CurrentAspectRatio;
    Pnts[0].Z := MainCamera.ZNear;
    Pnts[1] := Pnts[0];
    Pnts[1].Y := -Pnts[1].Y;
    Pnts[2] := Pnts[1];
    Pnts[2].X := -Pnts[2].X;
    Pnts[3] := Pnts[2];
    Pnts[3].Y := -Pnts[3].Y;

    Pnts[4].x := -2 * (Sin(MainCamera.HFoV / 2)/Cos(MainCamera.HFoV / 2)) * zf;
    Pnts[4].y := Pnts[0].X * MainCamera.CurrentAspectRatio;
    Pnts[4].Z := zf;
    Pnts[5] := Pnts[4];
    Pnts[5].Y := -Pnts[5].Y;
    Pnts[6] := Pnts[5];
    Pnts[6].X := -Pnts[6].X;
    Pnts[7] := Pnts[6];
    Pnts[7].Y := -Pnts[7].Y;

    M := IdentityMatrix4s;
    Matrix4sByQuat(M, Light.Orientation);
    M := InvertAffineMatrix4s(M);

    ShadowCamera.Orientation := Light.Orientation;

    ShadowCamera.Position := GetVector3s(0, 0, 0);
    for i := 0 to 7 do begin
      Pnts[i] := Transform4Vector33s(InvertAffineMatrix4s(MainCamera.ViewMatrix), Pnts[i]);
      Transform4Vector33s(TPnts[i], M, Pnts[i]);
    end;

    MinP := TPnts[0];
    MaxP := TPnts[0];
    for i := 1 to 7 do begin
      MinP.X := MinS(MinP.X, TPnts[i].X);
      MinP.Y := MinS(MinP.Y, TPnts[i].Y);
      MinP.Z := MinS(MinP.Z, TPnts[i].Z);
      MaxP.X := MaxS(MaxP.X, TPnts[i].X);
      MaxP.Y := MaxS(MaxP.Y, TPnts[i].Y);
      MaxP.Z := MaxS(MaxP.Z, TPnts[i].Z);
    end;
    ShadowCamera.InitOrthoProjMatrix(0.1, MaxS(4000, (100+MaxP.Z-MinP.Z)*2), MaxS(MaxP.X-MinP.X, MaxP.Y-MinP.Y), 1);

    MulMatrix4s(M, M, TranslationMatrix4s(-(MinP.X+MaxP.X)*0.5, -(Minp.Y+MaxP.Y)*0.5, -MinP.Z+100));
    ShadowCamera.ViewMatrix := M;
  end;

begin
  Scale := (TimerDelay + ErrorDelta)/TimerDelay;

  if KeyPressed[keyBoost] then Scale := Scale * 4;
  

  MainCamera.Position := AddVector3s(MainCamera.Position, ScaleVector3s(Velocity, Scale));

  CameraPos := MainCamera.Position;

  Velocity := ScaleVector3s(Velocity, 1-(1-BreakFactor)*scale);

  Velocity := AddVector3s(Velocity,
                          Transform3Vector3s(CutMatrix3s(MainCamera.Transform),
                                    GetVector3s( (Ord(KeyPressed[keyRight]) - Ord(KeyPressed[keyLeft]))    * CameraMoveAccel * Scale,
                                                 (Ord(KeyPressed[keyUp])    - Ord(KeyPressed[keyDown]))    * CameraMoveAccel * Scale,
                                                 (Ord(KeyPressed[keyBack])  - Ord(KeyPressed[keyForward])) * CameraMoveAccel * Scale)) );

  if Sqr(CameraPos.X) + Sqr(CameraPos.Z) > Sqr(CameraMoveRadius) then begin
    t := Sqrt(Sqr(CameraPos.X) + Sqr(CameraPos.Z));
    CameraPos.X := CameraPos.X / t * CameraMoveRadius;
    CameraPos.Z := CameraPos.Z / t * CameraMoveRadius;
  end;

  CameraInLand := Transform4Vector33s(InvertAffineMatrix4s(Landscape.Transform), CameraPos);

  h := Landscape.Map.GetHeight(CameraInLand.X, CameraInLand.Z);
  if h + MinCameraAlt > CameraInLand.Y then begin
    CameraPos.Y := CameraPos.Y + h + MinCameraAlt - CameraInLand.Y;
  end;

//  Velocity := AddVector3s(Velocity, ScaleVector3s(SubVector3s(CameraPos, MainCamera.Position), 1));
  MainCamera.Position := CameraPos;
  PostProcessCamera.Position := MainCamera.Position;

  Core.Timer.SetEvent(TimerDelay, {$IFDEF OBJFPCEnable}@{$ENDIF}HandleTimer, 0);

//  FPS := (Core.Renderer.FramesRendered - OldFramesRendered) / (TimerDelay + ErrorDelta);

  OldFramesRendered := Core.Renderer.FramesRendered;

//  OSUtils.SetWindowCaption(Starter.WindowHandle, Format('%3.3F - %3.3F, %3.3F', [Core.PerfProfile.FramesPerSecond, FPS, Scale]));
  FPSLabel.Text := 'FPS: ' + FloatToStrF(Core.PerfProfile.FramesPerSecond,    ffGeneral, 5, 3) +
                   '. PPS: ' + FloatToStrF(Core.PerfProfile.PrimitivesRendered * Core.PerfProfile.FramesPerSecond/1000000, ffNumber, 8, 2) + 'M';

  if Assigned(Light) then begin
    Light.Orientation := MulQuaternion(GetQuaternion(Light.TimeProcessed*LightRotateSpeed, GetVector3s(0, 1, 0)),
                                               LightOrigOrient);
    InitShadowCamera;
  end;
end;

procedure TLandDemo.HandleMouse(EventData: Integer; CustomData: SmallInt);
var MX, MY: Integer;
begin
  MX := Smallint(EventData and $FFFF);
  MY := Smallint((EventData div $10000) and $FFFF);
  with MainCamera do
    Orientation := MulQuaternion(GetQuaternion(MX*CameraRotateSpeed, GetVector3s(0, 1, 0)),
                                 MulQuaternion(GetQuaternion(MY*CameraRotateSpeed, RightVector),
                                               Orientation));
  PostProcessCamera.Orientation := MainCamera.Orientation;
//  BloomCamera.AspectRatio := 1/MainCamera.AspectRatio;
end;

procedure TLandDemo.ToggleBloom(EventData: Integer; CustomData: SmallInt);
begin
  if Assigned(BloomCamera) and (Core.Renderer.MainCamera = MainCamera) then begin
    Core.Renderer.MainCamera := BloomCamera;
    MainCamera.AspectRatio := MainCamera.CurrentAspectRatio;
//    Core.Renderer.MainCamera := ShadowCamera
  end else begin
    Core.Renderer.MainCamera := MainCamera;
    MainCamera.AspectRatio := 1;
  end;  
end;

end.
