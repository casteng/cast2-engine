{$I GDefines.Inc}
{$I C2Defines.Inc}
unit C2EdMain;

interface

uses
  Logger,
  SysUtils,
  BaseDebug,
  Template,
  BasePlugins,
  BaseMsg, Models, ItemMsg, CAST2, Resources, C2Res, BaseGraph, Base3D, C2Materials,
  {$IFDEF USEVAMPYRE}
    VampyreCarrier,
  {$ENDIF}
  C2MapEditMsg, C22D, C2GUI,
  ACSBase, GUIMsg, GUIFitter,
  C2Visual,
  C2EdUtil,
  C2Core,
  {$IFDEF USENEWTON} C2NewtonPhysics, {$ELSE} C2BasicPhysics, {$ENDIF}
  BaseTypes, Basics, Props, BaseClasses, AppsInit, OSUtils, VCLHelper;

const
  DataBaseFileExt = '.cbf';
  BackupFileExt   = '.cbk';
  PreviousFileExt = '.cbp';
  NodeFileExt     = '.cnf';

type
  TActionParams = class
  end;

  TPropertiesParams = class(TActionParams)
    Properties: Props.TProperties;
    constructor Create(AProperties: Props.TProperties);
  end;

  TDragDropParams = class(TActionParams)
    TargetItem: TItem;
    AttachMode: TItemMoveMode;
    constructor Create(ATargetItem: TItem; AAttachMode: TItemMoveMode);
  end;

  TClipboardParams = class(TActionParams)
    Clipboard: TStreamClipboard;
    constructor Create(AStreamClipboard: TStreamClipboard);
  end;

  TItemAction = procedure(Item: TItem; Params: TActionParams) of object;

  TItemNodeData = record
    Item: TItem;
  end;

  TC2EdApp = class(TVCLApp)
  public
    constructor Create(const AProgramName: string; AStarter: TAppStarter); override;
    procedure Init;
    destructor Destroy; override;

    procedure LoadPlugin(const Name: string);
    function LoadPluginDelegate(const Name: string): Boolean;

    procedure HandleMessage(const Msg: TMessage);
    function PickItem: Boolean;
    procedure CenterItem(Item: TProcessing);

    procedure ObtainNewItemData(const FullName: AnsiString; out ItemName: AnsiString; out Parent: TItem);

    procedure CancelPick;
    procedure FinalizePick;

    function IsTrial: Boolean; override;

    function SaveItem(Item: TItem; const FileName: string): Boolean;
    function SaveAs(const FileName: string): Boolean;
    procedure Save;
    function LoadAs(Item: TItem; const FileName: string): Boolean;
    procedure LoadFrom(const FileName: string);
    procedure Load;

    // Actions
    procedure ActNewScene;
    procedure ActNewItem(ItemClass: CItem; Parent: TItem);
    // Action callbacks
    procedure ActDeleteItem(Item: TItem; Params: TActionParams);
    procedure ActMoveUpItem(Item: TItem; Params: TActionParams);
    procedure ActMoveDownItem(Item: TItem; Params: TActionParams);
    procedure ActMoveLeftItem(Item: TItem; Params: TActionParams);
    procedure ActMoveRightItem(Item: TItem; Params: TActionParams);
    procedure ActDragDrop(Item: TItem; Params: TActionParams);
    procedure ActCopyItem(Item: TItem; Params: TActionParams);
    procedure ActDefault(Item: TItem; Params: TActionParams);
    procedure ActDuplicateItem(Item: TItem; Params: TActionParams);
    procedure ActPickItem(Item: TItem; Params: TActionParams);
    procedure ActEditHighlight(Item: TItem; Params: TActionParams);
    procedure ActEditMapBegin(Item: TItem; Params: TActionParams);
    procedure ActEditMap(Item: TItem; Params: TActionParams);
    procedure ActEditMapEnd(Item: TItem; Params: TActionParams);
    // Other delegates
    procedure OnApplyPropEdit(AChangedProps: TProperties);

    // Events
    procedure OnActivate(Sender: TObject);
    procedure OnDeActivate(Sender: TObject);
    procedure OnIdle(Sender: TObject; var Done: Boolean);
    procedure OnException(Sender: TObject; E: Exception);
  private
    EditMouseX, EditMouseY: Integer;
    // Temporary GUI root item
    FIGUIRootItem,
    // Reference to current GUI root item
    FGUIRootItem: TGUIRootItem;

    GUIFitterItem: TFitter;
    WorldFitterItem: T3DFitter;
    FEditorDummy: TDummyItem;
    FPickedItem: TProcessing;

    procedure HandleEdit;
    procedure AddFitters;
    procedure RemoveFitters;
    function GetTempFilename(Name: string = ''): string;
  public
    Active: Boolean;
    OperationManager: TOperationManager;
    ItemsList: TItemsList;
    LastItemAdded: TItem;
    function IsServiceItem(AItem: TItem): Boolean;
    procedure UpdateFitters;
    procedure OnTimer;
    function AddOperation(AOperation: TOperation): Boolean;          // Returns True if operation added to undo/redo queue
    property GUIRoot: TGUIRootItem read FGUIRootItem;
  end;

  _VectorValueType = NativeInt;
  {$MESSAGE 'Instantiating TIntVector interface'}
  {$I gen_coll_vector.inc}
  TIntVector = class(_GenVector) end;

