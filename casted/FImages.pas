{$I GDefines.inc}
{$I C2Defines.inc}
unit FImages;

interface

uses
   Logger, 
  BaseTypes, Basics, Base2D, Resources,
  EditWin, C2EdMain,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, ExtCtrls,
  Dialogs, StdCtrls, Menus, Buttons;

type
  TImagesForm = class(TForm)
    ImageList: TListBox;
    NewImgBut: TButton;
    CFontBut: TButton;
    OpenIDFBut: TButton;
    SaveIDFBut: TButton;
    TrackBox: TCheckBox;
    GenCMBut: TButton;
    SMGBut: TButton;
    ImagesCMenu: TPopupMenu;
    NewCMenu: TMenuItem;
    N3: TMenuItem;
    MakeMipsCMenu: TMenuItem;
    SeamlessCMenu: TMenuItem;
    N4: TMenuItem;
    CreateBMPResCMenu: TMenuItem;
    CreateIDFResCMenu: TMenuItem;
    N5: TMenuItem;
    CloseCMenu: TMenuItem;
    ImgOpenDialog: TOpenDialog;
    ImgSaveDialog: TSaveDialog;
    OnTopBut: TSpeedButton;
    procedure ImageListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ImageListDblClick(Sender: TObject);
    procedure OpenIDFButClick(Sender: TObject);
    procedure SaveIDFButClick(Sender: TObject);
    procedure CFontButClick(Sender: TObject);
    procedure GenCMButClick(Sender: TObject);
    procedure SMGButClick(Sender: TObject);
    procedure NewImgButClick(Sender: TObject);
    procedure MakeMipsCMenuClick(Sender: TObject);
    procedure SeamlessCMenuClick(Sender: TObject);
    procedure CreateBMPResCMenuClick(Sender: TObject);
    procedure CreateIDFResCMenuClick(Sender: TObject);
    procedure CloseCMenuClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OnTopButClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FHMapIndex: Integer;
    FSMapIndex: Integer;
    FCMapIndex: Integer;
    FCloneAnchorIndex, FCloneAnchorX, FCloneAnchorY: Integer;
    procedure SetCMapIndex(const Value: Integer);
    procedure SetHMapIndex(const Value: Integer);
    procedure SetSMapIndex(const Value: Integer);
  public
    procedure SetCloneAnchor(ACloneAnchorIndex, ACloneAnchorX, ACloneAnchorY: Integer);
    property HMapIndex: Integer read FHMapIndex write SetHMapIndex;
    property CMapIndex: Integer read FCMapIndex write SetCMapIndex;
    property SMapIndex: Integer read FSMapIndex write SetSMapIndex;
    property CloneAnchorIndex: Integer read FCloneAnchorIndex;
    property CloneAnchorX: Integer read FCloneAnchorX;
    property CloneAnchorY: Integer read FCloneAnchorY;
  end;

  function AddImageWindow(const Title: string; Res: Resources.TImageResource; const Color: LongWord = 0; Width: Integer = 0; Height: Integer = 0; Levels: Integer = 1; Fill: Boolean = False): Integer;
  function DeleteImageWindow(const Index: Integer): Boolean;
  function CheckImageMatchings(NeedWidth, NeedHeight: Integer): Integer;

var
  ImagesForm: TImagesForm;
  ImageForm: array of TEditForm;
  TotalImages: Integer;

implementation

uses C2Types, FCFont, FSMGen, ResizeF, FUVGen, FCMGen, MainForm;

{$R *.dfm}

