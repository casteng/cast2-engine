//-----------------------------------------------------------------------------
// File: SkinnedMesh.cpp
//
// Desc: Example code showing how to use animated models with skinning.
//
// Copyright (c) 1999-2001 Microsoft Corporation. All rights reserved.
//-----------------------------------------------------------------------------
(*----------------------------------------------------------------------------*
 *  Direct3D sample from DirectX 8.1 SDK Delphi adaptation by Alexey Barkovoy *
 *  E-Mail: clootie@reactor.ru                                                *
 *                                                                            *
 *  Modified: 05-Oct-2002                                                     *
 *                                                                            *
 *  Latest version can be downloaded from:                                    *
 *     http://clootie.narod.ru/delphi                                         *
 *----------------------------------------------------------------------------*)

unit SkinnedMeshUnit;

interface

{$I DirectX.inc}

uses
  Logger, C2Anim, Base3D,
  Windows, Messages, SysUtils, CommDlg,
  D3DX8, DXFile,
  D3DApp, D3DFont, D3DUtil, DXUtil,
  {$IFDEF DXG_COMPAT} DirectXGraphics {$ELSE} Direct3D8 {$ENDIF}
  ;

// C++Builder compile hack

///////////////////////////////////////////////////////////////////////////////
//
// File: mview.h
//
// Copyright (C) 2000-2001 Microsoft Corporation. All Rights Reserved.
//
//
///////////////////////////////////////////////////////////////////////////////

type
  METHOD = (
    D3DNONINDEXED,
    D3DINDEXED,
    SOFTWARE,

    D3DINDEXEDVS,
    NONE
  );

  PD3DXMatrixArray = ^TD3DXMatrixArray;
  TD3DXMatrixArray = array [0..$FFFF] of TD3DXMatrix;

  SMeshContainer = class
  public
    pMesh:              ID3DXMesh;
    rgMaterials:        array of TD3DMaterial8;
    pTextures:          array of IDirect3DTexture8;
    cpattr:             DWord;
    cMaterials:         DWord;
    iAttrSplit:         DWord;

    pmcNext:            SMeshContainer;

    szName:             String;

    // Skin info
    m_pSkinMesh:        ID3DXSkinMesh;
    m_pAttrTable:       array of TD3DXAttributeRange;
    m_pBoneMatrix:      array of PD3DXMatrix;
    m_pBoneNamesBuf:    ID3DXBuffer;
    m_pBoneOffsetBuf:   ID3DXBuffer;
    m_pBoneOffsetMat:   PD3DXMatrixArray; // It's used as pointer to "ID3DXBuffer.GetByfferPointer" :BAA
    m_rgiAdjacency:     array of DWord;
    // m_numBoneComb:      DWord; // not used anyway :BAA
    m_maxFaceInfl:      DWord;
    m_pBoneCombinationBuf: ID3DXBuffer;

    m_Method:           METHOD;
    m_paletteSize:      DWord;
    m_bUseSW:           Bool;

    constructor Create;
    destructor Destroy; override;
  end;

  // X File formation rotate key
  PSRotateKeyXFile = ^SRotateKeyXFile;
  SRotateKeyXFile = record
    dwTime:     DWord;
    dwFloats:   DWord;
    w, x, y, z: Single;
  end;

  PSScaleKeyXFile = ^SScaleKeyXFile;
  SScaleKeyXFile = record
    dwTime:     DWord;
    dwFloats:   DWord;
    vScale:     TD3DXVector3;
  end;


  PSPositionKeyXFile = ^SPositionKeyXFile;
  SPositionKeyXFile = record
    dwTime:     DWord;
    dwFloats:   DWord;
    vPos:       TD3DXVector3;
  end;

  PSMatrixKeyXFile = ^SMatrixKeyXFile;
  SMatrixKeyXFile = record
    dwTime:     DWord;
    dwFloats:   DWord;
    mat:        TD3DXMatrix;
  end;

  // in memory versions
  PSRotateKey = ^SRotateKey;
  SRotateKey = record
    dwTime:     DWord;
    quatRotate: TD3DXQuaternion;
  end;

  PSPositionKey = ^SPositionKey;
  SPositionKey = record
    dwTime:     DWord;
    vPos:       TD3DXVector3;
  end;

  PSScaleKey = ^SScaleKey;
  SScaleKey = record
    dwTime:     DWord;
    vScale:     TD3DXVector3;
  end;

  PSMatrixKey = ^SMatrixKey;
  SMatrixKey = record
    dwTime:     DWord;
    mat:        TD3DXMatrix;
  end;

  SFrame = class
  public
    pmcMesh:            SMeshContainer;
    matRot:             TD3DXMatrix;
    matTrans:           TD3DXMatrix;
    matRotOrig:         TD3DXMatrix;
    matCombined:        TD3DXMatrix;

    // animation information

    m_pPositionKeys:    array of SPositionKey;
    m_cPositionKeys:    LongWord;
    m_pRotateKeys:      array of SRotateKey;
    m_cRotateKeys:      LongWord;
    m_pScaleKeys:       array of SScaleKey;
    m_cScaleKeys:       LongWord;
    m_pMatrixKeys:      array of SMatrixKey;
    m_cMatrixKeys:      LongWord;

    pframeAnimNext:     SFrame;
    pframeToAnimate:    SFrame;

    pframeSibling:      SFrame;
    pframeFirstChild:   SFrame;

    bAnimationFrame:    BOOL;
    szName:             String;
    procedure AddFrame(pframe: SFrame);
    procedure AddMesh(pmc: SMeshContainer);

  public
    constructor Create;
    destructor Destroy; override;
    procedure SetTime(fGlobalTime: Single);
    function FindFrame(szFrame: String): SFrame;
    procedure ResetMatrix;
  end;


  SDrawElement = class
    pframeRoot: SFrame;

    vCenter: TD3DXVector3;
    fRadius: Single;

    // name of element for selection purposes
    szName: String;

    // animation list
    pframeAnimHead: SFrame;

	// next element in list

        pdeNext: SDrawElement;

    fCurTime: Single;
    fMaxTime: Single;

    constructor Create;
    destructor Destroy; override;

    procedure AddAnimationFrame(pframeAnim: SFrame);

    function FindFrame(szName: String): SFrame;
  end;

function CalculateBoundingSphere(pdeCur: SDrawElement): HResult;

var
  MyMesh:   SMeshContainer;

type
//-----------------------------------------------------------------------------
// Name: class CMyD3DApplication
// Desc: Application class. The base class (CD3DApplication) provides the
//       generic functionality needed in all Direct3D samples. CMyD3DApplication
//       adds functionality specific to this sample program.
//-----------------------------------------------------------------------------
  CMyD3DApplication = class
    m_method:   METHOD;

    m_dwFVF:    DWord;

    m_pmcSelectedMesh:  SMeshContainer;
    m_pframeSelected:   SFrame;
    m_pdeSelected:      SDrawElement;
    m_pdeHead:          SDrawElement;

    m_szPath:           array [0..MAX_PATH-1] of Char;
    m_pBoneMatrices:    array of TD3DXMatrix;
    m_maxBones:         DWord;

    m_dwIndexedVertexShader: array[0..3] of DWord;
    m_mView:            TD3DXMatrixA16;

  public
    function RestoreDeviceObjects: HResult;
    function InvalidateDeviceObjects: HResult;
    function DeleteDeviceObjects: HResult;
    function Render: HResult;

    function FindBones(pframeCur: SFrame; pde: SDrawElement): HResult;
    function LoadMeshHierarchy: HResult;
    function LoadAnimationSet(pxofobjCur: IDirectXFileData; pde: SDrawElement;
      options: DWord; fvf: DWord; pD3DDevice: IDirect3DDevice8;
      pframeParent: SFrame): HResult;
    function LoadAnimation(pxofobjCur: IDirectXFileData; pde: SDrawElement;
      options: DWord; fvf: DWord; pD3DDevice: IDirect3DDevice8;
      pframeParent: SFrame): HResult;
    function LoadFrames(pxofobjCur: IDirectXFileData; pde: SDrawElement;
      options: DWord; fvf: DWord; pD3DDevice: IDirect3DDevice8;
      pframeParent: SFrame): HResult;
    function LoadMesh(pxofobjCur: IDirectXFileData;
      options: DWord; fvf: DWord; pD3DDevice: IDirect3DDevice8;
      pframeParent: SFrame): HResult;
    function DeleteSelectedMesh: HResult;
    function DrawMeshContainer(pmcMesh: SMeshContainer): HResult;
    function UpdateFrames(pframeCur: SFrame; var matCur: TD3DXMatrix): HResult;
    function GenerateMesh(pmcMesh: SMeshContainer): HResult;

    function FrameMove: HResult;
    constructor Create;
  end;

function EqualGUID(const G1,G2: TGUID): Boolean;

var Indent: Integer;
function GetIndent: string;

implementation

uses Math;

function GetIndent: string;
var i: Integer;
begin
  SetLength(Result, Indent*2);
  for i := 1 to Length(Result) do Result[i] := ' ';
end;


const
  IDD_SHADER1                    = 154;
  IDD_SHADER2                    = 155;
  IDD_SHADER3                    = 156;
  IDD_SHADER4                    = 157;

  ID_FILE_OPENMESHHEIRARCHY      = 40008;
  ID_OPTIONS_D3DNONINDEXED       = 40009;
  ID_OPTIONS_D3DINDEXED          = 40010;
  ID_OPTIONS_SOFTWARESKINNING    = 40011;
  ID_OPTIONS_D3DINDEXEDVS        = 40012;

  UINT_MAX      = $FFFFFFFF;

function EqualGUID(const G1,G2: TGUID): Boolean;
begin
  Result := CompareMem(@G1,@G2,SizeOf(TGUID));
end;

///////////////////////////////////////////////////////////////////////////////
//  SMeshContainer  ///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

constructor SMeshContainer.Create;
begin
  m_Method:= NONE;
  m_bUseSW:= False;
end;

destructor SMeshContainer.Destroy;
var
  i: DWord;
begin
  if Assigned(pTextures) then
    for i:= 0 to cMaterials - 1 do pTextures[i]:= nil;

  pmcNext.Free;
end;


