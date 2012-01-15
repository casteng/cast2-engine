{$Include GDefines}
{$Include CDefines}
unit CMusic;

interface

uses
   Logger, 
  Basics, CAudio, Windows;

const
  Sqrt12Of2 = 1.0594630943592952645618252949463;
  Sqrt1536of2 = 1.0004513695322615727617341558255;
//  261 277 293 311 329 349 370 392 415 440 466 494

  SampleSign: TFileSignature = ('S', 'D', '0', '0');
  SamplesSign: TFileSignature = ('S', 'D', '0', '0');
  SamplesSign1: TFileSignature = ('S', 'D', 'B', '1');

  InstrumentSign: TFileSignature = ('I', 'F', '0', '0');
  InstrumentsSign: TFileSignature = ('I', 'C', '0', '0');
  InstrSamplesSign: TFileSignature = ('I', 'S', 'C', '0');

  SongSign: TFileSignature = ('T', 'Q', '0', '0');

  fSaveInstruments = 1;

  SubSeparator = '\';

  MaxVoices = 256;
  MaxTracks = 1;//256;
  TotalOctaves = 8;
  ExtOctaves = 2;
  TotalNotes = TotalOctaves * 12;  // Note [0..96] 96 - empty note
  MaxVoicesDef = 16;
  BaseOctave = 3;
  FinetuneLevels = 128;

  NotesStr: array[0..11] of string[2] = ('C ', 'C#', 'D ', 'D#', 'E ', 'F ', 'F#', 'G ', 'G#', 'A ', 'A#', 'B ');
  OctavesStr: array[0..TotalOctaves-1] of Char = ('S', 'C', 'B', '1', '2', '3', '4', '5');

// Loop kinds
  lkNone = 0; lkForward = 1; lkPingPong = 2; lkForwardLoopOnly = 3;
// Voice state
  vsFree = 0; vsSustain = 1; vsInUse = 2; vsReserved = 3;
// Sequence commands
  scNoteGo    = 0;      // Hi(Arg) - Note, Lo(Arg) - Instrument
  scNoteStop  = 1;      // Immediately stops specified channel
  scNoteFree  = 2;      // Stops sustaining last note
  scVolume    = 3;      // Arg - new volume
  scPan       = 4;      // Arg - new pan
  scPitch     = 5;      // Arg - new pitch
  scSamplePos = 6;      // Arg * $100 - new pos
  scFinetune  = 7;      // Hi(Arg) - new finetune, Lo(Arg) - sample. For compatibility only
// Envelope types
  etOn = 1; etSustain = 2; etLoop = 4;
  etRelative = 128;

  MaxNameLength = 127;

type
  TItemName = string[MaxNameLength];

  TEnvelopePoint = packed record
    Pos, Value: Word;
  end;

  TEnvelope = array of TEnvelopePoint;

  TNote = packed record
    Step: Integer;
    Command, Channel: Byte;
    Arg: SmallInt;
  end;
  TSequence = record
    MaxStep: Integer;
    LastCommandIndex: array of Integer;
    Notes: array of TNote;
  end;

  TVoice = record       // 32 bytes
    PlayingIndex: Integer;
    VolPosition, PanPosition, FreqPosition: Word;
    Pan: SmallInt;
    Volume, FadeoutVolume, Pitch: Word;
    Instrument, Sample: Word;
    SoundIndex: Smallint;
    State: Byte;
    Sustain: Boolean;
  end;

  TSample = packed record
    Format: Cardinal;
    Size: Integer;

    LoopKind: Integer;
    LoopStart, LoopEnd: Integer;

    FineTune, BaseNote: Integer;

    Name: TItemName;

    Data: Pointer;
// Run time
    SampleRate, LengthInSamples: Integer;
    SoundIndex: Integer;
  end;

const
  SampleHeaderSize = SizeOf(TSample) - 4*SizeOf(Integer);

type
  TInstrument = packed record
    Name: TItemName;
    Volume, Frequency, Pan: Integer;
    MaxChannels, Fadeout: Integer;
    Samples: array[0..TotalNotes-1] of SmallInt;
    VolJitter, FreqJitter: Integer;
    VolEnvPoints, PanEnvPoints, FreqEnvPoints,
    VolSustainPoint, PanSustainPoint, FreqSustainPoint,
    VolEnvLoopStart, VolEnvLoopEnd, PanEnvLoopStart, PanEnvLoopEnd, FreqEnvLoopStart, FreqEnvLoopEnd: Integer;
    VolEnvType, PanEnvType, FreqEnvType: Integer;
    VolEnvelope, PanEnvelope, FreqEnvelope: TEnvelope;
  end;

const
  InstrumentHeaderSize = SizeOf(TInstrument) - 3*SizeOf(TEnvelope);

type
  TSongHeader = record
    SongName, TrackerName: TItemName;
    Desc: string;
  end;

const
  SongBaseHeaderSize = SizeOf(TItemName)*2;

type
  TPlayer = class;

  TInstruments = class
    Count: Integer;
    Items: array of TInstrument;
    Player: TPlayer;
    constructor Create;

    function GetIndexByName(const Name: string): Integer;

    function Add(const Name: string): Integer;
    function AddForced(Name: string): Integer;
    procedure Delete(Index: Integer); virtual;
    procedure DeleteTree(const Path: string); virtual;

    procedure SetMaxChannels(Index, MaxChannels: Integer);

    function Save(Index: Integer; Stream: TDStream): Boolean;
    function Load(Stream: TDStream): Boolean;
    function SaveAll(Stream: TDStream; SaveSamples: Boolean): Boolean;
    function LoadAll(Stream: TDStream): Boolean;

    destructor Free;
  end;

  TPlaying = packed record
    Sequence: Integer;
    StartStep, TotalNotes, Position: Integer;
    Volume, Pan, Pitch: Integer;
    VoiceMap: array of Integer;
  end;

  TTrackElement = packed record
    Step: Integer;
    Sequence: Word;
  end;

  TSong = array[0..MaxTracks-1] of array of TTrackElement;

  TPlayer = class
    Samples: array of TSample; TotalSamples: Integer;
    Instruments: TInstruments;
    Voices: array[0..MaxVoices-1] of TVoice;
    UsedChannels: Integer;

    SongHeader: TSongHeader;
    Sequences: array of TSequence;
    SeqNames: array of TShortName;
    Song: TSong;
    SongPos, SongLength: Integer;

    IsPlaying, IsRecording, PlaySong : Boolean;
    PlayStep, RecStep: Integer;

    Playing: array[0..MaxVoices-1] of TPlaying; TotalPlaying, PlayingMaxStep: Integer;
    RecSequence: TSequence; TotalRecNotes, MaxRecStep: Integer;

    MusicVolume: Integer;        // MusicVolume [0..256]

    RecordingTrack: Integer;

    TimeQuantum: Cardinal;

    constructor Create(AAudio: TAudio); virtual;
    procedure InitFreqs;

    procedure NewSong; virtual;
    function SaveSong(Stream: TDStream): Boolean; virtual;
    function LoadSong(Stream: TDStream): Boolean; virtual;

    function LoadSample(Stream: TDStream): Boolean; virtual;
    function SaveSample(Index: Integer; Stream: TDStream): Boolean; virtual;
    function LoadSamples(Stream: TDStream): Boolean; virtual;
    function SaveSamples(Stream: TDStream): Boolean; virtual;
    function AddSample(const Name: TItemName; Format: Cardinal; Data: Pointer; Size: Integer): Integer; virtual;
    function AddSampleEx(Name: TItemName; Format: Cardinal; Data: Pointer; Size, FineTune, BaseNote, LoopKind, LoopStart, LoopEnd: Integer; Forced: Boolean): Integer; virtual;
    function GetSampleIndex(const Name: TItemName): Integer; virtual;
    procedure DeleteSample(Index: Integer); virtual;
    procedure DeleteSampleTree(const Path: string); virtual;

    procedure InitSample(Index: Integer); virtual;

    function GetUnusedChannel: Integer; virtual;

    procedure PlaySample(const Index: Integer); virtual;
    function PlayNote(PlayingIndex, Instrument, Note: Integer): Integer; virtual;
    function PlayNoteEx(PlayingIndex, Instrument, Note, Volume, Pan, Channel: Integer): Integer; virtual;

    function GetPlayingMaxStep: Integer; virtual;
    procedure Play; virtual;
    procedure SetPlayStep(NewStep: Integer); virtual;

    function GetMaxSequenceStep(Index: Integer): Integer; virtual;
    function InitSequence(Index: Integer): Integer; virtual;
    procedure PlaySequence(const Index: Integer); virtual;
    procedure StopSequence(const PlayingIndex: Integer); virtual;

    function AddSequence(const Name: TShortName): Integer; virtual;
    function AddToSequence(var Sequence: TSequence; Step, Command, Arg, Channel: Integer): Integer;
    procedure MergeSequences(var Sequence: TSequence; Sequence2: TSequence);

    procedure RecordSequence; virtual;

    procedure FreeNote(VoiceIndex, Channel: Integer); virtual;
    procedure StopNote(VoiceIndex, Channel: Integer); virtual;
    procedure StopAll; virtual;

    procedure Reset; virtual;

    procedure ProcessInstruments; virtual;
    procedure ProcessPlayback; virtual;
    procedure Process; virtual;
    destructor Free;
  private
    procedure SetAudio(const Value: TAudio);
  protected
    PlayedNotes: array[0..MaxVoices-1] of record
      Arg, Channel: Smallint;
    end;
    TotalPlayedNotes: Integer;
    CSection: _RTL_CRITICAL_SECTION;
    LastProcessTick, SavedTick: Cardinal;
    FAudio: TAudio;
    function SetChannelVoice(PlayingIndex, Channel: Integer): Integer;
  public
    property Audio: TAudio read FAudio write SetAudio;  
  end;

  procedure GetEnvelopePos(Env: TEnvelope; TotalPoints, SustainPoint, LoopStart, LoopEnd: Integer; var Position: Word; Sustain: Boolean);

