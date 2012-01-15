{$Include GDefines.inc}
{$Include CDefines.inc}
unit CRes;

interface

uses SysUtils,

     Logger,

     BaseTypes, Basics, Base3D, CTypes;

const
  rkAuto = $FFFFFFFF;    //ToFix: Replace it with GetClass
  rmError = 1 shl 31;
  ekInsert = 1; ekDelete = 2; ekMove = 3; ekSwap = 4;
  rsStream = 1; rsMemory = 2; rsInUse = 3; rsDeleted = 20;
  rsDefault = rsStream;

  moNeverReplace = 0; moReplaceIfNewer = 1; moAlwaysReplace = 2;

type
  TResourcesHeader = array[0..3] of Char;

  TMergeOptions = Cardinal;

  TOrderEvent = record
    EventKind, Arg1, Arg2: Integer;
  end;

  TResourceManager = class;

  CResource = class of TResource;
  TResource = class
    Data: Pointer;
    Kind, Format, Size, HeaderSize: Cardinal;
    Owner: TResourceManager;
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); virtual;
    procedure Allocate(const ASize: Cardinal); virtual;
    function Load(const Stream: TStream): Integer; virtual; abstract;
    function Save(const Stream: TStream): Integer; virtual; abstract;
    function LoadData(const Stream: TStream): Integer; virtual;
    function SaveData(const Stream: TStream): Integer; virtual;
    procedure OrderEvent(OrderEvent: TOrderEvent); virtual;
    procedure SetFormat(const AFormat: Cardinal); virtual;
    destructor Free; virtual;
    private
      FStatus: Cardinal;
      function GetStatus: Cardinal;
      procedure SetStatus(const Value: Cardinal);
    public
      property Status: Cardinal read GetStatus write SetStatus;
      class function GetHeaderSize: Cardinal; virtual;
  end;

  TArrayResource = class(TResource)
    TotalElements: Integer;
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
    function Load(const Stream: TStream): Integer; override;
    function Save(const Stream: TStream): Integer; override;
    class function GetHeaderSize: Cardinal; override;
  end;

  TImageResource = class(TResource)
    Width, Height: Cardinal;
    PaletteResource: LongInt;
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
    function Load(const Stream: TStream): Integer; override;
    function Save(const Stream: TStream): Integer; override;
    procedure OrderEvent(OrderEvent: TOrderEvent); override;
    class function GetHeaderSize: Cardinal; override;
  end;

  TTextureResource = class(TImageResource)
    Miplevels: Cardinal;
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
    function Load(const Stream: TStream): Integer; override;
    function Save(const Stream: TStream): Integer; override;
    class function GetHeaderSize: Cardinal; override;
  end;

  TAudioResource = class(TArrayResource)
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
  end;

  TTextResource = class(TArrayResource)
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
    function GetText: string; virtual;
  end;

  TScriptResource = class(TTextResource)
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
  end;

  TPathResource = class(TArrayResource)
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
  end;

  TFontResource = class(TArrayResource)
    FontTexture: Integer;
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
    procedure Allocate(const ASize: Cardinal); override;
    function Load(const Stream: TStream): Integer; override;
    function Save(const Stream: TStream): Integer; override;
    procedure OrderEvent(OrderEvent: TOrderEvent); override;
    class function GetHeaderSize: Cardinal; override;
    destructor Free; override;
  end;

  TCharMapResource = class(TArrayResource)
    constructor Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto); override;
    procedure Allocate(const ASize: Cardinal); override;
    destructor Free; override;
  end;

  TResourceInfo = packed record
    Name: BaseTypes.TShortName;
    Kind, Size, HeaderSize, Offset: Cardinal;
    Resource: TResource;
    CreateTime: Double;
  end;

  TResourceManager = class
    InputStream: TStream;
    StartOffset, DataOffset: Cardinal;
    FromVersion, Version: Longint;
    ResourceClasses: array of CResource; TotalResourceClasses: Cardinal;
    ResourcesInfo: array of TResourceInfo; TotalResources, StoredResources: Integer;
    rkImage, rkTexture, rkVertices, rkIndices, rkPalette, rkUVMap, rkAudio, rkPath, rkText, rkScript: Integer;
    Changed: Boolean;
    constructor Create(AStream: TStream; NewClasses: array of CResource);
    function ChangeName(const Index: Integer; const AName: TShortName): Boolean;
    procedure AddResourceClass(NewClass: CResource);
    function GetResourceClassIndex(const Name: TShortName): Integer;
    function ResourceByName(const Name: TShortName): TResource;
    function IndexByName(const Name: TShortName): Integer;
    function IndexByResource(const Res: TResource): Integer;
    function Add(const AName: TShortName; const AResource: TResource): Integer; overload;
    function Merge(const AResources: TResourceManager; const MergeOptions: TMergeOptions): Integer; overload;
    procedure Delete(const Index: Integer);
    procedure Clear;