///////////////////////////////////////////////////////////////////////////////
//  SFrame  ///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

constructor SFrame.Create;
begin
  D3DXMatrixIdentity(matRot);
  D3DXMatrixIdentity(matRotOrig);
  D3DXMatrixIdentity(matTrans);
end;

destructor SFrame.Destroy;
begin
  pmcMesh.Free;
  pframeFirstChild.Free;
  pframeSibling.Free;

  // do NOT delete pframeAnimNext
  // do NOT delete pframeToAnimate

  inherited;
end;

function SFrame.FindFrame(szFrame: String): SFrame;
begin
  if (szName <> '') and (szName = szFrame) then
  begin
    Result:= Self;
    Exit;
  end;

  if (pframeFirstChild <> nil) then
  begin
    Result:= pframeFirstChild.FindFrame(szFrame);
    if (Result <> nil) then Exit;
  end;

  if (pframeSibling <> nil) then
  begin
    Result:= pframeSibling.FindFrame(szFrame);
    if (Result <> nil) then Exit;
  end;

  Result:= nil;
end;

procedure SFrame.ResetMatrix;
begin
  matRot:= matRotOrig;
  D3DXMatrixIdentity(matTrans);

  if (pframeFirstChild <> nil)  then pframeFirstChild.ResetMatrix;

  if (pframeSibling <> nil)     then pframeSibling.ResetMatrix;
end;
                                                                
procedure SFrame.AddFrame(pframe: SFrame);
begin
  if (pframeFirstChild = nil)
    then pframeFirstChild:= pframe else
  begin
    pframe.pframeSibling:= pframeFirstChild.pframeSibling;
    pframeFirstChild.pframeSibling:= pframe;
  end;
end;

procedure SFrame.AddMesh(pmc: SMeshContainer);
begin
  pmc.pmcNext:= pmcMesh;
  pmcMesh:= pmc;
end;


///////////////////////////////////////////////////////////////////////////////
//  SDrawElement  /////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

constructor SDrawElement.Create;
begin
  vCenter:= D3DXVector3Zero;
  fRadius:= 1.0;
end;

destructor SDrawElement.Destroy;
begin
  pframeRoot.Free;
  pdeNext.Free;

  // do NOT delete pframeAnimHead;

  inherited;
end;

procedure SDrawElement.AddAnimationFrame(pframeAnim: SFrame);
begin
  pframeAnim.pframeAnimNext:= pframeAnimHead;
  pframeAnimHead:= pframeAnim;
end;

function SDrawElement.FindFrame(szName: String): SFrame;
begin
  if (pframeRoot = nil) then Result:= nil
    else Result:= pframeRoot.FindFrame(szName);
end;



///////////////////////////////////////////////////////////////////////////////
//  CMyD3DApplication  ////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

function CMyD3DApplication.FrameMove;
const m_fElapsedTime = 0.50;
var
  pdeCur: SDrawElement;
  pframeCur: SFrame;
begin
  pdeCur:= m_pdeHead;
  while (pdeCur <> nil) do
  begin
    pdeCur.fCurTime:= pdeCur.fCurTime + m_fElapsedTime * 4800;
    if (pdeCur.fCurTime > 1.0e15) then pdeCur.fCurTime:= 0;

    pframeCur:= pdeCur.pframeAnimHead;
    while (pframeCur <> nil) do
    begin
      pframeCur.SetTime(pdeCur.fCurTime);
      pframeCur:= pframeCur.pframeAnimNext;
    end;

    pdeCur:= pdeCur.pdeNext;
  end;

  Result:= S_OK;
end;

//-----------------------------------------------------------------------------
// Name: CMyD3DApplication()
// Desc: Application constructor. Sets attributes for the app.
//-----------------------------------------------------------------------------
constructor CMyD3DApplication.Create;
begin
  m_pmcSelectedMesh     := nil;
  m_pframeSelected      := nil;
  m_pdeHead             := nil;
  m_pdeSelected         := nil;

  m_dwFVF := D3DFVF_XYZ or D3DFVF_DIFFUSE or D3DFVF_NORMAL or D3DFVF_TEX1;

  m_method := D3DINDEXED;

  m_pBoneMatrices:= nil;
  m_maxBones:= 0;

  m_szPath:= #0;
end;

//-----------------------------------------------------------------------------
// Name: Render()
// Desc: Called once per frame, the call is the entry point for 3d
//       rendering. This function sets up render states, clears the
//       viewport, and renders the scene.
//-----------------------------------------------------------------------------
function CMyD3DApplication.Render;
var
  pdeCur: SDrawElement;

  cTriangles: UINT;
  mCur: TD3DXMatrixA16;
begin
  // Set up viewing postion from ArcBall
(*  pdeCur := m_pdeHead;
  while (pdeCur <> nil) do
  begin
    pdeCur.pframeRoot.matRot:=   m_ArcBall.GetRotationMatrix^;
    pdeCur.pframeRoot.matTrans:= m_ArcBall.GetTranslationMatrix^;
    pdeCur:= pdeCur.pdeNext;
  end;

  // Clear the viewport
  m_pd3dDevice.Clear(0, nil, D3DCLEAR_TARGET or D3DCLEAR_ZBUFFER,
    D3DCOLOR_XRGB(89,135,179), 1.0, 0 );

  if (m_pdeHead = nil) then
  begin
    Result:= S_OK;
    Exit;
  end;

  // Begin the scene
  if SUCCEEDED(m_pd3dDevice.BeginScene) then
  begin
    cTriangles := 0;
    D3DXMatrixTranslation(m_mView, 0, 0, -m_pdeSelected.fRadius * 2.8);

    Result:= m_pd3dDevice.SetTransform(D3DTS_VIEW, m_mView);
    if FAILED(Result) then Exit;

    pdeCur:= m_pdeHead;
    while (pdeCur <> nil) do
    begin
      D3DXMatrixIdentity(mCur);

      Result:= UpdateFrames(pdeCur.pframeRoot, mCur);
      if FAILED(Result) then Exit;
      Result:= DrawFrames(pdeCur.pframeRoot, cTriangles);
      if FAILED(Result) then Exit;

      pdeCur:= pdeCur.pdeNext;
    end;

    // Show frame rate
    m_pFont.DrawText( 2,  0, D3DCOLOR_ARGB(255,255,255,0), m_strFrameStats);
    m_pFont.DrawText( 2, 20, D3DCOLOR_ARGB(255,255,255,0), m_strDeviceStats);

    // End the scene.
    m_pd3dDevice.EndScene;
  end;*)

  Result:= S_OK;
end;



//-----------------------------------------------------------------------------
// Name: RestoreDeviceObjects()
// Desc: Initialize scene objects.
//-----------------------------------------------------------------------------
function CMyD3DApplication.RestoreDeviceObjects;
type
 TVectDecl = array [0..6] of DWord;
var
  light: TD3DLight8;
  dwIndexedVertexDecl1,
  dwIndexedVertexDecl2,
  dwIndexedVertexDecl3,
  dwIndexedVertexDecl4: TVectDecl;
  dwIndexedVertexDecl: array [0..3] of ^TVectDecl;

  pCode: ID3DXBuffer;
  bUseSW: DWord;
  i: DWord;

  vLightDir: TD3DXVector4;