type
  _HashMapKeyType = NativeInt;
  _HashMapValueType = TIntVector;
  {$MESSAGE 'Instantiating TIntIntVecHashMap interface'}
  {$I gen_coll_hashmap.inc}
  TIntIntVecHashMap = class(_GenHashMap) end;

var
  Core: TCore;
  App: TC2EdApp;
  GUIHelper: TVCLGUIHelper;

implementation

uses MapEditForm, FPropEdit, MainForm, Dialogs, AppHelper, Windows;

{$MESSAGE 'Instantiating TIntVector'}
{$I gen_coll_vector.inc}

const
  _HashMapOptions = [dsNullable];

{$MESSAGE 'Instantiating TIntIntVecHashMap'}
{$I gen_coll_hashmap.inc}

{ TPropertiesParams }

constructor TPropertiesParams.Create(AProperties: Props.TProperties);
begin
  Properties := AProperties;
end;

{ TDragDropParams }

constructor TDragDropParams.Create(ATargetItem: TItem; AAttachMode: TItemMoveMode);
begin
  TargetItem := ATargetItem;
  AttachMode := AAttachMode;
end;

{ TClipboardParams }

constructor TClipboardParams.Create(AStreamClipboard: TStreamClipboard);
begin
  Clipboard := AStreamClipboard;
end;

{ TC2EdApp }                 

constructor TC2EdApp.Create(const AProgramName: string; AStarter: TAppStarter);
begin
  inherited;
  if not Config.Valid('LastItem')               then Config.Add('LastItem',               vtString,  [], '',   '');
  if not Config.Valid('SaveAndExitOnException') then Config.Add('SaveAndExitOnException', vtBoolean, [], 'On', '');
  if not Config.Valid('AutoReloadResource')     then Config.Add('AutoReloadResource',     vtBoolean, [], 'On', '');
  if not Config.Valid('Render\SoftwareVP')      then Config.Add('Render\SoftwareVP',      vtBoolean, [], 'Off', '');

  KeyCfg := Config;

  Core  := TCore.Create;
  Core.MessageHandler := HandleMessage;
  {$IFDEF USENEWTON}
  Core.Physics := TNewtonPhysics.Create;
  {$ELSE}
  Core.Physics := TBasicPhysics.Create;
  {$ENDIF}
  ItemsList        := TItemsList.Create(Core, [TImageResource, TMaterial, TShaderResource]);
  OperationManager := TOperationManager.Create;
end;

// Invoked after init of all forms and renderer
procedure TC2EdApp.Init;
const TempPrefix: string[3] = '_$_';
begin
  {$IFDEF USEVAMPYRE}
    ResourceLinker.RegisterCarrier(TVampyreCarrier.Create);
  {$ENDIF}  

  GUIFitterItem := T2DFitter.Create(Core);
  GUIFitterItem.Name := TempPrefix + 'GUI fitter';
  GUIFitterItem.UseOperations := True;
  GUIFitterItem.State := GUIFitterItem.State + [isVisible, isProcessing];
  (GUIFitterItem.AggregatedItem as TVisible).Material := Core.DefaultMaterial;

  WorldFitterItem := T3DFitter.Create(Core);
  WorldFitterItem.Name := TempPrefix + 'World fitter';
  WorldFitterItem.UseOperations := True;
  WorldFitterItem.State := WorldFitterItem.State + [isVisible, isProcessing];

  FEditorDummy := TDummyItem.Create(Core);
  FEditorDummy.Name := TempPrefix + 'Dummy';
  FEditorDummy.State := FEditorDummy.State + [isVisible];

  FIGUIRootItem := TGUIRootItem.Create(Core);
  FIGUIRootItem.Name := TempPrefix + 'GUIRoot';
  FIGUIRootItem.State := FIGUIRootItem.State + [isVisible, isProcessing];
