{$I GDefines.inc}
unit FUVGen;

interface

uses
   Logger, 
  BaseTypes, Basics, C2Types, Resources, C2Res, BaseClasses,
  ObjFrame,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Grids, ExtCtrls,
  Buttons, ComCtrls;

type
  TUVForm = class(TForm)
    NameEdit: TEdit;
    Label5: TLabel;
    ApplyBut: TButton;
    ImgWidthEdit: TEdit;
    ImgHeightEdit: TEdit;
    Label7: TLabel;
    UVGrid: TStringGrid;
    Panel1: TPanel;
    WidthEdit: TEdit;
    HeightEdit: TEdit;
    UOfsEdit: TEdit;
    VOfsEdit: TEdit;
    Label3: TLabel;
    FramesEdit: TEdit;
    Label1: TLabel;
    VerticalCBox: TCheckBox;
    AddBut: TButton;
    Panel2: TPanel;
    RemoveBut: TButton;
    ShowBut: TButton;
    RefreshBut: TButton;
    EndKindCBox: TComboBox;
    SaveBut: TButton;
    LoadBut: TButton;
    UVOpenDialog: TOpenDialog;
    UVSaveDialog: TSaveDialog;
    UParEdit: TEdit;
    VParEdit: TEdit;
    ModBut: TButton;
    OpTypeCBox: TComboBox;
    OnTopBut: TSpeedButton;
    AddSelBut: TButton;
    ObjUpDown: TUpDown;
    procedure FormCreate(Sender: TObject);
    procedure RefreshGrid;
    procedure AddButClick(Sender: TObject);
    procedure RemoveButClick(Sender: TObject);
    procedure UOfsEditChange(Sender: TObject);
    procedure ShowUV(UVMap: BaseTypes.TUVMap; Count: Integer);
    procedure ShowButClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ImgWidthEditChange(Sender: TObject);
    procedure RefreshButClick(Sender: TObject);
    procedure LoadUV(const fn: string);
    procedure SaveUV(const fn: string);
    procedure SaveButClick(Sender: TObject);
    procedure LoadButClick(Sender: TObject);
    procedure UParEditChange(Sender: TObject);
    procedure ModButClick(Sender: TObject);
    procedure OnTopButClick(Sender: TObject);
    procedure ApplyButClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure AddSelButClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ObjUpDownChangingEx(Sender: TObject; var AllowChange: Boolean; NewValue: Smallint; Direction: TUpDownDirection);
    procedure UVGridClick(Sender: TObject);
  public
    TotalCoords: Integer;
    Coords: BaseTypes.TUVMap;
  end;

var
  UVForm: TUVForm;

implementation

uses FImages, EditWin, MainForm, C2EdMain;

{$R *.dfm}

procedure TUVForm.FormCreate(Sender: TObject);
begin
  UVGrid.Cells[0, 0] := '#'; UVGrid.Cells[1, 0] := 'U'; UVGrid.Cells[2, 0] := 'V'; UVGrid.Cells[3, 0] := 'W'; UVGrid.Cells[4, 0] := 'H';
  Coords := nil; TotalCoords := 0;
end;

procedure TUVForm.RefreshGrid;
var i: Integer;
begin
  UVGrid.RowCount := MaxI(2, TotalCoords+1);
  UVGrid.Cells[0, 1] := ''; UVGrid.Cells[1, 1] := ''; UVGrid.Cells[2, 1] := ''; UVGrid.Cells[3, 1] := ''; UVGrid.Cells[4, 1] := '';
  for i := 0 to TotalCoords - 1 do begin
    UVGrid.Cells[0, i+1] := Format('%3.3D', [i]);
    UVGrid.Cells[1, i+1] := Format('%4.4F', [Coords[i].U * StrToIntDef(ImgWidthEdit.Text, 256)]);
    UVGrid.Cells[2, i+1] := Format('%4.4F', [Coords[i].V * StrToIntDef(ImgHeightEdit.Text, 256)]);
    UVGrid.Cells[3, i+1] := Format('%4.4F', [Coords[i].W * StrToIntDef(ImgWidthEdit.Text, 256)]);
    UVGrid.Cells[4, i+1] := Format('%4.4F', [Coords[i].H * StrToIntDef(ImgHeightEdit.Text, 256)]);
{    Coords[i].U := i mod Columns * w / Width;
    Coords[i].V := i div Columns * h / Height;
    Coords[i].W := w / Width;
    Coords[i].H := h / Height;}
  end;
