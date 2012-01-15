(*
 CAST Engine types unit.
 (C) 2002-2004 George "Mirage" Bakhtadze.
 Unit contains basic types and constant declarations
*)
{$Include GDefines.inc}
{$Include CDefines.inc}
unit CTypes;

interface

uses SysUtils, BaseTypes, Basics, BaseStr, Base3D;

const
// Commands
  cmdCASTBase = $FFFF + 100;
  cmdFXBase = $FFFF + 1000;
  cmdInputBase = $FFFF + 4000;
  cmdGUIBase = $FFFF + 5000;
  cmdNetBase = $FFFF + 10000;

// Lighttypes
  ltDirectional = 0; ltOmniNoShadow = 1; ltOmni = 2; ltOmniBlink = 3;
  ltSpotNoShadow = 4; ltSpot = 5; ltSpotBlink = 6; ltSimpleSpot = 7;
// Specular lighting
  slNone = 0; slFast = 1; slQuality = 2;
// Texture filters
  tfNone = 0; tfPoint = 1; tfLinear = 2; tfAnisotropic = 3;
// Texture operations
  toDisable = 0; toARG1 = 1; toARG2 = 2;
  toModulate = 3; toModulate2X = 4; toModulate4X = 5;
  toAdd = 6; toSignedAdd = 7; toSignedAdd2X = 8;
  toSub = 9; toSmoothAdd = 10;
  toBlendDiffuseAlpha = 11; toBlendTextureAlpha = 12; toBlendFactorAlpha = 13;
  toBlendTextureAlphaPM = 14; toBlendCurrentAlphaPM = 15;
  toPremodulate = 16;
  toModulateAlpha_AddColor = 17; toModulateColor_AddAlpha = 18;
  toModulateInvAlpha_AddColor = 19; toModulateInvColor_AddAlpha = 20;
  toBumpEnv = 21; toBumpEnvLum = 22;
  toDotproduct3 = 23;
  toMultiplyAdd = 24; toLERP = 25;
// Texture arguments
  taDiffuse = 0;                     // select diffuse color (read only)
  taCurrent = 1;                     // select stage destination register (read/write)
  taTexture = 2;                     // select texture color (read only)
  taSpecular = 3;                    // select specular color (read only)
  taTemp = 4;                        // select temporary register color (read/write)
  taAlphaReplicate = $20;            // replicate alpha to color components (read modifier)
// Texture addressing modes
  taWrap = 0;
  taMirror = 1;
  taClamp = 2;
  taBorder = 3;
  taMirrorOnce = 4;
// Primitive types
  ptPOINTLIST = 0; ptLINELIST = 1; ptLINESTRIP = 2; ptTRIANGLELIST = 3; ptTRIANGLESTRIP = 4; ptTRIANGLEFAN = 5; ptQUADS = 6; ptQUADSTRIP = 7; ptPOLYGON = 8;
// Culling modes
  cmNone = 0; cmCW = 1; cmCCW = 2;
// Renderer states
  rsOK = 0; rsNotReady = 1; rsClean = 2; rsLost = 3; rsTryToRestore = 4; rsNotInitialized = 5;
// Fill modes
  fmDefault = 0; fmPoint = 1; fmWire = 2; fmSolid = 3; fmNone = $FFFFFFFF;
// Blending modes
  bmZERO               =  1;
  bmONE                =  2;
  bmSRCCOLOR           =  3;
  bmINVSRCCOLOR        =  4;
  bmSRCALPHA           =  5;
  bmINVSRCALPHA        =  6;
  bmDESTALPHA          =  7;
  bmINVDESTALPHA       =  8;
  bmDESTCOLOR          =  9;
  bmINVDESTCOLOR       = 10;
  bmSRCALPHASAT        = 11;
  bmBOTHSRCALPHA       = 12;
  bmBOTHINVSRCALPHA    = 13;
// Blending operations
  boADD = 0; boSUBTRACT = 1; boREVSUBTRACT = 2; boMIN = 3; boMAX = 4;

// Vertex formats
  vfTransformed = 1; vfNormals = 2; vfDiffuse = 4; vfSpecular = 8;
// Vertex elements
  vfiNorm = 1; vfiDiff = 2; vfiSpec = 3; vfiTex = 4; vfiWeight = 5;

// Offsets in map record
  OffsH = 3; OffsB = 5; OffsG = 6; OffsR = 7; OffsNZ = 0; OffsNY = 1; OffsNX = 2;

