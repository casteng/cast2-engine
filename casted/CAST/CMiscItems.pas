{$Include GDefines}
{$Include CDefines}
unit CMiscItems;

interface

uses
  SysUtils,
  Basics, Base3D, CTypes, CAST, CTess, CMiscTess, CMaps, CRender, CRes, CFX;

const
// Fade states
  fsNone = 0; fsFadeIn = 1; fsFadeOut = 2;

type
  TTree = class(TItem)
    CurZA, ZAStep, MaxAngle: Single;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    procedure SetLocation(ALocation: TVector3s); override;
    procedure SetMesh; override;
    function Process: Boolean; override;
  end;

  TColoredTree = class(TTree)
    EndColor: Cardinal;
    BurningTime: Cardinal;
    BurningMaterialName: TShortName;
    Burning, Burned: Boolean;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Process: Boolean; override;
    procedure Burn; virtual;
    procedure StopBurn; virtual;
  protected
    StemColor, CrownColor: Cardinal;
    BurningTimer: Cardinal;    
  end;

  TGrass = class(TItem)
    CurZA, ZAStep, MaxAngle: Single;
    GrassPBase: Integer;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(Properties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    procedure SetLocation(ALocation: TVector3s); override;
    procedure SetMesh; override;
    function Process: Boolean; override;
  end;

  TDome = class(TItem)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetMesh; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  end;

  TFXDome = class(TDome)
    procedure SetMesh; override;
    function Process: Boolean; override;
  end;

  TWheelTrace = class(TItem)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(Properties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    procedure AddPoint(const APoint: TVector3s); virtual;
    procedure Clear; virtual;
  private
    FHMap: TMap;
    procedure SetHMap(const Value: TMap);
  public
    property HMap: TMap read FHMap write SetHMap;
  end;

  TRock = class(TItem)
    PResIndex: Integer;
    Color: Longword;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(Properties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    procedure SetLocation(ALocation: TVector3s); override;
  private
    FHMap: TMap;
    procedure SetHMap(const Value: TMap);
  public
    property HMap: TMap read FHMap write SetHMap;
  end;

  TWater = class(TItem)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
  end;

  TPlane = class(TItem)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetMesh; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Process: Boolean; override;
  private
    function GetColor: Longword;
    function GetHeight: Single;
    function GetWidth: Single;
    procedure SetColor(const Value: Longword);
    procedure SetHeight(const Value: Single);
    procedure SetWidth(const Value: Single);
  public
    property Width: Single read GetWidth write SetWidth;
    property Height: Single read GetHeight write SetHeight;
    property Color: Longword read GetColor write SetColor;
  end;

  TGrid = class(TItem)
    AttachedToCamera, FixedY: Boolean;
    BasicUOfs, CurUOfs, BasicVOfs, CurVOfs: Single;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Process: Boolean; override;
    function GetLocation: TVector3s; override;
    procedure Render(Renderer: TRenderer); override;
    procedure SetLocation(ALocation: TVector3s); override;
    function GetCenterColor: Longword;
    function GetSideColor: Longword;
    procedure SetCenterColor(const Value: Longword);
    procedure SetSideColor(const Value: Longword);
  protected
    GridPBase, GeomPBase: Integer;
    SetPlace: Boolean;
    Place: TVector3s;
  public
    property CenterColor: Longword read GetCenterColor write SetCenterColor;
    property SideColor: Longword read GetSideColor write SetSideColor;
  end;

  TRing = class(TItem)
    YAngle: Single;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetMesh; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Process: Boolean; override;
  private
    function GetColor: Longword;
    procedure SetColor(const Value: Longword);
  public
    property Color: Longword read GetColor write SetColor;
  end;

  TFader = class(TItem)
    FadeState: Cardinal;
    CurAlpha: Single;                 // Current alpha while fading
    procedure Show; override;
    procedure Hide; override;
    function Process: Boolean; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
  private
    FColor: Longword;
    FadeinSpeed, FadeoutSpeed: Single;
    Flash: Boolean;            
    procedure SetColor(const Value: Longword);
  public
    property Color: Longword read FColor write SetColor;
  end;

  TBackground = class(TFader)
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;

    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Process: Boolean; override;

    function GetAngle: Integer;
    function GetZoom: Single;
    procedure SetColor(const Value: Longword);
    procedure SetAngle(const Value: Integer);
    procedure SetZoom(const Value: Single);
  public
    property Angle: Integer read GetAngle write SetAngle;
    property Zoom: Single read GetZoom write SetZoom;
  end;

implementation
 uses Logger, Math; 

{ TTree }

constructor TTree.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  MeshClass := TWholeTreeMesh;
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmINVSRCALPHA, tfLessEqual, tfGreater, 0, True, True);
//  SetMesh(-1 ,-1);
  MaxAngle := 5/180*pi;
  CurZA := (Cos(Location.X/180*pi/200))*5/180*pi;
  ZAStep := (0.3)/180*pi;
  CullMode := cmNone;
  SetMesh;
{  LHMapWidth := 3; LHMapHeight := 3;
  GetMem(LocalHeightMap, LHMapWidth * LHMapHeight);
  FillChar(LocalHeightMap^, LHMapWidth * LHMapHeight, 32);
  LocalHeightMap^[1] := 32;
  LocalHeightMap^[1*3] := 32; LocalHeightMap^[1*3+2] := 32;
  LocalHeightMap^[2*3+0] := 16; LocalHeightMap^[2*3+1] := 32; LocalHeightMap^[2*3+2] := 16;
  LocalHeightMap^[1*3+1] := 48;}
end;

function TTree.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Tweening speed', ptInt32, Pointer(Round(ZAStep/pi*180*10)));
  NewProperty(Result, 'Max. angle', ptInt32, Pointer(Round(MaxAngle/pi*180)));
  NewProperty(Result, 'Geometry', ptGroupBegin, nil);
    NewProperty(Result, 'Level height', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).LevelHeight));
    NewProperty(Result, 'Level stride', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).LevelStride));
    NewProperty(Result, 'Inner radius', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).InnerRadius));
    NewProperty(Result, 'Outer radius', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).OuterRadius));
    NewProperty(Result, 'Inner radius step', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).IRadiusStep));
    NewProperty(Result, 'Outer radius step', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).ORadiusStep));
    NewProperty(Result, 'Height factor', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).StrideFactor));
    NewProperty(Result, 'Stem', ptBoolean, Pointer(TWholeTreeMesh(CurrentLOD).RenderStem));
    NewProperty(Result, 'Stem U height', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).StemUHeight));
    NewProperty(Result, 'Stem V height', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).StemVHeight));
    NewProperty(Result, 'Crown UV radius', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).CrownUVRadius));
    NewProperty(Result, 'Stem bottom radius', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).StemLowRadius));
    NewProperty(Result, 'Stem top radius', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).StemHighRadius));
    NewProperty(Result, 'Stem height', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).StemHeight));
    NewProperty(Result, 'Crown start', ptSingle, Pointer(TWholeTreeMesh(CurrentLOD).CrownStart));
    NewProperty(Result, 'Smooth', ptNat32, Pointer(TWholeTreeMesh(CurrentLOD).Smoothing));
    NewProperty(Result, 'Levels', ptNat32, Pointer(TWholeTreeMesh(CurrentLOD).Levels));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TTree.SetProperties(AProperties: TProperties): Integer;