//  FEditorDummy.AddChild(FIGUIRootItem);

  FEditorDummy.AddChild(Core.DefaultMaterial);

  ActNewScene();
end;

destructor TC2EdApp.Destroy;
var Subsys: TSubsystem;
begin
  RemoveFitters;
  Core.DefaultMaterial.Parent := nil;
  FreeAndNil(FEditorDummy);
  FreeAndNil(FIGUIRootItem);
  FreeAndNil(GUIFitterItem);
  FreeAndNil(WorldFitterItem);

  FreeAndNil(OperationManager);

  Subsys := Core.Renderer;
  Core.Renderer := nil;
  Subsys.Free;

  Subsys := Core.Input;
  Core.Input := nil;
  FreeAndNil(Subsys);

  Subsys := Core.Physics;
  Core.Physics := nil;
  Subsys.Free;

  FreeAndNil(Core);
  FreeAndNil(ItemsList);
  inherited;
end;

procedure TC2EdApp.LoadPlugin(const Name: string);
begin
  Log('Loading package "' + Name + '"');
  case PluginSystem.LoadPlugin(Name) of
    lpOK: Log('Package load successful');
    lpLoadPackageFail: Log('LoadPackage() failed', lkError);
    lpRegisterNotCalled: Log('Package "' + Name + '" did not called RegisterPackage procedure', lkError);
    else Log('Unknown result', lkError);
  end;
end;

function TC2EdApp.LoadPluginDelegate(const Name: string): Boolean;
begin
  Result := True;
  LoadPlugin(Name);
end;

procedure TC2EdApp.HandleMessage(const Msg: TMessage);
begin
  if Msg is TMouseMsg then begin
    if Msg.ClassType = TMouseMoveMsg then with TMouseMoveMsg(Msg) do MainF.HandleMouseMove(X, Y);
    if Msg is TMouseButtonMsg then with TMouseButtonMsg(Msg) do begin
      if Msg.ClassType = TMouseDownMsg then MainF.HandleMouseDown(X, Y, Button);
      if Msg.ClassType = TMouseUpMsg   then MainF.HandleMouseUp(X, Y, Button);
    end;
  end else if Msg.ClassType = TGUIClickMsg then with TGUIMessage(Msg) do begin
    if not (Item is TFitter) then MainF.ItemsFrame1.FindItemByName(Item.GetFullName);
    FPickedItem := nil;
    MainF.WasIdleClick := False;
  end else if Msg.ClassType = TSubsystemMsg then with TSubsystemMsg(Msg) do begin
    if Subsystem is TGUIRootItem then case Action of
      saConnect: begin
        FGUIRootItem := Subsystem as TGUIRootItem;
//        AddFitters;
      end;
      saDisconnect: begin
//        RemoveFitters;
        FGUIRootItem := nil;
      end;
    end;
  end else if (Msg.ClassType = TOperationMsg) then begin
    AddOperation(TOperationMsg(Msg).Operation)
  end else if (Msg.ClassType = TProgressMsg) then begin
    MainF.ItemsFrame1.ProgressBar1.Show;
    MainF.ItemsFrame1.ProgressBar1.Position := ClampI(Round(TProgressMsg(Msg).Progress * 100), 0, 100);
    MainF.ItemsFrame1.ProgressBar1.Repaint;
  end;

  ItemsList.HandleMessage(Msg);

  if Msg.ClassType = TMouseMoveMsg then CancelPick;
end;

function TC2EdApp.PickItem: Boolean;
begin
  FPickedItem := MainF.GetObjectsUnderCursor;
  Result := Assigned(FPickedItem) and (FPickedItem <> MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode));
end;

