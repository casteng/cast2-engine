(*
 @Abstract(CAST II Engine basic physics unit)
 (C) 2006-2011 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Apr 11, 2010
 Unit contains basic physics subsystem implemetation which performs collision detection of bounding volumes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2BasicPhysics;

interface

uses Logger, BaseTypes, Basics, Props, BaseClasses, CAST2, C2Physics, Collisions;

type
  { Basic physics subsystem implementation.
    Performs collision detection of bounding volumes (currently supported OOBB and Sphere) and calls OnCollision method for both colliding entities.
    Current implementation has a complexity of O(N^2) where N is number of potentially colliding entities. }
  TBasicPhysics = class(TPhysicsSubsystem)
  protected
    procedure DoItemApply(AItem: TBaseColliding); override;
    procedure DoItemAdd(AItem: TBaseColliding); override;
    procedure ItemRemove(AItem: TBaseColliding); override;
  public
    procedure Process(const DeltaTime: TTimeUnit); override;
  end;

implementation

{ TBasicPhysics }

procedure TBasicPhysics.DoItemApply(AItem: TBaseColliding);
begin
  inherited;

end;

procedure TBasicPhysics.DoItemAdd(AItem: TBaseColliding);
begin
  inherited;

end;

procedure TBasicPhysics.ItemRemove(AItem: TBaseColliding);
begin
  inherited;

end;

procedure TBasicPhysics.Process(const DeltaTime: TTimeUnit);
var i, j: Integer; ColRes: Collisions.TCollisionResult; P: Pointer;
begin
  for i := 0 to FTotalItems-2 do for j := i+1 to FTotalItems-1 do
    if Assigned(TColliding(Items[i]).Owner) and (isProcessing in TColliding(Items[i]).Owner.State) and
       Assigned(TColliding(Items[j]).Owner) and (isProcessing in TColliding(Items[j]).Owner.State) then begin
    ColRes := VolumeColDet(TColliding(Items[i]).Volumes, TColliding(Items[j]).Volumes,
                           TProcessing(TColliding(Items[i]).Owner).Transform, TProcessing(TColliding(Items[j]).Owner).Transform);
    if ColRes.Vol1 <> nil then begin
      TProcessing(TColliding(Items[i]).Owner).OnCollision(TProcessing(TColliding(Items[j]).Owner), ColRes);
      P := ColRes.Vol1;
      ColRes.Vol1 := ColRes.Vol2;
      ColRes.Vol2 := P;
      TProcessing(TColliding(Items[j]).Owner).OnCollision(TProcessing(TColliding(Items[i]).Owner), ColRes);
    end;
  end;
end;

end.
