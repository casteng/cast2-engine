{$I GDefines.inc}
unit FScale;

interface

uses
   Logger, 
  Template,
  BaseTypes, BaseClasses, Base3D, C2VisItems, C2Visual, C2Res, C2Anim, CAST2,
  C2EdMain,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Buttons;

type
  TScaleForm = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    ScaleXEdit: TEdit;
    RotXEdit: TEdit;
    MoveXEdit: TEdit;
    MoveYEdit: TEdit;
    RotYEdit: TEdit;
    ScaleYEdit: TEdit;
    ScaleZEdit: TEdit;
    RotZEdit: TEdit;
    MoveZEdit: TEdit;
    MoveBut: TButton;
    RotBut: TButton;
    ScaleBut: TButton;
    AlignBut: TButton;
    CalcNormBut: TButton;
    TabSheet2: TTabSheet;
    ScaleUEdit: TEdit;
    MoveUEdit: TEdit;
    MoveVEdit: TEdit;
    ScaleVEdit: TEdit;
    ScaleWEdit: TEdit;
    MoveWEdit: TEdit;
    TexMoveBut: TButton;
    TexScaleBut: TButton;
    TexAlignBut: TButton;
    ReverseBut: TButton;
    InvNormBut: TButton;
    TexFlipBut: TButton;
    TabSheet3: TTabSheet;
    Label1: TLabel;
    Label3: TLabel;
    OnTopBut: TSpeedButton;
    BBoxEdit: TEdit;
    TabSheet4: TTabSheet;
    TabSheet5: TTabSheet;
    SetCBox: TComboBox;
    TexBoxEdit: TEdit;
    PBar: TProgressBar;
    Button1: TButton;
    AnalizeBut: TButton;
    OptStatLabel: TLabel;
    OptResLabel: TLabel;
    ValidateMeshBut: TButton;
    procedure ScaleXEditChange(Sender: TObject);
    function CalcUVBox(Tesselator: TMeshTesselator; TSet: Integer): TBoundingBox;

    function ScaleMesh(Mesh: TItem; Amount: TVector3s): Boolean;
    function RotateMesh(Mesh: TItem; Amount: TVector3s): Boolean;
    procedure MoveVertices(Resource: TVerticesResource; Amount: TVector3s);
    function MoveMesh(Mesh: TItem; Amount: TVector3s): Boolean;

    procedure ScaleUVMap(Resource: TVerticesResource; TSet: Integer; Amount: TVector3s);

    function OptimizeMesh(Mesh: TMesh; AllowModify: Boolean): Integer;
    procedure UpdateInfo;

    procedure OnTopButClick(Sender: TObject);
    procedure BBoxEditKeyPress(Sender: TObject; var Key: Char);
    procedure FormActivate(Sender: TObject);
    procedure ScaleButClick(Sender: TObject);
    procedure AlignButClick(Sender: TObject);
    procedure RotButClick(Sender: TObject);
    procedure MoveButClick(Sender: TObject);
    procedure InvNormButClick(Sender: TObject);
    procedure SetCBoxChange(Sender: TObject);
    procedure UpdateTexEditors;
    procedure AnalizeButClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ValidateMeshButClick(Sender: TObject);
    procedure TexScaleButClick(Sender: TObject);
    procedure RotateEditEnter(Sender: TObject);
    procedure ScaleEditEnter(Sender: TObject);
    procedure MoveEditEnter(Sender: TObject);
  private
    function ClearIntVector(const Key: NativeInt; const Value: TIntVector; Data: Pointer): Boolean;
  end;

var
  ScaleForm: TScaleForm;

implementation

uses MainForm, Basics, BaseStr, Props, Timer, C2Types, Resources;

{$R *.dfm}

procedure TScaleForm.ScaleXEditChange(Sender: TObject);
var i: word; NewText: TCaption;
begin
  with TEdit(Sender) do begin
    for i := 1 to Length(Text) do if CharInSet(Text[i], ['0'..'9', '-', DecimalSeparator]) then NewText := NewText + Text[i];
    Text := NewText;
  end;
end;

