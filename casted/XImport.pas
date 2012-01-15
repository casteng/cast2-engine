(*
 @Abstract(CAST II Engine landscapes unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: 29.01.2007 <br>
 Unit contains basic landscape classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit XImport;

interface

uses
  Logger,
  SysUtils,
  Windows,
//  {$IFNDEF DISABLED3DX8}
  Direct3D8,
  D3DX8,
  DXFile,
  C2DX8Render,
//  {$ENDIF}
  BaseTypes, BaseMsg, Basics, BaseStr, Base2D, Base3D, Props, BaseGraph,
  BaseClasses,
  C2Types, C2Res, CAST2, Resources, C2Visual, C2Maps, C2MapEditMsg,
  C2Render, C2Core, C2Anim,

  SkinnedMeshUnit;

function LoadX(ADirect3DDevice: IDirect3DDevice8; Handle: HWnd; FileName: BaseTypes.TFileName; Parent: TItem): TItem;

implementation

function LoadX(ADirect3DDevice: IDirect3DDevice8; Handle: HWnd; FileName: BaseTypes.TFileName; Parent: TItem): TItem;
var
  VRes: TVerticesResource; IRes: TIndicesResource; TRes: TImageResource;
  TotalAnimations: Integer;

  function CallCheck(const Name: string; Res: HResult): Boolean;
  begin
    Result := Succeeded(Res);
    if not Result then
      Log(Name + ': Result: ' + IntToStr(Res) + ' "' + HResultToStr(Res) + '"', lkFatalError);
  end;


  function FindMesh(Frame: SFrame): IInterface;
  var pmcMesh: SMeshContainer;
  begin
    Result := MyMesh.pMesh;
    Exit;
    Result := nil;

    pmcMesh := Frame.pmcMesh;
    while (pmcMesh <> nil) and (pmcMesh.pMesh = nil) {and (pmcMesh.m_pSkinMesh = nil)} do
      pmcMesh := pmcMesh.pmcNext;

    if pmcMesh <> nil then if pmcMesh.pMesh = nil then Result := nil{pmcMesh.m_pSkinMesh} else Result := pmcMesh.pMesh;

    if Result = nil then begin
      Frame := Frame.pframeFirstChild;
      while (Result = nil) and (Frame <> nil) do begin
        Result := FindMesh(Frame);
        Frame := Frame.pframeSibling;
      end;
    end;
  end;
  

  function FillResources(Mesh: ID3DXMesh): HResult;
  var
    NumVertices, NumIndices: Integer;
    p: PByte;
    ibuf: IDirect3DIndexBuffer8;
    ibdesc: _D3DINDEXBUFFER_DESC;
    FVF: Cardinal;
  begin
    Result := D3DERR_NOTFOUND;

    if not Assigned(Mesh) then Exit;

    NumVertices := Mesh.GetNumVertices;

    VRes := nil; IRes := nil; TRes := nil;

    FVF := Mesh.GetFVF;

    VRes := TVerticesResource.Create(nil);
    VRes.Name   := 'VER_' + GetFileName(FileName);
    VRes.Format := FVFToVertexFormat(FVF);
    VRes.Allocate(NumVertices * GetVertexSize(VRes.Format));

    Mesh.GetIndexBuffer(ibuf);
    ibuf.GetDesc(ibdesc);
    NumIndices  := ibdesc.Size div 2;// Mesh.GetNumFaces * 3;

    IRes := TIndicesResource.Create(nil);
    IRes.Name   := 'IND_' + GetFileName(FileName);
    IRes.Format := 2;
    IRes.Allocate(NumIndices * 2);

    Result := Mesh.LockVertexBuffer(D3DLOCK_READONLY, p);
    if Failed(Result) then Exit;
    Move(p^, VRes.Data^, VRes.DataSize);
    Mesh.UnlockVertexBuffer;

    Result := Mesh.LockIndexBuffer(D3DLOCK_READONLY, p);
    if Failed(Result) then Exit;
    Move(p^, IRes.Data^, IRes.DataSize);
    Mesh.UnlockIndexBuffer;
  end;

const
  UINT_MAX      = $FFFFFFFF;
type
  PD3DXBoneCombinationArray = ^TD3DXBoneCombinationArray;
  TD3DXBoneCombinationArray = array [0..0] of TD3DXBoneCombination;

  var Direct3DDevice: IDirect3DDevice8;

  function Create3DDevice: HResult;
  var
    D3DPP: TD3DPresent_Parameters;
    D3DDM: TD3DDisplayMode;
    Direct3D: IDirect3D8;
  begin
    Direct3D := Direct3DCreate8(D3D_SDK_VERSION);
    if Direct3D = nil then begin
      Log('LoadX: Error creating Direct3D object', lkFatalError);
      Exit;
    end;
    if not CallCheck('Get display mode', Direct3D.GetAdapterDisplayMode(D3DADAPTER_DEFAULT, D3DDM)) then Exit;
    FillChar(D3DPP, SizeOf(D3DPP), 0);

    D3DPP.BackBufferFormat := D3DDM.Format;
    D3DPP.BackBufferWidth  := 64;
    D3DPP.BackBufferHeight := 64;

    D3DPP.BackBufferCount := 1;
    D3DPP.MultiSampleType := D3DMULTISAMPLE_NONE;
    D3DPP.SwapEffect      := D3DSWAPEFFECT_DISCARD;
    D3DPP.hDeviceWindow   := Handle;
    D3DPP.Windowed        := True;
    D3DPP.EnableAutoDepthStencil := False;
    D3DPP.AutoDepthStencilFormat := D3DFMT_UNKNOWN;
    D3DPP.Flags                  := 0;
    if not CallCheck('LoadX: Creating Direct3D device', Direct3D.CreateDevice(D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, Handle, D3DCREATE_FPU_PRESERVE or D3DCREATE_SOFTWARE_VERTEXPROCESSING, D3DPP, Direct3DDevice)) then Exit;
  end;

  procedure BuildSkeleton(DrawEl: SDrawElement; var Skeleton: TAnimSkeleton);
  type APChar = array[0..$FFFF] of PChar;
  var
    BoneNames: ^APChar;
    TotalBoneNames: Integer;
    RotMatrix: array of TAnimTransform;
    SkeletonRes: TSkeletonResource;

    // Retrieves a list of bone names and places it in BoneNames
    procedure RetrieveNames(pmcMesh: SMeshContainer; Skeleton: TAnimSkeleton);
    begin
      if (pmcMesh.m_pSkinMesh <> nil) then begin
        BoneNames := pmcMesh.m_pBoneNamesBuf.GetBufferPointer;
        TotalBoneNames := pmcMesh.m_pSkinMesh.GetNumBones;
      end;
    end;

    function GetNameIndex(const Name: Ansistring): Integer;
    begin
      Result := TotalBoneNames-1;
      while (Result >= 0) and (BoneNames^[Result] <> Name) do Dec(Result);
    end;
    

    function IsValidFrame(const Frame: SFrame): Boolean;
    begin
//      Assert(not Assigned(Frame) or not Frame.bAnimationFrame);
      Result := Assigned(Frame) and (GetNameIndex(Frame.szName) <> -1) and
                not Assigned(Frame.pmcMesh)
//               (DrawEl.FindFrame(Frame.szName) <> nil)
               ;
    end;

{    function GetNextValidSibling(var Frame: SFrame): PAnimSkeletonElement;
    begin
      while Assigned(Frame) and not IsValidFrame(Frame) do Frame := Frame.pframeSibling;
      Result := GetAsElement(Frame);
    end;}


    // Convert animation data from D3DX frame format into CAST II format
    procedure AttachAnimation(Frame: SFrame);
    var
      i: Integer;
      SkelEl: PSkeletonElement;
      TimestampsMs: array of Cardinal;
      Anims: array of TAnimTransform;
      AnimRes: TAnimationResource;
    begin
      AnimRes := TAnimationResource.Create(nil);
      AnimRes.Name := 'A' + IntToStr(TotalAnimations) + ' ' + Frame.szName;
      Parent.AddChild(AnimRes);
      AnimRes.SetTotalBones(Skeleton.TotalBones);
      while Assigned(Frame) do begin
        SkelEl := Skeleton.GetElementByName(Frame.pframeToAnimate.szName);

        if Assigned(SkelEl) then begin

          Assert(Assigned(SkelEl), '"' + Frame.pframeToAnimate.szName + '" not found');

          SetLength(TimeStampsMs, Frame.m_cMatrixKeys);
          SetLength(Anims,        Frame.m_cMatrixKeys);

          for i := 0 to Frame.m_cMatrixKeys-1 do begin
            TimeStampsMs[i] := Frame.m_pMatrixKeys[i].dwTime;
            Anims[i] := (TMatrix4s(Frame.m_pMatrixKeys[i].mat));
          end;

          AnimRes.AddBoneAnim(SkelEl^.Index, TimeStampsMs, Anims);
        end;

        Frame := Frame.pframeSibling;
      end;
      Skeleton.AddAnimation(AnimRes);
      Inc(TotalAnimations);
    end;


    var
    //AnimParentFrame: array of SFrame;
    AnimParentFrame: SFrame;

    // Converts a D3DX frame into CAST II skeleton element and recursively calls itself for next and child frames
    procedure InitAsElement(var Result: PSkeletonElement; Frame: SFrame; ItemParent: TItem);
    var i: Integer; Item: TProcessing;
    begin
      if not Assigned(Frame) then Exit;

      Assert(Assigned(ItemParent) and Assigned(Frame));

      Item := TProcessing.Create(nil);
      Item.Name := '[Invalid]';

      if IsValidFrame(Frame) then begin
        Result := SkeletonRes.NewSkeletonElement();
        Result^.Index := GetNameIndex(Frame.szName);
        Assert(Result^.Index >= 0);
        RotMatrix[Result^.Index] := TMatrix4s(Frame.matTrans);

        SkeletonRes.ElementNames[Result^.Index] := Frame.szName;
      end else; Item.Name := Frame.szName;

        Assert(EqualsMatrix4s(IdentityMatrix4s, TMatrix4s(Frame.matTrans)));

//      if Assigned(Result) then begin

        if Frame.bAnimationFrame then begin
          if AnimParentFrame = nil then AnimParentFrame := Frame;
//          SetLength(AnimParentFrame, Length(AnimParentFrame)+1);
//          AnimParentFrame[High(AnimParentFrame)] := Frame;
          Item.Name := '(A)' + Item.Name;
        end;
        if Assigned(Frame.pmcMesh) then Item.Name := '(M)' + Item.Name;
        if Assigned(Frame.pframeToAnimate) then Item.Name := Item.Name + '->' + Frame.pframeToAnimate.szName;
//      end;

      if Assigned(Frame) then begin
        ItemParent.AddChild(Item);
        Item.Transform := TMatrix4s(Frame.matRot);
        Log('*** frame "' + Item.Name + '" successfully loaded');

        if IsValidFrame(Frame) then begin
          InitAsElement(Result^.Next,      Frame.pframeSibling,    ItemParent);
          InitAsElement(Result^.ChildHead, Frame.pframeFirstChild, Item);
        end else begin
          Log('*** invalid frame! "');
          InitAsElement(Result, Frame.pframeSibling,    ItemParent);
          InitAsElement(Result, Frame.pframeFirstChild, Item);
        end;
      end else Result := nil;

    end;

    // Retrieves an offset transform from D3DX mesh container
    procedure BuildMatrices(pmcMesh: SMeshContainer; Skeleton: TAnimSkeleton);
    var i: Integer;
    begin
      if (pmcMesh.m_pSkinMesh <> nil) then begin
//        Skeleton.Skeleton.SetTotalBones(pmcMesh.m_pSkinMesh.GetNumBones);
{        SetLength(IndRemap, pmcMesh.m_pSkinMesh.GetNumBones);
        for i := 0 to High(IndRemap) do begin
          IndRemap[Skeleton.GetElementByName(pBoneName^[i])^.Index] := i;
          Log(GetIndent + '*** A bone "' + pBoneName[i] + '" created');
        end;}

        MyMesh.m_pBoneOffsetMat := PD3DXMatrixArray(MyMesh.m_pBoneOffsetBuf.GetBufferPointer);
        SetLength(SkeletonRes.OffsTransform, pmcMesh.m_pSkinMesh.GetNumBones);
        for i := 0 to High(SkeletonRes.OffsTransform) do begin
          SkeletonRes.OffsTransform[i] := TMatrix4s(MyMesh.m_pBoneOffsetMat^[GetNameIndex(SkeletonRes.ElementNames[i])]);
        end;
      end;
    end;

  var i: Integer;
  begin
    Skeleton := TAnimSkeleton.Create;
    RetrieveNames(MyMesh, Skeleton);

    // Create and prepare skeleton and skeleton resource
    SkeletonRes := TSkeletonResource.Create(nil);
    SkeletonRes.Name := 'Skeleton';
    Parent.AddChild(SkeletonRes);
    SkeletonRes.TotalBones := TotalBoneNames;
    Skeleton.SetSkeletonRes(SkeletonRes);

    SetLength(RotMatrix, TotalBoneNames);

    // Convert D3DX bone frame hierarchy into CAST II bone hierarchy
    AnimParentFrame := nil;
    InitAsElement(SkeletonRes.Head, DrawEl.pframeRoot, Parent);
    Assert(SkeletonRes.TotalBones = MyMesh.m_pSkinMesh.GetNumBones);

    // Prepare transforms
    BuildMatrices(MyMesh, Skeleton);

    // Retrieve, convert and attach animation
//    for i := 0 to High(AnimParentFrame) do if Assigned(AnimParentFrame[i]) then
      AttachAnimation(AnimParentFrame.pframeFirstChild);
  end;

var
  pxofapi: IDirectXFile;
  pxofenum: IDirectXFileEnumObject;
  pxofobjCur: IDirectXFileData;
  pdeMesh:  SDrawElement;

  Props: TProperties;
  Garbage: IRefcountedContainer;

  app: CMyD3DApplication;

  i: Integer;

  DXMat, DXMat2: _D3DMATRIX;
  Mat: TMatrix4s;
  pBoneComb: PD3DXBoneCombinationArray;
  TempSkel: TAnimSkeleton;
begin
  Result := nil;

  TotalAnimations := 0;                            // Animations counter. Only one currently supported by the loader.

  Props := TProperties.Create;
  Garbage := CreateRefcountedContainer;
  Garbage.AddObject(Props);

  // Check if a 3D device is ready or create a new one
  if Assigned(ADirect3DDevice) then
    Direct3DDevice := ADirect3DDevice
  else
    if not CallCheck('LoadX: Creating Direct3D device', Create3DDevice()) then Exit;

  if not CallCheck('X file create', DirectXFileCreate(pxofapi)) then Exit;

  if not CallCheck('Register templates', pxofapi.RegisterTemplates(@D3DRM_XTEMPLATES, D3DRM_XTEMPLATE_BYTES)) then Exit;

  if not CallCheck('Create enum', pxofapi.CreateEnumObject(PChar(FileName), DXFILELOAD_FROMFILE, pxofenum)) then Exit;

  // Initialize application object from DXSDK sample
  app := CMyD3DApplication.Create;

  pdeMesh:= SDrawElement.Create;
  pdeMesh.pframeRoot:= SFrame.Create;

  // Enumerate top level objects.
  // Top level objects are always data object.
  Indent := 0;           // Used for logging
  while (SUCCEEDED(pxofenum.GetNextDataObject(pxofobjCur))) do
  begin
    if not CallCheck('Load frames', app.LoadFrames(pxofobjCur, pdeMesh, D3DXMESH_SYSTEMMEM or D3DXMESH_SOFTWAREPROCESSING, app.m_dwFVF, Direct3DDevice, pdeMesh.pframeRoot)) then Exit;
    pxofobjCur:= nil;
  end;

  Indent := 0;           // Used for logging

  if not CallCheck('Find bones', app.FindBones(pdeMesh.pframeRoot, pdeMesh)) then Exit;

              app.DeleteSelectedMesh;

              // link into the draw list
              pdeMesh.pdeNext:= App.m_pdeHead;
              App.m_pdeHead:= pdeMesh;

          //    if Assigned(m_pdeHead.pdeNext) then
          //    pdeMesh.pframeRoot.pframeFirstChild.pframeToAnimate := pdeMesh.pframeRoot.pframeFirstChild.pframeSibling.pframeSibling;

              App.m_pdeSelected:= pdeMesh;
              App.m_pmcSelectedMesh:= pdeMesh.pframeRoot.pmcMesh;

              App.m_pframeSelected:= pdeMesh.pframeRoot;

              App.m_pdeSelected.fCurTime:= 0.0;
              App.m_pdeSelected.fMaxTime:= 200.0;

  if not CallCheck('Filling resources', FillResources(ID3DXMesh(FindMesh(pdeMesh.pframeRoot)))) then Exit;

  if Length(MyMesh.m_pBoneMatrix) > 0 then begin           // Animation present
    BuildSkeleton(pdeMesh, TempSkel);
    TempSkel.UpdateHierarchy();
    TempSkel.SetTime(0);

    pBoneComb:= PD3DXBoneCombinationArray(MyMesh.m_pBoneCombinationBuf.GetBufferPointer);
    Assert(MyMesh.cpattr = 1);

    // Make sure if D3DX bone combination index array contains trivial values as it's not taken in account for now
    for i:= 0 to MyMesh.m_paletteSize - 1 do Assert(i = pBoneComb[0].BoneId[i]);
//      if (matid <> UINT_MAX) then
//        TempSkel.TotalTransform[matid] := MulMatrix4s(TempSkel.Skeleton.OffsTransform[matid], TempSkel.TotalTransform[matid]);
  end else TempSkel := nil;

      // Prepare properties (resource links etc)
      if Assigned(VRes) then begin
        Parent.AddChild(VRes);

        Props.Clear;
        Result := TSkinnedItem.Create(nil);
        Result.Name := GetFileName(FileName);
        Parent.AddChild(Result);

        if Assigned(TempSkel) then begin
          TSkinnedItem(Result).SetSkeleton(TempSkel);
          Result.AddProperties(nil);                     // To build item links
        end;

//        if Assigned(Mat) then Props.Add('Material', vtObjectLink, [], Mat.GetFullName,  '');

        Props.Add('Geometry\Vertices', vtObjectLink, [], VRes.GetFullName, '');
        if Assigned(IRes) then begin
          Parent.AddChild(IRes);
          Props.Add('Geometry\Indices',  vtObjectLink, [], IRes.GetFullName, '');
        end;

        Props.Add('Frame', vtSingle, [], '0', '');

        Props.Add('Geometry\Skeleton', vtObjectLink, [], TempSkel.SkeletonResource.GetFullName, '');
        for i := 0 to TempSkel.TotalAnimations - 1 do
          Props.Add('Geometry\Animation #' + IntToStr(i), vtObjectLink, [], TempSkel.AnimationResource[i].GetFullName, '');

        // Apply properties
        if Assigned(Result) then Result.SetProperties(Props);
      end;

  Log('Model "' + FileName + '" successfully loaded');
end;

end.
procedure ExecConsoleApp(CommandLine: AnsiString; Output: TStringList; Errors:
  TStringList);
var
  sa: TSECURITYATTRIBUTES;
  si: TSTARTUPINFO;
  pi: TPROCESSINFORMATION;
  hPipeOutputRead: THANDLE;
  hPipeOutputWrite: THANDLE;
  hPipeErrorsRead: THANDLE;
  hPipeErrorsWrite: THANDLE;
  Res, bTest: Boolean;
  env: array[0..100] of Char;
  szBuffer: array[0..256] of Char;
  dwNumberOfBytesRead: DWORD;
  Stream: TMemoryStream;
begin
  sa.nLength := sizeof(sa);
  sa.bInheritHandle := true;
  sa.lpSecurityDescriptor := nil;
  CreatePipe(hPipeOutputRead, hPipeOutputWrite, @sa, 0);
  CreatePipe(hPipeErrorsRead, hPipeErrorsWrite, @sa, 0);
  ZeroMemory(@env, SizeOf(env));
  ZeroMemory(@si, SizeOf(si));
  ZeroMemory(@pi, SizeOf(pi));
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
  si.wShowWindow := SW_HIDE;
  si.hStdInput := 0;
  si.hStdOutput := hPipeOutputWrite;
  si.hStdError := hPipeErrorsWrite;

  (* Remember that if you want to execute an app with no parameters you nil the
     second parameter and use the first, you can also leave it as is with no
     problems.                                                                 *)
  Res := CreateProcess(nil, pchar(CommandLine), nil, nil, true,
    CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, @env, nil, si, pi);

  // Procedure will exit if CreateProcess fail
  if not Res then
  begin
    CloseHandle(hPipeOutputRead);
    CloseHandle(hPipeOutputWrite);
    CloseHandle(hPipeErrorsRead);
    CloseHandle(hPipeErrorsWrite);
    Exit;
  end;
  CloseHandle(hPipeOutputWrite);
  CloseHandle(hPipeErrorsWrite);

  //Read output pipe
  Stream := TMemoryStream.Create;
  try
    while true do
    begin
      bTest := ReadFile(hPipeOutputRead, szBuffer, 256, dwNumberOfBytesRead,
        nil);
      if not bTest then
      begin
        break;
      end;
      Stream.Write(szBuffer, dwNumberOfBytesRead);
    end;
    Stream.Position := 0;
    Output.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;

  //Read error pipe
  Stream := TMemoryStream.Create;
  try
    while true do
    begin
      bTest := ReadFile(hPipeErrorsRead, szBuffer, 256, dwNumberOfBytesRead,
        nil);
      if not bTest then
      begin
        break;
      end;
      Stream.Write(szBuffer, dwNumberOfBytesRead);
    end;
    Stream.Position := 0;
    Errors.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;

  WaitForSingleObject(pi.hProcess, INFINITE);
  CloseHandle(pi.hProcess);
  CloseHandle(hPipeOutputRead);
  CloseHandle(hPipeErrorsRead);
end;