var Mesh: TWholeTreeMesh;
begin
  Result := -1;
  CullMode := cmNone;
  if inherited SetProperties(AProperties) < 0 then Exit;

  ZAStep := Integer(GetPropertyValue(AProperties, 'Tweening speed'))/180/10*pi;
  MaxAngle := Longword(GetPropertyValue(AProperties, 'Max. angle'))/180*pi;

  ClearMeshes;
//  MeshClass := TWholeTreeMesh;
  Mesh := MeshClass.Create('') as TWholeTreeMesh;
//  Mesh := TWholeTreeMesh.Create('') as TWholeTreeMesh;
  Mesh.SetParameters(Single(GetPropertyValue(AProperties, 'Level height')), Single(GetPropertyValue(AProperties, 'Level stride')),
                     Single(GetPropertyValue(AProperties, 'Inner radius')), Single(GetPropertyValue(AProperties, 'Outer radius')),
                     Single(GetPropertyValue(AProperties, 'Inner radius step')), Single(GetPropertyValue(AProperties, 'Outer radius step')),
                     Single(GetPropertyValue(AProperties, 'Height factor')),
                     Boolean(GetPropertyValue(AProperties, 'Stem')),
                     Single(GetPropertyValue(AProperties, 'Stem U height')), Single(GetPropertyValue(AProperties, 'Stem V height')),
                     Single(GetPropertyValue(AProperties, 'Crown UV radius')),
                     Single(GetPropertyValue(AProperties, 'Stem bottom radius')), Single(GetPropertyValue(AProperties, 'Stem top radius')),
                     Single(GetPropertyValue(AProperties, 'Stem height')),
                     Single(GetPropertyValue(AProperties, 'Crown start')),
                     Longword(GetPropertyValue(AProperties, 'Smooth')), Longword(GetPropertyValue(AProperties, 'Levels')));
  AddLOD(World.AddMesh(Mesh));

  Result := 0;
end;

procedure TTree.SetLocation(ALocation: TVector3s);
var AbsPos: TVector3s;
begin
  Location := ALocation;
  inherited SetLocation(Location);
//  CurZA := (Random-0.5)*10/180*pi;
//  CurZA := (Cos(Location.X/180*pi/200))*MaxAngle;
  CurZA := Random*2-1;
  ModelMatrix1 := MulMatrix4s(ZRotationMatrix4s(CurZA), ModelMatrix);
end;

procedure TTree.SetMesh;
begin
  ClearMeshes;
  AddLOD(World.AddMesh(MeshClass.Create('')));
end;

function TTree.Process: Boolean;
var AbsPos: TVector3s; h: Single;
begin
  Result := inherited Process;
//  Exit;
  if (World.Landscape <> nil) and (World.Landscape.HeightMap <> nil) then begin
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
  Result := True;
end;

{ TGrass }

constructor TGrass.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  ClearRenderPasses;
  AddRenderPass(bmSrcAlpha, bmINVSRCALPHA, tfLessEqual, tfGreater, 0, True, True);
//  SetMesh(-1 ,-1);
  MaxAngle := 45/180*pi;
  CurZA := (Cos(Location.X/180*pi/20))*MaxAngle;
  ZAStep := (5)/180*pi;
end;

