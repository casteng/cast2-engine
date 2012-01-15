unit FConfig;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls;

type
  TConfigForm = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    OKBut: TButton;
    CancelBut: TButton;
    LoadPluginBut: TButton;
    StaticText1: TStaticText;
    LoadPluginOpenDialog: TOpenDialog;
    PluginsList: TListBox;
    Bevel1: TBevel;
    PluginDesc: TStaticText;
    Label1: TLabel;
    Label2: TLabel;
    TabSheet2: TTabSheet;
    CheckBox1: TCheckBox;
    Edit1: TEdit;
    Label3: TLabel;
    procedure LoadPluginButClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PluginsListClick(Sender: TObject);
  private

  public
    procedure RefreshPluginList;
  end;

var
  ConfigForm: TConfigForm;

implementation

uses BasePlugins, C2EdMain;

{$R *.dfm}

procedure TConfigForm.LoadPluginButClick(Sender: TObject);
begin
  if LoadPluginOpenDialog.Execute then begin
    App.LoadPlugin(LoadPluginOpenDialog.FileName);
    RefreshPluginList;
  end;
end;

procedure TConfigForm.RefreshPluginList;
var i: Integer;
begin
  PluginsList.Clear;
  for i := 0 to PluginSystem.TotalPlugins-1 do PluginsList.Items.Add(PluginSystem.Plugin[i].Name);
end;

procedure TConfigForm.FormShow(Sender: TObject);
begin
  RefreshPluginList;
end;

procedure TConfigForm.PluginsListClick(Sender: TObject);
var i: Integer;
begin
  if (PluginsList.ItemIndex >= 0) and (PluginsList.ItemIndex < PluginSystem.TotalPlugins) then
    PluginDesc.Caption := PluginSystem.Plugin[PluginsList.ItemIndex].Description + #13#10 +
                          'File name: ' + PluginSystem.Plugin[PluginsList.ItemIndex].FileName + #13#10 +
                          'Classes introduced: [';
  for i := 0 to High(PluginSystem.Plugin[PluginsList.ItemIndex].ClassesAdded) do begin
    if i > 0 then PluginDesc.Caption := PluginDesc.Caption + ', ';
    PluginDesc.Caption := PluginDesc.Caption + PluginSystem.Plugin[PluginsList.ItemIndex].ClassesAdded[i].ClassName;
  end;
  PluginDesc.Caption := PluginDesc.Caption + ']';
end;

end.
