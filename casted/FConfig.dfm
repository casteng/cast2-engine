object ConfigForm: TConfigForm
  Left = 321
  Top = 357
  Width = 357
  Height = 297
  BorderIcons = [biSystemMenu, biHelp]
  Caption = 'Configuration'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  Icon.Data = {
    0000010001001010000001002000680400001600000028000000100000002000
    0000010020000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    00000000000000000000000000000000000000000000BE7A45FFBE7A45FFBE7A
    45FF000000000000000000000000000000000000000000000000000000000000
    00000000000000000000BE7A45FFBE7A45FF78553958BE7A45FFE3CDBCFFBE7A
    45FF78553958BE7A45FFBE7A45FF000000000000000000000000000000000000
    000000000000BE7A45FFE3CDBCFFD2A786FFBE7A45FFC79064FFDAB89DFFC790
    64FFBE7A45FFD2A786FFE3CDBCFFBE7A45FF0000000000000000000000000000
    000000000000BE7A45FFD2A786FFDAB89DFFDAB89DFFDAB89DFFDAB89DFFDAB8
    9DFFDAB89DFFDAB89DFFD2A786FFBE7A45FF0000000000000000000000000000
    00000000000078553958BE7A45FFE3CDBCFFCFA17CFFBD7F4CF8C38656FFBA7A
    46F4D5AE8FFFDAB89DFFBE7A45FF785539580000000000000000000000000000
    0000BE7A45FFBE7A45FFC79064FFDAB89DFFBD7F4CF8B78256CD78553959A56F
    43C0BA7A46F4DAB89DFFC79064FFBE7A45FFBE7A45FF00000000000000000000
    0000BE7A45FFE3CDBCFFDAB89DFFDAB89DFFC38656FF78553959000000007855
    3959C38656FFDAB89DFFDAB89DFFE3CDBCFFBE7A45FF00000000000000000000
    0000BE7A45FFBE7A45FFC79064FFDAB89DFFBA7A46F49C6B42AE785539598F63
    3F97BA7C49EEDAB89DFFC79064FFBE7A45FFBE7A45FF00000000000000000000
    00000000000078553958BE7A45FFDAB89DFFCFA17CFFBA7A46F4C38656FFBA7A
    46F4D1A582FFDAB89DFFBE7A45FF785539580000000000000000000000000000
    000000000000BE7A45FFD2A786FFDAB89DFFDAB89DFFDAB89DFFDAB89DFFDAB8
    9DFFDAB89DFFDAB89DFFD2A786FFBE7A45FF0000000000000000000000000000
    000000000000BE7A45FFE3CDBCFFD2A786FFBE7A45FFC79064FFDAB89DFFC790
    64FFBE7A45FFD2A786FFE3CDBCFFBE7A45FF0000000000000000000000000000
    00000000000078553958BE7A45FFBE7A45FF78553958BE7A45FFE3CDBCFFBE7A
    45FF78553958BE7A45FFBE7A45FF000000000000000000000000000000000000
    00000000000000000000000000000000000000000000BE7A45FFBE7A45FFBE7A
    45FF000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    000000000000000000000000000000000000000000000000000000000000FFFF
    0000FFFF0000FC7F0000E44F0000C0070000C0070000E28F000087C300008383
    000087C30000E28F0000C0070000C0070000E44F0000FC7F0000FFFF0000}
  OldCreateOrder = False
  ShowHint = True
  OnShow = FormShow
  DesignSize = (
    349
    266)
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 349
    Height = 230
    ActivePage = TabSheet2
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    object TabSheet2: TTabSheet
      Caption = 'Interface'
      ImageIndex = 1
      object Label3: TLabel
        Left = 3
        Top = 29
        Width = 70
        Height = 13
        Caption = 'Thumbnail size'
      end
      object CheckBox1: TCheckBox
        Left = 3
        Top = 3
        Width = 166
        Height = 17
        Caption = 'Remember window layout'
        Checked = True
        State = cbChecked
        TabOrder = 0
      end
      object Edit1: TEdit
        Left = 89
        Top = 26
        Width = 36
        Height = 21
        TabOrder = 1
        Text = '64'
      end
    end
    object TabSheet1: TTabSheet
      Caption = 'Plugins'
      DesignSize = (
        341
        202)
      object Bevel1: TBevel
        Left = 4
        Top = 154
        Width = 331
        Height = 2
        Anchors = [akLeft, akRight, akBottom]
      end
      object Label1: TLabel
        Left = 8
        Top = 0
        Width = 72
        Height = 13
        Caption = 'Loaded plugins'
      end
      object Label2: TLabel
        Left = 152
        Top = 0
        Width = 53
        Height = 13
        Caption = 'Description'
      end
      object LoadPluginBut: TButton
        Left = 4
        Top = 167
        Width = 75
        Height = 25
        Hint = 'Load a plugin'
        Anchors = [akLeft, akBottom]
        Caption = 'Load plugin'
        TabOrder = 0
        OnClick = LoadPluginButClick
      end
      object StaticText1: TStaticText
        Left = 84
        Top = 165
        Width = 251
        Height = 40
        Anchors = [akLeft, akRight, akBottom]
        AutoSize = False
        Caption = 
          'To make a plugin loading on startup place it to the "Plugins" fo' +
          'lder of the program'
        TabOrder = 1
      end
      object PluginsList: TListBox
        Left = 4
        Top = 16
        Width = 121
        Height = 131
        Anchors = [akLeft, akTop, akBottom]
        ItemHeight = 13
        TabOrder = 2
        OnClick = PluginsListClick
      end
      object PluginDesc: TStaticText
        Left = 128
        Top = 16
        Width = 206
        Height = 128
        Anchors = [akLeft, akTop, akRight, akBottom]
        AutoSize = False
        TabOrder = 3
      end
    end
  end
  object OKBut: TButton
    Left = 4
    Top = 235
    Width = 75
    Height = 25
    Hint = 'Apply changes'
    Anchors = [akLeft, akBottom]
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 1
  end
  object CancelBut: TButton
    Left = 268
    Top = 235
    Width = 75
    Height = 25
    Hint = 'Discard changes'
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
  object LoadPluginOpenDialog: TOpenDialog
    DefaultExt = 'bpl'
    Filter = 'CASTEd plugin (*.bpl)|*.bpl|All files (*.*)|*.*'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Title = 'Load Plugin'
    Left = 236
    Top = 232
  end
end
