// CAST engine network module.
// Changes IsMultiThread variable !!!
{$Include GDefines}
{$Include CDefines}
unit CNet;

interface

uses  Logger,  Basics, BaseCont, CTypes,
  {$IFDEF WANSUPPORT} WinSock, {$ENDIF}
  DirectPlay8, Windows, SysUtils, OSUtils;

const
// Network role
  nrNone = 0; nrServer = 1; nrHost = 2; nrClient = 3; nrHostCreation = 4;
// Commands
  cmdHostFound = cmdNetBase + 0;                        // Arg1 - index of host found
  cmdPlayerConnected = cmdNetBase + 1;                  // Arg1 - player ID
  cmdPlayerDisconnected = cmdNetBase + 2;               // Arg1 - player ID, Arg2 - reason
  cmdMessageReceived = cmdNetBase + 3;                  // Arg1 - index of last received message
  cmdConnected = cmdNetBase + 4;                        // Arg1 - 0 if was already connected
  cmdDisconnected = cmdNetBase + 5;
  cmdHostSearchEnd = cmdNetBase + 6;                    // Arg1 - total number of hosts found
  cmdHostQuery = cmdNetBase + 7;
  cmdRequestPlayerID = cmdNetBase + 8;                  // Arg1 - ID of player to report
  cmdReportPlayerID = cmdNetBase + 9;                   // Arg1 - Player ID
  cmdNetworkReply = cmdNetBase + 10;                    // Arg1 - string's ID in TempData container
  cmdHostReady = cmdNetBase + 11;                       
  cmdHostTerminated = cmdNetBase + 12;                  //
  cmdClientDisconnectRequest = cmdNetBase + 13;         // Arg1 - Client's player ID
  cmdLobbyScanEnd = cmdNetBase + 20;                    // Arg1 - Number of games found
// Baud rates
  br9600 = 0; br14400 = 1; br19200 = 2; br38400 = 3; br56000 = 4; br57600 = 5; br115200 = 6;
// Flow control values
  fcNone = 0; fcXOnXOff = 1; fcRTS = 2; fcDTR = 3; fcRTSDTR = 4;
// Parity values
  pNone = 0; pEven = 1; pOdd = 2; pMark = 3; pSpace = 4;
// Stop bits
  sbOne = 0; sbOneFive = 1; sbTwo = 2;
// Player groups
  pgAll = DPNID_ALL_PLAYERS_GROUP;
// Lobby query modes
  qmPing = 0; qmScan = 1;

{$IFDEF DEBUGMODE}  
  LobbyPingInterval = 1000;
{$ELSE}
  LobbyPingInterval = 60000;
{$ENDIF}

type
  TSPList = array[0..$FFFF] of TDPN_Service_Provider_Info;

  TFoundHost = packed record
    Name: string[128];
    Latency: Integer;
    AppDesc: PDPN_Application_Desc;
    HostAddress, DeviceAddress: IDirectPlay8Address;
  end;

  TReceivedMessage = packed record
    FromID, Size: Cardinal;
    Data: Pointer;
  end;

  TNetPlayer = record
    ID: Integer;
    Name: TShortName;
  end;

  TNet = class
    NetworkRole: Cardinal;
    Initialized, HostReady, Connected, Connecting, FindingHosts: Boolean;
//    MessagesLocked: Boolean;
    ReceivedMessages: array of TReceivedMessage; TotalReceivedMessages: Integer;
    NetCriticalSection, SockCriticalSection: _RTL_CRITICAL_SECTION;

    MaxPlayers: Integer;
    Players: array of TNetPlayer; TotalPlayers: Integer;
    Messages: TCommandQueue;

    DisallowJoining: Boolean;
    DisallowJoiningStr: string;

    CurrentPlayerID, HostPlayerID: Integer;
    GamesStr: TStringArray;

    DataPort: Cardinal;

    {$IFDEF WANSUPPORT}
    LobbyHost, LobbyURL, GameIDStr, InfoToSendStr: string;
    {$ENDIF}
    LocalHostsStr: TStringArray;
    constructor Initialize(AAppGuid: TGUID; AMessages: TCommandQueue); virtual;
    function ReInit: Boolean; virtual;

    procedure SetDisallowJoining(Disallow: Boolean; Reason: string); virtual;
    {$IFDEF WANSUPPORT}
    procedure QueryLobby; virtual;
    procedure StartPingThread; virtual;
    procedure KillPingThread; virtual;
    {$ENDIF}
    procedure ClearGames; virtual;
    procedure ClearLocalHostAddresses; virtual; abstract;
    procedure ClearFoundHosts; virtual; abstract;    

    function AddReceivedMessage(FromID, DataSize: Longword; Data: Pointer): Boolean; virtual;
    function GetReceivedMessage(Index: Integer; var Msg: TReceivedMessage): Boolean; virtual;
    function ExtractReceivedMessage(var Msg: TReceivedMessage): Boolean; virtual;
    procedure DelReceivedMessage(Index: Integer); virtual;

    function GetPlayerByID(ID: Integer): Integer; virtual;
    function AddPlayer(ID: Integer): Integer; virtual;
    procedure DeletePlayer(ID: Integer); virtual;

    function GetStoredString(ID: Integer): string; virtual;

    function FindPlayers: Boolean; virtual; abstract;
    function FindHosts(Local: Boolean): Boolean; virtual;
    function DoFindHosts: Boolean; virtual; abstract;
    function CreateHost(SessionName: string; Local, HostMigrate: Boolean): Boolean; virtual;
    function Connect(Index: Integer): Boolean; virtual; abstract;
    function Send(PlayerID: Integer; Buf: Pointer; Size: Integer; Guaranteed: Boolean): Boolean; virtual; abstract;
    function SendCommand(PlayerID: Integer; Command: TCommand; Guaranteed: Boolean): Boolean; virtual;
    function SendString(PlayerID: Integer; CmdID: Cardinal; Args: array of Integer; const s: string; Guaranteed: Boolean): Boolean; virtual;
    function SendBinary(PlayerID: Integer; CmdID: Cardinal; Data: Pointer; Size: Integer; Guaranteed: Boolean): Boolean; virtual;
    function DropPlayer(PlayerID: Integer): Boolean; virtual; abstract;
    function Disconnect: Boolean; virtual; abstract;
    function Process(const UserData: Pointer; MessageID: Longword; MessageData: Pointer): HResult; virtual; abstract;
    destructor Free;
  protected
