unit FNormMap;

interface

uses
  Props,
  treeviews,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, PropFrame, StdCtrls, ExtCtrls;

type
  TNormMapForm = class(TForm)
    PropsFrame1: TPropsFrame;
    Panel1: TPanel;
    BtnOK: TButton;
    BtnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BtnOKClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    Properties: TProperties;
    procedure TreeEditorAcceptEdit(const PropertyModified: TProperty);
  end;

var
  NormMapForm: TNormMapForm;

implementation

{$R *.dfm}

procedure TNormMapForm.FormCreate(Sender: TObject);
begin
  Properties := TProperties.Create;
  PropsFrame1.Properties := TProperties.Create;
  Properties.Add('Y/Z swap', vtBoolean, [], 'Off', '');
  Properties.Add('Scale',    vtSingle,  [], '0.05', '0.0-4.0');
  PropsFrame1.Properties.Merge(Properties, True);

  PropsFrame1.Tree.NodeDataSize := SizeOf(TPropNodeData);
  PropsFrame1.EditorTree := TPropsTree.Create(PropsFrame1.Tree, PropsFrame1.Properties, TreeEditorAcceptEdit);
  PropsFrame1.RefreshTree;
end;

procedure TNormMapForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(PropsFrame1.Properties);
  FreeAndNil(PropsFrame1.EditorTree);
  FreeAndNil(Properties);
end;

procedure TNormMapForm.TreeEditorAcceptEdit(const PropertyModified: TProperty);
begin

end;

procedure TNormMapForm.BtnOKClick(Sender: TObject);
begin
  Properties.Clear;
  Properties.Merge(PropsFrame1.Properties, True);
end;

procedure TNormMapForm.BtnCancelClick(Sender: TObject);
begin
  PropsFrame1.Properties.Clear;
  PropsFrame1.Properties.Merge(Properties, True);
end;

end.
