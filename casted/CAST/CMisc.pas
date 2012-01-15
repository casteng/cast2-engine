{$Include GDefines}
{$Include CDefines}
unit CMisc;

interface

uses SysUtils, Basics, Base2D, Base3D, Adv2D, CTypes, CRes, CRender, Cast;

const smNone = 0; smScale = 1; smNormalize = 2;     // Scaling modes

function LoadImage(FileName: TFileName; Resources: TResourceManager; Format: Cardinal): Integer;
function LoadOBJ(FileName: TFileName; World: TWorld; var Actor: TActor; VertexFormat: Cardinal; ScalingMode: Integer; Scale: Single; FromMax: Boolean = False; RecalcNormals: Boolean = False; ImportMaterial: Boolean = True; OptimizeModel: Boolean = True): Integer;
function ImportWavResource(FileName: TFileName; Resources: TResourceManager; Format: Cardinal): Integer;
function LoadWav(FileName: TFileName; var Data: Pointer; var Size: Cardinal; var Format: Cardinal): Integer;
function SaveWavHeader(Stream: TDStream; Format, Size: Cardinal): Integer;
procedure ConvertVertices(SrcFormat, DestFormat: Cardinal; TotalVertices: Integer; Src: Pointer; Dest: Pointer);
//function LoadMesh(FileName: TFileName; Resources: TResourceManager; Actor: TActor; Scale: Single = 1; FromMax: Boolean = False; RecalcNormals: Boolean = False): Integer;

implementation

function LoadImage(FileName: TFileName; Resources: TResourceManager; Format: Cardinal): Integer;
var
  Data: Pointer;
  Palette: PPalette;
  Stream: TFileDStream;
  LineSize, Width, Height, Bpp: Integer;
  PaletteSize, PixelSize, LoadPixelSize, SrcFormat: Cardinal;
  ImageRes: TImageResource;
  ResourceType: Cardinal;
  PalRes: TArrayResource;
  FileRes, TotalPixels: Integer;
  Signature: array[0..2] of Char;
  IDFHeader: TIDFHeader;
begin
  Result := -1;
  Stream := TFileDStream.Create(FileName);
  Stream.Read(Signature, 3);
  Stream.Seek(0);
  Palette := nil; Data := nil;
  if Signature = 'IDF' then begin
    FileRes := LoadIDF(Stream, IDFHeader, Data, TotalPixels);
    Width := IDFHeader.Width; Height := IDFHeader.Height;
    LineSize := Width * GetBytesPerPixel(Format);
    SrcFormat := IDFHeader.PixelFormat;
    if Format = pfAuto then Format := SrcFormat;
    LoadPixelSize := GetBytesPerPixel(IDFHeader.PixelFormat);
    ResourceType := Resources.GetResourceClassIndex('TTextureResource')
  end else begin
    FileRes := LoadBitmap(Stream, LineSize, Width, Height, BPP, PaletteSize, Palette, Data);
    case BPP of
      8: SrcFormat := pfP8;
      24: SrcFormat := pfB8G8R8;
      32: SrcFormat := pfA8R8G8B8;
      else
    end;
    if Format = pfAuto then Format := SrcFormat;
    LoadPixelSize := BPP div 8;
    ResourceType := Resources.GetResourceClassIndex('TImageResource');
  end;
  Stream.Free;
  if FileRes <> feOK then begin if Assigned(Data) then FreeMem(Data); if Assigned(Palette) then FreeMem(Palette); Exit; end;
  PixelSize := GetBytesPerPixel(Format);
  if ResourceType = Resources.GetResourceClassIndex('TImageResource') then begin
    TotalPixels := Width * Height;
    ImageRes := TImageResource.Create(Resources, Format, TotalPixels * PixelSize);
  end;
  if ResourceType = Resources.GetResourceClassIndex('TTextureResource') then begin
    ImageRes := TTextureResource.Create(Resources, Format, TotalPixels * PixelSize);
    (ImageRes as TTextureResource).Miplevels := IDFHeader.MipLevels;
  end;
  ImageRes.Status := rsMemory;
  GetMem(ImageRes.Data, ImageRes.Size);
  ImageRes.Width := Width; ImageRes.Height := Height;
  Result := Resources.Add(Signature+'_'+GetFileName(FileName), ImageRes);
  if Result < 0 then ImageRes.Free else begin
    ConvertImage(SrcFormat, Format, TotalPixels, Data, PaletteSize, Palette, ImageRes.Data);
    if (Format <> pfP8) and (Format <> pfA8P8) then begin
      if Assigned(Palette) then FreeMem(Palette)
    end else begin
      PalRes := TArrayResource.Create(Resources, 0, PaletteSize*SizeOf(TPaletteItem), Resources.rkPalette);
      PalRes.Data := Palette; PalRes.TotalElements := PaletteSize;
      ImageRes.PaletteResource := Resources.Add('Pal_'+GetFileName(FileName), PalRes);
      if ImageRes.PaletteResource < 0 then Dec(ImageRes.PaletteResource, rmError);
    end;
  end;
  if Assigned(Data) then FreeMem(Data);