function AddImageWindow(const Title: string; Res: Resources.TImageResource; const Color: LongWord = 0; Width: Integer = 0; Height: Integer = 0; Levels: Integer = 1; Fill: Boolean = False): Integer;
begin
  if Width = 0 then if (ImagesForm.ImageList.Items.Count > 0) and (ImagesForm.ImageList.ItemIndex <> -1) then
    Width := ImageForm[ImagesForm.ImageList.ItemIndex].ImageWidth else
      Width := DefaultWidth;
  if Height = 0 then if (ImagesForm.ImageList.Items.Count > 0) and (ImagesForm.ImageList.ItemIndex <> -1) then
    Height := ImageForm[ImagesForm.ImageList.ItemIndex].ImageHeight else
      Height := DefaultHeight;

  Inc(TotalImages); SetLength(ImageForm, TotalImages);

  ImagesForm.ImageList.Items.Add(IntToStr(TotalImages-1)+' '+Title);

  Application.CreateForm(TEditForm, ImageForm[TotalImages-1]);

  ImageForm[TotalImages-1].Init(Width, Height, Res);
  ImageForm[TotalImages-1].ImgName := Title;
  ImageForm[TotalImages-1].FormIndex := TotalImages-1;
  ImageForm[TotalImages-1].FormActivate(nil);

  if TotalImages > 1 then begin
    ImageForm[TotalImages-1].Top  := ImageForm[TotalImages-2].Top+16;
    ImageForm[TotalImages-1].Left := ImageForm[TotalImages-2].Left;
  end;
  ImageForm[TotalImages-1].ClientWidth  := MinI(512, Width+6);
  ImageForm[TotalImages-1].ClientHeight := MinI(512, ImageForm[TotalImages-1].ScrollBox1.Top + Height+6);
  if Fill and Assigned(ImageForm[TotalImages-1].Buffer) then FillDWord(ImageForm[TotalImages-1].Buffer^, Width*Height, Color);
//  if Fill then FillDWord(ImageForm[TotalImages-1].Undo.Buffer^, Width*Height, Color);
  ImageForm[TotalImages-1].SetResource(Res);
  ImageForm[TotalImages-1].ReDraw;
  Result := TotalImages-1;
end;

function DeleteImageWindow(const Index: Integer): Boolean;
var DRes: Integer;

  procedure CheckIndex(var AIndex: Integer; DeletedIndex: Integer);
  begin
    if AIndex = DeletedIndex then AIndex := -1
    else if AIndex = TotalImages-1 then AIndex := DeletedIndex;
  end;

begin
  Result := False;
  if (Index < 0) or (Index > TotalImages-1) then begin MessageDlg('Can''t destroy image: invalid index.', mtError, [mbOK], 0); Exit; end;
{  if ImageForm[Index].TextureInd <> -1 then begin
    TRes := EWorld.Renderer.GetTextureResourceByIndex(ImageForm[Index].TextureInd);
    if TRes <> -1 then begin
      DRes := MessageDlg('Image was bound as texture. Save changes to resource ?', mtConfirmation, [mbYes, mbNo, mbCancel], 0);
      if DRes = mrCancel then Exit;
      if DRes = mrYes then begin
        Move(ImageForm[Index].Buffer^, EWorld.ResourceManager[TRes].Data^, EWorld.ResourceManager[TRes].Size);
      end;
      if DRes = mrNo then EWorld.Renderer.UpdateTexture(EWorld.ResourceManager[TRes].Data, ImageForm[Index].TextureInd, GetArea(0, 0, ImageForm[Index].ImageWidth-1, ImageForm[Index].ImageHeight-1));
    end;
  end;}
  if ImageForm[Index].DataChanged then begin
    DRes := MessageDlg('Image was modified. Save ?', mtConfirmation, [mbYes, mbNo, mbCancel], 0);
    case DRes of
      mrCancel: Exit;
      mrYes: begin
        ImageForm[Index].ActImgApply.Execute();
        if ImageForm[Index].DataChanged then Exit;
      end;
      mrNo: begin
        ImageForm[Index].Cleanup;
      end;
    end;
  end;

  CheckIndex(ImagesForm.FCloneAnchorIndex, Index);

  ImageForm[Index].Release;
  ImageForm[Index] := ImageForm[TotalImages-1];
  ImageForm[Index].FormIndex := Index;
  ImagesForm.ImageList.Items[Index] := IntToStr(Index)+' '+ImageForm[Index].Caption;
  ImagesForm.ImageList.Items.Delete(TotalImages-1);
  Dec(TotalImages); SetLength(ImageForm, TotalImages);
//  MainForm.UpdateStatus;
  Result := True;
end;

