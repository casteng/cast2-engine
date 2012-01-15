(*
 CAST II Engine vegetation unit
 (C) 2006-2008 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Mar 13, 2008
 Unit contains
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Flora;

interface

uses SysUtils, Logger, Basics, BaseCont, BaseTypes, Base3d, Props, BaseClasses, C2Types, C2Visual, C2VisItems, CAST2;

type
  TTreeAdjTesselator = class(TMeshTesselator)
  private
    FAdjNormals, FAdjdiffuse: Boolean;
    FDiffuse: TColor;
    TimeElapsed: Integer;
    FRadius: Single;
    procedure AdjustMesh;
  public
    function IsSameItem(AItem: TReferencedItem): Boolean; override;
    procedure Init; override;

    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;

    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TTreeAdj = class(TMesh)
  public
    function GetTesselatorClass: CTesselator; override;
    procedure Process(const DeltaT: Float); override;
  end;

  // Procedural tree stem tesselator
  TTreeStemTesselator = class(TTesselator)
  public
    Width, Height: Single;
    Sides, Levels: Integer;
    procedure Init; override;

    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  // Procedural tree stem
  TTreeStem = class(TVisible)
  public
    function GetTesselatorClass: CTesselator; override;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TTreeAdj, TTreeStem]);
end;

{ TTreeAdjTesselator }

function TTreeAdjTesselator.IsSameItem(AItem: TReferencedItem): Boolean;
begin
  Result := False;
end;

procedure TTreeAdjTesselator.Init;
begin
  inherited;
  TesselationStatus[tbVertex].TesselatorType := ttStatic;
  TesselationStatus[tbIndex].TesselatorType  := ttStatic;
end;

procedure TTreeAdjTesselator.AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  Result.Add(PropNamePrefix + 'Adjust normals', vtBoolean, [], OnOffStr[FAdjNormals], '');
  Result.Add(PropNamePrefix + 'Adjust diffuse', vtBoolean, [], OnOffStr[FAdjdiffuse], '');
  Result.Add('Radius', vtSingle, [], FloatToStr(FRadius), '0.2-3.0');
  AddColorProperty(Result, PropNamePrefix + 'Diffuse', FDiffuse);
end;

procedure TTreeAdjTesselator.SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid(PropNamePrefix + 'Adjust normals') then FAdjNormals := Properties.GetAsInteger(PropNamePrefix + 'Adjust normals') > 0;
  if Properties.Valid(PropNamePrefix + 'Adjust diffuse') then FAdjdiffuse := Properties.GetAsInteger(PropNamePrefix +'Adjust diffuse') > 0;
  if Properties.Valid('Radius') then FRadius := StrToFloatDef(Properties['Radius'], 1);

  SetColorProperty(Properties, PropNamePrefix + 'Diffuse', FDiffuse);
  AdjustMesh;
end;

function TTreeAdjTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
const FreqK = 0.01; AmpK = 0.6;
var i, i1, i2, i3, t: Integer; v1, v2, v3, n: TVector3s; Freq, Amp: Single;
begin
  Result := 0;
  if FVertices = nil then Exit;

  Move(FVertices^, VBPTR^, TotalVertices * FVertexSize);

  for i := 0 to TotalPrimitives - 1 do begin
    i1 := GetIndex(i*3+0, Indices);
    i2 := GetIndex(i*3+1, Indices);
    i3 := GetIndex(i*3+2, Indices);
    v1 := GetVertexDataC(i1, Vertices);
    v2 := GetVertexDataC(i2, Vertices);
    v3 := GetVertexDataC(i3, Vertices);

//    n := CrossProductVector3s(SubVector3s(v1, v3), SubVector3s(v2, v1));
    n := AddVector3s(SubVector3s(v1, v3), SubVector3s(v2, v1));
    n := NormalizeVector3s(n);

    Amp := TimeElapsed*FreqK*0.5+(Params.ModelMatrix.ViewTranslate.x+Params.ModelMatrix.ViewTranslate.z)*0.0009;
    t := Trunc(Amp);
    if t mod 2 = 0 then begin
      Amp := Amp - t;
      Amp := 1+2*Sin(Amp*pi)//(Amp * Ord(Amp < 0.5) + (1 - Amp) * Ord(Amp >= 0.5));
    end else Amp := 1;
    Freq := FreqK * (1+i1 mod 8);
    Amp := Amp * AmpK * (1+i2 mod 4);
    v1 := AddVector3s(V1, ScaleVector3s(n, Sin(TimeElapsed*Freq)*Amp));
    SetVertexDataC(V1, i1, VBPTR);
//    v2.Y := V2.Y + Sin(TimeElapsed*K)*amp;
//    SetVertexDataC(V2, i2, VBPTR);
//    v3.Y := V3.Y + Sin(TimeElapsed*K)*amp;
//    SetVertexDataC(V3, i3, VBPTR);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
//  Status := tsChanged;
  LastTotalIndices := TotalIndices;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

procedure TTreeAdjTesselator.AdjustMesh;
var i, i1, i2, i3: Integer; v1, v2, v3, e1, e2, e3: TVector3s;
  mult, OneOverRadius: Single;
