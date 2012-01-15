const
  cfeFileNotFound = 1; cfeFileCorrupt = 2;

type
  CFFace = array of record
    V, N, T: Word;
  end;

var
  FData: array of array[0..2] of record
    V, N, T, M: Integer;
  end;
//  VertexData: array of Single;
  VData, NData, TData: array of TVector3s;
  MData: array of record
    Name: string[40];
    Diffuse, Specular: TVector3s;
  end;

function PosEx(const substr : AnsiString; const s : AnsiString; const start: Integer ) : Integer ;
Type StrRec = record
       allocSiz: Longint;
       refCnt: Longint;
       length: Longint;
     end;
Const skew = sizeof(StrRec);
asm
{     ->EAX     Pointer to substr               }
{       EDX     Pointer to string               }
{       ECX     Pointer to start      //cs      }
{     <-EAX     Position of substr in s or 0    }

        TEST    EAX,EAX
        JE      @@noWork
        TEST    EDX,EDX
        JE      @@stringEmpty
        TEST    ECX,ECX           //cs
        JE      @@stringEmpty     //cs

        PUSH    EBX
        PUSH    ESI
        PUSH    EDI

        MOV     ESI,EAX                         { Point ESI to  }
        MOV     EDI,EDX                         { Point EDI to  }

        MOV     EBX,ECX        //cs save start
        MOV     ECX,[EDI-skew].StrRec.length    { ECX =    }
        PUSH    EDI                             { remember s position to calculate index }

        CMP     EBX,ECX        //cs
        JG      @@fail         //cs

        MOV     EDX,[ESI-skew].StrRec.length    { EDX = bstr)          }

        DEC     EDX                             { EDX = Length(substr) -   }
        JS      @@fail                          { < 0 ? return             }
        MOV     AL,[ESI]                        { AL = first char of       }
        INC     ESI                             { Point ESI to 2'nd char of substr }
        SUB     ECX,EDX                         { #positions in s to look  }
                                                { = Length(s) - Length(substr) + 1      }
        JLE     @@fail
        DEC     EBX       //cs
        SUB     ECX,EBX   //cs
        JLE     @@fail    //cs
        ADD     EDI,EBX   //cs

@@loop:
        REPNE   SCASB
        JNE     @@fail
        MOV     EBX,ECX                         { save outer loop                }
        PUSH    ESI                             { save outer loop substr pointer }
        PUSH    EDI                             { save outer loop s              }

        MOV     ECX,EDX
        REPE    CMPSB
        POP     EDI                             { restore outer loop s pointer      }
        POP     ESI                             { restore outer loop substr pointer }
        JE      @@found
        MOV     ECX,EBX                         { restore outer loop nter    }
        JMP     @@loop

@@fail:
        POP     EDX                             { get rid of saved s nter    }
        XOR     EAX,EAX
        JMP     @@exit

@@stringEmpty:
        XOR     EAX,EAX
        JMP     @@noWork

@@found:
        POP     EDX                             { restore pointer to first char of s    }
        MOV     EAX,EDI                         { EDI points of char after match        }
        SUB     EAX,EDX                         { the difference is the correct index   }
@@exit:
        POP     EDI
        POP     ESI
        POP     EBX
@@noWork:
end;

function GetCoords(S : string) : TVector3s;
var P, P2 : Integer;
begin
  S := Trim(Copy(S, 3, Length(S)));
  P := Pos(' ', S); P2 := PosEx(' ', S, P+1);
  S := StringReplace(S, '.', DecimalSeparator, [rfReplaceAll]);

  Result.X := StrToFloat(Copy(S, 1, P-1));
  if P2 = 0 then begin
    Result.Y := StrToFloat(Copy(S, P+1, Length(S)));
    Result.Z := 0;
  end else begin
    Result.Y := StrToFloat(Copy(S, P+1, P2-P-1));
    Result.Z := StrToFloat(Copy(S, P2+1, Length(S)));
  end;  
end;

procedure LoadMaterials(S: string);
var MF: TextFile; FileDir: TFileName;
begin
  FileDir := ExtractFileDir(Filename);
  if (FileDir <> '') and (FileDir[Length(FileDir)] <> '\') then FileDir := FileDir + '\';
  S2 := FileDir + Copy(Trim(S), Pos(' ', S)+1, Length(S));
  if not FileExists(S2) then Exit;
  AssignFile(MF, S2); Reset(MF);
  while not EOF(MF) do begin
    Readln(MF, S2); S2 := Trim(S2); S2 := Uppercase(S2);
    if Copy(S2, 1, 6) = 'NEWMTL' then begin
      Inc(MCount); SetLength(MData, MCount);
      MData[MCount-1].Name := Copy(S2, Pos(' ', S2)+1, Length(S2));
      if MData[MCount-1].Name = 'DEFAULT' then CurMaterial := MCount - 1;
    end;
    if Copy(S2, 1, 6) = 'MAP_KD' then TextureFileName := FileDir + Copy(S2, Pos(' ', S2)+1, Length(S2));
    if Copy(S2, 1, 2) = 'KD' then MData[MCount-1].Diffuse := GetCoords(S2);
    if Copy(S2, 1, 2) = 'KS' then MData[MCount-1].Specular := GetCoords(S2);
  end;
  CloseFile(MF);
end;

procedure ReadVertexData(S : string);
var C : TVector3s; T: Single;
begin
  case S[2] of
    ' ': begin
      C := GetCoords(S);
      case ScalingMode of
        smScale: C := ScaleVector3s(C, Scale);
        smNormalize: begin
          if MinVector.X > C.X then MinVector.X := C.X;
          if MinVector.Y > C.Y then MinVector.Y := C.Y;
          if MinVector.Z > C.Z then MinVector.Z := C.Z;
          if MaxVector.X < C.X then MaxVector.X := C.X;
          if MaxVector.Y < C.Y then MaxVector.Y := C.Y;
          if MaxVector.Z < C.Z then MaxVector.Z := C.Z;
        end;
      end;  

      if FromMax then begin                    // 3DS MAX's coordinate system
        T := C.Z;
        C.Z := -C.Y;
        C.Y := T;
        C.X := -C.X;
      end;
      Inc(VCount); SetLength(VData, VCount);
      VData[VCount-1] := C;
      if Actor <> nil then with Actor.BoundingBox do begin
        if VCount = 1 then begin
          P1.X := C.X; P1.Y := C.Y; P1.Z := C.Z;
          P2.X := C.X; P2.Y := C.Y; P2.Z := C.Z;
        end else begin
          if C.X < P1.X then P1.X := C.X; if C.Y < P1.Y then P1.Y := C.Y; if C.Z < P1.Z then P1.Z := C.Z;
          if C.X > P2.X then P2.X := C.X; if C.Y > P2.Y then P2.Y := C.Y; if C.Z > P2.Z then P2.Z := C.Z;
        end;
      end;
    end;
    'N': if VertexFormat and 2 = 2 then begin
      C := GetCoords(S);
      if FromMax then begin                    // 3DS MAX's coordinate system
        T := C.Z;
        C.Z := -C.Y;
        C.Y := T;
        C.X := -C.X;
      end;
      Inc(NCount); SetLength(NData, NCount);
      NData[NCount-1] := C;
    end;
    'T': begin
      C := GetCoords(S);
      Inc(TCount); SetLength(TData, TCount);
      TData[TCount-1] := C;
//      if FromMax then
      TData[TCount-1].Y := 1-TData[TCount-1].Y;
    end;
  end;
end;

procedure ReadFaceData(S : string);
var P, P3 : Integer; F : CFFace; FVCount: Word; I1, I2: Integer;
begin
  P := Pos(' ', S); S := Trim(Copy(S, P+1, Length(S)));
  Inc(FCount); SetLength(FData, FCount);
  FVCount := 0;                  //   f 22 3/4 12/33/44 33//66 77/22/
  while (Length(S) > 0) do begin
    Inc(FVCount); SetLength(F, FVCount);
    F[FVCount-1].N := 0; F[FVCount-1].T := 0;
    P3 := Pos(' ', S);
    if P3 = 0 then P3 := Length(S)+1;
    S2 := Copy(S, 1, P3-1);            // 12/66/77
    if S2[Length(S2)] = '/' then S2 := Copy(S2, 1, Length(S2)-1);
    P := Pos('/', S2);
    if P > 0 then F[FVCount-1].V := StrToInt(Copy(S2, 1, P-1))-1 else begin
      F[FVCount-1].V := StrToInt(Copy(S2, 1, P3-1))-1;
      S := Copy(S, P3+1, Length(S));
      Continue;
    end;
    S2 := Copy(S2, P+1, Length(S2));
    P := Pos('/', S2);
    if P > 0 then F[FVcount-1].T := StrToIntDef(Copy(S2, 1, P-1), 1)-1 else begin
      F[FVCount-1].T := StrToInt(Copy(S2, 1, P3-1))-1;
      S := Copy(S, P3+1, Length(S));
      Continue;
    end;
    S2 := Copy(S2, P+1, Length(S2));
    P := Pos('/', S2);
{    if Copy(s2, 1, 4) = '690\' then begin
      S2 := S2;
    end;}
    if P > 0 then F[FVcount-1].N := StrToIntDef(Copy(S2, 1, P-1), 1)-1 else F[FVCount-1].N := StrToInt(Copy(S2, 1, P3-1))-1;
    S := Copy(S, P3+1, Length(S));
  end;

  if FromMax then begin               // Change vertices order
    I1 := 2; I2 := 1;
  end else begin
    I1 := 1; I2 := 2;
  end;

  FData[(FCount-1)][0].V := F[0].V;
  FData[(FCount-1)][I1].V := F[1].V;
  FData[(FCount-1)][I2].V := F[2].V;
  FData[(FCount-1)][0].N := F[0].N;
  FData[(FCount-1)][I1].N := F[1].N;
  FData[(FCount-1)][I2].N := F[2].N;
  FData[(FCount-1)][0].T := F[0].T;
  FData[(FCount-1)][I1].T := F[1].T;
  FData[(FCount-1)][I2].T := F[2].T;
  FData[(FCount-1)][0].M := CurMaterial;
  FData[(FCount-1)][I1].M := CurMaterial;
  FData[(FCount-1)][I2].M := CurMaterial;

  for P := 4 to FVCount do begin
    Inc(FCount); SetLength(FData, FCount);
    FData[(FCount-1)][0].V := F[0].V;
    FData[(FCount-1)][I1].V := F[P-2].V;
    FData[(FCount-1)][I2].V := F[P-1].V;
    FData[(FCount-1)][0].N := F[0].N;
    FData[(FCount-1)][I1].N := F[P-2].N;
    FData[(FCount-1)][I2].N := F[P-1].N;
    FData[(FCount-1)][0].T := F[0].T;
    FData[(FCount-1)][I1].T := F[P-2].T;
    FData[(FCount-1)][I2].T := F[P-1].T;
    FData[(FCount-1)][0].M := CurMaterial;
    FData[(FCount-1)][I1].M := CurMaterial;
    FData[(FCount-1)][I2].M := CurMaterial;
  end;

  SetLength(F, 0);
end;

procedure GetNormal(V1, V2, V3 : word; var N: TVector3s);
begin
  N.X := -((VData[V3].Y - VData[V1].Y)*(VData[V2].Z - VData[V1].Z) - (VData[V3].Z - VData[V1].Z)*(VData[V2].Y - VData[V1].Y));
  N.Y := -((VData[V3].Z - VData[V1].Z)*(VData[V2].X - VData[V1].X) - (VData[V3].X - VData[V1].X)*(VData[V2].Z - VData[V1].Z));
  N.Z := -((VData[V3].X - VData[V1].X)*(VData[V2].Y - VData[V1].Y) - (VData[V3].Y - VData[V1].Y)*(VData[V2].X - VData[V1].X));
  N := NormalizeVector3s(N);
end;

procedure CalcNormals;
var N: TVector3s; i: Integer;
begin
  NCount := VCount;
  SetLength(NData, NCount);
  for i := 0 to NCount-1 do NData[i] := ZeroVector3s;
  for i := 0 to FCount-1 do begin
    GetNormal(FData[i][0].V ,FData[i][1].V, FData[i][2].V, N);
    NData[FData[i][0].V] := AddVector3s(NData[FData[i][0].V], N);
    NData[FData[i][1].V] := AddVector3s(NData[FData[i][1].V], N);
    NData[FData[i][2].V] := AddVector3s(NData[FData[i][2].V], N);
    FData[i][0].N := FData[i][0].V; FData[i][1].N := FData[i][1].V; FData[i][2].N := FData[i][2].V;
  end;
  for i := 0 to NCount-1 do NData[i] := NormalizeVector3s(NData[i]);
end;