// Z-buffer types & consts
  zbtNone = 0; zbtZ = 1; zbtW = 2;
  tfNEVER = 0; tfLESS = 1; tfEQUAL = 2; tfLESSEQUAL = 3;
  tfGREATER = 4; tfNOTEQUAL = 5; tfGREATEREQUAL = 6; tfALWAYS = 7;

// Fog kinds
  fkNone = 0; fkVertex = 1; fkVertexRanged = 2; fkTable = 3;

// Alignment
  amLeft = 0; amCenter = 1; amRight = 2;
// Format usages
  fuTexture = 0; fuRenderTarget = 1; fuDepthStencil = 2; fuVolumeTexture = 3; fuCubeTexture = 4;
// Sound format elements
  sfeSampleRate = 0; sfeChannels = 1; sfeBits = 2;
// Shading modes
  smFlat = 1; smGouraud = 2; smPhong = 3;
// Lock modes
  lmNone = 0; lmDiscard = 1; lmNoOverwrite = 2;
// Texture transformations
  ttNone = 0; ttCount1 = 1; ttCount2 = 2; ttCount3 = 3; ttCount4 = 4; ttProjected = 256;
// TextureWrapping
  twNone = 0; twUCoord = 1; twVCoord = 2; twWCoord = 4; twW2Coord = 8;

type
  PStr = ^string;

  TUV = packed record U, V, W, H: Single; end;
  TUVArray = array of TUV;
  TUVMap = TUVArray;
  TCharMapItem = Longword;
  TCharMap = array of TCharMapItem;

  TPathPoint = packed record
    X, Y, Z: Single;
    Color: Longword;
    Res: Cardinal;
  end;
  TPathPointArray = array of TPathPoint;
  TPath = TPathPointArray;

  TCColor = packed record
    case Boolean of
      False: (C: Longword);
      True: (R, G, B, A: Byte);
  end;

  TColorB = packed record
    R, G, B, A: Byte;
  end;

  TColorS = packed record
    R, G, B, A: Single;
  end;

  THCNMapCell = packed record
    Height, B, G, R: Byte;
    Res: Byte;
    NZ, NY, NX: Shortint;
  end;

  TIntVector3 = record X, Y, Z: Integer; end;
  TSmIntVector3 = record X, Y, Z: Smallint; end;
{.$DEFINE OPENGL}
{$IFDEF OPENGL}
  TCDTVertex = packed record
    V, U: Single;
    DColor: Longword;
    X, Y, Z: Single;
  end;
{$ELSE}
  TCDTVertex = packed record
    X, Y, Z: Single;
    DColor: Longword;
    U, V: Single;
  end;
{$ENDIF}
  TCVertex = record
    X, Y, Z: Single;
  end;
  TCNVertex = record
    X, Y, Z: Single;
    NX, NY, NZ: Single;
  end;
  TCTVertex = record
    X, Y, Z, U, V: Single;
  end;
  TCDVertex = record
    X, Y, Z: Single;
    DColor: Longword;
  end;
  TTCDVertex = record
    X, Y, Z, RHW: Single;
    DColor: Longword;
  end;
  TTCDTVertex = packed record
    X, Y, Z, RHW: Single;
    DColor: Longword;
    U, V: Single;
  end;
  TTCDSTVertex = packed record
    X, Y, Z, RHW: Single;
    DColor, SColor: Longword;
    U, V: Single;
  end;
  TTCTVertex = packed record
    X, Y, Z, RHW: Single;
    U, V: Single;
  end;
  TCNDVertex = record
    X, Y, Z: Single;
    NX, NY, NZ: Single;
    DColor: Longword;
  end;
  TCNDTVertex = record
    X, Y, Z: Single;
    NX, NY, NZ: Single;
    DColor: Longword;
    U, V: Single;
  end;
  TCNTVertex = record
    X, Y, Z: Single;
    NX, NY, NZ: Single;
    U, V: Single;
  end;
  TCBNDTVertex = record
    X, Y, Z: Single;
    W1: Single;
    NX, NY, NZ: Single;
    DColor: Longword;
    U, V: Single;
  end;
  TCBNTVertex = record
    X, Y, Z: Single;
    W1: Single;
    NX, NY, NZ: Single;
    U, V: Single;
  end;
  TCBDTVertex = record
    X, Y, Z: Single;
    W1: Single;
    DColor: Longword;
    U, V: Single;
  end;

  TWordBuffer = array[0..$FFFFFF] of Word;
  TCDTBuffer = array[0..$FFFFFF] of TCDTVertex;
  TCDBufferType = array[0..$FFFFFF] of TCDVertex;
  TCBufferType = array[0..$FFFFFF] of TCVertex;
  TCNBufferType = array[0..$FFFFFF] of TCNVertex;
  TCNDBufferType = array[0..$FFFFFF] of TCNDVertex;
  TCNDTBufferType = array[0..$FFFFFF] of TCNDTVertex;
  TCNTBufferType = array[0..$FFFFFF] of TCNTVertex;
  TTCDTBuffer = array[0..$FFFFFF] of TTCDTVertex;
  TTCDSTBuffer = array[0..$FFFFFF] of TTCDSTVertex;
  TTCTBuffer = array[0..$FFFFFF] of TTCTVertex;
  TTCDBuffer = array[0..$FFFFFF] of TTCDVertex;

  TCamera = record
    X, Y, Z: Single;
    FieldOfView: Single;
    XAngle, YAngle, ZAngle: Single;
  end;

  TViewCamera = packed record
    LookAtX, LookAtY, LookAtZ: Single;
    XAngle, YAngle, ZAngle: Single;
    Range: Single;
  end;

  TIntLight = packed record        // Integer-based light record
    B, G, R, E: Smallint;  // +0
    LightType: Shortint;   // +8
    LightOn: Boolean;      // +9
    Range: Word;           // +10
    RangeSQ: Longword;        // +12
    IntensityMap: Pointer; // +16
    OldLocation: TIntVector3;
    case Word of
      ltOmni: (Location: TIntVector3); // +20