function CheckImageMatchings(NeedWidth, NeedHeight: Integer): Integer;
begin
  Result := -1;
  if ImagesForm.ImageList.SelCount <> 1 then begin
    MessageDlg('Select ONE image first', mtError, [mbOK], 0);
    Exit;
  end;
  if (ImageForm[ImagesForm.ImageList.ItemIndex].ImageWidth <> NeedWidth) or (ImageForm[ImagesForm.ImageList.ItemIndex].ImageHeight <> NeedHeight) then begin
    MessageDlg('Image dimensions must be '+IntToStr(NeedWidth)+'x'+IntToStr(NeedHeight), mtError, [mbOK], 0);
    Exit;
  end;
  Result := ImagesForm.ImageList.ItemIndex;
end;

procedure TImagesForm.ImageListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var Index: Integer;
begin
  if Button in [mbRight] then with ImagesForm.ImageList do if SelCount = 1 then begin
    Index := ItemAtPos(Point(X, Y), True);
    if (Index >= 0) and (Index < Items.Count) then begin
      ImagesForm.ImageList.ClearSelection;
      ImagesForm.ImageList.Selected[Index] := True;
    end;
  end;
end;

procedure TImagesForm.ImageListDblClick(Sender: TObject);
begin
  if ImageList.ItemIndex = -1 then Exit;
  ImageForm[ImageList.ItemIndex].Show;
end;

function BuildIDF(var TotalSize: Integer; var IDFHeader: TIDFHeader; var Buffers: array of Pointer): Integer;
var
  i, CurW, CurH: Integer;
  LevelFound: Boolean;
begin
  Result := -1;
  CurW := 0; CurH := 0;
  for i := 0 to ImagesForm.ImageList.Items.Count-1 do if ImagesForm.ImageList.Selected[i] then begin
    if (CurW+CurH) < (ImageForm[i].ImageWidth+ImageForm[i].ImageHeight) then begin
      CurW := ImageForm[i].ImageWidth;
      CurH := ImageForm[i].ImageHeight;
      Result := i;
    end;
  end;
  if Result = -1 then Exit;
  Buffers[0] := ImageForm[Result].Buffer;
  with IDFHeader do begin
    Signature := IDFSignature;
    Compression := icNone;
    PixelFormat := ImageForm[Result].Format;
    Width := ImageForm[Result].ImageWidth;
    Height := ImageForm[Result].ImageHeight;
  end;
  ImagesForm.ImageList.Selected[Result] := False;
  Result := 0;
  TotalSize := CurW * CurH * GetBytesPerPixel(IDFHeader.PixelFormat);
  repeat
    LevelFound := False;
    for i := 0 to ImagesForm.ImageList.Items.Count-1 do if ImagesForm.ImageList.Selected[i] then begin
      if (MaxI(1, CurW div 2) = ImageForm[i].ImageWidth) and (MaxI(1, CurH div 2) = ImageForm[i].ImageHeight) and (IDFHeader.PixelFormat = ImageForm[Result].Format) then begin
        Inc(Result);
        Buffers[Result] := ImageForm[i].Buffer;
        CurW := ImageForm[i].ImageWidth; CurH := ImageForm[i].ImageHeight;
        Inc(TotalSize, CurW*CurH*GetBytesPerPixel(IDFHeader.PixelFormat));
        LevelFound := True;
        ImagesForm.ImageList.Selected[i] := False;
        Break;
      end;
    end;
  until not LevelFound;
end;

procedure TImagesForm.OpenIDFButClick(Sender: TObject);
var i, CurW, CurH, TotalSize: Integer; Buffers: TPointerArray; IDFHeader: TIDFHeader; Stream: Basics.TFileStream;
begin
  if not ImgOpenDialog.Execute then Exit;
  Stream := Basics.TFileStream.Create(ImgOpenDialog.FileName);
  LoadIDFBuffers(Stream, IDFHeader, Buffers, TotalSize);
  Stream.Free;
  CurW := IDFHeader.Width; CurH := IDFHeader.Height;
  for i := 0 to IDFHeader.MipLevels do begin
    AddImageWindow(ExtractFileName(ImgOpenDialog.FileName)+' level '+IntToStr(i), nil, 0, CurW, CurH);
    FreeMem(ImageForm[TotalImages-1].Buffer);
