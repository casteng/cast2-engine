(*
 @Abstract(CAST II Engine miscellaneous visual items unit)
 (C) 2006-2008 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains some useful visual items
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2VisItems;

interface

uses
  Logger,
  SysUtils,
  BaseTypes, BaseMsg, Basics, Props, Base3D, Geometry, BaseClasses, Resources,
  C2Types, CAST2, C2Visual, C2Res, C2Core;

type
  TMeshTesselator = class(TTesselator)
  public
    Vertices, Indices: Pointer;
    NumberOfVertices, NumberOfIndices: Integer;
    constructor Create; override;
    procedure Init; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;

    function GetMaxVertices: Integer; override;
    function GetMaxIndices: Integer; override;

    function GetBoundingBox: TBoundingBox; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  protected
    FVertices, FIndices: Pointer;
  end;

  TMesh = class(TVisible)
    function GetTesselatorClass: CTesselator; override;
    procedure OnSceneLoaded; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  private
    function GetVerticesRes: TVerticesResource;
    function GetIndicesRes: TIndicesResource;
  protected
    procedure SetMesh; override;
  public
    procedure HandleMessage(const Msg: TMessage); override;
    property Vertices: TVerticesResource read GetVerticesRes;
    property Indices:  TIndicesResource  read GetIndicesRes;
  end;

  TPolyTesselator = class(TTesselator)
  private
    Poly: T2DPointList;
    Triangles: TTriangles;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Init; override;

    function GetBoundingBox: TBoundingBox; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TPolygon = class(TVisible)
  public
    function GetTesselatorClass: CTesselator; override;
    procedure AddPoint(v: TVector2s);
  end;

  TPlaneTesselator = class(TTesselator)
  protected
    FColor: BaseTypes.TColor;
    FWidth, FHeight: Single;
  public  
    Color: BaseTypes.TColor;
    Width, Height: Single;
    constructor Create; override;
    function GetBoundingBox: TBoundingBox; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TPlane = class(TVisible)
  public
    TexScaleU, TexScaleV, TexMoveU, TexMoveV: Single;
    constructor Create(AManager: TItemsManager); override;
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TMirrorPlaneTesselator = class(TTesselator)
  private
    vel, arr: array of single;
  protected
    FColor: BaseTypes.TColor;
    FWidth, FHeight: Single;
    FRows, FCols: Integer;
  public
    Color: BaseTypes.TColor;
    Width, Height: Single;
    Rows, Cols: Integer;
    constructor Create; override;
    procedure Init; override;
    function GetBoundingBox: TBoundingBox; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;

    procedure Iterate;
  end;

  TMirrorPlane = class(TVisible)
  private
    TexMat: TMatrix4s;
  protected
    procedure RetrieveTexMat(TextureStage: Integer; out Mat: TMatrix4s);
  public
    constructor Create(AManager: TItemsManager); override;
    function VisibilityCheck(const Camera: TCamera): Boolean; override;
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaTime: Single); override;
  end;

  TCircleTesselator = class(TTesselator)
  protected
    FCenterColor, FSideColor: BaseTypes.TColor;
    FRadius: Single;
    FSectors: Integer;
  public  
    CenterColor, SideColor: BaseTypes.TColor;
    Radius: Single;
    Sectors: Integer;
    constructor Create; override;
    procedure Init; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function GetBoundingBox: TBoundingBox; override;
  end;

  TCircle = class(TVisible)
  private
    function GetCenterColor: BaseTypes.TColor;
    function GetSideColor: BaseTypes.TColor;
    procedure SetCenterColor(const Value: BaseTypes.TColor);
    procedure SetSideColor(const Value: BaseTypes.TColor);
  public
    AttachedToCamera, FixedY: Boolean;
    TexScaleU, TexScaleV, TexMoveU, TexMoveV: Single;
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
    procedure Process(const DeltaT: Float); override;
  
    property CenterColor: BaseTypes.TColor read GetCenterColor write SetCenterColor;
    property SideColor:   BaseTypes.TColor read GetSideColor   write SetSideColor;
  end;

  TDomeTesselator = class(TTesselator)
  protected
    FSectors, FSegments: Integer;
    FRadius, FHeight, FTexScale: Single;
    FColor: BaseTypes.TColor;
    FSkyMap: BaseTypes.PImageBuffer;
  public  
    // Parameters
    Sectors, Segments: Integer;
    Radius, Height, TexScale: Single;
    Color: BaseTypes.TColor;
    SkyMap: BaseTypes.PImageBuffer;
    // Other
    SMWidth, SMHeight: Integer;
    constructor Create; override;
    procedure Init; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    function GetBoundingBox: TBoundingBox; override;
  end;

  TDome = class(TVisible)
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TSky = class(TDome)
  protected
    procedure ResolveLinks; override;
  public  
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TRingMesh = class(TTesselator)
  protected
    FInnerRadius, FOuterRadius, FFactor: Single;
    FSmoothing: Integer;
    FColor1, FColor2: BaseTypes.TColor;
    FUVMapType: Longword;
  public  
    InnerRadius, OuterRadius, Factor: Single;
    Smoothing: Integer;
    Color1, Color2: BaseTypes.TColor;
    UVMapType: Longword;
    UVFrame: TUV;
    constructor Create; override;
    procedure Init; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function GetBoundingBox: TBoundingBox; override;
  end;

  TRing = class(TVisible)
  private
    function GetColor: BaseTypes.TColor;
    procedure SetColor(const Value: BaseTypes.TColor);
  public
    YAngle: Single;
    constructor Create(AManager: TItemsManager); override;
    function VisibilityCheck(const Camera: TCamera): Boolean; override;
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
    property Color: BaseTypes.TColor read GetColor write SetColor;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TVisible, TMappedItem, TMesh, TPlane, TCircle, TDome, TSky, TPolygon]);
end;

{ TMeshTesselator }

constructor TMeshTesselator.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLELIST;
  Vertices      := nil;
  Indices       := nil;
  FVertices     := nil;
  FIndices      := nil;
  InitVertexFormat(GetVertexFormat(False, True, False, False, False, 0, [2]));
  Init;
end;