//      ltDirectional: (Direction: TIntVector3); // +20
      ltDirectional: (Direction: TSmIntVector3; R1, R2, R3: Smallint); // +20
  end;

  TLight = record
    LightType    : LongWord;        // Type of light source
    Diffuse      : TColorS;         // Diffuse color of light
    Specular     : TColorS;         // Specular color of light
    Ambient      : TColorS;         // Ambient color of light
    Location     : TVector3s;       // Position in world space
    OldLocation  : TVector3s;       // Previous position in world space
    Direction    : TVector3s;       // Direction in world space
    Range        : Single;          // Cutoff range
    Falloff      : Single;          // Falloff
    Attenuation0 : Single;          // Constant attenuation
    Attenuation1 : Single;          // Linear attenuation
    Attenuation2 : Single;          // Quadratic attenuation
    Theta        : Single;          // Inner angle of spotlight cone
    Phi          : Single;          // Outer angle of spotlight cone
    LightOn      : Boolean;
  end;

  TStage = packed record
    TextureRID, TextureInd: Integer;
    ColorOp, ColorArg1, ColorArg2: Longword;
    AlphaOp, AlphaArg1, AlphaArg2: Longword;
    TAddressing, Destination: Longword;
    MagFilter, MinFilter, MipFilter: Longword;
    UVSource, TTransform, TWrapping: Longword;    // Texture coordinates source, transform and wrapping
    TexMatrix: TMatrix4s;
//    TextureFilename: TFilename;                  // Future feature (resource?)
  end;

  TRenderParameters = record
    ZNear, ZFar, FoV, CurrentAspectRatio, AspectRatio: Single;
    Camera: TCamera;
    ViewMatrix, ProjMatrix, TotalMatrix: TMatrix4s;                     // View+project
    ActualWidth, ActualHeight: Integer;
    Ambient: Word;
    VideoFormat: Cardinal;
  end;

  TFXStatus = (fxsNormal, fxsFading);

  TSoundFormat = packed record
    Channels, BitsPerSample, SampleRate, BlockAlign: Cardinal;
  end;

  TSimpleConfig = class
    Names: array of TShortName;
    Values: array of string;
    TotalOptions: Integer;
    Changed: Boolean;
    function IndexOf(const Name: string): Integer; virtual;
    function Add(const Name, Value: string): Integer; virtual;
    procedure Clear; virtual;
    function GetValue(const Name: string): string; virtual;
    procedure SetValue(const Name, Value: string); virtual;
    function Load(const FileName: string): Boolean; virtual;
    function Save(const FileName: string): Boolean; virtual;
    destructor Free;
  end;

const
  StdUV: TUV = (U: 0; V: 0; W: 1; H: 1);

