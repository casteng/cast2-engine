unit FSMGen;

interface

uses
  BaseTypes, Basics, Base2D,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Grids;

const PreviewW = 64; PreviewH = 64; 

type
  TSMGForm = class(TForm)
    SScaleEdit: TEdit;
    HScaleEdit: TEdit;
    SJitterEdit: TEdit;
    HJitterEdit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    CloseSMGBut: TButton;
    GenerateSMBut: TButton;
    OnTopCBox: TCheckBox;
    ColorDialog1: TColorDialog;
    SMFLoadBut: TButton;
    SMFSaveBut: TButton;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    ImagesListH: TListBox;
    IMRefreshBut: TButton;
    TexGrid: TStringGrid;
    AddBut: TButton;
    DelBut: TButton;
    procedure GenerateSMButClick(Sender: TObject);
    procedure OnTopCBoxClick(Sender: TObject);

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

    procedure SMFSaveButClick(Sender: TObject);
    procedure SMFLoadButClick(Sender: TObject);
    procedure LoadSettings(fn: string);
    procedure SaveSettings(fn: string);
    procedure IMRefreshButClick(Sender: TObject);
    procedure AddButClick(Sender: TObject);
    procedure DelButClick(Sender: TObject);
    procedure CloseSMGButClick(Sender: TObject);
    procedure TexGridKeyPress(Sender: TObject; var Key: Char);
    procedure ImagesListHDblClick(Sender: TObject);
  private
    Buf: BaseTypes.PImageBuffer;
    TotalTextures: Integer;
    { Private declarations }
  public
    { Public declarations }
  end;

  TScanLine = array[0..65535] of DWord;

var
  SMGForm: TSMGForm;

implementation

uses FImages, EditWin;//MainUnit;

{$R *.dfm}

procedure TSMGForm.GenerateSMButClick(Sender: TObject);
var
  i, w, h, SJitter, HJitter, IIndex: Integer; SlopeScale, HeightScale: Single;
  Texs: array of record IIndex, Height: Integer; end; OldH: Integer;

  procedure Generate;
  var
    OverRange: Single;
    i, j, t1, t2, ti, tj, Height, Slope: Integer;
    Color1, Color2: BaseTypes.TColor;
  {$Q-}
  begin
    ReAllocMem(Buf, w*h*4);

    for j := 0 to h-1 do for i := 0 to w-1 do begin
      Height := Trunc(0.5 + (ImageForm[ImagesListH.ItemIndex].Buffer[j*w+i].C and 255) * HeightScale);
      Slope := Trunc(0.5 + SlopeScale*(Abs(ImageForm[ImagesListH.ItemIndex].Buffer[j*w + MaxI(0, i-1)].C and 255 -
                                           ImageForm[ImagesListH.ItemIndex].Buffer[j*w + MinI(w-1, i+1)].C and 255) +
                                       Abs(ImageForm[ImagesListH.ItemIndex].Buffer[MaxI(0, j-1)*w + i].C and 255 -
                                           ImageForm[ImagesListH.ItemIndex].Buffer[MinI(h-1, j+1)*w + i].C and 255)));

      Height := MinI(Texs[TotalTextures-1].Height, Height + Slope + Random(SJitter*2) - SJitter);
  // 0---1---2---3
      t1 := 0;
      while t1 < TotalTextures-1 do begin
        if Height < Texs[t1].Height then Break;
        Inc(t1);
      end;
      if t1 > 0 then Dec(t1);
      if t1 < TotalTextures-1 then t2 := t1+1 else t2 := t1;

      OverRange := 1/(Texs[t2].Height - Texs[t1].Height);

      ti := MinI(i, ImageForm[Texs[t1].IIndex].ImageWidth-1);
      tj := MinI(j, ImageForm[Texs[t1].IIndex].ImageHeight-1);
      Color1 := ImageForm[Texs[t1].IIndex].Buffer[tj*ImageForm[Texs[t1].IIndex].ImageWidth + ti];
      ti := MinI(i, ImageForm[Texs[t2].IIndex].ImageWidth-1);
      tj := MinI(j, ImageForm[Texs[t2].IIndex].ImageHeight-1);
      Color2 := ImageForm[Texs[t2].IIndex].Buffer[tj*ImageForm[Texs[t2].IIndex].ImageWidth + ti];

      Buf[j*w+i] := BlendColor(Color1, Color2, MaxS(0, (Height-Texs[t1].Height) * OverRange));
    end;
  end;

begin
  if (ImagesListH.ItemIndex = -1) or (TotalTextures = 0) then Exit;

  SetLength(Texs, TotalTextures);

  OldH := 0;
  for i := 0 to TotalTextures-1 do begin
    Texs[i].IIndex := ImagesListH.Items.IndexOf(TexGrid.Cells[0, i+1]);
    Texs[i].Height := MaxI(OldH, StrToIntDef(TexGrid.Cells[1, i+1], 0));
    OldH := StrToIntDef(TexGrid.Cells[1, i+1], 0);
  end;

  w := ImageForm[ImagesListH.ItemIndex].ImageWidth;
  h := ImageForm[ImagesListH.ItemIndex].ImageHeight;
  SlopeScale := StrToFloatDef(SScaleEdit.Text, 0.5) * 0.5;
  HeightScale := StrToFloatDef(HScaleEdit.Text, 0.5);
  SJitter := StrToIntDef(SJitterEdit.Text, 0);
  HJitter := StrToIntDef(HJitterEdit.Text, 0);

  Generate;
  if (ImagesForm.ImageList.ItemIndex <> -1) and
     (ImageForm[ImagesForm.ImageList.ItemIndex].ImageWidth = w) and (ImageForm[ImagesForm.ImageList.ItemIndex].ImageWidth = w) then
   IIndex := ImagesForm.ImageList.ItemIndex else
    IIndex := AddImageWindow('Colormap', nil, 0, w, h);
  Move(Buf^, ImageForm[IIndex].Buffer^, w*h*4);
  ImageForm[IIndex].Redraw; ImageForm[IIndex].Image1.Repaint;

