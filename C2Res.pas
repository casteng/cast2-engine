(*
 @Abstract(CAST II Engine resources unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains engine basic resource classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Res;

interface

uses SysUtils,
     Logger,
     Basics, BaseStr, Props, BaseTypes, BaseClasses, Resources, Base3D,
     C2Types;

type
  // Path data container
  TPathResource = class(Resources.TArrayResource)
    function GetElementSize: Integer; override;
  end;

  // Vertices data container
  TVerticesResource = class(Resources.TArrayResource)
  private
    FVertexSize: Integer;
    function GetVertexCoords(Index: Integer): TVector3s;
    procedure SetVertexCoords(Index: Integer; const Value: TVector3s);
  protected
    // Performs mesh conversion to new format
    function Convert(OldFormat, NewFormat: Cardinal): Boolean; override;
  public
    constructor Create(AManager: TItemsManager); override;
    function GetElementSize: Integer; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    // Coordinates of each vertice
    property VertexCoords[Index: Integer]: TVector3s read GetVertexCoords write SetVertexCoords;
  end;

  THeightMapResource = class(TImageResource)
  protected
    function Convert(OldFormat, NewFormat: Cardinal): Boolean; override;
  end;

  // Indices data container
  TIndicesResource = class(Resources.TArrayResource)
    function GetElementSize: Integer; override;
  end;

  // Shader programs container
  TShaderResource = class(Resources.TScriptResource)
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

uses C2Visual;                          // For GetVertexElementOffset, etc

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TPathResource, TVerticesResource, TIndicesResource, TShaderResource, THeightMapResource]);
end;

{ TPathResource }

function TPathResource.GetElementSize: Integer;
begin
  Result := SizeOf(TVector4s);
end;

{ TVerticesResource }

function TVerticesResource.GetVertexCoords(Index: Integer): TVector3s;
begin
  Result := TVector3s(Pointer(Cardinal(Integer(Data) + Index*GetElementSize + GetVertexElementOffset(Format, vfiXYZ)))^);
end;

procedure TVerticesResource.SetVertexCoords(Index: Integer; const Value: TVector3s);
begin
  TVector3s(Pointer(Cardinal(Integer(Data) + Index*GetElementSize + GetVertexElementOffset(Format, vfiXYZ)))^) := Value;
end;

function TVerticesResource.Convert(OldFormat, NewFormat: Cardinal): Boolean;
var Buffer: Pointer; BufSize: Integer;
begin
  Result := True;
  Assert(OldFormat <> NewFormat);
  if OldFormat = NewFormat then Exit;
  BufSize := TotalElements * Integer(GetVertexSize(NewFormat));
  GetMem(Buffer, BufSize);
  ConvertVertices(OldFormat, NewFormat, TotalElements, Data, Buffer);
  FVertexSize := MaxI(1, GetVertexSize(NewFormat));
  SetAllocated(BufSize, Buffer);
end;

constructor TVerticesResource.Create(AManager: TItemsManager);
begin
  inherited;
  FVertexSize := 1;
end;

function TVerticesResource.GetElementSize: Integer;
begin
  Result := FVertexSize;
end;

procedure TVerticesResource.AddProperties(const Result: TProperties);
const
  TexSetsStr: array[1..4] of string[4] = ('u', 'uv', 'uvw', 'uvwx');
  TexSetsEnum = 'u\&uv\&uvw\&uvwx';
var i: Integer; s: string;
begin
  inherited;
  if not Assigned(Result) then Exit;

  if VertexContains(Format, vfTRANSFORMED) then s := '[RHW' else s := '[XYZ';
  if VertexContains(Format, vfNORMALS)     then s := s + ' N';
  if VertexContains(Format, vfDIFFUSE)     then s := s + ' D';
  if VertexContains(Format, vfSPECULAR)    then s := s + ' S';
  if VertexContains(Format, vfPOINTSIZE)   then s := s + ' P';
  for i := 0 to GetVertexTextureSetsCount(Format)-1 do s := s + ' T' + TexSetsStr[GetVertexTextureCoordsCount(Format, i)];
  if GetVertexWeightsCount(Format) > 0 then s := s + ' W' + IntToStr(GetVertexWeightsCount(Format));
  if GetVertexIndexedBlending(Format) then s := s + 'i';
  s := s + '] ' + IntToStr(GetVertexSize(Format)) + ' bytes';
  Result.Add('Format\Vertex', vtString, [poDerivative, poReadonly], s, '');
  Result.Add('Format\Vertex\Transformed', vtBoolean, [poDerivative], OnOffStr[VertexContains(Format, vfTRANSFORMED)], '');
  Result.Add('Format\Vertex\Normals',     vtBoolean, [poDerivative], OnOffStr[VertexContains(Format, vfNORMALS)],     '');
  Result.Add('Format\Vertex\Diffuse',     vtBoolean, [poDerivative], OnOffStr[VertexContains(Format, vfDIFFUSE)],     '');
  Result.Add('Format\Vertex\Specular',    vtBoolean, [poDerivative], OnOffStr[VertexContains(Format, vfSPECULAR)],    '');
  Result.Add('Format\Vertex\Point size',  vtBoolean, [poDerivative], OnOffStr[VertexContains(Format, vfPOINTSIZE)],   '');

  Result.Add('Format\Vertex\Indexed blending', vtBoolean, [poDerivative], OnOffStr[GetVertexIndexedBlending(Format)],   '');

  Result.Add('Format\Vertex\Number of UV sets', vtInt, [poDerivative], IntToStr(GetVertexTextureSetsCount(Format)), '');
  for i := 0 to GetVertexTextureSetsCount(Format)-1 do
    Result.AddEnumerated('Format\Vertex\UV set ' + IntToStr(i), [poDerivative], GetVertexTextureCoordsCount(Format, i)-1, TexSetsEnum);
  Result.Add('Format\Vertex\Number of weights', vtInt, [poDerivative], IntToStr(GetVertexWeightsCount(Format)), '');
