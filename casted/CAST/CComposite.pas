{$Include GDefines}
{$Include CDefines}
unit CComposite;

interface

uses  Logger,  Basics, CTypes, CAST, CTess, CRender;

type
  TComposite = class(TItem)
//    Vertices, Indices: array of Byte;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetMesh; override;
    procedure SetManager(const AManager: TMeshManager); override;
    function SetChild(Index: Integer; AItem: TItem): TItem; override;
    function DeleteChild(AItem: TItem): Integer; override;
    procedure Render(Renderer: TRenderer); override;
  private
    LastChildStats: array of record Visible, Composite: Boolean; end;
  end;

  TCompositeTesselator = class(TMeshTesselator)
    Item: TComposite;
//    ChildMeshes: array of TTesselator; TotalChildMeshes: Integer;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  end;

implementation

{ TCompositeTesselator }

function TCompositeTesselator.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;  Offset, VOffset: Longword;
begin
  Offset := 0; VOffset := 0;
  TotalIndices := 0;
  for i := 0 to Item.TotalChilds-1 do if (Item.Childs[i].CompositeMode) and (Item.Childs[i].Status and isVisible > 0) then begin
    Inc(TotalIndices, Item.Childs[i].CurrentLOD.SetIndices(Pointer(Longword(IBPTR) + Offset*2)));
    if VOffset > 0 then for j := Offset to Offset + Item.Childs[i].CurrentLOD.LastTotalIndices-1 do
     TWordBuffer(IBPTR^)[j] := TWordBuffer(IBPTR^)[j] + VOffset;
    Inc(Offset, Item.Childs[i].CurrentLOD.LastTotalIndices);
    Inc(VOffset, Item.Childs[i].CurrentLOD.LastTotalVertices);
  end;

  LastTotalIndices := TotalIndices;
  IStatus := tsTesselated;
  Result := TotalIndices;
end;

function TCompositeTesselator.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i: Integer; Offset: Longword;
begin
  Offset := 0;
  TotalVertices := 0;
  TotalPrimitives :=  0;

  for i := 0 to Item.TotalChilds-1 do if (Item.Childs[i].CompositeMode) and (Item.Childs[i].Status and isVisible > 0) then begin
    Item.Childs[i].CurrentLOD.CompositeMember := True;
    Item.Childs[i].CurrentLOD.CompositeOffset := @Item.Childs[i].Location;
    Inc(TotalVertices, Item.Childs[i].CurrentLOD.Tesselate(RenderPars, Pointer(Longword(VBPTR) + Offset)));
    Inc(TotalPrimitives, Item.Childs[i].CurrentLOD.TotalPrimitives);
    Inc(Offset, TotalVertices*VertexSize);
    Item.Childs[i].CurrentLOD.LastFrameTesselated := -1;
    Item.Childs[i].CurrentLOD.CompositeMember := False;
  end;
  VStatus := tsTesselated;

  IndexingVertices := TotalVertices;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ TComposite }

constructor TComposite.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  SetMesh;
end;

procedure TComposite.SetMesh;
begin
  ClearMeshes;
  AddLOD(TCompositeTesselator.Create('Composite', 0, nil, 0, nil));
  TCompositeTesselator(CurrentLOD).Item := Self;;
end;

procedure TComposite.SetManager(const AManager: TMeshManager);
var i: Integer;
begin
  if Manager <> nil then begin
//    Dec(Manager.TotalVertices, MaxTotalVertices);
    for i := 0 to TotalLODs-1 do Manager.DeleteMesh(Meshes[i]);

    Log('Item "' + Name + '" mesh manager respecified', lkWarning);

  end;
  Manager := AManager;

  for i := 0 to TotalLODs-1 do if Manager.MeshExists(Meshes[i]) = -1 then Manager.AddMesh(Meshes[i]);
end;

function TComposite.SetChild(Index: Integer; AItem: TItem): TItem;
begin
  if AItem.CurrentLOD.TotalStrips <> 1 then begin
 Log('Adding to composite object "'+Name+'" object "'+AItem.Name+'" with many strips', lkError); 
    Exit;
  end;
  inherited SetChild(Index, AItem);
  if Index = 0 then begin
    CurrentLOD.VertexFormat := AItem.CurrentLOD.VertexFormat;
    CurrentLOD.VertexSize := GetVertexSize(CurrentLOD.VertexFormat);
    CurrentLOD.PrimitiveType := AItem.CurrentLOD.PrimitiveType;

    CurrentLOD.TotalStrips := 1;
    CurrentLOD.StripOffset := 0;
  end;
  Inc(CurrentLOD.TotalVertices, AItem.CurrentLOD.TotalVertices);
  Inc(CurrentLOD.TotalIndices, AItem.CurrentLOD.TotalIndices);
  CurrentLOD.IndexingVertices := CurrentLOD.TotalVertices;

  Inc(CurrentLOD.TotalPrimitives, AItem.CurrentLOD.TotalPrimitives);

  CurrentLOD.VStatus := tsSizeChanged; CurrentLOD.IStatus := tsSizeChanged;
  CurrentLOD.LastTotalVertices := 0;//AItem.CurrentLOD.LastTotalVertices;
  CurrentLOD.LastTotalIndices := 0;//AItem.CurrentLOD.LastTotalIndices;

//  SetLength(Vertices, CurrentLOD.TotalVertices * CurrentLOD.VertexSize);
//  SetLength(Indices, CurrentLOD.TotalIndices * 2);

  SetLength(LastChildStats, TotalChilds);
  LastChildStats[Index].Visible := (AItem.Status and isVisible) > 0;
  LastChildStats[Index].Composite := AItem.CompositeMode;

  if Index = 0 then World.ChooseManager(Self);

//  AItem.CurrentLOD.Tesselate(World.Renderer.RenderPars, Vertices);
//  AItem.CurrentLOD.SetIndices(Indices);
end;

function TComposite.DeleteChild(AItem: TItem): Integer;
begin
  Result := inherited DeleteChild(AItem);
  if Result = -1 then Exit;
  with CurrentLOD do begin
    Dec(TotalVertices, AItem.CurrentLOD.TotalVertices);
    Dec(TotalIndices, AItem.CurrentLOD.TotalIndices);
    IndexingVertices := TotalVertices;

    Dec(TotalPrimitives, AItem.CurrentLOD.TotalPrimitives);

    VStatus := tsSizeChanged; IStatus := tsSizeChanged;
    LastTotalVertices := AItem.CurrentLOD.LastTotalVertices;
    LastTotalIndices := AItem.CurrentLOD.LastTotalIndices;
  end;
end;

procedure TComposite.Render(Renderer: TRenderer);
var i: Integer;
begin
//  Renderer.AddTesselator(Mesh);
  Assert(not Assigned(CurrentLOD) or Assigned(Manager), 'TComposite.Render: Manager is nil');
  if CurrentLOD <> nil then Manager.AddItem(Self);
  if World.DebugOut and (World.DebugMeshManager <> nil) then World.DebugMeshManager.AddBVolume(BoundingVolumes, ModelMatrix);
  for i := 0 to TotalChilds - 1 do begin
    if (LastChildStats[i].Visible <> ((Childs[i].Status and isVisible) > 0)) or
       (LastChildStats[i].Composite <> Childs[i].CompositeMode) then begin
      CurrentLOD.VStatus := tsSizeChanged; CurrentLOD.IStatus := tsSizeChanged;
    end;
    LastChildStats[i].Visible := (Childs[i].Status and isVisible) > 0;
    LastChildStats[i].Composite := Childs[i].CompositeMode;
  end;
end;

end.
 