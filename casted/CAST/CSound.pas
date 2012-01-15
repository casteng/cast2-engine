{$Include GDefines}
{$Include CDefines}
unit CSound;

interface

uses
  Windows, MMSystem, DirectSound,
  SysUtils,
  
  Logger,
  
  Basics, CTypes, CRes;

const
  asStopped = 0; asPlay = 1; asPlayLooped = 2;

type
  TAudioManager = class;

  TSound = class
    Name: TShortName;
    ResourceIndex: Integer;
    Audio: TAudioManager;
    Length: Cardinal;
    Buffer: Pointer;
    Looping: Boolean;
    MinPlayInterval: Cardinal;
//    Buffer: IDirectSoundBuffer;
    constructor Create(const AName: TShortName; AAudioManager: TAudioManager);
    function Save(Stream: TDStream): Integer; virtual;
    function Load(Stream: TDStream): Integer; virtual;
    procedure Play; virtual;
    procedure Stop; virtual;
    destructor Free;
  private
    FPriority: Cardinal;
    FVolume: Single;
    FPan, FFrequency: Cardinal;
    FFormat: Cardinal;
    FStatus: Cardinal;
    LastPlayedTick: Cardinal;
    procedure SetPriority(const Value: Cardinal);
    procedure SetPan(const Value: Cardinal);
    procedure SetFormat(const Value: Cardinal);
    procedure SetFrequency(const Value: Cardinal);
    procedure SetVolume(const Value: Single);
    procedure SetStatus(const Value: Cardinal);
  public
    property Priority: Cardinal read FPriority write SetPriority;
    property Volume: Single read FVolume write SetVolume;
    property Pan: Cardinal read FPan write SetPan;
    property Frequency: Cardinal read FFrequency write SetFrequency;
    property Format: Cardinal read FFormat write SetFormat;
    property Status: Cardinal read FStatus write SetStatus;
  end;

  TAudioManager = class
    Resources: TResourceManager;
    Sounds: array of TSound; TotalSounds: Integer;
    DefaultFormat: Integer;
    DefaultVolume: Single;              // [0..1]
    Initialized, Enabled: Boolean;
    constructor Initialize(AHandle: Cardinal; AResources: TResourceManager); virtual; abstract;
    function SaveSounds(Stream: TDStream): Integer; virtual;
    function LoadSounds(Stream: TDStream): Integer; virtual;
    function CreateSound(Name, ResourceName: TShortName): TSound; virtual; abstract;
    function AddSound(ASound: TSound): TSound; virtual; abstract;
    function ReplaceSound(Index: Integer; ASound: TSound): TSound; virtual; abstract;
    procedure DeleteSound(Index: Integer); virtual; abstract;
    procedure CreateSoundBuffer(Sound: TSound; ResourceName: TShortName); virtual; abstract;
    procedure FreeSoundBuffer(Sound: TSound); virtual; abstract;
    procedure UpdateSound(Sound: TSound; Src: Pointer; Size: Cardinal); virtual; abstract;
    function SoundByName(Name: TShortName): TSound; virtual;
    function PlaySound(Sound: TSound; ResetSound: Boolean = True): Boolean; virtual;
    function PlaySoundV(Sound: TSound; const Volume: Single; ResetSound: Boolean = True): Boolean; virtual;
    procedure StopSound(Sound: TSound); virtual; abstract;
    destructor Shutdown; virtual; abstract;
  end;

  TDX8AudioManager = class(TAudioManager)
    DirectSound: IDirectSound8;
    constructor Initialize(AHandle: Cardinal; AResources: TResourceManager); override;
    function CreateSound(Name, ResourceName: TShortName): TSound; override;
    function AddSound(ASound: TSound): TSound; override;
    function ReplaceSound(Index: Integer; ASound: TSound): TSound; override;
    procedure DeleteSound(Index: Integer); override;
    procedure CreateSoundBuffer(Sound: TSound; ResourceName: TShortName); override;
    procedure FreeSoundBuffer(Sound: TSound); override;
    procedure UpdateSound(Sound: TSound; Src: Pointer; Size: Cardinal); override;
    function PlaySound(Sound: TSound; ResetSound: Boolean = True): Boolean; override;
    procedure StopSound(Sound: TSound); override;
    destructor Shutdown; override;
  end;

implementation