function TScaleForm.CalcUVBox(Tesselator: TMeshTesselator; TSet: Integer): TBoundingBox;
var i, j, UVOfs: Integer;
begin
  Result.P1 := GetVector3s(0, 0, 0); Result.P2 := GetVector3s(0, 0, 0);

  if (Tesselator = nil) or (Tesselator.Vertices = nil) then begin
    Log('TScaleForm.CalcUVBox: Tesselator or Tesselator.Vertices is nil', lkError);
    Exit;
  end;

  if GetVertexTextureSetsCount(Tesselator.VertexFormat) <= TSet then begin
    Log(Format('TScaleForm.CalcUVBox: Can''t process UV set #%D, because mesh contains only %D texture set(s)',
                   [TSet, GetVertexTextureSetsCount(Tesselator.VertexFormat)]), lkError);
    Exit;
  end;

  Result.P1 := GetVector3s( 100000,  100000,  100000);
  Result.P2 := GetVector3s(-100000, -100000, -100000);
  UVOfs := GetVertexElementOffset(Tesselator.VertexFormat, vfiTEX[TSet]);
  for i := 0 to Tesselator.TotalVertices-1 do for j := 0 to 2 do
    with TVector3s(PtrOffs(Tesselator.Vertices, i*Tesselator.VertexSize + UVOfs)^), Result do begin
      if GetVertexTextureCoordsCount(Tesselator.VertexFormat, TSet) > j then begin
        if V[j] < P1.V[j] then P1.V[j] := V[j];
        if V[j] > P2.V[j] then P2.V[j] := V[j];
      end else begin
        P1.V[j] := 0; P2.V[j] := 0;
      end;
    end;
end;

function TScaleForm.ScaleMesh(Mesh: TItem; Amount: TVector3s): Boolean;

  procedure ScaleVertices(Resource: TVerticesResource);
  var i, Ofs: Integer;
  begin
    if not Assigned(Resource) or not Assigned(Resource.Data) then
      Log('ScaleVertices: Resource or its data is nil', lkError)
    else begin
      Ofs := GetVertexElementOffset(Resource.Format, vfiXYZ);
      for i := 0 to Resource.TotalElements-1 do
        with TVector3s(PtrOffs(Resource.Data, i*Resource.GetElementSize + Ofs)^) do begin
          X := X * Amount.X;
          Y := Y * Amount.Y;
          Z := Z * Amount.Z;
        end;
    end;
  end;

var i: Integer; Anim: TMorphedItem;
begin
  Result := True;
  if Mesh is TMesh then begin
    if Mesh is TSkinnedItem then TSkinnedItem(Mesh).Skeleton.DoScale(Amount);
    ScaleVertices(TMesh(Mesh).Vertices);
    TMesh(Mesh).CurrentTesselator.Invalidate([tbVertex], False);
  end else if Mesh is TMorphedItem then begin
    Anim := Mesh as TMorphedItem;
    for i := 0 to Anim.TotalFrames-1 do ScaleVertices(Anim.FrameVertices[i]);
    Anim.SetFrames(0, 0, 0);
  end else
    Result := False;
end;

function TScaleForm.RotateMesh(Mesh: TItem; Amount: TVector3s): Boolean;

  procedure RotateVertices(Resource: TVerticesResource);
  var i, Ofs, NormOfs: Integer; RotMatrix: TMatrix3s; P: ^TVector3s;
  begin
    if not Assigned(Resource) or not Assigned(Resource.Data) then begin
      Log('TScaleForm.RotateMesh: Resource or its data is nil', lkError);
      Exit;
    end;

    RotMatrix := MulMatrix3s(ZRotationMatrix3s(Amount.Z/180*pi), YRotationMatrix3s(Amount.Y/180*pi));
    RotMatrix := MulMatrix3s(XRotationMatrix3s(Amount.X/180*pi), RotMatrix);

    Ofs     := GetVertexElementOffset(Resource.Format, vfiXYZ);
    NormOfs := GetVertexElementOffset(Resource.Format, vfiNORM);
    for i := 0 to Resource.TotalElements-1 do begin
      P := PtrOffs(Resource.Data, i*Resource.GetElementSize + Ofs);
      P^ := Transform3Vector3s(RotMatrix, P^);
      if VertexContains(Resource.Format, vfNORMALS) then begin
        P := PtrOffs(Resource.Data, i*Resource.GetElementSize + NormOfs);
        P^ := Transform3Vector3s(RotMatrix, P^);
      end;
    end;
  end;

var i: Integer; Anim: TMorphedItem;

begin
  Result := True;
  if Mesh is TMesh then begin
    if Mesh is TSkinnedItem then TSkinnedItem(Mesh).Skeleton.DoRotate(Amount);
    RotateVertices(TMesh(Mesh).Vertices);
    TMesh(Mesh).CurrentTesselator.Invalidate([tbVertex], False);
  end else if Mesh is TMorphedItem then begin
    Anim := Mesh as TMorphedItem;
    for i := 0 to Anim.TotalFrames-1 do RotateVertices(Anim.FrameVertices[i]);
    Anim.SetFrames(0, 0, 0);
  end else
    Result := False;
