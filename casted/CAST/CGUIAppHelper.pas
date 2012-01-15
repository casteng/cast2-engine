{$Include CDefines}
{$Include GDefines}
unit CGUIAppHelper;

interface

uses
   Logger, 
  Basics, BaseCont, CGUI, CAdvGUI, CAST, AppsInit, CAppHelper;

const
// GUI commands
  cmdFPSToggle = CAppCmdBase + 201;
  cmdHelpToggle = CAppCmdBase + 202;
{$IFDEF NETSUPPORT}
  cmdChatToggle = CAppCmdBase + 203;
{$ENDIF}
{$IFDEF DEBUGMODE}
  cmdDebugToggle = CAppCmdBase + 205;
{$ENDIF}
  cmdMenuToggle = CAppCmdBase + 410; cmdMenuBack = CAppCmdBase + 411; cmdMenuOn = CAppCmdBase + 412;
// GUI states
//  Main
  gsNone = 0; gsMainMenu = 1; gsOptions = 2; gsHighScores = 3; gsInfo = 4;
//  Options
  gsGameOptions = 5; gsPlayerOptions = 6; gsVideoOptions = 7; gsAudioOptions = 8;
  gsReg = 9;
  gsNag = 10;
  gsBigNag = 11;
{$IFDEF NETSUPPORT}
  gsNetGame = 12; gsCreateGame = 13; gsJoinGame = 14; gsNetworkOptions = 15;
  OutMsgColorPrefix = '^<CFFFFFFFF>';
  InMsgColorPrefix  = '^<CFFFF0000>';
{$ENDIF}
  MaxHelpPages = 4;
// Hints
  shNone = 0; shAll = 1;  

type
  TGUICastApp = class(TCastApp)
{ Handles basic GUI in a CAST application
  GUI structure:
  MainMenu
    New game
    Resume
    Options
      Game
      Player    (PlayerName, MouseSensitivity, MouseCameraControl)
      Video     (VideoMode, ColorDepth, ZBufferDepth, Detail, Specular)
      Audio     (SoundVolume, MusicVolume)
      Network   (NetworkMode, NetBaudRate, NetFlowControl, NetParity, NetStopBits, NetInvokeOptions, NetPort, NetConnectTo)
    High scores
    Info
    Quit
}
    GUI: TGUI;
    GUIState: Integer;
    MenuItemName: string;
    ForceFinish, MouseLeftDownInGUI: Boolean;
//    MouseX, MouseY: Integer;

    constructor Create(AProgramName: string; AStarter: TAppStarter; WorldClass: CWorld); override;
    procedure InitControls; override;

    procedure HideAllGUIItems; virtual;
    procedure EnableGUIItem(const ItemName: string); virtual;
    procedure DisableGUIItem(const ItemName: string); virtual;
    procedure SetGUIItemColor(const ItemName: string; Color: Longword); virtual;
    procedure SetGUIItemText(const ItemName, Text: string); virtual;
    function GetGUIItemText(const ItemName: string): string; virtual;

    procedure GUIToConfig(ItemName: string; ConfigIndex: Integer); virtual;
    procedure ConfigToGUI(ItemName: string; ConfigIndex: Integer); virtual;

    procedure OptionsToForm; virtual;
    procedure FormToOptions; virtual;

    procedure ApplyOptions; virtual;
    procedure ApplyInGameOptions; virtual;
{$IFDEF NETSUPPORT}
    procedure ApplyNetOptions; virtual;
    procedure ResetNetworkMode; override;
{$ENDIF}

    procedure HandleGUIClick(const Item: TGUIItem); virtual;
    procedure HandleGUICommand(const Command: TCommand); virtual;

    function SetGUIState(NewState: Integer): Integer; virtual;
    procedure RequestGUIState(const NewState: Integer); virtual;
    function MenuLevelUp: Integer; virtual;

{$IFDEF NETSUPPORT}
    procedure ProcessNetMessages(Messages: TCommandQueue); override;
{$ENDIF}
    procedure WorldProcess; override;
    procedure Process; override;
    procedure ProcessInput; override;
  protected
    LastNagMs, NextNagMs, GUIStateBeforeNag: Cardinal;
{$IFDEF NETSUPPORT}
    procedure RefreshHosts; virtual;
{$ENDIF}
    procedure HideAllStatusLabels;
{$IFDEF SHAREWARE}
    procedure RefreshRegInfo; virtual;
{$ENDIF}
  end;

implementation

