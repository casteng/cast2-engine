{$Include GDefines}
{$Include CDefines}
unit CMan;

interface

uses Basics, CTypes, CTess, CRender, CRes;

const
  VAllocStep = 256*32;
  VAllocMask: LongWord = not LongWord(VAllocStep-1);
  IAllocStep = 256;
  IAllocMask: LongWord = not LongWord(IAllocStep-1);

type
  TMeshManager = class
    Events: TCommandQueue;
    Renderer: TRenderer;
    StreamNum: LongWord;
    TotalItems: Integer;
    Items: array of TTesselator;
    constructor Create(ARenderer: TRenderer; AEvents: TCommandQueue);
    function AddItem(const Item: TTesselator): TTesselator; virtual;
    function AddMesh(const AVerticesRes, AIndicesRes: Integer): TTesselator; virtual;
    procedure DeleteItem(const Item: TTesselator); virtual;
    procedure Clear; virtual;
    procedure Process; virtual; abstract;
    procedure Render; virtual;
  end;

{$IFDEF DEBUGMODE}
var
  dResizeCount, dTesselateCount, dTotalBufferSize, dActualVertices: Integer;
  DebugStr: string;
{$ENDIF}

implementation

{ TMeshManager }

constructor TMeshManager.Create(ARenderer: TRenderer; AEvents: TCommandQueue);
begin
  Renderer := ARenderer;
  Events := AEvents;
  StreamNum := Renderer.AddStream(VAllocStep, IAllocStep, 2, False);
end;

function TMeshManager.AddItem(const Item: TTesselator): TTesselator;
begin
  Inc(TotalItems); SetLength(Items, TotalItems);
  Items[TotalItems - 1] := Item;
  Items[TotalItems - 1].Index := TotalItems - 1;
  Items[TotalItems - 1].Stream := StreamNum;
  Items[TotalItems - 1].Status := tsSizeChanged;
//  Items[TotalItems - 1].Manager := Self;
  Result := Item;
end;

procedure TMeshManager.DeleteItem(const Item: TTesselator);
begin
  if not (Item.Index < TotalItems) then begin
    Assert(Item.Index < TotalItems, 'TFXManager.DeleteItem: Index out of bounds');
  end;
  Dec(TotalItems);
  if Item.Index < TotalItems then begin
    if Items[Item.Index].TotalVertices = Items[TotalItems].TotalVertices then Items[TotalItems].Status := tsChanged else Items[TotalItems].Status := tsSizeChanged;
    Items[Item.Index] := Items[TotalItems];
    Items[Item.Index].Index := Item.Index;
  end;
  SetLength(Items, TotalItems);
  Item.Index := -1;
end;

procedure TMeshManager.Clear;
begin
  TotalItems := 0; SetLength(Items, TotalItems);
end;

procedure TMeshManager.Render;
var i, PopupIndex: Integer; Changed, RepeatRender: Boolean; Temp: Pointer; Res: HResult; VBuf, IBuf: PByte;
begin
  if (Renderer.State <> rsOK) and (Renderer.State <> rsClean) then Exit;        // ToFix: Where device lost test must be ?
//  if (Obj.Status <> tsStatic) and (Obj.CheckGeometry(RenderPars.Camera) or (State = rsClean) or (Obj.Status = tsSizeChanged) or (Obj.Status = tsChanged)) then begin
  with Renderer do begin
    Assert(Streams[StreamNum].VertexBuffer <> nil, 'VB of Stream is nil');
    VBuf := Renderer.LockVBuffer(StreamNum, 0, Streams[StreamNum].VertexBufferSize, lmNoOverwrite);
    if Streams[StreamNum].IndexBufferSize > 0 then IBuf := Renderer.LockIBuffer(StreamNum, 0, Streams[StreamNum].IndexBufferSize, 0);
  end;

//  Renderer.SetTextureFiltering(tfNone, tfNone, tfNone);
{$IFDEF DEBUGMODE}  { dResizeCount := 0;} dTesselateCount := 0; dActualVertices := 0; {$ENDIF}
  repeat
    PopupIndex := -1;
    Changed := False; RepeatRender := False;
    Renderer.Streams[StreamNum].CurVBOffset := 0; Renderer.Streams[StreamNum].CurIBOffset := 0;
    for i := 0 to TotalItems - 1 do begin
      Assert(Items[i].Stream = StreamNum, 'Stream mismatch');
      RepeatRender := False;
      if (Items[i].Status = tsMoved) and (PopupIndex = -1) then Changed := True;
      if (Items[i].Status = tsSizeChanged) and (PopupIndex = -1) then begin
        Changed := True; PopupIndex := i;
      end;
      if Changed then begin
        with Renderer.Streams[StreamNum] do begin
          if (VertexBufferSize < ((CurVBOffset + Items[i].TotalVertices*Items[i].VertexSize) and VAllocMask + VAllocStep)) then begin
{$IFDEF DEBUGMODE} Inc(dResizeCount); {$ENDIF}
            if IndexBufferSize > 0 then Renderer.UnLockIBuffer(StreamNum);
            Renderer.UnLockVBuffer(StreamNum);
            Renderer.ResizeStream(StreamNum, ((CurVBOffset + Items[i].TotalVertices*Items[i].VertexSize) and VAllocMask + VAllocStep),
                                             IndexBufferSize, 2, Static);
            VBuf := Renderer.LockVBuffer(StreamNum, 0, VertexBufferSize, lmNoOverwrite);
            if IndexBufferSize > 0 then IBuf := Renderer.LockIBuffer(StreamNum, 0, IndexBufferSize, 0);
            Items[0].Status := tsSizeChanged;
            RepeatRender := True;
          end;
          if (IndexBufferSize < ((CurIBOffset + Items[i].TotalIndices*IndexSize) and IAllocMask + IAllocStep)) then begin
            if IndexBufferSize > 0 then Renderer.UnLockIBuffer(StreamNum);
            Renderer.UnLockVBuffer(StreamNum);
            Renderer.ResizeStream(StreamNum, VertexBufferSize, ((CurIBOffset + Items[i].TotalIndices*IndexSize) and IAllocMask + IAllocStep), 2, Static);
            VBuf := Renderer.LockVBuffer(StreamNum, 0, VertexBufferSize, lmNoOverwrite);
            if IndexBufferSize > 0 then IBuf := Renderer.LockIBuffer(StreamNum, 0, IndexBufferSize, 0);
            Items[0].Status := tsSizeChanged;
            RepeatRender := True;
          end;
        end;
        if RepeatRender then Break;
        Items[i].Status := tsSizeChanged;
      end;
  {$IFDEF DEBUGMODE} Inc(dActualVertices, Items[i].TotalVertices); {$ENDIF}

      with Renderer do if (State = rsClean) or (Items[i].Status = tsSizeChanged) or (Items[i].Status = tsChanged) then begin
{$IFDEF DEBUGMODE} Inc(dTesselateCount); {$ENDIF}
        Items[i].VBOffset := Streams[StreamNum].CurVBOffset div Items[i].VertexSize;
