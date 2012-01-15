{$Include GDefines}
{$Include CDefines}
unit CAI;

interface

uses Base3D, CTypes, CRes;

const ptLinear = 0; ptCycled = 1; ptShuttle = 2;

type
  TAIPath = class
    TotalPoints: Integer;
    CurrentIndex, TargetIndex: Integer;
    OnRouteMovePoint, CurrentMovePoint: TVector3s;
    PathType: Cardinal;
    constructor Create;
    function LoadFromResource(const Resource: TResource): Boolean; virtual;

    function GetPoint(const Index: Integer): TVector3s; virtual;

    function GetNearestWayPoint(const Point: TVector3s): Integer; virtual;
    function GetNearestRoutePoint(const Point: TVector3s; out I1, I2: Integer): TVector3s; virtual;

    function SetCurrentIndex(const Point: TVector3s): Integer; virtual;
    function SetTargetIndex(const Location, Point: TVector3s): Integer; virtual;
    function NextPoint: Boolean; virtual;
    function GetCycledPoint(const Current, Amount: Integer): Integer; virtual;
    function CyclePoint(const Amount: Integer): Boolean; virtual;
    function GetDirection(const Start, Target: Integer): Integer;

    procedure SetMovePoint(const Index: Integer); overload;
    procedure SetMovePoint(const Point: TVector3s); overload;

    destructor Free;
    private
      Points: array of TVector3s;
      PathDir: Integer;
  end;

implementation

{ TAIPath }

constructor TAIPath.Create;
begin
  SetLength(Points, 0); TotalPoints := 0;
  CurrentIndex := -1; TargetIndex := -1;
  PathDir := 0;
  PathType := ptLinear;
end;

function TAIPath.GetNearestWayPoint(const Point: TVector3s): Integer;
var i: Integer; SQDist, MinSQDist: Single;
begin
  MinSQDist := Sqr(Points[0].X - Point.X) + Sqr(Points[0].Z - Point.Z);
  Result := 0;
  for i := 1 to TotalPoints-1 do begin
    SQDist := Sqr(Points[i].X - Point.X) + Sqr(Points[i].Z - Point.Z);
    if SQDist < MinSQDist then begin Result := i; MinSQDist := SQDist; end;
  end;
end;

function TAIPath.GetNearestRoutePoint(const Point: TVector3s; out I1, I2: Integer): TVector3s;
var NearestP, PrevP, NextP: Integer; DP1, DP2, OneOverDist: Single;
  OPnt, OPrev, ONext: TVector3s;
begin
  NearestP := GetNearestWayPoint(Point);

  I1 := NearestP; I2 := NearestP;

  TargetIndex := NearestP;
  PrevP := GetCycledPoint(NearestP, -1);
  NextP := GetCycledPoint(NearestP, 1);
  OPnt := GetVector3s(Point.X - Points[NearestP].X, 0, Point.Z - Points[NearestP].Z);
  OPrev := NormalizeVector3s(GetVector3s(Points[PrevP].X - Points[NearestP].X, 0, Points[PrevP].Z - Points[NearestP].Z));
  ONext := NormalizeVector3s(GetVector3s(Points[NextP].X - Points[NearestP].X, 0, Points[NextP].Z - Points[NearestP].Z));
  DP1 := DotProductVector3s(OPnt, OPrev);
  DP2 := DotProductVector3s(OPnt, ONext);
  if (DP1 <= 0) and (DP2 <= 0) then begin
    Result := Points[NearestP];
    Exit;
  end;
  Result.Y := 0;
  if DP1 > DP2 then begin
    OneOverDist := 1 / Sqrt(SqrMagnitude(OPrev));
    Result.X := Points[NearestP].X + OPrev.X * DP1 * OneOverDist;
    Result.Z := Points[NearestP].Z + OPrev.Z * DP1 * OneOverDist;
    I2 := PrevP; 
  end else begin
    OneOverDist := 1 / Sqrt(SqrMagnitude(ONext));
    Result.X := Points[NearestP].X + ONext.X * DP2 * OneOverDist;
    Result.Z := Points[NearestP].Z + ONext.Z * DP2 * OneOverDist;
    I2 := NextP;
  end;
