object ImagesForm: TImagesForm
  Left = 1346
  Top = 923
  Width = 392
  Height = 253
  VertScrollBar.Smooth = True
  VertScrollBar.Tracking = True
  AlphaBlendValue = 128
  BorderStyle = bsSizeToolWin
  Caption = 'Images'
  Color = clBtnFace
  Constraints.MinHeight = 64
  Constraints.MinWidth = 64
  DragKind = dkDock
  DragMode = dmAutomatic
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  Icon.Data = {
    0000010001001010000001002000680400001600000028000000100000002000
    000001002000000000000000000000000000000000000000000000000000858A
    88A4858A88FF858A88FF858A88FF858A88FF858A88FF858A88FF858A88FF858A
    88FF858A88FF858A88FF858A88FF858A88FF858A88FF858A88FF858A888D858A
    88FFFEFEFEFFF6F6F6FFF6F6F6FFF6F6F6FFF6F6F6FFF6F6F6FFF6F6F6FFF6F6
    F6FFF6F6F6FFF6F6F6FFF6F6F6FFF6F6F6FFF6F6F6FFFDFDFDFF858A88FF858A
    88FFFDFDFDFF98867AFF624737FF624737FF624737FF624737FF624737FF6247
    37FF624737FF624737FF624737FF624737FF98867AFFF6F6F6FF858A88FF858A
    88FFFDFDFDFF624737FFA28D81FF8F7567FF8F7567FF8F7567FF8F7567FF8F75
    67FF8F7567FF8F7567FF8F7567FF8F7567FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF624737FF745441FF745340FF71503DFF6E4C38FF6A4834FF6A47
    33FF515151FF515151FF515151FF515151FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF624737FF6D4E3DFF6D4F3DFF6D4F3DFF6D4E3DFF6B4C3BFF6242
    2FFF593623FF515151FF515151FF514138FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF6E5445FFBBA99FFFBBA99FFFBBA99FFFBBA99FFFBAA99EFFBAA8
    9EFFB9A79CFF515151FF515151FF9A8A81FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF735949FFD1B7A8FFD2B8A8FFD2B8A8FFD1B7A8FFD1B7A7FFD1B6
    A6FFD0B5A5FF515151FFA39186FFCEB3A2FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF735748FFCAAC9AFFC7AF9DFFB7C2B3FFB1D1C5FFC3B3A1FFC9AB
    98FFC8A996FF9D897DFFC7A895FFC6A693FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF735747FFC4A38EFFB2C5B6FFDFFAF7FFEEFDFCFFB1DCD1FFC1A1
    8CFFC19E88FFBF9C86FFBF9C86FFBE9A83FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF725645FFBD9980FFAFD1C4FFF9FEFEFFFEFFFFFFBEEBE2FFB89A
    81FFB99278FFB79075FFB79075FFB68D72FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF705443FFB68E73FFAFA68FFFB9E5DCFFCBF3EEFFA9B8A4FFB389
    6DFFB18669FFAF8365FFAF8365FFAD8061FF624737FFF6F6F6FF858A88FF858A
    88FFFEFEFEFF6F513FFFAB7F61FFAD8163FFAA8468FFA78D71FFAA7E5FFFA87B
    5BFFA67857FFA47554FFA47554FFA37250FF624737FFF6F6F6FF858A88FF858A
    88FFFDFDFDFF98867AFF624737FF624737FF624737FF624737FF624737FF6247
    37FF624737FF624737FF624737FF624737FF98867AFFF6F6F6FF858A88FF858A
    88FFFEFEFEFFFEFEFEFFFEFEFEFFFEFEFEFFFEFEFEFFFEFEFEFFFEFEFEFFFEFE
    FEFFFEFEFEFFFEFEFEFFFEFEFEFFFEFEFEFFFEFEFEFFFEFEFEFF858A88FF858A
    888D858A88FF858A88FF858A88FF858A88FF858A88FF858A88FF858A88FF858A
    88FF858A88FF858A88FF858A88FF858A88FF858A88FF858A88FF858A888D8001
    0000000000000000000000000000000000000000000000000000000000000000
    000000000000000000000000000000000000000000000000000080010000}
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  DesignSize = (
    384
    222)
  PixelsPerInch = 96
  TextHeight = 13
  object OnTopBut: TSpeedButton
    Left = 261
    Top = 190
    Width = 41
    Height = 22
    Hint = 'Place the window on top of others'
    AllowAllUp = True
    Anchors = [akRight, akBottom]
    GroupIndex = 1
    Down = True
    Caption = 'On top'
    OnClick = OnTopButClick
  end
  object ImageList: TListBox
    Left = 100
    Top = 1
    Width = 204
    Height = 189
    HelpContext = 1
    Anchors = [akLeft, akTop, akRight, akBottom]
    BevelInner = bvNone
    BevelKind = bkFlat
    BorderStyle = bsNone
    ImeName = #1056#1091#1089#1089#1082#1072#1103
    ItemHeight = 13
    MultiSelect = True
    PopupMenu = ImagesCMenu
    TabOrder = 0
    OnDblClick = ImageListDblClick
    OnMouseDown = ImageListMouseDown
  end
  object NewImgBut: TButton
    Left = 0
    Top = 0
    Width = 97
    Height = 25
    Hint = 'Create new image window'
    HelpContext = 1
    Caption = 'New image'
    Default = True
    TabOrder = 1
    OnClick = NewImgButClick
  end
  object CFontBut: TButton
    Left = 0
    Top = 28
    Width = 97
    Height = 25
    Hint = 'Launch font creation dialog'
    HelpContext = 1
    Caption = 'Create font'
    TabOrder = 2
    OnClick = CFontButClick
  end
  object OpenIDFBut: TButton
    Left = 0
    Top = 198
    Width = 97
    Height = 16
    Hint = 'Load .IDF texture'
    HelpContext = 1
    Caption = 'Open IDF'
    TabOrder = 3
    OnClick = OpenIDFButClick
  end
  object SaveIDFBut: TButton
    Left = 0
    Top = 178
    Width = 97
    Height = 16
    Hint = 'Save .IDF texture'
    HelpContext = 1
    Caption = 'Save as IDF'
    TabOrder = 4
    OnClick = SaveIDFButClick
  end
  object TrackBox: TCheckBox
    Left = 1
    Top = 154
    Width = 56
    Height = 22
    Hint = 
      'If selected moves camera when moving over heightmap image or col' +
      'ormap image'
    HelpContext = 1
    Caption = 'Track'
    TabOrder = 5
  end
  object GenCMBut: TButton
    Left = 176
    Top = 193
    Width = 64
    Height = 21
    Hint = 'Generate a color map based on a height map'
    HelpContext = 1
    Anchors = [akLeft, akBottom]
    Caption = 'Color map'
    TabOrder = 6
    OnClick = GenCMButClick
  end
  object SMGBut: TButton
    Left = 104
    Top = 193
    Width = 64
    Height = 21
    Hint = 'Generate sky map'
    Anchors = [akLeft, akBottom]
    Caption = 'Skymap'
    TabOrder = 7
    OnClick = SMGButClick
  end
  object ImagesCMenu: TPopupMenu
    Left = 64
    Top = 152
    object NewCMenu: TMenuItem
      Caption = 'New'
      OnClick = NewImgButClick
    end
    object N3: TMenuItem
      Caption = '-'
      Enabled = False
    end
    object MakeMipsCMenu: TMenuItem
      Caption = 'Make mipmaps'
      OnClick = MakeMipsCMenuClick
    end
    object SeamlessCMenu: TMenuItem
      Caption = 'Make seamless'
      OnClick = SeamlessCMenuClick
    end
    object N4: TMenuItem
      Caption = '-'
      Enabled = False
    end
    object CreateBMPResCMenu: TMenuItem
      Caption = 'Create BMP resource'
      OnClick = CreateBMPResCMenuClick
    end
    object CreateIDFResCMenu: TMenuItem
      Caption = 'Create IDF resource'
      OnClick = CreateIDFResCMenuClick
    end
    object N5: TMenuItem
      Caption = '-'
      Enabled = False
    end
    object CloseCMenu: TMenuItem
      Caption = 'Close'
      OnClick = CloseCMenuClick
    end
  end
  object ImgOpenDialog: TOpenDialog
    DefaultExt = 'idf'
    Filter = 'IDF texture|*.idf'
    Title = 'Load IDF texture'
    Left = 240
  end
  object ImgSaveDialog: TSaveDialog
    DefaultExt = 'idf'
    Filter = 'IDF textures|*.idf'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Save IDF texture'
    Left = 272
  end
end