var
  CPFormats: array[0..27] of Longword;             // Pixel formats
  CCullModes: array[0..2] of Longword;             // Cull modes
  CTFilters: array[0..3] of Longword;              // Texture filtering types
  CTOperation: array[0..25] of Longword;           // Texture stage operations
  CTAddressing: array[0..4] of Longword;           // Texture adressing modes
  CTArgument: array[0..5] of Longword;             // Texture stage arguments
  CPTypes: array[ptPOINTLIST..ptPOLYGON] of Longword;                // Primitive types
  CVFormatsLow: array[0..15] of Longword;          // Low bytes of vertex format
  TestFuncs: array[0..7] of Longword;
  BlendOps: array[0..4] of Longword;
  TexCoordSources: array[0..3] of Longword;
  FillModes: array[fmDefault..fmSolid] of Longword;
  LockModes: array[lmNone..lmNoOverwrite] of Longword;
  BlendModes: array[bmZERO-1..bmBOTHINVSRCALPHA-1] of Longword;
  TTransformFlags: array[ttNone..ttCount4] of Longword; 

function GetCamera(X, Y, Z, XAngle, YAngle, FieldOfView: Single): TCamera;
function GetIntVector3(X, Y, Z: Integer): TIntVector3;
function GetSmIntVector3(X, Y, Z: Smallint): TSmIntVector3;
function Normalize(v: TIntVector3; Length: Word = 1): TIntVector3; overload;
function Normalize(v: TSmIntVector3; Length: Word = 1): TSmIntVector3; overload;

function GetLight(LightType: Integer; LocDir : TVector3s; R, G, B, Range: Single): TLight;
function GetIntLight(LightType: Integer; LocDir : TIntVector3; R, G, B: Smallint; Range: Word): TIntLight;

function GetVertexFormat(Transformed, Normals, Diffuse, Specular: Boolean; Textures: Word; VertexWeights: Word = 0): Longword;
function GetVertexSize(VertexFormat: Cardinal): Cardinal;
function GetVertexElementOffset(VertexFormat, ElementIndex: Cardinal): Cardinal;
function GetStage(ATextureID: Integer; COperation, CArg1, CArg2, TAddressMode, AMagFilter, AMinFilter, AMipFilter, AUVSource: Cardinal): TStage;
function GetStageAlpha(ATextureID: Integer; COperation, CArg1, CArg2, AOperation, AArg1, AArg2, TAddressMode, AMagFilter, AMinFilter, AMipFilter, AUVSource: Cardinal): TStage;

function GetColorS(const R, G, B, A: Single): TColorS;
function ColorDToS(const Color: Longword): TColorS;
function GetColorFromS(const ColorS: TColorS): Longword;
function GetColorB(const R, G, B, A: Byte): TColorB;

function GetSTDUVMap: TUVMap;

function PackSoundFormat(SampleRate, BitsPerSample, Channels: Cardinal): Cardinal;
function UnpackSoundFormat(Format: Cardinal): TSoundFormat;
function GetSoundElementSize(Format: Cardinal): Integer;
function GetSoundFormatElement(Format, Element: Cardinal): Integer;

implementation

function GetIntVector3(X, Y, Z: Integer): TIntVector3;
begin
  Result.X := X; Result.Y := Y; Result.Z := Z;
end;

function GetSmIntVector3(X, Y, Z: Smallint): TSmIntVector3;
begin
  Result.X := X; Result.Y := Y; Result.Z := Z;
end;

function Normalize(v: TIntVector3; Length: Word = 1): TIntVector3; overload;
var VLength: Single;
begin
  VLength := sqrt(sqr(V.X+0.5) + sqr(V.Y+0.5) + sqr(V.Z+0.5));
  if VLength = 0 then begin
    Result.X := 0; Result.Y := 0; Result.Z := 0; Exit;
  end;
  Result.X := Trunc(0.5 + Length * V.X / VLength);
  Result.Y := Trunc(0.5 + Length * V.Y / VLength);
  Result.Z := Trunc(0.5 + Length * V.Z / VLength);
end;

function Normalize(v: TSmIntVector3; Length: Word = 1): TSmIntVector3; overload;
var VLength: Single;
begin
  VLength := sqrt(sqr(V.X) + sqr(V.Y) + sqr(V.Z));
  if VLength = 0 then begin
    Result.X := 0; Result.Y := 0; Result.Z := 0; Exit;
  end;
  Result.X := Trunc(0.5 + Length * V.X / VLength);
  Result.Y := Trunc(0.5 + Length * V.Y / VLength);
  Result.Z := Trunc(0.5 + Length * V.Z / VLength);
end;

function GetCamera(X, Y, Z, XAngle, YAngle, FieldOfView: Single): TCamera;
begin
  Result.X := X; Result.Y := Y; Result.Z := Z;
  Result.XAngle := XAngle; Result.YAngle := YAngle; Result.ZAngle := 0;
  Result.FieldOfView := FieldOfView;
