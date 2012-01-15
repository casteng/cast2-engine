{$I GDefines.inc}
unit ObjFrame;

interface

uses
   Logger, 
  BaseTypes, Basics, BaseStr, Props, TreeViews, BaseClasses, Cast2, C2Visual, C2Materials, Resources, Base2D,
  PropFrame, ACSBase,
  C2EdMain,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, VirtualTrees, ExtCtrls, StdCtrls, Buttons, ComCtrls,
  PngSpeedButton;

const
  PreviewSize = 24;
  MaxPreviewSourceSize = 256;

type
  {$IFDEF UNICODE}
  TreeString = string;
  {$ELSE}
  TreeString = WideString;
  {$ENDIF}

  TOnTreeChangeEvent = procedure(Item: TItem) of object;

  TNodeAction = procedure(ANode: PVirtualNode; Params: TActionParams) of object;

  TItemsTree = class(TEditorTree)
    Properties: TProperties;
    constructor Create(ATree: TBaseVirtualTree);
    function GetNodeText(Node: PVirtualNode; Column: Integer): string; override;
  end;

  TItemsFrame = class(TFrame)
    Tree: TVirtualStringTree;
    ButtonsPanel: TPanel;
    RenderModeBut: TSpeedButton;
    ProcessModeBut: TSpeedButton;
    BoundsModeBut: TSpeedButton;
    DisableTessButton: TSpeedButton;
    ProgressBar1: TProgressBar;
    BtnPause: TPngSpeedButton;
    procedure Init;
    destructor Destroy; override;
    procedure TreeEditing(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; var Allowed: Boolean);
    procedure TreeCompareNodes(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
    procedure TreeInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode; var InitialStates: TVirtualNodeInitStates);

    procedure DoForEach(ItemAction: TItemAction; NodeAction: TNodeAction; Params: TActionParams);
    procedure DoForEachSelected(ItemAction: TItemAction; NodeAction: TNodeAction; Params: TActionParams; DoForAllChildren: Boolean);

    procedure FindItemByName(const Name: string);
    procedure ShowItemByName(const Name: string);

    procedure DrawItemPreview(Item: TItem; ACanvas: TCanvas; AX, AY: Integer);

    function GetNodeItem(Node: PVirtualNode): TItem;
    function GetFocusedParent: TItem;
    procedure SelectItem(Item: TItem; EditName: Boolean);
    procedure TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: TreeString);
    procedure TreeNewText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; NewText: TreeString);
    procedure RenderModeButClick(Sender: TObject);
    procedure TreeChecking(Sender: TBaseVirtualTree; Node: PVirtualNode; var NewState: TCheckState; var Allowed: Boolean);
    procedure TreeGetCellIsEmpty(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; var IsEmpty: Boolean);
    procedure TreeMeasureItem(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode; var NodeHeight: Integer);
    procedure TreeAfterCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; CellRect: TRect);
    procedure TreeHeaderClick(Sender: TVTHeader; Column: TColumnIndex; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
private
    PreviewTempBuffer: Pointer;
  protected
    AddingItem: TItem;
    // Tree column indices
    tcName, tcPreview: Integer;
  public
    OnTreeChange: TOnTreeChangeEvent;
    EditorTree: TItemsTree;
    procedure RefreshTree;
    // Callbacks
    procedure CBDelete(Node: PVirtualNode; Params: TActionParams);
    procedure CBMoveUp(Node: PVirtualNode; Params: TActionParams);
    procedure CBMoveDown(Node: PVirtualNode; Params: TActionParams);
    procedure CBMoveLeft(Node: PVirtualNode; Params: TActionParams);
    procedure CBMoveRight(Node: PVirtualNode; Params: TActionParams);
  end;

implementation

uses MainForm, C2EdUtil;

{$R *.dfm}

{ TItemsTree }

constructor TItemsTree.Create(ATree: TBaseVirtualTree);
begin
  Init(ATree);
end;

function TItemsTree.GetNodeText(Node: PVirtualNode; Column: Integer): string;
var NodeData: ^TItemNodeData;
begin
  Result := '';
  if Node = nil then Exit;
  NodeData := Tree.GetNodeData(Node);
  if NodeData^.Item = nil then Result := 'undefined' else begin
    case Column of
     -1, 0: Result := NodeData^.Item.Name;
      2: Result := NodeData^.Item.ClassName;
      3: Result := IntToStr(NodeData^.Item.GetItemSize(True)) + ' b';
      else Result := '';
    end;
  end;
end;

{ TItemsFrame }

procedure TItemsFrame.Init;
var i: Integer;
begin
  GetMem(PreviewTempBuffer, MaxPreviewSourceSize*MaxPreviewSourceSize*4);

  tcName     := -1;
  tcPreview  := -1;

  for i := 0 to Tree.Header.Columns.Count-1 do begin
    if Tree.Header.Columns[i].Text = 'Name'    then tcName    := i;
    if Tree.Header.Columns[i].Text = 'Preview' then tcPreview := i;
  end;
end;

destructor TItemsFrame.Destroy;
begin
  FreeMem(PreviewTempBuffer);
  inherited;
end;

procedure TItemsFrame.RefreshTree;

  function IsItemVisible(AItem: TItem): Boolean;
  begin
    Result := not App.IsServiceItem(AItem) or (App.Config.GetAsInteger('ShowServiceItems') > 0);
  end;

  procedure AddItem(Item: TItem; Node: PVirtualNode);
  var i, cnt: Integer; NodeData: ^TItemNodeData; NewNode: PVirtualNode;
  begin
    AddingItem := Item;
    if (AddingItem = nil) or (Node = nil) then Exit;

    NodeData       := Tree.GetNodeData(Node);
    NodeData^.Item := Item;

    cnt := 0;
    for i := 0 to Item.TotalChilds-1 do if IsItemVisible(Item.Childs[i]) then Inc(cnt);

    Tree.ChildCount[Node] := cnt;
    NewNode := Tree.GetFirstChild(Node);
    for i := 0 to Item.TotalChilds-1 do begin
      if IsItemVisible(Item.Childs[i]) then begin         // skip editor dummy and its childs
        AddItem(Item.Childs[i], NewNode);
        NewNode := Tree.GetNextSibling(NewNode);
      end;
    end;
  end;

begin
  Tree.RootNodeCount := 1;
  AddItem(Core.Root, Tree.RootNode.FirstChild);
  Tree.ReinitChildren(Tree.RootNode, True);
  Tree.Repaint;
end;

procedure TItemsFrame.TreeEditing(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; var Allowed: Boolean);
begin
  Allowed := Column <= 0;
end;

procedure TItemsFrame.TreeCompareNodes(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
var s1, s2: string;
begin
  s1 := EditorTree.GetNodeText(Node1, Column); s2 := EditorTree.GetNodeText(Node2, Column);
  Result := Ord(s1 > s2) - Ord(s1 < s2);
end;

procedure TItemsFrame.TreeInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode; var InitialStates: TVirtualNodeInitStates);
var NodeData: ^TItemNodeData; 
begin
  Node^.CheckType := ctNone;

  NodeData := Tree.GetNodeData(Node);
  if NodeData^.Item = nil then NodeData^.Item := AddingItem;

  if RenderModeBut.Down and ((NodeData^.Item is TVisible) or (NodeData^.Item is TLight) or
                             (NodeData^.Item is TRenderPass) or (NodeData^.Item is TTechnique) or
                             (NodeData^.Item is TBaseGUIItem)) then begin
    Node.CheckType := ctCheckBox;
    if isVisible in NodeData^.Item.State then
      Node.CheckState := csCheckedNormal else
        Node.CheckState := csUncheckedNormal;
  end;
  if ProcessModeBut.Down and ((NodeData^.Item is TBaseProcessing) or (NodeData^.Item is TDummyItem)) then begin
    Node.CheckType := ctCheckBox;
    if isProcessing in NodeData^.Item.State then
      Node.CheckState := csCheckedNormal
    else
      Node.CheckState := csUncheckedNormal;
  end;
  if BoundsModeBut.Down and (NodeData^.Item is TProcessing) then begin
    Node.CheckType := ctCheckBox;
    if isDrawVolumes in NodeData^.Item.State then
      Node.CheckState := csCheckedNormal
    else
      Node.CheckState := csUncheckedNormal;
  end;
//  Node.States :=
end;

procedure TItemsFrame.DoForEach(ItemAction: TItemAction; NodeAction: TNodeAction; Params: TActionParams);
var i: Integer; Node, Node2: PVirtualNode; NodeData: ^TItemNodeData;
begin
  Assert((@NodeAction <> nil) or (@ItemAction <> nil));
  Node := Tree.GetFirst;
  for i := 0 to Integer(Tree.TotalCount)-1 do begin
    Node2  := Tree.GetNext(Node);
    if (@ItemAction <> nil) then begin
      NodeData := Tree.GetNodeData(Node);
      ItemAction(NodeData^.Item, Params);
    end;
    if (@NodeAction <> nil) then NodeAction(Node, Params);
    Node := Node2;
  end;
end;

procedure TItemsFrame.DoForEachSelected(ItemAction: TItemAction; NodeAction: TNodeAction; Params: TActionParams; DoForAllChildren: Boolean);
var i: Integer; NodeData: ^TItemNodeData; SelNodes: TNodeArray; Item: TItem;
begin
  Assert((@NodeAction <> nil) or (@ItemAction <> nil));

  SelNodes := Tree.GetSortedSelection(not DoForAllChildren);

  for i := 0 to High(SelNodes) do begin                                          // First need to execute node action to handle item destroy
    if (@ItemAction <> nil) then begin
      NodeData := Tree.GetNodeData(SelNodes[i]);
      if Assigned(NodeData) then Item := NodeData^.Item;
    end;
    if (@NodeAction <> nil) then NodeAction(SelNodes[i], Params);
    if (@ItemAction <> nil) then ItemAction(Item, Params);
  end;
end;

procedure TItemsFrame.FindItemByName(const Name: string);
var Levels: BaseTypes.TStringArray; Level, TotalLevels: Integer;

  procedure FindItem(ParentNode: PVirtualNode);
  var i: Integer; Node: PVirtualNode;
  begin
    Node := Tree.GetFirstChild(ParentNode);
    i := ParentNode.ChildCount;
    for i := 0 to i-1 do begin
      if Tree.Text[Node, 0] = Levels[Level] then begin
        if Level = TotalLevels-1 then begin
          MainF.ActionSelectNoneExecute(nil);
          Tree.Selected[Node] := True;
          Tree.FocusedNode    := Node;
        end else begin
          Tree.Expanded[Node] := True;
          Inc(Level);
          FindItem(Node);
        end;
        Break;
      end;
      Node := Tree.GetNextSibling(Node);
    end;
  end;

begin
  TotalLevels := Split(Name, HierarchyDelimiter, Levels, False);

  if (TotalLevels = 0) or (Levels[0] <> Core.Root.Name) then Exit;

  Level := 1;
  FindItem(Tree.RootNode.FirstChild);
end;

procedure TItemsFrame.ShowItemByName(const Name: string);
var Item: TItem;
begin                     
  Item := Core.Root.GetItemByFullName(Name);
  if Item <> nil then begin
    if Item is TCamera then Core.Renderer.MainCamera := Item as TCamera;
    if Item is Resources.TResource then ShowResource(Item as Resources.TResource);
  end else
    Log(ClassName + '.ShowItemByName: Item "' + Name + '" not found', lkError);
end;

function TItemsFrame.GetNodeItem(Node: PVirtualNode): TItem;
var NodeData: ^TItemNodeData;
begin
  Result := nil;
  if Node = nil then Exit;
  NodeData := Tree.GetNodeData(Node);
  Result := NodeData^.Item;
end;

function TItemsFrame.GetFocusedParent: TItem;
begin
  Result := GetNodeItem(Tree.FocusedNode);
  if Result = nil then Result := Core.Root; 
end;

procedure TItemsFrame.SelectItem(Item: TItem; EditName: Boolean);
var i: Integer; NodeData: ^TItemNodeData; Node: PVirtualNode;
begin
  if Item = nil then Exit;
  Node := Tree.GetFirst;
  for i := 1 to Tree.TotalCount do begin
    NodeData := Tree.GetNodeData(Node);
    if NodeData.Item = Item then begin
      Tree.Selected[Node] := True;
      Tree.FocusedNode    := Node;
      if EditName then Tree.EditNode(Node, 0);
      Exit;
    end;
    Node := Tree.GetNext(Node);
  end;
end;

procedure TItemsFrame.TreeNewText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; NewText: TreeString);
begin
  if Column <= 0 then begin
    GetNodeItem(Node).Name := NewText;
    MainF.ItemsChanged := True;
  end;
