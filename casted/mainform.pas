{$I GDefines.inc}
{$I C2Defines.inc}
unit mainform;

interface

uses
  Logger, BaseDebug,
  C2MapEditMsg,
  BaseTypes, BaseClasses, Basics, Props, OSUtils, Base3D, Collisions, BaseGraph, BaseMsg, Resources,

  Cast2, WInput,

  C2Visual,
//  C2VisItems, C2Materials, C2MiscVisual, C2FX, C2Particle, C2Affectors, C2ParticleAdv,
//  C22D, C2GUI, GUIMsg, C2Maps, C2Land, C2TileMaps, C2Core,
//  C2Anim,
  C22D, C2GUI,
  ACSBase, ACS, ACSAdv, GUIFitter,

  C2EdMain,
  ObjFrame, PropFrame, RenderFrame,
  C2EDUtil, ItemClassForm,
  {$IFDEF USEVAMPYRE}
    VampyreCarrier,
  {$ENDIF}
  VCLHelper,

  VirtualTrees,
  Windows, Messages, ShlObj, SysUtils, Classes, Graphics, Controls, Forms, ActiveX,
  Dialogs, Treeviews,
  StdCtrls, ExtCtrls, Menus,
  StdActns, ActnMan, ActnMenus,
  StdStyleActnCtrls, Clipbrd, ActnList, XPMan, ComCtrls, Buttons, AppEvnts, ImgList, PngImageList;

const
  FormCaption = 'CAST II Editor';
  VersionStr  = '1.25';
  ProgramURL  = 'http://www.casteng.com';
  MaxExceptionsCount = 10;
  EmergencySaveFileName = 'error_backup' + DataBaseFileExt;
// Modificator keys
  vkMouseLeft = 0; vkMouseRight = 1; vkMouseMiddle = 2; vkCTRL = 3; vkAlt = 4; vkShift = 5;
//
  CameraMoveSens   = 0.1;
  CameraRotateSens = 0.01;

type
  TMouseAction = (maNone, maMoveCamera, maRotateCamera, maZoomCamera, maEditItem);

  TreeItemsArray = array of PVirtualNode;

  TMainF = class(TForm)
    dlgOpenCbf: TOpenDialog;
    SaveDialog1: TSaveDialog;
    MainMenu1: TMainMenu;
    FileMenu: TMenuItem;
    ActionList1: TActionList;
    ActionNew: TAction;
    ActionOpen: TAction;
    ActionSave: TAction;
    ActionSaveAs: TAction;
    ActionQuit: TAction;
    New1: TMenuItem;
    Open1: TMenuItem;
    Save1: TMenuItem;
    Saveas1: TMenuItem;
    N1: TMenuItem;
    Quit1: TMenuItem;
    EditMenu: TMenuItem;
    ItemsMenu: TMenuItem;
    OptionsMenu: TMenuItem;
    WindowsMenu: TMenuItem;
    HelpMenu: TMenuItem;
    ActionCut: TAction;
    ActionCopy: TAction;
    ActionPaste: TAction;
    Cut1: TMenuItem;
    Copy1: TMenuItem;
    Paste1: TMenuItem;
    ActionNewItem: TAction;
    ActionChangeClass: TAction;
    ActionSelectAll: TAction;
    ActionSelectNone: TAction;
    N2: TMenuItem;
    Selectall1: TMenuItem;
    Selectnone1: TMenuItem;
    New2: TMenuItem;
    Changeclass1: TMenuItem;
    MenuShowLog: TMenuItem;
    MenuAbout: TMenuItem;
    ActionDelete: TAction;
    Delete1: TMenuItem;
    ActionRefresh: TAction;
    Refresh1: TMenuItem;
    ActionShowLog: TAction;
    Timer: TTimer;
    PopupMenu1: TPopupMenu;
    ActionItemDefault: TAction;
    Defaultaction1: TMenuItem;
    ActionCopyName: TAction;
    Copyfullname1: TMenuItem;
    N3: TMenuItem;
    New3: TMenuItem;
    Changeclass2: TMenuItem;
    N4: TMenuItem;
    Copyfullname2: TMenuItem;
    Defaultaction2: TMenuItem;
    ActionInportRDB: TAction;
    N5: TMenuItem;
    ImportCASTresources1: TMenuItem;
    ActionShowImages: TAction;
    Images1: TMenuItem;
    ActionShowResTools: TAction;
    ResourceTools1: TMenuItem;
    ActionShowMeshEditor: TAction;
    Meshtools1: TMenuItem;
    ImportDialog: TOpenDialog;
    ActionSaveNode: TAction;
    SaveNode1: TMenuItem;
    Duplicate1: TMenuItem;
    ActionDuplicateItem: TAction;
    XPManifest1: TXPManifest;
    UpdatePropsTimer: TTimer;
    ActionOptionsGUIFitter: TAction;
    GUIfitter1: TMenuItem;
    ActionOptionsWorldFitter: TAction;
    Worldfitter1: TMenuItem;
    MainPanel: TPanel;
    DockPanelLeft: TPanel;
    RenderSplitter: TSplitter;
    RendererFrame1: TRendererFrame;
    ItemsPanel: TPanel;
    TreeSplitter: TSplitter;
    PropsFrame1: TPropsFrame;
    ItemsFrame1: TItemsFrame;
    SplitterLeft: TSplitter;
    DockPanelBottom: TPanel;
    SplitterBottom: TSplitter;
    ActionPause: TAction;
    N6: TMenuItem;
    Pause1: TMenuItem;
    ActionShowMapEditor: TAction;
    MapEditor1: TMenuItem;
    ActionShowStatistics: TAction;
    N7: TMenuItem;
    Statistics1: TMenuItem;
    N8: TMenuItem;
    Configuration1: TMenuItem;
    ActionConfig: TAction;
    ActionOpenNode: TAction;
    Opennode1: TMenuItem;
    ActionAbout: TAction;
    ActionUndo: TAction;
    ActionRedo: TAction;
    N9: TMenuItem;
    Redo1: TMenuItem;
    Undo1: TMenuItem;
    ActionDisableTesselation: TAction;
    Disabletesselation1: TMenuItem;
    ImageLstActions: TPngImageList;
    ImageLstItems: TPngImageList;
    ActionShowNewMaterial: TAction;
    Newmaterial1: TMenuItem;
    ActionGraphValueEditor: TAction;
    Graphvalueeditor1: TMenuItem;
    TimeScalePanel: TPanel;
    trkTimeScale: TTrackBar;
    dlgOpenCnf: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Init;

