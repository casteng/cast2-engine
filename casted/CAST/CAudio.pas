{$Include GDefines}
{$Include CDefines}
unit CAudio;

interface

uses
  Windows, MMSystem, DirectSound,
  SysUtils,
  
  Logger,
  
  Basics, CTypes;

const
  MinDuration = 1000;
  MaxSounds = 1024;
  MaxChannels = 256;
  MaxVolume = 255;
// Sound states
  ssFree = 0; ssJustCreated = 1; ssStopped = 2; ssPlaying = 3; ssLoopDone = 16;
// Loop kinds
  lkNone = 0; lkForward = 1; lkPingPong = 2; lkForwardLoopOnly = 3;
// Play lag
  plAuto = $FFFF;
// Interpolation methods
  imNearest = 0; imLinear = 1; imSpline = 2;

type
  TSound = record
    OrigFormat, Format, Status: Cardinal;
    TotalSamples, NonLoopedSize: Integer;

    Buffer, LoopedBuffer: Pointer;
    CloneOf: Integer;

    LastVolume, LastPan,                           // Values from previous tick (for interpolation)
    Volume, Frequency, Pan: Integer;               // Volume [0..255]

    LoopKind, LoopStart, LoopEnd: Integer;         // Looping not incuding samples at LoopEnd

    Position, PositionFrac: Integer;

    FreeOnStop: Boolean;
  end;

  TAudio = class
    DefaulFormat: Integer;
    Interpolation: Cardinal;
    MasterVolume, MasterPan: Integer;              // Master volume [0..256]
    Initialized, Enabled: Boolean;
    Sounds: array[0..MaxSounds-1] of TSound;
    CurrentSound: Integer;
    StopOnSilence, ConvertBitsPerSample: Boolean;                        // For software mixer implementations
    MixerFormat, MixerBufElSize, MixerBufferFreq, MixerBufferPartLen: Cardinal;
    constructor Create(AHandle: Cardinal); virtual;
    function InitMixer(ABufferFormat, ATimeQuantum, APlayLag: Cardinal): Boolean; virtual;

    function NewSound(Format: Cardinal; Ptr: Pointer; Size, LoopKind, LoopStart, LoopEnd: Integer): Integer; virtual;
    function CloneSound(SoundIndex: Integer): Integer; virtual;
    function DoCloneSound(SoundIndex, NewSoundIndex: Integer): Boolean; virtual;
    procedure UpdateSound(SoundIndex: Integer; Src: Pointer; Offset, Size: Cardinal); virtual; abstract;

    function GetVolume(const Volume: Integer): Integer; virtual; // Volume [0..255]

    procedure PlaySound(const SoundIndex: Integer); virtual;
    procedure StopSound(const SoundIndex: Integer); virtual;
    function IsSoundPlaying(SoundIndex: Integer): Boolean; virtual;

    procedure SetPan(const SoundIndex, Value: Integer); virtual;
    procedure SetFrequency(const SoundIndex, Value: Cardinal); virtual;
    procedure SetVolume(const SoundIndex, Value: Cardinal); virtual;

    procedure SetMasterVolume(const Value: Cardinal); virtual;  // Value [0..256]
    procedure SetMasterPan(const Value: Integer); virtual;

    function GetPosition(const SoundIndex: Integer): Integer; virtual;
    procedure SetPosition(const SoundIndex, Value: Integer); virtual;

    function GetUsedSounds: Integer; virtual;
    function GetUnusedSound: Integer; virtual;
    function CheckSoundInUse(SoundIndex: Integer): Boolean; virtual;
    function CleanupSounds: Integer; virtual;

    procedure ProcessMixer; virtual;

    procedure FreeSound(SoundIndex: Integer); virtual;
    destructor Free; virtual; abstract;
  protected
    procedure PlayBuffer(SoundIndex: Integer; Looped: Boolean); virtual; abstract;
    procedure DoUpdateSound(SoundIndex: Integer; Src, Dest: Pointer; Offset, Size: Cardinal); virtual;
  end;

  TDX8Audio = class(TAudio)
    constructor Create(AHandle: Cardinal); override;
    function NewSound(Format: Cardinal; Ptr: Pointer; Size, LoopKind, LoopStart, LoopEnd: Integer): Integer; override;
    function DoCloneSound(SoundIndex, NewSoundIndex: Integer): Boolean; override;
    function GetVolume(const Volume: Integer): Integer; override; // Volume [0..255]

    procedure PlaySound(const SoundIndex: Integer); override;
    procedure StopSound(const SoundIndex: Integer); override;
    function IsSoundPlaying(SoundIndex: Integer): Boolean; override;

    procedure SetPan(const SoundIndex, Value: Integer); override;
    procedure SetFrequency(const SoundIndex, Value: Cardinal); override;
    procedure SetVolume(const SoundIndex, Value: Cardinal); override;

    function GetPosition(const SoundIndex: Integer): Integer; override;
    procedure SetPosition(const SoundIndex, Value: Integer); override;

    procedure ProcessMixer; override;

    procedure UpdateSound(SoundIndex: Integer; Src: Pointer; Offset, Size: Cardinal); override;
    procedure FreeSound(SoundIndex: Integer); override;
    destructor Free; override;
  protected
    DirectSound: IDirectSound8;
    procedure PlayBuffer(SoundIndex: Integer; Looped: Boolean); override;
  end;

  TSoftAudio = class(TAudio)
    PlayLag: Cardinal;
    constructor Create(AHandle: Cardinal); override;
    function InitMixer(ABufferFormat, ATimeQuantum, APlayLag: Cardinal): Boolean; override;
    procedure ResetPlayBuffer; virtual;

    function NewSound(Format: Cardinal; Ptr: Pointer; Size, LoopKind, LoopStart, LoopEnd: Integer): Integer; override;
    function DoCloneSound(SoundIndex, NewSoundIndex: Integer): Boolean; override;
    procedure UpdateSound(SoundIndex: Integer; Src: Pointer; Offset, Size: Cardinal); override;

    function GetPosition(const SoundIndex: Integer): Integer; override;

    procedure DoMix(Buffer: PSmallintBuffer; Len: Integer); virtual;
    procedure ProcessMixer; override;

    procedure FreeSound(SoundIndex: Integer); override;
    destructor Free; override;
  protected
    Playing: Boolean;
    LastChannelsMixed: Integer;
    MixingTick: Cardinal;
    MixingBuffers: array[0..MaxChannels-1] of Integer;
    Tick: Cardinal;
    TempBuf: PSmallintBuffer;
    procedure GetChannelsToMix; virtual;
  end;

  TSoftDXAudio = class(TSoftAudio)
    constructor Create(AHandle: Cardinal); override;
    function InitMixer(ABufferFormat, ATimeQuantum, APlayLag: Cardinal): Boolean; override;
    procedure ResetPlayBuffer; override;

    procedure SetMasterVolume(const Value: Cardinal); override;  // Value [0..256]

    procedure ProcessMixer; override;

    destructor Free; override;
{$IFDEF DEBUGMODE}
    procedure GetDebugInfo(var BufParts: Cardinal; var BufPartLen, CurPart, APlayLag, DSPlayPos, DSWritePos, LastChannels: Integer);
{$ENDIF}
  protected
    PlayingTick, SilentTick: Cardinal;
    BufferParts, CurrentPart: Cardinal;
    DirectSound: IDirectSound8;
    DSoundBuf: IDirectSoundBuffer;
  end;

  procedure ReSample(Src: Pointer; SrcFormat: Cardinal; Len: Integer; Dest: Pointer; DestFormat: Cardinal);