{ TDX8Audio }

constructor TDX8AudioManager.Initialize(AHandle: Cardinal; AResources: TResourceManager);
 {$IFDEF EXTLOGGING}
const CanStr: array[False..True] of string[3] = ('[ ]', '[X]');
 {$ENDIF}
var Res: HResult;
 {$IFDEF EXTLOGGING} DSCaps: TDSCaps; {$ENDIF}
begin
  Initialized := False;

  if DSoundDLL = 0 then begin

    Log('Can''t start DirectSound: DirectX 8 or greater not installed', lkError);

    Exit;
  end;

  DefaultFormat := PackSoundFormat(44100, 16, 1);
  DefaultVolume := 0;
  Resources := AResources;
{$IFDEF DIRECTSOUNDNIL}
  DirectSound := nil;
{$ELSE}
  DirectSoundCreate8(nil{@DSDEVID_DefaultPlayback}, DirectSound, nil);
{$ENDIF}


  Log('Starting DX8 Audio', lkTitle);
  if DirectSound = nil then Log('Error creating DirectSound object', lkFatalError) else
   Log('DirectSound object succesfully created');

  if DirectSound = nil then Exit;
  Res := DirectSound.SetCooperativeLevel(AHandle{GetCurrentProcess}, DSSCL_PRIORITY);

  if Failed(Res) then begin

    Log('Error setting DirectSound cooperative level', lkFatalError);

    Exit;
  end;
 {$IFDEF EXTLOGGING}
  Log('Checking sound device capabilites', lkTitle);
  DSCaps.dwSize := SizeOf(DSCaps);
  DirectSound.GetCaps(DSCaps);
  Log(' Driver caps', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_CONTINUOUSRATE > 0]+' The device supports all sample rates between '+IntToStr(DSCaps.dwMinSecondarySampleRate)+' and '+IntToStr(DSCaps.dwMaxSecondarySampleRate), lkInfo);
  Log(CanStr[not (DSCaps.dwFlags and DSCAPS_EMULDRIVER > 0)]+' The device have a DirectSound driver installed. No emulation used', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_PRIMARY16BIT > 0]+' The device supports primary sound buffers with 16-bit samples', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_PRIMARY8BIT > 0]+' The device supports primary buffers with 8-bit samples', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_PRIMARYMONO > 0]+' The device supports monophonic primary buffers', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_PRIMARYSTEREO > 0]+' The device supports stereo primary buffers', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_SECONDARY16BIT > 0]+' The device supports hardware-mixed secondary sound buffers with 16-bit samples', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_SECONDARY8BIT > 0]+' The device supports hardware-mixed secondary buffers with 8-bit samples', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_SECONDARYMONO > 0]+' The device supports hardware-mixed monophonic secondary buffers', lkInfo);
  Log(CanStr[DSCaps.dwFlags and DSCAPS_SECONDARYSTEREO > 0]+' The device supports hardware-mixed stereo secondary buffers', lkInfo);
  Log('Minimum hardware sample rate: '+IntToStr(DSCaps.dwMinSecondarySampleRate), lkInfo);
  Log('Maximum hardware sample rate: '+IntToStr(DSCaps.dwMaxSecondarySampleRate), lkInfo);
  Log('Maximum hardware mixing buffers: '+IntToStr(DSCaps.dwMaxHwMixingAllBuffers), lkInfo);
  Log('Maximum hardware mixing static buffers: '+IntToStr(DSCaps.dwMaxHwMixingStaticBuffers), lkInfo);
  Log('Maximum hardware mixing streaming buffers: '+IntToStr(DSCaps.dwMaxHwMixingStreamingBuffers), lkInfo);
  Log('Maximum hardware 3D buffers: '+IntToStr(DSCaps.dwMaxHw3DAllBuffers), lkInfo);
  Log('Maximum hardware 3D static buffers: '+IntToStr(DSCaps.dwMaxHw3DStaticBuffers), lkInfo);
  Log('Maximum hardware 3D streaming buffers: '+IntToStr(DSCaps.dwMaxHw3DStreamingBuffers), lkInfo);
  Log('Total sound device memory: '+IntToStr(DSCaps.dwTotalHwMemBytes)+' bytes', lkInfo);
  Log('Free sound device memory: '+IntToStr(DSCaps.dwFreeHwMemBytes)+' bytes', lkInfo);
  Log('Data transfer rate to hardware sound buffer: '+IntToStr(DSCaps.dwUnlockTransferRateHwBuffers)+' KBytes/sec', lkInfo);
  Log('Software mixing CPU overhead: '+IntToStr(DSCaps.dwPlayCpuOverheadSwBuffers )+'%', lkInfo);
 {$ENDIF}
  DefaultVolume := 1;
  Enabled := True;
  Initialized := True;
