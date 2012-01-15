unit FMaterial;

interface

uses
  Logger, Props, C2Types, Basics, BaseStr, CAST2, C2Res, 
  BaseTypes, BaseClasses, Resources, Base2D, C2Materials,
  MapEditForm,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Buttons, StdCtrls, ExtCtrls, ComCtrls, ValEdit, Grids;

type
  // Contains an item to edit. Managed automatically so should not be freed automatically
  TAffectedItem = class
  private
    FClass: CItem;
  public
    Item: TItem;
    constructor Create(AClass: CItem);
    // Acquire an item from currently selected in object tree
    procedure Acquire;
  end;

  TFormNewMaterial = class(TForm)
    CBoxTechnique: TComboBox;
    Label4: TLabel;
    Label5: TLabel;
    CBoxPass: TComboBox;
    SButNewTech: TSpeedButton;
    SButDelTech: TSpeedButton;
    SButDelPass: TSpeedButton;
    SButNewPass: TSpeedButton;
    Timer1: TTimer;
    SButShow: TSpeedButton;
    cboxName: TComboBox;
    BtnCreate: TButton;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    Label2: TLabel;
    Label3: TLabel;
    Label6: TLabel;
    SButDelStage: TSpeedButton;
    SButNewStage: TSpeedButton;
    CBoxBlend: TComboBox;
    EditTextureName: TEdit;
    ScrollBox1: TScrollBox;
    Panel1: TPanel;
    CBoxStage: TComboBox;
    TabSheet2: TTabSheet;
    Label7: TLabel;
    CBoxVertexShader: TComboBox;
    Label8: TLabel;
    CBoxPixelShader: TComboBox;
    SButVSShow: TSpeedButton;
    SButPSShow: TSpeedButton;
    TabSheet3: TTabSheet;
    VListPShaderConst: TValueListEditor;
    VListVShaderConst: TValueListEditor;
    TabSheet4: TTabSheet;
    procedure SButShowClick(Sender: TObject);
    procedure SButVSShowClick(Sender: TObject);
    procedure SButPSShowClick(Sender: TObject);
    procedure WMMouseWheel(var Message: TWMMouseWheel); message CM_MOUSEWHEEL;
    procedure ScrollBox1MouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure EditNameChange(Sender: TObject);
    procedure TextureButtonClick(Index: Integer);
    procedure TextureButtonDblClick(Index: Integer);
    procedure TextureButtonMouseUp(Index: Integer);
    procedure CBoxTechniqueChange(Sender: TObject);
    procedure CBoxPassChange(Sender: TObject);
    procedure CBoxStageChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure VListPShaderConstValidate(Sender: TObject; ACol, ARow: Integer; const KeyName, KeyValue: string);
    procedure VListPShaderConstKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure VListVShaderConstKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure VListVShaderConstValidate(Sender: TObject; ACol, ARow: Integer; const KeyName, KeyValue: string);
    procedure VListVShaderConstGetPickList(Sender: TObject; const KeyName: String; Values: TStrings);
  published
    Label1: TLabel;
    OnTopBut: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OnTopButClick(Sender: TObject);

    procedure BtnCreateClick(Sender: TObject);

    procedure UpdateForm;
  private
    LastTotalImageResource: Integer;
    AffectedItem: TAffectedItem;
    ConstantsList: TStringList;
    procedure ShadersToForm(APass: TRenderPass);
    procedure FormToShaders(APass: TRenderPass; AProps: TProperties);
    procedure SetMatName(const AName: AnsiString);
    procedure PreparePassProps(Props: TProperties);
  public
    TexPanel: TButtonsPanel;
    procedure HandleItemSelect(Item: TItem);
    procedure RefreshTextures;
  end;

var
  FormNewMaterial: TFormNewMaterial;

implementation

uses mainform, C2EdMain, VCLHelper;

{ TItemEdit }

constructor TAffectedItem.Create(AClass: CItem);
begin
  FClass := AClass;
  // ToDo: add self to a global collection
end;

procedure TAffectedItem.Acquire;
begin
  if MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) is FClass then
    Item := MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode);
end;

const btOpaque = 0; btAlphaTest = 1; btAlphaBlend = 2; btAdditiveBlend = 3; btCustom = 4;

{$R *.dfm}

var IsHandlingMWheel: Boolean = False;

procedure TFormNewMaterial.SButShowClick(Sender: TObject);
begin
  MainF.SelectItem(cboxName.Text);
