(*
 @Abstract(CAST II Engine landscapes unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: 29.01.2007 <br>
 Unit contains basic landscape classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Land;

interface

uses
  Logger,
  SysUtils,
  BaseTypes, BaseMsg, Basics, BaseStr, Base2D, Base3D, Props, BaseGraph,
  BaseClasses,
  Geometry,
  C2Types, C2Res, CAST2, Resources, C2Visual, C2Maps, C2MapEditMsg,
  C2Render, C2Core;

const
  // Enumeration strings for light map type
  LightmapTypesEnum = 'Light map' + StringDelimiter + 'Normal map';

  MipColors: array[0..15] of TColor = ((C: $00000000), (C: $00000080), (C: $00008000), (C: $00008080),
                                       (C: $00800000), (C: $00800080), (C: $00808000), (C: $00808080),
                                       (C: $00404040), (C: $000000FF), (C: $0000FF00), (C: $0000FFFF),
                                       (C: $00FF0000), (C: $00FF00FF), (C: $00FFFF00), (C: $00FFFFFF));



type
  // Type of texture used for landscape lighting
  TLightmapType = (// Simple lightmap for FFP lighting
                   lmtLightMap,
                   // Texture contains normals to calculate lighting in shader
                   lmtNormalMap);

  THeightMap = class(C2Maps.TMap)
  protected
    FImage: Resources.TImageResource;
    function GetData: Pointer; override;
    procedure ResolveLinks; override;
    function GetRawHeight(XI, ZI: Integer): Integer; override;
    procedure SetRawHeight(XI, ZI: Integer; const Value: Integer); override;
  public
    constructor Create(AManager: TItemsManager); override;

    procedure SwapRectHeights(const ARect: TRect; ABuf: Pointer); override;

    procedure SetDimensions(AWidth, AHeight: Integer); override;
    procedure SetImage(Image: Resources.TImageResource); virtual;

    function IsReady: Boolean; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    property Image: Resources.TImageResource read FImage;
  end;

  THeightMapTesselator = class(TMappedTesselator)
  protected
    FTextureScale: Single;
  public
    constructor Create; override;

    procedure Init; override;
    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;

    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

  THeightMapLandscape = class(C2Visual.TMappedItem)
  public
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TIslandTesselator = class(TMappedTesselator)
  private
    // Params
    FIslandThickness, FTextureScale: Single;
  public
    IslandThickness, TextureScale: Single;
    constructor Create; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;
    procedure Init; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

  TIsland = class(C2Visual.TMappedItem)
  public
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  end;

  TVertexWaterTesselator = class(THeightMapTesselator)
  private
    // Parameters
    FWaterColor: TColor;
    FWavesSpeed, FWavesFalloff, FViscosity: Single;
    FFullRefAngle: Integer;
    // Other
    Vel, Arr: array of single;
  public
    WaterColor: TColor;
    WavesSpeed, WavesFalloff, Viscosity: Single;
    FullRefAngle: Integer;
    procedure Init; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;

    procedure Iterate;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TVertexWater = class(THeightMapLandscape)
  private
    Counter: Cardinal;
    WaterColor: TColor;
    WavesSpeed, WavesFalloff, Viscosity: Single;
    FullRefAngle: Integer;
  public
    function GetTesselatorClass: CTesselator; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Process(const DeltaTime: Single); override;
  end;

  TQuadPoints = array[0..3] of TVector3s;

  TProjectedLandTesselator = class(THeightMapTesselator)
  private
protected
    // Params
    FGridWidth, FGridHeight, SmoothX, SmoothZ: Integer;
    MipBias, MipScale, DetailBalance, ViewDepth: Single;
    ExcessDist, TrilinearRange: Single;
    // Other

    CameraDir, CameraRight: TVector3s;
    FlipSign: Single;

    NearMip, FarMip: Integer;
    MipDetail: array[0..31] of Integer;
    MipStart:  array[0..31] of Single;
    MipTexture: array[0..31] of Integer;

    FMipZ: array of Single;
    CamOfsX, CamOfsZ: Single;
    LastTexUpdX, LastTexUpdZ: Single;
    FMegaTextureScale: Single;
    FLastClipmapSize, FClipmapSize: Integer;

    Renderer: TRenderer;

    FGrid: array of TVector2s;
  protected
    OldCameraMatrix: TMatrix4s;
//    function GetCameraInModel: TVector3s;
    procedure ProjectGrid(const Params: TTesselationParameters; out PrjPnt: TQuadPoints);
  public
    constructor Create; override;
    destructor Destroy; override;

    function GetMaxVertices: Integer; override;
    procedure Init; override;

    procedure DoManualRender(Item: TItem); override;

    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); override;
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); override;
  end;

  TProjGridTesselator = class(TProjectedLandTesselator)
  private
    Pnt, PrjPnt: TQuadPoints;
  public
    function GetUpdatedElements(Buffer: TTesselationBuffer; const Params: TTesselationParameters): Integer; override;

    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

  TRadGridTesselator = class(TProjectedLandTesselator)
  private
    procedure InitGrid;
  public
    procedure Init; override;
    function GetUpdatedElements(Buffer: TTesselationBuffer; const Params: TTesselationParameters): Integer; override;

    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

  TProjectedLandscape = class(C2Visual.TMappedItem)
  private
    ShaderConsts: TShaderConstants;
    procedure InitShaderConstants;
    function GetMegaTexture: TMegaImageResource;
  protected
    FLightmapType: TLightmapType;
    FTextureScale: Single;
    procedure OnModify(const ARect: BaseTypes.TRect); override;
  public
    constructor Create(AManager: TItemsManager); override;

    function VisibilityCheck(const Camera: TCamera): Boolean; override;

    procedure OnSceneLoaded; override;

    procedure RetrieveShaderConstants(var ConstList: TShaderConstants); override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure HandleMessage(const Msg: TMessage); override;

    procedure Process(const DeltaTime: Single); override;

    // Returns projected on the landscape four projected camera frustum points 
    procedure ProjectGrid(const Camera: TCamera; out PrjPnt: TQuadPoints);

    procedure RecalcLightMap(ARect: BaseTypes.TRect);

    property MegaTexture: TMegaImageResource read GetMegaTexture;
  end;

  TProjGridLandscape = class(TProjectedLandscape)
  public
    function GetTesselatorClass: CTesselator; override;
  end;

  TRadGridLandscape = class(TProjectedLandscape)
  public
    function GetTesselatorClass: CTesselator; override;
  end;

  TLandscapeShadowMapCamera = class(TShadowMapCamera)
  protected
    // Active camera before the shadow map render
    FOldCamera: TCamera;
    // If a landscape is specified it will be used to optimize shadow camera frustum
    FLandscape: TProjectedLandscape;
    procedure ResolveLinks; override;
  public
    procedure HandleMessage(const Msg: TMessage); override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    // Calculates camera view matrix according to FLight
    procedure ComputeViewMatrix; override;
    // OnApply event overridden to assign previous camera variable and setup clipping plane
    procedure OnApply(const OldCamera: TCamera); override;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TMap, THeightMap, THeightMapLandscape, TIsland, TVertexWater, TProjGridLandscape, TRadGridLandscape]);
end;

{ TIslandTesselator }

constructor TIslandTesselator.Create;
begin
  inherited;
  IslandThickness := 1;
  TextureScale    := 0.1;
end;

function TIslandTesselator.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := 2;
  if Internal then Parameters := @FIslandThickness else Parameters := @IslandThickness;
end;

procedure TIslandTesselator.Init;
begin
  inherited;
  if Assigned(FMap) then begin
    TotalVertices   := FMap.Width*FMap.Height;
    TotalIndices    := MaxI(0, (FMap.Width-1)) * MaxI(0, (FMap.Height-1)) * 6;
    TotalPrimitives := MaxI(0, (FMap.Width-1)) * MaxI(0, (FMap.Height-1)) * 2;
  end else begin
    TotalVertices   := 0;
    TotalIndices    := 0;
    TotalPrimitives := 0;
  end;
  IndexingVertices := TotalVertices;  
  PrimitiveType    := ptTRIANGLELIST;
  InitVertexFormat(GetVertexFormat(False, True, False, False, False, 0, [2]));
end;

function TIslandTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i, j: Integer; HalfLengthX, HalfLengthZ, y: Single;
begin
  Result := 0;
  if not Assigned(FMap) or not FMap.IsReady then Exit;

  HalfLengthX := (FMap.Width-1)  * FMap.CellWidthScale  * 0.5;
  HalfLengthZ := (FMap.Height-1) * FMap.CellHeightScale * 0.5;

  for j := 0 to FMap.Height-1 do for i := 0 to FMap.Width-1 do begin
    SetVertexDataUV(i * FTextureScale, j * FTextureScale, j * FMap.Width + i, VBPTR);
    if (i = 0) or (j = 0) or (i = FMap.Width-1) or (j = FMap.Height-1) or
//       (HMap.GetCellHeight(i-1, j-1) = 0) or (HMap.GetCellHeight(i+1, j-1) = 0) or
//       (HMap.GetCellHeight(i-1, j+1) = 0) or (HMap.GetCellHeight(i+1, j+1) = 0) or
       (FMap[i-1, j] = 0) or (FMap[i+1, j] = 0) or
       (FMap[i, j-1] = 0) or (FMap[i, j+1] = 0) then begin
      Y := -FIslandThickness;
//      SetVertexDataD(FMap.GetCellColor(i, j) and $FFFFFF, j * FMap.Width + i, VBPTR);
    end else begin
      Y := FMap[i+Ord(i=0)-Ord(i=FMap.Width-1), j+Ord(j=0)-Ord(j=FMap.Height-1)] * FMap.DepthScale;
//      SetVertexDataD(FMap.GetCellColor(i, j) or $FF000000, j * FMap.Width + i, VBPTR);
    end;
    SetVertexDataC(i * FMap.CellWidthScale - HalfLengthX, Y, j * FMap.CellHeightScale - HalfLengthZ, j * FMap.Width + i, VBPTR);
    SetVertexDataN(FMap.GetCellNormal(i, j), j * FMap.Width + i, VBPTR);
//    SetVertexDataD(GetColor($FFFFFFFF), j * FMap.Width + i, VBPTR);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
  Result  := TotalVertices;
  IndexingVertices  := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TIslandTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer; y11, y12, y21, y22, Points: Integer;
begin
{ * *     * * * * * * * *
  * * * * *     * * * * *
  * * * * *     * *   * *
  * * * * * * * * * * * * }
  TotalPrimitives := 0;
  if Assigned(FMap) and FMap.IsReady then for j := 0 to FMap.Height-2 do for i := 0 to FMap.Width-2 do begin
    y11 := FMap[i, j];
    y12 := FMap[i, j+1];
    y21 := FMap[i+1, j];
    y22 := FMap[i+1, j+1];
//                  8                      4                    2                    1
    Points := Ord(y11 > 0) shl 3 + Ord(y12 > 0) shl 2 + Ord(y21 > 0) shl 1 + Ord(y22 > 0);
    case Points of
      7: begin                           // y11 zero
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] := (j+1) * FMap.Width + i;         //  *
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * FMap.Width + i+1;       // **
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] :=  j    * FMap.Width + i+1;
        Inc(TotalPrimitives);
      end;
      11: begin                           // y12 zero
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] :=  j    * FMap.Width + i;         // **
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * FMap.Width + i+1;       //  *
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] :=  j    * FMap.Width + i + 1;
        Inc(TotalPrimitives);
      end;
      13: begin                           // y21 zero
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] :=  j    * FMap.Width + i;         // *
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * FMap.Width + i;         // **
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] := (j+1) * FMap.Width + i+1;
        Inc(TotalPrimitives);
      end;
      14: begin                           // y22 zero
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] :=  j    * FMap.Width + i;         // **
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * FMap.Width + i;         // *
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] :=  j    * FMap.Width + i+1;
        Inc(TotalPrimitives);
      end;
      15: begin                           // All points
        TWordBuffer(IBPTR^)[TotalPrimitives*3+0] :=  j    * FMap.Width + i;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+1] := (j+1) * FMap.Width + i;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+2] := (j+1) * FMap.Width + i+1;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+3] :=  j    * FMap.Width + i;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+4] := (j+1) * FMap.Width + i+1;
        TWordBuffer(IBPTR^)[TotalPrimitives*3+5] :=  j    * FMap.Width + i+1;
        Inc(TotalPrimitives, 2);
      end;
    end;
  end;
  TotalIndices := TotalPrimitives*3;
  TesselationStatus[tbIndex].Status := tsTesselated;
  Result := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

{ TIsland }

function TIsland.GetTesselatorClass: CTesselator; begin Result := TIslandTesselator; end;

procedure TIsland.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if Assigned(Result) and Assigned(CurrentTesselator) then begin
    Result.Add('Thickness',    vtSingle, [], FloatToStr(TIslandTesselator(CurrentTesselator).IslandThickness), '0,1-10');
    Result.Add('TextureScale', vtSingle, [], FloatToStr(TIslandTesselator(CurrentTesselator).TextureScale),    '0,01-10');
  end;
end;

procedure TIsland.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Assigned(CurrentTesselator) then begin
    if Properties.Valid('Thickness')    then TIslandTesselator(CurrentTesselator).IslandThickness := StrToFloatDef(Properties['Thickness'],    0);
    if Properties.Valid('TextureScale') then TIslandTesselator(CurrentTesselator).TextureScale    := StrToFloatDef(Properties['TextureScale'], 0);
