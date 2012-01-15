(*
 @Abstract(CAST II Engine animation unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: Feb 27, 2007 <br>
 Unit contains tesselator and item classes with animation support
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Anim;

interface

uses
  Logger,
  SysUtils,
  BaseTypes, Basics, BaseStr, Base3D, Props, BaseClasses, Resources,
  C2Types, C2VisItems, C2Visual, C2Res, CAST2;

//const
  // Maximum number of animations per skeleton
//  MaxAnimations = 16;

type
  TAnimatedTesselator = class(C2VisItems.TMeshTesselator)
  protected
    FFrame1, FFrame2, FTotalFrames: Integer;
    FFactor: Single;
    procedure SetTotalFrames(const Value: Integer); virtual;
    procedure Update; virtual; abstract;
  public
    destructor Destroy; override;
    procedure Fill(AVerticesRes: TVerticesResource; AIndicesRes: TIndicesResource);
    procedure SetFrames(Frame1, Frame2: Integer; Factor: Single); virtual;

    property TotalFrames: Integer read FTotalFrames write SetTotalFrames;
    property Frame1: Integer read FFrame1;
    property Frame2: Integer read FFrame2;
    property Factor: Single read FFactor;
  end;

  TMorphedTesselator = class(TAnimatedTesselator)
  protected
    FrameVertices, FrameIndices: array of Pointer;
    procedure SetTotalFrames(const Value: Integer); override;
    procedure Update; override;
  end;

  TAnimatedItem = class(TVisible)
  protected
    MeshValid: Boolean;                                       // True if mesh is in valid state (all frames are ready etc)
    FTotalFrames: Integer;
    FFrame: Single;
    procedure SetTotalFrames(const Value: Integer); virtual;
    procedure SetFrame(const Value: Single); virtual;
  public
    procedure OnSceneLoaded; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure SetFrames(Frame1, Frame2: Integer; Factor: Single); virtual;

    property TotalFrames: Integer read FTotalFrames write SetTotalFrames;
  end;

  TMorphedItem = class(TAnimatedItem)
  private
    function GetFrameIndicesRes(Index: Integer): TIndicesResource;
    function GetFrameVerticesRes(Index: Integer): TVerticesResource;
  protected
    procedure SetMesh; override;
  public
    function GetTesselatorClass: CTesselator; override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    property FrameVertices[Index: Integer]: TVerticesResource read GetFrameVerticesRes;
    property FrameIndices[Index: Integer]:  TIndicesResource  read GetFrameIndicesRes;
  end;

  TAnimationRec = record
    Timestamp: Cardinal;
    Transform: TMatrix4s;
  end;

  TAnimTransform = TMatrix4s;

(*  PAnimSkeletonElement = ^TAnimSkeletonElement;

  TAnimSkeletonElement = record
    Name: TShortName;
    OrigTransform,
    AnimTransform,
    TotalTransform: TMatrix4s;
    Next, ChildHead: PAnimSkeletonElement;
    Animation: array of TAnimationRec;
  end;

  TAnimSkeletons = array[0..$FFFF] of TAnimSkeletonElement;*)

  // Pointer to skeleton element type
  PSkeletonElement = ^TSkeletonElement;

  // Animation skeleton type
  TSkeletonElement = record
    Index: Integer;
    Next, ChildHead: PSkeletonElement;
  end;

  // Animation skeleton resource. Stores bones hierarchy as well as all per-bone static data.
  TSkeletonResource = class(TArrayResource)
  private
    HCounts, HIndices: array of Integer;
    procedure FreeSkeleton(El: PSkeletonElement);
  protected
    // Internal bone counter
    FTotalBones: Integer;
    // Called by @Link(AddProperties) for each bone. Can be used to specify custom properties in descendant skeleton types.
    procedure AddElementProperties(Element: PSkeletonElement; const Result: Props.TProperties; const Prefix: AnsiString); virtual;
    // Called by @Link(SetProperties) for each bone. Can be used to handle custom properties in descendant skeleton types.
    procedure SetElementProperties(Element: PSkeletonElement; Properties: Props.TProperties; const Prefix: AnsiString); virtual;
    // Sets total number of bones
    procedure SetTotalBones(ATotalBones: Integer);
  public
    // Bone hierarchy head
    Head: PSkeletonElement;
    // Offset transformations
    OffsTransform: array of TAnimTransform;
    // Bone names
    ElementNames: array of TShortName;

    destructor Destroy; override;

    function GetElementSize: Integer; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    // Scales the skeleton by the given amount
    procedure DoScale(Amount: TVector3s);
    // Rotates the skeleton by the given amount
    procedure DoRotate(Amount: TVector3s);

    // Creates and returns a new amination skeleton element
    function NewSkeletonElement: PSkeletonElement;

    // Total number of bones
    property TotalBones: Integer read FTotalBones write SetTotalBones;
  end;

  // Base class for animation resources
  TAnimationResource = class(TArrayResource)
  private
    function GetFrameIndex(TimeStampMs: Cardinal): Integer;
    procedure SetTotalTimeStamps(ATotalTimeStamps: Integer);
  public
    // Animation frame time stamps in milliseconds
    TimeStampsMs: array of Cardinal;
    // Frame transforms for each bone and each timestamp
    Transforms: array of array of TAnimTransform;
    // Current transform for each bone
    AnimTransform: array of TAnimTransform;
    // Total animation time in milliseconds
    TotalMs: Cardinal;

    destructor Destroy; override;

    function GetElementSize: Integer; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    // Sets total bones
    procedure SetTotalBones(ATotalBones: Integer);
    // Adds to a bone with the given index an animation described by array of time stamps and corresponding bone transformations
    procedure AddBoneAnim(ABoneIndex: Integer; ATimeStampsMs: array of Cardinal; AAnims: array of TAnimTransform);

    // Scales the animation by the given amount
    procedure DoScale(Amount: TVector3s);
    // Rotates the animation by the given amount
    procedure DoRotate(Amount: TVector3s);

    // Sets animation time and recalculates current transforms
    procedure SetTime(TimeStamp: TTimeUnit);
  end;

  // Animated skeleton class which encapsulates skeleton and animation resources
  TAnimSkeleton = class
  private
    Animation: array of TAnimationResource;
    TotalTransform: array of TMatrix4s;
    Skeleton: TSkeletonResource;
    FActiveAnimation: Integer;
    function GetTotalBones: Integer;
    function GetTotalAnimations: Integer;
    function GetAnimationResource(Index: Integer): TAnimationResource;
    procedure SetActiveAnimation(const Value: Integer);
  public
//    Head: PAnimSkeletonElement;
//    OffsMatrices: array of TMatrix4s;
//    Elements: array of PAnimSkeletonElement;
    constructor Create;
    destructor Destroy; override;
    function GetElementByName(const Name: TShortName): PSkeletonElement;
    procedure UpdateHierarchy;

    procedure SetSkeletonRes(ASkeletonRes: TSkeletonResource);

    procedure AddAnimation(AnimRes: TAnimationResource);

    procedure RetrieveTransform(var Result: TAnimTransform; Index: Integer);

    procedure DoScale(Amount: TVector3s);
    // Rotates the skeleton by the given amount
    procedure DoRotate(Amount: TVector3s);

    // For active animation sets time and recalculates current transforms
    procedure SetTime(Timestamp: TTimeUnit);

    // Total number of bones in skeleton
    property TotalBones: Integer read GetTotalBones;
    // Skeleton hierarchy resource
    property SkeletonResource: TSkeletonResource read Skeleton;
    // Total number of animations
    property TotalAnimations: Integer read GetTotalAnimations;
    // Array of resources representing animations
    property AnimationResource[Index: Integer]: TAnimationResource read GetAnimationResource;
    // Currently active animation
    property ActiveAnimation: Integer read FActiveAnimation write SetActiveAnimation;
  end;

  TSkinnedItem = class(TMesh)
  private
    FCurTime: TTimeUnit;
    FTimeScale: Single;
    FTotalAnimations: Integer;
    procedure SetTime(const Value: TTimeUnit);
    function GetTotalAnimations: Integer;
  protected
    procedure ResolveLinks; override;
  public
    Skeleton: TAnimSkeleton;
    ShaderConsts: TShaderConstants;
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;
    procedure RetrieveShaderConstants(var ConstList: TShaderConstants); override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure SetSkeleton(const ASkeleton: TAnimSkeleton);
    function GetAnimRes: TArrayResource;

    procedure Process(const DeltaT: Float); override;

    property CurTime: TTimeUnit read FCurTime write SetTime;
    property TimeScale: Single read FTimeScale write FTimeScale;
    // Number of animations og the skinned item
    property TotalAnimations: Integer read GetTotalAnimations;
  end;

  TSkeletalDummy = class(TProcessing)
  private
    BoneIndex: Integer;
    function GetBaseItem(): TSkinnedItem;
  protected
    procedure ComputeTransform; override;
  public
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
    property BaseItem: TSkinnedItem read GetBaseItem;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation


function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TSkeletonResource, TAnimationResource, TAnimatedItem, TMorphedItem, TSkinnedItem, TSkeletalDummy]);
end;

