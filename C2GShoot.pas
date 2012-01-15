unit C2GShoot;

interface

uses Basics, Base3D, Collisions, Props, BaseClasses, CAST2, C2Visual;

const
// Hit status
  hsNone = 0; hsLandscape = 1; hsItem = 2; hsVehicle = 4; hsSelf = 8;

type
  TAmmo = class(TMesh)
// Implements basic collision detection (object - object, object - landscape)
    Owner: TItem;
    CDLand, CDObjects: Boolean;
    ShellBoundingVolumes: TBoundingVolumes;
    LVelocity: TVector3s;
    AVelocity: TQuaternion;
    constructor Create(AManager: TItemsManager); override;
    procedure OnSceneLoaded; override;
    procedure InitBoundingVolume; virtual;

    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;

    procedure AddHitItem(Item: TItem); virtual;
    function CheckHit(Items: TItems; TotalItems: Integer): Integer; virtual;
    procedure Process; override;
  protected
    LastLocation: TVector3s;
    FirstProcess: Boolean;
    HitStatus: Cardinal;
    HitItem: TItem;
    HitItems: TItems; TotalHitItems: Integer;
  end;

implementation

{ TAmmo }

constructor TAmmo.Create(AManager: TItemsManager);
begin
  inherited;
  FirstProcess := True;
  CDLand := True; CDObjects := True;
end;

procedure TAmmo.OnSceneLoaded;
begin
  inherited;
  InitBoundingVolume;
end;

procedure TAmmo.InitBoundingVolume;
var ZAxis: TVector3s; Dist: Single;
begin
  LastLocation := Position;

  SubVector3s(ZAxis, Position, LastLocation);

  if SqrMagnitude(ZAxis) < epsilon then ZAxis := GetVector3s(0, 0, Dimensions.Z);

  Dist := Sqrt(SqrMagnitude(ZAxis)){ + BoundingVolumes.Dimensions.Z};        // Shell's path during last tick
  ZAxis.X := ZAxis.X / Dist; ZAxis.Y := ZAxis.Y / Dist; ZAxis.Z := ZAxis.Z / Dist;

  if ShellBoundingVolumes = nil then SetLength(ShellBoundingVolumes, 1);
  ShellBoundingVolumes[0].VolumeKind := bvOOBB;
  ScaleVector3s(ShellBoundingVolumes[0].Offset, ZAxis, 0.5*0);
  ShellBoundingVolumes[0].Dimensions := Dimensions;
  ShellBoundingVolumes[0].Dimensions.Z := MaxS(Dist*0.5, Dimensions.Z);
end;

procedure TAmmo.AddProperties(const Result: TProperties); 
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Physical\Objects collision test', vtBoolean, [], OnOffStr[CDObjects], '');
end;

procedure TAmmo.SetProperties(Properties: TProperties);
begin
  inherited;

  if Properties.Valid('Physical\Objects collision test') then CDObjects := Properties.GetAsInteger('Physical\Objects collision test') > 0;
end;

procedure TAmmo.Process;
begin
  HitStatus := hsNone; HitItem := nil;

  inherited;
  LastLocation := Position;
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
    for i := 0 to TotalItems-1 do if (Items[i] is TProcessing) and (Items[i] <> Self) then begin
      CR := VolumeColDet(ShellBoundingVolumes, TProcessing(Items[i]).Colliding.Volumes, Transform, TProcessing(Items[i]).Transform);
      if CR.Vol1 <> nil then begin
        if TotalHitItems = 0 then HitItem := Items[i];
        AddHitItem(Items[i]);
        HitStatus := HitStatus or hsItem;
      end;
    end;
  end;

(*  if CDLand and (World.Landscape.HeightMap <> nil) then with World.Landscape.HeightMap do begin
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
  end; *)

  FirstProcess := False;
  Result := TotalHitItems;
end;

end.