//    CurrentTesselator.Init;
    SetMesh;
  end;
end;

{ THeightMapTesselator }

constructor THeightMapTesselator.Create;
begin
  inherited;
  FTextureScale    := 0.1;
end;

procedure THeightMapTesselator.Init;
begin
  inherited;
  if Assigned(FMap) then begin
    TotalVertices   := FMap.Width*FMap.Height;
    TotalPrimitives := MaxI(0, (FMap.Width-1)) * 2;
    TotalStrips     := MaxI(0, (FMap.Height-1));
    TotalIndices    := FMap.Width * (FMap.Height-1) * 2;
    StripOffset     := FMap.Width;
  end else begin
    TotalVertices   := 0;
    TotalStrips     := 0;
    TotalIndices    := 0;
    TotalPrimitives := 0;
    StripOffset     := 0;
  end;

  PrimitiveType    := ptTRIANGLESTRIP;

  IndexingVertices := TotalPrimitives+2;

  InitVertexFormat(GetVertexFormat(False, True, False, False, False, 0, [2]));
end;

procedure THeightMapTesselator.AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Assigned(Result) then begin
    Result.Add(PropNamePrefix + 'TextureScale', vtSingle, [], FloatToStr(FTextureScale), '0,01-4');
  end;
end;

procedure THeightMapTesselator.SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid(PropNamePrefix + 'TextureScale') then FTextureScale := StrToFloatDef(Properties[PropNamePrefix + 'TextureScale'], 0.1);
end;

function THeightMapTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i, j: Integer; HalfLengthX, HalfLengthZ, y: Single;
begin
  Result := 0;
  if not Assigned(FMap) or (FMap.Width = 0) or (FMap.Height = 0) then Exit;

  HalfLengthX := (FMap.Width-1)  * FMap.CellWidthScale  * 0.5;
  HalfLengthZ := (FMap.Height-1) * FMap.CellHeightScale * 0.5;

  for j := 0 to FMap.Height-1 do for i := 0 to FMap.Width-1 do begin
    SetVertexDataUV(i * FTextureScale, j * FTextureScale, j * FMap.Width + i, VBPTR);
    Y := FMap[i, j] * FMap.DepthScale;
    SetVertexDataC(i * FMap.CellWidthScale - HalfLengthX,
                   Y,
                   j * FMap.CellHeightScale - HalfLengthZ,
                   j * FMap.Width + i, VBPTR);
    SetVertexDataN(FMap.GetCellNormal(i, j), j * FMap.Width + i, VBPTR);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
  Result  := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function THeightMapTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
  for j := 0 to TotalStrips-1 do for i := 0 to FMap.Width-1 do begin
    TWordBuffer(IBPTR^)[(j * FMap.Width + i)*2]   := (0*j+0) * FMap.Width + i;
    TWordBuffer(IBPTR^)[(j * FMap.Width + i)*2+1] := (0*j+1) * FMap.Width + i;
  end;

  TesselationStatus[tbIndex].Status := tsTesselated;
  Result  := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

{ THeightMapLandscape }

function THeightMapLandscape.GetTesselatorClass: CTesselator;
begin
  Result := THeightMapTesselator;
end;

procedure THeightMapLandscape.AddProperties(const Result: Props.TProperties);
begin
  inherited;
end;

procedure THeightMapLandscape.SetProperties(Properties: Props.TProperties);
begin
  inherited;
end;

{ THeightMap }

const ImagePropName = 'Image';

function THeightMap.GetData: Pointer;
begin
  if Assigned(FImage) then Result := FImage.Data else Result := nil;
end;

procedure THeightMap.ResolveLinks;
var Item: TItem;
begin
  inherited;
  ResolveLink(ImagePropName, Item);
  if Assigned(Item) then SetImage(Item as Resources.TImageResource);
end;

function THeightMap.GetRawHeight(XI, ZI: Integer): Integer;
begin
  Assert((XI >= 0) and (ZI >= 0) and (XI < Width) and (ZI < Height), ClassName + '.GetCellHeight: Invalid cell index');
  Result := BaseTypes.PByteBuffer(FImage.Data)^[ZI * Width + XI];
end;

procedure THeightMap.SetRawHeight(XI, ZI: Integer; const Value: Integer);
begin
  Assert((XI >= 0) and (ZI >= 0) and (XI < Width) and (ZI < Height), ClassName + '.SetRawHeight: Invalid cell index');
  BaseTypes.PByteBuffer(FImage.Data)^[ZI * Width + XI] := Value;
end;

procedure THeightMap.SwapRectHeights(const ARect: TRect; ABuf: Pointer);
begin
  inherited;
  FImage.GenerateMipLevels(ARect);
end;

procedure THeightMap.SetDimensions(AWidth, AHeight: Integer);
begin
  inherited;
end;

procedure THeightMap.SetImage(Image: Resources.TImageResource);
//var i, j: Integer;
begin
  if Assigned(Image) then begin
    if (GetBytesPerPixel(Image.Format) <> 1) then begin
      Log(Format('%S("%S").%S: a 8 bits per pixel image required', [ClassName, GetFullName, 'SetImage']), lkError);
      Exit;
    end;
    if Image.MipPolicy = mpNoMips then begin
      Log(Format('%S("%S").%S: an image with mipmaps enabled required', [ClassName, GetFullName, 'SetImage']), lkError);
//      Exit;
    end;
  end;
  FImage := Image;
end;

procedure THeightMap.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if Assigned(Result) then begin
  end;

  AddItemLink(Result, ImagePropName, [], 'TImageResource');
end;

procedure THeightMap.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid(ImagePropName) then SetLinkProperty(ImagePropName, Properties[ImagePropName]);

  ResolveLinks;
end;

constructor THeightMap.Create(AManager: TItemsManager);
begin
  inherited;
  FMaxHeight   := 255;                                   // 8-bit heights
  FElementSize := 1;
end;

function THeightMap.IsReady: Boolean;
begin
  Result := inherited IsReady and Assigned(FImage) and Assigned(FImage.Data);
end;

{ TVertexWaterTesselator }

procedure TVertexWaterTesselator.Init;
begin
  inherited;
  if Assigned(FMap) then begin
    SetLength(arr, TotalVertices);
    SetLength(Vel, TotalVertices);
    FillChar(arr[0], TotalVertices*4, 0);
    FillChar(vel[0], TotalVertices*4, 0);
  end;
  InitVertexFormat(GetVertexFormat(False, True, True, False, False, 0, [2]));
end;

function TVertexWaterTesselator.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result := 5;
  if Internal then Parameters := @FWaterColor else Parameters := @WaterColor;
end;

const MaxArr = 1000000000.0;

procedure TVertexWaterTesselator.Iterate;
//const k = 0.25;  VC = 0.25*1+0*1; FalOff = 1*1+0*0.98; RestoreForce = 1*0+1*0.98;
var i, j: Integer;
begin
  for j := 1 to FMap.Height-2 do
    for i := 1 to FMap.Width-2 do
      vel[j * FMap.Width + i] := (vel[j * FMap.Width + i] +
                                       (-arr[j * FMap.Width + i]*4 +
                                         arr[(j+1) * FMap.Width + i] + arr[(j-1) * FMap.Width + i] +
                                         arr[j * FMap.Width + i + 1] + arr[j * FMap.Width + i - 1]) * FWavesSpeed ) * FWavesFalloff;

  for j := 0 to FMap.Height-1 do begin
    for i := 0 to FMap.Width-1 do begin
//      arr[j * FMap.Width + i] := arr[j * FMap.Width + i] + Vel[j * FMap.Width + i] * 0.5;
      arr[j * FMap.Width + i] := (arr[j * FMap.Width + i] + Vel[j * FMap.Width + i]) * FViscosity;

      if arr[j * FMap.Width + i]>MaxArr then arr[j * FMap.Width + i] := MaxArr;
      if arr[j * FMap.Width + i]<0 then arr[j * FMap.Width + i] := 0;


      FMap[i, j] := Round((arr[(j div 1) * FMap.Width + i div 1]*1) / MaxArr*255);

{      FMap[i, j] := Round((
                                 arr[(j div 1) * FMap.Width + i div 1]*(1-k*4) +
                                 arr[MaxI(0, j-1) * FMap.Width + i]*k +
                                 arr[(j) * FMap.Width + MaxI(0, i-1)]*k +
                                 arr[MinI(FMap.Height-1, j+1) * FMap.Width + i]*k +
                                 arr[(j) * FMap.Width + MinI(FMap.Width-1, i+1)]*k
                                 ) / MaxArr*255);}
    end;
  end;
end;

function TVertexWaterTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i, j: Integer; HalfLengthX, HalfLengthZ, y, a, MinA, FRACos: Single; c, n: TVector3s;
begin
  Result := 0;
  if not Assigned(FMap) or not FMap.IsReady then Exit;

  if TesselationStatus[tbVertex].Status <> tsTesselated then Iterate;

  MinA := FWaterColor.A / 255;
  FRACos := Sin((FFullRefAngle)/180*pi);

  HalfLengthX := (FMap.Width-1)  * FMap.CellWidthScale  * 0.5;
  HalfLengthZ := (FMap.Height-1) * FMap.CellHeightScale * 0.5;

  for j := 0 to FMap.Height-1 do for i := 0 to FMap.Width-1 do begin
    SetVertexDataUV(i * FTextureScale, j * FTextureScale, j * FMap.Width + i, VBPTR);
    Y := FMap[i, j] * FMap.DepthScale;
    c := GetVector3s(i * FMap.CellWidthScale - HalfLengthX, Y, j * FMap.CellHeightScale - HalfLengthZ);
    SetVertexDataC(c, j * FMap.Width + i, VBPTR);
    n := FMap.GetCellNormal(i, j);
    SetVertexDataN(n, j * FMap.Width + i, VBPTR);
    n := Transform3Vector3s(CutMatrix3s(Params.ModelMatrix), n);
    c := Transform4Vector33s(Params.ModelMatrix, c);
    c := NormalizeVector3s(SubVector3s(Params.Camera.Position, c));
//    a := MaxS(0, MinA + MinS(1-MinA, (1-Abs(DotProductVector3s(c, n)))/FRACos) );
    a := MaxS(0, MinA + MinS(1-MinA, (1-MinA)*Sqrt(1-Sqr(DotProductVector3s(c, n)))/FRACos ));
    SetVertexDataD(GetColor(FWaterColor.R, FWaterColor.G, FWaterColor.B, Round(a*255)), j * FMap.Width + i, VBPTR);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

{ TVertexWater}

function TVertexWater.GetTesselatorClass: CTesselator; begin Result := TVertexWaterTesselator; end;

procedure TVertexWater.AddProperties(const Result: TProperties);
begin
  inherited;
  if Assigned(Result) then begin
    AddColorProperty(Result, 'Water color', WaterColor);
    Result.Add('100% reflection angle', vtInt,    [], IntToStr(FullRefAngle), '0-90');

    Result.Add('Waves speed',     vtSingle, [], FloatToStr(WavesSpeed),   '0.1-1');
    Result.Add('Waves falloff',   vtSingle, [], FloatToStr(WavesFalloff), '0.9-1');
    Result.Add('Water viscosity', vtSingle, [], FloatToStr(Viscosity),    '0.8-1');
  end;
end;

procedure TVertexWater.SetProperties(Properties: TProperties);
var Mesh: TVertexWaterTesselator;
begin
  inherited;
  SetColorProperty(Properties, 'Water color', WaterColor);
  if Properties.Valid('100% reflection angle') then FullRefAngle := StrToIntDef(Properties['100% reflection angle'], 30);

  if Properties.Valid('Waves speed')     then WavesSpeed   := StrToFloatDef(Properties['Waves speed'], 0);
  if Properties.Valid('Waves falloff')   then WavesFalloff := StrToFloatDef(Properties['Waves falloff'], 0);
  if Properties.Valid('Water viscosity') then Viscosity    := StrToFloatDef(Properties['Water viscosity'], 0);

  if not (CurrentTesselator is TVertexWaterTesselator) then Exit;
  Mesh := CurrentTesselator as TVertexWaterTesselator;
  Mesh.WaterColor   := WaterColor;
  Mesh.FullRefAngle := FullRefAngle;
  Mesh.WavesSpeed   := WavesSpeed;
  Mesh.WavesFalloff := WavesFalloff;
  Mesh.Viscosity    := Viscosity;
  SetMesh;
end;

procedure TVertexWater.Process(const DeltaTime: Single);

  procedure MakeWave(z, len: Integer; Height, Freq, Radii: Single);
  var i, j: Integer;
  begin
    with (CurrentTesselator as TVertexWaterTesselator) do begin
      for i := 2 to FMap.Width-4 do
        for j := 0 to len-1 do
        arr[MinI(FMap.Height-2, j+z-Round(Sin(pi*((i-2)/(FMap.Width-4))*FReq)*Radii)) * FMap.Width + MinI(FMap.Width-2, i)] := MaxArr*Height * Sin(j/(len-1)*pi);
//        arr[MinI(FMap.Height-2, z+j) * FMap.Width + MinI(FMap.Width-2, i)] := MaxArr*Height * Sin(j/(len-1)*pi);
    end;
  end;

  var w, h: Integer;

