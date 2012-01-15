(*
 @Abstract(CAST II Engine special effects unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains item and tesselator classes for basic special effects
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2FX;

interface

uses SysUtils, BaseTypes, Basics, BaseCont, Base3D, Props, BaseClasses, C2Types, CAST2, C2Visual, Resources;

const
  // Fade states
  fsNone = 0; fsFadeIn = 1; fsFadeOut = 2;

type
  T3DLineMesh = class(TTesselator)
  public
    Size1, Size2, Len, VScale: Single;
    Color1, Color2: BaseTypes.TColor;
    constructor Create; override;
    procedure Init; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  protected
    Point1, Point2: TVector4s;
    ModelMatrix: ^TMatrix4s;
    FSize1, FSize2, FLen, FVScale: Single;
    FColor1, FColor2: BaseTypes.TColor;
  end;

  T3DLine = class(TVisible)
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  protected
    function GetColor1: BaseTypes.TColor;
    procedure SetColor1(const Value: BaseTypes.TColor);
    function GetColor2: BaseTypes.TColor;
    procedure SetColor2(const Value: BaseTypes.TColor);
    function GetLength: Single;
    procedure SetLength(const Value: Single);
  public
    constructor Create(AManager: TItemsManager); override;
    function VisibilityCheck(const Camera: TCamera): Boolean; override;
    property Color1: BaseTypes.TColor read GetColor1 write SetColor1;
    property Color2: BaseTypes.TColor read GetColor2 write SetColor2;
    property Len: Single read GetLength write SetLength;
  end;

  TBackgroundTesselator = class(TTesselator)
  protected
    Cols, Rows: Integer;
  public
    Zoom, UOfs, VOfs: Single;
    Angle: Integer;
    Color: BaseTypes.TColor;
    constructor Create; override;
    function IsSameItem(AItem: TReferencedItem): Boolean; override;
    procedure Init; override;

    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;

    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

  // Shows a full-screen quad with color depending on processing time.
  // If AutoStop is True processing automatically stops when it reaches half of specified gradient.
  TFader = class(TVisible)
  private
    AutoStopNeeded: Boolean;
    procedure SetColor(const Value: TColor);
  public
    // Color gradient
    Colors: TSampledGradient;
    // Stop at half (probably when full visible) 
    AutoStop: Boolean;
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;
    
    function VisibilityCheck(const Camera: TCamera): Boolean; override;
    function GetTesselatorClass: CTesselator; override;
    procedure Show; override;
    procedure Process(const DeltaT: Single); override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TBackground = class(TVisible)
  protected
    function GetAngle: Integer;
    function GetColor: BaseTypes.TColor;
    function GetZoom: Single;
    procedure SetColor(const Value: BaseTypes.TColor);
    procedure SetAngle(const Value: Integer);
    procedure SetZoom(const Value: Single);
  public
    constructor Create(AManager: TItemsManager); override;
    function VisibilityCheck(const Camera: TCamera): Boolean; override;
    function GetTesselatorClass: CTesselator; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
    property Angle: Integer read GetAngle write SetAngle;
    property Zoom: Single read GetZoom write SetZoom;
  end;

  TBillboardMesh = class(TTesselator)
  private
    BBoxP1, BBoxP2: TVector3s;
  protected
    FColor: TColor;
    FWidth, FHeight: Single;
    FFrame: Integer;
  public
    MaxFrame: Integer;
    UVMap: TUVMap;
    constructor Create; override;
    function IsSameItem(AItem: TReferencedItem): Boolean; override;
    function GetBoundingBox: TBoundingBox; override;

    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;

    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    procedure SetFrame(const Value: Integer); virtual;

    property Frame: Integer read FFrame write SetFrame;
  end;

  // Shows a camera-oriented billboard. Can be textured and animated with an UV map.
  TBillboard = class(TVisible)
  protected
    AnimTime: Single;
  public
    AnimRate: Single;
    AnimRepeat, HideAtEnd: Boolean;
    constructor Create(AManager: TItemsManager); override;
    
    function VisibilityCheck(const Camera: TCamera): Boolean; override;
    function GetTesselatorClass: CTesselator; override;
    procedure ResolveLinks; override;

    procedure Process(const DeltaT: Single); override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TSplashTesselator = class(TTesselator)
  private
  public
    Color: TColor;
    Size: Single;
    constructor Create; override;
    function IsSameItem(AItem: TReferencedItem): Boolean; override;
    function GetBoundingBox: TBoundingBox; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TSplash = class(TVisible)
  public
    Color: TSampledGradient;
    Size: TSampledFloats;
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaT: Single); override;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([T3DLine, TFader, TBackground, TBillboard, TSplash]);
end;

{ T3DLineTesselator }

constructor T3DLineMesh.Create;
begin
  inherited;

  Len      := 1;
  Color1.C := $80808080;
  Color2.C := $80808080;
  Size1    := 0.05;  Size2 := 0.05;
  VScale   := 1;

  Init;

  PrimitiveType := ptTRIANGLEFAN;
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));

  TotalVertices   := 6;
  TotalPrimitives := 4;