end;

procedure TItemsFrame.RenderModeButClick(Sender: TObject);
begin
  RefreshTree;
end;

procedure TItemsFrame.TreeChecking(Sender: TBaseVirtualTree; Node: PVirtualNode; var NewState: TCheckState; var Allowed: Boolean);
var NodeData: ^TItemNodeData;
begin
  Allowed := True;
  NodeData := Tree.GetNodeData(Node);
  case NewState of
    csCheckedNormal: begin
      if RenderModeBut.Down then begin
        if (NodeData^.Item is TVisible) then TVisible(NodeData^.Item).Show;
        if (NodeData^.Item is TLight) or
           (NodeData^.Item is TRenderPass) or (NodeData^.Item is TTechnique) or
           (NodeData^.Item is TBaseGUIItem) then NodeData^.Item.State := NodeData^.Item.State + [isVisible];
      end;
      if ProcessModeBut.Down and (NodeData^.Item is TBaseProcessing) then
        NodeData^.Item.State := NodeData^.Item.State + [isProcessing];
      if BoundsModeBut.Down and (NodeData^.Item is TProcessing) then
        NodeData^.Item.State := NodeData^.Item.State + [isDrawVolumes];
    end;
    csUncheckedNormal: begin
      if RenderModeBut.Down then begin
        if (NodeData^.Item is TVisible) then TVisible(NodeData^.Item).Hide;
        if (NodeData^.Item is TLight) or
           (NodeData^.Item is TRenderPass) or (NodeData^.Item is TTechnique) or
           (NodeData^.Item is TBaseGUIItem) then NodeData^.Item.State := NodeData^.Item.State - [isVisible];
      end;
      if ProcessModeBut.Down and (NodeData^.Item is TBaseProcessing) then
        NodeData^.Item.State := NodeData^.Item.State - [isProcessing];
      if BoundsModeBut.Down and (NodeData^.Item is TProcessing) then
        NodeData^.Item.State := NodeData^.Item.State - [isDrawVolumes];
    end;
  end;
  MainF.ItemsChanged := True;