function NewSkeletonElement: PSkeletonElement;
begin
  New(Result);
  Result^.Index := -1;
  Result^.Next := nil;
  Result^.ChildHead := nil;
end;

{ TAnimatedMesh }

procedure TAnimatedTesselator.SetTotalFrames(const Value: Integer);
begin
  FTotalFrames := Value;
  SetFrames(MinI(FTotalFrames-1, FFrame1), MinI(FTotalFrames-1, FFrame2), FFactor);
end;

destructor TAnimatedTesselator.Destroy;
begin
  if Assigned(Vertices) then FreeMem(Vertices);
  if Assigned(Indices)  then FreeMem(Indices);
  inherited;
end;

procedure TAnimatedTesselator.SetFrames(Frame1, Frame2: Integer; Factor: Single); 
begin
  if (Frame1 = FFrame1) and (Frame2 = FFrame2) and (Factor = FFactor) then Exit;
  FFrame1 := Frame1;
  FFrame2 := Frame2;
  FFactor := Factor;
  Update();
end;

procedure TAnimatedTesselator.Fill(AVerticesRes: TVerticesResource; AIndicesRes: TIndicesResource);
var CurFrame: Integer;
begin
  Assert(Assigned(AVerticesRes), Format('%S.%S: VerticesRes is nil', [ClassName, 'Fill']));

  VertexFormat     := AVerticesRes.Format;
  NumberOfVertices := AVerticesRes.TotalElements;
  TotalVertices    := NumberOfVertices;
  ReallocMem(Vertices, AVerticesRes.DataSize);
  Move(AVerticesRes.Data^, Vertices^, AVerticesRes.DataSize);

  if Assigned(AIndicesRes) then begin
    NumberOfIndices := AIndicesRes.TotalElements;
    ReallocMem(Indices, AIndicesRes.DataSize);
    Move(AIndicesRes.Data^, Indices^, AIndicesRes.DataSize);
  end else begin
    NumberOfIndices := 0;
    ReallocMem(Indices, 0);
  end;
  Init();
  CurFrame := FFrame1;
  FFrame1 := -1;
  SetFrames(CurFrame, CurFrame, 0);
end;

{ TMorphedMesh }

procedure TMorphedTesselator.SetTotalFrames(const Value: Integer);
begin
  inherited;
  if Length(FrameVertices) < FTotalFrames then SetLength(FrameVertices, FTotalFrames);
  if Length(FrameIndices)  < FTotalFrames then SetLength(FrameIndices,  FTotalFrames);