end;

procedure T3DLineMesh.Init;
begin
  inherited;
  Point1 := GetVector4s(0, 0, 0, 1); Point2 := GetVector4s(0, 0, FLen, 1);
end;

function T3DLineMesh.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := 6;
  if Internal then Parameters := @FSize1 else Parameters := @Size1;
end;

function T3DLineMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  Trans1, Trans2: TVector4s;
  V, N, Cam: TVector3s;
  l, d, e: Single;
begin
//  Cam := CutVector3s(Transform4Vector4s(ModelMatrix^, ExpandVector3s(Camera.Position)));
//  Cam := GetVector3s(Params.Camera.Location.X, Camera.Location.Y, Camera.Location.Z);
  Cam := Params.Camera.GetAbsLocation;
//  Cam := ScaleVector3s(Camera.ViewOrigin, -1);
//  Cam := ScaleVector3s( Transform3Vector3s(InvertMatrix3s(CutMatrix3s(Params.Camera.ViewMatrix)), Params.Camera.ViewOrigin), -1);

  Trans1 := Transform4Vector4s(ModelMatrix^, Point1);
  Trans2 := Transform4Vector4s(ModelMatrix^, Point2);

//  Trans1 := CutVector3s(Point1); Trans2 := CutVector3s(Point2);

  N := SubVector4s(Trans2, Trans1).XYZ;                                   // Line vector in world
  V := GetVector3s(- Trans1.X + Cam.X, - Trans1.Y + Cam.Y, - Trans1.Z + Cam.Z);    // From Point1 to camera
{  W := N;
  d := DotProductVector3s(N, V);                                                   // V projected to N
  e := DotProductVector3s(N, W);
  I := AddVector3s(Trans1.XYZ, ScaleVector3s(W, d/e));

  N := CrossProductVector3s(GetVector3s(I.X - Cam.X, I.Y - Cam.Y, I.Z - Cam.Z), N);}

  N := CrossProductVector3s(V, N);

  N := Transform3Vector3s(InvertMatrix3s(CutMatrix3s(ModelMatrix^)), N);

  l := InvSqrt(SqrMagnitude(N));

//  N := GetVector3s(1, 0, 0); l := 1;

