{$Include CDefines}
{$Include GDefines}
unit CGShoot;

interface

uses Basics, Base3D, Collisions, CAST;

type

  TAmmo = class(TActor)
// Implements basic collision detection (object - object, object - landscape)
    Owner: TItem;
    CDLand, CDObjects: Boolean;
    ShellBoundingVolumes: TBoundingVolumes;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Init; override;
    procedure InitBoundingVolume; virtual;

    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;

    procedure AddHitItem(Item: TItem); virtual;
    function CheckHit(Items: TItems; TotalItems: Integer): Integer; virtual;
    function Process: Boolean; override;
  protected
    LastLocation: TVector3s;
    FirstProcess: Boolean;
    HitStatus: Cardinal;
    HitItem: TItem;
    HitItems: TItems; TotalHitItems: Integer;
  end;

implementation

{ TAmmo }

constructor TAmmo.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  CDLand := True; CDObjects := True;
end;

procedure TAmmo.Init;
begin
  inherited;
  FirstProcess := True;
  InitBoundingVolume;
end;

procedure TAmmo.InitBoundingVolume;
var
//  XAxis, YAxis,
  ZAxis: TVector3s;
  Dist: Single;
begin
  SubVector3s(ZAxis, Location, LastLocation);

  if SqrMagnitude(ZAxis) < epsilon then ZAxis := GetVector3s(0, 0, GetDimensions.Z);

  Dist := Sqrt(SqrMagnitude(ZAxis)){ + BoundingVolumes.Dimensions.Z};        // Shell's path during last tick
//  ZAxis.X := ZAxis.X / Dist; ZAxis.Y := ZAxis.Y / Dist; ZAxis.Z := ZAxis.Z / Dist;

  if ShellBoundingVolumes = nil then SetLength(ShellBoundingVolumes, 1);
  ShellBoundingVolumes[0].VolumeKind := bvOOBB;
  ScaleVector3s(ShellBoundingVolumes[0].Offset, ZAxis, 0.5 * 0);
//  AddVector3s(ShellBoundingVolumes[0].Offset, ShellBoundingVolumes[0].Offset, GetVector3s(0, 0, 100));
//  AddVector3s(ShellBoundingVolumes[0].Offset, LastLocation, ScaleVector3s(ZAxis, 0.5*0));
  ShellBoundingVolumes[0].Dimensions := GetDimensions;
  ShellBoundingVolumes[0].Dimensions.Z := MaxS(Dist*0.5, GetDimensions.Z);

(*  CrossProductVector3s(XAxis, GetVector3s(0, 1, 0), ZAxis);                          // X axis
  if SqrMagnitude(XAxis) < 0.00001*0.00001 then XRotationMatrix3s(ShellBoundingVolumes.Matrix, pi/2) else begin
    NormalizeVector3s(XAxis, XAxis);                                                 // Normalize X axis
    CrossProductVector3s(YAxis, ZAxis, XAxis);                                       // Y axis
    NormalizeVector3s(YAxis, YAxis);                                                 // Normalize Y axis

{      ZRotationMatrix3s(tmat, 0*pi/4);
    tmat := IdentityMatrix3s;
    MulMatrix3s(tmat, tmat, YRotationMatrix3s(-pi/2));
    tmat := YRotationMatrix3s(-pi/2);}

    ShellBoundingVolumes.Matrix._11 := XAxis.X;                                      // Shell way's matrix
    ShellBoundingVolumes.Matrix._12 := XAxis.Y;
    ShellBoundingVolumes.Matrix._13 := XAxis.Z;

    ShellBoundingVolumes.Matrix._21 := YAxis.X;
    ShellBoundingVolumes.Matrix._22 := YAxis.Y;
    ShellBoundingVolumes.Matrix._23 := YAxis.Z;

    ShellBoundingVolumes.Matrix._31 := ZAxis.X;
    ShellBoundingVolumes.Matrix._32 := ZAxis.Y;
    ShellBoundingVolumes.Matrix._33 := ZAxis.Z;
  end;

  ShellBoundingVolumes.TotalVolumes := 1;
  ShellBoundingVolumes.Dimensions := BoundingVolumes.Dimensions;
  if SqrMagnitude(ShellBoundingVolumes.Dimensions) < Epsilon then ShellBoundingVolumes.Dimensions := SubVector3s(BoundingBox.P2, BoundingBox.P1);
//    ShellBoundingVolumes.Dimensions.X := 30;
//    ShellBoundingVolumes.Dimensions.Y := 30;
  ShellBoundingVolumes.Dimensions.Z := Dist*0.5;

  if ShellBoundingVolumes.First = nil then
   ShellBoundingVolumes.First := NewBoundingVolume(vkOOBB, GetVector3s(0, 0, Dist*0.5), ShellBoundingVolumes.Dimensions) else begin
     ShellBoundingVolumes.First^.VolumeKind := vkOOBB;
     ShellBoundingVolumes.First^.Offset := GetVector3s(0, 0, Dist*0.5);
     ShellBoundingVolumes.First^.Dimensions := ShellBoundingVolumes.Dimensions;
     ShellBoundingVolumes.First^.Next := nil;
   end;
  ShellBoundingVolumes.Last := ShellBoundingVolumes.First;*)