procedure TMeshTesselator.Init;
begin
  inherited;
  Invalidate([tbVertex, tbIndex], (TotalVertices <> NumberOfVertices) or (TotalIndices <> NumberOfIndices));

  TotalVertices    := NumberOfVertices;
  TotalIndices     := NumberOfIndices;
  IndexingVertices := TotalVertices;
  TotalPrimitives  := TotalIndices div 3;
  FVertices        := Vertices;
  FIndices         := Indices;
end;

function TMeshTesselator.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := (2*SizeOf(Pointer)) div 4;
  if Internal then Parameters := @FVertices else Parameters := @Vertices;
end;

function TMeshTesselator.GetMaxVertices: Integer;
begin
  Result := NumberOfVertices;
end;

function TMeshTesselator.GetMaxIndices: Integer;
begin
  Result := NumberOfIndices;
end;

function TMeshTesselator.GetBoundingBox: TBoundingBox;
var i: Integer;
begin
  if FVertices = nil then Exit;
  Result.P1 := GetVector3s(100000, 100000, 100000); Result.P2 := GetVector3s(-100000, -100000, -100000);
  for i := 0 to TotalVertices-1 do with TVector3s((@TByteBuffer(FVertices^)[i*Integer(FVertexSize)])^), Result do begin
    if X < P1.X then P1.X := X; if Y < P1.Y then P1.Y := Y; if Z < P1.Z then P1.Z := Z;
    if X > P2.X then P2.X := X; if Y > P2.Y then P2.Y := Y; if Z > P2.Z then P2.Z := Z;
  end;
end;

function TMeshTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer;
begin
  Result := 0;
  if FVertices = nil then Exit;
  if not CompositeMember then begin
    Move(FVertices^, VBPTR^, TotalVertices * FVertexSize);
  end else begin
    Assert(CompositeOffset <> nil, 'Composite object''s offset is nil');
    for i := 0 to TotalVertices-1 do begin
      Move(TByteBuffer(FVertices^)[i*FVertexSize + SizeOf(TVector3s)], TByteBuffer(VBPTR^)[i*FVertexSize + SizeOf(TVector3s)], FVertexSize - SizeOf(TVector3s));
      TVector3s((@TByteBuffer(VBPTR^)[i*FVertexSize])^).X := TVector3s((@TByteBuffer(FVertices^)[i*FVertexSize])^).X + CompositeOffset^.X;
      TVector3s((@TByteBuffer(VBPTR^)[i*FVertexSize])^).Y := TVector3s((@TByteBuffer(FVertices^)[i*FVertexSize])^).Y + CompositeOffset^.Y;
      TVector3s((@TByteBuffer(VBPTR^)[i*FVertexSize])^).Z := TVector3s((@TByteBuffer(FVertices^)[i*FVertexSize])^).Z + CompositeOffset^.Z;
    end;
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
//  Status := tsChanged;
  LastTotalIndices := TotalIndices;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

function TMeshTesselator.SetIndices(IBPTR: Pointer): Integer;
begin
  Result := 0;
  if FIndices = nil then Exit;
  Move(TWordBuffer(FIndices^)[0], TWordBuffer(IBPTR^)[0], TotalIndices * IndexSize);
  LastTotalIndices := TotalIndices;
  TesselationStatus[tbIndex].Status := tsTesselated;
  Result := TotalIndices;
end;

{ TPlaneTesselator }

constructor TPlaneTesselator.Create;
begin
  inherited;
  PrimitiveType    := ptTRIANGLESTRIP;
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));

  TotalVertices    := 4;
  TotalPrimitives  := 2;

  Color.C  := $80808080;
  Width  := 1;
  Height := 1;

  Init;
end;

function TPlaneTesselator.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-Width, -Height, 0);
  Result.P2 := GetVector3s( Width,  Height, 0);
end;

function TPlaneTesselator.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := (1*SizeOf(Longword) + 2*SizeOf(Single)) div 4;
  if Internal then Parameters := @FColor else Parameters := @Color;
end;

function TPlaneTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
begin
  SetVertexDataC(-FWidth, FHeight, 0, 0, VBPTR);
  SetVertexDataUV(0, 0, 0, VBPTR);
  SetVertexDataD(FColor, 0, VBPTR);

  SetVertexDataC(FWidth, FHeight, 0, 1, VBPTR);
  SetVertexDataUV(1, 0, 1, VBPTR);
  SetVertexDataD(FColor, 1, VBPTR);

  SetVertexDataC(-FWidth, -FHeight, 0, 2, VBPTR);
  SetVertexDataUV(0, 1, 2, VBPTR);
  SetVertexDataD(FColor, 2, VBPTR);

  SetVertexDataC(FWidth, -FHeight, 0, 3, VBPTR);
  SetVertexDataUV(1, 1, 3, VBPTR);
  SetVertexDataD(FColor, 3, VBPTR);

  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result            := TotalVertices;
end;

{ TPlane }

constructor TPlane.Create(AManager: TItemsManager);
begin
  inherited;
  TexScaleU := 1; TexScaleV := 1; TexMoveU := 1; TexMoveV := 1;
end;

function TPlane.GetTesselatorClass: CTesselator; begin Result := TPlaneTesselator; end;

procedure TPlane.AddProperties(const Result: Props.TProperties);
var Tesselator: TPlaneTesselator;
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Texture\scale U', vtSingle, [], FloatToStr(TexScaleU), '');
  Result.Add('Texture\scale V', vtSingle, [], FloatToStr(TexScaleV), '');
  Result.Add('Texture\move U',  vtSingle, [], FloatToStr(TexMoveU),  '');
  Result.Add('Texture\move V',  vtSingle, [], FloatToStr(TexMoveV),  '');

  if not (CurrentTesselator is TPlaneTesselator) then Exit;
  Tesselator := CurrentTesselator as TPlaneTesselator;

  AddColorProperty(Result, 'Color', Tesselator.Color);
  Result.Add('Geometry\Width',  vtSingle, [],       FloatToStr(Tesselator.Width),   '');
  Result.Add('Geometry\Height', vtSingle, [],       FloatToStr(Tesselator.Height),  '');
end;