procedure TC2EdApp.CenterItem(item: TProcessing);
var ItemPos, ItemInCamera: TVector3s; X, Y, Z: Single;
begin
  if not Assigned(Core.Renderer.MainCamera) then Exit;

  ItemPos := ScaleVector3s(AddVector3s(Item.BoundingBox.P1, Item.BoundingBox.P2), 0.5);
  ItemPos := Transform4Vector33s(Item.Transform, ItemPos);

  if Core.Renderer.MainCamera is TLookAtCamera then begin
    with (Core.Renderer.MainCamera as TLookAtCamera) do LookTarget := ItemPos;
  end else with Core.Renderer.MainCamera do begin
    // Move camera to get the item on look ray
    ItemInCamera :=  SubVector3s(ItemPos, Position);
    X := DotProductVector3s(RightDir, ItemInCamera);
    Y := DotProductVector3s(UpDir,    ItemInCamera);
    Position     := AddVector3s(Location.XYZ, ScaleVector3s(RightDir, X));
    Position     := AddVector3s(Location.XYZ, ScaleVector3s(UpDir, Y));
    // Correct camera position on look ray
    ItemInCamera :=  SubVector3s(ItemPos, Position);
    Z := DotProductVector3s(LookDir, ItemInCamera) - Item.BoundingSphereRadius*2;
    Position     := AddVector3s(Location.XYZ, ScaleVector3s(LookDir, Z));
  end;
end;

procedure TC2EdApp.CancelPick;
begin
  FPickedItem := nil;
//   Log(Format('%S.%S: Canceled pick', [ClassName, 'CancelPick']), lkError); 
end;

procedure TC2EdApp.FinalizePick;
begin
  if Assigned(FPickedItem) then begin
    MainF.ItemsFrame1.FindItemByName(FPickedItem.GetFullName);
    if MainF.WasIdleClick then MainF.WasIdleClick := False;
    MainF.MouseAction := maNone;
  end;
  FPickedItem := nil;
end;

function TC2EdApp.IsTrial: Boolean;
begin
  Result := inherited IsTrial;
end;

function TC2EdApp.SaveItem(Item: TItem; const FileName: string): Boolean;
var Stream: Basics.TFileStream; Garbage: IRefcountedContainer;
begin
  Result := False;
  Stream := Basics.TFileStream.Create(FileName, fuReadWrite);
  Garbage := CreateRefcountedContainer;
  Garbage.AddObject(Stream);

  if (Item =  nil) and Core.SaveScene(Stream) or
     (Item <> nil) and Item.Save(Stream) then Result := True else begin
    
    Log('Error writing to file "' + FileName + '"', lkError)
    
  end;
end;

function TC2EdApp.SaveAs(const FileName: string): Boolean;
var fn: string;
begin
  Result := False;
  RemoveFitters;
  try
    // Make a backup copy of previously saved database
    fn := ChangeFileExt(FileName, PreviousFileExt);
    SysUtils.DeleteFile(fn);
    SysUtils.RenameFile(FileName, fn);
    // Save current database
    if SaveItem(nil, FileName) then Result := True;
    // Save again in another file
    SaveItem(nil, ChangeFileExt(FileName, BackupFileExt));
  finally
    AddFitters;
  end;

  MainF.ItemsChanged := not Result;

  
  if Result then Log('Save successful');
  
end;

procedure TC2EdApp.Save;
begin
  if not Config.Exists('CurrentDBFile') or (Config['CurrentDBFile'] = '') then Exit;
  SaveAs(Config['CurrentDBFile']);
end;

function SelectCamera(Item: TItem): TTraverseResult;
begin
  Result := trContinue;
  if Item is TCamera then begin
    Core.Renderer.MainCamera := Item as TCamera;
    MainF.AffectedCamera := Core.Renderer.MainCamera;
    Result := trStop;
  end;
end;