//    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure ItemsPanelMsgHandler(var Message: TMessage);
    procedure DockPanelLeftMsgHandler(var Message: TMessage);
    procedure DockPanelBottomMsgHandler(var Message: TMessage);
    procedure DrawPanel(DC: HDC; APanel: TPanel);

    procedure ItemsFrame1TreeChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure TreeEditorAcceptEdit(const PropertyModified: TProperty);
    procedure ItemsTreeOnChange(Item: TItem);
    procedure ItemsFrame1TreeFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);

    procedure ActionNewExecute(Sender: TObject);
    procedure ActionOpenExecute(Sender: TObject);
    procedure ActionSaveAsExecute(Sender: TObject);
    procedure ActionSaveExecute(Sender: TObject);
    procedure ActionSaveNodeExecute(Sender: TObject);

    procedure ActionQuitExecute(Sender: TObject);
    procedure ActionSelectNoneExecute(Sender: TObject);
    procedure ActionSelectAllExecute(Sender: TObject);
    procedure ActionNewItemExecute(Sender: TObject);

    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ActionDeleteExecute(Sender: TObject);
    procedure ActionRefreshExecute(Sender: TObject);
    procedure ActionCutExecute(Sender: TObject);
    procedure ActionCopyExecute(Sender: TObject);
    procedure ActionPasteExecute(Sender: TObject);
    procedure ActionShowLogExecute(Sender: TObject);
    procedure ActionItemDefaultExecute(Sender: TObject);
    procedure ActionCopyNameExecute(Sender: TObject);
    procedure ActionInportRDBExecute(Sender: TObject);
    procedure ActionChangeClassExecute(Sender: TObject);

    procedure ActionShowImagesExecute(Sender: TObject);
    procedure ActionShowResToolsExecute(Sender: TObject);
    procedure ActionShowMeshEditorExecute(Sender: TObject);
    procedure ActionDuplicateItemExecute(Sender: TObject);

    procedure ItemsFrame1TreeDragOver(Sender: TBaseVirtualTree; Source: TObject; Shift: TShiftState; State: TDragState; Pt: TPoint; Mode: TDropMode; var Effect: Integer; var Accept: Boolean);
    procedure ItemsFrame1TreeDragDrop(Sender: TBaseVirtualTree; Source: TObject; DataObject: IDataObject; Formats: TFormatArray; Shift: TShiftState; Pt: TPoint; var Effect: Integer; Mode: TDropMode);
    procedure ItemsFrame1TreeDblClick(Sender: TObject);
    procedure ItemsFrame1TreeKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: Char);

    procedure RendererFrame1RenderPanelClick(Sender: TObject);
    procedure RendererFrame1RenderPanelDblClick(Sender: TObject);
    procedure RendererFrame1RenderPanelMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure RendererFrame1RenderPanelMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure RendererFrame1RenderPanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure RendererFrame1RenderPanelMouseWheel(Sender: TObject; Shift: TShiftState; Delta: Integer);
    procedure RendererFrame1RenderPanelResize(Sender: TObject);

    procedure ItemsFrame1TreeHeaderDblClick(Sender: TVTHeader; Column: TColumnIndex; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ItemsFrame1TreeEdited(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);

    procedure DockPanelBottomDockOver(Sender: TObject; Source: TDragDockObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure DockPanelLeftDockOver(Sender: TObject; Source: TDragDockObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure SplitterLeftCanResize(Sender: TObject; var NewSize: Integer; var Accept: Boolean);
    procedure DockPanelDockDrop(Sender: TObject; Source: TDragDockObject; X, Y: Integer);
    procedure DockPanelUnDock(Sender: TObject; Client: TControl; NewTarget: TWinControl; var Allow: Boolean);
    procedure DockPanelClick(Sender: TObject);

    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure ActionPauseExecute(Sender: TObject);
    procedure ActionShowMapEditorExecute(Sender: TObject);
    procedure ActionShowStatisticsExecute(Sender: TObject);
    procedure ActionConfigExecute(Sender: TObject);
    procedure ActionOpenNodeExecute(Sender: TObject);
    procedure ActionAboutExecute(Sender: TObject);
    procedure ActionUndoExecute(Sender: TObject);
    procedure ActionRedoExecute(Sender: TObject);
    procedure ActionDisableTesselationExecute(Sender: TObject);
    procedure ActionOptionsGUIFitterExecute(Sender: TObject);
    procedure ActionOptionsWorldFitterExecute(Sender: TObject);

    procedure ItemsFrame1TreeCollapsed(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure ItemsFrame1TreeExpanded(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure ItemsFrame1TreeGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean; var ImageIndex: Integer);

    procedure TimerTimer(Sender: TObject);
    procedure UpdatePropsTimerTimer(Sender: TObject);
    procedure ActionShowNewMaterialExecute(Sender: TObject);
    procedure ActionGraphValueEditorExecute(Sender: TObject);
    procedure ItemsFrame1BtnPauseMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure trkTimeScaleChange(Sender: TObject);
    procedure TimeScalePanelMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ItemsFrame1TreeHeaderClick(Sender: TVTHeader;
      Column: TColumnIndex; Button: TMouseButton; Shift: TShiftState; X,
      Y: Integer);
  public
    AffectedCamera: TCamera;
    function GetCurrentParent: TItem;
    function CollectProperties: Boolean;
    procedure AutoSizeDockPanels;
    procedure RefreshColList;

    procedure ZoomCamera(Amount: Single);
    procedure DoCameraMove;
    procedure DoObjectsMark;
    procedure DoObjectsEdit;

    function GetObjectsUnderCursor: TProcessing;

    procedure HandleMouseMove(AX, AY: Integer);
    procedure HandleMouseUp(AX, AY, AButton: Integer);
    procedure HandleMouseDown(AX, AY, AButton: Integer);

    function GetKeyState(ModKey: Integer): Boolean;

    procedure SelectItem(const AFullName: string);

    procedure RefreshItems;

    procedure OnException(Sender: TObject; E: Exception);
  private
    FClickedOnItem: Boolean;               // To prevent double click handling when clicked not on an item
    ExceptionsCount: Integer;
    OldItemsPanelWndProc, OldDockPanelLeftWndProc, OldDockPanelBottomWndProc: TWndMethod;
    LastTick: Longword;
    LastFrame: Integer;
    CurFPS: Single;
    FItemsChanged, NeedPropsRefresh, NeedAutoSizeDockPanels, TimerProcessing: Boolean;
    FMouseAction: TMouseAction;
    OldRenderWidth, OldRenderHeight: Integer;
    LastMouseX, LastMouseY: Integer;

    EditorSetupItem: TItem;

    OldMouseX, OldMouseY: Integer;

    procedure SetAffectedCamera;

    procedure UpdateFormCaption;
    procedure SetItemsChanged(const Value: Boolean);
    procedure SetCurrentDBFile(const Value: string);
    function GetCurrentDBFile: string;
    procedure SetMouseAction(const Value: TMouseAction);
    function GetMapEditMode: Boolean;
    procedure SetMapEditMode(const Value: Boolean);

    function ForEachD(Item: TItem; Index: Integer; Data: Pointer): Boolean;
  public
    WasIdleClick: Boolean;

    property MapEditMode: Boolean read GetMapEditMode write SetMapEditMode;
    property ItemsChanged: Boolean read FItemsChanged write SetItemsChanged;
    property CurrentDBFile: string read GetCurrentDBFile write SetCurrentDBFile;
    property MouseAction: TMouseAction read FMouseAction write SetMouseAction;
  end;

var
  MainF: TMainF;

implementation

uses
  MapEditForm, LogForm, CImport, FImages, ResTools, FScale, Math,
  FStats, FConfig, FAbout, FPropEdit, FMaterial, FPEmitter;

{$R *.dfm}

type TClassIconRec = record Name: string[28]; IconIndex: Integer; end;
const
  ClassIcons: array[0..15] of TClassIconRec =
    ((Name: 'TEmitter';         IconIndex: 0),
     (Name: 'TTechnique';       IconIndex: 1),
     (Name: 'TPSAffector';      IconIndex: 2),
     (Name: 'TAudioResource';   IconIndex: 3),
     (Name: 'TAudioResource';   IconIndex: 4),
     (Name: 'TCamera';          IconIndex: 5),
     (Name: 'TLight';           IconIndex: 6),
     (Name: 'TFont';            IconIndex: 7),
     (Name: 'TImageResource';   IconIndex: 8),
     (Name: 'TMappedItem';      IconIndex: 9),
     (Name: 'TUVMapResource';   IconIndex: 10),
     (Name: 'TCharMapResource'; IconIndex: 11),
     (Name: 'TTextResource';    IconIndex: 12),
     (Name: 'TScriptResource';  IconIndex: 13),
     (Name: 'TRenderPass';      IconIndex: 14),
     (Name: 'TMaterial';        IconIndex: 14));

procedure TMainF.FormCreate(Sender: TObject);
begin
//  ItemsPanel.DoubleBuffered := True;
  OldItemsPanelWndProc       := ItemsPanel.WindowProc;
  ItemsPanel.WindowProc      := ItemsPanelMsgHandler;
  OldDockPanelLeftWndProc    := DockPanelLeft.WindowProc;
  DockPanelLeft.WindowProc   := DockPanelLeftMsgHandler;
  OldDockPanelBottomWndProc  := DockPanelBottom.WindowProc;
  DockPanelBottom.WindowProc := DockPanelBottomMsgHandler;

//  ItemsFrame1.VirtualStringTree1.RootNodeCount := 10;
  PropsFrame1.Properties := TProperties.Create;
//  PropsFrame1.Properties.Add('Boolean', vtBoolean, [poReadonly], 'Off', '');
  PropsFrame1.Properties.Add('Colors\Color',    vtColor, [], '#00FF00A0', '');
  PropsFrame1.Properties.Add('Colors\Color\c2', vtColor, [], '#0000FF00', '');
  PropsFrame1.Properties.Add('Colors', vtColor, [], '#00FFFF00', '');
{  PropsFrame1.Properties.Add('Enum sample', vtEnumerated, [], 'Jan', 'Jan\&Feb\&Mar\&Apr\&May\&Jun\&Jul\&Aug\&Sep\&Oct\&Nov\&Dec');
  PropsFrame1.Properties.Add('Name', vtString, [], 'Abcdef', '');
  PropsFrame1.Properties.Add('U', vtNat, [poReadonly], '5', '');
  PropsFrame1.Properties.Add('U\X', vtInt, [poReadonly], '0', '');
  PropsFrame1.Properties.Add('U\Y', vtSingle, [poReadonly], '0.5', '');
  PropsFrame1.Properties.Add('U\Y\1', vtSingle, [poReadonly], '1.5', '');
  PropsFrame1.Properties.Add('U\Z', vtNat, [poReadonly], '5', '');}

//  Core.Root.AddCollection([tmProcessing]);

  Core.RegisterItemClass(TVisible);

  ItemsFrame1.OnTreeChange := ItemsTreeOnChange;

  PropsFrame1.Tree.NodeDataSize := SizeOf(TPropNodeData);
  PropsFrame1.EditorTree := TPropsTree.Create(PropsFrame1.Tree, PropsFrame1.Properties, TreeEditorAcceptEdit);
  PropsFrame1.RefreshTree;

  ItemsFrame1.Tree.NodeDataSize := SizeOf(TItemNodeData);
  ItemsFrame1.EditorTree := TItemsTree.Create(ItemsFrame1.Tree);
  ItemsFrame1.RefreshTree;

  FItemsChanged := False;

  Core.Input := TOSController.Create(Handle, nil);

  OldRenderWidth  := RendererFrame1.RenderPanel.Width;
  OldRenderHeight := RendererFrame1.RenderPanel.Height;
  RendererFrame1.InitRender;

  ItemsFrame1.Init;
end;

procedure TMainF.FormDestroy(Sender: TObject);
begin
  Timer.Enabled := False;
  TC2Screen(BaseGraph.Screen).SetCore(nil);
  FreeAndNil(PropsFrame1.Properties);
  FreeAndNil(PropsFrame1.EditorTree);
  FreeAndNil(ItemsFrame1.EditorTree);
end;

procedure TMainF.Init;
begin
//  Core.Root.AddChild(TPlane.Create);
//  Core.Root.AddChild(CAST2.TResource.Create);
  ControlStyle := ControlStyle + [csOpaque];
  MainPanel.ControlStyle := MainPanel.ControlStyle + [csOpaque];

  PropEditF.OnApply := App.OnApplyPropEdit;

  ItemsFrame1.Tree.RootNodeCount := 0;

  App.Load;

  ItemsFrame1.RefreshTree;

  ItemsFrame1.SelectItem(Core.Root.GetItemByFullName(App.Config['LastItem']), False);

  Timer.Enabled := True;
  UpdatePropsTimer.Enabled := True;
end;

(*procedure TMainF.WMEraseBkgnd(var Message: TWMEraseBkgnd);
var Rect: TRect;
begin
  Rect := GetClientRect;
//  inherited;
  ValidateRect(Self.Handle, @Rect);
  Message.Result := 1;
end;*)

procedure TMainF.ItemsPanelMsgHandler(var Message: TMessage);
begin
  if Message.Msg = WM_ERASEBKGND then begin
    DrawPanel(HDC(Message.WParam), ItemsPanel); Message.Result := 1;
  end else if Assigned(OldItemsPanelWndProc) then OldItemsPanelWndProc(Message);
end;

procedure TMainF.DockPanelLeftMsgHandler(var Message: TMessage);
begin
  if Message.Msg = WM_ERASEBKGND then begin
    DrawPanel(HDC(Message.WParam), DockPanelLeft); Message.Result := 1;
  end else if Assigned(OldDockPanelLeftWndProc) then OldDockPanelLeftWndProc(Message);
end;

procedure TMainF.DockPanelBottomMsgHandler(var Message: TMessage);
begin
  if Message.Msg = WM_ERASEBKGND then begin
    DrawPanel(HDC(Message.WParam), DockPanelBottom); Message.Result := 1;
  end else if Assigned(OldDockPanelBottomWndProc) then OldDockPanelBottomWndProc(Message);
end;

procedure TMainF.DrawPanel(DC: HDC; APanel: TPanel);
var Rect: TRect;
begin
  Rect := APanel.ClientRect;
  FillRect(DC, Rect, APanel.Brush.Handle);
end;

function TMainF.CollectProperties: Boolean;
begin
  UpdatePropsTimer.Enabled := False;

  PropsFrame1.Properties.Clear;
  if EditorSetupItem <> nil then begin
    PropsFrame1.ActAddPropertiesOf(EditorSetupItem, nil);
    Result := True;
  end else begin    
    ItemsFrame1.DoForEachSelected(PropsFrame1.ActAddPropertiesOf, nil, nil, True);
    Result := PropsFrame1.Properties.TotalProperties > 0;
  end;

  UpdatePropsTimer.Enabled := True;
end;

procedure TMainF.ItemsFrame1BtnPauseMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var Coords: TPoint;
begin
  if not TimeScalePanel.Visible then begin
    Coords := ItemsFrame1.BtnPause.Parent.ClientToScreen(Point(ItemsFrame1.BtnPause.Left, ItemsFrame1.BtnPause.Top));
    Coords := TimeScalePanel.Parent.ScreenToClient(Coords);

    TimeScalePanel.Left := Coords.X  + (ItemsFrame1.BtnPause.Width - TimeScalePanel.Width) div 2;
    TimeScalePanel.Top  := Coords.Y  +  ItemsFrame1.BtnPause.Height-2;
    TimeScalePanel.Show;
  end;
end;

procedure TMainF.trkTimeScaleChange(Sender: TObject);
const MinTimeScale = 0.2; MaxTimeScale = 5;
var TrackBarMid: Integer; Msg: TMessage;
begin
  TrackBarMid := (trkTimeScale.Max - trkTimeScale.Min) div 2;
  if trkTimeScale.Position > TrackBarMid then
    Core.TimeScale := 1 + (MaxTimeScale-1) * (trkTimeScale.Position - TrackBarMid) / TrackBarMid
  else
    Core.TimeScale := MinTimeScale + (1-MinTimeScale) * trkTimeScale.Position / TrackBarMid;
  trkTimeScale.Hint := Format('Time scale: %3.3F', [Core.TimeScale]);
end;

procedure TMainF.TimeScalePanelMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not IsMouseOverControl(ItemsFrame1.BtnPause) and
    (GetCaptureControl <> trkTimeScale) then TimeScalePanel.Hide;
end;

procedure TMainF.ItemsFrame1TreeChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  ItemClassF.RefreshClasses;
  if Node <> nil then ItemClassF.SelectClass(ItemsFrame1.GetNodeItem(Node).ClassName);

//  if Node = nil then ItemClassF.ClassModifyBut.Enabled := False else ItemClassF.ClassModifyBut.Enabled := True;

  EditorSetupItem := nil;

  if ItemsFrame1.Tree.SelectedCount < 1 then Exit;

  CollectProperties;

  PropsFrame1.RefreshTree;

  ScaleForm.UpdateInfo;
  FormNewMaterial.HandleItemSelect(ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode));

  RefreshColList;                      // Collection list debug output. Temporarily disabled
end;

procedure TMainF.TreeEditorAcceptEdit(const PropertyModified: TProperty);
var OldPropsCount: Integer; Properties: TProperties; Params: TPropertiesParams; 
begin
  Properties := TProperties.Create;
  Properties.Add(PropertyModified.Name, PropertyModified.ValueType, PropertyModified.Options, PropertyModified.Value, PropertyModified.Enumeration);

  OldPropsCount := PropsFrame1.Properties.TotalProperties;

  Params := TPropertiesParams.Create(Properties);
  if EditorSetupItem <> nil then
    PropsFrame1.ActAppleNodeProperties(EditorSetupItem, Params)
  else
    ItemsFrame1.DoForEachSelected(PropsFrame1.ActAppleNodeProperties, nil, Params, True);
  FreeAndNil(Params);

  Properties.Free;

  NeedPropsRefresh := NeedPropsRefresh or (OldPropsCount <> PropsFrame1.Properties.TotalProperties);
end;

procedure TMainF.ItemsFrame1TreeFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
begin
  if ItemsFrame1.GetNodeItem(Node) <> nil then
    App.Config['LastItem'] := ItemsFrame1.GetNodeItem(Node).GetFullName
  else
    App.Config['LastItem'] := '';
  ItemsFrame1TreeChange(Sender, Node);
//  PropsFrame1.Tree.SetFocus;
  PropsFrame1.EditorTree.Editor.UpdateEditorPos;

  MapEditF.MapCursor.MainTextureName := '';
  MapEditF.MapCursor.UVMapName       := '';
  MapEditF.MapCursor.Params.Clear;
  if Assigned(ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode)) then
    ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode).HandleMessage(TRequestMapEditVisuals.Create(MapEditF.MapCursor));

  MapEditF.UpdateForm;
  PropEditF.UpdateProps(MapEditF.MapCursor.Params);
  PEmitterForm.UpdateForm;
  if Visible then SetFocus;
end;

procedure TMainF.ActionNewExecute(Sender: TObject);
begin
  if ItemsChanged then
    case MessageBox(Handle, 'Items database was changed. Do you want to save it?', 'CAST II Editor', MB_ICONQUESTION or MB_YESNOCANCEL or 0*MB_TASKMODAL) of
      idYes: ActionSaveExecute(Sender);
      idNo: ItemsChanged := False;
      idCancel: Exit;
    end;

  if Sender <> nil then ItemsFrame1.Tree.RootNodeCount := 0;
  App.ActNewScene();

  ActionRedo.Enabled := App.OperationManager.CanRedo;
  ActionUndo.Enabled := App.OperationManager.CanUndo;

  if Sender <> nil then begin
    CurrentDBFile := '';
    RefreshItems;
  end;
end;

procedure TMainF.ActionOpenExecute(Sender: TObject);
begin
  if not dlgOpenCbf.Execute then Exit;

  ItemsFrame1.Tree.RootNodeCount := 0;
  App.LoadFrom(dlgOpenCbf.FileName);
  ActionRedo.Enabled := App.OperationManager.CanRedo;
  ActionUndo.Enabled := App.OperationManager.CanUndo;
  App.OperationManager.Clear;

  RefreshItems;
end;

procedure TMainF.ActionOpenNodeExecute(Sender: TObject);
var Item: TItem;
begin
  Item := ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode);
  if Assigned(Item) then
    dlgOpenCnf.FileName := string(Item.Name);
  if not dlgOpenCnf.Execute then Exit;
  if not Assigned(Item) then Item := Core.Root;
  App.LoadAs(Item, dlgOpenCnf.FileName);

  RefreshItems;