procedure TPlane.SetProperties(Properties: Props.TProperties);
var Tesselator: TPlaneTesselator;
begin
  inherited;

  if Properties.Valid('Texture\scale U') then TexScaleU := StrToFloatDef(Properties['Texture\scale U'], 1);
  if Properties.Valid('Texture\scale V') then TexScaleV := StrToFloatDef(Properties['Texture\scale V'], 1);
  if Properties.Valid('Texture\move U')  then TexMoveU  := StrToFloatDef(Properties['Texture\move U'],  1);
  if Properties.Valid('Texture\move V')  then TexMoveV  := StrToFloatDef(Properties['Texture\move V'],  1);

  if not (CurrentTesselator is TPlaneTesselator) then Exit;
  Tesselator := CurrentTesselator as TPlaneTesselator;

  SetColorProperty(Properties, 'Color', Tesselator.Color);
  if Properties.Valid('Geometry\Width')  then Tesselator.Width  := StrToFloatDef(Properties['Geometry\Width'],  1);
  if Properties.Valid('Geometry\Height') then Tesselator.Height := StrToFloatDef(Properties['Geometry\Height'], 1);

  SetMesh;
end;

{ TMirrorPlaneTesselator }

constructor TMirrorPlaneTesselator.Create;
begin
  inherited;
  Cols := 1; Rows := 1;

  Color.C  := $80808080;
  Width    := 1;
  Height   := 1;

  Init;
end;

function TMirrorPlaneTesselator.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-Width, -Height, 0);
  Result.P2 := GetVector3s( Width,  Height, 0);
end;

procedure TMirrorPlaneTesselator.Init;
begin
  inherited;
  TotalVertices   := (FRows+1)*(FCols+1);
  TotalIndices    :=  FRows * FCols * 6;
  TotalPrimitives :=  FRows * FCols * 2;
  IndexingVertices := TotalVertices;
  PrimitiveType    := ptTRIANGLELIST;
  InitVertexFormat(GetVertexFormat(False, True, True, False, False, 0, []));

  SetLength(arr, TotalVertices);
  SetLength(Vel, TotalVertices);
  FillChar(arr[0], TotalVertices*4, 0);
  FillChar(vel[0], TotalVertices*4, 0);

  arr[Random(FRows) * FCols + Random(FCols)] := 1550;
end;

procedure TMirrorPlaneTesselator.Iterate;
var i, j: Integer;
begin
  arr[Random(FRows) * FCols + Random(FCols)] := 1550;
  for j := 1 to FRows-2 do begin
    for i := 1 to FCols-2 do begin
      vel[j * FCols + i] := vel[j * FCols + i] - arr[j * FCols + i]*4 +
                            arr[(j+1) * FCols + i] + arr[(j-1) * FCols + i] +
                            arr[j * FCols + i + 1] + arr[j * FCols + i - 1];
    end;
  end;
  for j := 0 to FRows-1 do begin
    for i := 0 to FCols-1 do begin
      arr[j * FCols + i] := arr[j * FCols + i] + Vel[j * FCols + i] * 0.5;
//      arr[j * FCols + i] := MinS(255, MaxS(0, arr[j * FCols + i]));
      if arr[j * FCols + i]>255 then arr[j * FCols + i] := 255;
      if arr[j * FCols + i]<0 then arr[j * FCols + i] := 0;
    end;
  end;
end;

function TMirrorPlaneTesselator.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := (1*SizeOf(FColor) + 4*SizeOf(FWidth)) div 4;
  if Internal then Parameters := @FColor else Parameters := @Color;
end;

function TMirrorPlaneTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
  TotalPrimitives := 0;
  for j := 0 to FRows-1 do for i := 0 to FCols-1 do begin
    TWordBuffer(IBPTR^)[TotalPrimitives*3+0] :=  j    * (FCols+1) + i;
    TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * (FCols+1) + i;
    TWordBuffer(IBPTR^)[TotalPrimitives*3+2] := (j+1) * (FCols+1) + i+1;
    TWordBuffer(IBPTR^)[TotalPrimitives*3+3] :=  j    * (FCols+1) + i;
    TWordBuffer(IBPTR^)[TotalPrimitives*3+4] := (j+1) * (FCols+1) + i+1;
    TWordBuffer(IBPTR^)[TotalPrimitives*3+5] :=  j    * (FCols+1) + i+1;
    Inc(TotalPrimitives, 2);
  end;
  TesselationStatus[tbIndex].Status := tsTesselated;
  Result  := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

function TMirrorPlaneTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i, j: Integer;
begin
{  SetVertexDataC(  -FWidth, FHeight, 0, 0, VBPTR);
  SetVertexDataD(FColor, 0, VBPTR);

  SetVertexDataC(  FWidth, FHeight, 0, 1, VBPTR);
  SetVertexDataD(FColor, 1, VBPTR);

  SetVertexDataC(  -FWidth, -FHeight, 0, 2, VBPTR);
  SetVertexDataD(FColor, 2, VBPTR);

  SetVertexDataC(  FWidth, -FHeight, 0, 3, VBPTR);
  SetVertexDataD(FColor, 3, VBPTR);}

  for j := 0 to FRows do for i := 0 to FCols do begin
    SetVertexDataC((0.5 - i / FCols) * FWidth,
                   Arr[j * FCols + i]/250,
                   (0.5 - j / FRows) * FHeight,

                   j * (FCols+1) + i, VBPTR);
    SetVertexDataD(FColor, j * (FCols+1) + i, VBPTR);
    SetVertexDataN(0, 0, -1, j * (FCols+1) + i, VBPTR);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
  Result  := TotalVertices;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

{ TMirrorPlane }

function TMirrorPlane.VisibilityCheck(const Camera: TCamera): Boolean;
var
//  BiasMat,
  Mat: TMatrix4s; Cam: TCamera;
//  Light: TLight;
//  offset: Single; t: Cardinal;
begin
  Result := inherited VisibilityCheck(Camera);
  Exit;
  // Adjust texture matrix
//  Light := FManager.Root.GetChildByPath('\Root item\Light1') as TLight;

//  Cam := Light.Childs[0] as TCamera;
//  Cam := TCore(FManager).Renderer.MainCamera;
  Cam := Childs[0] as TCamera;

  Mat := IdentityMatrix4s;

//  Mat := FTransform;

{//  Mat := MulMatrix4s(Mat, InvertAffineMatrix4s(Camera.ViewMatrix));
  Mat := MulMatrix4s(Mat, Cam.ViewMatrix);

  Mat := MulMatrix4s(Mat, Cam.ProjMatrix);}

