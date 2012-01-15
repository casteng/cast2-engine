{$I GDefines.inc}
unit FVFormat;

interface

uses
  CTypes,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TVFormatForm = class(TForm)
    OKBut: TButton;
    CancelBut: TButton;
    Label1: TLabel;
    DiffCBox: TCheckBox;
    SpecCBox: TCheckBox;
    NormCBox: TCheckBox;
    UVsEdit: TEdit;
    WightsEdit: TEdit;
    Label2: TLabel;
    Label3: TLabel;
    TransCBox: TCheckBox;
    Label4: TLabel;
    procedure FillForm(const VFormat: Cardinal);
    function GetVFormat: Cardinal;
    procedure OKButClick(Sender: TObject);
    procedure CancelButClick(Sender: TObject);
    procedure CheckButClick(Sender: TObject);
    procedure FormatChange(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  VFormatForm: TVFormatForm;

implementation

{$R *.dfm}

procedure TVFormatForm.OKButClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

procedure TVFormatForm.CancelButClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TVFormatForm.FillForm(const VFormat: Cardinal);
begin
  TransCBox.Checked := (VFormat and 1) <> 0;
  NormCBox.Checked  := (VFormat and 2) <> 0;
  DiffCBox.Checked  := (VFormat and 4) <> 0;
  SpecCBox.Checked  := (VFormat and 8) <> 0;

  UVsEdit.Text := IntToStr((VFormat shr 8) and 255);
  WightsEdit.Text := IntToStr((VFormat shr 16) and 255);
  FormatChange(nil);
end;

function TVFormatForm.GetVFormat: Cardinal;
begin
  if TransCBox.Checked then begin
    NormCBox.Checked := False;
  end;
  UVsEdit.Text := IntToStr(StrToIntDef(UVsEdit.Text, 1));
  WightsEdit.Text := IntToStr(StrToIntDef(WightsEdit.Text, 0));
  Result := GetVertexFormat(TransCBox.Checked, NormCBox.Checked, DiffCBox.Checked, SpecCBox.Checked,
                            StrToIntDef(UVsEdit.Text, 1), StrToIntDef(WightsEdit.Text, 0));
end;

procedure TVFormatForm.CheckButClick(Sender: TObject);
begin
  FillForm(GetVFormat);
end;

procedure TVFormatForm.FormatChange(Sender: TObject);
begin
  Label4.Caption := 'Vertex size: ' + IntToStr(GetVertexSize(GetVFormat)) + ' bytes';
end;

end.