end;

procedure TMorphedTesselator.Update;
var i: Integer; DestVec, SrcVec1, SrcVec2: ^TVector3s;
begin
  Assert((FFactor >= 0) and (FFactor <= 1));
  if (TotalFrames = 0) or not Assigned(FrameVertices[0]) then Exit;
  if FFactor < epsilon then begin
    Move(FrameVertices[FFrame1]^, Vertices^, TotalVertices * FVertexSize);
    Move(FrameIndices[FFrame1]^,  Indices^,  TotalIndices  * IndexSize);
  end else if 1-FFactor < epsilon then begin
    Move(FrameVertices[FFrame2]^, Vertices^, TotalVertices * FVertexSize);
    Move(FrameIndices[FFrame2]^,  Indices^,  TotalIndices  * IndexSize);
  end else begin
    for i := 0 to TotalVertices-1 do begin
      DestVec := @TByteBuffer(Vertices^)[i*FVertexSize];
      SrcVec1 := @TByteBuffer(FrameVertices[FFrame1]^)[i*FVertexSize];
      SrcVec2 := @TByteBuffer(FrameVertices[FFrame2]^)[i*FVertexSize];
      DestVec^.X := SrcVec1^.X * (1-FFactor) + SrcVec2^.X * FFactor;
      DestVec^.Y := SrcVec1^.Y * (1-FFactor) + SrcVec2^.Y * FFactor;
      DestVec^.Z := SrcVec1^.Z * (1-FFactor) + SrcVec2^.Z * FFactor;
    end;
  end;
  Invalidate([tbVertex], False);
end;

{ TAnimatedItem }

const GeomPrefix = 'Geometry\Frame #%D ';       // Use in Format()

procedure TAnimatedItem.SetTotalFrames(const Value: Integer);
begin
  FTotalFrames := Value;
  if CurrentTesselator is TAnimatedTesselator then begin
    TAnimatedTesselator(CurrentTesselator).TotalFrames := Value;
    if FFrame >= TAnimatedTesselator(CurrentTesselator).TotalFrames then SetFrame(MaxI(0, TAnimatedTesselator(CurrentTesselator).TotalFrames-1));
  end;
  BuildItemLinks();
end;

procedure TAnimatedItem.SetFrame(const Value: Single);
begin
  FFrame := Value;
  if MeshValid and (CurrentTesselator is TAnimatedTesselator) then begin
    TAnimatedTesselator(CurrentTesselator).SetFrames(Trunc(Value), MinI(TotalFrames, Trunc(Value+1)), Frac(Value));
  end;
end;

procedure TAnimatedItem.SetFrames(Frame1, Frame2: Integer; Factor: Single);
begin
  if MeshValid and (CurrentTesselator is TAnimatedTesselator) then
    TAnimatedTesselator(CurrentTesselator).SetFrames(Frame1, Frame2, Factor);
  FFrame := Frame1;
end;

procedure TAnimatedItem.OnSceneLoaded;
begin
  inherited;
  SetMesh();
end;

procedure TAnimatedItem.AddProperties(const Result: Props.TProperties);
begin
  inherited;

  if Assigned(Result) then begin
    Result.Add('Total frames', vtInt, [], IntToStr(FTotalFrames),  '');
    Result.Add('Frame', vtSingle, [], FloatToStr(FFrame), Format('%D-%D', [0, FTotalFrames-1]));
  end;
end;

procedure TAnimatedItem.SetProperties(Properties: Props.TProperties);
begin
  inherited;

  if Properties.Valid('Total frames') then TotalFrames := StrToIntDef(Properties['Total frames'], FTotalFrames);
  if Properties.Valid('Frame') then SetFrame(StrToFloatDef(Properties['Frame'], FFrame));
end;

{ TMorphedItem }

function TMorphedItem.GetFrameIndicesRes(Index: Integer): TIndicesResource;
var Item: TItem;
begin
  if ResolveLink(Format(GeomPrefix + 'indices', [Index]), Item) or (Item is TIndicesResource) then
    Result := Item as TIndicesResource else
      Result := nil;
end;

function TMorphedItem.GetFrameVerticesRes(Index: Integer): TVerticesResource;
var Item: TItem;
begin
  if ResolveLink(Format(GeomPrefix + 'vertices', [Index]), Item) or (Item is TVerticesResource) then
    Result := Item as TVerticesResource else
      Result := nil;
end;

procedure TMorphedItem.SetMesh;
var i: Integer; Mesh: TMorphedTesselator;
begin
  inherited;
  MeshValid := False;
  if CurrentTesselator is TMorphedTesselator then Mesh := TMorphedTesselator(CurrentTesselator) else Exit;
  if not Assigned(FrameVertices[0]) then Exit;
  Mesh.TotalFrames      := TotalFrames;
  Mesh.Fill(FrameVertices[0], FrameIndices[0]);

  MeshValid := True;
  for i := 0 to TotalFrames-1 do if Assigned(FrameVertices[i]) then begin
    Mesh.FrameVertices[i] := FrameVertices[i].Data;
//    Mesh.NumberOfVertices := FrameVertices[i].TotalElements;
    if (Mesh.NumberOfIndices > 0) and Assigned(FrameIndices[i]) then begin
      Mesh.FrameIndices[i] := FrameIndices[i].Data;
      
      if FrameIndices[i].TotalElements <> Mesh.NumberOfIndices then begin
        MeshValid := False;
        
        Log(Format('%S("%S").%S: Number of indices doesn''t match for all frames', [ClassName, Name, 'SetMesh']), lkError);
        
      end;

    end;

    if (FrameVertices[i].Format <> Mesh.VertexFormat) or (FrameVertices[i].TotalElements <> Mesh.NumberOfVertices) then begin
      MeshValid := False;
      
      Log(Format('%S("%S").%S: Format or number of vertices doesn''t match for all frames', [ClassName, Name, 'SetMesh']), lkError);
      
    end;
  end;

  if CurrentTesselator <> nil then begin
    CurrentTesselator.Init();
    BoundingBox := CurrentTesselator.GetBoundingBox;
  end;
  
  SetFrame(FFrame);