//    Mat := MulMatrix4s(Mat, InvertAffineMatrix4s(Cam.ViewMatrix));
//    Mat := MulMatrix4s(Mat, Cam.ViewMatrix);

    Mat := MulMatrix4s(Mat, Cam.ProjMatrix);

(*  offset := 0.5 + (0.5 / Cam.RenderTargetWidth);                                 // +Height ?
  t := 1 shl 24-1;
  biasMat._11:=0.5;	biasMat._12:=0.0;	biasMat._13:=0.0;		biasMat._14:=0.0;
  biasMat._21:=0.0;	biasMat._22:=-0.5;	biasMat._23:=0.0;		biasMat._24:=0.0;
  biasMat._31:=0.0;	biasMat._32:=0.0;	biasMat._33:=1 shl 24-1{Single((@t)^)};	biasMat._34:=0.0;
  biasMat._41:=offset;	biasMat._42:=offset;	biasMat._43:=5.00400000;		biasMat._44:=1.0;

  Mat := MulMatrix4s(Mat, BiasMat);*)

  Mat := MulMatrix4s(Mat, ScaleMatrix4s(0.5, -0.5, 1));
  Mat := MulMatrix4s(Mat, TranslationMatrix4s(0.5, 0.5, 0));

  TexMat := Mat;
end;

constructor TMirrorPlane.Create(AManager: TItemsManager);
begin
  inherited;
end;

function TMirrorPlane.GetTesselatorClass: CTesselator; begin Result := TMirrorPlaneTesselator; end;

procedure TMirrorPlane.AddProperties(const Result: TProperties);
var Tesselator: TMirrorPlaneTesselator;
begin
  inherited;
  if not Assigned(Result) then Exit;

  if not (CurrentTesselator is TMirrorPlaneTesselator) then Exit;
  Tesselator := CurrentTesselator as TMirrorPlaneTesselator;

  AddColorProperty(Result, 'Color', Tesselator.Color);
  Result.Add('Geometry\Width',  vtSingle, [], FloatToStr(Tesselator.Width),  '');
  Result.Add('Geometry\Height', vtSingle, [], FloatToStr(Tesselator.Height), '');
  Result.Add('Geometry\Rows',   vtInt,    [], IntToStr(Tesselator.Rows),     '');
  Result.Add('Geometry\Cols',   vtInt,    [], IntToStr(Tesselator.Cols),     '');
end;

procedure TMirrorPlane.SetProperties(Properties: TProperties);
var Tesselator: TMirrorPlaneTesselator;
begin
  inherited;
  if not (CurrentTesselator is TMirrorPlaneTesselator) then Exit;
  Tesselator := CurrentTesselator as TMirrorPlaneTesselator;

  SetColorProperty(Properties, 'Color', Tesselator.Color);
  if Properties.Valid('Geometry\Width')  then Tesselator.Width  := StrToFloatDef(Properties['Geometry\Width'],  1);
  if Properties.Valid('Geometry\Height') then Tesselator.Height := StrToFloatDef(Properties['Geometry\Height'], 1);
  if Properties.Valid('Geometry\Rows')   then Tesselator.Rows   := StrToIntDef(Properties['Geometry\Rows'],     1);
  if Properties.Valid('Geometry\Cols')   then Tesselator.Cols   := StrToIntDef(Properties['Geometry\Cols'],     1);

  SetMesh;

  RetrieveTextureMatrix := {$IFDEF OBJFPCEnable}@{$ENDIF}RetrieveTexMat;
end;

procedure TMirrorPlane.RetrieveTexMat(TextureStage: Integer; out Mat: TMatrix4s);
begin
  Mat := TexMat;
end;

procedure TMirrorPlane.Process(const DeltaTime: Single);
begin
  inherited;
  (CurrentTesselator as TMirrorPlaneTesselator).Iterate;
end;

{ TCircleTesselator }

constructor TCircleTesselator.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLEFAN;
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));

  CenterColor.C := $80808080;
  SideColor.C   := $80808080;
  Sectors       := 6;
  Radius        := 1;
  Init;
end;

procedure TCircleTesselator.Init;
begin
  inherited;
  Invalidate([tbVertex, tbIndex], TotalPrimitives <> FSectors);
  TotalVertices   := 1+FSectors+1;
  TotalPrimitives := FSectors;  
end;

function TCircleTesselator.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := (2*SizeOf(Longword) + 1*SizeOf(Integer) + 1*SizeOf(Single)) div 4;
  if Internal then Parameters := @FCenterColor else Parameters := @CenterColor;
end;

function TCircleTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer;
begin
  SetVertexDataC(0, 0, 0, 0, VBPTR);
  SetVertexDataUV(0.5, 0.5, 0, VBPTR);
  SetVertexDataD(FCenterColor, 0, VBPTR);

  for i := 0 to FSectors do begin
    SetVertexDataC(FRadius*Cos(i/FSectors*2*pi), 0, FRadius*Sin(i/FSectors*2*pi), i+1, VBPTR);
    SetVertexDataUV(0.5 + 0.5*Cos(i/FSectors*2*pi*1), 0.5 + 0.5*Sin(i/FSectors*2*pi*1), i+1, VBPTR);
    SetVertexDataD(FSideColor, i+1, VBPTR);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
  Result            := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TCircleTesselator.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-Radius, 0, -Radius);
  Result.P2 := GetVector3s( Radius, 0,  Radius);
end;

{ TCircle }

function TCircle.GetTesselatorClass: CTesselator; begin Result := TCircleTesselator; end;

procedure TCircle.AddProperties(const Result: Props.TProperties);
var Tesselator: TCircleTesselator;
begin
  inherited;
  if not Assigned(Result) then Exit;
  AddColorProperty(Result, 'Color\Center', CenterColor);
  AddColorProperty(Result, 'Color\Side',   SideColor);

  Result.Add('Texture\Scale U', vtSingle, [], FloatToStr(TexScaleU), '');
  Result.Add('Texture\Scale V', vtSingle, [], FloatToStr(TexScaleV), '');
  Result.Add('Texture\Move U',  vtSingle, [], FloatToStr(TexMoveU),  '');
  Result.Add('Texture\Move V',  vtSingle, [], FloatToStr(TexMoveV),  '');

  if not (CurrentTesselator is TCircleTesselator) then Exit;
  Tesselator := CurrentTesselator as TCircleTesselator;

  Result.Add('Geometry\Radius',  vtSingle, [], FloatToStr(Tesselator.Radius), '');
  Result.Add('Geometry\Sectors', vtInt,    [], IntToStr(Tesselator.Sectors), '');