uses SysUtils, Types, Windows,
     AppsHelper,
     CTypes, CInput,
{$IFDEF NETSUPPORT} CNet, {$ENDIF}
     CGUIFrames
{$IFDEF SHAREWARE} , RS {$ENDIF};

{ TGUICastApp }

procedure TGUICastApp.HideAllStatusLabels;
begin
  HideItem('NotConnectedStatus');
  HideItem('ConnectedStatus');
  HideItem('ErrorStatus');
  HideItem('FindingHostsStatus');
  HideItem('HostReadyStatus');
end;

constructor TGUICastApp.Create(AProgramName: string; AStarter: TAppStarter; WorldClass: CWorld);
{$IFDEF NETSUPPORT} var NetModeCFG: string; {$ENDIF}
begin
  inherited;

  if Starter.Finished then Exit;                           // Error occured

  Starter.Finished := True;

  World.AddItemClass(TGUI);
  World.AddItemClass(TGUICursor);
  World.AddItemClass(TGUIItem);
  World.AddItemClass(TGUIPoint);
  World.AddItemClass(TGUILine);
  World.AddItemClass(TPanel);
  World.AddItemClass(TLabel);
  World.AddItemClass(TButton);
  World.AddItemClass(TSwitchButton);
  World.AddItemClass(TSwitchLabel);
  World.AddItemClass(TSlider);
  World.AddItemClass(TEditor);
  World.AddItemClass(TList);
  World.AddItemClass(TTable);
  World.AddItemClass(TFrame);
  World.AddItemClass(TFramedButton);

  if not InitEngine then Exit;

  SetLength(SpecularVariants, 3);
  SetLength(DetailVariants, 2);
  SpecularVariants[slNone] := 'None'; SpecularVariants[slFast] := 'Fast'; SpecularVariants[slQuality] := 'Quality';
  DetailVariants[lodLow] := 'Low'; DetailVariants[lodHigh] := 'High';

  GUI := World.GetItemByName('GUI', True) as TGUI;
  GUI.Init(Controller, CommandQueue);
{$IFDEF NETSUPPORT}
  NetModeCFG := CFG['NetworkMode'].Value;                              // Save config value for NetworkMode
  ResetNetworkMode;                                                    // Reset it to TCP/IP
  if NetModeCFG <> '' then CFG.SetValue('NetworkMode', NetModeCFG);    // Set it again to configured if any
  ApplyNetOptions;
  EnableGUIItem('NetGameBut');
{$ENDIF}

  MenuItemName := 'MainMenu';

{$IFDEF PORTALBUILD} {$IFDEF SHAREWARE}
  HideItem('LicNameEdit');
  HideItem('LicNameLabel');
  KeyCfg.SetValue('LicenseName', UpperCase(PortalUsername));
{$ENDIF} {$ENDIF}

  NextNagMs := $FFFFFFFF;

  Starter.Finished := False;
end;

procedure TGUICastApp.InitControls;
begin
  inherited;
  with Controller do begin
// Standard GUI bindings
    BindCommand(NewBinding(btKeyClick, IK_ESCAPE)   , cmdKeyESC);
    BindCommand(NewBinding(btKeyClick, IK_RETURN)   , cmdKeyENTER);
    BindCommand(NewBinding(btKeyClick, IK_SPACE)    , cmdKeySpace);
    BindCommand(NewBinding(btKeyClick, IK_BACKSPACE), cmdKeyBackspace);
    BindCommand(NewBinding(btKeyClick, IK_DELETE)   , cmdKeyDelete);
    BindCommand(NewBinding(btKeyDown,  IK_MOUSELEFT), cmdLeftMouseDown);
    BindCommand(NewBinding(btKeyUp,    IK_MOUSELEFT), cmdLeftMouseUp);
    BindCommand(NewBinding(btKeyClick, IK_MOUSELEFT), cmdLeftMouseClick);

    BindCommand(NewBinding(btKeyClick, IK_F1), cmdHelpToggle);
    BindCommand(NewBinding(btKeyClick, IK_F2), cmdFPSToggle);
{$IFDEF NETSUPPORT}
    BindCommand(NewBinding(btKeyClick, IK_F5), cmdChatToggle);
{$ENDIF}
{$IFDEF DEBUGMODE}
    BindCommand(NewBinding(btKeyClick, IK_F11), cmdDebugToggle);
{$ENDIF}
    BindCommand(NewBinding(btKeyClick, IK_PAUSE), cmdMenuToggle);
    BindCommand(NewBinding(btKeyClick, IK_MOUSELEFT, NewBinding(btKeyClick, IK_MOUSELEFT, nil)), cmdMenuOn, DblClickTimeout);

    BindCommand(NewBinding(btKeyClick, IK_MOUSERIGHT), cmdMenuBack, 0, NewBinding(btMouseMove, 0));

    BindCommand(NewBinding(btKeyDown, IK_LCONTROL, NewBinding(btKeyClick, IK_V)), cmdClipBoardPaste, 0, NewBinding(btKeyUp, IK_LCONTROL));
    BindCommand(NewBinding(btKeyDown, IK_LSHIFT, NewBinding(btKeyClick, IK_INSERT)), cmdClipBoardPaste, 0, NewBinding(btKeyUp, IK_LSHIFT));
    BindCommand(NewBinding(btKeyDown, IK_RSHIFT, NewBinding(btKeyClick, IK_INSERT)), cmdClipBoardPaste, 0, NewBinding(btKeyUp, IK_RSHIFT));
    BindCommand(NewBinding(btKeyDown, IK_LSHIFT, NewBinding(btKeyClick, IK_NUMPAD0)), cmdClipBoardPaste, 0, NewBinding(btKeyUp, IK_LSHIFT));
    BindCommand(NewBinding(btKeyDown, IK_RSHIFT, NewBinding(btKeyClick, IK_NUMPAD0)), cmdClipBoardPaste, 0, NewBinding(btKeyUp, IK_RSHIFT));
  end;
  MouseLeftDownInGUI := False;