//  1           2
//        0
//  4           3

  SetVertexDataC((Point1.X + Point2.X) * 0.5, (Point1.Y + Point2.Y) * 0.5, (Point1.Z + Point2.Z) * 0.5, 0, VBPtr);
  SetVertexDataD(BlendColor(FColor1, FColor2, 0.5), 0, VBPtr);
  SetVertexDataUV(0.5, FVScale * 0.5, 0, VBPtr);

  SetVertexDataC(Point1.X - N.X * l * FSize1, Point1.Y - N.Y * l * FSize1, Point1.Z - N.Z * l * FSize1, 1, VBPtr);
  SetVertexDataD(FColor1, 1, VBPtr);
  SetVertexDataUV(0, FVScale, 1, VBPtr);

  SetVertexDataC(Point2.X - N.X * l * FSize2, Point2.Y - N.Y * l * FSize2, Point2.Z - N.Z * l * FSize2, 2, VBPtr);
  SetVertexDataD(FColor2, 2, VBPtr);
  SetVertexDataUV(0, 0 + 0*0.5, 2, VBPtr);

  {  SetVertexDataC(Point2.X, Point2.Y, Point2.Z, 3, VBPtr);
  SetVertexDataD(FColor2*0 + $FF008080, 3, VBPtr);
  SetVertexDataUV(0.5, 0, 3, VBPtr);}

  SetVertexDataC(Point1.X + N.X * l * FSize1, Point1.Y + N.Y * l * FSize1, Point1.Z + N.Z * l * FSize1, 4, VBPtr);
  SetVertexDataD(FColor1, 4, VBPtr);
  SetVertexDataUV(1, FVScale, 4, VBPtr);

  SetVertexDataC(Point2.X + N.X * l * FSize2, Point2.Y + N.Y * l * FSize2, Point2.Z + N.Z * l * FSize2, 3, VBPtr);
  SetVertexDataD(FColor2, 3, VBPtr);
  SetVertexDataUV(1, 0, 3, VBPtr);

  SetVertexDataC(Point1.X - N.X * l * FSize1, Point1.Y - N.Y * l * FSize1, Point1.Z - N.Z * l * FSize1, 5, VBPtr);
  SetVertexDataD(FColor1, 5, VBPtr);
  SetVertexDataUV(0, FVScale, 5, VBPtr);

//  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ T3DLine }

function T3DLine.GetTesselatorClass: CTesselator; begin Result := T3DLineMesh; end;

procedure T3DLine.AddProperties(const Result: Props.TProperties);
var Mesh: T3DLineMesh;
begin
  inherited;
  if not Assigned(Result) then Exit;

  if not (CurrentTesselator is T3DLineMesh) then Exit;
  Mesh := CurrentTesselator as T3DLineMesh;

  Result.Add('Geometry\Length',    vtSingle, [], FloatToStr(Mesh.Len), '');

  AddColorProperty(Result, 'Color\1', Mesh.Color1);
  AddColorProperty(Result, 'Color\2', Mesh.Color2);

  Result.Add('Geometry\Size near', vtSingle, [], FloatToStr(Mesh.Size1), '');
  Result.Add('Geometry\Size far',  vtSingle, [], FloatToStr(Mesh.Size2), '');

  Result.Add('Texture\V scale',   vtSingle, [], FloatToStr(Mesh.VScale), '');
end;

procedure T3DLine.SetProperties(Properties: Props.TProperties);
var Mesh: T3DLineMesh;
begin
  inherited;

  if not (CurrentTesselator is T3DLineMesh) then Exit;
  Mesh := CurrentTesselator as T3DLineMesh;

  if Properties.Valid('Geometry\Length')    then  Mesh.Len := StrToFloatDef(Properties['Geometry\Length'], 0);

  SetColorProperty(Properties, 'Color\1', Mesh.Color1);
  SetColorProperty(Properties, 'Color\2', Mesh.Color2);

  if Properties.Valid('Geometry\Size near') then Mesh.Size1 := StrToFloatDef(Properties['Geometry\Size near'], 0);
  if Properties.Valid('Geometry\Size far')  then Mesh.Size2 := StrToFloatDef(Properties['Geometry\Size far'],  0);

  if Properties.Valid('Texture\V scale')   then Mesh.VScale := StrToFloatDef(Properties['Texture\V scale'], 0);

  Mesh.ModelMatrix := @FTransform;

  CurrentTesselator.Init;
end;

function T3DLine.VisibilityCheck(const Camera: TCamera): Boolean;
begin
  Result := inherited VisibilityCheck(Camera);
  ComputeTransform;
end;

function T3DLine.GetColor1: BaseTypes.TColor;
begin
  if CurrentTesselator is T3DLineMesh then
   Result := (CurrentTesselator as T3DLineMesh).Color1 else
    Result.C := 0;
end;

procedure T3DLine.SetColor1(const Value: BaseTypes.TColor);
begin
  if not (CurrentTesselator is T3DLineMesh) then Exit;
  (CurrentTesselator as T3DLineMesh).Color1 := Value;
  CurrentTesselator.Init;
end;

