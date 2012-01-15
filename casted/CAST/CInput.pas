{$Include GDefines}
{$Include CDefines}
// Plan
//   Optionally break sequence if another sequense completed
unit CInput;

interface

uses Windows,  Logger,  OSUtils, Basics, BaseCont, CTypes, SysUtils;

const
  atBooleanOn = 1; atBooleanOff = 2; atBooleanToggle = 3; atSetByte = 4; atSetWord = 5; atSetLongWord = 6;

  cmdKeyDown = cmdInputBase; cmdKeyUp = cmdInputBase + 1;
  cmdKeyClick = cmdInputBase + 2; cmdKeyDblClick = cmdInputBase + 3;

  MaxEvents = 127;
  MaxPointers = 256;           // Must fit in a single byte
// Key query states
  kqsUp = 0; kqsDown = 1;
// Query input results
  qirNone = 0; qirKeyPressed = 1; qirKeyChanged = 2; qirMouseMoved = 4;
// Input event filters
  efNone = 0; efBond = 1; efNoBond = 2; efAll = 255;
// Binding members
  bmNone = 0; bmKeyboard = 1; bmMouseButtons = 2; bmMouseMotion = 4;

type
  TBindTypes = (btKeyDown, btKeyUp, btKeyClick,
                btMouseMove, btMouseHMove, btMouseVMove,
                btMouseRoll,
                btStrokeLeft, btStrokeRight, btStrokeUp, btStrokeDown,
                btStrokeLeftUp, btStrokeRightUp, btStrokeLeftDown, btStrokeRightDown,
                btNone, btForceWord = $FF);
  PBinding = ^TBinding;
  TBinding = packed record
    BindType: TBindTypes;
    BindData: Word;
    NextBinding: PBinding;
  end;

  TInputEvent = packed record
    EventType: TBindTypes;
    EventData: SmallInt;
  end;
  TInputEvents = array of TInputEvent;
  TMouseState = packed record
    lX, lY, lZ: LongInt;
    Buttons: array[0..3] of Byte;
  end;

  CController = class of TController;
  TController = class
    Handle: Cardinal;
    KeyTrans: array[0..255] of Byte;
    KeyboardState: TKeyboardState;
    DblClickTimeout: Cardinal;
    LastMouseState, MouseState: TMouseState;
    MouseX, MouseY: Integer;
    Pointers: array of Pointer;
    Bindings: array of packed record
      CommandID: LongWord;
      First, Current, Terminator: PBinding;
      LastTime: Longword; TimeOut: Word;
      MembersKind: Word;
    end;
    TotalBindings, TotalPointers: Word;
    MouseAnchorX, MouseAnchorY, MouseXCounter, MouseYCounter: LongInt;
    MouseWindow: TRect;
    MouseTimeOut, MouseQueryTick: Cardinal;
    FSystemCursor: Boolean;
//    LastMouseEvent: TBindTypes;
    InputEvents: array[0..MaxEvents] of TInputEvent; TotalEvents: Integer;
// Standard keys
    Active, ShiftState, CtrlState, AltState: Boolean;
    constructor Create(AHandle: Cardinal); virtual;

    procedure HandleCommand(const Command: TCommand); virtual;

    function NewBinding(BType: TBindTypes; BData: Word; Next: PBinding = nil): PBinding;

    procedure BindCommand(const ABinding: PBinding; const CID: LongWord; const ATimeout: LongWord = 0; const ATerminator: PBinding = nil); virtual;
    procedure BindPointer(const ABinding: PBinding; const ActionType: Longword; const Data: Pointer; const Value: Word = 0; const ATimeout: LongWord = 0; const ATerminator: PBinding = nil); virtual;

    procedure UnBind(const Index: Longword); virtual;
    procedure UnBindAll;
    procedure CleanPointers; virtual;

    function GetBinding(const Index: Word): TBinding; virtual;

    procedure SetMouseWindow(const X1, Y1, X2, Y2: Longint); virtual;
    procedure SetMouseAnchor(const X, Y: LongInt); virtual;
    function MouseAnchored: Boolean; virtual;
    procedure GetInputState; virtual; abstract;
    procedure ProcessInput(const Queue: TCommandQueue; const EventFilter: Longword); virtual;
    function QueryInput: Integer; virtual;
    procedure InputEventsToCommands(var CommandQueue: TCommandQueue); virtual;
    destructor Free; virtual;

    procedure SetSystemCursor(const Value: Boolean); virtual;
  protected
    FInputBuffer: ShortString;
    KeyQueryState: array[0..255] of record
      State: Cardinal;
      LastClickedTime: Cardinal;
    end;
    LastKeyState: array[0..255] of Byte;
    PreAnchorMouseX, PreAnchorMouseY: Integer;
    function GetMouseEvent: TBindTypes;
    procedure ApplyMouseAnchor(const X, Y: LongInt); virtual;
    function GetInputBuffer: ShortString;
  public
    property InputBuffer: ShortString read GetInputBuffer;
    property SystemCursor: Boolean read FSystemCursor write SetSystemCursor;
  end;

  {.$I CIVars.pas}

