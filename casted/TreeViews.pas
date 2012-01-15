unit treeviews;

interface

uses
  VCLHelper,
  BaseTypes, Basics, BaseStr, Props, Base2D, BaseClasses, Cast2,
  Windows, Messages, Classes, StdCtrls, ExtCtrls, ComCtrls, Controls, Forms, Dialogs, Buttons,
  VirtualTrees;

type
  TPropertyEditorEvent = procedure(const PropertyModified: TProperty) of object;

  TPropNodeData = record
    Index, Level: Integer;
  end;
  TItemNodeData = record
    Item: TItem;
  end;

  TPropEditor = class
//    WasModified: Boolean;
    OnAcceptEdit: TPropertyEditorEvent;
    IsEditing: Boolean;
    constructor Create(ATree: TBaseVirtualTree; AProperties: TProperties);
    destructor Destroy; override;

    procedure EditKeyPress(Sender: TObject; var Key: Char);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditLostFocus(Sender: TObject);
    procedure EditGetFocus(Sender: TObject);
    procedure EditResetFocus(Sender: TObject);
    procedure EditChanged(Sender: TObject);
    procedure TrackbarChanged(Sender: TObject);

    procedure SpeedBtn1Click(Sender: TObject);
    procedure SpeedBtn2Click(Sender: TObject);

    procedure UpdateEditorPos;
    procedure CheckBoxExit(Sender: TObject);
    procedure CheckBoxClick(Sender: TObject);
    procedure PanelClick(Sender: TObject);
    procedure PanelMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure AcceptEdit;
    procedure CancelEdit;

    procedure SetLastUpDown;

    procedure GetPanelsColors(Value: string; var Color1, Color2: Longword);
  private
    SliderRangeMin, SliderRangeMax: Double;
    SliderInt, LastEventIsUpDown: Boolean;
  protected
    Tree: TBaseVirtualTree;
    Properties: TProperties;
    AllowAcceptEdit: Boolean;
// Standard edit controls
    SpeedBtn1, SpeedBtn2: TSpeedButton;
    CBox: TComboBox;
    Edit: TEdit;
    ChBox: TCheckBox;
    ColorPanel, AlphaPanel: TPanel;
    TrackBar: TTrackBar;
// Additional controls
    ColorDialog: TColorDialog;
    function GetComposedColor: string;
    procedure HideControls;
  end;

  TTreeState = record
    NodeVisible: array of string; TotalVisible: Integer;
    FocusedName: string;
  end;

  TEditorTree = class
    Editor: TPropEditor;
    Tree: TBaseVirtualTree;
    procedure Init(ATree: TBaseVirtualTree);
    function GetNodeText(Node: PVirtualNode; Column: Integer): string; virtual; abstract;
    function SaveTreeState: TTreeState;
    procedure RestoreTreeState(State: TTreeState);
    procedure HeaderClick(Column: TColumnIndex; Button: TMouseButton); 
  end;

implementation

uses SysUtils, MainForm;

{ TPropEditor }

constructor TPropEditor.Create(ATree: TBaseVirtualTree; AProperties: TProperties);
begin
  Tree := ATree;
  Properties := AProperties;

  CBox             := TComboBox.Create(Tree.Owner);
  CBox.Parent      := Tree;
  CBox.Style       := csDropDownList;
  CBox.OnKeyPress  := EditKeyPress;
  CBox.OnKeyDown   := EditKeyDown;
  CBox.OnEnter     := EditGetFocus;
  CBox.OnExit      := EditLostFocus;
  CBox.OnChange    := EditChanged;
  CBox.Hide;

  Edit             := TEdit.Create(Tree.Owner);
  Edit.Parent      := Tree;
  Edit.OnKeyPress  := EditKeyPress;
  Edit.OnKeyDown   := EditKeyDown;
  Edit.OnEnter     := EditGetFocus;
  Edit.OnExit      := EditLostFocus;
  Edit.OnChange    := EditChanged;
  Edit.Hide;

  SpeedBtn1         := TSpeedButton.Create(Tree.Owner);
  SpeedBtn1.Name    := 'SButFindLinked';
  SpeedBtn1.Parent  := Tree;
  SpeedBtn1.Hint    := 'Click to find linked object';
  SpeedBtn1.OnClick := SpeedBtn1Click;

  SpeedBtn2        := TSpeedButton.Create(Tree.Owner);
  SpeedBtn2.Name    := 'SButExecLinked';
  SpeedBtn2.Parent := Tree;
  SpeedBtn2.Hint   := 'Click to execute default action of linked object';
  SpeedBtn2.OnClick := SpeedBtn2Click;

  ChBox            := TCheckBox.Create(Tree.Owner);
  ChBox.Parent     := Tree;
  ChBox.OnKeyPress := EditKeyPress;
  ChBox.OnKeyUp    := EditKeyDown;                       // OnKeyDown does not occur (!)
