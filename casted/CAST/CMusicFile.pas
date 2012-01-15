{$Include GDefines}
{$Include CDefines}
unit CMusicFile;

interface

uses Basics, CTypes, CMusic, math;

const
  lfSamples = 1; lfInstruments = 2; lfPatterns = 3; lfOrder = 4; lfAll = $FFFF;
  WfSine = 0; wfTrangle = 1; wfQuad = 2; wfRandom = 3;
  wfNoRetrig = 4;

function LoadMOD(const FileName: string; Player: TPlayer; Filter: Cardinal): Boolean;
function LoadXI(const FileName: string; Player: TPlayer; Filter: Cardinal): Boolean;
function LoadXM(const FileName: string; Player: TPlayer; Filter: Cardinal): Boolean;

implementation

uses SysUtils;

const
  ptMOD = 0; ptXM = 1;
  VibratoSine : array[0..63] of Integer = (0,24,49,74,97,120,141,161,180,197,
                                            212,224,235,244,250,253,255,253,250,
                                            244,235,224,212,197,180,161,141,120,
                                            97,74,49,24,
                                            0,-24,-49,-74,-97,-120,-141,-161,-180,-197,
                                            -212,-224,-235,-244,-250,-253,-255,-253,-250,
                                            -244,-235,-224,-212,-197,-180,-161,-141,-120,
                                            -97,-74,-49,-24);
  StartNoteBias = 12;
  Note2Period: array[0..12*5-1] of word = (
       1712, 1616, 1524, 1440, 1356, 1280, 1208, 1140, 1076, 1016,  960,  906,
       856,  808,  762,  720,  678,  640,  604,  570,  538,  508,  480,  453,
       428,  404,  381,  360,  339,  320,  302,  285,  269,  254,  240,  226,
       214,  202,  190,  180,  170,  160,  151,  143,  135,  127,  120,  113,
       107,  101,   95,   90,   85,   80,   75,   71,   67,   63,   60,   56);


type
  TXMEnvelope = array[0..11] of record Pos, Value: Word; end;
  TXMSample = packed record
    SamLength, SamLoopStart, SamLoopLength: Cardinal;
    SamVolume: Byte;
    SamFineTune: Shortint;
    SamType, SamPan: Byte;
    SamRelNote: Shortint;
    SamRes: Byte;
    SamName: array[1..22] of Char;
    SamData: Pointer;
  end;

  TXMInstrumentHeader2 = packed record
    SampleNumbers: array[0..95] of Byte;
    VolEnv, PanEnv: TXMEnvelope;
    TotalVolPoints, TotalPanPoints: Byte;
    VolSustainPoint, VolLoopStartPoint, VolLoopEndPoint: Byte;
    PanSustainPoint, PanLoopStartPoint, PanLoopEndPoint: Byte;
    VolumeType, PanType: Byte;
    VibratoType, VibratoSweep, VibratoDepth, VibratoRate: Byte;
    VolFadeOut: Word;
    Reserved: array[0..10] of Byte;
  end;

  TXMInstrument = packed record
    Size: Cardinal;
    Name: array[1..22] of Char;
    InstrumentType: Byte;
    TotalSamples: Word;
// If TotalSamples > 0
    Header2: TXMInstrumentHeader2;
    Samples: array of TXMSample;
  end;

  TNoteData = record
    Period: Word;
    Note, Instr, Volume, Effect, Arg: Byte;
  end;
  PMODNoteData = ^TMODNoteData;
  TMODNoteData = packed record
    InstrPeriod: Word;
    InstrEffect, Effect: Byte;
  end;

  TPattern = array[0..$FFFF] of TNoteData;

  TPatHeader = packed record
    HeaderLength: Cardinal;
    PackType: Byte;
    TotalRows, DataSize: Word;
    Data: ^TPattern;
  end;

  TMODPattern = array[0..$FFFF] of TMODNoteData;
  TPatterns = array of TPatHeader;

function Log2(const X: Extended): Extended;
asm
        FLD1
        FLD     X
        FYL2X
        FWAIT
end;

function SwapBytes(const w: Word): Word;
begin
  Result := (w and 255) shl 8 + w shr 8;
end;

function AsciiZToStr(const s, Default: string; Len: Integer): string;
var i: Integer;
begin
  Result := '';
  if s <> '' then for i := 1 to Len do if s[i] <> #0 then Result := Result + s[i] else Break;
  Result := Trim(Result);
  if Result = '' then Result := Default;
end;

function Period2Pitch(Period: Integer): Integer;
//          pitch = LG2(A/(8363*2*Period))     //
const A = 7093789.2 / 8363 / 2; // либо 7159090.5;
begin
  Result := Trunc(0.5 + (Log2(1712 / Period) * 12 + StartNoteBias)* FinetuneLevels);
end;

function Pitch2Period(Pitch: Integer): Integer;
//          pitch = LG2(A/(8363*2*Period))     //
const A = 7093789.2 / 8363 / 2; // либо 7159090.5;
begin
//  pitch := Trunc(0.5 + (Log2(1712 / Period) * 12 + StartNoteBias)* FinetuneLevels);
//  l2 = (pitch / ftl - snb)/12
//  1712/p = 2 ^ (pitch / ftl - snb)/12
  Result := Trunc(0.5 + 1712 / Power(2, (Pitch / FinetuneLevels - StartNoteBias)/12));
end;

function ModToNote(Note: PMODNoteData): TNoteData;
begin
  Result.Period := SwapBytes(Note^.InstrPeriod) and $0FFF;
  Result.Note := 0;
  Result.Instr := (SwapBytes(Note^.InstrPeriod) and $F000) shr 8 or (Note^.InstrEffect and $F0) shr 4;
  Result.Volume := 255;
  Result.Effect := Note.InstrEffect and $0F;
  Result.Arg := Note.Effect;