end;

function TMorphedItem.GetTesselatorClass: CTesselator; begin Result := TMorphedTesselator; end;

procedure TMorphedItem.AddProperties(const Result: Props.TProperties);
var i: Integer;
begin
  inherited;
  for i := 0 to FTotalFrames-1 do begin
    AddItemLink(Result, Format(GeomPrefix + 'vertices', [i]), [], 'TVerticesResource');
    AddItemLink(Result, Format(GeomPrefix + 'indices',  [i]), [], 'TIndicesResource');
  end;
end;

procedure TMorphedItem.SetProperties(Properties: Props.TProperties);
var i: Integer;
begin
  inherited;
  for i := 0 to FTotalFrames-1 do begin
    if Properties.Valid(Format(GeomPrefix + 'vertices', [i])) then
      SetLinkProperty(Format(GeomPrefix + 'vertices', [i]), Properties[Format(GeomPrefix + 'vertices', [i])]);
    if Properties.Valid(Format(GeomPrefix + 'indices', [i])) then
      SetLinkProperty(Format(GeomPrefix + 'indices', [i]), Properties[Format(GeomPrefix + 'indices', [i])]);
  end;

  SetMesh();
end;

{ TSkinnedItem }

procedure TSkinnedItem.SetTime(const Value: TTimeUnit);
var i: Integer;
begin
  FCurTime := Value;
//  CurrentTesselator.Invalidate([tbVertex], False);
  if Assigned(Skeleton) and Assigned(Skeleton.SkeletonResource) then begin
    Skeleton.SetTime(FCurTime);
    if Length(BlendMatrices) <> Skeleton.Skeleton.TotalBones then SetLength(BlendMatrices, Skeleton.Skeleton.TotalBones);
    for i := 0 to High(BlendMatrices) do begin
//      Skeleton.Elements[i]^.TotalTransform := MulMatrix4s(Skeleton.OffsMatrices[i], Skeleton.Elements[i]^.TotalTransform);
//      BlendMatrices[i] := Skeleton.Elements[i]^.TotalTransform;
      Skeleton.RetrieveTransform(BlendMatrices[i], i);
      BlendMatrices[i] := MulMatrix4s(BlendMatrices[i], Transform);
    end;
    InvalidateTransform();
  end;
end;

function TSkinnedItem.GetTotalAnimations: Integer;
begin
  Result := 0;
  if Assigned(Skeleton) then Result := Skeleton.TotalAnimations;
  if FTotalAnimations <> -1 then Result := FTotalAnimations;  
end;

procedure TSkinnedItem.ResolveLinks;
var i: Integer; Item: TItem;
begin
  inherited;
  if not Assigned(Skeleton) then Exit;
  if ResolveLink('Geometry\Skeleton', Item) then Skeleton.SetSkeletonRes(Item as TSkeletonResource);
  for i := 0 to TotalAnimations-1 do
    if ResolveLink('Geometry\Animation #' + IntToStr(i), Item) then Skeleton.AddAnimation(Item as TAnimationResource);
  FTotalAnimations := -1;           // Let TotalAnimations be determined by skeleton
end;

constructor TSkinnedItem.Create(AManager: TItemsManager);
begin
  Skeleton := TAnimSkeleton.Create;
  FTotalAnimations := -1;
  inherited;
end;

destructor TSkinnedItem.Destroy;
begin
  FreeAndNil(Skeleton);
  inherited;
end;

procedure TSkinnedItem.RetrieveShaderConstants(var ConstList: TShaderConstants);
//var i: Integer;
begin
  inherited;
{  SetLength(ConstList, GetAnimRes.DataSize div SizeOf(TMatrix4s)*4);
  for i := 0 to High(ConstList) do begin
    ConstList[i].ShaderKind := skVertex;
    ConstList[i].ShaderRegister :=
  end;
  ConstList := ShaderConsts;}
end;

procedure TSkinnedItem.AddProperties(const Result: TProperties);
var i: Integer;
begin
  inherited;
  AddItemLink(Result, 'Geometry\Skeleton', [], 'TSkeletonResource');
  if Assigned(Skeleton) then for i := 0 to TotalAnimations-1 do
    AddItemLink(Result, 'Geometry\Animation #' + IntToStr(i), [], 'TAnimationResource');

  if Assigned(Result) then begin
    Result.Add('Geometry\Total animations', vtInt, [poReadonly], IntToStr(TotalAnimations), '');
    Result.Add('Time', vtSingle, [], FloatToStr(FCurTime), Format('%D-%D', [0, 10]));
    Result.Add('Time scale', vtSingle, [], FloatToStr(FTimeScale), Format('%D-%D', [0, 10]));
  end;
end;

procedure TSkinnedItem.SetProperties(Properties: TProperties);
var i: Integer;
begin
  inherited;
  if Properties.Valid('Geometry\Total animations') then
    FTotalAnimations := StrToIntDef(Properties['Geometry\Total animations'], 0);          // Only used for loading
  BuildItemLinks;  
  if Properties.Valid('Geometry\Skeleton') then SetLinkProperty('Geometry\Skeleton', Properties['Geometry\Skeleton']);
  if Assigned(Skeleton) then for i := 0 to TotalAnimations-1 do
    if Properties.Valid('Geometry\Animation #' + IntToStr(i)) then
      SetLinkProperty('Geometry\Animation #' + IntToStr(i), Properties['Geometry\Animation #' + IntToStr(i)]);
  if Properties.Valid('Time') then CurTime := StrToFloatDef(Properties['Time'], 0);
  if Properties.Valid('Time scale') then TimeScale := StrToFloatDef(Properties['Time scale'], 0);
  SetMesh();
