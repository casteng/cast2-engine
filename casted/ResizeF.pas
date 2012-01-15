unit ResizeF;

interface

uses
  Basics, BaseStr, Base2D, Resources, VCLHelper,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TResizeForm = class(TForm)
    FilterBox: TComboBox;
    Label3: TLabel;
    Edit3: TEdit;
    FirstLevelBox: TCheckBox;
    Label1: TLabel;
    Label2: TLabel;
    Edit1: TEdit;
    Edit2: TEdit;
    AspectBox: TCheckBox;
    Button1: TButton;
    Button2: TButton;
    Label4: TLabel;
    procedure FilterBoxChange(Sender: TObject);
    procedure TestReal(Sender: TObject);
    procedure TestInteger(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure AspectBoxClick(Sender: TObject);
    procedure AspectBoxKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    AspectRatio: Single;
  end;

var
  ResizeForm: TResizeForm;

implementation

{$R *.dfm}

procedure TResizeForm.FilterBoxChange(Sender: TObject);
begin
  Edit3.Text := FloatToStr(DefaultResizeFilterValue[TImageResizeFilter(FilterBox.ItemIndex)]);
end;

procedure TResizeForm.TestReal(Sender: TObject);
var i: Word; NewText: TCaption;
begin
  with TEdit(Sender) do begin
    for i := 1 to Length(Text) do if ((Text[i] >= '0') and (Text[i] <= '9')) or (Text[i] = '-') or (Text[i] = DecimalSeparator) then NewText := NewText + Text[i];
    Text := NewText;
  end;
end;

procedure TResizeForm.TestInteger(Sender: TObject);
var i: Word; NewText: TCaption;
begin
  with TEdit(Sender) do begin
    for i := 1 to length(Text) do if ((Text[i] >= '0') and (Text[i] <= '9')) or (Text[i] = '-') then NewText := NewText + Text[i];
    Text := NewText;
  end;
  if AspectBox.Checked and (AspectRatio <> 0) then begin
    if Sender = Edit1 then Edit2.Text := IntToStr(Trunc(StrToIntDef(Edit1.Text, 0) / AspectRatio + 0.5));
    if Sender = Edit2 then Edit1.Text := IntToStr(Trunc(StrToIntDef(Edit2.Text, 0) * AspectRatio + 0.5));
  end else begin
    if AspectRatio = 0 then AspectBox.State := cbUnchecked;
  end;
end;

procedure TResizeForm.Button1Click(Sender: TObject);
begin
  if (Edit1.Text <> '') and (Edit2.Text <> '') then ModalResult := mrOk;
end;

procedure TResizeForm.AspectBoxClick(Sender: TObject);
begin
  if StrToIntDef(Edit2.Text, 0) <> 0 then AspectRatio := StrToIntDef(Edit1.Text, 0) / StrToIntDef(Edit2.Text, 0) else AspectRatio := 0;
end;

procedure TResizeForm.AspectBoxKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #32 then if StrToIntDef(Edit2.Text, 0) <> 0 then AspectRatio := StrToIntDef(Edit1.Text, 0) / StrToIntDef(Edit2.Text, 0) else AspectRatio := 0;
end;

procedure TResizeForm.FormCreate(Sender: TObject);
begin
  SplitToTStrings(ImageFilterEnums, StrDelim, FilterBox.Items, False, False);
  FilterBox.ItemIndex := 0;
end;

end.