//    procedure Add(AResources: array of TResource); overload;
    function Load: Integer;
    function LoadFrom(AStream: TStream): Integer;
    procedure Append(Resources: TResourceManager);
    function LoadInfo: Integer;
    function Save: Integer;
    function SaveAs(AStream: TStream): Integer;
    function CalcOffsets(CalcDeleted: Boolean): Boolean; virtual;
    destructor Free;
  private
    FResourceStatus: array of Cardinal;
    CurrentOffset: Cardinal;
    function GetResource(Index: Integer): TResource;
    function GetResourceStatus(Index: Integer): Cardinal;
    procedure SetResourceStatus(Index: Integer; Value: Cardinal);
  public
    property Resources[Index: Integer]: TResource read GetResource; default;
    property ResourceStatus[Index: Integer]: Cardinal read GetResourceStatus write SetResourceStatus;
  end;

implementation

const
  ResourcesHeader01: TResourcesHeader = ('R', 'C', '0', '1');
  ResourcesHeader02: TResourcesHeader = ('R', 'C', '0', '2');

{ TResource }

constructor TResource.Create(const AOwner: TResourceManager; const AFormat, ASize, AKind: Cardinal);
begin
  Owner := AOwner; Size := ASize; Format := AFormat;
  Status := rsDefault;
  HeaderSize := GetHeaderSize;
  Data := nil;
end;

procedure TResource.Allocate(const ASize: Cardinal);
var ind: Integer;
begin
  if (ASize = Size) and (Data <> nil) then Exit;
  if Data <> nil then FreeMem(Data, Size);
  Size := ASize;
  ind := Owner.IndexByResource(Self);
  if ind <> -1 then Owner.ResourcesInfo[ind].Size := Size;
  if Size = 0 then Data := nil else GetMem(Data, Size);
end;

destructor TResource.Free;
begin
  if Data <> nil then FreeMem(Data); Data := nil;
end;

function TResource.GetStatus: Cardinal;
begin
  Result := FStatus;
end;

procedure TResource.SetStatus(const Value: Cardinal);
begin
  FStatus := Value;
end;

const feOK = 0; feNotFound = -1; feCannotRead = -2; feCannotWrite = -3; feInvalidFileFormat = -4; feCannotSeek = -5; feCannotOpen = -6;

function TResource.LoadData(const Stream: TStream): Integer;
begin
  Result := feCannotRead;
  Allocate(Size);
  if Stream.Read(Data^, Size) <> feOK then Exit;
  Result := feOK;
end;

procedure TResource.OrderEvent(OrderEvent: TOrderEvent);
begin
end;

function TResource.SaveData(const Stream: TStream): Integer;
begin
  Result := feCannotWrite;
  if Stream.Write(Data^, Size) <> feOK then Exit;
  Result := feOK;
end;

class function TResource.GetHeaderSize: Cardinal;
begin
  Result := 0;
end;

procedure TResource.SetFormat(const AFormat: Cardinal);
begin
  Format := AFormat;
end;

{ TArrayResource }

constructor TArrayResource.Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TArrayResource') else Kind := AKind;
end;

class function TArrayResource.GetHeaderSize: Cardinal;
begin
  Result := 8;
end;

function TArrayResource.Load(const Stream: TStream): Integer;
begin
  Result := feCannotRead;
  if Stream.Read(Format, SizeOf(Format)) <> feOK then Exit;
  if Stream.Read(TotalElements, SizeOf(TotalElements)) <> feOK then Exit;
  Result := LoadData(Stream);
end;

function TArrayResource.Save(const Stream: TStream): Integer;
begin
  Result := feCannotWrite;
  if Stream.Write(Format, SizeOf(Format)) <> feOK then Exit;
  if Stream.Write(TotalElements, SizeOf(TotalElements)) <> feOK then Exit;
  Result := SaveData(Stream);
end;

{ TImageResource }

constructor TImageResource.Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TImageResource') else Kind := AKind;
  PaletteResource := -1; Width := 0; Height := 0;
end;