{  if IIndex = ImagesForm.HMapIndex then MainForm.UpdateHMap(ImageForm[IIndex].CheckArea(GetArea(0, 0, HMap.MapWidth-1, HMap.MapHeight-1)));
  if IIndex = ImagesForm.CMapIndex then MainForm.UpdateCMap(ImageForm[IIndex].CheckArea(GetArea(0, 0, HMap.MapWidth-1, HMap.MapHeight-1)));
  if IIndex = ImagesForm.SMapIndex then MainForm.UpdateSMap(ImageForm[IIndex].CheckArea(GetArea(0, 0, ImageForm[IIndex].ImgWidth-1, ImageForm[IIndex].ImgHeight-1)));}
end;

procedure TSMGForm.OnTopCBoxClick(Sender: TObject);
begin
  if OnTopCBox.Checked then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TSMGForm.FormCreate(Sender: TObject);
begin
  Buf := nil;
  LoadSettings('colormapg.ini');
  TexGrid.Cells[0, 0] := 'Image'; TexGrid.Cells[1, 0] := 'Height';
  TotalTextures := 0;
end;

procedure TSMGForm.FormDestroy(Sender: TObject);
begin
  SaveSettings('colormapg.ini');
  if Assigned(Buf) then FreeMem(Buf);
end;

procedure TSMGForm.SMFSaveButClick(Sender: TObject);
begin
  if SaveDialog1.Execute then SaveSettings(SaveDialog1.FileName);
end;

procedure TSMGForm.SMFLoadButClick(Sender: TObject);
begin
  if OpenDialog1.Execute then LoadSettings(OpenDialog1.FileName);
end;

procedure TSMGForm.LoadSettings(fn: string);
var f: TextFile; s: string;
begin
  if not FileExists(fn) then Exit;
  AssignFile(f, fn); ReSet(f);
  Readln(f, s);
  SScaleEdit.Text := s;
  Readln(f, s);
  HScaleEdit.Text := s;
  Readln(f, s);
  SJitterEdit.Text := s;
  Readln(f, s);
  HJitterEdit.Text := s;
  TotalTextures := 0;
  while not Eof(f) do begin
    Inc(TotalTextures);
    TexGrid.RowCount := MaxI(TexGrid.RowCount, TotalTextures+1);
    Readln(f, s);
    TexGrid.Cells[0, TotalTextures] := s;
    Readln(f, s);
    TexGrid.Cells[1, TotalTextures] := s;
  end;
  CloseFile(f);
end;

procedure TSMGForm.SaveSettings(fn: string);
var i: Integer; f: TextFile;
begin
  AssignFile(f, fn); ReWrite(f);
  Writeln(f, SScaleEdit.Text);
  Writeln(f, HScaleEdit.Text);
  Writeln(f, SJitterEdit.Text);
  Writeln(f, HJitterEdit.Text);
  for i := 1 to TotalTextures do begin
    Writeln(f, TexGrid.Cells[0, i]);
    Writeln(f, TexGrid.Cells[1, i]);
  end;  
  CloseFile(f);
end;

procedure TSMGForm.IMRefreshButClick(Sender: TObject);
var i: Integer; OldP2: Integer;
begin
  OldP2 := ImagesListH.ItemIndex;
  ImagesListH.Clear;
  for i := 0 to ImagesForm.ImageList.Count-1 do begin
    ImagesListH.Items.Add(ImagesForm.ImageList.Items[i]);
  end;
  ImagesListH.ItemIndex := OldP2;
end;

procedure TSMGForm.AddButClick(Sender: TObject);
begin
  if ImagesListH.ItemIndex = -1 then Exit;
  Inc(TotalTextures);
  TexGrid.RowCount := MaxI(TexGrid.RowCount, TotalTextures+1);
  TexGrid.Cells[0, TotalTextures] := ImagesListH.Items[ImagesListH.ItemIndex];
end;

procedure TSMGForm.DelButClick(Sender: TObject);
var i: Integer;
begin
  if TexGrid.Row = -1 then Exit;
  for i := TexGrid.Row to TexGrid.RowCount-1 do begin
    TexGrid.Cells[0, i] := TexGrid.Cells[0, i+1]; TexGrid.Cells[0, i+1] := '';
    TexGrid.Cells[1, i] := TexGrid.Cells[1, i+1]; TexGrid.Cells[1, i+1] := '';
  end;
  if TotalTextures > 0 then Dec(TotalTextures);
end;

procedure TSMGForm.CloseSMGButClick(Sender: TObject);
begin
  Visible := False;
end;

procedure TSMGForm.TexGridKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then GenerateSMButClick(nil);
end;

procedure TSMGForm.ImagesListHDblClick(Sender: TObject);
begin
  if ImagesListH.ItemIndex = -1 then Exit;
  ImageForm[ImagesListH.ItemIndex].Show;
end;

end.
