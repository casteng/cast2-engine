(*
 @Abstract(CAST II Engine Newton physics unit)
 (C) 2006-2011 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Apr 11, 2010
 Unit contains physics subsystem implemetation based on Newton Game Dynamics 2.0x physics engine (www.newtondynamics.com)
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2NewtonPhysics;

interface

uses
  Logger, Basics, BaseStr, Props, BaseClasses, BaseTypes, BaseMsg, ItemMsg, Base3D, Collisions,
  CAST2, C2Physics, C2Land,
  NewtonImport;

type
  // Newton-based physics subsystem implementation
  TNewtonPhysics = class(TPhysicsSubsystem)
  private
    World: PNewtonWorld;
  protected
    procedure DoItemApply(AItem: TBaseColliding); override;
    procedure DoItemAdd(AItem: TBaseColliding); override;
    procedure ItemRemove(AItem: TBaseColliding); override;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure HandleMessage(const Msg: TMessage); override;

    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    procedure Process(const DeltaTime: TTimeUnit); override;
  end;

implementation

var Subsystem: TNewtonPhysics;

procedure NewtonApplyForceAndTorqueCallback(const Body: PNewtonBody; Timestep: Float; threadIndex: int ); cdecl;
var Mass, Ixx, Iyy, Izz: Single; Force: TVector3s;
begin
  Assert(Assigned(Subsystem));
  NewtonBodyGetMassMatrix(Body, @Mass, @Ixx, @Iyy, @Izz) ;
  Force := AddVector3s(Subsystem.ForceConstant, ScaleVector3s(Subsystem.ForceGravity, Mass));
  NewtonBodySetForce(body, @Force.X) ;
end;

procedure NewtonSetTransformCallback(const Body: PNewtonBody; const Matrix: PFloat; threadIndex: int ); cdecl;
var Item: TColliding;
begin
  Item := NewtonBodyGetUserData(Body);
  TProcessing(Item.Owner).Transform := PMatrix4s(Matrix)^;
end;

{ TNewtonPhysics }

procedure TNewtonPhysics.DoItemApply(AItem: TBaseColliding);
var
  i: Integer;
  LItem: TColliding;
  Body: PNewtonBody;
  Mat: TMatrix4s;
  NColArr: array of PNewtonCollision;
  NCol: PNewtonCollision;
  Inertia, Origin: TVector4s;
  HMap: THeightMap;
  Heights: PWordBuffer;
  Attribs: PByteBuffer;
  P1, P2: TVector3s;
begin
  Assert(AItem is TColliding);

  LItem := TColliding(AItem);
  Body := LItem.Data;

  if Assigned(Body) then begin
    NewtonDestroyBody(World, Body);
    Body := nil;
    LItem.Data := nil;
  end;

  SetLength(NColArr, MaxI(1, Length(LItem.Volumes)));
  NColArr[0] := nil;

  if AItem.Owner is THeightMapLandscape then begin
    if THeightMapLandscape(AItem.Owner).Map is THeightMap then begin
      HMap := THeightMapLandscape(AItem.Owner).Map as THeightMap;
      if Assigned(HMap.Image) and (HMap.Width > 0) and (HMap.Height > 0) and (GetBytesPerPixel(HMap.Image.Format) = 1) then begin
        GetMem(Heights, HMap.Width * HMap.Height * 2);
        GetMem(Attribs, HMap.Width * HMap.Height * 1);
        for i := 0 to HMap.Width * HMap.Height-1 do begin                                // For an unknown reason Newton doesn't support 8-bit height fields
          Heights^[i] := PByteBuffer(HMap.Image.Data)^[i]*256;
          Attribs^[i] := 1;
        end;
        NColArr[0] := NewtonCreateHeightFieldCollision(World, HMap.Width, HMap.Height, 0, @Heights^[0], @Attribs^[0], HMap.CellWidthScale, HMap.DepthScale/256, 0);
        NewtonAddCollisionReference(NColArr[0]);
        FreeMem(Heights);
        FreeMem(Attribs);
      end;
    end;
  end else if Length(LItem.Volumes) > 0 then begin
    for i := 0 to Length(LItem.Volumes) - 1 do begin
      Mat := TranslationMatrix4s(LItem.Volumes[i].Offset.X, LItem.Volumes[i].Offset.Y, LItem.Volumes[i].Offset.Z);
      case LItem.Volumes[i].VolumeKind of
        bvkOOBB:            NColArr[i] := NewtonCreateBox            (World, LItem.Volumes[i].Dimensions.X*2, LItem.Volumes[i].Dimensions.Y*2, LItem.Volumes[i].Dimensions.Z*2, High(Items), @Mat._11);
        bvkSphere:          NColArr[i] := NewtonCreateSphere         (World, LItem.Volumes[i].Dimensions.X*1, LItem.Volumes[i].Dimensions.Y*1, LItem.Volumes[i].Dimensions.Z*1, High(Items), @Mat._11);
        bvkCylinder:        NColArr[i] := NewtonCreateCylinder       (World, LItem.Volumes[i].Dimensions.Y*1, LItem.Volumes[i].Dimensions.X*2, High(Items), @Mat._11);
        bvkCone:            NColArr[i] := NewtonCreateCone           (World, LItem.Volumes[i].Dimensions.Y*1, LItem.Volumes[i].Dimensions.X*2, High(Items), @Mat._11);
        bvkCapsule:         NColArr[i] := NewtonCreateCapsule        (World, LItem.Volumes[i].Dimensions.Y*1, LItem.Volumes[i].Dimensions.X*2, High(Items), @Mat._11);
        bvkChamferCylinder: NColArr[i] := NewtonCreateChamferCylinder(World, LItem.Volumes[i].Dimensions.Y*1, LItem.Volumes[i].Dimensions.X*2, High(Items), @Mat._11);
      end;
    end;
  end;

  if Assigned(NColArr[0]) then begin
    if Length(NColArr) = 1 then
      NCol := NColArr[0]
    else
      NCol := NewtonCreateCompoundCollision(World, Length(NColArr), @NColArr[0], 0);

    Body := NewtonCreateBody(World, NCol);
    LItem.Data := Body;

    NewtonBodySetUserData(Body, LItem);

    Mat := TProcessing(LItem.Owner).Transform;

    NewtonBodyGetAABB(Body, @p1.v[0], @p2.v[0]);

    if AItem.Owner is THeightMapLandscape then begin
      Mat.ViewTranslate.X := Mat.ViewTranslate.X - (P2.X - P1.X) * 0.5;
      Mat.ViewTranslate.Z := Mat.ViewTranslate.Z - (P2.Z - P1.Z) * 0.5;

      NewtonBodySetMatrix(Body, @Mat._11);
    end;

    NewtonBodySetMatrix(Body, @Mat._11);

    NewtonConvexCollisionCalculateInertialMatrix(NCol, @inertia.X, @origin.X);
    NewtonBodySetMassMatrix(Body, LItem.Mass, LItem.Mass * inertia.x, LItem.Mass * inertia.y, LItem.Mass * inertia.z);
    NewtonBodySetCentreOfMass(Body, @origin.X);

  //    newtoncr`

    NewtonBodySetForceAndTorqueCallback(Body, NewtonApplyForceAndTorqueCallback);

    NewtonBodySetTransformCallback(Body, NewtonSetTransformCallback);

    NewtonBodyGetAABB(Body, @p1.v[0], @p2.v[0]);
    Log(FormatA(' ****** AABB (%3.3F, %3.3F, %3.3F : %3.3F, %3.3F, %3.3F)', [P1.X, P1.Y, P1.Z, P2.X, P2.Y, P2.Z]));

    for i := 0 to High(NColArr) do NewtonReleaseCollision(World, NColArr[i]);
  end;
end;

procedure TNewtonPhysics.DoItemAdd(AItem: TBaseColliding);
begin
end;

procedure TNewtonPhysics.ItemRemove(AItem: TBaseColliding);
begin
  inherited;

end;

constructor TNewtonPhysics.Create;
var MinSize, MaxSize: TVector3s;
begin
  inherited;
  Subsystem := Self;
  World := NewtonCreate(nil, nil);
  Log(FormatA('Newton Game Dynamics v%D.%D initialized', [NewtonWorldGetVersion(World) div 100, NewtonWorldGetVersion(World) mod 100]));
  NewtonSetPlatformArchitecture(World, 0);
  MinSize := Vec3s(-1000, -1000, -1000);
  MaxSize := Vec3s( 1000,  1000,  1000);
  NewtonSetWorldSize  (World, @MinSize.X, @MaxSize.X);
  NewtonSetSolverModel(World, 1);
end;

destructor TNewtonPhysics.Destroy;
begin
  NewtonDestroyAllBodies(World);
  NewtonDestroy(World);
  inherited;
end;

procedure TNewtonPhysics.HandleMessage(const Msg: TMessage);
var Mat: TMatrix4s;
begin
  inherited;
  if Msg.ClassType = ItemMsg.TPhysicalTransformModifiedMsg then
    with TProcessing(ItemMsg.TPhysicalTransformModifiedMsg(Msg).Item) do begin
      Mat := Transform;
      if Assigned(TColliding(Colliding).Data) then NewtonBodySetMatrix(TColliding(Colliding).Data, @Mat._11);
    end;
end;

procedure TNewtonPhysics.AddProperties(const Result: TProperties);
begin
  inherited;

end;

procedure TNewtonPhysics.SetProperties(Properties: TProperties);
begin
  inherited;

end;

procedure TNewtonPhysics.Process(const DeltaTime: TTimeUnit);
begin
  inherited;
  NewtonUpdate(World, DeltaTime);
end;

initialization
  Subsystem := nil;
end.
