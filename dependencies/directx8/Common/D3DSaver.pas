unit D3DSaver;
//-----------------------------------------------------------------------------
// File: D3DSaver.h, D3DSaver.cpp
//
// Desc: Framework for screensavers that use Direct3D 8.0.
//
// Copyright (c) 2000 Microsoft Corporation. All rights reserved.
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// Original ObjectPascal conversion made by: Alexey Barkovoy
// E-Mail: clootie@reactor.ru
//
//-----------------------------------------------------------------------------
//  Latest version can be downloaded from:
//     http://clootie.narod.ru/DelphiGraphics/download.html
//       -- and choice version of DirectX SDK: 8.0 or 8.1 
//-----------------------------------------------------------------------------

interface

{$I DirectX.inc}

uses
  Windows, D3DX8, {$I UseD3D8.inc};

type
  //---------------------------------------------------------------------------
  // Error codes
  //---------------------------------------------------------------------------
  TAppMsgType = (MSG_NONE, MSGERR_APPMUSTEXIT, MSGWARN_SWITCHEDTOREF);
  APPMSGTYPE = TAppMsgType;

const
  D3DAPPERR_NODIRECT3D          = HResult($82000001);
  D3DAPPERR_NOWINDOW            = HResult($82000002);
  D3DAPPERR_NOCOMPATIBLEDEVICES = HResult($82000003);
  D3DAPPERR_NOWINDOWABLEDEVICES = HResult($82000004);
  D3DAPPERR_NOHARDWAREDEVICE    = HResult($82000005);
  D3DAPPERR_HALNOTCOMPATIBLE    = HResult($82000006);
  D3DAPPERR_NOWINDOWEDHAL       = HResult($82000007);
  D3DAPPERR_NODESKTOPHAL        = HResult($82000008);
  D3DAPPERR_NOHALTHISMODE       = HResult($82000009);
  D3DAPPERR_NONZEROREFCOUNT     = HResult($8200000a);
  D3DAPPERR_MEDIANOTFOUND       = HResult($8200000b);
  D3DAPPERR_RESIZEFAILED        = HResult($8200000c);
  D3DAPPERR_INITDEVICEOBJECTSFAILED = HResult($8200000d);
  D3DAPPERR_CREATEDEVICEFAILED  = HResult($8200000e);
  D3DAPPERR_NOPREVIEW           = HResult($8200000f);


  //---------------------------------------------------------------------------
  // Constants
  //---------------------------------------------------------------------------
  MAX_DISPLAYS  = 9;
  NO_ADAPTER    = $ffffffff;
  NO_MONITOR    = $ffffffff;


type
  //**************************************************************************
  // Modes of operation for screensaver
  TSaverMode =
  ( sm_config,         // Config dialog box
    sm_preview,        // Mini preview window in Display Properties dialog
    sm_full,           // Full-on screensaver mode
    sm_test,           // Test mode
    sm_passwordchange  // Change password
  );
  SaverMode = TSaverMode;


type
  // Prototype for VerifyScreenSavePwd() in password.cpl, used on Win9x
  TVerifyWndProc = function (hWindow: HWND): BOOL; pascal;
  VERIFYPWDPROC = TVerifyWndProc;


  //---------------------------------------------------------------------------
  // Name: struct D3DModeInfo
  // Desc: Structure for holding information about a display mode
  //---------------------------------------------------------------------------
  TD3DModeInfo = record
    Width:      DWORD;      // Screen width in this mode
    Height:     DWORD;      // Screen height in this mode
    Format:     TD3DFormat; // Pixel format in this mode
    dwBehavior: DWORD;      // Hardware / Software / Mixed vertex processing
    DepthStencilFormat: TD3DFormat; // Which depth/stencil format to use with this mode
  end;
  D3DModeInfo = TD3DModeInfo;


  //---------------------------------------------------------------------------
  // Name: struct D3DWindowedModeInfo
  // Desc: Structure for holding information about a display mode
  //---------------------------------------------------------------------------
  TD3DWindowedModeInfo = record
    DisplayFormat: TD3DFormat;
    BackBufferFormat: TD3DFormat;
    dwBehavior: DWord; // Hardware / Software / Mixed vertex processing
    DepthStencilFormat: TD3DFormat; // Which depth/stencil format to use with this mode
  end;
  D3DWindowedModeInfo = TD3DWindowedModeInfo;


  //-----------------------------------------------------------------------------
  // Name: struct D3DDeviceInfo
  // Desc: Structure for holding information about a Direct3D device, including
  //       a list of modes compatible with this device
  //-----------------------------------------------------------------------------
  PD3DDeviceInfo = ^TD3DDeviceInfo;
  TD3DDeviceInfo = record
    // Device data
    DeviceType:         TD3DDevType; // Reference, HAL, etc.
    d3dCaps:            TD3DCaps8;   // Capabilities of this device

    strDesc:            PChar;       // Name of this device {BAA: was "const TCHAR* strDesc"}
    bCanDoWindowed:     Boolean;     // Whether this device can work in windowed mode

    // Modes for this device
    dwNumModes: DWord;
    modes: array[0..149] of TD3DModeInfo;

    // Current state
    dwCurrentMode:      DWord;
    bWindowed:          Boolean;
    MultiSampleType:    TD3DMultiSampleType;
  end;
  D3DDeviceInfo = TD3DDeviceInfo;


//-----------------------------------------------------------------------------
// Name: struct D3DAdapterInfo
// Desc: Structure for holding information about an adapter, including a list
//       of devices available on this adapter
//-----------------------------------------------------------------------------
  PTD3DAdapterInfo = ^TD3DAdapterInfo;
  TD3DAdapterInfo = record
    // Adapter data
    iMonitor: DWord; // Which MonitorInfo corresponds to this adapter
    d3dAdapterIdentifier: TD3DAdapterIdentifier8;
    d3ddmDesktop: TD3DDisplayMode; // Desktop display mode for this adapter

    // Devices for this adapter
    dwNumDevices:       DWord;
    devices: array[0..2] of TD3DDeviceInfo;
    bHasHAL:            Boolean;
    bHasAppCompatHAL:   Boolean;
    bHasSW:             Boolean;
    bHasAppCompatSW:    Boolean;

    // User's preferred mode settings for this adapter
    dwUserPrefWidth:    DWord;
    dwUserPrefHeight:   DWord;
    d3dfmtUserPrefFormat: TD3DFormat;
    bLeaveBlack:        Boolean; // If TRUE, don't render to this display
    bDisableHW:         Boolean; // If TRUE, don't use HAL on this display

    // Current state
    dwCurrentDevice:    DWord;
    hWndDevice:         HWND;
  end;
  D3DAdapterInfo = TD3DAdapterInfo;


  //---------------------------------------------------------------------------
  // Name: struct MonitorInfo
  // Desc: Structure for holding information about a monitor
  //---------------------------------------------------------------------------
  PMonitorInfo = ^TMonitorInfo;
  TMonitorInfo = record
    strDeviceName:  array[0..127] of PChar;
    strMonitorName: array[0..127] of PChar;
    hMonitor:   HMONITOR;
    rcScreen:   TRect;
    iAdapter:   DWord; // Which D3DAdapterInfo corresponds to this monitor
    hWnd:       HWND;

    // Error message state
    xError:     Single;
    yError:     Single;
    widthError: Single;
    heightError:Single;
    xVelError:  Single;
    yVelError:  Single;
  end;
  MonitorInfo = TMonitorInfo;


  //---------------------------------------------------------------------------
  // Name: struct RenderUnit
  // Desc:
  //---------------------------------------------------------------------------
  PRenderUnit = ^TRenderUnit;
  TRenderUnit = record
    iAdapter:   LongWord;
    iMonitor:   LongWord;
    DeviceType: TD3DDevType;      // Reference, HAL, etc.
    dwBehavior: DWord;
    pd3dDevice: IDirect3DDevice8;
    d3dpp:      TD3DPresentParameters;
    bDeviceObjectsInited: Boolean; // InitDeviceObjects was called
    bDeviceObjectsRestored: Boolean; // RestoreDeviceObjects was called
    strDeviceStats: array[0..89] of PChar; // String to hold D3D device stats
    strFrameStats:  array[0..39] of PChar; // String to hold frame stats
  end;
  RenderUnit = TRenderUnit;


  //---------------------------------------------------------------------------
  // Name: class CD3DScreensaver
  // Desc: D3D screensaver class
  //---------------------------------------------------------------------------
  CD3DScreensaver = class
  public
    constructor Create;

    function Create_(hInstance: LongWord): HRESULT; virtual;
    function Run: Integer; virtual;
    function DisplayErrorMsg(hr: HRESULT; dwType: TAppMsgType = MSG_NONE): HRESULT;

  protected
    function ParseCommandLine(pstrCommandLine: PChar): TSaverMode;
    procedure ChangePassword;
    function DoSaver: HRESULT; virtual;

    procedure DoConfig; virtual;        { }
    procedure ReadSettings; virtual;    { }
    procedure ReadScreenSettings(hkeyParent: HKEY);
    procedure WriteScreenSettings(hkeyParent: HKEY);

    procedure DoPaint(hwnd: HWND; hdc: HDC); virtual;
    function Initialize3DEnvironment: HRESULT;
    procedure Cleanup3DEnvironment;
    function Render3DEnvironment: HRESULT;
    function SaverProc(hWnd: HWND; uMsg: LongWord; wParam: WPARAM; lParam: LPARAM): LRESULT; virtual;
    procedure InterruptSaver;
    procedure ShutdownSaver;
    procedure DoScreenSettingsDialog(hwndParent: HWND);
    function ScreenSettingsDlgProc(hWnd: HWND; uMsg: LongWord; wParam: WPARAM; lParam: LPARAM): LRESULT;
    procedure SetupAdapterPage(hWnd: HWND);

    function CreateSaverWindow: HRESULT;
    function BuildDeviceList: HRESULT;
    function FindDepthStencilFormat(iAdapter: LongWord; DeviceType: TD3DDevType;
      TargetFormat: TD3DFormat; var pDepthStencilFormat: TD3DFormat): Boolean;
    function CheckWindowedFormat(iAdapter: LongWord; out pD3DWindowedModeInfo: TD3DWindowedModeInfo): HRESULT;
    function CreateFullscreenRenderUnit(var pRenderUnit: TRenderUnit): HRESULT;
    function CreateWindowedRenderUnit  (var pRenderUnit: TRenderUnit): HRESULT;
    function FindNextLowerMode(var pD3DDeviceInfo_: TD3DDeviceInfo): Boolean;
    procedure SwitchToRenderUnit(iRenderUnit: LongWord);
    procedure BuildProjectionMatrix(fNear, fFar: Single; out pMatrix: TD3DXMatrix);
    function SetProjectionMatrix(fNear, fFar: Single): HRESULT;
    procedure UpdateDeviceStats; virtual;
    procedure UpdateFrameStats; virtual;
    function GetTextForError(hr: HRESULT; pszError: PChar; dwNumChars: DWORD): Boolean; virtual;
    procedure UpdateErrorBox;
    procedure EnumMonitors;
    function GetBestAdapter(out piAdapter: DWORD): Boolean;

    procedure SetDevice(iDevice: LongWord); virtual;    { }
    function RegisterSoftwareDevice: HRESULT; virtual;  { return S_OK; }
    function ConfirmDevice(const pCaps: TD3DCaps8; dwBehavior: DWORD;
      fmtBackBuffer: TD3DFormat): HRESULT; virtual;     { return S_OK; }
    function ConfirmMode(pd3dDev: IDirect3DDevice8): HRESULT; virtual; { return S_OK; }
    function OneTimeSceneInit: HRESULT; virtual;        { return S_OK; }
    function InitDeviceObjects: HRESULT; virtual;       { return S_OK; }
    function RestoreDeviceObjects: HRESULT; virtual;    { return S_OK; }
    function FrameMove: HRESULT; virtual;               { return S_OK; }
    function Render: HRESULT; virtual;                  { return S_OK; }
    function InvalidateDeviceObjects: HRESULT; virtual; { return S_OK; }
    function DeleteDeviceObjects: HRESULT; virtual;     { return S_OK; }
    function FinalCleanup: HRESULT; virtual;            { return S_OK; }

  protected
    m_SaverMode:        TSaverMode; // sm_config, sm_full, sm_preview, etc.
    m_bAllScreensSame:  Boolean;    // If TRUE, show same image on all screens
    m_hWnd:             HWND;       // Focus window and device window on primary
    m_hWndParent:       HWND;
    m_hInstance:        LongWord;
    m_bWaitForInputIdle: Boolean;   // Used to pause when preview starts
    m_dwSaverMouseMoveCount: DWORD;
    m_bIs9x:            Boolean;
    m_hPasswordDLL:     LongWord;
    m_VerifySaverPassword: TVerifyWndProc;
    m_bCheckingSaverPassword: Boolean;
    m_bWindowed:        Boolean;

    // Variables for non-fatal error management
    m_bErrorMode:       Boolean;          // Whether to display an error
    m_hrError:          HRESULT;          // Error code to display
    m_szError: array[0..399] of Char;     // Error message text

    m_Monitors: array[0..MAX_DISPLAYS-1] of TMonitorInfo;
    m_dwNumMonitors:    DWORD;
    m_RenderUnits: array[0..MAX_DISPLAYS-1] of TRenderUnit;
    m_dwNumRenderUnits: DWORD;
    m_Adapters: array[0..MAX_DISPLAYS-1] of PTD3DAdapterInfo;
    m_dwNumAdapters:    DWORD;
    m_pD3D:             IDirect3D8;
    m_pd3dDevice:       IDirect3DDevice8; // Current D3D device
    m_rcRenderTotal:    TRect;            // Rect of entire area to be rendered
    m_rcRenderCurDevice: TRect;           // Rect of render area of current device
    m_d3dsdBackBuffer:  TD3DSurfaceDesc;  // Info on back buffer for current device

    m_strWindowTitle: array[0..199] of Char; // Title for the app's window
    m_bAllowRef:        Boolean;          // Whether to allow REF D3D device
    m_bUseDepthBuffer:  Boolean;          // Whether to autocreate depthbuffer
    m_bMultithreaded:   Boolean;          // Whether to make D3D thread-safe
    m_bOneScreenOnly:   Boolean;          // Only ever show screensaver on one screen
    m_strRegPath: array[0..199] of Char;  // Where to store registry info
    m_dwMinDepthBits:   DWORD;            // Minimum number of bits needed in depth buffer
    m_dwMinStencilBits: DWORD;            // Minimum number of bits needed in stencil buffer
    m_SwapEffectFullscreen: TD3DSwapEffect; // SwapEffect to use in fullscreen Present()
    m_SwapEffectWindowed: TD3DSwapEffect; // SwapEffect to use in windowed Present()

    // Variables for timing
    m_fTime: Single;             // Current time in seconds
    m_fElapsedTime: Single;      // Time elapsed since last frame
    m_fFPS: Single;              // Instanteous frame rate
    m_strDeviceStats: array[0..89] of Char; // D3D device stats for current device
    m_strFrameStats:  array[0..39] of Char; // Frame stats for current device
  end;

type
  QSortCB = function (const arg1, arg2: Pointer): Integer;
  Size_t = Cardinal;

procedure QSort(base: Pointer; num: Size_t; width: Size_t; compare: QSortCB);

function EqualGUID(const G1, G2: TGUID): Boolean;

// Debug support
procedure OutputFileString(Str: String);

implementation

uses
  Messages, SysUtils, CommCtrl, MultiMon, RegStr, MMSystem,
  DXUtil;

/////BAA: added from 'winuser.h'
const
  ENUM_CURRENT_SETTINGS         = DWORD(-1);

  PBT_APMSUSPEND                = $0004;
  PBT_APMSTANDBY                = $0005;

/////BAA: added from 'wingdi.h'
/////  Borland realisation in 'Windows.pas" doesn't contain 'dmPosition' field
type
  TDevModeSE = packed record
    dmDeviceName: array[0..CCHDEVICENAME - 1] of AnsiChar;
    dmSpecVersion: Word;
    dmDriverVersion: Word;
    dmSize: Word;
    dmDriverExtra: Word;
    dmFields: DWORD;
    dmPosition: TPointL; //BAA: field was added instead of commented fields 
   {dmOrientation: SHORT;
    dmPaperSize: SHORT;
    dmPaperLength: SHORT;
    dmPaperWidth: SHORT;}
    dmScale: SHORT;
    dmCopies: SHORT;
    dmDefaultSource: SHORT;
    dmPrintQuality: SHORT;
    dmColor: SHORT;
    dmDuplex: SHORT;
    dmYResolution: SHORT;
    dmTTOption: SHORT;
    dmCollate: SHORT;
    dmFormName: array[0..CCHFORMNAME - 1] of AnsiChar;
    dmLogPixels: Word;
    dmBitsPerPel: DWORD;
    dmPelsWidth: DWORD;
    dmPelsHeight: DWORD;
    dmDisplayFlags: DWORD;
    dmDisplayFrequency: DWORD;
    dmICMMethod: DWORD;
    dmICMIntent: DWORD;
    dmMediaType: DWORD;
    dmDitherType: DWORD;
    dmICCManufacturer: DWORD;
    dmICCModel: DWORD;
    dmPanningWidth: DWORD;
    dmPanningHeight: DWORD;
  end;

/////BAA: added from 'windowsx.h'
type
  // #define GET_X_LPARAM(lp)                        ((int)(short)LOWORD(lp))
  GET_X_LPARAM = ShortInt;

// #define GET_Y_LPARAM(lp)                        ((int)(short)HIWORD(lp))
function GET_Y_LPARAM(l: DWORD): Integer;
begin
  Result := ShortInt(HIWORD(l));
end;

///////////////////////////////////////////////////////////////
///// <QSort> algorithm implementation                   

procedure qsort_int(base: Pointer; width: Integer; compare: QSortCB; Left, Right: Integer; TempBuffer, TempBuffer2: Pointer);
var
  Lo, Hi: Integer;
  P: Pointer;
begin
  Lo := Left;
  Hi := Right;
  P := Pointer(Integer(base) + ((Lo + Hi) div 2)*width);
  Move(P^, TempBuffer2^, width);
  repeat
    while compare(Pointer(Integer(base) + Lo*width), TempBuffer2) < 0 do Inc(Lo);
    while compare(Pointer(Integer(base) + Hi*width), TempBuffer2) > 0 do Dec(Hi);
    if Lo <= Hi then
    begin
      Move(Pointer(Integer(base) + Lo*width)^, TempBuffer^,                        width);
      Move(Pointer(Integer(base) + Hi*width)^, Pointer(Integer(base) + Lo*width)^, width);
      Move(TempBuffer^,                        Pointer(Integer(base) + Hi*width)^, width);
      Inc(Lo);
      Dec(Hi);
    end;
  until Lo > Hi;

  if Hi > Left  then qsort_int(base, width, compare, Left, Hi,  TempBuffer, TempBuffer2);
  if Lo < Right then qsort_int(base, width, compare, Lo, Right, TempBuffer, TempBuffer2);
end;

procedure QSort(base: Pointer; num: Size_t; width: Size_t; compare: QSortCB);
var
  p, p1: Pointer;
begin
  GetMem(p, width);
  GetMem(p1, width);
  try
    qsort_int(base, width, compare, 0, num - 1, p, p1);
  finally
    FreeMem(p1, width);
    FreeMem(p, width);
  end;
end;


function EqualGUID(const G1, G2: TGUID): Boolean;
begin
  Result := CompareMem(@G1, @G2, SizeOf(TGUID));
end;

//-----------------------------------------------------------------------------
// File: D3DSaver.cpp
//
// Desc: Framework for screensavers that use Direct3D 8.0.
//
// Copyright (c) 2000-2001 Microsoft Corporation. All rights reserved.
//-----------------------------------------------------------------------------

//todo: Check this out
// #define COMPILE_MULTIMON_STUBS
// #include <multimon.h>