//  ChBox.OnKeyDown  := EditKeyDown;                       // OnKeyDown does not occur (!)
  ChBox.OnClick    := EditChanged;
//  ChBox.OnEnter    := EditResetFocus;
  ChBox.OnExit     := nil;
  ChBox.OnClick    := CheckBoxClick;
  ChBox.OnExit     := CheckBoxExit;
  ChBox.TabStop    := True;
  ChBox.TabOrder   := 0;
  ChBox.Hide;

  TrackBar := TTrackBar.Create(Tree.Owner);
  TrackBar.Parent      := Tree.Parent;
  TrackBar.ThumbLength := 14;
  TrackBar.Max         := 10000;
  TrackBar.PageSize    := 1000;
  TrackBar.Frequency   := 1000;
  TrackBar.OnChange    := TrackbarChanged;
  TrackBar.Hide;

  ColorPanel             := TPanel.Create(Tree.Owner);
  ColorPanel.Parent      := Tree;
//  ColorPanel.OnClick     := PanelClick;
  ColorPanel.OnMouseUp   := PanelMouseUp;
  ColorPanel.BevelOuter  := bvNone;
  ColorPanel.BorderStyle := bsSingle;
  ColorPanel.Ctl3D       := False;
  ColorPanel.Hide;

  AlphaPanel             := TPanel.Create(Tree.Owner);
  AlphaPanel.Parent      := Tree;
//  AlphaPanel.OnClick     := PanelClick;
  AlphaPanel.OnMouseUp   := PanelMouseUp;
  AlphaPanel.BevelOuter  := bvNone;
  AlphaPanel.BorderStyle := bsSingle;
  AlphaPanel.Ctl3D       := False;
  AlphaPanel.Hide;

  ColorDialog            := TColorDialog.Create(Tree.Owner);
  ColorDialog.Options    := [cdFullOpen, cdAnyColor];

  AllowAcceptEdit := False;
end;

destructor TPropEditor.Destroy;
begin
{  FreeAndNil(SpeedBtn1);
  FreeAndNil(SpeedBtn2);
  FreeAndNil(CBox);
  FreeAndNil(Edit);
  FreeAndNil(ChBox);
  FreeAndNil(ColorPanel);
  FreeAndNil(AlphaPanel);
  FreeAndNil(TrackBar);
  FreeAndNil(ColorDialog);}
  inherited;
end;

procedure TPropEditor.EditKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #27: CancelEdit;
    #13: AcceptEdit;
  end;
end;

procedure TPropEditor.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

  procedure ForwardEvent;
  begin
    Tree.SetFocus;
    SendMessage(Tree.Handle, WM_KEYDOWN, Key, 0);
  end;

begin
  if (Key = VK_Up) or (Key = VK_Down) then begin
    // Hack to avoid VCL or WinAPI bug
    if not LastEventIsUpDown or not (Sender is TCheckBox) then ForwardEvent;
    LastEventIsUpDown := not (Sender is TCheckBox);
  end;

  if ((Key = VK_Left) or (Key = VK_Right)) then
    if not (Sender is TEdit) then ForwardEvent else with Sender as TEdit do
      if (Key = VK_Left) and (SelStart = 0) or (Key = VK_Right) and (SelStart = Length(Text)) then ForwardEvent;

  if Key = 27 then CancelEdit;
  if Key = 13 then begin
    AcceptEdit;
    Tree.SetFocus;
    SendMessage(Tree.Handle, WM_KEYDOWN, VK_DOWN, 0);
  end;
