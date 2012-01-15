(*
 @Abstract(CAST II engine resources import unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains resource import routines
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2ResImport;

interface

uses
  Logger,
  SysUtils,
  BaseTypes, BaseClasses, Basics, BaseStr, Base2D, Base3D, Resources, Props,
  Cast2, C2Types, C2Res, C2Visual, C2VisItems, C2Materials;

type
  // Resource carrier for mesh data base class
  TMeshCarrierBase = class(TResourceCarrier)
  protected
    // Creates and sets up a default material with texture in TRes
    function AddMaterial(TRes: TImageResource; const AURL: string): TMaterial;
  end;

  // Resource carrier implementation for .obj files
  TObjMeshCarrier = class(TMeshCarrierBase)
  protected
    function DoLoad(Stream: TStream; const AURL: string; var Resource: TItem): Boolean; override;
  public
    procedure Init; override;
    // Main resource class for the class is TVerticesResource
    function GetResourceClass: CItem; override;
  end;

  // Resource carrier implementation for simple binary mesh format
  TBinMeshCarrier = class(TMeshCarrierBase)
  protected
    function DoLoad(Stream: TStream; const AURL: string; var Resource: TItem): Boolean; override;
  public
    procedure Init; override;
    function GetResourceClass: CItem; override;
  end;


function LoadImage(FileName: BaseTypes.TFileName): TImageResource;
// Loads a WaveFront .obj mesh file from the given stream and returns mesh data in TRawMesh structure. Returns True if success.
//function LoadOBJ(Stream: Basics.TStream; out VRes: TVerticesResource; out IRes: TIndicesResource; out TRes: TImageResource): Boolean;
function ImportWavResource(FileName: BaseTypes.TFileName): TAudioResource;
function LoadWav(FileName: BaseTypes.TFileName; var Data: Pointer; var Size: Cardinal; var Format: Integer): Boolean;
function SaveWavHeader(Stream: TStream; Format, Size: Cardinal): Boolean;
//function LoadMesh(FileName: BaseTypes.TFileName; Resources: TResourceManager; Actor: TActor; Scale: Single = 1; FromMax: Boolean = False; RecalcNormals: Boolean = False): Integer;

implementation

const ImportCapacityStep = 32;

function LoadImage(FileName: BaseTypes.TFileName): TImageResource;
begin
  Result := nil;
  Result := TImageResource.Create(nil);
  Result.CarrierURL := FileName;
  if Result.Data <> nil then
    Result.Name := GetFileName(FileName)
  else
    FreeAndNil(Result);
end;

function ClearCR(s: string): string;
begin
  Result := s;
  while (Result[Length(Result)] = #$A) or (Result[Length(Result)] = #$D) do Result := Copy(Result, 1, Length(Result)-1);
end;

function LoadOBJ(Stream: Basics.TStream; out VRes: TVerticesResource; out IRes: TIndicesResource; out TRes: TImageResource): Boolean;
var
  S, S2: AnsiString;
  VCount, NCount, TCount, FCount, Curmaterial, MCount, GroupOffset: Integer;
  LFileName, TextureFileName: BaseTypes.TFileName;

  FData: array of array[0..2] of record
    V, N, T, M: Integer;
  end;
  VData, NData, TData: array of TVector3s;
  MData: array of record
    Name: string[40];
    Diffuse, Specular: TVector3s;
  end;

{$Include LoadObj.inc}
var

//  F: TextFile;
  SS: TAnsiStringStream;
  p: Pointer;

  i, j: Integer;

  VertexSize: Integer;
  TexOffset, NormOffset, DiffuseOffset, SpecularOffset: Word;

  Garbage: IRefCountedContainer;

begin
  Result := False;
  VRes := nil; IRes := nil; TRes := nil;

  if Stream is Basics.TFileStream then
    LFileName := Basics.TFileStream(Stream).FileName
  else
    LFileName := '';

//  S := ExtractFileName(FileName);
//  S := Copy(S, 1, Length(S)-Length(ExtractFileExt(FileName)));

//  if not FileExists(FileName) then if not ErrorHandler(TFileError.Create('File "' + FileName + '" not found')) then Exit;

  Garbage := CreateRefcountedContainer();

  if Stream is TAnsiStringStream then
    SS := Stream as TAnsiStringStream
  else begin
    GetMem(p, Stream.Size);
    Garbage.AddPointer(p);
    Stream.Read(p^, Stream.Size);
    SS := TAnsiStringStream.Create(p, Stream.Size, #10);
    Garbage.AddObject(SS);
  end;

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
        'M': LoadMtlMaterials(S);
      end;
    end;
  end;
  
  if VCount = 0 then begin
     Log(Format('%S: No vertices found', ['LoadOBJ']), lkError); 
    Exit;
  end;
  if NCount = 0 then begin
     Log(Format('%S: No normals found. Automatic calculation will apply', ['LoadOBJ']), lkWarning); 
    CalcNormals;
  end;
  if TCount = 0 then begin
    TCount := 1; SetLength(TData, TCount);
    TData[0] := GetVector3s(0, 0, 0);
  end;

  VRes := TVerticesResource.Create(nil);
  VRes.Name          := 'VER_' + GetFileName(LFileName);
  VRes.Format        := GetVertexFormat(False, True, True, True, False, 0, [2]);
  VertexSize         := GetVertexSize(VRes.Format);
  VRes.Allocate(FCount*3 * VertexSize);

  NormOffset     := GetVertexElementOffset(VRes.Format, vfiNORM);
  DiffuseOffset  := GetVertexElementOffset(VRes.Format, vfiDIFF);
  SpecularOffset := GetVertexElementOffset(VRes.Format, vfiSPEC);
  TexOffset      := GetVertexElementOffset(VRes.Format, vfiTEX0);

  IRes := TIndicesResource.Create(nil);
  IRes.Name          := 'IND_' + GetFileName(LFileName);
  IRes.Format        := IndexSize;
  IRes.Allocate(FCount*3 * IndexSize);

  for i := 0 to FCount-1 do for j := 0 to 2 do with FData[i][j] do begin
    TVector3s((@TByteBuffer(VRes.Data^)[(i*3+j)*VertexSize])^) := VData[V];
    if M >= 0 then
      Cardinal((@TByteBuffer(VRes.Data^)[(i*3+j)*VertexSize + DiffuseOffset])^) := Round(MData[M].Diffuse.X * 255) shl 16 + Round(MData[M].Diffuse.Y * 255) shl 8 + Round(MData[M].Diffuse.Z * 255)
    else
      Cardinal((@TByteBuffer(VRes.Data^)[(i*3+j)*VertexSize + DiffuseOffset])^) := $80808080;
    if M >= 0 then
      Cardinal((@TByteBuffer(VRes.Data^)[(i*3+j)*VertexSize + SpecularOffset])^) := Round(MData[M].Specular.X * 255) shl 16 + Round(MData[M].Specular.Y * 255) shl 8 + Round(MData[M].Specular.Z * 255)
    else
      Cardinal((@TByteBuffer(VRes.Data^)[(i*3+j)*VertexSize + SpecularOffset])^) := $80808080;

    TVector3s((@TByteBuffer(VRes.Data^)[(i*3+j)*VertexSize + TexOffset])^).X := TData[T].X;
    TVector3s((@TByteBuffer(VRes.Data^)[(i*3+j)*VertexSize + TexOffset])^).Y := TData[T].Y;

    if N < NCount then TVector3s((@TByteBuffer(VRes.Data^)[(i*3+j)*VertexSize + NormOffset])^) := NData[N];
    TWordBuffer(IRes.Data^)[i*3+j] := i*3+j;
  end;

  if TextureFileName <> '' then TRes := LoadImage(TextureFileName) else TRes := nil;

  SetLength(VData, 0); SetLength(NData, 0); SetLength(TData, 0); SetLength(MData, 0); SetLength(FData, 0);
  Result := True;
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

function ImportWavResource(FileName: BaseTypes.TFileName): TAudioResource;
var Data: Pointer; Size: Cardinal; Format: Integer;
begin
  Result := TAudioResource.Create(nil);

  if not LoadWav(FileName, Data, Size, Format) then Exit;
  Result.Format := Format;
  Result.SetAllocated(Size, Data);

  Result.Name := 'WAV_' + GetFileName(FileName);
end;

function LoadWav(FileName: BaseTypes.TFileName; var Data: Pointer; var Size: Cardinal; var Format: Integer): Boolean;
var F: file; WaveHeader: TWFHeader; BytesRead: Cardinal;
begin
  Result := False;
  AssignFile(F, FileName); Reset(F, 1);
  BlockRead(F, WaveHeader, SizeOf(WaveHeader), BytesRead);
  if BytesRead <> SizeOf(WaveHeader) then Exit;
  if WaveHeader.DataSign <> 'data' then WaveHeader.DataLength := FileSize(F)-SizeOf(WaveHeader);
  Format := PackSoundFormat(WaveHeader.Format.WaveFormat.SamplesPerSec, WaveHeader.Format.BitsPerSample, WaveHeader.Format.WaveFormat.Channels);
  GetMem(Data, WaveHeader.DataLength);
  BlockRead(F, Data^, WaveHeader.DataLength, BytesRead);
  Close(F);

  Size := WaveHeader.DataLength;

  Result := True;
end;

function SaveWavHeader(Stream: TStream; Format, Size: Cardinal): Boolean;
var WaveHeader: TWFHeader;
begin
  Result := False;
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

  if not Stream.WriteCheck(WaveHeader, SizeOf(WaveHeader)) then Exit;

  Result := True;
end;

{ TObjMeshCarrier }

function TObjMeshCarrier.DoLoad(Stream: TStream; const AURL: string; var Resource: TItem): Boolean;
var
  VRes: TVerticesResource;   // Vertex resources for models
  IRes: TIndicesResource;    // Index resources for models
  TRes: TImageResource;      // Texture resource
  Props: TProperties;        // Properties
  Actor: TMesh;
  Mat: TMaterial;
  CreateHierarchy: Boolean;    // Create a whole hierarchy of items or update only one resource
  Garbage: IRefcountedContainer;

begin
  Result := False;

  VRes := nil;
  IRes := nil;
  TRes := nil;

  Actor := nil;

  Mat  := nil;
  CreateHierarchy := Resource.Manager = nil;

  Props := TProperties.Create;

  // setup garbage collector
  Garbage := CreateRefcountedContainer;
  Garbage.AddObject(Props);

  if not LoadObj(Stream, VRes, IRes, TRes) then Exit;

  if CreateHierarchy then begin                             // Create whole items hierarchy
//    VRes.SetProperty('Data carrier', AURL);
//    if Assigned(IRes) then IRes.SetProperty('Data carrier', AURL);

    Actor := TMesh.Create(nil);                      // Create a new scene item for model
    Actor.Name := GetFileName(AURL);

    Mat := AddMaterial(TRes, AURL);
    if Assigned(Mat) then begin
      Actor.AddChild(Mat);
      Props.Add('Material', vtObjectLink, [], Mat.Name, '');
    end;

    Actor.AddChild(VRes);
    if Assigned(IRes) then begin
      Actor.AddChild(IRes);
      Props.Add('Geometry\Indices', vtObjectLink, [], IRes.Name, '');
    end;

    Props.Add('Geometry\Vertices', vtObjectLink, [], VRes.Name, '');

    Actor.SetProperties(Props);

    if Assigned(Resource) then Resource.Free;

    Resource := Actor;

    SetCarrierURL(VRes, AURL);
    SetCarrierURL(IRes, AURL);

    VRes := nil;
    IRes := nil;
    TRes := nil;

    Actor := nil;

    Mat := nil;
  end else begin                                            // Update only Resource
    if Resource is TVerticesResource then begin
      VRes.Format := TVerticesResource(Resource).Format;
      Resource.Assign(VRes);
      SetCarrierURL(VRes, AURL);
    end;
    if (Resource is TIndicesResource) and Assigned(IRes) then begin
      IRes.Format := TIndicesResource(Resource).Format;
      Resource.Assign(IRes);
      SetCarrierURL(IRes, AURL);
    end;
  end;

  if Assigned(VRes)  then FreeAndNil(VRes);
  if Assigned(IRes)  then FreeAndNil(IRes);
  if Assigned(TRes)  then FreeAndNil(TRes);
  if Assigned(Actor) then FreeAndNil(Actor);
  if Assigned(Mat) then FreeAndNil(Mat);

  Result := True;
end;

procedure TObjMeshCarrier.Init;
begin
  inherited;
  LoadingTypes := GetResTypeList([GetResTypeFromExt('obj')]);
end;

function TObjMeshCarrier.GetResourceClass: CItem;
begin
  Result := TVerticesResource;
end;

{ TBinMeshCarrier }

function TBinMeshCarrier.DoLoad(Stream: TStream; const AURL: string; var Resource: TItem): Boolean;
var
  VRes: TVerticesResource; IRes: TIndicesResource;
  Actor: TMesh;
  Mat: TMaterial;
  Props: TProperties;
  VCount, ICount: Integer;
  CreateHierarchy: Boolean;
begin
  Result := False;

  Props := TProperties.Create;

  VRes := nil;
  IRes := nil;
  Actor := nil;
  CreateHierarchy := Resource.Manager = nil;

  if not Stream.ReadCheck(VCount, 4) or (VCount = 0) then Exit;
  if not Stream.ReadCheck(ICount, 4) or (ICount = 0) then Exit;

  VRes := TVerticesResource.Create(nil);
  VRes.Format := GetVertexFormat(False, False, False, False, False, 0, [3]);
  VRes.Allocate(VCount * VRes.GetElementSize);
  Stream.ReadCheck(VRes.Data^, VRes.DataSize);

  IRes := TIndicesResource.Create(nil);
  IRes.Format := 2;
  IRes.Allocate(ICount * IRes.GetElementSize);
  Stream.ReadCheck(IRes.Data^, IRes.DataSize);

  if CreateHierarchy then begin                             // Create whole items hierarchy
    Actor := TMesh.Create(nil);                      // Create a new scene item for model
    Actor.Name := GetFileName(AURL);

    Mat := AddMaterial(nil, AURL);
    if Assigned(Mat) then begin
      Actor.AddChild(Mat);
      Props.Add('Material', vtObjectLink, [], Mat.Name,  '');
    end;

    Actor.AddChild(VRes);
    if Assigned(IRes) then begin
      Actor.AddChild(IRes);
      Props.Add('Geometry\Indices', vtObjectLink, [], IRes.Name, '');
    end;

    Props.Add('Geometry\Vertices', vtObjectLink, [], VRes.Name, '');

    Actor.SetProperties(Props);

    if Assigned(Resource) then Resource.Free;

    Resource := Actor;

    SetCarrierURL(VRes, AURL);
    SetCarrierURL(IRes, AURL);

    VRes := nil;
    IRes := nil;
    Actor := nil;
  end else begin                                            // Update only Resource
    if Resource is TVerticesResource then begin
      VRes.Format := TVerticesResource(Resource).Format;
      Resource.Assign(VRes);
      SetCarrierURL(VRes, AURL);
    end;
    if (Resource is TIndicesResource) and Assigned(IRes) then begin
      IRes.Format := TIndicesResource(Resource).Format;
      Resource.Assign(IRes);
      SetCarrierURL(IRes, AURL);
    end;
  end;

  Result := True;
end;

procedure TBinMeshCarrier.Init;
begin
  inherited;
  LoadingTypes := GetResTypeList([GetResTypeFromExt('bin')]);
end;

function TBinMeshCarrier.GetResourceClass: CItem;
begin
  Result := TVerticesResource;
end;

{ TMeshCarrierBase }

function TMeshCarrierBase.AddMaterial(TRes: TImageResource; const AURL: string): TMaterial;
var Tech: TTechnique; Pass: TRenderPass; Props: TProperties;
begin
  Props := TProperties.Create;
  Pass := TRenderPass.Create(nil);             // First and only pass
  Tech := TTechnique.Create(nil);              // Default technique
  Result  := TMaterial.Create(nil);               // Resulterial itself

  Result.Name := GetFileName(AURL);

//    ParentNode.AddChild(Result);                     // Add Resulterial to scene
  Result.AddChild(Tech);                           // Also technique
  Tech.AddChild(Pass);                          // And pass

  // Set up technique properties
  Props.Clear;
  Props.Add('Total passes', vtInt,        [], '1',              '');
  Props.Add('Pass #0',      vtObjectLink, [], Pass.Name, '');       // Add link to the pass
  Tech.SetProperties(Props);                                               // Apply properties

  // Set up Resulterial properties
  Props.Clear;
  Props.Add('Total techniques', vtInt,        [], '1',              '');
  Props.Add('Technique #0',     vtObjectLink, [], Tech.Name, '');   // Add link to the technique
  Result.SetProperties(Props);                                                // Apply properties

  // Set up pass properties
  Props.Add('Total stages',     vtNat,        [], '1',              '');
  if Assigned(TRes) then begin
    Result.AddChild(TRes);
    Props.Add('Stage #0\Texture', vtObjectLink, [], '.\.\' + TRes.Name, ''); // Add relative link to texture
  end;
  Pass.SetProperties(Props);                                               // Apply properties
  Pass.State := Pass.State + [isVisible];                                  // Make the pass visible

  FreeAndNil(Props);
end;

initialization
  ResourceLinker.RegisterCarrier(TObjMeshCarrier.Create);
  ResourceLinker.RegisterCarrier(TBinMeshCarrier.Create);
end.
