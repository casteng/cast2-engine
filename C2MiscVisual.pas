(*
 @Abstract(CAST II Engine miscellaneous visual items unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains miscellaneous classes of visual items
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2MiscVisual;

interface

uses
  SysUtils,
  Logger, 
  BaseTypes, Basics, Base3D, Props, BaseClasses, BaseCont, CAST2, C2VisItems, C2MiscTess, C2Materials, C2Visual;

type
  TScaledMeshTesselator = class(TMeshTesselator)
    Direction: TVector3s;
    constructor Create; override;
    function IsSameItem(AItem: TReferencedItem): Boolean; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TTree = class(TVisible)
    CurZA, ZAStep, MaxAngle: Single;
    constructor Create(AManager: TItemsManager); override;
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
    procedure Process(const DeltaT: Float); override;
  end;

  TColoredTree = class(TTree)
    EndColor: BaseTypes.TColor;
    BurningTime: Cardinal;
    Burning, Burned: Boolean;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
    procedure Process(const DeltaT: Float); override;
    procedure Burn; virtual;
    procedure StopBurn; virtual;
  protected
    BurningTimer: Cardinal;
  end;

implementation

{ TScaledMeshTesselator }

constructor TScaledMeshTesselator.Create;
begin
  Direction := GetVector3s(0, 0, 1);
  inherited;
end;

function TScaledMeshTesselator.IsSameItem(AItem: TReferencedItem): Boolean;
begin
  Result := False;
end;

function TScaledMeshTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer; DirP: Single;
begin
  LastTotalVertices := 0;
  Result := LastTotalVertices;
  if Vertices = nil then Exit;
  
  if not CompositeMember then begin
    for i := 0 to TotalVertices-1 do begin

      DirP := DotProductVector3s(TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^), Direction);

      TVector3s((@TByteBuffer(VBPTR^)[i*VertexSize])^) := SubVector3s(TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^), ScaleVector3s(Direction, DirP));

      Move(TByteBuffer(Vertices^)[i*VertexSize + SizeOf(TVector3s)], TByteBuffer(VBPTR^)[i*VertexSize + SizeOf(TVector3s)], VertexSize - SizeOf(TVector3s));
    end;
  end else begin
    Assert(CompositeOffset <> nil, 'Composite object''s offset is nil');
    for i := 0 to TotalVertices-1 do begin
      
      TVector3s((@TByteBuffer(VBPTR^)[i*VertexSize])^).X := TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^).X + CompositeOffset.X;
      TVector3s((@TByteBuffer(VBPTR^)[i*VertexSize])^).Y := TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^).Y + CompositeOffset.Y;
      TVector3s((@TByteBuffer(VBPTR^)[i*VertexSize])^).Z := TVector3s((@TByteBuffer(Vertices^)[i*VertexSize])^).Z + CompositeOffset.Z;

      Move(TByteBuffer(Vertices^)[i*VertexSize + SizeOf(TVector3s)], TByteBuffer(VBPTR^)[i*VertexSize + SizeOf(TVector3s)], VertexSize - SizeOf(TVector3s));
    end;
  end;

//  TesselationStatus[tbVertex].Status := tsTesselated;
  TesselationStatus[tbVertex].Status := tsChanged;
  LastTotalIndices := TotalIndices*1;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ TTree }

constructor TTree.Create(AManager: TItemsManager);
begin
  inherited;
  MaxAngle := 5/180*pi;
  CurZA := (Cos(Location.X/180*pi/200))*5/180*pi;
  ZAStep := (0.3)/180*pi;
  SetMesh;
end;

function TTree.GetTesselatorClass: CTesselator; begin Result := TWholeTreeMesh; end;

