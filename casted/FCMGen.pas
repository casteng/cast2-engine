{$I GDefines.inc}
unit FCMGen;

interface

uses
  BaseTypes, Basics, Base2D,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls;

const PreviewW = 64; PreviewH = 64; 

type
  TCMGForm = class(TForm)
    WidthEdit: TEdit;
    HeightEdit: TEdit;
    SunColorP: TPanel;
    ZenithColorP: TPanel;
    HorizonColorP: TPanel;
    SunXEdit: TEdit;
    SunYEdit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    SunSizeEdit: TEdit;
    Label5: TLabel;
    CloseSMGBut: TButton;
    GenerateSMBut: TButton;
    OnTopCBox: TCheckBox;
    Button1: TButton;
    SunSizeSlider: TTrackBar;
    ColorDialog1: TColorDialog;
    PreviewImage: TImage;
    ReverseCBox: TCheckBox;
    SMFLoadBut: TButton;
    SMFSaveBut: TButton;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    procedure GenerateSMButClick(Sender: TObject);
    procedure OnTopCBoxClick(Sender: TObject);
    procedure ColorPClick(Sender: TObject);
    procedure Generate(w, h: Integer);
    procedure Preview;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PreviewImageMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure SunSizeSliderChange(Sender: TObject);
    procedure ReverseCBoxClick(Sender: TObject);
    procedure PreviewImageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure SMFSaveButClick(Sender: TObject);
    procedure SMFLoadButClick(Sender: TObject);
    procedure LoadSettings(fn: string);
    procedure SaveSettings(fn: string);
  private
    Buf: BaseTypes.PImageBuffer;
    { Private declarations }
  public
    { Public declarations }
  end;

  TScanLine = array[0..65535] of DWord;

var
  CMGForm: TCMGForm;

implementation

uses FImages;//MainUnit;

{$R *.dfm}

procedure TCMGForm.GenerateSMButClick(Sender: TObject);
var w, h, IIndex: Integer;
begin
  w := StrToIntDef(WidthEdit.Text, 0); h := StrToIntDef(HeightEdit.Text, 0);
  if (w = 0) or (h = 0) then Exit;
  Generate(-1, -1);
  if (ImagesForm.ImageList.ItemIndex <> -1) and (ImagesForm.ImageList.ItemIndex <= High(ImageForm)) and
     (ImageForm[ImagesForm.ImageList.ItemIndex].ImageWidth = w) and (ImageForm[ImagesForm.ImageList.ItemIndex].ImageWidth = w) then
   IIndex := ImagesForm.ImageList.ItemIndex else
    IIndex := AddImageWindow('Skymap', nil, 0, w, h);
  Move(Buf^, ImageForm[IIndex].Buffer^, w*h*4);
  ImageForm[IIndex].Redraw; ImageForm[IIndex].Image1.Repaint;

{  if IIndex = ImagesForm.HMapIndex then MainForm.UpdateHMap(ImageForm[IIndex].CheckArea(GetArea(0, 0, HMap.MapWidth-1, HMap.MapHeight-1)));
  if IIndex = ImagesForm.CMapIndex then MainForm.UpdateCMap(ImageForm[IIndex].CheckArea(GetArea(0, 0, HMap.MapWidth-1, HMap.MapHeight-1)));
  if IIndex = ImagesForm.SMapIndex then MainForm.UpdateSMap(ImageForm[IIndex].CheckArea(GetArea(0, 0, ImageForm[IIndex].ImgWidth-1, ImageForm[IIndex].ImgHeight-1)));}
end;

procedure TCMGForm.OnTopCBoxClick(Sender: TObject);
begin
  if OnTopCBox.Checked then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TCMGForm.ColorPClick(Sender: TObject);
begin
  ColorDialog1.Color := TPanel(Sender).Color;
  if ColorDialog1.Execute then TPanel(Sender).Color := ColorDialog1.Color;
  Preview;
end;

procedure TCMGForm.Generate(w, h: Integer);
var
  i, j, SunX, SunY, SunSize, ZeroLevel: Integer;
  OneOverSunSize, K: Single;
  SunColor, ZenithColor, HorizonColor: BaseTypes.TColor;
  SunD: Single;
