object VFormatForm: TVFormatForm
  Left = 1035
  Top = 151
  BorderStyle = bsDialog
  Caption = 'Choose format'
  ClientHeight = 233
  ClientWidth = 202
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    202
    233)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 103
    Height = 13
    Caption = 'Choose vertex format:'
  end
  object Label2: TLabel
    Left = 0
    Top = 136
    Width = 20
    Height = 13
    Caption = 'UVs'
  end
  object Label3: TLabel
    Left = 0
    Top = 160
    Width = 39
    Height = 13
    Caption = 'Weights'
  end
  object Label4: TLabel
    Left = 8
    Top = 184
    Width = 54
    Height = 13
    Caption = 'Vertex size:'
  end
  object OKBut: TButton
    Left = 8
    Top = 204
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'OK'
    Default = True
    TabOrder = 0
    OnClick = OKButClick
  end
  object CancelBut: TButton
    Left = 120
    Top = 204
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Cancel'
    TabOrder = 1
    OnClick = CancelButClick
  end
  object DiffCBox: TCheckBox
    Left = 8
    Top = 80
    Width = 97
    Height = 17
    Caption = 'Diffuse'
    TabOrder = 2
    OnClick = FormatChange
  end
  object SpecCBox: TCheckBox
    Left = 8
    Top = 104
    Width = 97
    Height = 17
    Caption = 'Specular'
    TabOrder = 3
    OnClick = FormatChange
  end
  object NormCBox: TCheckBox
    Left = 8
    Top = 56
    Width = 97
    Height = 17
    Caption = 'Normals'
    TabOrder = 4
    OnClick = FormatChange
  end
  object UVsEdit: TEdit
    Left = 48
    Top = 131
    Width = 57
    Height = 21
    TabOrder = 5
    Text = '1'
    OnChange = FormatChange
  end
  object WightsEdit: TEdit
    Left = 48
    Top = 155
    Width = 57
    Height = 21
    TabOrder = 6
    Text = '0'
    OnChange = FormatChange
  end
  object TransCBox: TCheckBox
    Left = 8
    Top = 32
    Width = 161
    Height = 17
    Caption = 'Transformed coordinates'
    TabOrder = 7
    OnClick = FormatChange
  end
end