end;

procedure TMainF.ActionSaveAsExecute(Sender: TObject);
begin
  if SaveDialog1.Execute then if App.SaveAs(SaveDialog1.FileName) then CurrentDBFile := SaveDialog1.FileName;
end;

procedure TMainF.ActionSaveExecute(Sender: TObject);
begin
  if CurrentDBFile = '' then ActionSaveAsExecute(Sender) else App.SaveAs(CurrentDBFile);
end;

procedure TMainF.ActionSaveNodeExecute(Sender: TObject);
begin
  if ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode) = nil then begin
    Log('Save node: no node selected', lkError);
    Exit;
  end;
  if not SaveDialog1.Execute then Exit;
  App.SaveItem(ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode), SaveDialog1.FileName);
end;

procedure TMainF.ActionQuitExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainF.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  ActionNewExecute(nil);
  CanClose := not ItemsChanged;
end;

function TMainF.GetCurrentDBFile: string;
begin
  Result := CFG['CurrentDBFile'];
end;

procedure TMainF.SetCurrentDBFile(const Value: string);
begin
  CFG.Add('CurrentDBFile', vtString, [], Value, '');
  UpdateFormCaption;
end;

procedure TMainF.ActionNewItemExecute(Sender: TObject);
begin
//  ActionSelectNoneExecute(Sender);
  if not ItemClassF.Visible then ItemClassF.Show;