implementation

{ TController }

constructor TController.Create(AHandle: Cardinal);
var i: Integer;
begin
  Active := True;
  Handle := AHandle;
  MouseAnchorX := -1; MouseAnchorY := -1;
  FSystemCursor := True;
  for i := 0 to 255 do KeyTrans[i] := i;
  MouseTimeOut := 00;
  DblClickTimeout := 300;
  ShiftState := False;
  CtrlState := False;
  AltState := False;
  GetInputState;

  MouseWindow := GetClipCursor;
  SetMouseWindow(MouseWindow.Left, MouseWindow.Top, MouseWindow.Right, MouseWindow.Bottom);

  FillChar(KeyQueryState, SizeOf(KeyQueryState), 0);
end;

function TController.NewBinding(BType: TBindTypes; BData: Word; Next: PBinding = nil): PBinding;
var BindKey: Byte;
begin
  BindKey := KeyTrans[BData and 255];
  GetMem(Result, SizeOf(TBinding));
  case BType of
    btKeyClick: begin
      with Result^ do begin
        BindType := btKeyDown; BindData := 0*BData and $FF00 + BindKey; GetMem(NextBinding, SizeOf(TBinding));
      end;
      with Result^.NextBinding^ do begin
        BindType := btKeyUp; BindData := 0*BData and $FF00 + BindKey; NextBinding := Next;
      end;
    end;
    else with Result^ do begin
      BindType := BType; BindData := 0*BData and $FF00 + BindKey; NextBinding := Next;
    end;
  end;
end;

destructor TController.Free;
var i: Integer;
begin
  SetMouseAnchor(-1, -1);
  for i := 0 to TotalBindings - 1 do with Bindings[i] do begin
    Current := First;
    while Current <> nil do begin
      First := Current;
      Current := Current^.NextBinding;
      FreeMem(First);
    end;
  end;
  SetLength(Bindings, 0);
end;

function TController.GetBinding(const Index: Word): TBinding;
begin
  Result := Bindings[Index].First^;
end;

procedure TController.BindCommand(const ABinding: PBinding; const CID: LongWord; const ATimeout: LongWord = 0; const ATerminator: PBinding = nil);
var TB: PBinding;
begin
  Inc(TotalBindings); SetLength(Bindings, TotalBindings);
  with Bindings[TotalBindings - 1] do begin
    First := ABinding; Current := First;
    Terminator := ATerminator; Timeout := ATimeout;
    CommandID := CID;
  end;
  TB := ABinding;
  while TB <> nil do begin
    case TB.BindType of
      btKeyDown, btKeyUp, btKeyClick: if (TB.BindData = IK_MOUSELEFT) or (TB.BindData = IK_MOUSEMIDDLE) or (TB.BindData = IK_MOUSERIGHT) then
                                       Bindings[TotalBindings - 1].MembersKind := Bindings[TotalBindings - 1].MembersKind or bmMouseButtons else
                                        Bindings[TotalBindings - 1].MembersKind := Bindings[TotalBindings - 1].MembersKind or bmKeyboard;
      btMouseMove, btMouseHMove, btMouseVMove, btMouseRoll, btStrokeLeft..btStrokeRightDown: Bindings[TotalBindings - 1].MembersKind := Bindings[TotalBindings - 1].MembersKind or bmMouseMotion;
    end;
    TB := TB.NextBinding;
  end;
