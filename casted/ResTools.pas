{$I GDefines.inc}
{$I CDefines.inc}
unit ResTools;

interface

uses
   Logger, 
  C2EdMain,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtDlgs, Buttons,
  BaseTypes, Basics, BaseStr, Base2D, Base3D, Props, Resources, BaseClasses,
  C2Types, CAST2, C2ResImport, C2Res, C2Visual, C2VisItems, C2Anim, C2Materials,
  //?
  XImport, C2DX8Render, Direct3D8;

type
  TC2FileType = (ftNone, ftObjMesh, ftXMesh, ftPicture, ftWav, ftUVMap);

  TFResTools = class(TForm)
    GroupBox1: TGroupBox;
    ResMeshOpenDialog: TOpenDialog;
    LoadPicBut: TButton;
    ResOpenPictureDialog: TOpenPictureDialog;
    GroupBox2: TGroupBox;
    LoadUVBut: TButton;
    AddWavBut: TButton;
    AddMeshBut: TButton;
    ResExportSaveDialog: TSaveDialog;
    OnTopBut: TSpeedButton;
    ResWAVOpenDialog: TOpenDialog;
    ResUVOpenDialog: TOpenDialog;
    procedure AddMeshButClick(Sender: TObject);
    procedure LoadPicButClick(Sender: TObject);
    procedure LoadUVButClick(Sender: TObject);
    procedure AddWavButClick(Sender: TObject);
    procedure OnTopButClick(Sender: TObject);
  private
    function GetFileType(const AFileName: string): TC2FileType;
  public
    procedure LoadUVF(ParentNode: TItem; const FileName: string);
    procedure LoadObjFiles(ParentNode: TItem; AFiles: TStrings);
    procedure LoadXFiles(ParentNode: TItem; AFiles: TStrings);
    procedure LoadFiles(ParentNode: TItem; AFiles: TStrings);
  end;

var
  FResTools: TFResTools;

implementation

uses MainForm, FScale, FFormat, ModelLoadForm;

{$R *.dfm}

function TFResTools.GetFileType(const AFileName: string): TC2FileType;

  function IsPicture(LFileName: string): Boolean;
  var LCarrier: TResourceCarrier;
  begin
    LCarrier := ResourceLinker.GetLoader(GetResourceTypeID(LFileName));
    Result := Assigned(LCarrier) and LCarrier.GetResourceClass.InheritsFrom(TImageResource);
  end;

var Ext: string;
begin
  Ext := UpperCase(ExtractFileExt(AFileName));
  Result := ftNone;
  if Ext = '.OBJ' then Result := ftObjMesh
  else if Ext = '.X' then Result := ftXMesh
  else if Ext = '.WAV' then Result := ftWav
  else if Ext = '.UVF' then Result := ftUVMap
  else if IsPicture(AFileName) then Result := ftPicture;
end;

procedure TFResTools.OnTopButClick(Sender: TObject);
begin
  if OnTopBut.Down then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

// Loads one or more .obj files making them a child noted to ParentNode.
// If number of files is more than one them can be used as frames for animation (vertex morphing).
procedure TFResTools.LoadObjFiles(ParentNode: TItem; AFiles: TStrings);
var
  i: Integer;
  VRes: array of TVerticesResource;   // Vertex resources for models
  IRes: array of TIndicesResource;    // Index resources for models
  TRes: TImageResource;               // Texture resource
  Actor: TMesh;                       // Scene item in case of non-animated model
  AnimActor: TMorphedItem;            // Scene item in case of vertex morphing animated model
  Props: TProperties;                 // Properties
  Mat: TMaterial;                     // Material item
  Garbage: IRefcountedContainer;
  Animated: Boolean;
  SnapIndex: Integer;                 // Index of vertex to snap vertex morphing animated model to
  LStream: Basics.TStream;

  // Creates and sets up a default material with texture in TRes
  procedure AddMaterial;
  var Tech: TTechnique; Pass: TRenderPass;
  begin
    Pass := TRenderPass.Create(Core);             // First and only pass
    Tech := TTechnique.Create(Core);              // Default technique
    Mat  := TMaterial.Create(Core);               // Material itself

    Mat.Name := GetFileName(AFiles[0]);

    ParentNode.AddChild(Mat);                     // Add material to scene
    Mat.AddChild(Tech);                           // Also technique
    Tech.AddChild(Pass);                          // And pass

    // Set up technique properties
    Props.Clear;
    Props.Add('Total passes', vtInt,        [], '1',              '');
    Props.Add('Pass #0',      vtObjectLink, [], Pass.GetFullName, '');       // Add link to the pass
    Tech.SetProperties(Props);                                               // Apply properties

    // Set up material properties
    Props.Clear;
    Props.Add('Total techniques', vtInt,        [], '1',              '');
    Props.Add('Technique #0',     vtObjectLink, [], Tech.GetFullName, '');   // Add link to the technique
    Mat.SetProperties(Props);                                                // Apply properties

    // Set up pass properties
    Props.Add('Total stages',     vtNat,        [], '1',              '');
    if Assigned(TRes) then begin
      ParentNode.AddChild(TRes);
      Props.Add('Stage #0\Texture', vtObjectLink, [], TRes.GetFullName, ''); // Add link to texture
    end;
    Pass.SetProperties(Props);                                               // Apply properties
    Pass.State := Pass.State + [isVisible];                                  // Make the pass visible
  end;