function TImageResource.Load(const Stream: TStream): Integer;
begin
  Result := feCannotRead;
  if Stream.Read(Format, SizeOf(Format)) <> feOK then Exit;
  if Stream.Read(Width, SizeOf(Width)) <> feOK then Exit;
  if Stream.Read(Height, SizeOf(Height)) <> feOK then Exit;
  Result := LoadData(Stream);
end;

function TImageResource.Save(const Stream: TStream): Integer;
begin
  Result := feCannotWrite;
  if Stream.Write(Format, SizeOf(Format)) <> feOK then Exit;
  if Stream.Write(Width, SizeOf(Width)) <> feOK then Exit;
  if Stream.Write(Height, SizeOf(Height)) <> feOK then Exit;
  Result := SaveData(Stream);
end;

procedure TImageResource.OrderEvent(OrderEvent: TOrderEvent);
begin
  with OrderEvent do case EventKind of
    ekInsert:;
    ekDelete: if PaletteResource = Arg1 then PaletteResource := -1;
    ekMove: if PaletteResource = Arg2 then PaletteResource := Arg1;
    ekSwap:;
  end;
end;

class function TImageResource.GetHeaderSize: Cardinal;
begin
  Result := 12;
end;

{ TTextureResource }

constructor TTextureResource.Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TTextureResource') else Kind := AKind;
end;

class function TTextureResource.GetHeaderSize: Cardinal;
begin
  Result := 16;
end;

function TTextureResource.Load(const Stream: TStream): Integer;
begin
  Result := feCannotRead;
  if Stream.Read(Format, SizeOf(Format)) <> feOK then Exit;
  if Stream.Read(Width, SizeOf(Width)) <> feOK then Exit;
  if Stream.Read(Height, SizeOf(Height)) <> feOK then Exit;
  if Stream.Read(MipLevels, SizeOf(MipLevels)) <> feOK then Exit;
  Result := LoadData(Stream);
end;

function TTextureResource.Save(const Stream: TStream): Integer;
begin
  Result := feCannotWrite;
  if Stream.Write(Format, SizeOf(Format)) <> feOK then Exit;
  if Stream.Write(Width, SizeOf(Width)) <> feOK then Exit;
  if Stream.Write(Height, SizeOf(Height)) <> feOK then Exit;
  if Stream.Write(MipLevels, SizeOf(MipLevels)) <> feOK then Exit;
  Result := SaveData(Stream);
end;

{ TAudioResource }

constructor TAudioResource.Create(const AOwner: TResourceManager; const AFormat, ASize, AKind: Cardinal);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TAudioResource') else Kind := AKind;
end;

{ TTextResource }

constructor TTextResource.Create(const AOwner: TResourceManager; const AFormat, ASize, AKind: Cardinal);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TTextResource') else Kind := AKind;
end;

function TTextResource.GetText: string;
begin
  TotalElements := Size;
  SetLength(Result, TotalElements);
  if Data <> nil then Move(Data^, Result[1], Size);// else FillChar(Result[1], Size, 0);
end;

{ TPathResource }

constructor TPathResource.Create(const AOwner: TResourceManager; const AFormat, ASize, AKind: Cardinal);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TPathResource') else Kind := AKind;
end;

constructor TFontResource.Create(const AOwner: TResourceManager; const AFormat, ASize: Cardinal; const AKind: Cardinal = rkAuto);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TFontResource') else Kind := AKind;
end;

procedure TFontResource.Allocate(const ASize: Cardinal);
var ind: Integer;
begin
  if (ASize = Size) and (Data <> nil) then Exit;
  if Data <> nil then SetLength(TUVMap(Data), 0);
  Size := ASize;
  ind := Owner.IndexByResource(Self);
  if ind <> -1 then Owner.ResourcesInfo[ind].Size := Size;
  if Size = 0 then Data := nil else SetLength(TUVMap(Data), Size div SizeOf(TUV));
end;

function TFontResource.Load(const Stream: TStream): Integer;
var Temp: TShortName;
begin
  Result := feCannotRead;
  if Stream.Read(Format, SizeOf(Format)) <> feOK then Exit;
  if Stream.Read(TotalElements, SizeOf(TotalElements)) <> feOK then Exit;
  if Stream.Read(Temp, SizeOf(Temp)) <> feOK then Exit;
  FontTexture := Owner.IndexbyName(Temp);

//  if FontTexture < 1 then LogError('Resource not found');

  Result := LoadData(Stream);
end;