end;

procedure TPropEditor.EditLostFocus(Sender: TObject);
begin
//  if Tree.UpdateCount = 0 then AcceptEdit;
//  while Tree.UpdateCount > 0 do ;
  AcceptEdit;
end;

procedure TPropEditor.HideControls;
begin
  TrackBar.Hide;
  CBox.Hide;
  ChBox.Hide;
  Edit.Hide;
  SpeedBtn1.Hide;
  SpeedBtn2.Hide;
  ColorPanel.Hide;
  AlphaPanel.Hide;
end;

procedure TPropEditor.UpdateEditorPos;

const SliderHeight = 20;

  function ParseSliderDesc(const s: string): Boolean;
  var i: Integer;
  begin
    Result := False;
    i := Pos('-', s);
    if i = 0 then Exit;
    SliderRangeMin := StrToRealDef(Copy(s, 1, i-1), 0);
    SliderRangeMax := StrToRealDef(Copy(s, i+1, Length(s)), -1);
    if SliderRangeMin > SliderRangeMax then Exit;
    Result := True;
  end;

  function ValueToSlider(const Value: string): Integer;
  begin
    if SliderRangeMax <> SliderRangeMin then
      Result := Round((StrToFloatDef(Value, 0) - SliderRangeMin) / (SliderRangeMax - SliderRangeMin) * TrackBar.Max)
    else
      Result := Round(SliderRangeMin);
  end;

var
  NewPoint: TPoint; Rect1, Rect2: TRect; PanelX, PanelWidth: Integer;
  Prop: PProperty; NodeData: ^TPropNodeData;
  C1, C2: Longword;
  OldAllowAcceptEdit: Boolean;
  Value: Double;