begin
(*  m_ArcBall.SetWindow(m_d3dsdBackBuffer.Width, m_d3dsdBackBuffer.Height, 2.0);

  if (m_pdeSelected <> nil) then SetProjectionMatrix;

  m_pd3dDevice.SetRenderState(D3DRS_DITHERENABLE,       iTRUE);
  m_pd3dDevice.SetRenderState(D3DRS_ZENABLE,            iTRUE);
  m_pd3dDevice.SetRenderState(D3DRS_SPECULARENABLE,     iFalse);
  m_pd3dDevice.SetRenderState(D3DRS_NORMALIZENORMALS,   iTRUE);

  m_pd3dDevice.SetRenderState(D3DRS_CULLMODE,           D3DCULL_CW );
  m_pd3dDevice.SetRenderState(D3DRS_LIGHTING,           iTRUE);
  m_pd3dDevice.SetTextureStageState(0, D3DTSS_MAGFILTER, D3DTEXF_LINEAR);
  m_pd3dDevice.SetTextureStageState(0, D3DTSS_MINFILTER, D3DTEXF_LINEAR);

  m_pd3dDevice.SetRenderState(D3DRS_COLORVERTEX,        iFALSE);

  // Create vertex shader for the indexed skinning
  dwIndexedVertexDecl1[0]:=    D3DVSD_STREAM(0);
  dwIndexedVertexDecl1[1]:=    D3DVSD_REG(0, D3DVSDT_FLOAT3); // Position of first mesh
  dwIndexedVertexDecl1[2]:=    D3DVSD_REG(2, D3DVSDT_D3DCOLOR); // Blend indices
//  dwIndexedVertexDecl1[2]:=      D3DVSD_REG( 2, D3DVSDT_UBYTE4); // Blend indices
  dwIndexedVertexDecl1[3]:=    D3DVSD_REG(3, D3DVSDT_FLOAT3); // Normal
  dwIndexedVertexDecl1[4]:=    D3DVSD_REG(4, D3DVSDT_FLOAT2); // Tex coords
  dwIndexedVertexDecl1[5]:=    D3DVSD_END;

  dwIndexedVertexDecl2[0]:=    D3DVSD_STREAM(0);
  dwIndexedVertexDecl2[1]:=    D3DVSD_REG(0, D3DVSDT_FLOAT3); // Position of first mesh
  dwIndexedVertexDecl2[2]:=    D3DVSD_REG(1, D3DVSDT_FLOAT1); // Blend weights
  dwIndexedVertexDecl2[3]:=    D3DVSD_REG(2, D3DVSDT_D3DCOLOR); // Blend indices
//  dwIndexedVertexDecl2[3]:=      D3DVSD_REG(2, D3DVSDT_UBYTE4); // Blend indices
  dwIndexedVertexDecl2[4]:=    D3DVSD_REG(3, D3DVSDT_FLOAT3); // Normal
  dwIndexedVertexDecl2[5]:=    D3DVSD_REG(4, D3DVSDT_FLOAT2); // Tex coords
  dwIndexedVertexDecl2[6]:=    D3DVSD_END;

  dwIndexedVertexDecl3[0]:=    D3DVSD_STREAM(0);
  dwIndexedVertexDecl3[1]:=    D3DVSD_REG(0, D3DVSDT_FLOAT3); // Position of first mesh
  dwIndexedVertexDecl3[2]:=    D3DVSD_REG(1, D3DVSDT_FLOAT2); // Blend weights
  dwIndexedVertexDecl3[3]:=    D3DVSD_REG(2, D3DVSDT_D3DCOLOR); // Blend indices
//  dwIndexedVertexDecl3[3]:=      D3DVSD_REG( 2, D3DVSDT_UBYTE4); // Blend indices
  dwIndexedVertexDecl3[4]:=    D3DVSD_REG(3, D3DVSDT_FLOAT3); // Normal
  dwIndexedVertexDecl3[5]:=    D3DVSD_REG(4, D3DVSDT_FLOAT2); // Tex coords
  dwIndexedVertexDecl3[6]:=    D3DVSD_END;

  dwIndexedVertexDecl4[0]:=    D3DVSD_STREAM(0);
  dwIndexedVertexDecl4[1]:=    D3DVSD_REG(0, D3DVSDT_FLOAT3); // Position of first mesh
  dwIndexedVertexDecl4[2]:=    D3DVSD_REG(1, D3DVSDT_FLOAT3); // Blend weights
  dwIndexedVertexDecl4[3]:=    D3DVSD_REG(2, D3DVSDT_D3DCOLOR); // Blend indices
//  dwIndexedVertexDecl4[3]:=      D3DVSD_REG( 2, D3DVSDT_UBYTE4); // Blend indices
  dwIndexedVertexDecl4[4]:=    D3DVSD_REG(3, D3DVSDT_FLOAT3); // Normal
  dwIndexedVertexDecl4[5]:=    D3DVSD_REG(4, D3DVSDT_FLOAT2); // Tex coords
  dwIndexedVertexDecl4[6]:=    D3DVSD_END;

  // DWORD* dwIndexedVertexDecl[] = {dwIndexedVertexDecl1, dwIndexedVertexDecl2, dwIndexedVertexDecl3, dwIndexedVertexDecl4};
  dwIndexedVertexDecl[0]:= @dwIndexedVertexDecl1;
  dwIndexedVertexDecl[1]:= @dwIndexedVertexDecl2;
  dwIndexedVertexDecl[2]:= @dwIndexedVertexDecl3;
  dwIndexedVertexDecl[3]:= @dwIndexedVertexDecl4;

  bUseSW:= D3DUSAGE_SOFTWAREPROCESSING;
  if (m_d3dCaps.VertexShaderVersion >= D3DVS_VERSION(1, 1)) then
  begin
    bUseSW := 0;
  end;

  for i:= 0 to 3 do
  begin
    // Assemble the vertex shader file
    Result:= D3DXAssembleShaderFromResource(0, MAKEINTRESOURCE(IDD_SHADER1 + i), 0, nil, @pCode, nil);
    if FAILED(Result) then Exit;

    // Create the vertex shader
    {$IFDEF DXG_COMPAT}
    Result:= m_pd3dDevice.CreateVertexShader(dwIndexedVertexDecl[i][0],
                                             pCode.GetBufferPointer,
                                             m_dwIndexedVertexShader[i], bUseSW);
    {$ELSE}
    Result:= m_pd3dDevice.CreateVertexShader(@dwIndexedVertexDecl[i][0],
                                             pCode.GetBufferPointer,
                                             m_dwIndexedVertexShader[i], bUseSW);
    {$ENDIF}
    if FAILED(Result) then Exit;

    pCode:= nil;
  end;


  FillChar(light, SizeOf(light), 0);
  light._Type:= D3DLIGHT_DIRECTIONAL;

  light.Diffuse.r:= 1.0;
  light.Diffuse.g:= 1.0;
  light.Diffuse.b:= 1.0;
  light.Specular.r:= 0;
  light.Specular.g:= 0;
  light.Specular.b:= 0;
  light.Ambient.r:= 0.25;
  light.Ambient.g:= 0.25;
  light.Ambient.b:= 0.25;

  light.Direction:= D3DXVector3(0.0, 0.0, -1.0);

  Result:= m_pd3dDevice.SetLight(0, light);
  if FAILED(Result) then Exit;

  Result:= m_pd3dDevice.LightEnable(0, TRUE);
  if FAILED(Result) then Exit;

  // Set Light for vertex shader
  vLightDir:= D3DXVector4(0.0, 0.0, 1.0, 0.0);
  {$IFDEF DXG_COMPAT}
  m_pd3dDevice.SetVertexShaderConstant(1, @vLightDir, 1);
  {$ELSE}
  m_pd3dDevice.SetVertexShaderConstant(1, vLightDir, 1);
  {$ENDIF}*)

  Result:= S_OK;
end;

//-----------------------------------------------------------------------------
// Name: ReleaseDeviceDependentMeshes()
// Desc:
//-----------------------------------------------------------------------------
procedure ReleaseDeviceDependentMeshes(pframe: SFrame);
var
  pmcCurr: SMeshContainer;
begin
  if (pframe.pmcMesh <> nil) then
  begin
    // for (SMeshContainer* pmcCurr = pframe->pmcMesh; pmcCurr != NULL; pmcCurr = pmcCurr->pmcNext)
    pmcCurr:= pframe.pmcMesh;
    while (pmcCurr <> nil) do
    begin
      if (pmcCurr.m_pSkinMesh <> nil) then
      begin
        pmcCurr.pMesh:= nil;

        pmcCurr.m_Method:= NONE;
      end;
      pmcCurr:= pmcCurr.pmcNext;
    end;
  end;

  if (pframe.pframeFirstChild <> nil) then
      ReleaseDeviceDependentMeshes(pframe.pframeFirstChild);

  if (pframe.pframeSibling <> nil) then
      ReleaseDeviceDependentMeshes(pframe.pframeSibling);
end;


//-----------------------------------------------------------------------------
// Name: InvalidateDeviceObjects()
// Desc: Called when the app is exiting, or the device is being changed,
//       this function deletes any device dependent objects.
//-----------------------------------------------------------------------------
function CMyD3DApplication.InvalidateDeviceObjects;
var
  pdeCurr: SDrawElement;
begin
  // for (SDrawElement* pdeCurr = m_pdeHead; pdeCurr != NULL; pdeCurr = pdeCurr->pdeNext)
  pdeCurr:= m_pdeHead;
  while (pdeCurr <> nil) do
  begin
    ReleaseDeviceDependentMeshes(pdeCurr.pframeRoot);
    pdeCurr:= pdeCurr.pdeNext;
  end;

  Result:= S_OK;
end;




//-----------------------------------------------------------------------------
// Name: DeleteDeviceObjects()
// Desc: Called when the app is exiting, or the device is being changed,
//       this function deletes any device dependent objects.
//-----------------------------------------------------------------------------
function CMyD3DApplication.DeleteDeviceObjects;
begin
  if (m_pdeSelected = m_pdeHead) then m_pdeSelected:= nil;

  m_pdeHead.Free;
  m_pdeHead:= nil;

  Result:=S_OK;
end;


type
  PD3DXBoneCombinationArray = ^TD3DXBoneCombinationArray;
  TD3DXBoneCombinationArray = array [0..$FFFF] of TD3DXBoneCombination;

function CMyD3DApplication.DrawMeshContainer(pmcMesh: SMeshContainer): HResult;
var
  ipattr: UINT;
  pBoneComb: PD3DXBoneCombinationArray;
  numBlend: DWord;
  i: DWord;
  matid: DWord;
  Identity: TD3DXMatrix;
  cBones: DWord;
  iBone: DWord;

  AttribIdPrev: DWord;
  vConst: TD3DXVector4;
  pVB: IDirect3DVertexBuffer8;
  pIB: IDirect3DIndexBuffer8;
  mat: TD3DXMatrixA16;
  ambEmm: TD3DXColor;