//  Controller.SetMouseAnchor(-1, -1);
end;

procedure TGUICastApp.HideAllGUIItems;
begin
  HideItem(MenuItemName);
  HideItem('Options');
  HideItem('GameOptions');
  HideItem('PlayerOptions');
  HideItem('VideoOptions');
  HideItem('AudioOptions');
{$IFDEF NETSUPPORT}
  HideItem('NetOptions');
  HideItem('NetGame');
  HideItem('NetCreateGame');
  HideItem('NetJoinGame');
{$ENDIF}
  HideItem('HighScores');
  HideItem('Info');
  HideItem('Help');
  HideItem('RegForm');
  HideItem('Nag');
end;

procedure TGUICastApp.EnableGUIItem(const ItemName: string);
var Item: TGUIItem;
begin
  Item := GUI.GetChildByName(ItemName, True) as TGUIItem;
  if Item <> nil then Item.Enable;
end;

procedure TGUICastApp.DisableGUIItem(const ItemName: string);
var Item: TGUIItem;
begin
  Item := GUI.GetChildByName(ItemName, True) as TGUIItem;
  if Item <> nil then Item.Disable;
end;

procedure TGUICastApp.SetGUIItemColor(const ItemName: string; Color: Longword);
var Item: TItem;
begin
  Item := GUI.GetChildByName(ItemName, True);
  if Item is TGUIItem then (Item as TGUIItem).CurrentColor := Color;
end;

procedure TGUICastApp.SetGUIItemText(const ItemName, Text: string);
var Item: TItem;
begin
  Item := GUI.GetChildByName(ItemName, True);
  if Item is TTextGUIItem then (Item as TTextGUIItem).Text := Text else
   if Item is TEditor then (Item as TEditor).Text := Text;
end;

function TGUICastApp.GetGUIItemText(const ItemName: string): string;
var Item: TItem;
begin
  Result := '';
  Item := GUI.GetChildByName(ItemName, True);
  if Item is TTextGUIItem then Result := (Item as TTextGUIItem).Text else
   if Item is TEditor then Result := (Item as TEditor).Text;
end;

procedure TGUICastApp.GUIToConfig(ItemName: string; ConfigIndex: Integer);
var Item: TItem;
begin
  Item := GUI.GetChildByName(ItemName, True);
  if Item = nil then Exit;
  if (Item is TSwitchLabel) then Cfg.SetOptionIndex(Cfg.OptionByIndex[ConfigIndex].Name, (Item as TSwitchLabel).VariantIndex) else
   if (Item is TSwitchButton) then Cfg.SetOptionIndex(Cfg.OptionByIndex[ConfigIndex].Name, (Item as TSwitchButton).VariantIndex) else
    if (Item is TSlider) then Cfg.SetValue(Cfg.OptionByIndex[ConfigIndex].Name, IntToStr((Item as TSlider).Value)) else
     if (Item is TLabel) then Cfg.SetValue(Cfg.OptionByIndex[ConfigIndex].Name, (Item as TLabel).Text) else
      if (Item is TEditor) then Cfg.SetValue(Cfg.OptionByIndex[ConfigIndex].Name, (Item as TEditor).Text);
