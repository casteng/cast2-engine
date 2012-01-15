  CPFormats[0] := D3DFMT_UNKNOWN;
  CPFormats[1] := D3DFMT_R8G8B8;   CPFormats[2] := D3DFMT_A8R8G8B8;   CPFormats[3] := D3DFMT_X8R8G8B8;
  CPFormats[4] := D3DFMT_R5G6B5;   CPFormats[5] := D3DFMT_X1R5G5B5;   CPFormats[6] := D3DFMT_A1R5G5B5;
  CPFormats[7] := D3DFMT_A4R4G4B4; CPFormats[8] := D3DFMT_A8;         CPFormats[9] := D3DFMT_X4R4G4B4;
  CPFormats[10] := D3DFMT_A8P8;    CPFormats[11] := D3DFMT_P8;        CPFormats[12] := D3DFMT_L8;
  CPFormats[13] := D3DFMT_A8L8;    CPFormats[14] := D3DFMT_A4L4;      CPFormats[15] := D3DFMT_V8U8;
  CPFormats[16] := D3DFMT_L6V5U5;  CPFormats[17] := D3DFMT_X8L8V8U8;  CPFormats[18] := D3DFMT_Q8W8V8U8;
  CPFormats[19] := D3DFMT_V16U16;  CPFormats[20] := D3DFMT_W11V11U10; CPFormats[21] := D3DFMT_D16_LOCKABLE;
  CPFormats[22] := D3DFMT_D32;     CPFormats[23] := D3DFMT_D15S1;     CPFormats[24] := D3DFMT_D24S8;
  CPFormats[25] := D3DFMT_D16;     CPFormats[26] := D3DFMT_D24X8;     CPFormats[27] := D3DFMT_D24X4S4;

  CCullModes[0] := D3DCULL_NONE;   CCullModes[1] := D3DCULL_CW;       CCullModes[2] := D3DCULL_CCW;

  CTFilters[0] := D3DTEXF_NONE;    CTFilters[1] := D3DTEXF_POINT;     CTFilters[2] := D3DTEXF_LINEAR;
  CTFilters[3] := D3DTEXF_ANISOTROPIC;

  CTOperation[0] := D3DTOP_DISABLE;  CTOperation[1] := D3DTOP_SELECTARG1; CTOperation[2] := D3DTOP_SELECTARG2;
  CTOperation[3] := D3DTOP_MODULATE; CTOperation[4] := D3DTOP_MODULATE2X; CTOperation[5] := D3DTOP_MODULATE4X;
  CTOperation[6] := D3DTOP_ADD;      CTOperation[7] := D3DTOP_ADDSIGNED;  CTOperation[8] := D3DTOP_ADDSIGNED2X;
  CTOperation[9] := D3DTOP_SUBTRACT; CTOperation[10] := D3DTOP_ADDSMOOTH;
  CTOperation[11] := D3DTOP_BLENDDIFFUSEALPHA; CTOperation[12] := D3DTOP_BLENDTEXTUREALPHA;
  CTOperation[13] := D3DTOP_BLENDFACTORALPHA;  CTOperation[14] := D3DTOP_BLENDTEXTUREALPHAPM;
  CTOperation[15] := D3DTOP_BLENDCURRENTALPHA;
  CTOperation[16] := D3DTOP_PREMODULATE;       CTOperation[17] := D3DTOP_MODULATEALPHA_ADDCOLOR;
  CTOperation[18] := D3DTOP_MODULATECOLOR_ADDALPHA;
  CTOperation[19] := D3DTOP_MODULATEINVALPHA_ADDCOLOR;
  CTOperation[20] := D3DTOP_MODULATEINVCOLOR_ADDALPHA;
  CTOperation[21] := D3DTOP_BUMPENVMAP;        CTOperation[22] := D3DTOP_BUMPENVMAPLUMINANCE;
  CTOperation[23] := D3DTOP_DOTPRODUCT3;
  CTOperation[24] := D3DTOP_MULTIPLYADD;
  CTOperation[25] := D3DTOP_LERP;

  CTArgument[0] := D3DTA_DIFFUSE;  CTArgument[1] := D3DTA_CURRENT;    CTArgument[2] := D3DTA_TEXTURE;
  CTArgument[3] := D3DTA_SPECULAR; CTArgument[4] := D3DTA_TEMP;       CTArgument[5] := D3DTA_ALPHAREPLICATE;

  CTAddressing[0] := D3DTADDRESS_WRAP;         CTAddressing[1] := D3DTADDRESS_MIRROR;
  CTAddressing[2] := D3DTADDRESS_CLAMP;        CTAddressing[3] := D3DTADDRESS_BORDER;
  CTAddressing[4] := D3DTADDRESS_MIRRORONCE;

  CPTypes[ptPOINTLIST] := D3DPT_POINTLIST; CPTypes[ptLINELIST] := D3DPT_LINELIST; CPTypes[ptLINESTRIP] := D3DPT_LINESTRIP;
  CPTypes[ptTRIANGLELIST] := D3DPT_TRIANGLELIST; CPTypes[ptTRIANGLESTRIP] := D3DPT_TRIANGLESTRIP; CPTypes[ptTRIANGLEFAN] := D3DPT_TRIANGLEFAN;