begin
  inherited;
  if not Assigned((CurrentTesselator as TVertexWaterTesselator).FMap) or not (CurrentTesselator as TVertexWaterTesselator).FMap.IsReady then Exit;
  CurrentTesselator.Invalidate([tbVertex], False);
  with (CurrentTesselator as TVertexWaterTesselator) do begin
    Inc(Counter);
    w := FMap.Width;
    w := w div 2 + Random(w div 2-2) - Random(w div 2-2);
    h := FMap.Height;
    h := h div 2 + Random(h div 2-2) - Random(h div 2-2);
    if Counter mod 2 = 0 then arr[h * FMap.Width + w] := (MaxArr + Random * MaxArr)/2/2;
//    if Counter mod 2 = 0 then MakeWave(6, 0.03, 4, 4);
//    if Counter mod 6 = 0 then MakeWave(67, 0.08, 4, 4);
    if Counter mod 10 = 0 then MakeWave(126-6, 6, 0.2, 1, 18);
  end;
end;

{ TProjectedLandTesselator }

procedure TProjectedLandTesselator.ProjectGrid(const Params: TTesselationParameters; out PrjPnt: TQuadPoints);
var
  ModelInv: TMatrix4s; ModelInv33: TMatrix3s;
  CameraInModel: TVector3s;
  CameraElevation: Single;
  OPnt2, OPnt3: TVector3s;

  procedure SwapVec(var V1, V2: TVector3s);
  var Vec: TVector3s;
  begin
    Vec := V1;
    V1  := V2;
    V2  := Vec;
  end;

  function ProjectOnGrid2(X, Y: Single; out Point: TVector3s): Boolean;
  var PickRay: TVector3s;
  begin
    Result := False;
    PickRay := Transform3Vector3s(CutMatrix3s(InvertAffineMatrix4s(Params.Camera.ViewMatrix)), Params.Camera.GetPickRay(X, Y));
    PickRay := NormalizeVector3s(Transform3Vector3s(ModelInv33, PickRay) );
    if (Abs(PickRay.Y) > epsilon) and (Sign(PickRay.Y) <> Sign(CameraInModel.Y)) and
       (Abs(CameraElevation/PickRay.Y) < ViewDepth) then begin                      // Ray intersects the surface
      SubVector3s(Point, CameraInModel, ScaleVector3s(PickRay, CameraElevation/PickRay.Y));
      Point.Y := 0;
      Result := True;
    end;
  end;

  function ProjectNearEdge(FlipSign: Single): Boolean;
  var TempK, y: Single; Pnt0, Pnt1: TVector3s;
  begin
    Result := False;
    y := Params.Camera.RenderHeight * Ord(FlipSign >= 0);
    if not ProjectOnGrid2(Params.Camera.RenderWidth, y, PrjPnt[2]) then Exit;
    if not ProjectOnGrid2(0,                         y, PrjPnt[3]) then Exit;

    OPnt2 := PrjPnt[2];
    OPnt3 := PrjPnt[3];

    // Near edge with elevation taken in account
    TempK := SqrMagnitude(CameraDir);
    if TempK > epsilon then begin
      ScaleVector3s(CameraDir, CameraDir, InvSqrt(TempK));
      CameraElevation := MaxS(0, CameraInModel.Y-FMap.MaxHeight * FMap.DepthScale);

      if not ProjectOnGrid2(Params.Camera.RenderWidth, y, Pnt1) then Exit;
      if not ProjectOnGrid2(0,                         y, Pnt0) then Exit;

      TempK := MinS(0, MinS(DotProductVector3s(CameraDir, SubVector3s(Pnt1, PrjPnt[2])),
                            DotProductVector3s(CameraDir, SubVector3s(Pnt0, PrjPnt[3]))));

      AddVector3s(PrjPnt[2], PrjPnt[2], ScaleVector3s(CameraDir, TempK));
      AddVector3s(PrjPnt[3], PrjPnt[3], ScaleVector3s(CameraDir, TempK));
      CameraElevation := CameraInModel.Y;
    end;

    Result := True;
  end;

  function ProjectFarEdge(FlipSign: Single): Boolean;
  var y: Single; LeftRail, RightRail: TVector3s;
  begin
    Result := False;
    y := Params.Camera.RenderHeight * Ord(FlipSign >= 0);
    if not ProjectOnGrid2(Params.Camera.RenderWidth, y + 1 - 2*Ord(FlipSign >= 0), PrjPnt[1]) then Exit;
    if not ProjectOnGrid2(0,                         y + 1 - 2*Ord(FlipSign >= 0), PrjPnt[0]) then Exit;

    LeftRail  := NormalizeVector3s(SubVector3s(PrjPnt[0], OPnt3));
    RightRail := NormalizeVector3s(SubVector3s(PrjPnt[1], OPnt2));

    if not ProjectOnGrid2(Params.Camera.RenderWidth, Params.Camera.RenderHeight-y, PrjPnt[1]) then
      PrjPnt[1] := AddVector3s(OPnt2, ScaleVector3s(RightRail, ViewDepth));

    if not ProjectOnGrid2(0, Params.Camera.RenderHeight-y, PrjPnt[0]) then
      PrjPnt[0] := AddVector3s(OPnt3, ScaleVector3s(LeftRail, ViewDepth));

    Result := True;
  end;

  var TempK: Single;

begin
  ModelInv := InvertAffineMatrix4s(Params.ModelMatrix);
  ModelInv33 := CutMatrix3s(ModelInv);
  Transform4Vector33s(CameraInModel, ModelInv, Params.Camera.GetAbsLocation);
  CameraElevation := CameraInModel.Y;

  FlipSign := Sign(DotProductVector3s(Params.Camera.UpDir, Params.ModelMatrix.ViewUp));// *
//              -DotProductVector3s(Params.Camera.LookDir, Params.ModelMatrix.ViewUp);

  CameraRight := ScaleVector3s(Transform3Vector3s(ModelInv33, Params.Camera.RightVector), FlipSign);
  CameraRight.Y := 0;
  TempK := SqrMagnitude(CameraRight);
//  Assert(TempK > epsilon);
  ScaleVector3s(CameraRight, CameraRight, InvSqrt(TempK));

  CameraDir   := Transform3Vector3s(ModelInv33, Params.Camera.ForwardVector);
  CameraDir.Y := 0;

  if not ProjectNearEdge(FlipSign) then Exit;
  if not ProjectFarEdge(FlipSign) then Exit;

  TempK := SqrMagnitude(CameraDir);
  if TempK <= epsilon then
    CameraDir := CrossProductVector3s(Transform3Vector3s(ModelInv33, Params.Camera.ForwardVector), CameraRight);

  if FlipSign < 0 then begin
    SwapVec(PrjPnt[0], PrjPnt[1]);
    SwapVec(PrjPnt[2], PrjPnt[3]);
    SwapVec(OPnt2, OPnt3);
  end;
end;

constructor TProjectedLandTesselator.Create;
var i: Integer;
begin
  inherited;
  FGridWidth  := 100;
  FGridHeight := 200;
  MipBias     := 100;
  MipScale    := 1;
  SmoothX     := 1;
  SmoothZ     := 1;
  DetailBalance := 0.5;
  TrilinearRange := 0.3;
  FMegaTextureScale := 1;
  FLastClipmapSize  := 0;
  FClipmapSize      := 256;

  for i := 0 to High(MipTexture) do MipTexture[i] := -1;
end;

destructor TProjectedLandTesselator.Destroy;
begin
  SetLength(FGrid, 0);
  SetLength(FMipZ, 0);
  inherited;
end;

function TProjectedLandTesselator.GetMaxVertices: Integer;
begin
  Result := TotalVertices;
end;

procedure TProjectedLandTesselator.Init;
begin
  inherited;

  if Assigned(FMap) then begin
    TotalVertices   := (FGridWidth+1)*(FGridHeight+1);

    TotalIndices    := (FGridWidth+1)*2;    //  - - 89, 1 - 309-315, 2 - 85
    TotalStrips     := FGridHeight;
    TotalPrimitives := FGridWidth*2;
    StripOffset     := FGridWidth+1;
//    StripOffset     := FGridWidth+1;

    SetLength(FMipZ, FGridHeight+1);
//  0  2  4          0 1 2 3 4 5  5 1           P: ??? (w*2)*(h-1)-2 = (3*2)*3-2 = 16
//  1  3  5          1 6 3 7 5 8  8 6           V: w*h = 3*4 = 12
//  6  7  8          6 9 7 A 8 B                I: (2+(w-1)*2+2)*(h-1)-2 = 2*(w+1)*(h-1) = (2+(3-1)*2+2)*3-2 = 8*3-2 = 22
//  9  A  B

{    TotalIndices    := 2*(FGridWidth+2)*(FGridHeight);//-2
    TotalStrips     := 1;
    TotalPrimitives := 2*(FGridWidth+1)*(FGridHeight)-2;//(TotalIndices-2-2);
    StripOffset     := 0;}
  end else begin
    TotalVertices   := 0;
    TotalStrips     := 0;
    TotalIndices    := 0;
    TotalPrimitives := 0;
    StripOffset     := 0;
  end;

  if not ManualRender then Log('TProjectedLandTesselator.Init: Manual render should be turned on for megatextured landscapes', lkWarning);

  PrimitiveType := ptTRIANGLESTRIP;
  TesselationStatus[tbVertex].TesselatorType := ttStatic;
  TesselationStatus[tbIndex].TesselatorType  := ttStatic;

//   IndexingVertices := TotalVertices;
  IndexingVertices := (FGridWidth+1)*2;
//  IndexingVertices := (FGridHeight+1)*2;

//  InitVertexFormat(GetVertexFormat(False, False, True, False, False, 0, [2]));
  InitVertexFormat(GetVertexFormat(False, False, False, False, False, 0, []));

  LastTexUpdX := 0;
  LastTexUpdZ := 0;
end;

procedure TProjectedLandTesselator.DoManualRender(Item: TItem);
var TexI: Integer; MipWorldSize, LandSizeX, LandSizeZ: Single; TexUpd: Boolean;

  procedure ApplyNextMip;
  var LockedData: TLockedRectData; CenX, CenZ: Single;
  begin
//    texofs := texofs - 0.5/TexDim;
    TexI := TexI + 1;
    MipWorldSize := FClipmapSize * (1 shl TexI)/FMegaTextureScale;

    CenX := TProjectedLandscape(Item).MegaTexture.LevelInfo[TexI].Width  * (0.5 + FMegaTextureScale * CamOfsX / TProjectedLandscape(Item).MegaTexture.LevelInfo[0].Width);
    CenZ := TProjectedLandscape(Item).MegaTexture.LevelInfo[TexI].Height * (0.5 + FMegaTextureScale * CamOfsZ / TProjectedLandscape(Item).MegaTexture.LevelInfo[0].Height);
    CenZ := TProjectedLandscape(Item).MegaTexture.LevelInfo[TexI].Height - CenZ;

    if TexUpd or (MipTexture[TexI] = -1) or (FLastClipmapSize <> FClipmapSize) then begin
      if (MipTexture[TexI] = -1) or (FLastClipmapSize <> FClipmapSize) then begin
        if MipTexture[TexI] <> -1 then Renderer.Textures.Delete(MipTexture[TexI]);
        MipTexture[TexI] := Renderer.Textures.NewProceduralTexture(TProjectedLandscape(Item).MegaTexture.Format, FClipmapSize, FClipmapSize, 0, 1, [toProcedural]);
      end;
      if Renderer.Textures.Lock(MipTexture[TexI], 0, nil, LockedData, []) then begin
        TProjectedLandscape(Item).MegaTexture.LoadRect(GetRect(Trunc(CenX - FClipmapSize*0.5), Trunc(CenZ - FClipmapSize*0.5),
                                                             Trunc(CenX - FClipmapSize*0.5)+FClipmapSize, Trunc(CenZ - FClipmapSize*0.5)+FClipmapSize), TexI, LockedData.Data, FClipmapSize);
    //      FillDWord(LockedData.Data^, 512*512, MipColors[i]);
        Renderer.Textures.UnLock(MipTexture[TexI], 0);
        LastTexUpdX := CamOfsX;
        LastTexUpdZ := CamOfsZ;
      end;
    end;

    CenX := Frac(CenX - FClipmapSize*0.5)/FClipmapSize;
    CenZ := Frac(CenZ - FClipmapSize*0.5)/FClipmapSize;

    Renderer.Textures.Apply(0, MipTexture[TexI]);
    Renderer.APIState.SetShaderConstant(skVertex, 9, GetVector4s(1/MipWorldSize, -1/MipWorldSize, CenX, CenZ));
  end;

  var i, j, k: Integer;

begin
  if not Assigned(TProjectedLandscape(Item).MegaTexture) then Exit;

  TexUpd := (LastTexUpdX <> CamOfsX) or (LastTexUpdZ <> CamOfsZ);

  LandSizeX := FMap.Width * FMap.CellWidthScale;
  LandSizeZ := FMap.Width * FMap.CellWidthScale;

  j := 0;//FGridHeight-1;
  FMipZ[j] := MinS(FMipZ[j], Sqrt(Sqr(LandSizeX)+Sqr(LandSizeZ)));
  TexI := -1;//+1*ClipmapCount-1-1;
  ApplyNextMip;
  for k := 0 to FarMip-NearMip do for i := 0 to MipDetail[k] - 1-Ord(k=FarMip-NearMip) do begin