end;

procedure TGUICastApp.ConfigToGUI(ItemName: string; ConfigIndex: Integer);
var Item: TItem;
begin
  Item := GUI.GetChildByName(ItemName, True);
  if Item = nil then Exit;
  if (Item is TSwitchLabel) then (Item as TSwitchLabel).VariantIndex := Cfg.OptionByIndex[ConfigIndex].OptionIndex else
   if (Item is TSwitchButton) then (Item as TSwitchButton).VariantIndex := Cfg.OptionByIndex[ConfigIndex].OptionIndex else
    if (Item is TSlider) then (Item as TSlider).Value := StrToIntDef(Cfg.OptionByIndex[ConfigIndex].Value, 100) else
     if (Item is TLabel) then (Item as TLabel).Text := Cfg.OptionByIndex[ConfigIndex].Value else
      if (Item is TEditor) then (Item as TEditor).Text := Cfg.OptionByIndex[ConfigIndex].Value;
end;

procedure TGUICastApp.OptionsToForm;
// GUI item names must be identical to corresponding config names
var i: Integer;
begin
  for i := 0 to Cfg.TotalOptions-1 do ConfigToGUI(Cfg.OptionByIndex[i].Name, i);
end;

procedure TGUICastApp.FormToOptions;
// GUI item names must be identical to corresponding config names
var i: Integer;
begin
  for i := 0 to Cfg.TotalOptions-1 do GUIToConfig(Cfg.OptionByIndex[i].Name, i);
end;

procedure TGUICastApp.ApplyOptions;
begin
  if (Cfg['VideoMode'].OptionIndex <> LastVideoMode) or ((Cfg['ColorDepth'].OptionIndex <> LastColorDepth) and
     (Cfg['VideoMode'].OptionIndex <> vmWindowed)) then SetVideoMode(Cfg['VideoMode'].OptionIndex, Cfg['ColorDepth'].OptionIndex, False);

  World.Renderer.SetSpecular(Cfg['Specular'].OptionIndex);

{$IFDEF AUDIO}  
  if Assigned(Audio) then begin
    Audio.DefaultVolume := StrToIntDef(Cfg['SoundVolume'].Value, 100)/100;
    Audio.Enabled := Audio.DefaultVolume <> 0;
{$IFDEF SCREENSAVER}
    if (Starter is TScreenSaverStarter) and (Starter as TScreenSaverStarter).PreviewMode then Audio.Enabled := False;
{$ENDIF}
  end;
{$ENDIF}    

  if (World.Renderer <> nil) and (World.Renderer.State = rsOK) then World.Renderer.State := rsClean;
end;

procedure TGUICastApp.ApplyInGameOptions;
begin

end;

{$IFDEF NETSUPPORT}
procedure TGUICastApp.ApplyNetOptions;
begin
  Net.InvokeStdDialog := Cfg['NetInvokeOptions'].OptionIndex = 1;

  if Net.DataPort <> Longword(StrToIntDef(Cfg['NetPort'].Value, 0)) then begin
    Net.DataPort := StrToIntDef(Cfg['NetPort'].Value, 0);
    Net.ReInit;
  end;

  Net.SetServiceProvider(Cfg['NetworkMode'].OptionIndex);
end;

procedure TGUICastApp.ResetNetworkMode;
var i: Integer; Item: TSwitchLabel; s: string;
begin
  inherited;
  if GUI <> nil then Item := GUI.GetChildByName('NetworkMode', True) as TSwitchLabel else Item := nil;
  if Item <> nil then begin
    s := '';
    for i := 0 to Length(NetModeVariants)-1 do begin
      if i > 0 then s := s + '\&';
      s := s + NetModeVariants[i];
    end;
    Item.Text := s;
    Item.VariantIndex := Cfg['NetworkMode'].OptionIndex;
  end;
end;
{$ENDIF}

procedure TGUICastApp.HandleGUIClick(const Item: TGUIItem);
var i, j: Integer; {$IFDEF NETSUPPORT} HostList: TList; InternetGame: Boolean; {$ENDIF}
{$IFDEF SHAREWARE}
  hg: THandle; P: PChar; s: string;
{$ENDIF}
begin
// Main
  if Item.Name = 'MenuBut' then begin
    RequestGUIState(gsMainMenu);
  end;
  if Item.Name = 'MenuNewGame' then begin
    RequestGUIState(gsGameOptions);
  end;

  if Item.Name = 'NewGame' then begin
    RequestGUIState(gsNone);