end;

procedure ConvertPatterns(Player: TPlayer; Patterns: Pointer; PatType: Integer; PatternOrder: PByteBuffer; InstrIndex: PWordBuffer; TotalChannels, SongLen: Integer);
var
  i, j, k, l, Ofs: Integer;
  VolK, PatternRows: Integer;
  CurStep: Single;
  Tempo, Speed, Pitch, Effect, Tmp,
  BreakTo, JumpTo, PitchSign, VolSlide: Integer;
  PatNote: TNoteData;
  NewInstr: Boolean;

  Channels: array of record
    Period, CurrentPeriod, Pitch, Note,
    LastPorta, LastTonePorta, LastTonePortaPeriod, LastVibrato, LastTremolo, LastSampleOffset, LastVolSlide, LastFineVolSlide,
    LoopBegin, LoopCounter,
    VibratoType, VibratoPos, TremoloType, TremoloPos,
    SeqNum, Instr, Volume: Integer;
    Glissando: Boolean;
  end;

  XMPatterns: TPatterns;

function GetEffect(Note: TNoteData): Integer;
begin
  Result := Note.Effect;
  case Result of
    $0: if Note.Effect = 0 then Result := -1;
    $1, $2: if (Note.Arg = 0) and (Channels[k].LastPorta = -1) then Result := -1;
    $3: if ((Note.Arg = 0) and (Channels[k].LastTonePorta = -1)) or
           (Channels[k].CurrentPeriod = -1) or (Channels[k].CurrentPeriod = Note.Period) or ((Note.Period <= 0) and (Channels[k].CurrentPeriod = Channels[k].Period)) or
           ((Note.Period <= 0) and (Channels[k].Period = 0)) or
           ((Note.Period <> 0) and (Note.Instr <> 0)) then Result := -1;      // (?)
    $4: if ((Note.Arg and $0F = 0) and (Channels[k].LastVibrato and $0F = 0)) or
           ((Note.Arg and $F0 = 0) and (Channels[k].LastVibrato and $F0 = 0)) then Result := -1;
    $5: if (Channels[k].LastTonePorta = -1) or
           (Channels[k].CurrentPeriod = -1) or (Channels[k].CurrentPeriod = Note.Period) or ((Note.Period <= 0) and (Channels[k].CurrentPeriod = Channels[k].Period)) or
           ((Note.Period <= 0) and (Channels[k].Period = 0)) or
           ((Note.Period <> 0) and (Note.Instr <> 0)) or                                         // (?)
           ((Note.Arg = 0) or ((Note.Arg and $F <> 0) and (Note.Arg > $F))) and
           ((Channels[k].LastVolSlide = 0) or ((Channels[k].LastVolSlide and $F <> 0) and (Channels[k].LastVolSlide > $F))) then Result := -1;
    $6: if (Channels[k].LastVibrato = 0) or
           ((Note.Arg = 0) or ((Note.Arg and $F <> 0) and (Note.Arg > $F))) and
           ((Channels[k].LastVolSlide = 0) or ((Channels[k].LastVolSlide and $F <> 0) and (Channels[k].LastVolSlide > $F))) then Result := -1;
    $7: if ((Note.Arg and $0F = 0) and (Channels[k].LastTremolo and $0F = 0)) or
           ((Note.Arg and $F0 = 0) and (Channels[k].LastTremolo and $F0 = 0)) then Result := -1;
    $8: ;
    $9: if (Note.Arg = 0) and (Channels[k].LastSampleOffset <= 0) then Result := -1;
    $A: if ((Note.Arg = 0) or ((Note.Arg and $F <> 0) and (Note.Arg > $F))) and
           ((Channels[k].LastVolSlide = 0) or ((Channels[k].LastVolSlide and $F <> 0) and (Channels[k].LastVolSlide > $F))) then Result := -1;
    $B: ;
    $C: ;
    $D: ;
    $E: case (Note.Arg shr 4) and $F of
      $1, $2, $9: if Note.Arg and $F = 0 then Result := -1;
      $A, $B: if (Note.Arg and $F = 0) and (Channels[k].LastFineVolSlide and $0F = 0) then Result := -1;
      $E: if Note.Arg and $F < 2 then Result := -1;
    end;
    $F: if Note.Arg >= $20 then Tempo := Note.Arg else Speed := Note.Arg;
  end;
end;

begin
  SetLength(Channels, TotalChannels);
  Player.SongLength := TotalChannels;
  SetLength(Player.Song[0], Player.SongLength);            // To fix: use tracks for channels
  for i := 0 to TotalChannels-1 do begin
    Channels[i].SeqNum := Player.AddSequence('Channel #' + IntToStr(i));
    Player.Song[0, i].Step := 0;
    Player.Song[0, i].Sequence := Channels[i].SeqNum;
    case i and 3 of
      0, 3: Player.AddToSequence(Player.Sequences[Channels[i].SeqNum], 0, scPan, -128, 0);
      1, 2: Player.AddToSequence(Player.Sequences[Channels[i].SeqNum], 0, scPan, 127, 0);
    end;
    Channels[i].Volume := 0;
    Channels[i].Instr  := 0;

    Channels[i].Period        := 0;
    Channels[i].CurrentPeriod := 0;
    Channels[i].Pitch         := -1;
    Channels[i].Note          := $FF;

    Channels[i].LastPorta           := -1;
    Channels[i].LastTonePorta       := -1;
    Channels[i].LastTonePortaPeriod := -1;
    Channels[i].LastVibrato         := 0;
    Channels[i].LastTremolo         := 0;
    Channels[i].LastSampleOffset    := 0;
    Channels[i].LastVolSlide        := 0;
    Channels[i].LastFineVolSlide    := 0;
    Channels[i].VibratoType         := wfSine or wfNoRetrig;
    Channels[i].VibratoPos          := 0;
    Channels[i].TremoloType         := wfSine or wfNoRetrig;
    Channels[i].TremoloPos          := 0;
    Channels[i].Glissando           := False;
  end;

  if PatType = ptXM then XMPatterns := Patterns else XMPatterns := nil;
  VolK := 4;

