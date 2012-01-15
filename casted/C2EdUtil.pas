{$I GDefines.inc}
unit C2EdUtil;

interface

uses
  Logger, BaseClasses, BaseMsg, CAST2, ItemMsg, Resources,
  EditWin,
  BaseTypes, Basics, Props, SysUtils, ComCTRLs, Forms, Classes, Controls, ExtCtrls;

procedure ShowResource(Item: TResource);
procedure SetChildsEnabled(Container: TWinControl; Enabled: Boolean);

type
  TStreamClipboard = class
    Stream: Basics.TStream;
    TotalElements: Integer;
    constructor Create(FileName: string);
    procedure Clear;
    procedure PushObject;
    procedure PrepareObject(Index: Integer);
    destructor Destroy; override;
  protected
    Offsets: array of Cardinal;
  end;

{  TItemCollection = class
  private

    FItemClass: CItem;
    FTotalItems: Integer;

    constructor Create(AItemClass: CItem);
    function GetItem(Index: Integer): TItem;
  public
    procedure HandleMessage(const Msg: TMessage);
    procedure Add(Item: TItem);
    procedure Remove(Item: TItem);
    property TotalItems: Integer read FTotalItems;
    property Items[Index: Integer]: TItem read GetItem;
  end;}

  TItemsClass = record
    ItemsClass: CItem;
    ItemNames: TStrings;
  end;

  // Stores items of specified in constructor classes sorted by class
  TItemsList = class
  private
    FCore: TItemsManager;
    FItemClasses: array of TItemsClass;
    function GetClassIndex(AClass: TClass): Integer;
    function GetTotalItems(AClass: CItem): Integer;
    function GetItem(AClass: CItem; Index: Integer): TItem;
    function GetName(AClass: CItem; Index: Integer): AnsiString;
    function GetAsTStrings(AClass: CItem): TStrings;
    function GetIndex(Item: TItem; const FullName: AnsiString): Integer;
    function DoRemove(Item: TItem; const FullName: AnsiString): Boolean;
  public
    constructor Create(ACore: TItemsManager; AClasses: array of CItem);
    destructor Destroy; override;
    procedure HandleMessage(const Msg: TMessage);

    procedure Clear(AClass: CItem);
    procedure ClearAll();

    function Exists(Item: TItem): Boolean;
    procedure Add(Item: TItem);
    procedure Remove(Item: TItem);

    property Name[AClass: CItem; Index: Integer]: AnsiString read GetName;
    property TotalItems[AClass: CItem]: Integer read GetTotalItems;
    property Item[AClass: CItem; Index: Integer]: TItem read GetItem;
    property AsTStrings[AClass: CItem]: TStrings read GetAsTStrings;
  end;

var
  Cfg: Props.TNiceFileConfig;
  Clipboard: TStreamClipboard;

implementation

uses C2Types, FCharMap, FUVGen, FImages, Base2D, FTextEdit;
  

procedure ShowResource(Item: TResource);

  procedure ShowForm(AForm: TCustomForm);
  begin
    AForm.Show;
    if AForm.WindowState = wsMinimized then AForm.WindowState := wsNormal;
  end;

