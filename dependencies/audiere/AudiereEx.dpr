{ Audiere usage example
 (C) 2008 George Bakhtadze
 Loads and plays sound from file given in command line parameter }
program AudiereEx;
uses
  Audiere;

{$APPTYPE CONSOLE}

var
  s: PChar;
  Device: TAdrAudioDevice;
  Stream: TAdrOutputStream;
  Source: TAdrSampleSource;

procedure Error(const ErrorStr: string);
begin
  Writeln('Error: ', ErrorStr);
  Halt(1);
end;

begin
  // Retrieve version, supported formats etc information
  s := AdrGetVersion;
  Writeln('Audiere version: ' + s);
  s := AdrGetSupportedFileFormats;
  Writeln('  formats supported: ' + s);
  s := AdrGetSupportedAudioDevices;
  Writeln('  devices supported: ' + s);

  if ParamCount < 1 then Error('Usage: AudiereEx <File>');

  Writeln('Loading sound from file "', ParamStr(1), '"');
  // Open default device
  Device := AdrOpenDevice('', '');

  if not Assigned(Device) then Error('Can''t open device');
  // Open file
  Stream := nil;
  Source := AdrOpenSampleSource(PChar(ParamStr(1)), FF_AUTODETECT);
  if Assigned(Source) then
    Stream := AdrOpenSound(Device, Source, False);
  if not Assigned(Stream) then Error('Can''t open file "' + ParamStr(1) + '"');

  Writeln('Playing sound...');
  Writeln('Press enter to stop.');

  Stream.SetVolume(1.0);
  Stream.Play;

  Readln;

  Stream.Stop;
end.