function TGrass.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  GrassPBase := NewProperty(Result, 'Tweening speed', ptInt32, Pointer(Round(ZAStep/pi*180*10)));
  NewProperty(Result, 'Max. angle', ptInt32, Pointer(Round(MaxAngle/pi*180)));
  NewProperty(Result, 'Grass color', ptColor32, Pointer(TGrassMesh(CurrentLOD).GrassColor));
  NewProperty(Result, 'Geometry', ptGroupBegin, nil);
    NewProperty(Result, 'Height', ptInt32, Pointer(TGrassMesh(CurrentLOD).Height));
    NewProperty(Result, 'Radius', ptInt32, Pointer(TGrassMesh(CurrentLOD).Radius));
    NewProperty(Result, 'Levels', ptNat32, Pointer(TGrassMesh(CurrentLOD).Levels));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TGrass.SetProperties(Properties: TProperties): Integer;
var Mesh: TGrassMesh;
begin
  Result := -1;
  if inherited SetProperties(Properties) < 0 then Exit;

  ZAStep := Integer(Properties[GrassPBase + 0].Value)/180/10*pi;
  MaxAngle := Longword(Properties[GrassPBase + 1].Value)/180*pi;

  ClearMeshes;
  Mesh := TGrassMesh.Create('');
//  Mesh.SetParameters(Integer(Properties[GeomPBase + 1].Value), Integer(Properties[GeomPBase + 2].Value),
//                     Longword(Properties[GeomPBase + 3].Value), Longword(Properties[GrassPBase + 2].Value));
  AddLOD(World.AddMesh(Mesh));

  Result := 0;
end;

procedure TGrass.SetLocation(ALocation: TVector3s);
begin
  Location := ALocation;
  if World.Landscape <> nil then Location.Y := World.Landscape.HeightMap.GetHeight(Location.X, Location.Z);
  inherited SetLocation(Location);
//  CurZA := (Random-0.5)*10/180*pi;
  CurZA := (Cos(Location.X/180*pi/20))*MaxAngle;
end;

procedure TGrass.SetMesh;
begin
  ClearMeshes;
  AddLOD(World.AddMesh(TGrassMesh.Create('Grass mesh')));
end;

function TGrass.Process: Boolean;
begin
  Result := inherited Process;
//  Exit;
//  if World.Landscape.Mesh <> nil then Location.Y := World.Landscape.HeightMap.GetHeight(Location.X, Location.Z);
  CurZA := CurZA + ZAStep;
  if Abs(CurZA) > MaxAngle then ZAStep := -ZAStep;
  ModelMatrix1 := MulMatrix4s(ZRotationMatrix4s(CurZA), ModelMatrix);
  Result := True;
end;

{ TDome }

constructor TDome.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfGREATER, 0, True, True);
  CullMode := cmNone;
//  SetMesh(-1 ,-1);
end;

procedure TDome.SetMesh;
begin
  ClearMeshes;
  AddLOD(World.AddMesh(TDomeTesselator.Create('')));
end;

function TDome.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Sectors', ptInt32, Pointer(TDomeTesselator(CurrentLOD).Sectors));
  NewProperty(Result, 'Segments', ptInt32, Pointer(TDomeTesselator(CurrentLOD).Segments));
  NewProperty(Result, 'Radius', ptInt32, Pointer(TDomeTesselator(CurrentLOD).Radius));
  NewProperty(Result, 'Height', ptInt32, Pointer(TDomeTesselator(CurrentLOD).Height));
  NewProperty(Result, 'UV scale', ptSingle, Pointer(TDomeTesselator(CurrentLOD).UVScale));
  NewProperty(Result, 'Color', ptColor32, Pointer(TDomeTesselator(CurrentLOD).Color));
  NewProperty(Result, 'Inner dome surface', ptBoolean, Pointer(TDomeTesselator(CurrentLOD).Inner));
end;

function TDome.SetProperties(AProperties: TProperties): Integer;
var Mesh: TDomeTesselator;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  SetMesh;
  Mesh := CurrentLOD as TDomeTesselator;
  Mesh.SetParameters(Longword(GetPropertyValue(AProperties, 'Sectors')),
                     Longword(GetPropertyValue(AProperties, 'Segments')),
                     Longword(GetPropertyValue(AProperties, 'Radius')),
                     Longword(GetPropertyValue(AProperties, 'Height')),
                     Single(GetPropertyValue(AProperties, 'UV scale')),
                     Longword(GetPropertyValue(AProperties, 'Color')),
                     Boolean(GetPropertyValue(AProperties, 'Inner dome surface')));

  Result := 0;
end;

{ TWater }

constructor TWater.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited Create(AName, AWorld, AParent);
  AddLOD(TWaterTesselator.Create('WaterMesh'));
  Order := -500;
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, True, True);
//  TSkyDomeTesselator(CurrentLOD).SetParameters(16, 32, 65536, 65536, ZenithColor, HorizonColor);
//  Status := Status or isUnique;
end;

{ TWheelTrace }

constructor TWheelTrace.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  AddLOD(TWheelTraceTesselator.Create('WheelTraceMesh'));
//  Order := 1;
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, True, True);
end;

procedure TWheelTrace.AddPoint(const APoint: TVector3s);
begin
  TWheelTraceTesselator(CurrentLOD).AddPoint(APoint);
end;

procedure TWheelTrace.Clear;
begin
  TWheelTraceTesselator(CurrentLOD).Clear;
end;