//  Pitch := -1;
  CurStep := 0;
  Tempo := 125; Speed := 6;

  BreakTo := -1;
  JumpTo := -1;

  i := 0;

  while i < SongLen do begin
    case PatType of
      ptMOD: PatternRows := 64;
      ptXM: PatternRows := XMPatterns[PatternOrder^[i]].TotalRows;
      else PatternRows := 64;
    end;
    for k := 0 to TotalChannels-1 do begin
      Channels[k].LoopBegin   := -1;
      Channels[k].LoopCounter := -1;
    end;
    if BreakTo <> -1 then  begin
      j := BreakTo;
      if j > PatternRows-1 then j := 0;
      BreakTo := -1;
    end else j := 0;

    while j < PatternRows do begin
      for k := 0 to TotalChannels-1 do begin
        if PatType = ptMOD then begin
          Ofs := ((PatternOrder^[i]*PatternRows+j)*TotalChannels+k) * SizeOf(TMODNoteData);
          PatNote := ModToNote(Pointer(Integer(Patterns)+Ofs));
          if PatNote.Period <> 0 then begin
            for l := 0 to 12*5-1 do if PatNote.Period = Note2Period[l] then PatNote.Note := l+StartNoteBias;
            Assert(PatNote.Note <> 0, 'Invalid period: ' + IntTosTr(PatNote.Period));
            Channels[k].Period := PatNote.Period;
          end else PatNote.Note := Channels[k].Note;
        end else if PatType = ptXM then begin

          PatNote := XMPatterns[PatternOrder^[i]].Data^[j*TotalChannels+k];
          PatNote.Note := MinI(96, MaxI(0, PatNote.Note-1-12));
          if (PatNote.Note > 0) then begin
//            PatNote.Period := Pitch2Period((PatNote.Note-1) * FinetuneLevels);
            PatNote.Period := Note2Period[MinI(59, MaxI(0, PatNote.Note))];
//            PatNote.Period := 10*12*16*4 - (PatNote.Note+24) * 16*4;
          end else PatNote.Period := 0;
          if PatNote.Period <> 0 then begin
  //          PatNote.Note := Period2Pitch(PatNote.Period) div FinetuneLevels - 0*StartNoteBias;
            Assert(PatNote.Note <> 0, 'Invalid period: ' + IntTosTr(PatNote.Period));
            Channels[k].Period := PatNote.Period;
          end else PatNote.Note := Channels[k].Note;
        end;
        Effect := GetEffect(PatNote);

        NewInstr := False;
        if PatNote.Instr <> 0 then if Channels[k].Instr <> PatNote.Instr then begin
          Channels[k].Instr := PatNote.Instr;
          NewInstr := True;
        end;

        Channels[k].Note := PatNote.Note;

        if Channels[k].Note <> 0 then begin
          if (PatNote.Instr <> 0) and (Channels[k].Volume <> Player.Instruments.Items[InstrIndex[Channels[k].Instr-1]].Volume) then begin
            Channels[k].Volume := Player.Instruments.Items[InstrIndex^[Channels[k].Instr-1]].Volume;
            Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                 scVolume, Channels[k].Volume, 0);
          end;

          if ((PatNote.Period <> 0) or (PatNote.Instr <> 0)) and (Channels[k].Instr <> 0) and (Effect <> $3) and (Effect <> $5) then begin
            Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                 scNoteGo, MinI((TotalOctaves + ExtOctaves)*12-1, Channels[k].Note) shl 8 + InstrIndex[Channels[k].Instr-1], 0);
            if PatNote.Period <> 0 then Channels[k].CurrentPeriod := PatNote.Period;
            Pitch := MaxI(0, MinI((TotalOctaves + ExtOctaves)*12*FinetuneLevels-1, Channels[k].Note * FinetuneLevels));
            Channels[k].Pitch := Pitch;
          end;
        end;

