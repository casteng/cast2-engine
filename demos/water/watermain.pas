(*
 CAST II Engine water demo main unit
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 (C) 2007 George "Mirage" Bakhtadze
*)
{$I GDefines.inc}
{$I C2Defines.inc}
unit WaterMain;

interface

uses
  SysUtils,
  Logger, Basics, AppsInitWin, OSUtils,

  Resources, BaseGraph, BaseTypes, BaseMsg, Base3D,
  C2Res, C2VisItems, C2Anim, C22D, C2FX, C2Land, C2TileMaps,
  ACS, ACSAdv, C2GUI,

  C2Affectors, C2ParticleAdv,

  C2Render, {$IFDEF DIRECT3D8} C2DX8Render, {$ENDIF}
  Input, WInput,
  CAST2, C2Core,
  Timer;

const
  // These constants can be adjusted
  RunFullScreen = False;                      // Fullscreen mode
  SceneFileName = 'water.cbf';                // Scene to load
  CameraRotateSpeed = 0.003;                  // Camera rotation sensitivity
  CameraMoveAccel   = 0.05;                   // Camera movement sensitivity
  BreakFactor       = 0.85;                   // How far camera can move
  CameraMoveRadius  = 100;
  TimerDelay        = 1/60;                   // Delay between timer events

  KeyLeftBind    = 'A';                       // Key binding to move camera left
  KeyRightBind   = 'D';                       // Key binding to move camera right
  KeyUpBind      = 'Q';                       // Key binding to move camera up
  KeyDownBind    = 'E';                       // Key binding to move camera down
  KeyBackBind    = 'W';                       // Key binding to move camera back
  KeyForwardBind = 'S';                       // Key binding to move camera forward

  // Do not change
  keyLeft    = 0;                             // Left key
  keyRight   = 1;                             // Right key
  keyUp      = 2;                             // Up key
  keyDown    = 3;                             // Down key
  keyBack    = 4;                             // Back key
  keyForward = 5;                             // Forward key
  keyMax     = 5;                             // Max key index

