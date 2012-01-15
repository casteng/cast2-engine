unit EditWin;

interface

uses
  Logger, OSUtils, BaseTypes, Models, Props, Basics, BaseStr, Base2D, C2Types, Base3D, Resources,
  VCLHelper,
  ResizeF, AtF,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, ExtCtrls, Types,
  Menus, ImgList, ClipBrd, ComCtrls, StdCtrls, ExtDlgs, ActnList;

const
  EditFormat = pfA8R8G8B8;
  EditFormatBpP = 4;
// Combine filter operations
  foSet = 1; foAdd = 2; foMod = 3; foSub = 4;
  DefaultWidth = 512; DefaultHeight = 512;

  iemDraw = 1; iemMark = 2; iemSelX = 3; iemSelY = 4; iemSelW = 5; iemSelH = 6; iemSelXY = 7; iemSelWH = 8; iemSelWY = 9; iemSelXH = 10; iemFloodSelect = 11;

  mkAlt = 1; mkCTRL = 2;
  //
type
  TBrushBlend = (bbCopy, bbAdd, bbSub, bbMod);
  TBrushShape = (bsAir, bsSolid, bsRandom);
  TPaintTool  = (ptBrush, ptClone, ptSelect);
const
  BrushBlendsEnum = 'Copy' + StrDelim + 'Add' + StrDelim + 'Modulate' + StrDelim + 'Substract';
  BrushShapesEnum = 'Air' + StrDelim + 'Solid' + StrDelim + 'Random';
  ToolsEnum = 'Brush' + StrDelim + 'Clone' + StrDelim + 'Select';