end;

procedure TCircle.SetProperties(Properties: Props.TProperties);
var Tesselator: TCircleTesselator; C: BaseTypes.TColor;
begin
  inherited;
  C := CenterColor;
  SetColorProperty(Properties, 'Color\Center', C);
  CenterColor := C;
  C := SideColor;
  SetColorProperty(Properties, 'Color\Side',   C);
  SideColor := C;

  if Properties.Valid('Texture\Scale U') then TexScaleU := StrToFloatDef(Properties['Texture\Scale U'], 1.00);
  if Properties.Valid('Texture\Scale V') then TexScaleV := StrToFloatDef(Properties['Texture\Scale V'], 1.00);
  if Properties.Valid('Texture\Move U')  then TexMoveU  := StrToFloatDef(Properties['Texture\Move U'],  0.01);
  if Properties.Valid('Texture\Move V')  then TexMoveV  := StrToFloatDef(Properties['Texture\Move V'],  0.00);

  if not (CurrentTesselator is TCircleTesselator) then Exit;
  Tesselator := CurrentTesselator as TCircleTesselator;

  if Properties.Valid('Geometry\Radius')  then Tesselator.Radius  := StrToFloatDef(Properties['Geometry\Radius'], 1);
  if Properties.Valid('Geometry\Sectors') then Tesselator.Sectors := StrToIntDef(Properties['Geometry\Sectors'], 6);

  SetMesh;
end;

procedure TCircle.Process(const DeltaT: Float);
begin
  inherited;

{  Mesh.UOfs := BasicUOfs + CurUOfs;
  CurUOfs := CurUOfs + Mesh.UShift;
  if Mesh.UOfs > 2 then CurUOfs := CurUOfs-2;

  Mesh.VOfs := BasicVOfs + CurVOfs;
  CurVOfs := CurVOfs + Mesh.VShift;
  if Mesh.VOfs > 2 then CurVOfs := CurVOfs-2;}
end;

function TCircle.GetCenterColor: BaseTypes.TColor;
begin
  if CurrentTesselator is TCircleTesselator then
   Result := TCircleTesselator(CurrentTesselator).CenterColor else
    Result.C := 0;
end;

function TCircle.GetSideColor: BaseTypes.TColor;
begin
  if CurrentTesselator is TCircleTesselator then
   Result := TCircleTesselator(CurrentTesselator).SideColor else
    Result.C := 0;
end;

procedure TCircle.SetCenterColor(const Value: BaseTypes.TColor);
begin
  if not (CurrentTesselator is TCircleTesselator) then Exit;
  TCircleTesselator(CurrentTesselator).CenterColor := Value;
  CurrentTesselator.Invalidate([tbVertex], False);
end;

procedure TCircle.SetSideColor(const Value: BaseTypes.TColor);
begin
  if not (CurrentTesselator is TCircleTesselator) then Exit;
  TCircleTesselator(CurrentTesselator).SideColor := Value;
  CurrentTesselator.Invalidate([tbVertex], False);
end;

{ TDomeTesselator }

constructor TDomeTesselator.Create;
begin
  inherited;
//  PrimitiveType    := ptTRIANGLESTRIP;
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));

  Sectors  := 8;
  Segments := 4;
  Radius   := 1;
  Height   := 1;
  TexScale := 1;
  Color.C  := $FF808080;
  SkyMap   := nil;
  Init;

  SMWidth  := 0;
  SMHeight := 0;
end;

procedure TDomeTesselator.Init;
begin
  inherited;
  Invalidate([tbVertex, tbIndex], TotalVertices <> (FSegments+1) * (FSectors+1));
  TotalVertices    := (FSegments+1) * (FSectors+1);
  TotalIndices     := (FSegments  ) * (FSectors  )*2*3;
  TotalPrimitives  := (FSegments  ) * (FSectors  )*2+0*2*(FSegments-1);
  IndexingVertices := TotalVertices;
end;

function TDomeTesselator.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := (1*SizeOf(Longword) + 2*SizeOf(Integer) + 3*SizeOf(Single) + 1*SizeOf(Pointer)) div 4;
  if Internal then Parameters := @FSectors else Parameters := @Sectors;
end;

function TDomeTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i, j, si, sj, SMXI, SMYI: Integer; U, V, SMYO: Single;
begin
  Result := 0;
  if FSegments = 0 then Exit;
  for j := 0 to FSegments do for i := 0 to FSectors do begin