implementation

procedure UpSample(Src: Pointer; SrcFormat: Cardinal; Len: Integer; Dest: Pointer; DestFormat: Cardinal);
var
  i, NewLen, CP1, CP2: Integer;
  SFormat, DFormat: TSoundFormat;
  SBuf, DBuf: ^TWordBuffer;
  Step, CPos, COfs: Single;
begin
  SFormat := UnpackSoundFormat(SrcFormat);
  DFormat := UnpackSoundFormat(DestFormat);
  SBuf := Src; DBuf := Dest;
  Step := SFormat.SampleRate / DFormat.SampleRate;
  NewLen := Trunc(0.5 + Len / Step);
  CPos := 0;
  for i := 0 to NewLen-1 do begin
    CP1 := Trunc(CPos);
    CP2 := MinI(Len-1, CP1+1);
    COfs := Frac(CPos);
    DBuf[i] := Word(Trunc(0.5 + SmallInt(SBuf[CP1]) * (1-COfs) + SmallInt(SBuf[CP2]) * COfs));
    CPos := CPos + Step;
  end;
end;

procedure DownSample(Src: Pointer; SrcFormat: Cardinal; Len: Integer; Dest: Pointer; DestFormat: Cardinal);
var SFormat, DFormat: TSoundFormat;
begin
  SFormat := UnpackSoundFormat(SrcFormat);
  DFormat := UnpackSoundFormat(DestFormat);
end;

procedure ReSample(Src: Pointer; SrcFormat: Cardinal; Len: Integer; Dest: Pointer; DestFormat: Cardinal);
var SFormat, DFormat: TSoundFormat;
begin
  SFormat := UnpackSoundFormat(SrcFormat);
  DFormat := UnpackSoundFormat(DestFormat);
  if SFormat.SampleRate < DFormat.SampleRate then
   UpSample(Src, SrcFormat, Len, Dest, DestFormat) else
    DownSample(Src, SrcFormat, Len, Dest, DestFormat);
end;

{ TAudio }

constructor TAudio.Create(AHandle: Cardinal);
var i: Integer;
begin
  for i := 0 to MaxSounds-1 do FreeSound(i);
  CurrentSound := 0;
  DefaulFormat := PackSoundFormat(44100, 16, 1);
  MasterVolume := MaxVolume div 4;
  MasterPan := 0;
  ConvertBitsPerSample := True;
  InitMixer(PackSoundFormat(44100, 16, 2), 30, plAuto);
end;

function TAudio.InitMixer(ABufferFormat, ATimeQuantum, APlayLag: Cardinal): Boolean;
var i: Integer;
begin
  Result             := True;
  MixerFormat        := ABufferFormat;
  MixerBufElSize     := GetSoundElementSize(MixerFormat);
  MixerBufferFreq    := UnpackSoundFormat(ABufferFormat).SampleRate;
  MixerBufferPartLen := MixerBufferFreq * ATimeQuantum div 1000;

  for i := 0 to MaxSounds-1 do FreeSound(i);
end;

procedure TAudio.FreeSound(SoundIndex: Integer);
begin
  Sounds[SoundIndex].Status       := ssFree;
  Sounds[SoundIndex].Buffer       := nil;
  Sounds[SoundIndex].LoopedBuffer := nil;
end;

function TAudio.GetUsedSounds: Integer;
var i: Integer;
begin
  Result := 0;
  for i := 0 to MaxSounds-1 do if Sounds[i].Status <> ssFree then Inc(Result);
end;

function TAudio.GetUnusedSound: Integer;
var i: Integer;
begin
  CurrentSound := 0;
  Result := -1;
  for i := 0 to MaxSounds-1 do if Sounds[i].Status = ssFree then begin
    Result := CurrentSound; Exit;
  end else if CurrentSound < MaxSounds-1 then Inc(CurrentSound) else CurrentSound := 0;
end;

function TAudio.CleanupSounds: Integer;
var i, CurrentSound: Integer;
begin
  CurrentSound := 0;
  Result := -1;
  for i := 0 to MaxSounds-1 do if not CheckSoundInUse(CurrentSound) then begin
    Result := CurrentSound; Exit;
  end else if CurrentSound < MaxSounds-1 then Inc(CurrentSound) else CurrentSound := 0;
end;

function TAudio.GetVolume(const Volume: Integer): Integer;
begin
  Result := Volume;
end;

function TAudio.NewSound(Format: Cardinal; Ptr: Pointer; Size, LoopKind, LoopStart, LoopEnd: Integer): Integer;
begin
  Result := GetUnusedSound;

  if (Sounds[Result].Buffer <> nil) or (Sounds[Result].LoopedBuffer <> nil) then FreeSound(Result);

  if Result = -1 then begin

    Log(ClassName + '.NewSound: Can''t find free sound channel');

    Exit;
  end;

  Sounds[Result].OrigFormat    := Format;

  if ConvertBitsPerSample then
   Format     := PackSoundFormat(UnpackSoundFormat(Format).SampleRate, UnpackSoundFormat(MixerFormat).BitsPerSample, UnpackSoundFormat(Format).Channels);

  Sounds[Result].Format        := Format;
  Sounds[Result].Status        := ssJustCreated;
  Sounds[Result].Position      := 0;
  Sounds[Result].TotalSamples  := Size div GetSoundElementSize(Sounds[Result].OrigFormat);
  Sounds[Result].NonLoopedSize := 0;
  Sounds[Result].FreeOnStop    := False;//True;
  Sounds[Result].LastVolume    := -1;
  Sounds[Result].Volume        := MaxVolume;
  Sounds[Result].Frequency     := 0;
  Sounds[Result].LastPan       := -$FF;
  Sounds[Result].Pan           := 0;
  Sounds[Result].LoopKind      := LoopKind;
  Sounds[Result].LoopStart     := MaxI(0, MinI(Sounds[Result].TotalSamples-1, LoopStart));
  Sounds[Result].LoopEnd       := MaxI(Sounds[Result].LoopStart, MinI(Sounds[Result].TotalSamples-1, LoopEnd)); ;
  Sounds[Result].CloneOf       := -1;
end;

function TAudio.CloneSound(SoundIndex: Integer): Integer;
begin
  Result := -1;
  if Sounds[SoundIndex].CloneOf >= 0 then begin
    Result := CloneSound(Sounds[SoundIndex].CloneOf);
    Exit;
  end;

  if (SoundIndex < 0) or (SoundIndex >= MaxSounds) or (Sounds[SoundIndex].Status = ssFree) then Exit;

  Result := GetUnusedSound;
  DoCloneSound(SoundIndex, Result);
