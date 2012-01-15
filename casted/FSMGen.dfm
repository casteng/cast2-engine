object SMGForm: TSMGForm
  Left = 876
  Top = 92
  Width = 292
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
    284
    185)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 0
    Top = 8
    Width = 55
    Height = 13
    Caption = 'Slope scale'
  end
  object Label2: TLabel
    Left = 112
    Top = 8
    Width = 59
    Height = 13
    Caption = 'Height scale'
  end
  object Label3: TLabel
    Left = 0
    Top = 32
    Width = 49
    Height = 13
    Caption = 'Slope jitter'
  end
  object Label4: TLabel
    Left = 112
    Top = 32
    Width = 53
    Height = 13
    Caption = 'Height jitter'
  end
  object SScaleEdit: TEdit
    Left = 64
    Top = 0
    Width = 41
    Height = 21
    TabOrder = 0
    Text = '0,5'
  end
  object HScaleEdit: TEdit
    Left = 176
    Top = 0
    Width = 41
    Height = 21
    TabOrder = 1
    Text = '0,5'
  end
  object SJitterEdit: TEdit
    Left = 64
    Top = 24
    Width = 41
    Height = 21
    TabOrder = 2
    Text = '32'
  end
  object HJitterEdit: TEdit
    Left = 176
    Top = 24
    Width = 41
    Height = 21
    TabOrder = 3
    Text = '32'
  end
  object CloseSMGBut: TButton
    Left = 210
    Top = 165
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Close'
    TabOrder = 4
    OnClick = CloseSMGButClick
  end
  object GenerateSMBut: TButton
    Left = 0
    Top = 165
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Generate'
    Default = True
    TabOrder = 5
    OnClick = GenerateSMButClick
  end
  object OnTopCBox: TCheckBox
    Left = 228
    Top = -1
    Width = 57
    Height = 17
    Anchors = [akTop, akRight]
    Caption = 'On top'
    Checked = True
    State = cbChecked
    TabOrder = 6
    OnClick = OnTopCBoxClick
  end
  object SMFLoadBut: TButton
    Left = 208
    Top = 145
    Width = 33
    Height = 17
    Caption = 'Load'
    TabOrder = 7
    OnClick = SMFLoadButClick
  end
  object SMFSaveBut: TButton
    Left = 248
    Top = 145
    Width = 33
    Height = 17
    Caption = 'Save'
    TabOrder = 8
    OnClick = SMFSaveButClick
  end
  object ImagesListH: TListBox
    Left = 0
    Top = 48
    Width = 113
    Height = 97
    ItemHeight = 13
    TabOrder = 9
    OnDblClick = ImagesListHDblClick
  end
  object IMRefreshBut: TButton
    Left = 0
    Top = 145
    Width = 73
    Height = 17
    Caption = 'Refresh'
    TabOrder = 10
    OnClick = IMRefreshButClick
  end
  object TexGrid: TStringGrid
    Left = 112
    Top = 48
    Width = 172
    Height = 97
    ColCount = 2
    DefaultRowHeight = 16
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goEditing, goAlwaysShowEditor, goThumbTracking]
    TabOrder = 11
    OnKeyPress = TexGridKeyPress
    ColWidths = (
      100
      64)
    RowHeights = (
      16
      16)
  end
  object AddBut: TButton
    Left = 80
    Top = 145
    Width = 33
    Height = 17
    Caption = 'Add'
    TabOrder = 12
    OnClick = AddButClick
  end
  object DelBut: TButton
    Left = 120
    Top = 145
    Width = 33
    Height = 17
    Caption = 'Del'
    TabOrder = 13
    OnClick = DelButClick
  end
  object ColorDialog1: TColorDialog
    Left = 8
    Top = 56
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = 'smi'
    Filter = 'Sky map ini files (*.smi)|*.smi'
    Left = 48
    Top = 56
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'smi'
    Filter = 'Sky map ini files (*.smi)|*.smi'
    Left = 88
    Top = 56
  end
end