function T3DLine.GetColor2: BaseTypes.TColor;
begin
  if CurrentTesselator is T3DLineMesh then
   Result := (CurrentTesselator as T3DLineMesh).Color2 else
    Result.C := 0;
end;

procedure T3DLine.SetColor2(const Value: BaseTypes.TColor);
begin
  if not (CurrentTesselator is T3DLineMesh) then Exit;
  (CurrentTesselator as T3DLineMesh).Color2 := Value;
  CurrentTesselator.Init;
end;

procedure T3DLine.SetLength(const Value: Single);
begin
  if not (CurrentTesselator is T3DLineMesh) then Exit;
  (CurrentTesselator as T3DLineMesh).Len := Value;
  CurrentTesselator.Init;
end;

function T3DLine.GetLength: Single;
begin
  if CurrentTesselator is T3DLineMesh then
   Result := (CurrentTesselator as T3DLineMesh).Len else
    Result := 0;
end;

constructor T3DLine.Create(AManager: TItemsManager);
begin
  inherited;
end;

{ TBackgroundTesselator }

constructor TBackgroundTesselator.Create;
begin
  inherited;
  Zoom  := 1;
  Cols  := 2;
  Rows  := 2;
  Angle := 0;
  Color.C := $FF808080;
  UOfs := 0;
  VOfs := 0;

  TesselationStatus[tbVertex].TesselatorType := ttStatic;

  PrimitiveType := ptTRIANGLELIST;
  InitVertexFormat(GetVertexFormat(True, False, True, False, False, 0, [2]));

  Init;
end;

function TBackgroundTesselator.IsSameItem(AItem: TReferencedItem): Boolean;
begin
  Result := False;
end;

procedure TBackgroundTesselator.Init;
begin
  inherited;
  TotalVertices    := (Cols)*(Rows);
  TotalIndices     := (Rows-1)*(Cols-1)*2*3;
  TotalPrimitives  := (Rows-1)*(Cols-1)*2;
  IndexingVertices := TotalVertices;

  Invalidate([tbVertex, tbIndex], True);
end;

procedure TBackgroundTesselator.AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add(PropNamePrefix + 'Columns',  vtNat,    [], IntToStr(Cols), '');
  Result.Add(PropNamePrefix + 'Rows',     vtNat,    [], IntToStr(Rows), '');
  Result.Add(PropNamePrefix + 'U offset', vtSingle, [], FloatToStr(UOfs), '');
  Result.Add(PropNamePrefix + 'V offset', vtSingle, [], FloatToStr(VOfs), '');
end;

procedure TBackgroundTesselator.SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid(PropNamePrefix + 'Columns')  then Cols := StrToIntDef(Properties[PropNamePrefix + 'Columns'], 0);
  if Properties.Valid(PropNamePrefix + 'Rows')     then Rows := StrToIntDef(Properties[PropNamePrefix + 'Rows'],    0);
  if Properties.Valid(PropNamePrefix + 'U offset') then UOfs := StrToFloatDef(Properties[PropNamePrefix + 'U offset'], 0);
  if Properties.Valid(PropNamePrefix + 'V offset') then VOfs := StrToFloatDef(Properties[PropNamePrefix + 'V offset'], 0);
end;

function TBackgroundTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  i, j: Integer;
  OOZoom, OOCols, OORows: Single;