//    X := Radius*Cos(i/Sectors*2*pi)*Cos(j/(Segments)*pi/2);
    si := i*(SinTableSize) div FSectors;
    sj := j*(SinTableSize) div FSegments shr 2;

    SetVertexDataC(FRadius*SinTable[si+CosTabOffs]*SinTable[sj+CosTabOffs],
                   SinTable[sj] * FHeight,
                   FRadius*SinTable[si] * SinTable[sj + CosTabOffs],
                   j*(FSectors+1)+i, VBPTR);

    U := 0.5 + 0.5*(FSegments-j)/FSegments*SinTable[si + CosTabOffs];
    V := 0.5 + 0.5*(FSegments-j)/FSegments*SinTable[si];

    SetVertexDataUV(U * FTexScale, V * FTexScale, j*(FSectors+1)+i, VBPTR);

    if FSkyMap <> nil then begin
      SMXI := Trunc(U * (SMWidth-1));
      SMYI := Trunc(V * (SMHeight-1));
      SMYO := Frac(V * (SMHeight-1));
      SetVertexDataD(BlendColor(BlendColor(FSkyMap^[SMYI*SMWidth+SMXI], FSkyMap^[((SMYI+1) and (SMHeight-1))*SMWidth+SMXI], SMYO),
                                BlendColor(FSkyMap^[SMYI*SMWidth+(SMXI+1) and (SMWidth-1)], FSkyMap^[((SMYI+1) and (SMHeight-1))*SMWidth+(SMXI+1) and (SMWidth-1)], SMYO),
                                Frac (U * (SMWidth-1))), j*(FSectors+1)+i, VBPTR);
    end else SetVertexDataD(FColor, j*(FSectors+1)+i, VBPTR);
  end;
  TesselationStatus[tbVertex].Status := tsTesselated;
  Result            := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TDomeTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
  for j := 0 to FSegments-1 do begin
    for i := 0 to FSectors-1 do begin
      TWordBuffer(IBPTR^)[(j*(FSectors+0)+i)*6+0] := (j+0)*(FSectors+1)+i;
      TWordBuffer(IBPTR^)[(j*(FSectors+0)+i)*6+1] := (j+1)*(FSectors+1)+i;
      TWordBuffer(IBPTR^)[(j*(FSectors+0)+i)*6+2] := (j+0)*(FSectors+1)+i+1;
      TWordBuffer(IBPTR^)[(j*(FSectors+0)+i)*6+3] := (j+1)*(FSectors+1)+i;
      TWordBuffer(IBPTR^)[(j*(FSectors+0)+i)*6+4] := (j+1)*(FSectors+1)+i+1;
      TWordBuffer(IBPTR^)[(j*(FSectors+0)+i)*6+5] := (j+0)*(FSectors+1)+i+1
    end;
  end;
  TesselationStatus[tbIndex].Status := tsTesselated;
  Result  := TotalIndices;
end;

function TDomeTesselator.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-Radius, 0,      -Radius);
  Result.P2 := GetVector3s( Radius, Height,  Radius);
end;

{ TDome }

procedure TDome.AddProperties(const Result: Props.TProperties);
var Tesselator: TDomeTesselator;
begin
  inherited;
  if not Assigned(Result) then Exit;

  if not (CurrentTesselator is TDomeTesselator) then Exit;
  Tesselator := CurrentTesselator as TDomeTesselator;

  AddColorProperty(Result, 'Color', Tesselator.Color);
  Result.Add('Geometry\Sectors',       vtInt,    [],       IntToStr(Tesselator.Sectors),   '3-256');
  Result.Add('Geometry\Segments',      vtInt,    [],       IntToStr(Tesselator.Segments),  '1-16');
  Result.Add('Geometry\Radius',        vtSingle, [],       FloatToStr(Tesselator.Radius),   '');
  Result.Add('Geometry\Height',        vtSingle, [],       FloatToStr(Tesselator.Height),   '');
  Result.Add('Texture\Scale',          vtSingle, [],       FloatToStr(Tesselator.TexScale), '');
end;

function TDome.GetTesselatorClass: CTesselator; begin Result := TDomeTesselator; end;

procedure TDome.SetProperties(Properties: Props.TProperties);
var Tesselator: TDomeTesselator;
begin
  inherited;

  if not (CurrentTesselator is TDomeTesselator) then Exit;
  Tesselator := CurrentTesselator as TDomeTesselator;

  SetColorProperty(Properties, 'Color', Tesselator.Color);
  if Properties.Valid('Geometry\Sectors')  then Tesselator.Sectors  := StrToIntDef(Properties['Geometry\Sectors'],        8);
  if Properties.Valid('Geometry\Segments') then Tesselator.Segments := StrToIntDef(Properties['Geometry\Segments'],       4);
  if Properties.Valid('Geometry\Radius')   then Tesselator.Radius   := StrToFloatDef(Properties['Geometry\Radius'],        1);
  if Properties.Valid('Geometry\Height')   then Tesselator.Height   := StrToFloatDef(Properties['Geometry\Height'],        1);
  if Properties.Valid('Texture\Scale')     then Tesselator.TexScale := StrToFloatDef(Properties['Texture\Scale'],          1);

  SetMesh;
end;

{ TSky }

procedure TSky.ResolveLinks;
var Tesselator: TDomeTesselator; SMRes: TItem;
begin
  if not (CurrentTesselator is TDomeTesselator) then Exit;
  Tesselator := CurrentTesselator as TDomeTesselator;

  if ResolveLink('Color\Sky map', SMRes) then begin
    Tesselator.SkyMap   := (SMRes as TImageResource).Data;
    Tesselator.SMWidth  := (SMRes as TImageResource).Width;
    Tesselator.SMHeight := (SMRes as TImageResource).Height;
    SetMesh;
  end;
  if SMRes = nil then Tesselator.SkyMap := nil;
end;

procedure TSky.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  AddItemLink(Result, 'Color\Sky map', [], 'TImageResource');
end;

procedure TSky.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid('Color\Sky map') then SetLinkProperty('Color\Sky map', Properties['Color\Sky map']);
  ResolveLinks;
  SetMesh;
end;

{ TMesh }

function TMesh.GetTesselatorClass: CTesselator; begin Result := TMeshTesselator end;

procedure TMesh.OnSceneLoaded;
begin
  inherited;
  SetMesh;
end;

procedure TMesh.SetMesh;
var Tesselator: TMeshTesselator;

  procedure ResetMesh;
  begin
    Tesselator.Vertices         := nil;
    Tesselator.NumberOfVertices := 0;
    Tesselator.Indices          := nil;
    Tesselator.NumberOfIndices  := 0;
  end;

begin
  if (CurrentTesselator is TMeshTesselator) then begin
    Tesselator := CurrentTesselator as TMeshTesselator;

    ResetMesh;
    if Vertices <> nil then begin
      if (Integer(GetVertexSize(Vertices.Format)) * Vertices.TotalElements = Vertices.DataSize) then begin   // Simple validity check
        Tesselator.Vertices         := Vertices.Data;
        Tesselator.VertexFormat     := Vertices.Format;
        Tesselator.NumberOfVertices := Vertices.TotalElements;
      end else Log('TMesh("' + Name + '").SetMesh: Invalid vertices resource "' + Vertices.Name + '"', lkError);
    end;

    if Indices <> nil then begin
      Tesselator.Indices         := Indices.Data;
      Tesselator.NumberOfIndices := Indices.TotalElements;
    end;

(*    if not Tesselator.Validate then begin
      ResetMesh;
      Log(Format('%S("%S").%S: The mesh did not pass validation', [ClassName, Name, 'ResetIndices']), lkError); 
    end;*)
  end;
  inherited;
