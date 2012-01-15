{$I GDefines.inc}
unit ItemClassForm;

interface

uses
  BaseTypes, BaseClasses, CAST2, Basics, BaseStr, 
  C2EdMain,
  VCLHelper,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Buttons, StdCtrls, ComCtrls,
  VirtualTrees;

const
  ClassSeparator = ',';

type
  CItems =array of CItem;
  TItemClassF = class(TForm)
  private
    function InheritsFromSome(AClass: CItem; AClasses: CItems): Boolean;
  published
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    ClassCreateBut: TButton;
    ClassModifyBut: TButton;
    CatList: TListBox;
    ClassList: TListBox;
    OnTopBut: TSpeedButton;
    CatSetupText: TMemo;
    procedure OnTopButClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    function GetCatClasses(const CatName: string): CItems;
    function GetCatName(Index: Integer): string;
    procedure RefreshClasses;
    procedure SelectClass(Name: string);
    procedure ClassCreateButClick(Sender: TObject);
    procedure CatListClick(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
    procedure ClassModifyButClick(Sender: TObject);
    procedure ClassListDblClick(Sender: TObject);
  end;

var
  ItemClassF: TItemClassF;

implementation

uses MainForm, Logger;

{$R *.dfm}

function TItemClassF.InheritsFromSome(AClass: CItem; AClasses: CItems): Boolean;
var i: Integer;
begin
  i := High(AClasses);
  while (i >= 0) and not AClass.InheritsFrom(AClasses[i]) do Dec(i);
  Result := i >= 0;
end;

procedure TItemClassF.OnTopButClick(Sender: TObject);
begin
  if OnTopBut.Down then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TItemClassF.FormShow(Sender: TObject);
begin
  OnTopBut.Down := FormStyle = fsStayOnTop;
  CheckParentSize(Self);
end;

procedure TItemClassF.PageControl1Change(Sender: TObject);
begin
  RefreshClasses;
end;

procedure TItemClassF.CatListClick(Sender: TObject);
var CurClass, i: Integer; BaseClasses: CItems;
begin
  if CatList.ItemIndex = -1 then Exit;
  CurClass := ClassList.ItemIndex;
  ClassList.Clear;

  BaseClasses := GetCatClasses(CatList.Items[CatList.ItemIndex]);

  for i := 0 to Core.TotalItemClasses-1 do
    if InheritsFromSome(Core.ItemClasses[i], BaseClasses) and not Core.ItemClasses[i].isAbstract then
      ClassList.Items.Add(Core.ItemClasses[i].ClassName);

  ClassList.ItemIndex := CurClass;
end;

function TItemClassF.GetCatClasses(const CatName: string): CItems;
var i: Integer; Strs: TStringArray;
begin
  SetLength(Result, Split(CatSetupText.Lines.Values[CatName], ClassSeparator, Strs, False));
  for i := 0 to High(Result) do Result[i] := Core.FindItemClass(Trim(Strs[i]));
end;

function TItemClassF.GetCatName(Index: Integer): string;
begin
  Result := '';
  if (Index < 0) or (Index >= CatSetupText.Lines.Count) then Exit;
  Result := CatSetupText.Lines.Names[Index];
end;

procedure TItemClassF.RefreshClasses;
var CurCat, i: Integer;
begin
  CurCat   := CatList.ItemIndex;
  CatList.Clear;

  for i := 0 to CatSetupText.Lines.Count-1 do CatList.Items.Add(GetCatName(i));

  CatList.ItemIndex := CurCat;
end;

procedure TItemClassF.SelectClass(Name: string);

  function Match(const CatName: string; AClass: CItem): Boolean;
  var ItemCLasses: CItems;
  begin
    ItemClasses := GetCatClasses(CatName);
    Result := InheritsFromSome(AClass, ItemClasses);
  end;

var i: Integer; ItemClass: CItem;

begin
  ItemClass := Core.FindItemClass(Name);
  if ItemClass = nil then Exit;

  i := CatList.Items.Count-1;
  while (i >= 0) and not Match(CatList.Items[i], ItemClass) do Dec(i);
  if i >= 0 then begin
    CatList.ItemIndex := i;
    CatListClick(nil);
    ClassList.ItemIndex := ClassList.Items.IndexOf(Name);
  end;
end;

procedure TItemClassF.ClassCreateButClick(Sender: TObject);
var ItemClass: CItem;
begin
  if ClassList.ItemIndex = -1 then Exit;
  ItemClass := Core.FindItemClass(ClassList.Items[ClassList.ItemIndex]);
  if ItemClass = nil then begin
    Log('Class "' + ClassList.Items[ClassList.ItemIndex] + '" not registered', lkError);
    Exit;
  end;
  App.ActNewItem(ItemClass, MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode));
end;

procedure TItemClassF.ClassModifyButClick(Sender: TObject);
var i: Integer; Node: PVirtualNode; ItemClass: CItem;
begin
  if ClassList.ItemIndex = -1 then Exit;

  ItemClass := Core.FindItemClass(ClassList.Items[ClassList.ItemIndex]);
  if ItemClass = nil then begin
    Log('Class "' + ClassList.Items[ClassList.ItemIndex] + '" not registered', lkError);
    Exit;
  end;

  Node := MainF.ItemsFrame1.Tree.GetFirstSelected;
  for i := 0 to MainF.ItemsFrame1.Tree.SelectedCount-1 do begin
    Core.ChangeClass(MainF.ItemsFrame1.GetNodeItem(Node), ItemClass);
    Node := MainF.ItemsFrame1.Tree.GetNextSelected(Node);
  end;

  MainF.ItemsFrame1.RefreshTree;
  MainF.ItemsChanged := True;
end;

procedure TItemClassF.ClassListDblClick(Sender: TObject);
begin
  ClassCreateButClick(Sender);
end;

end.
