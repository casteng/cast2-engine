{$Include GDefines}
{$Include CDefines}
unit CDInput;

interface

uses
  {$IFDEF DEBUGMODE} SysUtils, {$ENDIF}
   Logger, 
  Basics, OSUtils, CTypes, CInput, DirectInput8;

const
  {$IFDEF DEBUGMODE}
    BFCoopMode = DISCL_BACKGROUND;
//    BFCoopMode = DISCL_FOREGROUND;
  {$ELSE}
    BFCoopMode = DISCL_FOREGROUND;
  {$ENDIF}

type
  TDIController = class(TController)
    DirectInput: IDirectInput8;
    KeyboardDevice, MouseDevice: IDirectInputDevice8;
    constructor Create(AHandle: Cardinal); override;
    procedure SetMode(Exclusive: Boolean); virtual;
    procedure GetInputState; override;
    procedure ApplyMouseAnchor(const X, Y: LongInt); override;
    procedure SetSystemCursor(const Value: Boolean); override;
    destructor Free; override;
  protected
    FSmoothN, CurSmoothN: Integer;              // Max and current elements of history array for smoothing
    MouseHistory: array of TMouseState;
    procedure DoSmooth(var MouseState: TMouseState);
    procedure SetSmoothSamples(const Value: Integer);
  public
    property SmoothSamples: Integer read FSmoothN write SetSmoothSamples;
  end;

implementation

{ TDIController }

procedure TDIController.ApplyMouseAnchor(const X, Y: Integer);
begin
  inherited;
  if X <> -1 then AdjustCursorVisibility(False) else AdjustCursorVisibility(True);
//  SetMode(X <> -1);
{  if X <> -1 then begin
    if CurrentMouseAnchorX = -1 then ShowCursor(False);
//    LastMouseX := X; LastMouseY := Y;
    SetCursorPos(X, Y);
  end else if CurrentMouseAnchorX <> -1 then ShowCursor(True);}
//  CurrentMouseAnchorX := X; CurrentMouseAnchorY := Y;

//  ProcessInput(nil, efNone);                           
end;

constructor TDIController.Create(AHandle: Cardinal);
var Res: HResult; i: Integer;
begin
  Res := DirectInput8Create(HInstance, DIRECTINPUT_VERSION, IID_IDirectInput8, DirectInput, nil);
  DirectInput.CreateDevice(GUID_SysKeyboard, KeyboardDevice, nil);
  Res := KeyboardDevice.SetDataFormat(c_dfDIKeyboard);
  KeyboardDevice.SetCooperativeLevel(Handle, BFCoopMode or DISCL_NONEXCLUSIVE);
  KeyboardDevice.Acquire;
  DirectInput.CreateDevice(GUID_SysMouse, MouseDevice, nil);
  Res := MouseDevice.SetDataFormat(c_dfDIMouse);
   if MouseAnchorX = -1 then Res := MouseDevice.SetCooperativeLevel(Handle, BFCoopMode or DISCL_NONEXCLUSIVE) else
   Res := MouseDevice.SetCooperativeLevel(Handle, BFCoopMode or DISCL_EXCLUSIVE);
  Res := MouseDevice.Acquire;

  inherited Create(AHandle);
  {$I DI_CONST.pas}

  SmoothSamples := 0;
end;

procedure TDIController.DoSmooth(var MouseState: TMouseState);
var i: Integer; lx, ly, d: Single;
begin
  if CurSmoothN < FSmoothN then begin
    MouseHistory[CurSmoothN] := MouseState;
    Inc(CurSmoothN);
  end else begin
    for i := 1 to FSmoothN-1 do MouseHistory[i-1] := MouseHistory[i];
    MouseHistory[FSmoothN-1] := MouseState;
  end;
  lx := 0; ly := 0; d := 0;
  for i := 0 to CurSmoothN-1 do begin
    lx := lx + MouseHistory[i].lX * (i+1);
    ly := ly + MouseHistory[i].lY * (i+1);
    d := d + i + 1;
  end;
  lx := lx / d;
  ly := ly / d;

  MouseState.lX := Trunc(0.5 + lx);
  MouseState.lY := Trunc(0.5 + ly);
end;

