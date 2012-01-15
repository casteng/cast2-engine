unit PropFrame;

interface

uses
  BaseTypes, Basics, BaseStr, Props, BaseClasses, Models,
  C2EdMain,
  TreeViews,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, VirtualTrees;

const GroupMask = 1 shl 31;

type
  {$IFDEF UNICODE}
  TreeString = string;
  {$ELSE}
  TreeString = WideString;
  {$ENDIF}

  TPropEditOp = class(Models.TOperation)
  protected
    Item: TItem;
    Props: TProperties;
    procedure DoApply; override;
    function DoMerge(AOperation: Models.TOperation): Boolean; override;
  public
    procedure Init(AItem: TItem; AProps: TProperties);
    destructor Destroy; override;
  end;

  TPropsTree = class(TEditorTree)
    Properties: Props.TProperties;
    constructor Create(ATree: TBaseVirtualTree; AProperties: Props.TProperties; AOnAcceptEdit: TPropertyEditorEvent);
    destructor Destroy; override;
    function GetNodeText(Node: PVirtualNode; Column: Integer): string; override;
  end;

  TPropsFrame = class(TFrame)
    Tree: TVirtualStringTree;
    procedure TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: TreeString);
    procedure TreeCompareNodes(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
    procedure TreeFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
    procedure TreeExpanded(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure TreeColumnResize(Sender: TVTHeader; Column: TColumnIndex);
    procedure TreeAfterCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; CellRect: TRect);

    procedure RefreshTree;
    procedure UpdateTree;
    procedure TreeKeyAction(Sender: TBaseVirtualTree; var CharCode: Word; var Shift: TShiftState; var DoDefault: Boolean);

  private
    { Private declarations }
  public
    EditorTree: TPropsTree;
    Properties: Props.TProperties;
    procedure ActAddPropertiesOf(Item: TItem; Params: TActionParams);
    procedure ActAppleNodeProperties(Item: TItem; Params: TActionParams);
  end;

implementation

{$R *.dfm}

procedure TPropsFrame.TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: TreeString);
begin
  CellText := EditorTree.GetNodeText(Node, Column);
end;