//    StartGame;
    FormToOptions;
    ApplyOptions;
  end;

  if (Item.Name = 'MenuQuit') or (Item.Name = 'BigNagQuit') or (Item.Name = 'NagQuit') or (Item.Name = 'QuitBut') then begin
    if (GUIState <> gsBigNag) and isTrial then begin
      SetGUIState(gsBigNag); ForceFinish := True;
    end else Starter.Finished := True;
  end;
// Misc
  if (Item.Name = 'MenuResume') or (Item.Name = 'Return') or
     (Item.Name = 'HighScoresOK') or (Item.Name = 'InfoOK') then RequestGUIState(MenuLevelUp);
// Help & Info
  if (Item.Name = 'HelpOKBut') then HideItem('Help');
  if Item.Name = 'MenuInfo' then RequestGUIState(gsInfo);
  if (Item.Name = 'MenuHelp') or (Item.Name = 'HelpBut') then ToggleItem('Help');
  for i := 1 to MaxHelpPages do if Item.Name = 'HelpPage'+IntToStr(i)+'But' then begin
    for j := 1 to MaxHelpPages do if j=i then
     ShowItem('HelpPage'+IntToStr(j)) else
      HideItem('HelpPage'+IntToStr(j));
  end;
  if Item.Name = 'QuickHelp' then ToggleItem('HelpPanel', Item);
  if Item.Name = 'QuickHelpOK' then if Item.Parent.Name = 'HelpPanel' then Item.Parent.Hide;
// High scores
  if Item.Name = 'MenuHighScores' then RequestGUIState(gsHighScores);
  if Item.Name = 'HighScoreOK' then RequestGUIState(MenuLevelUp);
{$IFDEF NETSUPPORT}
// Multiplayer
  if (Item.Name = 'MenuNetGame') or (Item.Name = 'Multiplayer') then begin
    FormToOptions;
    RequestGUIState(gsNetGame);
  end;
  if (Item.Name = 'MenuNetCreate') then RequestGUIState(gsCreateGame);
  if (Item.Name = 'MenuNetJoin') then RequestGUIState(gsJoinGame);
  if (Item.Name = 'HostCreate') or (Item.Name = 'LANCreate') or (Item.Name = 'InternetCreate') then begin
    FormToOptions;
    InternetGame := (GUI.GetChildByName('InternetGame', True) as TSwitchLabel).VariantIndex <> 0;
    if Net.CreateHost(GameHostName, not InternetGame, True) then begin
      HideAllStatusLabels;
      ShowItem('HostReadyStatus');
      DisableGUIItem('JoinBut');
      (GUI.GetChildByName('GameStatus', True) as TSwitchLabel).VariantIndex := 1 + Ord(InternetGame);
      EnableGUIItem('DisconnectBut');
      EnableGUIItem('ChatButton');
    end else begin
      HideAllStatusLabels;
      ShowItem('ErrorStatus');
      EnableGUIItem('JoinBut');
    end;
  end;
  if (Item.Name = 'HostSearch') or (Item.Name = 'LANSearch') then begin
    FormToOptions;
    InternetGame := (GUI.GetChildByName('InternetGame', True) as TSwitchLabel).VariantIndex <> 0;
    HostList := GUI.GetChildByName('HostList', True) as TList;
    if HostList <> nil then HostList.Clear;
    Net.FindHosts(not InternetGame);
    HideAllStatusLabels;
    ShowItem('FindingHostsStatus');
  end;
  if (Item.Name = 'JoinBut') or (Item.Name = 'ConnectHost') then begin
    HostList := GUI.GetChildByName('HostList', True) as TList;
    Net.Connect(HostList.Position);
    HostList.Clear;
    if not Net.Connected and not Net.Connecting then begin
      HideAllStatusLabels;
      ShowItem('ErrorStatus');
    end else DisableGUIItem('JoinBut');
  end;
  if (Item.Name = 'DisconnectBut') then begin
    if Net.NetworkRole = nrClient then
     Net.SendCommand(Net.HostPlayerID, NewCommand(cmdClientDisconnectRequest, [Net.CurrentPlayerID]), True) else
      EnableGUIItem('JoinBut');
    if Net.NetworkRole = nrHost then if Net.Disconnect then World.Messages.Add(cmdHostTerminated, []);
{    if Net.Disconnect then begin
      HideAllStatusLabels;
      ShowItem('NotConnectedStatus');
      DisableGUIItem('DisconnectBut');
      HideAllGameModeLabels;
      ShowItem('SingleGameStatus');
    end else begin
      HideAllStatusLabels;
      ShowItem('ErrorStatus');
    end;}
  end;
  if (Item.Name = 'MenuNetOptions') then RequestGUIState(gsNetworkOptions);
  if (Item.Name = 'NetOptionsOK') then begin
    RequestGUIState(MenuLevelUp);
    FormToOptions;
    ApplyNetOptions;
  end;
