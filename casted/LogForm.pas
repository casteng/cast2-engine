{$I GDefines.inc}
unit LogForm;

interface

uses
  Logger,
  BaseTypes,
  OSUtils, VCLHelper,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ComCtrls;

type
  TMemosAppender = class(TAppender)
    procedure AppendLog(const Time: TDateTime; const Str: string; CodeLoc: PCodeLocation; Level: TLogLevel); override;
  end;

  TLogF = class(TForm)
    ClearLogBut: TButton;
    LogModeCBox: TComboBox;
    Label1: TLabel;
    OnTopBut: TSpeedButton;
    LogPageControl: TPageControl;
    TabSheet1: TTabSheet;
    LogMemo: TMemo;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    TabSheet4: TTabSheet;
    TabSheet5: TTabSheet;
    DebugLogMemo: TMemo;
    InfoLogMemo: TMemo;
    WarningsLogMemo: TMemo;
    ErrorsLogMemo: TMemo;
    procedure LogModeCBoxChange(Sender: TObject);
    procedure ClearLogButClick(Sender: TObject);
    procedure OnTopButClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
  public
    procedure BeginUpdateLog;
    procedure EndUpdateLog;
  private
    MemosAppender: TMemosAppender;
  end;

var
  LogF: TLogF;

implementation

{$R *.dfm}

{ TCEDLog }

procedure TMemosAppender.AppendLog(const Time: TDateTime; const Str: string; CodeLoc: PCodeLocation; Level: TLogLevel);
begin
  if (LogF = nil) or (LogF.LogMemo = nil) then Exit;
  if Level <> lkDebug then LogF.LogMemo.Lines.Add(Formatter(Time, Str, CodeLoc, Level));
  case Level of
    lkDebug              : LogF.DebugLogMemo.Lines.Add(Formatter(Time, Str, CodeLoc, Level));
    lkInfo, lkNotice     : LogF.InfoLogMemo.Lines.Add(Formatter(Time, Str, CodeLoc, Level));
    lkWarning            : LogF.WarningsLogMemo.Lines.Add(Formatter(Time, Str, CodeLoc, Level));
    lkError, lkFatalError: LogF.ErrorsLogMemo.Lines.Add(Formatter(Time, Str, CodeLoc, Level));
  end;
end;

{ TLogF }

procedure TLogF.FormCreate(Sender: TObject);
begin
  {$IFDEF LOGGING}
    MemosAppender := TMemosAppender.Create(llFull);
    AddAppender(MemosAppender);
  {$ELSE}
    LogF.LogMemo.Lines.Add('The project was compiled without logging');
  {$ENDIF}
end;

procedure TLogF.FormDestroy(Sender: TObject);
begin
  RemoveAppender(MemosAppender);
  FreeAndNil(MemosAppender);
  LogF := nil;
end;

procedure TLogF.LogModeCBoxChange(Sender: TObject);
var i: Integer; Levels: TLogLevels;
begin
  
  Levels := [];
  for i := Ord(High(TLogLevel)) downto LogModeCBox.ItemIndex do Levels := Levels + [TLogLevel(i)];
  MemosAppender.LogLevels := Levels;
  
end;

procedure TLogF.ClearLogButClick(Sender: TObject);
begin
  case LogPageControl.ActivePageIndex of
    0: LogMemo.Clear;
    1: DebugLogMemo.Clear;
    2: InfoLogMemo.Clear;
    3: WarningsLogMemo.Clear;
    4: ErrorsLogMemo.Clear;
  end;
end;

procedure TLogF.OnTopButClick(Sender: TObject);
begin
  if OnTopBut.Down then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TLogF.BeginUpdateLog;
begin
//
end;

procedure TLogF.EndUpdateLog;
begin
//
end;

procedure TLogF.FormShow(Sender: TObject);
begin
  CheckParentSize(Self);
end;

end.