var
  NotesFreq: array[0..(TotalOctaves + ExtOctaves)*12*FinetuneLevels-1] of Single;

implementation

uses CTypes, SysUtils;

procedure GetEnvelopePos(Env: TEnvelope; TotalPoints, SustainPoint, LoopStart, LoopEnd: Integer; var Position: Word; Sustain: Boolean);
var LoopRange: Integer;
begin
  Assert(LoopStart <= LoopEnd, 'Invalid envelope loop');

  if Sustain and (SustainPoint >= 0) and (LoopEnd >= 0) then LoopEnd := MinI(LoopEnd, SustainPoint);
  if (LoopEnd <> -1) and (LoopStart <> -1) then
   LoopRange := Env[LoopEnd].Pos - Env[LoopStart].Pos else
    LoopRange := 0;

  if SustainPoint < 0 then begin
    Sustain := False;
    SustainPoint := 0;
  end;

  if LoopRange > 0 then begin
    if Sustain or (LoopEnd > SustainPoint) then
     while Position >= Env[LoopEnd].Pos do Dec(Position, LoopRange);
  end;

  if Sustain then Position := MinI(Position, Env[SustainPoint].Pos);
end;

function GetEnvelopeValue(Env: TEnvelope; TotalPoints, SustainPoint, Position, OffValue: Integer; Sustain: Boolean): Integer;
var i, Range1, Range2, RangeLen: Integer;
{  LB   LE      Sustain
 --<----->-------S------------- }
begin
  if SustainPoint < 0 then begin
    Sustain := False;
    SustainPoint := 0;
  end;

  if Sustain then begin
    if Position >= Env[SustainPoint].Pos then begin
      Result := Env[SustainPoint].Value;
      Exit;
    end else begin
      Range2 := 0;
      for i := 0 to SustainPoint do if Env[i].Pos > Position then begin
        Range2 := i; Break;
      end;
    end;
    Range1 := MaxI(0, Range2-1);
  end else begin
    if Position >= Env[TotalPoints-1].Pos then begin
      Result := OffValue;
      Exit;
    end else begin
      Range2 := 0;
      for i := 0 to TotalPoints-1 do if Env[i].Pos > Position then begin
        Range2 := i; Break;
      end;
    end;
    Range1 := MaxI(0, Range2-1);
  end;

  RangeLen := Env[Range2].Pos - Env[Range1].Pos;
  if RangeLen = 0 then Result := Env[Range1].Value else
   Result := (Env[Range1].Value * (Env[Range2].Pos - Position) + Env[Range2].Value * (Position - Env[Range1].Pos)) div RangeLen;
end;

{ TPlayer }

constructor TPlayer.Create(AAudio: TAudio);
begin
  Audio := AAudio;
  MusicVolume := 256;
  TimeQuantum := 30;
  Instruments := TInstruments.Create;
  Instruments.Player := Self;
  InitializeCriticalSection(CSection);
  SongLength := 0; SetLength(Song[0], 0);
  NewSong;
end;

procedure TPlayer.Reset;
var i: Integer;
begin
  SavedTick := GetTickCount;
  for i := 0 to MaxVoices-1 do begin
    Voices[i].PlayingIndex := -1;
    Voices[i].State := vsFree;
    Voices[i].SoundIndex := -1;
  end;
  UsedChannels := 0;

  for i := 0 to TotalSamples-1 do begin
    Samples[i].SoundIndex := -1;
  end;

  IsPlaying := False;
  PlayingMaxStep := 0;
  IsRecording := False;
  PlayStep := 0;
  PlaySong := False; SongPos := 0;
end;

function TPlayer.LoadSample(Stream: TDStream): Boolean;
var Sign: TFileSignature; Index: Integer; HeaderSize, DataPos: Cardinal; Sample: TSample; Name: string;
begin
  Result := False;

  if Stream = nil then Exit;

  if Stream.Read(Sign, SizeOf(SampleSign)) <> feOK then Exit;
  if Sign <> SampleSign then Exit;

  if Stream.Read(HeaderSize, SizeOf(HeaderSize)) <> feOK then Exit;

  DataPos := Stream.Position + HeaderSize;

  if HeaderSize < 2*SizeOf(Integer) then Exit;
  if HeaderSize > SizeOf(TSample) then HeaderSize := SizeOf(TSample);

  if Stream.Read(Sample, HeaderSize) <> feOK then Exit;
  Stream.Seek(DataPos);

  Index := AddSampleEx(Sample.Name, Sample.Format, nil, 0, 0, 0, 0, 0, 0, True);
  if Index = -1 then Exit;

  Name := Samples[Index].Name;
  Samples[Index] := Sample;
  Samples[Index].Name := Name;

  with Samples[Index] do begin
    LengthInSamples := Size div GetSoundElementSize(Format);
    SampleRate := GetSoundFormatElement(Format, sfeSampleRate);

    SoundIndex := -1; 

    if Size > 0 then begin
      GetMem(Data, Size);
      if Stream.Read(Data^, Size) <> feOK then Exit;
    end else Data := nil;
  end;
  Result := True;
end;

function TPlayer.SaveSample(Index: Integer; Stream: TDStream): Boolean;
var HeaderSize: Integer;
begin
  Result := False;
  Assert(Index <> -1, 'TPlayer.SaveSample: Invalid index');
  if Stream = nil then Exit;

  if Stream.Write(SampleSign, SizeOf(SampleSign)) <> feOK then Exit;

  HeaderSize := SampleHeaderSize;
  if Stream.Write(HeaderSize, SizeOf(HeaderSize)) <> feOK then Exit;

  if Stream.Write(Samples[Index], SampleHeaderSize) <> feOK then Exit;
  if Stream.Write(Samples[Index].Data^, Samples[Index].Size) <> feOK then Exit;

  Result := True;