//  public
    TempData: TTempContainer;
    LobbyPingThreadID, LobbyScanThreadID: Cardinal;
    TerminateLobbyPingThread: Boolean;
  end;

  TDX8Net = class(TNet)
    InvokeStdDialog: Boolean;
    SPInfo: ^TSPList; TotalServiceProviders: Integer;
    SelectedProvider: PDPN_Service_Provider_Info;
    HostsFound: array of TFoundHost; TotalHostsFound: Integer;
    AppDesc: TDPN_Application_Desc;
    SPCaps: TDPN_SP_Caps;
    AppGuid: TGuid;
    Peer: IDirectPlay8Peer; HostAddress, DeviceAddress: IDirectPlay8Address;
    LocalHostAddresses: array of IDirectPlay8Address;
    constructor Initialize(AAppGuid: TGUID; AMessages: TCommandQueue); override;

    procedure ClearLocalHostAddresses; override;
    procedure ClearFoundHosts; override;

    function AddReceivedMessageDX8(MessageData: PDPNMSG_RECEIVE): Boolean; virtual;
    function AddPlayerDX8(MessageData: PDPNMSG_CREATE_PLAYER): Boolean; virtual;
    procedure DeletePlayerDX8(MessageData: PDPNMSG_DESTROY_PLAYER); virtual;
    function AddURLComponent(Address: IDirectPlay8Address; Name, Value: WideString): Boolean; virtual;
    function ReInit: Boolean; override;
    function FindPlayers: Boolean; override;
    procedure GetCaps; virtual;
    function SetServiceProvider(Index: Integer): Boolean; virtual;
    function DoFindHosts: Boolean; override;
    function CreateHost(SessionName: string; Local, HostMigrate: Boolean): Boolean; override;
    function Connect(Index: Integer): Boolean; override;
    function Send(PlayerID: Integer; Buf: Pointer; Size: Integer; Guaranteed: Boolean): Boolean; override;
    function DropPlayer(PlayerID: Integer): Boolean; override;
    function Disconnect: Boolean; override;
    function Process(const UserData: Pointer; MessageID: Longword; MessageData: Pointer): HResult; override;

    procedure AddLogDPRes(const Func: string; Res: HResult; const Critical: Boolean = False); virtual;

    destructor Free;
  private
//    AddingHost: Boolean;
    ConnectHandle, FindHostsHandle, SendHandle: Longword;
    function GetHost(ApplicationGuid: TGUID; const HostURL: string): Integer; virtual;
    function AddHostFound(EHR_Msg: PDPNMsg_Enum_Hosts_Response): Boolean; virtual;
  end;

  TCommandNet = class(TDX8Net)
    ReceivedCommands: TCommandQueue;
    constructor Initialize(AAppGuid: TGUID; AMessages: TCommandQueue); override;
    function AddReceivedMessage(FromID, DataSize: Longword; Data: Pointer): Boolean; override;
  end;

  function ExtractURL(HostAddress: IDirectPlay8Address): PWChar;

implementation

var
  DX8Net_Global: TNet;

{$IFDEF WANSUPPORT}
function QueryLobbyServer(QueryMode, HostIndex: Integer): string;
const QueryStr: array[qmPing..qmScan] of string[4] = ('ping', 'scan');
var
  wData: WSADATA; addr: sockaddr_in;
  Sock: integer;
  Error: integer;
  Buf: array [0..1023] of Char;
  Str: string;
  Phe: PHostEnt;
begin
//Инициализация сокета
  Result := '';
  WSAStartup($0101, wData);
  Phe := GetHostByName(PChar(string(DX8Net_Global.LobbyHost)));
  if Phe = nil then begin
    WSACleanup;
    Exit;
  end;
  Sock := Socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Sock = INVALID_SOCKET then begin
    WSACleanup;
    Exit;
  end;
  Addr.sin_family := AF_INET;
  Addr.sin_port   := htons(80);
  Addr.sin_addr   := PInAddr(Phe.h_addr_list^)^;
  Error := Connect(Sock, Addr, SizeOf(Addr));
  if Error = SOCKET_ERROR then begin
    CloseSocket(Sock);
    WSACleanup;
    Exit;
  end;
// Составляем строку запроса
  Str := 'GET ' + DX8Net_Global.LobbyURL + '?GameID=' + DX8Net_Global.GameIDStr + '&Action=' + QueryStr[QueryMode];
  Str := Str + DX8Net_Global.InfoToSendStr;
  if QueryMode = qmPing then Str := Str + '&URI=' + DX8Net_Global.LocalHostsStr[HostIndex];

 {$IFDEF FULLNETLOGGING}
  DX8Net_Global.Log('Ping query: ' + Str);
 {$ENDIF}

  Str := Str + ' HTTP/1.0'#13#10#13#10;
// отправляем
  send(sock, str[1], Length(str), 0);