begin
(*  if Assigned(pmcMesh.m_pSkinMesh) then
  begin
    if (m_method <> pmcMesh.m_Method) then GenerateMesh(pmcMesh);

          // Use COLOR instead of UBYTE4 since Geforce3 does not support it
      // vConst.w should be 3, but due to about hack, mul by 255 and add epsilon
      vConst:= D3DXVector4(1.0, 0.0, 0.0, 765.01);

      if pmcMesh.m_bUseSW then
        m_pd3dDevice.SetRenderState(D3DRS_SOFTWAREVERTEXPROCESSING, iTRUE);

      pmcMesh.pMesh.GetVertexBuffer(pVB);
      pmcMesh.pMesh.GetIndexBuffer(pIB);
      Result:= m_pd3dDevice.SetStreamSource(0, pVB, D3DXGetFVFVertexSize(pmcMesh.pMesh.GetFVF));
      if FAILED(Result) then Exit;
      Result:= m_pd3dDevice.SetIndices(pIB, 0);
      if FAILED(Result) then Exit;
      pVB:= nil;
      pIB:= nil;

      Result:= m_pd3dDevice.SetVertexShader(m_dwIndexedVertexShader[pmcMesh.m_maxFaceInfl - 1]);
      if FAILED(Result) then Exit;

      pBoneComb:= PD3DXBoneCombinationArray(pmcMesh.m_pBoneCombinationBuf.GetBufferPointer);
      for ipattr:= 0 to pmcMesh.cpattr - 1 do
      begin
        for i:= 0 to pmcMesh.m_paletteSize - 1 do
        begin
          matid := pBoneComb[ipattr].BoneId[i];
          if (matid <> UINT_MAX) then
          begin
            D3DXMatrixMultiply(mat, pmcMesh.m_pBoneOffsetMat[matid], pmcMesh.m_pBoneMatrix[matid]^);
            D3DXMatrixMultiplyTranspose(mat, mat, m_mView);
            {$IFDEF DXG_COMPAT}
            m_pd3dDevice.SetVertexShaderConstant(i*3 + 9, @mat, 3);
            {$ELSE}
            m_pd3dDevice.SetVertexShaderConstant(i*3 + 9, mat, 3);
            {$ENDIF}
          end;
        end;

        // Sum of all ambient and emissive contribution
        D3DXColorModulate(ambEmm, TD3DXColor(pmcMesh.rgMaterials[pBoneComb[ipattr].AttribId].Ambient), D3DXColor(0.25, 0.25, 0.25, 1.0));
        D3DXColorAdd(ambEmm, ambEmm, TD3DXColor(pmcMesh.rgMaterials[pBoneComb[ipattr].AttribId].Emissive));
        {$IFDEF DXG_COMPAT}
        m_pd3dDevice.SetVertexShaderConstant(8, @pmcMesh.rgMaterials[pBoneComb[ipattr].AttribId].Diffuse, 1);
        m_pd3dDevice.SetVertexShaderConstant(7, @ambEmm, 1);
        {$ELSE}
        m_pd3dDevice.SetVertexShaderConstant(8, pmcMesh.rgMaterials[pBoneComb[ipattr].AttribId].Diffuse, 1);
        m_pd3dDevice.SetVertexShaderConstant(7, ambEmm, 1);
        {$ENDIF}
        vConst.y := pmcMesh.rgMaterials[pBoneComb[ipattr].AttribId].Power;
        {$IFDEF DXG_COMPAT}
        m_pd3dDevice.SetVertexShaderConstant(0, @vConst, 1);
        {$ELSE}
        m_pd3dDevice.SetVertexShaderConstant(0, vConst, 1);
        {$ENDIF}

        m_pd3dDevice.SetTexture(0, pmcMesh.pTextures[pBoneComb[ipattr].AttribId]);

        Result:= m_pd3dDevice.DrawIndexedPrimitive(D3DPT_TRIANGLELIST,
                                pBoneComb[ipattr].VertexStart, pBoneComb[ipattr].VertexCount,
                                pBoneComb[ipattr].FaceStart * 3, pBoneComb[ipattr].FaceCount);
        if FAILED(Result) then Exit;
      end;

      if (pmcMesh.m_bUseSW) then
        m_pd3dDevice.SetRenderState(D3DRS_SOFTWAREVERTEXPROCESSING, iFALSE);
    end
    else if (m_method = D3DINDEXED) then
    begin
      if (pmcMesh.m_bUseSW) then
        m_pd3dDevice.SetRenderState(D3DRS_SOFTWAREVERTEXPROCESSING, DWord(TRUE));

      if (pmcMesh.m_maxFaceInfl = 1)
        then m_pd3dDevice.SetRenderState(D3DRS_VERTEXBLEND, D3DVBF_0WEIGHTS)
        else m_pd3dDevice.SetRenderState(D3DRS_VERTEXBLEND, pmcMesh.m_maxFaceInfl - 1);

      if (pmcMesh.m_maxFaceInfl <> 0) then
        m_pd3dDevice.SetRenderState(D3DRS_INDEXEDVERTEXBLENDENABLE, DWord(TRUE));
      pBoneComb:= PD3DXBoneCombinationArray(pmcMesh.m_pBoneCombinationBuf.GetBufferPointer);
      for ipattr:= 0 to pmcMesh.cpattr - 1 do
      begin
        for i:= 0 to pmcMesh.m_paletteSize - 1 do
        begin
          matid:= pBoneComb[ipattr].BoneId[i];
          if (matid <> UINT_MAX) then
          begin
            m_pd3dDevice.SetTransform(D3DTS_WORLDMATRIX(i), pmcMesh.m_pBoneMatrix[matid]^);
            m_pd3dDevice.MultiplyTransform(D3DTS_WORLDMATRIX(i), pmcMesh.m_pBoneOffsetMat^[matid]);
          end;
        end;

        m_pd3dDevice.SetMaterial(pmcMesh.rgMaterials[pBoneComb[ipattr].AttribId]);
        m_pd3dDevice.SetTexture(0, pmcMesh.pTextures[pBoneComb[ipattr].AttribId]);

        Result:= pmcMesh.pMesh.DrawSubset( ipattr );
        if FAILED(Result) then Exit;
      end;
      m_pd3dDevice.SetRenderState(D3DRS_INDEXEDVERTEXBLENDENABLE, DWord(FALSE));
      m_pd3dDevice.SetRenderState(D3DRS_VERTEXBLEND, 0);

      if (pmcMesh.m_bUseSW) then
        m_pd3dDevice.SetRenderState(D3DRS_SOFTWAREVERTEXPROCESSING, DWord(FALSE));
    end
  end
  else // if Assigned(pmcMesh.m_pSkinMesh) -> assigned non-skinned mesh
  begin
    for ipattr:= 0 to pmcMesh.cpattr - 1 do
    begin
      m_pd3dDevice.SetMaterial(pmcMesh.rgMaterials[ipattr]);
      m_pd3dDevice.SetTexture(0, pmcMesh.pTextures[ipattr]);
      Result:= pmcMesh.pMesh.DrawSubset(ipattr);
      if FAILED(Result) then Exit;
    end;
  end;
*)
  Result:= S_OK;
end;

function CMyD3DApplication.UpdateFrames(pframeCur: SFrame; var matCur: TD3DXMatrix): HResult;
var
  pframeChild: SFrame;
begin
  pframeCur.matCombined:= matCur;
  D3DXMatrixMultiply(pframeCur.matCombined, pframeCur.matRot, matCur);
  D3DXMatrixMultiply(pframeCur.matCombined, pframeCur.matCombined, pframeCur.matTrans);
  pframeChild:= pframeCur.pframeFirstChild;
  while (pframeChild <> nil) do
  begin
    Result:= UpdateFrames(pframeChild, pframeCur.matCombined);
    if FAILED(Result) then Exit;

    pframeChild := pframeChild.pframeSibling;
  end;
  Result:= S_OK;
end;

procedure SFrame.SetTime(fGlobalTime: Single);
 function FMod(A, B: Single): Single;
 begin // returns remainder of floating divide
   if (B = 0) then Result:= 0
   //This is 99% correct substitute for the next line
   else Result:= (A/B - Round(A/B-0.499))*B;
// else Result:= B * Frac(A / B); // Floating exception rased in D3D fcomp mode 
 end;
var
  iKey: UINT;
  dwp2: UINT;
  dwp3: UINT;
  i0, i1, i2, i3: Integer;  
  matResult: TD3DXMatrixA16;
  matTemp: TD3DXMatrixA16;
  fTime1: Single;
  fTime2: Single;
  fLerpValue: Single;
  vScale: TD3DXVector3;
  vPos: TD3DXVector3;
  quat: TD3DXQuaternion;
  bAnimate: BOOL;
  fTime: Single;

  qA, qB, qC: TD3DXQuaternion;
begin
  bAnimate := False;

  dwp2:= 0; // new :BAA
  dwp3:= 0; // new :BAA

  if (m_pMatrixKeys <> nil) then
  begin
    fTime:= fmod(fGlobalTime, m_pMatrixKeys[m_cMatrixKeys-1].dwTime);

    for iKey:= 0 to m_cMatrixKeys - 1 do
    begin
      if (m_pMatrixKeys[iKey].dwTime > fTime) then
      begin
        dwp3:= iKey;

        if (iKey > 0) then
        begin
          dwp2:= iKey - 1;
        end
        else  // when iKey == 0, then dwp2 == 0
        begin
          dwp2:= iKey;
        end;

        Break;
      end;
    end;
    fTime1:= m_pMatrixKeys[dwp2].dwTime;
    fTime2:= m_pMatrixKeys[dwp3].dwTime;

    if ((fTime2 - fTime1) = 0)
      then fLerpValue := 0
      else fLerpValue:= (fTime - fTime1) / (fTime2 - fTime1);

    if (fLerpValue > 0.5) then
    begin
      iKey:= dwp3;
    end
    else
    begin
      iKey:= dwp2;
    end;

    pframeToAnimate.matRot:= m_pMatrixKeys[iKey].mat;
  end
  else
  begin
    D3DXMatrixIdentity(matResult);

    if (m_pScaleKeys <> nil) then
    begin
      dwp2:= 0;
      dwp3:= 0;

      fTime:= fmod(fGlobalTime, m_pScaleKeys[m_cScaleKeys-1].dwTime);

      for iKey:= 0 to m_cScaleKeys - 1 do
      begin
        if (m_pScaleKeys[iKey].dwTime > fTime) then
        begin
          dwp3:= iKey;

          if (iKey > 0) then
          begin
            dwp2:= iKey - 1;
          end
          else  // when iKey == 0, then dwp2 == 0
          begin
            dwp2:= iKey;
          end;

          Break;
        end;
      end;
      fTime1:= m_pScaleKeys[dwp2].dwTime;
      fTime2:= m_pScaleKeys[dwp3].dwTime;

      if ((fTime2 - fTime1) = 0)
        then fLerpValue:= 0
        else fLerpValue:= (fTime - fTime1) / (fTime2 - fTime1);

      D3DXVec3Lerp(vScale,
              m_pScaleKeys[dwp2].vScale,
              m_pScaleKeys[dwp3].vScale,
              fLerpValue);

      D3DXMatrixScaling(matTemp, vScale.x, vScale.y, vScale.z);

      D3DXMatrixMultiply(matResult, matResult, matTemp);

      bAnimate:= True;
    end;

    //check rot keys
    if (m_pRotateKeys <> nil) then
    begin
      i1 := 0;
      i2 := 0;

      fTime:= fmod(fGlobalTime, m_pRotateKeys[m_cRotateKeys-1].dwTime);

      for iKey:= 0 to m_cRotateKeys - 1 do
      begin
        if (m_pRotateKeys[iKey].dwTime > fTime) then
        begin
          if (iKey > 0) then i1:= iKey - 1 else i1:= 0;
          i2:= iKey;
          Break;
        end;
      end;
      fTime1:= m_pRotateKeys[i1].dwTime;
      fTime2:= m_pRotateKeys[i2].dwTime;

      if ((fTime2 - fTime1) = 0)
        then fLerpValue:= 0
        else fLerpValue:= (fTime - fTime1) / (fTime2 - fTime1);