end;

function GetLight(LightType: Integer; LocDir : TVector3s; R, G, B, Range: Single): TLight;
// Only for directional and omni light sources
begin
  Result.LightType := LightType;
  Result.Direction := LocDir;
  Result.Location := LocDir;
  Result.Diffuse := GetColorS(R, G, B, 0);
  Result.Specular := GetColorS(0.5, 0.5, 0.5, 1);
  Result.Ambient := GetColorS(0, 0, 0, 0);

  Result.Range := Range;
  Result.Falloff := 1.0;

  Result.Attenuation0 := 0;
  Result.Attenuation1 := 0;
  if Range <> 0 then Result.Attenuation2 := 1/(Range*Range) else Result.Attenuation2 := 0;

  Result.LightOn := True;
end;

function GetIntLight(LightType: Integer; LocDir : TIntVector3; R, G, B: Smallint; Range: Word): TIntLight;
begin
  Result.LightType := LightType;
  case LightType of
    ltDirectional: begin Result.Direction := GetSmIntVector3(LocDir.X, LocDir.Y, LocDir.Z); Result.R1 := 0; Result.R2 := 0; Result.R3 := 0; end;
    ltOmniNoShadow, ltOmni, ltOmniBlink, ltSpotNoShadow, ltSpot, ltSpotBlink, ltSimpleSpot: Result.Location := LocDir;
  end;
  Result.B := B; Result.G := G; Result.R := R; Result.E := 0;
  Result.Range := Range; Result.RangeSQ := Range * Range;
  Result.LightOn := True;
end;

function GetVertexFormat(Transformed, Normals, Diffuse, Specular: Boolean; Textures: Word; VertexWeights: Word = 0): Longword;
begin
  Result := VertexWeights shl 16 + Textures shl 8 + Byte(Transformed) shl 0 + Byte(Normals) shl 1 + Byte(Diffuse) shl 2 + Byte(Specular) shl 3;
end;

function GetVertexSize(VertexFormat: Cardinal): Cardinal;
begin
  Result := (3 + VertexFormat and 1 + (VertexFormat shr 1) and 1 * 3 + (VertexFormat shr 2) and 1 + (VertexFormat shr 3) and 1 + (VertexFormat shr 8) and 255 * 2 + (VertexFormat shr 16) and 255) shl 2;
end;

function GetVertexElementOffset(VertexFormat, ElementIndex: Cardinal): Cardinal;
var EOffset: array[vfiNorm..vfiWeight] of Cardinal;
begin
  if VertexFormat and vfTransformed = 0 then EOffset[vfiWeight] := 3*4 else EOffset[vfiWeight] := 4*4;
  EOffset[vfiNorm] := EOffset[vfiWeight] + ((VertexFormat shr 16) and 255) * 4;
  EOffset[vfiDiff] := EOffset[vfiNorm] + ((VertexFormat shr vfiNorm) and 1) * 3*4;
  EOffset[vfiSpec] := EOffset[vfiDiff] + ((VertexFormat shr vfiDiff) and 1) * 4;
  EOffset[vfiTex] := EOffset[vfiSpec] + ((VertexFormat shr vfiSpec) and 1) * 4;
  Result := EOffset[ElementIndex];
end;

function GetStage(ATextureID: Integer; COperation, CArg1, CArg2, TAddressMode, AMagFilter, AMinFilter, AMipFilter, AUVSource: Cardinal): TStage;
begin
  Result := GetStageAlpha(ATextureID, COperation, CArg1, CArg2, toDisable, taDiffuse, taTexture, TAddressMode, AMagFilter, AMinFilter, AMipFilter, AUVSource);
end;

function GetStageAlpha(ATextureID: Integer; COperation, CArg1, CArg2, AOperation, AArg1, AArg2, TAddressMode, AMagFilter, AMinFilter, AMipFilter, AUVSource: Cardinal): TStage;
begin
  with Result do begin
    TextureRID := ATextureID;
    TextureInd := -1;
    ColorOp := COperation; ColorArg1 := CArg1; ColorArg2 := CArg2;
    TAddressing := TAddressMode;
    AlphaOp := AOperation; AlphaArg1 := AArg1; AlphaArg2 := AArg2;
    MagFilter := AMagFilter; MinFilter := AMinFilter; MipFilter := AMipFilter;
    UVSource := AUVSource;
    TTransform := 0;
  end;