{   Period, CurrentPeriod, Pitch, Note,
    LastPorta, LastTonePorta, LastTremolo, LastSampleOffset,
    LoopBegin, LoopCounter,
    VibratoType, VibratoPos, TremoloType, TremoloPos, Glissando,
    SeqNum, Instr, Volume: Integer; }

        if (PatNote.Volume > $10) and (PatNote.Volume <= $50) then begin
          Channels[k].Volume := MinI(255, (PatNote.Volume-$10)*4);
          Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                               scVolume, Channels[k].Volume, 0);
        end;

        case Effect of
          $0: begin
            for l := 1 to Speed-1 do case l mod 3 of
              0: Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                      scPitch, Channels[k].Pitch, 0);
              1: Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                      scPitch, MaxI(0, MinI( Channels[k].Pitch + FinetuneLevels*((PatNote.Arg and $F0) shr 4), (TotalOctaves + ExtOctaves)*12*FinetuneLevels-1)), 0);
              2: Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                      scPitch, MaxI(0, MinI( Channels[k].Pitch + FinetuneLevels*(PatNote.Arg and $F), (TotalOctaves + ExtOctaves)*12*FinetuneLevels-1)), 0);
            end;
            Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*Speed) / (2*Tempo * Integer(Player.TimeQuantum))),
                                 scPitch, Channels[k].Pitch, 0);
          end;
          $1, $2: begin
            if PatNote.Arg = 0 then PatNote.Arg := Channels[k].LastPorta;
            if Effect and $0F = $1 then PitchSign := -1 else PitchSign := 1;
            for l := 1 to Speed-1 do begin
              Channels[k].CurrentPeriod := MaxI(1, Channels[k].CurrentPeriod + PitchSign * (PatNote.Arg));
              Channels[k].Pitch := MaxI(0, MinI(Period2Pitch(Channels[k].CurrentPeriod), (TotalOctaves + ExtOctaves)*12*FinetuneLevels-1));
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scPitch, Channels[k].Pitch, 0);
            end;
            Channels[k].LastPorta := PatNote.Arg;
          end;
          $3: begin
            if PatNote.Arg = 0 then PatNote.Arg := Channels[k].LastTonePorta;
            if PatNote.Period = 0 then PatNote.Period := Channels[k].Period;
            if Channels[k].CurrentPeriod < PatNote.Period then PitchSign := 1 else PitchSign := -1;
            if NewInstr and (Channels[k].Pitch <> -1) then begin
              Channels[k].Note := Channels[k].Pitch div FinetuneLevels;
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scNoteGo, MinI((TotalOctaves + ExtOctaves)*12-1, Channels[k].Note) shl 8 + InstrIndex[Channels[k].Instr-1], 0);
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scPitch, Channels[k].Pitch, 0);
            end;
            l := 1;
            while (l < Speed) and (Channels[k].CurrentPeriod <> PatNote.Period) do begin
              Channels[k].CurrentPeriod := Channels[k].CurrentPeriod + PitchSign * (PatNote.Arg);
              if (PitchSign =  1) and (Channels[k].CurrentPeriod > PatNote.Period) or
                 (PitchSign = -1) and (Channels[k].CurrentPeriod < PatNote.Period) then Channels[k].CurrentPeriod := PatNote.Period;
              Channels[k].Pitch := MaxI(0, MinI(Period2Pitch(Channels[k].CurrentPeriod), (TotalOctaves + ExtOctaves)*12*FinetuneLevels-1));
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scPitch, Channels[k].Pitch, 0);
              Inc(l);
            end;
            Channels[k].LastTonePorta := PatNote.Arg;
          end;
          $4: begin
            if PatNote.Arg and $0F = 0 then PatNote.Arg := PatNote.Arg or (Channels[k].LastVibrato and $0F);
            if PatNote.Arg and $F0 = 0 then PatNote.Arg := PatNote.Arg or (Channels[k].LastVibrato and $F0);
            if Channels[k].VibratoType and wfNoRetrig = 0 then Channels[k].VibratoPos := 0;
            for l := 0 to Speed-1 do begin
              PatNote.Period := MaxI(1, Channels[k].CurrentPeriod + (VibratoSine[Channels[k].VibratoPos] * (PatNote.Arg and $0F)) div 128);
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scPitch, MaxI(0, MinI(Period2Pitch(PatNote.Period), (TotalOctaves + ExtOctaves)*12*FinetuneLevels-1)), 0);
              Channels[k].VibratoPos := (Channels[k].VibratoPos + (PatNote.Arg and $F0) shr 4) and 63;
            end;
            Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*Speed) / (2*Tempo * Integer(Player.TimeQuantum))),
                                  scPitch, Channels[k].Pitch, 0);
            Channels[k].LastVibrato := PatNote.Arg;
          end;
          $5: begin
            if PatNote.Period = 0 then PatNote.Period := Channels[k].Period;
            if Channels[k].CurrentPeriod < PatNote.Period then PitchSign := 1 else PitchSign := -1;

            if NewInstr and (Channels[k].Pitch <> -1) then begin
              Channels[k].Note := Channels[k].Pitch div FinetuneLevels;
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scNoteGo, MinI((TotalOctaves + ExtOctaves)*12-1, Channels[k].Note) shl 8 + InstrIndex[Channels[k].Instr-1], 0);
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scPitch, Channels[k].Pitch, 0);
            end;

            if PatNote.Arg = 0 then PatNote.Arg := Channels[k].LastVolSlide;
            if (PatNote.Arg and $0F > 0) then
             VolSlide := -VolK * (PatNote.Arg and $0F) else
              VolSlide := VolK * ((PatNote.Arg and $F0) shr 4);

            l := 1;
            while (l < Speed) and (Channels[k].CurrentPeriod <> PatNote.Period) do begin
              Channels[k].CurrentPeriod := Channels[k].CurrentPeriod + PitchSign * Channels[k].LastTonePorta;
              if (PitchSign =  1) and (Channels[k].CurrentPeriod > PatNote.Period) or
                 (PitchSign = -1) and (Channels[k].CurrentPeriod < PatNote.Period) then Channels[k].CurrentPeriod := PatNote.Period;
              Channels[k].Pitch := MaxI(0, MinI(Period2Pitch(Channels[k].CurrentPeriod), (TotalOctaves + ExtOctaves)*12*FinetuneLevels-1));
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scPitch, Channels[k].Pitch, 0);

              Channels[k].Volume := MaxI(0, MinI(255, Channels[k].Volume + VolSlide));
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scVolume, Channels[k].Volume, 0);
              Inc(l);
            end;
            Channels[k].LastVolSlide := PatNote.Arg;
          end;
          $6: begin
            if Channels[k].VibratoType and wfNoRetrig = 0 then Channels[k].VibratoPos := 0;

            if PatNote.Arg = 0 then PatNote.Arg := Channels[k].LastVolSlide;
            if (PatNote.Arg and $0F > 0) then
             VolSlide := -VolK * (PatNote.Arg and $0F) else
              VolSlide := VolK * ((PatNote.Arg and $F0) shr 4);

            for l := 0 to Speed-1 do begin
              PatNote.Period := MaxI(1, Channels[k].CurrentPeriod + (VibratoSine[Channels[k].VibratoPos] * (PatNote.Arg and $0F)) div 128);
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scPitch, MaxI(0, MinI(Period2Pitch(PatNote.Period), (TotalOctaves + ExtOctaves)*12*FinetuneLevels-1)), 0);
              Channels[k].VibratoPos := (Channels[k].VibratoPos + (PatNote.Arg and $F0) shr 4) and 63;

              if l > 0 then begin
                Channels[k].Volume := MaxI(0, MinI(255, Channels[k].Volume + VolSlide));
                Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                     scVolume, Channels[k].Volume, 0);
              end;
            end;
            Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*Speed) / (2*Tempo * Integer(Player.TimeQuantum))),
                                  scPitch, Channels[k].Pitch, 0);
            Channels[k].LastVolSlide := PatNote.Arg;
          end;
          $7: begin
            if PatNote.Arg and $0F = 0 then PatNote.Arg := PatNote.Arg or (Channels[k].LastTremolo and $0F);
            if PatNote.Arg and $F0 = 0 then PatNote.Arg := PatNote.Arg or (Channels[k].LastTremolo and $F0);
            if Channels[k].TremoloType and wfNoRetrig = 0 then Channels[k].TremoloPos := 0;

            for l := 0 to Speed-1 do begin
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scVolume, MaxI(0, MinI(255, Channels[k].Volume + VibratoSine[Channels[k].TremoloPos] * (PatNote.Arg and $0F) div 128)), 0);
              Channels[k].TremoloPos := (Channels[k].TremoloPos + (PatNote.Arg and $F0) shr 4) and 63;
            end;
            Channels[k].LastTremolo := PatNote.Arg;

            Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*Speed) / (2*Tempo * Integer(Player.TimeQuantum))),
                                  scVolume, Channels[k].Volume, 0);
          end;
          $8: Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scPan, PatNote.Arg-128, 0);
          $9: Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scSamplePos, PatNote.Arg, 0);
          $A: begin
            if PatNote.Arg = 0 then PatNote.Arg := Channels[k].LastVolSlide;
            if (PatNote.Arg and $0F > 0) then
             VolSlide := -VolK * (PatNote.Arg and $0F) else
              VolSlide := VolK * ((PatNote.Arg and $F0) shr 4);
            for l := 1 to Speed-1 do begin
              Channels[k].Volume := MaxI(0, MinI(255, Channels[k].Volume + VolSlide));
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scVolume, Channels[k].Volume, 0);
            end;
            Channels[k].LastVolSlide := PatNote.Arg;
          end;
          $B: JumpTo := PatNote.Arg;
          $C: begin
            Channels[k].Volume := MinI(255, PatNote.Arg*4);
            Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                 scVolume, Channels[k].Volume, 0);
          end;
          $D: BreakTo := PatNote.Arg;
          $E: case PatNote.Arg and $F0 of
            $10, $20: begin
              if PatNote.Arg and $F0 = $10 then PitchSign := -1 else PitchSign := 1;
              Channels[k].CurrentPeriod := Channels[k].CurrentPeriod + PitchSign * (PatNote.Arg and $0F);
              Channels[k].Pitch := MaxI(0, MinI(Period2Pitch(Channels[k].CurrentPeriod), (TotalOctaves + ExtOctaves)*12*FinetuneLevels-1));
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scPitch, Channels[k].Pitch, 0);
            end;
            $30: Channels[k].Glissando := PatNote.Arg and $0F <> 0;
            $40: Channels[k].VibratoType := PatNote.Arg and $0F;
            $50: begin
              if PatNote.Arg and $0F <= 7 then Tmp := PatNote.Arg and $0F else Tmp := PatNote.Arg and $0F - 16;
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scFineTune, Tmp * FinetuneLevels div 8, 0);
            end;
            $60: begin
              if PatNote.Arg and $0F = 0 then begin
                Channels[k].LoopBegin := j;
                Channels[k].LoopCounter := -1;
              end else if Channels[k].LoopBegin <> -1 then begin
                if Channels[k].LoopCounter = 0 then Channels[k].LoopBegin := -1 else begin
                  if Channels[k].LoopCounter = -1 then
                   Channels[k].LoopCounter := PatNote.Arg and $0F else
                    Dec(Channels[k].LoopCounter);
                  JumpTo := Channels[k].LoopBegin;
                end
              end;
            end;
            $70: Channels[k].TremoloType := PatNote.Arg and $0F;
            $80: Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                      scPan, Trunc(0.5 + ((PatNote.Arg and $0F)/15)*255 - 128), 0);
            $90: for l := 1 to Speed-1 do if l mod (PatNote.Arg and $0F) = 0 then
             Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*l) / (2*Tempo * Integer(Player.TimeQuantum))),
                                  scSamplePos, 0, 0);
            $A0, $B0: begin
              if PatNote.Arg and $0F = 0 then PatNote.Arg := PatNote.Arg and $F0 or Channels[k].LastFineVolSlide;
              if PatNote.Arg and $F0 = $A0 then VolSlide := VolK else VolSlide := -VolK;
              Channels[k].Volume := MaxI(0, MinI(255, Channels[k].Volume + VolSlide * (PatNote.Arg and $0F)));
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scVolume, Channels[k].Volume, 0);
              Channels[k].LastFineVolSlide := PatNote.Arg and $0F;
            end;
            $C0: Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*(PatNote.Arg and $0F)) / (2*Tempo * Integer(Player.TimeQuantum))),
                                      scNoteStop, 0, 0);
            $D0: begin
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep),
                                   scNoteStop, 0, 0);
              Player.AddToSequence(Player.Sequences[Channels[k].SeqNum], Trunc(0.5 + CurStep + (5*1000*(PatNote.Arg and $0F)) / (2*Tempo * Integer(Player.TimeQuantum))),
                                   scSamplePos, 0, 0);
            end;
          end;
          $F: if PatNote.Arg >= $20 then Tempo := PatNote.Arg else Speed := PatNote.Arg;