function TC2EdApp.LoadAs(Item: TItem; const FileName: string): Boolean;
var Stream: Basics.TFileStream; Garbage: IRefcountedContainer;
begin
  Result := False;

  Stream := Basics.TFileStream.Create(FileName, fuReadWrite, smAllowAll);
  Garbage := CreateRefcountedContainer;
  Garbage.AddObject(Stream);

  if Item = nil then begin
    RemoveFitters();
    try
      if Core.LoadScene(Stream) then Result := True;
      if not Assigned(Core.Root) then Core.Root := TCASTRootItem.Create(Core);
    finally
      AddFitters();
    end;
  end else Result := Core.LoadItem(Stream, Item) <> nil;

  if not Result then begin
    Log('Error opening file "' + FileName + '"', lkError)
  end else
    if Item = nil then begin
      (Core.Root as TCASTRootItem).TraverseTree(SelectCamera);
      MainF.ItemsFrame1.Tree.RootNodeCount := 0;
    end;
  if Item = nil then MainF.ItemsChanged := not Result else if Result then MainF.ItemsChanged := True;
end;

procedure TC2EdApp.LoadFrom(const FileName: string);
begin
  Log('TC2EdApp.LoadFrom: Loading database from file "' + FileName + '"');
  if not LoadAs(nil, FileName) then begin
    SysUtils.Beep;
    Log('Error loading data. Trying backup database...', lkError);
    if LoadAs(nil, ChangeFileExt(FileName, BackupFileExt)) then Save else begin
      Log('Database is damaged. Will try to restore previous version', lkError);
      MessageDlg('Database is damaged. Will try to restore previous version', mtError, [mbOK], 0);
      if LoadAs(nil, ChangeFileExt(FileName, PreviousFileExt)) then begin
        MessageDlg('Success!', mtInformation, [mbOK], 0);
        Save;
      end else begin
        MessageDlg('Failed', mtError, [mbOK], 0);
        Exit;
      end;
    end;
  end;
  if not Assigned(Core.Root) then Core.Root := TCASTRootItem.Create(Core);
  MainF.CurrentDBFile := FileName;
  Log('Load successful');
  MainF.RefreshItems;
end;

procedure TC2EdApp.Load;
begin
  if not Config.Exists('CurrentDBFile') or (Config['CurrentDBFile'] = '') then Exit;
  LoadFrom(Config['CurrentDBFile']);
end;

procedure TC2EdApp.ActDeleteItem(Item: TItem; Params: TActionParams);
begin
  if Assigned(Item.Parent) then begin
    Item.Parent.RemoveChild(Item);
//    Item.Free;
    MainF.ItemsChanged := True;
  end else MessageDlg('Can''t delete root item!', mtError, [mbOK], 0);  
end;

procedure TC2EdApp.ActDragDrop(Item: TItem; Params: TActionParams);
var Pars: TDragDropParams;
begin
  Pars := Params as TDragDropParams;
  if (Pars.TargetItem <> Item) and not Pars.TargetItem.IsChildOf(Item) then
    Item.Parent.MoveChild(Item, Pars.TargetItem, Pars.AttachMode);
end;

procedure TC2EdApp.ActMoveDownItem(Item: TItem; Params: TActionParams);
begin

end;

procedure TC2EdApp.ActMoveLeftItem(Item: TItem; Params: TActionParams);
begin

end;

procedure TC2EdApp.ActMoveRightItem(Item: TItem; Params: TActionParams);
begin

end;

procedure TC2EdApp.ActMoveUpItem(Item: TItem; Params: TActionParams);
begin

end;

procedure TC2EdApp.ActNewScene;
var Camera: TCamera;
begin
  RemoveFitters();
  Core.ClearItems;
  OperationManager.Clear;

  Core.Root := TCASTRootItem.Create(Core);
  Camera := TCamera.Create(Core);

  MainF.AffectedCamera := nil;

  Core.Root.AddChild(Camera);
  Core.DefaultMaterial.Clone().Parent := Core.Root;
  TC2Screen(Screen).SetCore(nil);
  TC2Screen(Screen).SetCore(Core);

  AddFitters();
end;