begin
  Result := 0;
  if (Cols < 2) or (Rows < 2) then Exit;
  OOZoom := 1/Zoom; OOCols := 1/(Cols-1); OORows := 1/(Rows-1);     // Some optimizations
  for j := 0 to Rows-1 do for i := 0 to Cols-1 do begin
    SetVertexDataCRHW((i * OOCols) * Params.Camera.RenderWidth, (j * OORows) * Params.Camera.RenderHeight, 0, 0.001, j*Cols+i, VBPTR);
    SetVertexDataD(Color, j*Cols+i, VBPTR);
    SetVertexDataUV( ( (i * OOCols) * SinTable[(Angle + CosTabOffs) and (SinTableSize-1)] +
                       (j * OORows) * SinTable[(Angle) and (SinTableSize-1)] ) * OOZoom + UOfs,
                     ( (j * OORows) * SinTable[(Angle + CosTabOffs) and (SinTableSize-1)] -
                       (i * OOCols) * SinTable[(Angle) and (SinTableSize-1)] ) * OOZoom + VOfs,
                     j*Cols+i, VBPTR);
  end;
  TesselationStatus[tbVertex].Status := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TBackgroundTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
  for j := 0 to Rows-2 do begin
    for i := 0 to Cols-2 do begin
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+0] := (j+0)*(Cols)+i;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+1] := (j+0)*(Cols)+i+1;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+2] := (j+1)*(Cols)+i;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+3] := (j+1)*(Cols)+i;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+4] := (j+0)*(Cols)+i+1;
      TWordBuffer(IBPTR^)[(j*(Cols-1)+i)*6+5] := (j+1)*(Cols)+i+1
    end;
  end;
  TesselationStatus[tbIndex].Status := tsTesselated;
  Result := TotalIndices;
end;

{ TFader }

procedure TFader.SetColor(const Value: BaseTypes.TColor);
var Mesh: TBackgroundTesselator;
begin
  if CurrentTesselator is TBackgroundTesselator then
    Mesh := CurrentTesselator as TBackgroundTesselator
  else
    Exit;
  Mesh.Color := Value;
  Mesh.Invalidate([tbVertex], False);
end;

constructor TFader.Create(AManager: TItemsManager);
begin
  inherited;
  Colors := TSampledGradient.Create;
  Colors.MaxX := 2;
end;

destructor TFader.Destroy;
begin
  FreeAndNil(Colors);
  inherited;
end;

function TFader.GetTesselatorClass: CTesselator; begin Result := TBackgroundTesselator; end;

function TFader.VisibilityCheck(const Camera: TCamera): Boolean;
begin
  Result := True;
end;

procedure TFader.Show;
begin
  inherited;
  ResetProcessedTime();
  Resume();
  AutoStopNeeded := AutoStop;
end;

procedure TFader.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Colors.AddAsProperty(Result, 'Color');
  Result.Add('Auto stop', vtBoolean, [], OnOffStr[AutoStop], '');
end;

procedure TFader.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  Colors.SetFromProperty(Properties, 'Color');
  if Properties.Valid('Auto stop') then AutoStop := Properties.GetAsInteger('Auto stop') > 0;
end;

procedure TFader.Process(const DeltaT: Single);
begin
  inherited;
  SetColor(Colors.Value[TimeProcessed]);
  if AutoStopNeeded and (TimeProcessed > Colors.MaxX * 0.5) then begin
    Pause();
    AutoStopNeeded := False;
  end;
end;

{ TBackground }

function TBackground.GetAngle: Integer;
begin
  if CurrentTesselator is TBackgroundTesselator then Result := TBackgroundTesselator(CurrentTesselator).Angle else Result := 0;
end;

function TBackground.GetColor: BaseTypes.TColor;
begin
  if CurrentTesselator is TBackgroundTesselator then Result := TBackgroundTesselator(CurrentTesselator).Color else Result.C := $FF808080;
end;

function TBackground.GetZoom: Single;
begin
  if CurrentTesselator is TBackgroundTesselator then Result := TBackgroundTesselator(CurrentTesselator).Zoom else Result := 1;
end;

procedure TBackground.SetAngle(const Value: Integer);
begin
  if CurrentTesselator is TBackgroundTesselator then (CurrentTesselator as TBackgroundTesselator).Angle := Value;
  CurrentTesselator.Init;
end;

procedure TBackground.SetColor(const Value: BaseTypes.TColor);
begin
  if CurrentTesselator is TBackgroundTesselator then (CurrentTesselator as TBackgroundTesselator).Color := Value;
  CurrentTesselator.Init;
end;

procedure TBackground.SetZoom(const Value: Single);
begin
  if CurrentTesselator is TBackgroundTesselator then (CurrentTesselator as TBackgroundTesselator).Zoom := Value;
  CurrentTesselator.Init;
end;

constructor TBackground.Create(AManager: TItemsManager);
begin
  inherited;
end;

