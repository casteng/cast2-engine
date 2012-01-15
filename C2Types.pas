(*
 @Abstract(CAST II Engine types unit)
 (C) 2002-2004 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains basic engine-specific type and constant declarations
*)
{$Include GDefines.inc}
unit C2Types;

interface

uses SysUtils, Basics, BaseStr, BaseTypes, Base3D;

type
  TWordBuffer = array[0..$FFFFFFF] of Word;

  // Sound format
  TSoundFormat = packed record
    Channels, BitsPerSample, SampleRate, BlockAlign: Cardinal;
  end;

  TClearFlags = (ClearFrameBuffer, ClearZBuffer, ClearStencilBuffer);
  TClearFlagsSet = set of TClearFlags;

  // Vertex data types
  TVertexDataType = (// One float value
                     vdtFloat1,
                     // Two float values
                     vdtFloat2,
                     // Three float values
                     vdtFloat3,
                     // Four float values
                     vdtFloat4,
                     // 32-bit color value
                     vdtColor,
                     // Four byte values
                     vdtByte4,
                     // Two 16-bit integer values
                     vdtInt16_2,
                     // Four 16-bit integer values
                     vdtInt16_4,
                     // Three unsinged 10-bit integer values
                     vdtUInt10_3,
                     // Two 16-bit float values
                     vdtFloat16_2,
                     // Four 16-bit float values
                     vdtFloat16_4,
                     // No value
                     vdtNothing = $7FFFFFFF);

  // Vertex declaration type
  TVertexDeclaration = array of TVertexDataType;

  // Primitive types
  TPrimitiveType = (ptPOINTLIST, ptLINELIST, ptLINESTRIP, ptTRIANGLELIST, ptTRIANGLESTRIP, ptTRIANGLEFAN, ptQUADS, ptQUADSTRIP, ptPOLYGON);

  // Polygon filling modes
  TFillMode = Cardinal;
  // Polygon culling modes
  TCullMode = Cardinal;

  // Shader kind
  TShaderKind = (// Vertex shader (vertex program)
                 skVertex,
                 // Pixel shader (fragment program)
                 skPixel);
  TShaderRegisterType = TVector4s;

  { Shader constant data structure
    <b>ShaderKind</b>     - kind of shader (see @Link(TShaderKind) )
    <b>ShaderRegister</b> - index of 4-component vector register to set
    <b>Value</b>          - value of the register }
  TShaderConstant = record
    ShaderKind: TShaderKind;
    ShaderRegister: Integer;
    Value: TShaderRegisterType;
  end;
  // A list of shader constants
  TShaderConstants = array of TShaderConstant;
  // Possible members of @Link(TLockFlags) set
  TLockFlag = (// Indicates that contents of a locked resource can be discarded and allows some optimizations within an API
               lfDiscard,
               // Indicates that a resource is locked for read operation
               lfReadOnly,
               // Indicates that new data will be added to the resource and no older data will be overwritten. Currently applicable to vertex and index buffers.
               lfNoOverwrite);
  // Determines how a resource will be locked. Proper use of these flags may improve performance.
  TLockFlags = set of TLockFlag;