function TFontResource.Save(const Stream: TStream): Integer;
var FTName: TShortName;
begin
  Result := feCannotWrite;
  if Stream.Write(Format, SizeOf(Format)) <> feOK then Exit;
  if Stream.Write(TotalElements, SizeOf(TotalElements)) <> feOK then Exit;
  if (FontTexture < 0) or (FontTexture >= Owner.TotalResources) then
   FTName := Owner.ResourcesInfo[0].Name else FTName := Owner.ResourcesInfo[FontTexture].Name;
  if Stream.Write(FTName, SizeOf(FTName)) <> feOK then Exit;
  Result := SaveData(Stream);
end;

procedure TFontResource.OrderEvent(OrderEvent: TOrderEvent);
begin
  with OrderEvent do case EventKind of
    ekInsert:;
    ekDelete: if FontTexture = Arg1 then FontTexture := -1;
    ekMove: if FontTexture = Arg2 then FontTexture := Arg1;
    ekSwap:;
  end;
end;

class function TFontResource.GetHeaderSize: Cardinal;
begin
  Result := 8 + SizeOf(TShortName);
end;

destructor TFontResource.Free;
begin
  if Data <> nil then SetLength(TUVMap(Data), 0);
  Data := nil;
end;

{ TResourceManager }

constructor TResourceManager.Create(AStream: TStream; NewClasses: array of CResource);
var i: Integer;
begin
  Version := 0; FromVersion := -1;
  TotalResourceClasses := 0;
  AddResourceClass(TImageResource);
  AddResourceClass(TTextureResource);
  AddResourceClass(TArrayResource);
  AddResourceClass(TArrayResource);
  AddResourceClass(TArrayResource);
  AddResourceClass(TFontResource);
  AddResourceClass(TTextResource);
  AddResourceClass(TScriptResource);

  for i := 0 to Length(NewClasses)-1 do AddResourceClass(NewClasses[i]);

  AddResourceClass(TAudioResource);
  AddResourceClass(TPathResource);

  AddResourceClass(TCharMapResource);

  rkImage := GetResourceClassIndex('TImageResource');
  rkTexture := GetResourceClassIndex('TTextureResource');
  rkVertices := GetResourceClassIndex('TArrayResource');
  rkIndices := rkVertices + 1;
  rkPalette := rkVertices + 2;
  rkUVMap := GetResourceClassIndex('TFontResource');
  rkAudio := GetResourceClassIndex('TAudioResource');
  rkPath := GetResourceClassIndex('TPathResource');
  rkText := GetResourceClassIndex('TTextResource');
  rkScript := GetResourceClassIndex('TScriptResource');

  if AStream <> nil then LoadFrom(AStream);
end;

function TResourceManager.GetResource(Index: Integer): TResource;
begin
  Result := nil;
  if (Index < 0) or (Index >= TotalResources) then Exit;
  Result := ResourcesInfo[Index].Resource;
  if ResourceStatus[Index] = rsStream then ResourceStatus[Index] := rsMemory;
end;

procedure TResourceManager.AddResourceClass(NewClass: CResource);
begin
  Inc(TotalResourceClasses);
  SetLength(ResourceClasses, TotalResourceClasses);
  ResourceClasses[TotalResourceClasses-1] := NewClass;
end;

function TResourceManager.GetResourceClassIndex(const Name: TShortName): Integer;
begin
  for Result := 0 to TotalResourceClasses-1 do if ResourceClasses[Result].ClassName = Name then Exit;
  Result := -1;
end;

function TResourceManager.ChangeName(const Index: Integer; const AName: TShortName): Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to TotalResources - 1 do if (ResourcesInfo[i].Name = AName) and (FResourceStatus[i] <> rsDeleted) and (i <> Index) then Exit;
  ResourcesInfo[Index].Name := AName;
  Result := True;
  Changed := True;
end;

function TResourceManager.Add(const AName: TShortName; const AResource: TResource): Integer;
var i: Integer;
begin
  for i := 0 to TotalResources - 1 do if (ResourcesInfo[i].Name = AName) and (FResourceStatus[i] <> rsDeleted) then begin Result := i + rmError; Exit; end;
  Inc(TotalResources);
  SetLength(ResourcesInfo, TotalResources);
  SetLength(FResourceStatus, TotalResources);
  ResourcesInfo[TotalResources-1].Resource := AResource;
  ResourcesInfo[TotalResources-1].Name := AName;
  ResourcesInfo[TotalResources-1].Kind := AResource.Kind;
  ResourcesInfo[TotalResources-1].Size := AResource.Size;
  ResourcesInfo[TotalResources-1].HeaderSize := AResource.HeaderSize;
  ResourcesInfo[TotalResources-1].Offset := CurrentOffset;
  ResourcesInfo[TotalResources-1].CreateTime := Now;
  FResourceStatus[TotalResources-1] := AResource.Status;
  Inc(CurrentOffset, AResource.Size + AResource.HeaderSize);
  ResourcesInfo[TotalResources-1].Resource.Owner := Self;
  Result := TotalResources-1;
  Changed := True;