//    if j > 0 then FMipZ[j] := (ViewDepth + 1*ExcessDist) * (MipStart[k] + i*(MipStart[k+1] - MipStart[k])/(MipDetail[k]-Ord(k = FarMip-NearMip)));
    if FMipZ[j+1] >= MipWorldSize*0.5 - epsilon then ApplyNextMip();

    TCore(TProjectedLandscape(Item).FManager).Renderer.APIRenderIndexedStrip(Self, j);
    Inc(j);
  end;
  FLastClipmapSize := FClipmapSize;
end;

procedure TProjectedLandTesselator.AddProperties(const Result: TProperties; const PropNamePrefix: TNameString);
var RangeStr: ShortString;
begin
  inherited;
  if Assigned(Result) then begin
    Result.Add(PropNamePrefix + 'X resolution',  vtInt,    [], IntToStr(FGridWidth), '1-300');
    Result.Add(PropNamePrefix + 'YZ resolution', vtInt,    [], IntToStr(FGridHeight), '1-600');

    Result.Add(PropNamePrefix + 'Smooth X', vtNat, [], IntToStr(SmoothX-1), '0-15');
    Result.Add(PropNamePrefix + 'Smooth Z', vtNat, [], IntToStr(SmoothZ-1), '0-15');

    Result.Add(PropNamePrefix + 'Trilinear range', vtSingle, [], FloatToStr(TrilinearRange), '0.0001-1');

    Result.Add(PropNamePrefix + 'Excess distance', vtSingle, [], FloatToStr(ExcessDist), '0-128');

    if Assigned(FMap) then
      RangeStr := IntToStr(Round(FMap.CellWidthScale * 50)) + '-' + IntToStr(Round(FMap.CellWidthScale * 5000)) else
        RangeStr := '50-5000';
    Result.Add(PropNamePrefix + 'View depth', vtSingle, [], FloatToStr(ViewDepth), RangeStr);

    Result.Add(PropNamePrefix + 'Mip level bias', vtSingle, [], FloatToStr(MipBias),       '0-512');
    Result.Add(PropNamePrefix + 'Mip scale',      vtSingle, [], FloatToStr(MipScale),      '0.1-4');
    Result.Add(PropNamePrefix + 'Detail balance', vtSingle, [], FloatToStr(DetailBalance), '0-1');

    Result.Add(PropNamePrefix + 'Texture\Diffuse scale', vtSingle, [], FloatToStr(FMegaTextureScale), '0.1-10');
    Result.Add(PropNamePrefix + 'Texture\Clipmap size',  vtNat,    [], IntToStr(FClipmapSize),        '64-2048');
  end;
end;

procedure TProjectedLandTesselator.SetProperties(Properties: TProperties; const PropNamePrefix: TNameString);
begin
  inherited;
  if Properties.Valid(PropNamePrefix + 'X resolution')  then FGridWidth  := StrToIntDef(Properties[PropNamePrefix + 'X resolution'],  0);
  if Properties.Valid(PropNamePrefix + 'YZ resolution') then FGridHeight := StrToIntDef(Properties[PropNamePrefix + 'YZ resolution'], 0);

  if Properties.Valid(PropNamePrefix + 'Smooth X') then SmoothX := StrToIntDef(Properties[PropNamePrefix + 'Smooth X'], 0) + 1;
  if Properties.Valid(PropNamePrefix + 'Smooth Z') then SmoothZ := StrToIntDef(Properties[PropNamePrefix + 'Smooth Z'], 0) + 1;

  if Properties.Valid(PropNamePrefix + 'Trilinear range') then TrilinearRange := StrToFloatDef(Properties[PropNamePrefix + 'Trilinear range'], 0.3);

  if Properties.Valid(PropNamePrefix + 'Excess distance') then ExcessDist := StrToFloatDef(Properties[PropNamePrefix + 'Excess distance'], 0);

  if Properties.Valid(PropNamePrefix + 'View depth') then ViewDepth := StrToFloatDef(Properties[PropNamePrefix + 'View depth'], 500);

  if Properties.Valid(PropNamePrefix + 'Mip level bias') then MipBias       := StrToFloatDef(Properties[PropNamePrefix + 'Mip level bias'], 50);
  if Properties.Valid(PropNamePrefix + 'Mip scale')      then MipScale      := StrToFloatDef(Properties[PropNamePrefix + 'Mip scale'],      0);
  if Properties.Valid(PropNamePrefix + 'Detail balance') then DetailBalance := StrToFloatDef(Properties[PropNamePrefix + 'Detail balance'], 0.5);

  if Properties.Valid(PropNamePrefix + 'Texture\Diffuse scale') then FMegaTextureScale := StrToFloatDef(Properties[PropNamePrefix + 'Texture\Diffuse scale'], 1);
  if Properties.Valid(PropNamePrefix + 'Texture\Clipmap size')  then FClipmapSize      := StrToIntDef(Properties[PropNamePrefix + 'Texture\Clipmap size'],    256);

  Init;
end;

{ TProjGridTesselator }

function TProjGridTesselator.GetUpdatedElements(Buffer: TTesselationBuffer; const Params: TTesselationParameters): Integer;

  function IsInPnts(const Point: TVector3s): Boolean;
  var i: Integer; v1, v2: TVector3s;
  begin
    Result := False;
{    SubVector3s(V1, Pnt[0], Pnt[3]);
    SubVector3s(V2, Point,  Pnt[3]);
    Y := Sign(V1.Z*V2.X - V1.X*V2.Z);}
    for i := 0 to 3 do begin
      SubVector3s(V1, Pnt[(i+1) mod 4], Pnt[i]);
      SubVector3s(V2, Point, Pnt[i]);
      if Sign(V1.Z*V2.X - V1.X*V2.Z)*FlipSign < 0 then Exit;
    end;
    Result := True;
  end;

var i: Integer;
begin
  if Buffer = tbVertex then begin
    Result := TotalVertices;
    if //not EqualsMatrix4s(Params.Camera.Transform, OldCameraMatrix) or
       (TesselationStatus[Buffer].Status <> tsTesselated) then Exit;
    ProjectGrid(Params, PrjPnt);
    for i := 0 to 3 do if not IsInPnts(PrjPnt[i]) then Exit;
//    Result := 0;
  end else Result := inherited GetUpdatedElements(Buffer, Params);
end;

function TProjGridTesselator.SetIndices(IBPTR: Pointer): Integer;
var i: Integer;
begin
  for i := 0 to TotalIndices div 2-1 do begin
    TWordBuffer(IBPTR^)[i * 2 + 0] := i;
    TWordBuffer(IBPTR^)[i * 2 + 1] := i + FGridWidth + 1;
  end;

//  0  1  2          0 3 1 4 2 5  5 3           P: (w*2)*(h-1)-2 = (3*2)*3-2 = 16
//  3  4  5          3 6 4 7 5 8  8 6           V: w*h = 3*4 = 12
//  6  7  8          6 9 7 A 8 B                I: (2+(w-1)*2+2)*(h-1)-2 = 2*(w+1)*(h-1) = (2+(3-1)*2+2)*3-2 = 8*3-2 = 22
//  9  A  B

{  for j := 0 to FGridHeight-1 do begin
    for i := 0 to FGridWidth+1 - 1 do begin
      Assert(j*(FGridWidth+2)*2 + i*2+1 < TotalIndices);
      i1 := j * (FGridWidth+1) + i;
      TWordBuffer(IBPTR^)[j*(FGridWidth+2)*2 + i*2+0] := i1;
      TWordBuffer(IBPTR^)[j*(FGridWidth+2)*2 + i*2+1] := i1 + (FGridWidth+1);
    end;
    TWordBuffer(IBPTR^)[j*(FGridWidth+2)*2+(FGridWidth+1)*2] := i1 + (FGridWidth+1);
    TWordBuffer(IBPTR^)[j*(FGridWidth+2)*2+(FGridWidth+1)*2+1] := (j+1)*(FGridWidth+1);
  end;}

  TesselationStatus[tbIndex].Status := tsTesselated;
  Result  := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

function TProjGridTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  HalfLengthX, HalfLengthZ: Single;
  VBuf: ^TVector3s;

  // Returns True if the ray intersects with the grid
(*  function ProjectOnGrid(X, Y: Single; out Point: TVector3s; CorrectOnly: Boolean): Boolean;
  const CosA = 0.7;
  var PickRay: TVector3s; K: Single;
  begin
    PickRay := Transform3Vector3s(CutMatrix3s(InvertAffineMatrix4s(Params.Camera.ViewMatrix)), Params.Camera.GetPickRay2(X, Y));
    PickRay := NormalizeVector3s( Transform3Vector3s(ModelInv33, PickRay) );
    if (CorrectOnly) or
       (Abs(PickRay.Y) > epsilon) and (Sign(PickRay.Y) <> Sign(CameraInModel.Y)) and
       (Abs(CameraElevation/PickRay.Y) < ViewDepth) then begin                      // Ray intersects the surface
      SubVector3s(Point, CameraInModel, ScaleVector3s(PickRay, CameraElevation/PickRay.Y));
      Point.Y := 0;
      Result := True;
    end else begin
      PickRay.Y := 0;
      PickRay := NormalizeVector3s(PickRay);
      ScaleVector3s(PickRay, PickRay, ViewDepth);
      Point := PickRay;
      Point.Y := 0;
//      K := Sqrt(SqrMagnitude(Point))/ViewDepth;
//      if K < CosA then
      K := 1;
      AddVector3s(Point, CameraInModel, ScaleVector3s(PickRay, 1/K));
      Point.Y := 0;
      Result := False;
    end;
  end;


  procedure RestrictGrid;
  var i, i2, cnt: Integer;

    function IsInLandscape(const Point: TVector3s): Boolean;
    begin
      Result := (Point.X > -HalfLengthX) and (Point.X < HalfLengthX) and
                (Point.Z > -HalfLengthZ) and (Point.Z < HalfLengthZ);
    end;

  begin
    i := 0;
    while (i < 4) and not IsInLandscape(Pnt[i]) do Inc(i);
    if i < 4 then begin
      i2 := (i + 1) mod 4;
      for cnt := 0 to 3 do begin
        if not IsInLandscape(Pnt[i2]) then begin
          P := Pnt[i];
          ClipLine(P.X, P.Z, Pnt[i2].X, Pnt[i2].Z, -HalfLengthX, -HalfLengthZ, HalfLengthX, HalfLengthZ);
        end;
        i  := i2;
        i2 := (i + 1) mod 4;
      end;
    end else begin
      Pnt[0] := GetVector3s(-HalfLengthX, 0,  HalfLengthZ);
      Pnt[1] := GetVector3s( HalfLengthX, 0,  HalfLengthZ);
      Pnt[2] := GetVector3s( HalfLengthX, 0, -HalfLengthZ);
      Pnt[3] := GetVector3s(-HalfLengthX, 0, -HalfLengthZ);
    end;
  end;

  function ProjectBottomEdge(var Pnt1, Pnt2: TVector3s): Integer;
  var Proj: TVector4s;
  begin
    Result := 0;

    if ProjectOnGrid(Params.Camera.RenderWidth, Params.Camera.RenderHeight, Pnt1, False) then
    Inc(Result) else begin                                                                      // ToDo: Syncronize this case with Pnt2?
      Proj := Params.Camera.Project(Transform4Vector33s(Params.ModelMatrix, Pnt1));
      if (Proj.X < Params.Camera.RenderWidth-1) then ProjectOnGrid(Params.Camera.RenderWidth, Proj.Y, Pnt1, True);
    end;

    if ProjectOnGrid(0,                         Params.Camera.RenderHeight, Pnt2, False) then
    Inc(Result) else begin
      Proj := Params.Camera.Project(Transform4Vector33s(Params.ModelMatrix, Pnt2));
      if (Proj.X > 0) then ProjectOnGrid(0, Proj.Y, Pnt2, True);
    end;
  end;

  function ProjectTopEdge(var Pnt1, Pnt2: TVector3s): Integer;
  var Proj: TVector4s;
  begin
    Result := 0;

    if ProjectOnGrid(0,                         0,                          Pnt1, False) then
      Inc(Result) else begin                                                                    // ToDo: Syncronize this case with Pnt2?
        Proj := Params.Camera.Project(Transform4Vector33s(Params.ModelMatrix, Pnt1));
        if (Proj.X > 0) then ProjectOnGrid(0, Proj.Y, Pnt1, True);
      end;

    if ProjectOnGrid(Params.Camera.RenderWidth, 0,                          Pnt2, False) then
      Inc(Result) else begin
        Proj := Params.Camera.Project(Transform4Vector33s(Params.ModelMatrix, Pnt2));
       if (Proj.X < Params.Camera.RenderWidth-1) then ProjectOnGrid(Params.Camera.RenderWidth, Proj.Y, Pnt2, True);
      end;
  end;

  *)
var
  P, P1, P2, P1Incr, P2Incr, PIncr: TVector3s;
  OneOverCellWidthScale, OneOverCellHeightScale: Single;
  i, k, l, X1, Z1, Addr: Integer;
  Data, Data2: Pointer;
  LastY, CurY, xo, zo: Single;