begin
// Hide all editors
  OldAllowAcceptEdit := AllowAcceptEdit;
  AllowAcceptEdit := False;

  HideControls;

  AllowAcceptEdit := OldAllowAcceptEdit;

  if Tree.FocusedNode = nil then Exit;

  NodeData := Tree.GetNodeData(Tree.FocusedNode);
  if NodeData = nil then Exit;
  Prop := Properties.GetProperty(Properties.GetNameByIndex(NodeData^.Index));
  if Prop = nil then Exit;

  if (Tree.FocusedColumn <> 1) or (poReadOnly in Prop^.Options) then Exit;

  Rect1 := Tree.GetDisplayRect(Tree.FocusedNode, Tree.FocusedColumn, True);
  Rect2 := Tree.GetDisplayRect(Tree.FocusedNode, Tree.FocusedColumn, False);

  IsEditing := False;

  CBox.Enabled       := not (poReadOnly in Prop^.Options);
  ChBox.Enabled      := not (poReadOnly in Prop^.Options);
  Edit.Enabled       := not (poReadOnly in Prop^.Options);
  ColorPanel.Enabled := not (poReadOnly in Prop^.Options);
  AlphaPanel.Enabled := not (poReadOnly in Prop^.Options);

  case Prop^.ValueType of
    vtNat, vtInt, vtSingle, vtDouble, vtString, vtObjectLink: begin
      if (Prop^.ValueType = vtSingle) and IsFloat(Prop^.Value) then begin
        Value := StrToFloat(Prop^.Value);
        Edit.Text := FloatToStrF(Value, ffGeneral, 7, 3);
      end else
        Edit.Text := Prop^.Value;
      if Prop^.ValueType = vtObjectLink then begin
        PanelWidth := Rect2.Bottom-Rect1.Top-4;
        PanelX     := Rect2.Right - PanelWidth*2+1;
        
        SpeedBtn1.SetBounds(PanelX                 , Rect1.Top+2, PanelWidth-2, PanelWidth-1);
        SpeedBtn2.SetBounds(PanelX + PanelWidth - 1, Rect1.Top+2, PanelWidth-2, PanelWidth-1);
        SpeedBtn1.Show;
        SpeedBtn2.Show;
        Edit.SetBounds(Rect1.Left, Rect1.Top-1, MaxI(0, PanelX - Rect1.Left - 1), Rect2.Bottom-Rect1.Top+1);
      end else Edit.SetBounds(Rect1.Left, Rect1.Top-1, Rect2.Right-Rect1.Left, Rect2.Bottom-Rect1.Top+1+SliderHeight);
      Edit.Show;
      if Edit.Enabled then Edit.SetFocus;

      if ((Prop^.ValueType = vtNat) or (Prop^.ValueType = vtInt) or (Prop^.ValueType = vtSingle)) and
          ParseSliderDesc(Prop^.Enumeration) then begin
        SliderInt := not (Prop^.ValueType = vtSingle);
        NewPoint := Tree.ClientToScreen(Point(Rect1.Left, Rect2.Bottom-4));
        NewPoint := TrackBar.Parent.ScreenToClient(NewPoint);
        TrackBar.SetBounds(NewPoint.X, NewPoint.Y, Rect2.Right-Rect1.Left, SliderHeight);
        TrackBar.Position := ValueToSlider(Prop^.Value);
        TrackBar.Parent := Edit;
        TrackBar.Show;
      end;

      IsEditing := True;
    end;
    vtColor: begin
      PanelWidth := Rect2.Bottom-Rect1.Top-4;
      PanelX     := Rect2.Right - PanelWidth*2+1;
      Edit.Text  := Prop^.Value;
      Edit.SetBounds(Rect1.Left, Rect1.Top-1, MaxI(0, PanelX - Rect1.Left - 1), Rect2.Bottom-Rect1.Top+1);
      Edit.Show;
      if Edit.Enabled then Edit.SetFocus;
      IsEditing := True;
      ColorPanel.SetBounds(PanelX                 , Rect1.Top+2, PanelWidth-2, PanelWidth-1);
      AlphaPanel.SetBounds(PanelX + PanelWidth - 1, Rect1.Top+2, PanelWidth-2, PanelWidth-1);
      GetPanelsColors(Prop^.Value, C1, C2);
      ColorPanel.Color := C1;
      ColorPanel.Show;
      AlphaPanel.Color := C2;
      AlphaPanel.Show;
      SendMessage(Tree.Handle, WM_RBUTTONUP, MK_LBUTTON, 0);  // To make the color dialog invoke when clicking on a unfocused color box
    end;
    vtBoolean: begin
      ChBox.Checked := Prop^.Value = OnOffStr[True];
      ChBox.Caption := Prop^.Value;
      ChBox.SetBounds(Rect1.Left, Rect1.Top, Rect2.Right-Rect1.Left, Rect2.Bottom-Rect1.Top-1);
      ChBox.Show;
      if ChBox.Enabled then ChBox.SetFocus;
    end;
    vtEnumerated: begin
      CBox.Items.Clear;
      SplitToTStrings(Prop^.Enumeration, StringDelimiter, CBox.Items, False, False);
      CBox.ItemIndex := CBox.Items.IndexOf(Prop^.Value);
      CBox.SetBounds(Rect1.Left, Rect1.Top-1, Rect2.Right-Rect1.Left, Rect2.Bottom-Rect1.Top);
      CBox.Show;
      if CBox.Enabled then CBox.SetFocus;
    end;
    else Exit;
  end;
end;

procedure TPropEditor.AcceptEdit;
var
  j: Integer;
  Prop: PProperty; NodeData: ^TPropNodeData;
  fs: TFormatSettings; f: Extended; i: Int64; e: Integer; s: string;
  Enums: BaseTypes.TStringArray;
  OldAllowAcceptEdit: Boolean;
