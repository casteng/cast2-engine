unit FPropEdit;

interface

uses
  Props, BaseTypes, Basics, BaseStr, C2MapEditMsg, OSUtils,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Buttons, StdCtrls, ExtCtrls, ComCtrls;

const
  ControlsGrowStep = 8;

type
  TApplyDelegate = procedure(AChangedProps: TProperties) of object;

  TEditControl = record
    PropName: string;
    Control: TControl;
  end;
  TEditorRec = record
    Editor: TEdit;
    SliderNeeded, IntValue: Boolean;
    SliderMin, SliderMax: Single;
  end;

  TPropEditF = class(TForm)
    EditSlider: TTrackBar;
    SliderCtlTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ClearControls;
    procedure UpdateForm;
    procedure UpdateProps(AProps: TProperties);
    procedure SliderCtlTimerTimer(Sender: TObject);
    procedure EditSliderChange(Sender: TObject);
  private
    FControls: array of TEditControl;
    TotalControls: Integer;
    FEditors: array of TEditorRec;
    TotalEditors: Integer;
    SlIndex: Integer;
    FProps, FChangedProps: TProperties;
    TempCanvas: TCanvas;
    procedure PlaceControl(Prop: PProperty);
    function GetControlIndex(const AName: string): Integer;
    function IndexToControlName(AIndex: Integer): string;
    function AddControl(const APropName: string; AControl: TControl): Integer;
    procedure AddEditor(AEditor: TEdit; SlMin, SlMax: Single; IntegerValue: Boolean);
    procedure DoApply;
    function SenderValid(Sender: TObject; out Index: Integer; out Prop: PProperty): Boolean;

    // Events
    procedure EditChanged(Sender: TObject);
    procedure SpeedButClick(Sender: TObject);
  public
    ImmediateApply: Boolean;
    OnApply: TApplyDelegate;
  end;

var
  PropEditF: TPropEditF;

implementation

{$R *.dfm}

procedure TPropEditF.FormCreate(Sender: TObject);
begin
  FProps := TProperties.Create;
  FChangedProps := TProperties.Create;
  ImmediateApply := True;
  SlIndex := -1;
//  TempCanvas := TCanvas.Create;
end;

procedure TPropEditF.FormDestroy(Sender: TObject);
begin
//  FreeAndNil(TempCanvas);
  FreeAndNil(FChangedProps);
  FreeAndNil(FProps);
end;

procedure TPropEditF.PlaceControl(Prop: PProperty);
const Spacing = 4;
var
  Edit: TEdit; NewCont: TPanel;
  MinV, MaxV: Single;

  procedure AddEnumControls;
  var
    i: Integer; Enum: TStringArray;
    But: TSpeedButton; Panel: TPanel;
  begin
    TempCanvas := Canvas;
    for i := Split(Prop^.Enumeration, StringDelimiter, Enum, False)-1 downto 0 do begin
      But := TSpeedButton.Create(NewCont);
      But.Align      := alLeft;
      But.Parent     := NewCont;
      But.Caption    := Enum[i];
      But.GroupIndex := 1;
      But.AllowAllUp := False;
      But.Down       := Prop^.Value = Enum[i];
      But.OnClick    := SpeedButClick;
      But.Name       := IndexToControlName(i);
      TempCanvas.Font := But.Font;
      But.Width      := TempCanvas.TextWidth(Enum[i]) + Spacing*2;
//      But.Height     := TempCanvas.TextHeight(Enum[i]);

      Panel := TPanel.Create(NewCont);
      Panel.Caption    := '';
      Panel.Width      := Spacing;
      Panel.Height     := Spacing;
      Panel.Parent     := NewCont;
      Panel.BevelOuter := bvNone;
      Panel.Align      := alLeft;
    end;
  end;

  procedure ParseSliderDesc(const s: string);
  var i: Integer;
  begin
    i := Pos('-', s);
    MinV := 0;
    MaxV := -1;
    if i = 0 then Exit;
    MinV := StrToRealDef(Copy(s, 1, i-1), 0);
    MaxV := StrToRealDef(Copy(s, i+1, Length(s)), -1);
  end;

begin
  NewCont := TPanel.Create(Self);
  NewCont.Caption    := '';
  NewCont.AutoSize   := True;
  NewCont.Parent     := Self;
//  NewCont.BevelOuter := bvNone;
  case Prop^.ValueType of
    vtNat, vtInt: begin
      Edit := TEdit.Create(NewCont);
      Edit.Text     := Prop^.Value;
      Edit.Parent   := NewCont;
      Edit.OnChange := EditChanged;
      ParseSliderDesc(Prop^.Enumeration);
      AddEditor(Edit, MinV, MaxV, Prop^.ValueType <> vtSingle);
    end;
    vtEnumerated: AddEnumControls;
  end;
  if Assigned(NewCont) then begin
    NewCont.Hint  := Prop^.Description;
    NewCont.Name  := IndexToControlName(AddControl(Prop^.Name, NewCont));
    NewCont.Align := alTop;
  end;
end;

procedure TPropEditF.ClearControls;
var i: Integer;
begin
  for i := 0 to TotalEditors-1 do if Assigned(FEditors[i].Editor) then begin
    FEditors[i].Editor.Parent := nil;
    FreeAndNil(FEditors[i]);
  end;
  TotalEditors  := 0;
  for i := 0 to TotalControls-1 do if Assigned(FControls[i].Control) then begin
    FControls[i].Control.Parent := nil;
    FreeAndNil(FControls[i].Control);
  end;
  TotalControls := 0;
end;

