{$I GDefines.inc}
unit MapEditForm;

interface

uses
  Logger,
  BaseTypes, Basics, Base2D, CAST2, C2MapEditMsg, OSUtils, Resources,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, ImgList, StdCtrls, Buttons, ComCtrls;

type
  TButClickProc = procedure(Index: Integer) of object;
  TButtonsPanel = class
  private
    TempImage: Pointer;
    FThumbSize, FButtonSize: Integer;
    procedure DoButClick(Sender: TObject);
    procedure DoButDblClick(Sender: TObject);
    procedure DoMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure SetTotalButtons(const Value: Integer);    
    procedure SetThumbSize(const Value: Integer);
    procedure PanelResize(Sender: TObject);
  public
    OnButClick, OnButDblClick, OnMouseUp: TButClickProc;
    FParent: TPanel;
    Buts: array of TSpeedButton;
    Images: array of TImage;
    FTotalButtons: Integer;
    constructor Create(AParent: TPanel);
    destructor Destroy; override;

    procedure SetThumbnailFromImage(AIndex: Integer; ImageRes: TImageResource; UV: BaseTypes.PUV; UVIndex: Integer);
    procedure SetText(AIndex: Integer; AText, AHint: string);

    procedure RelayControls;

    property TotalButtons: Integer read FTotalButtons write SetTotalButtons;
    property ThumbSize: Integer read FThumbSize write SetThumbSize;
  end;

  TMapEditF = class(TForm)
    CursorSizeEdit: TEdit;
    CursorSizeSlider: TTrackBar;
    SliderCtlTimer: TTimer;
    ToolBar: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure UpdateForm;

    procedure CursorSizeSliderChange(Sender: TObject);
    procedure CursorSizeEditClick(Sender: TObject);
    procedure SliderCtlTimerTimer(Sender: TObject);
    procedure CursorSizeEditChange(Sender: TObject);
  private
    HideSizeSlider: Boolean;
    Panels: TButtonsPanel;
    procedure NoneButClick(Index: Integer);
    procedure DrawSelection(AValue: Integer);
  public
    MapCursor: C2MapEditMsg.TMapCursor;
  end;

var
  MapEditF: TMapEditF;

implementation

uses
  BaseClasses, C2Res, Props,
  C2EdMain, MainForm, FPropEdit;

{$R *.dfm}

{ TMapEditF }

procedure TMapEditF.DrawSelection(AValue: Integer);
var i: Integer;
begin
  if MapEditF.MapCursor.Value = 0 then Exit;
//  Panels[AIndex].Buts[MapEditF.MapCursor.Value].Glyph.Canvas.DrawFocusRect(Rect(2, 2, ThumbSize-2, ThumbSize-2));
//  Panels[AIndex].Buts[MapEditF.MapCursor.Value].Glyph.Canvas.DrawFocusRect(Rect(1, 1, ThumbSize-1, ThumbSize-1));
end;

procedure TMapEditF.FormCreate(Sender: TObject);
begin
  Panels := TButtonsPanel.Create(Toolbar);
  Panels.OnButClick := NoneButClick;
  MapCursor := C2MapEditMsg.TMapCursor.Create;
  MapCursor.Aligned := True;
end;

procedure TMapEditF.FormDestroy(Sender: TObject);
var i, j: Integer;
begin
  FreeAndNil(Panels);
  FreeAndNil(MapCursor);
end;

procedure TMapEditF.UpdateForm;
var
  i, j: Integer; Item: TItem; UVRes: TUVMapResource; ImageRes: TImageResource;
  TotalThumbs: Integer;
  PaletteSize: Integer; PaletteData: PPalette;
  Prop: PProperty;
  UV: PUV;
begin
//  Buts[0].Show;

  Item := Core.Root.GetItemByFullName(MapCursor.UVMapName);
  if (Item is TUVMapResource) then begin
    UVRes := Item as TUVMapResource;
    Item := Core.Root.GetItemByFullName(MapCursor.MainTextureName);
    if (Item is TImageResource) then begin
      ImageRes := Item as TImageResource;
      if Assigned(ImageRes.PaletteResource) then begin
        PaletteSize := ImageRes.PaletteResource.TotalElements;
        PaletteData := ImageRes.PaletteResource.Data;
      end else begin
        PaletteSize := 0;
        PaletteData := nil;
      end;

      TotalThumbs := UVRes.TotalElements div MaxI(1, MapCursor.UVMapStep);

      Panels.TotalButtons := TotalThumbs + 1;

      for i := 1 to Panels.TotalButtons-1 do begin
        UV := @BaseTypes.TUVMap(UVRes.Data)^[(i-1) * MaxI(1, MapEditF.MapCursor.UVMapStep)];
        Panels.SetThumbnailFromImage(i, ImageRes, UV, 0);
        Panels.SetText(i, '', Format('%s'#10#13'[%d]:(%d, %d - %d, %d)',
                              [ImageRes.GetFullName,
                               i-1,
                               Round(UV^.U * ImageRes.Width), Round(UV^.V * ImageRes.Height), Round((UV^.U + UV^.W) * ImageRes.Width), Round((UV^.V + UV^.H) * ImageRes.Height)]));
      end;
    end;
  end;