const
    // Vertex format flags
  // The vertices are already transformed (TLVertex)
  vfTRANSFORMED = 1;
  vfNORMALS = 2;
  vfDIFFUSE = 4;
  vfSPECULAR = 8;
  vfPOINTSIZE = 16;
  /// Vertex elements
  vfiXYZ = 0; vfiWEIGHT1 = 1; vfiWEIGHT2 = 2; vfiWEIGHT3 = 3; vfiNORM = 4; vfiPointSize = 5; vfiDIFF = 6; vfiSPEC = 7;
  vfiTEX0 = 8; vfiTEX1 = 9; vfiTEX2 = 10; vfiTEX3 = 11; vfiTEX4 = 12; vfiTEX5 = 13; vfiTEX6 = 14; vfiTEX7 = 15;
  vfiTex: array[0..7] of Integer = (vfiTEX0, vfiTEX1, vfiTEX2, vfiTEX3, vfiTEX4, vfiTEX5, vfiTEX6, vfiTEX7);
  /// Vertex data types enumeration
  VertexDataTypesEnum = 'Float1' + StringDelimiter + 'Float2' + StringDelimiter + 'Float3' + StringDelimiter + 'Float4' + StringDelimiter +
                        'Color' + StringDelimiter + 'Byte4' + StringDelimiter +
                        'Int16_2' + StringDelimiter + 'Int16_4' + StringDelimiter + 'UInt10_3' + StringDelimiter +
                        'Float16_2' + StringDelimiter + 'Float16_4';
  /// Offsets in a map record
  OffsH = 3; OffsB = 5; OffsG = 6; OffsR = 7; OffsNZ = 0; OffsNY = 1; OffsNX = 2;
  /// Specular lighting
  slNONE = 0; slFAST = 1; slACCURATE = 2;
  SpecularEnum = 'Off\&Fast\&Accurate';
  /// Texture filters
  tfNONE = 0; tfPOINT = 1; tfLINEAR = 2; tfANISOTROPIC = 3; tfLASTINDEX = 3;
  TexFiltersEnum = 'None\&Nearest\&Linear\&Anisotropic';
  /// Texture operations
  toDISABLE = 0; toARG1 = 1; toARG2 = 2;
  toMODULATE = 3; toMODULATE2X = 4; toMODULATE4X = 5;
  toADD = 6; toSIGNEDADD = 7; toSIGNEDADD2X = 8;
  toSUB = 9; toSMOOTHADD = 10;
  toBLENDDIFFUSEALPHA = 11; toBLENDTEXTUREALPHA = 12; toBLENDFACTORALPHA = 13;
  toBLENDTEXTUREALPHAPM = 14; toBLENDCURRENTALPHA = 15;
  toPREMODULATE = 16;

  toDOTPRODUCT3 = 17;
  toMULTIPLYADD = 18; toLERP = 19;

  toMODULATEALPHA_ADDCOLOR = 20; toMODULATECOLOR_ADDALPHA = 21;
  toMODULATEINVALPHA_ADDCOLOR = 22; toMODULATEINVCOLOR_ADDALPHA = 23;
  toBUMPENV = 24; toBUMPENVLUM = 25;

  AlphaOpsEnum = 'None\&Arg1\&Arg2\&Arg1 * Arg2\&Arg1 * Arg2 * 2\&Arg1 * Arg2 * 4\&' +
                 'Arg1 + Arg2\&Arg1 + Arg2 - 0.5\&(Arg1 + Arg2 - 0.5)*2\&Arg1 - Arg2\&Arg1 + Arg2(1-Arg1)\&' +
                 'Arg1*Diffuse.a + Arg2*(1-Diffuse.a)\&Arg1*Texture.a + Arg2*(1-Texture.a)\&Arg1*Factor.a + Arg2*(1-Factor.a)\&' +
                 'Arg1 + Arg2*(1-Texture.a)\&Arg1*Current.a + Arg2*(1-Current.a)\&' +
                 'Premodulate\&Arg1 dot Arg2\&Arg1 + Arg2*Arg3\&Arg1*Arg2 + (1-Arg1)*Arg3';
  ColorOpsEnum = AlphaOpsEnum + '\&Arg1.a*Arg2.rgb + Arg1.rgb\&Arg1.rgb*Arg2.rgb + Arg1.a\&' +
                                '(1-Arg1.a)*Arg2.rgb + Arg1.rgb\&(1-Arg1.rgb)*Arg2.rgb + Arg1.a\&' +
                                'BumpEnvMap\&BumpEnvMapLuminance';
    /// Texture arguments
  // select diffuse color (read only)
  taDIFFUSE  = 0;
  // select stage destination register (read/write)
  taCURRENT  = 1;
  // select texture color (read only)
  taTEXTURE  = 2;
  // select specular color (read only)
  taSPECULAR = 3;
  // select temporary register color (read/write)
  taTEMP     = 4;
  // select texture factor (read only)
  taTFactor  = 5;
  // replicate alpha to color components (read modifier)
  taALPHAREPLICATE = 6;                 
  AlphaArgsEnum = 'Diffuse\&Current\&Texture\&Specular\&Temporary\&Tex factor';
  ColorArgsEnum = AlphaArgsEnum + '\&Alpha replicate';
  /// Texture addressing modes
  taWRAP       = 0;
  taMIRROR     = 1;
  taCLAMP      = 2;
  taBORDER     = 3;
  taMIRRORONCE = 4;
  TexAdrsEnum = 'Wrap\&Mirror\&Clamp\&Border\&Mirror once';
  /// Texture coords generation
  tcgNone                        = 0;
  tcgCAMERASPACENORMAL           = 1;
  tcgCAMERASPACEPOSITION         = 2;
  tcgCAMERASPACEREFLECTIONVECTOR = 3;
  TexCoordsGenEnum = 'None\&Camera space normal\&Camera space position\&Camera space reflection';
    /// Renderer states
  // Renderer is ready
  rsOK = 0;
  // Renderer is not ready
  rsNOTREADY = 1;
  // Renderer is in clean state
  rsCLEAN = 2;
  // Renderer device is lost (DirectX only)
  rsLOST = 3;
  // Renderer device is lost and attempting to be restored (DirectX only)
  rsTRYTORESTORE = 4;
  // Renderer not yet (or failed) initialized
  rsNOTINITIALIZED = 5;

  /// Fill modes
  fmPOINT = 0; fmWIRE = 1; fmSOLID = 2; fmDEFAULT = 3; //fmNONE = $FFFFFFFF;
  CameraFillModesEnum = 'Points\&Wireframe\&Solid';
  FillModesEnum       = CameraFillModesEnum + '\&Default';

  /// Shade modes
  smGOURAUD = 0; smFLAT = 1; smPHONG = 2;
  ShadeModesEnum = 'Gouraud\&Flat\&Phong';

  /// Culling modes
  cmNONE = 0; cmCW = 1; cmCCW = 2; cmCAMERADEFAULT = 3; cmCAMERAINVERSE = 4;
  CameraCullModesEnum = 'None\&CW\&CCW';
  CullModesEnum       =  CameraCullModesEnum + '\&Camera default\&Camera inverse';

  /// Blending modes
  bmZERO               =  0;
  bmONE                =  1;
  bmSRCCOLOR           =  2;
  bmINVSRCCOLOR        =  3;
  bmSRCALPHA           =  4;
  bmINVSRCALPHA        =  5;
  bmDESTALPHA          =  6;
  bmINVDESTALPHA       =  7;
  bmDESTCOLOR          =  8;
  bmINVDESTCOLOR       =  9;
  bmSRCALPHASAT        = 10;
  bmBOTHSRCALPHA       = 11;
  bmBOTHINVSRCALPHA    = 12;
  BlendArgumentsEnum = 'Zero\&One\&SrcColor\&InvSrcColor\&SrcAlpha\&InvSrcAlpha\&DestAlpha\&InvDestAlpha\&DestColor\&InvDestColor\&SrcAlphaSat\&BothScrAlpha\&BothInvScrAlpha';

  /// Blending operations
  boADD = 0; boSUBTRACT = 1; boREVSUBTRACT = 2; boMIN = 3; boMAX = 4;
  BlendOpsEnum = 'Src + Dest\&Src - Dest\&Dest - Src\&Min\&Max';

  /// Z-buffer types & consts
  zbtNONE = 0; zbtZ = 1; zbtW = 2;

  /// Test functions
  tfNEVER = 0; tfLESS = 1; tfEQUAL = 2; tfLESSEQUAL = 3;
  tfGREATER = 4; tfNOTEQUAL = 5; tfGREATEREQUAL = 6; tfALWAYS = 7;
  TestFuncsEnum = 'Never\&<\&=\&<=\&>\&#\&>=\&Always';

  /// Fog kinds
  fkDEFAULT = 0; fkNONE = 1; fkVERTEX = 2; fkVERTEXRANGED = 3; fkTABLELINEAR = 4; fkTABLEEXP = 5; fkTABLEEXP2 = 6;
  FogKindsEnum = 'Default\&Off\&Vertex\&Vertex ranged\&Table linear\&Exponent\&Exponent^2';

  /// Format usages
  fuTEXTURE = 0; fuRENDERTARGET = 1; fuDEPTHSTENCIL = 2; fuVOLUMETEXTURE = 3; fuCUBETEXTURE = 4; fuDEPTHTEXTURE = 5;

  /// Texture transformations
  ttNONE = 0; ttCOUNT1 = 1; ttCOUNT2 = 2; ttCOUNT3 = 3; ttCOUNT4 = 4; ttPROJECTED = 256;

  /// TextureWrapping
  twNONE = 0; twUCOORD = 1; twVCOORD = 2; twWCOORD = 4; twW2COORD = 8;

  /// Stencil buffer operations
  soKEEP = 0; soZERO = 1; soREPLACE = 2; soINCSAT = 3; soDECSAT = 4; soINVERT = 5; soINC = 6; soDEC = 7;
  StencilOpsEnum = 'Keep\&Zero\&Replace\&Inc saturated\&Dec saturated\&Invert\&Inc\&Dec';

  /// Sound format elements
  sfeSampleRate = 0; sfeChannels = 1; sfeBits = 2;