const GeomPrefix = 'Geometry\Frame #%D ';       // Use in Format()


var LCarrier: TResourceCarrier; Stream: TStream;

begin
  Mat := nil;
  Props := TProperties.Create;

  // setup garbage collector
  Garbage := CreateRefcountedContainer;
  Garbage.AddObject(Props);

  Animated := False;
  case AFiles.Count of
    0: Exit;
    1: ;
    else if ModelLoadF.ShowModal = mrOK then begin                        // Let a user to choose if the model has animation
      Animated := ModelLoadF.PageControl1.ActivePageIndex = 1;
      if ModelLoadF.SnapCBox.Checked then
        SnapIndex := StrToIntDef(ModelLoadF.SnapIndexEdit.Text, -1)
      else
        SnapIndex := -1;
    end else Exit;
  end;

  // Create a scene item for a model with animation
  if Animated then begin
    AnimActor := TMorphedItem.Create(Core);
    AnimActor.Name := GetFileName(AFiles[0]);
    ParentNode.AddChild(AnimActor);
    AnimActor.TotalFrames := AFiles.Count;
  end;

  SetLength(VRes, AFiles.Count);
  SetLength(IRes, AFiles.Count);
  // For each file
  for i := 0 to AFiles.Count-1 do begin
    // Try to load model
    LStream := TFileStream.Create(AFiles[i]);
    Garbage.AddObject(LStream);
//    if not LoadObj(LStream, VRes[i], IRes[i], TRes) then begin
//       Log('Failed to load file "' + AFiles[i] + '"', lkError); 
//      Continue;
//    end;

    // Setup material
    if not Animated then
      AddMaterial
    else if not Assigned(Mat) then begin
      AddMaterial;
      if Assigned(Mat) then Props.Add('Material', vtObjectLink, [], Mat.GetFullName,  '');
    end;

    Actor := nil;
    if Assigned(VRes) then begin
      ParentNode.AddChild(VRes[i]);                       // Add resource containing vertices to scene

      if Animated then begin                              // Setup vertices and indices for animated models
        Props.Add(Format(GeomPrefix + 'vertices', [i]), vtObjectLink, [], VRes[i].GetFullName, '');
        if Assigned(IRes) then begin
          ParentNode.AddChild(IRes[i]);
          Props.Add(Format(GeomPrefix + 'indices', [i]),  vtObjectLink, [], IRes[i].GetFullName, '');
        end;
        if (SnapIndex >= 0) and (i > 0) then              // Snap model to the specified vertex
          ScaleForm.MoveVertices(VRes[i], SubVector3s(VRes[0].VertexCoords[SnapIndex], VRes[i].VertexCoords[SnapIndex]));
      end else begin                                      // Setup vertices and indices for non-animated models
        Props.Clear;
        Actor := TMesh.Create(Core);                      // Create a new scene item for model
        Actor.Name := GetFileName(AFiles[0]);
        ParentNode.AddChild(Actor);                       // Add to scene

        // Setup material property
        if Assigned(Mat) then Props.Add('Material', vtObjectLink, [], Mat.GetFullName,  '');
      end;

      // Setup vertex and index resources for model
      if not Animated or (i = 0) then begin
        Props.Add('Geometry\Vertices', vtObjectLink, [], VRes[i].GetFullName, '');
        if Assigned(IRes) then begin
          ParentNode.AddChild(IRes[i]);
          Props.Add('Geometry\Indices', vtObjectLink, [], IRes[i].GetFullName, '');
        end;
      end;

    end;
  end;

  // Apply properties to item
  if Animated then begin
    AnimActor.SetProperties(Props);
    AnimActor.SetFrames(0, 0, 0);
  end else
    Actor.SetProperties(Props);

  // Refresh items tree of CASTEd
  MainF.ItemsFrame1.RefreshTree;
  if Assigned(Actor) then MainF.ItemsFrame1.SelectItem(Actor, False);

  // Show up model manipulation tools
  ScaleForm.Show;
end;

procedure TFResTools.LoadXFiles(ParentNode: TItem; AFiles: TStrings);
var
  i, j: Integer;
  Actor: TItem;
  SnapIndex: Integer;
  SnapPoint: TVector3s;

  D3DDevice: IDirect3DDevice8;
  Skeleton: TAnimSkeleton;

const GeomPrefix = 'Geometry\Frame #%D ';       // Use in Format()

begin
  if Core.Renderer is TDX8Renderer then D3DDevice := TDX8Renderer(Core.Renderer).Direct3DDevice else D3DDevice := nil;

  if AFiles.Count <> 1 then Exit;

  for i := 0 to AFiles.Count-1 do begin
    Actor := LoadX(nil{D3DDevice}, Handle, AFiles[i], ParentNode);

    if not Assigned(Actor) then begin
      Log('Failed to load file "' + AFiles[i] + '"', lkError);
      Continue;
    end;
  end;

  MainF.ItemsFrame1.RefreshTree;
  if Assigned(Actor) then MainF.ItemsFrame1.SelectItem(Actor, False);

  ScaleForm.Show;
