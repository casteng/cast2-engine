object PEmitterForm: TPEmitterForm
  Left = 1224
  Top = 327
  VertScrollBar.Tracking = True
  Caption = ' - Graphic Value'
  ClientHeight = 826
  ClientWidth = 407
  Color = clBtnFace
  DragKind = dkDock
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Visible = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnMouseWheel = FormMouseWheel
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 13
  object GraphPanel: TPanel
    Left = 0
    Top = 0
    Width = 407
    Height = 185
    Align = alTop
    AutoSize = True
    ParentBackground = False
    TabOrder = 0
  end
  object Timer1: TTimer
    Interval = 100
    OnTimer = Timer1Timer
    Left = 128
    Top = 32
  end
end