end;

procedure TSkinnedItem.SetSkeleton(const ASkeleton: TAnimSkeleton);
begin
  Skeleton := ASkeleton;
end;

function TSkinnedItem.GetAnimRes: TArrayResource;
var Item: TItem;
begin
  if ResolveLink('Geometry\Animation', Item) then
    Result := Item as TArrayResource
  else if Item is TArrayResource then
    Result := Item as TArrayResource
  else
    Result := nil;
end;

procedure TSkinnedItem.Process(const DeltaT: Float);
begin
  inherited;
  CurTime := CurTime + DeltaT * FTimeScale;
end;

{ TAnimSkeleton }

function TAnimSkeleton.GetTotalBones: Integer;
begin
  if Assigned(Skeleton) then Result := Skeleton.TotalBones else Result := 0;
end;

function TAnimSkeleton.GetTotalAnimations: Integer;
begin
  Result := Length(Animation);
end;

function TAnimSkeleton.GetAnimationResource(Index: Integer): TAnimationResource;
begin
  Result := Animation[Index];
end;

procedure TAnimSkeleton.SetActiveAnimation(const Value: Integer);
begin
  FActiveAnimation := Value;
  if FActiveAnimation > High(Animation) then FActiveAnimation := -1;
end;

constructor TAnimSkeleton.Create;
begin
{  Head.Name := '';
  Head.Transform := IdentityMatrix4s;
  Head.Next := nil;
  Head.ChildHead := nil;}
  FActiveAnimation := -1;
end;

destructor TAnimSkeleton.Destroy;
begin
  inherited;
end;

function TAnimSkeleton.GetElementByName(const Name: TShortName): PSkeletonElement;

  function FindInElement(Element: PSkeletonElement): PSkeletonElement;
  begin
    Result:= Element;
    if Name = Skeleton.ElementNames[Element^.Index] then Exit;
    if Assigned(Element^.ChildHead) then begin
      Result := FindInElement(Element^.ChildHead);
      if Assigned(Result) then Exit;
    end;
    if Assigned(Element^.Next) then begin
      Result := FindInElement(Element^.Next);
      if Assigned(Result) then Exit;
    end;
    Result:= nil;
  end;

begin
  if Assigned(Skeleton.Head) then Result := FindInElement(Skeleton.Head) else Result := nil;
end;

procedure TAnimSkeleton.UpdateHierarchy;

  procedure UpdateElements(Element: PSkeletonElement; const MatCur: TMatrix4s);
  var Child: PSkeletonElement; Ind: Integer;
  begin
    Ind := Element^.Index;
    Assert(Ind <> -1);
//    if ind = -1 then Exit;

    TotalTransform[Ind] := MulMatrix4s(Animation[FActiveAnimation].AnimTransform[Ind], MatCur);

    Child := Element^.ChildHead;
    while Assigned(Child) do begin
      UpdateElements(Child, TotalTransform[Ind]);
      Child := Child^.Next;
    end;
  end;

begin
  UpdateElements(Skeleton.Head, IdentityMatrix4s);
end;

procedure TAnimSkeleton.SetSkeletonRes(ASkeletonRes: TSkeletonResource);
begin
  Skeleton := ASkeletonRes;
  if Assigned(Skeleton) then SetLength(TotalTransform, Skeleton.TotalBones);
end;

procedure TAnimSkeleton.AddAnimation(AnimRes: TAnimationResource);
begin
  Assert(Assigned(AnimRes));
  if not Assigned(AnimRes) then Exit;
  SetLength(Animation, Length(Animation)+1);
  Animation[High(Animation)] := AnimRes;
  if FActiveAnimation = -1 then FActiveAnimation := 0;
end;

procedure TAnimSkeleton.RetrieveTransform(var Result: TAnimTransform; Index: Integer);
begin
  MulMatrix4s(Result, Skeleton.OffsTransform[Index], TotalTransform[Index]);
end;

procedure TAnimSkeleton.DoScale(Amount: TVector3s);
var i: Integer;
begin
  Skeleton.DoScale(Amount);
  for i := 0 to High(Animation) do Animation[i].DoScale(Amount);
end;

procedure TAnimSkeleton.DoRotate(Amount: TVector3s);
var i: Integer;
begin
  Skeleton.DoRotate(Amount);
  for i := 0 to High(Animation) do Animation[i].DoRotate(Amount);
end;

procedure TAnimSkeleton.SetTime(Timestamp: TTimeUnit);
begin
  if FActiveAnimation = -1 then Exit;
  Animation[FActiveAnimation].SetTime(Timestamp);
  UpdateHierarchy();
end;

{ TSkeletonResource }

procedure TSkeletonResource.FreeSkeleton(El: PSkeletonElement);
var TempEl, CurEl: PSkeletonElement;
begin
  CurEl := El;
  while Assigned(CurEl) do begin
    FreeSkeleton(CurEl^.ChildHead);
    TempEl := CurEl^.Next;
    Dispose(CurEl);
    CurEl := TempEl;
  end;
end;

procedure TSkeletonResource.AddElementProperties(Element: PSkeletonElement; const Result: TProperties; const Prefix: AnsiString);
var i: Integer; Pref: AnsiString;
begin
  if not Assigned(Element) then Exit;
  Result.Add(Prefix + HierarchyDelimiter + 'Name', vtString, [], ElementNames[Element^.Index], '');
  Pref := Prefix + ElementNames[Element^.Index] + HierarchyDelimiter;

  for i := 0 to 3 do AddVector4sProperty(Result, Pref + 'Offs transform row#' + IntToStr(i), OffsTransform[Element^.Index].Rows[i]);
end;

