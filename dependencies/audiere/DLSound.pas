(*
 @Abstract(Simple Audiere-based audio unit)
 (C) 2006-2008 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: May 16, 2007 <br>
 Unit contains simple audiere-based sound and music implementation
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit DLSound;

interface

uses
  BaseMsg, BaseTypes, Basics, BaseClasses,
  Timer,
  SysUtils,
  Logger,
  Audiere;

const
  // Sounds collection capacity increment step
  SoundsCapacityStep = 16;
  // Default minimal delay between sound play
  DefaultDelay: TSecond = 0.150;

type
  TAdrSound = packed record
    Name: string[43];
    MinDelay: TSecond;
    TimeStamp: Timer.TTimeMark;
    Volume: Single;
    Device: TAdrAudioDevice;
    Stream: TAdrOutputStream;
    Source: TAdrSampleSource;
  end;

  // Sound management class
  TAudiereSound = class(TSubsystem)
  private
    FTimer: TTimer;
    MasterVolume: Single;
    FSounds: array of TAdrSound;
    TotalSounds: Integer;
    function IndexOf(const Name: string): Integer;
    procedure UnloadByIndex(Index: Integer);
  public
    constructor Create(ATimer: TTimer);
    destructor Destroy; override;
    procedure HandleMessage(const Msg: TMessage); override;
    { Loads a sound from file FileName. If AStreamin is false the file will completely loaded into memory.
      The loaded sound later can be referenced by Name. }
    procedure Load(const Name, FileName: string; AStreaming: Boolean);
    // Frees a sound with the given name
    procedure UnLoad(const Name: string);
    // Sets volume of the named sound. If name is empty master (affecting all sounds) volume will be changed. Volume range is [0..100].
    procedure SetVolume(const Name: string; Value: Integer);
    // Enables or disables repeating of the named sound
    procedure SetRepeat(const Name: string; Value: Boolean);
    // Sets minimal delay between two possible subsequent Play() calls of the named sound
    procedure SetDelay(const Name: string; Value: Double);
    // Plays the named sound. Many instances of the same sound can be played simultaneously.
    procedure Play(const Name: string);
    // Stops the sound playback
    procedure Stop(const Name: string);
  end;

implementation

{ TAudiereSound }

function TAudiereSound.IndexOf(const Name: string): Integer;
begin
  Result := TotalSounds-1;
  while (Result >= 0) and (FSounds[Result].Name <> Name) do Dec(Result);
end;

procedure TAudiereSound.UnloadByIndex(Index: Integer);
begin
  Assert((Index >= 0) and (Index < TotalSounds), '');
  if (Index < 0) or (Index >= TotalSounds) then Exit;
  
  FSounds[Index].Stream.Stop;
//  if Assigned(FSounds[Index].Stream) then FreeAndNil(FSounds[Index].Stream);
//  if Assigned(FSounds[Index].Source) then FreeAndNil(FSounds[Index].Source);
//  if Assigned(FSounds[Index].Device) then FreeAndNil(FSounds[Index].Device);

  Dec(TotalSounds);
  FSounds[Index] := FSounds[TotalSounds];
end;

constructor TAudiereSound.Create(ATimer: TTimer);
var s: PChar;
begin
  Assert(Assigned(ATimer), 'TAudiereSound.Create: ATimer should be assigned');
  MasterVolume := 0.5;
  s := AdrGetVersion;
  Log('Audiere version: ' + s, lkNotice);
  s := AdrGetSupportedFileFormats;
  Log('  formats supported: ' + s);
  s := AdrGetSupportedAudioDevices;
  Log('  devices supported: ' + s);
  FTimer := ATimer;
end;

destructor TAudiereSound.Destroy;
var i: Integer;
begin
  for i := TotalSounds-1 downto 0 do UnloadByIndex(i);
  inherited;
end;

procedure TAudiereSound.Load(const Name, FileName: string; AStreaming: Boolean);
begin
  if IndexOf(Name) <> -1 then begin
    Log('TAudiereSound.Load: Sound "' + Name + '" already defined', lkError);
    Exit;
  end;

  if Length(FSounds) <= TotalSounds then SetLength(FSounds, Length(FSounds) + SoundsCapacityStep);
  FSounds[TotalSounds].Stream := nil;

  FSounds[TotalSounds].Name   := Name;
  FSounds[TotalSounds].Volume := 0.5;
  FSounds[TotalSounds].Device := AdrOpenDevice('', '');
  if Assigned(FSounds[TotalSounds].Device) then begin
    FSounds[TotalSounds].Source := AdrOpenSampleSource(PChar(Filename), FF_AUTODETECT);
    if Assigned(FSounds[TotalSounds].Source) then
      FSounds[TotalSounds].Stream := AdrOpenSound(FSounds[TotalSounds].Device, FSounds[TotalSounds].Source, AStreaming);
  end;

  if FSounds[TotalSounds].Stream = nil then begin
//    if Assigned(FSounds[TotalSounds].Source) then FreeAndNil(FSounds[TotalSounds].Source);
//    if Assigned(FSounds[TotalSounds].Device) then FreeAndNil(FSounds[TotalSounds].Device);
    Log('TAudiereSound.Load: Error loading sound file "' + FileName + '"', lkError);
  end else begin
    FSounds[TotalSounds].Stream.SetVolume(FSounds[TotalSounds].Volume * MasterVolume);
    FSounds[TotalSounds].TimeStamp.Signature := NullSignature;
    FSounds[TotalSounds].MinDelay := DefaultDelay;
    Inc(TotalSounds);
  end;
end;

procedure TAudiereSound.UnLoad(const Name: string);
var i: Integer;
begin
  i := IndexOf(Name);
  if i >= 0 then UnloadByIndex(i) else begin
    Log('TAudiereSound.UnLoad: Sound "' + Name + '" not found', lkWarning); 
  end;
end;

procedure TAudiereSound.SetVolume(const Name: string; Value: Integer);
var i: Integer;
begin
  if Name = '' then begin
    MasterVolume := MinS(1, Value/100);
    for i := 0 to TotalSounds-1 do FSounds[i].Stream.SetVolume(FSounds[i].Volume * MasterVolume);
  end else begin
    i := IndexOf(Name);
    if i >= 0 then begin
      FSounds[i].Volume := MinS(1, Value/100);
      FSounds[i].Stream.SetVolume(FSounds[i].Volume * MasterVolume);
    end else begin
      Log('TAudiereSound.SetVolume: Sound "' + Name + '" not found', lkWarning); 
    end;
  end;
end;

procedure TAudiereSound.SetRepeat(const Name: string; Value: Boolean);
var i: Integer;
begin
  i := IndexOf(Name);
  if i >= 0 then
    FSounds[i].Stream.SetRepeat(Value) else begin
      Log('TAudiereSound.SetRepeat: Sound "' + Name + '" not found', lkWarning); 
    end;
end;

procedure TAudiereSound.SetDelay(const Name: string; Value: Double);
var i: Integer;
begin
  i := IndexOf(Name);
  if i >= 0 then
    FSounds[i].MinDelay := Value else begin
      Log('TAudiereSound.SetDelay: Sound "' + Name + '" not found', lkWarning); 
    end;
end;

procedure TAudiereSound.Play(const Name: string);
var i: Integer;
begin
  i := IndexOf(Name);
  if i >= 0 then begin
    if FTimer.IsIntervalPassed(FSounds[i].Timestamp, True, FSounds[i].MinDelay) then begin
      FSounds[i].Stream.Reset;
      FSounds[i].Stream.Play;
    end;
  end else
    Log('TAudiereSound.Play: Sound "' + Name + '" not found', lkWarning);
end;

procedure TAudiereSound.Stop(const Name: string);
var i: Integer;
begin
  i := IndexOf(Name);
  if i >= 0 then
    FSounds[i].Stream.Stop else begin
      Log('TAudiereSound.Stop: Sound "' + Name + '" not found', lkWarning);
    end;
end;

procedure TAudiereSound.HandleMessage(const Msg: TMessage);
begin
//  if
end;

end.