end;

procedure TController.BindPointer(const ABinding: PBinding; const ActionType: Longword; const Data: Pointer; const Value: Word = 0; const ATimeout: LongWord = 0; const ATerminator: PBinding = nil);
var i, PointerIndex: Integer;
begin
  PointerIndex := -1;
  for i := 0 to TotalPointers - 1 do if Pointers[i] = Data then begin PointerIndex := i; Break; end;
  if PointerIndex < 0 then begin
    if TotalPointers >= MaxPointers then begin
 Log('TController.BindPointer: Too many pointers.', lkError); 
      Exit;
    end;
    Inc(TotalPointers); SetLength(Pointers, TotalPointers);
    PointerIndex := TotalPointers - 1;
    Pointers[PointerIndex] := Data;
  end;
  Inc(TotalBindings); SetLength(Bindings, TotalBindings);
  with Bindings[TotalBindings - 1] do begin
    First := ABinding; Current := First;
    Terminator := ATerminator; Timeout := ATimeout;
    CommandID := ActionType shl 24 + Value shl 8 + PointerIndex;
  end;
end;

procedure TController.UnBind(const Index: Longword);
begin
  Dec(TotalBindings);
  if Index < TotalBindings then Bindings[Index] := Bindings[TotalBindings];
  SetLength(Bindings, TotalBindings);
  CleanPointers;
end;

procedure TController.CleanPointers;                               //ToFix: Bug here
var i, j: Cardinal; Used: Boolean;
begin
  for j := TotalPointers - 1 downto 0 do begin
    Used := False;
    for i := 0 to TotalBindings - 1 do if (Bindings[i].CommandID and $FF000000 > 0) and (Bindings[i].CommandID and $FFFF = j) then begin
      Used := True; Break;
    end;
    if not Used then begin
      Dec(TotalPointers);
      SetLength(Pointers, TotalPointers);
    end;
  end;
end;

procedure TController.UnBindAll;
begin
  TotalBindings := 0; TotalPointers := 0;
  SetLength(Bindings, TotalBindings);
  SetLength(Pointers, TotalPointers);
end;

procedure TController.ProcessInput(const Queue: TCommandQueue; const EventFilter: Longword);
var
  i: Integer; CurTerm: PBinding; CurTime: LongWord;
  EndPass, Terminated: Boolean;
  MouseEvent: TBindTypes;

function MatchMouseEvent(Event1, Event2: TBindTypes): Boolean;
begin
  Result := False;
  case Event1 of
    btMouseMove: Result := (Event2 >= btMouseMove) and (Event2 <= btStrokeRightDown);
    btMouseHMove: Result := (Event2 = btMouseHMove) or (Event2 = btStrokeLeft) or (Event2 = btStrokeRight) or (Event2 >= btStrokeLeftUp) and (Event2 <= btStrokeRightDown);
    btMouseVMove: Result := (Event2 = btMouseVMove) or (Event2 = btStrokeUp) or (Event2 = btStrokeDown) or (Event2 >= btStrokeLeftUp) and (Event2 <= btStrokeRightDown);
    
    btStrokeLeft: Result := (Event2 = btStrokeLeft) or (Event2 = btStrokeLeftUp) or (Event2 <= btStrokeLeftDown);
    btStrokeRight: Result := (Event2 = btStrokeRight) or (Event2 = btStrokeRightUp) or (Event2 <= btStrokeRightDown);
    btStrokeUp: Result := (Event2 = btStrokeUp) or (Event2 = btStrokeLeftUp) or (Event2 <= btStrokeRightUp);
    btStrokeDown: Result := (Event2 = btStrokeDown) or (Event2 = btStrokeLeftDown) or (Event2 <= btStrokeRightDown);
    btStrokeLeftUp, btStrokeRightUp, btStrokeLeftDown, btStrokeRightDown, btMouseRoll: Result := (Event2 = Event1);
  end;