end;

function TResourceManager.Merge(const AResources: TResourceManager; const MergeOptions: TMergeOptions): Integer;
var i, Ind: Integer; Adding: Boolean;
begin
 Log('Updating resource database', lkNotice); 
  Result := 0;
  for i := 0 to AResources.TotalResources-1 do begin
    Adding := True;
    Ind := IndexbyName(AResources.ResourcesInfo[i].Name);
    if Ind >= 0 then begin
 Log('Resource "' + ResourcesInfo[Ind].Name + '" already exists in database', lkWarning); 
      case MergeOptions of
        moNeverReplace: begin
 Log('Resource "' + ResourcesInfo[Ind].Name + '" skipped due to merging in non-replacing mode', lkWarning); 
          Adding := False;
        end;
        moReplaceIfNewer: begin
          if AResources.ResourcesInfo[i].CreateTime > ResourcesInfo[Ind].CreateTime then begin
 Log('Resource "' + ResourcesInfo[Ind].Name + '" replaced by newer one', lkWarning); 
          end else begin
 Log('Resource "' + ResourcesInfo[Ind].Name + '" skipped due to existing version is up-to-date', lkWarning); 
            Adding := False;
          end;
        end;
        moAlwaysReplace: begin
 Log('Resource "' + ResourcesInfo[Ind].Name + '" replaced', lkWarning); 
        end;
      end;
      if Adding then Delete(Ind);
    end else begin
 Log('Resource "' + AResources.ResourcesInfo[i].Name + '" added', lkWarning);     
    end;
    if Adding then begin
      Add(AResources.ResourcesInfo[i].Name, AResources.Resources[i]);
      ResourcesInfo[IndexByName(AResources.ResourcesInfo[i].Name)].CreateTime := AResources.ResourcesInfo[i].CreateTime;
      Inc(Result);
    end;  
  end;

  Log('Added / updated ' + IntToStr(Result) + ' resources');

end;

procedure TResourceManager.Delete(const Index: Integer);
begin
  if (Index < 0) or (Index >= TotalResources) then Exit;
  FResourceStatus[Index] := rsDeleted;
  Changed := True;
{  Dec(TotalResources);
  ResourcesInfo[Index].Resource.Free;
  ResourcesInfo[TotalResources].Offset := ResourcesInfo[Index].Offset;
  ResourcesInfo[Index] := ResourcesInfo[TotalResources];
  FResourceStatus[Index] := FResourceStatus[TotalResources];
  SetLength(ResourcesInfo, TotalResources);
  SetLength(FResourceStatus, TotalResources);
  for i := Index+1 to TotalResources-1 do ResourcesInfo[i].Offset := ResourcesInfo[i-1].Offset + ResourcesInfo[i-1].Size + ResourcesInfo[i-1].HeaderSize;
  if TotalResources = 0 then CurrentOffset := 0 else
   CurrentOffset := ResourcesInfo[TotalResources-1].Offset + ResourcesInfo[TotalResources-1].Size + ResourcesInfo[TotalResources-1].HeaderSize;}
{  with OrderEvent do begin
    EventKind := ekDelete;
    Arg1 := Index;
    Arg2 := TotalResources;
  end;
  for i := 0 to TotalResources-1 do ResourcesInfo[i].Resource.OrderEvent(OrderEvent);}
//  OrderEvent.EventKind := ekMove;
//  for i := 0 to TotalResources-1 do ResourcesInfo[i].Resource.OrderEvent(OrderEvent);
end;

procedure TResourceManager.Clear;
var i: Integer;
begin
  for i := 0 to TotalResources-1 do if Assigned(ResourcesInfo[i].Resource) then begin
    ResourcesInfo[i].Resource.Free;
  end;
  SetLength(ResourcesInfo, 0); SetLength(FResourceStatus, 0); TotalResources := 0; StoredResources := 0;
  CurrentOffset := 0;
  Changed := True;
