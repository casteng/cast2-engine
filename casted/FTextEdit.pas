{$I GDefines.inc}
{$I C2Defines.inc}
unit FTextEdit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, SynEdit, SynEditHighlighter, SynHighlighterJava, SynHighlighterGeneral, SynHighlighterAsm,
  SynHighlighterIni;

type
  TTextEditForm = class(TForm)
    ResNameEdit: TEdit;
    Label1: TLabel;
    ApplyButton: TButton;
    RevertButton: TButton;
    SourceEdit: TSynEdit;
    SynGeneralSyn1: TSynGeneralSyn;
    SynIniSyn1: TSynIniSyn;
    SynJavaSyn1: TSynJavaSyn;
    procedure ApplyButtonClick(Sender: TObject);
    procedure RevertButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  end;

var
  TextEditForm: TTextEditForm;

implementation

uses
  BaseClasses, Logger,
  SynHighlighterAsmShader,
  C2EdMain, Resources, C2Res, MainForm;

{$R *.dfm}

procedure TTextEditForm.ApplyButtonClick(Sender: TObject);
var Item, Parent: TItem; TempRes: TTextResource; LName: AnsiString;
begin
  Item := Core.Root.GetItemByFullName(ResNameEdit.Text);
  if Assigned(Item) and not (Item is TTextResource) then begin
     Log(Format('Item %S is not a TTextResource', [ResNameEdit.Text]), lkError);  ;
    Exit;
  end;
  if Item = nil then begin            // New resource
    Item := TTextResource.Create(Core);
    App.ObtainNewItemData(ResNameEdit.Text, LName, Parent);
    Item.Name := LName;
    Item.Parent := Parent;
  end;
  if Item is TTextResource then begin        // Existing resource
    TempRes := Item as TTextResource;
    TempRes.Text := SourceEdit.Text;
  end;
  MainF.ItemsChanged := True;
  MainF.ItemsFrame1.RefreshTree;
end;

procedure TTextEditForm.FormCreate(Sender: TObject);
var HL: TSynAsmShader;
begin
  HL := TSynAsmShader.Create(Self);
  SourceEdit.Highlighter := Hl;

  SourceEdit.ClearAll;
  SourceEdit.Text := HL.SampleSource;
end;

procedure TTextEditForm.FormDestroy(Sender: TObject);
begin
//  SourceEdit.Highlighter.Free;
end;

procedure TTextEditForm.RevertButtonClick(Sender: TObject);
var Item: TTextResource;
begin
  Item := Core.Root.GetItemByFullName(ResNameEdit.Text) as TTextResource;
  if not Assigned(Item) then Exit;
  SourceEdit.Text := Item.Text;
end;

end.
