{$I GDefines.inc}
unit FCFont;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls;

type
  TMkFontForm = class(TForm)
    Edit1: TEdit;
    Edit2: TEdit;
    Button1: TButton;
    Button2: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Button3: TButton;
    Button4: TButton;
    ColsEdit: TEdit;
    Label4: TLabel;
    DAlphaBox: TCheckBox;
    FSizeBox: TCheckBox;
    WidthEdit: TEdit;
    HeightEdit: TEdit;
    TSizeXEdit: TEdit;
    TSizeYEdit: TEdit;
    Label5: TLabel;
    Label6: TLabel;
    OffsXEdit: TEdit;
    OffsYEdit: TEdit;
    FontNameEdit: TEdit;
    Label7: TLabel;
    EndXEdit: TEdit;
    EndYEdit: TEdit;
    Label8: TLabel;
    StepXEdit: TEdit;
    StepYEdit: TEdit;
    Label9: TLabel;
    FXAddHEdit: TEdit;
    FXAddWEdit: TEdit;
    Label10: TLabel;
    FontSet: TRichEdit;
    Label11: TLabel;
    CenterCBox: TCheckBox;
    CSepCBox: TCheckBox;
    FontDialog1: TFontDialog;
    procedure Button4Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure TSizeXEditChange(Sender: TObject);
    procedure TSizeYEditChange(Sender: TObject);
    procedure FontSetChange(Sender: TObject);
    procedure FontSetSelectionChange(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MkFontForm: TMkFontForm;

implementation

{$R *.dfm}

procedure TMkFontForm.Button4Click(Sender: TObject);
var i: Integer;
begin
  for i := StrToIntDef(Edit1.Text, 0) to StrToIntDef(Edit2.Text, 0) do FontSet.Text := FontSet.Text + Chr(i);
end;

procedure TMkFontForm.Button3Click(Sender: TObject);
begin
  if FontDialog1.Execute then begin
    FontSet.SelAttributes.Name  := FontDialog1.Font.Name;
    FontSet.SelAttributes.Color := FontDialog1.Font.Color;
    FontSet.SelAttributes.Size  := FontDialog1.Font.Size;
    FontSet.SelAttributes.Style := FontDialog1.Font.Style;
    FontSet.SelAttributes.Pitch := FontDialog1.Font.Pitch;
  end;
end;

procedure TMkFontForm.Button1Click(Sender: TObject);
begin
//  if (TSizeXEdit.Text = '') or (TSizeYEdit.Text = '') or (ColsEdit.Text = '') then Exit;
  ModalResult := mrOK;
end;

procedure TMkFontForm.TSizeXEditChange(Sender: TObject);
begin
  EndXEdit.Text := IntToStr(StrToIntDef(TSizeXEdit.Text, 256));
end;

procedure TMkFontForm.TSizeYEditChange(Sender: TObject);
begin
  EndYEdit.Text := IntToStr(StrToIntDef(TSizeYEdit.Text, 256));
end;

procedure TMkFontForm.FontSetChange(Sender: TObject);
begin
  Label1.Caption := 'Total '+IntToStr(Length(FontSet.Text))+' characters';
end;

procedure TMkFontForm.FontSetSelectionChange(Sender: TObject);
begin
  Label11.Caption := 'S/H: ' + IntToStr(FontSet.SelAttributes.Size) + ' / ' + IntToStr(FontSet.SelAttributes.Height) +
                     ' H/S: ' + IntToStr(FontSet.SelAttributes.Size*Screen.PixelsPerInch div 72) + ' / ' + IntToStr(FontSet.SelAttributes.Height*72 div Screen.PixelsPerInch);
end;

end.