end;

function TAudio.DoCloneSound(SoundIndex, NewSoundIndex: Integer): Boolean;
begin
  Result := False;
  if (NewSoundIndex < 0) or (NewSoundIndex = SoundIndex) then Exit;

  Sounds[NewSoundIndex].Format        := Sounds[SoundIndex].Format;
  Sounds[NewSoundIndex].OrigFormat    := Sounds[SoundIndex].OrigFormat;
  Sounds[NewSoundIndex].Status        := ssJustCreated;
  Sounds[NewSoundIndex].Position      := 0;
  Sounds[NewSoundIndex].TotalSamples  := Sounds[SoundIndex].TotalSamples;
  Sounds[NewSoundIndex].NonLoopedSize := Sounds[SoundIndex].NonLoopedSize;
  Sounds[NewSoundIndex].FreeOnStop    := Sounds[SoundIndex].FreeOnStop;
  Sounds[NewSoundIndex].LastVolume    := -1;
  Sounds[NewSoundIndex].Volume        := Sounds[SoundIndex].Volume;
  Sounds[NewSoundIndex].Frequency     := Sounds[SoundIndex].Frequency;
  Sounds[NewSoundIndex].LastPan       := -$FF;
  Sounds[NewSoundIndex].Pan           := Sounds[SoundIndex].Pan;
  Sounds[NewSoundIndex].LoopKind      := Sounds[SoundIndex].LoopKind;
  Sounds[NewSoundIndex].LoopStart     := Sounds[SoundIndex].LoopStart;
  Sounds[NewSoundIndex].LoopEnd       := Sounds[SoundIndex].LoopEnd;
  Sounds[NewSoundIndex].CloneOf       := SoundIndex;

  Result := True;
end;

procedure TAudio.DoUpdateSound(SoundIndex: Integer; Src, Dest: Pointer; Offset, Size: Cardinal);
var
//  NewSoundBuf: Pointer; NewSoundBufSize: Integer;
  j, BitRate, BufBitRate, ConvK: Integer;
begin
  ConvK := 1;
  if ConvertBitsPerSample then begin
    BitRate    := UnpackSoundFormat(Sounds[SoundIndex].OrigFormat).BitsPerSample;
    BufBitRate := UnpackSoundFormat(Sounds[SoundIndex].Format    ).BitsPerSample;
    if BitRate < BufBitRate then ConvK := BufBitRate div BitRate;
  end;

//  Sleep(100);
  {$R-}
  if ConvK = 2 then begin
    for j := 0 to Size * Cardinal(GetSoundElementSize(Sounds[SoundIndex].OrigFormat)) div ConvK-1 do
     PWordBuffer(Pointer(Cardinal(Dest) + Offset))^[Cardinal(j)] := SmallInt((ShortInt(PByteBuffer(Src)^[j]) * 256));
  end else
   Move(Src^, Pointer(Cardinal(Dest) + Offset)^, Size);

{        if ConvTo16Bit then begin
          GetMem(Data16, Len*2*ResampleK);
          UpSample(TmpData16, PackSoundFormat(8363, 16, 1), Len, Data16, PackSoundFormat(8363*ResampleK, 16, 1));
          FreeMem(TmpData16);
        end;}

end;

procedure TAudio.PlaySound(const SoundIndex: Integer);
begin
  if Sounds[SoundIndex].Status <> ssFree then Sounds[SoundIndex].Status := ssPlaying;
end;

procedure TAudio.SetFrequency(const SoundIndex, Value: Cardinal);
begin
  Sounds[SoundIndex].Frequency := Value;
end;

procedure TAudio.SetPan(const SoundIndex, Value: Integer);
begin
  Sounds[SoundIndex].Pan := Value;
end;

procedure TAudio.SetVolume(const SoundIndex, Value: Cardinal);
begin

//  if Value > 0 then Log(Format(ClassName + '.SetVolume: SI: %D, V: %D', [SoundIndex, Value]));

  Sounds[SoundIndex].Volume := Value;
end;

function TAudio.GetPosition(const SoundIndex: Integer): Integer;
begin
  Result := Sounds[SoundIndex].Position;
end;

procedure TAudio.SetPosition(const SoundIndex, Value: Integer);
begin
  Sounds[SoundIndex].Position := Value;
  Sounds[SoundIndex].PositionFrac := 0;
end;

procedure TAudio.StopSound(const SoundIndex: Integer);
begin
  if Sounds[SoundIndex].FreeOnStop or (Sounds[SoundIndex].CloneOf >= 0) then
   FreeSound(SoundIndex) else
    Sounds[SoundIndex].Status := ssStopped;
end;

procedure TAudio.SetMasterVolume(const Value: Cardinal); // Value [0..256]
var i: Integer;
begin
  MasterVolume := Value;
  for i := 0 to MaxSounds-1 do
   if Sounds[i].Status <> ssFree then SetVolume(i, Sounds[i].Volume);
end;

procedure TAudio.SetMasterPan(const Value: Integer);
begin
  MasterPan := Value;
end;

function TAudio.CheckSoundInUse(SoundIndex: Integer): Boolean;
begin
  case Sounds[SoundIndex].Status and $F of
    ssPlaying: begin
      Result := IsSoundPlaying(SoundIndex);
      if not Result and (Sounds[SoundIndex].FreeOnStop or (Sounds[SoundIndex].CloneOf >= 0)) then
       FreeSound(SoundIndex) else
        Result := True;
    end;
    ssJustCreated, ssStopped: Result := True;
    else Result := False;
  end;

    if not Result then Log('Sound isn''t in use. Index: ' + IntToStr(SoundIndex));
  
end;

function TAudio.IsSoundPlaying(SoundIndex: Integer): Boolean;
begin
  Result := (SoundIndex <> -1) and (Sounds[SoundIndex].Status and $F = ssPlaying);
end;

procedure TAudio.ProcessMixer;
begin
end;

function InitDirectSound(AHandle: Cardinal): IDirectSound8;
 {$IFDEF EXTLOGGING}
const CanStr: array[False..True] of string[3] = ('[ ]', '[X]');
 {$ENDIF}
var Res: HResult; 
 {$IFDEF EXTLOGGING} DSCaps: TDSCaps; {$ENDIF}
begin
  Result := nil;
  if DSoundDLL = 0 then begin

    Log('Can''t start DirectSound: DirectX 8 or greater not installed', lkError);

    Exit;
  end;
{$IFDEF DIRECTSOUNDNIL}
  DirectSound := nil;
{$ELSE}
  DirectSoundCreate8(nil{@DSDEVID_DefaultPlayback}, Result, nil);
{$ENDIF}

  Log('Starting DX8 Audio', lkTitle);
  if Result = nil then
   Log('Error creating DirectSound object', lkFatalError) else
    Log('DirectSound object succesfully created');

  if Result = nil then Exit;
  Res := Result.SetCooperativeLevel(AHandle{GetCurrentProcess}, DSSCL_NORMAL);

  if Failed(Res) then begin

    Log('Error setting DirectSound cooperative level', lkFatalError);

    Exit;
  end;
 {$IFDEF EXTLOGGING}
  Log('Checking sound device capabilites', lkTitle);
  DSCaps.dwSize := SizeOf(DSCaps);
  Result.GetCaps(DSCaps);
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
end;