end;

procedure TScaleForm.MoveVertices(Resource: TVerticesResource; Amount: TVector3s);
var i, Ofs: Integer;
begin
  if not Assigned(Resource) or not Assigned(Resource.Data) then begin
    Log('TScaleForm.MoveVertices: Resource or its data is nil', lkError);
    Exit;
  end;
  Ofs := GetVertexElementOffset(Resource.Format, vfiXYZ);
  for i := 0 to Resource.TotalElements-1 do
    with TVector3s(PtrOffs(Resource.Data, i*Resource.GetElementSize + Ofs)^) do begin
      X := X + Amount.X;
      Y := Y + Amount.Y;
      Z := Z + Amount.Z;
    end;
end;

function TScaleForm.MoveMesh(Mesh: TItem; Amount: TVector3s): Boolean;
var i: Integer; Anim: TMorphedItem;
begin
  Result := True;
  if Mesh is TMesh then begin
    MoveVertices(TMesh(Mesh).Vertices, Amount);
    TMesh(Mesh).CurrentTesselator.Invalidate([tbVertex], False)
  end else if Mesh is TMorphedItem then begin
    Anim := Mesh as TMorphedItem;
    for i := 0 to Anim.TotalFrames-1 do MoveVertices(Anim.FrameVertices[i], Amount);
    Anim.SetFrames(0, 0, 0);
  end else
    Result := False;
end;

procedure TScaleForm.ScaleUVMap(Resource: TVerticesResource; TSet: Integer; Amount: TVector3s);
var i, j: Integer; UVOfs: Integer;
begin
  if not Assigned(Resource) or not Assigned(Resource.Data) then begin
    Log('TScaleForm.ScaleUVMap: Resource or its data is nil', lkError);
    Exit;
  end;

  if GetVertexTextureSetsCount(Resource.Format) <= TSet then begin
    Log(Format('TScaleForm.ScaleUVMap: Can''t process UV set #%D, because mesh contains only %D texture set(s)',
                   [TSet, GetVertexTextureSetsCount(Resource.Format)]), lkError);
    Exit;
  end;

  UVOfs := GetVertexElementOffset(Resource.Format, vfiTEX[TSet]);
  for i := 0 to Resource.TotalElements-1 do
    with TVector3s(PtrOffs(Resource.Data, i*Resource.GetElementSize + UVOfs)^) do
      for j := 0 to GetVertexTextureCoordsCount(Resource.Format, TSet)-1 do
        V[j] := V[j] * Amount.V[j];
end;

procedure TScaleForm.UpdateInfo;
var Mesh: TMesh;
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then begin
    Caption := 'Modify: no mesh selected';
    Exit;
  end;
  Mesh := MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh;

  Caption := 'Modify: [' + string(Mesh.Name) + ']';

  with Mesh.CurrentTesselator.GetBoundingBox do
    BBoxEdit.Text := Format('(%3.3F:%3.3F:%3.3F) - (%3.3F:%3.3F:%3.3F)', [P1.X, P1.Y, P1.Z, P2.X, P2.Y, P2.Z]);

  BBoxEdit.Height   := 15;
  TexBoxEdit.Height := 15;

  if Mesh.Vertices = nil then Label3.Caption := '0 vertices' else Label3.Caption := Format('%D vertices',  [Mesh.Vertices.TotalElements]);
  if Mesh.Indices  = nil then Label3.Caption := Label3.Caption + '0 vertices' else Label3.Caption := Label3.Caption + Format(', %D indices', [Mesh.Indices.TotalElements]);

  UpdateTexEditors;
end;

procedure TScaleForm.OnTopButClick(Sender: TObject);
begin
  if OnTopBut.Down then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TScaleForm.BBoxEditKeyPress(Sender: TObject; var Key: Char);
begin
  Key := #0;
end;

procedure TScaleForm.FormActivate(Sender: TObject);
begin
  BBoxEdit.Height   := 15;
  TexBoxEdit.Height := 15;
end;

