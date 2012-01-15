object MkFontForm: TMkFontForm
  Left = 311
  Top = 537
  Width = 501
  Height = 373
  Caption = 'Create font texture and mapping'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  ShowHint = True
  DesignSize = (
    493
    342)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 168
    Top = 326
    Width = 86
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Total 0 characters'
  end
  object Label2: TLabel
    Left = 0
    Top = 215
    Width = 23
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'From'
  end
  object Label3: TLabel
    Left = 80
    Top = 215
    Width = 9
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'to'
  end
  object Label4: TLabel
    Left = 208
    Top = 216
    Width = 40
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Columns'
  end
  object Label5: TLabel
    Left = 248
    Top = 240
    Width = 57
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Texture size'
  end
  object Label6: TLabel
    Left = 0
    Top = 243
    Width = 28
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Offset'
  end
  object Label7: TLabel
    Left = 0
    Top = 4
    Width = 28
    Height = 13
    Caption = 'Name'
  end
  object Label8: TLabel
    Left = 128
    Top = 242
    Width = 18
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'end'
  end
  object Label9: TLabel
    Left = 0
    Top = 266
    Width = 27
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Stride'
  end
  object Label10: TLabel
    Left = 128
    Top = 266
    Width = 34
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'FX add'
  end
  object Label11: TLabel
    Left = 160
    Top = 8
    Width = 38
    Height = 13
    Caption = 'Label11'
  end
  object Edit1: TEdit
    Left = 32
    Top = 211
    Width = 41
    Height = 21
    Hint = 'First character code'
    Anchors = [akLeft, akBottom]
    TabOrder = 0
    Text = '32'
  end
  object Edit2: TEdit
    Left = 96
    Top = 211
    Width = 41
    Height = 21
    Hint = 'Last character code'
    Anchors = [akLeft, akBottom]
    TabOrder = 1
    Text = '127'
  end
  object Button1: TButton
    Left = 0
    Top = 318
    Width = 75
    Height = 25
    Hint = 'Generate texture and UV mapping'
    Anchors = [akLeft, akBottom]
    Caption = 'Ok'
    Default = True
    TabOrder = 2
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 418
    Top = 318
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 3
  end
  object Button3: TButton
    Left = 442
    Top = 243
    Width = 49
    Height = 22
    Hint = 'Choose font'
    Anchors = [akRight, akBottom]
    Caption = 'Font'
    TabOrder = 4
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 144
    Top = 211
    Width = 49
    Height = 22
    Hint = 'Add characters range'
    Anchors = [akLeft, akBottom]
    Caption = 'Add'
    TabOrder = 5
    OnClick = Button4Click
  end
  object ColsEdit: TEdit
    Left = 256
    Top = 212
    Width = 41
    Height = 21
    Hint = 'Number of columns of text on texture'
    Anchors = [akLeft, akBottom]
    TabOrder = 6
    Text = '8'
  end
  object DAlphaBox: TCheckBox
    Left = 402
    Top = 295
    Width = 89
    Height = 17
    Hint = 'Check to draw the font to alpha component of the texture'
    Anchors = [akRight, akBottom]
    Caption = 'Draw to alpha'
    Checked = True
    State = cbChecked
    TabOrder = 7
  end
  object FSizeBox: TCheckBox
    Left = 0
    Top = 295
    Width = 73
    Height = 17
    Hint = 'Check to force all characters to fixed size'
    Anchors = [akLeft, akBottom]
    Caption = 'Fixed size'
    TabOrder = 8
  end
  object WidthEdit: TEdit
    Left = 72
    Top = 292
    Width = 41
    Height = 21
    Hint = 'Fixed width'
    Anchors = [akLeft, akBottom]
    TabOrder = 9
    Text = '16'
  end
  object HeightEdit: TEdit
    Left = 120
    Top = 292
    Width = 41
    Height = 21
    Hint = 'Fixed height'
    Anchors = [akLeft, akBottom]
    TabOrder = 10
    Text = '16'
  end
  object TSizeXEdit: TEdit
    Left = 320
    Top = 236
    Width = 49
    Height = 21
    Hint = 'Width of the texture in pixels'
    Anchors = [akLeft, akBottom]
    TabOrder = 11
    Text = '256'
    OnChange = TSizeXEditChange
  end
  object TSizeYEdit: TEdit
    Left = 368
    Top = 236
    Width = 49
    Height = 21
    Hint = 'Height of the texture in pixels'
    Anchors = [akLeft, akBottom]
    TabOrder = 12
    Text = '256'
    OnChange = TSizeYEditChange
  end
  object OffsXEdit: TEdit
    Left = 32
    Top = 239
    Width = 41
    Height = 21
    Hint = 'Horizontal offset from  the edge'
    Anchors = [akLeft, akBottom]
    TabOrder = 13
    Text = '0'
  end
  object OffsYEdit: TEdit
    Left = 80
    Top = 239
    Width = 41
    Height = 21
    Hint = 'Vertical offset from  the edge'
    Anchors = [akLeft, akBottom]
    TabOrder = 14
    Text = '0'
  end
  object FontNameEdit: TEdit
    Left = 40
    Top = 0
    Width = 105
    Height = 21
    Hint = 
      'Name of the font. Corresponding resource names will be based on ' +
      'this.'
    TabOrder = 15
    Text = 'Font'
  end
  object EndXEdit: TEdit
    Left = 152
    Top = 239
    Width = 41
    Height = 21
    Hint = 'Maximum X coordinate which can be used on texture (in pixels)'
    Anchors = [akLeft, akBottom]
    TabOrder = 16
    Text = '256'
  end
  object EndYEdit: TEdit
    Left = 200
    Top = 239
    Width = 41
    Height = 21
    Hint = 'Maximum Y coordinate which can be used on texture (in pixels)'
    Anchors = [akLeft, akBottom]
    TabOrder = 17
    Text = '256'
  end
  object StepXEdit: TEdit
    Left = 32
    Top = 263
    Width = 41
    Height = 21
    Hint = 'Horizontal stride between characters'
    Anchors = [akLeft, akBottom]
    TabOrder = 18
    Text = '0'
  end
  object StepYEdit: TEdit
    Left = 80
    Top = 263
    Width = 41
    Height = 21
    Hint = 'Vertical stride between characters'
    Anchors = [akLeft, akBottom]
    TabOrder = 19
    Text = '0'
  end
  object FXAddHEdit: TEdit
    Left = 216
    Top = 263
    Width = 41
    Height = 21
    Hint = 'Number of pixels which effects will add to characters height'
    Anchors = [akLeft, akBottom]
    TabOrder = 20
    Text = '0'
  end
  object FXAddWEdit: TEdit
    Left = 168
    Top = 263
    Width = 41
    Height = 21
    Hint = 'Number of pixels which effects will add to characters width'
    Anchors = [akLeft, akBottom]
    TabOrder = 21
    Text = '0'
  end
  object FontSet: TRichEdit
    Left = 0
    Top = 24
    Width = 490
    Height = 176
    Hint = 'Source text'
    Anchors = [akLeft, akTop, akRight, akBottom]
    Color = clBlack
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
    TabOrder = 22
    WantReturns = False
    WordWrap = False
    OnChange = FontSetChange
    OnSelectionChange = FontSetSelectionChange
  end
  object CenterCBox: TCheckBox
    Left = 168
    Top = 295
    Width = 81
    Height = 17
    Hint = 'Align characters to the center of the texture'
    Anchors = [akLeft, akBottom]
    Caption = 'Center align'
    TabOrder = 23
  end
  object CSepCBox: TCheckBox
    Left = 264
    Top = 295
    Width = 105
    Height = 17
    Hint = 
      'Check if you want to get on texture several lines of text. Lines' +
      ' should be separated in source by commas'
    Anchors = [akLeft, akBottom]
    Caption = 'Comma separated'
    TabOrder = 24
  end
  object FontDialog1: TFontDialog
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    Left = 216
  end
end