var
  {$MESSAGE 'replace with constants'}
  // Array to convert engine-specific pixel formats to API-specific pixel formats
  PFormats: array[0..TotalPixelFormats-1] of Longword;
  CullModes: array[cmNONE..cmCCW] of Longword;                      // Cull modes
  TexFilters: array[tfNONE..tfLASTINDEX+4] of Longword;             // Texture filtering types + min/mip filters table for OpenGL
  TexOperation: array[0..25] of Longword;                           // Texture stage operations
  TexAddressing: array[0..4] of Longword;                           // Texture adressing modes
  TexArgument: array[0..6] of Longword;                             // Texture stage arguments
  CPTypes: array[TPrimitiveType] of Longword;               // Primitive types
  CVFormatsLow: array[0..31] of Longword;                           // Low bytes of vertex format
  TestFuncs: array[0..7] of Longword;
  BlendOps: array[0..4] of Longword;
  TexCoordSources: array[0..3] of Longword;
  ShadeModes: array[smGOURAUD..smPHONG] of Longword;
  FillModes : array[fmPOINT..fmSOLID] of Longword;
  BlendModes: array[bmZERO..bmBOTHINVSRCALPHA] of Longword;
  StencilOps: array[soKEEP..soDEC] of Longword;
  TexTransformFlags: array[ttNONE..ttCOUNT4] of Longword;

