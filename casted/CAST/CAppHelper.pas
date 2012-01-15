{$Include GDefines}
{$Include CDefines}
unit CAppHelper;

interface

uses
  Windows,         // ToDo: move message processing to OSUtils
  SysUtils, Messages,
   Logger, 
  Basics, BaseCont, AppsHelper, AppsInit, CTypes, CAST, CRender,
  {$IFNDEF OpenGL} CDX8Render, {$ENDIF} {$IFDEF OpenGL} COGLRender, {$ENDIF}
  {$IFDEF Audio} CSound, {$ENDIF}
  CInput, {$IFDEF USE_DI} CDInput {$ELSE} CWInput {$ENDIF},
  {$IFDEF NETSUPPORT} CNet, {$ENDIF}
  CRes;

const
  vpcX = 0; vpcY = 1;
  cmMove = 0; cmRotate = 1; cmZoom = 2;
// Commands
  CAppCmdBase = $FFFF;
{$IFDEF DEBUGMODE}
  cmdSpeedLo = CAppCmdBase + 280; cmdSpeedNormal = CAppCmdBase + 281; cmdSpeedHi = CAppCmdBase + 282;
{$ENDIF}
  cmdToggleFullscreen = CAppCmdBase + 300;
  cmdMinimize = CAppCmdBase + 301;

  cmdMouseMove = CAppCmdBase + 500;
  cmdMouseRoll = CAppCmdBase + 501;

  cmdMoveDown = CAppCmdBase + 701; cmdRotateDown = CAppCmdBase + 702; cmdZoomDown = CAppCmdBase + 703;
  cmdMRotateDown = CAppCmdBase + 704; cmdMZoomDown = CAppCmdBase + 705;
  cmdMoveUp = CAppCmdBase + 706; cmdRotateUp = CAppCmdBase + 707; cmdZoomUp = CAppCmdBase + 708;
  cmdADown = CAppCmdBase + 710; cmdWDown = CAppCmdBase + 711;
  cmdSDown = CAppCmdBase + 712; cmdDDown = CAppCmdBase + 713;
  cmdQDown = CAppCmdBase + 714; cmdEDown = CAppCmdBase + 715;
  cmdZDown = CAppCmdBase + 716; cmdCDown = CAppCmdBase + 717;

{$IFDEF NETSUPPORT}
  cmdNetPlayerIndex = CAppCmdBase + 1000;       // Arg1 - Index, Arg2 - PlayerID
  cmdNetPlayerName = CAppCmdBase + 1001;
  cmdChatMessage = CAppCmdBase + 1002;
{$ENDIF}

// Video modes
  vmWindowed = 0; vm320 = 1; vm640 = 2; vm800 = 3; vm1024 = 4; vm1280 = 5;
  vmDefaultFullScreen = vm1024; vmDefault = vm1024;
  bpp16 = 0; bpp32 = 1; bppDefault = bpp16;
// Detail options
  lodLow = 0; lodHigh = 1;
// AWSD camera control modes
  ccNone = 0; ccMove = 1; ccRotate = 2; ccMoveZoom = 3; ccXMoveZoom = 4;

  YesNoVariants: array[False..True] of string = ('No', 'Yes');
  CheckBoxVariants: array[False..True] of string = ('[  ]', '[x]');

type
  TCastApp = class(TWin32App)
    World: TWorld;
{$IFDEF AUDIO}
    Audio: TAudioManager;
{$ENDIF}
    Controller: TController;
    CommandQueue: TCommandQueue;
{$IFDEF NETSUPPORT}
    Net: TDX8Net;
    GameHostName: string;
{$ENDIF}

    CatchAllInput: Boolean;

    Camera: TViewCamera;
    MinCameraRange, MaxCameraRange, CameraMinXAngle, CameraMaxXAngle: Single;

    KeyboardCameraControl, ForceMouseCameraControl: Boolean;
    AWSDCameraControlMode: Integer;
    AWSDCameraSens: Single;

    ResFilename, SceneFilename, MatFilename, AudioFilename: string;

    RenderWindowHandle: Cardinal;
    constructor Create(AProgramName: string; AStarter: TAppStarter; WorldClass: CWorld); virtual;
    function InitEngine: Boolean; virtual;

    procedure GotoURL(const URLFileName: string); 

    procedure ResetConfig; override;
    procedure ResetGameConfig; virtual;
    procedure ResetPlayerConfig; virtual;
    procedure ResetVideoConfig; virtual;
    procedure ResetAudioConfig; virtual;
{$IFDEF NETSUPPORT}
    procedure ResetNetworkMode; virtual;
    procedure ResetNetworkConfig; virtual;
{$ENDIF}

    procedure InitControls; virtual;
    function GraphicsRestart: Boolean; virtual;
    function SetVideoMode(Mode, Depth: Integer; StartUp: Boolean): Boolean; virtual;
    function GetViewportCenter(Coord: Integer): Integer; virtual;

    procedure ShowItem(const ItemName: string); virtual;
    procedure ToggleItem(const ItemName: string; Parent: TItem = nil); virtual;
    procedure HideItem(const ItemName: string); virtual;

    function ProcessMessage(Msg: Longword; wParam: Integer; lParam: Integer): Integer; override;
    procedure ProcessMessages(Messages: TCommandQueue); virtual;
{$IFDEF NETSUPPORT}
    procedure ProcessNetMessages(Messages: TCommandQueue); virtual;
{$ENDIF}
    procedure Process; override;
    procedure WorldProcess; virtual;

    function isInCameraControlMode: Boolean; virtual;
    procedure MoveCamera(X, Y: Single); virtual;
    procedure RotateCamera(XA, YA: Single); virtual;
    function ViewToCamera(ViewCamera: TViewCamera): TCamera; virtual;
    function CameraToView(Camera: TCamera; Range: Single): TViewCamera; virtual;
    procedure ChangeCamera(NewCamera: TCamera); virtual;
    procedure ShockCamera(ShockTime: Integer; ShockAmplitude: Single); virtual;
    procedure StopCamera; virtual;
    function GetCustomCamera: TCamera; virtual;
    procedure ProcessCamera; virtual;

    procedure PollInput; virtual;
    procedure ProcessInput; virtual;
    destructor Free;
  protected
    VideoModeVariants, ColorDepthVariants: array of string;
{$IFDEF NETSUPPORT}
    NetModeVariants, BaudVariants, FlowControlVariants, ParityVariants, StopBitsVariants: TStringArray;
{$ENDIF}
    VideoModeWidth, VideoModeHeight, BitDepth: array of Integer;
    SpecularVariants, DetailVariants: array of string;

    ResStream: TDStream;
    MouseInGUI, MoveMode, RotateMode, ZoomMode,
    APressed, WPressed, SPressed, DPressed,
    QPressed, EPressed, ZPressed, CPressed: Boolean;

    SkipCameraControl, SkipInputPoll: Boolean;

    CameraBlend, CameraShock: Boolean;
    OldCam, Cam: TCamera;
    CamK, CamKIncr: Single;
    CameraShockTimer, CameraShockTime: Integer;
    CameraShockAmplitude: Single;

    LastVideoMode, LastColorDepth, LastFSVideoMode: Integer;
    procedure StartCameraMode(Mode: Cardinal); virtual;
    procedure EndCameraMode(Mode: Cardinal); virtual;
  end;