procedure TC2EdApp.ActNewItem(ItemClass: CItem; Parent: TItem);
var Item: TItem; FittersRemoved: Boolean;
begin
  if ItemClass.InheritsFrom(TGUIItem) then begin
    if not Assigned(FGUIRootItem) or (FGUIRootItem = FIGUIRootItem) then begin
      Log('Can''t create GUI item: should create TGUIRootItem first');
      Exit;
    end;
    if not Assigned(Parent) or not ( (Parent = FGUIRootItem) or Parent.IsChildOf(FGUIRootItem) ) then begin
      Parent := FGUIRootItem;
      Log('Parent for GUI item changed to ' + FGUIRootItem.GetFullName);
    end;
  end;

  FittersRemoved := ItemClass.InheritsFrom(TGUIRootItem);
  if FittersRemoved then RemoveFitters;

  try
    Item := ItemClass.Construct(Core);
    if not Assigned(Parent) then Parent := Core.Root;

    Parent.AddChild(Item);
    Log('Item of class "' + ItemClass.ClassName + '" created as a child of item "' + Parent.GetFullName + '"');

    if Item is TCamera and not Assigned(Core.Renderer.MainCamera) then Core.Renderer.MainCamera := Item as TCamera;

    MainF.ItemsFrame1.RefreshTree;
    MainF.ItemsChanged := True;

    MainF.SelectItem(Item.GetFullName);
  finally
    if FittersRemoved then AddFitters;
  end;
end;

function TC2EdApp.GetTempFilename(Name: string): string;
begin

end;

procedure TC2EdApp.ActCopyItem(Item: TItem; Params: TActionParams);
begin
  (Params as TClipboardParams).Clipboard.PushObject;
  Item.Save((Params as TClipboardParams).Clipboard.Stream);
end;

procedure TC2EdApp.ActDefault(Item: TItem; Params: TActionParams);
begin
  if Item is TCamera then
    Core.Renderer.MainCamera := Item as TCamera
  else if Item is Resources.TResource then
    ShowResource(Item as Resources.TResource)
  else if Item is TSyncItem then
    TSyncItem(Item).Syncronize
  else if Item is TProcessing then
    CenterItem(Item as TProcessing);
end;

procedure TC2EdApp.ActDuplicateItem(Item: TItem; Params: TActionParams);
begin
  if Assigned(Item) and (Item <> Core.Root) then Item.Clone;
end;

procedure TC2EdApp.ActPickItem(Item: TItem; Params: TActionParams);
begin
  if Assigned(Item) then Item.State := Item.State + [isPicked];
end;

procedure TC2EdApp.ActEditHighlight(Item: TItem; Params: TActionParams);
var MX, MY: Integer; 
begin
  if not PropEditF.Visible or not Assigned(Item) or not (isVisible in Item.State) then Exit;
  OSUtils.ObtainCursorPos(MX, MY);
  OSUtils.ScreenToClient(MainF.RendererFrame1.RenderPanel.Handle, MX, MY);
  BaseGraph.Screen.Reset;
  MapEditF.MapCursor.MouseX := MX;
  MapEditF.MapCursor.MouseY := MY;
  MapEditF.MapCursor.Camera := Core.Renderer.MainCamera;
  MapEditF.MapCursor.Screen := BaseGraph.Screen;
  (BaseGraph.Screen as TC2Screen).SetTechnique(pkSolid, Core.DefaultMaterial.GetTechniqueByLOD(0));
  Item.HandleMessage(TMapDrawCursorMsg.Create(MapEditF.MapCursor));
end;

procedure TC2EdApp.HandleEdit;
begin
  if Assigned(MapEditF.MapCursor.Operation) then begin
    if AddOperation(MapEditF.MapCursor.Operation) then MapEditF.MapCursor.Operation := nil;

    MapEditF.MapCursor.LastEditMouseX := EditMouseX;
    MapEditF.MapCursor.LastEditMouseY := EditMouseY;
    
    MainF.MouseAction  := maEditItem;
    MainF.ItemsChanged := True;
    MainF.WasIdleClick := False;
  end;
end;

procedure TC2EdApp.ActEditMapBegin(Item: TItem; Params: TActionParams);
begin
  if not PropEditF.Visible or not Assigned(Item) or not (isVisible in Item.State) then Exit;
  OSUtils.ObtainCursorPos(EditMouseX, EditMouseY);
  OSUtils.ScreenToClient(MainF.RendererFrame1.RenderPanel.Handle, EditMouseX, EditMouseY);
  MapEditF.MapCursor.MouseX := EditMouseX;
  MapEditF.MapCursor.MouseY := EditMouseY;
  MapEditF.MapCursor.Camera := Core.Renderer.MainCamera;
  MapEditF.MapCursor.Screen := BaseGraph.Screen;

  Item.HandleMessage(TMapModifyBeginMsg.Create(MapEditF.MapCursor));
  if Assigned(MapEditF.MapCursor.Operation) then HandleEdit;
end;