{$define USE_SQUAD}
  {$ifdef USE_SQUAD}
      i0 := i1 - 1;
      i3 := i2 + 1;

      if (i0 < 0) then
        i0:= i0 + Integer(m_cRotateKeys);

      if (i3 >= Integer(m_cRotateKeys)) then
        i3:= i3 - Integer(m_cRotateKeys);

      D3DXQuaternionSquadSetup(qA, qB, qC,
          m_pRotateKeys[i0].quatRotate, m_pRotateKeys[i1].quatRotate,
          m_pRotateKeys[i2].quatRotate, m_pRotateKeys[i3].quatRotate);

      D3DXQuaternionSquad(quat, m_pRotateKeys[i1].quatRotate, qA, qB, qC, fLerpValue);
  {$else}
      D3DXQuaternionSlerp(quat, m_pRotateKeys[i1].quatRotate, m_pRotateKeys[i2].quatRotate, fLerpValue); 
  {$endif}

      quat.w := -quat.w;
      D3DXMatrixRotationQuaternion(matTemp, quat);
      D3DXMatrixMultiply(matResult, matResult, matTemp);

      bAnimate:= True;
    end;

    if (m_pPositionKeys <> nil) then
    begin
      dwp2:= 0;
      dwp3:= 0;

      fTime:= fmod(fGlobalTime, m_pPositionKeys[m_cPositionKeys-1].dwTime);

      for iKey:= 0 to m_cPositionKeys - 1 do
      begin
        if (m_pPositionKeys[iKey].dwTime > fTime) then
        begin
          dwp3:= iKey;

          if (iKey > 0) then
          begin
            dwp2:= iKey - 1;
          end
          else  // when iKey == 0, then dwp2 == 0
          begin
            dwp2:= iKey;
          end;

          Break;
        end;
      end;
      fTime1:= m_pPositionKeys[dwp2].dwTime;
      fTime2:= m_pPositionKeys[dwp3].dwTime;

      if ((fTime2 - fTime1) = 0)
        then fLerpValue:= 0
        else fLerpValue:= (fTime - fTime1) / (fTime2 - fTime1);

      D3DXVec3Lerp(vPos,
                   m_pPositionKeys[dwp2].vPos,
                   m_pPositionKeys[dwp3].vPos,
                   fLerpValue);

      D3DXMatrixTranslation(matTemp, vPos.x, vPos.y, vPos.z);

      D3DXMatrixMultiply(matResult, matResult, matTemp);
      bAnimate:= True;
    end
    else
    begin
      D3DXMatrixTranslation(matTemp, pframeToAnimate.matRotOrig._41, pframeToAnimate.matRotOrig._42, pframeToAnimate.matRotOrig._43);

      D3DXMatrixMultiply(matResult, matResult, matTemp);
    end;

    if (bAnimate) then
    begin
      pframeToAnimate.matRot:= matResult;
    end;
  end;
end;

/////========================== mload.cpp ================================/////

function CalculateSum(pframe: SFrame; const pmatCur: TD3DXMatrix;
  var pvCenter: TD3DXVector3; var pcVertices: UINT): HResult;
var
  pbPoints: PByte;
  cVerticesLocal: UINT;
  pbCur: PByte;
  pvCur: PD3DXVector3;
  vTransformedCur: TD3DXVector3;
  iPoint: UINT;
  pmcCur: SMeshContainer;
  pframeCur: SFrame;
  cVertices: UINT;
  matLocal: TD3DXMatrixA16;

  fvfsize: DWord;
begin
  Result:= S_OK;
  pbPoints:= nil;
  cVerticesLocal:= 0;

  D3DXMatrixMultiply(matLocal, pframe.matRot, pmatCur);

  pmcCur:= pframe.pmcMesh;
  try
    while (pmcCur <> nil) do
    begin
      fvfsize:= D3DXGetFVFVertexSize(pmcCur.pMesh.GetFVF);

      cVertices:= pmcCur.pMesh.GetNumVertices;

      Result:= pmcCur.pMesh.LockVertexBuffer(0, pbPoints);
      if FAILED(Result) then Exit;

      // for( iPoint=0, pbCur = pbPoints; iPoint < cVertices; iPoint++, pbCur += fvfsize)
      pbCur:= pbPoints;
      for iPoint:= 0 to cVertices - 1 do
      begin
        pvCur:= PD3DXVector3(pbCur);

        if ((pvCur.x <> 0.0) or (pvCur.y <> 0.0) or (pvCur.z <> 0.0)) then
        begin
          Inc(cVerticesLocal);

          D3DXVec3TransformCoord(vTransformedCur, pvCur^, matLocal);

          pvCenter.x:= pvCenter.x + vTransformedCur.x;
          pvCenter.y:= pvCenter.y + vTransformedCur.y;
          pvCenter.z:= pvCenter.z + vTransformedCur.z;
        end;

        // "for" cycle appendix :BAA
        Inc(pbCur, fvfsize);
      end;

      pmcCur.pMesh.UnlockVertexBuffer;
      pbPoints:= nil;

      pmcCur:= pmcCur.pmcNext;
    end;

    Inc(pcVertices, cVerticesLocal);

    pframeCur:= pframe.pframeFirstChild;
    while (pframeCur <> nil) do
    begin
      Result:= CalculateSum(pframeCur, matLocal, pvCenter, pcVertices);
      if FAILED(Result) then Exit;

      pframeCur:= pframeCur.pframeSibling;
    end;

  finally
    if (pbPoints <> nil) then
    begin
      pmcCur.pMesh.UnlockVertexBuffer;
    end;
  end;
end;

function CalculateRadius(pframe: SFrame; const pmatCur: TD3DXMatrix;
  var pvCenter: TD3DXVector3; var pfRadiusSq: Single): HResult;
var
  pbPoints: PByte;
  pbCur: PByte;
  pvCur: PD3DXVector3;
  vDist: TD3DXVector3;
  iPoint: UINT;
  cVertices: UINT;
  pmcCur: SMeshContainer;
  pframeCur: SFrame;
  fRadiusLocalSq: Single;
  fDistSq: Single;
  matLocal: TD3DXMatrixA16;

  fvfsize: DWord;
begin
  Result:= S_OK;
  pbPoints:= nil;

  D3DXMatrixMultiply(matLocal, pframe.matRot, pmatCur);

  pmcCur:= pframe.pmcMesh;
  try
    fRadiusLocalSq:= pfRadiusSq;
    while (pmcCur <> nil) do
    begin
      fvfsize:= D3DXGetFVFVertexSize(pmcCur.pMesh.GetFVF);

      cVertices:= pmcCur.pMesh.GetNumVertices;

      Result:= pmcCur.pMesh.LockVertexBuffer(0, pbPoints);
      if FAILED(Result) then Exit;

      // for( iPoint=0, pbCur = pbPoints; iPoint < cVertices; iPoint++, pbCur += fvfsize )
      pbCur:= pbPoints;
      for iPoint:=0 to cVertices - 1 do
      begin
        pvCur:= PD3DXVector3(pbCur);

        if ((pvCur.x = 0.0) and (pvCur.y = 0.0) and (pvCur.z = 0.0))
        then Continue;

        D3DXVec3TransformCoord(vDist, pvCur^, matLocal);

        // vDist -= *pvCenter;
        D3DXVec3Subtract(vDist, vDist, pvCenter);

        fDistSq:= D3DXVec3LengthSq(vDist);

        if (fDistSq > fRadiusLocalSq) then fRadiusLocalSq:= fDistSq;

        // "for" cycle appendix :BAA
        Inc(pbCur, fvfsize);
      end;

      pmcCur.pMesh.UnlockVertexBuffer;
      pbPoints:= nil;

      pmcCur:= pmcCur.pmcNext;
    end;

    pfRadiusSq:= fRadiusLocalSq;

    pframeCur:= pframe.pframeFirstChild;
    while (pframeCur <> nil) do
    begin
      Result:= CalculateRadius(pframeCur, matLocal, pvCenter, pfRadiusSq);
      if FAILED(Result) then Exit;

      pframeCur:= pframeCur.pframeSibling;
    end;

  finally
    if (pbPoints <> nil) then pmcCur.pMesh.UnlockVertexBuffer;
  end;
end;

function CalculateBoundingSphere(pdeCur: SDrawElement): HResult;
var
  vCenter: TD3DXVector3;
  cVertices: UINT;
  fRadiusSq: Single;
  matCur: TD3DXMatrixA16;
begin
  vCenter:= D3DXVector3Zero;
  cVertices:= 0;
  fRadiusSq:= 0;

  D3DXMatrixIdentity(matCur);
  Result:= CalculateSum(pdeCur.pframeRoot, matCur, vCenter, cVertices);
  if FAILED(Result) then Exit;

  if (cVertices > 0) then
  begin
    // vCenter /= (float)cVertices;
    D3DXVec3Scale(vCenter, vCenter, 1/cVertices);

    D3DXMatrixIdentity(matCur);
    Result:= CalculateRadius(pdeCur.pframeRoot, matCur, vCenter, fRadiusSq);
    if FAILED(Result) then Exit;
  end;

  pdeCur.fRadius:= sqrt(fRadiusSq);
  pdeCur.vCenter:= vCenter;
end;

// Builds bone name index
function CMyD3DApplication.FindBones(pframeCur: SFrame; pde: SDrawElement): HResult;
type
  APChar = array[0..$FFFF] of PChar;
var
  pmcMesh: SMeshContainer;
  pframeChild: SFrame;

  pBoneName: ^APChar;
  i: DWord;
  pFrame: SFrame;
begin
  pmcMesh:= pframeCur.pmcMesh;
  while (pmcMesh <> nil) do
  begin
    Inc(Indent);
    if (pmcMesh.m_pSkinMesh <> nil) then
    begin
      // char** pBoneName:= static_cast<char**>(pmcMesh.m_pBoneNamesBuf.GetBufferPointer());
      pBoneName:= pmcMesh.m_pBoneNamesBuf.GetBufferPointer;
      for i:= 0 to pmcMesh.m_pSkinMesh.GetNumBones - 1 do
      begin
        pFrame:= pde.FindFrame(pBoneName[i]);
        pmcMesh.m_pBoneMatrix[i]:= @pFrame.matCombined;
        Log(GetIndent + 'A bone "' + pBoneName[i] + '" found');
      end;
    end;
    pmcMesh:= pmcMesh.pmcNext;
  end;

  pframeChild:= pframeCur.pframeFirstChild;
  while (pframeChild <> nil) do
  begin
    Result:= FindBones(pframeChild, pde);
    if FAILED(Result) then Exit;

    pframeChild:= pframeChild.pframeSibling;
  end;

  Dec(Indent);
  Result:= S_OK;