begin
  if w = -1 then w := StrToIntDef(WidthEdit.Text, 0);
  if h = -1 then h := StrToIntDef(HeightEdit.Text, 0);
  if (w = 0) or (h = 0) then Exit;

  ReAllocMem(Buf, w*h*4);

  ZenithColor := VCLColorToColor(ZenithColorP.Color);
  HorizonColor := VCLColorToColor(HorizonColorP.Color);
  SunColor := VCLColorToColor(SunColorP.Color);
  SunSize := StrToIntDef(SunSizeEdit.Text, 1);
  SunX := StrToIntDef(SunXEdit.Text, w div 2);
  SunY := StrToIntDef(SunYEdit.Text, h div 2);
  if ReverseCBox.Checked then begin
    SunD := Sqrt(Sqr(w div 2-SunX)+Sqr(h div 2-SunY));
    if SunD = 0 then begin
      SunX := w*4; SunY := h*4;
    end else begin
      SunX := Trunc(0.5 + (SunX - w div 2)/SunD * (w - SunD)) + w div 2;
      SunY := Trunc(0.5 + (SunY - h div 2)/SunD * (h - SunD)) + h div 2;
    end;
  end;

  if SunSize = 0 then begin
    ZeroLevel := 1;
    OneOverSunSize := 1
  end else begin
    ZeroLevel := 0;
    OneOverSunSize := 1/SunSize;
  end;

  for j := 0 to h-1 do for i := 0 to w-1 do begin
    K := Sqrt(Sqr(w div 2-i)+Sqr(h div 2-j))/w*2;
//    if K <= 1 then
     Buf[j*w+i] := BlendColor(SunColor,
                    BlendColor(ZenithColor, HorizonColor, K),
                     ZeroLevel + OneOverSunSize*MinS(SunSize, Sqrt(Sqr(SunX-i)+Sqr(SunY-j))) );
//      Buf[j*w+i] := 0;
  end;
end;

procedure TCMGForm.Preview;
var i: Integer;
begin
  Generate(PreviewW, PreviewH);
  for i := 0 to PreviewH-1 do
   Move(Buf^[i*PreviewW], PreviewImage.Picture.Bitmap.ScanLine[i]^, PreviewW*4);
  PreviewImage.Repaint; 
end;

procedure TCMGForm.FormCreate(Sender: TObject);
begin
  Buf := nil;
  PreviewImage.Picture.Bitmap.PixelFormat := pf32bit;
  PreviewImage.Picture.Bitmap.Width := PreviewImage.Width;
  PreviewImage.Picture.Bitmap.Height := PreviewImage.Height;
  LoadSettings('skymapg.ini');
end;

procedure TCMGForm.FormDestroy(Sender: TObject);
begin
  SaveSettings('skymapg.ini');
  if Assigned(Buf) then FreeMem(Buf);
end;

procedure TCMGForm.PreviewImageMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  SunXEdit.Text := IntToStr(X);
  SunYEdit.Text := IntToStr(Y);
  Preview;
end;

procedure TCMGForm.PreviewImageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not (ssLeft in Shift) then Exit;
  SunXEdit.Text := IntToStr(X);
  SunYEdit.Text := IntToStr(Y);
  Preview;
end;

procedure TCMGForm.SunSizeSliderChange(Sender: TObject);
begin
  SunSizeEdit.Text := IntToStr(SunSizeSlider.Position);
  Preview;
end;

procedure TCMGForm.ReverseCBoxClick(Sender: TObject);
begin
  Preview;
end;

procedure TCMGForm.SMFSaveButClick(Sender: TObject);
begin
  if SaveDialog1.Execute then SaveSettings(SaveDialog1.FileName);
end;

procedure TCMGForm.SMFLoadButClick(Sender: TObject);
begin
  if OpenDialog1.Execute then LoadSettings(OpenDialog1.FileName);
end;

procedure TCMGForm.LoadSettings(fn: string);
var f: TextFile; s: string; c: Graphics.TColor;
begin
  if not FileExists(fn) then Exit;
  AssignFile(f, fn); ReSet(f);
  Readln(f, s);
  WidthEdit.Text := s;
  Readln(f, s);
  HeightEdit.Text := s;
  Readln(f, c);
  ZenithColorP.Color := c;
  Readln(f, c);
  HorizonColorP.Color := c;
  Readln(f, c);
  SunColorP.Color := c;
  Readln(f, s);
  SunSizeEdit.Text := s;
  Readln(f, s);
  SunXEdit.Text := s;
  Readln(f, s);
  SunYEdit.Text := s;
  CloseFile(f);
  Preview;
end;

procedure TCMGForm.SaveSettings(fn: string);
var f: TextFile;
begin
  AssignFile(f, fn); ReWrite(f);
  Writeln(f, WidthEdit.Text);
  Writeln(f, HeightEdit.Text);
  Writeln(f, ZenithColorP.Color);              
  Writeln(f, HorizonColorP.Color);
  Writeln(f, SunColorP.Color);
  Writeln(f, SunSizeEdit.Text);
  Writeln(f, SunXEdit.Text);
  Writeln(f, SunYEdit.Text);
  CloseFile(f);
end;

end.