//  ItemClassF.ClassCreateBut.Default := True;
//  ItemClassF.ClassModifyBut.Default := False;
  ItemClassF.SetFocus;
end;

procedure TMainF.ActionChangeClassExecute(Sender: TObject);
begin
  if not ItemClassF.Visible then ItemClassF.Show;
//  ItemClassF.ClassCreateBut.Default := False;
//  ItemClassF.ClassModifyBut.Default := True;
  ItemClassF.SetFocus;
end;

procedure TMainF.ActionDuplicateItemExecute(Sender: TObject);
begin
  ItemsFrame1.DoForEachSelected(App.ActDuplicateItem, nil, nil, True);
  ItemsChanged := True;
  ItemsFrame1.RefreshTree;
end;

procedure TMainF.ActionSelectNoneExecute(Sender: TObject);
begin
  ItemsFrame1.Tree.ClearSelection;
  ItemsFrame1.Tree.FocusedNode := nil;
  EditorSetupItem := nil;
end;

procedure TMainF.ActionSelectAllExecute(Sender: TObject);
begin
  if GUIHelper.IsInputInProcess() then
    SendMessage(GetFocus, EM_SETSEL, 0, $FFFF)
  else
    ItemsFrame1.Tree.SelectAll(False);
end;

procedure TMainF.ItemsTreeOnChange(Item: TItem);
begin
  ItemClassF.RefreshClasses;
//  if Item = nil then ItemClassF.ClassModifyBut.Enabled := False else ItemClassF.ClassModifyBut.Enabled := True;
end;

procedure TMainF.ActionDeleteExecute(Sender: TObject);
var s: string;
begin
//  if PropsFrame1.EditorTree.Editor.IsEditing
   if (MainF.ActiveControl <> ItemsFrame1.Tree) or (ItemsFrame1.Tree.SelectedCount = 0) then Exit;

  if Sender <> nil then begin
    if ItemsFrame1.Tree.SelectedCount > 1 then
      s := 'Delete ' + IntToStr(ItemsFrame1.Tree.SelectedCount) + 'selected items?'
    else
      s := 'Delete the item "' + string(ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode).Name) + '"?';
    if MessageBox(0, PChar(s), 'Delete Item', MB_ICONEXCLAMATION or MB_YESNO or MB_APPLMODAL) = idNo then Exit;
  end;

  ItemsFrame1.DoForEachSelected(App.ActDeleteItem, ItemsFrame1.CBDelete, nil, False);
end;

procedure TMainF.ActionDisableTesselationExecute(Sender: TObject);
begin
  Core.Renderer.DisableTesselation := not Core.Renderer.DisableTesselation;
  Disabletesselation1.Checked := Core.Renderer.DisableTesselation;
  ItemsFrame1.DisableTessButton.Down := Core.Renderer.DisableTesselation;
end;

procedure TMainF.ActionRefreshExecute(Sender: TObject);
begin
  RefreshItems;
end;

procedure TMainF.ActionCopyExecute(Sender: TObject);
var Params: TClipboardParams;
begin
  if GUIHelper.IsInputInProcess() then
    SendMessage(GetFocus, WM_COPY, 0, 0)
  else begin
    C2EDUtil.Clipboard.Clear;
    Params := TClipboardParams.Create(C2EDUtil.Clipboard);
    ItemsFrame1.DoForEachSelected(App.ActCopyItem, nil, Params, True);
    FreeAndNil(Params);
  end;
end;

procedure TMainF.ActionCutExecute(Sender: TObject);
begin
  if GUIHelper.IsInputInProcess() then
    SendMessage(GetFocus, WM_CUT, 0, 0)
  else begin
    ActionCopyExecute(Sender);
    ActionDeleteExecute(nil);
  end;
end;

