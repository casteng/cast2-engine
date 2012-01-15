(*
 @Abstract(CAST II Engine physics unit)
 (C) 2006-2010 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Apr 08, 2010
 Unit contains base physics classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Physics;

interface

uses Logger, BaseMsg, BaseTypes, ItemMsg, Basics, Base3D, Props, Collisions, BaseClasses, CAST2;

type
  // Class containing collision-related information for an item
  TColliding = class(TBaseColliding)
  protected
    // Mass. Zero mass will treated as infinite mass.
    FMass: Single;
  public
    // Subsystem-specific physics data. Do not modify manually.
    Data: Pointer;
    constructor Create(AOwner: TItem); override;
    //    destructor Destroy; override;
    // This procedure is called (by editor for example) to retrieve a list of item's properties and their values. No item links allowed.
    procedure AddProperties(const Result: Props.TProperties); override;
    // This procedure is called (by editor for example) to set values of item's properties.
    procedure SetProperties(Properties: Props.TProperties); override;
    // Mass. Zero mass will treated as infinite mass.
    property Mass: Single read FMass;
  end;

  { Base class of psysics-based simulations.
    Collects physics-enabled items from scene.
    Actual physics behaviour implementation should reside in descendant classes. }
  TPhysicsSubsystem = class(TSubsystem)
  protected
    // Gravity gives all bodies constant acceleration regardless to mass
    ForceGravity,
    // Constant force takes in account mass of a body
    ForceConstant: TVector3s;

    FTotalItems: Integer;
    Items: array of TBaseColliding;
    function GetItemIndex(AItem: TBaseColliding): Integer;
    function IsItemExists(AItem: TBaseColliding): Boolean;
    procedure DoItemApply(AItem: TBaseColliding); virtual; abstract;
    procedure DoItemAdd(AItem: TBaseColliding); virtual; abstract;
    procedure ItemAdd(AItem: TBaseColliding);
    procedure ItemRemove(AItem: TBaseColliding); virtual;
    // Returns True if the given item is ready to be handled with a physics subsystem
    function IsItemProcessing(AItem: TProcessing): Boolean; virtual;
  public
    constructor Create; virtual;
    procedure HandleMessage(const Msg: TMessage); override;

    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    // Performs physics-based simulation
    procedure Process(const DeltaTime: TTimeUnit); virtual; abstract;
  end;

implementation

uses SysUtils;

{ TPhysicsSubsystem }

constructor TPhysicsSubsystem.Create;
begin
  ForceGravity  := Vec3s(0, -1, 0);
  ForceConstant := ZeroVector3s;
end;

function TPhysicsSubsystem.GetItemIndex(AItem: TBaseColliding): Integer;
begin
  Result := FTotalItems-1;
  while (Result >= 0) and (Items[Result] <> AItem) do Dec(Result);
end;

function TPhysicsSubsystem.IsItemExists(AItem: TBaseColliding): Boolean;
begin
  Result := GetItemIndex(AItem) > 0;
end;

procedure TPhysicsSubsystem.ItemAdd(AItem: TBaseColliding);
begin
  {$IFDEF DEBUGMODE} Assert(not IsItemExists(AItem), ClassName + 'ItemAdd: Item already exists'); {$ENDIF}
  Inc(FTotalItems);
  if Length(Items) < FTotalItems then SetLength(Items, Length(Items) + ItemsCapacityStep);

  Items[FTotalItems-1] := AItem;

  DoItemAdd(AItem);
  DoItemApply(AItem);
//  Items[FTotalItems-1].Index := FTotalItems-1;
end;

procedure TPhysicsSubsystem.ItemRemove(AItem: TBaseColliding);
var Index: Integer;
begin
  Index := GetItemIndex(AItem);
  Assert(Index >= 0, ClassName + 'ItemRemove: Item not found');
  Items[Index] := Items[FTotalItems-1];
//  Items[Index].Index := Index;
  Dec(FTotalItems);
end;

function TPhysicsSubsystem.IsItemProcessing(AItem: TProcessing): Boolean;
begin
  Result := (isProcessing in AItem.State) and
             Assigned(AItem.Colliding) and (Length(TColliding(AItem.Colliding).Volumes) > 0);
end;

procedure TPhysicsSubsystem.HandleMessage(const Msg: TMessage);
var ProcItem: TProcessing;
begin
  inherited;
  if Msg.ClassType = ItemMsg.TPhysicalParameterModifiedMsg then begin
    ProcItem := TProcessing(ItemMsg.TItemProcessingModifiedMsg(Msg).Item);
    Assert(Assigned(ProcItem) and Assigned(ProcItem.Colliding));
    DoItemApply(ProcItem.Colliding);
  end else if Msg.ClassType = ItemMsg.TItemProcessingModifiedMsg then begin
    ProcItem := TProcessing(ItemMsg.TItemProcessingModifiedMsg(Msg).Item);
    if IsItemProcessing(ProcItem) then begin
      if not ProcItem.Colliding.IsInContainer then ItemAdd(ProcItem.Colliding)
    end else
      if ProcItem.Colliding.IsInContainer then ItemRemove(ProcItem.Colliding);
  end else if Msg.ClassType = ItemMsg.TAddToSceneMsg then with ItemMsg.TAddToSceneMsg(Msg) do begin
    if (Item is TProcessing) and Assigned(TProcessing(Item).Colliding) then ItemAdd(TProcessing(Item).Colliding);
//  end else if Msg.ClassType = ItemMsg.TReplaceMsg then with ItemMsg.TReplaceMsg(Msg) do begin
//    if (OldItem is TProcessing) and (TProcessing(OldItem).Colliding <> nil) then Collidings.Remove(TProcessing(OldItem).Colliding);
  end else if Msg.ClassType = ItemMsg.TRemoveFromSceneMsg then with ItemMsg.TRemoveFromSceneMsg(Msg) do begin
    if (Item is TProcessing) and Assigned(TProcessing(Item).Colliding) then ItemRemove(TProcessing(Item).Colliding);
  end
end;

procedure TPhysicsSubsystem.AddProperties(const Result: TProperties);
begin
  inherited;
  AddVector3sProperty(Result, 'Physics\Force\Gravity',  ForceGravity);
  AddVector3sProperty(Result, 'Physics\Force\Constant', ForceConstant);
end;

procedure TPhysicsSubsystem.SetProperties(Properties: TProperties);
begin
  inherited;
  SetVector3sProperty(Properties, 'Physics\Force\Gravity',  ForceGravity);
  SetVector3sProperty(Properties, 'Physics\Force\Constant', ForceConstant);
end;

{ TColliding }

constructor TColliding.Create(AOwner: TItem);
begin
  inherited;
  Data := nil;
  FMass := 0;
end;

procedure TColliding.AddProperties(const Result: Props.TProperties);
var i: Integer; Str: string;
begin
  Result.Add('Physics\Bounds\Total volumes', vtInt, [], IntToStr(Length(Volumes)), '');
  for i := 0 to High(Volumes) do begin
    Str := 'Physics\Bounds\Volume #' + IntToStr(i+1) + '\';

    Result.AddEnumerated(Str + 'Kind', [], Ord(Volumes[i].VolumeKind), VolumeKindsEnum);

    AddVector3sProperty(Result, Str + 'Offset', Volumes[i].Offset);
    AddVector3sProperty(Result, Str + 'Dimensions', Volumes[i].Dimensions);

    Result.Add('Physics\Mass', vtSingle, [], FloatToStr(FMass), '');
  end;
end;

procedure TColliding.SetProperties(Properties: Props.TProperties);

  procedure SetPropertiesEx(const Prefix: AnsiString);
  var i, TotalVolumes: Integer; Str: string;
  begin
    if Properties.Valid(Prefix + 'Bounds\Total volumes') then begin
      TotalVolumes := Length(Volumes);
      SetLength(Volumes, StrToIntDef(Properties[Prefix + 'Bounds\Total volumes'], Length(Volumes)));

  //    if (TotalVolumes =  0) and (High(Colliding.Volumes) >= 0) then (FManager.Root as TCASTRootItem).AddColliding(Self);
  //    if (TotalVolumes <> 0) and (High(Colliding.Volumes)  < 0) then (FManager.Root as TCASTRootItem).RemoveColliding(Self);

      for i := TotalVolumes to High(Volumes) do begin
        Volumes[i].VolumeKind := bvkOOBB;
        Volumes[i].Offset     := ScaleVector3s(AddVector3s(TProcessing(Owner).BoundingBox.P2, TProcessing(Owner).BoundingBox.P1), 0.5);
        Volumes[i].Dimensions := ScaleVector3s(SubVector3s(TProcessing(Owner).BoundingBox.P2, TProcessing(Owner).BoundingBox.P1), 0.5);
      end;
    end;

    for i := 0 to High(Volumes) do begin
      Str := Prefix + 'Bounds\Volume #' + IntToStr(i+1) + '\';

      if Properties.Valid(Str + 'Kind') then Volumes[i].VolumeKind := TBoundingVolumeKind(Properties.GetAsInteger(Str + 'Kind'));

      SetVector3sProperty(Properties, Str + 'Offset', Volumes[i].Offset);

      SetVector3sProperty(Properties, Str + 'Dimensions', Volumes[i].Dimensions);
    end;

    if Properties.Valid('Physics\Mass') then FMass := StrToFloatDef(Properties['Physics\Mass'], 0);

    Owner.SendMessage(TPhysicalParameterModifiedMsg.Create(Owner), nil, [mfCore]);
  end;

begin
  Assert(Assigned(Owner), 'nil');
  Assert(Owner is TProcessing);
  SetPropertiesEx('');                // Compatibility temporary
  SetPropertiesEx('Physics\');
end;

initialization
  CollidingClass := TColliding;
end.