begin
  if not AllowAcceptEdit or (Tree.FocusedNode = nil) then Exit;

  NodeData := Tree.GetNodeData(Tree.FocusedNode);
  if (Tree.FocusedColumn <> 1) or (NodeData = nil) then Exit;
  Prop := Properties.GetProperty(Properties.GetNameByIndex(NodeData^.Index));
  if Prop = nil then Exit;
// Validate value
  case Prop^.ValueType of
    vtNat, vtInt: begin
      Val(Edit.Text, i, e);
      if (e <> 0) or ( (Prop^.ValueType = vtNat) and (i < 0) ) then Exit;
    end;
    vtSingle: begin
      s := Copy(Edit.Text, 1, Length(Edit.Text));
      for j := 1 to Length(s) do if s[j] = ',' then s[j] := '.';
      GetLocaleFormatSettings(0, fs);
      fs.DecimalSeparator := '.';
      if not TextToFloat(PChar(s), f, fvExtended, fs) then Exit;
      s := '';
    end;
  end;
  case Prop^.ValueType of
    vtNat, vtInt, vtSingle, vtString, vtObjectLink: Properties[Properties.GetNameByIndex(NodeData^.Index)] := Edit.Text;
    vtColor: begin
      Properties[Properties.GetNameByIndex(NodeData^.Index)] := Edit.Text;
    end;
    vtBoolean: begin
      Split(Prop^.Enumeration, StringDelimiter, Enums, False);
      Properties[Prop^.Name] := Enums[Ord(ChBox.Checked)];
      Enums := nil;
    end;
    vtEnumerated: Properties[Prop^.Name] := CBox.Text;
    else Exit;
  end;

  OldAllowAcceptEdit := AllowAcceptEdit;
  AllowAcceptEdit := False;
  Tree.SetFocus;
  AllowAcceptEdit := OldAllowAcceptEdit;

  Prop := Properties.GetProperty(Properties.GetNameByIndex(NodeData^.Index));         // Read the fresh data
  if Prop = nil then Exit;

  if Assigned(OnAcceptEdit) then OnAcceptEdit(Prop^);
  AllowAcceptEdit := False;
end;

procedure TPropEditor.CancelEdit;
begin
  UpdateEditorPos;
  Tree.SetFocus;
  AllowAcceptEdit := False;
end;

procedure TPropEditor.SetLastUpDown;
begin
  LastEventIsUpDown := True;
end;

procedure TPropEditor.CheckBoxClick(Sender: TObject);
begin
  if not (Sender is TCheckBox) then Exit;
  (Sender as TCheckBox).Caption := OnOffStr[(Sender as TCheckBox).Checked];
  EditChanged(Sender);
end;

procedure TPropEditor.CheckBoxExit(Sender: TObject);
begin
  AcceptEdit;
end;

procedure TPropEditor.PanelClick(Sender: TObject);
begin
  ColorDialog.Color := (Sender as TPanel).Color;
  if ColorDialog.Execute then (Sender as TPanel).Color := ColorDialog.Color;
  Edit.Text := GetComposedColor;
  AcceptEdit;
end;

procedure TPropEditor.PanelMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  PanelClick(Sender);
end;

procedure TPropEditor.GetPanelsColors(Value: string; var Color1, Color2: Longword);
var Color: Longword;
begin
  if Value[1] = '#' then Value[1] := '$' else Exit;
  Color := Longword(StrToIntDef(Value, Integer($80808080)));
  Color1 := ColorToVCLColor(GetColor(Color and $FFFFFF));
  Color2 := ColorToVCLColor(GetColor((Color shr 24) shl 16 + (Color shr 24) shl 8 + Color shr 24));
end;

function TPropEditor.GetComposedColor: string;
var C: TColor;
begin
  C := VCLColorToColor(ColorPanel.Color);
  C.A := GetIntensity(VCLColorToColor(AlphaPanel.Color));
  Result := '#' + IntToHex(C.C, 8);
end;

procedure TPropEditor.EditGetFocus(Sender: TObject);
begin
  AllowAcceptEdit := False;