end;

procedure TVerticesResource.SetProperties(Properties: TProperties);
var
  NewFormat: Cardinal;
  NFTransformed, NFNormals, NFDiffuse, NFSpecular, NFPointSize, NFIndexedBlending: Boolean;
  TextureSets: array of Integer; i, NumberOfTSets, NumberOfWeights: Integer;
begin
  inherited;

  NFTransformed := VertexContains(Format, vfTRANSFORMED);
  NFNormals     := VertexContains(Format, vfNORMALS);
  NFDiffuse     := VertexContains(Format, vfDIFFUSE);
  NFSpecular    := VertexContains(Format, vfSPECULAR);
  NFPointSize   := VertexContains(Format, vfPOINTSIZE);
  NumberOfTSets := GetVertexTextureSetsCount(Format);
  SetLength(TextureSets, NumberOfTSets);
  for i := 0 to NumberOfTSets-1 do TextureSets[i] := GetVertexTextureCoordsCount(Format, i);
  NumberOfWeights := GetVertexWeightsCount(Format);
  NFIndexedBlending := GetVertexIndexedBlending(Format);

  if Properties.Valid('Format\Vertex\Transformed') then NFTransformed := Properties.GetAsInteger('Format\Vertex\Transformed') > 0;
  if Properties.Valid('Format\Vertex\Normals')     then NFNormals     := Properties.GetAsInteger('Format\Vertex\Normals')     > 0;
  if Properties.Valid('Format\Vertex\Diffuse')     then NFDiffuse     := Properties.GetAsInteger('Format\Vertex\Diffuse')     > 0;
  if Properties.Valid('Format\Vertex\Specular')    then NFSpecular    := Properties.GetAsInteger('Format\Vertex\Specular')    > 0;
  if Properties.Valid('Format\Vertex\Point size')  then NFPointSize   := Properties.GetAsInteger('Format\Vertex\Point size')  > 0;

  if Properties.Valid('Format\Vertex\Indexed blending') then NFIndexedBlending := Properties.GetAsInteger('Format\Vertex\Indexed blending') > 0;

  if Properties.Valid('Format\Vertex\Number of UV sets') then NumberOfTSets := StrToIntDef(Properties['Format\Vertex\Number of UV sets'], NumberOfTSets);
  SetLength(TextureSets, NumberOfTSets);
  for i := 0 to High(TextureSets) do TextureSets[i] := 2;
  for i := 0 to NumberOfTSets-1 do
    if Properties.Valid('Format\Vertex\UV set ' + IntToStr(i)) then TextureSets[i] := Properties.GetAsInteger('Format\Vertex\UV set ' + IntToStr(i)) + 1;

  if Properties.Valid('Format\Vertex\Number of weights') then NumberOfWeights := StrToIntDef(Properties['Format\Vertex\Number of weights'], NumberOfWeights);

  NewFormat := GetVertexFormat(NFTransformed, NFNormals, NFDiffuse, NFSpecular, NFPointSize, NumberOfWeights or (vwIndexedBlending * Ord(NFIndexedBlending)), TextureSets);
  if NewFormat <> Format then Format := NewFormat;

  TextureSets := nil;
end;

{ TIndicesResource }

function TIndicesResource.GetElementSize: Integer;
begin
  Result := MaxI(1, Format);
end;

{ THeightMapResource }

function THeightMapResource.Convert(OldFormat, NewFormat: Cardinal): Boolean;
begin
  case NewFormat of
    pfA8, pfL8, pfD16, pfD32: Result := inherited Convert(OldFormat, NewFormat);
    else begin
      Log('THeightMapResource.Convert: invalid format "' + PixelFormatToStr(NewFormat), lkError);
      Result := False;
    end;
  end;
end;

begin
  GlobalClassList.Add('C2Res', GetUnitClassList);
end.