//    ImageForm[TotalImages-1].Buffer := Buffers[i];
    ImageForm[TotalImages-1].Redraw;
    ImageForm[TotalImages-1].ScrollBox1.Repaint;
    CurW := CurW div 2; CurH := CurH div 2;
  end;
  SetLength(Buffers, 0);
//  UpdateStatus;
end;

procedure TImagesForm.SaveIDFButClick(Sender: TObject);
var
  CurLevel, TotalSize: Integer;
  IDFHeader: TIDFHeader;
  Buffers: array of Pointer;
  Stream: Basics.TFileStream;
begin
  if ImageList.SelCount <= 0 then Exit;
  if ImgSaveDialog.Execute then begin
    SetLength(Buffers, ImageList.SelCount);
    CurLevel := BuildIDF(TotalSize, IDFHeader, Buffers);
    SetLength(Buffers, CurLevel+1);
    if CurLevel = -1 then Exit;
    if (ImageList.SelCount = 0) or (MessageDlg('Found only '+IntToStr(Curlevel)+' mipmap levels. Save anyway ?', mtWarning, [mbYes,mbNo], 0) = mrYes) then begin
      IDFHeader.MipLevels := CurLevel;
      Stream := Basics.TFileStream.Create(ImgSaveDialog.FileName, fuWrite);
      if not SaveIDF(Stream, IDFHeader, Buffers) then MessageDlg('Error writing file.', mtError, [mbOK], 0);
      Stream.Free;
    end;
  end;
  SetLength(Buffers, 0);
//  UpdateStatus;
end;

procedure TImagesForm.CFontButClick(Sender: TObject);
var i, CurChar, CurX, CurY, DrawX, DrawY, EndX, StepX, StepY, FXAddW, FXAddH,
  TotalChars, MaxTextHeight: Integer; Coords: BaseTypes.TUVMap;
  TempRes: TUVMapResource;
  TextSize: TSize;
  Image: TImage;

  procedure SkipCommas;
  begin
    with MkFontForm do begin
      while (CurChar < Length(FontSet.Text)) and (FontSet.Text[CurChar+1] = ',') do Inc(CurChar);
    end;
  end;

  function GetLengthBeforeComma: Integer;
  begin
    Result := 0;
    with MkFontForm do begin
      while (CurChar + Result < Length(FontSet.Text)) and (FontSet.Text[CurChar + Result + 1] <> ',') do Inc(Result);
    end;
  end;

