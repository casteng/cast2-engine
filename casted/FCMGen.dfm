object CMGForm: TCMGForm
  Left = 520
  Top = 206
  Width = 233
  Height = 216
  Caption = 'Skymap generator'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    225
    185)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 0
    Top = 8
    Width = 28
    Height = 13
    Caption = 'Width'
  end
  object Label2: TLabel
    Left = 80
    Top = 8
    Width = 31
    Height = 13
    Caption = 'Height'
  end
  object Label3: TLabel
    Left = 0
    Top = 72
    Width = 29
    Height = 13
    Caption = 'Sun X'
  end
  object Label4: TLabel
    Left = 88
    Top = 72
    Width = 29
    Height = 13
    Caption = 'Sun Y'
  end
  object Label5: TLabel
    Left = 0
    Top = 104
    Width = 40
    Height = 13
    Caption = 'Sun size'
  end
  object PreviewImage: TImage
    Left = 80
    Top = 124
    Width = 64
    Height = 64
    Anchors = [akLeft, akBottom]
    OnMouseDown = PreviewImageMouseDown
    OnMouseMove = PreviewImageMouseMove
  end
  object WidthEdit: TEdit
    Left = 32
    Top = 0
    Width = 41
    Height = 21
    TabOrder = 0
    Text = '64'
  end
  object HeightEdit: TEdit
    Left = 120
    Top = 0
    Width = 41
    Height = 21
    TabOrder = 1
    Text = '64'
  end
  object SunColorP: TPanel
    Left = 0
    Top = 24
    Width = 225
    Height = 12
    Caption = 'Sun'
    Color = 16777088
    ParentBackground = False
    TabOrder = 2
    OnClick = ColorPClick
  end
  object ZenithColorP: TPanel
    Left = 0
    Top = 38
    Width = 225
    Height = 12
    Caption = 'Zenith'
    Color = 16744448
    ParentBackground = False
    TabOrder = 3
    OnClick = ColorPClick
  end
  object HorizonColorP: TPanel
    Left = 0
    Top = 52
    Width = 225
    Height = 12
    Caption = 'Horizon'
    Color = 14248960
    ParentBackground = False
    TabOrder = 4
    OnClick = ColorPClick
  end
  object SunXEdit: TEdit
    Left = 32
    Top = 64
    Width = 49
    Height = 21
    TabOrder = 5
    Text = '32'
  end
  object SunYEdit: TEdit
    Left = 128
    Top = 64
    Width = 49
    Height = 21
    TabOrder = 6
    Text = '32'
  end
  object SunSizeEdit: TEdit
    Left = 48
    Top = 96
    Width = 49
    Height = 21
    TabOrder = 7
    Text = '1'
  end
  object CloseSMGBut: TButton
    Left = 151
    Top = 165
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Close'
    TabOrder = 8
  end
  object GenerateSMBut: TButton
    Left = 0
    Top = 165
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Generate'
    Default = True
    TabOrder = 9
    OnClick = GenerateSMButClick
  end
  object OnTopCBox: TCheckBox
    Left = 169
    Top = 0
    Width = 57
    Height = 17
    Anchors = [akTop, akRight]
    Caption = 'On top'
    Checked = True
    State = cbChecked
    TabOrder = 10
    OnClick = OnTopCBoxClick
  end
  object Button1: TButton
    Left = 151
    Top = 126
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Get gradient'
    TabOrder = 11
  end
  object SunSizeSlider: TTrackBar
    Left = 104
    Top = 88
    Width = 121
    Height = 33
    Anchors = [akLeft, akTop, akRight]
    Max = 64
    PageSize = 8
    Frequency = 16
    TabOrder = 12
    TickMarks = tmTopLeft
    OnChange = SunSizeSliderChange
  end
  object ReverseCBox: TCheckBox
    Left = 4
    Top = 120
    Width = 61
    Height = 17
    Caption = 'Reverse'
    TabOrder = 13
    OnClick = ReverseCBoxClick
  end
  object SMFLoadBut: TButton
    Left = 0
    Top = 136
    Width = 33
    Height = 25
    Caption = 'Load'
    TabOrder = 14
    OnClick = SMFLoadButClick
  end
  object SMFSaveBut: TButton
    Left = 40
    Top = 136
    Width = 33
    Height = 25
    Caption = 'Save'
    TabOrder = 15
    OnClick = SMFSaveButClick
  end
  object ColorDialog1: TColorDialog
    Left = 8
    Top = 24
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = 'smi'
    Filter = 'Sky map ini files (*.smi)|*.smi'
    Left = 152
    Top = 32
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'smi'
    Filter = 'Sky map ini files (*.smi)|*.smi'
    Left = 184
    Top = 32
  end
end
