object LoadAtForm: TLoadAtForm
  Left = 290
  Top = 262
  Width = 203
  Height = 117
  Caption = 'LoadAtForm'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    195
    86)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 16
    Top = 8
    Width = 36
    Height = 13
    Caption = 'X offset'
  end
  object Label2: TLabel
    Left = 16
    Top = 32
    Width = 36
    Height = 13
    Caption = 'Y offset'
  end
  object Edit1: TEdit
    Left = 64
    Top = 0
    Width = 121
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    Text = '0'
    OnChange = TestInteger
  end
  object Edit2: TEdit
    Left = 64
    Top = 24
    Width = 121
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 1
    Text = '0'
    OnChange = TestInteger
  end
  object OkBut: TButton
    Left = 8
    Top = 56
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'OK'
    Default = True
    TabOrder = 2
    OnClick = OkButClick
  end
  object CancelBut: TButton
    Left = 112
    Top = 56
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 3
  end
end