procedure TScaleForm.ScaleButClick(Sender: TObject);
var Mesh: TMesh;
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then begin
    Log('TScaleForm.ScaleButClick: A mesh object must be selected', lkError);
    Exit;
  end;

  Mesh := (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh);
  ScaleMesh(MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh,
            GetVector3s(StrToFloatDef(ScaleXEdit.Text, 1), StrToFloatDef(ScaleYEdit.Text, 1), StrToFloatDef(ScaleZEdit.Text, 1)));
  Mesh.CurrentTesselator.Invalidate([tbVertex], False);
end;

procedure TScaleForm.AlignButClick(Sender: TObject);
var Mesh: TMesh; BBox: TBoundingBox; Scale, NormFactor: Single;
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then begin
    Log('TScaleForm.AlignButClick: A mesh object must be selected', lkError);
    Exit;
  end;

  Mesh := (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh);

  BBox := (Mesh.CurrentTesselator as TMeshTesselator).GetBoundingBox;

  Scale      := StrToFloatDef(ScaleXEdit.Text, 1);
  NormFactor := 1;

  if (BBox.P2.X - BBox.P1.X > BBox.P2.Y - BBox.P1.Y) and (BBox.P2.X - BBox.P1.X > BBox.P2.Z - BBox.P1.Z) then
    NormFactor := Scale / (BBox.P2.X - BBox.P1.X);
  if (BBox.P2.Y - BBox.P1.Y > BBox.P2.X - BBox.P1.X) and (BBox.P2.Y - BBox.P1.Y > BBox.P2.Z - BBox.P1.Z) then
    NormFactor := Scale / (BBox.P2.Y - BBox.P1.Y);
  if (BBox.P2.Z - BBox.P1.Z > BBox.P2.X - BBox.P1.X) and (BBox.P2.Z - BBox.P1.Z > BBox.P2.Y - BBox.P1.Y) then
    NormFactor := Scale / (BBox.P2.Z - BBox.P1.Z);

  ScaleMesh(MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh, GetVector3s(NormFactor, NormFactor, NormFactor));
  Mesh.CurrentTesselator.Invalidate([tbVertex], False);
end;

procedure TScaleForm.RotButClick(Sender: TObject);
begin
  if not RotateMesh(MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode),
                    GetVector3s(StrToFloatDef(RotXEdit.Text, 0), StrToFloatDef(RotYEdit.Text, 0), StrToFloatDef(RotZEdit.Text, 0))) then
    Log('TScaleForm.RotButClick: A mesh object must be selected', lkError);
end;

procedure TScaleForm.MoveButClick(Sender: TObject);
begin
  if not MoveMesh(MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode),
                  GetVector3s(StrToFloatDef(MoveXEdit.Text, 0), StrToFloatDef(MoveYEdit.Text, 0), StrToFloatDef(MoveZEdit.Text, 0))) then
    Log('TScaleForm.MoveButClick: A mesh object must be selected', lkError);
end;

procedure TScaleForm.InvNormButClick(Sender: TObject);
var i, NormOfs: Integer; Tesselator: TMeshTesselator; P: ^TVector3s;
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then begin
     Log('TScaleForm.InvNormButClick: A mesh object must be selected', lkError); 
    Exit;
  end;

  Tesselator := (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TVisible).CurrentTesselator as TMeshTesselator;

  if (Tesselator = nil) or (Tesselator.Vertices = nil) then begin
     Log('TScaleForm.InvNormButClick: Tesselator or Tesselator.Vertices is nil', lkError); 
    Exit;
  end;

  if not VertexContains(Tesselator.VertexFormat, vfNORMALS) then begin
     Log('TScaleForm.InvNormButClick: Tesselator doesn''t contain normals', lkError); 
    Exit;
  end;

  NormOfs := GetVertexElementOffset(Tesselator.VertexFormat, vfiNORM);
  for i := 0 to Tesselator.TotalVertices-1 do begin
    P := PtrOffs(Tesselator.Vertices, i*Tesselator.VertexSize + NormOfs);
    P^ := ScaleVector3s(P^, -1);
  end;

  Tesselator.Invalidate([tbVertex], False);
end;

procedure TScaleForm.SetCBoxChange(Sender: TObject);
begin
  UpdateTexEditors;
end;

