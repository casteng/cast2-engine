{$Include C2Defines.inc}
unit CImport;

interface

uses
   Logger, 
  Basics, Props, Resources,
  C2EdMain,
  SysUtils, ComCTRLs, Forms, Classes, Controls;

function ImportRDB(Filename: string): Boolean;

implementation

uses BaseClasses, CAST2, C2Res, C2Visual, CRes, MainForm;

function ImportRDB(Filename: string): Boolean;
var
  Stream: Basics.TFileStream; ResM: TResourceManager;
//  NewItem: C2Res.TResource;
  NewItem: BaseClasses.TItem;
  i, j: Integer;
  TSets: array of Integer;
  ItemClass: CItem;
begin
  Result := True;
  Stream := Basics.TFileStream.Create(FileName);
  ResM := TResourceManager.Create(Stream, []);

  for i := 0 to ResM.TotalResources-1 do begin
    ItemClass := Core.FindItemClass(ResM.ResourcesInfo[i].Resource.ClassName);
    if ItemClass = nil then begin
      
      Log('ImportRDB: Unknown class "' + ResM.ResourcesInfo[i].Resource.ClassName + '"', lkError);
      
      Continue;
    end;
    NewItem      := ItemClass.Create(Core);
    NewItem.Name := ResM.ResourcesInfo[i].Name;

    ResM.ResourceStatus[i] := rsMemory;

    if ResM.ResourceStatus[i] <> rsMemory then begin
      
      Log('ImportRDB: Error loading resource "' + ResM.ResourcesInfo[i].Name + '"', lkError);
      
      Continue;
    end;

    if (ResM.ResourcesInfo[i].Resource.ClassName = 'TArrayResource') and (UpperCase(Copy(ResM.ResourcesInfo[i].Name, 1, 4)) = 'VER_') then begin
      with ResM.ResourcesInfo[i].Resource do begin
        SetLength(TSets, (Format shr 8) and $FF);
        for j := 0 to Integer((Format shr 8) and $FF)-1 do TSets[j] := 2;
        (NewItem as Resources.TResource).Format :=
         GetVertexFormat(Format and 1 > 0, Format and 2 > 0, Format and 4 > 0, Format and 8 > 0, False,
                         (Format shr 16) and $FF, TSets);
        TSets := nil;
      end;
    end else (NewItem as Resources.TResource).Format := ResM.ResourcesInfo[i].Resource.Format;

    if ResM.ResourcesInfo[i].Resource is CRes.TImageResource then begin
      (NewItem as Resources.TImageResource).SetDimensions((ResM.ResourcesInfo[i].Resource as CRes.TImageResource).Width,
                                                          (ResM.ResourcesInfo[i].Resource as CRes.TImageResource).Height);
    end;

    (NewItem as Resources.TResource).Allocate(ResM.ResourcesInfo[i].Resource.Size);
    Move(ResM.ResourcesInfo[i].Resource.Data^, (NewItem as Resources.TResource).Data^, (NewItem as Resources.TResource).DataSize);

    MainF.GetCurrentParent.AddChild(NewItem);
    MainF.ItemsChanged := True;

    
    Log('Resource "' + ResM.ResourcesInfo[i].Name + '" succesfully imported as ' + NewItem.ClassName, lkNotice);
    
  end;

  ResM.Free;
  Stream.Free;

  if MainF.ItemsChanged then MainF.ItemsFrame1.RefreshTree;
end;

end.
