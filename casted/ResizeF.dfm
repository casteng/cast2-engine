object ResizeForm: TResizeForm
  Left = 336
  Top = 286
  Width = 204
  Height = 246
  Caption = 'ResizeForm'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  ShowHint = True
  OnCreate = FormCreate
  DesignSize = (
    196
    219)
  PixelsPerInch = 96
  TextHeight = 13
  object Label3: TLabel
    Left = 48
    Top = 32
    Width = 36
    Height = 13
    Caption = 'Radius:'
  end
  object Label1: TLabel
    Left = 24
    Top = 93
    Width = 50
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'New width'
  end
  object Label2: TLabel
    Left = 24
    Top = 117
    Width = 54
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'New height'
  end
  object Label4: TLabel
    Left = 24
    Top = 16
    Width = 59
    Height = 13
    Caption = 'Stretch filter:'
  end
  object FilterBox: TComboBox
    Left = 104
    Top = 8
    Width = 90
    Height = 21
    Style = csDropDownList
    Anchors = [akLeft, akTop, akRight]
    ItemHeight = 13
    ItemIndex = 5
    TabOrder = 0
    Text = 'Lanczos'
    OnChange = FilterBoxChange
    Items.Strings = (
      'Box'
      'Treangle'
      'Hermite'
      'Bell'
      'Spline'
      'Lanczos'
      'Mitchell')
  end
  object Edit3: TEdit
    Left = 104
    Top = 32
    Width = 90
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 1
    Text = '3'
    OnChange = TestReal
  end
  object FirstLevelBox: TCheckBox
    Left = 24
    Top = 64
    Width = 121
    Height = 15
    Hint = 
      'If checked only original image will be used to generate all mipm' +
      'aps. Otherwise each level will be used to generate next'
    Caption = 'Always use first level'
    Checked = True
    Enabled = False
    State = cbChecked
    TabOrder = 2
    Visible = False
  end
  object Edit1: TEdit
    Left = 104
    Top = 93
    Width = 90
    Height = 21
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 3
    Text = '256'
    OnChange = TestInteger
  end
  object Edit2: TEdit
    Left = 104
    Top = 117
    Width = 90
    Height = 21
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 4
    Text = '256'
    OnChange = TestInteger
  end
  object AspectBox: TCheckBox
    Left = 24
    Top = 149
    Width = 129
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Preserve aspect ratio'
    Checked = True
    State = cbChecked
    TabOrder = 5
    OnClick = AspectBoxClick
    OnKeyPress = AspectBoxKeyPress
  end
  object Button1: TButton
    Left = 0
    Top = 193
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'OK'
    Default = True
    TabOrder = 6
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 120
    Top = 193
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 7
  end
end
