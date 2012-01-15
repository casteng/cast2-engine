unit FAbout;

interface

uses
  CAST2,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,
  OSUtils;

type
  TAboutForm = class(TForm)
    TitleText: TStaticText;
    CopyrightText: TStaticText;
    RightsText: TStaticText;
    Button1: TButton;
    URLLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure URLLabelClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  AboutForm: TAboutForm;

implementation

uses MainForm;

{$R *.dfm}

procedure TAboutForm.FormCreate(Sender: TObject);
begin
  TitleText.Caption := FormCaption + ' v' + VersionStr + ', engine v' + EngineVersionMajor + '.' + EngineVersionMinor;
  URLLabel.Caption := ProgramURL;
end;

procedure TAboutForm.URLLabelClick(Sender: TObject);
begin
  OpenUrl(ProgramURL);
end;

end.