//  LastLine: array[0..1023] of Single;
  a, MinA, FRACos: Single;
  OutP: TVector3s;
  DistIncr, FarDist, NearDist, TempK, Error: Single;
  FirstPartK, LastPartK, LightMapScaleX, LightMapScaleZ, MipK, MipDivider, TempX, TempZ: Single;
  MipW, MipH, MipW2, MipH2, Index: Integer;
  IndI, IndJ: Cardinal;

{  function GetHeight(AData: Pointer; Offs: Integer): Single;
  const k1 = 0.25; k2 = 0.0;
  var X, Y: Integer;
  begin
    X := Offs mod MipW;
    Y := Offs div MipW;
    Result :=
               PByteBuffer(AData)^[Offs-MipW*2] * K2 +
               PByteBuffer(AData)^[Offs-MipW] * K1 +
               PByteBuffer(AData)^[Offs-2] * K2 +
               PByteBuffer(AData)^[Offs-1] * K1 +
               PByteBuffer(AData)^[Offs] * (1-K1*4-k2*4)+
               PByteBuffer(AData)^[Offs+MipW] * K1+
               PByteBuffer(AData)^[Offs+2*MipW] * K2+
               PByteBuffer(AData)^[Offs+2] * K2+
               PByteBuffer(AData)^[Offs+1] * K1 ;
//    Result := MaxI(0, Round((Sin(X * pi*2*4)*0+Sin(Y*0.01 * pi*2)) * 40));
  end;}

  type
    PBB = PByteBuffer;
    TData = record
      case Boolean of
        True: (a, b, c, d: Byte);
        False: (d32: Longword);
    end;
    TData2 = record
      case Boolean of
        True: (a, b: Byte);
        False: (d16: longword);
    end;
  var
    d0, d1, d2, d3: TData;
    ModelInv: TMatrix4s; CameraInModel: TVector3s;
    j: Integer;


begin
  Result := 0;
  if not Assigned(FMap) or not FMap.IsReady then Exit;

  OldCameraMatrix := Params.Camera.Transform;

  ModelInv := InvertAffineMatrix4s(Params.ModelMatrix);
  Transform4Vector33s(CameraInModel, ModelInv, Params.Camera.GetAbsLocation);

  CamOfsX := CameraInModel.X;
  CamOfsZ := CameraInModel.Z;

  HalfLengthX := (FMap.Width-1)  * FMap.CellWidthScale  * 0.5;
  HalfLengthZ := (FMap.Height-1) * FMap.CellHeightScale * 0.5;
  LightMapScaleX := 0.5/HalfLengthX;
  LightMapScaleZ := 0.5/HalfLengthZ;
  OneOverCellWidthScale  := 1/FMap.CellWidthScale;
  OneOverCellHeightScale := 1/FMap.CellHeightScale;

  ProjectGrid(Params, PrjPnt);

  AddVector3s(Pnt[0], PrjPnt[0], Vec3s(ExcessDist*(-CameraRight.X + CameraDir.X), 0, ExcessDist*(-CameraRight.Z + CameraDir.Z)));
  AddVector3s(Pnt[1], PrjPnt[1], Vec3s(ExcessDist*( CameraRight.X + CameraDir.X), 0, ExcessDist*( CameraRight.Z + CameraDir.Z)));
  AddVector3s(Pnt[2], PrjPnt[2], Vec3s(ExcessDist*( CameraRight.X - CameraDir.X), 0, ExcessDist*( CameraRight.Z - CameraDir.Z)));
  AddVector3s(Pnt[3], PrjPnt[3], Vec3s(ExcessDist*(-CameraRight.X - CameraDir.X), 0, ExcessDist*(-CameraRight.Z - CameraDir.Z)));

//  FillChar(LastLine[0], SizeOf(LastLine), 0);
//  LastLine[0] := FMap.GetHeight((Pnt[3].X+Pnt[2].X)*0.5, (Pnt[3].Z+Pnt[2].Z)*0.5);
//  FillDword(LastLine[1], FGridWidth, Cardinal(Pointer(@LastLine[0])^));

  NearDist := Sqrt(SqrMagnitude(SubVector3s(Pnt[2], Pnt[3])));
  FarDist  := Sqrt(SqrMagnitude(SubVector3s(Pnt[1], Pnt[0])));

  DistIncr := FarDist - NearDist;
  if DistIncr < 0 then Exit;

//  if not FInfinite then RestrictGrid;

  NearMip := 0;
  while (NearMip < THeightMap(FMap).FImage.SuggestedLevels-1) and
        (FMap.CellWidthScale * (FGridWidth+1) * (1 shl NearMip) * MipScale <= NearDist) do
    Inc(NearMip);

  FarMip := 0;
  while (FarMip < THeightMap(FMap).FImage.SuggestedLevels-1) and
        (FMap.CellWidthScale * (FGridWidth+1) * (1 shl FarMip) * MipScale <= FarDist) do
    Inc(FarMip);

  for i := NearMip to FarMip do MipStart[i-NearMip+1] := (FMap.CellWidthScale * (FGridWidth+1) * (1 shl i) * MipScale-NearDist) / DistIncr;
  if MipStart[FarMip-NearMip+1] < 1 then begin
    Assert(MipStart[FarMip-NearMip+1] >= 1);
  end;
  if FarMip-NearMip >= 1 then begin
    MipStart[0] := -(MipStart[2] - 3*MipStart[1])/2;
    FirstPartK  := MipStart[1]/(MipStart[1] - MipStart[0]);
    LastPartK   := (1-MipStart[FarMip-NearMip])/(MipStart[FarMip-NearMip+1] - MipStart[FarMip-NearMip]);
    TempK := 1/(FirstPartK + FarMip - NearMip - 1 + LastPartK);
    MipDetail[0] := Round(FirstPartK * TempK * (FGridHeight+1));
    Error := FirstPartK * TempK * (FGridHeight+1) - MipDetail[0];
    for i := NearMip+1 to FarMip-1 do begin
      MipDetail[i-NearMip] := Round(TempK * (FGridHeight+1) + Error);
      Error := (TempK * (FGridHeight+1) + Error) - MipDetail[i-NearMip];
    end;
    MipDetail[FarMip-NearMip] := Round(LastPartK * TempK * (FGridHeight+1) + Error);
    Error := (LastPartK * TempK * (FGridHeight+1) + Error) - MipDetail[FarMip-NearMip];
    if Error >= 0.5 then Inc(MipDetail[0]);

    if MipDetail[FarMip-NearMip] <= 1 then begin
      Inc(MipDetail[FarMip-NearMip-1], MipDetail[FarMip-NearMip]);
      Dec(FarMip);
    end;

    Error := 0;
    for i := 0 to FarMip-NearMip do Error := Error + MipDetail[i];
    Assert(Error = (FGridHeight+1));
  end else begin
    MipDetail[0] := (FGridHeight+1);
  end;

  MipStart[0] := 0;
  MipStart[FarMip-NearMip+1] := 1;

  P1Incr := ScaleVector3s(NormalizeVector3s(SubVector3s(Pnt[0], Pnt[3])), MinS(FMap.CellWidthScale, FMap.CellHeightScale));
  P2Incr := ScaleVector3s(NormalizeVector3s(SubVector3s(Pnt[1], Pnt[2])), MinS(FMap.CellWidthScale, FMap.CellHeightScale));

  VBuf := VBPTR;
  j := 0;

  for k := 0 to FarMip-NearMip do begin
    P1 := Pnt[3];
    P2 := Pnt[2];

    SubVector3s(OutP, Pnt[0], Pnt[3]);
    AddVector3s(P1, Pnt[3], ScaleVector3s(OutP, MipStart[k]));
    ScaleVector3s(P1Incr, OutP, (MipStart[k+1] - MipStart[k])/(MipDetail[k]-Ord(k = FarMip-NearMip)));

    SubVector3s(OutP, Pnt[1], Pnt[2]);
    AddVector3s(P2, Pnt[2], ScaleVector3s(OutP, MipStart[k]));
    ScaleVector3s(P2Incr, OutP, (MipStart[k+1] - MipStart[k])/(MipDetail[k]-Ord(k = FarMip-NearMip)));

    Data  := PtrOffs(FMap.Data, THeightMap(FMap).FImage.LevelInfo[k + NearMip].Offset);
    Data2 := PtrOffs(FMap.Data, THeightMap(FMap).FImage.LevelInfo[k + NearMip+1].Offset);

    MipDivider := 1/(1 shl (k + NearMip));
    MipW  := FMap.Width  shr (k + NearMip);
    MipH  := FMap.Height shr (k + NearMip);
    MipW2 := FMap.Width  shr (k + NearMip+1);
    MipH2 := FMap.Height shr (k + NearMip+1);

    for l := 0 to MipDetail[k]-1 do begin
      FMipZ[j] := Sqrt(SqrMagnitude(SubVector3s(Pnt[3], P1)));
//      Sqrt(SqrMagnitude(GetVector3s(P1.X - CamOfsX, 0, P1.Z - CamOfsZ)));
      Inc(j);

      ScaleVector3s(PIncr, SubVector3s(P2, P1), 1 / FGridWidth);
      P := P1;

      MipK := MaxS(0, l/MipDetail[k] - (1-TrilinearRange))/TrilinearRange;

      if MipK < epsilon then begin

        for i := 0 to FGridWidth do begin       // _/\_
          TempX := (ClampS(P.X, -HalfLengthX, HalfLengthX) + HalfLengthX) * OneOverCellWidthScale  * MipDivider;
          TempZ := (ClampS(P.Z, -HalfLengthZ, HalfLengthZ) + HalfLengthZ) * OneOverCellHeightScale * MipDivider;

          X1 := FastTrunc(TempX);
          Z1 := FastTrunc(TempZ);

          xo := (TempX - X1);// * Ord(X1 >= 0) * Ord(X1 < MipW);
          zo := (TempZ - Z1);// * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          X1 := X1 * Ord(X1 >= 0) * Ord(X1 < MipW);
          Z1 := Z1 * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          Addr := Z1 * MipW + X1;
//          ti1 := Addr + MipW * Ord(Z1 < MipH-1);
//          ti2 := Ord(X1 < MipW-1);

          // May read 2 bytes outside texture data. It's safe because these 2 bytes will go from next mipmap.
          d0.d32 := PLongword(Integer(Data) + Addr - MipW * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1))^;
          d3.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1) + MipW * Ord(Z1 < MipH-2))^;

          P.Y := ((1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo)) * FMap.DepthScale * 0.25;
{         0   1   2   3
          4   5   6   7
          8   9   A   B
          C   D   E   F}
{          P.Y := ((1-xo) * (PByteBuffer(Data)^[Addr] * (1-zo) +
                             PByteBuffer(Data)^[ti1] * zo ) +
                      xo  * (PByteBuffer(Data)^[Addr + ti2] * (1-zo) +
                             PByteBuffer(Data)^[ti1 + ti2] * zo)) * FMap.DepthScale;}

//          P.Y := (LastLine[i]*0 + 2*CurY)*0.5;
//          LastLine[i] := CurY;

          VBuf^ := P;

//          TColor(Pointer(Integer(VBuf) + 12)^).C := MipColors[k+NearMip];
          Single(Pointer(Integer(VBuf) + 12)^) := P.X - CameraInModel.X;
          Single(Pointer(Integer(VBuf) + 16)^) := P.Z - CameraInModel.Z;

          VBuf := Pointer(Integer(VBuf) + FVertexSize);

          P.X := P.X + PIncr.X;
          P.Z := P.Z + PIncr.Z;
        end;
      end else begin
        for i := 0 to FGridWidth do begin       // _/\_
          TempX := (ClampS(P.X, -HalfLengthX, HalfLengthX) + HalfLengthX) * OneOverCellWidthScale  * MipDivider;
          TempZ := (ClampS(P.Z, -HalfLengthZ, HalfLengthZ) + HalfLengthZ) * OneOverCellHeightScale * MipDivider;

          X1 := FastTrunc(TempX);
          Z1 := FastTrunc(TempZ);

          xo := (TempX - X1){ * Ord(X1 >= 0) * Ord(X1 < MipW)};
          zo := (TempZ - Z1){ * Ord(Z1 >= 0) * Ord(Z1 < MipH)};

          X1 := X1 * Ord(X1 >= 0) * Ord(X1 < MipW);
          Z1 := Z1 * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          Addr := Z1 * MipW + X1;
//          ti1 := Addr + MipW * Ord(Z1 < MipH-1);
//          ti2 := Ord(X1 < MipW-1);