type
  TWaterDemo = class
  private
    OldFramesRendered: Integer;

    KeyPressed: array[0..keyMax] of Boolean;  // Bound keys current state
    Velocity: TVector3s;                      // Current movement speed
    Core: TCore;
    function LoadScene(const FileName: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Process;
    procedure HandleMouse(EventData: Integer; CustomData: SmallInt);
    procedure HandleTimer(EventID: Integer; const ErrorDelta: TTimeUnit);     // Timer event
    procedure HandleMessage(const Msg: TMessage);                             // Message handler
    procedure HandleKeys(EventData: Integer; CustomData: Smallint);           // Keys handle delegate
  end;

var
  Starter: TWin32AppStarter;                                        // Application starter

implementation

function TWaterDemo.LoadScene(const FileName: string): Boolean;
var Stream: TFileStream;
begin
  Stream := TFileStream.Create(Filename);

  Result := Core.LoadScene(Stream);
  if not Result then Log(Self.ClassName + '.Create: Error loading file "' + FileName + '"', lkError);

  Stream.Free;
end;

constructor TWaterDemo.Create;
var HandleKeysProc: TInputDelegate;
begin
  Starter.Terminated := True;                                      // Terminate the application if an error occurs
  // Create engine core
  Core := TCore.Create;
  // Register item classes
  Core.RegisterItemClasses(Resources.GetUnitClassList);            // Base resources
  Core.RegisterItemClasses(BaseGraph.GetUnitClassList);            // Base graphics
  // Engine classes
  Core.RegisterItemClasses(C2Core.GetUnitClassList);               // Engine general classes
  Core.RegisterItemClasses(C2Res.GetUnitClassList);                // CAST II resource
  Core.RegisterItemClasses(C2VisItems.GetUnitClassList);           // Some visible item classes
  Core.RegisterItemClasses(C2Anim.GetUnitClassList);               // Animated item classes
  Core.RegisterItemClasses(C22D.GetUnitClassList);                 // 2D via CAST II wrapper classes
  Core.RegisterItemClasses(C2FX.GetUnitClassList);                 // Some visual effects classes
  Core.RegisterItemClasses(C2Land.GetUnitClassList);               // Landscape classes
//  Core.RegisterItemClasses(C2TileMaps.GetUnitClassList);           // Tilemap classes
  // ACS classes
  Core.RegisterItemClasses(ACS.GetUnitClassList);                  // Base controls
  Core.RegisterItemClasses(ACSAdv.GetUnitClassList);               // Advanced controls
  Core.RegisterItemClasses(C2GUI.GetUnitClassList);                // CAST II wrapper classes
  // Partcile system classes
  Core.RegisterItemClasses(C2Affectors.GetUnitClassList);          // Base particle system related classes
  Core.RegisterItemClasses(C2ParticleAdv.GetUnitClassList);        // Advanced particle system related classes

  Core.MessageHandler    := HandleMessage;      // Set message handler
  Starter.MessageHandler := Core.HandleMessage; // Redirect window messages to engine
  // Create renderer
  {$IFDEF DIRECT3D8}
  Core.Renderer := TDX8Renderer.Create(Core);
  {$ENDIF}

  if not Assigned(Core.Renderer) or (Core.Renderer.State = rsNotInitialized) then begin             // Error
    Starter.PrintError('Can''t start renderer', lkFatalError);
    Exit;
  end;

  ActivateWindow(Starter.WindowHandle);                            // Bring the application to foreground

  // Initialize render device
  if not Core.Renderer.CreateDevice(Starter.WindowHandle, 0, RunFullScreen) then begin
    Starter.PrintError('Failed to initiaize render device', lkFatalError);
    Exit;
  end;

  // Initialize input subsystem
  Core.Input := TOSController.Create(Starter.WindowHandle, {$IFDEF OBJFPCEnable}@{$ENDIF}Core.HandleMessage);
  Core.Input.BindCommand('ESC', TForceQuitMsg);                    // Bind exit to ESC key
  Core.Input.BindCommand('ALT+Q', TForceQuitMsg);                  // Bind exit to ALT+Q key combination
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

//  Core.Input.MouseCapture := True;

//  Core.CatchAllInput := True;

  Core.Input.BindDelegate('MouseMove^', {$IFDEF OBJFPCEnable}@{$ENDIF}HandleMouse, 0);

  // Load scene
  if not LoadScene(SceneFileName) then begin
    Starter.PrintError('Can''t open scene file "' + SceneFileName + '"', lkFatalError);
    Exit;
  end;

  Starter.Terminated := False;                                     // No errors

  Core.Timer.SetRecurringEvent(TimerDelay, {$IFDEF OBJFPCEnable}@{$ENDIF}HandleTimer, 0);
end;

destructor TWaterDemo.Destroy;
begin
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

procedure TWaterDemo.Process;

  procedure DrawPerfHUD;
  var i: Integer;
  begin
    if Count >= Width div Stride then begin
      Count := 0;
      MaxValue := epsilon;
    end;

    Values[viFrame,  Count] := Core.PerfProfile.Times[ptFrame];
    Values[viRender, Count] := Core.PerfProfile.Times[ptRender];
    if Values[viFrame, Count] > MaxValue then MaxValue := Values[viFrame, Count];
    Inc(Count);
    Screen.ResetViewport;
    Screen.Clear;

{    Screen.MoveTo(0, 0);
    Screen.LineTo(100, 100);
    Screen.LineTo(100, 200);}
    
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
  DrawPerfHUD;
end;

procedure TWaterDemo.HandleMessage(const Msg: TMessage);
var CapMX, CapMY: Integer;
begin
  ObtainCursorPos(CapMX, CapMY);
  if Msg.ClassType = TForceQuitMsg then Starter.Terminate;
end;

procedure TWaterDemo.HandleKeys(EventData: Integer; CustomData: Smallint);
begin
  KeyPressed[CustomData and $FF] := CustomData and $100 > 0;
end;

procedure TWaterDemo.HandleTimer(EventID: Integer; const ErrorDelta: TTimeUnit);
var FPS, Scale: Single;
begin
  Scale := (TimerDelay + ErrorDelta)/TimerDelay;

  Core.Renderer.MainCamera.Move(Velocity.X * scale, Velocity.Y * scale, Velocity.Z * scale);

  Velocity := ScaleVector3s(Velocity, 1-(1-BreakFactor)*scale);

  Velocity := AddVector3s(Velocity, GetVector3s( (Ord(KeyPressed[keyRight]) - Ord(KeyPressed[keyLeft]))    * CameraMoveAccel * Scale,
                                                 (Ord(KeyPressed[keyUp])    - Ord(KeyPressed[keyDown]))    * CameraMoveAccel * Scale,
                                                 (Ord(KeyPressed[keyBack])  - Ord(KeyPressed[keyForward])) * CameraMoveAccel * Scale));



  if SqrMagnitude(Core.Renderer.MainCamera.Position) > Sqr(CameraMoveRadius) then
    Core.Renderer.MainCamera.Position := NormalizeVector3s(Core.Renderer.MainCamera.Position, CameraMoveRadius);

  FPS := (Core.Renderer.FramesRendered - OldFramesRendered) / (TimerDelay + ErrorDelta);

  OldFramesRendered := Core.Renderer.FramesRendered;

  OSUtils.SetWindowCaption(Starter.WindowHandle, Format('%3.3F - %3.3F, %3.3F', [Core.PerfProfile.FramesPerSecond, FPS, Scale]));
end;

procedure TWaterDemo.HandleMouse(EventData: Integer; CustomData: SmallInt);
var MX, MY: Integer;
begin
  MX := Smallint(EventData and $FFFF);
  MY := Smallint((EventData div $10000) and $FFFF);
  with Core.Renderer.MainCamera do
    Orientation := MulQuaternion(GetQuaternion(MX*CameraRotateSpeed, GetVector3s(0, 1, 0)),
                                 MulQuaternion(GetQuaternion(MY*CameraRotateSpeed, RightVector),
                                               Orientation));
end;

end.