destructor TDIController.Free;
begin
  inherited;
  KeyboardDevice.Unacquire; MouseDevice.Unacquire;
  KeyboardDevice := nil; MouseDevice := nil;
  DirectInput := nil;
end;

procedure TDIController.GetInputState;
var Res: HRESULT;
begin
  if KeyboardDevice.GetDeviceState(SizeOf(KeyboardState), @KeyboardState) <> DI_OK then begin
    Move(LastKeyState[0], KeyboardState[0], 256);
  Log('Error getting keyboard state', lkError); 
  end;

  if not Active then Exit;

  Res := MouseDevice.GetDeviceState(SizeOf(MouseState), @MouseState);
//  Log(Format(' *** IK_MOUSELEFT state af GetKS: %D(%D)', [KeyboardState[IK_MOUSELEFT], LastKeyState[IK_MOUSELEFT]]));

  if FSmoothN > 0 then DoSmooth(MouseState);

  if Res = DIERR_INPUTLOST then begin
 if Log <> nil then Log('Input lost'); 
    MouseDevice.Acquire;
  end;// else if Res <> DI_OK then Windows.MessageBox(0, PChar(DIErrorString(Res)), 'ERROR', MB_ICONERROR);
  if Res = DI_OK then begin
//    Log(Format(' *** MOUSELEFT state af GetMS: %D(%D)', [MouseState.Buttons[0], LastMouseState.Buttons[0]]));
    KeyboardState[IK_MOUSELEFT]   := MouseState.Buttons[0];
    KeyboardState[IK_MOUSERIGHT]  := MouseState.Buttons[1];
    KeyboardState[IK_MOUSEMIDDLE] := MouseState.Buttons[2];

//    if KeyboardState[IK_MOUSELEFT] <> LastKeyState[IK_MOUSELEFT] then
//     Log(' *** IK_MOUSELEFT state changed');

    if SystemCursor then begin
      ObtainCursorPos(MouseX, MouseY);
      ScreenToClient(Handle, MouseX, MouseY);
      MouseX := MinI(MouseWindow.Right, MaxI(MouseWindow.Left, MouseX));
      MouseY := MinI(MouseWindow.Bottom, MaxI(MouseWindow.Top, MouseY));
    end else begin
      MouseX := MinI(MouseWindow.Right, MaxI(MouseWindow.Left, MouseX + MouseState.lX));
      MouseY := MinI(MouseWindow.Bottom, MaxI(MouseWindow.Top, MouseY + MouseState.lY));
    end;
    LastMouseState := MouseState;
{    if CurrentMouseAnchorX <> -1 then SetCursorPos(CurrentMouseAnchorX, CurrentMouseAnchorY) else begin
      LastMouseX := MouseXY.X; LastMouseY := MouseXY.Y;
    end;}
  end else begin
    MouseState := LastMouseState;
 Log('Error getting keyboard state', lkError); 
  end;
end;

procedure TDIController.SetMode(Exclusive: Boolean);
begin
  if Exclusive then begin
//    ProcessInput(nil, efNone);
    MouseDevice.UnAcquire;
//    MouseDevice.SetDataFormat(c_dfDIMouse);
    MouseDevice.SetCooperativeLevel(Handle, DISCL_FOREGROUND or DISCL_EXCLUSIVE);
    MouseDevice.SetDataFormat(c_dfDIMouse);
//    MouseDevice.Initialize(HInstance, DIRECTINPUT_VERSION, GUID_SysMouse);
    MouseDevice.Acquire;
//    MouseDevice.Poll;
  end else begin
    MouseDevice.UnAcquire;
//    MouseDevice.SetDataFormat(c_dfDIMouse);
    MouseDevice.SetCooperativeLevel(Handle, BFCoopMode or DISCL_NONEXCLUSIVE);
//    MouseDevice.Initialize(HInstance, DIRECTINPUT_VERSION, GUID_SysMouse);
    MouseDevice.Acquire;
//    MouseDevice.Poll;
//    ProcessInput(nil, efNone);
  end;
end;

procedure TDIController.SetSmoothSamples(const Value: Integer);
begin
  FSmoothN := Value;
  CurSmoothN := 0;
  SetLength(MouseHistory, FSmoothN);
end;

procedure TDIController.SetSystemCursor(const Value: Boolean);
begin
  inherited;
  SetMode(not Value);
end;

end.