begin
  with MkFontForm do if ShowModal = mrOK then begin
    if FontSet.Text = '' then Exit;
    TotalChars := Length(FontSet.Text);
    if ImageList.SelCount = 0 then begin
      AddImageWindow('Font', nil, 0, StrToIntDef(TSizeXEdit.Text, 256), StrToIntDef(TSizeYEdit.Text, 256));
      ImageList.ItemIndex := TotalImages-1;
    end;
    Image := TImage.Create(nil);
    Image.Picture.Bitmap.Width  := StrToIntDef(TSizeXEdit.Text, 256);
    Image.Picture.Bitmap.Height := StrToIntDef(TSizeYEdit.Text, 256);
    Image.Picture.Bitmap.PixelFormat := pf32bit;

    Image.Canvas.Brush.Style := bsClear;
    Image.Canvas.Brush.Color := clBlack;
    Image.Canvas.FillRect(Rect(0, 0, ImageForm[ImageList.ItemIndex].ImageWidth, ImageForm[ImageList.ItemIndex].ImageHeight));

    FXAddW := StrToIntDef(FXAddWEdit.Text, 0);
    FXAddH := StrToIntDef(FXAddHEdit.Text, 0);
    StepX := StrToIntDef(StepXEdit.Text, 0) + FXAddW;
    StepY := StrToIntDef(StepYEdit.Text, 0) + FXAddH;
    EndX := StrToIntDef(EndXEdit.Text, StrToIntDef(TSizeXEdit.Text, 256));

    with ImageForm[ImageList.ItemIndex] do begin
      Image.Canvas.Brush.Style := bsClear;
      i := 0; CurChar := 0;
      CurY := StrToIntDef(OffsYEdit.Text, 0);

      GetMem(Coords, TotalChars * SizeOf(TUV));
      CurX := StrToIntDef(OffsXEdit.Text, 0);
      MaxTextHeight := 0;
      while CurChar < TotalChars do begin
        if CSepCBox.Checked then begin
          SkipCommas;
          FontSet.SelStart := CurChar;
          FontSet.SelLength := GetLengthBeforeComma;
        end else begin
          FontSet.SelStart := i;
          FontSet.SelLength := 1;
        end;

        Image.Canvas.Font.Name  := FontSet.SelAttributes.Name;
        Image.Canvas.Font.Color := FontSet.SelAttributes.Color;
        Image.Canvas.Font.Size  := FontSet.SelAttributes.Size;
        Image.Canvas.Font.Style := FontSet.SelAttributes.Style;
        Image.Canvas.Font.Pitch := FontSet.SelAttributes.Pitch;

        TextSize := Image.Canvas.TextExtent(FontSet.SelText);

        if MaxTextHeight < TextSize.cy{-FontSet.SelAttributes.Height} then MaxTextHeight := TextSize.cy{-FontSet.SelAttributes.Height};

        if CurX + TextSize.cx > EndX-1 then begin
          CurX := StrToIntDef(OffsXEdit.Text, 0);

{          for j := LineBegin to i-1 do begin
            FontSet.SelStart := j; FontSet.SelLength := 1;

            Image.Canvas.Font.Name := FontSet.SelAttributes.Name;
            Image.Canvas.Font.Color := FontSet.SelAttributes.Color;
            Image.Canvas.Font.Size := FontSet.SelAttributes.Size;
            Image.Canvas.Font.Style := FontSet.SelAttributes.Style;
            Image.Canvas.Font.Pitch := FontSet.SelAttributes.Pitch;

            TextSize2 := Image.Canvas.TextExtent(FontSet.SelText);

            Image.Canvas.TextOut(CurX, CurY+MaxTextHeight-FontSet.SelAttributes.Height, FontSet.SelText);
            Coords[i].V := CurY+MaxTextHeight-FontSet.SelAttributes.Height;
            if FSizeBox.Checked then
             Inc(CurX, StrToIntDef(WidthEdit.Text, 16)) else
              Inc(CurX, TextSize2.cx + StepX);
          end;

          CurX := StrToIntDef(OffsXEdit.Text, 0);}

          if FSizeBox.Checked then
           Inc(CurY, StrToIntDef(HeightEdit.Text, 16)) else
            Inc(CurY, MaxTextHeight + StepY);
          MaxTextHeight := 0;
        end;

        if CenterCBox.Checked then begin
          DrawX := CurX - TextSize.cx div 2;
          DrawY := CurY - TextSize.cy div 2;
        end else begin
          DrawX := CurX; DrawY := CurY;
        end;

        Image.Canvas.TextOut(DrawX, DrawY{+MaxTextHeight-FontSet.SelAttributes.Height}, FontSet.SelText);

        Coords[i].U := CurX; Coords[i].V := CurY;//+MaxTextHeight-FontSet.SelAttributes.Height;

        if FSizeBox.Checked then begin
          Inc(CurX, StrToIntDef(WidthEdit.Text, 16));
          Coords[i].H := StrToIntDef(HeightEdit.Text, 16);
        end else begin
          Inc(CurX, TextSize.cx + StepX);
          Coords[i].H := TextSize.cy + FXAddH;
        end;
        Coords[i].W := TextSize.cx + FXAddW;
        Inc(i);
        Inc(CurChar, FontSet.SelLength);
      end;

      ViewAlpha := DAlphaBox.Checked; MenuViewAlpha.Checked := ViewAlpha;
      CopyFromBitmap(GetRect(0, 0, ImageWidth, ImageHeight), Image.Picture.Bitmap, 0, 0);
      FreeAndNil(Image);

      TempRes := TUVMapResource.Create(Core);
      TempRes.Allocate(TotalChars * SizeOf(TUV));
      for i := 0 to TotalChars - 1 do begin
        Coords[i].U := Coords[i].U / ImageForm[ImageList.ItemIndex].ImageWidth;
        Coords[i].V := Coords[i].V / ImageForm[ImageList.ItemIndex].ImageHeight;
        Coords[i].W := Coords[i].W / ImageForm[ImageList.ItemIndex].ImageWidth;
        Coords[i].H := Coords[i].H / ImageForm[ImageList.ItemIndex].ImageHeight;
      end;
      Move(Coords[0], BaseTypes.TUVMap(TempRes.Data)[0], TotalChars * SizeOf(TUV));

      FreeMem(Coords);
      TempRes.Name := FontNameEdit.Text;
      MainF.GetCurrentParent.AddChild(TempRes);
      MainF.ItemsFrame1.RefreshTree;
    end;
  end;