implementation

uses Base3D, OSUtils;

const
  StrNoDX = 'DirectX 8 or greater is not installed!'#13#10'You can download it at http://www.microsoft.com/directx';
//  StrUIError = 'Initialization error. File corrupt or version mismatch.'#13#10'Reinstalling the application should fix this problem.';
//  ZeroGUID: TGUID = '{00000000-0000-0000-0000-000000000000}';

procedure CastAppProcessRoutine;
begin
  if CurrentApplication is TCastApp then (CurrentApplication as TCastApp).WorldProcess;
end;

{ TCastApp }

constructor TCastApp.Create(AProgramName: string; AStarter: TAppStarter; WorldClass: CWorld); 
var i, j: Integer; SR: TSearchRec; Update: TResourceManager; Stream: TFileDStream; s: string;
begin
  SetLength(VideoModeVariants, 6);
  SetLength(ColorDepthVariants, 2);

  VideoModeVariants[vmWindowed] := 'Windowed'; VideoModeVariants[vm320] := '320x240';
  VideoModeVariants[vm640] := '640x480';       VideoModeVariants[vm800] := '800x600';
  VideoModeVariants[vm1024] := '1024x768';     VideoModeVariants[vm1280] := '1280x1024';

  ColorDepthVariants[bpp16] := '16 bit';  ColorDepthVariants[bpp32] := '32 bit';

  SetLength(VideoModeWidth, 6); SetLength(VideoModeHeight, 6); SetLength(BitDepth, 2);
  VideoModeWidth[vmWindowed] := 800; VideoModeHeight[vmWindowed] := 600;
  VideoModeWidth[vm320] := 320; VideoModeHeight[vm320] := 240;
  VideoModeWidth[vm640] := 640; VideoModeHeight[vm640] := 480;
  VideoModeWidth[vm800] := 800; VideoModeHeight[vm800] := 600;
  VideoModeWidth[vm1024] := 1024; VideoModeHeight[vm1024] := 768;
  VideoModeWidth[vm1280] := 1280; VideoModeHeight[vm1280] := 1024;
  BitDepth[bpp16] := 16; BitDepth[bpp32] := 32;
{$IFDEF NETSUPPORT}
  Split('9600\&14400\&19200\&38400\&56000\&57600\&115200', '\&', BaudVariants, False);
  Split('NONE\&XONXOFF\&RTS\&DTR\&RTSDTR', '\&', FlowControlVariants, False);
  Split('NONE\&EVEN\&ODD\&MARK\&SPACE', '\&', ParityVariants, False);
  Split('1\&1.5\&2', '\&', StopBitsVariants, False);
{$ENDIF}
  SetLength(SpecularVariants, 3);
  SetLength(DetailVariants, 2);

  SpecularVariants[slNone] := 'None'; SpecularVariants[slFast] := 'Fast'; SpecularVariants[slQuality] := 'Quality';
  DetailVariants[lodLow] := 'Low'; DetailVariants[lodHigh] := 'High';

  inherited Create(AProgramName, AStarter);

  if Starter.Finished then Exit;                           // Error occured

  ResFilename   := ProgramExeName + '.rdb';
  SceneFilename := ProgramExeName + '.csd';
  MatFilename   := ProgramExeName + '.cml';
  AudioFilename := ProgramExeName + '.csl';

  RenderWindowHandle := Starter.WindowHandle;

  Starter.Finished := True;

  SkipInputPoll := False;
  SkipCameraControl := False;
  ForceMouseCameraControl := False;

  if FileExists(ResFilename) then ResStream := TFileDStream.Create(ResFilename) else begin

    Log('File "'+ ResFilename + '" not found', lkFatalError);

    Exit;
  end;

  World := WorldClass.Create(ResStream, [], []);

   Log('Checking directory "update\" for updates...', lkTitle); 
  if FindFirst('update\*.rdb', faReadOnly or faHidden or faSysFile or faArchive, SR) = 0 then begin
    repeat

      Log('Update found in file "update\' + SR.Name + '"');

    Stream := TFileDStream.Create('update\' + SR.Name);
    Update := TResourceManager.Create(Stream, [TFontResource]);
    World.ResourceManager.Merge(Update, moReplaceIfNewer);
    Stream.Free;
    World.ResourceManager.Save;

    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end else begin

    Log('No updates found', lkTitle);

  end;

{$IFDEF SCREENSAVER}
  CFG.SetOptionIndex('VideoMode', 0);
{$ENDIF}

{$IFNDEF ONLINEBUILD}  
  ActivateSelf;
{$ENDIF}

  CommandQueue := TCommandQueue.Create;
{$IFDEF OPENGL}
  World.Renderer := TOGLRenderer.Initialize(World.ResourceManager, CommandQueue);
//  World.Renderer := TOGLDispListRenderer.Initialize(World.ResourceManager, CommandQueue  , Log );
{$ELSE}
  World.Renderer := TDX8Renderer.Initialize(World.ResourceManager, CommandQueue);
{$ENDIF}

  World.Renderer.NormalWindowStyle := Starter.WindowStyle;

  if World.Renderer.State = rsNotInitialized then begin

    Log('Can''t start renderer', lkFatalError);

    Starter.PrintError(StrNoDX, etFatalError);
    Exit;
  end;

{$IFDEF USE_DI}
  Controller := TDIController.Create(RenderWindowHandle);
{$ELSE}
  Controller := TWin32Controller.Create(RenderWindowHandle);
{$ENDIF}

{$IFDEF AUDIO}  
  Audio := TDX8AudioManager.Initialize(Starter.WindowHandle, World.ResourceManager);
{$ENDIF}

{$IFDEF NETSUPPORT}
  Net := TDX8Net.Initialize(AppGUID, World.NetMessages);
  SetLength(NetModeVariants, Net.TotalServiceProviders);
  for i := 0 to Net.TotalServiceProviders-1 do begin
    s := Net.SPInfo[i].pwszName;
    j := Pos('DirectPlay8', s);
    if j > 0 then Delete(s, j, Length('DirectPlay8'));
    j := Pos('Service Provider', s);
    if j > 0 then Delete(s, j, Length('Service Provider'));

    s := Trim(s);
    s := Upcase(s[1]) + Copy(s, 2, Length(s));

    NetModeVariants[i] := s;
    if Pos('TCP/IP', UpperCase(s)) > 0 then Net.SetServiceProvider(i);
  end;
  GameHostName := 'CAST multiplayer host';
{$ENDIF}

  LastFSVideoMode := vmDefaultFullScreen;
  if GraphicsRestart then Starter.Finished := False;

  MinCameraRange := ln(2000); MaxCameraRange := ln(10000);
  CameraMinXAngle := -pi/2;
  CameraMaxXAngle := pi/2*0;
  Camera.Range := ln(200); Camera.XAngle := -60/180*pi; Camera.YAngle := 90/180*pi;
  ProcessCamera;

  AWSDCameraControlMode := ccMove;
  AWSDCameraSens := 5;

  if not (Starter is TScreenSaverStarter) or not (Starter as TScreenSaverStarter).PreviewMode then InitControls;
end;

function TCastApp.InitEngine: Boolean;
var Stream: TFileDStream;
begin
  Result := False;

  World.Start;

  World.ProcessRoutine := CastAppProcessRoutine;

  Stream := TFileDStream.Create(MatFilename);
  World.LoadMaterials(Stream);
  Stream.Free;

  if not Assigned(World) or not Assigned(World.FRenderer) then Exit;
//  World.FRenderer.SetFog(fkVertexRanged, $0030A0FF, 32767, 65536);
//  World.FRenderer.SetTextureFiltering(0, tfPoint, tfPoint, tfPoint);

  CameraShock := False; CameraShockAmplitude := 0;

  World.Renderer.InitMatrices(90/180*pi, World.FRenderer.RenderPars.CurrentAspectRatio, 10, 65536*2);

  World.Renderer.RestoreViewport;

  World.Renderer.SetSpecular(Cfg['Specular'].OptionIndex);

  World.AddLight(GetLight(ltDirectional, NormalizeVector3s(GetVector3s(
                          128+0*512*(Cos((World.Renderer.FrameNumber shr 1) mod 360/180*pi*1)), -64,
                          0*64*(Cos((World.Renderer.FrameNumber shr 1) mod 360/180*pi*1))),
                          256), 0.5, 0.5, 0.5, 0));

  World.SetAmbient(GetColorB(96, 96, 96, 0));

  Stream := TFileDStream.Create(SceneFilename);
  Result := World.LoadScene(Stream) = feOK;
  Stream.Free;

  CatchAllInput := False;

//  ActivateSelf;
end;

procedure TCastApp.InitControls;
var AX, AY: Integer;
begin
  with Controller do begin
    ProcessInput(nil, efNone);

    if KeyboardCameraControl then begin
      BindCommand(NewBinding(btKeyDown, IK_W), cmdWDown); BindPointer(NewBinding(btKeyUp, IK_W), atBooleanOff, @WPressed);
      BindCommand(NewBinding(btKeyDown, IK_S), cmdSDown); BindPointer(NewBinding(btKeyUp, IK_S), atBooleanOff, @SPressed);
      BindCommand(NewBinding(btKeyDown, IK_A), cmdADown); BindPointer(NewBinding(btKeyUp, IK_A), atBooleanOff, @APressed);
      BindCommand(NewBinding(btKeyDown, IK_D), cmdDDown); BindPointer(NewBinding(btKeyUp, IK_D), atBooleanOff, @DPressed);

      BindCommand(NewBinding(btKeyDown, IK_Q), cmdQDown); BindPointer(NewBinding(btKeyUp, IK_Q), atBooleanOff, @QPressed);
      BindCommand(NewBinding(btKeyDown, IK_E), cmdEDown); BindPointer(NewBinding(btKeyUp, IK_E), atBooleanOff, @EPressed);
      BindCommand(NewBinding(btKeyDown, IK_Z), cmdZDown); BindPointer(NewBinding(btKeyUp, IK_Z), atBooleanOff, @ZPressed);
      BindCommand(NewBinding(btKeyDown, IK_C), cmdCDown); BindPointer(NewBinding(btKeyUp, IK_C), atBooleanOff, @CPressed);

      BindCommand(NewBinding(btKeyDown, IK_HOME), cmdQDown); BindPointer(NewBinding(btKeyUp, IK_HOME), atBooleanOff, @QPressed);
      BindCommand(NewBinding(btKeyDown, IK_PGUP), cmdEDown); BindPointer(NewBinding(btKeyUp, IK_PGUP), atBooleanOff, @EPressed);
      BindCommand(NewBinding(btKeyDown, IK_END), cmdZDown);  BindPointer(NewBinding(btKeyUp, IK_END),  atBooleanOff, @ZPressed);
      BindCommand(NewBinding(btKeyDown, IK_PGDN), cmdCDown); BindPointer(NewBinding(btKeyUp, IK_PGDN), atBooleanOff, @CPressed);
    end;

{$IFDEF SCREENSAVER}
    BindCommand(NewBinding(btKeyDown, IK_UP), cmdWDown);    BindPointer(NewBinding(btKeyUp, IK_UP),    atBooleanOff, @WPressed);
    BindCommand(NewBinding(btKeyDown, IK_DOWN), cmdSDown);  BindPointer(NewBinding(btKeyUp, IK_DOWN),  atBooleanOff, @SPressed);
    BindCommand(NewBinding(btKeyDown, IK_LEFT), cmdADown);  BindPointer(NewBinding(btKeyUp, IK_LEFT),  atBooleanOff, @APressed);
    BindCommand(NewBinding(btKeyDown, IK_RIGHT), cmdDDown); BindPointer(NewBinding(btKeyUp, IK_RIGHT), atBooleanOff, @DPressed);
{$ELSE}
{$IFNDEF ONLINEBUILD}
    BindCommand(NewBinding(btKeyClick, IK_GRAVE), cmdMinimize);
    BindPointer(NewBinding(btKeyDown, IK_Q, NewBinding(btKeyDown, IK_U, NewBinding(btKeyDown, IK_I, NewBinding(btKeyDown, IK_T)))), atBooleanOn, @Starter.Finished, 0, 1000);
    BindPointer(NewBinding(btKeyDown, IK_LALT, NewBinding(btKeyDown, IK_Q)), atBooleanOn, @Starter.Finished, 0, 0, NewBinding(btKeyUp, IK_LALT));
    BindCommand(NewBinding(btKeyDown, IK_LALT, NewBinding(btKeyClick, IK_RETURN)), cmdToggleFullscreen, 0, NewBinding(btKeyUp, IK_LALT));

    BindCommand(NewBinding(btKeyDown, IK_MOUSELEFT), cmdMZoomDown); Controller.BindCommand(NewBinding(btKeyUp, IK_MOUSELEFT), cmdZoomUp);
    BindCommand(NewBinding(btKeyDown, IK_MOUSERIGHT), cmdMRotateDown); Controller.BindCommand(NewBinding(btKeyUp, IK_MOUSERIGHT), cmdRotateUp);
{$ENDIF}
    BindCommand(NewBinding(btKeyDown, IK_LALT), cmdRotateDown); Controller.BindCommand(NewBinding(btKeyUp, IK_LALT), cmdRotateUp);

    BindCommand(NewBinding(btKeyDown, IK_LSHIFT), cmdZoomDown); Controller.BindCommand(NewBinding(btKeyUp, IK_LSHIFT), cmdZoomUp);
    BindCommand(NewBinding(btKeyDown, IK_MOUSEMIDDLE), cmdMoveDown); Controller.BindCommand(NewBinding(btKeyUp, IK_MOUSEMIDDLE), cmdMoveUp);
    BindCommand(NewBinding(btKeyDown, IK_CONTROL), cmdMoveDown); Controller.BindCommand(NewBinding(btKeyUp, IK_CONTROL), cmdMoveUp);
    BindCommand(NewBinding(btKeyDown, IK_LCONTROL), cmdMoveDown); Controller.BindCommand(NewBinding(btKeyUp, IK_LCONTROL), cmdMoveUp);

    BindCommand(NewBinding(btMouseMove, 0), cmdMouseMove);
    BindCommand(NewBinding(btMouseRoll, 0), cmdMouseRoll);
{$ENDIF}

{$IFDEF DEBUGMODE}
    BindPointer(NewBinding(btKeyClick, IK_B), atBooleanToggle, @World.DebugOut);
    BindPointer(NewBinding(btKeyClick, IK_8), atSetLongWord, @World.Renderer.FillMode, fmSolid);
    BindPointer(NewBinding(btKeyClick, IK_9), atSetLongWord, @World.Renderer.FillMode, fmWire);
    BindPointer(NewBinding(btKeyClick, IK_0), atSetLongWord, @World.Renderer.FillMode, fmPoint);

    BindCommand(NewBinding(btKeyClick, IK_F5), cmdSpeedLo);
    BindCommand(NewBinding(btKeyClick, IK_F6), cmdSpeedNormal);
    BindCommand(NewBinding(btKeyClick, IK_F7), cmdSpeedHi);
{$ENDIF}
    
//    BindCommand(NewBinding(btKeyDown, IK_MOUSEMIDDLE), cmdMinimize);
  end;

  MouseInGUI := False;

  if not Controller.SystemCursor then begin
    AX := GetViewportCenter(vpcX);
    AY := GetViewportCenter(vpcY);
    Controller.MouseX := AX;
    Controller.MouseY := AY;
    ScreenToClient(Controller.Handle, Controller.MouseX, Controller.MouseY);

  //  ClientToScreen(Controller.Handle, AX, AY);
    Controller.SetMouseAnchor(AX, AY);
  end;  
end;

function TCastApp.GraphicsRestart: Boolean;
// (W, 16, 32)
const
  ModesToTry: array[0..2] of record
    Mode, Depth: Integer;
  end = ( (Mode: vmWindowed; Depth: 0),
          (Mode: vmDefaultFullScreen; Depth: 0),
          (Mode: vmDefaultFullScreen; Depth: 1) );
var ModeIndex: Integer; s1, s2: string;
begin
  Result := False;

  ModeIndex := 0;

  if not SetVideoMode(Cfg['VideoMode'].OptionIndex, Cfg['ColorDepth'].OptionIndex, Starter.Finished) then begin
    s1 := VideoModeVariants[Cfg['VideoMode'].OptionIndex];
    if Cfg['VideoMode'].OptionIndex <> 0 then s1 := s1 + ' '+ColorDepthVariants[Cfg['ColorDepth'].OptionIndex];
    s2 := VideoModeVariants[ModesToTry[ModeIndex].Mode];
    if ModesToTry[ModeIndex].Mode <> 0 then s2 := s2 + ' '+ColorDepthVariants[ModesToTry[ModeIndex].Depth];
    Starter.PrintError(PChar('Can''t start ' + s1 + ' render mode'#13#10 +
                     'Trying to start ' + s2 + ' mode...'), etWarning);
    while (ModeIndex < 3) and not SetVideoMode(ModesToTry[ModeIndex].Mode, ModesToTry[ModeIndex].Depth, Starter.Finished) do begin
      s1 := s2;
      s2 := VideoModeVariants[ModesToTry[(ModeIndex+1) MOD 3].Mode];
      if ModesToTry[(ModeIndex+1) MOD 3].Mode <> 0 then s2 := s2 + ' '+ColorDepthVariants[ModesToTry[(ModeIndex+1) MOD 3].Depth];

      Starter.PrintError(PChar('Can''t start ' + s1 + ' render mode'#13#10 +
                       'Trying to start ' + s2 + ' mode...'), etWarning);
      Inc(ModeIndex);
    end;
  end;

  Result := ModeIndex < 3;
end;

function TCastApp.SetVideoMode(Mode, Depth: Integer;  StartUp: Boolean): Boolean;
begin
  Result := False;

  Cfg.SetOptionIndex('VideoMode', Mode);
  Cfg.SetOptionIndex('ColorDepth', Depth);
  Cfg.SetOptionIndex('ZBufferDepth', 0);

  case Cfg['VideoMode'].OptionIndex of
    vmWindowed..vm1280: begin
      World.Renderer.FullScreenWidth := VideoModeWidth[Cfg['VideoMode'].OptionIndex];
      World.Renderer.FullScreenHeight := VideoModeHeight[Cfg['VideoMode'].OptionIndex]
    end;
  end;

  World.Renderer.FullScreenColorDepth := BitDepth[Cfg['ColorDepth'].OptionIndex];

  World.Renderer.FFullScreen := Cfg['VideoMode'].OptionIndex <> vmWindowed;

  if StartUp then begin
    Result := World.FRenderer.CreateViewport(RenderWindowHandle, World.Renderer.FullScreenWidth, World.Renderer.FullScreenHeight,
                                                                 World.Renderer.FullScreenColorDepth, World.Renderer.FFullScreen,
                                                                 BitDepth[Cfg['ZBufferDepth'].OptionIndex], True) <> cvError;
  end else Result := World.FRenderer.RestoreViewport <> cvError;

  if Result then begin
    LastVideoMode := Cfg['VideoMode'].OptionIndex;
    LastColorDepth := Cfg['ColorDepth'].OptionIndex;
    if World.Renderer.FullScreen then LastFSVideoMode := LastVideoMode;
  end;

end;

function TCastApp.GetViewportCenter(Coord: Integer): Integer;
var Rect: TRect;
begin
  Result := 0;
  if not Assigned(World) or not Assigned(World.Renderer) then Exit;
  if World.Renderer.FullScreen then begin
    if Coord = vpcX then
     Result := World.Renderer.RenderPars.ActualWidth div 2 else
      Result := World.Renderer.RenderPars.ActualHeight div 2;
  end else begin
    GetWindowRect(World.Renderer.RenderWindowHandle, Rect);
    if Coord = vpcX then
     Result := (Rect.Left + Rect.Right) div 2 else
      Result := (Rect.Top + Rect.Bottom) div 2;
  end;
end;

procedure TCastApp.ShowItem(const ItemName: string);
var Item: TItem;
begin
  Item := World.GetItemByName(ItemName, True);
  if Item <> nil then Item.Show;
end;

procedure TCastApp.ToggleItem(const ItemName: string; Parent: TItem = nil);
var Item: TItem;
begin
  if Parent = nil then
   Item := World.GetItemByName(ItemName, True) else
    Item := Parent.GetChildByName(ItemName, True);
  if Item <> nil then if Item.Status and isVisible > 0 then Item.Hide else Item.Show;
end;

procedure TCastApp.HideItem(const ItemName: string);
var Item: TItem;
begin
  Item := World.GetItemByName(ItemName, True);
  if Item <> nil then Item.Hide;
end;

function TCastApp.ProcessMessage(Msg: Longword; wParam, lParam: Integer): Integer;
begin
  Starter.CallDefaultMsgHandler := True;

  if not Starter.Finished then begin
    if Assigned(World) and Assigned(World.FRenderer) then World.HandleCommand(MessageToCommand(Msg, wParam, lParam));
    if Assigned(Controller) then Controller.HandleCommand(MessageToCommand(Msg, wParam, lParam));
  end;

  case Msg of
    WM_SYSCOMMAND: if wParam and $FFF0 = SC_KEYMENU then Starter.CallDefaultMsgHandler := False;
    WM_ACTIVATEAPP: begin
//      if World.Renderer.FullScreen then begin
      if wParam = 0 then begin
        if Assigned(Controller) then begin
          EndCameraMode(cmRotate);
          MoveMode := False; RotateMode := False; ZoomMode := False;
        end;
      end else if Assigned(Controller) then begin
        EndCameraMode(cmRotate);
        MoveMode := False; RotateMode := False; ZoomMode := False;
      end;
//      end;
      if Assigned(Controller) then Controller.ProcessInput(nil, efNone);
    end;
//    WM_ERASEBKGND, WM_PAINT: Result := 1;//DefWindowProc(WHandle, Msg, WParam, LParam);
    WM_SIZE{, WM_CANCELMODE}: begin
      if (wParam = SIZE_RESTORED) or (wParam = SIZE_MAXIMIZED) then begin
//        if Assigned(Controller) then if Controller.MouseAnchored then Controller.SetMouseAnchor(GetViewportCenter(vpcX), GetViewportCenter(vpcY));
      end;
      if (wParam = SIZE_MINIMIZED) then World.Messages.Add(cmdPause, []);
    end;
    else ;
//    WM_Restore: World.Renderer.FullScreen := False;
  end;

  Result := inherited ProcessMessage(Msg, wParam, lParam);
end;

procedure TCastApp.WorldProcess;
var MoveSign: Single;
begin
  if AWSDCameraControlMode = ccMoveZoom then begin
    MoveCamera((Byte(DPressed)-Byte(APressed)) * AWSDCameraSens, 0);
    Camera.Range := MinS(MaxCameraRange, MaxS(MinCameraRange, Camera.Range + (Byte(SPressed)-Byte(WPressed)) * AWSDCameraSens * 0.005));
    RotateCamera((Byte(ZPressed)-Byte(CPressed))*10, (Byte(QPressed)-Byte(EPressed))*10);
  end else if AWSDCameraControlMode = ccXMoveZoom then begin
    if Cos(Cam.YAngle) > 0 then MoveSign := AWSDCameraSens else MoveSign := -AWSDCameraSens;
    Camera.LookAtX := Camera.LookAtX + (Byte(DPressed)-Byte(APressed)) * MoveSign * 128;
    Camera.Range := MinS(MaxCameraRange, MaxS(MinCameraRange, Camera.Range + (Byte(SPressed)-Byte(WPressed)) * AWSDCameraSens * 0.005));
    RotateCamera((Byte(ZPressed)-Byte(CPressed))*10, (Byte(QPressed)-Byte(EPressed))*10);
  end else if AWSDCameraControlMode = ccMove then
   MoveCamera((Byte(DPressed)-Byte(APressed)) * AWSDCameraSens, (Byte(WPressed)-Byte(SPressed)) * AWSDCameraSens) else
    if AWSDCameraControlMode = ccRotate then
     RotateCamera((Byte(WPressed)-Byte(SPressed))*10, (Byte(APressed)-Byte(DPressed))*10);
  ProcessCamera;
end;

procedure TCastApp.Process;
var
  TotalCommands: Integer;
{$IFDEF PROFILE}
  WPPerfCounter, MsgPerfCounter, RenderPerfCounter, InputPerfCounter: Int64;
{$ENDIF}
begin
{$IFDEF NETSUPPORT}
  EnterCriticalSection(Net.NetCriticalSection);
{$ENDIF}
  inherited;
{$IFDEF NETSUPPORT}
  LeaveCriticalSection(Net.NetCriticalSection);
{$ENDIF}

  if not Starter.Finished and Assigned(World) then begin
{$IFDEF PROFILE}
    WPPerfCounter := GetPerformanceCounter;
{$ENDIF}
    World.Process;
{$IFDEF PROFILE}
    TimeCounters[tcWorldProcess] := TimeCounters[tcWorldProcess] + GetPerformanceCounter - WPPerfCounter;

    MsgPerfCounter := GetPerformanceCounter;
{$ENDIF}
    ProcessMessages(World.Messages);
{$IFDEF PROFILE}
    TimeCounters[tcMessages] := TimeCounters[tcMessages] + GetPerformanceCounter - MsgPerfCounter;

    RenderPerfCounter := GetPerformanceCounter;
{$ENDIF}
    World.FRenderer.SetCamera(Cam);
    if Assigned(World.FRenderer) then World.FRenderer.Render;
{$IFDEF PROFILE}
    TimeCounters[tcRender] := TimeCounters[tcRender] + GetPerformanceCounter - RenderPerfCounter;

    InputPerfCounter := GetPerformanceCounter;
{$ENDIF}
//    if not (Starter is TScreenSaverStarter) or not (Starter as TScreenSaverStarter).PreviewMode then
    ProcessInput;
{$IFDEF PROFILE}
    TimeCounters[tcInput] := TimeCounters[tcInput] + GetPerformanceCounter - InputPerfCounter;
{$ENDIF}

    CommandQueue.Clear;

//    CommandQueue.Remove(0, TotalCommands);
  end;
end;

procedure TCastApp.MoveCamera(X, Y: Single);
begin
  Camera.LookAtX := Camera.LookAtX - X*128 * Cos(Camera.YAngle) + Y*128 * Sin(Camera.YAngle);
  Camera.LookAtZ := Camera.LookAtZ + Y*128 * Cos(Camera.YAngle) + X*128 * Sin(Camera.YAngle);
end;

procedure TCastApp.RotateCamera(XA, YA: Single);
begin
  Camera.YAngle := Camera.YAngle + YA / 180 * pi / 4;
  Camera.XAngle := Camera.XAngle - XA / 180 * pi / 4;
  if Camera.XAngle > CameraMaxXAngle then Camera.XAngle := CameraMaxXAngle;
  if Camera.XAngle < CameraMinXAngle then Camera.XAngle := CameraMinXAngle;
end;

function TCastApp.ViewToCamera(ViewCamera: TViewCamera): TCamera;
begin
  Result.X := ViewCamera.LookAtX - Exp(ViewCamera.Range)*Sin(ViewCamera.YAngle)*Cos(ViewCamera.XAngle);
  Result.Y := ViewCamera.LookAtY - Exp(ViewCamera.Range)*Sin(ViewCamera.XAngle);
  Result.Z := ViewCamera.LookAtZ - Exp(ViewCamera.Range)*Cos(ViewCamera.YAngle)*Cos(ViewCamera.XAngle);
  Result.XAngle := ViewCamera.XAngle;
  Result.YAngle := ViewCamera.YAngle;
  Result.ZAngle := ViewCamera.ZAngle;
  Result.FieldOfView := World.Renderer.RenderPars.FoV;
end;

function TCastApp.CameraToView(Camera: TCamera; Range: Single): TViewCamera;
begin
  Result.LookAtX := Camera.X + Exp(Range)*Sin(Camera.YAngle)*Cos(Camera.XAngle);
  Result.LookAtY := Camera.Y + Exp(Range)*Sin(Camera.XAngle);
  Result.LookAtZ := Camera.Z + Exp(Range)*Cos(Camera.YAngle)*Cos(Camera.XAngle);
  Result.XAngle := Camera.XAngle;
  Result.YAngle := Camera.YAngle;
  Result.ZAngle := Camera.ZAngle;
  Result.Range := Range;
end;

procedure TCastApp.ChangeCamera(NewCamera: TCamera);
begin
  OldCam := Cam; Cam := NewCamera;
//  NormalizeAngle(OldCam.XAngle); NormalizeAngle(OldCam.YAngle); NormalizeAngle(OldCam.ZAngle);
//  NormalizeAngle(Cam.XAngle); NormalizeAngle(Cam.YAngle); NormalizeAngle(Cam.ZAngle);
  while Abs(OldCam.YAngle - Cam.YAngle) > (pi + 1/60) do OldCam.YAngle := OldCam.YAngle - Sign(OldCam.YAngle - Cam.YAngle)*2*pi;

  CamK := 0; CamKIncr := 0.03;
  CameraBlend := True; 
  ProcessCamera;
end;

procedure TCastApp.ShockCamera(ShockTime: Integer; ShockAmplitude: Single);
begin
  CameraShockTimer := ShockTime;
  CameraShockTime := ShockTime;
  CameraShockAmplitude := MaxS(ShockAmplitude, CameraShockAmplitude);   
  CameraShock := ShockTime <> 0;
end;

procedure TCastApp.StopCamera;
begin
  CamK := 1;
  Camera := CameraToView(Cam, Camera.Range);
end;

function TCastApp.GetCustomCamera: TCamera;
begin
  Result := ViewToCamera(Camera);
  if CameraBlend then begin
    Result.X := Result.X * CamK + OldCam.X * (1-CamK);
    Result.Y := Result.Y * CamK + OldCam.Y * (1-CamK);
    Result.Z := Result.Z * CamK + OldCam.Z * (1-CamK);
    Result.XAngle := Result.XAngle * CamK + OldCam.XAngle * (1-CamK);
    Result.YAngle := Result.YAngle * CamK + OldCam.YAngle * (1-CamK);
    Result.ZAngle := Result.ZAngle * CamK + OldCam.ZAngle * (1-CamK);
  end;
  if CameraShock then begin
//    Result.Y := Result.Y + Sin(CameraShockTick*CameraShockFreq/180*pi)*Sin(CameraShockTimer/CameraShockTime*pi/2) * CameraShockAmplitude;
    Result.X := Result.X + Sin(CameraShockTimer/CameraShockTime*pi/2) * CameraShockAmplitude * (Random*2-1);
    Result.Y := Result.Y + Sin(CameraShockTimer/CameraShockTime*pi/2) * CameraShockAmplitude * (Random*2-1);
    Result.Z := Result.Z + Sin(CameraShockTimer/CameraShockTime*pi/2) * CameraShockAmplitude * (Random*2-1);
  end;
end;

procedure TCastApp.ProcessCamera;
begin
  Cam := GetCustomCamera;
  if CameraBlend then begin
    if CamK < 1-CamKIncr then CamK := CamK + CamKIncr else CamK := 1;
    if MoveMode then StopCamera;
  end;
  if CameraShock then begin
    if CameraShockTimer > 0 then begin
      Dec(CameraShockTimer);
    end else begin
      CameraShock := False;
      CameraShockAmplitude := 0;
    end;
  end;
end;

procedure TCastApp.PollInput;
begin
  if CatchAllInput then begin
    Controller.ProcessInput(CommandQueue, efAll);
    Controller.InputEventsToCommands(CommandQueue);
  end else Controller.ProcessInput(CommandQueue, efBond);
end;

procedure TCastApp.ProcessInput;
var i, MX, MY: Integer; Temp: Single;
begin
  if not World.FRenderer.RenderActive then Exit;

  if not SkipInputPoll then PollInput;

  i := 0;
  while i < CommandQueue.TotalCommands do with CommandQueue.Commands[i] do begin
    case CommandID of   // Game commands
      cmdToggleFullscreen: begin
        if World.FRenderer.FullScreen then begin
          LastFSVideoMode := Cfg['VideoMode'].OptionIndex;
          LastColorDepth := Cfg['ColorDepth'].OptionIndex;
          Cfg.SetOptionIndex('VideoMode', 0);
          World.FRenderer.FullScreen := False;
        end else begin
          Cfg.SetOptionIndex('VideoMode', LastFSVideoMode);
          Cfg.SetOptionIndex('ColorDepth', LastColorDepth);
          World.FRenderer.FullScreen := True;
        end;

//        MoveMode := False; RotateMode := False; ZoomMode := False;
        Controller.ProcessInput(nil, efNone);
//        if Assigned(Controller) then if Controller.MouseAnchored then Controller.SetMouseAnchor(GetViewportCenter(vpcX), GetViewportCenter(vpcY));
        World.HandleCommand(NewCommand(cmdResized, [World.Renderer.RenderPars.ActualWidth, World.Renderer.RenderPars.ActualHeight]));
      end;
      cmdMinimize: ShowWindow(Starter.WindowHandle, SW_MINIMIZE);
      cmdMoveDown: StartCameraMode(cmMove);
      cmdMoveUp: EndCameraMode(cmMove);
      cmdRotateDown: StartCameraMode(cmRotate);
      cmdRotateUp: EndCameraMode(cmRotate);
      cmdZoomDown: StartCameraMode(cmZoom);
      cmdZoomUp: EndCameraMode(cmZoom);
      cmdMRotateDown: if not MouseInGUI and (ForceMouseCameraControl or (Cfg['MouseCameraControl'].OptionIndex = 1)) then StartCameraMode(cmRotate);
      cmdMZoomDown: if not MouseInGUI and (ForceMouseCameraControl or (Cfg['MouseCameraControl'].OptionIndex = 1)) then StartCameraMode(cmZoom);
      cmdMouseMove: {if not MouseInGUI then }begin
        if MoveMode then MoveCamera(SmallInt(Arg1 and $FFFF), SmallInt(Arg1 div $10000)) else
         if RotateMode then RotateCamera(SmallInt(Arg1 div $10000), SmallInt(Arg1 and $FFFF)) else
          if ZoomMode then Camera.Range := MinS(MaxCameraRange, MaxS(MinCameraRange, Camera.Range + SmallInt(Arg1 div $FFFF) * 0.005));
      end;
      cmdMouseRoll: Camera.Range := MinS(MaxCameraRange, MaxS(MinCameraRange, Camera.Range - SmallInt(Arg1) * 0.0015));
{$IFDEF DEBUGMODE}
      cmdSpeedLo: begin
        World.CurrentTimeQuantum := 90;
      end;
      cmdSpeedNormal: begin
        World.CurrentTimeQuantum := 30;
      end;
      cmdSpeedHi: begin
        World.CurrentTimeQuantum := 4;
      end;
{$ENDIF}
      cmdADown: if not SkipCameraControl then APressed := True;
      cmdWDown: if not SkipCameraControl then WPressed := True;
      cmdSDown: if not SkipCameraControl then SPressed := True;
      cmdDDown: if not SkipCameraControl then DPressed := True;
      cmdQDown: if not SkipCameraControl then QPressed := True;
      cmdEDown: if not SkipCameraControl then EPressed := True;
      cmdZDown: if not SkipCameraControl then ZPressed := True;
      cmdCDown: if not SkipCameraControl then CPressed := True;
    end;
    Inc(i);
  end;

  SkipInputPoll := False;
  SkipCameraControl := False;
end;

destructor TCastApp.Free;
var Renderer: TRenderer;
begin
{$IFDEF NETSUPPORT} if Net <> nil then Net.Free; Net := nil; {$ENDIF}
  if World <> nil then begin
    Renderer := World.Renderer;
    World.Free; World := nil;
    if Renderer <> nil then Renderer.Shutdown; Renderer := nil;
  end;
  if Controller <> nil then Controller.Free; Controller := nil;
  if CommandQueue <> nil then CommandQueue.Free; CommandQueue := nil;
  inherited;
end;

procedure TCastApp.ResetConfig;
begin
  inherited;
  ResetGameConfig;
  ResetPlayerConfig;
  ResetVideoConfig;
  ResetAudioConfig;
{$IFDEF NETSUPPORT}
  ResetNetworkConfig;
  Cfg.AddExt('InternetGame', '[  ]', CheckBoxVariants);
{$ENDIF}
end;

procedure TCastApp.ResetGameConfig;
begin
  Cfg.AddExt('FirstStart', 'Yes', YesNoVariants);
end;

procedure TCastApp.ResetPlayerConfig;
begin
  Cfg.Add('PlayerNameEdit', 'Player');
  Cfg.Add('MouseSensitivity', '8');
  Cfg.AddExt('MouseCameraControl', 'No', YesNoVariants);
  Cfg.AddExt('Hints', 'Yes', YesNoVariants);
end;

procedure TCastApp.ResetVideoConfig;
begin
  Cfg.AddExt('VideoMode', 'Windowed', VideoModeVariants);
  Cfg.SetOptionIndex('VideoMode', vmDefault);
  Cfg.AddExt('ColorDepth', '32 bit', ColordepthVariants);
  Cfg.SetOptionIndex('ColorDepth', bppDefault);
  Cfg.AddExt('ZBufferDepth', '16 bit', ColordepthVariants);
  Cfg.AddExt('Detail', 'High', DetailVariants);
  Cfg.AddExt('Specular', 'Quality', SpecularVariants);
end;

procedure TCastApp.ResetAudioConfig;
begin
  Cfg.Add('SoundVolume', '100');
  Cfg.Add('MusicVolume', '50');
end;

{$IFDEF NETSUPPORT}
procedure TCastApp.ResetNetworkMode;
var i, TCPIPVariant: Integer;
begin
  TCPIPVariant := -1;
  for i := 0 to Length(NetModeVariants)-1 do if Pos('TCP/IP', NetModeVariants[i]) > 0 then TCPIPVariant := i;
  Cfg.AddExt('NetworkMode', '', NetModeVariants);
  if TCPIPVariant <> -1 then Cfg.SetOptionIndex('NetworkMode', TCPIPVariant);
end;

procedure TCastApp.ResetNetworkConfig;
begin
  ResetNetworkMode;
  Cfg.AddExt('NetBaudRate', '56000', BaudVariants);
  Cfg.AddExt('NetFlowControl', 'RTSDTR', FlowControlVariants);
  Cfg.AddExt('NetParity', 'NONE', ParityVariants);
  Cfg.AddExt('NetStopBits', '1', StopBitsVariants);
  Cfg.AddExt('NetInvokeOptions', 'No', YesNoVariants);
  if Net <> nil then Cfg.Add('NetPort', IntToStr(Net.DataPort)) else Cfg.Add('NetPort', '');
  Cfg.Add('NetConnectTo', '');
end;
{$ENDIF}

procedure TCastApp.ProcessMessages(Messages: TCommandQueue);
begin
  Messages.Clear;
end;

{$IFDEF NETSUPPORT}
procedure TCastApp.ProcessNetMessages(Messages: TCommandQueue);
begin
  Messages.Clear; 
end;
{$ENDIF}

procedure TCastApp.GotoURL(const URLFileName: string);
begin
  if Assigned(World) then begin
//    World.PauseMode := True;
//    if Assigned(World.Renderer) then World.Renderer.FullScreen := False;
    if Assigned(World.Renderer) and World.Renderer.FullScreen then ShowWindow(World.Renderer.RenderWindowHandle, SW_MINIMIZE);
  end;
  inherited;
end;

procedure TCastApp.StartCameraMode(Mode: Cardinal);
begin
  case Mode of
    cmMove: if not MoveMode then MoveMode := True else Exit;
    cmRotate: if not RotateMode then RotateMode := True else Exit;
    cmZoom: if not ZoomMode then ZoomMode := True else Exit;
  end;
{$IFDEF DEBUGMODE} 
  Log('** Anchor set by StartCameraMode');
 {$ENDIF}
  Controller.SetMouseAnchor(GetViewportCenter(vpcX), GetViewportCenter(vpcY));
end;

procedure TCastApp.EndCameraMode(Mode: Cardinal);
begin
  case Mode of
    cmMove: if MoveMode then MoveMode := False else Exit;
    cmRotate: if RotateMode then RotateMode := False else Exit;
    cmZoom: if ZoomMode then ZoomMode := False else Exit;
  end;
{$IFDEF DEBUGMODE}   
  Log('** Anchor reset by EndCameraMode');
 {$ENDIF}
  Controller.SetMouseAnchor(-1, -1);
end;

function TCastApp.isInCameraControlMode: Boolean;
begin
  Result := MoveMode or RotateMode or ZoomMode;
end;

end.