end;

procedure TMesh.AddProperties(const Result: Props.TProperties);
begin
  inherited;

  AddItemLink(Result, 'Geometry\Vertices', [], 'TVerticesResource');
  AddItemLink(Result, 'Geometry\Indices',  [], 'TIndicesResource');
end;

procedure TMesh.SetProperties(Properties: Props.TProperties);
begin
  inherited;

  if Properties.Valid('Geometry\Vertices') then SetLinkProperty('Geometry\Vertices', Properties['Geometry\Vertices']);
  if Properties.Valid('Geometry\Indices')  then SetLinkProperty('Geometry\Indices',  Properties['Geometry\Indices']);

  SetMesh;
end;

function TMesh.GetVerticesRes: TVerticesResource;
var Item: TItem;
begin
  if ResolveLink('Geometry\Vertices', Item) then
    Result := Item as TVerticesResource
  else if Item is TVerticesResource then
    Result := Item as TVerticesResource
  else Result := nil;
end;

function TMesh.GetIndicesRes: TIndicesResource;
var Item: TItem;
begin
  if ResolveLink('Geometry\Indices', Item) then
    Result := Item as TIndicesResource
  else if Item is TIndicesResource then
    Result := Item as TIndicesResource
  else Result := nil;
end;

procedure TMesh.HandleMessage(const Msg: TMessage);

  procedure ReplacePointer(OldP, NewP: Pointer);
  var i: Integer; Tesselator: TMeshTesselator;
  begin
    for i := 0 to High(FTesselators) do
      if FTesselators[i] is TMeshTesselator then begin
        Tesselator := FTesselators[i] as TMeshTesselator;
        if Tesselator.Vertices = OldP then Tesselator.Vertices := NewP;
        if Tesselator.Indices  = OldP then Tesselator.Indices  := NewP;
        Tesselator.Init;
      end;
  end;

begin
  inherited;
  if Msg.ClassType = TDataAdressChangeMsg then
    with TDataAdressChangeMsg(Msg) do ReplacePointer(OldData, NewData);
end;

{ TRingMesh }

const uvtPlanar = 0; uvtRadial = 1;    // Ring UV mapping types

constructor TRingMesh.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLESTRIP;
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));

  InnerRadius := 0.8;
  OuterRadius := 1;
  Factor      := 0.5;
  Smoothing   := 8;
  Color1.C    := $80FF0000;
  Color2.C    := $800000FF;
  UVMapType   := uvtPlanar;
  UVFrame.U := 0; UVFrame.V := 0; UVFrame.W := 1; UVFrame.H := 1;
  Init;
end;

procedure TRingMesh.Init;
begin
  inherited;
  Invalidate([tbVertex, tbIndex], TotalVertices <> (Smoothing+1)*2);

  TotalVertices   := (Smoothing+1)*2;
  TotalIndices    := 0;
  TotalPrimitives := Smoothing*2;
  IndexingVertices := TotalVertices;
end;

function TRingMesh.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := (3*SizeOf(Longword) + 1*SizeOf(Integer) + 3*SizeOf(Single)) div 4;
  if Internal then Parameters := @FInnerRadius else Parameters := @InnerRadius;
end;

function TRingMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer; t, t1, t2, w, oos, sw, f: Single; Col: BaseTypes.TColor;
begin
  oos := 1/FSmoothing;
  if FFactor < 1 then begin
    sw := 1 - FFactor;
    f  := 1 / FFactor;
  end else begin
    sw := 0;
    f  := FFactor;
  end;
  if Abs(FOuterRadius) > Epsilon then t := 0.5 / FOuterRadius else t := 0;
  for i := 0 to Smoothing do begin              // Outer edge
//    w := Abs(Smoothing*0.5 - i)*2*oos * Factor;
    w := (Abs(FSmoothing*0.5 - i)*2*oos  - sw) * f;
    Col := BlendColor(FColor2, FColor1, w);
//   c1 --------- c2 --------- c1
    t1 := Cos(i/180*pi*360*oos); t2 := Sin(i/180*pi*360*oos);
    SetVertexDataC(t1*FOuterRadius, 0, t2*FOuterRadius, i*2, VBPTR);
    SetVertexDataD(Col, i*2, VBPTR);

    SetVertexDataC(t1*FInnerRadius, 0, t2*FInnerRadius, i*2+1, VBPTR);
    SetVertexDataD(Col, i*2+1, VBPTR);

    if FUVMapType = uvtPlanar then begin
      SetVertexDataUV(UVFrame.U + (i * oos) * UVFrame.W, UVFrame.V, i*2, VBPTR);
      SetVertexDataUV(UVFrame.U + (i * oos) * UVFrame.W, UVFrame.V + UVFrame.H, i*2+1, VBPTR);
    end else begin
      SetVertexDataUV(0.5 + t1 * FOuterRadius * t, 0.5 - t2 * FOuterRadius * t, i*2, VBPTR);
      SetVertexDataUV(0.5 + t1 * FInnerRadius * t, 0.5 - t2 * FInnerRadius * t, i*2+1, VBPTR);
    end;
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TRingMesh.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-OuterRadius, 0, -OuterRadius);
  Result.P2 := GetVector3s( OuterRadius, 0,  OuterRadius);
end;

{ TRing }

function TRing.GetTesselatorClass: CTesselator; begin Result := TRingMesh; end;

constructor TRing.Create(AManager: TItemsManager);
begin
  inherited;
  YAngle := 0+pi/4;
end;

procedure TRing.AddProperties(const Result: Props.TProperties);
var Mesh: TRingMesh;
begin
  inherited;
  if not Assigned(Result) or not (CurrentTesselator is TRingMesh) then Exit;
  Mesh := CurrentTesselator as TRingMesh;

  AddColorProperty(Result, 'Color\1', Mesh.Color1);
  AddColorProperty(Result, 'Color\2', Mesh.Color2);
  Result.Add('Color\Factor',          vtSingle, [], FloatToStr(Mesh.Factor),        '0-1');
  Result.Add('Geometry\Smoothing',    vtInt,    [], IntToStr(Mesh.Smoothing),       '3-32');
  Result.Add('Geometry\Inner radius', vtSingle, [], FloatToStr(Mesh.InnerRadius),   '');
  Result.Add('Geometry\Outer radius', vtSingle, [], FloatToStr(Mesh.OuterRadius),   '');
  Result.AddEnumerated('Texture\Map type',  [], Mesh.UVMapType, 'Planar\&Radial');