procedure TScaleForm.UpdateTexEditors;
var Tesselator: TMeshTesselator;
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then Exit;

  Tesselator := (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TVisible).CurrentTesselator as TMeshTesselator;

  with CalcUVBox(Tesselator, SetCBox.ItemIndex) do
    TexBoxEdit.Text := Format('(%3.3F:%3.3F:%3.3F) - (%3.3F:%3.3F:%3.3F)', [P1.X, P1.Y, P1.Z, P2.X, P2.Y, P2.Z]);

  ScaleUEdit.Enabled := False; ScaleVEdit.Enabled := False; ScaleWEdit.Enabled := False;
  MoveUEdit.Enabled  := False; MoveVEdit.Enabled  := False; MoveWEdit.Enabled  := False;

  if GetVertexTextureSetsCount(Tesselator.VertexFormat) <= SetCBox.ItemIndex then Exit;

  if GetVertexTextureCoordsCount(Tesselator.VertexFormat, SetCBox.ItemIndex) >= 1 then begin
    ScaleUEdit.Enabled := True;
    MoveUEdit.Enabled  := True;
  end;
  if GetVertexTextureCoordsCount(Tesselator.VertexFormat, SetCBox.ItemIndex) >= 2 then begin
    ScaleVEdit.Enabled := True;
    MoveVEdit.Enabled  := True;
  end;
  if GetVertexTextureCoordsCount(Tesselator.VertexFormat, SetCBox.ItemIndex) >= 3 then begin
    ScaleWEdit.Enabled := True;
    MoveWEdit.Enabled  := True;
  end;
end;

procedure TScaleForm.AnalizeButClick(Sender: TObject);
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then begin
     Log('TScaleForm.MoveButClick: A mesh object must be selected', lkError); 
    Exit;
  end;

  OptimizeMesh(MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh, False);
end;

procedure TScaleForm.Button1Click(Sender: TObject);
var Removed: Integer;
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then begin
     Log('TScaleForm.MoveButClick: A mesh object must be selected', lkError); 
    Exit;
  end;

  Removed := OptimizeMesh(MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh, True);
  OptResLabel.Caption := IntToStr(Removed) + ' vertices removed';
end;

const
  PrimeArray: array[0..15] of Byte = (1, 3, 5, 7, 11, 13, 17, 19, 23, 27, 31, 33, 37, 39, 41, 43);
var
  VertexSize: NativeInt;
type
  _HashMapKeyType = Pointer;
  _HashMapValueType = NativeInt;
  {$MESSAGE 'Instantiating TPointerIntHashMap interface'}
  {$I gen_coll_hashmap.inc}
  TPointerIntHashMap = class(_GenHashMap)
  end;

  function _HashMapHashFunc(const Key: _HashMapKeyType): NativeInt; {$I inline.inc}
  var i: Integer;
  begin
    Result := 0;
    for i := 0 to VertexSize-1 do begin
      Result := Result + PByteArray(Key)^[i] * PrimeArray[i and 15]*i;
    end;
  end;

  function _HashMapKeyEquals(const Key1, Key2: _HashMapKeyType): Boolean;
  begin
    Result := CmpMem(Key1, Key2, VertexSize);
  end;
  {$MESSAGE 'Instantiating TPointerIntHashMap'}
  {$I gen_coll_hashmap.inc}

function TScaleForm.ClearIntVector(const Key: NativeInt; const Value: TIntVector; Data: Pointer): Boolean;
begin
  Value.Free;
end;

function TScaleForm.OptimizeMesh(Mesh: TMesh; AllowModify: Boolean): Integer;
var
  i, j, k, ProgCnt,
  VSize, UniqueElements: Integer;
  VRes: TVerticesResource;
  IRes: TIndicesResource;
  SrcI, DestI: Integer;
  TotalCut, TotalCopy: Integer;
  TempData: Pointer; NewSize: Integer;
  Props: TProperties;

  TimeMark: TTimeMark;

  VMap: TPointerIntHashMap;
  IMap: TIntIntVecHashMap;
  Vector: TIntVector;

  Garbage: IRefcountedContainer;