end;

procedure TImagesForm.GenCMButClick(Sender: TObject);
begin
  SMGForm.Visible := True; SMGForm.SetFocus;
end;

procedure TImagesForm.SMGButClick(Sender: TObject);
begin
  CMGForm.Visible := True; CMGForm.SetFocus;
end;

procedure TImagesForm.NewImgButClick(Sender: TObject);
begin
  AddImageWindow('Image '+IntToStr(TotalImages), nil);
end;

procedure TImagesForm.CreateBMPResCMenuClick(Sender: TObject);
var i: Integer; ImageRes: TImageResource;
begin
  for i := 0 to ImageList.Items.Count-1 do if ImageList.Selected[i] then with ImageForm[i] do begin
    ImageRes := TImageResource.Create(Core);
    ImageRes.Format := Format;
    ImageRes.SetDimensions(ImageWidth, ImageHeight);
    ImageRes.Allocate(Integer(ImageWidth * ImageHeight) * GetBytesPerPixel(Format));
    Move(Buffer^, ImageRes.Data^, ImageWidth * ImageHeight * GetBytesPerPixel(Format));
    MainF.GetCurrentParent.AddChild(ImageRes);
    MainF.ItemsChanged := True;
  end;
  MainF.ItemsFrame1.RefreshTree;
end;

procedure TImagesForm.CreateIDFResCMenuClick(Sender: TObject);
var
  i, TotalSize, MipLevels: Integer; ImageRes: TTextureResource;
  IDFHeader: TIDFHeader;
  Buffers: array of Pointer;
begin
  if ImageList.SelCount = 0 then Exit;
  SetLength(Buffers, ImageList.SelCount);
  MipLevels := BuildIDF(TotalSize, IDFHeader, Buffers);

  ImageRes := TTextureResource.Create(Core);

  SetLength(Buffers, MipLevels+1);
  ImageRes.Format    := IDFHeader.PixelFormat;
  ImageRes.MipLevels := MipLevels;
  ImageRes.SetDimensions(IDFHeader.Width, IDFHeader.Height);
  if (ImageList.SelCount = 0) or (MessageDlg('Found only '+IntToStr(MipLevels)+' mipmap levels. Save anyway ?', mtWarning, [mbYes,mbNo], 0) = mrYes) then begin
    ImageRes.Allocate(TotalSize);
    TotalSize := 0;
    for i := 0 to MipLevels do begin
      Move(Buffers[i]^, PtrOffs(ImageRes.Data, TotalSize)^, IDFHeader.Width*IDFHeader.Height*GetBytesPerPixel(IDFHeader.PixelFormat));
      Inc(TotalSize, IDFHeader.Width*IDFHeader.Height*GetBytesPerPixel(IDFHeader.PixelFormat));
      IDFHeader.Width := MaxI(1, IDFHeader.Width div 2); IDFHeader.Height := MaxI(1, IDFHeader.Height div 2);
    end;
    MainF.GetCurrentParent.AddChild(ImageRes);
  end else ImageRes.Free;
  SetLength(Buffers, 0);
  MainF.ItemsFrame1.RefreshTree;