procedure TMainF.ActionPasteExecute(Sender: TObject);
var i: Integer;
begin
  if GUIHelper.IsInputInProcess() then
    SendMessage(GetFocus, WM_PASTE, 0, 0)
  else begin
    if ItemsFrame1.Tree.FocusedNode = nil then Exit;
    for i := 0 to C2EDUtil.Clipboard.TotalElements-1 do begin
      C2EDUtil.Clipboard.PrepareObject(i);
      Core.LoadItem(C2EDUtil.Clipboard.Stream, ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode));
      ItemsChanged := True;
    end;
    ItemsFrame1.RefreshTree;
  end;
end;

procedure TMainF.ActionShowLogExecute(Sender: TObject);
begin
  if not LogF.Visible then LogF.Show else LogF.Hide;
end;

procedure TMainF.RefreshColList;
//var i: Integer;
begin
//  RootColList.Clear;
 //  for i := 0 to Core.Root.Collections[0].TotalItems-1 do
 //   RootColList.Items.Add(Core.Root.Collections[0].Items[i].Name);
 //  if Core.RenderItems <> nil then for i := 0 to Core.TotalRenderItems-1 do
//   RootColList.Items.Add(Core.RenderItems[i].Name);
end;

procedure TMainF.UpdateFormCaption;
begin
  if FItemsChanged then MainF.Caption := '* ' else MainF.Caption := '';
  MainF.Caption := Format('%S - %S - [%3.2F] %S', [MainF.Caption, CurrentDBFile, CurFPS, FormCaption]);
//  Caption := 'CASTEd [' + FloatToStrF(CurFPS, ffGeneral, 6, 2) +']';
end;

procedure TMainF.SetItemsChanged(const Value: Boolean);
begin
  FItemsChanged := Value;
  UpdateFormCaption;
end;

procedure TMainF.SetAffectedCamera;
begin
  if ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode) is TCamera then
    AffectedCamera := ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode) as TCamera;
  if not Assigned(AffectedCamera) then
    AffectedCamera := Core.Renderer.MainCamera;
end;

procedure TMainF.ZoomCamera(Amount: Single);
begin
  SetAffectedCamera();
  if not Assigned(AffectedCamera) then Exit;
  if AffectedCamera is TLookAtCamera then begin
    with (AffectedCamera as TLookAtCamera) do
      Range := MaxS(0, Range + Amount*0.01);
  end else with AffectedCamera do
    Position := AddVector3s(Position, ScaleVector3s(ForwardVector, -Amount*0.10));

  ItemsChanged := True;
end;

procedure TMainF.DoCameraMove;
var NewMouseX, NewMouseY: Integer; MoveAmount: Single;
begin
  SetAffectedCamera();
  if not Assigned(AffectedCamera) then Exit;
  if (MouseAction = maMoveCamera)   and (GetKeyState(vkCTRL)) or
     (MouseAction = maRotateCamera) and (GetKeyState(vkAlt))  or
     (MouseAction = maZoomCamera)   and (GetKeyState(vkShift)) then begin
    OSUtils.ObtainCursorPos(NewMouseX, NewMouseY);

    MoveAmount := CameraMoveSens;
    if AffectedCamera is TLookAtCamera then
      MoveAmount := 0.2 * MoveAmount * Exp(TLookAtCamera(AffectedCamera).Range*0.5);

    if MouseAction = maMoveCamera then AffectedCamera.Move(-(NewMouseX - LastMouseX) * MoveAmount, (NewMouseY - LastMouseY) * MoveAmount, 0);

    if MouseAction = maRotateCamera then with AffectedCamera do
      Orientation := MulQuaternion(GetQuaternion((NewMouseX - LastMouseX)*CameraRotateSens, GetVector3s(0, 1, 0)),
                                   MulQuaternion(GetQuaternion((NewMouseY - LastMouseY)*CameraRotateSens, RightVector),
                                                 Orientation));

    if MouseAction = maZoomCamera then ZoomCamera(NewMouseY - LastMouseY);

    LastMouseX := NewMouseX; LastMouseY := NewMouseY;
    ItemsChanged := True;
  end;
end;

procedure TMainF.DoObjectsMark;
var
  i: Integer;
  PickedItems: TItems; TotalPickedItems: Integer; PickedItem: TProcessing;
begin
  // Unpick previously picked objects
  TotalPickedItems := Core.Root.ExtractByMask([isPicked], False, PickedItems);
  for i := 0 to TotalPickedItems-1 do PickedItems[i].State := PickedItems[i].State - [isPicked];
  // Pick selected objects
  ItemsFrame1.DoForEachSelected(App.ActPickItem, nil, nil, True);
//  Globals.PickedColor := BlendColor(Globals.BoxColor, GetColor($FFFFFFFF), 0.25 + 0.25*Sin(Globals.CurrentTime/300));

  PickedItem := GetObjectsUnderCursor;
  if Assigned(PickedItem) then PickedItem.State := PickedItem.State + [isPicked];

  App.ActEditHighlight(ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode), nil);

  PickedItems := nil;
end;

procedure TMainF.DoObjectsEdit;
begin
//
end;

function TMainF.GetObjectsUnderCursor: TProcessing;
var
  i, MX, MY: Integer;
  PickedItems: TItems; TotalPickedItems: Integer;
  PickRay, CollPoint: TVector3s;
  OldDist, Dist: Double;
//  ShellBoundingVolumes: TBoundingVolume;
begin
  Result := nil;
  OldDist := MaxSingle;
  // Pick an object under cursor
  if Assigned(Core.Renderer) and Assigned(Core.Renderer.MainCamera) then begin
    OSUtils.ObtainCursorPos(MX, MY);
    OSUtils.ScreenToClient(RendererFrame1.RenderPanel.Handle, MX, MY);

    if (MX >= 0) and (MY >= 0) and (MX < RendererFrame1.RenderPanel.Width) and (MY < RendererFrame1.RenderPanel.Height) then begin
      PickRay := Core.Renderer.MainCamera.GetPickRayInWorld(MX, MY);
      PickRay := NormalizeVector3s(PickRay);
      
      TotalPickedItems := Core.Root.ExtractByMask([isVisible], False, PickedItems);
      for i := TotalPickedItems-1 downto 0 do if PickedItems[i] is TVisible then begin
        if RaySphereColDet(Core.Renderer.MainCamera.GetAbsLocation, PickRay,
                           TProcessing(PickedItems[i]).GetAbsLocation, TProcessing(PickedItems[i]).BoundingSphereRadius, CollPoint) then begin
          Dist := SqrMagnitude(SubVector3s(Core.Renderer.MainCamera.GetAbsLocation, CollPoint));

//          if SqrMagnitude(SubVector3s(Core.Renderer.ActiveCamera.GetAbsLocation, TProcessing(PickedItems[i]).GetAbsLocation)) <
//             Sqr(TProcessing(PickedItems[i]).BoundingSphereRadius) then Dist := -Dist;

          if (Result = nil) or (Dist < OldDist) then begin
            Result := TProcessing(PickedItems[i]);
            OldDist := Dist;
          end;
        end;
      end;
    end;
  end;

  PickedItems := nil;
end;

procedure TMainF.TimerTimer(Sender: TObject);
begin
  if TimerProcessing then Exit;

  LogF.BeginUpdateLog;

  TimerProcessing := True;

  Log('Test', GetCodeLoc('mainform', 'unit', '', 934, nil));
  Log('Test2', GetCodeLoc('', '', '', 934, nil));
  Assert(_Log(lkWarning), 'Test3');

  try
    if GetTickCount - LastTick > 500 then begin
      CurFPS := 1000*((Core.Renderer.FramesRendered - LastFrame)) / (GetTickCount - LastTick);
      LastTick  := GetTickCount;
      LastFrame := Core.Renderer.FramesRendered;
      UpdateFormCaption;
    end;

    App.UpdateFitters;
    Core.Process;
    StatF.UpdateStats(Core);

    if Core.Root <> nil then begin
      DoCameraMove;
      DoObjectsMark;
      DoObjectsEdit;
    end;

    if NeedPropsRefresh and PropsFrame1.Tree.Visible then begin
      PropsFrame1.RefreshTree;
      NeedPropsRefresh := False;
    end;

    ExceptionsCount := 0;

    LogF.EndUpdateLog;

    if NeedAutoSizeDockPanels then AutoSizeDockPanels;

  finally
    TimerProcessing := False;
  end;