procedure TWheelTrace.SetHMap(const Value: TMap);
begin
  FHMap := Value;
  TWheelTraceTesselator(CurrentLOD).HMap := FHMap;
end;

function TWheelTrace.GetProperties: TProperties;
var OldLen: Integer;
begin
  Result := inherited GetProperties;
  OldLen := Length(Result);
  SetLength(Result, OldLen + 3);

  Result[OldLen + 0].Name := 'Width';
  Result[OldLen + 0].ValueType := ptInt32;
  Result[OldLen + 0].Value := Pointer(TWheelTraceTesselator(CurrentLOD).Size);

  Result[OldLen + 1].Name := 'Color';
  Result[OldLen + 1].ValueType := ptColor32;
  Result[OldLen + 1].Value := Pointer(TWheelTraceTesselator(CurrentLOD).Color);

  Result[OldLen + 2].Name := 'Clearance';
  Result[OldLen + 2].ValueType := ptSingle;
  Result[OldLen + 2].Value := Pointer(TWheelTraceTesselator(CurrentLOD).Bias);
end;

function TWheelTrace.SetProperties(Properties: TProperties): Integer;
var OldLen: Integer;
begin
  Result := -1;
  OldLen := inherited SetProperties(Properties);
  if OldLen < 0 then Exit;
  if Length(Properties) - OldLen < 3 then Exit;
  if Properties[OldLen + 0].ValueType <> ptInt32 then Exit;
  if Properties[OldLen + 1].ValueType <> ptColor32 then Exit;
  if Properties[OldLen + 2].ValueType <> ptSingle then Exit;

  TWheelTraceTesselator(CurrentLOD).Size := Integer(Properties[OldLen + 0].Value);
  TWheelTraceTesselator(CurrentLOD).Color := Longword(Properties[OldLen + 1].Value);
  TWheelTraceTesselator(CurrentLOD).Bias := Single(Properties[OldLen + 2].Value);

  Result := OldLen + 3;
end;

{ TRock }

constructor TRock.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  AddLOD(TRockTesselator.Create('RockMesh'));
//  Order := 1;
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, True, True);
  Color := $FFFFFFFF;
end;

function TRock.GetProperties: TProperties;
var OldLen: Integer;
begin
  Result := inherited GetProperties;
  OldLen := Length(Result);
  SetLength(Result, OldLen + 10);
{  AHeight, ALeftTransHeight, ARightTransHeight, ALeftTransLength, ALeftLength,
  ARightTransLength, ARightLength: Integer; AUK: Single; AColor: Longword;
  ATotalPoints: Integer; APoints: Pointer);}

  Result[OldLen + 0].Name := 'Height';
  Result[OldLen + 0].ValueType := ptInt32;
  Result[OldLen + 0].Value := Pointer(0);

  Result[OldLen + 1].Name := 'Left transfer height';
  Result[OldLen + 1].ValueType := ptInt32;
  Result[OldLen + 1].Value := Pointer(TRockTesselator(CurrentLOD).LeftTransHeight);

  Result[OldLen + 2].Name := 'Right transfer height';
  Result[OldLen + 2].ValueType := ptInt32;
  Result[OldLen + 2].Value := Pointer(TRockTesselator(CurrentLOD).RightTransHeight);

  Result[OldLen + 3].Name := 'Left transfer lenght';
  Result[OldLen + 3].ValueType := ptInt32;
  Result[OldLen + 3].Value := Pointer(TRockTesselator(CurrentLOD).LeftTransLength);

  Result[OldLen + 4].Name := 'Right transfer lenght';
  Result[OldLen + 4].ValueType := ptInt32;
  Result[OldLen + 4].Value := Pointer(TRockTesselator(CurrentLOD).RightTransLength);

  Result[OldLen + 5].Name := 'Left Length';
  Result[OldLen + 5].ValueType := ptInt32;
  Result[OldLen + 5].Value := Pointer(TRockTesselator(CurrentLOD).LeftLength);

  Result[OldLen + 6].Name := 'Right Length';
  Result[OldLen + 6].ValueType := ptInt32;
  Result[OldLen + 6].Value := Pointer(TRockTesselator(CurrentLOD).RightLength);

  Result[OldLen + 7].Name := 'Texture U scale';
  Result[OldLen + 7].ValueType := ptSingle;
  Result[OldLen + 7].Value := Pointer(TRockTesselator(CurrentLOD).UK);

  Result[OldLen + 8].Name := 'Color';
  Result[OldLen + 8].ValueType := ptColor32;
  Result[OldLen + 8].Value := Pointer(TRockTesselator(CurrentLOD).Color);

  Result[OldLen + 9].Name := 'Path resource';
  Result[OldLen + 9].ValueType := ptResource + World.ResourceManager.GetResourceClassIndex('TPathResource') shl 8;
  Result[OldLen + 9].Value := Pointer(PResIndex);
end;