end;

function TAmmo.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Landscape collision test', ptBoolean, Pointer(CDLand));
  NewProperty(Result, 'Objects collision test', ptBoolean, Pointer(CDObjects));
end;

function TAmmo.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  CDLand := Boolean(GetPropertyValue(AProperties, 'Landscape collision test'));
  CDObjects := Boolean(GetPropertyValue(AProperties, 'Objects collision test'));
  Result := 0;
end;

function TAmmo.Process: Boolean;
  var
  XAxis, YAxis, ZAxis, RotAxis: TVector3s;
  Dist: Single;
begin
  Result := False;

  SubVector3s(ZAxis, Location, LastLocation);

  Dist := Sqrt(SqrMagnitude(ZAxis)){ + BoundingVolumes.Dimensions.Z};        // Shell's path during last tick
  if Dist < epsilon then Exit;
  ZAxis.X := ZAxis.X / Dist; ZAxis.Y := ZAxis.Y / Dist; ZAxis.Z := ZAxis.Z / Dist;

  GetVectorRotateQuat(Orient, GetVector3s(0, 0, 1), ZAxis);

  BoundingVolumes[0] := ShellBoundingVolumes[0];
//  BoundingVolumes[0].Offset := GetVector3s(0, 0, 0);

  SetOrientation(Orient);

  LastLocation := Location;
  Result := inherited Process;
end;

procedure TAmmo.AddHitItem(Item: TItem);      // Todo: optimize and implement sorting
begin
  Inc(TotalHitItems);
  SetLength(HitItems, TotalHitItems);
  HitItems[TotalHitItems-1] := Item;
end;

function TAmmo.CheckHit(Items: TItems; TotalItems: Integer): Integer;
const LandCollisionAcc = 20.0; FactorStep = LandCollisionAcc / 2000;
var
  i, Height: Integer; Dist, Factor: Single;
  XAxis, ZAxis: TVector3s; CR: TCollisionResult;

begin
  Result := 0;
  
  TotalHitItems := 0;
  HitStatus     := hsNone;
  HitItem       := nil;

  if CDObjects and not FirstProcess then begin
    InitBoundingVolume;
    for i := 0 to TotalItems-1 do if Items[i] <> Self then begin
      CR := VolumeColDet(ShellBoundingVolumes, Items[i].BoundingVolumes, ModelMatrix, Items[i].ModelMatrix);
      if CR.Vol1 <> nil then begin
        if TotalHitItems = 0 then HitItem := Items[i];
        AddHitItem(Items[i]);
        HitStatus := HitStatus or hsItem;
      end;
    end;
  end;

  if CDLand and (World.Landscape.HeightMap <> nil) then with World.Landscape.HeightMap do begin
    if (Location.Y + GetDimensions.Y > -BreakHeight) then begin         // The shell isn't under break
      Height := GetHeight(Location.X, Location.Z);
      Dist := Location.Y - GetDimensions.Y - Height;
      if (Dist < 0) and (Height >= MinHeight) then begin
        if CreateEvents then World.Events.Add(cmdCollision, [LongInt(Self)]);
        SubVector3s(ZAxis, Location, LastLocation);
        XAxis := Location;
        Factor := FactorStep;
        while (Abs(Dist) > LandCollisionAcc) and (Factor < 1) do begin
          Dist := XAxis.Y - GetDimensions.Y - GetHeight(XAxis.X, XAxis.Z);
          SubVector3s(XAxis, Location, ScaleVector3s(ZAxis, Factor));
          Factor := Factor + FactorStep;
        end;

        SetLocation(XAxis);
        HitStatus := HitStatus or hsLandscape;
      end;
    end;
  end;

  FirstProcess := False;
  Result := TotalHitItems;
end;

end.