// Chat
  if Item.Name = 'ChatButton' then ShowItem('Chat');
  if Item.Name = 'ChatCloseBut' then HideItem('Chat');
{$ENDIF}
{$IFDEF SHAREWARE}
//Nag & Reg
  if Item.Name = 'NagEnterKeyBut' then begin
    OpenClipboard(0);
    hg := GetClipboardData(CF_TEXT);
    CloseClipboard;
    P := GlobalLock(hg);
    s := Copy(P, 0, Length(P));
    GlobalUnlock(hg);
    if ExtractLicense(s) then begin
{$IFNDEF PORTALBUILD}
      SetGUIItemText('LicNameEdit', KeyCfg['LicenseName'].Value);
{$ENDIF}
      SetGUIItemText('LicCodeEdit', s);
    end;
    RefreshRegInfo;
  end;
  if Item.Name = 'NagOKBut' then begin
{$IFNDEF PORTALBUILD}
    KeyCfg.SetValue('LicenseName', UpperCase(GetGUIItemText('LicNameEdit')));
{$ENDIF}
    KeyCfg.SetValue('LicenseCodeHash', CtoH(SToC(UpperCase(GetGUIItemText('LicCodeEdit'))), RandomChain));
    RefreshRegInfo;
  end;
  if (Item.Name = 'NagLaterBut') or (Item.Name = 'BigNagLaterBut') then RequestGUIState(MenuLevelUp);
  if (Item.Name = 'NagBuyBut') then GotoURL('Buy');
  if (Item.Name = 'BigNagBuyBut') then begin
    GotoURL('Buy');
    Starter.Finished := True;
  end;
  if Item.Name = 'TrialBut' then RequestGUIState(gsNag);
{$ENDIF}
// Options
  if Item.Name = 'MenuOptions' then SetGUIState(gsOptions);
  if Item.Name = 'MenuGameOptions' then RequestGUIState(gsGameOptions);
  if Item.Name = 'MenuPlayerOptions' then RequestGUIState(gsPlayerOptions);
  if Item.Name = 'MenuVideoOptions' then RequestGUIState(gsVideoOptions);
  if Item.Name = 'MenuAudioOptions' then RequestGUIState(gsAudioOptions);
  if (Item.Name = 'VideoOptionsOK') or (Item.Name = 'PlayerOptionsOK') or (Item.Name = 'AudioOptionsOK') then begin
    RequestGUIState(MenuLevelUp);
    FormToOptions;
    ApplyOptions;
  end;
  if Item.Name = 'VideoOptionsReset' then begin
    ResetVideoConfig;
    ApplyInGameOptions;
    OptionsToForm;
  end;
  if Item.Name = 'PlayerOptionsReset' then begin
    ResetPlayerConfig;
    ApplyInGameOptions;
    OptionsToForm;
  end;
{$IFDEF NETSUPPORT}
  if Item.Name = 'NetOptionsReset' then begin
    ResetNetworkConfig;
    ApplyNetOptions;
    OptionsToForm;
  end;
{$ENDIF}
end;

procedure TGUICastApp.HandleGUICommand(const Command: TCommand);
var HostList: TList;
begin
  case Command.CommandID of
    cmdGUIClick: if Command.PTR1 <> nil then HandleGUIClick(TGUIItem(Command.PTR1));
    cmdGUIChange: if TItem(Command.PTR1).Name = 'HostList' then begin
      HostList := GUI.GetChildByName('HostList', True) as TList;
      if HostList.Position >= 0 then EnableGUIItem('JoinBut') else DisableGUIItem('JoinBut');
    end;
  end;
end;