//  InputStream.Free;
end;

function TResourceManager.Load: Integer;
begin
  InputStream.Seek(StartOffset);
  Result := LoadFrom(InputStream);
end;

function TResourceManager.LoadFrom(AStream: TStream): Integer;
var i: Integer; HDR: TResourcesHeader; ResClassName: TShortName;
begin
{  if Assigned(InputStream) then begin
    InputStream.Free;
  end;}
  InputStream := AStream;
  StartOffset := AStream.Position;
  Result := feCannotRead;
  Clear;

  if AStream.Read(HDR, SizeOf(HDR)) <> feOK then Exit;
  if (HDR <> ResourcesHeader01) and (HDR <> ResourcesHeader02) then begin

    Log('ResM: Invalid resource file', lkFatalError);
;
    Result := feInvalidFileFormat;
    Exit;
  end;
  if AStream.Read(FromVersion, SizeOf(Version)) <> feOK then Exit;
  if AStream.Read(Version, SizeOf(Version)) <> feOK then Exit;

  if AStream.Read(TotalResources, SizeOf(TotalResources)) <> feOK then Exit;
  StoredResources := TotalResources;

  SetLength(ResourcesInfo, TotalResources); SetLength(FResourceStatus, TotalResources);
  if HDR = ResourcesHeader01 then begin

    Log('ResM: Old resource file version', lkWarning);
;
    if AStream.Read(ResourcesInfo[0], TotalResources*SizeOf(TResourceInfo)) <> feOK then Exit;
    for i := 0 to TotalResources-1 do begin
      ResourcesInfo[i].Resource := nil;
      Dec(ResourcesInfo[i].Kind);
    end;
    DataOffset := SizeOf(ResourcesHeader01)+SizeOf(Version)*2+SizeOf(TotalResources) + StoredResources*(SizeOf(TResourceInfo));
  end;
  if HDR = ResourcesHeader02 then begin
    for i := 0 to TotalResources-1 do begin
      ResourcesInfo[i].Resource := nil;
      if AStream.Read(ResourcesInfo[i].Name, SizeOf(ResourcesInfo[i].Name)) <> feOK then Exit;
      if AStream.Read(ResClassName, SizeOf(ResClassName)) <> feOK then Exit;
      ResourcesInfo[i].Kind := GetResourceClassIndex(ResClassName);
      if UpperCase(Copy(ResourcesInfo[i].Name, 1, 4)) = 'IND_' then Inc(ResourcesInfo[i].Kind);
      if AStream.Read(ResourcesInfo[i].Size, SizeOf(ResourcesInfo[i].Size)) <> feOK then Exit;
      if AStream.Read(ResourcesInfo[i].HeaderSize, SizeOf(ResourcesInfo[i].HeaderSize)) <> feOK then Exit;
      if AStream.Read(ResourcesInfo[i].Offset, SizeOf(ResourcesInfo[i].Offset)) <> feOK then Exit;
      if AStream.Read(ResourcesInfo[i].CreateTime, SizeOf(ResourcesInfo[i].CreateTime)) <> feOK then Exit;
    end;
    DataOffset := SizeOf(ResourcesHeader02)+SizeOf(Version)*2+SizeOf(TotalResources) + StoredResources*(SizeOf(TResourceInfo)-8+SizeOf(TShortName));
  end;

  if not CalcOffsets(True) then begin

    Log('ResM: Can''t load resource database', lkFatalError);
;
    Clear;
    Exit;
  end;

  for i := 0 to TotalResources-1 do with ResourcesInfo[i] do begin
    Resource := ResourceClasses[Kind].Create(Self, 0, Size, Kind);
    FResourceStatus[i] := rsDefault;
  end;

//  for i := 0 to TotalResources-1 do Resources[i].Status := rsMemory;

  CurrentOffset := ResourcesInfo[TotalResources-1].Offset + ResourcesInfo[TotalResources-1].Size + ResourcesInfo[TotalResources-1].HeaderSize;
  Result := feOK;
  Changed := False;
end;

procedure TResourceManager.Append(Resources: TResourceManager);
begin
end;

function TResourceManager.LoadInfo: Integer;
var HDR: TResourcesHeader; i: Integer;  ResClassName: TShortName;
begin
  Result := feCannotRead;
  if InputStream.Read(HDR, SizeOf(HDR)) <> feOK then Exit;
  if (HDR <> ResourcesHeader01) and (HDR <> ResourcesHeader02) then begin

    Log('ResM: Invalid resource file', lkFatalError);