end;

procedure TMapEditF.NoneButClick(Index: Integer);
begin
//  if (MapEditF.MapCursor.Value > 0) and (MapEditF.MapCursor.Value <= High(Panels[AIndex].Images)) then
//    Panels[AIndex].Buts[MapEditF.MapCursor.Value].Glyph := Panels[AIndex].Images[MapEditF.MapCursor.Value].Picture.Bitmap;
  MapEditF.MapCursor.Value := Index;
  DrawSelection(MapEditF.MapCursor.Value);
end;

procedure TMapEditF.CursorSizeSliderChange(Sender: TObject);
begin
  CursorSizeEdit.Text := IntToStr(CursorSizeSlider.Position);
end;

procedure TMapEditF.CursorSizeEditClick(Sender: TObject);
begin
//  CursorSizeSlider.Show;
end;

procedure TMapEditF.SliderCtlTimerTimer(Sender: TObject);
var Pnt: TPoint;
begin
// Pnt :=
  OSUtils.ObtainCursorPos(Pnt.X, Pnt.Y);
//  GetCursorPos(Pnt);
  Pnt := ScreenToClient(Pnt);
  if PtInRect(CursorSizeEdit.BoundsRect, Pnt) then
    CursorSizeSlider.Show else
      if PtInRect(CursorSizeSlider.BoundsRect, Pnt) then CursorSizeSlider.Show else
        if GetCaptureControl <> CursorSizeSlider then CursorSizeSlider.Hide;
end;

procedure TMapEditF.CursorSizeEditChange(Sender: TObject);
begin
  CursorSizeSlider.Position := StrToIntDef(CursorSizeEdit.Text, CursorSizeSlider.Position);
  MapCursor.Params.Add('Size', vtNat, [], IntToStr(CursorSizeSlider.Position), '', '');
end;

{ TButtonsPanel }

constructor TButtonsPanel.Create(AParent: TPanel);
begin
  FParent := AParent;
  FParent.OnResize := PanelResize;
  FParent.DoubleBuffered := True;
  ThumbSize := 48;
end;

destructor TButtonsPanel.Destroy;
var i: Integer;
begin
  for i := 0 to Length(Buts) - 1 do begin
    FreeAndNil(Buts[i]);
    FreeAndNil(Images[i]);
  end;
  FreeMem(TempImage);
  inherited;
end;

procedure TButtonsPanel.DoButClick(Sender: TObject);
var i: Integer;
begin
  i := TotalButtons-1;
  while (i >= 0) and (Sender <> Buts[i]) do Dec(i);
  if Assigned(OnButClick) and (i >= 0) then OnButClick(i);
end;

procedure TButtonsPanel.DoButDblClick(Sender: TObject);
var i: Integer;
begin
  i := TotalButtons-1;
  while (i >= 0) and (Sender <> Buts[i]) do Dec(i);
  if Assigned(OnButDblClick) and (i >= 0) then OnButDblClick(i);
end;

procedure TButtonsPanel.DoMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var i: Integer;
begin
  if not (Button = mbRight) then Exit;  
  i := TotalButtons-1;
  while (i >= 0) and (Sender <> Buts[i]) do Dec(i);
  if Assigned(OnMouseUp) and (i >= 0) then OnMouseUp(i);
end;

procedure TButtonsPanel.PanelResize(Sender: TObject);
begin
  RelayControls;
end;

procedure TButtonsPanel.SetThumbnailFromImage(AIndex: Integer; ImageRes: TImageResource; UV: BaseTypes.PUV; UVIndex: Integer);
var
  j: Integer;
  PaletteSize: Integer; PaletteData: PPalette;
  Rect: BaseTypes.TRect;
