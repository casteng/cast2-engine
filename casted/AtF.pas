{$I GDefines.inc}
unit AtF;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TLoadAtForm = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Edit1: TEdit;
    Edit2: TEdit;
    OkBut: TButton;
    CancelBut: TButton;
    procedure TestInteger(Sender: TObject);
    procedure OkButClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  LoadAtForm: TLoadAtForm;

implementation

{$R *.dfm}

procedure TLoadAtForm.TestInteger(Sender: TObject);
var i: Word; NewText: TCaption;
begin
  with TEdit(Sender) do begin
    for i := 1 to length(Text) do if ((Text[i] >= '0') and (Text[i] <= '9')) or (Text[i] = '-') then NewText := NewText + Text[i];
    Text := NewText;
  end;
end;

procedure TLoadAtForm.OkButClick(Sender: TObject);
begin
  if (StrToIntDef(Edit1.Text, $FFFFFF) = $FFFFFF) or (StrToIntDef(Edit2.Text, $FFFFFF) = $FFFFFF) then Exit;
  ModalResult := mrOK;
end;

end.