end;

function TPlayer.LoadSamples(Stream: TDStream): Boolean;
var i, SamplesCount: Integer; Sign: TFileSignature;
begin
  Result := False;

  if Stream = nil then Exit;

  if Stream.Read(Sign, SizeOf(SamplesSign)) <> feOK then Exit;

  if Stream.Read(SamplesCount, SizeOf(TotalSamples)) <> feOK then Exit;

  if Sign = SamplesSign then begin

    TotalSamples := SamplesCount;
    SetLength(Samples, TotalSamples);

    for i := 0 to TotalSamples-1 do with Samples[i] do begin
      if Stream.Read(Name, SizeOf(TShortName)) <> feOK then Exit;

      if Stream.Read(Format, SizeOf(Format)) <> feOK then Exit;

      if Stream.Read(Size, SizeOf(Size)) <> feOK then Exit;
      LengthInSamples := Size div GetSoundElementSize(Format);

      SampleRate := GetSoundFormatElement(Format, sfeSampleRate);
      if Stream.Read(BaseNote, SizeOf(BaseNote)) <> feOK then Exit;

      if Stream.Read(LoopKind, SizeOf(LoopKind)) <> feOK then Exit;
      if Stream.Read(LoopStart, SizeOf(LoopStart)) <> feOK then Exit;
      if Stream.Read(LoopEnd, SizeOf(LoopEnd)) <> feOK then Exit;

      SoundIndex := -1;

      GetMem(Data, Size);
      if Stream.Read(Data^, Size) <> feOK then Exit;
    end;
  end else if Sign = SamplesSign1 then begin
    for i := 0 to SamplesCount-1 do if not LoadSample(Stream) then Exit;
  end else Exit;

  Result := True;
end;

function TPlayer.SaveSamples(Stream: TDStream): Boolean;
var i: Integer;
begin
  Result := False;

  if Stream = nil then Exit;

  if Stream.Write(SamplesSign1, SizeOf(SamplesSign1)) <> feOK then Exit;

  if Stream.Write(TotalSamples, SizeOf(TotalSamples)) <> feOK then Exit;

  for i := 0 to TotalSamples-1 do SaveSample(i, Stream);

  Result := True;
end;

function TPlayer.AddSample(const Name: TItemName; Format: Cardinal; Data: Pointer; Size: Integer): Integer;
begin
  Result := AddSampleEx(Name, Format, Data, Size, 0, 24, lkNone, 0, 0, True);
end;

function TPlayer.AddSampleEx(Name: TItemName; Format: Cardinal; Data: Pointer; Size, FineTune, BaseNote, LoopKind, LoopStart, LoopEnd: Integer; Forced: Boolean): Integer;
var i: Integer; NameBase: string;
begin
  Result := GetSampleIndex(Name);
  if Result <> -1 then begin
    if not Forced then Exit;
    i := 0;
    NameBase := Copy(Name, 1, MaxNameLength-2);
    while GetSampleIndex(Name) <> -1 do begin
      Name := NameBase + IntToStr(i);
      Inc(i);
      if i > 99 then Exit;
    end;
  end;

  Inc(TotalSamples); SetLength(Samples, TotalSamples);

  Samples[TotalSamples-1].Name := Name;
  Samples[TotalSamples-1].Format := Format;
  Samples[TotalSamples-1].Size := Size;
  Samples[TotalSamples-1].FineTune := FineTune;
  Samples[TotalSamples-1].BaseNote := BaseNote;
  Samples[TotalSamples-1].LengthInSamples := Size div GetSoundElementSize(Format);
  Samples[TotalSamples-1].LoopKind := LoopKind;
  Samples[TotalSamples-1].LoopStart := LoopStart;
  Samples[TotalSamples-1].LoopEnd := LoopEnd;
  Samples[TotalSamples-1].SampleRate := GetSoundFormatElement(Format, sfeSampleRate);
  Samples[TotalSamples-1].SoundIndex := -1;

  if Size <> 0 then begin
    GetMem(Samples[TotalSamples-1].Data, Size);
    Move(Data^, Samples[TotalSamples-1].Data^, Size);
  end else Samples[TotalSamples-1].Data := nil;
  Result := TotalSamples-1;
end;

function TPlayer.GetSampleIndex(const Name: TItemName): Integer;
begin
  for Result := 0 to TotalSamples-1 do if Samples[Result].Name = Name then Exit;
  Result := -1;
end;

procedure TPlayer.DeleteSample(Index: Integer);
var i, j: Integer;
begin
  Dec(TotalSamples);
  if Samples[Index].Data <> nil then FreeMem(Samples[Index].Data);
  if Index < TotalSamples then Samples[Index] := Samples[TotalSamples];
  
  for i := 0 to Instruments.Count-1 do for j := 0 to TotalNotes-1 do
   if Instruments.Items[i].Samples[j] = Index then Instruments.Items[i].Samples[j] := -1 else
    if Instruments.Items[i].Samples[j] = TotalSamples then Instruments.Items[i].Samples[j] := Index;

  SetLength(Samples, TotalSamples);
end;

procedure TPlayer.DeleteSampleTree(const Path: string);
var i: Integer;
begin
  for i := TotalSamples-1 downto 0 do if Copy(Samples[i].Name, 1, Length(Path)) = Path then DeleteSample(i);
end;

procedure TPlayer.InitSample(Index: Integer);
begin
  Log(ClassName + '.InitSample: ' + IntToStr(Index));

  if Samples[Index].SoundIndex <> -1 then Audio.FreeSound(Samples[Index].SoundIndex);

  Samples[Index].SoundIndex := -1;

  if Samples[Index].Size = 0 then Exit;
  Samples[Index].SoundIndex := Audio.NewSound(Samples[Index].Format, Samples[Index].Data, Samples[Index].Size, Samples[Index].LoopKind, Samples[Index].LoopStart, Samples[Index].LoopEnd);
end;

procedure TPlayer.PlaySample(const Index: Integer);
begin
  if Samples[Index].Size > 0 then
   Audio.PlaySound(Audio.NewSound(Samples[Index].Format, Samples[Index].Data, Samples[Index].Size, Samples[Index].LoopKind, Samples[Index].LoopStart, Samples[Index].LoopEnd));
end;

function TPlayer.PlayNote(PlayingIndex, Instrument, Note: Integer): Integer;
begin
  Result := PlayNoteEx(PlayingIndex, Instrument, Note, 255, 0, -1);
  if Result = -1 then Exit;
  if IsRecording then begin
    Inc(TotalRecNotes);
    AddToSequence(RecSequence, RecStep, scNoteGo, Note shl 8 + Instrument, -1);
    MaxRecStep := RecStep;
  end;
end;

function TPlayer.PlayNoteEx(PlayingIndex, Instrument, Note, Volume, Pan, Channel: Integer): Integer;
var Sample, FinalPitch: Integer;
begin
  Result := -1;

  if Instrument <> -1 then Sample := Instruments.Items[Instrument].Samples[Note] else Sample := -1;

  if (Sample = -1) or (Sample >= TotalSamples) then Exit;

  if PlayingIndex = -1 then Result := GetUnusedChannel else Result := Playing[PlayingIndex].VoiceMap[Channel];

//  Audio.Log(Format('Note at channel %D in voice %D', [Channel, Result]));

  if Result = -1 then Exit;