end;

procedure TItemsFrame.TreeGetCellIsEmpty(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; var IsEmpty: Boolean);
begin
  isEmpty := (Column = tcPreview) and not (GetNodeItem(Node) is TImageResource);
end;

procedure TItemsFrame.TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: TreeString);
begin
  CellText := EditorTree.GetNodeText(Node, Column);
end;

procedure TItemsFrame.TreeMeasureItem(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode; var NodeHeight: Integer);
begin
  if not Assigned(Core) then Exit;
  if (coVisible in Tree.Header.Columns[tcPreview].Options) and (GetNodeItem(Node) is TImageResource) then NodeHeight := MaxI(PreviewSize+3, NodeHeight);
end;

procedure TItemsFrame.CBDelete(Node: PVirtualNode; Params: TActionParams);
begin
  if not Assigned(Node) or not Assigned(GetNodeItem(Node)){ or not Assigned(GetNodeItem(Node).Parent)} then Exit;
  Tree.DeleteNode(Node);
end;

procedure TItemsFrame.CBMoveUp(Node: PVirtualNode; Params: TActionParams);
begin

end;

procedure TItemsFrame.CBMoveDown(Node: PVirtualNode; Params: TActionParams);
begin

end;

procedure TItemsFrame.CBMoveLeft(Node: PVirtualNode;  Params: TActionParams);
begin