end;

procedure TMainF.OnException(Sender: TObject; E: Exception);
var EmSaveRes: Boolean;
begin
  Timer.Enabled := False;
  try
    App.OnException(Sender, E);
    if (ExceptionsCount >= 0) and (App.Config.GetAsInteger('SaveAndExitOnException') = 1) then begin
      Inc(ExceptionsCount);
      if ExceptionsCount > MaxExceptionsCount then begin
        Log('Exceptions limit reached', lkError);
        if MessageBox(0, 'Do you want to close the program?'+#13+#10+
                         'Current scene will be saved to file "' + EmergencySaveFileName + '".',
                         'Error Limit Reached', MB_ICONSTOP or MB_YESNO) = mrYes then begin
          try
            EmSaveRes := App.SaveAs(EmergencySaveFileName);
          except
            EmSaveRes := False;
          end;
          if not EmSaveRes then MessageDlg('Save failed', mtError, [mbOK], 0);
          MainF.ItemsChanged := False;
          Close;
        end;
        ExceptionsCount := -1;
      end;
    end;
  finally
    Timer.Enabled := True;
  end;
end;

procedure TMainF.ItemsFrame1TreeDblClick(Sender: TObject);
begin
  if FClickedOnItem then ActionItemDefaultExecute(Sender);
end;

function TMainF.GetKeyState(ModKey: Integer): Boolean;
begin
  Result := False;
  case ModKey of
    vkMouseLeft:   Result := (OSUtils.GetAsyncKeyState(VK_LBUTTON) < 0);
    vkMouseRight:  Result := (OSUtils.GetAsyncKeyState(VK_RBUTTON) < 0);
    vkMouseMiddle: Result := (OSUtils.GetAsyncKeyState(VK_MBUTTON) < 0);
    vkCTRL:  Result := (OSUtils.GetAsyncKeyState(VK_LCONTROL) < 0) or (OSUtils.GetAsyncKeyState(VK_RCONTROL) < 0);
    vkAlt:   Result := (OSUtils.GetAsyncKeyState(VK_LMENU)    < 0) or (OSUtils.GetAsyncKeyState(VK_RMENU)    < 0);
    vkShift: Result := (OSUtils.GetAsyncKeyState(VK_LSHIFT)   < 0) or (OSUtils.GetAsyncKeyState(VK_RSHIFT)   < 0);
  end;
end;

procedure TMainF.SetMouseAction(const Value: TMouseAction);
begin
  FMouseAction := Value;
  case FMouseAction of
    maNone:         Screen.Cursor := crDefault;
    maMoveCamera:   Screen.Cursor := crSizeAll;
    maRotateCamera: Screen.Cursor := crSizeNWSE;
    maZoomCamera:   Screen.Cursor := crSizeNS;
    maEditItem:     Screen.Cursor := crCross;
  end;
end;

procedure TMainF.RendererFrame1RenderPanelResize(Sender: TObject);
begin
//  Core.SendMessage(TWindowResizeMsg.Create(0, 0, RendererFrame1.RenderPanel.Width, RendererFrame1.RenderPanel.Height), nil);
  if (OldRenderWidth <> RendererFrame1.RenderPanel.Width) or (OldRenderHeight <> RendererFrame1.RenderPanel.Height) then 
    Core.SendMessage(TWindowResizeMsg.Create(OldRenderWidth, OldRenderHeight, RendererFrame1.RenderPanel.Width, RendererFrame1.RenderPanel.Height), nil, [mfCore]);

  OldRenderWidth  := RendererFrame1.RenderPanel.Width;
  OldRenderHeight := RendererFrame1.RenderPanel.Height;
end;

procedure TMainF.ItemsFrame1TreeKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    46: if Active and (ActiveControl = ItemsFrame1.Tree) then ActionDeleteExecute(Sender);
  end;
end;

procedure TMainF.FormKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #27: if Active then ActionSelectNoneExecute(Sender);
  end;
end;

procedure TMainF.ActionItemDefaultExecute(Sender: TObject);
begin
  ItemsFrame1.DoForEachSelected(App.ActDefault, nil, nil, True);
end;

procedure TMainF.ActionCopyNameExecute(Sender: TObject);
var Item: TItem;
begin
  Item := ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode);
  if Item = nil then Exit;
  Clipboard.SetTextBuf(PChar(string(Item.GetFullName)));
end;

procedure TMainF.ActionInportRDBExecute(Sender: TObject);
begin
  if not ImportDialog.Execute then Exit;
  ImportRDB(ImportDialog.FileName);
end;

procedure TMainF.ItemsFrame1TreeHeaderDblClick(Sender: TVTHeader; Column: TColumnIndex; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  PropsFrame1.Height := PropsFrame1.Height - PropsFrame1.Height div 3;
end;

function TMainF.GetCurrentParent: TItem;
begin
  Result := ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode);
  if Result = nil then Result := Core.Root;
end;

procedure TMainF.ActionShowImagesExecute(Sender: TObject);
begin
  if not ImagesForm.Visible then ImagesForm.Show else ImagesForm.Hide;
end;

procedure TMainF.ActionShowResToolsExecute(Sender: TObject);
begin
  if not FResTools.Visible then FResTools.Show else FResTools.Hide;
end;