begin
  Result := 0;

  if Mesh = nil then Exit;

  Garbage := CreateRefcountedContainer();

  Core.Timer.GetInterval(TimeMark, True);

  VRes := Mesh.Vertices;
  IRes := Mesh.Indices;
  if (VRes = nil) or (IRes = nil) then Exit;

  VSize := GetVertexSize(VRes.Format);
  VertexSize := VSize;

  VMap := TPointerIntHashMap.Create(16*16);
  IMap := TIntIntVecHashMap.Create(16*16);

  Garbage.AddObjects([VMap, IMap]);

  for j := 0 to IRes.TotalElements-1 do begin
    i := TWordBuffer(IRes.Data^)[j];
    if not IMap.ContainsKey(i) then IMap[i] := TIntVector.Create(10) else begin
      i := i;
    end;
    IMap[i].Add(j);
  end;

  TotalCut := 0;

  PBar.Max := VRes.TotalElements-1;
  PBar.Show;
  ProgCnt := MaxI(1, VRes.TotalElements div 100);

  UniqueElements := 0;
  i := 0;
  while i < VRes.TotalElements - TotalCut do begin

    if VMap.ContainsKey(PtrOffs(VRes.Data, i * VSize)) then begin        // duplicate
      if AllowModify then begin
        DestI := VMap[PtrOffs(VRes.Data, i * VSize)];
        Move(TByteBuffer(VRes.Data^)[(VRes.TotalElements-1 - TotalCut)  * VSize],                     // Move last vertex to current
             TByteBuffer(VRes.Data^)[UniqueElements * VSize],
             VSize);

        // Adjust indices
        Vector := IMap[i];
        if Assigned(Vector) then begin
          for j := 0 to Vector.Count-1 do begin
            TWordBuffer(IRes.Data^)[Vector[j]] := DestI;
            IMap[DestI].Add(Vector[j]);
          end;
          Vector.Clear();
        end;

        Vector := IMap[VRes.TotalElements-1 - TotalCut];
        if Assigned(Vector) then begin
          for j := 0 to Vector.Count-1 do begin
            TWordBuffer(IRes.Data^)[Vector[j]] := UniqueElements;
            IMap[UniqueElements].Add(Vector[j]);
          end;
          Vector.Clear();
        end;

        Inc(TotalCut);
        Dec(i);
      end;

    end else begin
      VMap[PtrOffs(VRes.Data, i * VSize)] := i;
      Inc(UniqueElements);
    end;

    if i mod ProgCnt = 0 then begin
      PBar.Max := VRes.TotalElements-1 - TotalCut;
      PBar.Position := i;
      PBar.Repaint;
    end;

    Inc(i);
  end;

  IMap.ForEach(ClearIntVector, nil);

  if AllowModify then begin
    NewSize := UniqueElements * VSize;
    GetMem(TempData, NewSize);
    Move(VRes.Data^, TempData^, NewSize);

    VRes.Allocate(0);
    VRes.SetAllocated(NewSize, TempData);

    Props := TProperties.Create;
    Mesh.CurrentTesselator.Invalidate([tbVertex, tbIndex], True);
    Mesh.GetProperties(Props);
    Mesh.SetProperties(Props);
    Props.Free;

    Core.Renderer.Active := True;

    MainF.ItemsChanged := True;
  end;

//  EWorld.DoForEachItem(ResetOptimizedMesh);

  PBar.Hide;

  OptStatLabel.Caption := Format('Unique elements: %D of %D, time: %D ms', [UniqueElements, VRes.TotalElements, Round(Core.Timer.GetInterval(TimeMark, True) * 1000)]);
end;

procedure TScaleForm.ValidateMeshButClick(Sender: TObject);
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then begin
     Log('TScaleForm.ScaleButClick: A mesh object must be selected', lkError); 
    Exit;
  end;

  if ((MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TVisible).CurrentTesselator as TMeshTesselator).Validate then
    MessageDlg('Validation passed', mtInformation, [mbOK], 0)
  else
    MessageDlg('Validation error', mtError, [mbOK], 0);
end;

procedure TScaleForm.TexScaleButClick(Sender: TObject);
var Mesh: TMesh;
begin
  if not (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is TMesh) then begin
    Log('TScaleForm.ScaleButClick: A mesh object must be selected', lkError);
    Exit;
  end;

  Mesh := (MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh);
  ScaleUVMap((MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TMesh).Vertices, SetCBox.ItemIndex,
             GetVector3s(StrToFloatDef(ScaleUEdit.Text, 1), StrToFloatDef(ScaleVEdit.Text, 1), StrToFloatDef(ScaleWEdit.Text, 1)));
  Mesh.CurrentTesselator.Invalidate([tbVertex], False);
end;

procedure TScaleForm.RotateEditEnter(Sender: TObject);
begin
  RotBut.Default   := True;
  ScaleBut.Default := False;
  MoveBut.Default  := False;
end;

procedure TScaleForm.ScaleEditEnter(Sender: TObject);
begin
  ScaleBut.Default := True;
  RotBut.Default   := False;
  MoveBut.Default  := False;
end;

procedure TScaleForm.MoveEditEnter(Sender: TObject);
begin
  MoveBut.Default  := True;
  ScaleBut.Default := False;
  RotBut.Default   := False;
end;

end.