//  Assert((Voices[Result].SoundIndex = -1) and (Voices[Result].LoopedIndex = -1), 'TPlayer.PlayNoteEx: ');

  if Voices[Result].SoundIndex <> -1 then Audio.StopSound(Voices[Result].SoundIndex);
  if (Samples[Sample].SoundIndex = -1) then begin
    InitSample(Sample);
    Voices[Result].SoundIndex := Samples[Sample].SoundIndex;
  end else if Audio.IsSoundPlaying(Samples[Sample].SoundIndex) then begin
    Voices[Result].SoundIndex := Audio.CloneSound(Samples[Sample].SoundIndex);
  end else begin
    Voices[Result].SoundIndex := Samples[Sample].SoundIndex;
  end;

  Note := Note * FinetuneLevels;
  FinalPitch := MaxI(0, MinI((TotalOctaves + ExtOctaves)*12*FinetuneLevels-1, Note + Samples[Sample].FineTune));

  Voices[Result].PlayingIndex := PlayingIndex;
  Voices[Result].State := vsInUse;
  Voices[Result].Sustain := True;
  Voices[Result].VolPosition := 0;
  Voices[Result].PanPosition := 0;
  Voices[Result].FreqPosition := 0;

  Voices[Result].Volume := Volume;
  Voices[Result].FadeoutVolume := 65535;
  Voices[Result].Pan := Pan;
  Voices[Result].Pitch := Note;

  Voices[Result].Sample := Sample;
  Voices[Result].Instrument := Instrument;

  if Voices[Result].SoundIndex <> -1 then begin
    Audio.SetFrequency(Voices[Result].SoundIndex, Trunc(0.5 + Samples[Sample].SampleRate / NotesFreq[Samples[Sample].BaseNote * FinetuneLevels] * NotesFreq[FinalPitch]));
    Audio.SetVolume(Voices[Result].SoundIndex, (Volume*MusicVolume) shr 8);
    Audio.SetPan(Voices[Result].SoundIndex, Voices[Result].Pan);
    Audio.SetPosition(Voices[Result].SoundIndex, 0);
    Audio.PlaySound(Voices[Result].SoundIndex);
  end;
end;

procedure TPlayer.FreeNote(VoiceIndex, Channel: Integer);
begin
  if (Voices[VoiceIndex].Instrument >= Instruments.Count) then Exit;
  with Instruments.Items[Voices[VoiceIndex].Instrument] do
   if (VolEnvelope = nil) or (VolEnvPoints = 0) then StopNote(VoiceIndex, Channel) else begin
     Voices[VoiceIndex].Sustain := False;
//     if (VolSustainPoint <> VolEnvPoints-1) then Position := VolEnvelope[SustainPoint];
    end;

  if IsRecording and (Channel <> -1) then begin
    Inc(TotalRecNotes);
    AddToSequence(RecSequence, RecStep, scNoteFree, 0, Channel);
    MaxRecStep := RecStep;
  end;
end;

procedure TPlayer.StopNote(VoiceIndex, Channel: Integer);
begin
//  Assert(Channels[ChannelIndex].Instrument >= 0, 'StopNote: Invalid instrument: ' + IntToStr(Channels[ChannelIndex].Instrument));
  if (Voices[VoiceIndex].Instrument >= Instruments.Count) then Exit;

{$IFDEF DEBUGMODE}
//  Audio.Log(Format('StopNote. V: %D, SI: %D, LI: %D', [VoiceIndex, Voices[VoiceIndex].SoundIndex, Voices[VoiceIndex].LoopedIndex]));
{$ENDIF}

  if Voices[VoiceIndex].SoundIndex <> -1 then begin
    Audio.StopSound(Voices[VoiceIndex].SoundIndex);
    Voices[VoiceIndex].SoundIndex := -1;
  end;

  if (Voices[VoiceIndex].PlayingIndex <> -1) then Voices[VoiceIndex].State := vsReserved else begin
    Voices[VoiceIndex].State := vsFree;
    Dec(UsedChannels);
  end;

  if IsRecording and (Channel <> -1) then begin
    Inc(TotalRecNotes);
    AddToSequence(RecSequence, RecStep, scNoteStop, 0, Channel);
    MaxRecStep := RecStep;
  end;
end;

function TPlayer.GetUnusedChannel: Integer;
var i: Integer;
begin
{$IFDEF DEBUGMODE}
  Result := 0;
{$ELSE}
  Result := UsedChannels;
{$ENDIF}
  Inc(UsedChannels);
  for i := 0 to MaxVoices-1 do begin
    if (Voices[Result].State = vsFree) then Exit;
    if Result < MaxVoices-1 then Inc(Result) else Result := 0;
  end;
  Result := -1;
end;

function TPlayer.GetMaxSequenceStep(Index: Integer): Integer;
var i: Integer;
begin
  Sequences[Index].MaxStep := 0;
  for i := 0 to Length(Sequences[Index].Notes)-1 do
   if Sequences[Index].MaxStep < Sequences[Index].Notes[i].Step then Sequences[Index].MaxStep := Sequences[Index].Notes[i].Step;
  Result := Sequences[Index].MaxStep;
end;

function TPlayer.InitSequence(Index: Integer): Integer;
var i: Integer;
begin
  Result := 0;
  if Index >= Length(Sequences) then Exit;

  Sequences[Index].MaxStep := GetMaxSequenceStep(Index);

  for i := 0 to Length(Sequences[Index].Notes)-1 do
   if Result < Sequences[Index].Notes[i].Channel+1 then Result := Sequences[Index].Notes[i].Channel+1;
  SetLength(Sequences[Index].LastCommandIndex, Result);

  for i := 0 to Length(Sequences[Index].Notes)-1 do
   Sequences[Index].LastCommandIndex[Sequences[Index].Notes[i].Channel] := i;
end;

procedure TPlayer.PlaySequence(const Index: Integer);
var SeqChannels, i: Integer;
begin
  if TotalPlaying >= MaxVoices then Exit;
  Inc(TotalPlaying);
  SeqChannels := InitSequence(Index);

  SetLength(Playing[TotalPlaying-1].VoiceMap, SeqChannels);
  for i := 0 to SeqChannels-1 do Playing[TotalPlaying-1].VoiceMap[i] := -1;

  Playing[TotalPlaying-1].Sequence := Index;
  if IsPlaying then
   Playing[TotalPlaying-1].StartStep := PlayStep else        // Step when sequence play started
    Playing[TotalPlaying-1].StartStep := 0;                  // Zero if nothing played
  Playing[TotalPlaying-1].TotalNotes := Length(Sequences[Index].Notes);
  if Playing[TotalPlaying-1].TotalNotes = 0 then Exit;

  Playing[TotalPlaying-1].Volume := 255;
  Playing[TotalPlaying-1].Pan := 0;
  Playing[TotalPlaying-1].Pitch := 0;

  Playing[TotalPlaying-1].Position := 0;
  if not IsPlaying then PlayStep := 0;
  IsPlaying := True;
end;

procedure TPlayer.StopSequence(const PlayingIndex: Integer);
var i: Integer;
begin
  EnterCriticalSection(CSection);
  for i := 0 to Length(Playing[PlayingIndex].VoiceMap)-1 do begin
    Voices[Playing[PlayingIndex].VoiceMap[i]].PlayingIndex := -1;
    StopNote(Playing[PlayingIndex].VoiceMap[i], -1);
  end;
  Playing[PlayingIndex].Sequence := -1;
  if PlayingIndex < TotalPlaying-1 then Playing[PlayingIndex] := Playing[TotalPlaying-1];
  Dec(TotalPlaying);
  LeaveCriticalSection(CSection);
end;