procedure TSkeletonResource.SetElementProperties(Element: PSkeletonElement; Properties: TProperties; const Prefix: AnsiString);
begin
  if not Assigned(Element) then Exit;
//  Inc(FTotalBones);
end;

destructor TSkeletonResource.Destroy;
begin
  FreeSkeleton(Head);
  TotalBones := 0;
  inherited;
end;

function TSkeletonResource.GetElementSize: Integer;
begin
  Result := SizeOf(TSkeletonElement);
end;

procedure TSkeletonResource.AddProperties(const Result: TProperties);

  procedure BuildTree();
  var TotalIndices, TotalCounts: Integer;

    procedure AddCount(ACount: Integer);
    begin
      if Length(HCounts) <= TotalCounts then SetLength(HCounts, Totalcounts+1);
      HCounts[TotalCounts] := ACount;
      Inc(TotalCounts);
    end;

    procedure AddIndex(AIndex: Integer);
    begin
      if Length(HIndices) <= TotalIndices then SetLength(HIndices, TotalIndices+1);
      HIndices[TotalIndices] := AIndex;
      Inc(TotalIndices);
//      Log(' ****** Saved bone #' + IntToStr(High(Indices)) + ' "' + ElementNames[AIndex] + '", ind: ' + IntToStr(AIndex));
    end;

    procedure CountChilds(SkEl: PSkeletonElement);
    var CurEl: PSkeletonElement; Count: Integer;
    begin
//      Log(' ****** Level up #' + IntToStr(High(Counts)));
      CurEl := SkEl^.ChildHead;                   //
      Count := 0;                                 //            7
      while Assigned(CurEl) do begin              //           /
        AddIndex(CurEl^.Index);                   //      5-4-6
        Inc(Count);                               //       \
        CurEl := CurEl^.Next;                     //    2---3
      end;                                        //     \
      AddCount(Count);                            //      1
                                                  //     /         0  1  2 3  5 4 6  7
      CurEl := SkEl^.ChildHead;                   //    0       1  1  2  0 3  0 0 1  0
      while Assigned(CurEl) do begin
        CountChilds(CurEl);
        CurEl := CurEl^.Next;
      end;
    end;

  begin
    TotalIndices := 0;
    TotalCounts  := 0;
    AddIndex(Head^.Index);
    CountChilds(Head);
//    Log(' ****** Saved hierarchy: C: ' + IntToStr(Length(Counts)) + ', I: ' + IntToStr(Length(Indices)));
  end;

var i: Integer;
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Total bones', vtInt, [poReadonly], IntToStr(FTotalBones), '');
  Result.AddBinary('Offset transforms', [poReadonly, poHidden], @OffsTransform[0], FTotalBones * SizeOf(TAnimTransform));

  for i := 0 to FTotalBones-1 do
    Result.Add('Hierarchy\Bone name #' + IntToStr(i), vtString, [], ElementNames[i], '', '');

  // Build and serialize bone tree
  BuildTree();
  Result.AddBinary('Hierarchy\Counts',  [poReadonly, poHidden], @HCounts[0],  Length(HCounts)  * SizeOf(Integer));
  Result.AddBinary('Hierarchy\Indices', [poReadonly, poHidden], @HIndices[0], Length(HIndices) * SizeOf(Integer));

//  Log(' ****** C: ' + IntToStr(Counts[High(Counts)]) + ', I: ' + IntToStr(Indices[High(Indices)]));
end;

procedure TSkeletonResource.SetProperties(Properties: TProperties);
var StartIndex, StartCount: Integer;

  procedure SetChilds(ParentEl: PSkeletonElement);
  var i: Integer; NewEl, CurEl: PSkeletonElement;
  begin                                                             //
    Log(' ****** Level up #' + IntToStr(StartCount));
    CurEl := nil;                                                   //
    for i := 0 to HCounts[StartCount]-1 do begin                     //
      NewEl := NewSkeletonElement();                                //
      if i = 0 then                                                 //   4   5  6
        ParentEl^.ChildHead := NewEl                                //    \ /  /
      else                                                          //  0--2--3
        CurEl^.Next := NewEl;                                       //   \        c  3 0 2 1 0 0 0
      CurEl := NewEl;                                               //    1       i  1 0 2 3 4 5 6

//      Log(' ****** Loading bone #' + IntToStr(StartIndex));
//      Log(' ****** Loading bone #' + IntToStr(StartIndex) + ' "' + ElementNames[HIndices[StartIndex]] + '", ind: ' + IntToStr(HIndices[StartIndex]));
      CurEl^.Index := HIndices[StartIndex];
      Inc(StartIndex);
    end;

    CurEl := ParentEl^.ChildHead;
    for i := 0 to HCounts[StartCount]-1 do begin
      Inc(StartCount);      
      SetChilds(CurEl);
      CurEl := CurEl^.Next;
    end;
  end;

var
  i: Integer;

begin
  inherited;
  if Properties.Valid('Total bones') then TotalBones := StrToIntDef(Properties['Total bones'], 0);

  Log(' ****** Loading hierarchy');

  if Properties.Valid('Offset transforms') then begin
    if TotalBones > 0 then Properties.RetrieveBinPropertyData('Offset transforms', @OffsTransform[0]);
  end else
    Log(ClassName + '.SetProperties: offset transforms data not found', lkError);

  for i := 0 to FTotalBones-1 do
    if Properties.Valid('Hierarchy\Bone name #' + IntToStr(i)) then
      ElementNames[i] := Properties['Hierarchy\Bone name #' + IntToStr(i)];

  SetLength(HCounts, Properties.GetBinPropertySize('Hierarchy\Counts', SizeOf(Integer)));
  if Assigned(HCounts) then Properties.RetrieveBinPropertyData('Hierarchy\Counts', @HCounts[0]);

  SetLength(HIndices, Properties.GetBinPropertySize('Hierarchy\Indices', SizeOf(Integer)));
  if Assigned(HIndices) then Properties.RetrieveBinPropertyData('Hierarchy\Indices', @HIndices[0]);