end;
//           o----------o
//          /
//         /     p
//        o

function TAIPath.LoadFromResource(const Resource: TResource): Boolean;
var i: Integer;
begin
  Result := False;
  if not (Resource is TPathResource) then Exit;
  TotalPoints := (Resource as TArrayResource).TotalElements-1;
  SetLength(Points, TotalPoints);
  for i := 0 to TotalPoints-1 do begin
    Points[i].X := TPath(Resource.Data)[i].X;
    Points[i].Y := TPath(Resource.Data)[i].Y;
    Points[i].Z := TPath(Resource.Data)[i].Z;
  end;
  CurrentIndex := -1; TargetIndex := -1;
  PathDir := 0;
  Result := True;
end;

destructor TAIPath.Free;
begin
  SetLength(Points, 0); TotalPoints := 0;
end;

function TAIPath.SetCurrentIndex(const Point: TVector3s): Integer;
begin
  CurrentIndex := GetNearestWayPoint(Point);
  Result := CurrentIndex;
  PathDir := GetDirection(CurrentIndex, TargetIndex);
end;

function TAIPath.SetTargetIndex(const Location, Point: TVector3s): Integer;
var I1, I2, NI: Integer;
begin
  OnRouteMovePoint := GetNearestRoutePoint(Point, I1, I2);

  if Abs(CurrentIndex - I1) < Abs(CurrentIndex - I2) then TargetIndex := I2 else TargetIndex := I1;

  PathDir := GetDirection(CurrentIndex, TargetIndex);

  NI := GetCycledPoint(CurrentIndex, PathDir);
  if DotProductVector3s(SubVector3s(GetPoint(NI), GetPoint(CurrentIndex)), SubVector3s(Location, GetPoint(CurrentIndex))) >= 0 then begin
    CurrentIndex := NI;
    PathDir := GetDirection(CurrentIndex, TargetIndex);
  end;

  if CurrentIndex = TargetIndex then
   CurrentMovePoint := OnRouteMovePoint else
    CurrentMovePoint := GetPoint(CurrentIndex);

  Result := TargetIndex;
end;

function TAIPath.GetPoint(const Index: Integer): TVector3s;
begin
  Assert((Index >= 0) and (Index < TotalPoints), 'AIPath.GetPoint: Index out of bounds');
  Result := Points[Index];
end;

function TAIPath.NextPoint: Boolean;
begin
  Result := False;
  if CurrentIndex = TargetIndex then begin
    PathDir := 0;
    Exit;
  end;
  Inc(CurrentIndex, PathDir);

  if (CurrentIndex < 0) or (CurrentIndex >= TotalPoints) then begin    // ToFix: Add cycling
    Dec(CurrentIndex, PathDir);
    PathDir := 0;
    Result := False;
  end else Result := PathDir <> 0;

  if CurrentIndex = TargetIndex then begin
    CurrentMovePoint := OnRouteMovePoint;
  end else CurrentMovePoint := GetPoint(CurrentIndex);
end;

function TAIPath.GetCycledPoint(const Current, Amount: Integer): Integer;
var CP: Integer;
begin
  CP := Current + Amount;
  if CP < 0 then CP := TotalPoints-1;
  if CP >= TotalPoints then CP := 0;
  Result := CP;
end;

function TAIPath.CyclePoint(const Amount: Integer): Boolean;
begin
  Result := True;
  CurrentIndex := GetCycledPoint(CurrentIndex, Amount);
end;

function TAIPath.GetDirection(const Start, Target: Integer): Integer;
begin
  if Target = Start then Result := 0 else
   if Target > Start then Result := 1 else
    Result := -1;
end;

procedure TAIPath.SetMovePoint(const Point: TVector3s);
begin
end;

procedure TAIPath.SetMovePoint(const Index: Integer);
begin
  CurrentMovePoint := GetPoint(Index);
end;

end.