end;

function TDX8AudioManager.CreateSound(Name, ResourceName: TShortName): TSound;
begin
  Result := nil;
  if not Initialized then Exit;
  Result := TSound.Create(Name, Self);
  Result.ResourceIndex := Resources.IndexByName(ResourceName);
  CreateSoundBuffer(Result, ResourceName);
//  if Result.Buffer = nil then begin Result.Free; Result := nil; Exit; end;
  Result.Length := Resources[Result.ResourceIndex].Size;
  Result.Priority := 0;
  Result.Volume := DefaultVolume;
  Result.Pan := 0;
  Result.Format := Resources[Result.ResourceIndex].Format;
  Result.Frequency := UnPackSoundFormat(Resources[Result.ResourceIndex].Format).SampleRate;
  Result.Status := asStopped;
end;

function TDX8AudioManager.AddSound(ASound: TSound): TSound;
begin
  Result := nil;
  if not Initialized then Exit;
  Inc(TotalSounds); SetLength(Sounds, TotalSounds);
  Result := ASound;
  Result.Audio := Self;
  Sounds[TotalSounds-1] := ASound;
end;

function TDX8AudioManager.ReplaceSound(Index: Integer; ASound: TSound): TSound;
begin
  if (Index < 0) or (Index >= TotalSounds) then Exit;
  Sounds[Index].Free;
  Sounds[Index] := ASound;
end;

procedure TDX8AudioManager.DeleteSound(Index: Integer);
var i: Integer;
begin
  if (Index < 0) or (Index >= TotalSounds) then Exit;
  for i := Index to TotalSounds-2 do Sounds[i] := Sounds[i+1];
  Dec(TotalSounds); SetLength(Sounds, TotalSounds);
end;

procedure TDX8AudioManager.CreateSoundBuffer(Sound: TSound; ResourceName: TShortName);
var
  SRes: Integer;
  PCMWF: PCMWAVEFORMAT;
  DSBDesc: TDSBUFFERDESC;
  Res: HResult;
  DSBuf: IDirectSoundBuffer;
begin
  if not Initialized then Exit;

  Log('Creating sound buffer', lkTitle);


  SRes := Resources.IndexByName(ResourceName);
  if SRes = -1 then begin

    Log('Sound resource "'+ResourceName+'" not found', lkWarning);

    Exit;
  end;

  PCMWF.wf.wFormatTag := WAVE_FORMAT_PCM;
  PCMWF.wf.nChannels := UnPackSoundFormat(Resources[SRes].Format).Channels;
  PCMWF.wf.nSamplesPerSec := UnPackSoundFormat(Resources[SRes].Format).SampleRate;
  PCMWF.wf.nBlockAlign := UnPackSoundFormat(Resources[SRes].Format).BlockAlign;
  PCMWF.wf.nAvgBytesPerSec := pcmwf.wf.nSamplesPerSec * pcmwf.wf.nBlockAlign;
  PCMWF.wBitsPerSample := UnPackSoundFormat(Resources[SRes].Format).BitsPerSample;

  FillChar(dsbdesc, SizeOf(TDSBUFFERDESC), 0);
  DSBDesc.dwSize := SizeOf(TDSBUFFERDESC);
  DSBDesc.dwFlags := DSBCAPS_CTRLPAN or DSBCAPS_CTRLVOLUME or DSBCAPS_CTRLFREQUENCY;

  DSBDesc.dwBufferBytes := Resources[SRes].Size{*PCMWF.wf.nBlockAlign};           //ToFix: error here
  DSBDesc.lpwfxFormat := PWAVEFORMATEX(@PCMWF);

  Res := DirectSound.CreateSoundBuffer(DSBDesc, DSBuf, nil);
  if Failed(Res) then begin

    Log('Error creating sound buffer. Result: ' + IntToStr(Res) + ' Error #: ' + IntToStr(Res - MAKE_DSHRESULT_), lkError);

    Exit;
  end;
  if Sound.Buffer <> nil then FreeSoundBuffer(Sound);
  Sound.Buffer := Pointer(DSBuf);
  DSBuf._AddRef;
  UpdateSound(Sound, Resources[SRes].Data, Resources[SRes].Size);