//       VBuf := Renderer.LockVBuffer(StreamNum, Streams[StreamNum].CurVBOffset, Items[i].TotalVertices*Items[i].VertexSize, 0*lmNoOverwrite);
//       IBuf := Renderer.LockIBuffer(StreamNum, Streams[StreamNum].CurIBOffset, Items[i].TotalIndices*2, 0);
        Inc(Streams[StreamNum].CurVBOffset, Items[i].Tesselate(RenderPars, Lights, TotalLights, Pointer(Cardinal(VBuf)+Streams[StreamNum].CurVBOffset)) * Items[i].VertexSize);
//        Inc(Streams[StreamNum].CurVBOffset, Items[i].Tesselate(RenderPars, Lights, TotalLights, VBuf) * Items[i].VertexSize);
        if Items[i].TotalIndices > 0 then begin
          Items[i].IBOffset := Streams[StreamNum].CurIBOffset shr 1;
          Inc(Streams[StreamNum].CurIBOffset, Items[i].SetIndices(Pointer(Cardinal(IBuf)+Streams[StreamNum].CurIBOffset)) * Streams[StreamNum].IndexSize);
//          Inc(Streams[StreamNum].CurIBOffset, Items[i].SetIndices(IBuf) * Streams[StreamNum].IndexSize);
        end;
//       Renderer.UnLockVBuffer(StreamNum);
//       Renderer.UnLockIBuffer(StreamNum);
      end else begin
        Inc(Streams[StreamNum].CurVBOffset, Items[i].LastTotalVertices * Items[i].VertexSize);
        Inc(Streams[StreamNum].CurIBOffset, Items[i].LastTotalIndices * Streams[StreamNum].IndexSize);
      end;
//      Renderer.AddTesselator(Items[i]);
    end;
  until not RepeatRender;
  if Renderer.Streams[StreamNum].IndexBufferSize > 0 then Renderer.UnLockIBuffer(StreamNum);
  Renderer.UnLockVBuffer(StreamNum);

{$IFDEF DEBUGMODE} dTotalBufferSize := {PopupIndex;//}Renderer.Streams[StreamNum].VertexBufferSize{ div Items[0].VertexSize}; {$ENDIF}
  if (PopupIndex >= 0) and (PopupIndex < TotalItems - 1) then begin
    Temp := Items[PopupIndex];
    for i := PopupIndex + 1 to TotalItems - 1 do begin
      Items[i-1] := Items[i];
      Items[i-1].Index := i-1;
    end;
//    Items[PopupIndex] := Items[TotalItems - 1];
    Items[TotalItems - 1] := Temp;
    Items[TotalItems - 1].Index := TotalItems - 1;
    Items[PopupIndex].Index := PopupIndex;
    Items[PopupIndex].Status := tsMoved;
  end;
{  if TotalItems < 10 then }for i := 0 to TotalItems-1 do begin
    Assert(Items[i].Index = i, 'Items index mismatch');
    Renderer.AddTesselator(Items[i]);
  end;
//  Renderer.SetTextureFiltering(tfLinear, tfLinear, tfLinear);
end;

function TMeshManager.AddMesh(const AVerticesRes, AIndicesRes: Integer): TTesselator;
var i: Integer;
begin
  for i := 0 to TotalItems-1 do if (AVerticesRes = Items[i].VerticesRes) and (AIndicesRes = Items[i].IndicesRes) then begin
    Result := Items[i]; Exit;
  end;
  Result := TMeshTesselator.Create(StreamNum, TArrayResource(Renderer.Resources[AVerticesRes]).TotalElements, Renderer.Resources[AVerticesRes].Data,
                                              TArrayResource(Renderer.Resources[AIndicesRes]).TotalElements,  Renderer.Resources[AIndicesRes].Data);
  Result.VerticesRes := AVerticesRes;
  Result.IndicesRes := AIndicesRes;
end;

end.