end;

procedure TFormNewMaterial.SButVSShowClick(Sender: TObject);
begin
  MainF.SelectItem(CBoxVertexShader.Text);
end;

procedure TFormNewMaterial.SButPSShowClick(Sender: TObject);
begin
  MainF.SelectItem(CBoxPixelShader.Text);
end;

procedure TFormNewMaterial.WMMouseWheel(var Message: TWMMouseWheel);
var MousePos: TPoint; LControl: TControl;
begin
  if IsHandlingMWheel then Exit;
  IsHandlingMWheel := True;
  GetCursorPos(MousePos);
  MousePos := ScreenToClient(MousePos);
  LControl := ControlAtPos(MousePos, false, true);
  if LControl = nil then LControl := MainF;
  LControl.Perform(Message.Msg, Message.WheelDelta*65536, Message.YPos*65536+Message.XPos);
  IsHandlingMWheel := False;
end;

procedure TFormNewMaterial.ScrollBox1MouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
const WindowsStupidConstant = 120;
begin
  ScrollBox1.VertScrollBar.Position := ScrollBox1.VertScrollBar.Position - (WheelDelta*ScrollBox1.VertScrollBar.Increment div WindowsStupidConstant);
  Handled := True;
end;

procedure TFormNewMaterial.FormCreate(Sender: TObject);
begin
  ConstantsList := TStringList.Create;
  TexPanel := TButtonsPanel.Create(Panel1);
  TexPanel.ThumbSize  := 64;

  TexPanel.OnButClick    := TextureButtonClick;
  TexPanel.OnButDblClick := TextureButtonDblClick;
  TexPanel.OnMouseUp     := TextureButtonMouseUp;

  AffectedItem := TAffectedItem.Create(TMaterial);
end;

procedure TFormNewMaterial.FormDestroy(Sender: TObject);
begin
  FreeAndNil(AffectedItem);
  FreeAndNil(TexPanel);
  FreeAndNil(ConstantsList);
end;

procedure TFormNewMaterial.HandleItemSelect(Item: TItem);
var Str: AnsiString;
begin
  if (Item is TImageResource) or (Item is TCamera) then
    EditTextureName.Text := Item.GetFullName
  else if Item is TMaterial then
    SetMatName(Item.GetFullName)
  else if (Item is TTechnique) and (Item.Parent is TMaterial) then
    SetMatName(Item.Parent.GetFullName)
  else if (Item is TRenderPass) and (Item.Parent is TTechnique) and (Item.Parent.Parent is TMaterial) then
    SetMatName(Item.Parent.Parent.GetFullName)
  else begin
    if Assigned(Item) then begin
      Str := Item.GetProperty('Material');
      Item := Item.GetItemByPath(Str);
      if Item is TMaterial then
        SetMatName(Item.GetFullName);
    end;
  end;
end;

procedure TFormNewMaterial.OnTopButClick(Sender: TObject);
begin
  if OnTopBut.Down then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TFormNewMaterial.BtnCreateClick(Sender: TObject);
var Props: TProperties;

  function ObtainTechnique(Mat: TMaterial; const AName: AnsiString): TTechnique;
  var i, TotalTech: Integer;
  begin
    i := Mat.TotalTechniques-1;
    while (i >= 0) and (not Assigned(Mat.Technique[i]) or (Mat.Technique[i].Name <> AName)) do Dec(i);
    if i >= 0 then
      Result := Mat.Technique[i]
    else begin
      TotalTech := Mat.TotalTechniques;
      Result := TTechnique.Create(Core);
      if AName <> '' then Result.Name := AName;
      Mat.AddChild(Result);
      Props.Clear;
      Props.Add('Total techniques',                  vtInt,        [], IntToStr(TotalTech+1), '');
      Props.Add('Technique #' + IntToStr(TotalTech), vtObjectLink, [], Result.Name,           '');
      Mat.SetProperties(Props);
    end;
  end;

  function ObtainPass(Tech: TTechnique; const AName: AnsiString): TRenderPass;
  var i, TotalPasses: Integer;
  begin
    i := Tech.TotalPasses-1;
    while (i >= 0) and (Tech.Passes[i].Name <> AName) do Dec(i);
    if i >= 0 then
      Result := Tech.Passes[i]
    else begin
      TotalPasses := Tech.TotalPasses;
      Result := TRenderPass.Create(Core);
      if AName <> '' then Result.Name := AName;
      Tech.AddChild(Result);
      Props.Clear;
      Props.Add('Total passes',                     vtInt,      [], IntToStr(TotalPasses+1),       '');
      Props.Add('Pass #' + IntToStr(TotalPasses), vtObjectLink, [], Result.Name,                   '');
      Tech.SetProperties(Props);
    end;
  end;