begin
  if Item is TCharMapResource then begin
    CharMapForm.SetTotalCharacters((Item as TArrayResource).TotalElements);
    Move(BaseTypes.TCharMap((Item as TArrayResource).Data)[0], CharMapForm.CharMap[0], (Item as TArrayResource).TotalElements * SizeOf(TCharMapItem));
    CharMapForm.RefreshGrid;
    CharMapForm.NameEdit.Text := Item.GetFullName;
    ShowForm(CharMapForm);
  end;
  if Item is TUVMapResource then begin
    UVForm.TotalCoords := (Item as TArrayResource).TotalElements;
    ReallocMem(UVForm.Coords, UVForm.TotalCoords * SizeOf(TUV));
    Move(TUVMap(Item.Data)[0], UVForm.Coords[0], (Item as TArrayResource).TotalElements * SizeOf(TUV));
    UVForm.RefreshGrid;
    UVForm.NameEdit.Text := Item.GetFullName;
    ShowForm(UVForm);
  end;
  if Item is TTextResource then begin
    TextEditForm.ResNameEdit.Text := Item.GetFullName;
    TextEditForm.SourceEdit.Text := (Item as TTextResource).Text;
    ShowForm(TextEditForm);
  end;
  if Item is TImageResource then begin
    if Item is TMegaImageResource then
      AddImageWindow(Item.Name, Item as TImageResource, 0, (Item as TImageResource).Width, (Item as TImageResource).Height, (Item as TImageResource).ActualLevels)
    else begin
      if Item.Data = nil then begin
        Log('Can''t obtain resource data', lkError);
        Exit;
      end;
      AddImageWindow(Item.Name, Item as TImageResource, 0, (Item as TImageResource).Width, (Item as TImageResource).Height, (Item as TImageResource).ActualLevels);
      ConvertImage(Item.Format, EditFormat, Item.TotalElements, Item.Data, 0, nil, ImageForm[TotalImages-1].Buffer);
    end;
    ImageForm[TotalImages-1].Redraw;
    ImageForm[TotalImages-1].Image1.Repaint;
  end;
  if Item is TAudioResource then begin
//      if Sound <> nil then Sound.Free;
{$IFDEF AUDIO}
//      Sound := Audio.CreateSound('Audio', ResourcesInfo[ResGrid.Row-1].Name);
{$ENDIF}
//      Sound.Play;
  end;
  if Item is TScriptResource then begin
//      ScriptForm.Source.Lines.Text := TScriptResource(Resources[ResGrid.Row-1]).GetText;
//      ScriptForm.NameEdit.Text := Name;
//      ScriptForm.Visible := True;
  end;
end;

procedure SetChildsEnabled(Container: TWinControl; Enabled: Boolean);
var i: Integer;
begin
  for i := 0 to Container.ControlCount-1 do Container.Controls[i].Enabled := Enabled;
end;

{ TStreamClipboard }

constructor TStreamClipboard.Create(FileName: string);
begin
  if FileName <> '' then Stream := Basics.TFileStream.Create(FileName, fuWrite);
  Clear;
end;

procedure TStreamClipboard.Clear;
begin
  Offsets := nil; TotalElements := 0;
end;

procedure TStreamClipboard.PushObject;
begin
  Inc(TotalElements);
  SetLength(Offsets, TotalElements);
  Offsets[TotalElements-1] := Stream.Position;
end;

procedure TStreamClipboard.PrepareObject(Index: Integer);
begin
  Assert((Index >= 0) and (Index < TotalElements), 'TStreamClipboard.PrepareObject: Invalid index');
  Stream.Seek(Offsets[Index]);
end;

destructor TStreamClipboard.Destroy;
begin
  Clear;
  FreeAndNil(Stream);
  inherited;
end;


{ TItemCollectionsManager }

function TItemsList.GetClassIndex(AClass: TClass): Integer;
begin
  Result := High(FItemClasses);
  while (Result >= 0) and (AClass <> FItemClasses[Result].ItemsClass) do Dec(Result);
end;

function TItemsList.GetName(AClass: CItem; Index: Integer): AnsiString;
var CIndex: Integer;
begin
  Result := '';
  CIndex := GetClassIndex(AClass);
  if CIndex < 0 then Exit;
  Assert((Index >= 0) and (Index < TotalItems[AClass]));

  Result := FItemClasses[CIndex].ItemNames[Index];
end;

function TItemsList.GetAsTStrings(AClass: CItem): TStrings;
var CIndex: Integer;
begin
  Result := nil;
  CIndex := GetClassIndex(AClass);
  if (CIndex >= 0) then Result := FItemClasses[CIndex].ItemNames;
end;