// The following primitives working properly in OpenGL only   
  CPTypes[ptQUADS] := D3DPT_TRIANGLEFAN; CPTypes[ptQUADSTRIP] := D3DPT_TRIANGLEFAN; CPTypes[ptPOLYGON] := D3DPT_TRIANGLEFAN;
                                                                                           //       SDNT
  CVFormatsLow[0] :=  D3DFVF_XYZ;                                                          //       0000
  CVFormatsLow[1] :=  D3DFVF_XYZRHW;                                                       //       0001
  CVFormatsLow[2] :=  D3DFVF_XYZ or D3DFVF_NORMAL;                                         //       0010
  CVFormatsLow[3] :=  D3DFVF_XYZRHW or D3DFVF_NORMAL;                                      //       0011 Invalid combination
  CVFormatsLow[4] :=  D3DFVF_XYZ or D3DFVF_DIFFUSE;                                        //       0100
  CVFormatsLow[5] :=  D3DFVF_XYZRHW or D3DFVF_DIFFUSE;                                     //       0101
  CVFormatsLow[6] :=  D3DFVF_XYZ or D3DFVF_NORMAL or D3DFVF_DIFFUSE;                       //       0110
  CVFormatsLow[7] :=  D3DFVF_XYZRHW or D3DFVF_NORMAL or D3DFVF_DIFFUSE;                    //       0111 Invalid combination
  CVFormatsLow[8] :=  D3DFVF_XYZ or D3DFVF_SPECULAR;                                       //       1000
  CVFormatsLow[9] :=  D3DFVF_XYZRHW or D3DFVF_SPECULAR;                                    //       1001
  CVFormatsLow[10] := D3DFVF_XYZ or D3DFVF_NORMAL or D3DFVF_SPECULAR;                      //       1010
  CVFormatsLow[11] := D3DFVF_XYZRHW or D3DFVF_NORMAL or D3DFVF_SPECULAR;                   //       1011 Invalid combination
  CVFormatsLow[12] := D3DFVF_XYZ or D3DFVF_DIFFUSE or D3DFVF_SPECULAR;                     //       1100
  CVFormatsLow[13] := D3DFVF_XYZRHW or D3DFVF_DIFFUSE or D3DFVF_SPECULAR;                  //       1101
  CVFormatsLow[14] := D3DFVF_XYZ or D3DFVF_NORMAL or D3DFVF_DIFFUSE or D3DFVF_SPECULAR;    //       1110
  CVFormatsLow[15] := D3DFVF_XYZRHW or D3DFVF_NORMAL or D3DFVF_DIFFUSE or D3DFVF_SPECULAR; //       1111 Invalid combination

  TestFuncs[0] := D3DCMP_NEVER;
  TestFuncs[1] := D3DCMP_LESS;
  TestFuncs[2] := D3DCMP_EQUAL;
  TestFuncs[3] := D3DCMP_LESSEQUAL;
  TestFuncs[4] := D3DCMP_GREATER;
  TestFuncs[5] := D3DCMP_NOTEQUAL;
  TestFuncs[6] := D3DCMP_GREATEREQUAL;
  TestFuncs[7] := D3DCMP_ALWAYS;

  BlendOps[0] := D3DBLENDOP_ADD;
  BlendOps[1] := D3DBLENDOP_SUBTRACT;
  BlendOps[2] := D3DBLENDOP_REVSUBTRACT;
  BlendOps[3] := D3DBLENDOP_MIN;
  BlendOps[4] := D3DBLENDOP_MAX;

  TexCoordSources[0] := D3DTSS_TCI_PASSTHRU;
  TexCoordSources[1] := D3DTSS_TCI_CAMERASPACENORMAL;
  TexCoordSources[2] := D3DTSS_TCI_CAMERASPACEPOSITION;
  TexCoordSources[3] := D3DTSS_TCI_CAMERASPACEREFLECTIONVECTOR;

  FillModes[fmDefault] := 3; FillModes[fmPoint] := 1; FillModes[fmWire] := 2; FillModes[fmSolid] := 3;

  LockModes[lmNone] := 0;
  LockModes[lmDiscard] := D3DLOCK_DISCARD;
  LockModes[lmNoOverwrite] := D3DLOCK_NOOVERWRITE;

  BlendModes[bmZERO-1] := D3DBLEND_ZERO;
  BlendModes[bmONE-1] := D3DBLEND_ONE;
  BlendModes[bmSRCCOLOR-1] := D3DBLEND_SRCCOLOR;
  BlendModes[bmINVSRCCOLOR-1] := D3DBLEND_INVSRCCOLOR;
  BlendModes[bmSRCALPHA-1] := D3DBLEND_SRCALPHA;
  BlendModes[bmINVSRCALPHA-1] := D3DBLEND_INVSRCALPHA;
  BlendModes[bmDESTALPHA-1] := D3DBLEND_DESTALPHA;
  BlendModes[bmINVDESTALPHA-1] := D3DBLEND_INVDESTALPHA;
  BlendModes[bmDESTCOLOR-1] := D3DBLEND_DESTCOLOR;
  BlendModes[bmINVDESTCOLOR-1] := D3DBLEND_INVDESTCOLOR;
  BlendModes[bmSRCALPHASAT-1] := D3DBLEND_SRCALPHASAT;
  BlendModes[bmBOTHSRCALPHA-1] := D3DBLEND_BOTHSRCALPHA;
  BlendModes[bmBOTHINVSRCALPHA-1] := D3DBLEND_BOTHINVSRCALPHA;
// Texture transformations
  TTransformFlags[ttNone]   := D3DTTFF_DISABLE;
  TTransformFlags[ttCount1] := D3DTTFF_COUNT1;
  TTransformFlags[ttCount2] := D3DTTFF_COUNT2;
  TTransformFlags[ttCount3] := D3DTTFF_COUNT3;
  TTransformFlags[ttCount4] := D3DTTFF_COUNT4;

