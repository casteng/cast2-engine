{$I GDefines.inc}
unit FCharMap;

interface

uses
  BaseTypes, Basics, BaseClasses, C2Types, Resources, CAST2,
  C2EdMain,
  VCLHelper,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Grids, ValEdit, StdCtrls, Buttons;

type
  TCharMapForm = class(TForm)
    TotalCEdit: TEdit;
    OKBut: TButton;
    Label1: TLabel;
    SetBut: TButton;
    CharMapGrid: TValueListEditor;
    Label2: TLabel;
    NameEdit: TEdit;
    GroupBox1: TGroupBox;
    SetValueEdit: TEdit;
    SetValBut: TButton;
    SelectAllBut: TButton;
    SelectCurrentBut: TButton;
    AddBut: TButton;
    OnTopBut: TSpeedButton;
    procedure SetButClick(Sender: TObject);
    procedure SetTotalCharacters(ATotalChars: Integer);
    procedure OKButClick(Sender: TObject);
    procedure CharMapGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
    procedure SetValButClick(Sender: TObject);
    procedure SelectAllButClick(Sender: TObject);
    procedure SelectCurrentButClick(Sender: TObject);
    procedure AddButClick(Sender: TObject);
    procedure RefreshGrid;
    procedure OnTopButClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    TotalChars, SelectCellEnter: Integer;
    Charmap: array of BaseTypes.TCharMapItem;
    { Public declarations }
  end;

var
  CharMapForm: TCharMapForm;

implementation

uses MainForm;

//uses MainForm;

{$R *.dfm}

procedure TCharMapForm.SetButClick(Sender: TObject);
begin
  SetTotalCharacters(StrToIntDef(TotalCEdit.Text, 256));
end;

procedure TCharMapForm.SetTotalCharacters(ATotalChars: Integer);
begin
//  TotalChars := ATotalChars;
  try
    CharMapGrid.Hide;
    if TotalChars < 1 then TotalChars := 1;
    if ATotalChars < 1 then ATotalChars := 1;
    CharMapGrid.Row := 1;//CharMapGrid.RowCount-1;
    SetLength(Charmap, ATotalChars);
    while TotalChars > ATotalChars do begin
      CharMapGrid.DeleteRow(CharMapGrid.RowCount-1);
      Dec(TotalChars);
    end;
    while TotalChars < ATotalChars do begin
      CharMap[TotalChars] := TotalChars;
      CharMapGrid.InsertRow(Format('%3.3D', [TotalChars]) + '"' + Chr(TotalChars) + '"', IntToStr(CharMap[TotalChars]), True);
      Inc(TotalChars);
    end;
    TotalCEdit.Text := IntToStr(TotalChars);
  finally
    CharMapGrid.Show;
  end;
end;

procedure TCharMapForm.CharMapGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  Inc(SelectCellEnter);
  CanSelect := True;
  if SelectCellEnter > 3 then Exit;
  if ACol > 0 then begin
    CharMapGrid.Options := CharMapGrid.Options + [goEditing] + [goAlwaysShowEditor]
  end else begin
    CharMapGrid.EditorMode := False;
    CharMapGrid.Options := CharMapGrid.Options - [goEditing] - [goAlwaysShowEditor];
    CharMapGrid.Row := ARow;
//    CharMapGrid.Col := ACol;
  end;
  Dec(SelectCellEnter);
end;

procedure TCharMapForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #27 then SelectCurrentButClick(Sender);
end;

procedure TCharMapForm.FormCreate(Sender: TObject);
begin
  SelectCellEnter := 0;
  SetLength(Charmap, 1);
  Charmap[0] := 0;
end;

procedure TCharMapForm.SetValButClick(Sender: TObject);
var i: Integer;
begin
  for i := CharMapGrid.Selection.Top to CharMapGrid.Selection.Bottom do begin
    Charmap[i-1] := StrToIntDef(SetValueEdit.Text, 0);
    CharMapGrid.Values[CharMapGrid.Keys[i]] := IntToStr(Charmap[i-1]);
  end;
end;

procedure TCharMapForm.SelectAllButClick(Sender: TObject);
begin
  CharMapGrid.Selection := TGridRect(Rect(0, 1, 1, CharMapGrid.RowCount-1));
end;

procedure TCharMapForm.SelectCurrentButClick(Sender: TObject);
begin
  if CharMapGrid.EditorMode then CharMapGrid.EditorMode := False;
  CharMapGrid.Options := CharMapGrid.Options - [goEditing] - [goAlwaysShowEditor];
  CharMapGrid.Selection := TGridRect(Rect(0, CharMapGrid.Row, 1, CharMapGrid.Row));
end;

procedure TCharMapForm.AddButClick(Sender: TObject);
var i, Val: Integer;
begin
  Val := StrToIntDef(SetValueEdit.Text, 0);
  for i := CharMapGrid.Selection.Top to CharMapGrid.Selection.Bottom do begin
    Charmap[i-1] := MaxI(0, Charmap[i-1] + Cardinal(Val));
    CharMapGrid.Values[CharMapGrid.Keys[i]] := IntToStr(Charmap[i-1]);
  end;
end;

procedure TCharMapForm.RefreshGrid;
var i: Integer;
begin
  for i := 1 to CharMapGrid.RowCount-1 do begin
    CharMapGrid.Values[CharMapGrid.Keys[i]] := IntToStr(Charmap[i-1]);
  end;
end;

procedure TCharMapForm.OKButClick(Sender: TObject);
var TempRes: TCharMapResource; i: Integer; Item: TItem;
begin
  for i := 1 to CharMapGrid.RowCount-1 do begin
    Charmap[i-1] := StrToIntDef(CharMapGrid.Cells[1, i], 0);
  end;
  Item := Core.Root.GetItemByFullName(Text);
  if Item is TCharMapResource then begin   // Existing resource
    (Item as TCharMapResource).Allocate(TotalChars * SizeOf(BaseTypes.TCharMapItem));
    Move(Charmap[0], TCharMap((Item as TCharMapResource).Data)[0], TotalChars * SizeOf(BaseTypes.TCharMapItem));
  end else begin                           // New resource
    TempRes := TCharMapResource.Create(Core);
    TempRes.Allocate(TotalChars * SizeOf(BaseTypes.TCharMapItem));
    Move(CharMap[0], TCharMap(TempRes.Data)[0], TotalChars * SizeOf(BaseTypes.TCharMapItem));
    MainF.GetCurrentParent.AddChild(TempRes);
  end;
  MainF.ItemsChanged := True;
  MainF.ItemsFrame1.RefreshTree;
end;

procedure TCharMapForm.OnTopButClick(Sender: TObject);
begin
  if OnTopBut.Down then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TCharMapForm.FormShow(Sender: TObject);
begin
  CheckParentSize(Self);
end;

end.