//          else Player.Audio.Log(Format('Unknown effect: %X(%X), step: %D', [PatNote.InstrEffect and $0F, PatNote.Arg, Trunc(0.5 + CurStep)]));

        end;
      end;
      Inc(j);
      CurStep := CurStep + (5*1000*Speed) / (2*Tempo * Integer(Player.TimeQuantum));
//      CurStep := CurStep + 1/(Tempo*2/5/Speed/1000*Player.TimeQuantum);
      if JumpTo <> -1 then begin
//        i := JumpTo;
        JumpTo := -1;
        Break;
      end;
      if BreakTo <> -1 then Break;
    end;
    Inc(i);
  end;
end;

function LoadMOD(const FileName: string; Player: TPlayer; Filter: Cardinal): Boolean;
var
  i, j: Integer;
  Stream: TDStream;

  SongName: array[1..20] of Char;
  SongLen, Res: Byte;
  PatternOrder: array[0..127] of Byte;
  Signature: array[0..3] of Char;

  TotalSamples, TotalChannels: Integer;

  InstrIndex: array[0..30] of Word;

  Samples: array of packed record
    Name: array[1..22] of Char;
    Len: Word;
    FineTune: Shortint;
    Volume: Byte;
    LoopOffs, LoopLen: Word;
  end;
  LoopKind: Integer;

  Data: ^TByteBuffer;

  Patterns: ^TMODPattern; TotalPatterns: Integer;

  SampleIndex: Integer;