end;

procedure TDX8AudioManager.UpdateSound(Sound: TSound; Src: Pointer; Size: Cardinal);
var PTR1, PTR2: Pointer; Bytes1, Bytes2: Cardinal; Res: HResult;
begin
  if not Initialized then Exit;
//  inherited;
  Sound.Length := Resources[Sound.ResourceIndex].Size;
  Res := IDirectSoundBuffer(Sound.Buffer).Lock(0, Size, PTR1, Bytes1, PTR2, Bytes2, 0);
  Move(Src^, PTR1^, Size);
  Res := IDirectSoundBuffer(Sound.Buffer).Unlock(PTR1, Bytes1, PTR2, Bytes2);
end;

function GetDXVolume(const Volume: Integer): Integer; // Volume [0..255]
begin
  Result := DSBVOLUME_MIN + Trunc(0.5 + Ln(9*Ln(MaxI(0, Volume)+1)/(Ln(2)*8)+1)/Ln(10) * Abs(DSBVOLUME_MIN) );
end;

function TDX8AudioManager.PlaySound(Sound: TSound; ResetSound: Boolean = True): Boolean;
var dsb: IDirectSoundBuffer; DXVolume: Integer;
begin
  Result := False;
  if not inherited Playsound(Sound, ResetSound) then Exit;
  dsb := IDirectSoundBuffer(Sound.Buffer);
  if ResetSound then dsb.SetCurrentPosition(0);

  IDirectSoundBuffer(Sound.Buffer).SetFrequency(Sound.FFrequency);

  DXVolume := GetDXVolume(Trunc(0.5 + Sound.Volume * DefaultVolume * 255));
  IDirectSoundBuffer(Sound.Buffer).SetVolume(DXVolume);
  if Sound.Looping then dsb.Play(0, 0, DSBPLAY_LOOPING) else dsb.Play(0, 0, 0);
  Result := True;
end;

procedure TDX8AudioManager.StopSound(Sound: TSound);
begin
  if not Initialized then Exit;
  IDirectSoundBuffer(Sound.Buffer).Stop;
end;

destructor TDX8AudioManager.Shutdown;
var i: Integer;
begin

  Log('Shutting down DirectSound', lkTitle);

  for i := 0 to TotalSounds-1 do Sounds[i].Free;
  DirectSound := nil;
//  inherited;
end;

{ TSound }

constructor TSound.Create(const AName: TShortName; AAudioManager: TAudioManager);
begin
  Name := AName;
  ResourceIndex := -1;
  Audio := AAudioManager;
  Buffer := nil;
  Looping := False;
  MinPlayInterval := 100;
  Volume := 1;
end;

function TSound.Load(Stream: TDStream): Integer;
var s: TShortName;
begin
  Result := feCannotRead;
  if Stream.Read(Name, SizeOf(Name)) <> feOK then Exit;
  if Stream.Read(s, SizeOf(s)) <> feOK then Exit;
  if Stream.Read(Looping, SizeOf(Looping)) <> feOK then Exit;
  if Stream.Read(FPriority, SizeOf(FPriority)) <> feOK then Exit;
  if Stream.Read(FVolume, SizeOf(FVolume)) <> feOK then Exit;
  if Stream.Read(FPan, SizeOf(FPan)) <> feOK then Exit;
  if Stream.Read(FFrequency, SizeOf(FFrequency)) <> feOK then Exit;
  ResourceIndex := Audio.Resources.IndexByName(s);
  if ResourceIndex = -1 then begin
    Result := feCannotRead; Exit;
  end;
  Result := feOK;
end;

