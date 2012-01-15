object FormatForm: TFormatForm
  Left = 449
  Top = 188
  BorderStyle = bsDialog
  Caption = 'Choose format'
  ClientHeight = 94
  ClientWidth = 191
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  DesignSize = (
    191
    94)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 71
    Height = 13
    Caption = 'Choose format:'
  end
  object OKBut: TButton
    Left = 8
    Top = 65
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'OK'
    TabOrder = 1
    OnClick = OKButClick
  end
  object CancelBut: TButton
    Left = 109
    Top = 65
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Cancel'
    TabOrder = 2
    OnClick = CancelButClick
  end
  object FormatBox: TComboBox
    Left = 8
    Top = 32
    Width = 145
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    ItemIndex = 2
    TabOrder = 0
    Text = 'A8R8G8B8'
    Items.Strings = (
      'From file'
      'R8G8B8'
      'A8R8G8B8'
      'X8R8G8B8'
      'R5G6B5'
      'X1R5G5B5'
      'A1R5G5B5'
      'A4R4G4B4'
      'A8'
      'X4R4G4B4'
      'A8P8'
      'P8'
      'L8'
      'A8L8'
      'A4L4'
      'V8U8'
      'L6V5U5'
      'X8L8V8U8'
      'Q8W8V8U8'
      'V16U16'
      'W11V11U10'
      'D32'
      'D15S1'
      'D24S8'
      'D16'
      'pfB8G8R8 ')
  end
end