end;

procedure MatchBinding(BData: Integer);
begin
  with Bindings[i], Current^ do begin
    if NextBinding = nil then begin
      if CommandID and $FF000000 = 0 then begin        // Command
        Queue.Add(CommandID, [BData, MembersKind]);
        Current := First;                              //     bytes:    3
      end else case CommandID shr 24 of                // CommandID: [<ActionType><Data><Data><PointerIndex>]
        atBooleanOn: Boolean(Pointers[CommandID and $FF]^) := True;
        atBooleanOff: Boolean(Pointers[CommandID and $FF]^) := False;
        atBooleanToggle: Boolean(Pointers[CommandID and $FF]^) := not Boolean(Pointers[CommandID and $FF]^);
        atSetByte: Byte(Pointers[CommandID and $FF]^) := (CommandID shr 8) and $FFFF;
        atSetWord: Word(Pointers[CommandID and $FF]^) := (CommandID shr 8) and $FFFF;
        atSetLongWord: LongWord(Pointers[CommandID and $FF]^) := (CommandID shr 8) and $FFFF;
      end
    end else begin
      Current := NextBinding;
      EndPass := False;
    end;
    LastTime := GetTickCount;
  end;
end;

begin
//  if not Active then Exit;
  Move(KeyboardState[0], LastKeyState[0], 256);
  GetInputState;
  if EventFilter and efNoBond > 0 then begin
    if QueryInput and qirMouseMoved > 0 then MouseEvent := InputEvents[0].EventType else MouseEvent := btNone;
  end else MouseEvent := GetMouseEvent;
//  if MouseEvent = LastMouseEvent then MouseEvent := btNone;

  if (EventFilter and efBond > 0) and (Queue <> nil) then for i := 0 to TotalBindings - 1 do with Bindings[i] do if First <> nil then begin
    EndPass := False; Terminated := False;
    while not EndPass do begin
      EndPass := True;
      if Current <> First then begin
        if (Timeout > 0) then begin                                   // Handle timeout
          CurTime := GetTickCount;
          if CurTime - LastTime > Timeout then begin
            Current := First;
          end;
        end;

        CurTerm := Terminator;
        while (CurTerm <> nil) and (Current <> First) do begin
          with CurTerm^ do case BindType of
            btKeyDown: if (KeyboardState[BindData] >= 128) and (LastKeyState[BindData] < 128) then Break;//Current := First;
            btKeyUp: if (KeyboardState[BindData] < 128) and (LastKeyState[BindData] >= 128) then Break;//Current := First;
            btMouseMove..btStrokeRightDown: if MatchMouseEvent(CurTerm^.BindType, MouseEvent) then Break;
          end;
          CurTerm := CurTerm^.NextBinding;
        end;
        Terminated := CurTerm <> nil;
      end;
      if Terminated then begin
        Current := First;
      end else with Current^ do begin
        case BindType of
          btKeyDown: if (KeyboardState[BindData] >= 128) and (LastKeyState[BindData] < 128) then MatchBinding(BindData);
          btKeyUp: if (KeyboardState[BindData] < 128) and (LastKeyState[BindData] >= 128) then MatchBinding(BindData);
          btMouseMove: if (MouseState.lX <> 0) or (MouseState.lY <> 0) then MatchBinding((MouseState.lY) shl 16 + (MouseState.lX));
          btMouseHMove: if MouseState.lX <> 0 then MatchBinding(MouseState.lX);
          btMouseVMove: if MouseState.lY <> 0 then MatchBinding(MouseState.lY);
          btMouseRoll: if MouseState.lZ <> 0 then MatchBinding(MouseState.lZ);
        end;
        if BindType = MouseEvent then MatchBinding(0);
      end;
    end;
  end else begin
    MouseXCounter := 0; MouseYCounter := 0;
  end;
end;