function TBackground.GetTesselatorClass: CTesselator; begin Result := TBackgroundTesselator; end;

function TBackground.VisibilityCheck(const Camera: TCamera): Boolean;
begin
  Result := True;
end;

procedure TBackground.AddProperties(const Result: Props.TProperties);
var Mesh: TBackgroundTesselator;
begin
  inherited;
  if not Assigned(Result) then Exit;
  if CurrentTesselator is TBackgroundTesselator then Mesh := CurrentTesselator as TBackgroundTesselator else begin
    AddErrorProperty(Result, 'Tesselator is undefined');
    Exit;
  end;

  AddColorProperty(Result, 'Color', Mesh.Color);
  Result.Add('Angle',   vtInt,    [], IntToStr(Mesh.Angle), '');
  Result.Add('Zoom',    vtSingle, [], FloatToStr(Mesh.Zoom), '');
end;

procedure TBackground.SetProperties(Properties: Props.TProperties);
var Mesh: TBackgroundTesselator;
begin
  inherited;
  if CurrentTesselator is TBackgroundTesselator then Mesh := CurrentTesselator as TBackgroundTesselator else Exit;

  SetColorProperty(Properties, 'Color', Mesh.Color);
  if Properties.Valid('Angle')   then Mesh.Angle := StrToIntDef(Properties['Angle'],   0);
  if Properties.Valid('Zoom')    then Mesh.Zoom  := StrToFloatDef(Properties['Zoom'],  0);

  Mesh.Init;
end;

{ TBillboardMesh }

constructor TBillboardMesh.Create;
begin
  inherited;
  TesselationStatus[tbVertex].TesselatorType := ttDynamic;
  PrimitiveType := ptTRIANGLESTRIP;
  InitVertexFormat(GetVertexFormat(True, False, True, False, False, 0, [2]));

  TotalIndices    := 0;
  TotalVertices   := 4;
  TotalPrimitives := 2;
  IndexingVertices := 4;

  Invalidate([tbVertex, tbIndex], True);

  BBoxP1 := ZeroVector3s;
  BBoxP2 := ZeroVector3s;

  MaxFrame := 0;
  UVMap := GetDefaultUVMap;
end;

function TBillboardMesh.IsSameItem(AItem: TReferencedItem): Boolean;
begin
  Result := False;
end;

function TBillboardMesh.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := BBoxP1;
  Result.P2 := BBoxP2;
end;

procedure TBillboardMesh.AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add(PropNamePrefix + 'Width',  vtSingle, [], FloatToStr(FWidth), '');
  Result.Add(PropNamePrefix + 'Height', vtSingle, [], FloatToStr(FHeight), '');
  Result.Add('Frame', vtInt, [], IntToStr(FFrame), '0-' + IntToStr(MaxFrame));
  AddColorProperty(Result, PropNamePrefix + 'Color', FColor);
end;

procedure TBillboardMesh.SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid(PropNamePrefix + 'Width')  then FWidth  := StrToFloatDef(Properties[PropNamePrefix + 'Width'],  0);
  if Properties.Valid(PropNamePrefix + 'Height') then FHeight := StrToFloatDef(Properties[PropNamePrefix + 'Height'], 0);
  if Properties.Valid('Frame') then FFrame := StrToIntDef(Properties['Frame'], 0);
  SetColorProperty(Properties, PropNamePrefix + 'Color', FColor);
end;

function TBillboardMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var Transformed: TVector4s; Location: TVector3s; TRHW, SizeX, SizeY: Single;
begin
  Result := 0;
  LastTotalVertices := 0;

  if FFrame > MaxFrame then Exit;