const
  // Resource IDs.  D3DSaver assumes that you will create resources with
  // these IDs that it can use.  The easiest way to do this is to copy
  // the resources from the rc file of an existing D3DSaver-based program.
  IDI_MAIN_ICON                  = 101;
  IDD_SINGLEMONITORSETTINGS      = 200;
  IDD_MULTIMONITORSETTINGS       = 201;

  IDC_MONITORSTAB                = 2000;
  IDC_TABNAMEFMT                 = 2001;
  IDC_ADAPTERNAME                = 2002;
  IDC_RENDERING                  = 2003;
  IDC_MOREINFO                   = 2004;
  IDC_DISABLEHW                  = 2005;
  IDC_SCREENUSAGEBOX             = 2006;
  IDC_RENDER                     = 2007;
  IDC_LEAVEBLACK                 = 2008;
  IDC_DISPLAYMODEBOX             = 2009;
  IDC_MODESSTATIC                = 2010;
  IDC_MODESCOMBO                 = 2011;
  IDC_AUTOMATIC                  = 2012;
  IDC_DISPLAYMODENOTE            = 2013;
  IDC_GENERALBOX                 = 2014;
  IDC_SAME                       = 2015;
  IDC_MODEFMT                    = 2016;

  IDS_ERR_GENERIC                = 2100;
  IDS_ERR_NODIRECT3D             = 2101;
  IDS_ERR_NOWINDOWEDHAL          = 2102;
  IDS_ERR_CREATEDEVICEFAILED     = 2103;
  IDS_ERR_NOCOMPATIBLEDEVICES    = 2104;
  IDS_ERR_NOHARDWAREDEVICE       = 2105;
  IDS_ERR_HALNOTCOMPATIBLE       = 2106;
  IDS_ERR_NOHALTHISMODE          = 2107;
  IDS_ERR_MEDIANOTFOUND          = 2108;
  IDS_ERR_RESIZEFAILED           = 2109;
  IDS_ERR_OUTOFMEMORY            = 2110;
  IDS_ERR_OUTOFVIDEOMEMORY       = 2111;
  IDS_ERR_NOPREVIEW              = 2112;

  IDS_INFO_GOODHAL               = 2200;
  IDS_INFO_BADHAL_GOODSW         = 2201;
  IDS_INFO_BADHAL_BADSW          = 2202;
  IDS_INFO_BADHAL_NOSW           = 2203;
  IDS_INFO_NOHAL_GOODSW          = 2204;
  IDS_INFO_NOHAL_BADSW           = 2205;
  IDS_INFO_NOHAL_NOSW            = 2206;
  IDS_INFO_DISABLEDHAL_GOODSW    = 2207;
  IDS_INFO_DISABLEDHAL_BADSW     = 2208;
  IDS_INFO_DISABLEDHAL_NOSW      = 2209;
  IDS_RENDERING_HAL              = 2210;
  IDS_RENDERING_SW               = 2211;
  IDS_RENDERING_NONE             = 2212;


type
  // Use the following structure rather than DISPLAY_DEVICE, since some old
  // versions of DISPLAY_DEVICE are missing the last two fields and this can
  // cause problems with EnumDisplayDevices on Windows 2000.
  TDisplayDeviceFull = packed record
    cb          : DWord;
    DeviceName  : array[0..31] of Char;
    DeviceString: array[0..137] of Char;
    StateFlags  : DWord;
    DeviceID    : array[0..127] of Char;
    DeviceKey   : array[0..127] of Char;
  end;
  DISPLAY_DEVICE_FULL = TDisplayDeviceFull;


var
  s_pD3DScreensaver: CD3DScreensaver = nil;