function TRock.SetProperties(Properties: TProperties): Integer;
var i, TotalPoints: Integer; OldLen, Segments: Integer; PointsData: Pointer;
begin
  Result := -1;
  OldLen := inherited SetProperties(Properties);
  if OldLen < 0 then Exit;
  if Length(Properties) - OldLen < 10 then Exit;
  if Properties[OldLen + 0].ValueType <> ptInt32 then Exit;
  if Properties[OldLen + 1].ValueType <> ptInt32 then Exit;
  if Properties[OldLen + 2].ValueType <> ptInt32 then Exit;
  if Properties[OldLen + 3].ValueType <> ptInt32 then Exit;
  if Properties[OldLen + 4].ValueType <> ptInt32 then Exit;
  if Properties[OldLen + 5].ValueType <> ptInt32 then Exit;
  if Properties[OldLen + 6].ValueType <> ptInt32 then Exit;
  if Properties[OldLen + 7].ValueType <> ptSingle then Exit;
  if Properties[OldLen + 8].ValueType <> ptColor32 then Exit;
  if Properties[OldLen + 9].ValueType <> ptResource + World.ResourceManager.GetResourceClassIndex('TPathResource') shl 8 then Exit;

  PResIndex := Integer(Properties[OldLen + 9].Value);

  if PResIndex <> -1 then begin
    PointsData := World.ResourceManager[PResIndex].Data;
    TotalPoints := TPathResource(World.ResourceManager[PResIndex]).TotalElements
  end else begin
    TotalPoints := 0; PointsData := nil;
  end;


  TRockTesselator(CurrentLOD).SetParameters(
                                            Integer(Properties[OldLen + 1].Value), Integer(Properties[OldLen + 2].Value),
                                            Integer(Properties[OldLen + 3].Value), Integer(Properties[OldLen + 5].Value),
                                            Integer(Properties[OldLen + 4].Value), Integer(Properties[OldLen + 6].Value),
                                            Single(Properties[OldLen + 7].Value),
                                            Longword(Properties[OldLen + 8].Value),
                                            TotalPoints, PointsData);

  Result := OldLen + 10;
end;

procedure TRock.SetLocation(ALocation: TVector3s);
begin
  inherited;
  TRockTesselator(CurrentLOD).Angle := Orientation.Y;
  TRockTesselator(CurrentLOD).Loc := ALocation;
  CurrentLOD.Invalidate(False);
end;

procedure TRock.SetHMap(const Value: TMap);
begin
  FHMap := Value;
  TRockTesselator(CurrentLOD).HMap := Value;
end;

{ TPlane }

constructor TPlane.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited Create(AName, AWorld, AParent);
  SetMesh;
  Order := -400;
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, True, True);
end;

procedure TPlane.SetMesh;
begin
  ClearMeshes;
  AddLOD(World.AddMesh(TPlaneTesselator.Create('')));
end;

function TPlane.GetColor: Longword;
begin
  Result := TPlaneTesselator(CurrentLOD).Color;
end;

function TPlane.GetWidth: Single;
begin
  Result := TPlaneTesselator(CurrentLOD).Width;
end;

function TPlane.GetHeight: Single;
begin
  Result := TPlaneTesselator(CurrentLOD).Height;
end;

procedure TPlane.SetColor(const Value: Longword);
begin
  TPlaneTesselator(CurrentLOD).Color := Value;
  CurrentLOD.Invalidate(False);
end;

procedure TPlane.SetHeight(const Value: Single);
begin
  TPlaneTesselator(CurrentLOD).Height := Value;
  CurrentLOD.Invalidate(False);
end;

procedure TPlane.SetWidth(const Value: Single);
begin
  TPlaneTesselator(CurrentLOD).Width := Value;
  CurrentLOD.Invalidate(False);
end;

function TPlane.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Color', ptColor32, Pointer(Color));
  NewProperty(Result, 'Width', ptSingle, Pointer(Width));
  NewProperty(Result, 'Height', ptSingle, Pointer(Height));
  NewProperty(Result, 'Texture repeats in width', ptSingle, Pointer(TPlaneTesselator(CurrentLOD).TexturesWidth));
  NewProperty(Result, 'Texture repeats in height', ptSingle, Pointer(TPlaneTesselator(CurrentLOD).TexturesHeight));
  NewProperty(Result, 'Texture U shift speed', ptSingle, Pointer(TPlaneTesselator(CurrentLOD).UShift));
  NewProperty(Result, 'Texture V shift speed', ptSingle, Pointer(TPlaneTesselator(CurrentLOD).VShift));
end;

function TPlane.Process: Boolean;
var Mesh: TPlanetesselator;
begin
  Result := inherited Process;
  Mesh := TPlaneTesselator(CurrentLOD);
  Mesh.UOfs := Mesh.UOfs + Mesh.UShift;
  if Mesh.UOfs > 1 then Mesh.UOfs := Mesh.UOfs-1;
  Mesh.VOfs := Mesh.VOfs + Mesh.VShift;
  if Mesh.VOfs > 1 then Mesh.VOfs := Mesh.VOfs-1;
  Mesh.Invalidate(False);
end;

function TPlane.SetProperties(AProperties: TProperties): Integer;
var Mesh: TPlaneTesselator;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;

  Mesh := TPlaneTesselator(CurrentLOD);

  ClearMeshes;
  Mesh := TPlaneTesselator.Create('');
  Mesh.SetParameters(Longword(GetPropertyValue(AProperties, 'Color')),
                     Single(GetPropertyValue(AProperties, 'Width')), Single(GetPropertyValue(AProperties, 'Height')),
                     Single(GetPropertyValue(AProperties, 'Texture repeats in width')), Single(GetPropertyValue(AProperties, 'Texture repeats in height')),
                     Single(GetPropertyValue(AProperties, 'Texture U shift speed')), Single(GetPropertyValue(AProperties, 'Texture V shift speed')));
  AddLOD(World.AddMesh(Mesh));