function TSound.Save(Stream: TDStream): Integer;
begin
  Result := feCannotWrite;
  if Stream.Write(Name, SizeOf(Name)) <> feOK then Exit;
  if Stream.Write(Audio.Resources.ResourcesInfo[ResourceIndex].Name, SizeOf(Audio.Resources.ResourcesInfo[ResourceIndex].Name)) <> feOK then Exit;
  if Stream.Write(Looping, SizeOf(Looping)) <> feOK then Exit;
  if Stream.Write(FPriority, SizeOf(FPriority)) <> feOK then Exit;
  if Stream.Write(FVolume, SizeOf(FVolume)) <> feOK then Exit;
  if Stream.Write(FPan, SizeOf(FPan)) <> feOK then Exit;
  if Stream.Write(FFrequency, SizeOf(FFrequency)) <> feOK then Exit;
  Result := feOK;
end;

procedure TSound.Play;
begin
  Audio.PlaySound(Self);
end;

procedure TSound.Stop;
begin
  Audio.StopSound(Self);
end;

destructor TSound.Free;
begin
  Audio.FreeSoundBuffer(Self);
  Buffer := nil;
end;

procedure TSound.SetFormat(const Value: Cardinal);
begin
  FFormat := Value;
end;

procedure TSound.SetFrequency(const Value: Cardinal);
begin
  FFrequency := Value;
end;

procedure TSound.SetPan(const Value: Cardinal);
begin
  FPan := Value;
end;

procedure TSound.SetPriority(const Value: Cardinal);
begin
  FPriority := Value;
end;

procedure TSound.SetStatus(const Value: Cardinal);
begin
  FStatus := Value;
end;

procedure TSound.SetVolume(const Value: Single);
begin
  FVolume := Value;
end;

procedure TDX8AudioManager.FreeSoundBuffer(Sound: TSound);
begin
  IDirectSoundBuffer(Sound.Buffer)._Release;
  Sound.Buffer := nil;
end;

{ TAudioManager }

function TAudioManager.PlaySound(Sound: TSound; ResetSound: Boolean): Boolean;
// Returns True if Sound should be played.
var Tick: Cardinal;
begin
  Result := False;
  if not Initialized then Exit;
  if (not Enabled) or (Sound = nil) or (Sound.Buffer = nil) then Exit;
  Tick := GetTickCount;
  if Tick - Sound.LastPlayedTick < Sound.MinPlayInterval then Exit;

  Sound.LastPlayedTick := Tick;
  Result := True;
end;

function TAudioManager.PlaySoundV(Sound: TSound; const Volume: Single; ResetSound: Boolean): Boolean;
begin
{  Result := False;
  if not Initialized then Exit;
  if (not Enabled) or (Sound = nil) or (Sound.Buffer = nil) then Exit;
  Tick := GetTickCount;
  if Tick - Sound.LastPlayedTick < Sound.MinPlayInterval then Exit;
  Sound.LastPlayedTick := Tick;}
  if (not Enabled) or (Sound = nil) or (Sound.Buffer = nil) then Exit;
  Sound.Volume := Volume;
  PlaySound(Sound, ResetSound);
  Result := True;
end;

function TAudioManager.SaveSounds(Stream: TDStream): Integer;
var i: Integer;
begin
  Result := feCannotWrite;
  if not Initialized then Exit;
  if Stream.Write(TotalSounds, SizeOf(TotalSounds)) <> feOK then Exit;
  for i := 0 to TotalSounds-1 do Sounds[i].Save(Stream);
  Result := feOK;
end;

function TAudioManager.LoadSounds(Stream: TDStream): Integer;
var i, Res: Integer;
begin
  Result := feCannotRead;
  if not Initialized then Exit;
  if Stream.Read(TotalSounds, SizeOf(TotalSounds)) <> feOK then Exit;
  Result := feOK;
  SetLength(Sounds, TotalSounds);
  i := 0;
  while i < TotalSounds do begin
    if Sounds[i] = nil then Sounds[i] := TSound.Create('', Self);
    Res := Sounds[i].Load(Stream);
    if Sounds[i].ResourceIndex = -1 then begin
      Dec(i); Dec(TotalSounds);
    end else CreateSoundBuffer(Sounds[i], Resources.ResourcesInfo[Sounds[i].ResourceIndex].Name);
    if Res <> feOK then Result := Res;
    Inc(i);
  end;
end;

function TAudioManager.SoundByName(Name: TShortName): TSound;
var i: Integer;
begin
  Result := nil;
  if not Initialized then Exit;
  for i := 0 to TotalSounds-1 do if Sounds[i].Name = Name then begin
    Result := Sounds[i]; Exit;
  end;
end;

end.