// Packs a sound format specified by the sample rate, the number of bits per sample and the number of channels to a single value
function PackSoundFormat(SampleRate, BitsPerSample, Channels: Cardinal): Cardinal;
// Converts a format value to @Link(TSoundFormat) structure
function UnpackSoundFormat(Format: Cardinal): TSoundFormat;
// Returns size of element of a sound in bytes
function GetSoundElementSize(Format: Cardinal): Integer;
// Returns sample rate, number of bits per sample or number of channels of the specified format value
function GetSoundFormatElement(Format, Element: Cardinal): Integer;

implementation

function PackSoundFormat(SampleRate, BitsPerSample, Channels: Cardinal): Cardinal;
begin
  Result := Channels shl 24 + BitsPerSample shl 16 + SampleRate;
end;

function UnpackSoundFormat(Format: Cardinal): TSoundFormat;
begin
  Result.Channels      := (Format shr 24) and $FF;
  Result.BitsPerSample := (Format shr 16) and $FF;
  Result.SampleRate    := Format and $FFFF;
  Result.BlockAlign    := Result.BitsPerSample shr 3*Result.Channels;
end;

function GetSoundElementSize(Format: Cardinal): Integer;
begin
  Result := ((Format shr 16) and $FF) div 8 * ((Format shr 24) and $FF);
end;

function GetSoundFormatElement(Format, Element: Cardinal): Integer;
begin
  case Element of
    sfeSampleRate: Result :=  Format and $FFFF;
    sfeChannels:   Result := (Format shr 24) and $FF;
    sfeBits:       Result := (Format shr 16) and $FF;
    else Result := 0;
  end;
end;

end.