{ TDX8Audio }

constructor TDX8Audio.Create(AHandle: Cardinal);
begin
  inherited;
  Initialized := False;

  DirectSound := InitDirectSound(AHandle);
  if DirectSound = nil then Exit;

  Enabled     := True;
  Initialized := True;
end;

function CreateDSBuffer(DirectSound: IDirectSound8; Format: Cardinal; Size: Integer; Flags: Cardinal): Pointer;
var DSBuf: IDirectSoundBuffer; Res: HResult; PCMWF: PCMWAVEFORMAT; DSBDesc: TDSBUFFERDESC;
begin
  PCMWF.wf.wFormatTag      := WAVE_FORMAT_PCM;
  PCMWF.wf.nChannels       := UnPackSoundFormat(Format).Channels;
  PCMWF.wf.nSamplesPerSec  := UnPackSoundFormat(Format).SampleRate;
  PCMWF.wf.nBlockAlign     := UnPackSoundFormat(Format).BlockAlign;
  PCMWF.wf.nAvgBytesPerSec := pcmwf.wf.nSamplesPerSec * pcmwf.wf.nBlockAlign;
  PCMWF.wBitsPerSample     := UnPackSoundFormat(Format).BitsPerSample;

  FillChar(dsbdesc, SizeOf(TDSBUFFERDESC), 0);
  DSBDesc.dwSize  := SizeOf(TDSBUFFERDESC);
  DSBDesc.dwBufferBytes := Size;
  DSBDesc.dwFlags := Flags;
  DSBDesc.dwReserved := 0;
  DSBDesc.lpwfxFormat := PWAVEFORMATEX(@PCMWF);
//  DSBDesc.guid3DAlgorithm := GUID_Null;

  Res := DirectSound.CreateSoundBuffer(DSBDesc, DSBuf, nil);
  if Failed(Res) then begin

//    Log(ClassName + 'CreateBuffer: Error creating sound buffer. Result: ' + IntToStr(Res) + ' Error #: ' + IntToStr(Res - MAKE_DSHRESULT_), lkError);

    Result := nil;
    Exit;
  end;

  DSBuf._AddRef;
  Result := Pointer(DSBuf);
end;

function TDX8Audio.NewSound(Format: Cardinal; Ptr: Pointer; Size, LoopKind, LoopStart, LoopEnd: Integer): Integer;
var ElSize, LoopedSize, LoopSizeK, MinSampleLen, LoopedCount: Integer;
begin
  Result := -1;
  if not Initialized then Exit;

  Result := inherited NewSound(Format, Ptr, Size, LoopKind, LoopStart, LoopEnd);
  if Result = -1 then Exit;


  Log(ClassName + ': Creating sound buffer', lkTitle);


  if (Sounds[Result].Buffer <> nil) or (Sounds[Result].LoopedBuffer <> nil) then FreeSound(Result);
  Sounds[Result].Buffer := nil;
  Sounds[Result].LoopedBuffer := nil;

  case LoopKind of                                              // Non-looped
    lkNone: Sounds[Result].Buffer := CreateDSBuffer(DirectSound, Sounds[Result].Format, Sounds[Result].TotalSamples * GetSoundElementSize(Sounds[Result].Format), DSBCAPS_CTRLVOLUME or DSBCAPS_CTRLPAN or DSBCAPS_CTRLFREQUENCY or 0*DSBCAPS_LOCSOFTWARE or 0*DSBCAPS_STATIC or DSBCAPS_GETCURRENTPOSITION2);
    lkForward, lkPingPong: begin
      if LoopKind = lkPingPong then LoopSizeK := 2 else LoopSizeK := 1;
      ElSize := GetSoundElementSize(Sounds[Result].Format);
      if Sounds[Result].LoopStart = 0 then begin                             // Looped from the beginning
        LoopedSize := MinI(Sounds[Result].LoopEnd * ElSize + ElSize, Sounds[Result].TotalSamples * ElSize);
        Sounds[Result].LoopedBuffer := CreateDSBuffer(DirectSound, Sounds[Result].Format, LoopedSize * LoopSizeK, DSBCAPS_CTRLVOLUME or DSBCAPS_CTRLPAN or DSBCAPS_CTRLFREQUENCY or 0*DSBCAPS_LOCSOFTWARE or 0*DSBCAPS_STATIC or DSBCAPS_GETCURRENTPOSITION2);
      end else begin                                                           // Looped
        MinSampleLen := MinDuration * UnpackSoundFormat(Sounds[Result].Format).SampleRate div 1000;
        LoopedSize := MinI(Sounds[Result].LoopEnd * ElSize + ElSize, Sounds[Result].TotalSamples * ElSize) - Sounds[Result].LoopStart * ElSize;
        LoopedCount := MaxI(1, (MinSampleLen-Sounds[Result].LoopEnd * ElSize) div (LoopedSize * LoopSizeK));

        Sounds[Result].Buffer := CreateDSBuffer(DirectSound, Sounds[Result].Format, Sounds[Result].LoopEnd * ElSize + LoopedCount * LoopedSize * LoopSizeK, DSBCAPS_CTRLVOLUME or DSBCAPS_CTRLPAN or DSBCAPS_CTRLFREQUENCY or 0*DSBCAPS_LOCSOFTWARE or 0*DSBCAPS_STATIC or DSBCAPS_GETCURRENTPOSITION2);
        Sounds[Result].LoopedBuffer := CreateDSBuffer(DirectSound, Sounds[Result].Format, LoopedSize * LoopSizeK, DSBCAPS_CTRLVOLUME or DSBCAPS_CTRLPAN or DSBCAPS_CTRLFREQUENCY or 0*DSBCAPS_LOCSOFTWARE or 0*DSBCAPS_STATIC or DSBCAPS_GETCURRENTPOSITION2);
      end;
    end;
    lkForwardLoopOnly: begin
      ElSize := GetSoundElementSize(Sounds[Result].Format);
      LoopedSize := MinI(Sounds[Result].LoopEnd * ElSize + ElSize, Sounds[Result].TotalSamples * ElSize) - Sounds[Result].LoopStart * ElSize;
      Sounds[Result].LoopedBuffer := CreateDSBuffer(DirectSound, Sounds[Result].Format, LoopedSize, DSBCAPS_CTRLVOLUME or DSBCAPS_CTRLPAN or DSBCAPS_CTRLFREQUENCY or 0*DSBCAPS_LOCSOFTWARE or 0*DSBCAPS_STATIC or DSBCAPS_GETCURRENTPOSITION2);
    end;
  end;

  if Ptr <> nil then UpdateSound(Result, Ptr, 0, Size);

  Sounds[Result].Status := ssStopped;