end;

function CMyD3DApplication.LoadMeshHierarchy: HResult;
var
  pszFile: PChar;
  pdeMesh: SDrawElement;
  pxofapi: IDirectXFile;
  pxofenum: IDirectXFileEnumObject;
  pxofobjCur: IDirectXFileData;
  dwOptions: DWord;
  cchFileName: Integer;
begin
  Result:= S_OK;

    // delete the current mesh, now that the load has succeeded
    DeleteSelectedMesh;

    // link into the draw list
    pdeMesh.pdeNext:= m_pdeHead;
    m_pdeHead:= pdeMesh;

//    if Assigned(m_pdeHead.pdeNext) then
//    pdeMesh.pframeRoot.pframeFirstChild.pframeToAnimate := pdeMesh.pframeRoot.pframeFirstChild.pframeSibling.pframeSibling;

    m_pdeSelected:= pdeMesh;
    m_pmcSelectedMesh:= pdeMesh.pframeRoot.pmcMesh;


    m_pframeSelected:= pdeMesh.pframeRoot;

    Result:= CalculateBoundingSphere(pdeMesh);
    if FAILED(Result) then Exit;

    m_pdeSelected.fCurTime:= 0.0;
    m_pdeSelected.fMaxTime:= 200.0;

    D3DXMatrixTranslation(m_pdeSelected.pframeRoot.matRot,
        -pdeMesh.vCenter.x, -pdeMesh.vCenter.y, -pdeMesh.vCenter.z);
    m_pdeSelected.pframeRoot.matRotOrig:= m_pdeSelected.pframeRoot.matRot;

    if FAILED(Result) then pdeMesh.Free;
end;

function CMyD3DApplication.LoadAnimation(
  pxofobjCur: IDirectXFileData; pde: SDrawElement; options, fvf: DWord;
  pD3DDevice: IDirect3DDevice8; pframeParent: SFrame): HResult;
var
  pFileRotateKey: PSRotateKeyXFile;
  pFileScaleKey: PSScaleKeyXFile;
  pFilePosKey: PSPositionKeyXFile;
  pFileMatrixKey: PSMatrixKeyXFile;
  pframeCur: SFrame;
  pxofobjChild: IDirectXFileData;
  pxofChild: IDirectXFileObject;
  pxofobjChildRef: IDirectXFileDataReference;
  dwSize: DWord;
  pData: PByteArray;
  dwKeyType: DWord;
  cKeys: DWord;
  iKey: DWord;
  cchName: DWord;
  szFrameName: String;

{$WRITEABLECONST ON}
const
  _type: PGUID = nil;
{$WRITEABLECONST OFF}
begin
  Result:= S_OK;
  Inc(Indent);
  try
    try
      pframeCur:= SFrame.Create;
    except
      Result:= E_OUTOFMEMORY;
      Exit;
    end;
    pframeCur.bAnimationFrame:= True;

    pframeParent.AddFrame(pframeCur);
    pde.AddAnimationFrame(pframeCur);

    Log(GetIndent + 'An animation found');

    // Enumerate child objects.
    // Child object can be data, data reference or binary.
    // Use QueryInterface() to find what type of object a child is.
    while (SUCCEEDED(pxofobjCur.GetNextObject(pxofChild))) do
    begin
      // Query the child for it's FileDataReference
      Result:= pxofChild.QueryInterface(IID_IDirectXFileDataReference,
          pxofobjChildRef);
      if SUCCEEDED(Result) then
      begin
        Result:= pxofobjChildRef.Resolve(pxofobjChild);
        if SUCCEEDED(Result) then
        begin
          Result:= pxofobjChild.GetType(_type);
          if FAILED(Result) then Exit;

          if EqualGUID(TID_D3DRMFrame, _type^) then
          begin
            if (pframeCur.pframeToAnimate <> nil) then 
            begin
              Result:= E_INVALIDARG;
              Exit;
            end;

            Result:= pxofobjChild.GetName(nil, cchName);
            if FAILED(Result) then Exit;

            if (cchName = 0) then
            begin
              Result:= E_INVALIDARG;
              Exit;
            end;

            // "_alloca": Allocates temporary stack space. - can't be used in Delphi
            // So using usial Delphi "long" strings
            SetLength(szFrameName, cchName - 1);

            Result:= pxofobjChild.GetName(PChar(szFrameName), cchName);
            if FAILED(Result) then Exit;

            Log(GetIndent + '  A reference to frame "' + szFrameName + '" found (current "' + pframeCur.szName + '")');

            pframeCur.pframeToAnimate:= pde.FindFrame(szFrameName);
            if (pframeCur.pframeToAnimate = nil) then
            begin
              Result:= E_INVALIDARG;
              Exit;
            end;

          end;

          pxofobjChild:= nil;
        end;

        pxofobjChildRef:= nil;
      end
      else
      begin

        // Query the child for it's FileData
        Result:= pxofChild.QueryInterface(IID_IDirectXFileData, pxofobjChild);
        if SUCCEEDED(Result) then
        begin
          Result:= pxofobjChild.GetType(_type);
          if FAILED(Result) then Exit;

          if EqualGUID(TID_D3DRMFrame, _type^) then
          begin
            Result:= LoadFrames(pxofobjChild, pde, options, fvf, pD3DDevice, pframeCur);
            if FAILED(Result) then Exit;
          end
          else if EqualGUID(TID_D3DRMAnimationOptions, _type^) then
          begin
                 // This is commented in original code :BAA
            //ParseAnimOptions(pChildData,pParentFrame);
            //i=2;
          end
          else if EqualGUID(TID_D3DRMAnimationKey, _type^) then
          begin
            Result:= pxofobjChild.GetData(nil, dwSize, Pointer(pData));
            if FAILED(Result) then Exit;

            dwKeyType:= PDWord(pData)^;
            // cKeys:= ((DWORD*)pData)[1];
            cKeys:= PDWord(@pData[4])^;

            if (dwKeyType = 0) then
            begin
              if (pframeCur.m_pRotateKeys <> nil) then
              begin
                Result:= E_INVALIDARG;
                Exit;
              end;

              Log(GetIndent + '  A rotate animation key found. Count: ' + IntToStr(cKeys));

              SetLength(pframeCur.m_pRotateKeys, cKeys);
              if (pframeCur.m_pRotateKeys = nil) then
              begin
                Result:= E_OUTOFMEMORY;
                Exit;
              end;

              pframeCur.m_cRotateKeys:= cKeys;
              //NOTE x files are w x y z and QUATERNIONS are x y z w

              pFileRotateKey:= PSRotateKeyXFile((DWord(pData) + (SizeOf(DWord)*2)));
              for iKey:= 0 to cKeys - 1 do
              begin
                pframeCur.m_pRotateKeys[iKey].dwTime:= pFileRotateKey.dwTime;
                pframeCur.m_pRotateKeys[iKey].quatRotate.x:= pFileRotateKey.x;
                pframeCur.m_pRotateKeys[iKey].quatRotate.y:= pFileRotateKey.y;
                pframeCur.m_pRotateKeys[iKey].quatRotate.z:= pFileRotateKey.z;
                pframeCur.m_pRotateKeys[iKey].quatRotate.w:= pFileRotateKey.w;

                Inc(pFileRotateKey);
              end;
            end
            else if (dwKeyType = 1) then
            begin
              if (pframeCur.m_pScaleKeys <> nil) then
              begin
                Result:= E_INVALIDARG;
                Exit;
              end;

              Log(GetIndent + '  A scale animation key found. Count: ' + IntToStr(cKeys));

              SetLength(pframeCur.m_pScaleKeys, cKeys);
              if (pframeCur.m_pScaleKeys = nil) then
              begin
                Result:= E_OUTOFMEMORY;
                Exit;
              end;

              pframeCur.m_cScaleKeys:= cKeys;

              pFileScaleKey:= PSScaleKeyXFile(DWord(pData) + (SizeOf(DWORD)*2));
              for iKey:= 0 to cKeys - 1 do
              begin
                pframeCur.m_pScaleKeys[iKey].dwTime:= pFileScaleKey.dwTime;
                pframeCur.m_pScaleKeys[iKey].vScale:= pFileScaleKey.vScale;

                Inc(pFileScaleKey);
              end;
            end
            else if (dwKeyType = 2) then
            begin
              if (pframeCur.m_pPositionKeys <> nil) then
              begin
                Result:= E_INVALIDARG;
                Exit;
              end;

              Log(GetIndent + '  A position animation key found. Count: ' + IntToStr(cKeys));

              SetLength(pframeCur.m_pPositionKeys, cKeys);
              if (pframeCur.m_pPositionKeys = nil) then
              begin
                Result:= E_OUTOFMEMORY;
                Exit;
              end;

              pframeCur.m_cPositionKeys:= cKeys;

              pFilePosKey:= PSPositionKeyXFile(DWord(pData) + (SizeOf(DWORD)*2));
              for iKey:= 0 to cKeys - 1 do
              begin
                pframeCur.m_pPositionKeys[iKey].dwTime:= pFilePosKey.dwTime;
                pframeCur.m_pPositionKeys[iKey].vPos:= pFilePosKey.vPos;

                Inc(pFilePosKey);
              end;
            end
            else if (dwKeyType = 4) then
            begin
              if (pframeCur.m_pMatrixKeys <> nil) then
              begin
                Result:= E_INVALIDARG;
                Exit;
              end;

              Log(GetIndent + '  A matrix animation key found. Count: ' + IntToStr(cKeys));

              SetLength(pframeCur.m_pMatrixKeys, cKeys);
              if (pframeCur.m_pMatrixKeys = nil) then
              begin
                Result:= E_OUTOFMEMORY;
                Exit;
              end;

              pframeCur.m_cMatrixKeys:= cKeys;

              pFileMatrixKey:= PSMatrixKeyXFile(DWord(pData) + (SizeOf(DWord)*2));
              for iKey:= 0 to cKeys - 1 do
              begin
                pframeCur.m_pMatrixKeys[iKey].dwTime:= pFileMatrixKey.dwTime;
                pframeCur.m_pMatrixKeys[iKey].mat:= pFileMatrixKey.mat;

                Inc(pFileMatrixKey);
              end;
            end
            else
            begin
              Result:= E_INVALIDARG;
              Exit;
            end;
          end;

          pxofobjChild:= nil;
        end;
      end;

      pxofChild:= nil;
    end;

  except
    on EOutOfMemory do Result:= E_OUTOFMEMORY;
   else raise;
  end;

  Dec(Indent);
