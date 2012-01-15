object PropEditF: TPropEditF
  Left = 0
  Top = 0
  AutoSize = True
  BorderStyle = bsToolWindow
  Caption = 'Edit Parameters'
  ClientHeight = 14
  ClientWidth = 104
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  ShowHint = True
  Visible = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object EditSlider: TTrackBar
    Left = 0
    Top = 0
    Width = 89
    Height = 14
    Hint = 'Cursor size'
    Max = 10000
    PageSize = 1000
    Frequency = 1000
    Position = 1
    TabOrder = 0
    TabStop = False
    ThumbLength = 14
    TickStyle = tsNone
    Visible = False
    OnChange = EditSliderChange
  end
  object SliderCtlTimer: TTimer
    Interval = 100
    OnTimer = SliderCtlTimerTimer
  end
end