procedure TPlayer.StopAll;
var i: Integer;
begin
  EnterCriticalSection(CSection);
  IsPlaying := False;
  IsRecording := False;
  TotalPlaying := 0;
  PlayingMaxStep := 0;
  for i := 0 to MaxVoices-1 do if (Voices[i].State <> vsFree) then StopNote(i, -1);
  LeaveCriticalSection(CSection);
end;

destructor TPlayer.Free;
begin
  StopAll;
  DeleteCriticalSection(CSection);
  Instruments.Free;
end;

procedure TPlayer.RecordSequence;
begin
  IsRecording := True; RecStep := 0;
  TotalRecNotes := 0; MaxRecStep := 0;
  SetLength(RecSequence.Notes, 0);
end;

procedure TPlayer.ProcessInstruments;
var i, EnvVol, FinalVol, EnvPan, FinalPan, EnvPitch, FinalPitch, SustainPoint, LoopStart, LoopEnd: Integer;
begin
  for i := 0 to MaxVoices-1 do if (Voices[i].State <> vsFree) and (Voices[i].Instrument < Instruments.Count) then begin
    if (Voices[i].SoundIndex  = -1) or not Audio.CheckSoundInUse(Voices[i].SoundIndex ) or not Audio.IsSoundPlaying(Voices[i].SoundIndex ) then begin
      if (Voices[i].PlayingIndex <> -1) then Voices[i].State := vsReserved else begin
        Voices[i].State := vsFree;
        Dec(UsedChannels);
      end;
      Voices[i].SoundIndex := -1;
    end;
// Envelopes handling
    with Instruments.Items[Voices[i].Instrument] do begin
// Volume envelope handling
      if (VolEnvType and etOn > 0) and (VolEnvelope <> nil) and (VolEnvPoints > 0) then begin
        if VolEnvType and etSustain > 0 then SustainPoint := VolSustainPoint else SustainPoint := -1;
        if VolEnvType and etLoop > 0 then begin
          LoopStart := VolEnvLoopStart; LoopEnd := VolEnvLoopEnd;
        end else begin
          LoopStart := -1; LoopEnd := -1;
        end;
        if Voices[i].Sustain or (SustainPoint <> VolEnvPoints-1) then Inc(Voices[i].VolPosition);
        GetEnvelopePos(VolEnvelope, VolEnvPoints, SustainPoint, LoopStart, LoopEnd, Voices[i].VolPosition, Voices[i].Sustain{ or (VolSustainPoint = VolEnvPoints-1)});
        EnvVol := GetEnvelopeValue(VolEnvelope, VolEnvPoints, SustainPoint, Voices[i].VolPosition,
                                   0, Voices[i].Sustain{ or (VolSustainPoint = VolEnvPoints-1)});
      end else EnvVol := 255;

      if (Voices[i].FadeoutVolume <= Instruments.Items[Voices[i].Instrument].Fadeout) or (EnvVol = 0) then begin
        StopNote(i, -1);
        Continue;
      end else begin
        if not Voices[i].Sustain then Dec(Voices[i].FadeoutVolume, Instruments.Items[Voices[i].Instrument].Fadeout);

        FinalVol := Trunc(0.5 + (Voices[i].Volume/255) * (Voices[i].FadeoutVolume/65535) * (EnvVol/255) {$IFDEF DEBUGMODE} * Instruments.Items[Voices[i].Instrument].Volume/255 {$ENDIF} * (MusicVolume/255) * 255);

        if Voices[i].SoundIndex  <> -1 then Audio.SetVolume(Voices[i].SoundIndex,  FinalVol);
      end;
// Panning envelope handling
      if (PanEnvType and etOn > 0) and (PanEnvelope <> nil) and (PanEnvPoints > 0) then begin
        if PanEnvType and etSustain > 0 then SustainPoint := PanSustainPoint else SustainPoint := -1;
        if PanEnvType and etLoop > 0 then begin
          LoopStart := PanEnvLoopStart; LoopEnd := PanEnvLoopEnd;
        end else begin
          LoopStart := -1; LoopEnd := -1;
        end;
        if Voices[i].Sustain or (SustainPoint <> PanEnvPoints-1) then Inc(Voices[i].PanPosition);
        GetEnvelopePos(PanEnvelope, PanEnvPoints, SustainPoint, LoopStart, LoopEnd, Voices[i].PanPosition, Voices[i].Sustain{ or (PanSustainPoint = PanEnvPoints-1)});
        EnvPan := GetEnvelopeValue(PanEnvelope, PanEnvPoints, SustainPoint, Voices[i].PanPosition,
                                   0, Voices[i].Sustain{ or (PanSustainPoint = PanEnvPoints-1)})-128;
      end else EnvPan := 0;

      FinalPan := MinI(127, MaxI(-128, Voices[i].Pan + EnvPan {$IFDEF DEBUGMODE} + Instruments.Items[Voices[i].Instrument].Pan {$ENDIF} ));

      if Voices[i].SoundIndex  <> -1 then Audio.SetPan(Voices[i].SoundIndex,  FinalPan);
// Pitch envelope handling
      if (FreqEnvelope <> nil) and (FreqEnvPoints > 0) then begin
        if FreqEnvType and etSustain > 0 then SustainPoint := FreqSustainPoint else SustainPoint := -1;
        if FreqEnvType and etLoop > 0 then begin
          LoopStart := FreqEnvLoopStart; LoopEnd := FreqEnvLoopEnd;
        end else begin
          LoopStart := -1; LoopEnd := -1;
        end;
        if Voices[i].Sustain or (SustainPoint <> FreqEnvPoints-1) then Inc(Voices[i].FreqPosition);
        GetEnvelopePos(FreqEnvelope, FreqEnvPoints, SustainPoint, LoopStart, LoopEnd, Voices[i].FreqPosition, Voices[i].Sustain{ or (VolSustainPoint = VolEnvPoints-1)});
        EnvPitch := GetEnvelopeValue(FreqEnvelope, FreqEnvPoints, SustainPoint, Voices[i].FreqPosition,
                                     128, Voices[i].Sustain{ or (VolSustainPoint = VolEnvPoints-1)}) - 128;

      end else EnvPitch := 0;
      FinalPitch := Trunc(0.5 + Self.Samples[Voices[i].Sample].SampleRate / NotesFreq[Self.Samples[Voices[i].Sample].BaseNote * FinetuneLevels] *
                                NotesFreq[MaxI(0, MinI((TotalOctaves + ExtOctaves)*12*FinetuneLevels-1, Voices[i].Pitch + EnvPitch*8 + Self.Samples[Voices[i].Sample].FineTune))]);

      if Voices[i].SoundIndex  <> -1 then Audio.SetFrequency(Voices[i].SoundIndex,  FinalPitch);
    end;
  end;
end;

procedure TPlayer.ProcessPlayback;
var i, j, SeqPlayStep: Integer;

procedure AddPlayedNote(Arg, Channel: Smallint);
begin
  Inc(TotalPlayedNotes);
  PlayedNotes[TotalPlayedNotes-1].Arg := Arg;
  PlayedNotes[TotalPlayedNotes-1].Channel:= Channel;
end;