//  Log(' ****** C: ' + IntToStr(Counts[High(Counts)]) + ', I: ' + IntToStr(Indices[High(Indices)]));

  FreeSkeleton(Head);

  if Length(HCounts) > 0 then begin
//    Log(' ****** Loading hierarchy: C: ' + IntToStr(Length(Counts)) + ', I: ' + IntToStr(Length(Indices)));
    Head := NewSkeletonElement();
    Head^.Index := HIndices[0];
    StartIndex := 1;
    StartCount := 0;
    SetChilds(Head);
  end;
end;

procedure TSkeletonResource.SetTotalBones(ATotalBones: Integer);
begin
  FTotalBones := ATotalBones;
//  if Length(OffsTransform) >= TotalBones then Exit;
  SetLength(OffsTransform, FTotalBones);
  SetLength(ElementNames,  FTotalBones);
end;

procedure TSkeletonResource.DoScale(Amount: TVector3s);
var i: Integer;
begin
  for i := 0 to High(OffsTransform) do begin
    OffsTransform[i]._41 := OffsTransform[i]._41 * Amount.X;
    OffsTransform[i]._42 := OffsTransform[i]._42 * Amount.Y;
    OffsTransform[i]._43 := OffsTransform[i]._43 * Amount.Z;
  end;
end;

procedure TSkeletonResource.DoRotate(Amount: TVector3s);
var i: Integer; RotMatrix: TMatrix3s;
begin
  RotMatrix := MulMatrix3s(ZRotationMatrix3s(Amount.Z/180*pi), YRotationMatrix3s(Amount.Y/180*pi));
  RotMatrix := MulMatrix3s(XRotationMatrix3s(Amount.X/180*pi), RotMatrix);
  for i := 0 to High(OffsTransform) do
//    OffsTransform[i].ViewTranslate := Transform3Vector3s(RotMatrix, OffsTransform[i].ViewTranslate);
    OffsTransform[i] := MulMatrix4s(OffsTransform[i], ExpandMatrix3s(RotMatrix));
end;

function TSkeletonResource.NewSkeletonElement: PSkeletonElement;
begin
  New(Result);
  Result^.Index := FTotalBones;
  Result^.Next := nil;
  Result^.ChildHead := nil;
end;

{ TAnimationResource }

function TAnimationResource.GetFrameIndex(TimeStampMs: Cardinal): Integer;
begin

end;

procedure TAnimationResource.SetTotalTimeStamps(ATotalTimeStamps: Integer);
var i: Integer;
begin
  SetLength(TimeStampsMS, ATotalTimeStamps);
  for i := 0 to High(Transforms) do SetLength(Transforms[i], ATotalTimeStamps);
end;

destructor TAnimationResource.Destroy;
begin
  SetLength(TimeStampsMs, 0);
  SetTotalBones(0);
  inherited;
end;

function TAnimationResource.GetElementSize: Integer;
begin
  Result := SizeOf(TAnimTransform);
end;

procedure TAnimationResource.AddProperties(const Result: Props.TProperties);
var i: Integer;
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.Add('Total time, ms', vtInt, [],           IntToStr(TotalMs), '');
  Result.Add('Total frames',   vtInt, [poReadonly], IntToStr(Length(TimeStampsMs)), '');

  Result.Add('Data\Total bones', vtInt, [poReadonly], IntToStr(Length(Transforms)), '');
  Result.AddBinary('Data\Timestamps', [poReadonly, poHidden], @TimeStampsMs[0], Length(TimeStampsMs) * SizeOf(Cardinal));
  for i := 0 to High(Transforms) do
    Result.AddBinary('Data\Bone #' + IntToStr(i), [poReadonly, poHidden], @Transforms[i][0], Length(Transforms[i]) * SizeOf(TAnimTransform));
end;


procedure TAnimationResource.SetProperties(Properties: Props.TProperties);
var i: Integer;
begin
  inherited;
  if Properties.Valid('Total time, ms') then TotalMs := StrToIntDef(Properties['Total time, ms'], 0);
  if Properties.Valid('Data\Total bones') then SetTotalBones(StrToIntDef(Properties['Data\Total bones'], 0));
  if Properties.Valid('Total frames') then SetTotalTimeStamps(StrToIntDef(Properties['Total frames'], 0));
  Properties.RetrieveBinPropertyData('Data\Timestamps', @TimeStampsMs[0]);      // ToFix: avoid range error
  for i := 0 to High(Transforms) do
    Properties.RetrieveBinPropertyData('Data\Bone #' + IntToStr(i), @Transforms[i][0]);      // ToFix: avoid range error
end;


procedure TAnimationResource.SetTotalBones(ATotalBones: Integer);
begin
  SetLength(Transforms,    ATotalBones);
  SetLength(AnimTransform, ATotalBones);
end;


procedure TAnimationResource.AddBoneAnim(ABoneIndex: Integer; ATimeStampsMs: array of Cardinal; AAnims: array of TAnimTransform);

  procedure InsertAt(Index: Integer);
  var Bone, i: Integer;
  begin
    SetTotalTimeStamps(Length(TimeStampsMS)+1);
    for i := High(TimeStampsMs) downto Index+1 do begin
      TimeStampsMs[i] := TimeStampsMs[i+1];
      for Bone := 0 to High(Transforms) do
        Transforms[Bone, i] := Transforms[Bone, i-1];
    end;
  end;

  function GetTimeIndex(TimeMs: Cardinal): Integer;
  begin
    Result := 0;
    while (Result <= High(TimeStampsMs)) and (TimeMs > TimeStampsMs[Result]) do Inc(Result);
    if (Result > High(TimeStampsMs)) or (TimeMs > TimeStampsMs[Result]) then InsertAt(Result);
  end;