end;

procedure TUVForm.AddButClick(Sender: TObject);
var i, Frames, OfsU, OfsV, Width, Height, w, h, CoordsOfs: Integer;
  CurU, CurV, StepU, StepV: Single;
begin
  Frames := StrToIntDef(FramesEdit.Text, 0); if Frames = 0 then Exit;
  Width := StrToIntDef(ImgWidthEdit.Text, 256);
  Height := StrToIntDef(ImgHeightEdit.Text, 256);

  if (Width = 0) or (Height = 0) then Exit;

  OfsU := StrToIntDef(UOfsEdit.Text, 0);
  OfsV := StrToIntDef(VOfsEdit.Text, 0);
  if EndKindCBox.ItemIndex = 0 then begin
    w := StrToIntDef(WidthEdit.Text, 128);
    h := StrToIntDef(HeightEdit.Text, 128);
  end else begin
    w := StrToIntDef(WidthEdit.Text, 128) - OfsU;
    h := StrToIntDef(HeightEdit.Text, 128) - OfsV;
  end;

  StepU := StrToIntDef(UParEdit.Text, 1);
  StepV := StrToIntDef(VParEdit.Text, 1);

  CoordsOfs := TotalCoords;
  Inc(TotalCoords, Frames); ReallocMem(Coords, TotalCoords * SizeOf(TUV));

  CurU := OfsU / Width; CurV := OfsV / Height;

  for i := 0 to Frames - 1 do begin
    Coords[CoordsOfs + i].U := CurU;
    Coords[CoordsOfs + i].V := CurV;
    if not VerticalCBox.Checked then
     CurU := CurU + (w + StepU) / Width else
      CurV := CurV + (h + StepV) / Height;
    Coords[CoordsOfs + i].W := w / Width;
    Coords[CoordsOfs + i].H := h / Height;
  end;

  if not VerticalCBox.Checked then
   UOfsEdit.Text := IntToStr(Trunc(0.5 + CurU * Width)) else
    VOfsEdit.Text := IntToStr(Trunc(0.5 + CurV * Height));

  RefreshGrid;
  AddBut.Default := False;
  ApplyBut.Default := True;
end;

procedure TUVForm.RemoveButClick(Sender: TObject);
var i: Integer;
begin
  if TotalCoords = 0 then Exit;
  for i := UVGrid.Selection.Bottom to TotalCoords-1 do Coords[i - UVGrid.Selection.Bottom + UVGrid.Selection.Top - 1] := Coords[i];
  Dec(TotalCoords, UVGrid.Selection.Bottom - UVGrid.Selection.Top + 1); ReallocMem(Coords, TotalCoords * SizeOf(TUV));
  RefreshGrid;
end;

procedure TUVForm.UOfsEditChange(Sender: TObject);
begin
  AddBut.Default := True;
  ShowBut.Default := False;
  RefreshBut.Default := False;
  ApplyBut.Default := False;
  ModBut.Default := False;
end;

procedure TUVForm.ImgWidthEditChange(Sender: TObject);
begin
  RefreshBut.Default := True;
  AddBut.Default := False;
  ShowBut.Default := False;
  ApplyBut.Default := False;
  ModBut.Default := False;
end;

procedure TUVForm.UParEditChange(Sender: TObject);
begin
  ApplyBut.Default := True;
  RefreshBut.Default := False;
  AddBut.Default := False;
  ShowBut.Default := False;
  ApplyBut.Default := False;
end;

procedure TUVForm.ShowUV(UVMap: BaseTypes.TUVMap; Count: Integer);
var i: Integer;
begin
  if (ImagesForm.ImageList.ItemIndex >= 0) and (ImagesForm.ImageList.ItemIndex <= High(ImageForm)) then with ImageForm[ImagesForm.ImageList.ItemIndex] do begin
    Redraw;
    for i := 0 to Count-1 do if (i+1 >= UVGrid.Selection.Top) and (i+1 <= UVGrid.Selection.Bottom) then begin
      Image1.Canvas.Brush.Color := $FFFFFF;
      Image1.Canvas.Brush.Style := Graphics.bsSolid;
      Image1.Canvas.FrameRect(Rect(Trunc(0.5+UVMap[i].U*ImageWidth), Trunc(0.5+UVMap[i].V*ImageHeight),
                                   Trunc(0.5+(UVMap[i].U+UVMap[i].W)*ImageWidth), Trunc(0.5+(UVMap[i].V+UVMap[i].H)*ImageHeight)));
    end;
  end else Log('Please select an image window to show the UV map on', lkError);