procedure TPropsFrame.TreeCompareNodes(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
var s1, s2: string;
begin
  s1 := EditorTree.GetNodeText(Node1, Column);
  s2 := EditorTree.GetNodeText(Node2, Column);
  Result := Ord(s1 > s2) - Ord(s1 < s2);
end;

procedure TPropsFrame.RefreshTree;
type
  TPropStr = ShortString;
  TPropNode = record
    Name: TPropStr;
    Index: Integer;
  end;

  var Strs: BaseTypes.TStringArray;

  procedure FillLevel(Node: PVirtualNode; const Path: TPropStr; Level, StartProp: Integer);
  var
    i, Num, CurLevel, PresentAtIndex: Integer;
    PropNodes: array of TPropNode;
    NodeData: ^TPropNodeData;

    function NotNamePresent(const AName: TPropStr): Integer;
    begin
      for Result := 0 to High(PropNodes) do if PropNodes[Result].Name = AName then Exit;
      Result := -1;
    end;

    function MatchPath: Boolean;
    var i, CurPos: Integer;
    begin
      Result := False;
      CurPos := 1;
      for i := 0 to Level-2 do begin
        if Strs[i] <> Copy(Path, CurPos, Length(Strs[i])) then Exit;
        Inc(CurPos, Length(Strs[i]));
      end;
      Result := True;
    end;

  begin
    SetLength(PropNodes, 128);
    Num := 0;
    for i := StartProp to Properties.TotalProperties-1 do begin
      CurLevel := Split(Properties.GetNameByIndex(i), '\', Strs, False);

      if CurLevel >= Level then begin                                              // The property has enough levels
//        for j := 0 to Level-2 do s := s + Strs[j];
        if MatchPath then begin                                                    // First Level levels of the property matches the current path
          PresentAtIndex := NotNamePresent(Strs[Level-1]);
          if PresentAtIndex <> -1 then begin                                       // Level name already present
            if (PropNodes[PresentAtIndex].Index and GroupMask <> 0) and (Level = CurLevel) then  // And erroneously threated as a group
              PropNodes[PresentAtIndex].Index := i;                                              // Fix it
          end else begin                                                           // New group or property found
            Inc(Num);
            if Length(PropNodes) < Num then SetLength(PropNodes, Num);
            PropNodes[Num-1].Name := Strs[Level-1];
            PropNodes[Num-1].Index := i or
  //          (GroupMask * Ord((Level <> CurLevel) and not Properties.Exists(Path + PropNodes[Num-1].Name)));
            (GroupMask * Ord(Level <> CurLevel));
          end;  
        end;
      end;
    end;

    Tree.ChildCount[Node] := Num;
    Node := Tree.GetFirstChild(Node);
    for i := 0 to Num-1 do begin
      NodeData := Tree.GetNodeData(Node);
      NodeData^.Index := PropNodes[i].Index;
      NodeData^.Level := Level-1;

      FillLevel(Node, Path + PropNodes[i].Name, Level+1, i);

      Node := Tree.GetNextSibling(Node);
    end;
  end; { FillLevel }

begin
  Tree.BeginUpdate;

  FillLevel(Tree.RootNode, '', 1, 0);

  Tree.EndUpdate;
  EditorTree.Editor.UpdateEditorPos;
end;

procedure TPropsFrame.TreeFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
begin
  if EditorTree.Editor <> nil then EditorTree.Editor.UpdateEditorPos;
end;

procedure TPropsFrame.TreeExpanded(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  if EditorTree.Editor <> nil then EditorTree.Editor.UpdateEditorPos;
end;

procedure TPropsFrame.TreeColumnResize(Sender: TVTHeader; Column: TColumnIndex);
begin
  if EditorTree.Editor <> nil then EditorTree.Editor.UpdateEditorPos;
end;

procedure TPropsFrame.TreeAfterCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; CellRect: TRect);
var Prop: PProperty; NodeData: ^TPropNodeData; PanelX, PanelWidth: Integer; C1, C2: Longword;
begin
  if Column <> 1 then Exit;
  NodeData := Tree.GetNodeData(Node);
  Prop := Properties.GetProperty(Properties.GetNameByIndex(NodeData^.Index));
  if Prop = nil then Exit;
  if Prop^.ValueType = vtColor then begin
    TargetCanvas.Pen.Width := 1; TargetCanvas.Pen.Mode := pmCopy; TargetCanvas.Pen.Style := psSolid;
    TargetCanvas.Pen.Color := 0; TargetCanvas.Brush.Style := bsSolid;

    PanelWidth := CellRect.Bottom-CellRect.Top-4;
    PanelX := CellRect.Right - PanelWidth*2 - 2;

    EditorTree.Editor.GetPanelsColors(Prop^.Value, C1, C2);

    TargetCanvas.Brush.Color := C1;
    TargetCanvas.FillRect(Rect(PanelX + 2, CellRect.Top + 3, PanelX + PanelWidth-1, CellRect.Top + PanelWidth + 1));
    TargetCanvas.Brush.Color := 0;
    TargetCanvas.FrameRect(Rect(PanelX + 1, CellRect.Top + 2, PanelX + PanelWidth, CellRect.Top+ PanelWidth + 2));

    TargetCanvas.Brush.Color := C2;
    TargetCanvas.FillRect(Rect(PanelX + PanelWidth + 2, CellRect.Top + 3, PanelX + PanelWidth*2-1, CellRect.Top + PanelWidth + 1));
    TargetCanvas.Brush.Color := 0;
    TargetCanvas.FrameRect(Rect(PanelX + PanelWidth + 1, CellRect.Top + 2, PanelX + PanelWidth*2, CellRect.Top+ PanelWidth + 2));
  end;
end;

{ TPropsTree }

constructor TPropsTree.Create(ATree: TBaseVirtualTree; AProperties: Props.TProperties; AOnAcceptEdit: TPropertyEditorEvent);
begin
  Init(ATree);
  Properties := AProperties;
  Editor := TPropEditor.Create(Tree, Properties);
  Editor.OnAcceptEdit := AOnAcceptEdit;
end;

destructor TPropsTree.Destroy;
begin
  FreeAndNil(Editor);
  inherited;
end;

function TPropsTree.GetNodeText(Node: PVirtualNode; Column: Integer): string;
var Prop: PProperty; NodeData: ^TPropNodeData; Strs: BaseTypes.TStringArray; Level: Integer; Value: Double;
begin
  Result := '';
  if Node = nil then Exit;
  NodeData := Tree.GetNodeData(Node);
  Prop := Properties.GetProperty(Properties.GetNameByIndex(NodeData^.Index and not GroupMask));
  if Prop = nil then Result := 'undefined' else begin
    Level := Split(Prop^.Name, '\', Strs, False);
    if NodeData^.Level+1 = Level then case Column of
     -1, 0: Result := Strs[Level-1];
      1: begin
        if (Prop^.ValueType = vtSingle) and IsFloat(Prop^.Value) then begin
          Value := StrToFloat(Prop^.Value);
          Result := FloatToStrF(Value, ffGeneral, 7, 3);
        end else
          Result := Prop^.Value;
      end;
      2: Result := Properties.GetTypeAsString(NodeData^.Index and not GroupMask);
    end else case Column of
     -1, 0: if NodeData^.Level < Level then Result := Strs[NodeData^.Level] else Result := '<Error>';
      1, 2: Result := 'Group';
    end;
  end;
end;

procedure TPropsFrame.UpdateTree;
var Node: PVirtualNode; //    NodeData: ^TPropNodeData;
begin
  Node := Tree.GetFirstVisible;
  while Node <> nil do begin
    Tree.RepaintNode(Node);
    Node := Tree.GetNextVisible(Node);
  end;
end;

procedure TPropsFrame.ActAddPropertiesOf(Item: TItem; Params: TActionParams);
begin
  if Assigned(Item) then Item.AddProperties(Properties);
end;

procedure TPropsFrame.ActAppleNodeProperties(Item: TItem; Params: TActionParams);
var Op: TPropEditOp;
begin
  Op := TPropEditOp.Create;
  Op.Init(Item, (Params as TPropertiesParams).Properties);
  App.AddOperation(Op);
//  Item.SetProperties((Params as TPropertiesParams).Properties);
//  Item.GetProperties(Properties);
end;

procedure TPropsFrame.TreeKeyAction(Sender: TBaseVirtualTree; var CharCode: Word; var Shift: TShiftState; var DoDefault: Boolean);
begin
  DoDefault := True;
  if (CharCode = VK_Up) or (CharCode = VK_Down) then EditorTree.Editor.SetLastUpDown;
end;

{ TPropEditOp }

procedure TPropEditOp.Init(AItem: TItem; AProps: TProperties);
begin
  Item  := AItem;
  Props := TProperties.Create;
  Props.Merge(AProps, True);
end;

destructor TPropEditOp.Destroy;
begin
  FreeAndNil(Props);
  inherited;
end;

procedure TPropEditOp.DoApply;
var TempProps: TProperties;
begin
  TempProps := TProperties.Create;
  Item.GetProperties(TempProps);
  Item.SetProperties(Props);
  Props.Free;
  Props := TempProps;
end;

function TPropEditOp.DoMerge(AOperation: Models.TOperation): Boolean;
var i: Integer; NewProps: TProperties;
begin
  Result := False; 
  if not (AOperation is TPropEditOp) or (Item <> TPropEditOp(AOperation).Item) then Exit;

  NewProps := TPropEditOp(AOperation).Props;
  Assert(Assigned(NewProps));

  i := NewProps.TotalProperties-1;
  while (i >= 0) and Props.Exists(NewProps.GetNameByIndex(i)) do Dec(i);

  Result := i < 0;

  if Result and not (ofApplied in Flags) then Props.Merge(NewProps, True);
end;

end.
