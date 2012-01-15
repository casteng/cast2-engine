(*
 @Abstract(CAST II Engine materials unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains material base class
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Materials;

interface

uses
  Logger,
  BaseTypes, Basics, BaseStr, BaseMsg, Props, BaseCompiler, BaseClasses, Resources, ItemMsg,
  C2Types, CAST2, C2Res, C2Msg;

const
  // Color mask
  cmAlpha = 1; cmRed = 2; cmGreen = 4; cmBlue = 8;

    // Texture index special values
  // Texture unresolved yet or its resolution failed
  tivUnresolved   = -1;
  // No texture specified for the given stage
  tivNull         = -2;
  // Texture is a render target
  tivRenderTarget = -16;
    // Shader index special values
  // Shader unresolved yet or its resolution failed
  sivUnresolved   = -1;
  // No Shader specified for the given render pass
  sivNull         = -2;
  // Texture matrix type enumeration string
  TextureMatrixTypesEnum = 'None' + StringDelimiter +
                           'Camera inverse' + StringDelimiter + 'Mirror' + StringDelimiter + 'Shadow map' + StringDelimiter +
                           'Scale' + StringDelimiter +
                           'Custom';
  // Pass running conditions enumeration string
  TPassConditionsEnum = 'Once' + StringDelimiter + 'For each light';

type
  // Pass running conditions enumeration
  TPassCondition = (// Run the pass once for an item
                    pcOnce,
                    // Run the pass for each light affecting the currently rendering item   
                    pcEachLight);

  TBlendingState = record
    Enabled: Boolean;
    CRC, AlphaRef, ATestFunc, SrcBlend, DestBlend, Operation: Integer;
  end;

  TZBufferState = record
    CRC, ZTestFunc, ZBias: Integer;
    ZWrite: Boolean;
  end;

  TFillShadeMode = record
    CRC, FillMode, ShadeMode, CullMode: Integer;
    ColorMask: Cardinal;
  end;

  TStencilState = record
    CRC, SFailOp, ZFailOp, PassOp, STestFunc: Integer;
  end;

  TTWrapCoordSet = array[0..MaxTextureCoordSets-1] of Cardinal;
  TTextureWrap = record
    CRC: Cardinal;
    CoordSet: TTWrapCoordSet;
  end;

  TLightingState = record
    CRC: Integer;
    GlobalAmbient: BaseTypes.TColor;
    SpecularMode: SmallInt;
    NormalizeNormals, Enabled: Boolean;
  end;

  TPointEdgeState = record
    CRC: Integer;
    PointSprite, PointScale, EdgeAntialias: Boolean;
  end;

  // Texture matrix setting
  TTextureMatrixType = (// No texture matrix
                        tmNone,
                        // Inverse camera view matrix
                        tmCameraInverse,
                        { Predefined texture matrix for a mirror implementation
                        }
                        tmMirror,
                        { Predefined texture matrix for shadow maps implementation
                        }
                        tmShadowMap,
                        // Scale matrix by <b>TextureMatrixBias</b>
                        tmScale,
                        // Texture matrix for the given coordinate set will be retrieved from the item currently drawn with the @Link(RetrieveTextureMatrix) delegate
                        tmCustom);

  TStage = record
    TextureIndex: Integer;                          // can be tivUnresolved, tivNull, tivRenderTarget
    ColorArg0, AlphaArg0: Longword;
    ColorOp, ColorArg1, ColorArg2: Longword; InvertColorArg1, InvertColorArg2: Boolean;
    AlphaOp, AlphaArg1, AlphaArg2: Longword; InvertAlphaArg1, InvertAlphaArg2: Boolean;
    TAddressing: Longword; StoreToTemp: Boolean;
    MipLODBias: Single;
    MaxMipLevel, MaxAnisotropy, Filtering: Longword;
    UVSource, TTransform: Longword;                 // Texture coordinates source, transform and wrapping
    TextureBorder: BaseTypes.TColor;
    TextureMatrixType: TTextureMatrixType;
    TextureMatrixBias: Single;
    Camera: TCamera;
  end;

  TRenderPass = class(TItem)
  public
    // SortBias is added to any sorted item's SortValue 
    SortBias: Single;
    Group: TPassGroup;
    BlendingState: TBlendingState;
    FillShadeMode: TFillShadeMode;
    ZBufferState : TZBufferState;
    StencilState : TStencilState;
    StencilRef, StencilMask, StencilWriteMask: Integer;

    TextureFactor: BaseTypes.TColor;    
    TextureWrap  : TTextureWrap;

    Ambient, Diffuse, Specular, Emissive: BaseTypes.TColor4S;
    Power: Single;
    LightingState: TLightingState;
    Stages: array of TStage;

    FogKind: Integer;
    FogStart, FogEnd, FogDensity: Single;
    FogColor: BaseTypes.TColor;
    PointSize, MinPointSize, MaxPointSize: Single;
    PointScaleA, PointScaleB, PointScaleC: Single;
    PointEdgeState: TPointEdgeState;
    LinePattern: Longword;

    VertexShaderIndex, PixelShaderIndex: Integer;   /// can be sivUnresolved, sivNull
    VertexDeclaration: TVertexDeclaration;

    ApplyCondition: TPassCondition;

    Items: TItems; TotalItems: Integer;                               // Items using this pass
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    /// For internal use only.
    function AddItem(const Item: TItem): Integer;
    /// For internal use only.
    function RemoveItem(const Index: Integer): Boolean;

    /// Called from TRenderer.ResolveTexture. For internal use only.
    function ResolveTexture(const Index: Integer; out Texture: Resources.TImageResource): Boolean;
    function ResolveVertexShader(var Shader: C2Res.TShaderResource): Boolean;
    function ResolvePixelShader(var Shader: C2Res.TShaderResource): Boolean;
  private
      ResolvedTexture: Resources.TImageResource;  // Obsolete?
    ResolvedVertexShader, ResolvedPixelShader: C2Res.TShaderResource;
    FOrder: Integer;
    FTotalVertexStreams, FStream0Elements: Integer;
    FVertexShaderConstants, FPixelShaderConstants: TAnsiStringArray;
    FCompiledVertexShaderConstants, FCompiledPixelShaderConstants: array of TRTData;
    function GetTotalStages: Integer;
    procedure SetTotalStages(const Value: Integer);
    function GetItemIndex(const Item: TItem): Integer;
    procedure SetOrder(const Value: Integer);
    function GetTotalPixelShaderConstants: Integer;
    function GetTotalVertexShaderConstants: Integer;
    procedure SetTotalPixelShaderConstants(const Value: Integer);
    procedure SetTotalVertexShaderConstants(const Value: Integer);
    function GetPixelShaderConstant(Index: Integer): string;
    function GetVertexShaderConstant(Index: Integer): string;
    procedure SetPixelShaderConstant(Index: Integer; const Value: string);
    procedure SetVertexShaderConstant(Index: Integer; const Value: string);
    function GetCompiledPixelShaderConstants(Index: Integer): TRTData;
    function GetCompiledVertexShaderConstants(Index: Integer): TRTData;
  public
    procedure HandleMessage(const Msg: TMessage); override;

    procedure RequestValidation;

    property TotalStages: Integer read GetTotalStages write SetTotalStages;
    property Order: Integer read FOrder write SetOrder;

    property TotalVertexShaderConstants: Integer read GetTotalVertexShaderConstants write SetTotalVertexShaderConstants;
    property TotalPixelShaderConstants: Integer read GetTotalPixelShaderConstants write SetTotalPixelShaderConstants;
    property VertexShaderConstant[Index: Integer]: string read GetVertexShaderConstant write SetVertexShaderConstant;
    property PixelShaderConstant[Index: Integer]: string read GetPixelShaderConstant write SetPixelShaderConstant;
    property CompiledVertexShaderConstants[Index: Integer]: TRTData read GetCompiledVertexShaderConstants;
    property CompiledPixelShaderConstants[Index: Integer]:  TRTData read GetCompiledPixelShaderConstants;
  end;

  TTechnique = class(TItem)
  private
    FTotalPasses: Integer;
    PassesCache: array of TRenderPass;
    FValid: Boolean;
    procedure SetTotalPasses(const Value: Integer);
    function GetPass(Index: Integer): TRenderPass;
    procedure SetPass(Index: Integer; const Value: TRenderPass);
  protected
    procedure SetState(const Value: TItemFlags); override;
  public
    LOD: Integer;
    constructor Create(AManager: TItemsManager); override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    property TotalPasses: Integer read FTotalPasses write SetTotalPasses;
    property Passes[Index: Integer]: TRenderPass read GetPass write SetPass; default;
    property Valid: Boolean read FValid write FValid;
  end;

  TMaterial = class(TItem)
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
    function GetTechniqueByLOD(Lod: Single): TTechnique;
  private
    FTotalTechniques: Integer;
    function GetTechnique(Index: Integer): TTechnique;
    procedure SetTechnique(Index: Integer; const Value: TTechnique);
    procedure SetTotalTechniques(const Value: Integer);
    function PassBelongs(AItem: TItem): Boolean;
  public
    procedure OnSceneLoaded; override;
    procedure HandleMessage(const Msg: TMessage); override;

    property TotalTechniques: Integer read FTotalTechniques write SetTotalTechniques;
    property Technique[Index: Integer]: TTechnique read GetTechnique write SetTechnique; default;
  end;

  // Pass options
  TPassOption = (// Alpha test
                 poAlphaTest,
                 // Z test
                 poZTest,
                 // Lighting
                 poLighting,
                 // Fog
                 poFog);
  // Pass option set
  TPassOptions = set of TPassOption;

  // Pass blending options
  TPassBlending = (// No blending
                   pbOpaque,
                   // Alpha blending ( Dest = Src * Alpha + Dest * (1 - alpha) )
                   pbAlphaBlend,
                   // Additive blending 
                   pbAdditiveBlend,
                   // Leave blending unchanged
                   pbCustom);

  function GetPointEdgeState(PointSprite, PointScale, EdgeAntialias: Boolean): TPointEdgeState;
  function GetBlendingState(Enabled: Boolean; SrcBlend, DestBlend, AlphaRef, ATestFunc, Operation: Integer): TBlendingState;
  function GetZBufferState(ZWrite: Boolean; ZTestFunc, ZBias: Integer): TZBufferState;
  function GetFillShadeMode(FillMode, ShadeMode, CullMode: Integer; ColorMask: Cardinal): TFillShadeMode;
  function GetStencilstate(SFailOp, ZFailOp, PassOp, STestFunc: Integer): TStencilState;
  function GetTextureWrap(Set0, Set1, Set2, Set3, Set4, Set5, Set6, Set7: Cardinal): TTextureWrap;
  function GetLightingState(SpecularMode: Integer; NormalizeNormals, Enabled: Boolean; GlobalAmbient: BaseTypes.TColor): TLightingState;

  // Modifies the specified stage of the specified pass with the specified parameters
  procedure ModifyPass(Pass: TRenderPass; Blending: TPassBlending; Options: TPassOptions);

implementation

uses SysUtils;

procedure ModifyPass(Pass: TRenderPass; Blending: TPassBlending; Options: TPassOptions);
var AlfaTestFunc, ZTestFunc: Integer;
begin
  if not Assigned(Pass) then Exit;

  if poAlphaTest in Options then
    AlfaTestFunc := tfGREATER
  else
    AlfaTestFunc := tfALWAYS;

  if poZTest in Options then
    ZTestFunc := tfLESSEQUAL
  else
    ZTestFunc := tfALWAYS;

  if poFog in Options then
    Pass.FogKind := fkDEFAULT
  else
    Pass.FogKind := fkNONE;

  Pass.LightingState.Enabled := poLighting in Options;

  case Blending of
    pbOpaque: begin
      Pass.BlendingState := GetBlendingState(poAlphaTest in Options, bmONE, bmZERO, Pass.BlendingState.AlphaRef, AlfaTestFunc, Pass.BlendingState.Operation);
      Pass.ZBufferState  := GetZBufferState(True, ZTestFunc, 0);
      Pass.Order := poNormal;
    end;
    pbAlphaBlend: begin
      Pass.BlendingState := GetBlendingState(True, bmSRCALPHA, bmInvSRCALPHA, Pass.BlendingState.AlphaRef, AlfaTestFunc, Pass.BlendingState.Operation);
      Pass.ZBufferState  := GetZBufferState(False, ZTestFunc, 0);
      Pass.Order := poSorted;
    end;
    pbAdditiveBlend: begin
      Pass.BlendingState := GetBlendingState(True, bmSRCALPHA, bmONE, Pass.BlendingState.AlphaRef, AlfaTestFunc, Pass.BlendingState.Operation);
      Pass.ZBufferState  := GetZBufferState(False, ZTestFunc, 0);
      Pass.Order := poSorted;
    end;
    pbCustom: ;
    else Assert(False);
  end;
end;


function GetPointEdgeState(PointSprite, PointScale, EdgeAntialias: Boolean): TPointEdgeState;
begin
  Result.PointSprite   := PointSprite;
  Result.PointScale    := PointScale;
  Result.EdgeAntialias := EdgeAntialias;
  Result.CRC           := Ord(EdgeAntialias) shl 2 + Ord(PointScale) shl 1 + Ord(PointSprite);
end;

function GetBlendingState(Enabled: Boolean; SrcBlend, DestBlend, AlphaRef, ATestFunc, Operation: Integer): TBlendingState;
begin
  Result.Enabled   := Enabled;
  Result.SrcBlend  := SrcBlend;
  Result.DestBlend := DestBlend;
  Result.AlphaRef  := AlphaRef;
  Result.ATestFunc := ATestFunc;
  Result.Operation := Operation;
  Result.CRC       := AlphaRef shl 24 + Ord(Enabled) shl 23 + Operation shl 18 + ATestFunc shl 12 + SrcBlend shl 6 + DestBlend;
end;

function GetZBufferState(ZWrite: Boolean; ZTestFunc, ZBias: Integer): TZBufferState;
begin
  Result.ZWrite    := ZWrite;
  Result.ZTestFunc := ZTestFunc;
  Result.ZBias     := ZBias;
  Result.CRC       := Ord(ZWrite) shl 15 + ZTestFunc shl 8 + ZBias;
end;

function GetFillShadeMode(FillMode, ShadeMode, CullMode: Integer; ColorMask: Cardinal): TFillShadeMode;
begin
  Result.FillMode  := FillMode;
  Result.ShadeMode := ShadeMode;
  Result.CullMode  := CullMode;
  Result.ColorMask := ColorMask;
  Result.CRC       := Integer(ColorMask shl 16) + CullMode shl 12 + ShadeMode shl 4 + FillMode;
end;

function GetStencilstate(SFailOp, ZFailOp, PassOp, STestFunc: Integer): TStencilState;
begin
  Result.SFailOp   := SFailOp;
  Result.ZFailOp   := ZFailOp;
  Result.PassOp    := PassOp;
  Result.STestFunc := STestFunc;
  Result.CRC       := STestFunc shl 24 + PassOp shl 16 + ZFailOp shl 8 + SFailOp;
end;

function GetTextureWrap(Set0, Set1, Set2, Set3, Set4, Set5, Set6, Set7: Cardinal): TTextureWrap;
begin
  Result.CoordSet[0] := Set0;
  Result.CoordSet[1] := Set1;
  Result.CoordSet[2] := Set2;
  Result.CoordSet[3] := Set3;
  Result.CoordSet[4] := Set4;
  Result.CoordSet[5] := Set5;
  Result.CoordSet[6] := Set6;
  Result.CoordSet[7] := Set7;
  Result.CRC  := Set7 shl 28 + Set6 shl 24 + Set5 shl 20 + Set4 shl 16 + Set3 shl 12 + Set2 shl 8 + Set1 shl 4 + Set0;
end;

function GetLightingState(SpecularMode: Integer; NormalizeNormals, Enabled: Boolean; GlobalAmbient: BaseTypes.TColor): TLightingState;
begin
  Result.SpecularMode     := SpecularMode;
  Result.NormalizeNormals := NormalizeNormals;
  Result.Enabled          := Enabled;
  Result.GlobalAmbient    := GlobalAmbient;
  Result.CRC              := Ord(SpecularMode) shl 2 + Ord(NormalizeNormals) shl 1 + Ord(Enabled);
end;

{ TRenderPass }

constructor TRenderPass.Create(AManager: TItemsManager);
begin
  inherited;
  FOrder           := poNormal;
  SortBias         := 0;
  BlendingState    := GetBlendingState(False, bmONE, bmZERO, 0, tfALWAYS, boADD);
  FillShadeMode    := GetFillShadeMode(fmDEFAULT, smGOURAUD, cmCAMERADEFAULT, $FFFFFFFF);
  ZBufferState     := GetZBufferState(True, tfLESSEQUAL, 0);
  StencilState     := GetStencilstate(soKEEP, soKEEP, soKEEP, tfALWAYS);
  StencilRef       := 0;
  StencilMask      := -1;
  StencilWriteMask := -1;

  TextureFactor.C   := $00000000;
  TextureWrap       := GetTextureWrap(0, 0, 0, 0, 0, 0, 0, 0);

  Ambient          := GetColor4S(0.5, 0.5, 0.5, 0.5);
  Diffuse          := GetColor4S(0.5, 0.5, 0.5, 0.5);
  Specular         := GetColor4S(0.0, 0.0, 0.0, 0.0);
  Power            := 0;
  LightingState    := GetLightingState(slACCURATE, False, True, GetColor($40404040));

  Group           := 0;
  FogKind         := fkNONE;
  FogStart        := 0;
  FogEnd          := 10000;
  FogDensity      := 1;
  FogColor.C      := $808080FF;
  PointSize       := 1;
  LinePattern     := 0;
  MinPointSize    := 0;
  MaxPointSize    := 10000;
  PointScaleA     := 1;
  PointScaleB     := 0;
  PointScaleC     := 0;
  PointEdgeState  := GetPointEdgeState(False, False, False);

  VertexShaderIndex := sivNull;
  PixelShaderIndex  := sivNull;

  FTotalVertexStreams := 1;
  FStream0Elements    := 0;

  TotalStages := 1;
end;

destructor TRenderPass.Destroy;
var i: Integer;
begin
  VertexDeclaration := nil;
  Items             := nil;

  for i := 0 to High(FVertexShaderConstants) do FVertexShaderConstants[i] := '';
  FVertexShaderConstants := nil;
  for i := 0 to High(FPixelShaderConstants) do  FPixelShaderConstants[i]  := '';
  FPixelShaderConstants := nil;
  for i := 0 to High(FCompiledVertexShaderConstants) do FreeAndNil(FCompiledVertexShaderConstants[i]);
  FCompiledVertexShaderConstants := nil;
  for i := 0 to High(FCompiledPixelShaderConstants) do FreeAndNil(FCompiledPixelShaderConstants[i]);
  FCompiledPixelShaderConstants := nil;

  inherited;
end;

procedure TRenderPass.AddProperties(const Result: Props.TProperties);
var j, k: Integer; LevelStr: string[50];
begin
  inherited;
  if Assigned(Result) then begin
    Result.AddEnumerated('Group', [], Group, PassGroupsEnum);

    Result.AddEnumerated('Render\Order',             [], Order, PassOrdersEnum);
    Result.Add('Render\Sort bias',        vtSingle,  [], FloatToStr(SortBias), '');
    Result.AddEnumerated('Render\Face culling',      [], FillShadeMode.CullMode,  CullModesEnum);
    Result.Add('Render\Color write mask', vtColor,   [], '#' + IntToHex(FillShadeMode.ColorMask, 8), '');

    Result.Add('Blend',                    vtBoolean, [], OnOffStr[BlendingState.Enabled], '');
    Result.AddEnumerated('Blend\Operation',           [], BlendingState.Operation, BlendOpsEnum);
    Result.AddEnumerated('Blend\Source',              [], BlendingState.SrcBlend,  BlendArgumentsEnum);
    Result.AddEnumerated('Blend\Destination',         [], BlendingState.DestBlend, BlendArgumentsEnum);
    Result.AddEnumerated('Blend\Alpha test function', [], BlendingState.ATestFunc, TestFuncsEnum);
    Result.Add('Blend\Alpha reference',     vtInt,    [], IntToStr(BlendingState.AlphaRef), '0-255');

    Result.AddEnumerated('Render\Fill mode',         [], FillShadeMode.FillMode,  FillModesEnum);
    Result.AddEnumerated('Render\Shade mode',        [], FillShadeMode.ShadeMode, ShadeModesEnum);

    Result.AddEnumerated('Z buffer\Test function',  [], ZBufferState.ZTestFunc, TestFuncsEnum);
    Result.Add('Z buffer\Bias',          vtInt,     [], IntToStr(ZBufferState.ZBias),  '');
    Result.Add('Z buffer\Write',         vtBoolean, [], OnOffStr[ZBufferState.ZWrite], '');

    Result.AddEnumerated('Stencil\On stencil fail', [], StencilState.SFailOp,   StencilOpsEnum);
    Result.AddEnumerated('Stencil\On Z fail',       [], StencilState.ZFailOp,   StencilOpsEnum);
    Result.AddEnumerated('Stencil\On pass',         [], StencilState.PassOp,    StencilOpsEnum);
    Result.AddEnumerated('Stencil\Test function',   [], StencilState.STestFunc, TestFuncsEnum);

    Result.Add('Stencil\Reference',  vtInt, [], IntToStr(StencilRef),       '0-255');
    Result.Add('Stencil\Mask',       vtInt, [], IntToStr(StencilMask),      '');
    Result.Add('Stencil\Write mask', vtInt, [], IntToStr(StencilWriteMask), '');

    AddColor4sProperty(Result, 'Texture\Factor', ColorTo4S(TextureFactor));

    for j := 0 to MaxTextureCoordSets-1 do begin
      LevelStr := 'Texture\Coord set ' + IntToStr(j) + '\';
      Result.Add(LevelStr + 'Wrap U',  vtBoolean, [], OnOffStr[TextureWrap.CoordSet[j] and twUCoord > 0],   '');
      Result.Add(LevelStr + 'Wrap V',  vtBoolean, [], OnOffStr[TextureWrap.CoordSet[j] and twVCoord > 0],   '');
      Result.Add(LevelStr + 'Wrap W',  vtBoolean, [], OnOffStr[TextureWrap.CoordSet[j] and twWCoord > 0],   '');
      Result.Add(LevelStr + 'Wrap W2', vtBoolean, [], OnOffStr[TextureWrap.CoordSet[j] and twW2Coord > 0],  '');
    end;

    Result.Add('Lighting', vtBoolean, [], OnOffStr[LightingState.Enabled], '');

    AddColor4sProperty(Result, 'Lighting\Ambient',  Ambient);
    AddColor4sProperty(Result, 'Lighting\Diffuse',  Diffuse);
    AddColor4sProperty(Result, 'Lighting\Specular', Specular);
    AddColor4sProperty(Result, 'Lighting\Emissive', Emissive);

    Result.Add('Lighting\Specular\Power', vtSingle, [], FloatToStr(Power), '0-100');
    Result.AddEnumerated('Lighting\Specular\Mode',         [], LightingState.SpecularMode, SpecularEnum);
    Result.Add('Lighting\Normalize normals',    vtBoolean, [], OnOffStr[LightingState.NormalizeNormals], '');

    AddColor4sProperty(Result, 'Global ambient', ColorTo4S(LightingState.GlobalAmbient));

    AddColor4sProperty(Result, 'Fog\Color', ColorTo4S(FogColor));

    Result.AddEnumerated('Fog\Type', [], FogKind, FogKindsEnum);
    Result.Add('Fog\Start',   vtSingle,  [], FloatToStr(FogStart),   '0.1-100');
    Result.Add('Fog\End',     vtSingle,  [], FloatToStr(FogEnd),     '50-1000');
    Result.Add('Fog\Density', vtSingle,  [], FloatToStr(FogDensity), '1-10');

    Result.Add('Point\Sprites', vtBoolean, [], OnOffStr[PointEdgeState.PointSprite], '');
    Result.Add('Point\Scaling', vtBoolean, [], OnOffStr[PointEdgeState.PointScale], '');

    Result.Add('Point\Size',     vtSingle, [], FloatToStr(PointSize),    '0.01-10');
    Result.Add('Point\Size min', vtSingle, [], FloatToStr(MinPointSize), '0.01-10');
    Result.Add('Point\Size max', vtSingle, [], FloatToStr(MaxPointSize), '0.01-10');

    Result.Add('Point\Scale A', vtSingle, [], FloatToStr(PointScaleA), '0.01-10');
    Result.Add('Point\Scale B', vtSingle, [], FloatToStr(PointScaleB), '0.01-10');
    Result.Add('Point\Scale C', vtSingle, [], FloatToStr(PointScaleC), '0.01-10');

    Result.Add('Line pattern', vtNat, [], IntToStr(LinePattern), '');

    Result.Add('Edge antialiasing', vtBoolean, [], OnOffStr[PointEdgeState.EdgeAntialias], '');

    Result.Add('Total stages', vtNat, [], IntToStr(TotalStages), '');

    Result.Add('Shaders\Vertex\Declaration\Total streams', vtInt, [], IntToStr(FTotalVertexStreams), '');
    for j := 0 to FTotalVertexStreams-1 do begin
      LevelStr := 'Shaders\Vertex\Declaration\Stream #' + IntToStr(j) + '\';
      Result.Add(LevelStr + 'Total elements', vtInt, [], IntToStr(FStream0Elements), '');
      for k := 0 to FStream0Elements-1 do Result.AddEnumerated(LevelStr + '#' + IntToStr(k) + 'Data type', [], Ord(VertexDeclaration[k]), VertexDataTypesEnum);
    end;

    Result.Add('Shaders\Vertex\Total constants', vtInt, [], IntToStr(TotalVertexShaderConstants), '');
    Result.Add('Shaders\Pixel\Total constants',  vtInt, [], IntToStr(TotalPixelShaderConstants), '');

    for j := 0 to TotalVertexShaderConstants-1 do
      Result.Add('Shaders\Vertex\Constants\#' + IntToStr(j), vtString, [], FVertexShaderConstants[j], '');

    for j := 0 to TotalPixelShaderConstants-1 do
      Result.Add('Shaders\Pixel\Constants\#' + IntToStr(j), vtString, [], FPixelShaderConstants[j], '');
  end;

  AddItemLink(Result, 'Shaders\Vertex', [], 'TShaderResource');
  AddItemLink(Result, 'Shaders\Pixel',  [], 'TShaderResource');

  for j := 0 to TotalStages-1 do begin
    LevelStr := 'Stage #' + IntToStr(j) + '\';

    AddItemLink(Result, LevelStr + 'Texture', [], 'TItem');

    if Assigned(Result) then begin
      Result.AddEnumerated(LevelStr + 'Color\Operation',  [], Stages[j].ColorOp,   ColorOpsEnum);
      Result.AddEnumerated(LevelStr + 'Color\Argument 0', [], Stages[j].ColorArg0, ColorArgsEnum);
      Result.AddEnumerated(LevelStr + 'Color\Argument 1', [], Stages[j].ColorArg1, ColorArgsEnum);
      Result.AddEnumerated(LevelStr + 'Color\Argument 2', [], Stages[j].ColorArg2, ColorArgsEnum);
      Result.Add(LevelStr + 'Color\Invert Arg1', vtBoolean, [], OnOffStr[Stages[j].InvertColorArg1], '');
      Result.Add(LevelStr + 'Color\Invert Arg2', vtBoolean, [], OnOffStr[Stages[j].InvertColorArg2], '');
      Result.AddEnumerated(LevelStr + 'Alpha\Operation',  [], Stages[j].AlphaOp,   AlphaOpsEnum);
      Result.AddEnumerated(LevelStr + 'Alpha\Argument 0', [], Stages[j].AlphaArg0, AlphaArgsEnum);
      Result.AddEnumerated(LevelStr + 'Alpha\Argument 1', [], Stages[j].AlphaArg1, AlphaArgsEnum);
      Result.AddEnumerated(LevelStr + 'Alpha\Argument 2', [], Stages[j].AlphaArg2, AlphaArgsEnum);
      Result.Add(LevelStr + 'Alpha\Invert Arg1', vtBoolean, [], OnOffStr[Stages[j].InvertColorArg1], '');
      Result.Add(LevelStr + 'Alpha\Invert Arg2', vtBoolean, [], OnOffStr[Stages[j].InvertColorArg2], '');

      Result.AddEnumerated(LevelStr + 'Adressing\U', [],  Stages[j].TAddressing and $00F,        TexAdrsEnum);
      Result.AddEnumerated(LevelStr + 'Adressing\V', [], (Stages[j].TAddressing and $0F0) shr 4, TexAdrsEnum);
      Result.AddEnumerated(LevelStr + 'Adressing\W', [], (Stages[j].TAddressing and $F00) shr 8, TexAdrsEnum);

      Result.Add(LevelStr + 'Store in Temp register', vtBoolean, [], OnOffStr[Stages[j].StoreToTemp], '');

      Result.AddEnumerated(LevelStr + 'Filtering\Min', [],  Stages[j].Filtering and $00F,        TexFiltersEnum);
      Result.AddEnumerated(LevelStr + 'Filtering\Max', [], (Stages[j].Filtering and $0F0) shr 4, TexFiltersEnum);
      Result.AddEnumerated(LevelStr + 'Filtering\Mip', [], (Stages[j].Filtering and $F00) shr 8, TexFiltersEnum);
      Result.Add(LevelStr + 'Filtering\Mip LOD bias',   vtSingle, [], FloatToStr(Stages[j].MipLODBias),  '0-16');
      Result.Add(LevelStr + 'Filtering\Max mip level',  vtInt,    [], IntToStr(Stages[j].MaxMipLevel),   '0-14');
      Result.Add(LevelStr + 'Filtering\Max anisotropy', vtInt,    [], IntToStr(Stages[j].MaxAnisotropy), '0-16');

      AddColor4sProperty(Result, LevelStr + 'Texture border', ColorTo4S(Stages[j].TextureBorder));

      Result.Add(LevelStr + 'Texture coords\Set', vtNat, [], IntToStr(Stages[j].UVSource and $F), '');

      Result.AddEnumerated(LevelStr + 'Texture coords\Generation',  [], Stages[j].UVSource shr 4, TexCoordsGenEnum);
      Result.AddEnumerated(LevelStr + 'Texture coords\Transform',   [], Stages[j].TTransform and $F, 'None\&U\&U, V\&U, V, W, \&U, V, W, W2');
      Result.AddEnumerated(LevelStr + 'Texture coords\Matrix type', [], Ord(Stages[j].TextureMatrixType), TextureMatrixTypesEnum);
      Result.Add(LevelStr + 'Texture coords\Matrix bias', vtSingle, [], FloatToStr(Stages[j].TextureMatrixBias), '-1-1');

      Result.Add(LevelStr + 'Texture coords\Projected', vtBoolean, [], OnOffStr[Stages[j].TTransform and $80 > 0], '');
    end;
  end;
end;

procedure TRenderPass.SetProperties(Properties: Props.TProperties);
var j, k: Integer; LevelStr: string[50];
begin
  inherited;

  if Properties.Valid('Group') then Group := Properties.GetAsInteger('Group');

  if Properties.Valid('Render\Order')            then Order    := Properties.GetAsInteger('Render\Order');
  if Properties.Valid('Render\Sort bias')        then SortBias := StrToFloatDef(Properties['Render\Sort bias'], 0);
  if Properties.Valid('Render\Face culling')     then FillShadeMode.CullMode  :=          Properties.GetAsInteger('Render\Face culling');
  if Properties.Valid('Render\Color write mask') then FillShadeMode.ColorMask := Longword(Properties.GetAsInteger('Render\Color write mask'));

  if Properties.Valid('Blend')                     then BlendingState.Enabled   := Properties.GetAsInteger('Blend') > 0;
  if Properties.Valid('Blend\Operation')           then BlendingState.Operation := Properties.GetAsInteger('Blend\Operation');
  if Properties.Valid('Blend\Source')              then BlendingState.SrcBlend  := Properties.GetAsInteger('Blend\Source');
  if Properties.Valid('Blend\Destination')         then BlendingState.DestBlend := Properties.GetAsInteger('Blend\Destination');
  if Properties.Valid('Blend\Alpha test function') then BlendingState.ATestFunc := Properties.GetAsInteger('Blend\Alpha test function');
  if Properties.Valid('Blend\Alpha reference')     then BlendingState.AlphaRef  := StrToIntDef(Properties[ 'Blend\Alpha reference'], 0);
  BlendingState := GetBlendingState(BlendingState.Enabled, BlendingState.SrcBlend, BlendingState.DestBlend, BlendingState.AlphaRef, BlendingState.ATestFunc, BlendingState.Operation);

  if Properties.Valid('Render\Fill mode')  then FillShadeMode.FillMode  := Properties.GetAsInteger('Render\Fill mode');
  if Properties.Valid('Render\Shade mode') then FillShadeMode.ShadeMode := Properties.GetAsInteger('Render\Shade mode');

  FillShadeMode := GetFillShadeMode(FillShadeMode.FillMode, FillShadeMode.ShadeMode, FillShadeMode.CullMode, FillShadeMode.ColorMask);

  if Properties.Valid('Z buffer\Test function') then ZBufferState.ZTestFunc := Properties.GetAsInteger('Z buffer\Test function');
  if Properties.Valid('Z buffer\Bias')          then ZBufferState.ZBias     := StrToIntDef(Properties[ 'Z buffer\Bias'], 0);
  if Properties.Valid('Z buffer\Write')         then ZBufferState.ZWrite    := Properties.GetAsInteger('Z buffer\Write') > 0;
  ZBufferState := GetZBufferState(ZBufferState.ZWrite, ZBufferState.ZTestFunc, ZBufferState.ZBias);

  if Properties.Valid('Stencil\On stencil fail') then StencilState.SFailOp   := Properties.GetAsInteger('Stencil\On stencil fail');
  if Properties.Valid('Stencil\On Z fail')       then StencilState.ZFailOp   := Properties.GetAsInteger('Stencil\On Z fail');
  if Properties.Valid('Stencil\On pass')         then StencilState.PassOp    := Properties.GetAsInteger('Stencil\On pass');
  if Properties.Valid('Stencil\Test function')   then StencilState.STestFunc := Properties.GetAsInteger('Stencil\Test function');
  StencilState := GetStencilstate(StencilState.SFailOp, StencilState.ZFailOp, StencilState.PassOp, StencilState.STestFunc);

  if Properties.Valid('Stencil\Reference')  then StencilRef       := StrToIntDef(Properties['Stencil\Reference'], 0);
  if Properties.Valid('Stencil\Mask')       then StencilMask      := StrToIntDef(Properties['Stencil\Mask'], -1);
  if Properties.Valid('Stencil\Write mask') then StencilWriteMask := StrToIntDef(Properties['Stencil\Write mask'], -1);

  SetColorProperty(Properties, 'Texture\Factor', TextureFactor);

  for j := 0 to MaxTextureCoordSets-1 do begin
    LevelStr := 'Texture\Coord set ' + IntToStr(j) + '\';
    if Properties.Valid(LevelStr + 'Wrap U') then
     if Properties.GetAsInteger(LevelStr + 'Wrap U') > 0 then
      TextureWrap.CoordSet[j] := TextureWrap.CoordSet[j] or twUCoord else
       TextureWrap.CoordSet[j] := TextureWrap.CoordSet[j] and not twUCoord;
    if Properties.Valid(LevelStr + 'Wrap V') then
     if Properties.GetAsInteger(LevelStr + 'Wrap V') > 0 then
      TextureWrap.CoordSet[j] := TextureWrap.CoordSet[j] or twVCoord else
       TextureWrap.CoordSet[j] := TextureWrap.CoordSet[j] and not twVCoord;
    if Properties.Valid(LevelStr + 'Wrap W') then
     if Properties.GetAsInteger(LevelStr + 'Wrap W') > 0 then
      TextureWrap.CoordSet[j] := TextureWrap.CoordSet[j] or twWCoord else
       TextureWrap.CoordSet[j] := TextureWrap.CoordSet[j] and not twWCoord;
    if Properties.Valid(LevelStr + 'Wrap W2') then
     if Properties.GetAsInteger(LevelStr + 'Wrap W2') > 0 then
      TextureWrap.CoordSet[j] := TextureWrap.CoordSet[j] or twW2Coord else
       TextureWrap.CoordSet[j] := TextureWrap.CoordSet[j] and not twW2Coord;
  end;
  TextureWrap := GetTextureWrap(TextureWrap.CoordSet[0], TextureWrap.CoordSet[1], TextureWrap.CoordSet[2], TextureWrap.CoordSet[3],
                                TextureWrap.CoordSet[4], TextureWrap.CoordSet[5], TextureWrap.CoordSet[6], TextureWrap.CoordSet[7]);

  SetColor4sProperty(Properties, 'Lighting\Ambient',  Ambient);
  SetColor4sProperty(Properties, 'Lighting\Diffuse',  Diffuse);
  SetColor4sProperty(Properties, 'Lighting\Specular', Specular);
  SetColor4sProperty(Properties, 'Lighting\Emissive', Emissive);

  if Properties.Valid('Lighting')                   then LightingState.Enabled          := Properties.GetAsInteger('Lighting') > 0;
  if Properties.Valid('Lighting\Specular\Power') then Power := StrToFloatDef(Properties['Lighting\Specular\Power'], 0);
  if Properties.Valid('Lighting\Specular\Mode')     then LightingState.SpecularMode     := Properties.GetAsInteger('Lighting\Specular\Mode');
  if Properties.Valid('Lighting\Normalize normals') then LightingState.NormalizeNormals := Properties.GetAsInteger('Lighting\Normalize normals') > 0;
  SetColorProperty(Properties, 'Global ambient', LightingState.GlobalAmbient);

  LightingState := GetLightingState(LightingState.SpecularMode, LightingState.NormalizeNormals, LightingState.Enabled, LightingState.GlobalAmbient);

  SetColorProperty(Properties, 'Fog\Color', FogColor);
  if Properties.Valid('Fog\Type')    then FogKind    := Properties.GetAsInteger('Fog\Type');
  if Properties.Valid('Fog\Start')   then FogStart   := StrToFloatDef(Properties['Fog\Start'],   0);
  if Properties.Valid('Fog\End')     then FogEnd     := StrToFloatDef(Properties['Fog\End'],     10000);
  if Properties.Valid('Fog\Density') then FogDensity := StrToFloatDef(Properties['Fog\Density'], 1);

  if Properties.Valid('Point\Sprites') then PointEdgeState.PointSprite := Properties.GetAsInteger('Point\Sprites') > 0;
  if Properties.Valid('Point\Scaling') then PointEdgeState.PointScale  := Properties.GetAsInteger('Point\Scaling') > 0;

  if Properties.Valid('Point\Size')     then PointSize    := StrToFloatDef(Properties['Point\Size'],   1);
  if Properties.Valid('Point\Size min') then MinPointSize := StrToFloatDef(Properties['Point\Size min'], 0);
  if Properties.Valid('Point\Size max') then MaxPointSize := StrToFloatDef(Properties['Point\Size max'], 1000);

  if Properties.Valid('Point\Scale A') then PointScaleA := StrToFloatDef(Properties['Point\Scale A'], 1);
  if Properties.Valid('Point\Scale B') then PointScaleB := StrToFloatDef(Properties['Point\Scale B'], 0);
  if Properties.Valid('Point\Scale C') then PointScaleC := StrToFloatDef(Properties['Point\Scale C'], 0);

  if Properties.Valid('Line pattern') then LinePattern := StrToIntDef(Properties['Line pattern'], 0);

  if Properties.Valid('Edge antialiasing') then PointEdgeState.EdgeAntialias := Properties.GetAsInteger('Edge antialiasing') > 0;
  PointEdgeState := GetPointEdgeState(PointEdgeState.PointSprite, PointEdgeState.PointScale, PointEdgeState.EdgeAntialias);

  // Shaders
  LevelStr := 'Shaders\Vertex\Declaration\Total streams';
  if Properties.Valid(LevelStr) then FTotalVertexStreams := Properties.GetAsInteger(LevelStr);

  for j := 0 to FTotalVertexStreams-1 do begin
    LevelStr := 'Shaders\Vertex\Declaration\Stream #' + IntToStr(j) + '\';
    if Properties.Valid(LevelStr + 'Total elements') then begin
      FStream0Elements := Properties.GetAsInteger(LevelStr + 'Total elements');
      SetLength(VertexDeclaration, FStream0Elements);
    end;
    for k := 0 to FStream0Elements-1 do
      if Properties.Valid(LevelStr + '#' + IntToStr(k) + 'Data type') then VertexDeclaration[k] := TVertexDataType(Properties.GetAsInteger(LevelStr + '#' + IntToStr(k) + 'Data type'));
  end;

  LevelStr := 'Shaders\Vertex\Total constants';
  if Properties.Valid(LevelStr) then TotalVertexShaderConstants := Properties.GetAsInteger(LevelStr);

  LevelStr := 'Shaders\Pixel\Total constants';
  if Properties.Valid(LevelStr) then TotalPixelShaderConstants := Properties.GetAsInteger(LevelStr);

  for j := 0 to TotalVertexShaderConstants-1 do begin
    LevelStr := 'Shaders\Vertex\Constants\#' + IntToStr(j);
    if Properties.Valid(LevelStr) then
      VertexShaderConstant[j] := Properties[LevelStr];
  end;

  for j := 0 to TotalPixelShaderConstants-1 do begin
    LevelStr := 'Shaders\Pixel\Constants\#' + IntToStr(j);
    if Properties.Valid(LevelStr) then
      PixelShaderConstant[j] := Properties[LevelStr];
  end;
  
  if Properties.Valid('Shaders\Vertex') then begin
    if SetLinkProperty('Shaders\Vertex', Properties['Shaders\Vertex']) then
      VertexShaderIndex := sivUnresolved;
    if (Properties['Shaders\Vertex'] = '') then VertexShaderIndex := sivNull;
  end;
        
  if Properties.Valid('Shaders\Pixel')  then begin
    if SetLinkProperty('Shaders\Pixel', Properties['Shaders\Pixel']) then
      PixelShaderIndex := sivUnresolved;
    if (Properties['Shaders\Pixel'] = '') then PixelShaderIndex := sivNull;
  end;

  // Texture stages        
  if Properties.Valid('Total stages') then TotalStages := Properties.GetAsInteger('Total stages');

  for j := 0 to TotalStages-1 do begin
    LevelStr := 'Stage #' + IntToStr(j) + '\';

    if Properties.Valid(LevelStr + 'Texture') then
      if (Properties[LevelStr + 'Texture'] = '') then begin
        Stages[j].TextureIndex := tivNull;
        SetLinkProperty(LevelStr + 'Texture', '');
      end else if SetLinkProperty(LevelStr + 'Texture', Properties[LevelStr + 'Texture']) then
        Stages[j].TextureIndex := tivUnresolved;

    if Properties.Valid(LevelStr + 'Color\Operation')   then Stages[j].ColorOp         := Properties.GetAsInteger(LevelStr + 'Color\Operation');
    if Properties.Valid(LevelStr + 'Color\Argument 0')  then Stages[j].ColorArg0       := Properties.GetAsInteger(LevelStr + 'Color\Argument 0');
    if Properties.Valid(LevelStr + 'Color\Argument 1')  then Stages[j].ColorArg1       := Properties.GetAsInteger(LevelStr + 'Color\Argument 1');
    if Properties.Valid(LevelStr + 'Color\Argument 2')  then Stages[j].ColorArg2       := Properties.GetAsInteger(LevelStr + 'Color\Argument 2');
    if Properties.Valid(LevelStr + 'Color\Invert Arg1') then Stages[j].InvertColorArg1 := Properties.GetAsInteger(LevelStr + 'Color\Invert Arg1') > 0;
    if Properties.Valid(LevelStr + 'Color\Invert Arg2') then Stages[j].InvertColorArg2 := Properties.GetAsInteger(LevelStr + 'Color\Invert Arg2') > 0;

    if Properties.Valid(LevelStr + 'Alpha\Operation')   then Stages[j].AlphaOp         := Properties.GetAsInteger(LevelStr + 'Alpha\Operation');
    if Properties.Valid(LevelStr + 'Alpha\Argument 0')  then Stages[j].AlphaArg0       := Properties.GetAsInteger(LevelStr + 'Alpha\Argument 0');
    if Properties.Valid(LevelStr + 'Alpha\Argument 1')  then Stages[j].AlphaArg1       := Properties.GetAsInteger(LevelStr + 'Alpha\Argument 1');
    if Properties.Valid(LevelStr + 'Alpha\Argument 2')  then Stages[j].AlphaArg2       := Properties.GetAsInteger(LevelStr + 'Alpha\Argument 2');
    if Properties.Valid(LevelStr + 'Alpha\Invert Arg1') then Stages[j].InvertAlphaArg1 := Properties.GetAsInteger(LevelStr + 'Alpha\Invert Arg1') > 0;
    if Properties.Valid(LevelStr + 'Alpha\Invert Arg2') then Stages[j].InvertAlphaArg2 := Properties.GetAsInteger(LevelStr + 'Alpha\Invert Arg2') > 0;

    if Properties.Valid(LevelStr + 'Adressing\U') then Stages[j].TAddressing := (Stages[j].TAddressing and not $00F) or Cardinal(Properties.GetAsInteger(LevelStr + 'Adressing\U'));
    if Properties.Valid(LevelStr + 'Adressing\V') then Stages[j].TAddressing := (Stages[j].TAddressing and not $0F0) or Cardinal(Properties.GetAsInteger(LevelStr + 'Adressing\V')) shl 4;
    if Properties.Valid(LevelStr + 'Adressing\W') then Stages[j].TAddressing := (Stages[j].TAddressing and not $F00) or Cardinal(Properties.GetAsInteger(LevelStr + 'Adressing\W')) shl 8;

    if Properties.Valid(LevelStr + 'Store in Temp register') then Stages[j].StoreToTemp := Properties.GetAsInteger(LevelStr + 'Store in Temp register') > 0;

    if Properties.Valid(LevelStr + 'Filtering\Min') then Stages[j].Filtering := (Stages[j].Filtering and not $00F) or Cardinal(Properties.GetAsInteger(LevelStr + 'Filtering\Min'));
    if Properties.Valid(LevelStr + 'Filtering\Max') then Stages[j].Filtering := (Stages[j].Filtering and not $0F0) or Cardinal(Properties.GetAsInteger(LevelStr + 'Filtering\Max')) shl 4;
    if Properties.Valid(LevelStr + 'Filtering\Mip') then Stages[j].Filtering := (Stages[j].Filtering and not $F00) or Cardinal(Properties.GetAsInteger(LevelStr + 'Filtering\Mip')) shl 8;
    if Properties.Valid(LevelStr + 'Filtering\Mip LOD bias')   then Stages[j].MipLODBias  := StrToFloatDef(Properties[LevelStr + 'Filtering\Mip LOD bias'], 0);
    if Properties.Valid(LevelStr + 'Filtering\Max mip level')  then Stages[j].MaxMipLevel := Properties.GetAsInteger(LevelStr + 'Filtering\Max mip level');
    if Properties.Valid(LevelStr + 'Filtering\Max anisotropy') then Stages[j].MaxAnisotropy := Properties.GetAsInteger(LevelStr + 'Filtering\Max anisotropy');

    SetColorProperty(Properties, LevelStr + 'Texture border', Stages[j].TextureBorder);

    if Properties.Valid(LevelStr + 'Texture coords\Set')        then Stages[j].UVSource := (Stages[j].UVSource and not $0F) or Cardinal(Properties.GetAsInteger(LevelStr + 'Texture coords\Set'));
    if Properties.Valid(LevelStr + 'Texture coords\Generation') then Stages[j].UVSource := (Stages[j].UVSource and not $F0) or Cardinal(Properties.GetAsInteger(LevelStr + 'Texture coords\Generation')) shl 4;

    if Properties.Valid(LevelStr + 'Texture coords\Transform')   then Stages[j].TTransform        := (Stages[j].TTransform and not $0F) or Cardinal(Properties.GetAsInteger(LevelStr + 'Texture coords\Transform'));
    if Properties.Valid(LevelStr + 'Texture coords\Matrix type') then Stages[j].TextureMatrixType := TTextureMatrixType(Properties.GetAsInteger(LevelStr + 'Texture coords\Matrix type'));
    if Properties.Valid(LevelStr + 'Texture coords\Matrix bias') then Stages[j].TextureMatrixBias := StrToFloatDef(Properties[LevelStr + 'Texture coords\Matrix bias'], 0);

    if Properties.Valid(LevelStr + 'Texture coords\Projected')   then Stages[j].TTransform        := (Stages[j].TTransform and not $80) or Cardinal(Properties.GetAsInteger(LevelStr + 'Texture coords\Projected')) shl 7;
  end;

  RequestValidation;
end;

function TRenderPass.GetTotalStages: Integer;
begin
  Result := Length(Stages);
end;

procedure TRenderPass.SetTotalStages(const Value: Integer);
var i: Integer; OldTotalStages: Integer;
begin
  OldTotalStages := TotalStages;
  SetLength(Stages, Value);
  for i := OldTotalStages to Value-1 do begin
    Stages[i].TextureIndex      := tivNull;
    Stages[i].ColorOp           := toMODULATE;
    Stages[i].ColorArg1         := taTexture;
    Stages[i].ColorArg2         := taDiffuse;
    Stages[i].InvertColorArg1   := False;
    Stages[i].InvertColorArg2   := False;
    Stages[i].AlphaOp           := toDISABLE;
    Stages[i].AlphaArg1         := taTexture;
    Stages[i].AlphaArg2         := taDiffuse;
    Stages[i].InvertAlphaArg1   := False;
    Stages[i].InvertAlphaArg2   := False;
    Stages[i].TAddressing       := 0;
    Stages[i].StoreToTemp       := False;
    Stages[i].Filtering         := $222;
    Stages[i].UVSource          := 0;
    Stages[i].TTransform        := 2;
    Stages[i].TextureMatrixType := tmNone;
    Stages[i].TextureMatrixBias := 0;
  end;
  BuildItemLinks;
end;

function TRenderPass.AddItem(const Item: TItem): Integer;
begin
  Assert(GetItemIndex(Item) = -1, ClassName + '.AddItem: Item already exists');
  if TotalItems = 0 then (FManager as CAST2.TBaseCore).AddPass(Self);
  Inc(TotalItems);
  if Length(Items) < TotalItems then SetLength(Items, Length(Items) + ItemsCapacityStep);
  Items[TotalItems-1] := Item;
  Result := TotalItems-1;
end;

function TRenderPass.RemoveItem(const Index: Integer): Boolean;
// Returns true if item relocation in Items array occured
begin
  Assert((Index >= 0) and (Index < TotalItems), ClassName + '.RemoveItem: Invalid index "' + IntToStr(Index) + '"');
  Dec(TotalItems);
  Items[Index] := Items[TotalItems];
  Result := Index <> TotalItems;
  if TotalItems = 0 then (FManager as CAST2.TBaseCore).RemovePass(Self);
end;

function TRenderPass.ResolveTexture(const Index: Integer; out Texture: Resources.TImageResource): Boolean;
var Item: TItem;
begin
  Result := ResolveLink('Stage #' + IntToStr(Index) + '\Texture', Item);
  if Item is TImageResource then begin
    Texture := Item as Resources.TImageResource;
    Stages[Index].Camera := nil;
    ResolvedTexture := Texture;
  end else if Item is TCamera then begin
    Stages[Index].TextureIndex := tivRenderTarget;
    Stages[Index].Camera := Item as TCamera;
  end;
end;

function TRenderPass.ResolveVertexShader(var Shader: TShaderResource): Boolean;
var Item: TItem;
begin
  Result := ResolveLink('Shaders\Vertex', Item);
  Shader := Item as TShaderResource;
  ResolvedVertexShader := Shader;
end;

function TRenderPass.ResolvePixelShader(var Shader: TShaderResource): Boolean;
var Item: TItem;
begin
  Result := ResolveLink('Shaders\Pixel', Item);
  Shader := Item as TShaderResource;
  ResolvedPixelShader := Shader;
end;

function TRenderPass.GetItemIndex(const Item: TItem): Integer;
begin
  Result := 0;
  while Result < TotalItems do begin
    if Items[Result] = Item then Exit;
    Inc(Result);
  end;
  Result := -1;
end;

procedure TRenderPass.SetOrder(const Value: Integer);
begin
  if Value = FOrder then Exit;
  FOrder := Value;
  if (TotalItems > 0) and (FManager <> nil) then begin                 // For pass reordering in core
    (FManager as CAST2.TBaseCore).RemovePass(Self);
    (FManager as CAST2.TBaseCore).AddPass(Self);
  end;
end;

function TRenderPass.GetTotalPixelShaderConstants: Integer;
begin
  Result := Length(FPixelShaderConstants);
end;

function TRenderPass.GetTotalVertexShaderConstants: Integer;
begin
  Result := Length(FVertexShaderConstants);
end;

procedure TRenderPass.SetTotalPixelShaderConstants(const Value: Integer);
begin
  SetLength(FPixelShaderConstants, Value);
  SetLength(FCompiledPixelShaderConstants, Value);
  RequestValidation;
end;

procedure TRenderPass.SetTotalVertexShaderConstants(const Value: Integer);
begin
  SetLength(FVertexShaderConstants, Value);
  SetLength(FCompiledVertexShaderConstants, Value);
  RequestValidation;
end;

function TRenderPass.GetPixelShaderConstant(Index: Integer): string;
begin
  Result := FPixelShaderConstants[Index];
end;

function TRenderPass.GetVertexShaderConstant(Index: Integer): string;
begin
  Result := FVertexShaderConstants[Index];
end;

procedure TRenderPass.SetVertexShaderConstant(Index: Integer; const Value: string);
begin
  if (Index >= 0) or (Index < TotalVertexShaderConstants) then begin
    FVertexShaderConstants[Index] := Value;
    FCompiledVertexShaderConstants[Index] := FManager.Compiler.Compile(Value);
  end else Log(Format('%S.%S: Invalid index', [ClassName, 'SetVertexShaderConstant']), lkError);
end;

procedure TRenderPass.SetPixelShaderConstant(Index: Integer; const Value: string);
begin
  if (Index >= 0) or (Index < TotalPixelShaderConstants) then begin
    FPixelShaderConstants[Index] := Value;
    FCompiledPixelShaderConstants[Index] := FManager.Compiler.Compile(Value);
  end else Log(Format('%S.%S: Invalid index', [ClassName, 'SetPixelShaderConstant']), lkError);
end;

function TRenderPass.GetCompiledVertexShaderConstants(Index: Integer): TRTData;
begin
  Result := FCompiledVertexShaderConstants[Index];
end;

function TRenderPass.GetCompiledPixelShaderConstants(Index: Integer): TRTData;
begin
  Result := FCompiledPixelShaderConstants[Index];
end;

procedure TRenderPass.HandleMessage(const Msg: TMessage);
var i: Integer;
begin
  inherited;
  if Msg.ClassType = TDataModifyMsg then begin
    if TDataModifyMsg(Msg).Data = Pointer(ResolvedVertexShader) then VertexShaderIndex := sivUnresolved;
    if TDataModifyMsg(Msg).Data = Pointer(ResolvedPixelShader) then  PixelShaderIndex  := sivUnresolved;
//    if TDataModifyMsg(Msg).Data = ResolvedTexture     then  texVertexShaderIndex := sivUnresolved;
  end else if Msg.ClassType = TSceneClearMsg then begin
    TotalItems := 0;
  end else if Msg.ClassType = TRemoveFromSceneMsg then with TRemoveFromSceneMsg(Msg) do begin
    for i := TotalItems - 1 downto 0 do if Items[i] = Item then RemoveItem(i);
    for i := 0 to TotalStages-1 do
      if (Item = Stages[i].Camera) and (Item is TCamera) then begin
        Stages[i].TextureIndex := tivUnresolved;
        SetLinkProperty('Stage #' + IntToStr(i) + '\Texture', Stages[i].Camera.GetFullName);
        Stages[i].Camera       := nil;
      end;
  end;
end;

procedure TRenderPass.RequestValidation;
begin
  if Assigned(FManager) and not FManager.IsSceneLoading and Assigned(FManager.Root) then
    SendMessage(TRenderPassModifiedMsg.Create(Self), nil, [mfBroadcast]);
end;

{ TTechnique }

procedure TTechnique.SetState(const Value: TItemFlags);
var Modified: Boolean;
begin
  Modified := (isVisible in State) and not (isVisible in Value) or
              not (isVisible in State) and (isVisible in Value);
  inherited;
  if Modified and not FManager.IsSceneLoading and Assigned(FManager.Root) then
    SendMessage(TRenderPassModifiedMsg.Create(Passes[0]), nil, [mfBroadcast]);
end;

constructor TTechnique.Create(AManager: TItemsManager);
begin
  inherited;
  TotalPasses := 0;
  LOD         := 0;
  Valid       := False;
  Include(FState, isVisible);
end;

procedure TTechnique.AddProperties(const Result: Props.TProperties);
var i: Integer;
begin
  inherited;

  if Assigned(Result) then begin
    Result.Add('Total passes', vtInt, [], IntToStr(TotalPasses),  '');
    Result.Add('LOD',  vtInt,    [], IntToStr(LOD),  '');
  end;  

  for i := 0 to TotalPasses-1 do
    AddItemLink(Result, Format('Pass #%D', [i]), [], 'TRenderPass');
end;

procedure TTechnique.SetProperties(Properties: Props.TProperties);
var ItemProps: Props.TProperties;

  function GetPassIndex(const Name: string): Integer;
  begin
    Result := TotalPasses-1;
    while (Result >= 0) and (ItemProps[Format('Pass #%D', [Result])] <> Name) do Dec(Result);
  end;

var i, Ind: Integer; PropName: string;

begin
  inherited;

//  Include(FState, isVisible);

  if Properties.Valid('Total passes') then TotalPasses := StrToIntDef(Properties['Total passes'], TotalPasses);

  ItemProps := Props.TProperties.Create;
  AddProperties(ItemProps);

  for i := 0 to TotalPasses-1 do if Properties.Valid(Format('Pass #%D', [i])) then begin
    PropName := Format('Pass #%D', [i]);
    Ind := GetPassIndex(Properties[PropName]);
    if (Ind = -1) or (Ind = i) then
      SetLinkProperty(PropName, Properties[PropName])
    else Log('TTechnique.SetProperties: Duplicate pass in technique: "' + Properties[PropName], lkError);
  end;

  FreeAndNil(ItemProps);

  if Properties.Valid('LOD') then LOD := StrToIntDef(Properties['LOD'], 0);
end;

procedure TTechnique.SetTotalPasses(const Value: Integer);
begin
  if Assigned(FManager) and not FManager.IsSceneLoading and Assigned(FManager.Root) then
    SendMessage(TTechniqueModificationBeginMsg.Create(Self), nil, [mfBroadcast]);
  FTotalPasses := Value;
  SetLength(PassesCache, FTotalPasses);
  Assert(Length(PassesCache) = TotalPasses);
  BuildItemLinks;
  if Assigned(FManager) and not FManager.IsSceneLoading and Assigned(FManager.Root) then
    SendMessage(TTechniqueModificationEndMsg.Create(Self), nil, [mfBroadcast]);
end;

function TTechnique.GetPass(Index: Integer): TRenderPass;
var Item: TItem;
begin
  Assert(Index < TotalPasses);
  Assert(Length(PassesCache) = TotalPasses, ClassName+'("' + GetFullName + '")');
  if PassesCache[Index] <> nil then
    Result := PassesCache[Index]
  else begin
    ResolveLink(Format('Pass #%D', [Index]), Item);
    PassesCache[Index] := Item as TRenderPass;
    Result := PassesCache[Index]
  end;
end;

procedure TTechnique.SetPass(Index: Integer; const Value: TRenderPass);
begin
  if not FManager.IsSceneLoading and Assigned(FManager.Root) then
    SendMessage(TTechniqueModificationBeginMsg.Create(Self), nil, [mfBroadcast]);
  SetLinkedObject(Format('Pass #%D', [Index]), Value);
  if not FManager.IsSceneLoading and Assigned(FManager.Root) then
    SendMessage(TTechniqueModificationEndMsg.Create(Self), nil, [mfBroadcast]);
end;

{ TMaterial }

procedure TMaterial.AddProperties(const Result: Props.TProperties);
var i: Integer;
begin
  inherited;

  if Assigned(Result) then Result.Add('Total techniques', vtInt, [], IntToStr(TotalTechniques),  '');

  for i := 0 to TotalTechniques-1 do
    AddItemLink(Result, Format('Technique #%D', [i]), [], 'TTechnique');
end;

procedure TMaterial.SetProperties(Properties: Props.TProperties);
var i: Integer;
begin
  inherited;
  if Properties.Valid('Total techniques') then
    TotalTechniques := StrToIntDef(Properties['Total techniques'], TotalTechniques);

  for i := 0 to TotalTechniques-1 do if Properties.Valid(Format('Technique #%D', [i])) then
    SetLinkProperty(Format('Technique #%D', [i]), Properties[Format('Technique #%D', [i])]);
end;

function TMaterial.GetTechniqueByLOD(Lod: Single): TTechnique;
var i: Integer;
begin
  Result := nil;
  i := 0;
  while (i < TotalTechniques) and
        ( not (isVisible in Technique[i].State) or not Technique[i].Valid or (Technique[i].LOD <> Round(Lod)) ) do Inc(i);
  if i < TotalTechniques then Result := Technique[i];
end;

function TMaterial.GetTechnique(Index: Integer): TTechnique;
var Item: TItem;
begin
  ResolveLink(Format('Technique #%D', [Index]), Item);
  Result := Item as TTechnique;
end;

procedure TMaterial.SetTechnique(Index: Integer; const Value: TTechnique);
begin
  SetLinkedObject(Format('Technique #%D', [Index]), Value);
end;

procedure TMaterial.SetTotalTechniques(const Value: Integer);
begin
  FTotalTechniques := Value;
  BuildItemLinks;
end;

function TMaterial.PassBelongs(AItem: TItem): Boolean;

  function BelongsToTechnique(Tech: TTechnique): Boolean;
  var i: Integer;
  begin
    Result := False;
    if not Assigned(Tech) then Exit;
    i := Tech.TotalPasses-1;
    while (i >= 0) and (Tech.Passes[i] <> AItem) do Dec(i);
    Result := i >= 0;
  end;

var i: Integer;
begin
  i := TotalTechniques-1;
  while (i >= 0) and not BelongsToTechnique(Technique[i]) do Dec(i);
  Result := i >= 0;
end;

procedure TMaterial.HandleMessage(const Msg: TMessage);
begin
  inherited;
  if (Msg.ClassType = TRenderReinitMsg) or                                                                     // validate if renderer reinitialized or
    ((Msg.ClassType = TRenderPassModifiedMsg) and PassBelongs(TRenderPassModifiedMsg(Msg).Item))               // modifed one of passes or
//    ((Msg.ClassType = TAddToSceneMsg) and ( (TAddToSceneMsg(Msg).Item = Self) or IsChildOf(TAddToSceneMsg(Msg).Item) ))
    then  // the material just added to scene
    SendMessage(TRequestValidationMsg.Create(Self), nil, [mfCore]);
end;

procedure TMaterial.OnSceneLoaded;
begin
  inherited;
  SendMessage(TRequestValidationMsg.Create(Self), nil, [mfCore]);
end;

end.