end;

procedure TUVForm.ShowButClick(Sender: TObject);
begin
  ShowUV(Coords, TotalCoords);
end;

procedure TUVForm.FormShow(Sender: TObject);
begin
  RefreshGrid;
end;

procedure TUVForm.RefreshButClick(Sender: TObject);
begin
  RefreshGrid;
end;

procedure TUVForm.SaveUV(const fn: string);
var f: file;
begin
  AssignFile(f, fn); Rewrite(f, 1);
  BlockWrite(f, TotalCoords, SizeOf(TotalCoords));
  BlockWrite(f, Coords[0], TotalCoords * SizeOf(TUV));
  CloseFile(f);
end;

procedure TUVForm.LoadUV(const fn: string);
var NewCoords: BaseTypes.TUVMap; NewTotalCoords, ReadBytes, i: Integer; f: file;
begin
  AssignFile(f, fn); Reset(f, 1);
  BlockRead(f, NewTotalCoords, SizeOf(NewTotalCoords));
  GetMem(NewCoords, NewTotalCoords * SizeOf(TUV));
  BlockRead(f, NewCoords[0], NewTotalCoords * SizeOf(TUV), ReadBytes);
  CloseFile(f);
  if ReadBytes <> NewTotalCoords * SizeOf(TUV) then begin
    MessageDlg('Can''t load UVMap resource', mtError, [mbOK], 0);
    Exit;
  end;

  ReallocMem(Coords, (TotalCoords + NewTotalCoords) * SizeOf(TUV));
  for i := 0 to NewTotalCoords-1 do Coords[TotalCoords + i] := NewCoords[i];
  Inc(TotalCoords, NewTotalCoords);

  FreeMem(NewCoords);

  RefreshGrid;
end;

procedure TUVForm.SaveButClick(Sender: TObject);
begin
  if UVSaveDialog.Execute then SaveUV(UVSaveDialog.FileName);
end;

procedure TUVForm.LoadButClick(Sender: TObject);
begin
  if UVOpenDialog.Execute then LoadUV(UVOpenDialog.FileName);
end;

procedure TUVForm.ModButClick(Sender: TObject);
var i, Width, Height: Integer;
begin
  Width := StrToIntDef(ImgWidthEdit.Text, 256);
  Height := StrToIntDef(ImgHeightEdit.Text, 256);
  if (Width = 0) or (Height = 0) then Exit;
  for i := UVGrid.Selection.Top-1 to UVGrid.Selection.Bottom-1 do begin
    case OpTypeCBox.ItemIndex of
      0: begin
        Coords[i].U := Coords[i].U + StrToIntDef(UParEdit.Text, 0) / Width;
        Coords[i].V := Coords[i].V + StrToIntDef(VParEdit.Text, 0) / Height;
      end;
      1: begin
        Coords[i].W := Coords[i].W + StrToIntDef(UParEdit.Text, 0) / Width;
        Coords[i].H := Coords[i].H + StrToIntDef(VParEdit.Text, 0) / Height;
      end;
    end;
  end;
  RefreshGrid;
end;

procedure TUVForm.OnTopButClick(Sender: TObject);
begin
  if OnTopBut.Down then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TUVForm.ApplyButClick(Sender: TObject);