//  Location := Transform4Vector33s({InvertAffineMatrix4s(} Params.Camera.ViewMatrix, Vec3s(0, 0, 0));
  with Params.ModelMatrix do Location := GetVector3s(_41, _42, _43);

  Transformed := Transform4Vector3s(Params.Camera.TotalMatrix, Location);
  if Transformed.W < epsilon then Exit;

  TRHW := 1/Transformed.W;
  SizeX := Params.Camera.RenderWidth *0.5;
  SizeY := Params.Camera.RenderHeight*0.5;

  Transformed.X := SizeX * (1 + Transformed.X * TRHW);
  Transformed.Y := SizeY * (1 - Transformed.Y * TRHW);

  SizeX := FWidth  * TRHW * SizeX;
  SizeY := FHeight * TRHW * SizeY * Params.Camera.CurrentAspectRatio;

  //  InvCam := InvertMatrix3s(CutMatrix3s(Params.Camera.TotalMatrix)
  BBoxP1 := Transform3Vector3s(InvertMatrix3s( CutMatrix3s(Params.Camera.ViewMatrix) ), Vec3s(-SizeX, -SizeY, 0));
  BBoxP2 := Transform3Vector3s(InvertMatrix3s( CutMatrix3s(Params.Camera.ViewMatrix) ), Vec3s( SizeX,  SizeY, 0));

  with Params.Camera do Transformed.Z := 0.002+0*(ZFar/(ZFar-ZNear))*(1-ZNear/(Transformed.Z));

  SetVertexDataCRHW(Transformed.X - SizeX, Transformed.Y - SizeY, Transformed.Z, TRHW, 0, VBPTR);
  SetVertexDataD(FColor, 0, VBPTR);
  SetVertexDataUV(UVMap[FFrame].U, UVMap[FFrame].V, 0, VBPTR);

  SetVertexDataCRHW(Transformed.X + SizeX, Transformed.Y - SizeY, Transformed.Z, TRHW, 1, VBPTR);
  SetVertexDataD(FColor, 1, VBPTR);
  SetVertexDataUV(UVMap[FFrame].U + UVMap[FFrame].W, UVMap[FFrame].V, 1, VBPTR);

  SetVertexDataCRHW(Transformed.X - SizeX, Transformed.Y + SizeY, Transformed.Z, TRHW, 2, VBPTR);
  SetVertexDataD(FColor, 2, VBPTR);
  SetVertexDataUV(UVMap[FFrame].U, UVMap[FFrame].V + UVMap[FFrame].H, 2, VBPTR);

  SetVertexDataCRHW(Transformed.X + SizeX, Transformed.Y + SizeY, Transformed.Z, TRHW, 3, VBPTR);
  SetVertexDataD(FColor, 3, VBPTR);
  SetVertexDataUV(UVMap[FFrame].U + UVMap[FFrame].W, UVMap[FFrame].V + UVMap[FFrame].H, 3, VBPTR);

  TesselationStatus[tbVertex].Status := tsChanged;            // The vertex buffer should be updated every frame

  LastTotalVertices := 4;
  Result := LastTotalVertices;
end;

procedure TBillboardMesh.SetFrame(const Value: Integer);
begin
  if (Value = FFrame) then Exit;
  FFrame := ClampI(Value, 0, MaxFrame);
end;

{ TBillboard }

constructor TBillboard.Create(AManager: TItemsManager);
begin
  inherited;
end;

function TBillboard.GetTesselatorClass: CTesselator; begin Result := TBillboardMesh; end;

function TBillboard.VisibilityCheck(const Camera: TCamera): Boolean;
begin
  Result := True;                    // ToFix: cull out when behind camera
end;

procedure TBillboard.ResolveLinks;
var Item: TItem; Mesh: TBillboardMesh;
begin
  inherited;
  if CurrentTesselator is TBillboardMesh then Mesh := CurrentTesselator as TBillboardMesh else Exit;

  ResolveLink('UV map', Item);
  if Assigned(Item) then begin
    Mesh.UVMap    := (Item as TUVMapResource).Data;
    Mesh.MaxFrame := (Item as TUVMapResource).TotalElements-1;
  end;
end;

procedure TBillboard.Process(const DeltaT: Single);
var Mesh: TBillboardMesh; NewFrame: Integer;
begin
  inherited;
  AnimTime := AnimTime + DeltaT;
  if CurrentTesselator is TBillboardMesh then begin
    Mesh := CurrentTesselator as TBillboardMesh;
    NewFrame := Round(AnimTime * AnimRate);
    if (Mesh.MaxFrame >= 0) and (NewFrame > Mesh.MaxFrame) then begin
      if AnimRepeat then Mesh.Frame := NewFrame mod (Mesh.MaxFrame+1);
      if HideAtEnd  then State := State - [isVisible];
    end else Mesh.Frame := NewFrame
  end;