function TController.GetMouseEvent: TBindTypes;   // ToDo: mouse roll support
const MouseTolerance = 3;
var Rel, RelX, RelY: Single;
begin
  Result := btNone;
  Inc(MouseXCounter, MouseState.LX);
  Inc(MouseYCounter, MouseState.LY);
  if Abs(MouseXCounter) > 0 then Result := btMouseHMove;
  if Abs(MouseYCounter) > Abs(MouseXCounter) then Result := btMouseVMove;
  if GetTickCount - MouseQueryTick >= MouseTimeOut then begin
    MouseQueryTick := GetTickCount;
    if MouseYCounter <> 0 then begin
      Rel := MouseXCounter / MouseYCounter;
      if MouseYCounter > 0 then RelX := Rel else RelX := -Rel;
      if RelX < -MouseTolerance then Result := btStrokeLeft;
      if RelX > MouseTolerance then Result := btStrokeRight;
      if MouseXCounter > 0 then RelY := Rel else RelY := -Rel;
      if (RelY < 1/MouseTolerance) and (RelY > 0) then Result := btStrokeDown;
      if (RelY > -1/MouseTolerance) and (RelY < 0) then Result := btStrokeUp;
      if (Rel > 1-1/MouseTolerance) and (Rel < 1+1/MouseTolerance) then begin
        if MouseYCounter > 0 then Result := btStrokeRightDown else Result := btStrokeLeftUp;
      end;
      if (Rel > -1-1/MouseTolerance) and (Rel < -1+1/MouseTolerance) then begin
        if MouseYCounter > 0 then Result := btStrokeLeftDown else Result := btStrokeRightUp;
      end;
    end else begin
      if MouseXCounter < -MouseTolerance then Result := btStrokeLeft;
      if MouseXCounter > MouseTolerance then Result := btStrokeRight;
    end;
    MouseXCounter := 0; MouseYCounter := 0;
  end;
end;

procedure TController.SetMouseAnchor(const X, Y: Integer);
var Res: Integer;
begin
//  if not Active then Exit;
  ApplyMouseAnchor(X, Y);
  MouseAnchorX := X; MouseAnchorY := Y;
{$IFDEF DEBUGMODE} 
  AdjustCursorVisibility(True);
  Res := AdjustCursorVisibility(False);
  if X = -1 then
   Log('*** Anchor reset: ' + IntToStr(Res)) else
    Log('*** Anchor set: ' + IntToStr(Res));
 {$ENDIF}    
end;

function TController.QueryInput: Integer;
var i: Integer;

procedure AddEvent(EType: TBindTypes; EData: Smallint);
begin
  Assert(TotalEvents < MaxEvents, 'TController.QueryInput: too many events');
  if (EType = btNone) or (TotalEvents >= MaxEvents) then Exit;

  Inc(TotalEvents);
  InputEvents[TotalEvents-1].EventType := EType;
  InputEvents[TotalEvents-1].EventData := EData;
  case EType of
    btKeyDown: begin
      Result := Result or qirKeyPressed or qirKeyChanged;
      if (EData = IK_LSHIFT) or (EData = IK_RSHIFT) or (EData = IK_SHIFT) then ShiftState := True;
      if (EData = IK_LCONTROL) or (EData = IK_RCONTROL) or (EData = IK_CONTROL) then CtrlState := True;
      if (EData = IK_LALT) or (EData = IK_RALT) or (EData = IK_ALT) then AltState := True;
    end;
    btKeyUp: begin
      Result := Result or qirKeyChanged;
      if (EData = IK_LSHIFT) or (EData = IK_RSHIFT) or (EData = IK_SHIFT) then ShiftState := False;
      if (EData = IK_LCONTROL) or (EData = IK_RCONTROL) or (EData = IK_CONTROL) then CtrlState := False;
      if (EData = IK_LALT) or (EData = IK_RALT) or (EData = IK_ALT) then AltState := False;
    end;
    btStrokeLeft..btStrokeRightDown: Result := Result or qirMouseMoved;
  end;
end;

begin
  Result := qirNone;
  TotalEvents := 0;
  AddEvent(GetMouseEvent, 0);
  for i := 0 to 255 do begin
    if KeyboardState[i] <> LastKeyState[i] then begin
      if KeyboardState[i] >= 128 then AddEvent(btKeyDown, i) else AddEvent(btKeyUp, i);
    end;
  end;
end;