function TGUICastApp.SetGUIState(NewState: Integer): Integer;
begin
{$IFDEF SHAREWARE}
  if (GUIState = gsNag) and (NewState <> gsNag) then begin
    LastNagMs := CurrentMs;
    NextNagMs := LastNagMs + NagIntervalMs;
  end;
{$ENDIF}
  HideAllGUIItems;

  World.PauseMode := True;

  if GUI.FocusedControl <> nil then GUI.FocusedControl.SetFocus(False);

  case NewState of
    gsNone: World.PauseMode := False;//
    gsMainMenu: begin
      ShowItem(MenuItemName);
    end;
    gsOptions: ShowItem('Options');
    gsHighScores: begin
      ShowItem('HighScores');
    end;
    gsInfo: begin
      ShowItem('Info');
    end;
    gsGameOptions: begin
      ShowItem('GameOptions');
      OptionsToForm;
    end;
    gsPlayerOptions: begin
      ShowItem('PlayerOptions');
      OptionsToForm;
    end;
    gsVideoOptions: begin
      ShowItem('VideoOptions');
      OptionsToForm;
    end;
    gsAudioOptions: begin
      ShowItem('AudioOptions');
      OptionsToForm;
    end;
    gsReg: ShowItem('RegForm');
    gsNag: begin
      ShowItem('Nag');
      if GUIState <> gsNag then GUIStateBeforeNag := GUIState;
    end;
    gsBigNag: ShowItem('BigNag');
{$IFDEF NETSUPPORT}
    gsNetGame: begin
      ShowItem('NetGame');
    end;
    gsNetworkOptions: begin
      ShowItem('NetOptions');
      OptionsToForm;
    end;
    gsCreateGame: ShowItem('NetCreateGame');
    gsJoinGame: begin
      ShowItem('NetJoinGame');
//      HostsList.Clear;
//      Net.FindHosts;
    end;
{$ENDIF}
  end;
  GUIState := NewState;
  Result := NewState;
end;

procedure TGUICastApp.RequestGUIState(const NewState: Integer);
begin
  SetGUIState(NewState);
end;

function TGUICastApp.MenuLevelUp: Integer;
begin
  case GUIState of
    gsMainMenu: Result := gsNone;
    gsGameOptions, gsPlayerOptions, gsVideoOptions, gsAudioOptions: Result := gsOptions;
{$IFDEF NETSUPPORT}
    gsNetworkOptions: Result := gsOptions;
    gsCreateGame, gsJoinGame: Result := gsNetGame;
{$ENDIF}
    gsNag: Result := GUIStateBeforeNag;
    else Result := gsMainMenu;
  end;
end;

procedure TGUICastApp.WorldProcess;
begin
  inherited;
  if CFG.Changed then OptionsToForm;
  CFG.Changed := False;
end;

procedure TGUICastApp.Process;
begin
  inherited;
  if (GUIState <> gsNag) and (GUIState <> gsBigNag) and (GUIState <> gsReg) then begin
{$IFDEF SHAREWARE}
    if isTrial and (NextNagMs <> $FFFFFFFF) and (CurrentMs > NextNagMs) then SetGUIState(gsNag);
{$ENDIF}
    if ForceFinish then Starter.Finished := True;
  end;  
end;

procedure TGUICastApp.ProcessInput;

{procedure GetMousePos(var MX, MY: Integer);
var MouseXY: TPoint;
begin
  GetCursorPos(MouseXY);
  if not World.Renderer.FullScreen then ScreenToClient(World.Renderer.RenderWindowHandle, MouseXY);
  MX := MouseXY.X;
  MY := MouseXY.Y;
end;}

var i: Integer;

begin
  if not World.FRenderer.RenderActive then Exit;

  PollInput;

  if GUI = nil then Exit;

//  GetMousePos(MouseX, MouseY);
  MouseInGUI := GUI.ProcessInput(Controller.MouseX, Controller.MouseY);
  SkipCameraControl := MouseInGUI or (GUI.FocusedControl <> nil);