procedure TC2EdApp.ActEditMap(Item: TItem; Params: TActionParams);
begin
  if not PropEditF.Visible or not Assigned(Item) or not (isVisible in Item.State) then Exit;
  OSUtils.ObtainCursorPos(EditMouseX, EditMouseY);
  OSUtils.ScreenToClient(MainF.RendererFrame1.RenderPanel.Handle, EditMouseX, EditMouseY);
  MapEditF.MapCursor.MouseX := EditMouseX;
  MapEditF.MapCursor.MouseY := EditMouseY;
  MapEditF.MapCursor.Camera := Core.Renderer.MainCamera;
  MapEditF.MapCursor.Screen := BaseGraph.Screen;

  Item.HandleMessage(TMapModifyMsg.Create(MapEditF.MapCursor));
  if Assigned(MapEditF.MapCursor.Operation) then HandleEdit;
end;

procedure TC2EdApp.ActEditMapEnd(Item: TItem; Params: TActionParams);
begin
  if not PropEditF.Visible or not Assigned(Item) or not (isVisible in Item.State) then Exit;
  Item.HandleMessage(TMapModifyEndMsg.Create(MapEditF.MapCursor));
  if Assigned(MapEditF.MapCursor.Operation) then HandleEdit;
end;

procedure TC2EdApp.OnApplyPropEdit(AChangedProps: TProperties);
begin
  MapEditF.MapCursor.Params.Merge(AChangedProps, True);
end;

procedure TC2EdApp.AddFitters;
begin
  if Assigned(FEditorDummy) then begin
    Core.Root.AddChild(FEditorDummy);
    FEditorDummy.State := FEditorDummy.State - [isVisible];
    if FGUIRootItem = nil then begin
      FIGUIRootItem.Parent := FEditorDummy;
      (FIGUIRootItem.AggregatedItem as TVisible).Material := Core.DefaultMaterial;
      (FIGUIRootItem.AggregatedItem as TVisible).Material;
    end;
  end;
  if not Assigned(FGUIRootItem) then Exit;
  if Assigned(GUIFitterItem) then begin
    FGUIRootItem.AddChild(GUIFitterItem);
    GUIFitterItem.State := GUIFitterItem.State - [isVisible];
//    (GUIFitterItem.AggregatedItem as TVisible).Material := Core.DefaultMaterial;
    (GUIFitterItem.AggregatedItem as TVisible).Material;
  end;

  if Assigned(WorldFitterItem) then begin
    FGUIRootItem.AddChild(WorldFitterItem);
    WorldFitterItem.State := WorldFitterItem.State - [isVisible];
    (WorldFitterItem.AggregatedItem as TVisible).Material := Core.DefaultMaterial;
    (WorldFitterItem.AggregatedItem as TVisible).Material;
  end;
end;

procedure TC2EdApp.RemoveFitters;
begin
  if Assigned(GUIFitterItem)   and Assigned(GUIFitterItem.Parent)   then GUIFitterItem.Parent   := nil;
  if Assigned(WorldFitterItem) and Assigned(WorldFitterItem.Parent) then WorldFitterItem.Parent := nil;
  if Assigned(FEditorDummy)    and Assigned(FEditorDummy.Parent) then begin
    FEditorDummy.Parent     := nil;
    FEditorDummy.State := FEditorDummy.State + [isNeedInit];
//    if FGUIRootItem = FIGUIRootItem then FGUIRootItem := nil;
    (FIGUIRootItem.AggregatedItem as TVisible).Material := nil;
    FIGUIRootItem.Parent := nil;    
  end;
//  SelectedItem.Parent.RemoveChild(GUIFitterItem);
end;

function TC2EdApp.IsServiceItem(AItem: TItem): Boolean;
begin
  Result := (AItem = FEditorDummy) or (AItem = GUIFitterItem) or (AItem = WorldFitterItem);
end;