begin
  Result := False;
  Stream := TFileDStream.Create(FileName);
  try
    Stream.Read(SongName[1], SizeOf(SongName));

    Stream.Seek(1080);
    Stream.Read(Signature, SizeOf(Signature));
    if (Signature[0] in [#32..#127]) and (Signature[1] in [#32..#127]) and
       (Signature[2] in [#32..#127]) and (Signature[3] in [#32..#127]) then TotalSamples := 31 else TotalSamples := 15;
    Stream.Seek(20);

    SetLength(Samples, TotalSamples);

    for i := 0 to TotalSamples-1 do with Samples[i] do begin
      Stream.Read(Name[1], SizeOf(Name));
      Stream.Read(Len, SizeOf(Len));
      Stream.Read(FineTune, SizeOf(FineTune));
      FineTune := ShortInt(Finetune * 16);
      Stream.Read(Volume, SizeOf(Volume));
      Stream.Read(LoopOffs, SizeOf(LoopOffs));
      Stream.Read(LoopLen, SizeOf(LoopLen));
    end;

    Stream.Read(SongLen, SizeOf(SongLen));
    Stream.Read(Res, SizeOf(Res));
    Stream.Read(PatternOrder, SizeOf(PatternOrder));

    TotalChannels := 4;
    if TotalSamples = 31 then begin
      Stream.Read(Signature, SizeOf(Signature));
      if Copy(Signature, 1, 3) = 'FLT' then TotalChannels := StrToIntDef(Signature[3], 4) else
       if Copy(Signature, 2, 3) = 'CHN' then TotalChannels := StrToIntDef(Signature[0], 4) else
        if Copy(Signature, 3, 3) = 'CH' then TotalChannels := StrToIntDef(Copy(Signature, 1, 2), 4);
    end;

    TotalPatterns := 0;
    for i := 0 to 127 do begin
      if PatternOrder[i]+1 > TotalPatterns then TotalPatterns := PatternOrder[i]+1;
    end;

    GetMem(Patterns, TotalChannels*TotalPatterns*SizeOf(TMODNoteData)*64);
    Stream.Read(Patterns^, TotalChannels*TotalPatterns*SizeOf(TMODNoteData)*64);   //17468

    for i := 0 to TotalSamples-1 do with Samples[i] do begin         // 5422
      Len := MaxI(0, SwapBytes(Len)*2-2);                            // Skip first two bytes (???)
      if Len > 0 then begin
        GetMem(Data, Len);

        Stream.Read(Data^, 2);
        Stream.Read(Data^, Len);

        if SwapBytes(Samples[i].LoopLen) > 1 then LoopKind := lkForward else LoopKind := lkNone;
        SampleIndex := Player.AddSampleEx(Trim(SongName) + SubSeparator + AsciiZToStr(Samples[i].Name, 'noname', 22),
                                          PackSoundFormat(8363, 8, 1), Data, Len, Samples[i].FineTune, BaseOctave*12, LoopKind, MaxI(0, SwapBytes(Samples[i].LoopOffs)*2-2), MaxI(0, SwapBytes(Samples[i].LoopOffs)*2-2) + SwapBytes(Samples[i].LoopLen)*2-1, True);
        InstrIndex[i] := Player.Instruments.AddForced(Trim(SongName) + SubSeparator + AsciiZToStr(Samples[i].Name, 'noname', 22));
        Player.Instruments.Items[InstrIndex[i]].Volume := MaxI(0, Integer(Samples[i].Volume)*4-1);
        for j := 0 to TotalNotes-1 do Player.Instruments.Items[InstrIndex[i]].Samples[j] := SampleIndex;
        FreeMem(Data);
      end;
    end;

    ConvertPatterns(Player, Patterns, ptMOD, @PatternOrder, @InstrIndex, TotalChannels, SongLen);

    SetLength(Samples, 0);
  finally
    Stream.Free;
  end;

  Result := True;
end;

function LoadXMInstrument(Stream: TDStream; Player: TPlayer; BaseName: string; var Instrument: TXMInstrument; XI: Boolean): Integer;
var
  j, k, Value, LoopKind: Integer;
  StartSample, SampleIndex, SamplePos, NextSamplePos: Integer;
  SamHeaderSize: Cardinal;
  TmpData16, Data16: ^TWordBuffer;
begin
  Result := -1;

  if not XI then with Instrument do begin
    Stream.Read(Size, SizeOf(Size));
    SamplePos := Stream.Position + Size - SizeOf(Size);
    Stream.Read(Name[1], SizeOf(Name));
    Stream.Read(InstrumentType, SizeOf(InstrumentType));
    Stream.Read(TotalSamples, SizeOf(TotalSamples));
    if TotalSamples = 0 then begin
      Stream.Seek(SamplePos);
      Exit;
    end;
    Stream.Read(SamHeaderSize, SizeOf(SamHeaderSize));
    Stream.Read(Header2, SizeOf(Header2));

    Stream.Seek(SamplePos);
  end else begin
    Stream.Read(Instrument.Header2, SizeOf(Instrument.Header2));
    Stream.Read(Instrument.Header2.Reserved, 11);
    Stream.Read(Instrument.TotalSamples, SizeOf(Instrument.TotalSamples));
  end;  

// Sample
  StartSample := Player.TotalSamples;
  with Instrument do begin
    SetLength(Samples,  TotalSamples);
    for j := 0 to TotalSamples-1 do begin
      NextSamplePos := Stream.Position + SamHeaderSize;
      Stream.Read(Instrument.Samples[j], SizeOf(Samples[j]) - SizeOf(Samples[j].SamData));
      if not XI then Stream.Seek(NextSamplePos);
    end;
    for j := 0 to TotalSamples-1 do with Samples[j] do begin
      if SamLength > 0 then begin
        GetMem(SamData, SamLength);

        Stream.Read(SamData^, SamLength);
{$R-}
        if SamType and 16 = 0 then begin                   // 8 bit sample
          Value := 0;
          for k := 0 to SamLength-1 do begin
            TByteBuffer(SamData^)[k] := Value + ShortInt(TByteBuffer(SamData^)[k]);
            Value := ShortInt(TByteBuffer(SamData^)[k]);
          end;
          LoopKind := SamType and 3;
          if SamLoopLength = 0 then LoopKind := lkNone;
          SampleIndex := Player.AddSampleEx(BaseName + SubSeparator + AsciiZToStr(SamName, 'noname', 22),
                                            PackSoundFormat(8363, 8, 1), SamData, SamLength, SamFineTune, BaseOctave*12, LoopKind, SamLoopStart, Integer(SamLoopStart + SamLoopLength)-1, True);
        end else begin                                     // 16 bit sample
{$R-}        
          Value := 0;
          for k := 0 to SamLength div 2-1 do begin
            TWordBuffer(SamData^)[k] := Value + SmallInt(TWordBuffer(SamData^)[k]);
            Value := TWordBuffer(SamData^)[k];
          end;
          LoopKind := SamType and 3;
          if SamLoopLength = 0 then LoopKind := lkNone;
          SampleIndex := Player.AddSampleEx(BaseName + SubSeparator + AsciiZToStr(SamName, 'noname', 22),
                                            PackSoundFormat(8363, 16, 1), SamData, SamLength, SamFineTune, BaseOctave*12, LoopKind, SamLoopStart div 2, (SamLoopStart + SamLoopLength - 1) div 2, True);
        end;

        if SampleIndex <> -1 then begin
          Player.Samples[SampleIndex].FineTune := SamRelNote * FinetuneLevels + SamFineTune;
        end;
        if SamLength > 0 then FreeMem(SamData);
      end;
    end;

    Result := Player.Instruments.AddForced(BaseName + SubSeparator + AsciiZToStr(Name, 'noname', 22));
    with Header2 do if TotalSamples > 0 then begin
      for j := 0 to TotalNotes-1 do Player.Instruments.Items[Result].Samples[j] := StartSample + SampleNumbers[MinI(96, j+StartNoteBias)];

      Player.Instruments.Items[Result].Fadeout := VolFadeOut;

      Player.Instruments.Items[Result].VolEnvType      := VolumeType;
      Player.Instruments.Items[Result].VolSustainPoint := VolSustainPoint;
      Player.Instruments.Items[Result].VolEnvLoopStart := VolLoopStartPoint;
      Player.Instruments.Items[Result].VolEnvLoopEnd   := VolLoopEndPoint;
      Player.Instruments.Items[Result].VolEnvPoints    := TotalVolPoints;
      SetLength(Player.Instruments.Items[Result].VolEnvelope, TotalVolPoints);
      for j := 0 to TotalVolPoints-1 do begin
        Player.Instruments.Items[Result].VolEnvelope[j].Pos   := VolEnv[j].Pos;
        Player.Instruments.Items[Result].VolEnvelope[j].Value := MinI(255, VolEnv[j].Value*4);
      end;

      Player.Instruments.Items[Result].PanEnvType      := PanType;
      Player.Instruments.Items[Result].PanSustainPoint := PanSustainPoint;
      Player.Instruments.Items[Result].PanEnvLoopStart := PanLoopStartPoint;
      Player.Instruments.Items[Result].PanEnvLoopEnd   := PanLoopEndPoint;
      Player.Instruments.Items[Result].PanEnvPoints    := TotalPanPoints;
      SetLength(Player.Instruments.Items[Result].PanEnvelope, TotalPanPoints);
      for j := 0 to TotalPanPoints-1 do begin
        Player.Instruments.Items[Result].PanEnvelope[j].Pos   := PanEnv[j].Pos;
        Player.Instruments.Items[Result].PanEnvelope[j].Value := MinI(255, PanEnv[j].Value*4);
      end;
    end;
  end;
end;

function LoadXI(const FileName: string; Player: TPlayer; Filter: Cardinal): Boolean;
//316
const
  StartNoteBias = 12;
var
  TrackerName: array[1..20] of Char;
  Stream: TDStream;
  c: Byte;
  Version: Word;

  Instrument: TXMInstrument;
begin
  Result := False;
  Stream := TFileDStream.Create(FileName);

  Stream.Read(Instrument.Name, 21);
  if Copy(Instrument.Name, 1, 21) <> 'Extended Instrument: ' then Exit;
  Stream.Read(Instrument.Name, SizeOf(Instrument.Name));
  Stream.Read(c, SizeOf(c)); if c <> $1A then Exit;
  Stream.Read(TrackerName, SizeOf(TrackerName));
  Stream.Read(Version, SizeOf(Version));
  LoadXMInstrument(Stream, Player, Trim(Instrument.Name), Instrument, True);

  Stream.Free;
end;

function LoadXM(const FileName: string; Player: TPlayer; Filter: Cardinal): Boolean;
type
  TModuleHeader = packed record
    HeaderSize: Cardinal;
    SongLen, RestartPos, TotalChannels, TotalPatterns, TotalInstruments, Flags, DefaultTempo, DefaultBPM: Word;
  end;
var
  i, j, k: Integer;
  Stream: TDStream;
  SongName, TrackerName: array[1..20] of Char;
  c: Byte;
  Version: Word;

  ModuleHeader: TModuleHeader;

  InstrIndex: array[0..255] of Word;
  PatternOrder: array[0..255] of Byte;

  Instruments: array of TXMInstrument;

  StreamPos, DataPos: Cardinal;

  Patterns: TPatterns;
  RawPat: PByteBuffer;
  b: Byte;

function GetNextByte: Byte;
begin
  Result := 0;
  if DataPos >= Patterns[i].Datasize then Exit;
  Result := RawPat^[DataPos];
  Inc(DataPos);
end;

begin
  Result := False;
  Stream := TFileDStream.Create(FileName);

  Stream.Read(SongName, 17);
  if Copy(SongName, 1, 17) <> 'Extended Module: ' then Exit;
  Stream.Read(SongName, SizeOf(SongName));
  Stream.Read(c, SizeOf(c)); if c <> $1A then Exit;
  Stream.Read(TrackerName, SizeOf(TrackerName));
  Stream.Read(Version, SizeOf(Version));

  Stream.Read(ModuleHeader, SizeOf(ModuleHeader));

  Stream.Read(PatternOrder, SizeOf(PatternOrder));

  SetLength(Patterns, ModuleHeader.TotalPatterns);
  GetMem(RawPat,ModuleHeader.TotalChannels * 5 * 256);
  for i := 0 to ModuleHeader.TotalPatterns-1 do begin
    StreamPos := Stream.Position;
    Stream.Read(Patterns[i], SizeOf(Patterns[i]) - SizeOf(Patterns[i].Data));
    Stream.Seek(StreamPos + Patterns[i].HeaderLength);
    Stream.Read(RawPat^, Patterns[i].Datasize);
    DataPos := 0;
    GetMem(Patterns[i].Data, Patterns[i].TotalRows * ModuleHeader.TotalChannels * SizeOf(TNoteData));
    if Patterns[i].DataSize > 0 then for j := 0 to Patterns[i].TotalRows-1 do for k := 0 to ModuleHeader.TotalChannels-1 do begin
      b := GetNextByte;
      if b and $80 = 0 then begin
        Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Note   := b and $7F;
//          if (Patterns[i]^[j].Period = 97) then Patterns[i]^[j].Period := mdkeyoff
//          else if (Patterns[i]^[j].Period > 96) then Patterns[i]^[j].Period := 96;
        Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Instr  := GetNextByte;
        Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Volume := GetNextByte - $10;
        Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Effect := GetNextByte;
        Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Arg    := GetNextByte;
      end else begin
        FillChar(Patterns[i].Data^[j * ModuleHeader.TotalChannels + k], SizeOf(Patterns[i].Data^[j * ModuleHeader.TotalChannels + k]), 0);
        { Packed note       }
        if (b and $01 <> 0) then begin
          Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Note := GetNextByte;
{            if (patt.per = 97) then patt.per := mdkeyoff else if (patt.per > 96) then patt.per := 96;}
        end;
        { Packed instrument }
        if (b and $02 <> 0) then Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Instr  := GetNextByte;
        { Packed volume     }
        if (b and $04 <> 0) then Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Volume := GetNextByte;
        { Packed command    }
        if (b and $08 <> 0) then Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Effect := GetNextByte;
        { Packed argument   }
        if (b and $10 <> 0) then Patterns[i].Data^[j * ModuleHeader.TotalChannels + k].Arg    := GetNextByte;
      end;
    end;
  end;
  FreeMem(RawPat);

  SetLength(Instruments, ModuleHeader.TotalInstruments);
  for i := 0 to ModuleHeader.TotalInstruments-1 do
   InstrIndex[i] := LoadXMInstrument(Stream, Player, ExtractFileName(FileName), Instruments[i], False);

  ConvertPatterns(Player, Patterns, ptXM, @PatternOrder, @InstrIndex, ModuleHeader.TotalChannels, ModuleHeader.SongLen);

  for i := 0 to ModuleHeader.TotalInstruments-1 do begin
//    for j := 0 to Instruments[i].TotalSamples-1 do FreeMem(Instruments[i].Samples[j].SamData);
    SetLength(Instruments[i].Samples, 0);
  end;
  SetLength(Instruments, 0);

  for i := 0 to ModuleHeader.TotalPatterns-1 do FreeMem(Patterns[i].Data);
  SetLength(Patterns, 0);

  Stream.Free;
  Result := True;
end;

end.