end;

procedure TBillboard.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  AddItemLink(Result, 'UV map',  [], 'TUVMapResource');

  if not Assigned(Result) then Exit;
  if not (CurrentTesselator is TBillboardMesh) then begin
    AddErrorProperty(Result, 'Tesselator is undefined');
    Exit;
  end;

  Result.Add('Animation rate',  vtSingle,  [], FloatToStr(AnimRate), '');
  Result.Add('Animation cycle', vtBoolean, [], OnOffStr[AnimRepeat], '');
  Result.Add('Hide at end',     vtBoolean, [], OnOffStr[HideAtEnd],  '');
end;

procedure TBillboard.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid('UV map') then SetLinkProperty('UV map', Properties['UV map']);

  if Properties.Valid('Animation rate')  then begin
    AnimRate := StrToFloatDef(Properties['Animation rate'], 0);
    AnimTime := 0;
  end;  
  if Properties.Valid('Animation cycle') then Animrepeat := Properties.GetAsInteger('Animation cycle') > 0;
  if Properties.Valid('Hide at end')     then HideAtEnd  := Properties.GetAsInteger('Hide at end')     > 0;
end;

{ TSplashTesselator }

constructor TSplashTesselator.Create;
begin
  inherited;
  PrimitiveType    := ptTRIANGLESTRIP;
  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));

  TotalVertices    := 4;
  TotalPrimitives  := 2;

  Color.C  := $80808080;
  Size     := 1;
end;

function TSplashTesselator.IsSameItem(AItem: TReferencedItem): Boolean;
begin
  Result := False;
end;

function TSplashTesselator.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-Size, -Size, 0);
  Result.P2 := GetVector3s( Size,  Size, 0);
end;

function TSplashTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
begin
  SetVertexDataC(-Size, Size, 0, 0, VBPTR);
  SetVertexDataUV(0, 0, 0, VBPTR);
  SetVertexDataD(Color, 0, VBPTR);

  SetVertexDataC(Size, Size, 0, 1, VBPTR);
  SetVertexDataUV(1, 0, 1, VBPTR);
  SetVertexDataD(Color, 1, VBPTR);

  SetVertexDataC(-Size, -Size, 0, 2, VBPTR);
  SetVertexDataUV(0, 1, 2, VBPTR);
  SetVertexDataD(Color, 2, VBPTR);

  SetVertexDataC(Size, -Size, 0, 3, VBPTR);
  SetVertexDataUV(1, 1, 3, VBPTR);
  SetVertexDataD(Color, 3, VBPTR);

  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result            := TotalVertices;
end;

{ TSplash }

constructor TSplash.Create(AManager: TItemsManager);
begin
  inherited;
  Color := TSampledGradient.Create;
  Size  := TSampledFloats.Create;
end;

destructor TSplash.Destroy;
begin
  FreeAndNil(Color);
  FreeAndNil(Size);
  inherited;
end;

function TSplash.GetTesselatorClass: CTesselator; begin Result := TSplashTesselator; end;

procedure TSplash.AddProperties(const Result: Props.TProperties);

begin
  inherited;
  if not Assigned(Result) then Exit;
  Color.AddAsProperty(Result, 'Color');
  Size.AddAsProperty(Result, 'Size');
end;

procedure TSplash.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  Color.SetFromProperty(Properties, 'Color');
  Size.SetFromProperty(Properties, 'Size');
  SetMesh;
  ResetProcessedTime;
end;

procedure TSplash.Process(const DeltaT: Single);
var Tesselator: TSplashTesselator;
begin
  inherited;
  if not (CurrentTesselator is TSplashTesselator) then Exit;
  Tesselator := CurrentTesselator as TSplashTesselator;
  Tesselator.Color := Color.Value[TimeProcessed];
  Tesselator.Size  := Size.Value[TimeProcessed];
  Tesselator.Invalidate([tbVertex], False);
end;

begin
  GlobalClassList.Add('C2FX', GetUnitClassList);
end.