end;

function TDX8Audio.DoCloneSound(SoundIndex, NewSoundIndex: Integer): Boolean;

function CloneBuffer(Buffer: Pointer): Pointer;
var Res: HResult; DSBuf: IDirectSoundBuffer;
begin
  Res := DirectSound.DuplicateSoundBuffer(IDirectSoundBuffer(Buffer), DSBuf);
  if Failed(Res) then begin

    Log(ClassName + 'CloneBuffer: Error cloning sound buffer. Result: ' + IntToStr(Res) + ' Error #: ' + IntToStr(Res - MAKE_DSHRESULT_), lkError);

    Result := nil;
    Exit;
  end;

  DSBuf._AddRef;
  Result := Pointer(DSBuf);
end;

begin
  Result := False;
  if not Initialized then Exit;

  if not inherited DoCloneSound(SoundIndex, NewSoundIndex) then Exit;

  if (Sounds[NewSoundIndex].Buffer <> nil) or (Sounds[NewSoundIndex].LoopedBuffer <> nil) then FreeSound(NewSoundIndex);

  if Sounds[SoundIndex].Buffer       <> nil then Sounds[NewSoundIndex].Buffer       := CloneBuffer(Sounds[SoundIndex].Buffer);
  if Sounds[SoundIndex].LoopedBuffer <> nil then Sounds[NewSoundIndex].LoopedBuffer := CloneBuffer(Sounds[SoundIndex].LoopedBuffer);

  Result := True;
end;

procedure TDX8Audio.UpdateSound(SoundIndex: Integer; Src: Pointer; Offset, Size: Cardinal);
var
  ElSize, OrigElSize, LoopedLen, LoopSizeK, MinSampleLen, LoopedCount, i: Integer; Data: Pointer;
  BitRate, BufBitRate, ConvK: Cardinal;

procedure UpdateBuffer(Buffer, BSrc: Pointer; Offs, DSize: Cardinal);
// Updates a buffer. Using PTR1 only.
var Res: HResult; PTR1, PTR2: Pointer; Bytes1, Bytes2: Cardinal;
begin
  if Buffer = nil then begin

    Log(ClassName + 'UpdateBuffer: Buffer is nil', lkError);

    Exit;
  end;
  Res := IDirectSoundBuffer(Buffer).Lock(Offs, DSize, PTR1, Bytes1, PTR2, Bytes2, 0{DSBLOCK_ENTIREBUFFER});
  if Failed(Res) then begin

    Log('Error locking sound buffer. Result: ' + IntToStr(Res) + ' Error #: ' + IntToStr(Res - MAKE_DSHRESULT_), lkError);

    Exit;
  end;
  DoUpdateSound(SoundIndex, BSrc, PTR1, 0, DSize);
//  Move(BSrc^, PTR1^, DSize);
  IDirectSoundBuffer(Buffer).Unlock(PTR1, Bytes1, PTR2, Bytes2);
end;

begin
  if not Initialized then Exit;

  ConvK := 1;
  if ConvertBitsPerSample then begin
    BitRate    := UnpackSoundFormat(Sounds[SoundIndex].OrigFormat).BitsPerSample;
    BufBitRate := UnpackSoundFormat(Sounds[SoundIndex].Format    ).BitsPerSample;
    if BitRate < BufBitRate then ConvK := BufBitRate div BitRate;
  end;
//  Sounds[SoundIndex] := Resources[Sound.ResourceIndex].Size;

  Data := nil;
  case Sounds[SoundIndex].LoopKind of                                              // Non-looped
    lkNone: UpdateBuffer(Sounds[SoundIndex].Buffer, Src, Offset * ConvK, Size * ConvK);
    lkForward, lkPingPong: begin
      ElSize := GetSoundElementSize(Sounds[SoundIndex].Format);
      OrigElSize := GetSoundElementSize(Sounds[SoundIndex].OrigFormat);
      if (Sounds[SoundIndex].LoopStart = 0) then begin                           // Looped from the beginning
        Sounds[SoundIndex].NonLoopedSize := 0;
        LoopedLen := MinI(Sounds[SoundIndex].LoopEnd+1, Sounds[SoundIndex].TotalSamples);

        UpdateBuffer(Sounds[SoundIndex].LoopedBuffer, Src, 0, LoopedLen * ElSize);

        if Sounds[SoundIndex].LoopKind = lkPingPong then begin                   // Reverse the original buffer
          GetMem(Data, LoopedLen * OrigElSize);
          case OrigElSize of
            1: MoveReverse8(Src, Data, LoopedLen);
            2: MoveReverse16(Src, Data, LoopedLen);
          end;
          UpdateBuffer(Sounds[SoundIndex].LoopedBuffer, Data, LoopedLen * ElSize, LoopedLen * ElSize);
        end;
      end else begin                                                             // Looped
        MinSampleLen := MinDuration * UnpackSoundFormat(Sounds[SoundIndex].Format).SampleRate div 1000;
        LoopedLen := MinI(Sounds[SoundIndex].LoopEnd + 1, Sounds[SoundIndex].TotalSamples) - Sounds[SoundIndex].LoopStart;
        if Sounds[SoundIndex].LoopKind = lkPingPong then LoopSizeK := 2 else LoopSizeK := 1;
        LoopedCount := MaxI(1, (MinSampleLen-Sounds[SoundIndex].LoopEnd * ElSize) div (LoopedLen * ElSize * LoopSizeK));

        UpdateBuffer(Sounds[SoundIndex].Buffer, Src, 0, Sounds[SoundIndex].LoopEnd * ElSize);

        GetMem(Data, LoopedLen * LoopSizeK * OrigElSize);
        Move(Pointer(Integer(Src) + Sounds[SoundIndex].LoopStart * OrigElSize)^, Data^, LoopedLen * OrigElSize);
        if Sounds[SoundIndex].LoopKind = lkPingPong then case OrigElSize of
          1: MoveReverse8(Pointer(Integer(Src) + Sounds[SoundIndex].LoopStart * OrigElSize),
                          Pointer(Integer(Data) + LoopedLen * OrigElSize), LoopedLen * OrigElSize);
          2: MoveReverse16(Pointer(Integer(Src) + Sounds[SoundIndex].LoopStart * OrigElSize),
                           Pointer(Integer(Data) + LoopedLen * OrigElSize), LoopedLen * OrigElSize);
        end;

        for i := 0 to LoopedCount-1 do                                         // Looped part several times for correct looping
         UpdateBuffer(Sounds[SoundIndex].Buffer, Data, Sounds[SoundIndex].LoopEnd * ElSize + i * LoopedLen * ElSize * LoopSizeK, LoopedLen * ElSize * LoopSizeK);

        Sounds[SoundIndex].NonLoopedSize := Sounds[SoundIndex].LoopEnd * ElSize;

        UpdateBuffer(Sounds[SoundIndex].LoopedBuffer, Data, 0, LoopedLen * ElSize * LoopSizeK);
      end;
    end;
    lkForwardLoopOnly: begin
      ElSize     := GetSoundElementSize(Sounds[SoundIndex].Format);
      OrigElSize := GetSoundElementSize(Sounds[SoundIndex].OrigFormat);
      Sounds[SoundIndex].NonLoopedSize := 0;

      UpdateBuffer(Sounds[SoundIndex].LoopedBuffer, Pointer( Integer(Src) + Sounds[SoundIndex].LoopStart * OrigElSize ), 0, (Sounds[SoundIndex].LoopEnd - Sounds[SoundIndex].LoopStart + 1) * ElSize);
    end;
  end;
  if Data <> nil then FreeMem(Data);