end;

procedure TFResTools.AddMeshButClick(Sender: TObject);
begin
  if ResMeshOpenDialog.Execute then LoadFiles(MainF.ItemsFrame1.GetFocusedParent, ResMeshOpenDialog.Files);
end;

procedure TFResTools.LoadPicButClick(Sender: TObject);
begin
  if ResOpenPictureDialog.Execute then
    LoadFiles(MainF.ItemsFrame1.GetFocusedParent, ResOpenPictureDialog.Files);
{  if ExtractFileExt(ResOpenPictureDialog.FileName) <> 'idf' then begin
    if FormatForm.ShowModal <> mrOK then Exit;
    if FormatForm.FormatBox.ItemIndex = 0 then
      Format := pfAuto else
        if FormatForm.FormatBox.ItemIndex < 21 then
          Format := FormatForm.FormatBox.ItemIndex else
            if FormatForm.FormatBox.ItemIndex <= pfD16-1 then
              Format := FormatForm.FormatBox.ItemIndex+1 else
                Format := pfB8G8R8;
  end else Format := pfAuto;}
end;

procedure TFResTools.LoadUVButClick(Sender: TObject);
begin
  if ResUVOpenDialog.Execute then LoadFiles(MainF.ItemsFrame1.GetFocusedParent, ResUVOpenDialog.Files);
end;

procedure TFResTools.AddWavButClick(Sender: TObject);
begin
  if ResWavOpenDialog.Execute then LoadFiles(MainF.ItemsFrame1.GetFocusedParent, ResWAVOpenDialog.Files);
end;

procedure TFResTools.LoadUVF(ParentNode: TItem; const FileName: string);
var f: file; TotalChars, ReadBytes: Integer; TempRes: TUVMapResource;
begin
  AssignFile(f, FileName); Reset(f, 1);
  BlockRead(f, TotalChars, SizeOf(TotalChars));
  TempRes := TUVMapResource.Create(Core);
  TempRes.Allocate(TotalChars * SizeOf(BaseTypes.TUV));
  BlockRead(f, TempRes.Data^, TotalChars * SizeOf(BaseTypes.TUV), ReadBytes);
  CloseFile(f);
  if ReadBytes <> TotalChars * SizeOf(BaseTypes.TUV) then begin
     Log('TFResTools.LoadUVButClick: Error loading UV map', lkError); 
    TempRes.Free;
    Exit;
  end;

  TempRes.Name := 'UVM_' + GetFileName(FileName);

  MainF.ItemsFrame1.GetFocusedParent.AddChild(TempRes);
end;

procedure TFResTools.LoadFiles(ParentNode: TItem; AFiles: TStrings);
var
  i: Integer; MeshObjFiles, MeshXFiles: TStrings; Garbage: IRefcountedContainer;
  LCarrier: TResourceCarrier; Stream: TStream;
  Item: TItem;
begin
  if not Assigned(AFiles) or (AFiles.Count = 0) then Exit;

  if ParentNode = nil then ParentNode := MainF.ItemsFrame1.GetFocusedParent;

  MeshObjFiles := TStringList.Create;
  MeshXFiles   := TStringList.Create;
  Garbage := CreateRefcountedContainer;
  Garbage.AddObject(MeshObjFiles);
  Garbage.AddObject(MeshXFiles);

  for i := 0 to AFiles.Count-1 do begin
    if GetFileType(AFiles[i]) = ftXMesh then
      MeshXFiles.Add(AFiles[i])
    else begin
      Item := nil;
      LCarrier := ResourceLinker.GetLoader(GetResourceTypeID(AFiles[i]));
      if Assigned(LCarrier) then begin
        Stream := GetResourceStream(AFiles[i], True);
        if Assigned(Stream) then begin
          LCarrier.Load(Stream, AFiles[i], Item);
          if Assigned(Item) then Item.Parent := ParentNode;
        end else
          Log(ClassName + '.LoadFiles: No appropriate stream class found for URL: "' + AFiles[i] + '"', lkWarning);
  {      ftNone: Log('Unknown type of file "' + AFiles[i] + '"', lkWarning);
        ftObjMesh: MeshObjFiles.Add(AFiles[i]);
        f
        ftPicture: ParentNode.AddChild(C2ResImport.LoadImage(AFiles[i]));
        ftWav:     ParentNode.AddChild(ImportWavResource(AFiles[i]));
        ftUVMap:   LoadUVF(MainF.ItemsFrame1.GetFocusedParent, AFiles[i]);}
      end else
        Log(ClassName + '.LoadFiles: No appropriate loader found for URL: "' + AFiles[i] + '"', lkWarning);
    end;
  end;

//  LoadObjFiles(ParentNode, MeshObjFiles);
  LoadXFiles(ParentNode, MeshXFiles);

  MainF.ItemsFrame1.RefreshTree;
  MainF.ItemsChanged := True;
end;

end.