begin
  if IsPlaying then begin
    if PlaySong then begin
      for i := 0 to MaxTracks-1 do while (SongPos < SongLength) and (Song[i, SongPos].Step = PlayStep) do begin
        PlaySequence(Song[i, SongPos].Sequence);
        Inc(SongPos);
      end;
    end;

    for i := 0 to TotalPlaying-1 do begin
      SeqPlayStep := PlayStep - Playing[i].StartStep;
      TotalPlayedNotes := 0;
      while (Playing[i].Position < Playing[i].TotalNotes) and (Sequences[Playing[i].Sequence].Notes[Playing[i].Position].Step = SeqPlayStep) do begin
        with Sequences[Playing[i].Sequence].Notes[Playing[i].Position] do begin
          SetChannelVoice(i, Channel);
          case Command of
            scNoteGo: AddPlayedNote(Arg, Channel);
            scNoteStop: if Playing[i].VoiceMap[Channel] <> -1 then StopNote(Playing[i].VoiceMap[Channel], Channel);
            scNoteFree: if Playing[i].VoiceMap[Channel] <> -1 then FreeNote(Playing[i].VoiceMap[Channel], Channel);
            scVolume: begin
              Voices[Playing[i].VoiceMap[Channel]].Volume := Arg;
              Playing[i].Volume := Arg;
            end;
            scPan: begin
              Voices[Playing[i].VoiceMap[Channel]].Pan := Arg;
              Playing[i].Pan := Arg;
            end;
            scPitch: Voices[Playing[i].VoiceMap[Channel]].Pitch := Arg;
          end;
        end;

        Inc(Playing[i].Position);
      end;

      for j := 0 to TotalPlayedNotes-1 do PlayNoteEx(i, PlayedNotes[j].Arg and $FF, (PlayedNotes[j].Arg shr 8) and $FF, Playing[i].Volume, Playing[i].Pan, PlayedNotes[j].Channel);

//      if SeqPlayStep >= Playing[i].MaxStep then StopSequence(i);

    end;
    if TotalPlaying > 0 then Inc(PlayStep) else begin
      IsPlaying := False;
      PlayingMaxStep := 0;
    end;
  end;
end;

procedure TPlayer.Process;
begin
  EnterCriticalSection(CSection);

  LastProcessTick := GetTickCount;
  while SavedTick + TimeQuantum < LastProcessTick do begin
    ProcessPlayback;
    ProcessInstruments;
    if IsRecording then Inc(RecStep);
    Inc(SavedTick, TimeQuantum);
    Audio.ProcessMixer;
  end;  

  LeaveCriticalSection(CSection);
end;

procedure TPlayer.Play;
begin
  StopAll;
  SongPos := 0;
  PlaySong := SongLength > 0;
  IsPlaying := IsPlaying or PlaySong;
  PlayStep := 0;

  PlayingMaxStep := GetPlayingMaxStep;
end;

procedure TPlayer.SetPlayStep(NewStep: Integer);
var i, j: Integer; Note: TNote;
begin
  EnterCriticalSection(CSection);
  PlayStep := NewStep;
  TotalPlaying := 0;
  for i := 0 to MaxVoices-1 do if (Voices[i].State <> vsFree) then StopNote(i, -1);

  SongPos := -1;

  for j := 0 to MaxTracks-1 do for i := 0 to SongLength-1 do begin
    if (Song[j, i].Step <= NewStep) and (Song[j, i].Step + GetMaxSequenceStep(Song[j, i].Sequence) >= NewStep) then begin
      PlaySequence(Song[j, i].Sequence);
      Playing[TotalPlaying-1].StartStep := Song[j, i].Step;
    end;
    if (Song[j, i].Step >= NewStep) and (SongPos = -1) then SongPos := i;
  end;

  if SongPos = -1 then SongPos := SongLength;

  for j := 0 to TotalPlaying-1 do begin
    Playing[j].Position := -1;
    for i := 0 to Playing[j].TotalNotes-1 do begin
      Note := Sequences[Playing[j].Sequence].Notes[i];
      if (Playing[j].StartStep + Note.Step >= NewStep) then begin
        Playing[j].Position := i;
        Break;
      end else begin
        SetChannelVoice(j, Note.Channel);
        case Note.Command of
          scVolume: begin
            Voices[Playing[j].VoiceMap[Note.Channel]].Volume := Note.Arg;
            Playing[j].Volume := Note.Arg;
          end;
          scPan: begin
            Voices[Playing[j].VoiceMap[Note.Channel]].Pan := Note.Arg;
            Playing[j].Pan := Note.Arg;
          end;
        end;
      end;
    end;
//    Assert(Playing[j].Position <> -1, 'SetPlayStep: Invalid sequence position');
  end;
  LeaveCriticalSection(CSection);
end;

function TPlayer.GetPlayingMaxStep: Integer;
var i, j, MaxStep: Integer;
begin
  Result := 0;

  for j := 0 to MaxTracks-1 do for i := 0 to SongLength-1 do begin
    MaxStep := Song[j, i].Step + GetMaxSequenceStep(Song[j, i].Sequence);
    if Result < MaxStep then Result := MaxStep;
  end;
end;

function TPlayer.AddSequence(const Name: TShortName): Integer;
begin
  Result := Length(Sequences);
  SetLength(Sequences, Result+1);
  SetLength(SeqNames, Result+1);
  SeqNames[Result] := Name;
  Sequences[Result].Notes := nil;
end;

function TPlayer.AddToSequence(var Sequence: TSequence; Step, Command, Arg, Channel: Integer): Integer;
var i, ind: Integer;
begin
  Result := Length(Sequence.Notes)+1;
  SetLength(Sequence.Notes, Result);

  ind := Result-1;
// 1 2 4 6 7
  for i := Result-1 downto 1 do 
   if Sequence.Notes[i-1].Step > Step then Sequence.Notes[i] := Sequence.Notes[i-1] else begin
     ind := i;
     Break;
   end;

  Sequence.Notes[ind].Step    := Step;
  Sequence.Notes[ind].Command := Command;
  Sequence.Notes[ind].Arg     := Arg;
  Sequence.Notes[ind].Channel := Channel;
end;

procedure TPlayer.MergeSequences(var Sequence: TSequence; Sequence2: TSequence);
var i: Integer;
begin
  for i := 0 to Length(Sequence2.Notes)-1 do AddToSequence(Sequence, Sequence2.Notes[i].Step, Sequence2.Notes[i].Command, Sequence2.Notes[i].Arg, Sequence2.Notes[i].Channel);
end;

procedure TPlayer.InitFreqs;
var i, j, k: Integer;
begin
  for i := 0 to 11 do for j := 1 to FinetuneLevels-1 do
   NotesFreq[(BaseOctave*12 + i) * FinetuneLevels + j] := NotesFreq[(BaseOctave*12 + i) * FinetuneLevels + j-1] * Sqrt1536of2;

  for k := BaseOctave-1 downto 0 do for i := 0 to 11 do for j := 0 to FinetuneLevels-1 do
   NotesFreq[(k*12 + i) * FinetuneLevels + j] := NotesFreq[((k+1)*12 + i) * FinetuneLevels + j] * 0.5;
  for k := BaseOctave+1 to TotalOctaves + ExtOctaves-1 do for i := 0 to 11 do for j := 0 to FinetuneLevels-1 do
   NotesFreq[(k*12 + i) * FinetuneLevels + j] := NotesFreq[((K-1)*12 + i) * FinetuneLevels + j] * 2;
end;

function TPlayer.SetChannelVoice(PlayingIndex, Channel: Integer): Integer;
begin
  Result := -1;
  if PlayingIndex >= TotalPlaying then Exit;
  if Playing[PlayingIndex].VoiceMap[Channel] = -1 then begin
    Result := GetUnusedChannel;
    Playing[PlayingIndex].VoiceMap[Channel] := Result;
    Voices[Playing[PlayingIndex].VoiceMap[Channel]].State := vsReserved;
    Voices[Playing[PlayingIndex].VoiceMap[Channel]].PlayingIndex := PlayingIndex;
//    Inc(UsedChannels);
  end;
end;

procedure TPlayer.NewSong;
var i: Integer;
begin
  StopAll;
  Reset;
  SongLength := 0; SetLength(Song[0], 0);
  SongHeader.SongName := 'Untitled song';
  SongHeader.TrackerName := 'Trequencer 0.5';
  SongHeader.Desc := '';

  for i := 0 to Length(Sequences)-1 do Sequences[i].Notes := nil;
  Sequences := nil; SeqNames := nil;

  for i := 0 to MaxTracks-1 do Song[i] := nil;