end;

{ TGrid }

constructor TGrid.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited Create(AName, AWorld, AParent);
  AddLOD(TGridTesselator.Create(''));
  Order := -200;
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, True, True);
  CullMode := cmNone;
  SetPlace := True;
  BasicUOfs := 0; BasicVOfs := 0;
end;

function TGrid.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  GridPBase := NewProperty(Result, 'Attached to camera', ptBoolean, Pointer(AttachedToCamera));
  NewProperty(Result, 'Fixed Y', ptBoolean, Pointer(FixedY));
  NewProperty(Result, 'Grid center color', ptColor32, Pointer(TGridTesselator(CurrentLOD).CenterColor));
  NewProperty(Result, 'Grid side color', ptColor32, Pointer(TGridTesselator(CurrentLOD).SideColor));
  GeomPBase := NewProperty(Result, 'Geometry', ptGroupBegin, nil);
    NewProperty(Result, 'Grid sectors', ptInt32, Pointer(TGridTesselator(CurrentLOD).Sectors));
    NewProperty(Result, 'Grid radius', ptSingle, Pointer(TGridTesselator(CurrentLOD).Radius));
    NewProperty(Result, 'Texture repeats in width', ptSingle, Pointer(TGridTesselator(CurrentLOD).TexturesWidth));
    NewProperty(Result, 'Texture repeats in height', ptSingle, Pointer(TGridTesselator(CurrentLOD).TexturesHeight));
    NewProperty(Result, 'Texture U shift speed', ptSingle, Pointer(TGridTesselator(CurrentLOD).UShift));
    NewProperty(Result, 'Texture V shift speed', ptSingle, Pointer(TGridTesselator(CurrentLOD).VShift));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TGrid.SetProperties(AProperties: TProperties): Integer;
var Mesh: TGridTesselator;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  AttachedToCamera := Boolean(GetPropertyValue(AProperties, 'Attached to camera'));
  FixedY := Boolean(GetPropertyValue(AProperties, 'Fixed Y'));

  Mesh := TGridTesselator(CurrentLOD);

//  ClearMeshes;
//  Mesh := TGridTesselator.Create('');
  Mesh.SetParameters(Longword(GetPropertyValue(AProperties, 'Grid center color')), Longword(GetPropertyValue(AProperties, 'Grid side color')),
                     Integer(GetPropertyValue(AProperties, 'Grid sectors')), Single(GetPropertyValue(AProperties, 'Grid radius')),
                     Single(GetPropertyValue(AProperties, 'Texture repeats in width')), Single(GetPropertyValue(AProperties, 'Texture repeats in height')),
                     Single(GetPropertyValue(AProperties, 'Texture U shift speed')), Single(GetPropertyValue(AProperties, 'Texture V shift speed')));

  BasicUOfs := 0; BasicVOfs := 0;
  CurUOfs := 0; CurVOfs := 0;
//  AddLOD(World.AddMesh(Mesh));
  Result := 0;
end;

function TGrid.Process: Boolean;
var Mesh: TGridTesselator;
begin
  Result := inherited Process;
  Mesh := TGridTesselator(CurrentLOD);

  Mesh.UOfs := BasicUOfs + CurUOfs;
  CurUOfs := CurUOfs + Mesh.UShift;
  if Mesh.UOfs > 2 then CurUOfs := CurUOfs-2;

  Mesh.VOfs := BasicVOfs + CurVOfs;
  CurVOfs := CurVOfs + Mesh.VShift;
  if Mesh.VOfs > 2 then CurVOfs := CurVOfs-2;

  Mesh.Invalidate(False);
end;

procedure TGrid.Render(Renderer: TRenderer);
begin
  SetPlace := False;
  if AttachedToCamera then
   SetLocation(GetVector3s(Place.X + World.Renderer.RenderPars.Camera.X, Place.Y + Byte(not FixedY)*World.Renderer.RenderPars.Camera.Y, Place.Z + World.Renderer.RenderPars.Camera.Z));
  SetPlace := True;
  inherited;
end;

procedure TGrid.SetLocation(ALocation: TVector3s);
begin
  inherited;
  if SetPlace then Place := Location;
end;

function TGrid.GetLocation: TVector3s;
begin
  Result := Place;
end;

function TGrid.GetCenterColor: Longword;
begin
  Result := TGridTesselator(CurrentLOD).CenterColor;
end;

function TGrid.GetSideColor: Longword;
begin
  Result := TGridTesselator(CurrentLOD).SideColor;
end;

procedure TGrid.SetCenterColor(const Value: Longword);
begin
  TGridTesselator(CurrentLOD).CenterColor := Value;
  TGridTesselator(CurrentLOD).Invalidate(False);
end;

procedure TGrid.SetSideColor(const Value: Longword);
begin
  TGridTesselator(CurrentLOD).SideColor := Value;
  TGridTesselator(CurrentLOD).Invalidate(False);
end;

{ TFXDome }

procedure TFXDome.SetMesh;
begin
  ClearMeshes;
  AddLOD(World.AddMesh(TFXDomeTesselator.Create('')));
end;

function TFXDome.Process: Boolean;
var Mesh: TFXDomeTesselator;
begin
  Result := inherited Process;
  if CurrentLOD <> nil then begin
    Mesh := (CurrentLOD as TFXDomeTesselator);
    Mesh.CurrentTick := TicksProcessed;
    Mesh.Invalidate(False);
  end;