{          T1 := Addr - MipW * Ord(Z1 > 0);
          T2 := T1 + Ord(X1 < MipW-1);
          T4 := Addr - Ord(X1 > 0);
          T5 := Addr;
          T6 := Addr + Ord(X1 < MipW-1);
          T7 := T6 + Ord(X1 < MipW-2);
          T9 := Addr + MipW * Ord(Z1 < MipH-1);
          T8 := T9 - Ord(X1 > 1);

          TA := T9 + Ord(X1 < MipW-1);
          TB := TA + Ord(X1 < MipW-2);
          TD := T9 + MipW * Ord(Z1 < MipH-2);
          TE := TD + Ord(X1 < MipW-1);

          P.Y := ((1-xo) * (( PBB(Data)^[T1] + PBB(Data)^[T4] + PBB(Data)^[T6] + PBB(Data)^[T9] ) * (1-zo) +
                             ( PBB(Data)^[T5] + PBB(Data)^[T8] + PBB(Data)^[TA] + PBB(Data)^[TD] ) * zo ) +
                      xo  * (( PBB(Data)^[T2] + PBB(Data)^[T5] + PBB(Data)^[T7] + PBB(Data)^[TA] ) * (1-zo) +
                             ( PBB(Data)^[T6] + PBB(Data)^[T9] + PBB(Data)^[TB] + PBB(Data)^[TE] ) * zo));}
          d0.d32 := PLongword(Integer(Data) + Addr - MipW * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1))^;
          d3.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1) + MipW * Ord(Z1 < MipH-2))^;

          P.Y := ((1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo));
 {         P.Y := ((1-xo) * (PByteBuffer(Data)^[Addr] * (1-zo) +
                             PByteBuffer(Data)^[ti1] * zo ) +
                      xo  * (PByteBuffer(Data)^[Addr + ti2] * (1-zo) +
                             PByteBuffer(Data)^[ti1 + ti2] * zo));}
          // Second mip
          xo := (xo + X1 and 1)*0.5;
          zo := (zo + Z1 and 1)*0.5;
          X1 := X1 shr 1;
          Z1 := Z1 shr 1;

          Addr := Z1 * MipW2 + X1;
//          ti1 := Addr + MipW2 * Ord(Z1 < MipH2-1);
//          ti2 := Ord(X1 < MipW2-1);

          d0.d32 := PLongword(Integer(Data2) + Addr - MipW2 * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0) + MipW2 * Ord(Z1 < MipH2-1))^;
          d3.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0) + MipW2 * Ord(Z1 < MipH2-1) + MipW2 * Ord(Z1 < MipH2-2))^;

          P.Y := 0.25*(P.Y * (1 - MipK) + MipK * (
                  (1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo)) ) * FMap.DepthScale;

{          P.Y := (P.Y * (1 - MipK) + MipK * (
                          (1-xo) * (PByteBuffer(Data2)^[Addr] * (1-zo) +
                                    PByteBuffer(Data2)^[ti1] * zo ) +
                             xo  * (PByteBuffer(Data2)^[Addr + ti2] * (1-zo) +
                                    PByteBuffer(Data2)^[ti1 + ti2] * zo) )) * FMap.DepthScale;}
//          P.Y := (LastLine[i]*1 + 1*CurY)*0.5;
//          LastLine[i] := CurY;

          VBuf^ := P;

//          TColor(Pointer(Integer(VBuf) + 12)^).C := MipColors[k+NearMip];
          Single(Pointer(Integer(VBuf) + 12)^) := P.X - CameraInModel.X;
          Single(Pointer(Integer(VBuf) + 16)^) := P.Z - CameraInModel.Z;

          VBuf := Pointer(Integer(VBuf) + FVertexSize);

          P.X := P.X + PIncr.X;
          P.Z := P.Z + PIncr.Z;
        end;
      end;
      P1.X := P1.X + P1Incr.X;
      P1.Z := P1.Z + P1Incr.Z;
      P2.X := P2.X + P2Incr.X;
      P2.Z := P2.Z + P2Incr.Z;
    end;
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
//  TesselationStatus[tbVertex].Status := tsChanged;
  Result  := TotalVertices;
//  Assert((FGridWidth+1)*jj = Result);
  LastTotalVertices := TotalVertices;
end;

{ TProjectedLandscape }

procedure TProjectedLandscape.InitShaderConstants;
begin
  if Assigned(FMap) then begin
    SetLength(ShaderConsts, 2);
    ShaderConsts[0].ShaderKind     := skVertex;
    ShaderConsts[0].ShaderRegister := 10;
    ShaderConsts[0].Value          := Vec4s(FTextureScale, FTextureScale, 0, -1);

    ShaderConsts[1].ShaderKind     := skVertex;
    ShaderConsts[1].ShaderRegister := 11;
    ShaderConsts[1].Value          := Vec4s(1/(FMap.Width*FMap.CellWidthScale), 1/(FMap.Height*FMap.CellHeightScale), 0.5*FMap.Width*FMap.CellWidthScale, 0.5*FMap.Height*FMap.CellHeightScale);
  end;
end;

function TProjectedLandscape.GetMegaTexture: TMegaImageResource;
var Item: TItem;
begin
  ResolveLink('Megatexture', Item);
  Result := Item as TMegaImageResource;
end;

procedure TProjectedLandscape.OnModify(const ARect: BaseTypes.TRect);
begin
  inherited;
  RecalcLightMap(ARect);
end;

constructor TProjectedLandscape.Create(AManager: TItemsManager);
begin
  inherited;
  SetLength(FTesselators, 3);
  FTextureScale := 0.1;
  FLightmapType := lmtLightMap;
end;

procedure TProjectedLandscape.OnSceneLoaded;
begin
  inherited;
  InitShaderConstants;
end;

procedure TProjectedLandscape.RetrieveShaderConstants(var ConstList: TShaderConstants);
var CamInModel: TVector2s;
begin
  if CurrentTesselator is TProjectedLandTesselator then
    CamInModel := Vec2s(TProjectedLandTesselator(CurrentTesselator).CamOfsX, TProjectedLandTesselator(CurrentTesselator).CamOfsZ)
  else
    CamInModel := Vec2s(0, 0);

  ShaderConsts[0].Value.Z := CamInModel.X;
  ShaderConsts[0].Value.W := CamInModel.Y;
  ConstList := ShaderConsts;
end;

const
  LightmapBasePropName  = 'Lightmap recalc';
  LightmapTexPropName   = LightmapBasePropName + '\Texture';
  LightmapLightPropName = LightmapBasePropName + '\Light source';
  LightmapTypePropName  = LightmapBasePropName + '\Type';

procedure TProjectedLandscape.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  AddItemLink(Result, LightmapTexPropName,   [], 'TImageResource');
  AddItemLink(Result, LightmapLightPropName, [], 'TLight');
  AddItemLink(Result, 'Megatexture',         [], 'TMegaImageResource');

  if Assigned(Result) then begin
    Result.AddEnumerated(LightmapTypePropName,  [], Ord(FLightmapType), LightmapTypesEnum);
    Result.Add(LightmapBasePropName, vtBoolean, [], OnOffStr[False], '');
    Result.Add('Texture scale', vtSingle, [], FloatToStr(FTextureScale),    '0,01-10');
  end;
end;

procedure TProjectedLandscape.SetProperties(Properties: Props.TProperties);
var i: Integer;
begin
  inherited;
  if Properties.Valid(LightmapTexPropName)   then SetLinkProperty(LightmapTexPropName,   Properties[LightmapTexPropName]);
  if Properties.Valid(LightmapLightPropName) then SetLinkProperty(LightmapLightPropName, Properties[LightmapLightPropName]);

  if Properties.Valid(LightmapTypePropName) then FLightmapType := TLightmapType(Properties.GetAsInteger(LightmapTypePropName));

  if Properties.Valid('Megatexture') then SetLinkProperty('Megatexture', Properties['Megatexture']);

  if Properties.Valid('Texture scale')       then FTextureScale := StrToFloatDef(Properties['Texture scale'], 0);

  if Assigned(FMap) and
     Properties.Valid(LightmapBasePropName) and (Properties.GetAsInteger(LightmapBasePropName) > 0) then
    RecalcLightMap(GetRect(0, 0, FMap.Width, FMap.Height));

  InitShaderConstants;

  for i := 0 to High(FTesselators) do (FTesselators[i] as TProjectedLandTesselator).Renderer := TCore(FManager).Renderer;
end;

procedure TProjectedLandscape.Process(const DeltaTime: Single);
begin
  inherited;
//  if Assigned(CurrentTesselator) then CurrentTesselator.Invalidate(False);
end;

procedure TProjectedLandscape.ProjectGrid(const Camera: TCamera; out PrjPnt: TQuadPoints);
var Params: TTesselationParameters;
begin
  if not (CurrentTesselator is TProjectedLandTesselator) then Exit;
  Params.Camera := Camera;
  Params.ModelMatrix := Transform;
  TProjectedLandTesselator(CurrentTesselator).ProjectGrid(Params, PrjPnt);
end;

procedure TProjectedLandscape.RecalcLightMap(ARect: BaseTypes.TRect);
var
  Item: TItem; Image: TImageResource; Light: TLight; N: TVector3s;
  tmp, i, j, k, l, w, h: Integer;
  oneoverwh, LPower: Single;
  LightColor: TColor;
  Buffer: Pointer;
begin
  ResolveLink(LightmapTexPropName, Item);
  if not Assigned(Item) or not Assigned(FMap) then Exit;
  Image := Item as TImageResource;
  ResolveLink(LightmapLightPropName, Item);
  if not Assigned(Item) and (FLightmapType = lmtLightmap) then Exit;
  Light := Item as TLight;

//  FillChar(Image.Data^, Image.DataSize, 0);

  w := FMap.Width  div Image.Width;
  h := FMap.Height div Image.Height;

  if (w = 0) or (h = 0) then begin
    Log('TProjectedLandscape.RecalcLightMap: Lightmap should be same size as heightmap or less', lkError);
    Exit;
  end;

  ARect.Left   := ClampI(ARect.Left,   0, FMap.Width-1)  div w;
  ARect.Right  := ClampI(ARect.Right,  0, FMap.Width-1)  div w;
  ARect.Top    := ClampI(ARect.Top,    0, FMap.Height-1) div h;
  ARect.Bottom := ClampI(ARect.Bottom, 0, FMap.Height-1) div h;

  oneoverwh := 1 / (w*h);

  if FLightmapType = lmtLightmap then begin
    LightColor := GetColorFrom4s(Light.Diffuse);
    GetMem(Buffer, Image.Width{ * Image.Height} * ProcessingFormatBpP);
    for j := ARect.Top to ARect.Bottom-1 do begin
      for i := ARect.Left to ARect.Right-1 do begin
        LPower := 0;
        for k := i*w to MinI(FMap.Width, (i+1)*w)-1 do for l := j*h to MinI(FMap.Width, (j+1)*h)-1 do
          LPower := LPower + MaxS(0, -DotProductVector3s(FMap.GetCellNormal(k, l), Light.ForwardVector));
        LPower := LPower * oneoverwh;

        PImageBuffer(Buffer)^[i] := ScaleColorS(LightColor, MinS(LPower, 1));
      end;
      ConvertFromProcessing(Image.Format, ARect.Right - ARect.Left, PtrOffs(Buffer, ARect.Left * ProcessingFormatBpP), tmp, nil, PtrOffs(Image.Data, (j * Image.Width + ARect.Left) * GetBytesPerPixel(Image.Format)));
    end;
    FreeMem(Buffer);
  end else if FLightmapType = lmtNormalmap then begin
    if GetBytesPerPixel(Image.Format) <> 4 then begin
      Log('TProjectedLandscape.RecalcLightMap: Normal map should be of 4 bytes per pixel format', lkError);
      Exit;
    end;
    for j := ARect.Top to ARect.Bottom-1 do for i := ARect.Left to ARect.Right-1 do begin
      N := ZeroVector3s;
      for k := i*w to MinI(FMap.Width, (i+1)*w)-1 do for l := j*h to MinI(FMap.Width, (j+1)*h)-1 do
        AddVector3s(N, N, FMap.GetCellNormal(k, l));
      N.Y := N.Y * 0.7;  
//      ScaleVector3s(N, N, oneoverwh);
      NormalizeVector3s(N, N);
      PImageBuffer(Image.Data)^[j * Image.Width + i] := VectorToColor(N);
    end;
  end;

  SendMessage(TResourceModifyMsg.Create(Image), Image, [mfCore, mfRecipient]);
end;

procedure TProjectedLandscape.HandleMessage(const Msg: TMessage);
begin
  inherited;
  {$IFDEF EDITORMODE}
//  if Msg.ClassType = TMapDrawCursorMsg then with TMapDrawCursorMsg(Msg) do DrawCursor(Cursor, Cursor.Camera, Cursor.Screen);
//  if (Msg.ClassType = TMapModifyBeginMsg) or (Msg.ClassType = TMapModifyMsg) then with TMapEditorMessage(Msg) do Modify(Cursor, Cursor.Camera);

  {$ENDIF}
end;

function TProjectedLandscape.VisibilityCheck(const Camera: TCamera): Boolean;
var d: Single; LOD: Integer; CameraPos: TVector3s;
begin
  Result := Assigned(FTesselators[0]) and (Camera.IsSpehereVisible(GetAbsLocation, BoundingSphereRadius) <> fcOutside);
  if Result then begin
    CameraPos := Camera.GetAbsLocation;
    CameraPos := Transform4Vector33s(InvertAffineMatrix4s(Transform), CameraPos);
    d := (CameraPos.Y - FMap.GetHeight(CameraPos.X, CameraPos.Z))/(FTesselators[0] as TProjectedLandTesselator).ViewDepth;
    LOD := ClampI(Round(High(FTesselators) * d + Camera.LODBias), 0, High(FTesselators));
    FCurrentTesselator := FTesselators[LOD];
  end;
end;

{ TProjGridLandscape }

function TProjGridLandscape.GetTesselatorClass: CTesselator; begin Result := TProjGridTesselator; end;

{ TRadGridLandscape }

function TRadGridLandscape.GetTesselatorClass: CTesselator; begin Result := TRadGridTesselator; end;

{ TRadGridTesselator }