;
    Result := feInvalidFileFormat;
    Exit;
  end;
  if InputStream.Read(FromVersion, SizeOf(Version)) <> feOK then Exit;
  if InputStream.Read(Version, SizeOf(Version)) <> feOK then Exit;

  if InputStream.Read(TotalResources, SizeOf(TotalResources)) <> feOK then Exit;
  StoredResources := TotalResources;

  SetLength(ResourcesInfo, TotalResources); SetLength(FResourceStatus, TotalResources);
  for i := 0 to TotalResources-1 do FResourceStatus[i] := rsDefault;

  if HDR = ResourcesHeader01 then begin

    Log('ResM: Old resource file version', lkWarning);
;
    if InputStream.Read(ResourcesInfo[0], TotalResources*SizeOf(TResourceInfo)) <> feOK then Exit;
    for i := 0 to TotalResources-1 do begin
      ResourcesInfo[i].Resource := nil;
      Dec(ResourcesInfo[i].Kind);
    end;
    DataOffset := SizeOf(ResourcesHeader01)+SizeOf(Version)*2+SizeOf(TotalResources) + StoredResources*(SizeOf(TResourceInfo));
  end;
  if HDR = ResourcesHeader02 then begin
    for i := 0 to TotalResources-1 do begin
      ResourcesInfo[i].Resource := nil;
      if InputStream.Read(ResourcesInfo[i].Name, SizeOf(ResourcesInfo[i].Name)) <> feOK then Exit;
      if InputStream.Read(ResClassName, SizeOf(ResClassName)) <> feOK then Exit;
      ResourcesInfo[i].Kind := GetResourceClassIndex(ResClassName);
      if UpperCase(Copy(ResourcesInfo[i].Name, 1, 4)) = 'IND_' then Inc(ResourcesInfo[i].Kind);
      if InputStream.Read(ResourcesInfo[i].Size, SizeOf(ResourcesInfo[i].Size)) <> feOK then Exit;
      if InputStream.Read(ResourcesInfo[i].HeaderSize, SizeOf(ResourcesInfo[i].HeaderSize)) <> feOK then Exit;
      if InputStream.Read(ResourcesInfo[i].Offset, SizeOf(ResourcesInfo[i].Offset)) <> feOK then Exit;
      if InputStream.Read(ResourcesInfo[i].CreateTime, SizeOf(ResourcesInfo[i].CreateTime)) <> feOK then Exit;
    end;
    DataOffset := SizeOf(ResourcesHeader02)+SizeOf(Version)*2+SizeOf(TotalResources) + StoredResources*(SizeOf(TResourceInfo)-8+SizeOf(TShortName));
  end;

  CurrentOffset := ResourcesInfo[TotalResources-1].Offset + ResourcesInfo[TotalResources-1].Size + ResourcesInfo[TotalResources-1].HeaderSize;
  Result := feOK;
  Changed := True;
end;

function TResourceManager.Save: Integer;                   //ToFix: Prevent cycling save-saveas
begin
  Result := SaveAs(InputStream);
end;

function TResourceManager.SaveAs(AStream: TStream): Integer;
var i, TotRes: Integer; ResClassName: TShortName;
begin
  Result := feCannotWrite;

  if AStream = InputStream then begin
    for i := 0 to TotalResources-1 do if ResourceStatus[i] <> rsDeleted then ResourceStatus[i] := rsMemory;
    if InputStream is TFileStream then begin
      (InputStream as TFileStream).Close;
      (InputStream as TFileStream).Open(fuWrite, fmOpenWrite);
    end;  
  end;

  if not CalcOffsets(True) then Exit;

  StartOffset := AStream.Position;

  if AStream.Write(ResourcesHeader02, SizeOf(ResourcesHeader02)) <> feOK then Exit;
  if AStream.Write(FromVersion, SizeOf(Version)) <> feOK then Exit;
  Inc(Version);
  if AStream.Write(Version, SizeOf(Version)) <> feOK then Exit;

  TotRes := TotalResources;
  for i := 0 to TotalResources-1 do if ResourceStatus[i] = rsDeleted then Dec(TotRes);

  if AStream.Write(TotRes, SizeOf(TotalResources)) <> feOK then Exit;

  for i := 0 to TotalResources-1 do if ResourceStatus[i] <> rsDeleted then begin
    if AStream.Write(ResourcesInfo[i].Name, SizeOf(ResourcesInfo[i].Name)) <> feOK then Exit;
    ResClassName := Resources[i].ClassName;
    if AStream.Write(ResClassName, SizeOf(ResClassName)) <> feOK then Exit;
    if AStream.Write(ResourcesInfo[i].Size, SizeOf(ResourcesInfo[i].Size)) <> feOK then Exit;
    if AStream.Write(ResourcesInfo[i].HeaderSize, SizeOf(ResourcesInfo[i].HeaderSize)) <> feOK then Exit;
    if AStream.Write(ResourcesInfo[i].Offset, SizeOf(ResourcesInfo[i].Offset)) <> feOK then Exit;
    if AStream.Write(ResourcesInfo[i].CreateTime, SizeOf(ResourcesInfo[i].CreateTime)) <> feOK then Exit;
  end;

  for i := 0 to TotalResources-1 do
   if ResourceStatus[i] <> rsDeleted then if Resources[i].Save(AStream) <> feOK then Exit;

  InputStream := AStream;

  Result := feOK;
  Changed := False;
