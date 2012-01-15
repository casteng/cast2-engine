  PFormats[pfUndefined]    := Cardinal(D3DFMT_UNKNOWN);
  PFormats[pfR8G8B8]       := Cardinal(D3DFMT_R8G8B8);
  PFormats[pfA8R8G8B8]     := Cardinal(D3DFMT_A8R8G8B8);
  PFormats[pfX8R8G8B8]     := Cardinal(D3DFMT_X8R8G8B8);
  PFormats[pfR5G6B5]       := Cardinal(D3DFMT_R5G6B5);
  PFormats[pfX1R5G5B5]     := Cardinal(D3DFMT_X1R5G5B5);
  PFormats[pfA1R5G5B5]     := Cardinal(D3DFMT_A1R5G5B5);
  PFormats[pfA4R4G4B4]     := Cardinal(D3DFMT_A4R4G4B4);
  PFormats[pfA8]           := Cardinal(D3DFMT_A8);
  PFormats[pfX4R4G4B4]     := Cardinal(D3DFMT_X4R4G4B4);
  PFormats[pfA8P8]         := Cardinal(D3DFMT_A8P8);
  PFormats[pfP8]           := Cardinal(D3DFMT_P8);
  PFormats[pfL8]           := Cardinal(D3DFMT_L8);
  PFormats[pfA8L8]         := Cardinal(D3DFMT_A8L8);
  PFormats[pfA4L4]         := Cardinal(D3DFMT_A4L4);
  PFormats[pfV8U8]         := Cardinal(D3DFMT_V8U8);
  PFormats[pfL6V5U5]       := Cardinal(D3DFMT_L6V5U5);
  PFormats[pfX8L8V8U8]     := Cardinal(D3DFMT_X8L8V8U8);
  PFormats[pfQ8W8V8U8]     := Cardinal(D3DFMT_Q8W8V8U8);
  PFormats[pfV16U16]       := Cardinal(D3DFMT_V16U16);
  PFormats[pfW11V11U10]    := Cardinal(D3DFMT_W11V11U10);
  PFormats[pfD16_LOCKABLE] := Cardinal(D3DFMT_D16_LOCKABLE);
  PFormats[pfD32]          := Cardinal(D3DFMT_D32);
  PFormats[pfD15S1]        := Cardinal(D3DFMT_D15S1);
  PFormats[pfD24S8]        := Cardinal(D3DFMT_D24S8);
  PFormats[pfD16]          := Cardinal(D3DFMT_D16);
  PFormats[pfD24X8]        := Cardinal(D3DFMT_D24X8);
  PFormats[pfD24X4S4]      := Cardinal(D3DFMT_D24X4S4);
  PFormats[pfB8G8R8]       := Cardinal(D3DFMT_UNKNOWN);
  PFormats[pfR8G8B8A8]     := Cardinal(D3DFMT_UNKNOWN);
  PFormats[pfATIDF16]      := MAKEFOURCC('D','F','1','6');
  PFormats[pfATIDF24]      := MAKEFOURCC('D','F','2','4');

  CullModes[cmNONE] := D3DCULL_NONE; CullModes[cmCW] := D3DCULL_CW; CullModes[cmCCW] := D3DCULL_CCW;

  TexFilters[tfNONE]        := D3DTEXF_NONE;
  TexFilters[tfPOINT]       := D3DTEXF_POINT;
  TexFilters[tfLINEAR]      := D3DTEXF_LINEAR;
  TexFilters[tfANISOTROPIC] := D3DTEXF_ANISOTROPIC;

  TexOperation[toDISABLE]  := D3DTOP_DISABLE;
  TexOperation[toARG1]     := D3DTOP_SELECTARG1; TexOperation[toARG2]       := D3DTOP_SELECTARG2;
  TexOperation[toMODULATE] := D3DTOP_MODULATE;   TexOperation[toMODULATE2X] := D3DTOP_MODULATE2X; TexOperation[toMODULATE4X]  := D3DTOP_MODULATE4X;
  TexOperation[toADD]      := D3DTOP_ADD;        TexOperation[toSIGNEDADD]  := D3DTOP_ADDSIGNED;  TexOperation[toSIGNEDADD2X] := D3DTOP_ADDSIGNED2X;
  TexOperation[toSUB]      := D3DTOP_SUBTRACT;   TexOperation[toSMOOTHADD]  := D3DTOP_ADDSMOOTH;

  TexOperation[toBLENDDIFFUSEALPHA]   := D3DTOP_BLENDDIFFUSEALPHA;
  TexOperation[toBLENDTEXTUREALPHA]   := D3DTOP_BLENDTEXTUREALPHA;
  TexOperation[toBLENDFACTORALPHA]    := D3DTOP_BLENDFACTORALPHA;
  TexOperation[toBLENDTEXTUREALPHAPM] := D3DTOP_BLENDTEXTUREALPHAPM;
  TexOperation[toBLENDCURRENTALPHA]   := D3DTOP_BLENDCURRENTALPHA;

  TexOperation[toPREMODULATE]               := D3DTOP_PREMODULATE;
  TexOperation[toMODULATEALPHA_ADDCOLOR]    := D3DTOP_MODULATEALPHA_ADDCOLOR;
  TexOperation[toMODULATECOLOR_ADDALPHA]    := D3DTOP_MODULATECOLOR_ADDALPHA;
  TexOperation[toMODULATEINVALPHA_ADDCOLOR] := D3DTOP_MODULATEINVALPHA_ADDCOLOR;
  TexOperation[toMODULATEINVCOLOR_ADDALPHA] := D3DTOP_MODULATEINVCOLOR_ADDALPHA;

  TexOperation[toBUMPENV] := D3DTOP_BUMPENVMAP; TexOperation[toBUMPENVLUM] := D3DTOP_BUMPENVMAPLUMINANCE;

  TexOperation[toDOTPRODUCT3] := D3DTOP_DOTPRODUCT3;
  TexOperation[toMULTIPLYADD] := D3DTOP_MULTIPLYADD;
  TexOperation[toLERP] := D3DTOP_LERP;

  TexArgument[taDIFFUSE]  := D3DTA_DIFFUSE;  TexArgument[taCURRENT] := D3DTA_CURRENT;    TexArgument[taTEXTURE] := D3DTA_TEXTURE;
  TexArgument[taSPECULAR] := D3DTA_SPECULAR; TexArgument[taTEMP]    := D3DTA_TEMP;       TexArgument[taTFactor] := D3DTA_TFACTOR;
  TexArgument[taALPHAREPLICATE] := D3DTA_ALPHAREPLICATE;

  TexAddressing[taWRAP]       := Cardinal(D3DTADDRESS_WRAP);
  TexAddressing[taMIRROR]     := Cardinal(D3DTADDRESS_MIRROR);
  TexAddressing[taCLAMP]      := Cardinal(D3DTADDRESS_CLAMP);
  TexAddressing[taBORDER]     := Cardinal(D3DTADDRESS_BORDER);
  TexAddressing[taMIRRORONCE] := Cardinal(D3DTADDRESS_MIRRORONCE);

  CPTypes[ptPOINTLIST]     := Cardinal(D3DPT_POINTLIST);
  CPTypes[ptLINELIST]      := Cardinal(D3DPT_LINELIST);
  CPTypes[ptLINESTRIP]     := Cardinal(D3DPT_LINESTRIP);
  CPTypes[ptTRIANGLELIST]  := Cardinal(D3DPT_TRIANGLELIST);
  CPTypes[ptTRIANGLESTRIP] := Cardinal(D3DPT_TRIANGLESTRIP);
  CPTypes[ptTRIANGLEFAN]   := Cardinal(D3DPT_TRIANGLEFAN);