procedure TRadGridTesselator.InitGrid;
var
  i, k, l: Integer;
  DistIncr, FarDist, NearDist, TempK, Error: Single;
  MipStart: array[0..31] of Single;
  FirstPartK, LastPartK: Single;
  j: Integer;
  Rad: Single;

begin
  if not Assigned(FMap) or not FMap.IsReady then Exit;
  SetLength(FGrid, TotalVertices);

  Rad := 0;
  NearDist := 2*pi * Rad;
  FarDist  := 2*pi * (ViewDepth + 1*ExcessDist);

  DistIncr := FarDist - NearDist;
  if DistIncr < epsilon then Exit;

  NearMip := 0;
  while (NearMip < THeightMap(FMap).FImage.SuggestedLevels-1) and
        (2*pi*FMap.CellWidthScale * (FGridWidth+1) * (1 shl NearMip) * MipScale <= NearDist) do
    Inc(NearMip);

  FarMip := 0;
  while (FarMip < THeightMap(FMap).FImage.SuggestedLevels-1) and
        (2*pi*FMap.CellWidthScale * (FGridWidth+1) * (1 shl FarMip) * MipScale <= FarDist) do
    Inc(FarMip);

  for i := NearMip to FarMip do MipStart[i-NearMip+1] := (FMap.CellWidthScale * (FGridWidth+1) * (1 shl i) * MipScale-NearDist) / DistIncr;
  if MipStart[FarMip-NearMip+1] < 1 then begin
//    Assert(MipStart[FarMip-NearMip+1] >= 1);
  end;
  if FarMip-NearMip >= 1 then begin
    MipStart[0] := -(MipStart[2] - 3*MipStart[1])/2;
    FirstPartK  := MipStart[1]/(MipStart[1] - MipStart[0]);
    LastPartK   := (1-MipStart[FarMip-NearMip])/(MipStart[FarMip-NearMip+1] - MipStart[FarMip-NearMip]);
    TempK := 1/(FirstPartK + FarMip - NearMip - 1 + LastPartK);
    MipDetail[0] := Round(FirstPartK * TempK * (FGridHeight+1));
    Error := FirstPartK * TempK * (FGridHeight+1) - MipDetail[0];
    for i := NearMip+1 to FarMip-1 do begin
      MipDetail[i-NearMip] := Round(TempK * (FGridHeight+1) + Error);
      Error := (TempK * (FGridHeight+1) + Error) - MipDetail[i-NearMip];
    end;
    MipDetail[FarMip-NearMip] := Round(LastPartK * TempK * (FGridHeight+1) + Error);
    Error := (LastPartK * TempK * (FGridHeight+1) + Error) - MipDetail[FarMip-NearMip];
    if Error >= 0.5 then Inc(MipDetail[0]);

    if MipDetail[FarMip-NearMip] <= 1 then begin
      Inc(MipDetail[FarMip-NearMip-1], MipDetail[FarMip-NearMip]);
      Dec(FarMip);
    end;

    Error := 0;
    for i := 0 to FarMip-NearMip do Error := Error + MipDetail[i];
    Assert(Error = (FGridHeight+1));
  end else begin
    MipDetail[0] := (FGridHeight+1);
  end;

  MipStart[0] := 0;
  MipStart[FarMip-NearMip+1] := 1;

  j := 0;

  for k := 0 to FarMip-NearMip do begin
    for l := 0 to MipDetail[k]-1 do begin
      Rad := (ViewDepth + 1*ExcessDist) * (MipStart[k] + l*(MipStart[k+1] - MipStart[k])/(MipDetail[k]-Ord(k = FarMip-NearMip)));
      FMipZ[j] := Rad;

      for i := 0 to FGridWidth do begin       // _/\_
        SinCos(2*pi*i/(FGridWidth-1), FGrid[j*(FGridWidth+1)+i].Y, FGrid[j*(FGridWidth+1)+i].X);
        FGrid[j*(FGridWidth+1)+i].X := Rad * FGrid[j*(FGridWidth+1)+i].X;
        FGrid[j*(FGridWidth+1)+i].Y := Rad * FGrid[j*(FGridWidth+1)+i].Y;
      end;
      Inc(j);
    end;
  end;
end;

procedure TRadGridTesselator.Init;
begin
  inherited;
  InitGrid;
end;

function TRadGridTesselator.GetUpdatedElements(Buffer: TTesselationBuffer; const Params: TTesselationParameters): Integer;
var LCameraInModel, LOldCameraInModel: TVector3s; ModelInv: TMatrix4s;
begin
  if Buffer = tbVertex then begin
    ModelInv := InvertAffineMatrix4s(Params.ModelMatrix);
    Transform4Vector33s(LCameraInModel, ModelInv, Params.Camera.GetAbsLocation);
    Transform4Vector33s(LOldCameraInModel, ModelInv, OldCameraMatrix.ViewTranslate);
    Result := TotalVertices * Ord( (Sqr(LCameraInModel.X - LOldCameraInModel.X)+Sqr(LCameraInModel.Z - LOldCameraInModel.Z)) > Sqr(ExcessDist));
  end else Result := inherited GetUpdatedElements(Buffer, Params);
end;

function TRadGridTesselator.SetIndices(IBPTR: Pointer): Integer;
var i: Integer;
begin
  for i := 0 to TotalIndices div 2-1 do begin
//    TWordBuffer(IBPTR^)[i * 2 + 0] := i * (FGridHeight+1) + 0;
//    TWordBuffer(IBPTR^)[i * 2 + 1] := i * (FGridHeight+1) + 1;
    TWordBuffer(IBPTR^)[i * 2 + 0] := i;
    TWordBuffer(IBPTR^)[i * 2 + 1] := i + (FGridWidth+1);
  end;

  TesselationStatus[tbIndex].Status := tsTesselated;
  Result  := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

function TRadGridTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  HalfLengthX, HalfLengthZ: Single;
  VBuf: PVector3s;
  TVBuf: PVector2s;

  P, P1, P2, P1Incr, P2Incr, PIncr: TVector3s;
  OneOverCellWidthScale, OneOverCellHeightScale: Single;
  i, k, l, X1, Z1, Addr: Integer;
  Data, Data2: Pointer;
  LastY, CurY, xo, zo: Single;
//  LastLine: array[0..1023] of Single;
  OutP: TVector3s;
  DistIncr, FarDist, NearDist, TempK, Error: Single;
  FirstPartK, LastPartK, LightMapScaleX, LightMapScaleZ, MipK, MipDivider, TempX, TempZ: Single;
  MipW, MipH, MipW2, MipH2, Index: Integer;
  IndI, IndJ: Cardinal;

  type
    TData = record
      case Boolean of
        True: (a, b, c, d: Byte);
        False: (d32: Longword);
    end;
  var
    d0, d1, d2, d3: TData;
    ModelInv: TMatrix4s;
    CameraInModel: TVector3s;
    j: Integer;
    Rad: Single;

begin
  Result := 0;
  if not Assigned(FMap) or not FMap.IsReady then Exit;

  OldCameraMatrix := Params.Camera.Transform;

  ModelInv := InvertAffineMatrix4s(Params.ModelMatrix);
  Transform4Vector33s(CameraInModel, ModelInv, Params.Camera.GetAbsLocation);

  CamOfsX := CameraInModel.X;
  CamOfsZ := CameraInModel.Z;

  HalfLengthX := (FMap.Width-1)  * FMap.CellWidthScale  * 0.5;
  HalfLengthZ := (FMap.Height-1) * FMap.CellHeightScale * 0.5;
  LightMapScaleX := 0.5/HalfLengthX;
  LightMapScaleZ := 0.5/HalfLengthZ;
  OneOverCellWidthScale  := 1/FMap.CellWidthScale;
  OneOverCellHeightScale := 1/FMap.CellHeightScale;

  Rad := 0;
  NearDist := 2*pi * Rad;
  FarDist  := 2*pi * (ViewDepth + 1*ExcessDist);

  DistIncr := FarDist - NearDist;
  if DistIncr < 0 then Exit;

  NearMip := 0;
  while (NearMip < THeightMap(FMap).FImage.SuggestedLevels-1) and
        (2*pi*FMap.CellWidthScale * (FGridWidth+1) * (1 shl NearMip) * MipScale <= NearDist) do
    Inc(NearMip);

  FarMip := 0;
  while (FarMip < THeightMap(FMap).FImage.SuggestedLevels-1) and
        (2*pi*FMap.CellWidthScale * (FGridWidth+1) * (1 shl FarMip) * MipScale <= FarDist) do
    Inc(FarMip);

  for i := NearMip to FarMip do MipStart[i-NearMip+1] := (FMap.CellWidthScale * (FGridWidth+1) * (1 shl i) * MipScale-NearDist) / DistIncr;
  if MipStart[FarMip-NearMip+1] < 1 then begin
//    Assert(MipStart[FarMip-NearMip+1] >= 1);
  end;
  if FarMip-NearMip >= 1 then begin
    MipStart[0] := -(MipStart[2] - 3*MipStart[1])/2;
    FirstPartK  := MipStart[1]/(MipStart[1] - MipStart[0]);
    LastPartK   := (1-MipStart[FarMip-NearMip])/(MipStart[FarMip-NearMip+1] - MipStart[FarMip-NearMip]);
    TempK := 1/(FirstPartK + FarMip - NearMip - 1 + LastPartK);
    MipDetail[0] := Round(FirstPartK * TempK * (FGridHeight+1));
    Error := FirstPartK * TempK * (FGridHeight+1) - MipDetail[0];
    for i := NearMip+1 to FarMip-1 do begin
      MipDetail[i-NearMip] := Round(TempK * (FGridHeight+1) + Error);
      Error := (TempK * (FGridHeight+1) + Error) - MipDetail[i-NearMip];
    end;
    MipDetail[FarMip-NearMip] := Round(LastPartK * TempK * (FGridHeight+1) + Error);
    Error := (LastPartK * TempK * (FGridHeight+1) + Error) - MipDetail[FarMip-NearMip];
    if Error >= 0.5 then Inc(MipDetail[0]);

    if MipDetail[FarMip-NearMip] <= 1 then begin
      Inc(MipDetail[FarMip-NearMip-1], MipDetail[FarMip-NearMip]);
      Dec(FarMip);
    end;

    Error := 0;
    for i := 0 to FarMip-NearMip do Error := Error + MipDetail[i];
    Assert(Error = (FGridHeight+1));
  end else begin
    MipDetail[0] := (FGridHeight+1);
  end;

  MipStart[0] := 0;
  MipStart[FarMip-NearMip+1] := 1;

  VBuf := VBPTR;
  TVBuf := @FGrid[0];

  j := 0;

  for k := 0 to FarMip-NearMip do begin
    Data  := PtrOffs(FMap.Data, THeightMap(FMap).FImage.LevelInfo[k + NearMip].Offset);
    Data2 := PtrOffs(FMap.Data, THeightMap(FMap).FImage.LevelInfo[k + NearMip+1].Offset);

    MipDivider := 1/(1 shl (k + NearMip));
    MipW  := FMap.Width  shr (k + NearMip);
    MipH  := FMap.Height shr (k + NearMip);
    MipW2 := FMap.Width  shr (k + NearMip+1);
    MipH2 := FMap.Height shr (k + NearMip+1);

    for l := 0 to MipDetail[k]-1 do begin
//      Rad := (ViewDepth + ExcessDist) * (MipStart[k] + l*(MipStart[k+1] - MipStart[k])/(MipDetail[k]-Ord(k = FarMip-NearMip)));
//      FMipZ[j] := Rad;
//      Sqrt(SqrMagnitude(GetVector3s(P1.X - CamOfsX, 0, P1.Z - CamOfsZ)));
//      Inc(j);

//      ScaleVector3s(PIncr, SubVector3s(P2, P1), 1 / FGridWidth);
//      P := P1;

      MipK := MaxS(0, l/MipDetail[k] - (1-TrilinearRange))/TrilinearRange;

      if MipK < epsilon then begin
        for i := 0 to FGridWidth do begin
          P.X := CamOfsX - TVBuf^.X;
          P.Z := CamOfsZ + TVBuf^.Y;

          TempX := (ClampS(P.X, -HalfLengthX, HalfLengthX) + HalfLengthX) * OneOverCellWidthScale  * MipDivider;
          TempZ := (ClampS(P.Z, -HalfLengthZ, HalfLengthZ) + HalfLengthZ) * OneOverCellHeightScale * MipDivider;

          X1 := FastTrunc(TempX);
          Z1 := FastTrunc(TempZ);

          xo := (TempX - X1);// * Ord(X1 >= 0) * Ord(X1 < MipW);
          zo := (TempZ - Z1);// * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          X1 := X1 * Ord(X1 >= 0) * Ord(X1 < MipW);
          Z1 := Z1 * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          Addr := Z1 * MipW + X1;
          // May read 2 bytes outside texture data. It's safe because these 2 bytes will go from next mipmap.
          d0.d32 := PLongword(Integer(Data) + Addr - MipW * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1))^;
          d3.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1) + MipW * Ord(Z1 < MipH-2))^;

          P.Y := ((1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo)) * FMap.DepthScale * 0.25;
          VBuf^ := P;

