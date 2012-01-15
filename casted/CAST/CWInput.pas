{$Include GDefines}
{$Include CDefines}
unit CWInput;

interface

uses Basics, OSUtils, CInput;

type
  TWin32Controller = class(TController)
    LastMouseX, LastMouseY: LongInt;
    constructor Create(AHandle: Cardinal); virtual;
    procedure SetMouseWindow(const X1, Y1, X2, Y2: Longint); override;
    procedure ApplyMouseAnchor(const X, Y: Longint); override;
    procedure GetInputState; override;
  end;

implementation

{ TWin32Controller }

constructor TWin32Controller.Create(AHandle: Cardinal);
begin
  inherited;
  {$I WI_CONST.pas}
end;

procedure TWin32Controller.GetInputState;
begin
  ObtainKeyboardState(KeyboardState);
  ObtainCursorPos(MouseX, MouseY);
  with MouseState do begin
    lX := MouseX - LastMouseX;
    lY := MouseY - LastMouseY;
    Buttons[0] := Byte(GetAsyncKeyState(IK_MOUSELEFT) < 0) * 128;
    Buttons[1] := Byte(GetAsyncKeyState(IK_MOUSERIGHT) < 0) * 128;
    Buttons[2] := Byte(GetAsyncKeyState(IK_MOUSEMIDDLE) < 0) * 128;
  end;
  if MouseAnchorX <> -1 then SetCursorPos(MouseAnchorX, MouseAnchorY) else begin
    LastMouseX := MouseX; LastMouseY := MouseY;
  end;
  ScreenToClient(Handle, MouseX, MouseY);
  MouseX := MinI(MouseWindow.Right, MaxI(MouseWindow.Left, MouseX));
  MouseY := MinI(MouseWindow.Bottom, MaxI(MouseWindow.Top, MouseY));
end;

procedure TWin32Controller.ApplyMouseAnchor(const X, Y: LongInt);
begin
  inherited;
  if X <> -1 then begin
{    if CurrentMouseAnchorX = -1 then }AdjustCursorVisibility(False);
    LastMouseX := X; LastMouseY := Y;
    SetCursorPos(X, Y);
  end else {if CurrentMouseAnchorX <> -1 then }AdjustCursorVisibility(True);
//  MouseAnchorX := X; MouseAnchorY := Y;
end;

procedure TWin32Controller.SetMouseWindow(const X1, Y1, X2, Y2: Integer);
begin
  inherited;
  ClipCursor(MouseWindow);
end;

end.