// The following primitives working properly in OpenGL only
  CPTypes[ptQUADS]     := Cardinal(D3DPT_TRIANGLEFAN);
  CPTypes[ptQUADSTRIP] := Cardinal(D3DPT_TRIANGLEFAN);
  CPTypes[ptPOLYGON]   := Cardinal(D3DPT_TRIANGLEFAN);
                                                                                           //       SDNT
  for i := 0 to 31 do begin
    if i and vfTRANSFORMED > 0 then CVFormatsLow[i] := D3DFVF_XYZRHW else CVFormatsLow[i] := D3DFVF_XYZ;

    if i and vfNORMALS   > 0 then CVFormatsLow[i] := CVFormatsLow[i] or D3DFVF_NORMAL;
    if i and vfDIFFUSE   > 0 then CVFormatsLow[i] := CVFormatsLow[i] or D3DFVF_DIFFUSE;
    if i and vfSPECULAR  > 0 then CVFormatsLow[i] := CVFormatsLow[i] or D3DFVF_SPECULAR;
    if i and vfPOINTSIZE > 0 then CVFormatsLow[i] := CVFormatsLow[i] or D3DFVF_PSIZE;
  end;

  TestFuncs[tfNEVER]        := D3DCMP_NEVER;
  TestFuncs[tfLESS]         := D3DCMP_LESS;
  TestFuncs[tfEQUAL]        := D3DCMP_EQUAL;
  TestFuncs[tfLESSEQUAL]    := D3DCMP_LESSEQUAL;
  TestFuncs[tfGREATER]      := D3DCMP_GREATER;
  TestFuncs[tfNOTEQUAL]     := D3DCMP_NOTEQUAL;
  TestFuncs[tfGREATEREQUAL] := D3DCMP_GREATEREQUAL;
  TestFuncs[tfALWAYS]       := D3DCMP_ALWAYS;

  BlendOps[boADD]         := D3DBLENDOP_ADD;
  BlendOps[boSUBTRACT]    := D3DBLENDOP_SUBTRACT;
  BlendOps[boREVSUBTRACT] := D3DBLENDOP_REVSUBTRACT;
  BlendOps[boMIN]         := D3DBLENDOP_MIN;
  BlendOps[boMAX]         := D3DBLENDOP_MAX;

  TexCoordSources[tcgNone]                        := D3DTSS_TCI_PASSTHRU;
  TexCoordSources[tcgCAMERASPACENORMAL]           := D3DTSS_TCI_CAMERASPACENORMAL;
  TexCoordSources[tcgCAMERASPACEPOSITION]         := D3DTSS_TCI_CAMERASPACEPOSITION;
  TexCoordSources[tcgCAMERASPACEREFLECTIONVECTOR] := D3DTSS_TCI_CAMERASPACEREFLECTIONVECTOR;