end;

function ClearCR(s: string): string;
begin
  Result := s;
  while (Result[Length(Result)] = #$A) or (Result[Length(Result)] = #$D) do Result := Copy(Result, 1, Length(Result)-1);
end;

function LoadOBJ(FileName: TFileName; World: TWorld; var Actor: TActor; VertexFormat: Cardinal; ScalingMode: Integer; Scale: Single; FromMax: Boolean = False; RecalcNormals: Boolean = False; ImportMaterial: Boolean = True; OptimizeModel: Boolean = True): Integer;
//function LoadMesh(FileName: TFileName; Resources: TResourceManager; Actor: TActor; Scale: Single = 1; FromMax: Boolean = False; RecalcNormals: Boolean = False): Integer;
const Infinity =  1.0 / 0.0; NegInfinity =  -1.0 / 0.0;
var
//  F: TextFile;
  FS: TFileDStream;
  SS: TStringDStream;
  p: Pointer;
  S, S2: string;
  i, j: Integer;
  TextureFileName: TFileName;
  VertexSize: Integer;
  TexOffset, NormOffset, DiffuseOffset, SpecularOffset: Word;
  VCount, NCount, TCount, FCount, Curmaterial, MCount, GroupOffset: Integer;
  VRes, IRes: TArrayResource;
  TResIndex: Integer;
  Mat: TMaterial;
  MinVector, MaxVector: TVector3s;
  NormFactor: Single;
{$Include LoadObj.inc}

begin
  S := ExtractFileName(FileName);
  S := Copy(S, 1, Length(S)-Length(ExtractFileExt(FileName)));
  Actor := TActor.Create(S, World, nil);
  NormOffset := 3;
  DiffuseOffset := NormOffset + (VertexFormat shr 1) and 1 * 3;
  SpecularOffset := DiffuseOffset + (VertexFormat shr 2) and 1;
  TexOffset := SpecularOffset + (VertexFormat shr 3) and 1;
  VertexSize := GetVertexSize(VertexFormat) shr 2;

  if not FileExists(FileName) then begin Result := feNotFound; Exit; end;

  FS := TFileDStream.Create(FileName);
  GetMem(p, FS.Size);
  FS.Read(p^, FS.Size);
  SS := TStringDStream.Create(p, FS.Size, #10);
  FS.Free;

  MinVector := GetVector3s(Infinity, Infinity, Infinity);
  MaxVector := GetVector3s(NegInfinity, NegInfinity, NegInfinity);
  VCount := 0; NCount := 0; TCount := 0; FCount := 0; MCount := 0; CurMaterial := -1;
  GroupOffset := 0;
//  AssignFile(F, FileName); Reset(F);
  while SS.Position < SS.Size do begin
    SS.Readln(S);
    S := Uppercase(Trim(S));
    if (S <> '') and (S[1] <> '#') then begin
      if S <> '' then while S[Length(s)] = '\' do begin
        SS.Readln(S2);
        S2 := Uppercase(Trim(S2));
        S := Copy(S, 1, Length(S)-1) + ' ' + S2;
      end;
      case S[1] of
        'G': GroupOffset := VCount;
        'V': ReadVertexData(S);
        'F': ReadFaceData(S);
        'U': for i := 0 to MCount-1 do if MData[i].Name = ClearCR(Copy(S, 8, Length(S))) then CurMaterial := i;
        'M': LoadMaterials(S);
      end;
    end;
  end;
  SS.Free;
  if RecalcNormals then NCount := 0;
  if (VertexFormat and 2 = 2) and (NCount = 0) then CalcNormals;
  if ((VertexFormat shr 8) and 255 > 0) and (TCount = 0) then begin
    TCount := 1; SetLength(TData, TCount);
    TData[0] := GetVector3s(0, 0, 0);
  end;

  VRes := TArrayResource.Create(World.ResourceManager, VertexFormat, (FCount*3)*VertexSize*4, World.ResourceManager.GetResourceClassIndex('TArrayResource'));
  VRes.Status := rsMemory;
  IRes := TArrayResource.Create(World.ResourceManager, 2, FCount*3*2, World.ResourceManager.GetResourceClassIndex('TArrayResource')+1);
  IRes.Status := rsMemory;

  VRes.TotalElements := FCount*3; Getmem(VRes.Data, VRes.Size);
  IRes.TotalElements := FCount*3; Getmem(IRes.Data, IRes.Size);

  if ScalingMode = smNormalize then begin
    if (MaxVector.X - MinVector.X > MaxVector.Y - MinVector.Y) and (MaxVector.X - MinVector.X > MaxVector.Z - MinVector.Z) then
     NormFactor := Scale / (MaxVector.X - MinVector.X);
    if (MaxVector.Y - MinVector.Y > MaxVector.X - MinVector.X) and (MaxVector.Y - MinVector.Y > MaxVector.Z - MinVector.Z) then
     NormFactor := Scale / (MaxVector.Y - MinVector.Y);
    if (MaxVector.Z - MinVector.Z > MaxVector.X - MinVector.X) and (MaxVector.Z - MinVector.Z > MaxVector.Y - MinVector.Y) then
     NormFactor := Scale / (MaxVector.Z - MinVector.Z);
    for i := 0 to VCount-1 do ScaleVector3s(VData[i], VData[i], NormFactor);  
  end;

  for i := 0 to FCount-1 do for j := 0 to 2 do with FData[i][j] do begin
    TVector3s((@TSingleBuffer(VRes.Data^)[(i*3+j)*VertexSize])^) := VData[V];
    if (VertexFormat shr 2) and 1 > 0 then if M >= 0 then
     TDwordBuffer(VRes.Data^)[(i*3+j)*VertexSize + DiffuseOffset] := Round(MData[M].Diffuse.X * 255) shl 16 + Round(MData[M].Diffuse.Y * 255) shl 8 + Round(MData[M].Diffuse.Z * 255) else
      TDwordBuffer(VRes.Data^)[(i*3+j)*VertexSize + DiffuseOffset] := $00808080*0+255;
    if (VertexFormat shr 3) and 1 > 0 then if M >= 0 then
     TDwordBuffer(VRes.Data^)[(i*3+j)*VertexSize + SpecularOffset] := Round(MData[M].Specular.X * 255) shl 16 + Round(MData[M].Specular.Y * 255) shl 8 + Round(MData[M].Specular.Z * 255) else
      TDwordBuffer(VRes.Data^)[(i*3+j)*VertexSize + SpecularOffset] := $00808080*0+255;
    if (VertexFormat shr 8) and 255 > 0 then begin
      TVector3s((@TSingleBuffer(VRes.Data^)[(i*3+j)*VertexSize + TexOffset])^).X := TData[T].X;
      TVector3s((@TSingleBuffer(VRes.Data^)[(i*3+j)*VertexSize + TexOffset])^).Y := TData[T].Y;
    end;
    if (VertexFormat and 2 = 2) and (N < NCount) then TVector3s((@TSingleBuffer(VRes.Data^)[(i*3+j)*VertexSize + NormOffset])^) := NData[N];
    TWordBuffer(IRes.Data^)[i*3+j] := i*3+j;
  end;

  if Actor <> nil then begin
    Actor.SetMeshResources(World.ResourceManager.Add('Ver_'+GetFileName(FileName), VRes),
                           World.ResourceManager.Add('Ind_'+GetFileName(FileName), IRes));
    if Actor.CurrentLOD = nil then begin
      Actor.Free;
      VRes.Free;
      IRes.Free;
    end else begin
      Actor.SetMesh;
  //    if Actor.CurrentLOD.VerticesRes < 0 then begin VRes.Free; Dec(Actor.CurrentLOD.VerticesRes, rmError); end;
      Actor.CurrentLOD.TotalVertices := FCount*3;
      Actor.CurrentLOD.Vertices := World.ResourceManager[Actor.CurrentLOD.VerticesRes].Data;
  //    if Actor.CurrentLOD.IndicesRes < 0 then begin IRes.Free; Dec(Actor.CurrentLOD.IndicesRes, rmError); end;
      Actor.CurrentLOD.TotalIndices := FCount*3;                                                                     //ToFix: Potential bug here
      Actor.CurrentLOD.Indices := World.ResourceManager[Actor.CurrentLOD.IndicesRes].Data;
      Actor.CurrentLOD.TotalPrimitives := FCount;
    end;
  end else begin
    World.ResourceManager.Add('Ver_'+GetFileName(FileName), VRes);
    World.ResourceManager.Add('Ind_'+GetFileName(FileName), IRes);
  end;
  if ImportMaterial and (TextureFileName <> '') then TResIndex := LoadImage(TextureFileName, World.ResourceManager, pfA8R8G8B8) else TResIndex := -1;
  if (Actor <> nil) and (Actor.CurrentLOD <> nil) then begin
    if (TResIndex < 0) and (TResIndex <> -1) then Dec(TResIndex, rmError);
    if ImportMaterial then begin
      Mat := TMaterial.Create(Actor.Name, World.Renderer);
      Mat.Stages[0].TextureRID := TResIndex;
      Mat.Stages[0].TextureInd := World.Renderer.AddTexture(TResIndex);
      Mat.Stages[0].ColorOp := toModulate2X;
    end else Mat := World.Renderer.GetMaterialByName('Default');
    Actor.SetMaterial(0, World.Renderer.AddMaterial(Mat));
    World.AddItem(Actor);
//    Actor.TextureRes := TResIndex;
//  Actor.CurrentLOD.Material.AddTextureStage(Actor.World.Renderer.AddTexture(Actor.TextureRes), toModulate2X, taTexture, taDiffuse, taWrap);
  end;
  SetLength(VData, 0); SetLength(NData, 0); SetLength(TData, 0); SetLength(MData, 0); SetLength(FData, 0);
  Result := feOK;
end;

type
  TWaveFormat = packed record
    FormatTag: Word;
    Channels: Word;
    SamplesPerSec: Longword;
    AvgBytesPerSec: Longword;
    BlockAlign: Word;
  end;
  TPCMWaveFormat = packed record
    WaveFormat: TWaveFormat;
    BitsPerSample: Word;
  end;
  TWFHeader = packed record
    RIFFSign: TFileSignature;
    FileLength: Longword;
    WAVESign: TFileSignature;
    FMTSign: TFileSignature;
    FormatLength: Longword;
    Format: TPCMWaveFormat;
    DataSign: TFileSignature;
    DataLength: Longword;
  end;

function ImportWavResource(FileName: TFileName; Resources: TResourceManager; Format: Cardinal): Integer;
var AudioRes: TAudioResource; Data: Pointer; Size: Cardinal;
begin
  LoadWav(FileName, Data, Size, Format);
  AudioRes := TAudioResource.Create(Resources, Format, Size);
  AudioRes.Allocate(Size);
  Move(Data^, AudioRes.Data^, Size);
  Resources.Add('WAV_'+GetFileName(FileName), AudioRes);
  FreeMem(Data);
end;

function LoadWav(FileName: TFileName; var Data: Pointer; var Size: Cardinal; var Format: Cardinal): Integer;
var F: file; WaveHeader: TWFHeader; BytesRead: Cardinal;
begin
  Result := feCannotRead;
  AssignFile(F, FileName); Reset(F, 1);
  BlockRead(F, WaveHeader, SizeOf(WaveHeader), BytesRead);
  if BytesRead <> SizeOf(WaveHeader) then Exit;
  if WaveHeader.DataSign <> 'data' then WaveHeader.DataLength := FileSize(F)-SizeOf(WaveHeader);
  Format := PackSoundFormat(WaveHeader.Format.WaveFormat.SamplesPerSec, WaveHeader.Format.BitsPerSample, WaveHeader.Format.WaveFormat.Channels);
  GetMem(Data, WaveHeader.DataLength);
  BlockRead(F, Data^, WaveHeader.DataLength, BytesRead);
  Close(F);

  Size := BytesRead;

//  if Format = pfAuto then Format := SrcFormat;
  Result := feOK;
end;

function SaveWavHeader(Stream: TDStream; Format, Size: Cardinal): Integer;
var WaveHeader: TWFHeader;
begin
  Result := feCannotWrite;
  WaveHeader.RIFFSign     := 'RIFF';
  WaveHeader.FileLength   := Size + SizeOf(WaveHeader) - SizeOf(WaveHeader.RIFFSign) - SizeOf(WaveHeader.FileLength);
  WaveHeader.WAVESign     := 'WAVE';
  WaveHeader.FMTSign      := 'fmt ';
  WaveHeader.FormatLength := SizeOf(WaveHeader.Format);
  WaveHeader.Format.WaveFormat.FormatTag      := 1;                    // WAVE_FORMAT_PCM
  WaveHeader.Format.WaveFormat.Channels       := UnpackSoundFormat(Format).Channels;
  WaveHeader.Format.WaveFormat.SamplesPerSec  := UnpackSoundFormat(Format).SampleRate;
  WaveHeader.Format.WaveFormat.AvgBytesPerSec := UnpackSoundFormat(Format).SampleRate * UnpackSoundFormat(Format).Channels * UnpackSoundFormat(Format).BitsPerSample div 8;
  WaveHeader.Format.WaveFormat.BlockAlign     := UnpackSoundFormat(Format).Channels * UnpackSoundFormat(Format).BitsPerSample div 8;
  WaveHeader.Format.BitsPerSample             := UnpackSoundFormat(Format).BitsPerSample;
  WaveHeader.DataSign     := 'data';
  WaveHeader.DataLength   := Size;

  if Stream.Write(WaveHeader, SizeOf(WaveHeader)) <> feOK then Exit;

  Result := feOK;
end;

procedure ConvertVertices(SrcFormat, DestFormat: Cardinal; TotalVertices: Integer; Src: Pointer; Dest: Pointer);
type TVBuf = array[0..$FFFFFF] of Byte;
const
  vfiNorm = 1; vfiDiff = 2; vfiSpec = 3; vfiTex = 4; vfiWeight = 5;
  riSrc = 0; riDest = 1;
var i: Integer; SVSize, DVSize, CoordsSize: Cardinal;
  EOffset: array[riSrc..riDest, vfiNorm..vfiWeight] of Cardinal;
//TexOffset, NormOffset, DiffOffset, SpecOffset: Longword;

procedure GetOffsets(Format, Res: Cardinal);
begin
  if Format and vfTransformed = 0 then EOffset[Res, vfiNorm] := 3*4 else EOffset[Res, vfiNorm] := 4*4;
  EOffset[Res, vfiDiff] := EOffset[Res, vfiNorm] + ((Format shr vfiNorm) and 1) * 3*4;
  EOffset[Res, vfiSpec] := EOffset[Res, vfiDiff] + ((Format shr vfiDiff) and 1) * 4;
  EOffset[Res, vfiTex] := EOffset[Res, vfiSpec] + ((Format shr vfiSpec) and 1) * 4;
  EOffset[Res, vfiWeight] := EOffset[Res, vfiTex] + ((Format shr 8) and 255) * 8;
end;

begin
// vfTransformed = 1; vfNormals = 2; vfDiffuse = 4; vfSpecular = 8;
  GetOffsets(SrcFormat, riSrc);
  GetOffsets(DestFormat, riDest);
  SVSize := GetVertexSize(SrcFormat);
  DVSize := GetVertexSize(DestFormat);
  CoordsSize := 3*4;
  if (SrcFormat and vfTransformed > 0) and (DestFormat and vfTransformed > 0) then CoordsSize := 4*4;
  FillChar(Dest^, TotalVertices * DVSize, 0);
  for i := 0 to TotalVertices-1 do begin
    Move(TVBuf(Src^)[i*SVSize], TVBuf(Dest^)[i*DVSize], CoordsSize);
    if (SrcFormat and vfNormals > 0) and (DestFormat and vfNormals > 0) then
     Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, vfiNorm]],
          TVBuf(Dest^)[i*DVSize + EOffset[riDest, vfiNorm]], 3*4);
    if (SrcFormat and vfDiffuse > 0) and (DestFormat and vfDiffuse > 0) then
     Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, vfiDiff]],
          TVBuf(Dest^)[i*DVSize + EOffset[riDest, vfiDiff]], 4);
    if (SrcFormat and vfSpecular > 0) and (DestFormat and vfSpecular > 0) then
     Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, vfiSpec]],
          TVBuf(Dest^)[i*DVSize + EOffset[riDest, vfiSpec]], 4);
    Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, vfiTex]],
         TVBuf(Dest^)[i*DVSize + EOffset[riDest, vfiTex]],
         MinI((SrcFormat shr 8) and 255, (DestFormat shr 8) and 255)*8);
    Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, vfiTex]],
         TVBuf(Dest^)[i*DVSize + EOffset[riDest, vfiTex]],
         MinI((SrcFormat shr 16) and 255, (DestFormat shr 16) and 255)*4);
  end;
end;

end.