procedure TTree.AddProperties(const Result: Props.TProperties);
var Mesh: TWholeTreeMesh; Str: string;
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Tweening speed',     vtInt,     [], IntToStr(Round(ZAStep/pi*180*10)), '');
  Result.Add('Max. angle',         vtInt,     [], IntToStr(Round(MaxAngle/pi*180)), '');

  if not (CurrentTesselator is TWholeTreeMesh) then Exit;
  Mesh := CurrentTesselator as TWholeTreeMesh;

  Str := 'Geometry';

  Result.Add(Str + '\Smoothing',          vtInt,     [], IntToStr(Mesh.Smoothing),       '');
  Result.Add(Str + '\Levels',             vtInt,     [], IntToStr(Mesh.Levels),          '');
  Result.Add(Str + '\Level height',       vtSingle,  [], FloatToStr(Mesh.LevelHeight),    '');
  Result.Add(Str + '\Level stride',       vtSingle,  [], FloatToStr(Mesh.LevelStride),    '');
  Result.Add(Str + '\Inner radius',       vtSingle,  [], FloatToStr(Mesh.InnerRadius),    '');
  Result.Add(Str + '\Outer radius',       vtSingle,  [], FloatToStr(Mesh.OuterRadius),    '');
  Result.Add(Str + '\Inner radius step',  vtSingle,  [], FloatToStr(Mesh.IRadiusStep),    '');
  Result.Add(Str + '\Outer radius step',  vtSingle,  [], FloatToStr(Mesh.ORadiusStep),    '');
  Result.Add(Str + '\Stride factor',      vtSingle,  [], FloatToStr(Mesh.StrideFactor),   '');

  Result.Add('Texture\Crown UV radius',   vtSingle,  [], FloatToStr(Mesh.CrownUVRadius),  '');
  Result.Add(Str + '\Crown start',        vtSingle,  [], FloatToStr(Mesh.CrownStart),     '');

  Result.Add('Color',             vtBoolean, [], OnOffStr[Mesh.Colored], '');
  AddColorProperty(Result, 'Color\Stem',  Mesh.StemColor);
  AddColorProperty(Result, 'Color\Crown', Mesh.CrownColor);

  Str := Str + '\Stem';

  Result.Add(Str,                    vtBoolean, [], OnOffStr[Mesh.Stem],             '');
  Result.Add('Texture\U height',     vtSingle,  [], FloatToStr(Mesh.StemUHeight),    '');
  Result.Add('Texture\V height',     vtSingle,  [], FloatToStr(Mesh.StemVHeight),    '');
  Result.Add(Str + '\Bottom radius', vtSingle,  [], FloatToStr(Mesh.StemLowRadius),  '');
  Result.Add(Str + '\Top radius',    vtSingle,  [], FloatToStr(Mesh.StemHighRadius), '');
  Result.Add(Str + '\Height',        vtSingle,  [], FloatToStr(Mesh.StemHeight),     '');
end;

procedure TTree.SetProperties(Properties: Props.TProperties);
var Mesh: TWholeTreeMesh; Str: string;
begin
  inherited;

  if Properties.Valid('Tweening speed') then ZAStep := StrToIntDef(Properties['Tweening speed'], 0) / 180*pi/10;
  if Properties.Valid('Max. angle')     then MaxAngle := StrToIntDef(Properties['Max. angle'], 0)   / 180*pi;

  if not (CurrentTesselator is TWholeTreeMesh) then Exit;
  Mesh := CurrentTesselator as TWholeTreeMesh;

  Str := 'Geometry';

  if Properties.Valid(Str + '\Smoothing')         then Mesh.Smoothing    := StrToIntDef (Properties[Str + 'Smoothing'],         6);
  if Properties.Valid(Str + '\Levels')            then Mesh.Levels       := StrToIntDef (Properties[Str + 'Levels'],            3);
  if Properties.Valid(Str + '\Level height')      then Mesh.LevelHeight  := StrToFloatDef(Properties[Str + 'Level height'],      0.2);
  if Properties.Valid(Str + '\Level stride')      then Mesh.LevelStride  := StrToFloatDef(Properties[Str + 'Level stride'],      0.3);
  if Properties.Valid(Str + '\Inner radius')      then Mesh.InnerRadius  := StrToFloatDef(Properties[Str + 'Inner radius'],      0.4);
  if Properties.Valid(Str + '\Outer radius')      then Mesh.OuterRadius  := StrToFloatDef(Properties[Str + 'Outer radius'],      0.8);
  if Properties.Valid(Str + '\Inner radius step') then Mesh.IRadiusStep  := StrToFloatDef(Properties[Str + 'Inner radius step'], 0.08);
  if Properties.Valid(Str + '\Outer radius step') then Mesh.ORadiusStep  := StrToFloatDef(Properties[Str + 'Outer radius step'], 0.08);
  if Properties.Valid(Str + '\Stride factor')     then Mesh.StrideFactor := StrToFloatDef(Properties[Str + 'Stride factor'],     0.9);

  if Properties.Valid('Texture\Crown UV radius')  then Mesh.CrownUVRadius := StrToFloatDef(Properties['Texture\Crown UV radius'], 1.0);
  if Properties.Valid(Str + '\Crown start')       then Mesh.CrownStart    := StrToFloatDef(Properties[Str + '\Crown start'],      0.2);

  if Properties.Valid('Color')       then Mesh.Colored    := Properties.GetAsInteger('Color') > 0;
  SetColorProperty(Properties, 'Color\Stem',  Mesh.StemColor);
  SetColorProperty(Properties, 'Color\Crown', Mesh.CrownColor);

  Str := Str + '\Stem';

  if Properties.Valid(Str)                    then Mesh.Stem           := Properties.GetAsInteger(Str) > 0;
  if Properties.Valid('Texture\U height')     then Mesh.StemUHeight    := StrToFloatDef(Properties['Texture\U height'],       0.25);
  if Properties.Valid('Texture\V height')     then Mesh.StemVHeight    := StrToFloatDef(Properties['Texture\V height'],       0.25);
  if Properties.Valid(Str + '\Bottom radius') then Mesh.StemLowRadius  := StrToFloatDef(Properties[Str + '\Bottom radius'],   0.30);
  if Properties.Valid(Str + '\Top radius')    then Mesh.StemHighRadius := StrToFloatDef(Properties[Str + '\Top radius'],      0.10);
  if Properties.Valid(Str + '\Height')        then Mesh.StemHeight     := StrToFloatDef(Properties[Str + '\Height'],          1.00);

  SetMesh;