end;

{ TFader }

function TFader.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Color', ptColor32, Pointer(FColor));
  NewProperty(Result, 'Fadein speed', ptSingle, Pointer(FadeinSpeed));
  NewProperty(Result, 'Fadeout speed', ptSingle, Pointer(FadeoutSpeed));
  NewProperty(Result, 'Flash', ptBoolean, Pointer(Flash));
end;

function TFader.SetProperties(AProperties: TProperties): Integer;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;

  SetColor(Longword(GetPropertyValue(AProperties, 'Color')));
  FadeinSpeed := Single(GetPropertyValue(AProperties, 'Fadein speed'));
  FadeoutSpeed := Single(GetPropertyValue(AProperties, 'Fadeout speed'));
  Flash := Boolean(GetPropertyValue(AProperties, 'Flash'));
end;

procedure TFader.Show;
begin
  inherited;
  FadeState := fsFadeIn;
  Status := Status or isProcessing;          // Enable processing
end;

procedure TFader.Hide;
begin
  if FadeState <> fsNone then begin
//    inherited;
  end else begin
    CurAlpha := 1;
  end;
  FadeState := fsFadeOut;
end;

function TFader.Process: Boolean;
begin
  Result := inherited Process;

  case FadeState of
    fsFadeIn: if CurAlpha < 1-FadeinSpeed then
     CurAlpha := CurAlpha + FadeinSpeed else begin
       CurAlpha := 1;
       FadeState := fsNone;
       if Flash then Hide;
     end;
    fsFadeOut: if CurAlpha > FadeoutSpeed then
     CurAlpha := CurAlpha - FadeoutSpeed else begin
       CurAlpha := 0;
       FadeState := fsNone;
       inherited Hide;
     end;
  end;
end;

procedure TFader.SetColor(const Value: Longword);
begin
  FColor := Value;
  FadeState := fsNone;
  CurAlpha := 1;
end;

{ TBackground }

constructor TBackground.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  AddLOD(TBackgroundTesselator.Create(''));
  Order := -2000;
  ClearRenderPasses;
  AddRenderPass(bmOne, bmZero, tfAlways, tfAlways, 0, True, False);
  CullMode := cmNone;
end;

function TBackground.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Columns', ptInt32, Pointer(TBackgroundTesselator(CurrentLOD).Cols));
  NewProperty(Result, 'Rows', ptInt32, Pointer(TBackgroundTesselator(CurrentLOD).Rows));
  NewProperty(Result, 'Angle', ptInt32, Pointer(TBackgroundTesselator(CurrentLOD).Angle));
  NewProperty(Result, 'Zoom', ptSingle, Pointer(TBackgroundTesselator(CurrentLOD).Zoom));
end;

function TBackground.SetProperties(AProperties: TProperties): Integer;
var Mesh: TBackgroundTesselator;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;

  Mesh := TBackgroundTesselator(CurrentLOD);

  Mesh.SetParameters(FColor,
                     Integer(GetPropertyValue(AProperties, 'Columns')), Integer(GetPropertyValue(AProperties, 'Rows')),
                     Integer(GetPropertyValue(AProperties, 'Angle')), Single(GetPropertyValue(AProperties, 'Zoom')));
end;

function TBackground.GetAngle: Integer;
begin
  Result := (CurrentLOD as TBackgroundTesselator).Angle;
end;

function TBackground.GetZoom: Single;
begin
  Result := (CurrentLOD as TBackgroundTesselator).Zoom;
end;

function TBackground.Process: Boolean;
begin
  Result := inherited Process;
  (CurrentLOD as TBackgroundTesselator).Color := FColor and $FFFFFF or Trunc(0.5 + MinS(CurAlpha * (FColor shr 24), 255)) shl 24;
  CurrentLOD.Invalidate(False);
end;

procedure TBackground.SetAngle(const Value: Integer);
begin
  (CurrentLOD as TBackgroundTesselator).Angle := Value;
  CurrentLOD.Invalidate(False);
end;

procedure TBackground.SetColor(const Value: Longword);
begin
  inherited;
  (CurrentLOD as TBackgroundTesselator).Color := Value;
  CurrentLOD.Invalidate(False);
end;

procedure TBackground.SetZoom(const Value: Single);
begin
  (CurrentLOD as TBackgroundTesselator).Zoom := Value;
  CurrentLOD.Invalidate(False);
end;

{ TColoredTree }

constructor TColoredTree.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  MeshClass := TColoredTreeMesh;
end;

function TColoredTree.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Stem color', ptColor32, Pointer(StemColor));
  NewProperty(Result, 'Crown color', ptColor32, Pointer(CrownColor));
  NewProperty(Result, 'End color', ptColor32, Pointer(EndColor));
  NewProperty(Result, 'Burning time', ptInt32, Pointer(BurningTime));
  NewProperty(Result, 'Burning material', ptString, @BurningMaterialName);
end;

function TColoredTree.SetProperties(AProperties: TProperties): Integer;
var Mesh: TColoredTreeMesh;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  StemColor := Longword(GetPropertyValue(AProperties, 'Stem color'));
  CrownColor := Longword(GetPropertyValue(AProperties, 'Crown color'));
  EndColor := Longword(GetPropertyValue(AProperties, 'End color'));
  BurningTime := Integer(GetPropertyValue(AProperties, 'Burning time'));
  BurningMaterialName := TShortName(GetPropertyValue(AProperties, 'Burning material')^);

  Mesh := CurrentLOD as TColoredTreeMesh;
  Mesh.StemColor := StemColor;
  Mesh.CrownColor := CrownColor;
  Mesh.Invalidate(False);

  Burned := False;
  Burning := False;