end;

function GetColorS(const R, G, B, A: Single): TColorS;
begin
  Result.B := B; Result.G := G; Result.R := R; Result.A := A;
end;

function ColorDToS(const Color: Longword): TColorS;
const Norm: Single = 1/255;
begin
  Result.B := (Color and 255)*Norm;
  Result.G := ((Color shr 8) and 255)*Norm;
  Result.R := ((Color shr 16) and 255)*Norm;
  Result.A := (Color shr 24)*Norm;
end;

function GetColorFromS(const ColorS: TColorS): Longword;
begin
  Result := Trunc(ColorS.A*255+0.5) shl 24 + Trunc(ColorS.R*255+0.5) shl 16 + Trunc(ColorS.G*255+0.5) shl 8 + Trunc(ColorS.B*255+0.5);
end;

function GetColorB(const R, G, B, A: Byte): TColorB;
begin
  Result.R := R; Result.G := G; Result.B := B; Result.A := A;
end;

function GetSTDUVMap: TUVMap;
begin
  SetLength(Result, 1);
  Result[0] := StdUV;
end;

function PackSoundFormat(SampleRate, BitsPerSample, Channels: Cardinal): Cardinal;
begin
  Result := Channels shl 24 + BitsPerSample shl 16 + SampleRate;
end;

function UnpackSoundFormat(Format: Cardinal): TSoundFormat;
begin
  Result.Channels := (Format shr 24) and $FF;
  Result.BitsPerSample := (Format shr 16) and $FF;
  Result.SampleRate := Format and $FFFF;
  Result.BlockAlign := Result.BitsPerSample shr 3*Result.Channels;
end;

function GetSoundElementSize(Format: Cardinal): Integer;
begin
  Result := ((Format shr 16) and $FF) shr 3 * ((Format shr 24) and $FF);
end;

function GetSoundFormatElement(Format, Element: Cardinal): Integer;
begin
  case Element of
    sfeSampleRate: Result := Format and $FFFF;
    sfeChannels: Result := (Format shr 24) and $FF;
    sfeBits: Result := (Format shr 16) and $FF;
    else Result := 0;
  end;
end;

{ TSimpleConfig }

function TSimpleConfig.IndexOf(const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to TotalOptions-1 do if UpperCase(Names[i]) = UpperCase(Name) then begin
    Result := i;
    Exit;
  end;
end;

function TSimpleConfig.Add(const Name, Value: string): Integer;
begin
  Result := -1;
  if Name = '' then Exit;
  Result := IndexOf(Name);
  if Result = -1 then begin
    Inc(TotalOptions);
    SetLength(Names, TotalOptions);
    SetLength(Values, TotalOptions);
    Result := TotalOptions-1;
    Names[Result] := Name;
    Values[Result] := Value;
    Changed := True;
  end else SetValue(Name, Value);
end;

procedure TSimpleConfig.Clear;
begin
  TotalOptions := 0;
  SetLength(Names, 0); SetLength(Values, 0);
end;

function TSimpleConfig.GetValue(const Name: string): string;
var i: Integer;
begin
  Result := '';
  i := IndexOf(Name);
  if i <> -1 then Result := Values[i];
end;

procedure TSimpleConfig.SetValue(const Name, Value: string);
var i: Integer;
begin
  i := IndexOf(Name);
  if i = -1 then Exit;
  Values[i] := Value;

  Changed := True;
end;

function TSimpleConfig.Load(const FileName: string): Boolean;
var cf: Text; s: string; SplitPos: Integer;
begin
  Result := False;
  if not FileExists(FileName) then Exit;
  Assign(cf, FileName); Reset(cf);
  while not EOF(cf) do begin
    Readln(cf, s); s := TrimSpaces(s);
    SplitPos := Pos('=', s);
    if (s[1] <> '#') and (SplitPos > 0) then Add(TrimSpaces(Copy(s, 1, SplitPos-1)), TrimSpaces(Copy(s, SplitPos+1, Length(s))));
  end;
  Close(cf);
  Result := True;
end;

function TSimpleConfig.Save(const FileName: string): Boolean;
var cf: Text; i: Integer;
begin
  Result := False;
  try
    Assign(cf, FileName); Rewrite(cf);
    for i := 0 to TotalOptions-1 do Writeln(cf, Names[i] + ' = ' + Values[i]);
  except
    Close(cf);
    Exit;
  end;
  Close(cf);
  Result := True;
end;

destructor TSimpleConfig.Free;
begin
  Clear;
end;

end.