end;

procedure TDX8Audio.FreeSound(SoundIndex: Integer);
begin
  if Sounds[SoundIndex].Buffer <> nil then IDirectSoundBuffer(Sounds[SoundIndex].Buffer)._Release;
  if Sounds[SoundIndex].LoopedBuffer <> nil then IDirectSoundBuffer(Sounds[SoundIndex].LoopedBuffer)._Release;
  inherited;
end;

procedure TDX8Audio.PlayBuffer(SoundIndex: Integer; Looped: Boolean);
begin
  if Looped then begin
    if Sounds[SoundIndex].LoopedBuffer <> nil then
     IDirectSoundBuffer(Sounds[SoundIndex].LoopedBuffer).Play(0, 0, DSBPLAY_LOOPING);
    if Sounds[SoundIndex].Buffer <> nil then
     IDirectSoundBuffer(Sounds[SoundIndex].Buffer).Stop;
  end else begin
    if Sounds[SoundIndex].Buffer <> nil then
     IDirectSoundBuffer(Sounds[SoundIndex].Buffer).Play(0, 0, 0);
    if Sounds[SoundIndex].LoopedBuffer <> nil then
     IDirectSoundBuffer(Sounds[SoundIndex].LoopedBuffer).Stop;
  end;
end;

procedure TDX8Audio.PlaySound(const SoundIndex: Integer);
begin
  inherited;
  Assert(Sounds[SoundIndex].Buffer <> nil, ClassName + '.PlaySound: Sound buffer is nil');
  SetPan(SoundIndex, Sounds[SoundIndex].Pan);
  SetFrequency(SoundIndex, Sounds[SoundIndex].Frequency);
  SetVolume(SoundIndex, Sounds[SoundIndex].Volume);

  if Sounds[SoundIndex].Buffer <> nil then PlayBuffer(SoundIndex, False) else PlayBuffer(SoundIndex, True);
end;

procedure TDX8Audio.StopSound(const SoundIndex: Integer);
begin
  if Sounds[SoundIndex].Buffer <> nil then
   IDirectSoundBuffer(Sounds[SoundIndex].Buffer).Stop;
  if Sounds[SoundIndex].LoopedBuffer <> nil then
   IDirectSoundBuffer(Sounds[SoundIndex].LoopedBuffer).Stop;

//      Log('StopSound. SoundIndex: ' + IntToStr(SoundIndex));

  inherited;
end;

function TDX8Audio.IsSoundPlaying(SoundIndex: Integer): Boolean;
var BufStatus: Cardinal;
begin
  if (SoundIndex = -1) or not (Sounds[SoundIndex].Status and $F = ssPlaying) or
     ((Sounds[SoundIndex].Buffer = nil) and (Sounds[SoundIndex].LoopedBuffer = nil)) then Result := False else begin
    Result := False;
    if Sounds[SoundIndex].Buffer <> nil then begin
      IDirectSoundBuffer(Sounds[SoundIndex].Buffer).GetStatus(BufStatus);
      Result := (BufStatus and DSBSTATUS_PLAYING <> 0);
    end;
    if Sounds[SoundIndex].LoopedBuffer <> nil then begin
      IDirectSoundBuffer(Sounds[SoundIndex].LoopedBuffer).GetStatus(BufStatus);
      Result := Result or (BufStatus and DSBSTATUS_PLAYING <> 0);
    end;

//    if not Result then Log('Sound isn''t playing. Index: ' + IntToStr(SoundIndex));

    if not Result then Sounds[SoundIndex].Status := ssStopped;
  end;
end;

procedure TDX8Audio.SetFrequency(const SoundIndex, Value: Cardinal);
begin
  inherited;
  if (Sounds[SoundIndex].Buffer <> nil) then
   IDirectSoundBuffer(Sounds[SoundIndex].Buffer).SetFrequency(Sounds[SoundIndex].Frequency);
  if (Sounds[SoundIndex].LoopedBuffer <> nil) then
   IDirectSoundBuffer(Sounds[SoundIndex].LoopedBuffer).SetFrequency(Sounds[SoundIndex].Frequency);
end;

procedure TDX8Audio.SetPan(const SoundIndex, Value: Integer);
var DXPan: Integer;
begin
  inherited;
  if Sounds[SoundIndex].Pan < 0 then DXPan := GetVolume(255-MinI(255, -Sounds[SoundIndex].Pan*2)) else DXPan := -GetVolume(255-Sounds[SoundIndex].Pan*2);
  if Sounds[SoundIndex].Buffer       <> nil then IDirectSoundBuffer(Sounds[SoundIndex].Buffer).SetPan(DXPan);
  if Sounds[SoundIndex].LoopedBuffer <> nil then IDirectSoundBuffer(Sounds[SoundIndex].LoopedBuffer).SetPan(DXPan);
end;

procedure TDX8Audio.SetVolume(const SoundIndex, Value: Cardinal);
begin
  inherited;
  if Sounds[SoundIndex].Buffer <> nil then
   IDirectSoundBuffer(Sounds[SoundIndex].Buffer).SetVolume(GetVolume((MasterVolume * Sounds[SoundIndex].Volume) shr 8));
  if Sounds[SoundIndex].LoopedBuffer <> nil then
   IDirectSoundBuffer(Sounds[SoundIndex].LoopedBuffer).SetVolume(GetVolume((MasterVolume * Sounds[SoundIndex].Volume) shr 8));
end;

function TDX8Audio.GetVolume(const Volume: Integer): Integer;
begin
  Result := DSBVOLUME_MIN + Trunc(0.5 + Ln(9*Ln(Volume+1)/(Ln(2)*8)+1)/Ln(10) * Abs(DSBVOLUME_MIN) );
end;

function TDX8Audio.GetPosition(const SoundIndex: Integer): Integer;
begin
  if Sounds[SoundIndex].Buffer <> nil then
   IDirectSoundBuffer(Sounds[SoundIndex].Buffer).GetCurrentPosition(@Result, nil);
end;

procedure TDX8Audio.SetPosition(const SoundIndex, Value: Integer);
begin
  inherited;
  if Sounds[SoundIndex].Buffer <> nil then
   IDirectSoundBuffer(Sounds[SoundIndex].Buffer).SetCurrentPosition(Value);
end;