procedure TC2EdApp.UpdateFitters;
var SelectedItem: TItem;
begin
  SelectedItem := MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode);
  if not (SelectedItem is TFitter) and                                 // Doesn't need a fitter to fit a fitter
    (SelectedItem is TGUIItem){ and (SelectedItem.Parent is TBaseGUIItem)} and Assigned(GUIFitterItem) then begin

    GUIFitterItem.AffectedItem := TGUIItem(SelectedItem);

    GUIFitterItem.PxX      := TGUIItem(SelectedItem).PxX*1;
    GUIFitterItem.PxY      := TGUIItem(SelectedItem).PxY*1;
    GUIFitterItem.PxWidth  := TGUIItem(SelectedItem).PxWidth;
    GUIFitterItem.PxHeight := TGUIItem(SelectedItem).PxHeight;

    GUIFitterItem.State := GUIFitterItem.State + [isVisible];
  end else if Assigned(GUIFitterItem) then begin
    GUIFitterItem.ResetFitter;
    GUIFitterItem.State := GUIFitterItem.State - [isVisible];
  end;

  if (SelectedItem is TProcessing) and Assigned(WorldFitterItem) and
      Assigned(Core.Renderer)      and Assigned(Core.QuerySubsystem(TGUIRootItem)) then begin

    WorldFitterItem.AffectedItem := TProcessing(SelectedItem);

    WorldFitterItem.Camera      := Core.Renderer.MainCamera;
    WorldFitterItem.Location    := TProcessing(SelectedItem).Location;
    WorldFitterItem.Orientation := TProcessing(SelectedItem).Orientation;

    WorldFitterItem.State := WorldFitterItem.State + [isVisible];
  end else if Assigned(WorldFitterItem) then begin
    WorldFitterItem.ResetFitter;
    WorldFitterItem.State := WorldFitterItem.State - [isVisible];
  end;
end;

procedure TC2EdApp.OnTimer;
begin
  if Assigned(GUIFitterItem) and Assigned(GUIFitterItem.Parent) then
    GUIFitterItem.Parent.MoveChild(GUIFitterItem, GUIFitterItem.Parent, mmAddChildFirst);
end;

procedure TC2EdApp.ObtainNewItemData(const FullName: Ansistring; out ItemName: AnsiString; out Parent: TItem);
var HDelimPos: Integer;
begin
  Parent := nil;
  HDelimPos := Length(FullName);
  while (HDelimPos > 0) and (FullName[HDelimPos] <> HierarchyDelimiter) do Dec(HDelimPos);
  if HDelimPos > 0 then begin
    ItemName := Copy(FullName, HDelimPos+1, Length(FullName));
    Parent := Core.Root.GetItemByFullName(Copy(FullName, 1, HDelimPos-1));
  end else ItemName := FullName;
  if not Assigned(Parent) then Parent := MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode);
end;

function TC2EdApp.AddOperation(AOperation: TOperation): Boolean;
begin
  Result := False;

//  MainF.ItemsFrame1.ProgressBar1.Show;
  AOperation.Apply;
  if not (ofIntermediate in AOperation.Flags) then begin
    Include(AOperation.Flags, ofHandled);
    OperationManager.Add(AOperation);
    MainF.ActionUndo.Enabled := App.OperationManager.CanUndo;
    MainF.ActionRedo.Enabled := App.OperationManager.CanRedo;
    MainF.ItemsChanged := True;
    Result := True;
  end;
  MainF.ItemsFrame1.ProgressBar1.Hide;
end;

procedure TC2EdApp.OnActivate(Sender: TObject);
begin
//  if Assigned(Core) and Assigned(Core.Renderer) then Core.Renderer.Active := True;
  Writeln(' ===***');
  Active := True;
  if Assigned(MainF) then
    MainF.Timer.Enabled := False;
    
  if App.Config.GetAsInteger('AutoReloadResource') > 0 then
    Core.SendMessage(TResourceReloadMsg.Create, nil, [mfBroadcast]);  
end;

procedure TC2EdApp.OnDeActivate(Sender: TObject);
begin
  Active := False;
  if Assigned(MainF) then begin
    MainF.Timer.Interval := 100;
    MainF.Timer.Enabled := True;
  end;
//  if Assigned(Core) and Assigned(Core.Renderer) then Core.Renderer.Active := False;
end;

procedure TC2EdApp.OnIdle(Sender: TObject; var Done: Boolean);
begin
  if Active and Assigned(MainF) then MainF.Timer.OnTimer(Sender);
  Done := False;
end;

procedure TC2EdApp.OnException(Sender: TObject; E: Exception);
begin
  Log('Exception class "' + E.ClassName + '" with message "' + E.Message + '" at'#13#10 + GetStackTraceStr(2), lkError);
end;

end.
