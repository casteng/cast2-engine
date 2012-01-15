(*
 @Abstract(CAST II Engine applications helper unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains a class which performs some usual tasks like menu system etc
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2AppHelper;

interface

uses
  SysUtils,
  Logger,
  AppsInit, AppHelper,  
  BaseTypes, Basics, BaseMsg, Props,
  BaseClasses, Resources, BaseGraph,
  C2Render,
  CAST2, C2Core, C2Visual, C2VisItems, C2Materials, C22D, C2Particle, C2Affectors,
  {$IFDEF DIRECT3D8} C2DX8Render, {$ENDIF} {$IFDEF OpenGL} COGLRender, {$ENDIF}
  {$IFDEF AUDIO} C2Audio, {$ENDIF}
  {$IFDEF USE_DI} DInput {$ELSE} WInput {$ENDIF},
  {$IFDEF NETSUPPORT} C2Net, {$ENDIF}
  C2Res;

const
  // User profile file extension
  ProfileFileExtension = '.pfl';
  // Key binding prefix on config
  KeyBindPrefix = 'Key_';
  // AWSD camera control modes
//  ccNone = 0; ccMove = 1; ccRotate = 2; ccMoveZoom = 3; ccXMoveZoom = 4;

type
  // Camera modes
  TCameraMode = (// Move camera with mouse
                 cmMove,
                 // Rotate camera with mouse
                 cmRotate,
                 // zoom camera with mouse
                 cmZoom);

  // This message is generated when full screen mode switched on or off
  TFullScreenToggleMsg = class(BaseMSg.TSystemMessage)
  end;

  // This message is generated when main menu switched on or off
  TMenuToggleMsg = class(BaseMSg.TSystemMessage)
  end;

  // This message is generated when help screen switched on or off
  THelpToggleMsg = class(BaseMSg.TSystemMessage)
  end;

  { @Abstract(Base class for applications which uses CAST II engine)
  }
  TCast2App = class(TApp)
  private
    function MatchVideoMode(const VM: TVideoMode; const Str: string): Boolean;
    procedure ActionActivateCallback(BindData: Integer; CustomData: SmallInt);
    procedure ActionDeactivateCallback(BindData: Integer; CustomData: SmallInt);
  protected
//    procedure StartCameraMode(Mode: TCameraMode); virtual;
//    procedure EndCameraMode(Mode: TCameraMode); virtual;
    // Binds default controls for some standard actions
    procedure BindStandardControls; virtual;
    // Applies controls
    procedure ApplyControls; virtual;

    // Enumerate video modes
    procedure EnumModes;
    // Enumerate video modes and users
    procedure EnumAll;
    // Returns profile file name by a user name
    function UserNameToFileName(const UserName: string): string;
  public
    // CAST II core reference
    Core: C2Core.TCore;
    {$IFDEF AUDIO}
    // Audio manager reference
    Audio: TAudioManager;
    {$ENDIF}
    {$IFDEF NETSUPPORT}
    // Network manager reference
    Net: TNet;
    // Host name for game server
    GameHostName: string;
    {$ENDIF}

    constructor Create(const AProgramName: string; AStarter: TAppStarter); override;
    destructor Destroy; override;

    // Creates engine core of the specified class and registers standard item classes
    procedure CreateCore(CoreClass: C2Core.CCore); virtual;
    // Loads a scene from the specified file and returns <b>True</b> if success
    function LoadScene(const FileName: string): Boolean;
    { Binds an action or message to the specified in <b>AActivateBinding</b> input event or a sequence of events.
      If <b>Msg</b> is not <b>nil</b> the message will be generated when the specified in <b>AActivateBinding</b> set of input events will occur.
      Otherwise an action named <b>AName</b> will be activated when input will match <b>AActivateBinding</b> and deactivated when input will match <b>ADeactivateBinding</b>. }
    procedure BindAction(Msg: CMessage; const AName, AActivateBinding, ADeactivateBinding: string);
    // Delete the specified action
    procedure DeleteAction(const AName: string);
    // Logs on a user with the specified name and loads its profile
    procedure LogOn(UserName: string);
    // Saves current user's profile and logs off the user
    procedure LogOff;

    // Opens the specified URL in system default browser. If application is operating in full screen mode it's minimized.
    procedure GotoURL(const URLFileName: string);

    { Applies the specified option set. An option set is a grouped by category set of options.
      For example "VIDEOOPTIONS" set includes video mode options, gamma control options and so on. }
    procedure ApplyOptionSet(const OptionSet: string); virtual;
    // Applies all option sets
    procedure ApplyOptions; virtual;
    // Applies video option set ("VIDEOOPTIONS")
    function ApplyVideoOptions: Boolean; virtual;
    // Temporarily applies the specified value to the specified option for preview purposes
    procedure PreviewOptions(OptionName, Value: string); virtual;

    // Fills <b>X</b> and <b>Y</b> with X and Y of current viewport center
    procedure ObtainViewportCenter(out X, Y: Integer); virtual;

    // Messages handler. Handles full screen toggling, forced quit, etc
    procedure HandleMessage(const Msg: TMessage); virtual;

    // Performs OS message processing (calls <b>Starter.Process</b>) and engine core processing. Should be called in main application cycle.
    procedure Process; virtual;
  end;

implementation

uses Base3D, OSUtils;

const
  StrNoDX = 'DirectX 8 or greater is not installed!'#13#10'You can download it at http://www.microsoft.com/directx';
//  StrUIError = 'Initialization error. File corrupt or version mismatch.'#13#10'Reinstalling the application should fix this problem.';
//  ZeroGUID: TGUID = '{00000000-0000-0000-0000-000000000000}';

{ TCast2App }

function TCast2App.MatchVideoMode(const VM: TVideoMode; const Str: string): Boolean;
begin
  Result := (SysUtils.Format('%Dx%Dx%D', [VM.Width, VM.Height, GetBitsPerPixel(VM.Format)-1]) = Str) or          // For 15 and 16 bit modes compatibility
            (SysUtils.Format('%Dx%Dx%D', [VM.Width, VM.Height, GetBitsPerPixel(VM.Format)+1]) = Str) or
            (SysUtils.Format('%Dx%Dx%D', [VM.Width, VM.Height, GetBitsPerPixel(VM.Format)])   = Str);
end;

procedure TCast2App.ActionActivateCallback(BindData: Integer; CustomData: SmallInt);
begin
  FActions[CustomData].Active := True;
end;

procedure TCast2App.ActionDeactivateCallback(BindData: Integer; CustomData: SmallInt);
begin
  FActions[CustomData].Active := False;
end;

procedure TCast2App.EnumModes;
var CurVM, i: Integer; s: string;
begin
  if (Core = nil) or (Core.Renderer = nil) then Exit;
  CurVM := 0;
  s := '';
  for i := 0 to Core.Renderer.TotalVideoModes-1 do with Core.Renderer.VideoMode[i] do begin
    if i > 0 then s := s + StringDelimiter;
    s := s + SysUtils.Format('%Dx%Dx%D', [Width, Height, GetBitsPerPixel(Format)]);
    if MatchVideoMode(Core.Renderer.VideoMode[i], Config['VideoMode']) then CurVM := i;
  end;
  Config.AddEnumerated('VideoMode', [], CurVM, s);
end;

procedure TCast2App.EnumAll;

  procedure EnumUsers;
  var i, CurUser: Integer; s: string; SR: TSearchRec;

    procedure AddUser(const AName: string);
    begin
      if AName = '' then Exit;
      if s <> '' then s := s + StringDelimiter;
      s := s + AName;
      if AName = Config['UserName'] then CurUser := i;
      Inc(i);
    end;

  begin
    s := ''; i := 0; CurUser := -1;
    if FindFirst(Starter.ProgramWorkDir + '*' + ProfileFileExtension, faReadOnly or faHidden or faSysFile or faArchive, SR) = 0 then begin
      repeat AddUser(GetFileName(SR.Name)); until FindNext(SR) <> 0;
      SysUtils.FindClose(SR);
    end;
    if CurUser = -1 then AddUser(Config['UserName']);

    Config.AddEnumerated('UserName', [], CurUser, s);
  end;

begin
  EnumUsers;
  EnumModes;
end;

function TCast2App.UserNameToFileName(const UserName: string): string;
begin
  Result := Starter.ProgramWorkDir + UserName + ProfileFileExtension;
end;

(*procedure TCast2App.StartCameraMode(Mode: TCameraMode);
var CenterX, CenterY: Integer;
begin
  case Mode of
    cmMove: if not MoveMode then MoveMode := True else Exit;
    cmRotate: if not RotateMode then RotateMode := True else Exit;
    cmZoom: if not ZoomMode then ZoomMode := True else Exit;
  end;
  {$IFDEF DEBUGMODE}
  Log('** Anchor set by StartCameraMode');
  {$ENDIF}
  ObtainViewportCenter(CenterX, CenterY);
  Core.Input.SetMouseAnchor(CenterX, CenterY);
end;

procedure TCast2App.EndCameraMode(Mode: TCameraMode);
begin
  case Mode of
    cmMove: if MoveMode then MoveMode := False else Exit;
    cmRotate: if RotateMode then RotateMode := False else Exit;
    cmZoom: if ZoomMode then ZoomMode := False else Exit;
  end;
  {$IFDEF DEBUGMODE}
  Log('** Anchor reset by EndCameraMode');
  {$ENDIF}
  Core.Input.SetMouseAnchor(-1, -1);
end; *)

procedure TCast2App.BindStandardControls;
var i: Integer;
begin
  BindAction(TForceQuitMsg,  'Quit', 'Alt+Q', '');
  BindAction(TMenuToggleMsg, 'Menu', 'SPACE', '');
  BindAction(THelpToggleMsg, 'Help', 'F1', '');
  BindAction(TFullScreenToggleMsg, 'FullScreenToggle', 'Alt+Enter', '');

  BindAction(nil, 'Forward',  'W+', 'W-');
  BindAction(nil, 'Backward', 'S+', 'S-');
  BindAction(nil, 'Left',     'A+', 'A-');
  BindAction(nil, 'Right',    'D+', 'D-');
                         
  for i := 0 to High(FActions) do begin
    if FActions[i].Message <> nil then begin
      if Config[KeyBindPrefix + FActions[i].Name] = '' then
        Config.Add(KeyBindPrefix + FActions[i].Name, vtString, [], FActions[i].ActivateBinding, '', '');
    end else if Config[KeyBindPrefix + FActions[i].Name + OnOffStr[True]] = '' then begin
      Config.Add(KeyBindPrefix + FActions[i].Name + OnOffStr[True],  vtString, [], FActions[i].ActivateBinding,  '', '');
      Config.Add(KeyBindPrefix + FActions[i].Name + OnOffStr[False], vtString, [], FActions[i].DeactivateBinding, '', '');
    end;
  end;

  ApplyControls;
end;

procedure TCast2App.ApplyControls;
var i: Integer;
begin
  if not Assigned(Core) or not Assigned(Core.Input) then begin
     Log(ClassName + '.ApplyControls: Core or Core.Input is not assigned', lkError); 
    Exit;
  end;

  Core.Input.UnBindAll;
  for i := 0 to High(FActions) do begin
    if Config[KeyBindPrefix + FActions[i].Name] <> '' then
      BindAction(FActions[i].Message, FActions[i].Name, Config[KeyBindPrefix + FActions[i].Name], '');
    if Config[KeyBindPrefix + FActions[i].Name + OnOffStr[True]] <> '' then
      BindAction(FActions[i].Message, FActions[i].Name, Config[KeyBindPrefix + FActions[i].Name + OnOffStr[True]],
                                                        Config[KeyBindPrefix + FActions[i].Name + OnOffStr[False]]);
  end;

(*
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

    BindCommand(NewBinding(btKeyDown, IK_MOUSELEFT), cmdMZoomDown); Input.BindCommand(NewBinding(btKeyUp, IK_MOUSELEFT), cmdZoomUp);
    BindCommand(NewBinding(btKeyDown, IK_MOUSERIGHT), cmdMRotateDown); Input.BindCommand(NewBinding(btKeyUp, IK_MOUSERIGHT), cmdRotateUp);
{$ENDIF}
    BindCommand(NewBinding(btKeyDown, IK_LALT), cmdRotateDown); Input.BindCommand(NewBinding(btKeyUp, IK_LALT), cmdRotateUp);

    BindCommand(NewBinding(btKeyDown, IK_LSHIFT), cmdZoomDown); Input.BindCommand(NewBinding(btKeyUp, IK_LSHIFT), cmdZoomUp);
    BindCommand(NewBinding(btKeyDown, IK_MOUSEMIDDLE), cmdMoveDown); Input.BindCommand(NewBinding(btKeyUp, IK_MOUSEMIDDLE), cmdMoveUp);
    BindCommand(NewBinding(btKeyDown, IK_CONTROL), cmdMoveDown); Input.BindCommand(NewBinding(btKeyUp, IK_CONTROL), cmdMoveUp);
    BindCommand(NewBinding(btKeyDown, IK_LCONTROL), cmdMoveDown); Input.BindCommand(NewBinding(btKeyUp, IK_LCONTROL), cmdMoveUp);

    BindCommand(NewBinding(btMouseMove, 0), cmdMouseMove);
    BindCommand(NewBinding(btMouseRoll, 0), cmdMouseRoll);
{$ENDIF}

{$IFDEF DEBUGMODE}
    BindPointer(NewBinding(btKeyClick, IK_B), atBooleanToggle, @Core.DebugOut);
//    BindPointer(NewBinding(btKeyClick, IK_8), atSetLongWord, @World.Renderer.FillMode, fmSolid);
//    BindPointer(NewBinding(btKeyClick, IK_9), atSetLongWord, @World.Renderer.FillMode, fmWire);
//    BindPointer(NewBinding(btKeyClick, IK_0), atSetLongWord, @World.Renderer.FillMode, fmPoint);

    BindCommand(NewBinding(btKeyClick, IK_F5), cmdSpeedLo);
    BindCommand(NewBinding(btKeyClick, IK_F6), cmdSpeedNormal);
    BindCommand(NewBinding(btKeyClick, IK_F7), cmdSpeedHi);
{$ENDIF}

//    BindCommand(NewBinding(btKeyDown, IK_MOUSEMIDDLE), cmdMinimize);*)

//  MouseInGUI := False;

  Core.Input.MouseCapture := not Core.Input.SystemCursor;
end;

constructor TCast2App.Create(const AProgramName: string; AStarter: TAppStarter);

  {$IFDEF DIRECT3D8}  
  procedure SetDeviceType(const AName: string);
  var i: Integer; DTStrs: TStringArray;
  begin
    for i := 0 to Split(DeviceTypesEnum, StringDelimiter, DTStrs, False)-1 do
      if AName = DTStrs[i] then (Core.Renderer as TDX8Renderer).SetDeviceType(i);
    DTStrs := nil;

    EnumModes;
  end;
  {$ENDIF}

function SetAdapter(const AName: string): Boolean;
var i: Integer;
begin
  Result := True;
  if AName = '' then Exit;
  for i := 0 to Core.Renderer.TotalAdapters-1 do
    if AName = Core.Renderer.AdapterName[i] then begin
      Core.Renderer.SetVideoAdapter(i);
      Exit;
    end;
  Result := False;      
end;

{$IFDEF NETSUPPORT} var i, j: Integer; {$ENDIF}
begin
  inherited;
  if Starter.Terminated then Exit;                           // Error occured
  Starter.Terminated := True;

  LogOn(Config['UserName']);

  CreateCore(TCore);
  Core.MessageHandler := HandleMessage;
  Starter.MessageHandler := Core.HandleMessage;
// Render
  {$IFDEF OPENGL}
  Core.Renderer := TOGLRenderer.Initialize(World.ResourceManager, CommandQueue);
//  World.Renderer := TOGLDispListRenderer.Initialize(World.ResourceManager, CommandQueue  , Log );
  {$ELSE}
  Core.Renderer := TDX8Renderer.Create(Core);
  SetDeviceType(Config['DeviceType']);
  {$ENDIF}

  if not SetAdapter(Config['VideoAdapter']) then begin
     Log(ClassName + '.Create: Video adapter "' + Config['VideoAdapter'] + '" not found. Default video adapter used', lkError); 
  end;

  if Core.Renderer.State = rsNotInitialized then begin
     Log('Can''t start renderer', lkFatalError); 
    Starter.PrintError(StrNoDX, lkFatalError);
    Exit;
  end;
//
  {$IFDEF SCREENSAVER}
  CFG.SetOptionIndex('VideoMode', 0);
  {$ENDIF}

  {$IFNDEF ONLINEBUILD}
  if not ActivateWindow(Starter.WindowHandle) then begin
     Log('Failed to activate main window', lkWarning); 
  end;
  {$ENDIF}

  Core.Input := TOSController.Create(Starter.WindowHandle, Core.HandleMessage);
//  SkipInputPoll     := False;
//  SkipCameraControl := False;

  {$IFDEF AUDIO}
//  Audio := TDX8AudioManager.Initialize(Starter.WindowHandle, World.ResourceManager);
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

  if ApplyVideoOptions then Starter.Terminated := False;

//  Core.Renderer.MaxTextureWidth := 64;
//  Core.Renderer.MaxTextureHeight := 64;

  if not (Starter is TScreenSaverStarter) or not (Starter as TScreenSaverStarter).PreviewMode then BindStandardControls;

//  MouseSensitivity := 0.1;
end;

procedure TCast2App.CreateCore(CoreClass: CCore);
begin
  Core := CoreClass.Create;
  Core.RegisterItemClass(TItem);
  Core.RegisterItemClass(TDummyItem);
  Core.RegisterItemClass(TRootItem);
  Core.RegisterItemClass(TProcessing);
  Core.RegisterItemClass(TCamera);
  Core.RegisterItemClass(TLookAtCamera);
  Core.RegisterItemClass(TMaterial);
  Core.RegisterItemClass(TTechnique);
  Core.RegisterItemClass(TRenderPass);
  Core.RegisterItemClass(TLight);
// Resources
  Core.RegisterItemClass(TResource);
  Core.RegisterItemClass(TImageResource);
  Core.RegisterItemClass(TTextureResource);
  Core.RegisterItemClass(TVerticesResource);
  Core.RegisterItemClass(TIndicesResource);
  Core.RegisterItemClass(TUVMapResource);
  Core.RegisterItemClass(TCharMapResource);
  Core.RegisterItemClass(TAudioResource);
  Core.RegisterItemClass(TScriptResource);
// Visible
  Core.RegisterItemClass(TVisible);
  Core.RegisterItemClass(TMesh);
  Core.RegisterItemClass(C2VisItems.TPlane);
  Core.RegisterItemClass(TCircle);
  Core.RegisterItemClass(TDome);
  Core.RegisterItemClass(TSky);
// Particle
  Core.RegisterItemClass(TParticleSystem);
  Core.RegisterItemClass(T2DParticleSystem);
  Core.RegisterItemClass(T3DParticleSystem);
  Core.RegisterItemClass(TEmitter);
  Core.RegisterItemClass(TPSAbsorber);
  Core.RegisterItemClass(TPSMover);
  Core.RegisterItemClass(TPSAttractor);
  Core.RegisterItemClass(TPSColorInterpolator);
  Core.RegisterItemClass(TPSForce);
  Core.RegisterItemClass(TSphericalEmitter);
// 2D
  Core.RegisterItemClass(TFont);
  Core.RegisterItemClass(TBitmapFont);

  Core.CatchAllInput := True;
end;

function TCast2App.LoadScene(const FileName: string): Boolean;
var Stream: TFileStream;
begin
  Result := False;

  Stream := TFileStream.Create(Filename);

  if not Core.LoadScene(Stream) then begin
    
    Log(Self.ClassName + '.Create: Error loading file "' + FileName + '"', lkError);
    
    Stream.Free;
    Exit;
  end;
  
  Result := True;
end;

procedure TCast2App.BindAction(Msg: CMessage; const AName, AActivateBinding, ADeactivateBinding: string);
var Index: Integer;
begin
  Index := GetActionIndex(AName);

  if AActivateBinding = '' then begin                   // Delete binding
    Log(Format('%S.%S: Activation binding not specified for action "%S"', [ClassName, 'BindAction', AName]), lkWarning);
  end;

  if Index = -1 then begin
    Index := Length(FActions);
    SetLength(FActions, Index+1);
  end;
  FActions[Index].Name              := AName;
  FActions[Index].ActivateBinding   := AActivateBinding;
  FActions[Index].DeactivateBinding := ADeactivateBinding;
  FActions[Index].Message           := Msg;
  FActions[Index].Active            := False;

  if not Assigned(Core) or not Assigned(Core.Input) then begin
    Log(ClassName + '.BindAction: Core or Core.Input is not assigned', lkError);
    Exit;
  end;

  if Msg = nil then begin                               // No message to bind - using activated/deactivated semantics
    Core.Input.BindDelegate(AActivateBinding, ActionActivateCallback, Index);
    if ADeactivateBinding <> '' then
      Core.Input.BindDelegate(ADeactivateBinding, ActionDeactivateCallback, Index) else begin
        Log(ClassName + '.BindAction: Message to bind and deactivation binding both undefined for action "' + AName + '"', lkWarning);
      end;
  end else Core.Input.BindCommand(AActivateBinding, Msg);
end;

procedure TCast2App.DeleteAction(const AName: string);
var Index: Integer;
begin
  Index := GetActionIndex(AName);
  if Index = -1 then Exit;

  FActions[Index] := FActions[High(FActions)];
  SetLength(FActions, Length(FActions)-1);
end;

procedure TCast2App.LogOff;
begin
  if Config['UserName'] = '' then Exit;
   Log(ClassName + '.LogOff: User "' + Config['UserName'] + '"', lkNotice); 
  Config.SaveAs(UserNameToFileName(Config['UserName']));
  Config['UserName'] := '';
end;

procedure TCast2App.LogOn(UserName: string);
begin
  if UserName = '' then UserName := 'Player';
   Log(ClassName + '.LogOn: User "' + UserName + '"', lkNotice); 
  if not Config.LoadFrom(UserNameToFileName(UserName)) then begin
     Log(ClassName + '.LogOn: User profile file "' + UserNameToFileName(UserName) + '"not found', lkWarning); 
  end;
  Config['UserName'] := UserName;
  EnumAll;
  ApplyOptions;
end;

procedure TCast2App.ApplyOptionSet(const OptionSet: string);
begin
  if OptionSet = 'VIDEOOPTIONS' then ApplyVideoOptions else
    if OptionSet = 'PLAYERLIST' then begin
      LogOn(Config['UserName']);
    end;
end;

procedure TCast2App.ApplyOptions;
begin
  ApplyControls;
  ApplyVideoOptions;
end;

function TCast2App.ApplyVideoOptions: Boolean;
var i: Integer; CurVideoMode: Cardinal; ModifyViewport: Boolean;
begin
  Result := True;
  if (Core = nil) or (Core.Renderer = nil) then Exit;

  Exclude(Core.Renderer.AppRequirements.Flags, arForceVSync);
  Exclude(Core.Renderer.AppRequirements.Flags, arForceNoVSync);
  if Config['VSync'] = OnOffStr[True] then
    Include(Core.Renderer.AppRequirements.Flags, arForceVSync) else
      if Config['VSync'] = OnOffStr[False] then
        Include(Core.Renderer.AppRequirements.Flags, arForceNoVSync);          

  CurVideoMode := 0;
  for i := 0 to Core.Renderer.TotalVideoModes-1 do if MatchVideoMode(Core.Renderer.VideoMode[i], Config['VideoMode']) then begin
    CurVideoMode := i;
    Break;
  end;
// Skip viewport restoring if nothing was changed
  ModifyViewport := (Core.Renderer.State = rsNotReady) or
                    (Core.Renderer.FullScreen <> (Config.GetAsInteger('Windowed') = 0)) or
                    (Core.Renderer.FullScreen and (Core.Renderer.CurrentVideoMode <> CurVideoMode));

//                    (not Core.Renderer.FullScreen and (Config.GetAsInteger('Windowed') > 0) or
//                         Core.Renderer.FullScreen and (Config.GetAsInteger('Windowed') = 0) and (Core.Renderer.CurrentVideoMode = CurVideoMode));

  if Core.Renderer.State = rsNotReady then begin
    Result := Core.Renderer.CreateDevice(Starter.WindowHandle, CurVideoMode, Config.GetAsInteger('Windowed') = 0);
  end else if ModifyViewport then
    Result := Core.Renderer.RestoreDevice(CurVideoMode, Config.GetAsInteger('Windowed') = 0);

  if not Result then begin
    Starter.PrintError(PChar('Can''t start renderer...'), lkError);
    Exit;
  end;

  Core.HandleMessage(TWindowResizeMsg.Create(0, 0, Core.Renderer.RenderWidth, Core.Renderer.RenderHeight));

  Core.Renderer.SetGamma(StrToIntDef(Config['Gamma'], 50)/50, StrToIntDef(Config['Contrast'], 50)/50, StrToIntDef(Config['Brightness'], 50)/50);

  Result := True;
end;

procedure TCast2App.PreviewOptions(OptionName, Value: string);
var Gamma, Contrast, Brightness: Single;
begin
// Video
  if OptionName = 'GAMMA'      then Gamma      := StrToIntDef(Value, 50)/50 else Gamma      := StrToIntDef(Config['Gamma'],      50)/50;
  if OptionName = 'CONTRAST'   then Contrast   := StrToIntDef(Value, 50)/50 else Contrast   := StrToIntDef(Config['Contrast'],   50)/50;
  if OptionName = 'BRIGHTNESS' then Brightness := StrToIntDef(Value, 50)/50 else Brightness := StrToIntDef(Config['Brightness'], 50)/50;
  Core.Renderer.SetGamma(Gamma, Contrast, Brightness);
// User profiles  
  if OptionName = 'USERNAME'   then LogOff;
end;

procedure TCast2App.ObtainViewportCenter(out X, Y: Integer);
var Rect: TRect;
begin
  if not Assigned(Core) or not Assigned(Core.Renderer) then Exit;
  if Core.Renderer.FullScreen then begin
    X := Core.Renderer.RenderWidth div 2;
    Y := Core.Renderer.RenderHeight div 2;
  end else begin
    GetWindowRect(Starter.WindowHandle, Rect);
    X := (Rect.Left + Rect.Right) div 2;
    Y := (Rect.Top + Rect.Bottom) div 2;
  end;
end;

procedure TCast2App.HandleMessage(const Msg: TMessage);
const SC_KEYMENU = 61696;
begin
  if Msg = nil then Exit;

  Starter.CallDefaultMsgHandler := True;

  if not Starter.Terminated then begin
//    if Assigned(Core) then Core.HandleMessage(Msg);
  end;
// -- OS Messages
  if Msg.ClassType = TWindowMenuCommand then begin
    with TWindowMenuCommand(Msg) do if Command and $FFF0 = SC_KEYMENU then Starter.CallDefaultMsgHandler := False;
  end else if (Msg.ClassType = TWindowActivateMsg) or (Msg.ClassType = TWindowDeactivateMsg) then begin
//    Core.Paused := Msg.ClassType = TWindowActivateMsg;
    if Assigned(Core.Input) then begin
//      EndCameraMode(cmRotate);
//      MoveMode := False; RotateMode := False; ZoomMode := False;
    end;
    if Assigned(Core.Input) then Core.Input.ProcessInput([]);
  end else if Msg.ClassType = TWindowResizeMsg then begin
//    if Assigned(Input) then if Input.MouseAnchored then Input.SetMouseAnchor(GetViewportCenter(vpcX), GetViewportCenter(vpcY));
  end else if Msg.ClassType = TWindowMinimizeMsg then begin
//    Core.Paused := True;
  end else
// -- System messages
  if Msg is TForceQuitMsg then
    Starter.Terminated := True else
  if Msg.ClassType = TOptionsApplyMsg then with TOptionsApplyMsg(Msg) do begin
    ApplyOptionSet(OptionSet);
  end else if (Msg.ClassType = TOptionsPreviewMsg) or (Msg.ClassType = TOptionsApplyNotifyMsg) then begin
    with TOptionsPreviewMsg(Msg) do PreviewOptions(OptionName, Value);
  end else
// -- Miscellaneous messages
  if Msg.ClassType = TFullScreenToggleMsg then begin
    if Config.GetAsInteger('Windowed') > 0 then
      Config.Add('Windowed', vtBoolean, [], OnOffStr[False], '', '') else
        Config.Add('Windowed', vtBoolean, [], OnOffStr[True], '', '');
    Core.Renderer.FullScreen := Config.GetAsInteger('Windowed') = 0;
  end;
end;

procedure TCast2App.Process;
//var LRMove, FBMove: Single; 
begin
  Starter.Process;
  if not Starter.Terminated and Assigned(Core) then begin
    Core.Process;
{    LRMove := (- Ord(Action['Left'])     + Ord(Action['Right'])   ) * MouseSensitivity;
    FBMove := (- Ord(Action['Backward']) + Ord(Action['Forward']) ) * MouseSensitivity;

    with Core.Renderer.MainCamera do begin
      if Abs(LRMove) + Abs(FBMove) > epsilon then
        Position := AddVector3s(Location.XYZ, AddVector3s(ScaleVector3s(RightVector, LRMove), ScaleVector3s(ForwardVector, FBMove)));
    end;}
  end;
end;

destructor TCast2App.Destroy;
var Subsys: TSubsystem;
begin
  Config.Save;
  LogOff;
{$IFDEF NETSUPPORT} if Net <> nil then Net.Free; Net := nil; {$ENDIF}
  Subsys := Core.Renderer;
  Core.Renderer := nil;
  if Assigned(Subsys) then Subsys.Free;

  Subsys := Core.Input;
  Core.Input := nil;
  if Assigned(Subsys) then Subsys.Free;

  if Core <> nil then Core.Free; Core := nil;

  inherited;
end;

procedure TCast2App.GotoURL(const URLFileName: string);
begin
  if Assigned(Core) then begin
    if Assigned(Core.Renderer) and Core.Renderer.FullScreen then OSUtils.MinimizeWindow(Starter.WindowHandle);
  end;
  OSUtils.OpenURL(URLFileName);
  inherited;
end;

end.