// Shade modes
  ShadeModes[smFlat] := D3DSHADE_FLAT; ShadeModes[smGouraud] := D3DSHADE_GOURAUD; ShadeModes[smPhong] := D3DSHADE_Phong;
// Fill modes
  FillModes[fmPoint] := D3DFILL_POINT; FillModes[fmWire] := D3DFILL_WIREFRAME; FillModes[fmSolid] := D3DFILL_SOLID;               
// Blend modes
  BlendModes[bmZERO]            := D3DBLEND_ZERO;
  BlendModes[bmONE]             := D3DBLEND_ONE;
  BlendModes[bmSRCCOLOR]        := D3DBLEND_SRCCOLOR;
  BlendModes[bmINVSRCCOLOR]     := D3DBLEND_INVSRCCOLOR;
  BlendModes[bmSRCALPHA]        := D3DBLEND_SRCALPHA;
  BlendModes[bmINVSRCALPHA]     := D3DBLEND_INVSRCALPHA;
  BlendModes[bmDESTALPHA]       := D3DBLEND_DESTALPHA;
  BlendModes[bmINVDESTALPHA]    := D3DBLEND_INVDESTALPHA;
  BlendModes[bmDESTCOLOR]       := D3DBLEND_DESTCOLOR;
  BlendModes[bmINVDESTCOLOR]    := D3DBLEND_INVDESTCOLOR;
  BlendModes[bmSRCALPHASAT]     := D3DBLEND_SRCALPHASAT;
  BlendModes[bmBOTHSRCALPHA]    := D3DBLEND_BOTHSRCALPHA;
  BlendModes[bmBOTHINVSRCALPHA] := D3DBLEND_BOTHINVSRCALPHA;
// Texture transformations
  TexTransformFlags[ttNone]   := D3DTTFF_DISABLE;
  TexTransformFlags[ttCount1] := D3DTTFF_COUNT1;
  TexTransformFlags[ttCount2] := D3DTTFF_COUNT2;
  TexTransformFlags[ttCount3] := D3DTTFF_COUNT3;
  TexTransformFlags[ttCount4] := D3DTTFF_COUNT4;
// Stencil operations
  StencilOps[soKeep]    := D3DSTENCILOP_KEEP;
  StencilOps[soZero]    := D3DSTENCILOP_ZERO;
  StencilOps[soReplace] := D3DSTENCILOP_REPLACE;
  StencilOps[soIncSat]  := D3DSTENCILOP_INCRSAT;
  StencilOps[soDecSat]  := D3DSTENCILOP_DECRSAT;
  StencilOps[soInvert]  := D3DSTENCILOP_INVERT;
  StencilOps[soInc]     := D3DSTENCILOP_INCR;
  StencilOps[soDec]     := D3DSTENCILOP_DECR;