// Если нужен ответ то принимаем
  if QueryMode = qmScan then begin
    ZeroMemory(@Buf, 1024);
    Error := Recv(Sock, Buf, 1024, 0);
    while Error > 0 do begin
      Result := Result + Copy(Buf, 0, Error);
      Error  := Recv(Sock, Buf, 1024, 0);
    end;
  end;
 // Закрываем сокет – завершаем работу с сетью
 CloseSocket(Sock);
 WSACleanup;

 // Вырезаем из ответа то что нам нужно, т.е. отрезаем HTTP заголовки
 if (QueryMode = qmScan) and (Result <> '') then
  Result := Copy(Result, pos(#13#10#13#10, Result) + 4, Length(Result));
end;

function LobbyPingThreadProc(Param: Pointer): Integer; stdcall;
var i: Integer;  
begin
  Result := 0;
  if DX8Net_Global = nil then Exit;

  while (DX8Net_Global <> nil) and (DX8Net_Global.LocalHostsStr <> nil) do begin
    EnterCriticalSection(DX8Net_Global.SockCriticalSection);
    if DX8Net_Global.TerminateLobbyPingThread then begin
      DX8Net_Global.TerminateLobbyPingThread := False;
      LeaveCriticalSection(DX8Net_Global.SockCriticalSection);
      Break;
    end;
    for i := 0 to Length(DX8Net_Global.LocalHostsStr)-1 do begin
      QueryLobbyServer(qmPing, i);
 {$IFDEF FULLNETLOGGING}
//      DX8Net_Global.Log('Lobby ping proceed' + DX8Net_Global.LocalHostsStr[i]);
 {$ENDIF}
    end;
    LeaveCriticalSection(DX8Net_Global.SockCriticalSection);
    Sleep(LobbyPingInterval);
  end;

  if DX8Net_Global <> nil then DX8Net_Global.LobbyPingThreadID := 0;
end;

function LobbyScanThreadProc(Param: Pointer): Integer; stdcall;
var s: string; Delim: string[2];
begin
  Result := 0;
  if DX8Net_Global = nil then Exit;

  s := QueryLobbyServer(qmScan, 0);
  if Pos(#13#10, s) > 0 then Delim := #13#10 else Delim := #10;
  EnterCriticalSection(DX8Net_Global.SockCriticalSection);
  DX8Net_Global.Messages.Add(cmdLobbyScanEnd, [Split(s, Delim, DX8Net_Global.GamesStr, False)]);
  LeaveCriticalSection(DX8Net_Global.SockCriticalSection);
  DX8Net_Global.DoFindHosts;
end;
{$ENDIF}

function DPProcess_Global(pvUserContext: Pointer; dwMessageType: Longword; pMessage: Pointer): HResult; stdcall;
begin
  if DX8Net_Global <> nil then begin
    EnterCriticalSection(DX8Net_Global.NetCriticalSection);
    Result := DX8Net_Global.Process(pvUserContext, dwMessageType, pMessage);
    LeaveCriticalSection(DX8Net_Global.NetCriticalSection);
  end else Result := S_OK;
end;

{ TNet }

constructor TNet.Initialize(AAppGuid: TGUID; AMessages: TCommandQueue);
begin
  Messages := AMessages;
  MaxPlayers := 8;

  TempData := TTempContainer.Create;

  InitializeCriticalSection(NetCriticalSection);
  InitializeCriticalSection(SockCriticalSection);
  CurrentPlayerID := 0;
  HostPlayerID := 0;
  NetworkRole := nrNone;
  IsMultiThread := False;

{$IFDEF WANSUPPORT}
{$IFDEF DEBUGMODE}  
  LobbyHost := 'mirage.aesp.ru';
//  LobbyHost := 'avagames.net';
{$ELSE}
  LobbyHost := 'avagames.net';
{$ENDIF}
  LobbyURL := 'http://' + LobbyHost + '/perl/gameserver.pl';
  GameIDStr := 'CAST Net';
  InfoToSendStr := '&Info=No information';
{$ENDIF}
  DataPort := 0;//2628;
end;

{$IFDEF WANSUPPORT}
procedure TNet.QueryLobby;
begin
  CreateThread(nil, 128, @LobbyScanThreadProc, Pointer(qmScan), 0, LobbyScanThreadID);
end;

procedure TNet.StartPingThread;
begin
  TerminateLobbyPingThread := False;
  if LobbyPingThreadID = 0 then
   CreateThread(nil, 128, @LobbyPingThreadProc, Pointer(qmPing), 0, LobbyPingThreadID);
end;

procedure TNet.KillPingThread;
begin
  if LobbyPingThreadID <> 0 then if TerminateThread(LobbyPingThreadID, 0) then begin
    LobbyPingThreadID := 0;
  end else begin
{$IFDEF DEBUGMODE} 
    Log('Can''t terminate ping process: ' + GetOSErrorStr(GetLastError));
 {$ENDIF}
  end;
end;
{$ENDIF}

procedure TNet.ClearGames;
var i: Integer;
begin
  EnterCriticalSection(SockCriticalSection);
  for i := 0 to Length(GamesStr)-1 do GamesStr[i] := '';
  GamesStr := nil;
  LeaveCriticalSection(SockCriticalSection);
end;

function TNet.AddReceivedMessage(FromID, DataSize: Longword; Data: Pointer): Boolean;
var Cmd: ^TCommand;
begin
//  Result := False;
//  if MessagesLocked then Exit;
//  MessagesLocked := True;
//  EnterCriticalSection(NetCriticalSection);

  Cmd := Data;
  case Cmd.CommandID of
    cmdRequestPlayerID: SendCommand(Cmd.Arg1, NewCommand(cmdReportPlayerID, [Cmd.Arg1]), True);
    cmdReportPlayerID: begin CurrentPlayerID := Cmd.Arg1; HostPlayerID := Integer(FromID); end;
    cmdClientDisconnectRequest: DropPlayer(Cmd.Arg1);
    else begin
      Inc(TotalReceivedMessages); SetLength(ReceivedMessages, TotalReceivedMessages);
      ReceivedMessages[TotalReceivedMessages-1].Size := DataSize;
      ReceivedMessages[TotalReceivedMessages-1].FromID := FromID;
      GetMem(ReceivedMessages[TotalReceivedMessages-1].Data, ReceivedMessages[TotalReceivedMessages-1].Size);
      Move(Data^, ReceivedMessages[TotalReceivedMessages-1].Data^, ReceivedMessages[TotalReceivedMessages-1].Size);
//      MessagesLocked := False;
      Messages.Add(cmdMessageReceived, [TotalReceivedMessages-1]);
    end;
  end;
  Result := True;
//  LeaveCriticalSection(NetCriticalSection);
end;

function TNet.GetReceivedMessage(Index: Integer; var Msg: TReceivedMessage): Boolean;
begin
  Result := False;
  if NetworkRole = nrNone then Exit;

  EnterCriticalSection(NetCriticalSection);

  if Index < TotalReceivedMessages then begin
    Msg.FromID := ReceivedMessages[Index].FromID;
    Msg.Size := ReceivedMessages[Index].Size;
    GetMem(Msg.Data, Msg.Size);
    Move(ReceivedMessages[Index].Data^, Msg.Data^, Msg.Size);
    Result := True;
  end;

  LeaveCriticalSection(NetCriticalSection);
end;

procedure TNet.DelReceivedMessage(Index: Integer);
var i: Integer;
begin
  EnterCriticalSection(NetCriticalSection);
  if Index < TotalReceivedMessages then begin
    if (ReceivedMessages[Index].Data <> nil) and (ReceivedMessages[Index].Size > 0) then FreeMem(ReceivedMessages[Index].Data);
    ReceivedMessages[Index].Data := nil;
    for i := Index to TotalReceivedMessages-2 do ReceivedMessages[i] := ReceivedMessages[i+1];
    Dec(TotalReceivedMessages);
  end;
  LeaveCriticalSection(NetCriticalSection);
end;

function TNet.ExtractReceivedMessage(var Msg: TReceivedMessage): Boolean;
begin
  Result := GetReceivedMessage(0, Msg);
  DelReceivedMessage(0);
end;

function TNet.GetPlayerByID(ID: Integer): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to TotalPlayers-1 do if Players[i].ID = ID then begin
    Result := i; Exit;
  end;
end;

function TNet.AddPlayer(ID: Integer): Integer;
begin
  Result := GetPlayerByID(ID);
  if Result <> -1 then Exit;
  Result := TotalPlayers;
  Inc(TotalPlayers); SetLength(Players, TotalPlayers);
  Players[Result].ID := ID;
  if NetworkRole = nrHost then SendCommand(ID, NewCommand(cmdReportPlayerID, [Integer(ID)]), True);
  if NetworkRole = nrHostCreation then begin
    CurrentPlayerID := ID;
    HostPlayerID := ID;
  end;
end;

procedure TNet.DeletePlayer(ID: Integer);
begin
  ID := GetPlayerByID(ID);
  if ID = -1 then Exit;
  Dec(TotalPlayers);
  if ID < TotalPlayers then Players[ID] := Players[TotalPlayers];
end;

function TNet.CreateHost(SessionName: string; Local, HostMigrate: Boolean): Boolean;
begin
  {$IFDEF WANSUPPORT}
  if not Local then StartPingThread;
  {$ENDIF}
  SetDisallowJoining(False, '');     // Allow joining
end;

function TNet.FindHosts(Local: Boolean): Boolean;
begin
  ClearFoundHosts;
  ClearGames;
  if Local then DoFindHosts {$IFDEF WANSUPPORT} else QueryLobby {$ENDIF} ;
end;

function TNet.SendCommand(PlayerID: Integer; Command: TCommand; Guaranteed: Boolean): Boolean;
var Cmd: TCommand; // PCmd: ^TCommand;
begin
  Cmd := Command; //  PCmd := @Cmd;
  Result := Send(PlayerID, @Cmd, SizeOf(TCommand), Guaranteed);
end;

function TNet.SendString(PlayerID: Integer; CmdID: Cardinal; Args: array of Integer; const s: string; Guaranteed: Boolean): Boolean;
var Cmd: TCommand; Buf: Pointer; Len: Integer; Arg2, Arg3, Ofs: Integer;
begin
  Len := Length(s);
  Ofs := 8 + MinI(2, Length(Args)) * SizeOf(Integer);
  if Length(Args) > 0 then Arg2 := Args[0];
  if Length(Args) > 1 then Arg3 := Args[1];

  Cmd := NewCommand(CmdID, [Len, Arg2, Arg3]);
  GetMem(Buf, Len + Ofs);
  Move(Cmd, Buf^, Ofs);
  if Len > 0 then Move(s[1], Pointer(Cardinal(Buf)+Ofs)^, Len);
  Result := Send(PlayerID, Buf, Len + Ofs, Guaranteed);
  FreeMem(Buf);
end;

function TNet.SendBinary(PlayerID: Integer; CmdID: Cardinal; Data: Pointer; Size: Integer; Guaranteed: Boolean): Boolean;
var Cmd: TCommand; Buf: Pointer;
begin
  Cmd := NewCommand(CmdID, [Size]);
  GetMem(Buf, Size + 2*SizeOf(Integer));
  Move(Cmd, Buf^, 2*SizeOf(Integer));
  Move(Data^, Pointer(Cardinal(Buf)+2*SizeOf(Integer))^, Size);
  Result := Send(PlayerID, Buf, Size + 2*SizeOf(Integer), Guaranteed);
  FreeMem(Buf);
end;

function TNet.GetStoredString(ID: Integer): string;
var Size: Integer;
begin
  EnterCriticalSection(DX8Net_Global.NetCriticalSection);
  Size := TempData.GetDataSize(ID);
  SetLength(Result, Size);
  if Size <> 0 then Move(TempData.GetData(ID)^, Result[1], Size);
  TempData.RemoveData(ID);
  LeaveCriticalSection(DX8Net_Global.NetCriticalSection);
end;

destructor TNet.Free;
begin
  ClearFoundHosts;
  TempData.Free;
  TerminateLobbyPingThread := True;
  ClearGames;
  ClearLocalHostAddresses;
  DX8Net_Global := nil;
  DeleteCriticalSection(NetCriticalSection);
  DeleteCriticalSection(SockCriticalSection);
end;

procedure TNet.SetDisallowJoining(Disallow: Boolean; Reason: string);
begin
  DisallowJoining := Disallow;
  if Reason <> '' then DisallowJoiningStr := Reason;
  if DisallowJoining then TerminateLobbyPingThread := True
end;

function TNet.ReInit: Boolean;
begin
  SetDisallowJoining(False, 'Joining function disabled');     // Allow joining
end;

{ TDX8Net }

constructor TDX8Net.Initialize(AAppGuid: TGUID; AMessages: TCommandQueue);
begin
  inherited;
  if DPlayDLL = 0 then begin

    Log('Can''t start DirectPlay: DirectX 8 or greater not installed', lkError);

    Exit;
  end;
  AppGuid := AAppGuid;
  InvokeStdDialog := False;
  ReInit;
end;

procedure TDX8Net.AddLogDPRes(const Func: string; Res: HResult; const Critical: Boolean = False);

const
  Err: array[False..True, False..True] of Integer = ((lkInfo, lkError), (lkInfo, lkFatalError));

begin

  Log(Func + ': ' + DPErrorString(Res), Err[Critical, (Res <> S_OK) and (Res <> DPNSUCCESS_PENDING)]);

end;

function TDX8Net.ReInit: Boolean;
var Res: HResult; EnumData, Returned: Cardinal;   cnt: Integer;
begin
  Initialized := False;

  TerminateLobbyPingThread := True;

  if HostReady then Messages.Add(cmdHostTerminated, []);

  HostReady := False;
  ClearGames;

//  AddingHost := False;
//  MessagesLocked := False;

  if Peer <> nil then begin
    Peer.Close(0);
    Peer := nil;
  end;
  AddLogDPRes('DirectPlay8Create', DirectPlay8Create(IID_IDirectPlay8Peer, Peer, nil), True);
  AddLogDPRes('Peer.Initialize', Peer.Initialize(nil, DPProcess_Global, 0));

  if SPInfo <> nil then FreeMem(SPInfo);

  EnumData := 0;
  Peer.EnumServiceProviders(nil, nil, nil, EnumData, Returned, 0);
  GetMem(SPInfo, EnumData);
  Res := Peer.EnumServiceProviders(nil, nil, @SPInfo^[0], EnumData, Returned, 0);
  AddLogDPRes('Peer.EnumServiceProviders', Res);
  TotalServiceProviders := Returned;
//  for i := 0 to Returned-1 do SPList.Items.Add(SPInfo^[i].pwszName);

  AppDesc.dwSize := SizeOf(AppDesc);
  Appdesc.dwFlags := 0;//DPNSESSION_NODPNSVR;// or }DPNSESSION_MIGRATE_HOST ;

  Appdesc.guidApplication := AppGuid;
//  Appdesc.dwMaxPlayers := 200;
  GetMem(AppDesc.pwszSessionName, 256);
  Appdesc.pwszSessionName := StringToWideChar('CAST multiplayer session', Appdesc.pwszSessionName, 128);

{$IFDEF DEBUGMODE}  
  if DeviceAddress <> nil then begin
    cnt := DeviceAddress._AddRef;
    cnt := DeviceAddress._Release;
    DeviceAddress := nil;
  end;
{$ENDIF}
  HostAddress := nil;
  Res := DirectPlay8AddressCreate(IID_IDirectPlay8Address, DeviceAddress, nil);
  if DataPort <> 0 then AddURLComponent(DeviceAddress, 'Port', IntToStr(DataPort));
//  AddURLComponent(DeviceAddress, 'Port', '2626');
  AddLogDPRes('DirectPlay8AddressCreate', Res);
  DirectPlay8AddressCreate(IID_IDirectPlay8Address, HostAddress, nil);
//  Res := CoCreateInstance(CLSID_DirectPlay8Address, nil, CLSCTX_INPROC_SERVER, IID_IDirectPlay8Address, DeviceAddress);
//  AddLogDPRes('CoCreateInstance', Res);

  DX8Net_Global := Self;

  CurrentPlayerID := 0;
  HostPlayerID := 0;

  NetworkRole := nrNone;
  IsMultiThread := False;

  Initialized := True;

  if TempData <> nil then TempData.Free;
  TempData := TTempContainer.Create;
  
  Result := Initialized;
end;

function TDX8Net.GetHost(ApplicationGuid: TGUID; const HostURL: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to TotalHostsFound-1 do
   if isSameGUID(HostsFound[i].Appdesc.guidApplication, ApplicationGUID) and
     (string(ExtractURL(HostsFound[i].HostAddress)) = HostURL) then begin
     Result := i;
     Exit;
   end;
end;

function TDX8Net.AddHostFound(EHR_Msg: PDPNMsg_Enum_Hosts_Response): Boolean;
var l: Integer;
begin

  Log('DX8Net: Host found. Session name "' + EHR_Msg^.pApplicationDescription^.pwszSessionName + '" URL: "' + ExtractURL(EHR_Msg^.pAddressSender) + '"');

  if GetHost(EHR_Msg^.pApplicationDescription^.guidApplication, ExtractURL(EHR_Msg^.pAddressSender)) = -1 then begin
    Inc(TotalHostsFound); SetLength(HostsFound, TotalHostsFound);

    SetLength(HostsFound[TotalHostsFound-1].Name, EHR_Msg^.dwResponseDataSize);
    if EHR_Msg^.dwResponseDataSize > 0 then Move(EHR_Msg^.pvResponseData^, HostsFound[TotalHostsFound-1].Name[1], EHR_Msg^.dwResponseDataSize);

    New(HostsFound[TotalHostsFound-1].Appdesc);
    HostsFound[TotalHostsFound-1].Appdesc^ := EHR_Msg^.pApplicationDescription^;
    l := Length(EHR_Msg^.pApplicationDescription^.pwszSessionName)+2;
    if l > 2 then begin
      GetMem(HostsFound[TotalHostsFound-1].Appdesc^.pwszSessionName, l*2);
      Move(EHR_Msg^.pApplicationDescription^.pwszSessionName^, HostsFound[TotalHostsFound-1].Appdesc^.pwszSessionName^, l*2);
    end else HostsFound[TotalHostsFound-1].Appdesc^.pwszSessionName := nil;
    l := Length(EHR_Msg^.pApplicationDescription^.pwszPassword)+2;
    if l > 2 then begin
      GetMem(HostsFound[TotalHostsFound-1].Appdesc^.pwszPassword, l*2);
      Move(EHR_Msg^.pApplicationDescription^.pwszPassword^, HostsFound[TotalHostsFound-1].Appdesc^.pwszPassword^, l*2);
    end else HostsFound[TotalHostsFound-1].Appdesc^.pwszPassword := nil;

    HostsFound[TotalHostsFound-1].Latency := EHR_Msg^.dwRoundTripLatencyMS;
    EHR_Msg^.pAddressSender.Duplicate(HostsFound[TotalHostsFound-1].HostAddress);
    EHR_Msg^.pAddressDevice.Duplicate(HostsFound[TotalHostsFound-1].DeviceAddress);
    Messages.Add(cmdHostFound, [TotalHostsFound-1]);
  end;
  Result := True;
end;

function TDX8Net.AddReceivedMessageDX8(MessageData: PDPNMSG_RECEIVE): Boolean;
begin
  Result := AddReceivedMessage(MessageData^.dpnidSender, MessageData^.dwReceiveDataSize, MessageData^.pReceiveData);
end;

function TDX8Net.AddURLComponent(Address: IDirectPlay8Address; Name, Value: WideString): Boolean;
var Res, DWordValue: DWord;
begin
  Result := True;
  if (UpperCase(Name) = 'HOSTNAME') then
   AddLogDPRes('Address.AddURLComponent', Address.AddComponent(DPNA_KEY_HOSTNAME, PWideChar(Value), 2+Length(Value)*2, DPNA_DATATYPE_STRING));
  if (UpperCase(Name) = 'PORT') then begin
    DWordValue := StrToIntDef(Value, 0);
    Res := Address.AddComponent(DPNA_KEY_PORT, @DWordValue, SizeOf(DWord), DPNA_DATATYPE_DWORD);
    AddLogDPRes('Address.AddURLComponent', Res);
  end;
end;

procedure TDX8Net.GetCaps;
var Res: HResult; s: string;
begin
  SPCaps.dwSize := SizeOf(SPCaps);
  Res := Peer.GetSPCaps(@SelectedProvider.GUID, SPCaps, 0);
  AddLogDPRes('Peer.GetSPCaps', Res);
 {$IFDEF EXTLOGGING}
  if Res = S_OK then begin
    Log('--- Service provider capabilites ---', lkTitle);
    s := '';
    if (SPCaps.dwFlags or DPNSPCAPS_SUPPORTSDPNSRV) > 0 then s := s + '[SUPPORTSDPNSRV] ';
    if (SPCaps.dwFlags or DPNSPCAPS_SUPPORTSBROADCAST) > 0 then s := s + '[SUPPORTSBROADCAST] ';
    if (SPCaps.dwFlags or DPNSPCAPS_SUPPORTSALLADAPTERS) > 0 then s := s + '[SUPPORTSALLADAPTERS] ';
    Log('    Flags: ' + s);
    Log('    Number of threads: ' + IntToStr(SPCaps.dwNumThreads) + ', Buffers per thread: ' + IntToStr(SPCaps.dwBuffersPerThread));
    Log('    Enumeration defaults: Count: ' + IntToStr(SPCaps.dwDefaultEnumCount) + ', Retry interval: ' + IntToStr(SPCaps.dwDefaultEnumRetryInterval) + ', Timeout: ' + IntToStr(SPCaps.dwDefaultEnumTimeout));
    Log('    Max payload size: ' + IntToStr(SPCaps.dwMaxEnumPayloadSize));
    Log('    System buffer size: ' + IntToStr(SPCaps.dwSystemBufferSize));
  end;
 {$ENDIF}
end;

function TDX8Net.SetServiceProvider(Index: Integer): Boolean;
var Res: HResult;
begin
  Result := False;
  if (Index < 0) or (Index >= TotalServiceProviders) then Exit;
  SelectedProvider := @SPInfo^[Index];
  Res := DeviceAddress.SetSP(@SelectedProvider.GUID);
 Log('TDX8Net: Setting service provider to ' + SPInfo^[Index].pwszName, lkTitle); 
  AddLogDPRes('DeviceAddress.SetSP', Res);
  if Res = S_OK then begin
    HostAddress.SetEqual(DeviceAddress);
  end;
  GetCaps;
  Result := Res = S_OK;
end;

function TDX8Net.DoFindHosts: Boolean;
var i: Integer; Res: HRESULT; TargetHostAddress: IDirectPlay8Address;// sw: PWideChar;
begin
  //  AddingHost := False;
//  DPAdresses[0] := DeviceAddress;
  AppDesc.dwFlags := 0;
  DirectPlay8AddressCreate(IID_IDirectPlay8Address, TargetHostAddress, nil);
  if not InvokeStdDialog then for i := 0 to Length(GamesStr)-1 do if GamesStr[i] <> '' then begin
//    GetMem(sw, 2048);
//    sw := StringToWideChar(GamesStr[i], sw, 1024);
//    sw := PWideChar(GamesStr[i]);
    EnterCriticalSection(SockCriticalSection);
    try
      Res := TargetHostAddress.BuildFromURLA(PChar(GamesStr[i]));
    finally
      LeaveCriticalSection(SockCriticalSection);
    end;
//    FreeMem(sw, 2048);
    AddLogDPRes('Peer.BuildFromURLA', Res);

    Log('Host from lobby: ' + GamesStr[i]);

    Res := Peer.EnumHosts(AppDesc, TargetHostAddress, DeviceAddress, @Res, 4, 0, 0, 0, @Res, @FindHostsHandle, DPNENUMHOSTS_OKTOQUERYFORADDRESSING * Ord(InvokeStdDialog = True));
  end;

  TargetHostAddress := nil;
  Res := Peer.EnumHosts(AppDesc, HostAddress, DeviceAddress, @Res, 4, 0, 0, 0, @Res, @FindHostsHandle, DPNENUMHOSTS_OKTOQUERYFORADDRESSING * Ord(InvokeStdDialog = True));
  AddLogDPRes('Peer.EnumHosts', Res);
  FindingHosts := (Res = DPNSUCCESS_PENDING) or (Res = S_OK);
  Result := FindingHosts;
end;

function TDX8Net.CreateHost(SessionName: string; Local, HostMigrate: Boolean): Boolean;
var Res: HResult; DPAdresses: TIDirectPlay8Addresses; AdressesCount: Cardinal; OldNR, i: Integer;
begin
  Result := False;
  if SelectedProvider = nil then Exit;

  IsMultiThread := True;

  OldNR := NetworkRole;
  NetworkRole := nrHostCreation;
  DPAdresses[0] := DeviceAddress;
  AppDesc.dwFlags := 0;//DPNSESSION_NODPNSVR;

  if not Local then AppDesc.dwFlags := AppDesc.dwFlags or DPNSESSION_NODPNSVR;
  if HostMigrate then AppDesc.dwFlags := AppDesc.dwFlags or DPNSESSION_MIGRATE_HOST;
  AppDesc.pwszSessionName := StringToWideChar(SessionName, AppDesc.pwszSessionName, 128);
  Res := Peer.Host(@Appdesc, @DPAdresses[0], 1, nil, nil, nil, DPNHOST_OKTOQUERYFORADDRESSING * Ord(InvokeStdDialog = True));
  AddLogDPRes('Peer.Host', Res);
  if Res <> S_OK then begin
    NetworkRole := OldNR;
    Exit;
  end;
  NetworkRole := nrHost;

  Messages.Add(cmdHostReady, []);
  Result := True;

  HostReady := True;

  ClearLocalHostAddresses;
  AdressesCount := 0;
  Res := Peer.GetLocalHostAddresses(nil, AdressesCount, 0);
  if AdressesCount > 0 then begin
    EnterCriticalSection(SockCriticalSection);
    SetLength(LocalHostAddresses, AdressesCount);
    SetLength(LocalHostsStr, AdressesCount);
    if Res = DPNERR_BUFFERTOOSMALL then Res := Peer.GetLocalHostAddresses(@LocalHostAddresses[0], AdressesCount, 0);
    for i := 0 to AdressesCount-1 do begin
      LocalHostsStr[i] := ExtractURL(LocalHostAddresses[i]);
 {$IFDEF FULLNETLOGGING}
      Log('  Local host address: ' + LocalHostsStr[i]);
 {$ENDIF}
    end;
    LeaveCriticalSection(SockCriticalSection);
  end;
  inherited CreateHost(SessionName, Local, HostMigrate);

  DPAdresses[0] := nil;
end;

function TDX8Net.Connect(Index: Integer): Boolean;
var Res: HResult; DPAdresses, HPAdresses: TIDirectPlay8Addresses;
begin
  Result := False;
  if (Index < 0) or (Index >= TotalHostsFound) then Exit;

  IsMultiThread := True;

  EnterCriticalSection(NetCriticalSection);
  DPAdresses[0] := HostsFound[Index].DeviceAddress;
  HPAdresses[0] := HostsFound[Index].HostAddress;
  LeaveCriticalSection(NetCriticalSection);
  AppDesc.dwFlags := 0;
//  AppDesc.guidInstance := FoundHosts[HostList.ItemIndex].AppDesc.guidInstance;
  Res := Peer.Connect(@Appdesc, HPAdresses[0], DPAdresses[0], nil, nil, nil{@Res}, 0, nil, nil, @ConnectHandle, DPNCONNECT_OKTOQUERYFORADDRESSING * Ord(InvokeStdDialog = True));
  AddLogDPRes('Peer.Connect', Res);
  Connecting := (Res = DPNSUCCESS_PENDING) or (Res = S_OK);
  CurrentPlayerID := 0;
  HostPlayerID := 0;

//  NetworkRole := nrClient;
  Result := Connecting;
end;

function TDX8Net.Send(PlayerID: Integer; Buf: Pointer; Size: Integer; Guaranteed: Boolean): Boolean;
var Res: HResult; BufDesc: TDPN_BUFFER_DESC; Flags: Cardinal;
begin
{$Q-}
  BufDesc.dwBufferSize := Size;
  BufDesc.pBufferData := Buf;

  if Guaranteed then Flags := DPNSEND_GUARANTEED else Flags := 0;
  if PlayerID <> CurrentPlayerID then Flags := Flags or DPNSEND_NOLOOPBACK;    // Allow to send to self
//  Flags := Flags or DPNSEND_NONSEQUENTIAL;

  Res := Peer.SendTo(Cardinal(PlayerID), BufDesc, 1, 0, nil, @SendHandle, Flags);
{$IFDEF FULLNETLOGGING}
  AddLogDPRes('Peer.SendTo', Res);
{$ENDIF}
  Result := (Res = DPNSUCCESS_PENDING) or (Res = S_OK);
end;

function TDX8Net.DropPlayer(PlayerID: Integer): Boolean;
var Res: HResult;
begin
  Res := Peer.DestroyPeer(Cardinal(PlayerID), @Res, 4, 0);
  Result := Res = S_OK;
end;

function TDX8Net.Disconnect: Boolean;
var Res: HResult;
begin
//  if NetworkRole <> nrClient then
  TerminateLobbyPingThread := True; 
  Res := Peer.TerminateSession(@Res, 4, 0);
  AddLogDPRes('Peer.TerminateSession', Res);
  Result := Res = S_OK;
  if Connecting then Peer.CancelAsyncOperation(ConnectHandle, 0);
  Connecting := False;
  Connected := not Result;
  ClearLocalHostAddresses;
  NetworkRole := nrNone;
//  IsMultiThread := False;
end;

destructor TDX8Net.Free;
var i: Integer;
begin
//  AddingHost := False;
  if SPInfo <> nil then FreeMem(SPInfo);
  if Peer <> nil then begin
    Peer.Close(0);
    Peer := nil;
  end;

  DeviceAddress := nil;
  HostAddress := nil;
  inherited;
end;

function TDX8Net.Process(const UserData: Pointer; MessageID: Longword; MessageData: Pointer): HResult;
// Must be thread-safe
var
  AsyncOpData: PDPNMSG_ASYNC_OP_COMPLETE;
  ConnectData: PDPNMSG_CONNECT_COMPLETE;
  s: string; TempDataID: Integer;
begin
  Result := S_OK;
  case MessageID of
    DPN_MSGID_ENUM_HOSTS_RESPONSE: begin
      AddHostFound(MessageData);
    end;
    DPN_MSGID_ASYNC_OP_COMPLETE: if MessageData <> nil then begin
      AsyncOpData := MessageData;
      if AsyncOpData.hAsyncOp = FindHostsHandle then begin
        FindingHosts := False;
        Messages.Add(cmdHostSearchEnd, [TotalHostsFound]);
      end;
//      if AsyncOpData.hAsyncOp = ConnectHandle then Connecting := False;
    end;
    DPN_MSGID_CONNECT_COMPLETE: begin
      ConnectData := MessageData;
      if ConnectData.hAsyncOp = ConnectHandle then begin
        if (ConnectData.hResultCode = S_OK) or (ConnectData.hResultCode = DPNERR_ALREADYCONNECTED) then begin
          Connected := True;
          Messages.Add(cmdConnected, [Ord(ConnectData.hResultCode <> DPNERR_ALREADYCONNECTED)]);
          if Connected then NetworkRole := nrClient;
        end;
        Connecting := False;
      end;
      s := '';
      with PDPNMSG_CONNECT_COMPLETE(MessageData)^ do begin
        SetLength(s, dwApplicationReplyDataSize);
        if dwApplicationReplyDataSize > 0 then begin
          Move(pvApplicationReplyData^, s[1], dwApplicationReplyDataSize);
          Messages.Add(cmdNetworkReply, [TempData.AddData(@s[1], Length(s))]);
        end;
      end;
 if Connected then Log('TDX8Net: Connect. Server reply: "' + s + '"'); 
    end;
    DPN_MSGID_RECEIVE: AddReceivedMessageDX8(MessageData);
    DPN_MSGID_TERMINATE_SESSION: begin
      Connected := False;
      NetworkRole := nrNone;
//      IsMultiThread := False;
      CurrentPlayerID := 0;
      HostPlayerID := 0;
      Messages.Add(cmdDisconnected, []);
 Log('TDX8Net: Session terminated'); 
    end;
    DPN_MSGID_CREATE_PLAYER: AddPlayerDX8(MessageData);
    DPN_MSGID_DESTROY_PLAYER: DeletePlayerDX8(MessageData);
    DPN_MSGID_INDICATE_CONNECT: begin
//      Assert(NetworkRole = nrHost, 'DPN_MSGID_INDICATE_CONNECT received by non-host');
      NetworkRole := nrHost;
      if DisallowJoining then begin
        Result := S_OK+1;
        s := DisallowJoiningStr;
      end else if TotalPlayers >= MaxPlayers then begin
        Result := S_OK+1;
        s := 'No empty remote slot at host';
      end else s := 'Welcome!';
      TempDataID := TempData.AddData(@s[1], Length(s));
      with PDPNMSG_INDICATE_CONNECT(MessageData)^ do begin
        pvReplyData := TempData.GetData(TempDataID);
        dwReplyDataSize := Length(s);
        pvReplyContext := Pointer(TempDataID);
      end;

      PDPNMSG_INDICATE_CONNECT(MessageData)^.pAddressPlayer._AddRef;
      Log('TDX8Net: Connection attempt detected from "' + ExtractURL(PDPNMSG_INDICATE_CONNECT(MessageData)^.pAddressPlayer)+'"', lkTitle);
      if Result = S_OK then Log('  Connection approved') else Log('  Connection rejected due to maximum players limit reached');
      PDPNMSG_INDICATE_CONNECT(MessageData)^.pAddressPlayer._Release;

    end;
    DPN_MSGID_ENUM_HOSTS_QUERY: begin
      s := 'CAST netsession';
      TempDataID := TempData.AddData(@s[1], Length(s));
      with PDPNMSG_ENUM_HOSTS_QUERY(MessageData)^ do begin
        dwMaxResponseDataSize := 128;
        pvResponseData := TempData.GetData(TempDataID);
        dwResponseDataSize := Length(s);
        pvResponseContext := Pointer(TempDataID);
      end;
      Messages.Add(cmdHostQuery, []);
 Log('TDX8Net: Host query detected. TempData.TotalDataChains: ' + IntTosTr(TempData.TotalDataChains)); 
    end;
    DPN_MSGID_RETURN_BUFFER: with PDPNMSG_RETURN_BUFFER(MessageData)^ do begin
      Assert(pvBuffer = TempData.ExtractData(Integer(pvUserContext)), 'Data mismatch in RETURN_BUFFER');
// Log('TDX8Net: Return buffer detected. Result code: ' + IntToStr(hResultCode) + ', context: ' + IntToStr(Integer(pvUserContext))); 
    end;
    DPN_MSGID_SEND_COMPLETE: with PDPNMSG_SEND_COMPLETE(MessageData)^ do begin
// Log('TDX8Net: Send complete. Result code: ' + IntToStr(hResultCode) + ', time: ' + IntToStr(dwSendTime) + ' ms'); 
    end;

    else Log('TDX8Net: Unknown message detected: ' + IntToHex(MessageID, 8));

  end;
//  if (PeekMessage(Msg, 0, 0, 0, PM_REMOVE)) then if (Msg.message = WM_QUIT) then Form1.Close else begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;

{ ****** }

function ExtractURL(HostAddress: IDirectPlay8Address): PWChar;
var URL: PWChar; URLLen: DWord;
begin
  URLLen := 0;
  HostAddress.GetURLW(nil, URLLen);
  GetMem(URL, URLLen * SizeOf(WChar));
  HostAddress.GetURLW(URL, URLLen);
  Result := URL;
end;

function TDX8Net.AddPlayerDX8(MessageData: PDPNMSG_CREATE_PLAYER): Boolean;
begin
  AddPlayer(Integer(MessageData^.dpnidPlayer));
  Messages.Add(cmdPlayerConnected, [Integer(MessageData^.dpnidPlayer)]);
 Log('TDX8Net: Player ' + IntToStr(Integer(MessageData^.dpnidPlayer)) + ' connected'); 
  Result := True;
end;

procedure TDX8Net.DeletePlayerDX8(MessageData: PDPNMSG_DESTROY_PLAYER);

function GetReasonStr(Reason: Integer): string;
begin
  case Reason of
    DPNDESTROYPLAYERREASON_NORMAL: Result := 'Normal';
    DPNDESTROYPLAYERREASON_CONNECTIONLOST: Result := 'Connection lost';
    DPNDESTROYPLAYERREASON_SESSIONTERMINATED: Result := 'Session terminated';
    DPNDESTROYPLAYERREASON_HOSTDESTROYEDPLAYER: Result := 'Disconnected by host';
    else Result := 'Unknown';
  end;
end;

begin
  Messages.Add(cmdPlayerDisconnected, [Integer(MessageData^.dpnidPlayer), MessageData^.dwReason]);
  DeletePlayer(Integer(MessageData^.dpnidPlayer));
  if (NetworkRole = nrClient) and (Integer(MessageData^.dpnidPlayer) = HostPlayerID) then begin
    NetworkRole := nrNone;
    CurrentPlayerID := 0;
    Messages.Add(cmdDisconnected, []);
  end;
 Log('TDX8Net: Player ' + IntToStr(Integer(MessageData^.dpnidPlayer)) + ' disconnected. Reason: ' + GetReasonStr(MessageData^.dwReason)); 
end;

function TDX8Net.FindPlayers: Boolean;                   // Not tested
var
  i: Integer;
  BufSize: Cardinal; Res: HResult;
  PlayerIDS: array of Integer; 
begin
  BufSize := 0;
  Res := Peer.EnumPlayersAndGroups(nil, BufSize, DPNENUM_PLAYERS);
  if Res = DPNERR_BUFFERTOOSMALL then begin
    SetLength(PlayerIDS, BufSize);
    SetLength(Players, BufSize);
    Peer.EnumPlayersAndGroups(@PlayerIDS[0], BufSize, DPNENUM_PLAYERS);
    for i := 0 to BufSize do Players[i].ID := PlayerIDS[i];
    TotalPlayers := BufSize;
    SetLength(PlayerIDS, 0);
  end else AddLogDPRes('Peer.EnumPlayersAndGroups', Res);
  Result := Res = S_OK;
end;

procedure TDX8Net.ClearLocalHostAddresses;
var i: Integer;
begin
  EnterCriticalSection(SockCriticalSection);
  for i := 0 to Length(LocalHostAddresses)-1 do LocalHostAddresses[i] := nil;
  for i := 0 to Length(LocalHostsStr)-1 do LocalHostsStr[i] := '';
  LocalHostAddresses := nil;
  LocalHostsStr := nil;
  LeaveCriticalSection(SockCriticalSection);
end;

procedure TDX8Net.ClearFoundHosts;
var i: Integer;
begin
  EnterCriticalSection(NetCriticalSection);
  for i := 0 to TotalHostsFound - 1 do begin
    HostsFound[i].HostAddress := nil;
    HostsFound[i].DeviceAddress := nil;
    if HostsFound[i].Appdesc.pwszSessionName <> nil then FreeMem(HostsFound[i].Appdesc.pwszSessionName);
    if HostsFound[i].Appdesc.pwszPassword <> nil then FreeMem(HostsFound[i].Appdesc.pwszPassword);
    FreeMem(HostsFound[i].Appdesc);
  end;
  SetLength(HostsFound, 0); TotalHostsFound := 0;
  LeaveCriticalSection(NetCriticalSection);
end;

{ TCommandNet }

function TCommandNet.AddReceivedMessage(FromID, DataSize: Longword; Data: Pointer): Boolean;
var i: Integer; Cmd: TCommand;
begin
  for i := 0 to DataSize div SizeOf(TCommand) - 1 do begin
    Move(PByteBuffer(Data)^[i*SizeOf(TCommand)], Cmd, SizeOf(TCommand));
    ReceivedCommands.Add(Cmd);
  end;
  Result := True;
end;

constructor TCommandNet.Initialize(AAppGuid: TGUID; AMessages: TCommandQueue);
begin
  inherited;
  if ReceivedCommands <> nil then ReceivedCommands.Clear else ReceivedCommands := TCommandQueue.Create;
end;

initialization

begin
  DX8Net_Global := nil;
end;

end.
