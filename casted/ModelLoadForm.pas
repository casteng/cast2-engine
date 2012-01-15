unit ModelLoadForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, ExtCtrls;

type
  TModelLoadF = class(TForm)
    PageControl1: TPageControl;
    Panel1: TPanel;
    OKBut: TButton;
    CancelBut: TButton;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    SnapIndexEdit: TEdit;
    SnapCBox: TCheckBox;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ModelLoadF: TModelLoadF;

implementation

{$R *.dfm}

end.