procedure TMainF.ItemsFrame1TreeEdited(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
begin
//  PropsFrame1.RefreshTree;
  ItemsFrame1TreeChange(Sender, Node);
  if ItemsFrame1.GetNodeItem(Node) <> nil then App.Config['LastItem'] := ItemsFrame1.GetNodeItem(Node).GetFullName;
end;

procedure TMainF.ActionShowMeshEditorExecute(Sender: TObject);
begin
  if not ScaleForm.Visible then ScaleForm.Show else ScaleForm.Hide;
end;

procedure TMainF.ItemsFrame1TreeDragOver(Sender: TBaseVirtualTree; Source: TObject; Shift: TShiftState; State: TDragState; Pt: TPoint; Mode: TDropMode; var Effect: Integer; var Accept: Boolean);
begin
  Accept := True;
end;

procedure TMainF.ItemsFrame1TreeDragDrop(Sender: TBaseVirtualTree; Source: TObject; DataObject: IDataObject; Formats: TFormatArray; Shift: TShiftState; Pt: TPoint; var Effect: Integer; Mode: TDropMode);

var
  FilesDropped: TStrings;
  TargetNode: PVirtualNode;

  procedure AddFile(DataObject: IDataObject; Target: TVirtualStringTree; Mode: TVTNodeAttachMode);
  var
    FormatEtc: TFormatEtc;
    Medium: TStgMedium;
    OLEData: PDropFiles;
    Files: Pointer;
    AnsiPtr: PAnsiChar;
    WidePtr: PWideChar;
    Str: string;
  begin
    if Mode = amNowhere then Exit;
    with FormatEtc do begin
      cfFormat := CF_HDROP;
      ptd      := nil;
      dwAspect := DVASPECT_CONTENT;
      lindex   := -1;
      tymed    := TYMED_HGLOBAL;
    end;
    if DataObject.QueryGetData(FormatEtc) = S_OK then begin
      if DataObject.GetData(FormatEtc, Medium) = S_OK then begin
        OLEData := GlobalLock(Medium.hGlobal);
        if Assigned(OLEData) then begin
          Target.BeginUpdate;
          TargetNode := Target.DropTargetNode;
          if TargetNode = nil then TargetNode := Target.FocusedNode;
          try
            //Files := PChar(OLEData) + OLEData^.pFiles;
            Files := PtrOffs(OLEData, OLEData^.pFiles);

            if OLEData^.fWide then begin
              WidePtr := Files;
              while WidePtr^ <> #0 do begin
                Str := '';
                while WidePtr^ <> #0 do begin
                  Str := Str + WidePtr^;
                  Inc(WidePtr);
                end;
                FilesDropped.Add(Str);
              end;
            end else begin
              AnsiPtr := Files;
              while AnsiPtr^ <> #0 do begin
                Str := '';
                while AnsiPtr^ <> #0 do begin
                  Str := Str + AnsiPtr^;
                  Inc(AnsiPtr);
                end;
                FilesDropped.Add(Str);
              end;
            end;

          finally
            GlobalUnlock(Medium.hGlobal);
            Target.EndUpdate;
          end;
        end;
        ReleaseStgMedium(Medium);
      end;
    end;
  end;

var
  i: Integer;
  AttachMode: TVTNodeAttachMode;
  DestItem: TItem;
  SelItems: TreeItemsArray;
  Params: TDragDropParams;
  Garbage: IRefcountedContainer;
begin
  Garbage := CreateRefcountedContainer();
  FilesDropped := TStringList.Create;
  Garbage.AddObject(FilesDropped);
  SelItems := nil;
  try
    if Length(Formats) > 0 then begin                                                 // Ole d'n'd
      ItemsFrame1.Tree.Header.SortColumn := -1;
      AttachMode := amAddChildLast;
      case Mode of
        dmAbove:  AttachMode := amInsertBefore;
        dmBelow:  AttachMode := amInsertAfter;
      end;

      DestItem := ItemsFrame1.GetNodeItem(Sender.DropTargetNode);
      if not Assigned(DestItem) then DestItem := Core.Root;

      Params := TDragDropParams.Create(DestItem, mmAddChildLast);
      case AttachMode of
        amInsertBefore:  Params.AttachMode := mmInsertBefore;
        amInsertAfter:   Params.AttachMode := mmInsertAfter;
        amAddChildFirst: Params.AttachMode := mmAddChildFirst;
      end;

      for i := 0 to High(Formats) do
        case Formats[i] of
          CF_HDROP: begin
            AddFile(DataObject, Sender as TVirtualStringTree, AttachMode);
            Break;
          end;
          CF_TEXT: Beep;
          CF_BITMAP: Beep;
          CF_DIB: Beep;
          CF_DIBV5: Beep;
          else if (Formats[i] = CF_VIRTUALTREE) and (Source = ItemsFrame1.Tree) and (Sender.DropTargetNode <> nil) then begin
            Effect := DROPEFFECT_MOVE;
            ItemsFrame1.Tree.ProcessDrop(DataObject, Sender.DropTargetNode, Effect, AttachMode);
            ItemsFrame1.DoForEachSelected(App.ActDragDrop, nil, Params, False);
            Break;
          end;
        end;

      Params.Free;
      ItemsChanged := True;
    end else begin
      // VCL drag'n drop, Effects contains by default both move and copy effect suggestion,
      // as usual the application has to find out what operation is finally to do
      Beep;
    end;
  except
    on E: Exception do OnException(Sender, E);
  end;
  
  FResTools.LoadFiles(ItemsFrame1.GetNodeItem(TargetNode), FilesDropped);
end;

procedure TMainF.RendererFrame1RenderPanelClick(Sender: TObject);
begin
  TimerProcessing := False;
  if MouseAction = maNone then Core.SendMessage(TMouseClickMsg.Create(LastMouseX, LastMouseY, IK_MOUSELEFT, Core.Input.Modifiers), nil, [mfCore]);
end;

procedure TMainF.RendererFrame1RenderPanelDblClick(Sender: TObject);
begin
  if MouseAction = maNone then Core.SendMessage(TMouseDblClickMsg.Create(LastMouseX, LastMouseY, IK_MOUSELEFT, Core.Input.Modifiers), nil, [mfCore]);
end;

procedure TMainF.HandleMouseMove(AX, AY: Integer);
begin
//
end;

procedure TMainF.RendererFrame1RenderPanelMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if (OldMouseX = X) and (OldMouseY = Y) then Exit;
  OldMouseX := X;
  OldMouseY := Y;

  if MouseAction = maNone then Core.SendMessage(TMouseMoveMsg.Create(X, Y, Core.Input.Modifiers), nil, [mfCore]);

  if ((ssLeft in Shift) or (ssRight in Shift)) and (MouseAction = maEditItem) then begin
    App.ActEditMap(ItemsFrame1.GetNodeItem(ItemsFrame1.Tree.FocusedNode), nil);
    WasIdleClick := False;
  end;
end;

procedure TMainF.HandleMouseUp(AX, AY, AButton: Integer);
begin
//
end;

procedure TMainF.RendererFrame1RenderPanelMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if MainF.WasIdleClick {and not MapEditing }then App.FinalizePick else
    if MouseAction = maEditItem then ItemsFrame1.DoForEachSelected(App.ActEditMapEnd, nil, nil, False);

  if MouseAction = maNone then begin
    if Button = mbLeft   then Core.SendMessage(TMouseUpMsg.Create(X, Y, IK_MOUSELEFT, Core.Input.Modifiers),   nil, [mfCore]);
    if Button = mbRight  then Core.SendMessage(TMouseUpMsg.Create(X, Y, IK_MOUSERIGHT, Core.Input.Modifiers),  nil, [mfCore]);
    if Button = mbMiddle then Core.SendMessage(TMouseUpMsg.Create(X, Y, IK_MOUSEMIDDLE, Core.Input.Modifiers), nil, [mfCore]);
  end;
  MouseAction := maNone;
end;

procedure TMainF.HandleMouseDown(AX, AY, AButton: Integer);
begin
  if not Assigned(App.GUIRoot) or not App.GUIRoot.IsWithinGUI(AX, AY) then begin
    if (AButton = IK_MOUSELEFT) then begin
      ItemsFrame1.DoForEachSelected(App.ActEditMapBegin, nil, nil, False);
    end;
//    if (MouseAction = maNone) or (MouseAction = maEditItem) then
      WasIdleClick := True;
    App.PickItem;
  end;
end;

procedure TMainF.RendererFrame1RenderPanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (ssCTRL in Shift) or (ssALT in Shift) or (ssShift in Shift) then begin
    if ssCTRL  in Shift then MouseAction := maMoveCamera;
    if ssALT   in Shift then MouseAction := maRotateCamera;
    if ssShift in Shift then MouseAction := maZoomCamera;
    LastMouseX := X; LastMouseY := Y;
    OSUtils.ClientToScreen((Sender as TWinControl).Handle, LastMouseX, LastMouseY);
  end;

  if MouseAction = maNone then begin
    if Button = mbLeft   then Core.SendMessage(TMouseDownMsg.Create(X, Y, IK_MOUSELEFT, Core.Input.Modifiers),   nil, [mfCore]);
    if Button = mbRight  then Core.SendMessage(TMouseDownMsg.Create(X, Y, IK_MOUSERIGHT, Core.Input.Modifiers),  nil, [mfCore]);
    if Button = mbMiddle then Core.SendMessage(TMouseDownMsg.Create(X, Y, IK_MOUSEMIDDLE, Core.Input.Modifiers), nil, [mfCore]);
  end;
end;

procedure TMainF.RendererFrame1RenderPanelMouseWheel(Sender: TObject; Shift: TShiftState; Delta: Integer);
begin
  ZoomCamera(-Delta*0.1);
end;

procedure TMainF.UpdatePropsTimerTimer(Sender: TObject);
begin
  FClickedOnItem := True;
  if CollectProperties then PropsFrame1.UpdateTree else PropsFrame1.Tree.Clear;
  if not IsMouseOverControl(TimeScalePanel) and not IsMouseOverControl(ItemsFrame1.BtnPause) and
    (GetCaptureControl <> trkTimeScale) then
    TimeScalePanel.Hide;    
end;

procedure TMainF.ActionOptionsGUIFitterExecute(Sender: TObject);
begin
//  EditorSetupItem := GUIFitterItem;
  CollectProperties;
  PropsFrame1.RefreshTree;
end;

procedure TMainF.ActionOptionsWorldFitterExecute(Sender: TObject);
begin
//  EditorSetupItem := WorldFitterItem;
  CollectProperties;
  PropsFrame1.RefreshTree;
end;

procedure TMainF.SelectItem(const AFullName: string);
begin
  ItemsFrame1.FindItemByName(AFullName);
end;

procedure TMainF.RefreshItems;
begin
  ItemsFrame1.RefreshTree;
  PropsFrame1.RefreshTree;
end;

procedure TMainF.DockPanelBottomDockOver(Sender: TObject; Source: TDragDockObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
var t: TRect;
begin
  t := Source.DockRect;
  t.Top := Source.DockRect.Bottom - Source.Control.ClientRect.Bottom + Source.Control.ClientRect.Top;
  Source.DockRect := t;
end;

procedure TMainF.DockPanelLeftDockOver(Sender: TObject; Source: TDragDockObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
var t: TRect;
begin
  t := Source.DockRect;
  t.Left := Source.DockRect.Right - Source.Control.ClientRect.Right + Source.Control.ClientRect.Left;
  Source.DockRect := t;
end;

procedure TMainF.SplitterLeftCanResize(Sender: TObject; var NewSize: Integer; var Accept: Boolean);
begin
//  DockPanelLeft.Width := NewSize;
//  DockPanelLeft.Realign;
//  Accept := True;
end;

procedure TMainF.AutoSizeDockPanels;
begin
  DockPanelLeft.AutoSize   := True;
  DockPanelLeft.AutoSize   := False;
  DockPanelBottom.AutoSize := True;
  DockPanelBottom.AutoSize := False;
  NeedAutoSizeDockPanels   := False;
end;

procedure TMainF.DockPanelDockDrop(Sender: TObject; Source: TDragDockObject; X, Y: Integer);
begin
  AutoSizeDockPanels;
end;

procedure TMainF.DockPanelUnDock(Sender: TObject; Client: TControl; NewTarget: TWinControl; var Allow: Boolean);
begin
  NeedAutoSizeDockPanels := True;
end;

procedure TMainF.DockPanelClick(Sender: TObject);
begin
  AutoSizeDockPanels
end;

var IsHandlingMWheel: Boolean = false;

procedure TMainF.FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);

  function MouseInControl(AControl: TControl): Boolean;
  var TopLeft, BottomRight: TPoint;
  begin
    TopLeft     := AControl.ClientToScreen(AControl.BoundsRect.TopLeft);
    BottomRight := AControl.ClientToScreen(AControl.BoundsRect.BottomRight);
    Result := (MousePos.X >= TopLeft.X)     and (MousePos.Y >= TopLeft.Y) and
              (MousePos.X <  BottomRight.X) and (MousePos.Y <  BottomRight.Y);
    Handled := Handled or Result;
  end;

  procedure ScrollControl(AControl: TWinControl; XDelta, YDelta: Integer);
  var i: Integer;
  begin
    for i := 0 to     XDelta-1 do SendMessage(AControl.Handle, WM_HSCROLL, SB_LINEUP, 0);
    for i := 0 downto XDelta+1 do SendMessage(AControl.Handle, WM_HSCROLL, SB_LINEDOWN, 0);
    for i := 0 to     YDelta-1 do SendMessage(AControl.Handle, WM_VSCROLL, SB_LINEUP, 0);
    for i := 0 downto YDelta+1 do SendMessage(AControl.Handle, WM_VSCROLL, SB_LINEDOWN, 0);
  end;


  procedure MWheelForm(AForm: TForm);
  var LMousePos: TPoint; LControl: TControl;
  begin
     if IsHandlingMWheel then Exit;
     IsHandlingMWheel := True;
    GetCursorPos(LMousePos);
    LMousePos := AForm.ScreenToClient(LMousePos);
    LControl := AForm.ControlAtPos(LMousePos, false, true);
    if not (LControl is TWinControl) then LControl := MainF;
//    LControl.Perform(WM_MOUSEWHEEL, WheelDelta*65536, MousePos.Y*65536+MousePos.X);
     ScrollControl(TWinControl(LControl), 0, WheelDelta div 64);
     IsHandlingMWheel := False;

  end;
var i: Integer;
begin
  Handled := False;
  if MouseInControl(RendererFrame1.RenderPanel) then RendererFrame1RenderPanelMouseWheel(Sender, Shift, WheelDelta);
  if MouseInControl(ItemsFrame1.Tree) then ScrollControl(ItemsFrame1.Tree, 0, WheelDelta div 32);
  if MouseInControl(PropsFrame1.Tree) then ScrollControl(PropsFrame1.Tree, 0, WheelDelta div 64);
//  for i := 0 to Screen.FormCount-1 do if Screen.Forms[i].Visible then MWheelForm(Screen.Forms[i]);
end;

function TMainF.ForEachD(Item: TItem; Index: Integer; Data: Pointer): Boolean;
begin
  Log('Del>' + IntToStr(Index) + ': ' + Item.Name);
  Result := False;
end;

function ForEachCB(Item: TItem; Index: Integer; Data: Pointer): Boolean;
begin
  Log('CB>' + IntToStr(Index) + ': ' + Item.Name);
  Result := False;
end;

procedure TMainF.ActionPauseExecute(Sender: TObject);
begin
  Core.Paused := not Core.Paused;
//  ActionPause.ImageIndex := 3 + Ord(Core.Paused);
  Pause1.Checked            := Core.Paused;
  ItemsFrame1.BtnPause.Down := Core.Paused;
end;

function TMainF.GetMapEditMode: Boolean;
begin
  Result := PropEditF.Visible;
end;

procedure TMainF.SetMapEditMode(const Value: Boolean);
begin
  PropEditF.Visible := Value;
  MapEditF.Visible  := Value;
end;

procedure TMainF.ActionShowMapEditorExecute(Sender: TObject);
begin
  MapEditMode := not MapEditMode;
end;

procedure TMainF.ActionShowStatisticsExecute(Sender: TObject);
begin
  if not StatF.Visible then StatF.Show else StatF.Hide;
end;

procedure TMainF.ActionShowNewMaterialExecute(Sender: TObject);
begin
  if not FormNewMaterial.Visible then FormNewMaterial.Show else FormNewMaterial.Hide;
end;

procedure TMainF.ActionGraphValueEditorExecute(Sender: TObject);
begin
  if not PEmitterForm.Visible then PEmitterForm.Show else PEmitterForm.Hide;
end;

procedure TMainF.ActionConfigExecute(Sender: TObject);
begin
  ConfigForm.ShowModal;
end;

procedure TMainF.ActionAboutExecute(Sender: TObject);
begin
  AboutForm.ShowModal;
end;

procedure TMainF.ActionUndoExecute(Sender: TObject);
begin
  if GUIHelper.IsInputInProcess() then
    SendMessage(GetFocus, WM_UNDO, 0, 0)
  else begin
    App.OperationManager.Undo;
    ActionUndo.Enabled := App.OperationManager.CanUndo;
    ActionRedo.Enabled := App.OperationManager.CanRedo;
  end;
end;

procedure TMainF.ActionRedoExecute(Sender: TObject);
begin
  if GUIHelper.IsInputInProcess() then
    SendMessage(GetFocus, WM_UNDO, 0, 0)
  else begin
    App.OperationManager.Redo;
    ActionRedo.Enabled := App.OperationManager.CanRedo;
    ActionUndo.Enabled := App.OperationManager.CanUndo;
  end;
end;

procedure TMainF.ItemsFrame1TreeCollapsed(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  FClickedOnItem := False;
end;

procedure TMainF.ItemsFrame1TreeExpanded(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  FClickedOnItem := False;
end;

procedure TMainF.ItemsFrame1TreeGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean; var ImageIndex: Integer);
var Item: TItem;

  function MatchIconClass(Index: Integer): Boolean;
  var ItemClass: CItem;
  begin
    ItemClass := Core.FindItemClass(ClassIcons[Index].Name);
    Assert(Assigned(ItemClass), ClassIcons[Index].Name);
    Result := Item is ItemClass;
  end;

begin
  if Column <> 2 then Exit;
  Item := ItemsFrame1.GetNodeItem(Node);
  ImageIndex := High(ClassIcons);
  while (ImageIndex >= 0) and not MatchIconClass(ImageIndex) do Dec(ImageIndex);
  if ImageIndex >= 0 then ImageIndex := ClassIcons[ImageIndex].IconIndex;
end;

procedure TMainF.ItemsFrame1TreeHeaderClick(Sender: TVTHeader;
  Column: TColumnIndex; Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  ItemsFrame1.TreeHeaderClick(Sender, Column, Button, Shift, X, Y);

end;

end.
