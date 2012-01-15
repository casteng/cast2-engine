  TestFuncs[tfNever] := GL_NEVER;
  TestFuncs[tfLess] := GL_LESS;
  TestFuncs[tfEqual] := GL_EQUAL;
  TestFuncs[tfLessEqual] := GL_LEQUAL;
  TestFuncs[tfGreater] := GL_GREATER;
  TestFuncs[tfNotEqual] := GL_NOTEQUAL;
  TestFuncs[tfGreaterEqual] := GL_GEQUAL;
  TestFuncs[tfAlways] := GL_ALWAYS;

  CPTypes[ptPOINTLIST]     := GL_POINTS;
  CPTypes[ptLINELIST]      := GL_LINES;
  CPTypes[ptLINESTRIP]     := GL_LINE_STRIP;
  CPTypes[ptTRIANGLELIST]  := GL_TRIANGLES;
  CPTypes[ptTRIANGLESTRIP] := GL_TRIANGLE_STRIP;
  CPTypes[ptTRIANGLEFAN]   := GL_TRIANGLE_FAN;
// The following primitives working properly in OpenGL only
  CPTypes[ptQUADS]         := GL_QUADS;
  CPTypes[ptQUADSTRIP]     := GL_QUAD_STRIP;
  CPTypes[ptPOLYGON]       := GL_POLYGON;

  FillModes[fmPoint] := GL_POINT; FillModes[fmWire] := GL_LINE; FillModes[fmSolid] := GL_FILL;

  CullModes[cmNone] := GL_FRONT; CullModes[cmCW] := GL_BACK; CullModes[cmCCW] := GL_FRONT;

  TexFilters[tfNONE]        := GL_NEAREST;
  TexFilters[tfPOINT]       := GL_NEAREST;
  TexFilters[tfLINEAR]      := GL_LINEAR;
  TexFilters[tfANISOTROPIC] := GL_LINEAR;
  // Used in OpenGL only
  TexFilters[tfLASTINDEX + tfPOINT]      := GL_NEAREST_MIPMAP_NEAREST;
  TexFilters[tfLASTINDEX + tfLINEAR]     := GL_LINEAR_MIPMAP_NEAREST;
  TexFilters[tfLASTINDEX + 2 + tfPOINT]  := GL_NEAREST_MIPMAP_LINEAR;
  TexFilters[tfLASTINDEX + 2 + tfLINEAR] := GL_LINEAR_MIPMAP_LINEAR;

  TexAddressing[taWRAP]       := Cardinal(GL_REPEAT);
  TexAddressing[taMIRROR]     := Cardinal(GL_MIRRORED_REPEAT);
  TexAddressing[taCLAMP]      := Cardinal(GL_CLAMP_TO_EDGE);
  TexAddressing[taBORDER]     := Cardinal(GL_CLAMP_TO_BORDER);
  TexAddressing[taMIRRORONCE] := Cardinal(GL_MIRROR_CLAMP_TO_EDGE_EXT);

  // Blend modes
  BlendModes[bmZERO]            := GL_ZERO;
  BlendModes[bmONE]             := GL_ONE;
  BlendModes[bmSRCCOLOR]        := GL_SRC_COLOR;
  BlendModes[bmINVSRCCOLOR]     := GL_ONE_MINUS_SRC_COLOR;
  BlendModes[bmSRCALPHA]        := GL_SRC_ALPHA;
  BlendModes[bmINVSRCALPHA]     := GL_ONE_MINUS_SRC_ALPHA;
  BlendModes[bmDESTALPHA]       := GL_DST_ALPHA;
  BlendModes[bmINVDESTALPHA]    := GL_ONE_MINUS_DST_ALPHA;
  BlendModes[bmDESTCOLOR]       := GL_DST_COLOR;
  BlendModes[bmINVDESTCOLOR]    := GL_ONE_MINUS_DST_COLOR;
  BlendModes[bmSRCALPHASAT]     := GL_SRC_ALPHA_SATURATE;
  BlendModes[bmBOTHSRCALPHA]    := GL_SRC_ALPHA;
  BlendModes[bmBOTHINVSRCALPHA] := GL_ONE_MINUS_SRC_ALPHA;

  BlendOps[boADD]         := GL_FUNC_ADD;
  BlendOps[boSUBTRACT]    := GL_FUNC_SUBTRACT;
  BlendOps[boREVSUBTRACT] := GL_FUNC_REVERSE_SUBTRACT;
  BlendOps[boMIN]         := GL_MIN;
  BlendOps[boMAX]         := GL_MAX;

  TexCoordSources[tcgNone]                        := GL_EYE_LINEAR;
  TexCoordSources[tcgCAMERASPACENORMAL]           := GL_NORMAL_MAP;
  TexCoordSources[tcgCAMERASPACEPOSITION]         := GL_EYE_LINEAR;
  TexCoordSources[tcgCAMERASPACEREFLECTIONVECTOR] := GL_REFLECTION_MAP;
