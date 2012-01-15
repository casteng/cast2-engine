unit FPEmitter;

interface

uses
  Props, Basics,
  BaseClasses,
  C2Particle,
  GraphBoxU, GradientBoxU,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls;

type
  CGraphControl = class of TGraphControl;

  TPEmitterForm = class(TForm)
    Timer1: TTimer;
    GraphPanel: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

    procedure FormResize(Sender: TObject);

    procedure OnGraphChange(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
  private
    FTotalGraphs: Integer;
    FItem: TItem;
    OriginalCaption: string;
    Graphs: array of TGraphControl;
    procedure RelayControls;
    procedure RepaintControls;
    procedure ClearGraphs;
    procedure AddGraph(GraphControlClass: CGraphControl; const APropName: AnsiString);
  public
    procedure UpdateForm;
  end;

var
  PEmitterForm: TPEmitterForm;

implementation

uses mainform;

{$R *.dfm}

{ TForm1 }

procedure TPEmitterForm.FormCreate(Sender: TObject);
begin
  OriginalCaption := Caption;
  AutoScroll := True;
//  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csOpaque];
  GraphPanel.ControlStyle := GraphPanel.ControlStyle + [csOpaque];
  GraphPanel.DoubleBuffered := True;
  RelayControls;
end;

procedure TPEmitterForm.FormDestroy(Sender: TObject);
begin
//
end;

procedure TPEmitterForm.FormResize(Sender: TObject);
begin
  RelayControls;
end;

procedure TPEmitterForm.RelayControls;
const GradientHeight = 64; MinGraphHeight = 100;
var i, GraphHeight, TotalGradients, TotalHeight: Integer;
begin
  if FTotalGraphs = 0 then Exit;
  TotalGradients := 0;
  for i := 0 to FTotalGraphs - 1 do if Graphs[i] is TGradientBox then Inc(TotalGradients);
  TotalHeight := ClientHeight - GradientHeight * TotalGradients;

  if FTotalGraphs > TotalGradients then
    GraphHeight := MaxI(TotalHeight div (FTotalGraphs - TotalGradients), MinGraphHeight)
  else
    GraphHeight := 0;

  GraphPanel.AutoSize := False;
  TotalHeight := 0;
  for i := 0 to FTotalGraphs - 1 do
    if Graphs[i] is TGraphBox then begin
      Graphs[i].SetBounds(0, TotalHeight, GraphPanel.ClientWidth, GraphHeight-2);
      Inc(TotalHeight, GraphHeight);
    end else if Graphs[i] is TGradientBox then begin
      Graphs[i].SetBounds(0, TotalHeight, GraphPanel.ClientWidth, GradientHeight-2);
      Inc(TotalHeight, GradientHeight);
    end;
  GraphPanel.AutoSize := True;
  VertScrollBar.Increment := MaxI(GraphHeight, GradientHeight) div 2;
end;

procedure TPEmitterForm.RepaintControls;
var i: Integer;
begin
  for i := 0 to FTotalGraphs - 1 do Graphs[i].Invalidate;
end;

procedure TPEmitterForm.ClearGraphs;
var i: Integer;
begin
  for i := 0 to FTotalGraphs-1 do if Assigned(Graphs[i]) then Graphs[i].Hide;
  FTotalGraphs := 0;
end;

procedure TPEmitterForm.AddGraph(GraphControlClass: CGraphControl; const APropName: AnsiString);
begin
  Inc(FTotalGraphs);
  if Length(Graphs) < FTotalGraphs then SetLength(Graphs, FTotalGraphs);
  if not (Graphs[FTotalGraphs-1] is GraphControlClass) then begin
    if Assigned(Graphs[FTotalGraphs-1]) then Graphs[FTotalGraphs-1].Free;    
    Graphs[FTotalGraphs-1] := GraphControlClass.Create(Self);
  end;

  Graphs[FTotalGraphs-1].Parent := GraphPanel;
  Graphs[FTotalGraphs-1].Caption := APropName;
  Graphs[FTotalGraphs-1].OnChange := OnGraphChange;
  Graphs[FTotalGraphs-1].Show;
end;

procedure TPEmitterForm.UpdateForm;
var
  i: Integer;
  Props: TProperties;
  Garbage: IRefcountedContainer;
  Item: TItem;

  function IsGraphValue(Index: Integer): Boolean;
  var t: TPropertyValueType;
  begin
    t := Props.GetType(Props.GetNameByIndex(i));
    Result := (t = vtSingleSample) or (t = vtGradientSample);
  end;

begin
//  DisableAutoRange;
  Garbage := CreateRefcountedContainer();
  Item := MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode);
  if Item = nil then begin
    Caption := OriginalCaption + ': no Item selected';
    ClearGraphs;
    FTotalGraphs := 0;
  end else begin
    Item := MainF.ItemsFrame1.GetNodeItem(MainF.ItemsFrame1.Tree.FocusedNode) as TItem;

    Props := TProperties.Create;
    Garbage.AddObject(Props);

    Item.AddProperties(Props);

    i := Props.TotalProperties-1;
    while (i >= 0) and not IsGraphValue(i) do Dec(i);

    if i < 0 then Exit;

    GraphPanel.AutoSize := False;
    ClearGraphs;

    for i := 0 to Props.TotalProperties-1 do case Props.GetType(Props.GetNameByIndex(i)) of
      vtSingleSample: begin
        AddGraph(TGraphBox, Props.GetNameByIndex(i));
        Graphs[FTotalGraphs-1].GetGenericSamples.SetFromProperty(Props, Props.GetNameByIndex(i));
      end;
      vtGradientSample: begin
        AddGraph(TGradientBox, Props.GetNameByIndex(i));
        Graphs[FTotalGraphs-1].GetGenericSamples.SetFromProperty(Props, Props.GetNameByIndex(i));
      end;
    end;

    GraphPanel.AutoSize := True;

    FItem := Item;
    Caption := '[' + FItem.GetFullName + ']' + OriginalCaption;
  end;

  RelayControls;
  if (FTotalGraphs > 0) and not Visible then Show;
  GraphPanel.Invalidate;
//  EnableAutoRange;
end;

procedure TPEmitterForm.OnGraphChange(Sender: TObject);
var Props: TProperties; Garbage: IRefcountedContainer;
begin
  if not (Sender is TGraphControl) then Exit;
  Props := TProperties.Create;
  Garbage := CreateRefcountedContainer();
  Garbage.AddObject(Props);
  with TGraphControl(Sender) do
    GetGenericSamples.AddAsProperty(Props, Caption);
  FItem.SetProperties(Props);
end;

procedure TPEmitterForm.Timer1Timer(Sender: TObject);
begin
//  UpdateForm;
//  RelayControls;
  RepaintControls;
end;

procedure TPEmitterForm.FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
const WindowsStupidConstant = 120;
begin
  if IsInArea(MousePos.X, MousePos.Y, Left, Top, Left + Width, Top + Height) then begin
    VertScrollBar.Position := VertScrollBar.Position - (WheelDelta*VertScrollBar.Increment div WindowsStupidConstant);
    Handled := True;
  end else begin
    Handled := False;
    MainF.Perform(WM_MOUSEWHEEL, WheelDelta*65536, MousePos.X * 65536 + MousePos.Y);
  end;
end;

end.
