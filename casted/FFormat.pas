unit FFormat;

interface

uses
  VCLHelper, Basics, BaseStr, 
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TFormatForm = class(TForm)
    OKBut: TButton;
    CancelBut: TButton;
    FormatBox: TComboBox;
    Label1: TLabel;
    procedure OKButClick(Sender: TObject);
    procedure CancelButClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormatForm: TFormatForm;

implementation

{$R *.dfm}

procedure TFormatForm.OKButClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

procedure TFormatForm.CancelButClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFormatForm.FormCreate(Sender: TObject);
begin
  SplitToTStrings(PixelFormatsEnum, StringDelimiter, FormatBox.Items, False, False);
end;

end.