// Shade modes
  ShadeModes[smFlat]    := GL_FLAT;
  ShadeModes[smGouraud] := GL_SMOOTH;
  ShadeModes[smPhong]   := GL_SMOOTH;
// Fill modes

// Stencil operations
{  StencilOps[soKeep]    := D3DSTENCILOP_KEEP;
  StencilOps[soZero]    := D3DSTENCILOP_ZERO;
  StencilOps[soReplace] := D3DSTENCILOP_REPLACE;
  StencilOps[soIncSat]  := D3DSTENCILOP_INCRSAT;
  StencilOps[soDecSat]  := D3DSTENCILOP_DECRSAT;
  StencilOps[soInvert]  := D3DSTENCILOP_INVERT;
  StencilOps[soInc]     := D3DSTENCILOP_INCR;
  StencilOps[soDec]     := D3DSTENCILOP_DECR;}

  // OpenGL internal texture format
  PFormats[pfUndefined]    := Cardinal(GL_NONE);
  PFormats[pfR8G8B8]       := Cardinal(3);
  PFormats[pfA8R8G8B8]     := Cardinal(4);
  PFormats[pfX8R8G8B8]     := Cardinal(3);
  PFormats[pfR5G6B5]       := Cardinal(3);
  PFormats[pfX1R5G5B5]     := Cardinal(3);
  PFormats[pfA1R5G5B5]     := Cardinal(4);
  PFormats[pfA4R4G4B4]     := Cardinal(4);
  PFormats[pfA8]           := Cardinal(1);
  PFormats[pfX4R4G4B4]     := Cardinal(3);
  PFormats[pfA8P8]         := Cardinal(2);
  PFormats[pfP8]           := Cardinal(1);
  PFormats[pfL8]           := Cardinal(1);
  PFormats[pfA8L8]         := Cardinal(2);
  PFormats[pfA4L4]         := Cardinal(2);
  PFormats[pfV8U8]         := Cardinal(2);
  PFormats[pfL6V5U5]       := Cardinal(3);
  PFormats[pfX8L8V8U8]     := Cardinal(3);
  PFormats[pfQ8W8V8U8]     := Cardinal(4);
  PFormats[pfV16U16]       := Cardinal(2);
  PFormats[pfW11V11U10]    := Cardinal(3);
  PFormats[pfD16_LOCKABLE] := Cardinal(1);
  PFormats[pfD32]          := Cardinal(1);
  PFormats[pfD15S1]        := Cardinal(2);
  PFormats[pfD24S8]        := Cardinal(2);
  PFormats[pfD16]          := Cardinal(1);
  PFormats[pfD24X8]        := Cardinal(1);
  PFormats[pfD24X4S4]      := Cardinal(2);
  PFormats[pfB8G8R8]       := Cardinal(3);
  PFormats[pfR8G8B8A8]     := Cardinal(4);
  PFormats[pfATIDF16]      := Cardinal(GL_NONE);
  PFormats[pfATIDF24]      := Cardinal(GL_NONE);

  // Pixel data format to provide to OpenGL
  DFFormats[pfUndefined]    := Cardinal(GL_NONE);
  DFFormats[pfR8G8B8]       := Cardinal(GL_RGB);
  DFFormats[pfA8R8G8B8]     := Cardinal(GL_RGBA);
  DFFormats[pfX8R8G8B8]     := Cardinal(GL_RGB);
  DFFormats[pfR5G6B5]       := Cardinal(GL_RGB);
  DFFormats[pfX1R5G5B5]     := Cardinal(GL_RGB);
  DFFormats[pfA1R5G5B5]     := Cardinal(GL_RGB);
  DFFormats[pfA4R4G4B4]     := Cardinal(GL_RGBA);
  DFFormats[pfA8]           := Cardinal(GL_ALPHA);
  DFFormats[pfX4R4G4B4]     := Cardinal(GL_RGB);
  DFFormats[pfA8P8]         := Cardinal(GL_NONE);
  DFFormats[pfP8]           := Cardinal(GL_COLOR_INDEX);
  DFFormats[pfL8]           := Cardinal(GL_LUMINANCE);
  DFFormats[pfA8L8]         := Cardinal(GL_LUMINANCE_ALPHA);
  DFFormats[pfA4L4]         := Cardinal(GL_LUMINANCE_ALPHA);
  DFFormats[pfV8U8]         := Cardinal(GL_LUMINANCE_ALPHA);
  DFFormats[pfL6V5U5]       := Cardinal(GL_RGB);
  DFFormats[pfX8L8V8U8]     := Cardinal(GL_RGB);
  DFFormats[pfQ8W8V8U8]     := Cardinal(GL_RGBA);
  DFFormats[pfV16U16]       := Cardinal(GL_LUMINANCE_ALPHA);
  DFFormats[pfW11V11U10]    := Cardinal(GL_RGB);
  DFFormats[pfD16_LOCKABLE] := Cardinal(GL_DEPTH_COMPONENT);
  DFFormats[pfD32]          := Cardinal(GL_DEPTH_COMPONENT);
  DFFormats[pfD15S1]        := Cardinal(GL_DEPTH_COMPONENT);
  DFFormats[pfD24S8]        := Cardinal(GL_DEPTH_COMPONENT);
  DFFormats[pfD16]          := Cardinal(GL_DEPTH_COMPONENT);
  DFFormats[pfD24X8]        := Cardinal(GL_DEPTH_COMPONENT);
  DFFormats[pfD24X4S4]      := Cardinal(GL_DEPTH_COMPONENT);
  DFFormats[pfB8G8R8]       := Cardinal(GL_BGR);
  DFFormats[pfR8G8B8A8]     := Cardinal(GL_RGBA);
  DFFormats[pfATIDF16]      := Cardinal(GL_NONE);
  DFFormats[pfATIDF24]      := Cardinal(GL_NONE);

  // Pixel data type to provide to OpenGL
  DTFormats[pfUndefined]    := Cardinal(GL_NONE);
  DTFormats[pfR8G8B8]       := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfA8R8G8B8]     := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfX8R8G8B8]     := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfR5G6B5]       := Cardinal(GL_UNSIGNED_SHORT_5_6_5);
  DTFormats[pfX1R5G5B5]     := Cardinal(GL_UNSIGNED_SHORT_5_5_5_1);
  DTFormats[pfA1R5G5B5]     := Cardinal(GL_UNSIGNED_SHORT_5_5_5_1);
  DTFormats[pfA4R4G4B4]     := Cardinal(GL_UNSIGNED_SHORT_4_4_4_4);
  DTFormats[pfA8]           := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfX4R4G4B4]     := Cardinal(GL_UNSIGNED_SHORT_4_4_4_4);
  DTFormats[pfA8P8]         := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfP8]           := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfL8]           := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfA8L8]         := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfA4L4]         := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfV8U8]         := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfL6V5U5]       := Cardinal(GL_UNSIGNED_SHORT_5_6_5);
  DTFormats[pfX8L8V8U8]     := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfQ8W8V8U8]     := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfV16U16]       := Cardinal(GL_UNSIGNED_SHORT);
  DTFormats[pfW11V11U10]    := Cardinal(GL_NONE);
  DTFormats[pfD16_LOCKABLE] := Cardinal(GL_UNSIGNED_SHORT);
  DTFormats[pfD32]          := Cardinal(GL_UNSIGNED_INT);
  DTFormats[pfD15S1]        := Cardinal(GL_UNSIGNED_SHORT);
  DTFormats[pfD24S8]        := Cardinal(GL_UNSIGNED_INT);
  DTFormats[pfD16]          := Cardinal(GL_UNSIGNED_SHORT);
  DTFormats[pfD24X8]        := Cardinal(GL_UNSIGNED_INT);
  DTFormats[pfD24X4S4]      := Cardinal(GL_UNSIGNED_SHORT);
  DTFormats[pfB8G8R8]       := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfR8G8B8A8]     := Cardinal(GL_UNSIGNED_BYTE);
  DTFormats[pfATIDF16]      := Cardinal(GL_NONE);
  DTFormats[pfATIDF24]      := Cardinal(GL_NONE);
