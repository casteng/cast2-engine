{ Audiere object oriented wrapper usage example
 (C) 2008 George Bakhtadze
 Loads and plays sounds from files given in command line parameters }
program AudiereOOEx;
uses
  DLSound;

{$APPTYPE CONSOLE}

var
  Sounds: TAudiereSound;

procedure Error(const ErrorStr: string);
begin
  Writeln('Error: ', ErrorStr);
  Halt(1);
end;

begin
//  SndTimer := TTimer.Create(Sounds.HandleMessage);
  Sounds := TAudiereSound.Create(nil);

  if ParamCount < 1 then Error('Usage: AudiereOOEx <File> [File to stream]');

  Writeln('Loading sound from file "', ParamStr(1), '"');
  Sounds.Load('Sound1', ParamStr(1), False);

  if ParamCount > 1 then begin
    Writeln('Loading streaming sound from file "', ParamStr(2), '"');
    Sounds.Load('Streaming sound', ParamStr(2), True);
  end;

  Writeln('Press enter to stop playing sounds.');

  Sounds.SetVolume('Sound1', 100);
  Sounds.Play('Sound1');

  Sounds.SetVolume('Streaming sound', 50);
  Sounds.SetRepeat('Streaming sound', True);
  Sounds.Play('Streaming sound');

  Readln;

  Sounds.Free;
end.