end;

procedure TPropEditor.EditResetFocus(Sender: TObject);
begin
  Tree.SetFocus;
end;

procedure TPropEditor.EditChanged(Sender: TObject);
begin
  AllowAcceptEdit := True;
end;

procedure TPropEditor.TrackbarChanged(Sender: TObject);
var Value: Double;
begin
  Value := TrackBar.Position / TrackBar.Max * (SliderRangeMax - SliderRangeMin) + SliderRangeMin;
  if SliderInt then Edit.Text := IntToStr(Round(Value)) else Edit.Text := FloatToStr(Value);
  AcceptEdit;
  Edit.SetFocus;
  Edit.SelectAll;
end;

procedure TPropEditor.SpeedBtn1Click(Sender: TObject);
begin
  MainF.ItemsFrame1.FindItemByName(Edit.Text);
end;

procedure TPropEditor.SpeedBtn2Click(Sender: TObject);
begin
  MainF.ItemsFrame1.ShowItemByName(Edit.Text);
end;

{ TEditorTree }

procedure TEditorTree.Init(ATree: TBaseVirtualTree);
begin
  Tree := ATree;
end;

function TEditorTree.SaveTreeState: TTreeState;
var i: Integer; Node: PVirtualNode;
begin
  if Tree.FocusedNode <> nil then Result.FocusedName := GetNodeText(Tree.FocusedNode, 0) else Result.FocusedName := #1#2#4#11;

  SetLength(Result.NodeVisible, Tree.VisibleCount);
// Save expansion
  Result.TotalVisible := 0;
  Node := Tree.GetFirstVisible;
  for i := 0 to Integer(Tree.VisibleCount)-1 do begin
    if Tree.Expanded[Node] then begin
      Result.NodeVisible[Result.TotalVisible] := GetNodeText(Node, 0);
      Inc(Result.TotalVisible);
    end;
    Node := Tree.GetNext(Node);
  end;
end;

procedure TEditorTree.RestoreTreeState(State: TTreeState);
var i: Integer; Node: PVirtualNode;
begin
// Restore expansion
  i := 0;
  Node := Tree.GetFirstVisible;
  while (Node <> nil) do begin
    if (i < State.TotalVisible) and (GetNodeText(Node, 0) = State.NodeVisible[i]) then begin
      Tree.Expanded[Node] := True;
      Inc(i);
    end;
    if GetNodeText(Node, 0) = State.FocusedName then begin
      Tree.FocusedNode := Node;
    end;
    Node := Tree.GetNext(Node);
  end;

  State.NodeVisible := nil;
end;

procedure TEditorTree.HeaderClick(Column: TColumnIndex; Button: TMouseButton);
begin
  if mbLeft <> Button then Exit;
  if (Tree as TVirtualStringTree).Header.SortColumn = Column then begin
    if (Tree as TVirtualStringTree).Header.SortDirection = sdAscending then
     (Tree as TVirtualStringTree).Header.SortDirection := sdDescending else
       (Tree as TVirtualStringTree).Header.SortColumn := -1;
  end else begin
    (Tree as TVirtualStringTree).Header.SortColumn := Column;
    (Tree as TVirtualStringTree).Header.SortDirection := sdAscending;
  end;

  if (Tree as TVirtualStringTree).Header.SortColumn = -1 then
    (Tree as TVirtualStringTree).TreeOptions.AutoOptions := (Tree as TVirtualStringTree).TreeOptions.AutoOptions - [toAutoSort] else begin
      (Tree as TVirtualStringTree).TreeOptions.AutoOptions := (Tree as TVirtualStringTree).TreeOptions.AutoOptions + [toAutoSort];
      (Tree as TVirtualStringTree).SortTree((Tree as TVirtualStringTree).Header.SortColumn, (Tree as TVirtualStringTree).Header.SortDirection);
    end;
    
  if Editor <> nil then Editor.AcceptEdit;
  if Editor <> nil then Editor.UpdateEditorPos;
end;

end.