end;

procedure TRing.SetProperties(Properties: Props.TProperties);
var Mesh: TRingMesh;
begin
  inherited;
  if not (CurrentTesselator is TRingMesh) then Exit;
  Mesh := CurrentTesselator as TRingMesh;

  SetColorProperty(Properties, 'Color\1', Mesh.Color1);
  SetColorProperty(Properties, 'Color\2', Mesh.Color2);

  if Properties.Valid('Color\Factor')          then Mesh.Factor      := StrToFloatDef(Properties['Color\Factor'],          0);
  if Properties.Valid('Geometry\Smoothing')    then Mesh.Smoothing   := StrToIntDef(Properties['Geometry\Smoothing'],     0);
  if Properties.Valid('Geometry\Inner radius') then Mesh.InnerRadius := StrToFloatDef(Properties['Geometry\Inner radius'], 0);
  if Properties.Valid('Geometry\Outer radius') then Mesh.OuterRadius := StrToFloatDef(Properties['Geometry\Outer radius'], 0);
  if Properties.Valid('Texture\Map type')      then Mesh.UVMapType   := Properties.GetAsInteger('Texture\Map type');
  SetMesh;
end;

function TRing.GetColor: BaseTypes.TColor;
begin
  Result := TRingMesh(CurrentTesselator).Color1;
end;

procedure TRing.SetColor(const Value: BaseTypes.TColor);
var Mesh: TRingMesh;
begin
  if CurrentTesselator is TRingMesh then Mesh := CurrentTesselator as TRingMesh else Exit;
  Mesh.Color1 := Value;
  SetMesh;
end;

function TRing.VisibilityCheck(const Camera: TCamera): Boolean;
var CameraForward, Axis: TVector3s; Angle: Single;
begin
  Result := inherited VisibilityCheck(Camera);
  CameraForward := Transform3Vector3s(GetTransposedMatrix3s(CutMatrix3s(Camera.ViewMatrix)), GetVector3s(0, 0, 1));
  Axis := NormalizeVector3s(CrossProductVector3s(CameraForward, GetVector3s(0, 1, 0)));
//  Axis := Transform3Vector3s({TransposeMatrix3s(}CutMatrix3s(Transform), Axis);
  Angle := ArcTan2(-sqrt(Sqr(CameraForward.X) + Sqr(CameraForward.Z)), -CameraForward.Y);
  Orientation := MulQuaternion(GetQuaternion(-Angle, Axis), GetQuaternion(YAngle, GetVector3s(0, 1, 0)));
end;

{ TPolygon }

procedure TPolygon.AddPoint(v: TVector2s);
begin
  if CurrentTesselator is TPolyTesselator then TPolyTesselator(CurrentTesselator).Poly.Add(v);
  CurrentTesselator.Init();
end;

function TPolygon.GetTesselatorClass: CTesselator; begin Result := TPolyTesselator; end;

{ TPolyTesselator }

constructor TPolyTesselator.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLELIST;
  InitVertexFormat(GetVertexFormat(False, True, False, False, False, 0, [2]));
  Poly := T2DPointList.Create();
//  Poly.Add(Vec2s(0, 0));
//  Poly.Add(Vec2s(100, 0));
//  Poly.Add(Vec2s(100, 100));
  Init;
end;

destructor TPolyTesselator.Destroy;
begin
  FreeAndNil(Poly);
  inherited;
end;

procedure TPolyTesselator.Init;
var TriCnt: Integer;
begin
  inherited;
  TriCnt := MaxI(0, Poly.Count-2);

  Invalidate([tbVertex], TotalVertices <> TriCnt*3);

  TotalVertices    := TriCnt*3;
  TotalIndices     := 0;
  IndexingVertices := TotalVertices;
  TotalPrimitives  := TriCnt;
  if Poly.Count >= 3 then
    Triangles := Poly.Triangulate()
  else
    Triangles := nil;
end;

function TPolyTesselator.GetBoundingBox: TBoundingBox;
var i: Integer;
begin
  Result.P1 := GetVector3s(-100, 0, -100); Result.P2 := GetVector3s(100, 0, 100);
{  for i := 0 to TotalVertices-1 do with TVector3s((@TByteBuffer(FVertices^)[i*Integer(FVertexSize)])^), Result do begin
    if X < P1.X then P1.X := X; if Y < P1.Y then P1.Y := Y; if Z < P1.Z then P1.Z := Z;
    if X > P2.X then P2.X := X; if Y > P2.Y then P2.Y := Y; if Z > P2.Z then P2.Z := Z;
  end;}
end;

function TPolyTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer; tscale: Single;
begin
  Result := 0;
  if Length(Triangles) = 0 then Exit;

  tscale := 0.1;
  
  for i := 0 to High(Triangles) do begin
    SetVertexDataC(Triangles[i][0].X, 0, Triangles[i][0].Y, i*3, VBPTR);
    SetVertexDataN(0, 1, 0, i*3, VBPTR);
    SetVertexDataUV(Triangles[i][0].X*tscale, Triangles[i][0].Y*tscale, i*3, VBPTR);

    SetVertexDataC(Triangles[i][1].X, 0, Triangles[i][1].Y, i*3+1, VBPTR);
    SetVertexDataN(0, 1, 0, i*3+1, VBPTR);
    SetVertexDataUV(Triangles[i][1].X*tscale, Triangles[i][1].Y*tscale, i*3+1, VBPTR);

    SetVertexDataC(Triangles[i][2].X, 0, Triangles[i][2].Y, i*3+2, VBPTR);
    SetVertexDataN(0, 1, 0, i*3+2, VBPTR);
    SetVertexDataUV(Triangles[i][2].X*tscale, Triangles[i][2].Y*tscale, i*3+2, VBPTR);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
//  Status := tsChanged;
  LastTotalIndices := TotalIndices;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;

end;

begin
  GlobalClassList.Add('C2VisItems', GetUnitClassList);
end.