var
  i, Ind: Integer;

begin
  Assert(Length(ATimeStampsMs) = Length(AAnims));

  for i := 0 to High(ATimeStampsMs) do begin
    Ind := GetTimeIndex(ATimeStampsMs[i]);
    TimeStampsMs[Ind] := ATimeStampsMs[i];
    Transforms[ABoneIndex, Ind] := AAnims[i];

    if TotalMs < TimeStampsMs[Ind] then TotalMs := TimeStampsMs[Ind];
{
    if not Assigned(Skeleton.Animation[0].Transforms[SkelEl^.Index]) then
      SetLength(Skeleton.Animation[0].Transforms[SkelEl^.Index], Frame.m_cMatrixKeys);
    for i := 0 to High(Skeleton.Animation[0].TimeStampsMs) do begin
      Skeleton.Animation[0].TimeStampsMs[i] := Frame.m_pMatrixKeys[i].dwTime;
      Skeleton.Animation[0].Transforms[SkelEl^.Index, i] := TMatrix4s(Frame.m_pMatrixKeys[i].mat);

      if Skeleton.Animation[0].TotalMs < Skeleton.Animation[0].TimeStampsMs[i] then
        Skeleton.Animation[0].TotalMs := Skeleton.Animation[0].TimeStampsMs[i]}
  end;
end;


procedure TAnimationResource.DoScale(Amount: TVector3s);
var i, j: Integer;
begin
  for i := 0 to High(Transforms) do begin
    // Scale translation part of current transforms
    AnimTransform[i]._41 := AnimTransform[i]._41 * Amount.X;
    AnimTransform[i]._42 := AnimTransform[i]._42 * Amount.Y;
    AnimTransform[i]._43 := AnimTransform[i]._43 * Amount.Z;
    for j := 0 to High(Transforms[i]) do begin                // Scale translation part of animation transforms
      Transforms[i, j]._41 := Transforms[i, j]._41 * Amount.X;
      Transforms[i, j]._42 := Transforms[i, j]._42 * Amount.Y;
      Transforms[i, j]._43 := Transforms[i, j]._43 * Amount.Z;
    end;
  end;
end;

procedure TAnimationResource.DoRotate(Amount: TVector3s);
var i, j: Integer; RotMatrix: TMatrix3s;
begin
  RotMatrix := MulMatrix3s(ZRotationMatrix3s(Amount.Z/180*pi), YRotationMatrix3s(Amount.Y/180*pi));
  RotMatrix := MulMatrix3s(XRotationMatrix3s(-Amount.X/180*pi), RotMatrix);
  for i := 0 to High(Transforms) do begin
    // Rotate translation part of current transforms
//    AnimTransform[i].ViewTranslate := Transform3Vector3s(RotMatrix, AnimTransform[i].ViewTranslate);
    AnimTransform[i] := MulMatrix4s(AnimTransform[i], ExpandMatrix3s(RotMatrix));
    for j := 0 to High(Transforms[i]) do                 // Rotate translation part of animation transforms
      Transforms[i, j] := MulMatrix4s(Transforms[i, j], ExpandMatrix3s(RotMatrix));
//      Transforms[i, j].ViewTranslate := Transform3Vector3s(RotMatrix, Transforms[i, j].ViewTranslate);
  end;
end;

procedure TAnimationResource.SetTime(TimeStamp: TTimeUnit);
var
  i, Ind, i1, i2: Integer;
  LerpValue: Single;
  TimeStampMs: Cardinal;
begin
  TimeStampMs := TimeUnitToMs(TimeStamp) mod TotalMs;

  i1 := 0;
  i2 := 0;
    // ToFix: rewrite
    for Ind := 0 to High(TimeStampsMs) do if (TimeStampsMs[Ind] > TimeStampMs) then begin
      i2 := Ind;

      if (Ind > 0) then i1 := Ind - 1 else i1 := Ind;
      Break;
    end;

  if ((TimeStampsMs[i2] - TimeStampsMs[i1]) = 0) then
    LerpValue := 0
  else
    LerpValue := (TimeStampMs - TimeStampsMs[i1]) / (TimeStampsMs[i2] - TimeStampsMs[i1]);

  if (LerpValue > 0.5) then Ind := i2 else Ind := i1;

  for i := 0 to High(AnimTransform) do if Assigned(Transforms[i]) then
    AnimTransform[i] := Transforms[i, Ind];
end;

{ TSkeletalDummy }

procedure TSkeletalDummy.ComputeTransform;
begin
  if Assigned(BaseItem) then begin
    BaseItem.Skeleton.RetrieveTransform(FTransform, BoneIndex);
    FTransform := MulMatrix4s(FTransform, BaseItem.Transform);
  end;
  TransformValid := True;
end;

function TSkeletalDummy.GetBaseItem: TSkinnedItem;
var Item: TItem;
begin
  ResolveLink('Base item', Item);
  Result := TSkinnedItem(Item);
end;

procedure TSkeletalDummy.AddProperties(const Result: Props.TProperties);
var BonesEnum: AnsiString;
begin
  inherited;
  AddItemLink(Result, 'Base item', [], 'TSkinnedItem');
  if not Assigned(Result) then Exit;

  BonesEnum := '';
  if Assigned(BaseItem) then
    BonesEnum := StringsToEnumA(BaseItem.Skeleton.Skeleton.ElementNames, True);

  Result.AddEnumerated('Bone index', [], BoneIndex, BonesEnum);
end;

procedure TSkeletalDummy.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid('Base item') then SetLinkProperty('Base item', Properties['Base item']);
  if Properties.Valid('Bone index') then BoneIndex := Properties.GetAsInteger('Bone index');
end;

begin
  GlobalClassList.Add('C2Anim', GetUnitClassList);
end.