end;

procedure TItemsFrame.CBMoveRight(Node: PVirtualNode; Params: TActionParams);
begin

end;

procedure TItemsFrame.TreeAfterCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; CellRect: TRect);
var X, Y: Integer;
begin
  X := (CellRect.Right  + CellRect.Left - PreviewSize) div 2;
  Y := (CellRect.Bottom + CellRect.Top  - PreviewSize) div 2;
  if Column = tcPreview then begin
    TargetCanvas.Pen.Color := 0;
    TargetCanvas.Rectangle(X-1, Y-1, X + PreviewSize+1, Y + PreviewSize+1);
    DrawItemPreview(GetNodeItem(Node), TargetCanvas, X, Y);
  end;
end;

procedure TItemsFrame.DrawItemPreview(Item: TItem; ACanvas: TCanvas; AX, AY: Integer);
var i, w, h, Level, DataFormat: Integer; Data: Pointer; ImageRes: TImageResource; PaletteSize: Integer; PaletteData: PPalette; Result: TBitmap;
begin
  Result := nil;
  if not (Item is TImageResource) then Exit;
  ImageRes := Item as TImageResource;
  if Assigned(ImageRes.PaletteResource) then begin
    PaletteSize := ImageRes.PaletteResource.TotalElements;
    PaletteData := ImageRes.PaletteResource.Data;
  end else begin
    PaletteSize := 0;
    PaletteData := nil;
  end;

  Result := TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.Width       := PreviewSize;
  Result.Height      := PreviewSize;

  if ImageRes is TMegaImageResource then begin
    Level := ImageRes.ActualLevels;
    while (Level > 0) and
          (ImageRes.LevelInfo[Level].Width + ImageRes.LevelInfo[Level].Height < 2*PreviewSize) do Dec(Level);

    w := MinI(MaxPreviewSourceSize, ImageRes.LevelInfo[Level].Width);
    h := MinI(MaxPreviewSourceSize, ImageRes.LevelInfo[Level].Height);
    Data := PreviewTempBuffer;

    (ImageRes as TMegaImageResource).LoadRectAsRGBA(GetRect(0, 0, w, h), Level, PreviewTempBuffer, w);
    DataFormat := pfA8R8G8B8;
  end else begin
    w := ImageRes.Width;
    h := ImageRes.Height;
    Data := ImageRes.Data;
    DataFormat := ImageRes.Format;
  end;
  if Data <> nil then begin
    CreateThumbnail(DataFormat, w, GetRect(0, 0, w, h), Data, PaletteSize, PaletteData,
                    pfA8R8G8B8, PreviewSize, PreviewSize, PreviewTempBuffer);//Result.ScanLine[0]);
    for i := 0 to PreviewSize-1 do Move(PtrOffs(PreviewTempBuffer, i*PreviewSize*4)^, Result.ScanLine[i]^, PreviewSize*4);
  end;
  ACanvas.Draw(AX, AY, Result);
  FreeAndNil(Result);
end;

procedure TItemsFrame.TreeHeaderClick(Sender: TVTHeader; Column: TColumnIndex; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  EditorTree.HeaderClick(Column, Button);
end;

end.

