object ImageForm: TImageForm
  Left = 430
  Top = 172
  Width = 307
  Height = 353
  Caption = 'Image'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  DesignSize = (
    299
    302)
  PixelsPerInch = 96
  TextHeight = 13
  object ScBarH: TScrollBar
    Left = 0
    Top = 284
    Width = 274
    Height = 16
    Anchors = [akLeft, akRight, akBottom]
    PageSize = 0
    TabOrder = 0
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 274
    Height = 277
    Anchors = [akLeft, akTop, akRight, akBottom]
    BevelOuter = bvLowered
    ParentBackground = False
    TabOrder = 1
    object Image1: TImage
      Left = 1
      Top = 1
      Width = 272
      Height = 275
      Align = alClient
    end
  end
  object ScBarV: TScrollBar
    Left = 281
    Top = 0
    Width = 16
    Height = 277
    Anchors = [akTop, akRight, akBottom]
    Kind = sbVertical
    PageSize = 0
    TabOrder = 2
  end
  object ActionList1: TActionList
    Left = 64
    Top = 64
    object ActImgMakeAlpha: TAction
      Category = 'Edit'
      Caption = 'Make alpha'
      ShortCut = 49217
    end
    object ActImgMakeNMap: TAction
      Category = 'Edit'
      Caption = 'Make normal map...'
      ShortCut = 49230
    end
    object ActImgApply: TAction
      Category = 'File'
      Caption = 'Apply'
      HelpKeyword = 'ApplyImage'
      Hint = 'Apply changes'
    end
  end
  object MainMenu1: TMainMenu
    Left = 32
    Top = 64
    object FileMenu: TMenuItem
      Caption = 'File'
      object MenuNew: TMenuItem
        Caption = 'New'
      end
      object MenuOpen: TMenuItem
        Caption = 'Open'
        ShortCut = 16463
      end
      object MenuSave: TMenuItem
        Caption = 'Save'
        ShortCut = 16467
      end
      object MenuSaveAs: TMenuItem
        Caption = 'Save as'
      end
      object N2: TMenuItem
        Caption = '-'
      end
      object Apply1: TMenuItem
        Action = ActImgApply
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object MenuOpenAt: TMenuItem
        Caption = 'Open at...'
        Hint = 'Open a picture inside current'
      end
      object MenuClose: TMenuItem
        Caption = 'Close'
      end
    end
    object EditMenu: TMenuItem
      Caption = 'Edit'
      object Undo1: TMenuItem
        Caption = 'Undo'
        ShortCut = 16474
      end
      object Redo1: TMenuItem
        Caption = 'Redo'
        ShortCut = 16473
      end
      object MenuCopy: TMenuItem
        Caption = 'Copy'
        ShortCut = 16451
      end
      object MenuPaste: TMenuItem
        Caption = 'Paste'
        ShortCut = 16470
      end
      object TMenuItem
        Enabled = False
      end
      object MenuResize: TMenuItem
        Caption = 'Resize'
        ShortCut = 16466
      end
      object MenuMkAlpha: TMenuItem
        Action = ActImgMakeAlpha
      end
      object Makenormalmap1: TMenuItem
        Action = ActImgMakeNMap
      end
    end
    object ViewMenu: TMenuItem
      Caption = 'View'
      object MenuViewAlpha: TMenuItem
        Caption = 'View alpha'
        Hint = 'Show alpha channel'
      end
    end
    object Color: TMenuItem
      Caption = 'Color'
    end
    object Alpha: TMenuItem
      Caption = 'Alpha'
    end
    object Ontop1: TMenuItem
      Caption = 'On top'
    end
    object Deselect1: TMenuItem
      Caption = '___'
    end
  end
end