end;

function CMyD3DApplication.LoadAnimationSet(pxofobjCur: IDirectXFileData;
  pde: SDrawElement; options: DWord; fvf: DWord; pD3DDevice: IDirect3DDevice8;
  pframeParent: SFrame): HResult;
var
  pframeCur: SFrame;
  _type: PGUID;
  pxofobjChild: IDirectXFileData;
  pxofChild: IDirectXFileObject;
  cchName: DWord;
begin
  pframeCur:= SFrame.Create;
  if (pframeCur = nil) then
  begin
    Result:= E_OUTOFMEMORY;
    Exit;
  end;
  pframeCur.bAnimationFrame:= True;

  pframeParent.AddFrame(pframeCur);

  Result:= pxofobjCur.GetName(nil, cchName);
  if FAILED(Result) then Exit;

  if (cchName > 0) then
  begin
    SetLength(pframeCur.szName, cchName - 1);

    Result:= pxofobjCur.GetName(PChar(pframeCur.szName), cchName);
    if FAILED(Result) then Exit;
  end;

  Log(Format('%SAn animation set "%S" found, Parent: %S',
                   [GetIndent, pframeCur.szName, pframeParent.szName]));
  // Enumerate child objects.
  // Child object can be data, data reference or binary.
  // Use QueryInterface() to find what type of object a child is.
  while SUCCEEDED(pxofobjCur.GetNextObject(pxofChild)) do
  begin
    // Query the child for it's FileData
    Result:= pxofChild.QueryInterface(IID_IDirectXFileData, pxofobjChild);
    if SUCCEEDED(Result) then
    begin
      Result:= pxofobjChild.GetType(_type);
      if FAILED(Result) then Exit;

      if EqualGUID(TID_D3DRMAnimation, _type^) then
      begin
        Result:= LoadAnimation(pxofobjChild, pde, options, fvf, pD3DDevice, pframeCur);
        if FAILED(Result) then Exit;
      end;

      pxofobjChild:= nil;
    end;

    pxofChild:= nil;
  end;
end;

function CMyD3DApplication.GenerateMesh(pmcMesh: SMeshContainer): HResult;
var
  pDevice: IDirect3DDevice8;
  // cFaces: DWORD; //BAA: not used anyway
  rgBoneCombinations: PD3DXBoneCombinationArray;
  cInfl: DWORD;
  iInfl: DWORD;
  pMeshTmp: ID3DXMesh;
  flags: DWORD;
  newFVF: DWORD;
  pMesh: ID3DXMesh;
  maxFaceInfl: DWORD;
label
  e_Exit;
begin
  // ASSUMPTION:  pmcMesh->m_rgiAdjacency contains the current adjacency
  // Result:= S_OK; //BAA: not used anyway
  pDevice:= nil;
  // cFaces:= pmcMesh.m_pSkinMesh.GetNumFaces; //BAA: not used anyway

  Result:= pmcMesh.m_pSkinMesh.GetDevice(pDevice);
  if FAILED(Result) then goto e_Exit;

  pmcMesh.pMesh:= nil;
  m_pBoneMatrices   := nil; // == "delete [] m_pBoneMatrices;"

  pmcMesh.pMesh     := nil;
  m_pBoneMatrices   := nil;

  if (m_method = D3DINDEXEDVS) then
  begin
    // Get palette size
    pmcMesh.m_paletteSize := min(28, pmcMesh.m_pSkinMesh.GetNumBones);

    flags := D3DXMESH_SYSTEMMEM;

    Result:= pmcMesh.m_pSkinMesh.ConvertToIndexedBlendedMesh(
      flags, @pmcMesh.m_rgiAdjacency[0], pmcMesh.m_paletteSize, nil,
      pmcMesh.cpattr, pmcMesh.m_pBoneCombinationBuf, nil, nil, pmcMesh.pMesh);
    if FAILED(Result) then goto e_Exit;

    if ((pmcMesh.pMesh.GetFVF and D3DFVF_POSITION_MASK) <> D3DFVF_XYZ) then
    begin
      pmcMesh.m_maxFaceInfl := ((pmcMesh.pMesh.GetFVF and D3DFVF_POSITION_MASK) - D3DFVF_XYZRHW) div 2;
    end else
    begin
      pmcMesh.m_maxFaceInfl := 1;
    end;

    // FVF has to match our declarator. Vertex shaders are not as forgiving as FF pipeline
    newFVF:= (pmcMesh.pMesh.GetFVF and D3DFVF_POSITION_MASK) or D3DFVF_NORMAL or D3DFVF_TEX1 or D3DFVF_LASTBETA_UBYTE4;
    if (newFVF <> pmcMesh.pMesh.GetFVF) then
    begin
      Result:= pmcMesh.pMesh.CloneMeshFVF(pmcMesh.pMesh.GetOptions, newFVF, pDevice, pMesh);
//      Result:= pmcMesh.pMesh.CloneMeshFVF(pmcMesh.pMesh.GetOptions, m_dwFVF, pDevice, pMesh);
      if not FAILED(Result) then
      begin
        pmcMesh.pMesh := pMesh;
        pMesh := nil;
      end;
    end;
  end
  else if (m_method = D3DINDEXED) then
  begin
    flags := D3DXMESHOPT_VERTEXCACHE or 0*D3DXMESHOPT_COMPACT;

    Result:= pmcMesh.m_pSkinMesh.GetMaxFaceInfluences(maxFaceInfl);
    if FAILED(Result) then goto e_Exit;

    // 12 entry palette guarantees that any triangle (4 independent influences per vertex of a tri)
    // can be handled
    maxFaceInfl:= min(maxFaceInfl, 12);

    pmcMesh.m_paletteSize := min(256, pmcMesh.m_pSkinMesh.GetNumBones);
    pmcMesh.m_bUseSW := True;
    flags := flags or D3DXMESH_SYSTEMMEM or D3DXMESH_SOFTWAREPROCESSING;

    Result := pmcMesh.m_pSkinMesh.ConvertToIndexedBlendedMesh(
      flags, @pmcMesh.m_rgiAdjacency[0], pmcMesh.m_paletteSize, nil,
      pmcMesh.cpattr, pmcMesh.m_pBoneCombinationBuf, nil, nil, pmcMesh.pMesh);
    if FAILED(Result) then goto e_Exit;

    // Here we are talking of max vertex influence which we determine from 
    // the FVF of the returned mesh
    if ((pmcMesh.pMesh.GetFVF and D3DFVF_POSITION_MASK) <> D3DFVF_XYZ) then
    begin
      pmcMesh.m_maxFaceInfl := ((pmcMesh.pMesh.GetFVF and D3DFVF_POSITION_MASK) - D3DFVF_XYZRHW) div 2;
    end else
    begin
      pmcMesh.m_maxFaceInfl := 1;
    end;

        // FVF has to match our declarator. Vertex shaders are not as forgiving as FF pipeline
    newFVF:= (pmcMesh.pMesh.GetFVF and D3DFVF_POSITION_MASK) or D3DFVF_NORMAL or D3DFVF_TEX1 or D3DFVF_LASTBETA_UBYTE4;
//    newFVF := D3DFVF_XYZB2 or D3DFVF_NORMAL or D3DFVF_TEX1 or D3DFVF_LASTBETA_UBYTE4;
//    newFVF := D3DFVF_XYZB1 or D3DFVF_NORMAL or D3DFVF_TEX1;
    if (newFVF <> pmcMesh.pMesh.GetFVF) then
    begin
      Result:= pmcMesh.pMesh.CloneMeshFVF(pmcMesh.pMesh.GetOptions, newFVF, pDevice, pMesh);
//      Result:= pmcMesh.pMesh.CloneMeshFVF(pmcMesh.pMesh.GetOptions, m_dwFVF, pDevice, pMesh);
      if not FAILED(Result) then
      begin
        pmcMesh.pMesh := pMesh;
        pMesh := nil;
      end;
    end;
    newFVF := pmcMesh.pMesh.GetFVF;
  end
  else if (m_method = SOFTWARE) then
  begin
    Result := pmcMesh.m_pSkinMesh.GenerateSkinnedMesh
                               (
                                 D3DXMESH_WRITEONLY,         // options
                                 0.0,                        // minimum bone weight allowed
                                 @pmcMesh.m_rgiAdjacency[0], // adjacency of in-mesh
                                 nil,                        // adjacency of out-mesh
                                 nil,                        // face remap array
                                 nil,                        // vertex remap buffer
                                 pmcMesh.pMesh               // out-mesh
                              );
    if FAILED(Result) then goto e_Exit;

    Result := pmcMesh.pMesh.GetAttributeTable(nil, @pmcMesh.cpattr);
    if FAILED(Result) then goto e_Exit;

    pmcMesh.m_pAttrTable:= nil; // == delete[] pmcMesh->m_pAttrTable;
    SetLength(pmcMesh.m_pAttrTable, pmcMesh.cpattr);
    { // in Delphi Exception will be raised if "OutOfmemory condition" occurs
    if (pmcMesh.m_pAttrTable = nil) then
    begin
        hr := E_OUTOFMEMORY;
        goto e_Exit;
    end;
    }

    Result := pmcMesh.pMesh.GetAttributeTable(@pmcMesh.m_pAttrTable[0], nil);
    if FAILED(Result) then goto e_Exit;

    Result := pmcMesh.m_pSkinMesh.GetMaxFaceInfluences(pmcMesh.m_maxFaceInfl);
    if FAILED(Result) then goto e_Exit;

    // Allocate space for blend matrices
    SetLength(m_pBoneMatrices, m_maxBones);
    { // in Delphi Exception will be raised if "OutOfmemory condition" occurs
    if (m_pBoneMatrices = nil) then
    begin
        Result:= E_OUTOFMEMORY;
        goto e_Exit;
    end;
    }
  end;
  pmcMesh.m_Method := m_method;