begin
  if not Assigned(ImageRes) or (AIndex < 0) or (AIndex >= TotalButtons) then Exit;

  if Assigned(ImageRes.PaletteResource) then begin
    PaletteSize := ImageRes.PaletteResource.TotalElements;
    PaletteData := ImageRes.PaletteResource.Data;
  end else begin
    PaletteSize := 0;
    PaletteData := nil;
  end;

  if Assigned(UV) then
    Rect := BaseTypes.GetRectOnImage(UV^, ImageRes.Width, ImageRes.Height)
  else
    Rect := BaseTypes.GetRect(0, 0, ImageRes.Width, ImageRes.Height);

  if Assigned(ImageRes.Data) then
    CreateThumbnail(ImageRes.Format, ImageRes.Width, Rect,
                    ImageRes.Data, PaletteSize, PaletteData,
                    pfX8R8G8B8, ThumbSize, ThumbSize, TempImage)
  else
    Log('Image resource "' + ImageRes.GetFullName + '" data is nil', lkError);

  for j := 0 to ThumbSize-1 do
    Move(Pointer(Cardinal(TempImage) + Cardinal(j*ThumbSize*4))^, Images[AIndex].Picture.Bitmap.ScanLine[j]^, ThumbSize*4);

  Buts[AIndex].Glyph := Images[AIndex].Picture.Bitmap;
end;

procedure TButtonsPanel.SetText(AIndex: Integer; AText, AHint: string);
begin
  if (AIndex < 0) or (AIndex >= TotalButtons) then Exit;
  Buts[AIndex].Caption := AText;
  Buts[AIndex].Hint    := AHint;
end;

procedure TButtonsPanel.SetThumbSize(const Value: Integer);
begin
  FThumbSize := Value;
  FButtonSize := ThumbSize + 6;
  ReallocMem(TempImage, ThumbSize * ThumbSize * 4);
  if FParent.Parent is TScrollingWinControl then with TScrollingWinControl(FParent.Parent) do if Assigned(VertScrollBar) then VertScrollBar.Increment := FThumbSize div 2;
end;

procedure TButtonsPanel.SetTotalButtons(const Value: Integer);
var i: Integer;
begin
  i := Length(Buts);
  if Value > i then begin
    SetLength(Buts,   Value);
    SetLength(Images, Value);
    for i := MaxI(0, i) to Value-1 do begin
      Buts[i] := TSpeedButton.Create(FParent);
      Buts[i].Parent      := FParent;//Panels[AIndex].Panel;
      Buts[i].Left        := i * (FButtonSize + 4);
      Buts[i].Top         := 2;
      Buts[i].Width       := FButtonSize;
      Buts[i].Height      := FButtonSize;
      Buts[i].GroupIndex  := Integer(Self);
      Buts[i].Visible     := True;
      Buts[i].Transparent := False;

      Images[i] := TImage.Create(nil);

      Images[i].Width  := ThumbSize;
      Images[i].Height := ThumbSize;
      Images[i].Picture.Bitmap.PixelFormat := pf32bit;

      Images[i].Picture.Bitmap.Width  := ThumbSize;
      Images[i].Picture.Bitmap.Height := ThumbSize;
      Images[i].Picture.Bitmap.Transparent := False;
      Images[i].Picture.Bitmap.TransparentColor := FParent.Color;

      Buts[i].OnClick    := DoButClick;
      Buts[i].OnDblClick := DoButDblClick;
      Buts[i].OnMouseUp  := DoMouseUp;
    end;
  end else if Value > TotalButtons then
    for i := TotalButtons to Value-1 do Buts[i].Visible := True
  else
    for i := TotalButtons-1 downto Value do Buts[i].Visible := False;

  FTotalButtons := Value;
  RelayControls;
end;

procedure TButtonsPanel.RelayControls;
const StartX = 0; StartY = 2; GlyphMargin = 2; ButtonPadding = 4;
var i: Integer; lx, ly: Integer;
begin
  FParent.AutoSize := False;
  lx := StartX;
  ly := StartY;
  for i := 0 to TotalButtons - 1 do begin
    if (lx > StartX) and (lx + FButtonSize + ButtonPadding > FParent.ClientWidth) then begin
      lx := StartX;
      Inc(ly, FButtonSize + ButtonPadding);
    end;
    Buts[i].SetBounds(lx, ly, FButtonSize, FButtonSize);
    Inc(lx, FButtonSize + ButtonPadding);
  end;
  FParent.AutoSize := True;
end;

end.