type
  PARGB = ^TARGB;
  
  TEditForm = class(TForm)
    ScBarH: TScrollBar;
    ScBarV: TScrollBar;
    ActDeselect: TAction;
    ActNextLevel: TAction;
    ActPrevLevel: TAction;
    N3: TMenuItem;
    Prevlevel1: TMenuItem;
    Nextlevel1: TMenuItem;
    PnlTools: TPanel;
    Label1: TLabel;
    BSizeTracker: TProgressBar;
    BTransTracker: TProgressBar;
    ActImgUndo: TAction;
    ActImgRedo: TAction;
    BrushSize: TEdit;
    BrushShape: TComboBox;
    BrushTrans: TEdit;
    BrushBlend: TComboBox;
    PaintTool: TComboBox;
    procedure ScrollBox1Resize(Sender: TObject);
    procedure ScBarChange(Sender: TObject);
    procedure ScBarScroll(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
    procedure ActPrevLevelExecute(Sender: TObject);
    procedure ActNextLevelExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ActImgUndoExecute(Sender: TObject);
    procedure ActImgRedoExecute(Sender: TObject);
    procedure BrushSizeKeyPress(Sender: TObject; var Key: Char);
    procedure BrushTransKeyPress(Sender: TObject; var Key: Char);
    procedure CBoxChange(Sender: TObject);
  private
    BrushProps: Props.TProperties;
    PaintBrush: Base2D.TBrush;
    ImageSource: TBaseImageSource;
    CloneStartX, CloneStartY: Integer;
    
    FResource: Resources.TImageResource;
    FChanged: Boolean;
    ImgEditMode: Integer;
    FTotalLevels,
    FViewLevel,
    FDataSize,                          // Total data size
    FBufSize: Integer;                  // Temporary buffer size
    FImgWidth, FImgHeight: Integer;
    FBuffer: PImageBuffer;               // Data of image associated with the edit form
    FLevels: TImageLevels;
    FLastMMX, FLastMMY: Integer;
    function GetFileLWTime(Filename: string): Int64;
    procedure SetChanged(const Value: Boolean);

    function GetXPos: Integer;                  // Image view X offset
    function GetYPos: Integer;                  // Image view Y offset

    procedure CopyToBitmap(const ARect: BaseTypes.TRect; ABitmap: TBitmap; XOfs, YOfs: Integer);  // Copies a rectangular area of image to the specified place in TImage
    procedure ClientToImage(var X, Y: Integer); // Converts coordinates in client system to coordinates in image system
    procedure CorrectView;                      // Corrects offsets if needed and show/hide scroll bars
    procedure SetViewLevel(const Value: Integer);
    function GetLevelHeight: Integer;
    function GetLevelWidth: Integer;
    procedure UpdateFormCaption;
    procedure InitPaintBrush;
    procedure UpdateBrushImage(X, Y: Integer);
    procedure UpdateBrushShape;
    procedure InitImageSource;
    procedure HandleApplyOperation;
    function AddOperation(AOperation: Models.TOperation): Boolean;
    function GetOperation: TPaintTool;          
  published
    ScrollBox1: TScrollBox;
    Image1: TImage;
    MainMenu1: TMainMenu;
    FileMenu: TMenuItem;
    EditMenu: TMenuItem;
    MenuNew: TMenuItem;
    MenuOpen: TMenuItem;
    MenuSaveAs: TMenuItem;
    MenuClose: TMenuItem;
    MenuResize: TMenuItem;
    Color: TMenuItem;
    Alpha: TMenuItem;
    MenuOpenAt: TMenuItem;
    MenuSave: TMenuItem;
    ViewMenu: TMenuItem;
    MenuViewAlpha: TMenuItem;
    MenuMkAlpha: TMenuItem;
    ImageList1: TImageList;
    MenuCopy: TMenuItem;
    MenuPaste: TMenuItem;
    Undo1: TMenuItem;
    Redo1: TMenuItem;
    OpenPictureDialog: TOpenPictureDialog;
    SavePictureDialog: TSavePictureDialog;
    Timer1: TTimer;
    Ontop1: TMenuItem;
    Deselect1: TMenuItem;
    ColorDialog1: TColorDialog;
    ActionList1: TActionList;
    ActImgMakeAlpha: TAction;
    ActImgMakeNMap: TAction;
    Makenormalmap1: TMenuItem;
    ActImgApply: TAction;
    N1: TMenuItem;
    N2: TMenuItem;
    Apply1: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure CheckChanges;
    procedure Image1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Image1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormDeactivate(Sender: TObject);
    procedure Close1Click(Sender: TObject);
    procedure MenuResizeClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ColorClick(Sender: TObject);
    procedure ColorAdvancedDrawItem(Sender: TObject; ACanvas: TCanvas; ARect: TRect; State: TOwnerDrawState);
    procedure FormActivate(Sender: TObject);
    procedure LoadImage(FileName: string; XO, YO: Integer);
    procedure MenuOpenClick(Sender: TObject);
    procedure MenuSaveAsClick(Sender: TObject);
    procedure MenuCloseClick(Sender: TObject);
    procedure MenuNewClick(Sender: TObject);
    procedure MenuOpenAtClick(Sender: TObject);
    procedure Image1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MenuSaveClick(Sender: TObject);
    procedure MenuViewAlphaClick(Sender: TObject);
    procedure AlphaClick(Sender: TObject);
    procedure AlphaAdvancedDrawItem(Sender: TObject; ACanvas: TCanvas; ARect: TRect; State: TOwnerDrawState);
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuPasteClick(Sender: TObject);

    procedure MakeAlpha(Rect: BaseTypes.TRect);
    procedure BTrackerMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BTrackerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Timer1Timer(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure Ontop1Click(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Deselect1Click(Sender: TObject);
    procedure ActDeselectExecute(Sender: TObject);

    procedure ActImgMakeAlphaExecute(Sender: TObject);
    procedure ActImgMakeNMapExecute(Sender: TObject);
    procedure ActImgApplyExecute(Sender: TObject);
  public
    ImgName: TShortName;
    ImgFileName: string;
    ImgFileDateTime: Int64;
    FormIndex: Integer;

    Format: Integer;

    ViewAlpha: Boolean;

    Selected, LastSelected: BaseTypes.TRect;
    TextureInd: Integer;

    OperationManager: TOperationManager;

    procedure CopyFromBitmap(ARect: BaseTypes.TRect; ABitmap: TBitmap; XOfs, YOfs: Integer);  // Copies a rectangular area from to the specified place in TImage
    procedure DrawOnWindow(MX, MY: Word);
    procedure DrawSelRect;
    procedure DelSelRect;
    procedure Init(NewWidth, NewHeight: Integer; AResource: TImageResource; NewBuffer: Pointer = nil); // Resizes buffer according to new image size
    procedure Redraw(Rect: BaseTypes.TRect); overload;

    function GetImgEditMode(ModKeys: Integer; X, Y: Integer): Integer;
    procedure SetModeCursor(Mode: Integer);
    function GetKeyMods: Integer;
    function GetFloodRect(FloodX, FloodY: Integer): BaseTypes.TRect;
    procedure UpdateStatus;

    procedure SetResource(AResource: Resources.TImageResource);

    procedure Redraw; overload;
    procedure Apply;                                      // Applies image to resource
    function CheckRect(const CRect: BaseTypes.TRect): BaseTypes.TRect;
    procedure Cleanup;

    property DataChanged: Boolean read FChanged write SetChanged;

    property TotalLevels: Integer read FTotalLevels;
    property ViewLevel: Integer read FViewLevel write SetViewLevel;

    property LevelWidth: Integer  read GetLevelWidth;
    property LevelHeight: Integer read GetLevelHeight;
    property ImageWidth: Integer  read FImgWidth;
    property ImageHeight: Integer read FImgHeight;
    property Buffer: PImageBuffer read FBuffer;               // Data of image associated with the edit form

    property Operation: TPaintTool read GetOperation;
  end;

//  function Blend(V1, V2, K: Single): Single;

var
  EditForm: TEditForm;
  Filters: array of TImageFilterFunction;

implementation

uses Mainform, FImages, FNormMap, C2EdMain;//, FImages, HForm;

type
  TScanLine = array[0..65535] of DWord;

{$R *.dfm}

function Blend(V1, V2, K: Single): Single;
begin
  Result := V1 * (1-K) + V2 * K;
end;

procedure Rectangle(X1, Y1, X2, Y2: Integer; Color: DWord; Where: TBitmap);
var i, t: Integer; Scan: ^TScanLine;
begin
  if Where = nil then Exit;

  t := X1;
  X1 := MinI(X1, X2);
  X2 := MaxI(t,  X2);
  t := Y1;
  Y1 := MinI(Y1, Y2);
  Y2 := MaxI(t,  Y2);

  if (Y1 >= 0) and (Y1 < Where.Height) then begin
    Scan := Where.ScanLine[Y1];
    for i := MaxI(0, X1) to MinI(Where.Width-1, X2-1) do Scan^[i] := Color;
  end;
  if (Y2 >= 0) and (Y2 < Where.Height) then begin
    Scan := Where.ScanLine[Y2];
    for i := MaxI(0, X1) to MinI(Where.Width-1, X2-1) do Scan^[i] := Color;
  end;
  for i := MaxI(0, Y1) to MinI(Where.Height-1, Y2-1) do begin
    Scan := Where.ScanLine[i];
    if (X1 >= 0) and (X1 < Where.Width) then Scan^[X1] := Color;
    if (X2 >= 0) and (X2 < Where.Width) then Scan^[X2] := Color;
  end;
end;

procedure TEditForm.SetChanged(const Value: Boolean);
begin
  FChanged := Value;
  UpdateFormCaption;
end;

function TEditForm.GetXPos: Integer;
begin
  Result := ScBarH.Position-1;
end;

function TEditForm.GetYPos: Integer;
begin
  Result := ScBarV.Position-1;
end;

procedure TEditForm.CopyToBitmap(const ARect: BaseTypes.TRect; ABitmap: TBitmap; XOfs, YOfs: Integer);
var i, j: Integer; Scan: ^TScanLine; PTemp: ^BaseTypes.TColor;
begin
  if not Assigned(ABitmap) or
    (not (FResource is TMegaImageResource) and (Buffer = nil)) then Exit;

  if FResource is TMegaImageResource then begin
    for j := ARect.Top to ARect.Bottom-1 do begin
      TMegaImageResource(FResource).LoadSeq(ARect.Left, j, ARect.Right-ARect.Left, ViewLevel, Buffer);
      ConvertImage(FResource.Format, EditFormat, ARect.Right-ARect.Left, Buffer, 0, nil, PtrOffs(ABitmap.ScanLine[j-ARect.Top + YOfs], XOfs * EditFormatBpP))
    end;
  end else begin
    if ViewAlpha then begin
      for j := ARect.Top to ARect.Bottom-1 do begin
        PTemp := PtrOffs(Buffer, FLevels[ViewLevel].Offset + (j*LevelWidth+ARect.Left) * EditFormatBpP);
        Scan := ABitmap.ScanLine[j-ARect.Top + YOfs];
        for i := ARect.Left to ARect.Right-1 do begin
          Scan^[i-ARect.Left+XOfs] := PTemp^.A shl 16 + PTemp^.A shl 8 + PTemp^.A;
          Inc(PTemp);
        end;
      end;
    end else for j := ARect.Top to ARect.Bottom-1 do begin
      PTemp := PtrOffs(Buffer, FLevels[ViewLevel].Offset + (j*LevelWidth+ARect.Left) * EditFormatBpP);
      Move(PTemp^, PtrOffs(ABitmap.ScanLine[j-ARect.Top + YOfs], XOfs * EditFormatBpP)^, (ARect.Right - ARect.Left)*EditFormatBpP);
    end;
  end;
end;

procedure TEditForm.CopyFromBitmap(ARect: BaseTypes.TRect; ABitmap: TBitmap; XOfs, YOfs: Integer);
var i, j: Integer; Scan: ^TScanLine; PTemp: ^BaseTypes.TColor;
begin
  RectIntersect(ARect, GetRect(0, 0, ABitmap.Width, ABitmap.Height), ARect);
  RectIntersect(ARect, GetRect(0, 0, LevelWidth - XOfs, LevelHeight - YOfs), ARect);
  if ViewAlpha then begin
    for j := ARect.Top to ARect.Bottom-1 do begin
      PTemp := PtrOffs(Buffer, FLevels[ViewLevel].Offset + ((j - ARect.Top + YOfs)*LevelWidth + XOfs - ARect.Left) * EditFormatBpP);
      Scan := ABitmap.ScanLine[j];
      for i := ARect.Left to ARect.Right-1 do begin
        PTemp^.A := GetIntensity(BaseTypes.GetColor(Scan^[i]));
        Inc(PTemp);
      end;
    end;
  end else begin
    for j := ARect.Top to ARect.Bottom-1 do begin
      PTemp := PtrOffs(Buffer, FLevels[ViewLevel].Offset + ((j - ARect.Top + YOfs)*LevelWidth + XOfs - ARect.Left) * EditFormatBpP);
      Scan := ABitmap.ScanLine[j];
      for i := ARect.Left to ARect.Right-1 do begin
        PTemp^ := BaseTypes.GetColor(Scan^[i]);
        Inc(PTemp);
      end;
    end;
  end;
end;

procedure TEditForm.ClientToImage(var X, Y: Integer);
begin
  X := Basics.ClampI(X + GetXPos, 0, LevelWidth-1);
  Y := Basics.ClampI(Y + GetYPos, 0, LevelHeight-1);
end;

procedure TEditForm.CorrectView;

  procedure CorrectSB(ASB: TScrollBar);
  begin
    if ASB.Position > ASB.Max - ASB.PageSize+1 then ASB.Position := ASB.Max - ASB.PageSize+1;
  end;

var
  NewWidth, NewHeight, SBMax: Integer;
begin
  NewWidth  := MaxI(0, MinI(LevelWidth,  ScBarV.Left -1));// ScrollBox1.ClientWidth  - ScBarV.Width  - 2);
  NewHeight := MaxI(0, MinI(LevelHeight, ScBarH.Top  -1)); // ScrollBox1.ClientHeight - ScBarH.Height - 2);

  SBMax := LevelWidth;
  if SCBarH.Max > NewWidth then SCBarH.PageSize := NewWidth;
  SCBarH.Max         := SBMax;
  SCBarH.PageSize    := NewWidth;
  SCBarH.LargeChange := MaxI(1, NewWidth);
  SCBarH.SmallChange := MaxI(1, NewWidth div 10);

  SBMax := LevelHeight;
  if SCBarV.Max > NewHeight then SCBarV.PageSize := NewHeight;
  ScBarV.Max         := SBMax;
  SCBarV.PageSize    := NewHeight;
  SCBarV.LargeChange := MaxI(1, NewHeight);
  SCBarV.SmallChange := MaxI(1, NewHeight div 10);

  if (NewWidth <> Image1.Width) or (NewHeight <> Image1.Height) then begin
    Image1.Width  := NewWidth;
    Image1.Height := NewHeight;
    Image1.Picture.Bitmap.Width  := Image1.Width;
    Image1.Picture.Bitmap.Height := Image1.Height;
    Redraw;
    DrawSelRect;
    Image1.Repaint;
  end;
  CorrectSB(SCBarH);
  CorrectSB(SCBarV);
end;

procedure TEditForm.ScBarChange(Sender: TObject);
begin
  Redraw;
  DrawSelRect;
  Image1.Repaint;
end;

procedure TEditForm.ScBarScroll(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
begin
  if ScrollPos > TScrollBar(Sender).Max - TScrollBar(Sender).PageSize+1 then ScrollPos := TScrollBar(Sender).Max - TScrollBar(Sender).PageSize+1;
end;

procedure TEditForm.ActPrevLevelExecute(Sender: TObject);
begin
  ViewLevel := ViewLevel - 1;
end;

procedure TEditForm.ActNextLevelExecute(Sender: TObject);
begin
  ViewLevel := ViewLevel + 1;
end;

procedure TEditForm.FormDestroy(Sender: TObject);
begin
  FreeMem(Buffer);
  FreeAndNil(OperationManager);
end;

procedure TEditForm.SetViewLevel(const Value: Integer);
begin
  if FViewLevel = ClampI(Value, 0, TotalLevels-1) then Exit;
  FViewLevel := ClampI(Value, 0, TotalLevels-1);
  CorrectView;
  Redraw;
  DrawSelRect;
  ScrollBox1.Repaint;
  UpdateFormCaption
end;

function TEditForm.GetLevelHeight: Integer;
begin
//  if Assigned(FResource) then Result := FResource.LevelInfo[ViewLevel].Height else Result := ImageHeight;
  Result := MaxI(1, ImageHeight div (1 shl ViewLevel));
end;

function TEditForm.GetLevelWidth: Integer;
begin
//  if Assigned(FResource) then Result := FResource.LevelInfo[ViewLevel].Width else
  Result := MaxI(1, ImageWidth div (1 shl ViewLevel));
end;

procedure TEditForm.MakeAlpha(Rect: BaseTypes.TRect);
var i, j: Integer; PTemp: ^BaseTypes.TColor;
begin
  Rect := CheckRect(Rect);
  for j := Rect.Top to Rect.Bottom-1 do for i := Rect.Left to Rect.Right-1 do begin
    PTemp := PtrOffs(Buffer, FLevels[ViewLevel].Offset + (j * LevelWidth + i) * EditFormatBpP);
    PTemp^.A := GetIntensity(PTemp^) * Ord((PTemp^.C and $00FFFFFF) <> $00FF00FF);
  end;
  DataChanged := True;
  ReDraw(Rect);
  DrawSelRect;
end;

procedure TEditForm.DrawOnWindow(MX, MY: Word);
var
  SX, SY: Integer;
  DRect: BaseTypes.TRect;
  Op: Base2D.TImageOperation;
begin
  SX := MX;
  SY := MY;

  if Operation = ptClone then UpdateBrushImage(SX, SY);

//  EditMask := $FF000000 * Cardinal(Ord(ViewAlpha)) + $FFFFFF * Cardinal(Ord(not ViewAlpha));
  DRect := CheckRect(GetRectWH(SX-PaintBrush.Width div 2, SY-PaintBrush.Height div 2, PaintBrush.Width, PaintBrush.Height));

  if (FResource is TMegaImageResource) then
    Op := TMegaImagePaintOp.Create(SX-PaintBrush.Width div 2, SY-PaintBrush.Height div 2, TMegaImageResource(FResource), ViewLevel, PaintBrush, DRect)
  else
    Op := TImagePaintOp.Create(SX-PaintBrush.Width div 2, SY-PaintBrush.Height div 2, Buffer, ImageWidth, EditFormat, PaintBrush, DRect);
  AddOperation(Op);
end;

procedure TEditForm.DrawSelRect;
begin
  with Selected do begin
    if (Left = Right) or (Top = Bottom) then Exit;
  end;
  Rectangle(Selected.Left - GetXPos, Selected.Top - GetYPos, Selected.Right - GetXPos, Selected.Bottom - GetYPos, $FFFFFF, Image1.Picture.Bitmap);
  LastSelected := Selected;
end;

procedure TEditForm.DelSelRect;
begin
  with Selected do begin
    if (Left = Right) or (Top = Bottom) then Exit;
    Redraw(GetRect(Basics.MinI(Left, Right), Basics.MinI(Top, Bottom), Basics.MaxI(Left, Right)+1, Basics.MinI(Top, Bottom)+1));
    Redraw(GetRect(Basics.MinI(Left, Right), Basics.MaxI(Top, Bottom), Basics.MaxI(Left, Right)+1, Basics.MaxI(Top, Bottom)+1));
    Redraw(GetRect(Basics.MinI(Left, Right), Basics.MinI(Top, Bottom), Basics.MinI(Left, Right)+1, Basics.MaxI(Top, Bottom)+1));
    Redraw(GetRect(Basics.MaxI(Left, Right), Basics.MinI(Top, Bottom), Basics.MaxI(Left, Right)+1, Basics.MaxI(Top, Bottom)+1));
//    Redraw(GetRect(Trunc(0.5+ViewX), Trunc(0.5+ViewZ), Trunc(0.5+ViewX), Trunc(0.5+ViewZ)));
  end;
end;

procedure TEditForm.Init(NewWidth, NewHeight: Integer; AResource: TImageResource; NewBuffer: Pointer = nil);
var i: Integer;
begin
  DataChanged := False;
  FImgWidth  := NewWidth;
  FImgHeight := NewHeight;

  FTotalLevels := GetSuggestedMipLevelsInfo(FImgWidth, FImgHeight, EditFormat, FLevels);
  if Assigned(AResource) then FTotalLevels := AResource.ActualLevels;

  FViewLevel := 0;
  FResource  := AResource;

  FDataSize := 0;
  for i := 0 to FTotalLevels-1 do Inc(FDataSize, FLevels[i].Size);

  if FBuffer <> nil then FreeMem(FBuffer);
  FBuffer := nil;

  FBufSize := FDataSize;

  if NewBuffer <> nil then
    FBuffer := NewBuffer
  else begin
    if (AResource is TMegaImageResource) then FBufSize := AResource.Width * GetBytesPerPixel(AResource.Format);
    GetMem(FBuffer, FBufSize);
    FillChar(FBuffer^, FBufSize, 0);
  end;

  InitImageSource;

  CorrectView;
end;

procedure TEditForm.Redraw(Rect: BaseTypes.TRect);
var VisRect: BaseTypes.TRect; xo, yo: Integer;
begin
  if Rect.Left   < 0 then Rect.Left := 0;
  if Rect.Top    < 0 then Rect.Top := 0;
  if Rect.Right  > LevelWidth  then Rect.Right  := LevelWidth;
  if Rect.Bottom > LevelHeight then Rect.Bottom := LevelHeight;

  xo := GetXPos;
  yo := GetYPos;
  VisRect.Left   := xo;
  VisRect.Top    := yo;
  VisRect.Right  := VisRect.Left + Image1.Width;
  VisRect.Bottom := VisRect.Top  + Image1.Height;

//  RectIntersect(Rect, VisRect, VisRect);

  CopyToBitmap(VisRect, Image1.Picture.Bitmap, VisRect.Left - xo, VisRect.Top - yo);
end;

procedure TEditForm.Redraw;
begin
  Redraw(GetRect(0, 0, LevelWidth, LevelHeight));
end;

procedure TEditForm.Apply;
begin
  if FResource is TMegaImageResource or
     (FResource is TImageResource) and Base2D.ConvertImage(Format, FResource.Format, FResource.TotalElements, Buffer, 0, nil, FResource.Data) then begin
    DataChanged := False;
    Core.SendMessage(TResourceModifyMsg.Create(FResource), FResource, [mfCore, mfRecipient]);
  end;
end;

function TEditForm.CheckRect(const CRect: BaseTypes.TRect): BaseTypes.TRect;
begin
  with Selected do
    if (Left = Right) or (Top = Bottom) then Result := GetRect(0, 0, LevelWidth, LevelHeight)
    else Result := GetCorrectRect(Left, Top, Right, Bottom);
  Result.Left := MaxI(Result.Left, CRect.Left); Result.Right := MinI(Result.Right, CRect.Right);
  Result.Top  := MaxI(Result.Top, CRect.Top); Result.Bottom := MinI(Result.Bottom, CRect.Bottom);
end;

procedure TEditForm.FormCreate(Sender: TObject);
begin
  PaintBrush := Base2D.TBrush.Create;
  BrushProps := TProperties.Create;

  BrushProps.AddEnumerated('BrushBlend', [], 0, BrushBlendsEnum);
  BrushProps.AddEnumerated('BrushShape', [], 0, BrushShapesEnum);
  BrushProps.AddEnumerated('PaintTool',  [], 0, ToolsEnum);
  BrushProps.Add('BrushSize',    vtInt,    [], BrushSize.Text,  '');
  BrushProps.Add('BrushTrans',   vtInt,    [], BrushTrans.Text, '');
  BrushProps.Add('BrushDensity', vtInt,    [], '20', '');

  GUIHelper.ConfigToForm(Name, BrushProps);

  OperationManager := TOperationManager.Create;
  ImgFileName := '';
  FormIndex := -1;
  TextureInd := -1;
  Image1.Picture.Bitmap.PixelFormat := pf32bit;
  Format := EditFormat;
  ScrollBox1.ControlStyle := [];
  DataChanged := False;
  PaintBrush.Color.C := $FFFFFFFF;
  Visible := True;
  ViewAlpha := False;
  Image1.PopupMenu := ImagesForm.ImagesCMenu;
  ImgEditMode := iemDraw;
  InitPaintBrush;
end;

function TEditForm.GetImgEditMode(ModKeys: Integer; X, Y: Integer): Integer;
const SelEdittolerance = 4;
begin
  if ModKeys and mkCtrl > 0 then begin
    Result := iemFloodSelect; Exit;
  end;
  if (Operation = ptSelect) or (ModKeys and mkAlt > 0) then Result := iemMark else Result := iemDraw;

  if (Selected.Left <> Selected.Right) and (Selected.Top <> Selected.Bottom) then begin
    if (Abs(X - Selected.Left) < SelEdittolerance) and (Y > Selected.Top) and (Y < Selected.Bottom) then Result := iemSelX;
    if (Abs(Y - Selected.Top) < SelEdittolerance) and (X > Selected.Left) and (X < Selected.Right) then Result := iemSelY;
    if (Abs(X - Selected.Right) < SelEdittolerance) and (Y > Selected.Top) and (Y < Selected.Bottom) then Result := iemSelW;
    if (Abs(Y - Selected.Bottom) < SelEdittolerance) and (X > Selected.Left) and (X < Selected.Right) then Result := iemSelH;
    if (X > Selected.Left-SelEdittolerance) and (X < Selected.Left+SelEdittolerance) and (Y > Selected.Top-SelEdittolerance) and (Y < Selected.Top+SelEdittolerance) then Result := iemSelXY;
    if (X > Selected.Right-SelEdittolerance) and (X < Selected.Right+SelEdittolerance) and (Y > Selected.Bottom-SelEdittolerance) and (Y < Selected.Bottom+SelEdittolerance) then Result := iemSelWH;
    if (X > Selected.Right-SelEdittolerance) and (X < Selected.Right+SelEdittolerance) and (Y > Selected.Top-SelEdittolerance) and (Y < Selected.Top+SelEdittolerance) then Result := iemSelWY;
    if (X > Selected.Left-SelEdittolerance) and (X < Selected.Left+SelEdittolerance) and (Y > Selected.Bottom-SelEdittolerance) and (Y < Selected.Bottom+SelEdittolerance) then Result := iemSelXH;
  end;
end;

procedure TEditForm.Image1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  ClientToImage(X, Y);
  if (FLastMMX = X) and (FLastMMY = Y) then Exit;

  if ssLeft in Shift then case ImgEditMode of
    iemDraw: begin
      DrawOnWindow(X, Y);
    end;
    iemMark..iemSelXH: begin
      DelSelRect;

      case ImgEditMode of
        iemMark, iemSelWH: begin Selected.Right := X; Selected.Bottom := Y; end;
        iemSelX: Selected.Left   := X;
        iemSelW: Selected.Right  := X;
        iemSelY: Selected.Top    := Y;
        iemSelH: Selected.Bottom := Y;
        iemSelXY: begin Selected.Left  := X; Selected.Top    := Y; end;
        iemSelWY: begin Selected.Right := X; Selected.Top    := Y; end;
        iemSelXH: begin Selected.Left  := X; Selected.Bottom := Y; end;
      end;

      DrawSelRect;
      UpdateStatus;
      Image1.Repaint;
    end;
  end;

  FLastMMX := X;
  FLastMMY := Y;

{  if ((ssShift in Shift) xor ImagesForm.TrackBox.Checked) and ((ImagesForm.HMapIndex = FormIndex) or (ImagesForm.CMapIndex = FormIndex)) then begin
    ViewX := X*HMap.TileSize - HMap.MapHalfWidth; ViewZ := (HMap.MapHeight-1-Y)*HMap.TileSize - HMap.MapHalfHeight;
  end;}
end;

procedure TEditForm.Image1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  ClientToImage(X, Y);

  ImgEditMode := GetImgEditMode(GetKeyMods, X, Y);
  SetModeCursor(ImgEditMode);

  if mbRight = Button then begin
    ImagesForm.SetCloneAnchor(FormIndex, X, Y);
    CloneStartX  := X;
    CloneStartY  := Y;
    UpdateBrushImage(CloneStartX, CloneStartY);
  end;

  if mbLeft = Button then begin
    DelSelRect;
    if ImgEditMode = iemDraw then begin
      CloneStartX  := X;
      CloneStartY  := Y;
      DrawOnWindow(X, Y);
    end else if ImgEditMode = iemMark then Selected := GetRect(X, Y, X, Y)
    else if ImgEditMode = iemFloodSelect then Selected := GetFloodRect(X, Y);
    DrawSelRect;
    UpdateStatus;
    Image1.Repaint;
  end; 
end;

procedure TEditForm.FormDeactivate(Sender: TObject);
begin
  ScrollBox1.Repaint;
end;

procedure TEditForm.Close1Click(Sender: TObject);
begin
  Close;
end;

procedure TEditForm.MenuCopyClick(Sender: TObject);
var Bitmap: TBitmap; Rect: BaseTypes.TRect;
begin
  DelSelRect;
  Bitmap := TBitmap.Create;
  Rect := CheckRect(GetRect(0, 0, LevelWidth, LevelHeight));
  try
    Bitmap.Width  := Rect.Right  - Rect.Left;
    Bitmap.Height := Rect.Bottom - Rect.Top;
    Bitmap.PixelFormat := pf32bit;
    CopyToBitmap(Rect, Bitmap, 0, 0);
//  TPic.Bitmap.Canvas.CopyRect(Classes.Rect(0, 0, TPic.Bitmap.Width, TPic.Bitmap.Height), Image1.Picture.Bitmap.Canvas, Classes.Rect(Rect.Left, Rect.Top, Rect.Right, Rect.Bottom));
    ClipBoard.Assign(Bitmap);
  finally
    FreeAndNil(Bitmap);
  end;  
  DrawSelRect;
end;

procedure TEditForm.MenuPasteClick(Sender: TObject);
var Bitmap: TBitmap; Rect: BaseTypes.TRect;
begin
  if not ClipBoard.HasFormat(CF_BITMAP) then Exit;
  DelSelRect;
  Bitmap := TBitmap.Create;
  Bitmap.PixelFormat := pf32bit;
  Bitmap.Assign(ClipBoard);
  Rect := CheckRect(GetRect(Selected.Left, Selected.Top, Selected.Left + Bitmap.Width, Selected.Top + Bitmap.Height));

  CopyFromBitmap(GetRect(0, 0, MinI(Bitmap.Width,  Rect.Right  - Rect.Left),
                               MinI(Bitmap.Height, Rect.Bottom - Rect.Top)),
                 Bitmap, Rect.Left, Rect.Top);

  FreeAndNil(Bitmap);
  ReDraw;
  DrawSelRect;
  ScrollBox1.Repaint;
  DataChanged := True;
end;

procedure TEditForm.MenuResizeClick(Sender: TObject);
var Buf: PImageBuffer; W, H: Integer; OldAspectBox: Boolean;
begin
  with ResizeForm do begin
    OldAspectBox := AspectBox.Checked;
    AspectBox.Checked := False;
    AspectRatio := 0;
    Edit1.Text := IntToStr(LevelWidth);
    Edit2.Text := IntToStr(LevelHeight);
    AspectBox.Checked := OldAspectBox;
    if ShowModal <> mrOK then Exit;
    W := StrToInt(Edit1.Text);
    H := StrToInt(Edit2.Text);
  end;
  if (W = LevelWidth) and (H = LevelHeight) then Exit;

  GetMem(Buf, W * H * EditFormatBpP);

  if ResizeImage(TImageResizeFilter(ResizeForm.FilterBox.ItemIndex), StrToFloatDef(ResizeForm.Edit3.Text, 1),
                 EditFormat, Buffer, GetRect(0, 0, LevelWidth, LevelHeight), LevelWidth,
                             Buf,    GetRect(0, 0, W, H),                    W) then begin
    Init(W, H, nil, Buf);
    Redraw();
    DrawSelRect();
    ScrollBox1.Repaint();
    DataChanged := True;
  end;  
end;

procedure TEditForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := DeleteImageWindow(FormIndex);
end;

procedure TEditForm.ColorClick(Sender: TObject);
begin
  ColorDialog1.Color :=  ColorToVCLColor(PaintBrush.Color);
  if ColorDialog1.Execute then PaintBrush.Color.C := VCLColorToColor(ColorDialog1.Color).C and $FFFFFF or (PaintBrush.Color.C and $FF000000);
  Color.Enabled := False;
  Color.Enabled := True;
  InitPaintBrush;
end;

procedure TEditForm.AlphaClick(Sender: TObject);
begin
  ColorDialog1.Color := ColorToVCLColor(PaintBrush.Color);
  if ColorDialog1.Execute then PaintBrush.Color := GetColor(PaintBrush.Color.R, PaintBrush.Color.G, PaintBrush.Color.B, GetIntensity(BaseTypes.GetColor(ColorDialog1.Color)));
  Alpha.Enabled := False;
  Alpha.Enabled := True;
  InitPaintBrush;
end;

procedure TEditForm.ColorAdvancedDrawItem(Sender: TObject; ACanvas: TCanvas; ARect: TRect; State: TOwnerDrawState);
begin
  ACanvas.Brush.Color := ColorToVCLColor(PaintBrush.Color);
  ACanvas.Pen.Color := 0;
  ACanvas.Rectangle(ARect);
end;

procedure TEditForm.AlphaAdvancedDrawItem(Sender: TObject; ACanvas: TCanvas; ARect: Types.TRect; State: TOwnerDrawState);
begin
  ACanvas.Brush.Color := PaintBrush.Color.A shl 16 + PaintBrush.Color.A shl 8 + PaintBrush.Color.A;
  ACanvas.Pen.Color := 0;
  ACanvas.Rectangle(ARect);
end;

procedure TEditForm.FormActivate(Sender: TObject);
begin
//  ImagesForm.ImageList.ClearSelection;
//  ImagesForm.ImageList.Selected[FormIndex] := True;
  ScBarH.Top    := ScrollBox1.Height - ScBarH.Height - 2;
  ScBarV.Left   := ScrollBox1.Width  - ScBarV.Width  - 2;

  ScBarH.Width  := ScBarV.Left;
  ScBarV.Height := ScBarH.Top;

  Image1.Left := 0;
  Image1.Top  := 0;

  CheckChanges;
end;

procedure TEditForm.LoadImage(FileName: string; XO, YO: Integer);
var TPic, Pic2: TPicture;
begin
  TPic := TPicture.Create;
  Pic2 := TPicture.Create;
  Pic2.Bitmap.PixelFormat := pf32bit;
  
  ImgFileName := OpenPictureDialog.FileName;
  TPic.LoadFromFile(ImgFileName);
  if TPic.Width <> 0 then
    Log('Picture loaded')
  else begin
    Log('Error loading file "' + FileName + '"');
    Exit;
  end;
  Pic2.Bitmap.Width  := TPic.Width;
  Pic2.Bitmap.Height := TPic.Height;
  Pic2.Bitmap.Canvas.Draw(0, 0, TPic.Graphic);
  FreeAndNil(TPic);

  ImgFileDateTime := GetFileLWTime(ImgFileName);

  ImgName := ExtractFileName(ImgFileName);
  UpdateFormCaption;
  ImagesForm.ImageList.Items[FormIndex] := IntToStr(FormIndex) + ' ' + ImgName;
  if (Pic2.Width <> LevelWidth) or (Pic2.Height <> LevelHeight) then
    Init(Pic2.Width, Pic2.Height, nil);
  CopyFromBitmap(GetRect(0, 0, Pic2.Width, Pic2.Height), Pic2.Bitmap, XO, YO);
  FreeAndNil(Pic2);
  ClientWidth  := MinI(512, LevelWidth+6);
  ClientHeight := MinI(512, ScrollBox1.Top + LevelHeight+6);
  ImagesForm.ImageList.Selected[FormIndex] := True;
  Redraw();
  DrawSelRect();
  ScrollBox1.Repaint();
  DataChanged := False;
end;

procedure TEditForm.MenuOpenClick(Sender: TObject);
begin
  if OpenPictureDialog.Execute then LoadImage(OpenPictureDialog.FileName, 0, 0);
end;

procedure TEditForm.MenuSaveClick(Sender: TObject);
var FT: FileTime;
begin
  if ImgFileName = '' then MenuSaveAsClick(Sender) else begin
    Image1.Picture.SaveToFile(ImgFileName);
    ImgName := ExtractFileName(ImgFileName);
    Caption := ImgName;
    ImagesForm.ImageList.Items[FormIndex] := IntToStr(FormIndex)+' '+ImgName;
    DataChanged := False;
    GetSystemTimeAsFileTime(FT);
    ImgFileDateTime := Int64(FT);
    ImagesForm.ImageList.Selected[FormIndex] := True;
  end;
end;

procedure TEditForm.MenuSaveAsClick(Sender: TObject);
begin
  if SavePictureDialog.Execute then begin
    ImgFileName := SavePictureDialog.FileName;
    if ImgFileName <> '' then MenuSaveClick(Sender);
  end;
end;

procedure TEditForm.MenuCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TEditForm.MenuNewClick(Sender: TObject);
begin
  AddImageWindow('Image '+IntToStr(TotalImages), nil);
end;

procedure TEditForm.MenuOpenAtClick(Sender: TObject);
var AtX, AtY: Integer;
begin
  if OpenPictureDialog.Execute then begin
    if LoadAtForm.ShowModal = mrOK then begin
      AtX := StrToInt(LoadAtForm.Edit1.Text);
      AtY := StrToInt(LoadAtForm.Edit2.Text);
      LoadImage(OpenPictureDialog.FileName, AtX, AtY);
      DataChanged := True;
    end;
  end;
end;

procedure TEditForm.Image1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var t: Integer;
begin
  ClientToImage(X, Y);
  if Selected.Left > Selected.Right then begin t := Selected.Left; Selected.Left := Selected.Right;  Selected.Right  := t; end;
  if Selected.Top > Selected.Bottom then begin t := Selected.Top;  Selected.Top  := Selected.Bottom; Selected.Bottom := t; end;
  DrawSelRect;
  Image1.Repaint;
  UpdateStatus;
end;

procedure TEditForm.MenuViewAlphaClick(Sender: TObject);
begin
  ViewAlpha := not ViewAlpha;
  MenuViewAlpha.Checked := ViewAlpha;
  ReDraw;
  DrawSelRect;
  Image1.Repaint;  
end;

procedure TEditForm.BTrackerMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  BTrackerMouseMove(Sender, Shift, X, Y);
end;

procedure TEditForm.BTrackerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not (ssLeft in Shift) then Exit;
  TProgressBar(Sender).Position := TProgressBar(Sender).Min + round((X) / (TProgressBar(Sender).Width - 3) * (TProgressBar(Sender).Max - TProgressBar(Sender).Min));
  InitPaintBrush;
end;

procedure TEditForm.Cleanup;
begin
  if (FResource is TMegaImageResource) then
    while OperationManager.CanUndo do OperationManager.Undo;
end;

function TEditForm.GetFileLWTime(Filename: string): Int64;
var CTime, LWTime, LATime: TFileTime; FHandle: Integer;
begin
  FHandle := FileOpen(Filename, 0);
  GetFileTime(FHandle, @CTime, @LATime, @LWTime);
  FileClose(FHandle);
  Result := Int64(LWTime);
end;

procedure TEditForm.CheckChanges;
begin
  if ImgFileName = '' then Exit;
  if not FileExists(ImgFileName) then begin DataChanged := True; Exit; end;
  if GetFileLWTime(ImgFileName) > ImgFileDateTime then
    if MessageDlg(ImgFileName+'''s contents DataChanged. Reload?', mtConfirmation, [mbYes,mbNo], 0) = mrYes then
      LoadImage(ImgFileName, 0, 0);
end;

procedure TEditForm.SetModeCursor(Mode: Integer);
begin
  case Mode of
    iemDraw: Image1.Cursor := crDefault;
    iemMark: Image1.Cursor := crCross;
    iemSelX, iemSelW: Image1.Cursor := crSizeWE;
    iemSelY, iemSelH: Image1.Cursor := crSizeNS;
    iemSelXY, iemSelWH: Image1.Cursor := crSizeNWSE;
    iemSelWY, iemSelXH: Image1.Cursor := crSizeNESW;
  end;
end;

procedure TEditForm.Timer1Timer(Sender: TObject);
var M: TPoint;

  function ExpandRect(const ARect: Types.TRect; Amount: Integer): Types.TRect;
  begin
    Result.Left   := ARect.Left   - Amount;
    Result.Top    := ARect.Top    - Amount;
    Result.Right  := ARect.Right  + Amount;
    Result.Bottom := ARect.Bottom + Amount;
  end;

  procedure AdjustSliderVisibility(Owner, Slider: TControl);
  begin
    OSUtils.ObtainCursorPos(M.X, M.Y);
    M := PnlTools.ScreenToClient(M);
    if (GetCaptureControl = nil) and PtInRect(Owner.BoundsRect, M) then
      Slider.Show
    else if PtInRect(ExpandRect(Slider.BoundsRect, 2), M) and Slider.Visible then
      Slider.Show
    else if GetCaptureControl <> Slider then
      Slider.Hide;
  end;

begin
  GetCursorPos(M);
  M := Image1.ScreenToClient(M);
  ClientToImage(M.X, M.Y);
  SetModeCursor(GetImgEditMode(GetKeyMods, M.X, M.Y));
  Forms.Screen.Cursor := Image1.Cursor;

  AdjustSliderVisibility(BrushSize,  BSizeTracker);
  AdjustSliderVisibility(BrushTrans, BTransTracker);
end;

procedure TEditForm.FormShow(Sender: TObject);
begin
  Timer1.Enabled := True;
end;

procedure TEditForm.FormHide(Sender: TObject);
begin
  Timer1.Enabled := False;
end;

function TEditForm.GetKeyMods: Integer;
begin
  Result := (Ord(MainF.GetKeyState(vkAlt)) * mkAlt) or (Ord(MainF.GetKeyState(vkCTRL)) * mkCTRL);
end;

function TEditForm.GetFloodRect(FloodX, FloodY: Integer): BaseTypes.TRect;
type TXY = packed record X, Y: Integer; end;
var
  Stack: array of TXY; StackPTR: Integer;
  MinX, MaxX, FX, FY: Integer;
  Buf: array of Byte;
  BColor: BaseTypes.TColor;

  procedure Push(X, Y: Integer);
  begin
    Inc(StackPTR); SetLength(Stack, StackPTR);
    Stack[StackPTR-1].X := X; Stack[StackPTR-1].Y := Y;
  end;

  function Pop(var X, Y: Integer): Boolean;
  begin
    Result := False;
    if StackPTR = 0 then Exit;
    Dec(StackPTR);
    X := Stack[StackPTR].X; Y := Stack[StackPTR].Y;
    Result := True;
  end;

  procedure ScanLine(BegX, EndX, Y: Integer);
  var i: Integer; Fill: Boolean;
  begin
    if (Y < 0) or (Y > LevelHeight-1) then Exit;
    Fill := False;
    for i := BegX to EndX do begin
      if (Buffer^[Y * LevelWidth + i].C <> BColor.C) and (Buf[Y * LevelWidth + i] = 0) then begin
        Fill := True;
        Buf[FY * LevelWidth + MaxX] := 1;
      end else if Fill then begin
        Fill := False;
        Push(i, Y);
      end;
    end;
    if Fill then Push(EndX, Y);
  end;

begin
  SetLength(Buf, LevelWidth*LevelHeight);
  StackPTR := 0;
  BColor.C := 0;

  Result := GetRect(FloodX, FloodY, FloodX+1, FloodY+1);

  if Buffer^[FloodY * LevelWidth + FloodX].C <> BColor.C then Push(FloodX, FloodY);

  while Pop(FX, FY) do begin
    MaxX := FX;
    while (Buffer^[FY * LevelWidth + MaxX].C <> BColor.C) and (Buf[FY * LevelWidth + MaxX] = 0) do begin
      Buf[FY * LevelWidth + MaxX] := 1;
      if MaxX < LevelWidth-1 then Inc(MaxX) else Break;
    end;
    MinX := FX-1;
    while (Buffer^[FY * LevelWidth + MinX].C <> BColor.C) and (Buf[FY * LevelWidth + MinX] = 0) do begin
      Buf[FY * LevelWidth + MinX] := 1;
      if MinX > 0 then Dec(MinX) else Break;
    end;

    ScanLine(MinX, MaxX, FY+1);
    ScanLine(MinX, MaxX, FY-1);

    if Result.Left > MinX then Result.Left := MinX;
    if Result.Right <= MaxX then Result.Right := MaxX+1;
    if Result.Top > FY then Result.Top := FY;
    if Result.Bottom <= FY then Result.Bottom := FY+1;
  end;

  SetLength(Stack, 0);
  SetLength(Buf, 0);

  Redraw;
  DrawSelRect;
end;

procedure TEditForm.Ontop1Click(Sender: TObject);
begin
  if FormStyle = fsStayOnTop then FormStyle := fsNormal else FormStyle := fsStayOnTop;
end;

procedure TEditForm.SetResource(AResource: Resources.TImageResource);
begin
  FResource := AResource;
  UpdateFormCaption;
end;

procedure TEditForm.UpdateFormCaption;
var s: string;
begin
  if FChanged then s := '* ' else s := '';
  s := SysUtils.Format('%S level %D/%D of', [s, ViewLevel, TotalLevels-1]);
  if Assigned(FResource) then
    s := s + ' [ ' + FResource.GetFullName + ']' else
      s := s + ' ' + ImgName;
  Caption := s;
  ActImgUndo.Enabled := OperationManager.CanUndo;
  ActImgRedo.Enabled := OperationManager.CanRedo;
end;

procedure TEditForm.UpdateStatus;
begin
//  Label1.Caption := SysUtils.Format('(%D, %D) (%D, %D)', [Selected.Left, Selected.Top, Selected.Right - Selected.Left, Selected.Bottom - Selected.Top]);
//  Label1.Caption := SysUtils.Format('(%D, %D) (%D, %D)', [CloneAnchorX, CloneAnchorY, CloneStartX, CloneStartY]);
end;

procedure TEditForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
//    112: HelpForm.ShowHelp(ActiveControl.HelpContext);
    27: ActDeselect.Execute;
    109: {if ssCtrl in Shift then }ActPrevLevel.Execute;
    107: {if ssCtrl in Shift then }ActNextLevel.Execute;
//    else Log('***' + IntToStr(Key));
  end;
end;

procedure TEditForm.Deselect1Click(Sender: TObject);
begin
  ImagesForm.ImageList.ClearSelection;
  ImagesForm.ImageList.ItemIndex := -1;
end;

procedure TEditForm.ActDeselectExecute(Sender: TObject);
begin
  DelSelRect;
  Selected := GetRect(0, 0, 0, 0);
  DrawSelRect;
  Redraw; Image1.Repaint;
end;

procedure TEditForm.ActImgMakeAlphaExecute(Sender: TObject);
begin
  MakeAlpha(GetRect(0, 0, LevelWidth, LevelHeight));
  ScrollBox1.Repaint;
end;

procedure TEditForm.ActImgMakeNMapExecute(Sender: TObject);
var i, j: Integer; Rect: BaseTypes.TRect; Scale: Single; SwapYZ: Boolean; TempBuf: PImageBuffer;

  function GetNormal(X, Y: Integer): TVector3s;
  var NX1, NZ1, NX2, NZ2: Integer;
  begin
    NX1 := MaxI(0, X-1);
    NZ1 := MaxI(0, Y-1);
    NX2 := MinI(Rect.Right-1,  X+1);
    NZ2 := MinI(Rect.Bottom-1, Y+1);

    CrossProductVector3s(Result, GetVector3s(0, (GetIntensity(Buffer^[NZ2*LevelWidth+X]) - GetIntensity(Buffer^[NZ1*LevelWidth+X]))*Scale, 1),
                                 GetVector3s(1, (GetIntensity(Buffer^[Y*LevelWidth+NX2]) - GetIntensity(Buffer^[Y*LevelWidth+NX1]))*Scale, 0) );
    NormalizeVector3s(Result, Result);
    if SwapYZ then Swap(Result.Y, Result.Z);
  end;

  function GetNormal3(X, Y: Integer): TVector3s;
  var NX1, NZ1, NX2, NZ2: Integer; s1, s2, s3, s4: Single;
  begin
    NX1 := MaxI(0, X-1);
    NZ1 := MaxI(0, Y-1);
    NX2 := MinI(Rect.Right-1,  X+1);
    NZ2 := MinI(Rect.Bottom-1, Y+1);

    s1 := GetIntensity(Buffer^[Y*LevelWidth+NX1]);
    s2 := GetIntensity(Buffer^[NZ1*LevelWidth+X]);
    s3 := GetIntensity(Buffer^[Y*LevelWidth+NX2]);
    s4 := GetIntensity(Buffer^[NZ2*LevelWidth+X]);

    Result := NormalizeVector3s(GetVector3s((s1-s3)*Scale, 2, (s2-s4)*Scale));

    if SwapYZ then Swap(Result.Y, Result.Z);
  end;

begin
  if NormMapForm.ShowModal = mrCancel then Exit;
  Rect := CheckRect(BaseTypes.GetRect(0, 0, LevelWidth, LevelHeight));

  Scale := StrToFloatDef(NormMapForm.Properties['Scale'], 0.05);
  SwapYZ := NormMapForm.Properties.GetAsInteger('Y/Z swap') > 0;

  GetMem(TempBuf, LevelWidth * LevelHeight * EditFormatBpP);
  for j := Rect.Top to Rect.Bottom-1 do for i := Rect.Left to Rect.Right-1 do
    TempBuf^[j*LevelWidth+i] := VectorToColor(GetNormal3(i, j));
  for j := Rect.Top to Rect.Bottom-1 do
    Move(PtrOffs(TempBuf, (j * LevelWidth + Rect.Left) * EditFormatBpP)^, PtrOffs(Buffer, (j * LevelWidth + Rect.Left) * EditFormatBpP)^, (Rect.Right-Rect.Left)*EditFormatBpP);

  FreeMem(TempBuf, LevelWidth * LevelHeight * EditFormatBpP);
  DataChanged := True;
  ReDraw(Rect);
  ScrollBox1.Repaint;
  DrawSelRect;
end;

procedure TEditForm.ActImgApplyExecute(Sender: TObject);
begin
  Apply;
end;

procedure TEditForm.ScrollBox1Resize(Sender: TObject);
begin
  CorrectView;
end;

function TEditForm.AddOperation(AOperation: Models.TOperation): Boolean;
begin
  Result := False;

  MainF.ItemsFrame1.ProgressBar1.Show;
  AOperation.Apply;
  HandleApplyOperation;
  if not (ofIntermediate in AOperation.Flags) then begin
    Include(AOperation.Flags, ofHandled);
    OperationManager.Add(AOperation);
    DataChanged := True;
    Result := True;
  end;
  MainF.ItemsFrame1.ProgressBar1.Hide;
end;

procedure TEditForm.ActImgUndoExecute(Sender: TObject);
begin
  OperationManager.Undo;
  HandleApplyOperation;
end;

procedure TEditForm.ActImgRedoExecute(Sender: TObject);
begin
  OperationManager.Redo;
  HandleApplyOperation;
end;

procedure TEditForm.HandleApplyOperation;
var LastOp: Models.TOperation;
begin
  UpdateFormCaption;
  LastOp := OperationManager.LastOperation;
  if LastOp is TImageOperation then ReDraw(TImageOperation(LastOp).Rect);
  DrawSelRect;
  Image1.Repaint;
end;

procedure TEditForm.InitPaintBrush;
var BSize: Integer;
begin
  BrushSize.Text  := IntToStr(BSizeTracker.Position);
  BrushTrans.Text := IntToStr(BTransTracker.Position);

  GUIHelper.FormToConfig(Name, BrushProps);

  BSize    := BSizeTracker.Position+2;

  PaintBrush.Init(BSize, BSize, nil, nil, ProcessingFormat, PaintBrush.Color, TColorCombineOperation(BrushProps.GetAsInteger('BrushBlend')), ImageSource);
  UpdateBrushImage(CloneStartX, CloneStartY);
  UpdateBrushShape;
end;

procedure TEditForm.UpdateBrushImage(X, Y: Integer);
var CloneX, CloneY, BSize: Integer; PatternData: PImageBuffer;
begin
  PatternData := PaintBrush.PatternData;

  BSize := BSizeTracker.Position+2;

  case Operation of
    ptBrush: FillDWord(PatternData^, BSize * BSize, PaintBrush.Color.C);
    ptClone: begin
      CloneX := ImagesForm.CloneAnchorX + (X - CloneStartX);
      CloneY := ImagesForm.CloneAnchorY + (Y - CloneStartY);
//      Log(SysUtils.Format(' *** (%D, %D)', [CloneX, CloneY]));
      ImageForm[ImagesForm.CloneAnchorIndex].ImageSource.LoadDataAsRGBA(GetRectWH(CloneX - BSize div 2, CloneY - BSize div 2, BSize, BSize), PatternData, BSize);
    end;
  end;

  UpdateStatus;
end;                                       

procedure TEditForm.UpdateBrushShape;
var i, j, HalfSize, BSize: Integer; ShapeData: PByteBuffer; BTrans, TransK, Density: Single; Shape: TBrushShape;
begin
  ShapeData := PaintBrush.ShapeData;

  BTrans  := BTransTracker.Position / 100;
  TransK  := BTrans;

  BSize    := BSizeTracker.Position+2;
  HalfSize := BSize div 2;

  Shape := TBrushShape(BrushProps.GetAsInteger('BrushShape'));
  Density := BrushProps.GetAsInteger('BrushDensity')/100;

  for j := 0 to BSize-1 do for i := 0 to BSize-1 do begin
    if Sqrt(Sqr(i-HalfSize) + Sqr(j-HalfSize)) <= HalfSize then begin
      case Shape of
        bsAir: TransK := Blend(BTrans, 0, Sqrt(Sqr(i-HalfSize) + Sqr(j-HalfSize)) / HalfSize);
        bsSolid: TransK := 1;
        bsRandom: TransK := Blend(BTrans, 0, Sqrt(Sqr(i-HalfSize) + Sqr(j-HalfSize)) / HalfSize) *
                            Ord(Random < Density);
      end;
      ShapeData^[j*BSize+i] := Round(TransK*255);
    end else ShapeData^[j*BSize+i] := 0;
  end;
end;

procedure TEditForm.BrushSizeKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then begin
    BSizeTracker.Position := StrToIntDef(BrushSize.Text, BSizeTracker.Position);
    ActiveControl := nil;
    InitPaintBrush;
  end;
end;

procedure TEditForm.BrushTransKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then begin
    BTransTracker.Position := StrToIntDef(BrushTrans.Text, BTransTracker.Position);
    ActiveControl := nil;
    InitPaintBrush;
  end;
end;

function TEditForm.GetOperation: TPaintTool;
begin
  Result := TPaintTool(BrushProps.GetAsInteger('PaintTool'));
end;

procedure TEditForm.CBoxChange(Sender: TObject);
begin
  InitPaintBrush;
end;

procedure TEditForm.InitImageSource;
begin
  if Assigned(ImageSource) then FreeAndNil(ImageSource);
  if FResource is TMegaImageResource then
    ImageSource := TMegaImageSource.Create(FResource as TMegaImageResource, ViewLevel)
  else
    ImageSource := TImageSource.Create(Buffer, EditFormat, LevelWidth, LevelHeight);
end;

end.