destructor TDX8Audio.Free;
var i: Integer;
begin

  Log(ClassName + ': Shutting down DirectSound', lkTitle);

  for i := 0 to MaxSounds-1 do FreeSound(i);
  DirectSound := nil;
  inherited;
end;

procedure TDX8Audio.ProcessMixer;
var i, sp: Integer;
begin
  for i := 0 to MaxSounds-1 do begin
    if Sounds[i].Buffer <> nil then begin
      if (Sounds[i].LoopedBuffer <> nil) and (Sounds[i].Status and ssLoopDone = 0) then begin
        if Sounds[i].Status = ssPlaying then
         sp := GetPosition(i) else
          sp := Sounds[i].NonLoopedSize;
        if sp >= Sounds[i].NonLoopedSize then begin
          SetPosition(i, (sp - Sounds[i].NonLoopedSize) mod (Sounds[i].TotalSamples * GetSoundElementSize(Sounds[i].Format)));
          PlayBuffer(i, True);
          Sounds[i].Status := Sounds[i].Status or ssLoopDone;
        end;
      end;
    end;
  end;
end;

{ TSoftAudio }

constructor TSoftAudio.Create(AHandle: Cardinal);
begin
  inherited;
  Initialized := False;
  TempBuf := nil;
  
  Interpolation := imLinear;
  StopOnSilence := True;//False;
  Enabled       := True;
  Initialized   := True;
  
  ConvertBitsPerSample := True;
end;

function TSoftAudio.InitMixer(ABufferFormat, ATimeQuantum, APlayLag: Cardinal): Boolean;
const AutoLagSamples = 1480{ div 3};
begin
  Result := False;
  if not inherited InitMixer(ABufferFormat, ATimeQuantum, APlayLag) then Exit;

  if APlayLag = plAuto then
   PlayLag := AutoLagSamples div MixerBufferPartLen + Cardinal(Ord(AutoLagSamples mod MixerBufferPartLen <> 0)) else
    PlayLag := APlayLag;

  if TempBuf <> nil then FreeMem(TempBuf);
//  GetMem(TempBuf, MixerBufferPartLen * MixerBufElSize);

  ResetPlayBuffer;
  SetMasterVolume(MasterVolume);

  Result := True;
end;

procedure TSoftAudio.ResetPlayBuffer;
begin
  Playing     := False;
  MixingTick  := 0;
end;

function TSoftAudio.NewSound(Format: Cardinal; Ptr: Pointer; Size, LoopKind, LoopStart, LoopEnd: Integer): Integer;
begin
  Result := -1;
  if not Initialized then Exit;

  Result := inherited NewSound(Format, Ptr, Size, LoopKind, LoopStart, LoopEnd);
  if Result = -1 then Exit;

  Sounds[Result].OrigFormat := Format;


  Log(ClassName + ': Creating new sound', lkTitle);


  GetMem(Sounds[Result].Buffer, Sounds[Result].TotalSamples * GetSoundElementSize(Sounds[Result].Format));

  if Ptr <> nil then UpdateSound(Result, Ptr, 0, Size * GetSoundElementSize(Sounds[Result].Format));

  Sounds[Result].Status := ssStopped;
end;

function TSoftAudio.DoCloneSound(SoundIndex, NewSoundIndex: Integer): Boolean;
begin
  Result := inherited DoCloneSound(SoundIndex, NewSoundIndex);
  if not Result then Exit;
  Sounds[NewSoundIndex].Buffer := Sounds[SoundIndex].Buffer;
end;

procedure TSoftAudio.UpdateSound(SoundIndex: Integer; Src: Pointer; Offset, Size: Cardinal);
begin
  if Sounds[SoundIndex].Buffer = nil then Exit;
  DoUpdateSound(SoundIndex, Src, Sounds[SoundIndex].Buffer, Offset, Size);
end;

function TSoftAudio.GetPosition(const SoundIndex: Integer): Integer;
begin
  Result := Sounds[SoundIndex].Position;
end;

procedure TSoftAudio.DoMix(Buffer: PSmallintBuffer; Len: Integer);

function GetSamplingPos(var Pos1, Pos2: Integer; Position, LoopKind, LoopStart, LoopEnd, TotalSamples: Integer): Boolean;
var LoopLen: Integer;
begin
  Result := True;
  Pos1 := Position; Pos2 := MinI(TotalSamples-1, Position+1);
  case LoopKind of
//  l-------S-------E------*---------l
    lkForward: if Position+1 >= LoopEnd then begin
      Pos1 := LoopStart + (Position     - LoopStart) mod (LoopEnd - LoopStart);
      if (Interpolation = imLinear) then Pos2 := LoopStart + (Position + 1 - LoopStart) mod (LoopEnd - LoopStart);
    end;
    lkPingPong: if Position+1 >= LoopEnd then begin
      LoopLen := LoopEnd - LoopStart;
      Pos1 := (Position     - LoopStart) mod (2*LoopLen);           // Position relative to LoopStart
      if Pos1 < LoopLen then                                        // First half (ping)
       Pos1 := LoopStart + Pos1 else                                // Second half (pong)
        Pos1 := LoopEnd - 1 - (Pos1 - LoopLen);
      if (Interpolation = imLinear) then begin
        Pos2 := (Position + 1 - LoopStart) mod (2*LoopLen);           // Position relative to LoopStart
        if Pos2 < LoopLen then                                        // First half (ping)
         Pos2 := LoopStart + Pos2 else                                // Second half (pong)
          Pos2 := LoopEnd - 1 - (Pos2 - LoopLen);
      end;
    end;
    else if Position >= TotalSamples then Result := False;
  end;
end;

var
  i, j, Pos1, Pos2, MixVol, MixPan: Integer;
  Value, Value1, Value2: Int64;

begin
  if LastChannelsMixed = 0 then begin
    FillChar(Buffer^, Cardinal(Len) * MixerBufElSize, 0);
    Exit;
  end;
  for i := 0 to Len-1 do begin
    Value1 := 0; Value2 := 0;
    for j := 0 to LastChannelsMixed-1 do with Sounds[MixingBuffers[j]] do {if (Status and $0F) = ssPlaying then }begin
      if not GetSamplingPos(Pos1, Pos2, Position, LoopKind, LoopStart, LoopEnd, TotalSamples) then begin
        if FreeOnStop or (CloneOf >= 0) then FreeSound(MixingBuffers[j]) else Status := ssStopped;
        Continue;
      end;

      MixVol := (LastVolume * (Len-i-1) + Volume * i) * $100 div (Len-1);
      MixPan := (   LastPan * (Len-i-1) +    Pan * i) div (Len-1);

      if (Interpolation = imLinear) then
       Value := ( PSmallintBuffer(Buffer)^[Pos1] * ($100 - PositionFrac) +
                  PSmallintBuffer(Buffer)^[Pos2] * (       PositionFrac) ) else
        Value := PSmallintBuffer(Buffer)^[Pos1] * $100;

      Value := Value * MixVol;

      Value1 := Value1 + Value * MinI(128, (127 - MixPan));
      Value2 := Value2 + Value * MinI(128, (128 + MixPan));

      PositionFrac := PositionFrac + Frequency * $100 div Integer(MixerBufferFreq);
      Position     := Position + PositionFrac shr 8;
      PositionFrac := PositionFrac and $FF;
    end;

