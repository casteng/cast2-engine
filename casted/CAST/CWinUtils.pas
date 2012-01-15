unit CWinUtils;

interface

uses Windows, Messages, Basics, CTypes;

function MessageToCommand(MsgID: Cardinal; wParam, lParam: Longint): TCommand; overload;
function MessageToCommand(Msg: TMessage): TCommand; overload;

implementation

function MessageToCommand(MsgID: Cardinal; wParam, lParam: Longint): TCommand;
begin
  case MsgID of
    WM_ACTIVATE: if (wParam and 65535 = WA_ACTIVE) or (wParam and 65535 = WA_CLICKACTIVE) then
                  Result := NewCommand(cmdActivated, [wParam]) else
                   if wParam and 65535 = WA_INACTIVE then Result := NewCommand(cmdDeactivated, []);
    WM_EXITSIZEMOVE: begin
    end;
    WM_SIZE: if WParam = SIZE_MINIMIZED then Result := NewCommand(cmdMinimized, []) else Result := NewCommand(cmdResized, [lParam and 65535, lParam shr 16]);
    WM_CANCELMODE: Result := NewCommand(cmdPopupInvoke, []);
  end;
end;

function MessageToCommand(Msg: TMessage): TCommand;
begin
  Result := MessageToCommand(Msg.Msg, Msg.WParam, Msg.LParam);
end;

end.