procedure TPropEditF.UpdateForm;
var i: Integer;
begin
  ClearControls;
  for i := 0 to FProps.TotalProperties-1 do
    PlaceControl(FProps.GetProperty(FProps.GetNameByIndex(i)));
  EditSlider.BringToFront;  
end;                                                         

procedure TPropEditF.UpdateProps(AProps: TProperties);
begin
  FChangedProps.Clear;
  FProps.Clear;
  FProps.Merge(AProps, False);
  if FProps.TotalProperties > 0 then Show else Hide;
  UpdateForm;
end;

procedure TPropEditF.EditSliderChange(Sender: TObject);
var Value: Double;
begin
  if SlIndex = -1 then Exit;
  Value := EditSlider.Position / EditSlider.Max * (FEditors[SlIndex].SliderMax - FEditors[SlIndex].SliderMin) + FEditors[SlIndex].SliderMin;
  if FEditors[SlIndex].IntValue then FEditors[SlIndex].Editor.Text := IntToStr(Round(Value)) else FEditors[SlIndex].Editor.Text := FloatToStr(Value);
end;

function TPropEditF.GetControlIndex(const AName: string): Integer;
begin
  Result := StrToIntDef(Copy(AName, Pos('_', AName)+1, Length(AName)), -1);
end;

function TPropEditF.IndexToControlName(AIndex: Integer): string;
begin
  Result := '_' + IntToStr(AIndex);
end;

function TPropEditF.AddControl(const APropName: string; AControl: TControl): Integer;
begin
  if High(FControls) <= TotalControls then SetLength(FControls, Length(FControls) + ControlsGrowStep);
  FControls[TotalControls].PropName := APropName;
  FControls[TotalControls].Control  := AControl;
  Result := TotalControls;
  Inc(TotalControls);
end;

procedure TPropEditF.AddEditor(AEditor: TEdit; SlMin, SlMax: Single; IntegerValue: Boolean);
begin
  if High(FEditors) <= TotalEditors then SetLength(FEditors, Length(FEditors) + ControlsGrowStep);
  FEditors[TotalEditors].Editor       := AEditor;
  FEditors[TotalEditors].SliderMin    := SlMin;
  FEditors[TotalEditors].SliderMax    := SlMax;
  FEditors[TotalEditors].SliderNeeded := SlMin <= SlMax;
  FEditors[TotalEditors].IntValue     := IntegerValue;
  Inc(TotalEditors);
end;

procedure TPropEditF.DoApply;
begin
  if Assigned(OnApply) then OnApply(FChangedProps);
end;

procedure TPropEditF.EditChanged(Sender: TObject);
var Index: Integer; Prop: PProperty;
begin
  if not SenderValid(Sender, Index, Prop) or not (Sender is TEdit) then Exit;
  FChangedProps.Add(Prop^.Name, Prop^.ValueType, Prop^.Options, TEdit(Sender).Text, Prop^.Enumeration, Prop^.Description);
  if ImmediateApply then DoApply;
end;

procedure TPropEditF.SpeedButClick(Sender: TObject);
var Index: Integer; Prop: PProperty;
begin
  if not SenderValid(Sender, Index, Prop) or not (Sender is TSpeedButton) then Exit;
  FChangedProps.AddEnumerated(Prop^.Name, Prop^.Options, GetControlIndex(TWinControl(Sender).Name), Prop^.Enumeration);
  if ImmediateApply then DoApply;
end;

function TPropEditF.SenderValid(Sender: TObject; out Index: Integer; out Prop: PProperty): Boolean;
begin
  Result := False;
  if not (Sender is TControl) or not (TControl(Sender).Parent is TControl) then Exit;
  Index := GetControlIndex(TControl(TControl(Sender).Parent).Name);
  if (Index < 0) or (Index >= TotalControls) then Exit;
  Prop := FProps.GetProperty(FControls[Index].PropName);
  Assert(Assigned(Prop)); if not Assigned(Prop) then Exit;
  Result := True;
end;

procedure TPropEditF.SliderCtlTimerTimer(Sender: TObject);
// No OnMouseLeave etc events in Delphi 7 so timer approach is used
var i: Integer; MPnt: TPoint; Pnt: TPoint;

  function ValueToSlider(const Value: string; MinV, MaxV: Single): Integer;
  begin
    Result := Round((StrToFloatDef(Value, 0) - MinV) / (MaxV - MinV) * EditSlider.Max);
  end;

begin
  if GetCaptureControl = EditSlider then Exit;
  OSUtils.ObtainCursorPos(MPnt.X, MPnt.Y);
  if PtInRect(EditSlider.BoundsRect, EditSlider.Parent.ScreenToClient(MPnt)) then Exit;

  i := TotalEditors - 1;
  while (i >= 0) and
        not (FEditors[i].SliderNeeded and PtInRect(FEditors[i].Editor.BoundsRect, FEditors[i].Editor.Parent.ScreenToClient(MPnt))) do
    Dec(i);

  if i >= 0 then begin
    Pnt.X := 0;
    Pnt.Y := 0;
    Pnt := FEditors[i].Editor.ClientToScreen(Pnt);
    Pnt := EditSlider.Parent.ScreenToClient(Pnt);
    EditSlider.Position := ValueToSlider(FEditors[i].Editor.Text, FEditors[i].SliderMin, FEditors[i].SliderMax);
    EditSlider.Left     := Pnt.X;
    EditSlider.Top      := Pnt.Y + FEditors[i].Editor.Height-4;
    EditSlider.Width    := FEditors[i].Editor.Width;
    EditSlider.Show;
    SlIndex := i;
  end else begin
    EditSlider.Hide;
    SlIndex := -1;
  end;  
end;

end.