//  if BurningMaterialName <> '' then Burn;

  Result := 0;
end;

function TColoredTree.Process: Boolean;
var Mesh: TColoredTreeMesh;
begin
  Result := inherited Process;
  if not Burning then Exit;

  Mesh := CurrentLOD as TColoredTreeMesh;
  Mesh.StemColor := BlendColor(StemColor, EndColor, 1 - BurningTimer/BurningTime);
  Mesh.CrownColor := BlendColor(CrownColor, EndColor, 1 - BurningTimer/BurningTime);
  Mesh.Invalidate(False);
  if BurningTimer > 0 then Dec(BurningTimer) else StopBurn;
end;

procedure TColoredTree.Burn;
var i: Integer;
begin
  if (BurningTime <= 0) or Burned then Exit;
  Burning := True;
  BurningTimer := BurningTime + Trunc(0.5 + (Random*2-1) * BurningTime * 0.1);
  SetMaterial(0, BurningMaterialName);

  CurZA := 0; MaxAngle := MaxAngle * 0.5;

  for i := 0 to TotalChilds-1 do if Childs[i] is TParticleSystem then begin
    Childs[i].Status := Childs[i].Status or isProcessing or isVisible;
    Childs[i].Init;
  end;
end;

procedure TColoredTree.StopBurn;
var i: Integer;
begin
  Burning := False;
  Burned := True;
  for i := 0 to TotalChilds-1 do if Childs[i] is TParticleSystem then begin
    (Childs[i] as TParticleSystem).DisableEmit := True;
  end;
end;

{ TRing }

constructor TRing.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited Create(AName, AWorld, AParent);
  SetMesh;
  ClearRenderPasses;
  AddRenderPass(bmSRCALPHA, bmINVSRCALPHA, tfLessEqual, tfAlways, 0, True, True);
  YAngle := 0+pi/4;
end;

procedure TRing.SetMesh;
begin
  ClearMeshes;
  AddLOD(World.AddMesh(TRingMesh.Create('')));
end;

function TRing.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Color 1',      ptColor32, Pointer(TRingMesh(CurrentLOD).Color1));
  NewProperty(Result, 'Color 2',      ptColor32, Pointer(TRingMesh(CurrentLOD).Color2));
  NewProperty(Result, 'Factor',       ptSingle,  Pointer(TRingMesh(CurrentLOD).Factor));
  NewProperty(Result, 'Smoothing',    ptInt32,   Pointer(TRingMesh(CurrentLOD).Smoothing));
  NewProperty(Result, 'Inner radius', ptSingle,  Pointer(TRingMesh(CurrentLOD).InnerRadius));
  NewProperty(Result, 'Outer radius', ptSingle,  Pointer(TRingMesh(CurrentLOD).OuterRadius));
  NewProperty(Result, 'UV map type',  ptInt32,   Pointer(TRingMesh(CurrentLOD).UVMapType));
end;

function TRing.SetProperties(AProperties: TProperties): Integer;
var Mesh: TRingMesh;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;

  ClearMeshes;
  Mesh := TRingMesh.Create('');
  Mesh.SetParameters(Single(GetPropertyValue(AProperties, 'Inner radius')), Single(GetPropertyValue(AProperties, 'Outer radius')),
                     Integer(GetPropertyValue(AProperties, 'Smoothing')),
                     Longword(GetPropertyValue(AProperties, 'Color 1')), Longword(GetPropertyValue(AProperties, 'Color 2')),
                     Single(GetPropertyValue(AProperties, 'Factor')), 
                     Integer(GetPropertyValue(AProperties, 'UV map type')));
  AddLOD(World.AddMesh(Mesh));
end;

function TRing.GetColor: Longword;
begin
  Result := TRingMesh(CurrentLOD).Color1;
end;

function TRing.Process: Boolean;
var CameraForward, Axis: TVector3s; Angle: Single;
begin
  Result := inherited Process;
  CameraForward := Transform3Vector3s(GetTransposedMatrix3s(CutMatrix3s(World.Renderer.RenderPars.ViewMatrix)), GetVector3s(0, 0, 1));
  Axis := NormalizeVector3s(CrossProductVector3s(CameraForward, GetVector3s(0, 1, 0)));
//  Axis := Transform3Vector3s({TransposeMatrix3s(}CutMatrix3s(ModelMatrix), Axis);
  Angle := ArcTan2(-sqrt(Sqr(CameraForward.X) + Sqr(CameraForward.Z)), -CameraForward.Y);
  SetOrientation(MulQuaternion(GetQuaternion(-Angle, Axis), GetQuaternion(YAngle, GetVector3s(0, 1, 0))));
end;

procedure TRing.SetColor(const Value: Longword);
var Mesh: TRingMesh;
begin
  if CurrentLOD is TRingMesh then Mesh := CurrentLOD as TRingMesh else Exit;
  Mesh.SetParameters(Mesh.InnerRadius, Mesh.OuterRadius, Mesh.Smoothing, Value, Mesh.Color2, Mesh.Factor, Mesh.UVMapType);
end;

end.