function TItemsList.GetTotalItems(AClass: CItem): Integer;
var CIndex: Integer;
begin
  Result := 0;
  CIndex := GetClassIndex(AClass);
  if (CIndex >= 0) and Assigned(FItemClasses[CIndex].ItemNames) then
    Result := FItemClasses[CIndex].ItemNames.Count;
end;

function TItemsList.GetIndex(Item: TItem; const FullName: AnsiString): Integer;
var CIndex: Integer;
begin
  Result := -1;
  CIndex := GetClassIndex(Item.ClassType);
  if (CIndex >= 0) and Assigned(FItemClasses[CIndex].ItemNames) then begin
    if FullName = '' then
      Result := FItemClasses[CIndex].ItemNames.IndexOf(Item.GetFullName)
    else
      Result := FItemClasses[CIndex].ItemNames.IndexOf(FullName);
  end;
end;

function TItemsList.DoRemove(Item: TItem; const FullName: AnsiString): Boolean;
var Index: Integer;
begin
  Index := GetIndex(Item, FullName);
  Result := Index >= 0;
  if Result then FItemClasses[GetClassIndex(Item.ClassType)].ItemNames.Delete(Index);
end;

function TItemsList.GetItem(AClass: CItem; Index: Integer): TItem;
var CIndex: Integer;
begin
  Result := nil;
  CIndex := GetClassIndex(AClass);
  if (CIndex >= 0) and Assigned(FItemClasses[CIndex].ItemNames) then
    Result := FCore.Root.GetItemByFullName(FItemClasses[CIndex].ItemNames[Index]);
end;

procedure TItemsList.HandleMessage(const Msg: TMessage);
begin
  if (Msg.ClassType = TAddToSceneMsg) then
    Add(TAddToSceneMsg(Msg).Item)
  else if (Msg.ClassType = TItemNameModifiedMsg) then begin
    if DoRemove(TItemNameModifiedMsg(Msg).Item, TItemNameModifiedMsg(Msg).OldName) then
      Add(TItemNameModifiedMsg(Msg).Item);
  end else if (Msg.ClassType = TRemoveFromSceneMsg) then
    DoRemove(TAddToSceneMsg(Msg).Item, '')
  else if (Msg.ClassType = TSceneClearMsg) then
    ClearAll();
end;

procedure TItemsList.Clear(AClass: CItem);
var CIndex: Integer;
begin
  CIndex := GetClassIndex(AClass);
  if (CIndex >= 0) and Assigned(FItemClasses[CIndex].ItemNames) then
    FItemClasses[CIndex].ItemNames.Clear;
end;

procedure TItemsList.ClearAll;
var i: Integer;
begin
  for i := 0 to High(FItemClasses) do Clear(FItemClasses[i].ItemsClass);
end;

constructor TItemsList.Create(ACore: TItemsManager; AClasses: array of CItem);
var i: Integer;
begin
  FCore := ACore;
  SetLength(FItemClasses, Length(AClasses));
  for i := 0 to High(AClasses) do begin
    FItemClasses[i].ItemsClass := AClasses[i];
    FItemClasses[i].ItemNames := TStringList.Create;
  end;
end;

destructor TItemsList.Destroy;
var i: Integer;
begin
  for i := 0 to High(FItemClasses) do
    if Assigned(FItemClasses[i].ItemNames) then FreeAndNil(FItemClasses[i].ItemNames);
  SetLength(FItemClasses, 0);

  inherited;
end;

function TItemsList.Exists(Item: TItem): Boolean;
begin
  Result := GetIndex(Item, '') >= 0;
end;

procedure TItemsList.Add(Item: TItem);
var CIndex: Integer;
begin
  CIndex := GetClassIndex(Item.ClassType);
  if (CIndex >= 0) and Assigned(FItemClasses[CIndex].ItemNames) then
    FItemClasses[CIndex].ItemNames.Add(Item.GetFullName);
end;

procedure TItemsList.Remove(Item: TItem);
begin
  DoRemove(Item, '');
end;

end.