end;

procedure TImagesForm.CloseCMenuClick(Sender: TObject);
var i: Integer;
begin
  for i := ImageList.Items.Count-1 downto 0 do if ImageList.Selected[i] then ImageForm[i].Close;
end;

procedure TImagesForm.MakeMipsCMenuClick(Sender: TObject);
var CurW, CurH, CurLevel, SourceIndex, i: Integer;
begin
  if ImageList.SelCount = 0 then Exit;
  with ResizeForm do begin
    AspectRatio := 0;
    Edit1.Visible := False; Edit2.Visible := False;
    Label1.Visible := False; Label2.Visible := False;
    AspectBox.Visible := False;
    FirstLevelBox.Visible := True;
//    Height := 118;
    if ShowModal <> mrOK then Exit;
    Edit1.Visible := True; Edit2.Visible := True;
    Label1.Visible := True; Label2.Visible := True;
    AspectBox.Visible := True;
    FirstLevelBox.Visible := False;
  end;
  SourceIndex := ImageList.ItemIndex;
  with ImageForm[SourceIndex] do begin
    CurW := MaxI(1, ImageWidth div 2); CurH := MaxI(1, ImageHeight div 2);
  end;
  CurLevel := 1;
  while (CurW > 1) or (CurH > 1) do begin
    with ImageForm[SourceIndex] do begin
      AddImageWindow(Caption + ' level '+IntToStr(CurLevel), nil, 0, CurW, CurH);
      if not ResizeImage(TImageResizeFilter(ResizeForm.FilterBox.ItemIndex), StrToFloatDef(ResizeForm.Edit3.Text, 1), EditFormat,
                         Buffer,                          GetRect(0, 0, ImageWidth, ImageHeight), ImageWidth,
                         ImageForm[TotalImages-1].Buffer, GetRect(0, 0, CurW,       CurH),        CurW) then begin
        ImageForm[TotalImages-1].Close;
        Break;
      end;
    end;
    with ImageForm[TotalImages-1] do begin
      Redraw; ScrollBox1.Repaint; DataChanged := False;
    end;
    CurW := MaxI(1, CurW div 2); CurH := MaxI(1, CurH div 2); Inc(CurLevel);
  end;
  with ResizeForm do begin
    Edit1.Visible := True; Edit2.Visible := True;
    Label1.Visible := True; Label2.Visible := True;
    AspectBox.Visible := True;
    FirstLevelBox.Visible := False;
//    Height := 166;
  end;
end;

function LinMask(i, j, N: Integer): Single;
begin
  if i > N/2 then i := N - 1 - i;
  if j > N/2 then j := N - 1 - j;
  Result := MaxS((N/2-i), (N/2-j)) / (N/2);
end;

function RadMask(i, j, N: Integer): Single;
begin
  if i > N/2 then i := N - 1 - i;
  if j > N/2 then j := N - 1 - j;
  Result := MinS(1, Sqrt( (i-N/2)*(i-N/2) + (j-N/2)*(j-N/2) ) / (N/2));
end;

function SLCombine(i, j: Integer; Buffer: PImageBuffer; Width: Integer): BaseTypes.TColor;
var i1, j1: Integer; A1, R1, G1, B1, A2, R2, G2, B2: DWord; m1, m2: Single;
begin
  i1 := (i + Width div 2) mod (Width-1);
  j1 := (j + Width div 2) mod (Width-1);
  A1 := Buffer^[ j*Width+i ].A;
  R1 := Buffer^[ j*Width+i ].R;
  G1 := Buffer^[ j*Width+i ].G;
  B1 := Buffer^[ j*Width+i ].B;
  A2 := Buffer^[ j1*Width+i1 ].A;
  R2 := Buffer^[ j1*Width+i1 ].R;
  G2 := Buffer^[ j1*Width+i1 ].G;
  B2 := Buffer^[ j1*Width+i1 ].B;
  m1 := LinMask( i,  j, Width);
  m2 := LinMask(i1, j1, Width);
  if 2-m1-m2 <> 0 then begin
    Result.A := MinI(255, Round(( ( (1 - m1)*A1 )*1 + 1*( (1 - m2)*A2 ) )/ (2-m1-m2) ));
    Result.R := MinI(255, Round(( ( (1 - m1)*R1 )*1 + 1*( (1 - m2)*R2 ) )/ (2-m1-m2) ));
    Result.G := MinI(255, Round(( ( (1 - m1)*G1 )*1 + 1*( (1 - m2)*G2 ) )/ (2-m1-m2) ));
    Result.B := MinI(255, Round(( ( (1 - m1)*B1 )*1 + 1*( (1 - m2)*B2 ) )/ (2-m1-m2) ));
  end else begin
    Result.C := 0;
  end;