//  if GUI.FocusedControl <> nil then Exit;

  i := 0;
  while i < CommandQueue.TotalCommands do with CommandQueue.Commands[i] do begin
    case CommandID of   // Game commands
      cmdLeftMouseDown: if MouseInGUI then MouseLeftDownInGUI := True;
      cmdLeftMouseUp: MouseLeftDownInGUI := False;
      cmdGUIFirst..cmdGUILast: HandleGUICommand(CommandQueue.Commands[i]);
      cmdMenuBack: if (GUI.FocusedControl = nil) and (GUIState <> gsNone) then RequestGUIState(MenuLevelUp);
      cmdMenuToggle, cmdKeyESC: if (GUI.FocusedControl = nil) then RequestGUIState(MenuLevelUp);
      cmdMenuOn: if (GUI.FocusedControl = nil) and (GUIState = gsNone) and not MouseInGUI then RequestGUIState(gsMainMenu);
      cmdHelpToggle: ToggleItem('Help');
{      if (GUIState = gsNone) or (GUIState = gsMainMenu) then
       RequestGUIState(gsHelp) else if GUIState = gsHelp then
        RequestGUIState(StateBeforeHelp);}
      cmdFPSToggle: begin
        ToggleItem('FpsLabel');
{$IFDEF PROFILE}
        ToggleItem('ProfileLabel');
{$ENDIF}
      end;
{$IFDEF NETSUPPORT}
      cmdChatToggle: if Net.NetworkRole <> nrNone then ToggleItem('Chat');
{$ENDIF}
{$IFDEF DEBUGMODE}
      cmdDebugToggle: ToggleItem('DebugLabel');
{$ENDIF}
    end;
    Inc(i);
  end;

  SkipInputPoll := True;
  inherited;
end;

{$IFDEF NETSUPPORT}
procedure TGUICastApp.ProcessNetMessages(Messages: TCommandQueue);
var i: Integer; ChatPlayerList: TItem; InternetGame: Boolean; 
begin
  for i := 0 to Messages.TotalCommands-1 do case Messages.Commands[i].CommandID of
    cmdHostFound: RefreshHosts;
    cmdHostSearchEnd: begin
      HideAllStatusLabels;
      if Net.Connected then ShowItem('ConnectedStatus') else ShowItem('NotConnectedStatus');
      RefreshHosts;
    end;
    cmdPlayerConnected, cmdPlayerDisconnected: SetGUIItemText('TotalPlayersValue', IntToStr(Net.TotalPlayers));
    cmdConnected: begin
      HideAllStatusLabels;
      ShowItem('ConnectedStatus');
      InternetGame := (GUI.GetChildByName('InternetGame', True) as TSwitchLabel).VariantIndex <> 0;
      (GUI.GetChildByName('GameStatus', True) as TSwitchLabel).VariantIndex := 1 + Ord(InternetGame);
      EnableGUIItem('DisconnectBut');
      EnableGUIItem('ChatButton');
{$IFDEF AUDIO}
      if Audio <> nil then Audio.PlaySound(Audio.SoundByName('Connect'));
{$ENDIF}
    end;
    cmdDisconnected, cmdHostTerminated: begin
      HideAllStatusLabels;
      ShowItem('NotConnectedStatus');
      DisableGUIItem('DisconnectBut');
      (GUI.GetChildByName('GameStatus', True) as TSwitchLabel).VariantIndex := 0;
      EnableGUIItem('JoinBut');
      DisableGUIItem('ChatButton');
      HideItem('Chat');
      ChatPlayerList := GUI.GetChildByName('ChatPlayerList', True);
      if ChatPlayerList <> nil then (ChatPlayerList as TList).Clear;
    end;
    cmdNetworkReply: begin
      SetGUIItemText('NetworkReply', Net.GetStoredString(Messages.Commands[i].Arg1));
    end;
  end;
  inherited;
end;

procedure TGUICastApp.RefreshHosts;
var i, OldPosition: Integer; HostList: TItem;
begin
  HostList := GUI.GetChildByName('HostList', True);
  if HostList is TList then with HostList as TList do begin
    OldPosition := Position;
    Clear;
    for i := 0 to Net.TotalHostsFound-1 do Add(Format('(%.4D)', [Net.HostsFound[i].Latency]) + ' ' + Net.HostsFound[i].AppDesc.pwszSessionName);
    SetPosition(OldPosition);
  end;
  SetGUIItemText('HostsFoundValue', IntToStr(Net.TotalHostsFound));
end;
{$ENDIF}

{$IFDEF SHAREWARE}
procedure TGUICastApp.RefreshRegInfo;
begin
  if isTrial then begin
    HideItem('NagRegistered');
    HideItem('NagRegisteredName');
    HideItem('Registered');
    HideItem('RegisteredName');
    ShowItem('NagNotFound');
    ShowItem('TrialBut');
  end else begin
    SetGUIItemText('NagRegisteredName', KeyCFG['LicenseName'].Value);
    ShowItem('NagRegistered');
    SetGUIItemText('RegisteredName', KeyCFG['LicenseName'].Value);
    ShowItem('NagRegisteredName');
    ShowItem('Registered');
    ShowItem('RegisteredName');
    HideItem('NagNotFound');
    HideItem('TrialBut');
  end;
end;
{$ENDIF}

end.