e_Exit:

  pDevice:= nil;
end;

function CMyD3DApplication.LoadMesh(pxofobjCur: IDirectXFileData;
  options: DWord; fvf: DWord; pD3DDevice: IDirect3DDevice8;
  pframeParent: SFrame): HResult;
type
  PD3DXMaterialArray = ^TD3DXMaterialArray;
  TD3DXMaterialArray = array [0..$FFFF] of TD3DXMaterial;
var
  pmcMesh: SMeshContainer;
  pbufMaterials: ID3DXBuffer;
  pbufAdjacency: ID3DXBuffer;
  cchName: DWord;
  cFaces, cVertices: UINT;
  iMaterial: UINT;
  pAdjacencyIn: PDWord;

  pMaterials: PD3DXMaterialArray;
  szPath: array [0..MAX_PATH - 1] of Char;

  function GetMeshBonesCount: Integer;
  begin
    if Assigned(pmcMesh) and Assigned(pmcMesh.m_pSkinMesh) then
      Result := pmcMesh.m_pSkinMesh.GetNumBones
    else
      Result := 0;
  end;

begin
  try
  pmcMesh:= SMeshContainer.Create;
  try

    Result:= pxofobjCur.GetName(nil, cchName);
    if FAILED(Result) then Exit;

    if (cchName > 0) then
    begin
      SetLength(pmcMesh.szName, cchName - 1);

      Result:= pxofobjCur.GetName(PChar(pmcMesh.szName), cchName);
      if FAILED(Result) then Exit;
    end;

    Result:= D3DXLoadSkinMeshFromXof(pxofobjCur, options, pD3DDevice,
               @pbufAdjacency, @pbufMaterials, @pmcMesh.cMaterials,
               @pmcMesh.m_pBoneNamesBuf, @pmcMesh.m_pBoneOffsetBuf,
               ID3DXMesh(pmcMesh.m_pSkinMesh));
    if FAILED(Result) then
    begin
      if (Result = D3DXERR_LOADEDMESHASNODATA) then Result := S_OK;
      Exit;
    end;

    cFaces    := pmcMesh.m_pSkinMesh.GetNumFaces;
    cVertices := pmcMesh.m_pSkinMesh.GetNumVertices;

    pAdjacencyIn:= PDWord(pbufAdjacency.GetBufferPointer);

    SetLength(pmcMesh.m_rgiAdjacency, cFaces * 3);

    // memcpy(pmcMesh->m_rgiAdjacency, pAdjacencyIn, cFaces * 3 * sizeof(DWORD));
    Move(pAdjacencyIn^, pmcMesh.m_rgiAdjacency[0], cFaces * 3 * SizeOf(DWORD));

    // Process skinning data
    if (pmcMesh.m_pSkinMesh.GetNumBones <> 0) then
    begin
      // Update max bones of any mesh in the app
      m_maxBones:= max(pmcMesh.m_pSkinMesh.GetNumBones, m_maxBones);

      SetLength(pmcMesh.m_pBoneMatrix, pmcMesh.m_pSkinMesh.GetNumBones);
      pmcMesh.m_pBoneOffsetMat:= PD3DXMatrixArray(pmcMesh.m_pBoneOffsetBuf.GetBufferPointer);

      Result:= GenerateMesh(pmcMesh);
    end
    else
    begin
      pmcMesh.m_pSkinMesh.GetOriginalMesh(pmcMesh.pMesh);
      pmcMesh.m_pSkinMesh:= nil;
      pmcMesh.cpattr:= pmcMesh.cMaterials;
    end;

    if ((pbufMaterials = nil) or (pmcMesh.cMaterials = 0)) then
    begin
      SetLength(pmcMesh.rgMaterials, 1);
      SetLength(pmcMesh.pTextures, 1);

      FillChar(pmcMesh.rgMaterials[0], SizeOf(TD3DMaterial8), 0);
      pmcMesh.rgMaterials[0].Diffuse.r:= 0.5;
      pmcMesh.rgMaterials[0].Diffuse.g:= 0.5;
      pmcMesh.rgMaterials[0].Diffuse.b:= 0.5;
      pmcMesh.rgMaterials[0].Specular:= pmcMesh.rgMaterials[0].Diffuse;
      pmcMesh.pTextures[0]:= nil;
    end
    else
    begin
      SetLength(pmcMesh.rgMaterials, pmcMesh.cMaterials);
      SetLength(pmcMesh.pTextures, pmcMesh.cMaterials);

      pMaterials:= PD3DXMaterialArray(pbufMaterials.GetBufferPointer);

      for iMaterial:= 0 to pmcMesh.cMaterials - 1 do
      begin
        pmcMesh.rgMaterials[iMaterial]:= pMaterials[iMaterial].MatD3D;

        pmcMesh.pTextures[iMaterial]:= nil;
        if (pMaterials[iMaterial].pTextureFilename <> nil) then
        begin
          DXUtil_FindMediaFile(szPath, PChar(pMaterials[iMaterial].pTextureFilename));

          if FAILED(D3DXCreateTextureFromFile(pD3DDevice, szPath, pmcMesh.pTextures[iMaterial])) then begin
            Log('Media file "' + szPath + '" not found', lkError);
          end;
        end;
      end;
    end;

    Log(Format('%SA mesh "%S" found. Vertices: %D, Faces: %D, Bones: %D, Materials: %D',
                   [GetIndent, pmcMesh.szName, cVertices, cFaces,
                    GetMeshBonesCount, pmcMesh.cMaterials]));

    // add the mesh to the parent frame
    pframeParent.AddMesh(pmcMesh);
    MyMesh := pmcMesh;
    pmcMesh:= nil;

  finally
    pmcMesh.Free;
  end;
  except
    on EOutOfMemory do Result:= E_OUTOFMEMORY;
   else raise;
  end;
end;


function CMyD3DApplication.LoadFrames(pxofobjCur: IDirectXFileData; pde: SDrawElement;
      options: DWord; fvf: DWord; pD3DDevice: IDirect3DDevice8;
      pframeParent: SFrame): HResult;
var
  pxofobjChild: IDirectXFileData;
  pxofChild: IDirectXFileObject;
  cbSize: DWord;
  pmatNew: PD3DXMatrix;
  pframeCur: SFrame;
  cchName: DWord;
  _type: PGUID;
begin
  // Get the type of the object
  _type:= nil;
  Result:= pxofobjCur.GetType(_type);
  if FAILED(Result) then Exit;
  Inc(Indent);

  try
    if EqualGUID(_type^, TID_D3DRMMesh) then
    begin
      Result:= LoadMesh(pxofobjCur, options, fvf, pD3DDevice, pframeParent);
      if FAILED(Result) then Exit;
    end
    else if EqualGUID(_type^, TID_D3DRMFrameTransformMatrix) then
    begin
      Log(GetIndent + 'A transform matrix found');
      Result:= pxofobjCur.GetData(nil, cbSize, Pointer(pmatNew));
      if FAILED(Result) then Exit;

      // update the parents matrix with the new one
      pframeParent.matRot:= pmatNew^;
      pframeParent.matRotOrig:= pmatNew^;

//      if not EqualsMatrix4s(IdentityMatrix4s, TMatrix4s(pframeParent.matRot)) then Log(GetIndent + '*** not identity matrix!');

    end
    else if EqualGUID(_type^, TID_D3DRMAnimationSet) then
    begin
      LoadAnimationSet(pxofobjCur, pde, options, fvf, pD3DDevice, pframeParent);
    end
    else if EqualGUID(_type^, TID_D3DRMAnimation) then
    begin
      LoadAnimation(pxofobjCur, pde, options, fvf, pD3DDevice, pframeParent);
    end
    else if EqualGUID(_type^, TID_D3DRMFrame) then
    begin
      pframeCur:= SFrame.Create;

      Result:= pxofobjCur.GetName(nil, cchName);
      if FAILED(Result) then Exit;

      if (cchName > 0) then
      begin
        SetLength(pframeCur.szName, cchName - 1);

        Result:= pxofobjCur.GetName(PChar(pframeCur.szName), cchName);
        if FAILED(Result) then Exit;
        Log(GetIndent + 'A frame "' + pframeCur.szName + '" found');
      end;

      pframeParent.AddFrame(pframeCur);

      // Enumerate child objects.
      // Child object can be data, data reference or binary.
      // Use QueryInterface() to find what type of object a child is.
      while (SUCCEEDED(pxofobjCur.GetNextObject(pxofChild))) do 
      begin
        // Query the child for it's FileData
        Result:= pxofChild.QueryInterface(IID_IDirectXFileData, pxofobjChild);
        if SUCCEEDED(Result) then
        begin
          Result:= LoadFrames(pxofobjChild, pde, options, fvf, pD3DDevice, pframeCur);
          if FAILED(Result) then Exit;

          pxofobjChild:= nil;
        end;
        
        pxofChild:= nil;
      end;
    end;
  except
    on EOutOfMemory do Result:= E_OUTOFMEMORY;
   else raise;
  end;

  Dec(Indent);
end;


function CMyD3DApplication.DeleteSelectedMesh: HResult;
var
  pdeCur:  SDrawElement;
  pdePrev: SDrawElement;
begin
  if (m_pdeSelected <> nil) then
  begin
    pdeCur:= m_pdeHead;
    pdePrev:= nil;
    while ((pdeCur <> nil) and (pdeCur <> m_pdeSelected)) do
    begin
      pdePrev:= pdeCur;
      pdeCur:= pdeCur.pdeNext;
    end;

    if (pdePrev = nil) then
    begin
      m_pdeHead:= m_pdeHead.pdeNext;
    end
    else
    begin
      pdePrev.pdeNext:= pdeCur.pdeNext;
    end;

    m_pdeSelected.pdeNext:= nil;
    if (m_pdeHead = m_pdeSelected) then m_pdeHead:= nil;
    m_pdeSelected.Free;
    m_pdeSelected:= nil;
  end;

  Result:= S_OK;
end;

end.