end;

function TPlayer.SaveSong(Stream: TDStream): Boolean;
var Flags, i, HeaderSize, DescLen, TotalSeqs, SeqLen, TotalTracks, TrackLen: Integer; LastPos: Cardinal;
begin
  Result := False;

  if Stream.Write(SongSign, SizeOf(SongSign)) <> feOK then Exit;

  HeaderSize := SongBaseHeaderSize + SizeOf(Flags) + SizeOf(DescLen);
  DescLen := Length(SongHeader.Desc);
  if DescLen > 0 then HeaderSize := HeaderSize + DescLen*SizeOf(SongHeader.Desc[1]);

  if Stream.Write(HeaderSize, SizeOf(HeaderSize)) <> feOK then Exit;

  Flags := fSaveInstruments;
  if Stream.Write(Flags, SizeOf(Flags)) <> feOK then Exit;
  if Stream.Write(SongHeader.SongName, SizeOf(SongHeader.SongName)) <> feOK then Exit;
  if Stream.Write(SongHeader.TrackerName, SizeOf(SongHeader.TrackerName)) <> feOK then Exit;

  if Stream.Write(DescLen, SizeOf(DescLen)) <> feOK then Exit;
  if DescLen > 0 then
   if Stream.Write(SongHeader.Desc[1], Length(SongHeader.Desc)*SizeOf(SongHeader.Desc[1])) <> feOK then Exit;
{$IFDEF DEBUGMODE}
  Log('Song header size: ' + IntToStr(HeaderSize));
  LastPos := Stream.Position;
{$ENDIF}
  TotalSeqs := Length(Sequences);
  if Stream.Write(TotalSeqs, SizeOf(TotalSeqs)) <> feOK then Exit;

  for i := 0 to TotalSeqs-1 do begin
    if Stream.Write(SeqNames[i], SizeOf(SeqNames[i])) <> feOK then Exit;
    SeqLen := Length(Sequences[i].Notes);
    if Stream.Write(SeqLen, SizeOf(SeqLen)) <> feOK then Exit;
    if SeqLen > 0 then
     if Stream.Write(Sequences[i].Notes[0], SeqLen * SizeOf(Sequences[i].Notes[0])) <> feOK then Exit;
  end;

  TotalTracks := 1;
  if Stream.Write(TotalTracks, SizeOf(TotalTracks)) <> feOK then Exit;

  for i := 0 to TotalTracks-1 do begin
    TrackLen := Length(Song[i]);
    if Stream.Write(TrackLen, SizeOf(TrackLen)) <> feOK then Exit;
    if TrackLen > 0 then
     if Stream.Write(Song[i][0], TrackLen * SizeOf(Song[i][0])) <> feOK then Exit;
  end;
{$IFDEF DEBUGMODE}  
  Log('Song+sequences size: ' + IntToStr(Stream.Position - LastPos));
  LastPos := Stream.Position;
{$ENDIF}
  if Flags and fSaveInstruments > 0 then if not Instruments.SaveAll(Stream, True) then Exit;
{$IFDEF DEBUGMODE}
  Log('Instruments+samples size: ' + IntToStr(Stream.Position - LastPos));
{$ENDIF}
  Result := True;
end;

function TPlayer.LoadSong(Stream: TDStream): Boolean;
var
  Sign: TFileSignature;
  DataPos, HeaderSize: Cardinal;
  Flags, i, DescLen, TotalSeqs, SeqLen, TotalTracks, TrackLen: Integer;
begin
  Result := False;

  if Stream = nil then Exit;

  NewSong;

  if Stream.Read(Sign, SizeOf(SamplesSign)) <> feOK then Exit;
  if Sign <> SongSign then Exit;

  if Stream.Read(HeaderSize, SizeOf(HeaderSize)) <> feOK then Exit;
  DataPos := Stream.Position + HeaderSize;

  if Stream.Read(Flags, SizeOf(Flags)) <> feOK then Exit;
  if Stream.Read(SongHeader.SongName, SizeOf(SongHeader.SongName)) <> feOK then Exit;
  if Stream.Read(SongHeader.TrackerName, SizeOf(SongHeader.TrackerName)) <> feOK then Exit;

  if Stream.Read(DescLen, SizeOf(DescLen)) <> feOK then Exit;
  SetLength(SongHeader.Desc, DescLen);
  if DescLen > 0 then
   if Stream.Read(SongHeader.Desc[1], Length(SongHeader.Desc)*SizeOf(SongHeader.Desc[1])) <> feOK then Exit;

  Stream.Seek(DataPos);

  if Stream.Read(TotalSeqs, SizeOf(TotalSeqs)) <> feOK then Exit;
  SetLength(Sequences, TotalSeqs);
  SetLength(SeqNames, TotalSeqs);

  for i := 0 to TotalSeqs-1 do begin
    if Stream.Read(SeqNames[i], SizeOf(SeqNames[i])) <> feOK then Exit;
    if Stream.Read(SeqLen, SizeOf(SeqLen)) <> feOK then Exit;
    SetLength(Sequences[i].Notes, SeqLen);
    if SeqLen > 0 then
     if Stream.Read(Sequences[i].Notes[0], SeqLen * SizeOf(Sequences[i].Notes[0])) <> feOK then Exit;
  end;

  if Stream.Read(TotalTracks, SizeOf(TotalTracks)) <> feOK then Exit;

  for i := 0 to TotalTracks-1 do begin
    if Stream.Read(TrackLen, SizeOf(TrackLen)) <> feOK then Exit;
    SetLength(Song[i], TrackLen);
    if TrackLen > 0 then
     if Stream.Read(Song[i][0], TrackLen * SizeOf(Song[i][0])) <> feOK then Exit;
  end;

  SongLength := Length(Song[0]);

  if Flags and fSaveInstruments > 0 then if not Instruments.LoadAll(Stream) then Exit;

  Result := True;
end;

procedure TPlayer.SetAudio(const Value: TAudio);
begin
  FAudio := Value;
  Reset;
end;

{ TInstruments }

constructor TInstruments.Create;
begin                                         
  Count := 0;
end;