{  Mesh.SetParameters(Single(GetPropertyValue(AProperties, 'Level height')), Single(GetPropertyValue(AProperties, 'Level stride')),
                     Single(GetPropertyValue(AProperties, 'Inner radius')), Single(GetPropertyValue(AProperties, 'Outer radius')),
                     Single(GetPropertyValue(AProperties, 'Inner radius step')), Single(GetPropertyValue(AProperties, 'Outer radius step')),
                     Single(GetPropertyValue(AProperties, 'Height factor')),
                     Boolean(GetPropertyValue(AProperties, 'Stem')),
                     Single(GetPropertyValue(AProperties, 'Stem U height')), Single(GetPropertyValue(AProperties, 'Stem V height')),
                     Single(GetPropertyValue(AProperties, 'Crown UV radius')),
                     Single(GetPropertyValue(AProperties, 'Stem bottom radius')), Single(GetPropertyValue(AProperties, 'Stem top radius')),
                     Single(GetPropertyValue(AProperties, 'Stem height')),
                     Single(GetPropertyValue(AProperties, 'Crown start')),
                     Longword(GetPropertyValue(AProperties, 'Smooth')), Longword(GetPropertyValue(AProperties, 'Levels')));}
end;

procedure TTree.Process(const DeltaT: Float);
//var AbsPos: TVector3s; h: Single;
begin
  inherited;
//  Exit;
(*  if (World.Landscape <> nil) and (World.Landscape.HeightMap <> nil) then begin
    AbsPos := GetAbsLocation3s;
    h := World.Landscape.HeightMap.GetHeight(AbsPos.X, AbsPos.Z);
    if h > World.Landscape.HeightMap.MinHeight then begin
      if (AbsPos.Y - h > Epsilon) or (AbsPos.Y - h < -Epsilon) then
       SetLocation(GetVector3s(Location.X, Location.Y - (AbsPos.Y - h), Location.Z));
    end else SetLocation(GetVector3s(Location.X, Location.Y + World.GlobalForce.Y*10, Location.Z));
  end;
  CurZA := CurZA + ZAStep*5;
//  if Abs(CurZA) > 1 then ZAStep := -ZAStep;
  ModelMatrix1 := MulMatrix4s(ZRotationMatrix4s(Sin(CurZA)*MaxAngle), ModelMatrix);
  Result := True;*)
end;

{ TColoredTree }

procedure TColoredTree.AddProperties(const Result: Props.TProperties);
begin
  inherited;

  if Assigned(Result) then begin
    AddColorProperty(Result, 'Color\Final', EndColor);
    Result.Add('Burning\Time',     vtInt,        [], IntToStr(BurningTime),        '');
  end;  

  AddItemLink(Result, 'Burning\Material', [], 'TMaterial');
end;

procedure TColoredTree.SetProperties(Properties: Props.TProperties);
begin
  inherited;

  SetColorProperty(Properties, 'Color\Final', EndColor);
  if Properties.Valid('Burning\Time')     then BurningTime         := StrToIntDef(Properties['Burning\Time'], 0);

  if Properties.Valid('Burning\Material') then SetLinkProperty('Burning\Material', Properties['Burning\Material']);

  SetMesh;

  Burned := False;
  Burning := False;

//  if BurningMaterialName <> '' then Burn;
end;

procedure TColoredTree.Process(const DeltaT: Float);
var Mesh: TWholeTreeMesh;
begin
  inherited;
  if not Burning then Exit;

  Mesh := CurrentTesselator as TWholeTreeMesh;
  Mesh.StemColor := BlendColor(Mesh.StemColor, EndColor, 1 - BurningTimer/BurningTime);
  Mesh.CrownColor := BlendColor(Mesh.CrownColor, EndColor, 1 - BurningTimer/BurningTime);
  Mesh.Invalidate([tbVertex], False);
  if BurningTimer > 0 then Dec(BurningTimer) else StopBurn;
end;

procedure TColoredTree.Burn;
//var i: Integer;
begin
  if (BurningTime <= 0) or Burned then Exit;
//  if not Burning then MatName := BurningMaterialName;
  Burning := True;
  BurningTimer := BurningTime + Trunc(0.5 + (Random*2-1) * BurningTime * 0.1);

  CurZA := 0; MaxAngle := MaxAngle * 0.5;

{  for i := 0 to TotalChilds-1 do if Childs[i] is TParticleSystem then begin
    Childs[i].Status := Childs[i].Status or isProcessing or isVisible;
    Childs[i].Init;
  end;}
end;

procedure TColoredTree.StopBurn;
//var i: Integer;
begin
  Burning := False;
  Burned := True;
{  for i := 0 to TotalChilds-1 do if Childs[i] is TParticleSystem then begin
    (Childs[i] as TParticleSystem).DisableEmit := True;
  end;}
end;

end.