begin
  if not Assigned(Vertices) or not Assigned(Indices) or (PrimitiveType <> ptTriangleList) then begin
    Log('TTreeAdjTesselator.AdjustMesh: Vertices or indices are not present or primitive type is not triangle list', lkError);
    Exit;
  end;

  if Abs(FRadius) > epsilon then
    OneOverRadius := 1/FRadius
  else
    OneOverRadius := 1;

  for i := 0 to TotalPrimitives - 1 do begin
    i1 := GetIndex(i*3+0, Indices);
    i2 := GetIndex(i*3+1, Indices);
    i3 := GetIndex(i*3+2, Indices);
    v1 := GetVertexDataC(i1, Vertices);
    v2 := GetVertexDataC(i2, Vertices);
    v3 := GetVertexDataC(i3, Vertices);

    mult := DotProductVector3s(v1, v1)*OneOverRadius;
    FDiffuse := BlendColor(GetColor(0), GetColor($FFFFFFFF), mult);
    SetVertexDataD(FDiffuse, i1, Vertices);

    mult := DotProductVector3s(v2, v2)*OneOverRadius;
    FDiffuse := BlendColor(GetColor(0), GetColor($FFFFFFFF), mult);
    SetVertexDataD(FDiffuse, i2, Vertices);

    mult := DotProductVector3s(v3, v3)*OneOverRadius;
    FDiffuse := BlendColor(GetColor(0), GetColor($FFFFFFFF), mult);
    SetVertexDataD(FDiffuse, i3, Vertices);
    if FAdjNormals then begin
      e1 := SubVector3s(v2, v1);
      e2 := SubVector3s(v3, v2);
      e3 := SubVector3s(v1, v3);
      SetVertexDataN(NormalizeVector3s(SubVector3s(e3, e1)), i1, Vertices);
      SetVertexDataN(NormalizeVector3s(SubVector3s(e1, e2)), i2, Vertices);
      SetVertexDataN(NormalizeVector3s(SubVector3s(e2, e3)), i3, Vertices);
    end;
  end;

  Inc(TimeElapsed);
  Invalidate([tbVertex], False);
end;

{ TTreeAdj }

function TTreeAdj.GetTesselatorClass: CTesselator; begin Result := TTreeAdjTesselator; end;

procedure TTreeAdj.Process(const DeltaT: Float);
begin
  inherited;
  if Assigned(CurrentTesselator) then TTreeAdjTesselator(CurrentTesselator).AdjustMesh;
end;

{ TTreeStem }

function TTreeStem.GetTesselatorClass: CTesselator; begin Result := TTreeStemTesselator; end;

{ TTreeStemTesselator }

procedure TTreeStemTesselator.Init;
begin
  inherited;
end;

procedure TTreeStemTesselator.AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  Result.Add('Width',  vtSingle, [], FloatToStr(Width),  '');
  Result.Add('Height', vtSingle, [], FloatToStr(Height), '');
  Result.Add('Sides',  vtInt,    [], IntToStr(Sides),    '');
  Result.Add('Levels', vtInt,    [], IntToStr(Levels),   '');
end;

procedure TTreeStemTesselator.SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid('Width')  then Width  := StrToFloatDef(Properties['Width'],  0);
  if Properties.Valid('Height') then Height := StrToFloatDef(Properties['Height'], 0);
  if Properties.Valid('Sides')  then Sides  := StrToIntDef(Properties['Sides'],    0);
  if Properties.Valid('Levels') then Levels := StrToIntDef(Properties['Levels'],   0);

  TotalVertices := Sides*6;
  TotalPrimitives := Sides*2;
end;

function TTreeStemTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer; c1, s1, c2, s2: Single;
begin
  for i := 0 to Sides-1 do begin
    c1 := Cos(i/180*pi*360/Sides);     s1 := Sin(i/180*pi*360/Sides);
    c2 := Cos((i+1)/180*pi*360/Sides); s2 := Sin((i+1)/180*pi*360/Sides);

    // First triangle of a side
    SetVertexDataC(c1*Width, Height, -s1*Width, i*6, VBPTR);
    SetVertexDataN(c1, 0, -s1, i*6, VBPTR);

    SetVertexDataC(c1*Width, 0, -s1*Width, i*6+1, VBPTR);
    SetVertexDataN(c1, 0, -s1, i*6+1, VBPTR);

    SetVertexDataC(c2*Width, 0, -s2*Width, i*6+2, VBPTR);
    SetVertexDataN(c2, 0, -s2, i*6+2, VBPTR);

    // Second triangle of a side
    SetVertexDataC(c1*Width, Height, -s1*Width, i*6+3, VBPTR);
    SetVertexDataN(c1, 0, -s1, i*6+3, VBPTR);

    SetVertexDataC(c2*Width, 0, -s2*Width, i*6+4, VBPTR);
    SetVertexDataN(c2, 0, -s2, i*6+4, VBPTR);

    SetVertexDataC(c2*Width, Height, -s2*Width, i*6+5, VBPTR);
    SetVertexDataN(c2, 0, -s2, i*6+5, VBPTR);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalIndices  := TotalIndices;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

begin
  GlobalClassList.Add('C2Flora', GetUnitClassList);
end.