procedure TController.SetMouseWindow(const X1, Y1, X2, Y2: Integer);
begin
//  if not Active then Exit;
  MouseWindow.Left := X1; MouseWindow.Top := Y1;
  MouseWindow.Right := X2; MouseWindow.Bottom := Y2;
end;

procedure TController.InputEventsToCommands(var CommandQueue: TCommandQueue);
var i: Integer; MembersKind: Word;
begin
  for i := 0 to TotalEvents-1 do begin
    if (InputEvents[i].EventType = btKeyDown) or (InputEvents[i].EventType = btKeyUp) then begin
      if (InputEvents[i].EventData = IK_MOUSELEFT) or (InputEvents[i].EventData = IK_MOUSEMIDDLE) or (InputEvents[i].EventData = IK_MOUSERIGHT) then
       MembersKind := MembersKind or bmMouseButtons else
        MembersKind := MembersKind or bmKeyboard;

      if (InputEvents[i].EventType = btKeyDown) then begin
        CommandQueue.Add(cmdKeyDown, [InputEvents[i].EventData, MembersKind]);
        KeyQueryState[InputEvents[i].EventData].State := kqsDown;
      end else begin
        CommandQueue.Add(cmdKeyUp, [InputEvents[i].EventData, MembersKind]);
        if KeyQueryState[InputEvents[i].EventData].State = kqsDown then begin
          CommandQueue.Add(cmdKeyClick, [InputEvents[i].EventData, MembersKind]);
          if (KeyQueryState[InputEvents[i].EventData].LastClickedTime <> 0) and (GetTickCount - KeyQueryState[InputEvents[i].EventData].LastClickedTime < DblClickTimeout) then CommandQueue.Add(cmdKeyDblClick, [InputEvents[i].EventData, MembersKind]);
          KeyQueryState[InputEvents[i].EventData].LastClickedTime := GetTickCount;
        end;
        KeyQueryState[InputEvents[i].EventData].State := kqsUp;
      end;
    end;
  end;
end;

procedure TController.HandleCommand(const Command: TCommand);
begin
  case Command.CommandID of
    cmdActivated: begin
//      if MouseAnchorX <> -1 then ApplyMouseAnchor(MouseAnchorX, MouseAnchorY);
      Active := True;
      ProcessInput(nil, efNone);
      SetSystemCursor(FSystemCursor);
    end;
    cmdDeactivated, cmdMinimized: begin
      Active := False;
//      MouseAnchorX := -1;
      ApplyMouseAnchor(-1, -1);
    end;
    cmdResized: begin
    end;
    cmdCharInput: if Command.Arg1 >= 32 then
                   FInputBuffer := FInputBuffer + Char(Command.Arg1) else
                    if Command.Arg1 = 8 then if FInputBuffer <> '' then
                     FInputBuffer := Copy(FInputBuffer, 0, Length(FInputBuffer)-1) else
                      FInputBuffer := Chr(Command.Arg1);
  end;
end;

function TController.MouseAnchored: Boolean;
begin
  Result := MouseAnchorX <> -1;
end;

procedure TController.SetSystemCursor(const Value: Boolean);
begin
//  if not Active then Exit;
  FSystemCursor := Value;
  if FSystemCursor then ShowCursor else HideCursor;
end;

procedure TController.ApplyMouseAnchor(const X, Y: Integer);
var SX, SY: Integer;
begin
  if X <> -1 then begin                          // Set anchor
//    if not MouseAnchored then begin
      PreAnchorMouseX := MouseX; PreAnchorMouseY := MouseY;
//    end;
//    Log(Format('Set anchor to [%D, %D] at [%D, %D].', [X, Y, MouseX, MouseY]));
  end else begin                                 // Release anchor
    if MouseAnchored then begin
      MouseX := PreAnchorMouseX; MouseY := PreAnchorMouseY;
      SX := MouseX; SY := MouseY;
      ClientToScreen(Handle, SX, SY);
      SetCursorPos(SX, SY);
    end;
  end;
end;

function TController.GetInputBuffer: ShortString;
begin
  Result := FInputBuffer;
  FInputBuffer := '';
end;

end.
