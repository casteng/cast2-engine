object MapEditF: TMapEditF
  Left = 619
  Top = 890
  Width = 207
  Height = 118
  HorzScrollBar.Tracking = True
  VertScrollBar.Tracking = True
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSizeToolWin
  Caption = 'Map Edit Tools'
  Color = clBtnFace
  DragKind = dkDock
  DragMode = dmAutomatic
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  ScreenSnap = True
  ShowHint = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object CursorSizeSlider: TTrackBar
    Left = 0
    Top = 28
    Width = 89
    Height = 14
    Hint = 'Cursor size'
    Max = 32
    Min = 1
    PageSize = 8
    Frequency = 8
    Position = 1
    TabOrder = 1
    TabStop = False
    ThumbLength = 14
    TickStyle = tsNone
    Visible = False
    OnChange = CursorSizeSliderChange
  end
  object CursorSizeEdit: TEdit
    Left = 4
    Top = 4
    Width = 48
    Height = 21
    Hint = 'Cursor size'
    ImeName = #1056#1091#1089#1089#1082#1072#1103
    TabOrder = 0
    Text = '1'
    OnChange = CursorSizeEditChange
    OnClick = CursorSizeEditClick
  end
  object ToolBar: TPanel
    Left = 56
    Top = 0
    Width = 52
    Height = 28
    Alignment = taLeftJustify
    AutoSize = True
    ParentBackground = False
    TabOrder = 2
  end
  object SliderCtlTimer: TTimer
    Interval = 100
    OnTimer = SliderCtlTimerTimer
    Left = 176
    Top = 8
  end
end