function TInstruments.GetIndexByName(const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do if Items[i].Name = Name then begin
    Result := i; Break;
  end;
end;

function TInstruments.Add(const Name: string): Integer;
var i: Integer;
begin
  Result := GetIndexByName(Name);
  if Result <> -1 then Exit;
  Inc(Count); SetLength(Items, Count);
  Items[Count-1].Name := Name;
  Items[Count-1].Volume := 128;
  Items[Count-1].Frequency := 0;
  Items[Count-1].Pan := 0;
  Items[Count-1].Fadeout := 0;
  SetMaxChannels(Count-1, MaxVoicesDef);

  Items[Count-1].VolEnvPoints := 0;
  Items[Count-1].VolEnvLoopStart := -1;
  Items[Count-1].VolEnvLoopEnd := -1;
  Items[Count-1].VolEnvType := 0;
  Items[Count-1].VolEnvelope := nil;

  Items[Count-1].PanEnvPoints := 0;
  Items[Count-1].PanEnvLoopStart := -1;
  Items[Count-1].PanEnvLoopEnd := -1;
  Items[Count-1].PanEnvType := 0;
  Items[Count-1].PanEnvelope := nil;

  Items[Count-1].FreqEnvPoints := 0;
  Items[Count-1].FreqEnvLoopStart := -1;
  Items[Count-1].FreqEnvLoopEnd := -1;
  Items[Count-1].FreqEnvType := 0;
  Items[Count-1].FreqEnvelope := nil;

  for i := 0 to TotalNotes-1 do Items[Count-1].Samples[i] := -1;

  Result := Count-1;
end;

function TInstruments.AddForced(Name: string): Integer;
var i: Integer; NameBase: string;
begin
  Result := -1;
  i := 0;
  NameBase := Copy(Name, 1, MaxNameLength-2);
  while GetIndexByName(Name) <> -1 do begin
    Name := NameBase + IntToStr(i);
    Inc(i);
    if i > 99 then Exit;
  end;
  Result := Add(Name);
end;

procedure TInstruments.Delete(Index: Integer);
var i: Integer;
begin
  for i := 0 to MaxVoices-1 do
   if Player.Voices[i].Instrument = Index then Player.StopNote(i, -1) else
    if Player.Voices[i].Instrument = Count-1 then Player.Voices[i].Instrument := Index;

  Dec(Count);

  if Index < Count then Items[Index] := Items[Count];

  SetLength(Items, Count);
end;

procedure TInstruments.DeleteTree(const Path: string);
var i: Integer;
begin
  for i := Count-1 downto 0 do if Copy(Items[i].Name, 1, Length(Path)) = Path then Delete(i);
end;

procedure TInstruments.SetMaxChannels(Index, MaxChannels: Integer);
begin
  Items[Index].MaxChannels := MaxChannels;
end;

function TInstruments.Save(Index: Integer; Stream: TDStream): Boolean;
var HeaderSize: Integer;
begin
  Result := False;
  Assert(Index <> -1, 'TInstruments.Save: Invalid index');

  if Stream = nil then Exit;

  if Stream.Write(InstrumentSign, SizeOf(InstrumentSign)) <> feOK then Exit;

  HeaderSize := InstrumentHeaderSize;
  if Stream.Write(HeaderSize, SizeOf(HeaderSize)) <> feOK then Exit;

  if Stream.Write(Items[Index], SizeOf(Items[Index]) - (SizeOf(Items[Index].VolEnvelope)*3)) <> feOK then Exit;

  if Items[Index].VolEnvPoints > 0 then
   if Stream.Write(Items[Index].VolEnvelope[0], Items[Index].VolEnvPoints * SizeOf(Items[Index].VolEnvelope[0])) <> feOK then Exit;
  if Items[Index].PanEnvPoints > 0 then
   if Stream.Write(Items[Index].PanEnvelope[0], Items[Index].PanEnvPoints * SizeOf(Items[Index].PanEnvelope[0])) <> feOK then Exit;
  if Items[Index].FreqEnvPoints > 0 then
   if Stream.Write(Items[Index].FreqEnvelope[0], Items[Index].FreqEnvPoints * SizeOf(Items[Index].FreqEnvelope[0])) <> feOK then Exit;

  Result := True;
end;

function TInstruments.Load(Stream: TDStream): Boolean;
var Sign: TFileSignature; Inst: TInstrument; Index: Integer; Name: string; HeaderSize, DataPos: Cardinal;
begin
  Result := False;

  if Stream = nil then Exit;

  if Stream.Read(Sign, SizeOf(InstrumentSign)) <> feOK then Exit;
  if Sign <> InstrumentSign then Exit;

  if Stream.Read(HeaderSize, SizeOf(HeaderSize)) <> feOK then Exit;

  DataPos := Stream.Position + HeaderSize;

  if HeaderSize <= 0 then Exit;
  if HeaderSize > SizeOf(TInstrument) then HeaderSize := SizeOf(TInstrument);

  if Stream.Read(Inst, SizeOf(Inst) - (SizeOf(Inst.VolEnvelope)*3)) <> feOK then Exit;

  Stream.Seek(DataPos);

  Index := AddForced(Inst.Name);
  if Index = -1 then Exit;

  Name := Items[Index].Name;
  Items[Index] := Inst;
  Items[Index].Name := Name;
  Items[Index].MaxChannels := 0;
  SetMaxChannels(Index, Inst.MaxChannels);

  if Items[Index].VolEnvPoints > 0 then begin
    SetLength(Items[Index].VolEnvelope, Items[Index].VolEnvPoints);
    if Stream.Read(Items[Index].VolEnvelope[0], Items[Index].VolEnvPoints * SizeOf(Items[Index].VolEnvelope[0])) <> feOK then Exit;
  end;
  if Items[Index].PanEnvPoints > 0 then begin
    SetLength(Items[Index].PanEnvelope, Items[Index].PanEnvPoints);
    if Stream.Read(Items[Index].PanEnvelope[0], Items[Index].PanEnvPoints * SizeOf(Items[Index].PanEnvelope[0])) <> feOK then Exit;
  end;
  if Items[Index].FreqEnvPoints > 0 then begin
    SetLength(Items[Index].FreqEnvelope, Items[Index].FreqEnvPoints);
    if Stream.Read(Items[Index].FreqEnvelope[0], Items[Index].FreqEnvPoints * SizeOf(Items[Index].FreqEnvelope[0])) <> feOK then Exit;
  end;

  Result := True;
end;

function TInstruments.SaveAll(Stream: TDStream; SaveSamples: Boolean): Boolean;
var i, j, TotalSamplesToSave: Integer; SamplesToSave: array of Integer; LastPos: Cardinal;

procedure AddSample(Index: Integer);
var i: Integer;
begin
  for i := 0 to TotalSamplesToSave-1 do if SamplesToSave[i] = Index then Exit;
  Inc(TotalSamplesToSave); SetLength(SamplesToSave, TotalSamplesToSave);
  SamplesToSave[TotalSamplesToSave-1] := Index;
end;

begin
  Result := False;

  if Stream = nil then Exit;

  if SaveSamples then begin
    if Stream.Write(InstrSamplesSign, SizeOf(InstrSamplesSign)) <> feOK then Exit;
    TotalSamplesToSave := 0;
    for i := 0 to Count-1 do for j := 0 to TotalNotes-1 do AddSample(Items[i].Samples[j]);
    if Stream.Write(TotalSamplesToSave, SizeOf(TotalSamplesToSave)) <> feOK then Exit;
    LastPos := Stream.Position;    
    for i := 0 to TotalSamplesToSave-1 do if not Player.SaveSample(SamplesToSave[i], Stream) then Exit;
{$IFDEF DEBUGMODE}
    Log('Samples size: ' + IntToStr(Stream.Position - LastPos));
{$ENDIF}
  end else
   if Stream.Write(InstrumentsSign, SizeOf(InstrumentsSign)) <> feOK then Exit;

  if Stream.Write(Count, SizeOf(Count)) <> feOK then Exit;

  for i := 0 to Count-1 do if not Save(i, Stream) then Exit;

  Result := True;
end;

function TInstruments.LoadAll(Stream: TDStream): Boolean;
var i, j: Integer; Sign: TFileSignature; OldTotalSamples, TotalSamples, TotalInstruments: Integer;
begin
  Result := False;

  if Stream = nil then Exit;

  if Stream.Read(Sign, SizeOf(InstrSamplesSign)) <> feOK then Exit;

  OldTotalSamples := 0;
  if Sign = InstrSamplesSign then begin
    OldTotalSamples := Player.TotalSamples;
    if Stream.Read(TotalSamples, SizeOf(TotalSamples)) <> feOK then Exit;
    for i := 0 to TotalSamples-1 do if not Player.LoadSample(Stream) then Exit;
  end else if Sign <> InstrumentsSign then Exit;

  if Stream.Read(TotalInstruments, SizeOf(TotalInstruments)) <> feOK then Exit;

  for i := 0 to TotalInstruments-1 do if not Load(Stream) then Exit;

  for i := Count - TotalInstruments to Count-1 do for j := 0 to TotalNotes-1 do Inc(Items[i].Samples[j], OldTotalSamples);

  Result := True;
end;

destructor TInstruments.Free;
begin
  Count := 0; SetLength(Items, 0);
end;

end.