var Item, Parent: TItem; TempRes: TUVMapResource; HDelimPos: Integer; LName: AnsiString;
begin
  Item := Core.Root.GetItemByFullName('\'+NameEdit.Text);
  if Assigned(Item) and not (Item is TUVMapResource) then begin
     Log(Format('Item %S is not a TUVMapResource', [NameEdit.Text]), lkError);  ;
    Exit;
  end;
  if Item = nil then begin            // New resource
    Item := TUVMapResource.Create(Core);

    App.ObtainNewItemData(NameEdit.Text, LName, Parent);
    Item.Name := LName;
    Item.Parent := Parent;
  end;
  if Item is TUVMapResource then begin        // Existing resource
    TempRes := Item as TUVMapResource;
    TempRes.Allocate(TotalCoords * SizeOf(TUV));
    Move(Coords[0], TempRes.Data^, TotalCoords * SizeOf(TUV));
  end;
  MainF.ItemsChanged := True;
  MainF.ItemsFrame1.RefreshTree;
end;

procedure TUVForm.FormActivate(Sender: TObject);
begin
  if (ImagesForm.ImageList.ItemIndex <> -1) and (ImagesForm.ImageList.ItemIndex < TotalImages) then begin
    AddSelBut.Enabled := True;
    ImgWidthEdit.Text := IntToStr(ImageForm[ImagesForm.ImageList.ItemIndex].ImageWidth);
    ImgHeightEdit.Text := IntToStr(ImageForm[ImagesForm.ImageList.ItemIndex].ImageHeight);
  end else begin
    AddSelBut.Enabled  := False;
    ImgWidthEdit.Text  := '256';
    ImgHeightEdit.Text := '256';
  end;
  RefreshGrid;
end;

procedure TUVForm.AddSelButClick(Sender: TObject);
var W, H: Integer;
begin
  W := StrToIntDef(ImgWidthEdit.Text,  256);
  H := StrToIntDef(ImgHeightEdit.Text, 256);

  if (W = 0) or (H = 0) then Exit;

  if ImagesForm.ImageList.ItemIndex = -1 then Exit;

  with ImageForm[ImagesForm.ImageList.ItemIndex] do begin
    if (Selected.Left = Selected.Right) or (Selected.Top = Selected.Bottom) then Exit;
    Inc(TotalCoords); ReallocMem(Coords, TotalCoords * SizeOf(TUV));
    Coords[TotalCoords-1].U := Selected.Left / W;
    Coords[TotalCoords-1].V := Selected.Top / H;
    Coords[TotalCoords-1].W := (Selected.Right - Selected.Left + 1) / W;
    Coords[TotalCoords-1].H := (Selected.Bottom - Selected.Top + 1) / H;
  end;

  RefreshGrid;
end;

procedure TUVForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
//    112: HelpForm.ShowHelp(ActiveControl.HelpContext);
    46: begin
      if (ActiveControl = UVGrid) and (not UVGrid.EditorMode) and (UVGrid.Selection.Top <= UVGrid.Selection.Bottom) then
       if MessageDlg('Delete selected UVs?', mtConfirmation, [mbYes,mbNo], 0) = mrYes then RemoveButClick(Sender);
    end;
  end;
end;

procedure TUVForm.ObjUpDownChangingEx(Sender: TObject; var AllowChange: Boolean; NewValue: Smallint; Direction: TUpDownDirection);
var i, j: Integer; TempUV: TUV; s: string; Sel: TGridRect;
begin
  Sel := UVGrid.Selection;
  case Direction of
    updUp: if Sel.Top > 1 then begin
      for i := Sel.Top to Sel.Bottom do begin
        TempUV := Coords[i - 2];
        Coords[i - 2] := Coords[i - 1];
        Coords[i - 1] := TempUV;
        for j := 1 to 4 do begin
          s := UVGrid.Cells[j, i];
          UVGrid.Cells[j, i] := UVGrid.Cells[j, i-1];
          UVGrid.Cells[j, i-1] := s;
        end;
      end;
      Dec(Sel.Top); Dec(Sel.Bottom);

    end;
    updDown:;
  end;
  UVGrid.Selection := Sel;
  AllowChange := False;
end;

procedure TUVForm.UVGridClick(Sender: TObject);
var i, Width, Height: Integer;
begin
  Width := StrToIntDef(ImgWidthEdit.Text, 256);
  Height := StrToIntDef(ImgHeightEdit.Text, 256);
  i := UVGrid.Selection.Top-1;
  case EndKindCBox.ItemIndex of
    0: begin
      UOfsEdit.Text := Format('%0.0F', [Coords[i].U*Width]);
      VOfsEdit.Text := Format('%0.0F', [Coords[i].V*Height]);
      WidthEdit.Text := Format('%0.0F', [Coords[i].W*Width]);
      HeightEdit.Text := Format('%0.0F', [Coords[i].H*Height]);
    end;
    1: begin
      UOfsEdit.Text := Format('%0.0F', [Coords[i].U*Width]);
      VOfsEdit.Text := Format('%0.0F', [Coords[i].V*Height]);
      WidthEdit.Text := Format('%0.0F', [(Coords[i].U+Coords[i].W)*Width]);
      HeightEdit.Text := Format('%0.0F', [(Coords[i].V+Coords[i].H)*Height]);
    end;
  end;
end;

end.