function SaverProcStub(hWnd: HWND; uMsg: LongWord; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; forward;


//-----------------------------------------------------------------------------
// CD3DScreensaver STUB procedures
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.DoConfig; begin end;
procedure CD3DScreensaver.ReadSettings; begin end;
procedure CD3DScreensaver.SetDevice(iDevice: LongWord); begin end;

function CD3DScreensaver.RegisterSoftwareDevice: HRESULT;    begin Result:= S_OK; end;
function CD3DScreensaver.ConfirmDevice(const pCaps: TD3DCaps8; dwBehavior: DWORD;
  fmtBackBuffer: TD3DFormat): HRESULT;
begin Result:= S_OK; end;

function CD3DScreensaver.ConfirmMode(pd3dDev: IDirect3DDevice8): HRESULT;   begin Result:= S_OK; end;
function CD3DScreensaver.OneTimeSceneInit: HRESULT;          begin Result:= S_OK; end;
function CD3DScreensaver.InitDeviceObjects: HRESULT;         begin Result:= S_OK; end;
function CD3DScreensaver.RestoreDeviceObjects: HRESULT;      begin Result:= S_OK; end;
function CD3DScreensaver.FrameMove: HRESULT;                 begin Result:= S_OK; end;
function CD3DScreensaver.Render: HRESULT;                    begin Result:= S_OK; end;
function CD3DScreensaver.InvalidateDeviceObjects: HRESULT;   begin Result:= S_OK; end;
function CD3DScreensaver.DeleteDeviceObjects: HRESULT;       begin Result:= S_OK; end;
function CD3DScreensaver.FinalCleanup: HRESULT;              begin Result:= S_OK; end;

//-----------------------------------------------------------------------------
// Name: CD3DScreensaver()
// Desc: Constructor
//-----------------------------------------------------------------------------
constructor CD3DScreensaver.Create;
begin
  s_pD3DScreensaver := Self;

  m_bCheckingSaverPassword := False;
  m_bIs9x := False;
  m_dwSaverMouseMoveCount := 0;
  m_hWndParent := 0;
  m_hPasswordDLL := 0;
  m_hWnd := 0;
  m_VerifySaverPassword := nil;
    
  m_bAllScreensSame := False;
  m_pD3D := nil;
  m_pd3dDevice := nil;
  m_bWindowed := False;
  m_bWaitForInputIdle := False;

  m_bErrorMode := FALSE;
  m_hrError := S_OK;
  m_szError[0] := #0;

  m_fFPS              := 0.0;
  m_strDeviceStats[0] := #0;
  m_strFrameStats[0]  := #0;

  // Note: clients should load a resource into m_strWindowTitle to localize this string
  lstrcpy(m_strWindowTitle, 'Screen Saver');
  m_bAllowRef := FALSE;
  m_bUseDepthBuffer := FALSE;
  m_bMultithreaded := FALSE;
  m_bOneScreenOnly := FALSE;
  m_strRegPath[0] := #0;
  m_dwMinDepthBits := 16;
  m_dwMinStencilBits := 0;
  m_SwapEffectFullscreen := D3DSWAPEFFECT_DISCARD;
  m_SwapEffectWindowed := D3DSWAPEFFECT_COPY_VSYNC;

  SetRectEmpty(m_rcRenderTotal);
  SetRectEmpty(m_rcRenderCurDevice);

  ZeroMemory(@m_Monitors, SizeOf(m_Monitors));
  m_dwNumMonitors := 0;

  ZeroMemory(@m_Adapters, SizeOf(m_Adapters));
  m_dwNumAdapters := 0;

  ZeroMemory(@m_RenderUnits, SizeOf(m_RenderUnits));
  m_dwNumRenderUnits := 0;

  m_fTime := 0.0;
end;

//-----------------------------------------------------------------------------
// Name: Create()
// Desc: Have the client program call this function before calling Run().
//-----------------------------------------------------------------------------
function CD3DScreensaver.Create_(hInstance: LongWord): HRESULT;
var
  pstrCmdLine: PChar;
  msg: TMsg;
  bCompatibleDeviceFound: Boolean;
  iAdapter: DWORD;
begin
  SetThreadPriority(GetCurrentThread, THREAD_PRIORITY_IDLE);

  m_hInstance := hInstance;

  // Parse the command line and do the appropriate thing
  pstrCmdLine := GetCommandLine;
  m_SaverMode := ParseCommandLine(pstrCmdLine);

  EnumMonitors;

  // Create the screen saver window(s)
  if (m_SaverMode = sm_preview) or
     (m_SaverMode = sm_test) or
     (m_SaverMode = sm_full) then
  begin
    Result:= CreateSaverWindow;
    if FAILED(Result) then
    begin
      m_bErrorMode := True;
      m_hrError := Result;
    end;
  end;

  if (m_SaverMode = sm_preview) then
  begin
    // In preview mode, "pause" (enter a limited message loop) briefly
    // before proceeding, so the display control panel knows to update itself.
    m_bWaitForInputIdle := True;

    // Post a message to mark the end of the initial group of window messages
    PostMessage(m_hWnd, WM_USER, 0, 0);

    while m_bWaitForInputIdle do
    begin
      // If GetMessage returns FALSE, it's quitting time.
      if not GetMessage(msg, m_hWnd, 0, 0) then
      begin
        // Post the quit message to handle it later
        PostQuitMessage(0);
        Break;
      end;

      TranslateMessage(msg);
      DispatchMessage(msg);
    end;
  end;

  // Create Direct3D object
  m_pD3D := Direct3DCreate8(D3D_SDK_VERSION);
  if (m_pD3D = nil) then
  begin
    m_bErrorMode := TRUE;
    m_hrError := D3DAPPERR_NODIRECT3D;
    Result:= S_OK;
    Exit;
  end;

  // Give the app the opportunity to register a pluggable SW D3D Device.
  Result := RegisterSoftwareDevice;
  if FAILED(Result) then
  begin
    m_bErrorMode := TRUE;
    m_hrError := Result;
    Result:= S_OK;
    Exit;
  end;

  // Build a list of Direct3D adapters, modes and devices. The
  // ConfirmDevice() callback is used to confirm that only devices that
  // meet the app's requirements are considered.
  Result := BuildDeviceList;
  if FAILED(Result) then
  begin
    m_bErrorMode := TRUE;
    m_hrError := Result;
    Result:= S_OK;
    Exit;
  end;

  // Make sure that at least one valid usable D3D device was found
  bCompatibleDeviceFound := FALSE;
  for iAdapter:= 0 to m_dwNumAdapters - 1 do 
  begin
    if (m_Adapters[iAdapter].bHasAppCompatHAL or
        m_Adapters[iAdapter].bHasAppCompatSW) then
    begin
      bCompatibleDeviceFound := TRUE;
      Break;
    end;
  end;
  if not bCompatibleDeviceFound then
  begin
    m_bErrorMode := TRUE;
    m_hrError := D3DAPPERR_NOCOMPATIBLEDEVICES;
    Result:= S_OK;
    Exit;
  end;

  // Read any settings we need
  ReadSettings;

  Result:= S_OK;
end;


//-----------------------------------------------------------------------------
// Name: EnumMonitors()
// Desc: Determine HMONITOR, desktop rect, and other info for each monitor.
//       Note that EnumDisplayDevices enumerates monitors in the order
//       indicated on the Settings page of the Display control panel, which
//       is the order we want to list monitors in, as opposed to the order
//       used by D3D's GetAdapterInfo.
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.EnumMonitors;
var
  iDevice: DWord;
  dispdev: TDisplayDeviceFull;
  dispdev2: TDisplayDeviceFull;
  devmode: TDevMode;
  pMonitorInfoNew: PMonitorInfo;
begin
  iDevice := 0;
  dispdev.cb := SizeOf(dispdev);
  dispdev2.cb := SizeOf(dispdev2);
  devmode.dmSize := SizeOf(devmode);
  devmode.dmDriverExtra := 0;
  while EnumDisplayDevices(nil, iDevice, PDisplayDevice(@dispdev)^, 0) do
  begin
    // Ignore NetMeeting's mirrored displays
    //todo: need to verify next line ??? - if Flag is set when NO mirrow drv ?
    if (dispdev.StateFlags and DISPLAY_DEVICE_MIRRORING_DRIVER) <> 0 then
    begin
      // To get monitor info for a display device, call EnumDisplayDevices
      // a second time, passing dispdev.DeviceName (from the first call) as
      // the first parameter.
      EnumDisplayDevices(@dispdev.DeviceName, 0, PDisplayDevice(@dispdev2)^, 0);

      pMonitorInfoNew := @m_Monitors[m_dwNumMonitors];
      ZeroMemory(pMonitorInfoNew, SizeOf(MonitorInfo));
      lstrcpy(@pMonitorInfoNew.strDeviceName, dispdev.DeviceString);
      lstrcpy(@pMonitorInfoNew.strMonitorName, dispdev2.DeviceString);
      pMonitorInfoNew.iAdapter := NO_ADAPTER;

      //todo: need to verify next line
      if (dispdev.StateFlags and DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) = 0 then 
      begin
        EnumDisplaySettings(dispdev.DeviceName, ENUM_CURRENT_SETTINGS, devmode);
        if (dispdev.StateFlags and DISPLAY_DEVICE_PRIMARY_DEVICE) <> 0 then
        begin
          // For some reason devmode.dmPosition is not always (0, 0)
          // for the primary display, so force it.
          pMonitorInfoNew.rcScreen.left := 0;
          pMonitorInfoNew.rcScreen.top := 0;
        end else
        begin
          pMonitorInfoNew.rcScreen.left := TDevModeSE(devmode).dmPosition.x;
          pMonitorInfoNew.rcScreen.top := TDevModeSE(devmode).dmPosition.y;
        end;
        pMonitorInfoNew.rcScreen.right := pMonitorInfoNew.rcScreen.left + Integer(devmode.dmPelsWidth);
        pMonitorInfoNew.rcScreen.bottom := pMonitorInfoNew.rcScreen.top + Integer(devmode.dmPelsHeight);
        pMonitorInfoNew.hMonitor := MonitorFromRect(@pMonitorInfoNew.rcScreen, MONITOR_DEFAULTTONULL);
with
pMonitorInfoNew^ do
OutputFileString(PChar(Format('Monitor From Rect (%dx%d - %dx%d) = %d',
 [rcScreen.left, rcScreen.top, rcScreen.right - rcScreen.left, rcScreen.bottom - rcScreen.top, pMonitorInfoNew.hMonitor])));
      end;
      Inc(m_dwNumMonitors);
      if (m_dwNumMonitors = MAX_DISPLAYS) then Break;
    end;
    Inc(iDevice);
  end;
end;


//-----------------------------------------------------------------------------
// Name: Run()
// Desc: Starts main execution of the screen saver.
//-----------------------------------------------------------------------------
function CD3DScreensaver.Run: Integer;
var
  hr: HRESULT;
  iAdapter: DWORD;
begin
  // Parse the command line and do the appropriate thing
  case m_SaverMode of
    sm_config:
    begin
      if m_bErrorMode
        then DisplayErrorMsg(m_hrError, MSG_NONE)
        else DoConfig;
    end;

    sm_preview,
    sm_test,
    sm_full:
    begin
      hr := DoSaver;
      if FAILED(hr) then
        DisplayErrorMsg(hr, MSG_NONE);
    end;

    sm_passwordchange:
      ChangePassword;
  end;

  for iAdapter:= 0 to m_dwNumAdapters - 1 do
    FreeMem(m_Adapters[iAdapter]);
  SAFE_RELEASE(m_pD3D);
  Result:= 0;
end;


//-----------------------------------------------------------------------------
// Name: ParseCommandLine()
// Desc: Interpret command-line parameters passed to this app.
//-----------------------------------------------------------------------------
function CD3DScreensaver.ParseCommandLine(pstrCommandLine: PChar): TSaverMode;
begin
  m_hWndParent := 0;

  // Skip the first part of the command line, which is the full path
  // to the exe.  If it contains spaces, it will be contained in quotes.
  if (pstrCommandLine^ = '"') then
  begin
    Inc(pstrCommandLine);
    while (pstrCommandLine^ <> #0) and (pstrCommandLine^ <> '"') do
      Inc(pstrCommandLine);
    if (pstrCommandLine = '"') then
      Inc(pstrCommandLine);
  end else
  begin
    while (pstrCommandLine^ <> #0) and (pstrCommandLine^ <> ' ') do
      Inc(pstrCommandLine);
    if (pstrCommandLine^ = ' ') then
      Inc(pstrCommandLine);
  end;

  // Skip along to the first option delimiter "/" or "-"
  while (pstrCommandLine^ <> #0) and (pstrCommandLine^ <> '/') and
        (pstrCommandLine^ <> '-') do
    Inc(pstrCommandLine);

  // If there wasn't one, then must be config mode
  if (pstrCommandLine^ = #0) then
  begin
    Result:= sm_config;
    Exit;
  end;

  // Otherwise see what the option was
  Inc(pstrCommandLine);
  case (pstrCommandLine^) of
    'c', 'C':
    begin
      Inc(pstrCommandLine);
      while (pstrCommandLine^ <> #0) and not (pstrCommandLine^ in ['0'..'9']) do
        Inc(pstrCommandLine);
      if (pstrCommandLine^ in ['0'..'9']) then
      begin
{$IFDEF WIN64}
        CHAR strCommandLine[2048];
        DXUtil_ConvertGenericStringToAnsi(strCommandLine, pstrCommandLine, 2048);
        m_hWndParent = HWND(_atoi64(strCommandLine));
{$ELSE}
        m_hWndParent := HWND(StrToInt(pstrCommandLine));
{$ENDIF}
      end else
      begin
        m_hWndParent := 0;
      end;
      Result:= sm_config;
    end;

    't', 'T':
      Result:= sm_test;

    'p', 'P':
    begin
      // Preview-mode, so option is followed by the parent HWND in decimal
      Inc(pstrCommandLine);
      while (pstrCommandLine^ <> #0) and not (pstrCommandLine^ in ['0'..'9']) do
        Inc(pstrCommandLine);
      if (pstrCommandLine^ in ['0'..'9']) then
      begin
{$IFDEF WIN64}
        CHAR strCommandLine[2048];
        DXUtil_ConvertGenericStringToAnsi(strCommandLine, pstrCommandLine, 2048);
        m_hWndParent = HWND(_atoi64(strCommandLine));
{$ELSE}
        m_hWndParent := HWND(StrToInt(pstrCommandLine));
{$ENDIF}
      end;
      Result:= sm_preview;
    end;

    'a', 'A':
    begin
      // Password change mode, so option is followed by parent HWND in decimal
      Inc(pstrCommandLine);
      while (pstrCommandLine^ <> #0) and not (pstrCommandLine^ in ['0'..'9']) do
        Inc(pstrCommandLine);
      if (pstrCommandLine^ in ['0'..'9']) then
      begin
{$IFDEF WIN64}
        CHAR strCommandLine[2048];
        DXUtil_ConvertGenericStringToAnsi(strCommandLine, pstrCommandLine, 2048);
        m_hWndParent = HWND(_atoi64(strCommandLine));
{$ELSE}
        m_hWndParent := HWND(StrToInt(pstrCommandLine));
{$ENDIF}
      end;
      Result:= sm_passwordchange;
    end;

   else
    // All other options => run the screensaver (typically this is "/s")
    Result:= sm_full;
  end;
end;


//-----------------------------------------------------------------------------
// Name: CreateSaverWindow
// Desc: Register and create the appropriate window(s)
//-----------------------------------------------------------------------------
function CD3DScreensaver.CreateSaverWindow: HRESULT;
var
  cls: TWndClass;
  rect: TRect;
  hwnd: Windows.HWND;

  rc: TRect;
  dwStyle: DWORD;
  iMonitor: DWORD;
  pMonitorInfo_: PMonitorInfo;
begin
(*
    // Uncomment this code to allow stepping thru code in the preview case
  if (m_SaverMode = sm_preview) then
  begin
    cls.hCursor        := 0;
    cls.hIcon          := 0;
    cls.lpszMenuName   := nil;
    cls.lpszClassName  := 'Parent';
    cls.hbrBackground  := HBRUSH(GetStockObject(WHITE_BRUSH));
    cls.hInstance      := m_hInstance;
    cls.style          := CS_VREDRAW or CS_HREDRAW or CS_SAVEBITS or CS_DBLCLKS;
    cls.lpfnWndProc    := @DefWindowProc;
    cls.cbWndExtra     := 0;
    cls.cbClsExtra     := 0;
    RegisterClass(cls);

    // Create the window
    rect.left := 40;
    rect.top := 40;
    rect.right := rect.left+200;
    rect.bottom := rect.top+200;
    AdjustWindowRect(rect, WS_VISIBLE or WS_OVERLAPPED or WS_CAPTION or WS_POPUP, FALSE);
    hwnd := CreateWindow('Parent', 'FakeShell',
        WS_VISIBLE or WS_OVERLAPPED or WS_CAPTION or WS_POPUP, rect.left, rect.top,
        rect.right-rect.left, rect.bottom-rect.top, 0,
        0, m_hInstance, nil);
    m_hWndParent := hwnd;
  end;
*)

  // Register an appropriate window class
  cls.hCursor        := LoadCursor(0, IDC_ARROW);
  cls.hIcon          := LoadIcon(m_hInstance, MAKEINTRESOURCE(IDI_MAIN_ICON));
  cls.lpszMenuName   := nil;
  cls.lpszClassName  := 'D3DSaverWndClass';
  cls.hbrBackground  := HBRUSH(GetStockObject(BLACK_BRUSH));
  cls.hInstance      := m_hInstance;
  cls.style          := CS_VREDRAW or CS_HREDRAW;
  cls.lpfnWndProc    := @SaverProcStub;
  cls.cbWndExtra     := 0;
  cls.cbClsExtra     := 0;
  RegisterClass(cls);

  // Create the window
  case m_SaverMode of
    sm_preview:
    begin
      GetClientRect(m_hWndParent, rc);
      dwStyle := WS_VISIBLE or WS_CHILD;
      AdjustWindowRect(rc, dwStyle, False);
      m_hWnd := CreateWindow('D3DSaverWndClass', m_strWindowTitle, dwStyle,
                             rc.left, rc.top, rc.right-rc.left, rc.bottom-rc.top,
                             m_hWndParent, 0, m_hInstance, Self);
      m_Monitors[0].hWnd := m_hWnd;
      GetClientRect(m_hWnd, m_rcRenderTotal);
      GetClientRect(m_hWnd, m_rcRenderCurDevice);
    end;

    sm_test:
    begin
      rc.left := 50;
      rc.top := 50;
      rc.right := rc.left+600;
      rc.bottom := rc.top+400;
      dwStyle := WS_VISIBLE or WS_OVERLAPPED or WS_CAPTION or WS_MINIMIZEBOX or WS_SYSMENU;
      AdjustWindowRect(rc, dwStyle, False);
OutputFileString(PChar(Format('Create test window (%dx%d - %dx%d)',
 [rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top])));
      m_hWnd := CreateWindow('D3DSaverWndClass', m_strWindowTitle, dwStyle,
                             rc.left, rc.top, rc.right-rc.left, rc.bottom-rc.top,
                             0, 0, m_hInstance, Self);
      m_Monitors[0].hWnd := m_hWnd;
      GetClientRect(m_hWnd, m_rcRenderTotal);
      GetClientRect(m_hWnd, m_rcRenderCurDevice);
    end;

    sm_full:
    begin
      // Create windows for each monitor.  Note that m_hWnd is NULL when CreateWindowEx
      // is called for the first monitor, so that window has no parent.  Windows for
      // additional monitors are created as children of the window for the first monitor.
      dwStyle := WS_VISIBLE or WS_POPUP;
      m_hWnd := 0;
      for iMonitor:= 0 to m_dwNumMonitors - 1 do
      begin
        pMonitorInfo_ := @m_Monitors[iMonitor];
        if (pMonitorInfo_.hMonitor = 0) then
          Continue;
        rc := pMonitorInfo_.rcScreen;
OutputFileString(PChar(Format('Create window (%dx%d - %dx%d) for iMonitor = %d',
 [rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top, iMonitor])));
        pMonitorInfo_.hWnd := CreateWindowEx(WS_EX_TOPMOST, 'D3DSaverWndClass',
          m_strWindowTitle, dwStyle, rc.left, rc.top, rc.right - rc.left,
          rc.bottom - rc.top, m_hWnd, 0, m_hInstance, Self);
OutputFileString(PChar(Format('Creatde window ID = %d',
 [pMonitorInfo_.hWnd])));
        if (pMonitorInfo_.hWnd = 0) then
        begin
          Result:= E_FAIL;
          Exit;
        end;
        if (m_hWnd = 0) then
          m_hWnd := pMonitorInfo_.hWnd;
      end;
    end;
  end;
  if (m_hWnd = 0) then
  begin
    Result:= E_FAIL;
    Exit;
  end;

  Result:= S_OK;
end;


//-----------------------------------------------------------------------------
// Name: DoSaver()
// Desc: Run the screensaver graphics - may be preview, test or full-on mode
//-----------------------------------------------------------------------------
function CD3DScreensaver.DoSaver: HRESULT;
var
  osvi: TOSVersionInfo;
  hKey_: HKEY;
  dwVal, dwSize: DWORD;
  bUnused: BOOL;
  bGotMsg: BOOL;
  msg: TMsg;
begin
  // Figure out if we're on Win9x
  osvi.dwOSVersionInfoSize := SizeOf(osvi);
  GetVersionEx(osvi);
  m_bIs9x := (osvi.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS);

  // If we're in full on mode, and on 9x, then need to load the password DLL
  if (m_SaverMode = sm_full) and m_bIs9x then
  begin
    // Only do this if the password is set - check registry:
    if RegOpenKey(HKEY_CURRENT_USER, REGSTR_PATH_SCREENSAVE, hKey_) = ERROR_SUCCESS then
    begin
      dwSize:= SizeOf(dwVal);

      if (RegQueryValueEx(hKey_, REGSTR_VALUE_USESCRPASSWORD, nil, nil,
                          @dwVal, @dwSize) = ERROR_SUCCESS) and (dwVal <> 0) then
      begin
        m_hPasswordDLL := LoadLibrary('PASSWORD.CPL');
        if m_hPasswordDLL <> 0 then
          m_VerifySaverPassword:= TVerifyWndProc(GetProcAddress(m_hPasswordDLL, 'VerifyScreenSavePwd'));
        RegCloseKey(hKey_);
      end;
    end;
  end;

  // Initialize the application timer
  DXUtil_Timer(TIMER_START);

  if not m_bErrorMode then
  begin
    // Initialize the app's custom scene stuff
    Result:= OneTimeSceneInit;
    if FAILED(Result) then
    begin
      Result:= DisplayErrorMsg(Result, MSGERR_APPMUSTEXIT);
      Exit;
    end;

    // Do graphical init stuff
    Result:= Initialize3DEnvironment;
    if FAILED(Result) then Exit;
  end;

  // Flag as screensaver running if in full on mode
  if (m_SaverMode = sm_full) then
  begin
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, iTRUE, @bUnused, 0);
  end;

  // Message pump
  msg.message := WM_NULL;
  while (msg.message <> WM_QUIT) do
  begin
    bGotMsg := PeekMessage(msg, 0, 0, 0, PM_REMOVE);
    if bGotMsg then
    begin
      TranslateMessage(msg);
      DispatchMessage(msg);
    end else
    begin
      Sleep(10);
      if m_bErrorMode
        then UpdateErrorBox
        else Render3DEnvironment;
    end;
  end;

  Result:= S_OK;
end;


//-----------------------------------------------------------------------------
// Name: ShutdownSaver()
// Desc:
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.ShutdownSaver;
var
  bUnused: BOOL;
begin
  // Unflag screensaver running if in full on mode
  if (m_SaverMode = sm_full) then
  begin
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, iFALSE, @bUnused, 0);
  end;

  // Kill graphical stuff
  Cleanup3DEnvironment();

  // Let client app clean up its resources
  FinalCleanup();

  // Unload the password DLL (if we loaded it)
  if (m_hPasswordDLL <> 0) then
  begin
    FreeLibrary(m_hPasswordDLL);
    m_hPasswordDLL := 0;
  end;

  // Post message to drop out of message loop
  PostQuitMessage(0);
end;


//-----------------------------------------------------------------------------
// Name: SaverProcStub()
// Desc: This function forwards all window messages to SaverProc, which has
//       access to the "this" pointer.
//-----------------------------------------------------------------------------
function SaverProcStub(hWnd: HWND; uMsg: LongWord; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; 
begin
  Result:= s_pD3DScreensaver.SaverProc(hWnd, uMsg, wParam, lParam);
end;


//-----------------------------------------------------------------------------
// Name: SaverProc()
// Desc: Handle window messages for main screensaver windows (one per screen).
//-----------------------------------------------------------------------------
function CD3DScreensaver.SaverProc(hWnd: HWND; uMsg: LongWord; wParam: WPARAM; lParam: LPARAM): LRESULT;
var
  ps: TPaintStruct;
  rc: TRect;
  iRenderUnit: Integer;
  pRenderUnit: ^RenderUnit;
  pD3DAdapterInfo: PTD3DAdapterInfo;
  xCur, yCur: Integer;
{$WRITEABLECONST ON}
const
  xPrev: Integer = -1;
  yPrev: Integer = -1;
{$WRITEABLECONST OFF}
begin
  case uMsg of
    WM_USER:
      // All initialization messages have gone through.  Allow
      // 500ms of idle time, then proceed with initialization.
      SetTimer(hWnd, 1, 500, nil);

    WM_TIMER:
    begin
      // Initial idle time is done, proceed with initialization.
      m_bWaitForInputIdle := FALSE;
      KillTimer(hWnd, 1);
    end;

    WM_DESTROY:
      if m_SaverMode in [sm_preview, sm_test] then
        ShutdownSaver;

    WM_SETCURSOR:
      if (m_SaverMode = sm_full) and not m_bCheckingSaverPassword then
      begin
        // Hide cursor
        SetCursor(0);
        Result:= iTRUE;
        Exit;
      end;

    WM_PAINT:
    begin
      // Show error message, if there is one
      BeginPaint(hWnd, ps);

      // In preview mode, just fill
      // the preview window with black.
      if not m_bErrorMode and (m_SaverMode = sm_preview) then
      begin
        GetClientRect(hWnd, rc);
        FillRect(ps.hdc, rc, HBRUSH(GetStockObject(BLACK_BRUSH)));
      end else
      begin
        DoPaint(hWnd, ps.hdc);
      end;

      EndPaint(hWnd, ps);
      Result:= 0;
      Exit;
    end;

    WM_ERASEBKGND:
      // Erase background if checking password or if window is not
      // assigned to a render unit
      if not m_bCheckingSaverPassword then
      begin
        for iRenderUnit:= 0 to Integer(m_dwNumRenderUnits) - 1 do
        begin
          pRenderUnit := @m_RenderUnits[iRenderUnit];
          pD3DAdapterInfo := m_Adapters[pRenderUnit.iAdapter];
          if (pD3DAdapterInfo.hWndDevice = hWnd) then
          begin
            Result:= iTRUE; // don't erase this window
            Exit;
          end;
        end;
      end;

    WM_MOUSEMOVE:
      if (m_SaverMode <> sm_test) then
      begin
        xCur := GET_X_LPARAM(lParam);
        yCur := GET_Y_LPARAM(lParam);
        if (xCur <> xPrev) or (yCur <> yPrev) then
        begin
          xPrev := xCur;
          yPrev := yCur;
          Inc(m_dwSaverMouseMoveCount);
          if (m_dwSaverMouseMoveCount > 5) then
            InterruptSaver;
        end;
      end;

    WM_KEYDOWN, WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN:
      if (m_SaverMode <> sm_test) then
        InterruptSaver;

    WM_ACTIVATEAPP:
      if (wParam = 0) and (m_SaverMode <> sm_test) then
        InterruptSaver;

    WM_POWERBROADCAST:
      if (wParam = PBT_APMSUSPEND) and (@m_VerifySaverPassword = nil) then
        InterruptSaver;

    WM_SYSCOMMAND:
      if (m_SaverMode = sm_full) then
      begin
        case wParam of
          SC_NEXTWINDOW,
          SC_PREVWINDOW,
          SC_SCREENSAVE,
          SC_CLOSE:
          begin
            Result:= iFALSE;
            Exit;
          end;
        end;
      end;
  end;

  Result:= DefWindowProc(hWnd, uMsg, wParam, lParam);
end;




//-----------------------------------------------------------------------------
// Name: InterruptSaver()
// Desc: A message was received (mouse move, keydown, etc.) that may mean
//       the screen saver should show the password dialog and/or shut down.
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.InterruptSaver;
var
  hr: HRESULT;
  iRenderUnit: DWORD;
  pRenderUnit: ^TRenderUnit;
  bPasswordOkay: Boolean;
  pD3DAdapterInfo: PTD3DAdapterInfo;
  iAdapter: DWORD;
begin
  // bPasswordOkay := FALSE; //BAA: Never used

OutputFileString('interrupt');
  if (m_SaverMode in [sm_test, sm_full]) and (not m_bCheckingSaverPassword) then
  begin
    if m_bIs9x and (m_SaverMode = sm_full) then
    begin
      // If no VerifyPassword function, then no password is set
      // or we're not on 9x.
      if (@m_VerifySaverPassword <> nil) then
      begin
        // Shut down all D3D devices so we can show a Windows dialog
OutputFileString(PChar(Format(':: m_dwNumRenderUnits = ', [m_dwNumRenderUnits])));
        for iRenderUnit:= 0 to m_dwNumRenderUnits - 1 do
        begin
          pRenderUnit := @m_RenderUnits[iRenderUnit];
          SwitchToRenderUnit(iRenderUnit);
          if pRenderUnit.bDeviceObjectsRestored then
          begin
            InvalidateDeviceObjects;
            pRenderUnit.bDeviceObjectsRestored := False;
          end;
          if pRenderUnit.bDeviceObjectsInited then
          begin
            DeleteDeviceObjects;
            pRenderUnit.bDeviceObjectsInited := False;
          end;
          SAFE_RELEASE(pRenderUnit.pd3dDevice);
        end;

        // Make sure all adapter windows cover the whole screen,
        // even after deleting D3D devices (which may have caused
        // mode changes)
        for iAdapter:= 0 to m_dwNumAdapters - 1 do
        begin
          pD3DAdapterInfo := m_Adapters[iAdapter];
          ShowWindow(pD3DAdapterInfo.hWndDevice, SW_RESTORE);
          ShowWindow(pD3DAdapterInfo.hWndDevice, SW_MAXIMIZE);
        end;

        m_bCheckingSaverPassword := TRUE;

        bPasswordOkay := m_VerifySaverPassword(m_hWnd);

        m_bCheckingSaverPassword := FALSE;

        if bPasswordOkay then
        begin
          // D3D devices are all torn down, so it's safe
          // to discard all render units now (so we don't
          // try to clean them up again later).
          m_dwNumRenderUnits := 0;
        end else
        begin
          // Back to screen saving...
          SetCursor(0);
          m_dwSaverMouseMoveCount := 0;

          // Recreate all D3D devices
          for iRenderUnit:= 0 to m_dwNumRenderUnits - 1 do
          begin
            pRenderUnit := @m_RenderUnits[iRenderUnit];
            hr := m_pD3D.CreateDevice(pRenderUnit.iAdapter,
                pRenderUnit.DeviceType, m_hWnd,
                pRenderUnit.dwBehavior, pRenderUnit.d3dpp,
                pRenderUnit.pd3dDevice);
            if FAILED(hr) then
            begin
              m_bErrorMode := True;
              m_hrError := D3DAPPERR_CREATEDEVICEFAILED;
            end else
            begin
              SwitchToRenderUnit(iRenderUnit);
              hr := InitDeviceObjects;
              if FAILED(hr) then
              begin
                m_bErrorMode := True;
                m_hrError := D3DAPPERR_INITDEVICEOBJECTSFAILED;
              end else
              begin
                pRenderUnit.bDeviceObjectsInited := True;
                hr := RestoreDeviceObjects;
                if FAILED(hr) then
                begin
                  m_bErrorMode := True;
                  m_hrError := D3DAPPERR_INITDEVICEOBJECTSFAILED;
                end else
                begin
                  pRenderUnit.bDeviceObjectsRestored := True;
                end;
              end;
            end;
          end;

          Exit;
        end;
      end;
    end;
    ShutdownSaver;
  end;
end;


//-----------------------------------------------------------------------------
// Name: Initialize3DEnvironment()
// Desc: Set up D3D device(s)
//-----------------------------------------------------------------------------
function CD3DScreensaver.Initialize3DEnvironment: HRESULT;
var
  hr: HRESULT;
  iAdapter, iMonitor: DWORD;
  pD3DAdapterInfo: PTD3DAdapterInfo;
  pMonitorInfo: ^TMonitorInfo;
  iRenderUnit: DWORD;
  pRenderUnit: ^TRenderUnit;
  monitorInfo: MultiMon.TMonitorInfo;
begin
  if (m_SaverMode = sm_full) then
  begin
    // Fullscreen mode.  Create a RenderUnit for each monitor (unless
    // the user wants it black)
    m_bWindowed := FALSE;

    if m_bOneScreenOnly then
    begin
      // Set things up to only create a RenderUnit on the best device
      for iAdapter:= 0 to m_dwNumAdapters - 1 do
      begin
        pD3DAdapterInfo := m_Adapters[iAdapter];
        pD3DAdapterInfo.bLeaveBlack := True;
      end;
      GetBestAdapter(iAdapter);
      if (iAdapter = NO_ADAPTER) then
      begin
        m_bErrorMode := True;
        m_hrError := D3DAPPERR_NOCOMPATIBLEDEVICES;
      end else
      begin
        pD3DAdapterInfo := m_Adapters[iAdapter];
        pD3DAdapterInfo.bLeaveBlack := False;
      end;
    end;

OutputFileString(PChar(Format('Initialize3DEnv m_dwNumMonitors = %d', [m_dwNumMonitors])));
    for iMonitor:= 0 to m_dwNumMonitors - 1 do
    begin
OutputFileString(PChar(Format('Initialize3DEnv iMonitor = %d', [iMonitor])));
      pMonitorInfo := @m_Monitors[iMonitor];
      iAdapter := pMonitorInfo.iAdapter;
      if (iAdapter = NO_ADAPTER) then
        Continue;
      pD3DAdapterInfo := m_Adapters[iAdapter];
      if (pD3DAdapterInfo.bDisableHW and not pD3DAdapterInfo.bHasAppCompatSW and
          not m_bAllowRef) then
      begin
        pD3DAdapterInfo.bLeaveBlack := True;
      end;
      if not pD3DAdapterInfo.bLeaveBlack and (pD3DAdapterInfo.dwNumDevices > 0) then
      begin
        pD3DAdapterInfo.hWndDevice := pMonitorInfo.hWnd;
        pRenderUnit := @m_RenderUnits[m_dwNumRenderUnits];
        Inc(m_dwNumRenderUnits);
        ZeroMemory(pRenderUnit, SizeOf(RenderUnit));
        pRenderUnit.iAdapter := iAdapter;
        hr := CreateFullscreenRenderUnit(pRenderUnit^);
        if FAILED(hr) then
        begin
          // skip this render unit and leave screen blank
          Dec(m_dwNumRenderUnits);
          m_bErrorMode := True;
          m_hrError := D3DAPPERR_CREATEDEVICEFAILED;
        end;
      end;
    end;
  end else
  begin
    // Windowed mode, for test mode or preview window.  Just need one RenderUnit.
    m_bWindowed := True;

    GetClientRect(m_hWnd, m_rcRenderTotal);
    GetClientRect(m_hWnd, m_rcRenderCurDevice);

    GetBestAdapter(iAdapter);
    if (iAdapter = NO_ADAPTER) then
    begin
      m_bErrorMode := True;
      m_hrError := D3DAPPERR_CREATEDEVICEFAILED;
    end else
    begin
      pD3DAdapterInfo := m_Adapters[iAdapter];
      pD3DAdapterInfo.hWndDevice := m_hWnd;
    end;
    if not m_bErrorMode then
    begin
      pRenderUnit := @m_RenderUnits[m_dwNumRenderUnits];
      Inc(m_dwNumRenderUnits);
      ZeroMemory(pRenderUnit, SizeOf(RenderUnit));
      pRenderUnit.iAdapter := iAdapter;
      hr := CreateWindowedRenderUnit(pRenderUnit^);
      if FAILED(hr) then
      begin
        Dec(m_dwNumRenderUnits);
        m_bErrorMode := True;
        if (m_SaverMode = sm_preview) then
          m_hrError := D3DAPPERR_NOPREVIEW
        else
          m_hrError := D3DAPPERR_CREATEDEVICEFAILED;
      end;
    end;
  end;

  // Once all mode changes are done, (re-)determine coordinates of all
  // screens, and make sure windows still cover each screen
  for iMonitor := 0 to m_dwNumMonitors - 1 do
  begin
    pMonitorInfo := @m_Monitors[iMonitor];
    monitorInfo.cbSize := SizeOf(TMonitorInfo);
    GetMonitorInfo(pMonitorInfo.hMonitor, @monitorInfo);
    pMonitorInfo.rcScreen := monitorInfo.rcMonitor;
    if not m_bWindowed then
    begin
      SetWindowPos(pMonitorInfo.hWnd, HWND_TOPMOST, monitorInfo.rcMonitor.left,
        monitorInfo.rcMonitor.top, monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left,
        monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top, SWP_NOACTIVATE);
    end;
  end;

  // For fullscreen, determine bounds of the virtual screen containing all
  // screens that are rendering.  Don't just use SM_XVIRTUALSCREEN, because
  // we don't want to count screens that are just black
  if not m_bWindowed then
  begin
    for iRenderUnit:= 0 to m_dwNumRenderUnits - 1 do
    begin
      pRenderUnit := @m_RenderUnits[iRenderUnit];
      pMonitorInfo := @m_Monitors[pRenderUnit.iMonitor];
      UnionRect(m_rcRenderTotal, m_rcRenderTotal, pMonitorInfo.rcScreen);
    end;
  end;

  if not m_bErrorMode then
  begin
    // Initialize D3D devices for all render units
    for iRenderUnit:= 0 to m_dwNumRenderUnits - 1 do
    begin
      pRenderUnit := @m_RenderUnits[iRenderUnit];
      SwitchToRenderUnit(iRenderUnit);
      hr := InitDeviceObjects;
      if FAILED(hr) then
      begin
        m_bErrorMode := TRUE;
        m_hrError := D3DAPPERR_INITDEVICEOBJECTSFAILED;
      end else
      begin
        pRenderUnit.bDeviceObjectsInited := True;
        hr := RestoreDeviceObjects;
        if FAILED(hr) then
        begin
          m_bErrorMode := True;
          m_hrError := D3DAPPERR_INITDEVICEOBJECTSFAILED;
        end else
        begin
          pRenderUnit.bDeviceObjectsRestored := True;
        end;
      end;
    end;
    UpdateDeviceStats;
  end;

  // Make sure all those display changes don't count as user mouse moves
  m_dwSaverMouseMoveCount := 0;

  Result:= S_OK;
end;




//-----------------------------------------------------------------------------
// Name: GetBestAdapter()
// Desc: To decide which adapter to use, loop through monitors until you find
//       one whose adapter has a compatible HAL.  If none, use the first
//       monitor that has an compatible SW device.
//-----------------------------------------------------------------------------
function CD3DScreensaver.GetBestAdapter(out piAdapter: DWORD): Boolean;
var
  iAdapterBest, iAdapter, iMonitor: DWORD;
  pMonitorInfo: ^TMonitorInfo;
  pD3DAdapterInfo: PTD3DAdapterInfo;
begin
  iAdapterBest := NO_ADAPTER;

  for iMonitor:= 0 to m_dwNumMonitors - 1 do
  begin
    pMonitorInfo := @m_Monitors[iMonitor];
    iAdapter := pMonitorInfo.iAdapter;
    if (iAdapter = NO_ADAPTER) then
      Continue;
    pD3DAdapterInfo := m_Adapters[iAdapter];
    if pD3DAdapterInfo.bHasAppCompatHAL then
    begin
      iAdapterBest := iAdapter;
      Break;
    end;
    if pD3DAdapterInfo.bHasAppCompatSW then
    begin
      iAdapterBest := iAdapter;
      // but keep looking...
    end;
  end;
  piAdapter := iAdapterBest;

  Result:= (iAdapterBest <> NO_ADAPTER);
end;




//-----------------------------------------------------------------------------
// Name: CreateFullscreenRenderUnit()
// Desc: 
//-----------------------------------------------------------------------------
function CD3DScreensaver.CreateFullscreenRenderUnit(var pRenderUnit: TRenderUnit): HRESULT;
var
  iAdapter: LongWord;
  pD3DAdapterInfo: PTD3DAdapterInfo;
  iMonitor: DWORD;
  pD3DDeviceInfo: ^TD3DDeviceInfo;
  pD3DModeInfo: ^TD3DModeInfo;
  dwCurrentDevice: DWORD;
  curType: TD3DDevType;
  iDevice, iMode: DWORD;

  bFound16BitMode: Boolean;
  dwSmallestHeight: DWORD;
  bMatchedSize, bGot32Bit: Boolean;

  dwWidthMax: DWORD;
  dwHeightMax: DWORD;
  dwBppMax: DWORD;
  dwWidthCur: DWORD;
  dwHeightCur: DWORD;
  dwBppCur: DWORD;

  bAtLeastOneFailure: Boolean;

  strKey: array[0..99] of Char;
  hkeyParent: HKEY;
  hkey_: HKEY;
begin
  Result:= S_OK;
  
  iAdapter := pRenderUnit.iAdapter;
  pD3DAdapterInfo := m_Adapters[iAdapter];
  iMonitor := pD3DAdapterInfo.iMonitor;

  if (iAdapter >= m_dwNumAdapters) then
  begin
    Result:= E_FAIL;
    Exit;
  end;

  if (pD3DAdapterInfo.dwNumDevices = 0) then
  begin
    Result:= E_FAIL;
    Exit;
  end;

  // Find the best device for the adapter.  Use HAL
  // if it's there, otherwise SW, otherwise REF.
  dwCurrentDevice := $ffff;
  curType := {D3DDEVTYPE_FORCE_DWORD} TD3DDevType(-1);
  for iDevice:= 0 to pD3DAdapterInfo.dwNumDevices - 1 do
  begin
    pD3DDeviceInfo := @pD3DAdapterInfo.devices[iDevice];
    if (pD3DDeviceInfo.DeviceType = D3DDEVTYPE_HAL) and
       not pD3DAdapterInfo.bDisableHW then
    begin
      dwCurrentDevice := iDevice;
      // curType := D3DDEVTYPE_HAL; //BAA: Never used
      Break; // stop looking
    end
    else if (pD3DDeviceInfo.DeviceType = D3DDEVTYPE_SW) then
    begin
      dwCurrentDevice := iDevice;
      curType := D3DDEVTYPE_SW;
      // but keep looking
    end
    else if (pD3DDeviceInfo.DeviceType = D3DDEVTYPE_REF) and
             m_bAllowRef and (curType <> D3DDEVTYPE_SW) then
    begin
      dwCurrentDevice := iDevice;
      curType := D3DDEVTYPE_REF;
      // but keep looking
    end;
  end;
  if (dwCurrentDevice = $ffff) then
  begin
    Result:= D3DAPPERR_NOHARDWAREDEVICE;
    Exit;
  end;
  pD3DDeviceInfo := @pD3DAdapterInfo.devices[dwCurrentDevice];

  pD3DDeviceInfo.dwCurrentMode := $ffff;
  if (pD3DAdapterInfo.dwUserPrefWidth <> 0) then
  begin
    // Try to find mode that matches user preference
    for iMode := 0 to pD3DDeviceInfo.dwNumModes - 1 do
    begin
      pD3DModeInfo := @pD3DDeviceInfo.modes[iMode];
      if (pD3DModeInfo.Width = pD3DAdapterInfo.dwUserPrefWidth) and
         (pD3DModeInfo.Height = pD3DAdapterInfo.dwUserPrefHeight) and
         (pD3DModeInfo.Format = pD3DAdapterInfo.d3dfmtUserPrefFormat) then
      begin
        pD3DDeviceInfo.dwCurrentMode := iMode;
        Break;
      end;
    end;
  end;

  // If user-preferred mode is not specified or not found,
  // use "Automatic" technique:
  if (pD3DDeviceInfo.dwCurrentMode = $ffff) then
  begin
    if (pD3DDeviceInfo.DeviceType = D3DDEVTYPE_SW) then
    begin
      // If using a SW rast then try to find a low resolution and 16-bpp.
      bFound16BitMode := False;
      dwSmallestHeight := 0; //BAA: was (-1) in original C++ source
      pD3DDeviceInfo.dwCurrentMode := 0; // unless we find something better

      for iMode:= 0 to pD3DDeviceInfo.dwNumModes - 1 do
      begin
        pD3DModeInfo := @pD3DDeviceInfo.modes[iMode];

        // Skip 640x400 because 640x480 is better
        if (pD3DModeInfo.Height = 400) then
          Continue;

        if (pD3DModeInfo.Height < dwSmallestHeight) or
           (pD3DModeInfo.Height = dwSmallestHeight) and not bFound16BitMode then
        begin
          dwSmallestHeight := pD3DModeInfo.Height;
          pD3DDeviceInfo.dwCurrentMode := iMode;
          bFound16BitMode := False;

          if (pD3DModeInfo.Format = D3DFMT_R5G6B5) or
             (pD3DModeInfo.Format = D3DFMT_X1R5G5B5) or
             (pD3DModeInfo.Format = D3DFMT_A1R5G5B5) or
             (pD3DModeInfo.Format = D3DFMT_A4R4G4B4) or
             (pD3DModeInfo.Format = D3DFMT_X4R4G4B4) then
          begin
            bFound16BitMode := True;
          end;
        end;
      end;
    end else
    begin
      // Try to find mode matching desktop resolution and 32-bpp.
      bMatchedSize := FALSE;
      bGot32Bit := FALSE;
      pD3DDeviceInfo.dwCurrentMode := 0; // unless we find something better
      for iMode:= 0 to pD3DDeviceInfo.dwNumModes - 1 do
      begin
        pD3DModeInfo := @pD3DDeviceInfo.modes[iMode];
        if (pD3DModeInfo.Width = pD3DAdapterInfo.d3ddmDesktop.Width) and
           (pD3DModeInfo.Height = pD3DAdapterInfo.d3ddmDesktop.Height) then
        begin
          if not bMatchedSize then
            pD3DDeviceInfo.dwCurrentMode := iMode;
          bMatchedSize := True;
          if not bGot32Bit and
             (pD3DModeInfo.Format = D3DFMT_X8R8G8B8)  or
             (pD3DModeInfo.Format = D3DFMT_A8R8G8B8) then
          begin
            pD3DDeviceInfo.dwCurrentMode := iMode;
            // bGot32Bit := True; //BAA: Never used
            Break;
          end;
        end;
      end;
    end;
  end;

  // If desktop mode not found, pick highest mode available
  if (pD3DDeviceInfo.dwCurrentMode = $ffff) then
  begin
    dwWidthMax := 0;
    dwHeightMax := 0;
    dwBppMax := 0;
    // dwWidthCur := 0;  //BAA: Never used
    // dwHeightCur := 0; //BAA: Never used
    // dwBppCur := 0;    //BAA: Never used
    for iMode:= 0 to pD3DDeviceInfo.dwNumModes - 1  do
    begin
      pD3DModeInfo := @pD3DDeviceInfo.modes[iMode];
      dwWidthCur := pD3DModeInfo.Width;
      dwHeightCur := pD3DModeInfo.Height;
      if (pD3DModeInfo.Format = D3DFMT_X8R8G8B8) or
         (pD3DModeInfo.Format = D3DFMT_A8R8G8B8) then
      begin
        dwBppCur := 32;
      end else
      begin
        dwBppCur := 16;
      end;
      if (dwWidthCur > dwWidthMax) or
         (dwHeightCur > dwHeightMax) or
         (dwWidthCur = dwWidthMax) and (dwHeightCur = dwHeightMax) and (dwBppCur > dwBppMax) then 
      begin
        dwWidthMax := dwWidthCur;
        dwHeightMax := dwHeightCur;
        dwBppMax := dwBppCur;
        pD3DDeviceInfo.dwCurrentMode := iMode;
      end;
    end;
  end;

  // Try to create the D3D device, falling back to lower-res modes if it fails
  bAtLeastOneFailure := FALSE;
  while True do
  begin
    pD3DModeInfo := @pD3DDeviceInfo.modes[pD3DDeviceInfo.dwCurrentMode];
    pRenderUnit.DeviceType := pD3DDeviceInfo.DeviceType;
    pRenderUnit.dwBehavior := pD3DModeInfo.dwBehavior;
    pRenderUnit.iMonitor := iMonitor;
    pRenderUnit.d3dpp.BackBufferFormat := pD3DModeInfo.Format;
    pRenderUnit.d3dpp.BackBufferWidth := pD3DModeInfo.Width;
    pRenderUnit.d3dpp.BackBufferHeight := pD3DModeInfo.Height;
    pRenderUnit.d3dpp.Windowed := FALSE;
    pRenderUnit.d3dpp.FullScreen_RefreshRateInHz := D3DPRESENT_RATE_DEFAULT;
    pRenderUnit.d3dpp.FullScreen_PresentationInterval := D3DPRESENT_INTERVAL_ONE;
    pRenderUnit.d3dpp.AutoDepthStencilFormat := pD3DModeInfo.DepthStencilFormat;
    pRenderUnit.d3dpp.BackBufferCount := 1;
    pRenderUnit.d3dpp.MultiSampleType := D3DMULTISAMPLE_NONE;
    pRenderUnit.d3dpp.SwapEffect := m_SwapEffectFullscreen;
    pRenderUnit.d3dpp.hDeviceWindow := pD3DAdapterInfo.hWndDevice;
    pRenderUnit.d3dpp.EnableAutoDepthStencil := m_bUseDepthBuffer;
    pRenderUnit.d3dpp.Flags := 0;

    // Create device
OutputFileString('Create FULLSCREEn RENDER UNIT');
    Result := m_pD3D.CreateDevice(iAdapter, pRenderUnit.DeviceType,
                                  m_hWnd, // (this is the focus window)
                                  pRenderUnit.dwBehavior, pRenderUnit.d3dpp,
                                  pRenderUnit.pd3dDevice);
    if SUCCEEDED(Result) then
    begin
      // Give the client app an opportunity to reject this mode
      // due to not enough video memory, or any other reason
      Result:= ConfirmMode(pRenderUnit.pd3dDevice);
      if SUCCEEDED(Result) then
        Break
      else
        SAFE_RELEASE(pRenderUnit.pd3dDevice);
    end;

    // If we get here, remember that CreateDevice or ConfirmMode failed, so
    // we can change the default mode next time
    bAtLeastOneFailure := TRUE;

    if not FindNextLowerMode(pD3DDeviceInfo^) then
      Break;
  end;

  if SUCCEEDED(Result) and bAtLeastOneFailure and (m_strRegPath[0] <> #0) then
  begin
    // Record the mode that succeeded in the registry so we can
    // default to it next time
    pD3DAdapterInfo.dwUserPrefWidth := pRenderUnit.d3dpp.BackBufferWidth;
    pD3DAdapterInfo.dwUserPrefHeight := pRenderUnit.d3dpp.BackBufferHeight;
    pD3DAdapterInfo.d3dfmtUserPrefFormat := pRenderUnit.d3dpp.BackBufferFormat;

    if (ERROR_SUCCESS = RegCreateKeyEx(HKEY_CURRENT_USER, m_strRegPath,
          0, nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nil, hkeyParent, nil)) then
    begin
      StrFmt(strKey, 'Screen %d', [iMonitor + 1]);
      if (ERROR_SUCCESS = RegCreateKeyEx(hkeyParent, strKey,
            0, nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nil, hkey_, nil)) then
      begin
        RegSetValueEx(hkey_, 'Width', 0, REG_DWORD,
          @pD3DAdapterInfo.dwUserPrefWidth, SizeOf(DWORD));
        RegSetValueEx(hkey_, 'Height', 0, REG_DWORD,
          @pD3DAdapterInfo.dwUserPrefHeight, SizeOf(DWORD));
        RegSetValueEx(hkey_, 'Format', 0, REG_DWORD,
          @pD3DAdapterInfo.d3dfmtUserPrefFormat, SizeOf(DWORD));
        RegSetValueEx(hkey_, 'Adapter ID', 0, REG_BINARY,
          @pD3DAdapterInfo.d3dAdapterIdentifier.DeviceIdentifier, SizeOf(TGUID));
        RegCloseKey(hkey_);
      end;
      RegCloseKey(hkeyParent);
    end;
  end;
end;


//-----------------------------------------------------------------------------
// Name: FindNextLowerMode()
// Desc:
//-----------------------------------------------------------------------------
function CD3DScreensaver.FindNextLowerMode(var pD3DDeviceInfo_: TD3DDeviceInfo): Boolean;
var
  iModeCur: DWORD;
  pD3DModeInfoCur: ^TD3DModeInfo;
  dwWidthCur, dwHeightCur, dwNumPixelsCur: DWORD;
  d3dfmtCur: TD3DFormat;
  b32BitCur: Boolean;
  iModeNew: DWORD;
  pD3DModeInfoNew: ^TD3DModeInfo;
  dwWidthNew, dwHeightNew, dwNumPixelsNew: DWORD;
  d3dfmtNew: TD3DFormat;
  b32BitNew: Boolean;

  {dwWidthBest, dwHeightBest, }dwNumPixelsBest: DWORD;
  b32BitBest: Boolean;
  iModeBest: DWORD;
begin
  iModeCur := pD3DDeviceInfo_.dwCurrentMode;
  pD3DModeInfoCur := @pD3DDeviceInfo_.modes[iModeCur];
  dwWidthCur := pD3DModeInfoCur.Width;
  dwHeightCur := pD3DModeInfoCur.Height;
  dwNumPixelsCur := dwWidthCur * dwHeightCur;
  d3dfmtCur := pD3DModeInfoCur.Format;
  b32BitCur := (d3dfmtCur = D3DFMT_A8R8G8B8) or
               (d3dfmtCur = D3DFMT_X8R8G8B8);
  // d3dfmtNew := D3DFMT_UNKNOWN; //BAA: Never used

  // dwWidthBest := 0;  //BAA: Never used
  // dwHeightBest := 0; //BAA: Never used
  dwNumPixelsBest := 0;
  b32BitBest := False;
  iModeBest := $ffff;

  for iModeNew:= 0 to pD3DDeviceInfo_.dwNumModes - 1 do
  begin
    // Don't pick the same mode we currently have
    if (iModeNew = iModeCur) then
      Continue;

    // Get info about new mode
    pD3DModeInfoNew := @pD3DDeviceInfo_.modes[iModeNew];
    dwWidthNew := pD3DModeInfoNew.Width;
    dwHeightNew := pD3DModeInfoNew.Height;
    dwNumPixelsNew := dwWidthNew * dwHeightNew;
    d3dfmtNew := pD3DModeInfoNew.Format;
    b32BitNew := (d3dfmtNew = D3DFMT_A8R8G8B8) or
                 (d3dfmtNew = D3DFMT_X8R8G8B8);

    // If we're currently 32-bit and new mode is same width/height and 16-bit, take it
    if b32BitCur and
       not b32BitNew and
       (pD3DModeInfoNew.Width = dwWidthCur) and
       (pD3DModeInfoNew.Height = dwHeightCur) then
    begin
      pD3DDeviceInfo_.dwCurrentMode := iModeNew;
      Result:= True;
      Exit;
    end;

    // If new mode is smaller than current mode, see if it's our best so far
    if (dwNumPixelsNew < dwNumPixelsCur) then
    begin
      // If current best is 32-bit, new mode needs to be bigger to be best
      if b32BitBest and (dwNumPixelsNew < dwNumPixelsBest) then
        Continue;

      // If new mode is bigger or equal to best, make it the best
      if (dwNumPixelsNew > dwNumPixelsBest) or
         (not b32BitBest and b32BitNew) then
      begin
        // dwWidthBest := dwWidthNew;   //BAA: Never used
        // dwHeightBest := dwHeightNew; //BAA: Never used
        dwNumPixelsBest := dwNumPixelsNew;
        iModeBest := iModeNew;
        b32BitBest := b32BitNew;
      end;
    end;
  end;
  if (iModeBest = $ffff) then
  begin
    Result:= False; // no smaller mode found
    Exit;
  end;
  pD3DDeviceInfo_.dwCurrentMode := iModeBest;
  Result:= True;
end;




//-----------------------------------------------------------------------------
// Name: CreateWindowedRenderUnit()
// Desc:
//-----------------------------------------------------------------------------
function CD3DScreensaver.CreateWindowedRenderUnit(var pRenderUnit: TRenderUnit): HRESULT;
var
  iAdapter: LongWord;
  pD3DAdapterInfo: PTD3DAdapterInfo;
  iMonitor: DWORD;
  pD3DDeviceInfo: ^TD3DDeviceInfo;
  curType: TD3DDevType;

  iDevice: DWORD;
  D3DWindowedModeInfo: TD3DWindowedModeInfo;
begin
  iAdapter := pRenderUnit.iAdapter;
  pD3DAdapterInfo := m_Adapters[iAdapter];
  iMonitor := pD3DAdapterInfo.iMonitor;

  // Find the best device for the primary adapter.  Use HAL
  // if it's there, otherwise SW, otherwise REF.
  pD3DAdapterInfo.dwCurrentDevice := $ffff; // unless we find something better
  curType := {D3DDEVTYPE_FORCE_DWORD} TD3DDevType(-1);
  for iDevice := 0 to pD3DAdapterInfo.dwNumDevices - 1 do
  begin
    pD3DDeviceInfo := @pD3DAdapterInfo.devices[iDevice];
    if (pD3DDeviceInfo.DeviceType = D3DDEVTYPE_HAL) and
       not pD3DAdapterInfo.bDisableHW and
       pD3DDeviceInfo.bCanDoWindowed then
    begin
      pD3DAdapterInfo.dwCurrentDevice := iDevice;
      //curType := D3DDEVTYPE_HAL; //BAA: Never used
      Break;
    end
    else if (pD3DDeviceInfo.DeviceType = D3DDEVTYPE_SW) and
            pD3DDeviceInfo.bCanDoWindowed then
    begin
      pD3DAdapterInfo.dwCurrentDevice := iDevice;
      curType := D3DDEVTYPE_SW;
      // but keep looking
    end
    else if (pD3DDeviceInfo.DeviceType = D3DDEVTYPE_REF) and m_bAllowRef and
            (curType <> D3DDEVTYPE_SW) then
    begin
      pD3DAdapterInfo.dwCurrentDevice := iDevice;
      curType := D3DDEVTYPE_REF;
      // but keep looking
    end;
  end;
  if (pD3DAdapterInfo.dwCurrentDevice = $ffff) then
  begin
    Result:= D3DAPPERR_NOHARDWAREDEVICE;
    Exit;
  end;
  pD3DDeviceInfo := @pD3DAdapterInfo.devices[pD3DAdapterInfo.dwCurrentDevice];

  D3DWindowedModeInfo.DisplayFormat := pD3DAdapterInfo.d3ddmDesktop.Format;
  D3DWindowedModeInfo.BackBufferFormat := pD3DAdapterInfo.d3ddmDesktop.Format;
  if FAILED(CheckWindowedFormat(iAdapter, D3DWindowedModeInfo)) then
  begin
    D3DWindowedModeInfo.BackBufferFormat := D3DFMT_A8R8G8B8;
    if FAILED(CheckWindowedFormat(iAdapter, D3DWindowedModeInfo)) then
    begin
      D3DWindowedModeInfo.BackBufferFormat := D3DFMT_X8R8G8B8;
      if FAILED(CheckWindowedFormat(iAdapter, D3DWindowedModeInfo)) then
      begin
        D3DWindowedModeInfo.BackBufferFormat := D3DFMT_A1R5G5B5;
        if FAILED(CheckWindowedFormat(iAdapter, D3DWindowedModeInfo)) then
        begin
          D3DWindowedModeInfo.BackBufferFormat := D3DFMT_R5G6B5;
          if FAILED(CheckWindowedFormat(iAdapter, D3DWindowedModeInfo)) then
          begin
            Result:= E_FAIL;
            Exit;
          end;
        end;
      end;
    end;
  end;

  pRenderUnit.DeviceType := pD3DDeviceInfo.DeviceType;
  pRenderUnit.dwBehavior := D3DWindowedModeInfo.dwBehavior;
  pRenderUnit.iMonitor := iMonitor;
  pRenderUnit.d3dpp.BackBufferWidth := 0;
  pRenderUnit.d3dpp.BackBufferHeight := 0;
  pRenderUnit.d3dpp.Windowed := TRUE;
  pRenderUnit.d3dpp.FullScreen_RefreshRateInHz := 0;
  pRenderUnit.d3dpp.FullScreen_PresentationInterval := 0;
  pRenderUnit.d3dpp.BackBufferFormat := D3DWindowedModeInfo.BackBufferFormat;
  pRenderUnit.d3dpp.AutoDepthStencilFormat := D3DWindowedModeInfo.DepthStencilFormat;
  pRenderUnit.d3dpp.BackBufferCount := 1;
  pRenderUnit.d3dpp.MultiSampleType := D3DMULTISAMPLE_NONE;
  pRenderUnit.d3dpp.SwapEffect := m_SwapEffectWindowed;
  pRenderUnit.d3dpp.hDeviceWindow := pD3DAdapterInfo.hWndDevice;
  pRenderUnit.d3dpp.EnableAutoDepthStencil := m_bUseDepthBuffer;
  pRenderUnit.d3dpp.Flags := 0;
  // Create device
OutputFileString('Create device with Windowed mode');
  Result := m_pD3D.CreateDevice(iAdapter, pRenderUnit.DeviceType, m_hWnd,
              pRenderUnit.dwBehavior, pRenderUnit.d3dpp, pRenderUnit.pd3dDevice);
  if FAILED(Result) then Exit;

  Result:= S_OK;
end;


//-----------------------------------------------------------------------------
// Name: UpdateDeviceStats()
// Desc: Store device description
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.UpdateDeviceStats;
var
  iRenderUnit: DWORD;
  pRenderUnit: ^TRenderUnit;

  szDescription: array[0..299] of Char;
begin
  for iRenderUnit:= 0 to m_dwNumRenderUnits - 1 do
  begin
    pRenderUnit := @m_RenderUnits[iRenderUnit];
    if pRenderUnit.DeviceType = D3DDEVTYPE_REF then
      lstrcpy(@pRenderUnit.strDeviceStats, 'REF')
    else if pRenderUnit.DeviceType = D3DDEVTYPE_HAL then
      lstrcpy(@pRenderUnit.strDeviceStats, 'HAL')
    else if pRenderUnit.DeviceType = D3DDEVTYPE_SW then
      lstrcpy(@pRenderUnit.strDeviceStats, 'SW');

    if (pRenderUnit.dwBehavior and D3DCREATE_HARDWARE_VERTEXPROCESSING <> 0) and
       (pRenderUnit.dwBehavior and D3DCREATE_PUREDEVICE <> 0) then
    begin
      if (pRenderUnit.DeviceType = D3DDEVTYPE_HAL) then
        lstrcat(@pRenderUnit.strDeviceStats, ' (pure hw vp)')
      else
        lstrcat(@pRenderUnit.strDeviceStats, ' (simulated pure hw vp)');
    end
    else if (pRenderUnit.dwBehavior and D3DCREATE_HARDWARE_VERTEXPROCESSING <> 0) then
    begin
      if (pRenderUnit.DeviceType = D3DDEVTYPE_HAL) then
        lstrcat(@pRenderUnit.strDeviceStats, ' (hw vp)')
      else
        lstrcat(@pRenderUnit.strDeviceStats, ' (simulated hw vp)');
    end
    else if (pRenderUnit.dwBehavior and D3DCREATE_MIXED_VERTEXPROCESSING <> 0) then
    begin
      if (pRenderUnit.DeviceType = D3DDEVTYPE_HAL) then
        lstrcat(@pRenderUnit.strDeviceStats, ' (mixed vp)')
      else
        lstrcat(@pRenderUnit.strDeviceStats, ' (simulated mixed vp)');
    end
    else if (pRenderUnit.dwBehavior and D3DCREATE_SOFTWARE_VERTEXPROCESSING <> 0) then
    begin
      lstrcat(@pRenderUnit.strDeviceStats, ' (sw vp)');
    end;

    if (pRenderUnit.DeviceType = D3DDEVTYPE_HAL) then
    begin
      lstrcat(@pRenderUnit.strDeviceStats, ': ');
      DXUtil_ConvertAnsiStringToGeneric(szDescription,
        m_Adapters[pRenderUnit.iAdapter].d3dAdapterIdentifier.Description, 300);
      lstrcat(@pRenderUnit.strDeviceStats, szDescription);
    end;
  end;
end;


//-----------------------------------------------------------------------------
// Name: SwitchToRenderUnit()
// Desc: Updates internal variables and notifies client that we are switching
//       to a new RenderUnit / D3D device.
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.SwitchToRenderUnit(iRenderUnit: LongWord);
var
  pRenderUnit: ^TRenderUnit;
  pMonitorInfo: ^TMonitorInfo;
  pBackBuffer: IDirect3DSurface8;
begin
  pRenderUnit := @m_RenderUnits[iRenderUnit];
  pMonitorInfo := @m_Monitors[pRenderUnit.iMonitor];

  m_pd3dDevice := pRenderUnit.pd3dDevice;
  if not m_bWindowed then
    m_rcRenderCurDevice := pMonitorInfo.rcScreen;

  if (m_pd3dDevice <> nil) then
  begin
    // Store render target surface desc
    m_pd3dDevice.GetBackBuffer(0, D3DBACKBUFFER_TYPE_MONO, pBackBuffer);
    pBackBuffer.GetDesc(m_d3dsdBackBuffer);
    pBackBuffer:= nil;
  end;

  lstrcpy(@m_strDeviceStats, @pRenderUnit.strDeviceStats);
  lstrcpy(@m_strFrameStats, @pRenderUnit.strFrameStats);

  // Notify the client to switch to this device
  SetDevice(iRenderUnit);
end;


//-----------------------------------------------------------------------------
// Name: BuildProjectionMatrix()
// Desc: This function sets up an appropriate projection matrix to support
//       rendering the appropriate parts of the scene to each screen.
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.BuildProjectionMatrix(fNear, fFar: Single; out pMatrix: TD3DXMatrix);
var
  mat: TD3DXMatrix;
  cx, cy: Integer;
  dx, dy: Integer;
  dd: Integer;
  l, r, t, b: Single;
begin
  if m_bAllScreensSame then
  begin
    cx := (m_rcRenderCurDevice.right + m_rcRenderCurDevice.left) div 2;
    cy := (m_rcRenderCurDevice.bottom + m_rcRenderCurDevice.top) div 2;
    dx := m_rcRenderCurDevice.right - m_rcRenderCurDevice.left;
    dy := m_rcRenderCurDevice.bottom - m_rcRenderCurDevice.top;
  end else
  begin
    cx := (m_rcRenderTotal.right + m_rcRenderTotal.left) div 2;
    cy := (m_rcRenderTotal.bottom + m_rcRenderTotal.top) div 2;
    dx := m_rcRenderTotal.right - m_rcRenderTotal.left;
    dy := m_rcRenderTotal.bottom - m_rcRenderTotal.top;
  end;

  if (dx > dy) then dd:= dy else dd:= dx;

  l := (m_rcRenderCurDevice.left   - cx) / dd;
  r := (m_rcRenderCurDevice.right  - cx) / dd;
  t := (m_rcRenderCurDevice.top    - cy) / dd;
  b := (m_rcRenderCurDevice.bottom - cy) / dd;

  l := fNear * l;
  r := fNear * r;
  t := fNear * t;
  b := fNear * b;

  D3DXMatrixPerspectiveOffCenterLH(mat, l, r, t, b, fNear, fFar);
  pMatrix:= mat;
end;


//-----------------------------------------------------------------------------
// Name: SetProjectionMatrix()
// Desc: This function sets up an appropriate projection matrix to support
//       rendering the appropriate parts of the scene to each screen.
//-----------------------------------------------------------------------------
function CD3DScreensaver.SetProjectionMatrix(fNear, fFar: Single): HRESULT;
var
  mat: TD3DXMatrix;
begin
  BuildProjectionMatrix(fNear, fFar, mat);
  Result:= m_pd3dDevice.SetTransform(D3DTS_PROJECTION, mat);
end;


//-----------------------------------------------------------------------------
// Name: SortModesCallback()
// Desc: Callback function for sorting display modes (used by BuildDeviceList).
//-----------------------------------------------------------------------------
function SortModesCallback(const arg1, arg2: Pointer): Integer;
var
  p1: PD3DDisplayMode;
  p2: PD3DDisplayMode;
begin
  p1 := arg1;
  p2 := arg2;

  if (p1^.Width  < p2^.Width)  then begin result:= -1; Exit; end;
  if (p1^.Width  > p2^.Width)  then begin result:= +1; Exit; end;
  if (p1^.Height < p2^.Height) then begin result:= -1; Exit; end;
  if (p1^.Height > p2^.Height) then begin result:= +1; Exit; end;
  if (p1^.Format > p2^.Format) then begin result:= -1; Exit; end;
  if (p1^.Format < p2^.Format) then begin result:= +1; Exit; end;

  Result:= 0;
end;


//-----------------------------------------------------------------------------
// Name: BuildDeviceList()
// Desc: Builds a list of all available adapters, devices, and modes.
//-----------------------------------------------------------------------------
function CD3DScreensaver.BuildDeviceList: HRESULT;
var
  dwNumDeviceTypes: DWORD;
const
  strDeviceDescs: array[0..2] of PChar = ('HAL', 'SW', 'REF');
  DeviceTypes: array[0..2] of TD3DDevType = (D3DDEVTYPE_HAL, D3DDEVTYPE_SW, D3DDEVTYPE_REF);
var
  hMonitor: {$I UseD3D8.inc}.HMONITOR;
  bHALExists,
  bHALIsWindowedCompatible,
  bHALIsDesktopCompatible{,
  bHALIsSampleCompatible}: Boolean; //BAA: Never used this time

  iAdapter: LongWord;
  pAdapter: PTD3DAdapterInfo;
  pMonitorInfo: ^TMonitorInfo;
  iMonitor: DWORD;

  modes: array[0..99] of TD3DDisplayMode;
  formats: array[0..19] of TD3DFormat;
  dwNumFormats, dwNumModes, dwNumAdapterModes: DWORD;

  iMode, iDevice: LongWord;
  DisplayMode: TD3DDisplayMode;
  m, f: DWORD;
  pDevice: PD3DDeviceInfo;

  bFormatConfirmed: array[0..19] of Boolean;
  dwBehavior: array[0..19] of DWORD;
  fmtDepthStencil: array[0..19] of TD3DFormat;
begin
  if m_bAllowRef then
    dwNumDeviceTypes := 3
  else
    dwNumDeviceTypes := 2;

  hMonitor := 0;
  bHALExists := FALSE;
  bHALIsWindowedCompatible := FALSE;
  bHALIsDesktopCompatible := FALSE;
  // bHALIsSampleCompatible := FALSE; //BAA: Never used this tim

  // Loop through all the adapters on the system (usually, there's just one
  // unless more than one graphics card is present).
  for iAdapter:= 0 to m_pD3D.GetAdapterCount - 1 do
  begin
    // Fill in adapter info
    if (m_Adapters[m_dwNumAdapters] = nil) then
    begin
      GetMem(m_Adapters[m_dwNumAdapters], SizeOf(TD3DAdapterInfo));
      {//In Delphi - EOutOfMemory exception will be raised on conditions below 
      if (m_Adapters[m_dwNumAdapters]:= nil)
      begin
        Result:= E_OUTOFMEMORY;
        Exit;
      end;
      }
      ZeroMemory(m_Adapters[m_dwNumAdapters], SizeOf(TD3DAdapterInfo));
    end;

    pAdapter := m_Adapters[m_dwNumAdapters];
    m_pD3D.GetAdapterIdentifier(iAdapter, D3DENUM_NO_WHQL_LEVEL, pAdapter.d3dAdapterIdentifier);
    m_pD3D.GetAdapterDisplayMode(iAdapter, pAdapter.d3ddmDesktop);
    pAdapter.dwNumDevices    := 0;
    pAdapter.dwCurrentDevice := 0;
    pAdapter.bLeaveBlack := FALSE;
    pAdapter.iMonitor := NO_MONITOR;

    // Find the MonitorInfo that corresponds to this adapter.  If the monitor
    // is disabled, the adapter has a NULL HMONITOR and we cannot find the
    // corresponding MonitorInfo.  (Well, if one monitor was disabled, we
    // could link the one MonitorInfo with a NULL HMONITOR to the one
    // D3DAdapterInfo with a NULL HMONITOR, but if there are more than one,
    // we can't link them, so it's safer not to ever try.)
    hMonitor := m_pD3D.GetAdapterMonitor(iAdapter);
    if (hMonitor <> 0) then
    begin
      for iMonitor:= 0 to m_dwNumMonitors - 1 do
      begin
        pMonitorInfo := @m_Monitors[iMonitor];
        if (pMonitorInfo.hMonitor = hMonitor) then
        begin
          pAdapter.iMonitor := iMonitor;
          pMonitorInfo.iAdapter := iAdapter;
          Break;
        end;
      end;
    end;

    // Enumerate all display modes on this adapter
    dwNumFormats      := 0;
    dwNumModes        := 0;
    dwNumAdapterModes := m_pD3D.GetAdapterModeCount(iAdapter);

    // Add the adapter's current desktop format to the list of formats
    formats[dwNumFormats] := pAdapter.d3ddmDesktop.Format;
    Inc(dwNumFormats);

    // for( UINT iMode = 0; iMode < dwNumAdapterModes; iMode++ )
    iMode := DWORD(0-1);
    while (iMode+1 < dwNumAdapterModes) do
    begin
      Inc(iMode);
      // Get the display mode attributes
      m_pD3D.EnumAdapterModes(iAdapter, iMode, DisplayMode);

      // Filter out low-resolution modes
      if (DisplayMode.Width < 640) or (DisplayMode.Height < 400) then
        Continue;

      // Check if the mode already exists (to filter out refresh rates)
      // for( DWORD m=0L; m<dwNumModes; m++ )
      m:= 0;
      while (m < dwNumModes) do
      begin
        if (modes[m].Width  = DisplayMode.Width ) and
           (modes[m].Height = DisplayMode.Height) and
           (modes[m].Format = DisplayMode.Format)
        then Break;
        Inc(m);
      end;

      // If we found a new mode, add it to the list of modes
      if (m = dwNumModes) then
      begin
        modes[dwNumModes].Width       := DisplayMode.Width;
        modes[dwNumModes].Height      := DisplayMode.Height;
        modes[dwNumModes].Format      := DisplayMode.Format;
        modes[dwNumModes].RefreshRate := 0;
        Inc(dwNumModes);

        // Check if the mode's format already exists
        for f:=0 to dwNumFormats - 1 do
        begin
          if (DisplayMode.Format = formats[f]) then
            Break;
        end;

        // If the format is new, add it to the list
        if (f = dwNumFormats) then
        begin
          formats[dwNumFormats] := DisplayMode.Format;
          Inc(dwNumFormats);
        end;
      end;
    end;

    // Sort the list of display modes (by format, then width, then height)
    QSort(@modes, dwNumModes, SizeOf(TD3DDisplayMode), SortModesCallback);

    // Add devices to adapter
    for iDevice:= 0 to dwNumDeviceTypes - 1 do
    begin
      // Fill in device info
      pDevice                := @pAdapter.devices[pAdapter.dwNumDevices];
      pDevice.DeviceType     := DeviceTypes[iDevice];
      m_pD3D.GetDeviceCaps(iAdapter, DeviceTypes[iDevice], pDevice.d3dCaps);
      pDevice.strDesc        := strDeviceDescs[iDevice];
      pDevice.dwNumModes     := 0;
      pDevice.dwCurrentMode  := 0;
      pDevice.bCanDoWindowed := FALSE;
      pDevice.bWindowed      := FALSE;
      pDevice.MultiSampleType := D3DMULTISAMPLE_NONE;

      // Examine each format supported by the adapter to see if it will
      // work with this device and meets the needs of the application.
      for f:= 0 to dwNumFormats - 1 do
      begin
        bFormatConfirmed[f] := FALSE;
        fmtDepthStencil[f] := D3DFMT_UNKNOWN;

        // Skip formats that cannot be used as render targets on this device
        Result:= m_pD3D.CheckDeviceType(iAdapter, pDevice.DeviceType,
                                        formats[f], formats[f], False);
        if FAILED(Result) then Continue;

        if (pDevice.DeviceType = D3DDEVTYPE_SW) then
        begin
          // This system has a SW device
          pAdapter.bHasSW := True;
        end;

        if (pDevice.DeviceType = D3DDEVTYPE_HAL) then
        begin
          // This system has a HAL device
          // bHALExists := True; //BAA: Never used
          pAdapter.bHasHAL := True;

          if (pDevice.d3dCaps.Caps2 and D3DCAPS2_CANRENDERWINDOWED <> 0) then
          begin
            // HAL can run in a window for some mode
            bHALIsWindowedCompatible := True;

            if (f = 0) then
            begin
              // HAL can run in a window for the current desktop mode
              bHALIsDesktopCompatible := True;
            end;
          end;
        end;

        // Confirm the device/format for HW vertex processing
        if (pDevice.d3dCaps.DevCaps and D3DDEVCAPS_HWTRANSFORMANDLIGHT <> 0) then
        begin
          if (pDevice.d3dCaps.DevCaps and D3DDEVCAPS_PUREDEVICE <> 0) then
          begin
            dwBehavior[f] := D3DCREATE_HARDWARE_VERTEXPROCESSING or
                             D3DCREATE_PUREDEVICE;

            Result := ConfirmDevice(pDevice.d3dCaps, dwBehavior[f], formats[f]);
            if SUCCEEDED(Result) then
              bFormatConfirmed[f] := True;
          end;

          if (FALSE = bFormatConfirmed[f]) then
          begin
            dwBehavior[f] := D3DCREATE_HARDWARE_VERTEXPROCESSING;

            Result := ConfirmDevice(pDevice.d3dCaps, dwBehavior[f], formats[f]);
            if SUCCEEDED(Result) then
              bFormatConfirmed[f] := True;
          end;

          if (FALSE = bFormatConfirmed[f]) then
          begin
            dwBehavior[f] := D3DCREATE_MIXED_VERTEXPROCESSING;

            Result := ConfirmDevice(pDevice.d3dCaps, dwBehavior[f], formats[f]);
            if SUCCEEDED(Result) then
              bFormatConfirmed[f] := True;
          end;
        end;

        // Confirm the device/format for SW vertex processing
        if (FALSE = bFormatConfirmed[f]) then
        begin
          dwBehavior[f] := D3DCREATE_SOFTWARE_VERTEXPROCESSING;

          Result:= ConfirmDevice(pDevice.d3dCaps, dwBehavior[f], formats[f]);
          if SUCCEEDED(Result) then
            bFormatConfirmed[f] := True;
        end;

        if bFormatConfirmed[f] and m_bMultithreaded then
        begin
          dwBehavior[f] := dwBehavior[f] or D3DCREATE_MULTITHREADED;
        end;

        // Find a suitable depth/stencil buffer format for this device/format
        if bFormatConfirmed[f] and m_bUseDepthBuffer then
        begin
          if not FindDepthStencilFormat(iAdapter, pDevice.DeviceType,
                   formats[f], fmtDepthStencil[f]) then
          begin
            bFormatConfirmed[f] := False;
          end;
        end;
      end;

      // Add all enumerated display modes with confirmed formats to the
      // device's list of valid modes
      // for( DWORD m=0L; m<dwNumModes; m++ )
      m:= 0;
      while (m < dwNumModes) do
      begin
        for f:= 0 to dwNumFormats - 1 do
        begin
          if (modes[m].Format = formats[f]) then
          begin
            if (bFormatConfirmed[f] = TRUE) then
            begin
              // Add this mode to the device's list of valid modes
              pDevice.modes[pDevice.dwNumModes].Width      := modes[m].Width;
              pDevice.modes[pDevice.dwNumModes].Height     := modes[m].Height;
              pDevice.modes[pDevice.dwNumModes].Format     := modes[m].Format;
              pDevice.modes[pDevice.dwNumModes].dwBehavior := dwBehavior[f];
              pDevice.modes[pDevice.dwNumModes].DepthStencilFormat := fmtDepthStencil[f];
              Inc(pDevice.dwNumModes);

              {if (pDevice.DeviceType = D3DDEVTYPE_HAL) then
                bHALIsSampleCompatible := True;} //BAA: Never used this tim
            end;
          end;
        end;
        Inc(m);
      end;

      // Select any 640x480 mode for default (but prefer a 16-bit mode)
      // for( m=0; m<pDevice->dwNumModes; m++ )
      m:= 0;
      while (m < pDevice.dwNumModes) do
      begin
        if (pDevice.modes[m].Width=640) and (pDevice.modes[m].Height=480) then
        begin
          pDevice.dwCurrentMode := m;
          if (pDevice.modes[m].Format = D3DFMT_R5G6B5) or
             (pDevice.modes[m].Format = D3DFMT_X1R5G5B5) or
             (pDevice.modes[m].Format = D3DFMT_A1R5G5B5) then
          begin
            Break;
          end;
        end;
        Inc(m);
      end;

      // Check if the device is compatible with the desktop display mode
      // (which was added initially as formats[0])
      if bFormatConfirmed[0] and (pDevice.d3dCaps.Caps2 and D3DCAPS2_CANRENDERWINDOWED <> 0) then
      begin
        pDevice.bCanDoWindowed := TRUE;
        pDevice.bWindowed      := TRUE;
      end;

      // If valid modes were found, keep this device
      if (pDevice.dwNumModes > 0) then
      begin
        Inc(pAdapter.dwNumDevices);
        if (pDevice.DeviceType = D3DDEVTYPE_SW) then
          pAdapter.bHasAppCompatSW := True
        else if (pDevice.DeviceType = D3DDEVTYPE_HAL) then
          pAdapter.bHasAppCompatHAL := True;
      end;
    end;

    // If valid devices were found, keep this adapter
// Count adapters even if no devices, so we can throw up blank windows on them
//  if (pAdapter.dwNumDevices > 0) then
      Inc(m_dwNumAdapters);
  end;
//BAA: Below is MS commented code  
(*
    // Return an error if no compatible devices were found
    if( 0L == m_dwNumAdapters )
        return D3DAPPERR_NOCOMPATIBLEDEVICES;

    // Pick a default device that can render into a window
    // (This code assumes that the HAL device comes before the REF
    // device in the device array).
    for( DWORD a=0; a<m_dwNumAdapters; a++ )
    {
        for( DWORD d=0; d < m_Adapters[a]->dwNumDevices; d++ )
        {
            if( m_Adapters[a]->devices[d].bWindowed )
            {
                m_Adapters[a]->dwCurrentDevice = d;
                m_dwAdapter = a;
                m_bWindowed = TRUE;

                // Display a warning message
                if( m_Adapters[a]->devices[d].DeviceType == D3DDEVTYPE_REF )
                {
                    if( !bHALExists )
                        DisplayErrorMsg( D3DAPPERR_NOHARDWAREDEVICE, MSGWARN_SWITCHEDTOREF );
                    else if( !bHALIsSampleCompatible )
                        DisplayErrorMsg( D3DAPPERR_HALNOTCOMPATIBLE, MSGWARN_SWITCHEDTOREF );
                    else if( !bHALIsWindowedCompatible )
                        DisplayErrorMsg( D3DAPPERR_NOWINDOWEDHAL, MSGWARN_SWITCHEDTOREF );
                    else if( !bHALIsDesktopCompatible )
                        DisplayErrorMsg( D3DAPPERR_NODESKTOPHAL, MSGWARN_SWITCHEDTOREF );
                    else // HAL is desktop compatible, but not sample compatible
                        DisplayErrorMsg( D3DAPPERR_NOHALTHISMODE, MSGWARN_SWITCHEDTOREF );
                }

                return S_OK;
            }
        }
    }
    return D3DAPPERR_NOWINDOWABLEDEVICES;
*)

  Result:= S_OK;
end;


//-----------------------------------------------------------------------------
// Name: CheckWindowedFormat()
// Desc:
//-----------------------------------------------------------------------------
function CD3DScreensaver.CheckWindowedFormat(iAdapter: LongWord; out pD3DWindowedModeInfo: TD3DWindowedModeInfo): HRESULT;
var
  pD3DAdapterInfo: PTD3DAdapterInfo;
  pD3DDeviceInfo: ^TD3DDeviceInfo;
  bFormatConfirmed: Boolean;
begin
  pD3DAdapterInfo := m_Adapters[iAdapter];
  pD3DDeviceInfo := @pD3DAdapterInfo.devices[pD3DAdapterInfo.dwCurrentDevice];
  bFormatConfirmed := FALSE;

  Result := m_pD3D.CheckDeviceType(iAdapter, pD3DDeviceInfo.DeviceType,
                                   pD3DAdapterInfo.d3ddmDesktop.Format,
                                   pD3DWindowedModeInfo.BackBufferFormat, True);
  if FAILED(Result) then Exit;

  // Confirm the device/format for HW vertex processing
  if (pD3DDeviceInfo.d3dCaps.DevCaps and D3DDEVCAPS_HWTRANSFORMANDLIGHT <> 0) then
  begin
    if (pD3DDeviceInfo.d3dCaps.DevCaps and D3DDEVCAPS_PUREDEVICE <> 0) then
    begin
      pD3DWindowedModeInfo.dwBehavior := D3DCREATE_HARDWARE_VERTEXPROCESSING or
                                         D3DCREATE_PUREDEVICE;

      if SUCCEEDED(ConfirmDevice(pD3DDeviceInfo.d3dCaps, pD3DWindowedModeInfo.dwBehavior,
                                 pD3DWindowedModeInfo.BackBufferFormat))
      then bFormatConfirmed := TRUE;
    end;

    if not bFormatConfirmed then
    begin
      pD3DWindowedModeInfo.dwBehavior := D3DCREATE_HARDWARE_VERTEXPROCESSING;

      if SUCCEEDED(ConfirmDevice(pD3DDeviceInfo.d3dCaps, pD3DWindowedModeInfo.dwBehavior,
                                 pD3DWindowedModeInfo.BackBufferFormat))
      then bFormatConfirmed := True;
    end;

    if not bFormatConfirmed then
    begin
      pD3DWindowedModeInfo.dwBehavior := D3DCREATE_MIXED_VERTEXPROCESSING;

      if SUCCEEDED(ConfirmDevice(pD3DDeviceInfo.d3dCaps, pD3DWindowedModeInfo.dwBehavior,
                                 pD3DWindowedModeInfo.BackBufferFormat))
      then bFormatConfirmed := True;
    end;
  end;

  // Confirm the device/format for SW vertex processing
  if not bFormatConfirmed then
  begin
    pD3DWindowedModeInfo.dwBehavior := D3DCREATE_SOFTWARE_VERTEXPROCESSING;

    if SUCCEEDED(ConfirmDevice(pD3DDeviceInfo.d3dCaps, pD3DWindowedModeInfo.dwBehavior,
                               pD3DWindowedModeInfo.BackBufferFormat))
    then bFormatConfirmed := TRUE;
  end;

  if bFormatConfirmed and m_bMultithreaded then
  begin
    with pD3DWindowedModeInfo do
      dwBehavior:= dwBehavior or D3DCREATE_MULTITHREADED;
  end;

  // Find a suitable depth/stencil buffer format for this device/format
  if bFormatConfirmed and m_bUseDepthBuffer then
  begin
    if not FindDepthStencilFormat(iAdapter, pD3DDeviceInfo.DeviceType,
                                  pD3DWindowedModeInfo.BackBufferFormat,
                                  pD3DWindowedModeInfo.DepthStencilFormat) then
    begin
      bFormatConfirmed := FALSE;
    end;
  end;

  if not bFormatConfirmed then
  begin
    Result:= E_FAIL;
    Exit;
  end;

  Result:= S_OK;
end;


//-----------------------------------------------------------------------------
// Name: FindDepthStencilFormat()
// Desc: Finds a depth/stencil format for the given device that is compatible
//       with the render target format and meets the needs of the app.
//-----------------------------------------------------------------------------
function CD3DScreensaver.FindDepthStencilFormat(iAdapter: LongWord; DeviceType: TD3DDevType;
  TargetFormat: TD3DFormat; var pDepthStencilFormat: TD3DFormat): Boolean;
begin
  if (m_dwMinDepthBits <= 16) and (m_dwMinStencilBits = 0) then
  begin
    if SUCCEEDED(m_pD3D.CheckDeviceFormat(iAdapter, DeviceType,
         TargetFormat, D3DUSAGE_DEPTHSTENCIL, D3DRTYPE_SURFACE, D3DFMT_D16)) then
    begin
      if SUCCEEDED(m_pD3D.CheckDepthStencilMatch(iAdapter, DeviceType,
           TargetFormat, TargetFormat, D3DFMT_D16)) then
      begin
        pDepthStencilFormat := D3DFMT_D16;
        Result:= True;
        Exit;
      end;
    end;
  end;

  if (m_dwMinDepthBits <= 15) and (m_dwMinStencilBits <= 1) then
  begin
    if SUCCEEDED( m_pD3D.CheckDeviceFormat(iAdapter, DeviceType,
         TargetFormat, D3DUSAGE_DEPTHSTENCIL, D3DRTYPE_SURFACE, D3DFMT_D15S1)) then
    begin
      if SUCCEEDED(m_pD3D.CheckDepthStencilMatch(iAdapter, DeviceType,
           TargetFormat, TargetFormat, D3DFMT_D15S1)) then
      begin
        pDepthStencilFormat := D3DFMT_D15S1;
        Result:= TRUE;
        Exit;
      end;
    end;
  end;

  if (m_dwMinDepthBits <= 24) and (m_dwMinStencilBits = 0) then
  begin
    if SUCCEEDED(m_pD3D.CheckDeviceFormat(iAdapter, DeviceType,
         TargetFormat, D3DUSAGE_DEPTHSTENCIL, D3DRTYPE_SURFACE, D3DFMT_D24X8)) then
    begin
      if SUCCEEDED(m_pD3D.CheckDepthStencilMatch(iAdapter, DeviceType,
           TargetFormat, TargetFormat, D3DFMT_D24X8)) then
      begin
        pDepthStencilFormat := D3DFMT_D24X8;
        Result:= TRUE;
        Exit;
      end;
    end;
  end;

  if (m_dwMinDepthBits <= 24) and (m_dwMinStencilBits <= 8) then
  begin
    if SUCCEEDED(m_pD3D.CheckDeviceFormat(iAdapter, DeviceType,
         TargetFormat, D3DUSAGE_DEPTHSTENCIL, D3DRTYPE_SURFACE, D3DFMT_D24S8)) then
    begin
      if SUCCEEDED(m_pD3D.CheckDepthStencilMatch(iAdapter, DeviceType,
           TargetFormat, TargetFormat, D3DFMT_D24S8)) then
      begin
        pDepthStencilFormat := D3DFMT_D24S8;
        Result:= TRUE;
        Exit;
      end;
    end;
  end;

  if (m_dwMinDepthBits <= 24) and (m_dwMinStencilBits <= 4) then
  begin
    if SUCCEEDED(m_pD3D.CheckDeviceFormat(iAdapter, DeviceType,
         TargetFormat, D3DUSAGE_DEPTHSTENCIL, D3DRTYPE_SURFACE, D3DFMT_D24X4S4)) then
    begin
      if SUCCEEDED(m_pD3D.CheckDepthStencilMatch(iAdapter, DeviceType,
           TargetFormat, TargetFormat, D3DFMT_D24X4S4)) then
      begin
        pDepthStencilFormat := D3DFMT_D24X4S4;
        Result:= TRUE;
        Exit;
      end;
    end;
  end;

  if (m_dwMinDepthBits <= 32) and (m_dwMinStencilBits = 0) then
  begin
    if SUCCEEDED(m_pD3D.CheckDeviceFormat(iAdapter, DeviceType,
         TargetFormat, D3DUSAGE_DEPTHSTENCIL, D3DRTYPE_SURFACE, D3DFMT_D32)) then
    begin
      if SUCCEEDED(m_pD3D.CheckDepthStencilMatch(iAdapter, DeviceType,
          TargetFormat, TargetFormat, D3DFMT_D32)) then
      begin
        pDepthStencilFormat := D3DFMT_D32;
        Result:= TRUE;
        Exit;
      end;
    end;
  end;

  Result:= FALSE;
end;


//-----------------------------------------------------------------------------
// Name: Cleanup3DEnvironment()
// Desc:
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.Cleanup3DEnvironment;
var
  pRenderUnit: ^TRenderUnit;
  iRenderUnit: DWORD;
begin
  for iRenderUnit:= 0 to m_dwNumRenderUnits - 1 do
  begin
    pRenderUnit := @m_RenderUnits[iRenderUnit];
    SwitchToRenderUnit(iRenderUnit);
    if pRenderUnit.bDeviceObjectsRestored then
    begin
      InvalidateDeviceObjects;
      pRenderUnit.bDeviceObjectsRestored := FALSE;
    end;
    if pRenderUnit.bDeviceObjectsInited then
    begin
      DeleteDeviceObjects;
      pRenderUnit.bDeviceObjectsInited := FALSE;
    end;
    SAFE_RELEASE(m_pd3dDevice);
  end;
  m_dwNumRenderUnits := 0;
  SAFE_RELEASE(m_pD3D);
end;


//-----------------------------------------------------------------------------
// Name: Render3DEnvironment()
// Desc: 
//-----------------------------------------------------------------------------
function CD3DScreensaver.Render3DEnvironment: HRESULT;
var
  pRenderUnit: ^TRenderUnit;
  pAdapterInfo: PTD3DAdapterInfo;

  iRenderUnit: DWORD;
begin
  m_fTime        := DXUtil_Timer(TIMER_GETAPPTIME);
  m_fElapsedTime := DXUtil_Timer(TIMER_GETELAPSEDTIME);

  // Tell client to update the world
  FrameMove;
  UpdateFrameStats;

  for iRenderUnit:= 0 to m_dwNumRenderUnits - 1 do
  begin
    pRenderUnit := @m_RenderUnits[iRenderUnit];
    pAdapterInfo := m_Adapters[pRenderUnit.iAdapter];

    SwitchToRenderUnit(iRenderUnit);

    if (m_pd3dDevice = nil) then
      Continue;

    // Test the cooperative level to see if it's okay to render
    Result := m_pd3dDevice.TestCooperativeLevel;
    if FAILED(Result) then
    begin
      // If the device was lost, do not render until we get it back
      if (D3DERR_DEVICELOST = Result) then
      begin
        Result:= S_OK;
        Exit;
      end;

      // Check if the device needs to be reset.
      if (D3DERR_DEVICENOTRESET = Result) then
      begin
        // If we are windowed, read the desktop mode and use the same format for
        // the back buffer
        if m_bWindowed then
        begin
          m_pD3D.GetAdapterDisplayMode(pRenderUnit.iAdapter, pAdapterInfo.d3ddmDesktop);
//        m_d3dpp.BackBufferFormat := pAdapterInfo.d3ddmDesktop.Format;
        end;

        if pRenderUnit.bDeviceObjectsRestored then
        begin
          InvalidateDeviceObjects;
          pRenderUnit.bDeviceObjectsRestored := False;
        end;
        Result := m_pd3dDevice.Reset(pRenderUnit.d3dpp);
        if FAILED(Result) then
        begin
          m_bErrorMode := True;
        end else
        begin
          Result := RestoreDeviceObjects;
          if FAILED(Result) then
          begin
            m_bErrorMode := True;
          end else
          begin
            pRenderUnit.bDeviceObjectsRestored := True;
          end;
        end;
      end;
    end;

    // Tell client to render using the current device
    Render;
  end;

  // Call Present() in a separate loop once all rendering is done
  // so multiple monitors are as closely synced visually as possible
  for iRenderUnit:= 0 to m_dwNumRenderUnits - 1 do
  begin
    // pRenderUnit := @m_RenderUnits[iRenderUnit]; //BAA: Never used
    SwitchToRenderUnit(iRenderUnit);
    // Present the results of the rendering to the screen
    m_pd3dDevice.Present(nil, nil, 0, nil);
  end;

  Result:= S_OK;
end;


//-----------------------------------------------------------------------------
// Name: UpdateErrorBox()
// Desc: Update the box that shows the error message
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.UpdateErrorBox;
{$WRITEABLECONST ON}
const
  dwTimeLast: DWORD = 0;
{$WRITEABLECONST OFF}
var
  pMonitorInfo: ^TMonitorInfo;
  hwnd: Windows.HWND;
  rcBounds: TRect;
  dwTimeNow: DWORD;
  fTimeDelta: Single;

  iMonitor: DWORD;

  rcOld, rcNew: TRect;
begin
  // Make sure all the RenderUnits / D3D devices have been torn down
  // so the error box is visible
  if m_bErrorMode and (m_dwNumRenderUnits > 0) then
  begin
    Cleanup3DEnvironment;
  end;

  // Update timing to determine how much to move error box
  if (dwTimeLast = 0) then
    dwTimeLast := timeGetTime;
  dwTimeNow := timeGetTime;
  fTimeDelta := (dwTimeNow - dwTimeLast) / 1000.0;
  dwTimeLast := dwTimeNow;

  // Load error string if necessary
  if (m_szError[0] = #0) then
  begin
    GetTextForError(m_hrError, @m_szError, SizeOf(m_szError) div SizeOf(Char));
  end;

  for iMonitor:= 0 to m_dwNumMonitors - 1 do
  begin
    pMonitorInfo := @m_Monitors[iMonitor];
    hwnd := pMonitorInfo.hWnd;
    if (hwnd = 0) then
      Continue;
    if (m_SaverMode = sm_full) then
    begin
      rcBounds := pMonitorInfo.rcScreen;
      //todo: Attention: this can be wrong translation
      // ScreenToClient( hwnd, (POINT*)&rcBounds.left );
      ScreenToClient(hwnd, rcBounds.TopLeft);
      //ScreenToClient( hwnd, (POINT*)&rcBounds.right );
      ScreenToClient(hwnd, rcBounds.BottomRight);
    end else
    begin
      rcBounds := m_rcRenderTotal;
    end;

    if (pMonitorInfo.widthError = 0) then
    begin
      if (m_SaverMode = sm_preview) then
      begin
        pMonitorInfo.widthError := (rcBounds.right - rcBounds.left);
        pMonitorInfo.heightError := (rcBounds.bottom - rcBounds.top);
        pMonitorInfo.xError := 0.0;
        pMonitorInfo.yError := 0.0;
        pMonitorInfo.xVelError := 0.0;
        pMonitorInfo.yVelError := 0.0;
        InvalidateRect(hwnd, nil, False);    // Invalidate the hwnd so it gets drawn
        UpdateWindow(hwnd);
      end else
      begin
        pMonitorInfo.widthError := 300;
        pMonitorInfo.heightError := 150;
        pMonitorInfo.xError := (rcBounds.right + rcBounds.left - pMonitorInfo.widthError) / 2.0;
        pMonitorInfo.yError := (rcBounds.bottom + rcBounds.top - pMonitorInfo.heightError) / 2.0;
        pMonitorInfo.xVelError := (rcBounds.right - rcBounds.left) / 10.0;
        pMonitorInfo.yVelError := (rcBounds.bottom - rcBounds.top) / 20.0;
      end;
    end else
    begin
      if (m_SaverMode <> sm_preview) then
      begin
        SetRect(rcOld, Round(pMonitorInfo.xError), Round(pMonitorInfo.yError),
            Round(pMonitorInfo.xError + pMonitorInfo.widthError),
            Round(pMonitorInfo.yError + pMonitorInfo.heightError));

        // Update rect velocity
        if ((pMonitorInfo.xError + pMonitorInfo.xVelError * fTimeDelta +
               pMonitorInfo.widthError > rcBounds.right) and
            (pMonitorInfo.xVelError > 0.0)) or
           ((pMonitorInfo.xError + pMonitorInfo.xVelError * fTimeDelta <
               rcBounds.left) and
            (pMonitorInfo.xVelError < 0.0)) then
        begin
          pMonitorInfo.xVelError := -pMonitorInfo.xVelError;
        end;
        if ((pMonitorInfo.yError + pMonitorInfo.yVelError * fTimeDelta +
               pMonitorInfo.heightError > rcBounds.bottom) and
             (pMonitorInfo.yVelError > 0.0) or
           ((pMonitorInfo.yError + pMonitorInfo.yVelError * fTimeDelta <
               rcBounds.top) and
            (pMonitorInfo.yVelError < 0.0))) then
        begin
          pMonitorInfo.yVelError := -pMonitorInfo.yVelError;
        end;
        // Update rect position
        pMonitorInfo.xError:= pMonitorInfo.xError + pMonitorInfo.xVelError * fTimeDelta;
        pMonitorInfo.yError:= pMonitorInfo.xError + pMonitorInfo.yVelError * fTimeDelta;

        SetRect(rcNew, Round(pMonitorInfo.xError), Round(pMonitorInfo.yError),
          Round(pMonitorInfo.xError + pMonitorInfo.widthError),
          Round(pMonitorInfo.yError + pMonitorInfo.heightError));

        if (rcOld.left <> rcNew.left) or (rcOld.top <> rcNew.top) then
        begin
          InvalidateRect(hwnd, @rcOld, False);    // Invalidate old rect so it gets erased
          InvalidateRect(hwnd, @rcNew, False);    // Invalidate new rect so it gets drawn
          UpdateWindow(hwnd);
        end;
      end;
    end;
  end;
end;


//-----------------------------------------------------------------------------
// Name: GetTextForError()
// Desc: Translate an HRESULT error code into a string that can be displayed
//       to explain the error.  A class derived from CD3DScreensaver can
//       provide its own version of this function that provides app-specific
//       error translation instead of or in addition to calling this function.
//       This function returns TRUE if a specific error was translated, or
//       FALSE if no specific translation for the HRESULT was found (though
//       it still puts a generic string into pszError).
//-----------------------------------------------------------------------------
function CD3DScreensaver.GetTextForError(hr: HRESULT; pszError: PChar; dwNumChars: DWORD): Boolean;
const
  dwErrorMap: array[0..12, 0..1] of HRESULT =
  (
    // HRESULT, stringID
    (E_FAIL, IDS_ERR_GENERIC),
    (D3DAPPERR_NODIRECT3D, IDS_ERR_NODIRECT3D),
    (D3DAPPERR_NOWINDOWEDHAL, IDS_ERR_NOWINDOWEDHAL),
    (D3DAPPERR_CREATEDEVICEFAILED, IDS_ERR_CREATEDEVICEFAILED),
    (D3DAPPERR_NOCOMPATIBLEDEVICES, IDS_ERR_NOCOMPATIBLEDEVICES),
    (D3DAPPERR_NOHARDWAREDEVICE, IDS_ERR_NOHARDWAREDEVICE),
    (D3DAPPERR_HALNOTCOMPATIBLE, IDS_ERR_HALNOTCOMPATIBLE),
    (D3DAPPERR_NOHALTHISMODE, IDS_ERR_NOHALTHISMODE),
    (D3DAPPERR_MEDIANOTFOUND, IDS_ERR_MEDIANOTFOUND),
    (D3DAPPERR_RESIZEFAILED, IDS_ERR_RESIZEFAILED),
    (E_OUTOFMEMORY, IDS_ERR_OUTOFMEMORY),
    (D3DERR_OUTOFVIDEOMEMORY, IDS_ERR_OUTOFVIDEOMEMORY),
    (D3DAPPERR_NOPREVIEW, IDS_ERR_NOPREVIEW)
  );

  dwErrorMapSize = SizeOf(dwErrorMap) div SizeOf(DWORD)*2;
var
  iError: DWORD;
  resid: DWORD;
begin
  resid:= 0;

  for iError := 0 to dwErrorMapSize - 1 do
  begin
    if (hr = dwErrorMap[iError][0]) then
    begin
      resid := dwErrorMap[iError][1];
    end;
  end;
  if (resid = 0) then
  begin
    resid := IDS_ERR_GENERIC;
  end;

  LoadString(0, resid, pszError, dwNumChars);

  if (resid = IDS_ERR_GENERIC) then
    Result:= FALSE
  else
    Result:= TRUE;
end;




//-----------------------------------------------------------------------------
// Name: UpdateFrameStats()
// Desc: Keep track of the frame count
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.UpdateFrameStats;
{$WRITEABLECONST ON}
const
  fLastTime: Single = 0.0;
  dwFrames: DWORD = 0;
{$WRITEABLECONST OFF}
var
  iRenderUnit: LongWord;
  pRenderUnit: ^TRenderUnit;
  iAdapter: LongWord;
  fTime: Single;
  mode: TD3DDisplayMode;
const
  Is32array: array[False..True] of Byte = (16, 32);  
var
  pAdapterInfo: PTD3DAdapterInfo;
  pDeviceInfo: ^TD3DDeviceInfo;
  pModeInfo: ^TD3DModeInfo;
begin
  fTime := DXUtil_Timer(TIMER_GETABSOLUTETIME);

  Inc(dwFrames);

  // Update the scene stats once per second
  if (fTime - fLastTime > 1.0) then
  begin
    m_fFPS    := dwFrames / (fTime - fLastTime);
    fLastTime := fTime;
    dwFrames  := 0;

    for iRenderUnit := 0 to m_dwNumRenderUnits - 1 do
    begin
      pRenderUnit := @m_RenderUnits[iRenderUnit];
      iAdapter := pRenderUnit.iAdapter;

      // Get adapter's current mode so we can report
      // bit depth (back buffer depth may be unknown)
      m_pD3D.GetAdapterDisplayMode(iAdapter, mode);

      StrFmt(@pRenderUnit.strFrameStats, '%.02f fps (%dx%dx%d)',
        [m_fFPS, mode.Width, mode.Height, Is32array[mode.Format=D3DFMT_X8R8G8B8]]);
      if m_bUseDepthBuffer then
      begin
        pAdapterInfo := m_Adapters[iAdapter];
        pDeviceInfo  := @pAdapterInfo.devices[pAdapterInfo.dwCurrentDevice];
        pModeInfo    := @pDeviceInfo.modes[pDeviceInfo.dwCurrentMode];

        case pModeInfo.DepthStencilFormat of
          D3DFMT_D16:
            lstrcat(@pRenderUnit.strFrameStats, ' (D16)');
          D3DFMT_D15S1:
            lstrcat(@pRenderUnit.strFrameStats, ' (D15S1)');
           D3DFMT_D24X8:
            lstrcat(@pRenderUnit.strFrameStats, ' (D24X8)');
           D3DFMT_D24S8:
            lstrcat(@pRenderUnit.strFrameStats, ' (D24S8)');
           D3DFMT_D24X4S4:
            lstrcat(@pRenderUnit.strFrameStats, ' (D24X4S4)');
           D3DFMT_D32:
            lstrcat(@pRenderUnit.strFrameStats, ' (D32)');
        end;
      end;
    end;
  end;
end;




//-----------------------------------------------------------------------------
// Name: DoPaint()
// Desc: 
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.DoPaint(hwnd: HWND; hdc: HDC);
var
  hMonitor: {$I UseD3D8.inc}.HMONITOR;
  pMonitorInfo: ^TMonitorInfo;
  iMonitor: DWORD;
  rc, rc2: TRect;
  height: Integer;
begin
  pMonitorInfo:= nil;
  hMonitor := MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  for iMonitor := 0 to m_dwNumMonitors - 1 do
  begin
    pMonitorInfo := @m_Monitors[iMonitor];
    if (pMonitorInfo.hMonitor = hMonitor) then
      Break;
  end;
  Assert(Assigned(pMonitorInfo));

  if (iMonitor = m_dwNumMonitors) then Exit;

  // Draw the error message box
  SetRect(rc, Round(pMonitorInfo.xError), Round(pMonitorInfo.yError),
      Round(pMonitorInfo.xError + pMonitorInfo.widthError),
      Round(pMonitorInfo.yError + pMonitorInfo.heightError));
  FillRect(hdc, rc, HBRUSH(COLOR_WINDOW+1));
  FrameRect(hdc, rc, HBRUSH(GetStockObject(BLACK_BRUSH)));
  rc2 := rc;
  height := DrawText(hdc, m_szError, -1, rc, DT_WORDBREAK or DT_CENTER or DT_CALCRECT);
  rc := rc2;

  rc2.top := (rc.bottom + rc.top - height) div 2;

  DrawText(hdc, m_szError, -1, rc2, DT_WORDBREAK or DT_CENTER);

  // Erase everywhere except the error message box
  ExcludeClipRect(hdc, rc.left, rc.top, rc.right, rc.bottom);
  rc := pMonitorInfo.rcScreen;
  //todo: Attention: this can be wrong translation
  // ScreenToClient(hwnd, (POINT*)@rc.left);
  ScreenToClient(hwnd, rc.TopLeft);
  ScreenToClient(hwnd, rc.BottomRight);
  FillRect(hdc, rc, HBRUSH(GetStockObject(BLACK_BRUSH)));
end;


//-----------------------------------------------------------------------------
// Name: ChangePassword()
// Desc:
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.ChangePassword;
type
  PWCHGPROC = function (s: PChar; hWnd: HWND; p1: DWORD; p2: Pointer): DWORD; pascal;
var
  mpr: HModule;
  pwd: PWCHGPROC;
begin
  // Load the password change DLL
  mpr := LoadLibrary('MPR.DLL');

  if (mpr <> 0) then
  begin
    // Grab the password change function from it
    pwd:= PWCHGPROC(GetProcAddress(mpr, 'PwdChangePasswordA'));

    // Do the password change
    if (@pwd <> nil) then
      pwd('SCRSAVE', m_hWndParent, 0, nil);

    // Free the library
    FreeLibrary(mpr);
  end;
end;


//-----------------------------------------------------------------------------
// Name: DisplayErrorMsg()
// Desc: Displays error messages in a message box
//-----------------------------------------------------------------------------
function CD3DScreensaver.DisplayErrorMsg(hr: HRESULT; dwType: TAppMsgType = MSG_NONE): HRESULT;
var
  strMsg: array[0..511] of Char;
begin
  GetTextForError(hr, strMsg, 512);

  MessageBox(m_hWnd, strMsg, m_strWindowTitle, MB_ICONERROR or MB_OK);

  Result:= hr;
end;


//-----------------------------------------------------------------------------
// Name: ReadScreenSettings()
// Desc: Read the registry settings that affect how the screens are set up and
//       used.
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.ReadScreenSettings(hkeyParent: HKEY);
var
  strKey: array[0..99] of Char;
  iMonitor, iAdapter: DWORD;
  pMonitorInfo: ^TMonitorInfo;
  pD3DAdapterInfo: PTD3DAdapterInfo;
  hkey: Windows.HKEY;
  dwType, dwLength, dwLength2: DWORD;
  guidAdapterID, guidZero: TGUID;
begin
  dwType := REG_DWORD;
  dwLength := SizeOf(DWORD);
  dwLength2 := SizeOf(TGUID);
  ZeroMemory(@guidAdapterID, SizeOf(TGUID));
  ZeroMemory(@guidZero, SizeOf(TGUID));

  RegQueryValueEx(hkeyParent, 'AllScreensSame', nil, @dwType,
      @m_bAllScreensSame, @dwLength);
  for iMonitor := 0 to m_dwNumMonitors - 1 do
  begin
    pMonitorInfo := @m_Monitors[iMonitor];
    iAdapter := pMonitorInfo.iAdapter;
    if (iAdapter = NO_ADAPTER) then
      Continue; 
    pD3DAdapterInfo := m_Adapters[iAdapter];
    StrFmt(@strKey, 'Screen %d', [iMonitor + 1]);
    if (ERROR_SUCCESS = RegCreateKeyEx(hkeyParent, strKey,
          0, nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nil, hkey, nil)) then
    begin
      RegQueryValueEx(hkey, 'Adapter ID', nil, @dwType,
        @guidAdapterID, @dwLength2);

      RegQueryValueEx(hkey, 'Leave Black', nil, @dwType,
        @pD3DAdapterInfo.bLeaveBlack, @dwLength);

      if EqualGUID(guidAdapterID, pD3DAdapterInfo.d3dAdapterIdentifier.DeviceIdentifier) or
         EqualGUID(guidAdapterID, guidZero) then
      begin
        RegQueryValueEx(hkey, 'Disable Hardware', nil, @dwType,
          @pD3DAdapterInfo.bDisableHW, @dwLength);
        RegQueryValueEx(hkey, 'Width', nil, @dwType,
          @pD3DAdapterInfo.dwUserPrefWidth, @dwLength);
        RegQueryValueEx(hkey, 'Height', nil, @dwType,
          @pD3DAdapterInfo.dwUserPrefHeight, @dwLength);
        RegQueryValueEx(hkey, 'Format', nil, @dwType,
          @pD3DAdapterInfo.d3dfmtUserPrefFormat, @dwLength);
      end;
      RegCloseKey(hkey);
    end;
  end;
end;


//-----------------------------------------------------------------------------
// Name: WriteScreenSettings()
// Desc: Write the registry settings that affect how the screens are set up and
//       used.
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.WriteScreenSettings(hkeyParent: HKEY);
var
  strKey: array[0..99] of Char;
  iMonitor, iAdapter: DWORD;
  pMonitorInfo: ^TMonitorInfo;
  pD3DAdapterInfo: PTD3DAdapterInfo;
  hkey: WIndows.HKEY;
begin
  RegSetValueEx(hkeyParent, 'AllScreensSame', 0, REG_DWORD,
    @m_bAllScreensSame, SizeOf(DWORD));
  for iMonitor:= 0 to m_dwNumMonitors - 1 do
  begin
    pMonitorInfo := @m_Monitors[iMonitor];
    iAdapter := pMonitorInfo.iAdapter;
    if (iAdapter = NO_ADAPTER) then
      Continue;
    pD3DAdapterInfo := m_Adapters[iAdapter];
    StrFmt(@strKey, 'Screen %d', [iMonitor + 1]);
    if (ERROR_SUCCESS = RegCreateKeyEx(hkeyParent, strKey,
          0, nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nil, hkey, nil)) then
    begin
      RegSetValueEx(hkey, 'Leave Black', 0, REG_DWORD,
        @pD3DAdapterInfo.bLeaveBlack, SizeOf(DWORD));
      RegSetValueEx(hkey, 'Disable Hardware', 0, REG_DWORD,
        @pD3DAdapterInfo.bDisableHW, SizeOf(DWORD));
      RegSetValueEx(hkey, 'Width', 0, REG_DWORD,
        @pD3DAdapterInfo.dwUserPrefWidth, SizeOf(DWORD));
      RegSetValueEx(hkey, 'Height', 0, REG_DWORD,
        @pD3DAdapterInfo.dwUserPrefHeight, SizeOf(DWORD));
      RegSetValueEx(hkey, 'Format', 0, REG_DWORD,
        @pD3DAdapterInfo.d3dfmtUserPrefFormat, SizeOf(DWORD));
      RegSetValueEx(hkey, 'Adapter ID', 0, REG_BINARY,
        @pD3DAdapterInfo.d3dAdapterIdentifier.DeviceIdentifier, SizeOf(TGUID));
      RegCloseKey( hkey);
    end;
  end;
end;


function ScreenSettingsDlgProcStub(hWnd: HWND; uMsg: LongWord; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; forward;
//-----------------------------------------------------------------------------
// Name: DoScreenSettingsDialog()
// Desc:
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.DoScreenSettingsDialog(hwndParent: HWND);
var
  pstrTemplate: PChar;
begin
  if (m_dwNumAdapters > 1) and not m_bOneScreenOnly then
    pstrTemplate := MAKEINTRESOURCE(IDD_MULTIMONITORSETTINGS)
  else
    pstrTemplate := MAKEINTRESOURCE(IDD_SINGLEMONITORSETTINGS);

  DialogBox(m_hInstance, pstrTemplate, hwndParent, @ScreenSettingsDlgProcStub);
end;

//-----------------------------------------------------------------------------
// Name: ScreenSettingsDlgProcStub()
// Desc:
//-----------------------------------------------------------------------------
function ScreenSettingsDlgProcStub(hWnd: HWND; uMsg: LongWord; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  Result:= s_pD3DScreensaver.ScreenSettingsDlgProc(hWnd, uMsg, wParam, lParam);
end;

// We need to store a copy of the original screen settings so that the user
// can modify those settings in the dialog, then hit Cancel and have the
// original settings restored.
var
  s_AdaptersSave: array[0..8] of PTD3DAdapterInfo;
  s_bAllScreensSameSave: Boolean;

//-----------------------------------------------------------------------------
// Name: ScreenSettingsDlgProc()
// Desc:
//-----------------------------------------------------------------------------
function CD3DScreensaver.ScreenSettingsDlgProc(hWnd: HWND; uMsg: LongWord; wParam: WPARAM; lParam: LPARAM): LRESULT;
var
  hwndTabs: Windows.HWND;
  hwndModeList: Windows.HWND;
  iMonitor, iAdapter: DWORD;
  pMonitorInfo: ^TMonitorInfo;

  i: Integer;
  tie: TC_ITEM;
  szFmt, sz: array[0..99] of Char;

  pnmh: PNMHDR;
  code: LongWord;

  iSel, iMode: DWORD;

  pD3DAdapterInfo: PTD3DAdapterInfo;
  pD3DDeviceInfo: ^TD3DDeviceInfo;
  pD3DModeInfo: ^TD3DModeInfo;

  szText: array[0..499] of Char;
  bHasHAL, bHasAppCompatHAL, bDisabledHAL, bHasSW, bHasAppCompatSW: Boolean;
const
  CChecked: array [False..True] of DWord = (MF_UNCHECKED, MF_CHECKED);
begin
  hwndTabs := GetDlgItem(hWnd, IDC_MONITORSTAB);
  hwndModeList := GetDlgItem(hWnd, IDC_MODESCOMBO);

  case (uMsg) of
    WM_INITDIALOG:
    begin
      i:= 0;
      GetWindowText(GetDlgItem(hWnd, IDC_TABNAMEFMT), szFmt, 100);

      tie.mask := TCIF_TEXT or TCIF_IMAGE;
      tie.iImage := -1;
      for iMonitor := 0 to m_dwNumMonitors - 1 do
      begin
        StrFmt(sz, szFmt, [iMonitor + 1]);
        tie.pszText := sz;
        // TabCtrl_InsertItem(hwndTabs, i, @tie); --> expands by (not translated by Borland)
        // #define TabCtrl_InsertItem(hwnd, iItem, pitem)   \
        //  (int)SNDMSG((hwnd), TCM_INSERTITEM, (WPARAM)(int)iItem, (LPARAM)(const TC_ITEM FAR*)(pitem))
        SendMessage(hwndTabs, TCM_INSERTITEM, i, Windows.LPARAM(@tie));

        Inc(i);
      end;
      for iAdapter:= 0 to m_dwNumAdapters - 1 do
      begin
        GetMem(s_AdaptersSave[iAdapter], SizeOf(TD3DAdapterInfo));
        if (s_AdaptersSave[iAdapter] <> nil) then
          s_AdaptersSave[iAdapter]^:= m_Adapters[iAdapter]^;
      end;
      s_bAllScreensSameSave := m_bAllScreensSame;
      SetupAdapterPage(hWnd);
      CheckDlgButton(hWnd, IDC_SAME, CChecked[m_bAllScreensSame]);
      Result:= iTRUE;
      Exit;
    end;

    WM_NOTIFY:
    begin
      pnmh := PNMHDR(lParam);
      code := pnmh.code;
      if (Integer(code) = TCN_SELCHANGE) then
      begin
        SetupAdapterPage(hWnd);
      end;
      Result:= iTRUE;
      Exit;
    end;

    WM_COMMAND:
    begin
      case LOWORD(wParam) of
        IDC_SAME:
          m_bAllScreensSame := (IsDlgButtonChecked(hWnd, IDC_SAME) = BST_CHECKED);

        IDC_LEAVEBLACK,
        IDC_RENDER:
        begin
          if m_bOneScreenOnly then
          begin
            GetBestAdapter(iAdapter);
            iMonitor := m_Adapters[iAdapter].iMonitor;
          end else
          begin
            //iMonitor := TabCtrl_GetCurSel(hwndTabs);
            //#define TabCtrl_GetCurSel(hwnd) \
            //    (int)SNDMSG((hwnd), TCM_GETCURSEL, 0, 0)
            iMonitor := SendMessage(hwndTabs, TCM_GETCURSEL, 0, 0);
          end;
          pMonitorInfo := @m_Monitors[iMonitor];
          iAdapter := pMonitorInfo.iAdapter;
          if (IsDlgButtonChecked(hWnd, IDC_LEAVEBLACK) = BST_CHECKED) then
          begin
            m_Adapters[iAdapter].bLeaveBlack := TRUE;
            EnableWindow(GetDlgItem(hWnd, IDC_MODESCOMBO), FALSE);
            EnableWindow(GetDlgItem(hWnd, IDC_MODESSTATIC), FALSE);
            EnableWindow(GetDlgItem(hWnd, IDC_DISPLAYMODEBOX), FALSE);
            EnableWindow(GetDlgItem(hWnd, IDC_DISPLAYMODENOTE), FALSE);
          end else
          begin
            m_Adapters[iAdapter].bLeaveBlack := FALSE;
            EnableWindow(GetDlgItem(hWnd, IDC_MODESCOMBO), TRUE);
            EnableWindow(GetDlgItem(hWnd, IDC_MODESSTATIC), TRUE);
            EnableWindow(GetDlgItem(hWnd, IDC_DISPLAYMODEBOX), TRUE);
            EnableWindow(GetDlgItem(hWnd, IDC_DISPLAYMODENOTE), TRUE);
          end;
        end;

        IDC_MODESCOMBO:
        begin
          if (HIWORD(wParam) = CBN_SELCHANGE) then
          begin
              if m_bOneScreenOnly then
              begin
                GetBestAdapter(iAdapter);
                iMonitor := m_Adapters[iAdapter].iMonitor;
              end else
              begin
                //iMonitor := TabCtrl_GetCurSel(hwndTabs);
                //#define TabCtrl_GetCurSel(hwnd) \
                //    (int)SNDMSG((hwnd), TCM_GETCURSEL, 0, 0)
                iMonitor := SendMessage(hwndTabs, TCM_GETCURSEL, 0, 0);
              end;
              pMonitorInfo := @m_Monitors[iMonitor];
              iAdapter := pMonitorInfo.iAdapter;
              // iSel := ComboBox_GetCurSel(hwndModeList);
              iSel := SendMessage(hwndModeList, TCM_GETCURSEL, 0, 0);
              if (iSel = 0) then
              begin
                // Automatic
                m_Adapters[iAdapter].dwUserPrefWidth := 0;
                m_Adapters[iAdapter].dwUserPrefHeight := 0;
                m_Adapters[iAdapter].d3dfmtUserPrefFormat := D3DFMT_UNKNOWN;
              end else
              begin
                pD3DAdapterInfo := m_Adapters[iAdapter];
                pD3DDeviceInfo := @pD3DAdapterInfo.devices[pD3DAdapterInfo.dwCurrentDevice];
                //#define ComboBox_GetItemData(hwndCtl, index)
                //  ((LRESULT)(DWORD)SNDMSG((hwndCtl), CB_GETITEMDATA, (WPARAM)(int)(index), 0L))
                // iMode := DWORD(ComboBox_GetItemData(hwndModeList, iSel));
                iMode := DWORD(SendMessage(hwndModeList, CB_GETITEMDATA, iSel, 0));
                pD3DModeInfo := @pD3DDeviceInfo.modes[iMode];
                m_Adapters[iAdapter].dwUserPrefWidth := pD3DModeInfo.Width;
                m_Adapters[iAdapter].dwUserPrefHeight := pD3DModeInfo.Height;
                m_Adapters[iAdapter].d3dfmtUserPrefFormat := pD3DModeInfo.Format;
              end;
          end;
        end;

        IDC_DISABLEHW:
        begin
          if m_bOneScreenOnly then
          begin
            GetBestAdapter(iAdapter);
            iMonitor := m_Adapters[iAdapter].iMonitor;
          end else
          begin
            //#define TabCtrl_GetCurSel(hwnd) \
            //    (int)SNDMSG((hwnd), TCM_GETCURSEL, 0, 0)
            // iMonitor := TabCtrl_GetCurSel(hwndTabs);
            iMonitor := SendMessage(hwndTabs, TCM_GETCURSEL, 0, 0);
          end;
          pMonitorInfo := @m_Monitors[iMonitor];
          iAdapter := pMonitorInfo.iAdapter;
          if (IsDlgButtonChecked(hWnd, IDC_DISABLEHW) = BST_CHECKED) then
            m_Adapters[iAdapter].bDisableHW := TRUE
          else
            m_Adapters[iAdapter].bDisableHW := FALSE;
          SetupAdapterPage(hWnd);
        end;

        IDC_MOREINFO:
        begin
          if m_bOneScreenOnly then
          begin
            GetBestAdapter(iAdapter);
            iMonitor := m_Adapters[iAdapter].iMonitor;
          end else
          begin
            //#define TabCtrl_GetCurSel(hwnd) \
            //    (int)SNDMSG((hwnd), TCM_GETCURSEL, 0, 0)
            // iMonitor := TabCtrl_GetCurSel(hwndTabs);
            iMonitor := SendMessage(hwndTabs, TCM_GETCURSEL, 0, 0);
          end;
          pMonitorInfo := @m_Monitors[iMonitor];
          iAdapter := pMonitorInfo.iAdapter;

          if (pMonitorInfo.hMonitor = 0) then
            pD3DAdapterInfo := nil
          else
            pD3DAdapterInfo := m_Adapters[pMonitorInfo.iAdapter];

          // Accelerated / Unaccelerated settings
          bHasHAL := FALSE;
          bHasAppCompatHAL := FALSE;
          bDisabledHAL := FALSE;
          bHasSW := FALSE;
          bHasAppCompatSW := FALSE;

          if (pD3DAdapterInfo <> nil) then
          begin
            bHasHAL := pD3DAdapterInfo.bHasHAL;
            bHasAppCompatHAL := pD3DAdapterInfo.bHasAppCompatHAL;
            bDisabledHAL := pD3DAdapterInfo.bDisableHW;
            bHasSW := pD3DAdapterInfo.bHasSW;
            bHasAppCompatSW := pD3DAdapterInfo.bHasAppCompatSW;
          end;
          if (bHasHAL and not bDisabledHAL and bHasAppCompatHAL) then
          begin
            // Good HAL
            LoadString(0, IDS_INFO_GOODHAL, szText, 500);
          end
          else if(bHasHAL and bDisabledHAL) then
          begin
            // Disabled HAL
            if (bHasSW and bHasAppCompatSW) then
              LoadString(0, IDS_INFO_DISABLEDHAL_GOODSW, szText, 500)
            else if bHasSW then
              LoadString(0, IDS_INFO_DISABLEDHAL_BADSW, szText, 500)
            else
              LoadString(0, IDS_INFO_DISABLEDHAL_NOSW, szText, 500);
          end
          else if (bHasHAL and not bHasAppCompatHAL) then
          begin
            // Bad HAL
            if (bHasSW and bHasAppCompatSW) then
              LoadString(0, IDS_INFO_BADHAL_GOODSW, szText, 500)
            else if bHasSW then
              LoadString(0, IDS_INFO_BADHAL_BADSW, szText, 500)
            else
              LoadString(0, IDS_INFO_BADHAL_NOSW, szText, 500);
          end else
          begin
            // No HAL
            if (bHasSW and bHasAppCompatSW) then
              LoadString(0, IDS_INFO_NOHAL_GOODSW, szText, 500)
            else if bHasSW then
              LoadString(0, IDS_INFO_NOHAL_BADSW, szText, 500)
            else
              LoadString(0, IDS_INFO_NOHAL_NOSW, szText, 500);
          end;

          MessageBox(hWnd, szText, @pMonitorInfo.strDeviceName, MB_OK or MB_ICONINFORMATION);
        end;

        IDOK:
        begin
          for iAdapter:= 0 to m_dwNumAdapters - 1 do
          begin
            FreeMem(s_AdaptersSave[iAdapter]);
          end;
          EndDialog(hWnd, IDOK);
        end;

        IDCANCEL:
        begin
          // Restore member values to original state
          for iAdapter := 0 to m_dwNumAdapters - 1 do
          begin
            if (s_AdaptersSave[iAdapter] <> nil) then
              m_Adapters[iAdapter]^ := s_AdaptersSave[iAdapter]^;
            FreeMem(s_AdaptersSave[iAdapter]);
          end;
          m_bAllScreensSame := s_bAllScreensSameSave;
          EndDialog(hWnd, IDCANCEL);
        end;
      end;
      Result:= iTRUE;
    end;
   else
    Result:= iFALSE;
  end;
end;




//-----------------------------------------------------------------------------
// Name: SetupAdapterPage()
// Desc: Set up the controls for a given page in the Screen Settings dialog.
//-----------------------------------------------------------------------------
procedure CD3DScreensaver.SetupAdapterPage(hWnd: HWND);
var
  hwndTabs, hwndModeList, hwndDesc: Windows.HWND;
  iPage: LongWord;

  pMonitorInfo: ^TMonitorInfo;
  pD3DAdapterInfo: PTD3DAdapterInfo;
  pD3DDeviceInfo: ^TD3DDeviceInfo;
  pD3DModeInfo: ^TD3DModeInfo;

  iAdapter: DWORD;
  bHasHAL, bHasAppCompatHAL, bDisabledHAL, bHasSW, bHasAppCompatSW: Boolean;

  szStatus: array[0..199] of Char;
  strAutomatic: array[0..99] of Char;

  iSelInitial: DWORD;
  strModeFmt: array[0..99] of Char;
  dwBitDepth: DWORD;
  iMode: Integer;
  strMode: array[0..79] of Char;
  dwItem: DWORD;
begin
  hwndTabs := GetDlgItem(hWnd, IDC_MONITORSTAB);
  hwndModeList := GetDlgItem(hWnd, IDC_MODESCOMBO);
  iPage := TabCtrl_GetCurFocus(hwndTabs);
  hwndDesc := GetDlgItem(hWnd, IDC_ADAPTERNAME);

  if m_bOneScreenOnly then
  begin
    GetBestAdapter(iAdapter);
    if (iAdapter <> NO_ADAPTER) then
    begin
      pD3DAdapterInfo := m_Adapters[iAdapter];
      iPage := pD3DAdapterInfo.iMonitor;
    end;
  end;

  pMonitorInfo := @m_Monitors[iPage];

  SetWindowText(hwndDesc, @pMonitorInfo.strDeviceName);

  if (pMonitorInfo.iAdapter = NO_ADAPTER) then
    pD3DAdapterInfo := nil
  else
    pD3DAdapterInfo := m_Adapters[pMonitorInfo.iAdapter];

  // Accelerated / Unaccelerated settings
  bHasHAL := FALSE;
  bHasAppCompatHAL := FALSE;
  bDisabledHAL := FALSE;
  bHasSW := FALSE;
  bHasAppCompatSW := FALSE;
  if (pD3DAdapterInfo <> nil) then
  begin
    bHasHAL := pD3DAdapterInfo.bHasHAL;
    bHasAppCompatHAL := pD3DAdapterInfo.bHasAppCompatHAL;
    bDisabledHAL := pD3DAdapterInfo.bDisableHW;
    bHasSW := pD3DAdapterInfo.bHasSW;
    bHasAppCompatSW := pD3DAdapterInfo.bHasAppCompatSW;
  end;

  if (bHasHAL and not bDisabledHAL and bHasAppCompatHAL) then
  begin
    LoadString(0, IDS_RENDERING_HAL, szStatus, 200);
  end
  else if (bHasSW and bHasAppCompatSW) then
  begin
    LoadString(0, IDS_RENDERING_SW, szStatus, 200);
  end else
  begin
    LoadString(0, IDS_RENDERING_NONE, szStatus, 200);
  end;
  SetWindowText(GetDlgItem(hWnd, IDC_RENDERING), szStatus);

  if (bHasHAL and bHasAppCompatHAL) then
  begin
    EnableWindow(GetDlgItem(hWnd, IDC_DISABLEHW), TRUE);
    if pD3DAdapterInfo.bDisableHW then
      CheckDlgButton(hWnd, IDC_DISABLEHW, BST_CHECKED)
    else
      CheckDlgButton(hWnd, IDC_DISABLEHW, BST_UNCHECKED);
  end else
  begin
      EnableWindow(GetDlgItem(hWnd, IDC_DISABLEHW), FALSE);
      CheckDlgButton(hWnd, IDC_DISABLEHW, BST_UNCHECKED);
  end;

  if ((bHasAppCompatHAL and not bDisabledHAL) or bHasAppCompatSW) then
  begin
    if pD3DAdapterInfo.bLeaveBlack then
      CheckRadioButton(hWnd, IDC_RENDER, IDC_LEAVEBLACK, IDC_LEAVEBLACK)
    else
      CheckRadioButton(hWnd, IDC_RENDER, IDC_LEAVEBLACK, IDC_RENDER);
    EnableWindow(GetDlgItem(hWnd, IDC_LEAVEBLACK), TRUE);
    EnableWindow(GetDlgItem(hWnd, IDC_RENDER), TRUE);
    EnableWindow(GetDlgItem(hWnd, IDC_SCREENUSAGEBOX), TRUE);
  end else
  begin
    CheckRadioButton(hWnd, IDC_RENDER, IDC_LEAVEBLACK, IDC_LEAVEBLACK);
    EnableWindow(GetDlgItem(hWnd, IDC_LEAVEBLACK), FALSE);
    EnableWindow(GetDlgItem(hWnd, IDC_RENDER), FALSE);
    EnableWindow(GetDlgItem(hWnd, IDC_SCREENUSAGEBOX), FALSE);
  end;

  if (IsDlgButtonChecked(hWnd, IDC_LEAVEBLACK) = BST_CHECKED) then
  begin
    EnableWindow(GetDlgItem(hWnd, IDC_MODESCOMBO), FALSE);
    EnableWindow(GetDlgItem(hWnd, IDC_MODESSTATIC), FALSE);
    EnableWindow(GetDlgItem(hWnd, IDC_DISPLAYMODEBOX), FALSE);
    EnableWindow(GetDlgItem(hWnd, IDC_DISPLAYMODENOTE), FALSE);
  end
  else
  begin
    EnableWindow(GetDlgItem(hWnd, IDC_MODESCOMBO), TRUE);
    EnableWindow(GetDlgItem(hWnd, IDC_MODESSTATIC), TRUE);
    EnableWindow(GetDlgItem(hWnd, IDC_DISPLAYMODEBOX), TRUE);
    EnableWindow(GetDlgItem(hWnd, IDC_DISPLAYMODENOTE), TRUE);
  end;

  // Mode list
  // #define ComboBox_ResetContent(hwndCtl)
  //      ((int)(DWORD)SNDMSG((hwndCtl), CB_RESETCONTENT, 0L, 0L))
  // ComboBox_ResetContent(hwndModeList);
  SendMessage(hwndModeList, CB_RESETCONTENT, 0, 0);
  if (pD3DAdapterInfo = nil) then Exit;
  GetWindowText(GetDlgItem(hWnd, IDC_AUTOMATIC), strAutomatic, 100);
  //#define ComboBox_AddString(hwndCtl, lpsz)
  //      ((int)(DWORD)SNDMSG((hwndCtl), CB_ADDSTRING, 0L, (LPARAM)(LPCTSTR)(lpsz)))
  // ComboBox_AddString(hwndModeList, strAutomatic );
  SendMessage(hwndModeList, CB_ADDSTRING, 0, Integer(@strAutomatic));
  //#define ComboBox_SetItemData(hwndCtl, index, data)
  //  ((int)(DWORD)SNDMSG((hwndCtl), CB_SETITEMDATA, (WPARAM)(int)(index), (LPARAM)(data)))
  // ComboBox_SetItemData(hwndModeList, 0, -1 );
  SendMessage(hwndModeList, CB_SETITEMDATA, 0, -1);
  pD3DDeviceInfo := @pD3DAdapterInfo.devices[pD3DAdapterInfo.dwCurrentDevice];

  iSelInitial := 0;
  GetWindowText(GetDlgItem(hWnd, IDC_MODEFMT), strModeFmt, 100);
  for iMode:= 0 to pD3DDeviceInfo.dwNumModes - 1 do
  begin
    pD3DModeInfo := @pD3DDeviceInfo.modes[iMode];
    dwBitDepth := 16;
    if (pD3DModeInfo.Format = D3DFMT_X8R8G8B8) or
       (pD3DModeInfo.Format = D3DFMT_A8R8G8B8) or
       (pD3DModeInfo.Format = D3DFMT_R8G8B8) then
    begin
      dwBitDepth := 32;
    end;

    StrFmt(@strMode, @strModeFmt,
      [pD3DModeInfo.Width, pD3DModeInfo.Height, dwBitDepth]);
    //#define ComboBox_AddString(hwndCtl, lpsz)
    //      ((int)(DWORD)SNDMSG((hwndCtl), CB_ADDSTRING, 0L, (LPARAM)(LPCTSTR)(lpsz)))
    // dwItem := ComboBox_AddString(hwndModeList, strMode);
    dwItem := SendMessage(hwndModeList, CB_ADDSTRING, 0, Integer(@strMode));
    //#define ComboBox_SetItemData(hwndCtl, index, data)
    //  ((int)(DWORD)SNDMSG((hwndCtl), CB_SETITEMDATA, (WPARAM)(int)(index), (LPARAM)(data)))
    // ComboBox_SetItemData( hwndModeList, dwItem, iMode );
    SendMessage(hwndModeList, CB_SETITEMDATA, dwItem, iMode);

    if (pD3DModeInfo.Width = pD3DAdapterInfo.dwUserPrefWidth) and
       (pD3DModeInfo.Height = pD3DAdapterInfo.dwUserPrefHeight) and
       (pD3DModeInfo.Format = pD3DAdapterInfo.d3dfmtUserPrefFormat) then
    begin
      iSelInitial := dwItem;
    end;
  end;
  //#define ComboBox_SetCurSel(hwndCtl, index)
  //          ((int)(DWORD)SNDMSG((hwndCtl), CB_SETCURSEL, (WPARAM)(int)(index), 0L))
  //ComboBox_SetCurSel( hwndModeList, iSelInitial );
  SendMessage(hwndModeList, CB_SETCURSEL, iSelInitial, 0);
end;

procedure OutputFileString(Str: String);
var
  F: Text;
begin
  Assign(F, 'c:\1.txt');
  if FileExists('c:\1.txt')
    then Append(F)
    else Rewrite(F);

  WriteLn(F, Str);
  CloseFile(F);
end;

end.