var
  Tech: TTechnique; Pass: TRenderPass; Mat: TMaterial; LName: AnsiString;
  ParentNode: TItem; Garbage: IRefcountedContainer;

begin
  Garbage := CreateRefcountedContainer;
  Props := TProperties.Create;
  Garbage.AddObject(Props);

  ParentNode := Core.Root.GetItemByFullName('\'+CBoxName.Text);
  if Assigned(ParentNode) and not (ParentNode is TMaterial) then begin
    Log(Format('Item %s of class "%s" is not a material', [CBoxName.Text, ParentNode.ClassName]), lkError);
    Exit;
  end;

  if Assigned(ParentNode) then
    Mat := ParentNode as TMaterial
  else
    Mat := TMaterial.Create(Core);

  App.ObtainNewItemData(CBoxName.Text, LName, ParentNode);
  if not Assigned(ParentNode) then ParentNode := Core.Root;
  
  Mat.Name := LName;
  if Mat.Parent = nil then Mat.Parent := ParentNode;

  Tech := ObtainTechnique(Mat, CBoxTechnique.Text);

  Pass := ObtainPass(Tech, CBoxPass.Text);

  Props.Clear;
  Pass.AddProperties(Props);
  PreparePassProps(Props);

  FormToShaders(Pass, Props);

  Pass.SetProperties(Props);
  Pass.State := Pass.State + [isVisible];

  MainF.ItemsChanged := True;
  MainF.ItemsFrame1.RefreshTree;
end;

procedure TFormNewMaterial.RefreshTextures;
var i: Integer; Image: TItem;
begin
  TexPanel.TotalButtons := App.ItemsList.TotalItems[TImageResource];
  for i := 0 to App.ItemsList.TotalItems[TImageResource] - 1 do begin
    Image := App.ItemsList.Item[TImageResource, i];
    if Image is TImageResource then begin
      TexPanel.SetThumbnailFromImage(i, TImageResource(Image), nil, 0);
      TexPanel.SetText(i, '', Format('%s'#10#13'Image: %dx%d, %s',
                            [Image.GetFullName,
                             TImageResource(Image).Width, TImageResource(Image).Height,
                             PixelFormatToStr(TImageResource(Image).Format)]));
    end;
  end;
  ScrollBox1.AutoScroll := True;
  Invalidate;
  ScrollBox1.Invalidate;
  Refresh;
  ScrollBox1.Refresh;
end;

procedure TFormNewMaterial.EditNameChange(Sender: TObject);
begin
//  if not (AffectedItem.Item is TMaterial) then Exit;
  if Core.Root.GetItemByFullName(CBoxName.Text) is TMaterial then begin
    AffectedItem.Item := Core.Root.GetItemByFullName(CBoxName.Text);
    BtnCreate.Caption := 'Modify';
    UpdateForm;
  end else
    BtnCreate.Caption := 'Create'
end;

procedure TFormNewMaterial.TextureButtonClick(Index: Integer);
begin
  if (Index >= 0) and (Index < App.ItemsList.TotalItems[TImageResource]) then
    if Assigned(App.ItemsList.Item[TImageResource, Index]) then
      EditTextureName.Text := App.ItemsList.Item[TImageResource, Index].GetFullName;
end;

procedure TFormNewMaterial.TextureButtonDblClick(Index: Integer);
begin
  App.ActDefault(App.ItemsList.Item[TImageResource, Index], nil);
end;

procedure TFormNewMaterial.TextureButtonMouseUp(Index: Integer);
begin
  MainF.SelectItem(App.ItemsList.Name[TImageResource, Index]);
end;

procedure TFormNewMaterial.Timer1Timer(Sender: TObject);
begin
  if Assigned(App) then begin
    if CBoxName.Items.Count <> App.ItemsList.TotalItems[TMaterial] then
      CBoxName.Items.Assign(App.ItemsList.AsTStrings[TMaterial]);

    if CBoxVertexShader.Items.Count <> App.ItemsList.TotalItems[TShaderResource] then begin
      CBoxVertexShader.Items.Assign(App.ItemsList.AsTStrings[TShaderResource]);
      CBoxPixelShader.Items.Assign(CBoxVertexShader.Items);
    end;  

    if LastTotalImageResource <> App.ItemsList.TotalItems[TImageResource] then RefreshTextures;
    LastTotalImageResource := App.ItemsList.TotalItems[TImageResource];
  end;
end;

procedure TFormNewMaterial.CBoxTechniqueChange(Sender: TObject);
var i: Integer; Tech: TTechnique;
begin
  if AffectedItem.Item is TMaterial then begin
    if (CBoxTechnique.ItemIndex >= 0) and (CBoxTechnique.ItemIndex < TMaterial(AffectedItem.Item).TotalTechniques) then begin
      Tech := TMaterial(AffectedItem.Item).Technique[CBoxTechnique.ItemIndex];
      CBoxPass.Clear;
      if Assigned(Tech) then begin
        for i := 0 to Tech.TotalPasses-1 do
          if Assigned(Tech.Passes[i]) then
            CBoxPass.Items.Add(Tech.Passes[i].Name)
          else
            CBoxPass.Items.Add('<undefined>');
        CBoxPass.ItemIndex := 0;
        CBoxPassChange(CBoxPass);
      end;
    end;
  end;
end;

procedure TFormNewMaterial.CBoxPassChange(Sender: TObject);
var i: Integer; Tech: TTechnique; Pass: TRenderPass;
begin
  if AffectedItem.Item is TMaterial then begin
    if (CBoxTechnique.ItemIndex >= 0) and (CBoxTechnique.ItemIndex < TMaterial(AffectedItem.Item).TotalTechniques) then begin
      Tech := TMaterial(AffectedItem.Item).Technique[CBoxTechnique.ItemIndex];
      if Assigned(Tech) and (CBoxPass.ItemIndex >= 0) and (CBoxPass.ItemIndex < Tech.TotalPasses) then begin
        Pass := Tech.Passes[CBoxPass.ItemIndex];

        CBoxStage.Clear;
        if Assigned(Pass) then begin
          if Pass.BlendingState.Enabled then begin
            if (Pass.BlendingState.SrcBlend = bmSRCALPHA) and (Pass.BlendingState.DestBlend = bmONE) then
              CBoxBlend.ItemIndex := btAdditiveBlend
            else
              CBoxBlend.ItemIndex := btAlphaBlend
          end else if Pass.BlendingState.ATestFunc = tfGREATER then
            CBoxBlend.ItemIndex := btAlphaTest
          else
            CBoxBlend.ItemIndex := btOpaque;

          for i := 0 to Pass.TotalStages-1 do CBoxStage.Items.Add(Format('Stage #%D', [i]));

          CBoxStage.ItemIndex := 0;
        end;
        CBoxStageChange(CBoxStage);
        ShadersToForm(Pass);
      end;
    end;    
  end;
end;

procedure TFormNewMaterial.CBoxStageChange(Sender: TObject);
var Tech: TTechnique; Pass: TRenderPass; Texture: Resources.TImageResource;
begin
  if AffectedItem.Item is TMaterial then begin
    if (CBoxTechnique.ItemIndex >= 0) and (CBoxTechnique.ItemIndex < TMaterial(AffectedItem.Item).TotalTechniques) then begin
      Tech := TMaterial(AffectedItem.Item).Technique[CBoxTechnique.ItemIndex];
      if Assigned(Tech) and (CBoxPass.ItemIndex >= 0) and (CBoxPass.ItemIndex < Tech.TotalPasses) then begin
        Pass := Tech.Passes[CBoxPass.ItemIndex];

        Texture := nil;
        Pass.ResolveTexture(CBoxStage.ItemIndex, Texture);

        if (CBoxStage.ItemIndex >= 0) and Assigned(Texture) then
          EditTextureName.Text := Texture.GetFullName
        else
          EditTextureName.Text := '';
      end;
    end;
  end;
end;

procedure TFormNewMaterial.ShadersToForm(APass: TRenderPass);
var i: Integer; Shader: TShaderResource;
begin
  if not Assigned(APass) then Exit;

  if (CBoxTechnique.ItemIndex >= 0) and (CBoxTechnique.ItemIndex < TMaterial(AffectedItem.Item).TotalTechniques) then begin
    Shader := nil;
    APass.ResolveVertexShader(Shader);
    if Assigned(Shader) then CBoxVertexShader.Text := Shader.GetFullName;

    Shader := nil;
    APass.ResolvePixelShader(Shader);
    if Assigned(Shader) then CBoxPixelShader.Text := Shader.GetFullName;
  end;

  SplitToTStrings(Core.ConstantsEnum, StringDelimiter, ConstantsList, False, False);

  VListVShaderConst.Strings.Clear;
  for i := 0 to APass.TotalVertexShaderConstants - 1 do begin
    VListVShaderConst.InsertRow(IntToStr(i), APass.VertexShaderConstant[i], True);
    VListVShaderConst.ItemProps[i].EditStyle := esPickList;
    VListVShaderConst.ItemProps[i].PickList := ConstantsList;
  end;
  VListPShaderConst.Strings.Clear;
  for i := 0 to APass.TotalPixelShaderConstants - 1 do begin
    VListPShaderConst.InsertRow(IntToStr(i), APass.PixelShaderConstant[i], True);
    VListPShaderConst.ItemProps[i].EditStyle := esPickList;
    VListPShaderConst.ItemProps[i].PickList := ConstantsList;
  end;
end;

procedure TFormNewMaterial.FormToShaders(APass: TRenderPass; AProps: TProperties);
var i: Integer;
begin
  if not Assigned(APass) then Exit;
{  Result.Add('Shaders\Vertex\Declaration\Total streams', vtInt, [], IntToStr(FTotalVertexStreams), '');
    for j := 0 to FTotalVertexStreams-1 do begin
      LevelStr := 'Shaders\Vertex\Declaration\Stream #' + IntToStr(j) + '\';
      Result.Add(LevelStr + 'Total elements', vtInt, [], IntToStr(FStream0Elements), '');
      for k := 0 to FStream0Elements-1 do Result.AddEnumerated(LevelStr + '#' + IntToStr(k) + 'Data type', [], Ord(VertexDeclaration[k]), VertexDataTypesEnum);
    end;    
  end;
}
  AProps.Add('Shaders\Vertex\Total constants', vtInt, [], IntToStr(VListVShaderConst.RowCount-1), '');
  AProps.Add('Shaders\Pixel\Total constants',  vtInt, [], IntToStr(VListPShaderConst.RowCount-1), '');

  for i := 0 to VListVShaderConst.RowCount-2 do
    AProps.Add('Shaders\Vertex\Constants\#' + IntToStr(i), vtString, [], VListVShaderConst.Cells[1, i+1], '');

  for i := 0 to VListPShaderConst.RowCount-2 do
    AProps.Add('Shaders\Pixel\Constants\#'  + IntToStr(i), vtString, [], VListPShaderConst.Cells[1, i+1], '');

  AProps.Add('Shaders\Vertex', vtObjectLink, [], CBoxVertexShader.Text, '');
  AProps.Add('Shaders\Pixel',  vtObjectLink, [], CBoxPixelShader.Text,  '');
end;

procedure TFormNewMaterial.UpdateForm;
var i: Integer; Mat: TMaterial;
begin
  if AffectedItem.Item is TMaterial then begin
    SetMatName(AffectedItem.Item.GetFullName);
    Mat := TMaterial(AffectedItem.Item);
    CBoxTechnique.Clear;
    for i := 0 to Mat.TotalTechniques-1 do
      if Assigned(Mat.Technique[i]) then
        CBoxTechnique.Items.Add(Mat.Technique[i].Name);
    CBoxPass.Text := 'Select a technique';
    CBoxTechnique.ItemIndex := 0;
    CBoxTechniqueChange(CBoxTechnique);
    BtnCreate.Caption := 'Modify';
  end;
end;

function IsLastLineEmpty(List: TValueListEditor): Boolean;
begin
  Result := Assigned(List) and (List.Cells[1, List.RowCount-1] = '');
end;

procedure TFormNewMaterial.VListPShaderConstKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ((Key = VK_DOWN) or (Key = VK_RETURN)) and
      (VListPShaderConst.Row = VListPShaderConst.RowCount-1) then begin
    VListPShaderConst.InsertRow('', '', True);
    VListPShaderConstValidate(Sender, VListPShaderConst.Col, VListPShaderConst.Row, '', '');
  end;
end;

procedure TFormNewMaterial.VListPShaderConstValidate(Sender: TObject; ACol, ARow: Integer; const KeyName, KeyValue: string);
begin
  if VListPShaderConst.Cells[1, ARow] <> '' then VListPShaderConst.Keys[ARow] := IntToStr(ARow-1);
end;

procedure TFormNewMaterial.VListVShaderConstKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ((Key = VK_DOWN) or (Key = VK_RETURN)) and
      (VListVShaderConst.Row = VListVShaderConst.RowCount-1) then begin
    VListVShaderConst.InsertRow('', '', True);
    VListVShaderConstValidate(Sender, VListVShaderConst.Col, VListVShaderConst.Row, '', '');
  end;
end;

procedure TFormNewMaterial.VListVShaderConstValidate(Sender: TObject; ACol, ARow: Integer; const KeyName, KeyValue: string);
begin
  if VListVShaderConst.Cells[1, ARow] <> '' then VListVShaderConst.Keys[ARow] := IntToStr(ARow-1);
end;

procedure TFormNewMaterial.FormShow(Sender: TObject);
begin
  RefreshTextures;
end;

procedure TFormNewMaterial.SetMatName(const AName: AnsiString);
begin
//  CBoxName.ItemIndex := CBoxName.Items.IndexOf(AName);
  if CBoxName.Text <> AName then begin
    CBoxName.Text := AName;
    EditNameChange(CBoxName);
  end;
end;

procedure TFormNewMaterial.PreparePassProps(Props: TProperties);
var Pass: TRenderPass; Garbage: IRefcountedContainer; PassOpt: TPassOptions;
begin
  Garbage := CreateRefcountedContainer;

  Pass := TRenderPass.Create(Core);
  Garbage.AddObject(Pass);

  Pass.TotalStages := 1;

  Pass.SetProperties(Props);

  PassOpt := [];

  if (Pass.BlendingState.ATestFunc <> tfALWAYS) or (CBoxBlend.ItemIndex = btAlphaTest) then Include(PassOpt, poAlphaTest);
  if (Pass.ZBufferState.ZTestFunc  <> tfALWAYS) then Include(PassOpt, poZTest);
  if Pass.LightingState.Enabled then Include(PassOpt, poLighting);
  if Pass.FogKind <> fkNONE then Include(PassOpt, poFog);

  ModifyPass(Pass, TPassBlending(CBoxBlend.ItemIndex), PassOpt);

//  Props.Add('Total stages',     vtNat,        [], '1',              '');

  case CBoxBlend.ItemIndex of
    btOpaque: begin
      Pass.BlendingState := GetBlendingState(False, bmONE, bmZERO, Pass.BlendingState.AlphaRef, Pass.BlendingState.ATestFunc, Pass.BlendingState.Operation);
      Pass.ZBufferState  := GetZBufferState(True, tfLESSEQUAL, 0);
      Pass.Order := poNormal;
    end;
    btAlphaTest: begin
      Pass.BlendingState := GetBlendingState(Pass.BlendingState.Enabled, Pass.BlendingState.SrcBlend, Pass.BlendingState.DestBlend, Pass.BlendingState.AlphaRef, tfGREATER, Pass.BlendingState.Operation);
    end;
    btAlphaBlend: begin
      Pass.BlendingState := GetBlendingState(True, bmSRCALPHA, bmInvSRCALPHA, Pass.BlendingState.AlphaRef, Pass.BlendingState.ATestFunc, Pass.BlendingState.Operation);
      Pass.ZBufferState  := GetZBufferState(False, tfLESSEQUAL, 0);
      Pass.Order := poSorted;
    end;
    btAdditiveBlend: begin
      Pass.BlendingState := GetBlendingState(True, bmSRCALPHA, bmONE, Pass.BlendingState.AlphaRef, Pass.BlendingState.ATestFunc, Pass.BlendingState.Operation);
      Pass.ZBufferState  := GetZBufferState(False, tfLESSEQUAL, 0);
      Pass.Order := poSorted;
    end;  
    btCustom: ;
    else Assert(False);
  end;

  Pass.AddProperties(Props);

  Props.Add('Stage #' + IntToStr(CBoxStage.ItemIndex) + '\Texture', vtObjectLink, [], EditTextureName.Text, '');
end;

procedure TFormNewMaterial.VListVShaderConstGetPickList(Sender: TObject; const KeyName: String; Values: TStrings);
begin
//  SplitToTStrings(Core.ConstantsEnum, StringDelimiter, Values, False, False);
end;

end.