end;

procedure TImagesForm.SeamlessCMenuClick(Sender: TObject);
var i, j: Integer;
begin
  if ImageList.ItemIndex < 0 then Exit;
  with ImageForm[ImageList.ItemIndex] do begin
    AddImageWindow(Name+' seamless', nil, 0, ImageWidth, ImageHeight);
    for j := 0 to ImageHeight-1 do for i := 0 to ImageWidth-1 do begin
      ImageForm[TotalImages-1].Buffer^[j*ImageWidth+i] := SLCombine(i, j, Buffer, ImageWidth);
    end;
  end;
  ImageForm[TotalImages-1].Redraw;
  ImageForm[TotalImages-1].Image1.Repaint;
end;

procedure TImagesForm.FormCreate(Sender: TObject);
begin
  FHMapIndex := -1;
  FCMapIndex := -1;
  FSMapIndex := -1;
  SetLength(Filters, 7);
  Filters[0] := @ImageBoxFilter;
  Filters[1] := @ImageTriangleFilter;
  Filters[2] := @ImageHermiteFilter;
  Filters[3] := @ImageBellFilter;
  Filters[4] := @ImageSplineFilter;
  Filters[5] := @ImageLanczos3Filter;
  Filters[6] := @ImageMitchellFilter;
end;

procedure TImagesForm.OnTopButClick(Sender: TObject);
begin
  if OnTopBut.Down then FormStyle := fsStayOnTop else FormStyle := fsNormal;
end;

procedure TImagesForm.SetCloneAnchor(ACloneAnchorIndex, ACloneAnchorX, ACloneAnchorY: Integer);
begin
  FCloneAnchorIndex := ACloneAnchorIndex;
  FCloneAnchorX     := ACloneAnchorX;
  FCloneAnchorY     := ACloneAnchorY;
end;

procedure TImagesForm.SetCMapIndex(const Value: Integer);
begin
  if (FCMapIndex <> -1) and (ImageList.Items[FCMapIndex][1] = '(')  then ImageList.Items[FCMapIndex] := Copy(ImageList.Items[FCMapIndex], 5, Length(ImageList.Items[FCMapIndex]));
  FCMapIndex := Value;
  if FCMapIndex <> -1 then ImageList.Items[FCMapIndex] := '(C) ' + ImageList.Items[FCMapIndex];
end;

procedure TImagesForm.SetHMapIndex(const Value: Integer);
begin
  if (FHMapIndex <> -1) and (ImageList.Items[FHMapIndex][1] = '(')  then ImageList.Items[FHMapIndex] := Copy(ImageList.Items[FHMapIndex], 5, Length(ImageList.Items[FHMapIndex]));
  FHMapIndex := Value;
  if FHMapIndex <> -1 then ImageList.Items[FHMapIndex] := '(H) ' + ImageList.Items[FHMapIndex];
end;

procedure TImagesForm.SetSMapIndex(const Value: Integer);
begin
  if (FSMapIndex <> -1) and (ImageList.Items[FSMapIndex][1] = '(') then ImageList.Items[FSMapIndex] := Copy(ImageList.Items[FSMapIndex], 5, Length(ImageList.Items[FSMapIndex]));
  FSMapIndex := Value;
  if FSMapIndex <> -1 then ImageList.Items[FSMapIndex] := '(S) ' + ImageList.Items[FSMapIndex];
end;

procedure TImagesForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Filters := nil;
end;

end.
