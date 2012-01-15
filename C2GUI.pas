(*
 @Abstract(CAST II Engine ACS (GUI) wrapper unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains classes which brings the power of ACS GUI library to CAST II engine
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2GUI;

interface

uses
  Math,
  Logger,
  BaseTypes, Basics, Base3D, Props, Models, BaseGraph, BaseClasses, BaseMsg, ItemMsg, ACSBase, GUIFitter,
  Resources, CAST2, C22D, C2Visual, C2Materials, C2Core;

type
  TCFont = class(TItem)
    destructor Destroy; override;
  protected
    FFont: BaseGraph.TFont;
  public
    property Font: BaseGraph.TFont read FFont;
  end;

  TCBitmapFont = class(TCFont)
    constructor Create(AManager: TItemsManager); override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  protected
    procedure ResolveLinks; override;
  end;

  TC2GUIItem = class(TVisible)
    constructor Create(AManager: TItemsManager); override;
    constructor Construct(AManager: TItemsManager); override;

    procedure InitAItem; virtual; abstract;
    procedure HandleMessage(const Msg: TMessage); override;
    procedure OnSceneAdd; override;
    procedure OnSceneLoaded; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure Render; override;
    procedure Process(const DeltaT: Float); override;
  protected
    Aggregate: ACSBase.TBaseGUIItem;
//    function isActuallyVisible: Boolean; override;
  end;

  T3DFitter = class(TFitter)
  private
    MinControlLength, MaxControlLength, ControlLength: Extended;
    PushLocation, PushLocationWorld: TVector3s;                         // Starting position of the item
    PushOrientation: TQuaternion;
    RotAxis: TVector3s;
    PushAxisX, PushAxisY: Single;                                       // Axis in screen space along which the item being moved
    CenterX, CenterY,
    XRBarX, XRBarY, YRBarX, YRBarY, ZRBarX, ZRBarY,
    XBarX, XBarY, YBarX, YBarY, ZBarX, ZBarY: Single; // Control points coordinates
    VisibleAreas: TSet32;
    FCamera: CAST2.TCamera;
//debug
    projsx, projsy: single;
    function GetAreaAt(MX, MY: Single): Integer;
    function Project(Vector: TVector3s; out AX, AY: Single): Boolean;
    procedure SavePushState(MX, MY: Single; Modifiers: TKeyModifiers);
    procedure SetCamera(const Value: CAST2.TCamera);
  protected
    procedure BuildAreas; override;
    procedure HandleMove(AX, AY: Single); override;
    function GetAffectedItem: TItem; override;
    procedure SetAffectedItem(const Value: TItem); override;
  public
    XAColor, YAColor, ZAColor: BaseTypes.TColor;
    AffectedProcessing: CAST2.TProcessing;
    Location: TLocation;
    Orientation: TQuaternion;
    constructor Create(AManager: TItemsManager); override;

    procedure ResetFitter; override;

    function GUIHandleMessage(const Msg: TMessage): Boolean; override;
    procedure Draw; override;

    property Camera: CAST2.TCamera read FCamera write SetCamera;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

uses SysUtils;

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([T3DFitter]);
end;

{ TCFont }

destructor TCFont.Destroy;
begin
  inherited;
  if FFont <> nil then FFont.Free;
end;

{ TCBitmapFont }

constructor TCBitmapFont.Create(AManager: TItemsManager);
begin
  inherited;
  FFont := TBitmapFont.Create(AManager);
end;

procedure TCBitmapFont.AddProperties(const Result: Props.TProperties);
begin
  inherited;

  AddItemLink(Result, 'Bitmap',   [], 'TImageResource');
  AddItemLink(Result, 'UV map',   [], 'TUVMapResource');
  AddItemLink(Result, 'Char map', [], 'TCharMapResource');
end;

procedure TCBitmapFont.SetProperties(Properties: Props.TProperties);
begin
  inherited;

  if Properties.Valid('Bitmap')   then SetLinkProperty('Bitmap',   Properties['Bitmap']);
  if Properties.Valid('UV map')   then SetLinkProperty('UV map',   Properties['UV map']);
  if Properties.Valid('Char map') then SetLinkProperty('Char map', Properties['Char map']);

  ResolveLinks;
end;

procedure TCBitmapFont.ResolveLinks;
var LinkedRes: TItem; BFont: TBitmapFont;
begin
  Assert(FFont <> nil, ClassName + '.ResolveLinks: Font is undefined');
  BFont := FFont as TBitmapFont;
  if ResolveLink('UV map', LinkedRes) then begin
    BFont.UVMap    := (LinkedRes as TUVMapResource).Data;
    BFont.TotalUVs := (LinkedRes as TUVMapResource).TotalElements;
  end;
  if ResolveLink('Char map', LinkedRes) then begin
    BFont.CharMap         := (LinkedRes as TCharMapResource).Data;
    BFont.TotalCharacters := (LinkedRes as TCharMapResource).TotalElements;
  end;
  if ResolveLink('Bitmap', LinkedRes) then begin
    BFont.Bitmap       := (LinkedRes as TImageResource).Data;
    BFont.BitmapFormat := (LinkedRes as TImageResource).Format;
    BFont.XScale       := (LinkedRes as TImageResource).Width;
    BFont.YScale       := (LinkedRes as TImageResource).Height;
  end;
  FFont := BFont;
end;

{ TC2GUIItem }

constructor TC2GUIItem.Create(AManager: TItemsManager);
begin
  inherited;

  TesselatorKind := tkNone;

  Assert(AManager is TBaseCore, ClassName + '.Create: AManager should be an instance of TBaseCore or one of its descendants');
  Assert(Screen is TC2Screen, ClassName + '.Create: Screen should be an instance of TC2Screen or one of its descendants');
end;

constructor TC2GUIItem.Construct(AManager: TItemsManager);
begin
  inherited;
end;

procedure TC2GUIItem.OnSceneAdd;
begin
  inherited;
  Assert(Screen is TC2Screen, 'TC2GUIItem.Create: Screen should be an instance of TC2Screen or one of its descendants');
  TC2Screen(BaseGraph.Screen).SetCore(FManager as TCore);
end;

procedure TC2GUIItem.OnSceneLoaded;
begin
  inherited;
end;

procedure TC2GUIItem.AddProperties(const Result: Props.TProperties);
begin
  inherited;
{  if AItem <> nil then begin
    LinksPush;
//    AItem.AddProperties(Result);
    Props := Props.TProperties.Create;
    AItem.GetProperties(Props);
    Result.Merge(Props, False);
    Props.Free;
    LinksPop;
  end;}
end;

procedure TC2GUIItem.SetProperties(Properties: Props.TProperties);
begin
  inherited;
{  if AItem <> nil then begin
//    PropagateObjectLinks(AItem);
    AItem.SetProperties(Properties);
  end;}
end;

procedure TC2GUIItem.Render;
var SolidTech, TextTech: TTechnique;
//procedure RenderItem(Item: TC2GUIItem);
//var i, j: Integer;
//begin
//  if Assigned(Item.CurTechnique) then begin
//    TC2Screen(Screen).SetTechnique(pkText,  Item.CurTechnique);
//    TC2Screen(Screen).SetTechnique(pkSolid, Item.CurTechnique);
////    TC2Screen(Screen).SetTechnique(pkSolid, FManager.Root.GetChildByFullName('Root item\Materials\2D\2D Technique 1') as TTechnique);
//    Item.Aggregate.Draw;
//  end;
//  for i := 0 to Item.Aggregate.TotalChilds-1 do begin
//    if (Item.Aggregate.Childs[i] is TBaseGUIItem) and (isVisible in Item.Aggregate.Childs[i].State) then
//      RenderItem(TC2GUIItem(TBaseGUIItem(Item.Aggregate.Childs[i]).AggregatedItem)) else
//        if Item.Aggregate.Childs[i] is TDummyItem then for i := 0 to Item.Aggregate.TotalChilds-1 do
//  end;
//end;

  procedure RenderItem(Item: TItem);
  var i: Integer; C2GUIItem: TC2GUIItem;
  begin
    if not (isVisible in Item.State) then Exit;
    if Item is TBaseGUIItem then begin

        C2GUIItem := TBaseGUIItem(Item).AggregatedItem as TC2GUIItem;
        if Assigned(C2GUIItem.CurTechnique) then begin
          TC2Screen(Screen).SetTechnique(pkText,  C2GUIItem.CurTechnique);
          TC2Screen(Screen).SetTechnique(pkSolid, C2GUIItem.CurTechnique);
      //    TC2Screen(Screen).SetTechnique(pkSolid, FManager.Root.GetChildByFullName('Root item\Materials\2D\2D Technique 1') as TTechnique);
          TBaseGUIItem(Item).Draw;
        end;
  //    end;
    end;// else Assert(Item is TDummyItem, Format('Only GUI items or dummy items are allowed in GUI hierarchy, but an item of class %s found', [Item.ClassName]));
    for i := 0 to Item.TotalChilds-1 do RenderItem(Item.Childs[i]);
  end;

begin
  inherited;
  
  SolidTech := TC2Screen(Screen).SolidTechnique;
  TextTech  := TC2Screen(Screen).TextTechnique;

//  Screen.CurrentZ := ClearingZ;                           // ToDo: Eliminate it
  RenderItem(Self.Aggregate);

  TC2Screen(Screen).SetTechnique(pkSolid, SolidTech);
  TC2Screen(Screen).SetTechnique(pkText,  TextTech);
end;

procedure TC2GUIItem.HandleMessage(const Msg: TMessage);
begin
  inherited;
//  AItem.HandleMessage(Msg);
  if Msg.ClassType = TAggregateMsg then begin
    Aggregate := TAggregateMsg(Msg).Aggregate as TBaseGUIItem;
//    FState := Aggregate.State;
    if Aggregate is TGUIRootItem then TesselatorKind := tkShared;
  end;
end;

procedure TC2GUIItem.Process(const DeltaT: Float);
begin
  inherited;
//  AItem.Process;
end;

{function TC2GUIItem.isActuallyVisible: Boolean;
var Item: TItem;
begin
//  if not Assigned(Aggregate) then Exit;
  Item := Aggregate;

  while Assigned(Item) and
        not (((Item is TVisible) or (Item is TBaseGUIItem) or (Item is TDummyItem)) and not (isVisible in Item.State)) do
    Item := Item.Parent;

  Result := not Assigned(Item) and Assigned(Aggregate);
end;}

{ T3DFitter }

function T3DFitter.GetAreaAt(MX, MY: Single): Integer;
var i: Integer;
begin
  Result := -1;
  for i := haCenter to haZRotate do if IsInArea(MX, MY, Areas[i]) then Result:= i;
end;

function T3DFitter.Project(Vector: TVector3s; out AX, AY: Single): Boolean;
var Transformed: TVector4s;
begin
//  Transformed := Transform4Vector3s(Camera.TotalMatrix, AddVector3s(AffectedProcessing.Position, Transform3Vector3s(CutMatrix3s(AffectedProcessing.Transform), Vector)));
  AX := 0;
  AY := 0;
  Transformed := Transform4Vector3s(Camera.TotalMatrix, Transform4Vector33s(AffectedProcessing.Transform, Vector));
  if Transformed.W > 0 then begin
    Transformed.W := 1/Transformed.W;
    AX := Camera.RenderWidth  shr 1 * (1 + Transformed.X * Transformed.W);
    AY := Camera.RenderHeight shr 1 * (1 - Transformed.Y * Transformed.W);
    Result := True;
//    (AX >= 0) and (AY >= 0) and (AX < Camera.ScreenWidth) and (AY < Camera.ScreenHeight);
  end else Result := False;
end;

procedure T3DFitter.SavePushState(MX, MY: Single; Modifiers: TKeyModifiers);
begin
  if not Assigned(AffectedProcessing) then Exit;

  if kmOS in Modifiers then
    AffectedProcessing := TProcessing(AffectedProcessing.Clone());

  HoverArea := GetAreaAt(MX, MY);
  Project(GetVector3s(0, 0, 0), PushAxisX, PushAxisY);
{  case HoverArea of
    haXMove: Project(GetVector3s(ControlLength, 0, 0), PushX, PushY);
    haYMove: Project(GetVector3s(0, ControlLength, 0), PushX, PushY);
    haZMove: Project(GetVector3s(0, 0, ControlLength), PushX, PushY);
  end;}
  PushX := MX; PushY := MY;
  PushAxisX := (PushX - PushAxisX);// / ControlLength;// / Sqrt( Sqr(PushX - PushAxisX) + Sqr(PushY - PushAxisY) );
  PushAxisY := (PushY - PushAxisY);// / ControlLength;// / Sqrt( Sqr(PushX - PushAxisX) + Sqr(PushY - PushAxisY) );
  PushLocation := AffectedProcessing.Position;
  PushLocationWorld := AffectedProcessing.GetAbsLocation;
  PushOrientation   := AffectedProcessing.Orientation;// AffectedProcessing.GetAbsOrientation;
  case HoverArea of
    haXRotate: RotAxis := AffectedProcessing.RightVector;
    haYRotate: RotAxis := AffectedProcessing.UpVector;
    haZRotate: RotAxis := AffectedProcessing.ForwardVector;
  end;
end;

procedure T3DFitter.SetCamera(const Value: CAST2.TCamera);
begin
  FCamera := Value;
  if FCamera <> nil then begin                            // Expand the control on entire screen to issue GUI events (TGUIDownMsg etc)
    Width  := FCamera.RenderWidth;
    Height := FCamera.RenderHeight;
  end;
end;

procedure T3DFitter.BuildAreas;

  function SquareArea(CX, CY: single): BaseTypes.TArea;
  begin
    Result := GetArea(CX - DefaultSize*0.5, CY - DefaultSize*0.5, CX + DefaultSize*0.5, CY + DefaultSize*0.5);
  end;

  procedure CalcControlLength;                            // Calculate control axis length taking in account min and max values
  var Dist: Extended; CX, CY, FX, FY: Single;
  begin
    ControlLength := 1;
    if not Project(GetVector3s(0, 0, 0), CX, CY) then Exit;                // Check the maximum possible length of control axis
    if not Project(Transform3Vector3sTransp(CutMatrix3s(AffectedProcessing.Transform), Camera.RightVector), FX, FY) then Exit;                  // by projection of the camera's right vector
    Dist := Sqr(FX - CX) + Sqr(FY - CY);

    if Dist > 0 then begin
      if Dist < Sqr(MinControlLength) then ControlLength := MinControlLength / Sqrt(Dist);
      if Dist > Sqr(MaxControlLength) then ControlLength := MaxControlLength / Sqrt(Dist);
    end;
  end;

begin
  VisibleAreas := [];
  if (Camera = nil) or (AffectedProcessing = nil) then Exit;

  CalcControlLength;

  if Project(GetVector3s(0, 0, 0), CenterX, CenterY) then Include(VisibleAreas, haCenter);
  Areas[haCenter] := SquareArea(CenterX, CenterY);

  if Project(GetVector3s(ControlLength, 0, 0), XBarX, XBarY) then Include(VisibleAreas, haXMove);
  Areas[haXMove]  := SquareArea(XBarX, XBarY);
  if Project(GetVector3s(0, ControlLength, 0), YBarX, YBarY) then Include(VisibleAreas, haYMove);
  Areas[haYMove]  := SquareArea(YBarX, YBarY);
  if Project(GetVector3s(0, 0, ControlLength), ZBarX, ZBarY) then Include(VisibleAreas, haZMove);
  Areas[haZMove]  := SquareArea(ZBarX, ZBarY);

  if Project(GetVector3s(0, -ControlLength*2, 0), XRBarX, XRBarY) then Include(VisibleAreas, haXRotate);
  Areas[haXRotate]  := SquareArea(XRBarX, XRBarY);
  if Project(GetVector3s(0, 0, -ControlLength*2), YRBarX, YRBarY) then Include(VisibleAreas, haYRotate);
  Areas[haYRotate]  := SquareArea(YRBarX, YRBarY);
  if Project(GetVector3s(-ControlLength*2, 0, 0), ZRBarX, ZRBarY) then Include(VisibleAreas, haZRotate);
  Areas[haZRotate]  := SquareArea(ZRBarX, ZRBarY);
end;

procedure T3DFitter.HandleMove(AX, AY: Single);

  function ScreenToCamera(X, Y: Single): TVector3s;
  begin
    Result.X := (X - 0.5*Camera.RenderWidth ) / Camera.RenderWidth;
    Result.Y := (0.5*Camera.RenderHeight - Y) / Camera.RenderHeight / Camera.CurrentAspectRatio;
    Result.Z := 0.5 / Sin(Camera.HFoV/2)*Cos(Camera.HFoV/2);
  end;

  function CameraToWorld(const V: TVector3s): TVector3s;
  begin
    Result := Transform4Vector3s(InvertMatrix4s(Camera.ViewMatrix), V).XYZ;
  //  d := 0.5*Camera.ScreenWidth / Sin(Camera.HFoV/2)*Cos(Camera.HFoV/2);
  //  Result := AddVector3s(Camera.GetAbsLocation, ScaleVector3s(Camera.ForwardVector, -d*0));
  end;

  procedure DoMove;
  var
    ReverseMat: TMatrix4s;
    MV, WP1, WP2, SP1, SP2, Axis: TVector3s;
    d, wd, CosA, SinB, SinC: Extended;
    Op: TItemMoveOp;
  begin
    case HoverArea of
      haCenter: ;
      haXMove: begin                                                          // AX/|AX| * MV * cos
        Axis := AffectedProcessing.RightVector;
      end;
      haYMove: Axis := AffectedProcessing.UpVector;
      haZMove: Axis := AffectedProcessing.ForwardVector;
    end;

    wd := Sqr(PushAxisX) + Sqr(PushAxisY);
    d  := (PushAxisX * (AX - PushX) + PushAxisY * (AY - PushY)) / wd; // |AxP|/|MV|*cos

//    d :=

    MV.X := PushAxisX * d;
    MV.Y := PushAxisY * d;                                                    // MV - move vector projected on PushAxis

    projsx := PushX + MV.X;
    projsy := PushY + MV.Y;

    if Sqr(MV.X) + Sqr(MV.Y) > Sqr(0.1) then begin
      SP1 := CameraToWorld(ScreenToCamera(PushX, PushY));
      SP2 := CameraToWorld(ScreenToCamera(PushX + MV.X, PushY + MV.Y));

      WP1 := AddVector3s(PushLocationWorld, ScaleVector3s(Axis, ControlLength));
      d   := Sqrt(SqrMagnitude(SubVector3s(WP1, Camera.Position))/
                  SqrMagnitude(SubVector3s(SP1, Camera.Position)));
      WP2 := AddVector3s(Camera.Position, ScaleVector3s(SubVector3s(SP2, Camera.Position), d));
      wd  := Sqrt(SqrMagnitude(SubVector3s(WP2, WP1)));
  // sin(b)/wd = sin(c)/x => x = sin(c)*wd/sin(b)
      CosA := DotProductVector3s(Axis, SubVector3s(WP2, WP1))/wd;
      SinB := Sqrt(1 - Sqr(DotProductVector3s(Axis, NormalizeVector3s(SubVector3s(WP2, Camera.Position)))));
      SinC := Sqrt(1 - Sqr(DotProductVector3s(SubVector3s(WP2, WP1), NormalizeVector3s(SubVector3s(WP2, Camera.Position)))/wd));

      wd := wd * SinC / SinB * Sign(CosA);

  //    Location := AddVector3s(PushLocation, ScaleVector3s(Axis, wd));
      if (AffectedProcessing.Parent is CAST2.TProcessing) then
        ReverseMat := InvertMatrix4s(CAST2.TProcessing(AffectedProcessing.Parent).Transform)
      else
        ReverseMat := IdentityMatrix4s;
      Location := Transform4Vector3s(ReverseMat, AddVector3s(PushLocationWorld, ScaleVector3s(Axis, wd)));

    end else Location := GetLocationFromVec3s(PushLocation);

    if Assigned(AffectedItem) then
      if UseOperations then begin
        Op := TItemMoveOp.Create;
        if Op.Init(AffectedProcessing, Location) then
          SendMessage(TOperationMsg.Create(Op), nil, [mfCore])
        else
          Op.Free;
      end else
        AffectedProcessing.Location := Location;
  end;

  procedure DoRotate;
  var
//    ReverseMat: TMatrix4s;
    NewPos, OldPos: TVector3s;
    Ang, t: Extended;
    Quat: TQuaternion;
    Op: TItemRotateOp;

    function GetPointOnPlane(UseOld: Boolean; var Res: TVector3s): Boolean;
    var d, wd, PX, PY: Extended; W: TVector3s;
    begin
      Result := True;
      if UseOld then begin
        PX := PushX; PY := PushY;
      end else begin
        PX := AX; PY := AY;
      end;
      W := Camera.Position;
      d := DotProductVector3s(RotAxis, SubVector3s(AffectedProcessing.GetAbsLocation, W));
      W := SubVector3s(CameraToWorld(ScreenToCamera(PX, PY)), W);
      wd := DotProductVector3s(RotAxis, W);
      if Abs(wd) > epsilon then
        Res := AddVector3s(Camera.Position, ScaleVector3s(W, d/wd)) else begin
          if UseOld then
            AddVector3s(Res, AffectedProcessing.GetAbsLocation, RotAxis) else
              Res := CameraToWorld(ScreenToCamera(PX, PY));
        end;
    end;

  begin
    if not GetPointOnPlane(True, OldPos) or not GetPointOnPlane(False, NewPos) then Exit;
    SubVector3s(OldPos, OldPos, AffectedProcessing.GetAbsLocation);
    SubVector3s(NewPos, NewPos, AffectedProcessing.GetAbsLocation);

    t := DotProductVector3s(OldPos, NewPos) / Sqrt(SqrMagnitude(OldPos)) / Sqrt(SqrMagnitude(NewPos));
    if (t > 1) then t := 1;
    if (t < -1) then t := -1;
    Ang := -ArcCos(t);
    if DotProductVector3s(CrossProductVector3s(OldPos, NewPos), RotAxis) > 0 then Ang := - Ang;

    Quat := GetQuaternion(Ang, RotAxis);

{      if (AffectedProcessing.Parent is TProcessing) then
        ReverseMat := RotTransMatrixInvert(TProcessing(AffectedProcessing.Parent).Transform) else
          ReverseMat := IdentityMatrix4s;}

    if Assigned(AffectedItem) then
      if UseOperations then begin
        Op := TItemRotateOp.Create;
        if Op.Init(AffectedProcessing, NormalizeQuaternion(MulQuaternion(Quat, PushOrientation))) then
          SendMessage(TOperationMsg.Create(Op), nil, [mfCore])
        else
          Op.Free;
      end else
        AffectedProcessing.Orientation := NormalizeQuaternion(MulQuaternion(Quat, PushOrientation));
  end;

begin
  if (Camera = nil) or (AffectedProcessing = nil) or (HoverArea = -1) then Exit;

  case HoverArea of
    haCenter, haXMove, haYMove, haZMove: DoMove;
    haXRotate, haYRotate, haZRotate: DoRotate;
  end;
end;

function T3DFitter.GetAffectedItem: TItem;
begin
  Result := AffectedProcessing;
end;

procedure T3DFitter.SetAffectedItem(const Value: TItem);
begin
  if Value is CAST2.TProcessing then
    AffectedProcessing := Value as CAST2.TProcessing else begin
       Log(ClassName + '.SetAffectedItem: Affected item is not a TProcessing', lkError); 
    end;
  BuildAreas;  
end;

constructor T3DFitter.Create(AManager: TItemsManager);
begin
  inherited;
  XAColor.C := $FF0000FF;
  YAColor.C := $FF00FF00;
  ZAColor.C := $FFFF0000;
  MinControlLength := 16;
  MaxControlLength := 64;
end;

procedure T3DFitter.ResetFitter;
begin
  inherited;
  FCamera := nil;
end;

function T3DFitter.GUIHandleMessage(const Msg: TMessage): Boolean;
var i: Integer; OMX, OMY: Integer; MX, MY: Single; Processed: Boolean;
begin
  if Msg is TMouseMsg then with TMouseMsg(Msg) do begin
    OMX := X; OMY := Y;
    MX  := X; MY  := Y;
    ScreenToClient(MX, MY);
  end else begin
    OMX := 0; OMY := 0;
  end;
  Result := inherited GUIHandleMessage(Msg);
  if not Result then Exit;
  if Msg is TMouseMsg then with TMouseMsg(Msg) do begin
    Processed := False;
    if (Msg.ClassType = TMouseDownMsg) then begin
      if Hover then begin
        SavePushState(MX, MY, ModifierState);
        Processed := True;
      end;
    end else if (Msg.ClassType = TMouseMoveMsg) then begin
      Processed := True;
      if Pushed then HandleMove(MX, MY) else begin
        HoverArea := -1;
        for i := haCenter to haZRotate do if IsInArea(MX, MY, Areas[i]) then HoverArea := i;
        Processed := HoverArea <> -1;
      end;
    end;
    if not Processed then begin                           // Restore mouse coordinates to allow the message handling by other controls
      X := OMX;
      Y := OMY;
    end;
  end;
end;

procedure T3DFitter.Draw;
begin
  if not (haCenter in VisibleAreas) then Exit;
  inherited;
  BuildAreas;
  if haCenter = HoverArea then Screen.SetColor(Color) else Screen.SetColor(NormalColor);
  Screen.Bar(Areas[haCenter].X1, Areas[haCenter].Y1, Areas[haCenter].X2, Areas[haCenter].Y2);
  if haXMove in VisibleAreas then begin
    if haXMove = HoverArea then Screen.SetColor(Color) else Screen.SetColor(XAColor);
    Screen.Line(CenterX, CenterY, XBarX, XBarY);
    Screen.Bar(Areas[haXMove].X1, Areas[haXMove].Y1, Areas[haXMove].X2, Areas[haXMove].Y2);
  end;
  if haYMove in VisibleAreas then begin
    if haYMove = HoverArea then Screen.SetColor(Color) else Screen.SetColor(YAColor);
    Screen.Line(CenterX, CenterY, YBarX, YBarY);
    Screen.Bar(Areas[haYMove].X1, Areas[haYMove].Y1, Areas[haYMove].X2, Areas[haYMove].Y2);
  end;
  if haZMove in VisibleAreas then begin
    if haZMove = HoverArea then Screen.SetColor(Color) else Screen.SetColor(ZAColor);
    Screen.Line(CenterX, CenterY, ZBarX, ZBarY);
    Screen.Bar(Areas[haZMove].X1, Areas[haZMove].Y1, Areas[haZMove].X2, Areas[haZMove].Y2);
  end;

  if haXRotate in VisibleAreas then begin
    if haXRotate = HoverArea then Screen.SetColor(Color) else Screen.SetColor(XAColor);
    Screen.Line(CenterX, CenterY, XRBarX, XRBarY);
    Screen.Bar(Areas[haXRotate].X1+RoundShift, Areas[haXRotate].Y1, Areas[haXRotate].X2-RoundShift, Areas[haXRotate].Y2);
    Screen.Bar(Areas[haXRotate].X1, Areas[haXRotate].Y1+RoundShift, Areas[haXRotate].X2, Areas[haXRotate].Y2-RoundShift);
  end;
  if haYRotate in VisibleAreas then begin
    if haYRotate = HoverArea then Screen.SetColor(Color) else Screen.SetColor(YAColor);
    Screen.Line(CenterX, CenterY, YRBarX, YRBarY);
    Screen.Bar(Areas[haYRotate].X1+RoundShift, Areas[haYRotate].Y1, Areas[haYRotate].X2-RoundShift, Areas[haYRotate].Y2);
    Screen.Bar(Areas[haYRotate].X1, Areas[haYRotate].Y1+RoundShift, Areas[haYRotate].X2, Areas[haYRotate].Y2-RoundShift);
  end;
  if haZRotate in VisibleAreas then begin
    if haZRotate = HoverArea then Screen.SetColor(Color) else Screen.SetColor(ZAColor);
    Screen.Line(CenterX, CenterY, ZRBarX, ZRBarY);
    Screen.Bar(Areas[haZRotate].X1+RoundShift, Areas[haZRotate].Y1, Areas[haZRotate].X2-RoundShift, Areas[haZRotate].Y2);
    Screen.Bar(Areas[haZRotate].X1, Areas[haZRotate].Y1+RoundShift, Areas[haZRotate].X2, Areas[haZRotate].Y2-RoundShift);
  end;

  if Pushed then begin
    Screen.SetColor(GetColor($FFFFFF00));
//    Screen.Bar(PushX - 2, PushY - 2, PushX + 2, PushY + 2);
    Screen.SetColor(GetColor($FF00FF00));
    Screen.Bar(projsx - 2, projsy - 2, projsx + 2, projsy + 2);
  end;
end;

initialization
  ACSBase.AggregatedClass := TC2GUIItem;
  GlobalClassList.Add('C2GUI', GetUnitClassList);
end.