//          TColor(Pointer(Integer(VBuf) + 12)^).C := MipColors[k+NearMip];
//          Single(Pointer(Integer(VBuf) + 12)^) := P.X - CameraInModel.X;
//          Single(Pointer(Integer(VBuf) + 16)^) := P.Z - CameraInModel.Z;

          VBuf := Pointer(Integer(VBuf) + FVertexSize);
          TVBuf := Pointer(Integer(TVBuf) + SizeOf(TVector2s));
        end;
      end else begin
        for i := 0 to FGridWidth do begin
          P.X := CamOfsX - TVBuf^.X;
          P.Z := CamOfsZ + TVBuf^.Y;

          TempX := (ClampS(P.X, -HalfLengthX, HalfLengthX) + HalfLengthX) * OneOverCellWidthScale  * MipDivider;
          TempZ := (ClampS(P.Z, -HalfLengthZ, HalfLengthZ) + HalfLengthZ) * OneOverCellHeightScale * MipDivider;

          X1 := FastTrunc(TempX);
          Z1 := FastTrunc(TempZ);

          xo := (TempX - X1){ * Ord(X1 >= 0) * Ord(X1 < MipW)};
          zo := (TempZ - Z1){ * Ord(Z1 >= 0) * Ord(Z1 < MipH)};

          X1 := X1 * Ord(X1 >= 0) * Ord(X1 < MipW);
          Z1 := Z1 * Ord(Z1 >= 0) * Ord(Z1 < MipH);

          Addr := Z1 * MipW + X1;
          d0.d32 := PLongword(Integer(Data) + Addr - MipW * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1))^;
          d3.d32 := PLongword(Integer(Data) + Addr - Ord(X1 > 0) + MipW * Ord(Z1 < MipH-1) + MipW * Ord(Z1 < MipH-2))^;

          P.Y := ((1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo));
          // Second mip
          xo := (xo + X1 and 1)*0.5;
          zo := (zo + Z1 and 1)*0.5;
          X1 := X1 shr 1;
          Z1 := Z1 shr 1;

          Addr := Z1 * MipW2 + X1;

          d0.d32 := PLongword(Integer(Data2) + Addr - MipW2 * Ord(Z1 > 0) - Ord(X1 > 0))^;
          d1.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0))^;
          d2.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0) + MipW2 * Ord(Z1 < MipH2-1))^;
          d3.d32 := PLongword(Integer(Data2) + Addr - Ord(X1 > 0) + MipW2 * Ord(Z1 < MipH2-1) + MipW2 * Ord(Z1 < MipH2-2))^;

          P.Y := 0.25*(P.Y * (1 - MipK) + MipK * (
                  (1-xo) * (( d0.b + d1.a + d1.c + d2.b ) * (1-zo) +
                            ( d1.b + d2.a + d2.c + d3.b ) * zo ) +
                     xo  * (( d0.c + d1.b + d1.d + d2.c ) * (1-zo) +
                            ( d1.c + d2.b + d2.d + d3.c ) * zo)) ) * FMap.DepthScale;

          VBuf^ := P;

//          TColor(Pointer(Integer(VBuf) + 12)^).C := MipColors[k+NearMip];
//          Single(Pointer(Integer(VBuf) + 12)^) := P.X - CameraInModel.X;
//          Single(Pointer(Integer(VBuf) + 16)^) := P.Z - CameraInModel.Z;

          VBuf := Pointer(Integer(VBuf) + FVertexSize);
          TVBuf := Pointer(Integer(TVBuf) + SizeOf(TVector2s));
        end;
      end;
    end;
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
//  TesselationStatus[tbVertex].Status := tsChanged;
  Result  := TotalVertices;
//  Assert((FGridWidth+1)*jj = Result);
  LastTotalVertices := TotalVertices;
end;

{ TLandscapeShadowMapCamera }

const LandscapePropName = 'Landscape';

procedure TLandscapeShadowMapCamera.ResolveLinks;
var i: Integer; Item: TItem;
begin
  inherited;
  ResolveLink(LandscapePropName, Item);

  if Item is TProjectedLandscape then begin
    FLandscape := TProjectedLandscape(Item);
    InvalidateTransform();
  end;
end;

procedure TLandscapeShadowMapCamera.HandleMessage(const Msg: TMessage);
begin
  inherited;

end;

procedure TLandscapeShadowMapCamera.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if Assigned(Result) then begin
  end;

  AddItemLink(Result, LandscapePropName, [], 'TProjectedLandscape');
end;

procedure TLandscapeShadowMapCamera.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid(LandscapePropName) then SetLinkProperty(LandscapePropName, Properties[LandscapePropName]);
  ResolveLinks;
end;

procedure TLandscapeShadowMapCamera.ComputeViewMatrix;

  procedure InitShadowCamera;
  const
    ShadowMaxDist = 500;
  var
    Pnts, TPnts: TQuadPoints;
    i: Integer;
    MinP, MaxP: TVector3s;
    M: TMatrix4s;
    d: Single;
  begin
    if FLandscape is TProjectedLandscape then TProjectedLandscape(FLandscape).ProjectGrid(FOldCamera, Pnts);

    M := IdentityMatrix4s;
    Matrix4sByQuat(M, FLight.Orientation);
    M := InvertAffineMatrix4s(M);

    Orientation := FLight.Orientation;

    Position := GetVector3s(0, 0, 0);
    for i := 0 to 3 do begin

      d := Sqr(Pnts[i].X - FOldCamera.Position.X) + Sqr(Pnts[i].Z - FOldCamera.Position.Z);
      if d > Sqr(ShadowMaxDist) then begin
        Pnts[i].X := FOldCamera.Position.X + (Pnts[i].X - FOldCamera.Position.X)/Sqrt(d) * ShadowMaxDist;
        Pnts[i].Z := FOldCamera.Position.Z + (Pnts[i].Z - FOldCamera.Position.Z)/Sqrt(d) * ShadowMaxDist;
      end;


//      Pnts[i].Y := 0;
      Transform4Vector33s(TPnts[i], M, Pnts[i]);
    end;

    MinP := TPnts[0];
    MaxP := TPnts[0];
    for i := 1 to 3 do begin
      MinP.X := MinS(MinP.X, TPnts[i].X);
      MinP.Y := MinS(MinP.Y, TPnts[i].Y);
      MinP.Z := MinS(MinP.Z, TPnts[i].Z);
      MaxP.X := MaxS(MaxP.X, TPnts[i].X);
      MaxP.Y := MaxS(MaxP.Y, TPnts[i].Y);
      MaxP.Z := MaxS(MaxP.Z, TPnts[i].Z);
    end;
    InitOrthoProjMatrix(0.1, MaxS(4000, (100+MaxP.Z-MinP.Z)*2), MaxS(MaxP.X-MinP.X, MaxP.Y-MinP.Y), 1);

    MulMatrix4s(M, M, TranslationMatrix4s(-(MinP.X+MaxP.X)*0.5, -(Minp.Y+MaxP.Y)*0.5, -MinP.Z+100));
    ViewMatrix := M;

    for i := 0 to 3 do begin
      Transform4Vector33s(TPnts[i], M, Pnts[i]);
    end;
    MinP := TPnts[0];
    MaxP := TPnts[0];
    for i := 1 to 3 do begin
      MinP.X := MinS(MinP.X, TPnts[i].X);
      MinP.Y := MinS(MinP.Y, TPnts[i].Y);
      MinP.Z := MinS(MinP.Z, TPnts[i].Z);
      MaxP.X := MaxS(MaxP.X, TPnts[i].X);
      MaxP.Y := MaxS(MaxP.Y, TPnts[i].Y);
      MaxP.Z := MaxS(MaxP.Z, TPnts[i].Z);
    end;
  end;

  procedure InitShadowCamera2;
  var
    i, TotalItems: Integer;
    Items: TItems;
    MinP, MaxP, TPnt: TVector3s;
    M: TMatrix4s;
    d: Single;
  begin
    TotalItems := TCASTRootItem(FManager.Root).ExtractByMaskClassInCamera([isVisible], TVisible, Items, FOldCamera);

    M := IdentityMatrix4s;
    Matrix4sByQuat(M, FLight.Orientation);
    M := InvertAffineMatrix4s(M);

    Orientation := FLight.Orientation;

    Position := GetVector3s(0, 0, 0);

    for i := 0 to TotalItems-1 do if TVisible(Items[i]).Material.Technique[0].Passes[0].Group = 1 then begin
      d := TVisible(Items[i]).BoundingSphereRadius;
      Transform4Vector33s(TPnt, M, TProcessing(Items[i]).GetAbsLocation);
      if i = 0 then begin
        MinP := SubVector3s(TPnt, GetVector3s(d, d, d));
        MaxP := AddVector3s(TPnt, GetVector3s(d, d, d));
      end else begin
        MinP.X := MinS(MinP.X, TPnt.X-d);
        MinP.Y := MinS(MinP.Y, TPnt.Y-d);
        MinP.Z := MinS(MinP.Z, TPnt.Z-d);
        MaxP.X := MaxS(MaxP.X, TPnt.X+d);
        MaxP.Y := MaxS(MaxP.Y, TPnt.Y+d);
        MaxP.Z := MaxS(MaxP.Z, TPnt.Z+d);
      end;
    end;

    InitOrthoProjMatrix(0.1, MaxS(4000, (100+MaxP.Z-MinP.Z)*2), MaxS(MaxP.X-MinP.X, MaxP.Y-MinP.Y), 1);

    MulMatrix4s(M, M, TranslationMatrix4s(-(MinP.X+MaxP.X)*0.5, -(Minp.Y+MaxP.Y)*0.5, -MinP.Z+200));
    ViewMatrix := M;
  end;

  procedure InitShadowCamera3;
  const
    ShadowMaxDist = 500;
  var
    Pnts, TPnts: array[0..7] of TVector3s;
    i: Integer;
    MinP, MaxP: TVector3s;
    M: TMatrix4s;
    zf: Single;
  begin
    zf := 500;//FOldCamera.ZFar*0.01;
    Pnts[0].x := -2 * (Sin(FOldCamera.HFoV / 2)/Cos(FOldCamera.HFoV / 2)) * FOldCamera.ZNear;
    Pnts[0].y := Pnts[0].X * FOldCamera.CurrentAspectRatio;
    Pnts[0].Z := FOldCamera.ZNear;
    Pnts[1] := Pnts[0];
    Pnts[1].Y := -Pnts[1].Y;
    Pnts[2] := Pnts[1];
    Pnts[2].X := -Pnts[2].X;
    Pnts[3] := Pnts[2];
    Pnts[3].Y := -Pnts[3].Y;

    Pnts[4].x := -2 * (Sin(FOldCamera.HFoV / 2)/Cos(FOldCamera.HFoV / 2)) * zf;
    Pnts[4].y := Pnts[0].X * FOldCamera.CurrentAspectRatio;
    Pnts[4].Z := zf;
    Pnts[5] := Pnts[4];
    Pnts[5].Y := -Pnts[5].Y;
    Pnts[6] := Pnts[5];
    Pnts[6].X := -Pnts[6].X;
    Pnts[7] := Pnts[6];
    Pnts[7].Y := -Pnts[7].Y;

    M := IdentityMatrix4s;
    Matrix4sByQuat(M, FLight.Orientation);
    M := InvertAffineMatrix4s(M);

    Orientation := FLight.Orientation;

    Position := GetVector3s(0, 0, 0);
    for i := 0 to 7 do begin
      Pnts[i] := Transform4Vector33s(InvertAffineMatrix4s(FOldCamera.ViewMatrix), Pnts[i]);
      Transform4Vector33s(TPnts[i], M, Pnts[i]);
    end;

    MinP := TPnts[0];
    MaxP := TPnts[0];
    for i := 1 to 7 do begin
      MinP.X := MinS(MinP.X, TPnts[i].X);
      MinP.Y := MinS(MinP.Y, TPnts[i].Y);
      MinP.Z := MinS(MinP.Z, TPnts[i].Z);
      MaxP.X := MaxS(MaxP.X, TPnts[i].X);
      MaxP.Y := MaxS(MaxP.Y, TPnts[i].Y);
      MaxP.Z := MaxS(MaxP.Z, TPnts[i].Z);
    end;
    InitOrthoProjMatrix(0.1, MaxS(4000, (100+MaxP.Z-MinP.Z)*2), MaxS(MaxP.X-MinP.X, MaxP.Y-MinP.Y), 1);

    MulMatrix4s(M, M, TranslationMatrix4s(-(MinP.X+MaxP.X)*0.5, -(Minp.Y+MaxP.Y)*0.5, -MinP.Z+100));
    ViewMatrix := M;
  end;

begin
  if Assigned(FOldCamera) and Assigned(FLight) then begin
    if Assigned(FLandscape) then
      InitShadowCamera2()
    else
      InitShadowCamera();
    FInvViewMatrix := InvertAffineMatrix4s(FViewMatrix);
    MulMatrix4s(FTotalMatrix, FViewMatrix, ProjMatrix);
    FViewValid := True;
    FOldCamera := nil;
    ComputeFrustumPlanes;
  end else inherited;
end;

procedure TLandscapeShadowMapCamera.OnApply(const OldCamera: TCamera);
begin
  FOldCamera := OldCamera;
  FViewValid  := False;
  if not Assigned(ClipPlanes[0]) then GetMem(ClipPlanes[0], SizeOf(ClipPlanes[0]^));
  ClipPlanes[0]^ := GetPlaneFromPointNormal(GetAbsLocation, ScaleVector3s(Transform.ViewForward, 1));
end;

begin
  GlobalClassList.Add('C2Land', GetUnitClassList);
end.