end;

function TResourceManager.CalcOffsets(CalcDeleted: Boolean): Boolean;
var i: Integer;
begin
  Result := False;
  ResourcesInfo[0].Offset := 0;
  for i := 1 to TotalResources-1 do if ResourcesInfo[i-1].Kind < TotalResourceClasses then
   ResourcesInfo[i].Offset := ResourcesInfo[i-1].Offset +
    Cardinal(Ord((ResourceStatus[i-1] <> rsDeleted) or CalcDeleted)) *
    (ResourcesInfo[i-1].Size + ResourceClasses[ResourcesInfo[i-1].Kind].GetHeaderSize) else begin

    Log('ResM: Unknown class of resource "'+ResourcesInfo[i-1].Name+'"', lkFatalError);
;
    Exit;
  end;
  Result := True;
end;

function TResourceManager.IndexByName(const Name: TShortName): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to TotalResources-1 do if (UpperCase(ResourcesInfo[i].Name) = UpperCase(Name)) and (FResourceStatus[i] <> rsDeleted) then begin
    Result := i; Exit;
  end;
end;

function TResourceManager.IndexByResource(const Res: TResource): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to TotalResources-1 do if ResourcesInfo[i].Resource = Res then begin
    Result := i; Exit;
  end;
end;

function TResourceManager.ResourceByName(const Name: TShortName): TResource;
var i: Integer;
begin
  Result := nil;
  for i := 0 to TotalResources-1 do if ResourcesInfo[i].Name = Name then begin
    Result := Resources[i]; Exit;
  end;
end;

destructor TResourceManager.Free;
begin
  Clear;
  TotalResourceClasses := 0; SetLength(ResourceClasses, 0);
end;

function TResourceManager.GetResourceStatus(Index: Integer): Cardinal;
begin
  Result := FResourceStatus[Index];
end;

procedure TResourceManager.SetResourceStatus(Index: Integer; Value: Cardinal);
begin
  if (FResourceStatus[Index] = rsStream) and (Value = rsMemory) then begin
    if not InputStream.Seek(DataOffset + ResourcesInfo[Index].Offset) then Exit;
    if ResourcesInfo[Index].Resource.Load(InputStream) <> feOK then Exit;
  end;
  FResourceStatus[Index] := Value;
end;

{ TCharMapResource }

procedure TCharMapResource.Allocate(const ASize: Cardinal);
var ind: Integer;
begin
  if (ASize = Size) and (Data <> nil) then Exit;
  if Data <> nil then SetLength(TCharMap(Data), 0);
  Size := ASize;
  ind := Owner.IndexByResource(Self);
  if ind <> -1 then Owner.ResourcesInfo[ind].Size := Size;
  if Size = 0 then Data := nil else SetLength(TCharMap(Data), Size div SizeOf(TCharMapItem));
end;

constructor TCharMapResource.Create(const AOwner: TResourceManager; const AFormat, ASize, AKind: Cardinal);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TCharMapResource') else Kind := AKind;
end;

destructor TCharMapResource.Free;
begin
  if Data <> nil then SetLength(TCharMap(Data), 0);
  Data := nil;
end;

{ TScriptResource }

constructor TScriptResource.Create(const AOwner: TResourceManager; const AFormat, ASize, AKind: Cardinal);
begin
  inherited;
  if AKind = rkAuto then Kind := AOwner.GetResourceClassIndex('TScriptResource') else Kind := AKind;
end;

end.

