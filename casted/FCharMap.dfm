object CharMapForm: TCharMapForm
  Left = 478
  Top = 292
  Width = 263
  Height = 281
  Caption = 'Character map'
  Color = clBtnFace
  Constraints.MinHeight = 254
  Constraints.MinWidth = 220
  DragKind = dkDock
  DragMode = dmAutomatic
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  KeyPreview = True
  OldCreateOrder = False
  ShowHint = True
  OnCreate = FormCreate
  OnKeyPress = FormKeyPress
  OnShow = FormShow
  DesignSize = (
    255
    250)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 0
    Top = 32
    Width = 77
    Height = 13
    Caption = 'Total characters'
  end
  object Label2: TLabel
    Left = 0
    Top = 8
    Width = 75
    Height = 13
    Caption = 'Resource name'
  end
  object OnTopBut: TSpeedButton
    Left = 200
    Top = -1
    Width = 41
    Height = 22
    Hint = 'Place the window on top of others'
    AllowAllUp = True
    Anchors = [akTop, akRight]
    GroupIndex = 1
    Down = True
    Caption = 'On top'
    OnClick = OnTopButClick
  end
  object TotalCEdit: TEdit
    Left = 88
    Top = 28
    Width = 41
    Height = 21
    TabOrder = 0
    Text = '256'
  end
  object OKBut: TButton
    Left = 4
    Top = 227
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Apply'
    Default = True
    TabOrder = 1
    OnClick = OKButClick
  end
  object SetBut: TButton
    Left = 136
    Top = 28
    Width = 57
    Height = 22
    Caption = 'Set'
    TabOrder = 2
    OnClick = SetButClick
  end
  object CharMapGrid: TValueListEditor
    Left = 0
    Top = 56
    Width = 124
    Height = 170
    Anchors = [akLeft, akTop, akRight, akBottom]
    DefaultColWidth = 48
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goAlwaysShowEditor, goThumbTracking]
    Strings.Strings = (
      '000=0')
    TabOrder = 3
    TitleCaptions.Strings = (
      'Character'
      'UV frame')
    OnSelectCell = CharMapGridSelectCell
    ColWidths = (
      48
      70)
  end
  object NameEdit: TEdit
    Left = 88
    Top = 4
    Width = 108
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 4
    Text = 'CHM_'
  end
  object GroupBox1: TGroupBox
    Left = 131
    Top = 120
    Width = 121
    Height = 105
    Anchors = [akTop, akRight]
    Caption = 'Modify value'
    TabOrder = 5
    object SetValueEdit: TEdit
      Left = 8
      Top = 16
      Width = 105
      Height = 21
      TabOrder = 0
      Text = '0'
    end
    object SetValBut: TButton
      Left = 8
      Top = 40
      Width = 105
      Height = 25
      Caption = 'Set'
      TabOrder = 1
      OnClick = SetValButClick
    end
    object AddBut: TButton
      Left = 8
      Top = 72
      Width = 105
      Height = 25
      Caption = 'Add'
      TabOrder = 2
      OnClick = AddButClick
    end
  end
  object SelectAllBut: TButton
    Left = 131
    Top = 56
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Select all'
    TabOrder = 6
    OnClick = SelectAllButClick
  end
  object SelectCurrentBut: TButton
    Left = 131
    Top = 88
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Select current'
    TabOrder = 7
    OnClick = SelectCurrentButClick
  end
end