//    for j := 0 to 1000 do
    Buffer^[i*2  ] := MinI(32767+0*32768, MaxI(-32768, Value1 div $80000000));
    Buffer^[i*2+1] := MinI(32767+0*32768, MaxI(-32768, Value2 div $80000000));

//    Buffer^[i] := Trunc(0.5 + Sin(tick*pi/80)*30000);
//    Inc(Tick);
  end;

  for i := 0 to LastChannelsMixed-1 do begin
    Sounds[MixingBuffers[i]].LastVolume := Sounds[MixingBuffers[i]].Volume;
    Sounds[MixingBuffers[i]].LastPan    := Sounds[MixingBuffers[i]].Pan;
  end;
end;

procedure TSoftAudio.GetChannelsToMix;
// Must be called once per mixing cycle
var i: Integer;
begin
  LastChannelsMixed := 0;
  for i := 0 to MaxSounds-1 do if ((Sounds[i].Status and $0F) = ssPlaying) and (Sounds[i].Buffer <> nil) then begin
    if Sounds[i].LastVolume >= 0 then begin
      MixingBuffers[LastChannelsMixed] := i;
      Inc(LastChannelsMixed);
      if LastChannelsMixed = MaxChannels then Break;
    end else begin
      Sounds[i].LastVolume := Sounds[i].Volume;
      Sounds[i].LastPan    := Sounds[i].Pan;
    end;
  end;
end;

procedure TSoftAudio.ProcessMixer;
begin
  inherited;

  GetChannelsToMix;

  Inc(MixingTick);
end;

procedure TSoftAudio.FreeSound(SoundIndex: Integer);

function FreeBuffer: Boolean;
var i, NewOrig: Integer;
begin
  Result := False;
  if Sounds[SoundIndex].CloneOf < 0 then begin            // Not cloned
    NewOrig := -1;
    for i := 0 to MaxSounds-1 do if (Sounds[i].Status <> ssFree) and (Sounds[i].CloneOf = SoundIndex) then begin
      if NewOrig = -1 then begin
        NewOrig := i;
        Sounds[i].CloneOf := -1;                                 // Sounds[i] is now original sound
      end else Sounds[i].CloneOf := NewOrig;                     // Other sounds are now clones of Sounds[i]
    end;
    if NewOrig = -1 then FreeMem(Sounds[SoundIndex].Buffer);
    Result := True;
  end else Sounds[SoundIndex].Status := ssFree;
end;

begin
  if Sounds[SoundIndex].Buffer = nil then Exit;
  FreeBuffer;
  inherited;
end;

destructor TSoftAudio.Free;
var i: Integer;
begin

  Log(ClassName + ': Shutting down DirectSound', lkTitle);

  for i := 0 to MaxSounds-1 do FreeSound(i);
  if TempBuf <> nil then FreeMem(TempBuf);
  inherited;
end;

{ TSoftDXAudio }

constructor TSoftDXAudio.Create(AHandle: Cardinal);
begin
  Initialized := False;
  DirectSound := InitDirectSound(AHandle);
  if DirectSound = nil then Exit;
  inherited;
end;

function TSoftDXAudio.InitMixer(ABufferFormat, ATimeQuantum, APlayLag: Cardinal): Boolean;
begin
  Result := False;
  if not inherited InitMixer(ABufferFormat, ATimeQuantum, APlayLag) then Exit;

  Result      := False;
  DSoundBuf   := nil;
  BufferParts := PlayLag *2;
  DSoundBuf   := IDirectSoundBuffer(CreateDSBuffer(DirectSound, MixerFormat, BufferParts * MixerBufferPartLen * MixerBufElSize, DSBCAPS_CTRLVOLUME or DSBCAPS_GETCURRENTPOSITION2));

  if DSoundBuf = nil then Exit;

  ResetPlayBuffer;
  SetMasterVolume(MasterVolume);

  Result      := True;
end;

procedure TSoftDXAudio.ResetPlayBuffer;
begin
  if Playing then begin
    DSoundBuf.Stop;
    DSoundBuf.SetCurrentPosition(0);
  end;
  inherited;  
  PlayingTick := 0;
  SilentTick  := 0;
  CurrentPart := 0;
end;

procedure TSoftDXAudio.SetMasterVolume(const Value: Cardinal);
begin
  inherited;
  if DSoundBuf <> nil then DSoundBuf.SetVolume(DSBVOLUME_MIN + Trunc(0.5 + Ln(9*Ln(Value+1)/(Ln(2)*8)+1)/Ln(10) * Abs(DSBVOLUME_MIN) ));
end;

procedure TSoftDXAudio.ProcessMixer;
var
  Res: HResult; PTR1, PTR2: Pointer; Bytes1, Bytes2: Cardinal;
begin
  GetChannelsToMix;

  if LastChannelsMixed = 0 then begin                                  // Silence
    if MixingTick = 0 then Exit;                              // Not played anything yet
    Inc(SilentTick);
    if StopOnSilence and (SilentTick > PlayLag) then begin
      ResetPlayBuffer;
      Exit;
    end;
  end else SilentTick := 0;              // Silence broken

  Res := DSoundBuf.Lock(CurrentPart * MixerBufferPartLen * MixerBufElSize, MixerBufferPartLen * MixerBufElSize, Ptr1, Bytes1, PTR2, Bytes2, 0{DSBLOCK_ENTIREBUFFER});
  if Failed(Res) then begin

    Log('Error locking sound buffer. Result: ' + IntToStr(Res) + ' Error #: ' + IntToStr(Res - MAKE_DSHRESULT_), lkError);

    Exit;
  end;

  DoMix(Ptr1, MixerBufferPartLen);
//  Move(TempBuf^, Ptr1^, Bytes1);

  DSoundBuf.Unlock(Ptr1, Bytes1, PTR2, Bytes2);

  if not Playing and (MixingTick >= PlayLag) then begin
    DSoundBuf.Play(0, 0, DSBPLAY_LOOPING);
    Playing := True;
  end;

  Inc(MixingTick);

  CurrentPart := MixingTick mod BufferParts;
end;

destructor TSoftDXAudio.Free;
begin
  DSoundBuf := nil;
  DirectSound := nil;
  inherited;
end;

{$IFDEF DEBUGMODE}
procedure TSoftDXAudio.GetDebugInfo(var BufParts: Cardinal; var BufPartLen, CurPart, APlayLag, DSPlayPos, DSWritePos, LastChannels: Integer);
begin
  BufParts   := BufferParts;
  BufPartLen := MixerBufferPartLen;
  CurPart    := CurrentPart;
  APlayLag   := PlayLag;

  if Playing then DSoundBuf.GetCurrentPosition(@DSPlayPos, @DSWritePos);

  LastChannels := LastChannelsMixed;
end;
{$ENDIF}

end.
