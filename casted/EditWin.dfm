object EditForm: TEditForm
  Left = 1237
  Top = 702
  Width = 361
  Height = 373
  Anchors = []
  Caption = 'Image'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  KeyPreview = True
  Menu = MainMenu1
  OldCreateOrder = False
  Position = poScreenCenter
  ShowHint = True
  Visible = True
  OnActivate = FormActivate
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnDeactivate = FormDeactivate
  OnHide = FormHide
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ScrollBox1: TScrollBox
    Left = 0
    Top = 33
    Width = 353
    Height = 294
    HorzScrollBar.Tracking = True
    VertScrollBar.Tracking = True
    Align = alClient
    AutoScroll = False
    Color = clBtnFace
    ParentColor = False
    TabOrder = 1
    OnResize = ScrollBox1Resize
    DesignSize = (
      349
      290)
    object Image1: TImage
      Left = 152
      Top = 16
      Width = 41
      Height = 41
      OnMouseDown = Image1MouseDown
      OnMouseMove = Image1MouseMove
      OnMouseUp = Image1MouseUp
    end
    object ScBarH: TScrollBar
      Left = 0
      Top = 18
      Width = 271
      Height = 16
      Anchors = [akLeft, akRight, akBottom]
      LargeChange = 50
      Min = 1
      PageSize = 50
      Position = 1
      SmallChange = 5
      TabOrder = 1
      TabStop = False
      OnChange = ScBarChange
      OnScroll = ScBarScroll
    end
    object ScBarV: TScrollBar
      Left = 273
      Top = 0
      Width = 16
      Height = 16
      Anchors = [akTop, akRight, akBottom]
      Kind = sbVertical
      Min = 1
      PageSize = 0
      Position = 1
      TabOrder = 0
      TabStop = False
      OnChange = ScBarChange
      OnScroll = ScBarScroll
    end
  end
  object PnlTools: TPanel
    Left = 0
    Top = 0
    Width = 353
    Height = 33
    Align = alTop
    AutoSize = True
    ParentBackground = False
    TabOrder = 0
    object Label1: TLabel
      Left = 298
      Top = 3
      Width = 51
      Height = 13
      Caption = '(0, 0) (0, 0)'
    end
    object BSizeTracker: TProgressBar
      Left = 48
      Top = 23
      Width = 105
      Height = 9
      Min = 1
      Max = 300
      Position = 24
      Smooth = True
      TabOrder = 5
      Visible = False
      OnMouseDown = BTrackerMouseDown
      OnMouseMove = BTrackerMouseMove
    end
    object BTransTracker: TProgressBar
      Left = 83
      Top = 23
      Width = 105
      Height = 9
      Position = 90
      Smooth = True
      Step = 1
      TabOrder = 6
      Visible = False
      OnMouseDown = BTrackerMouseDown
      OnMouseMove = BTrackerMouseMove
    end
    object BrushSize: TEdit
      Left = 88
      Top = 3
      Width = 25
      Height = 18
      Hint = 'Brush size'
      TabStop = False
      BevelKind = bkFlat
      BevelOuter = bvRaised
      BorderStyle = bsNone
      ImeName = #1056#1091#1089#1089#1082#1072#1103
      TabOrder = 3
      Text = '24'
      OnKeyPress = BrushSizeKeyPress
    end
    object BrushShape: TComboBox
      Left = 230
      Top = 1
      Width = 64
      Height = 21
      Hint = 'Brush shape'
      BevelKind = bkFlat
      BevelOuter = bvRaised
      Style = csDropDownList
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ImeName = #1056#1091#1089#1089#1082#1072#1103
      ItemHeight = 13
      ItemIndex = 0
      ParentFont = False
      TabOrder = 2
      TabStop = False
      Text = 'Air'
      OnChange = CBoxChange
      Items.Strings = (
        'Air'
        'Solid'
        'Random')
    end
    object BrushTrans: TEdit
      Left = 119
      Top = 3
      Width = 25
      Height = 18
      Hint = 'Brush size'
      TabStop = False
      BevelInner = bvLowered
      BevelKind = bkFlat
      BorderStyle = bsNone
      ImeName = #1056#1091#1089#1089#1082#1072#1103
      TabOrder = 4
      Text = '90'
      OnKeyPress = BrushTransKeyPress
    end
    object BrushBlend: TComboBox
      Left = 1
      Top = 1
      Width = 81
      Height = 21
      Hint = 'Brush blending mode'
      BevelKind = bkFlat
      BevelOuter = bvRaised
      Style = csDropDownList
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ImeName = #1056#1091#1089#1089#1082#1072#1103
      ItemHeight = 13
      ItemIndex = 0
      ParentFont = False
      TabOrder = 0
      TabStop = False
      Text = 'Copy'
      OnChange = CBoxChange
      Items.Strings = (
        'Copy'
        'Add'
        'Substract'
        'Multiply')
    end
    object PaintTool: TComboBox
      Left = 150
      Top = 1
      Width = 74
      Height = 21
      Hint = 'Brush blending mode'
      BevelKind = bkFlat
      BevelOuter = bvRaised
      Style = csDropDownList
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ImeName = #1056#1091#1089#1089#1082#1072#1103
      ItemHeight = 13
      ParentFont = False
      TabOrder = 1
      TabStop = False
      OnChange = CBoxChange
    end
  end
  object MainMenu1: TMainMenu
    Images = ImageList1
    OwnerDraw = True
    Left = 96
    Top = 64
    object FileMenu: TMenuItem
      Caption = 'File'
      object MenuNew: TMenuItem
        Caption = 'New'
        OnClick = MenuNewClick
      end
      object MenuOpen: TMenuItem
        Caption = 'Open'
        ShortCut = 16463
        OnClick = MenuOpenClick
      end
      object MenuSave: TMenuItem
        Caption = 'Save'
        ShortCut = 16467
        OnClick = MenuSaveClick
      end
      object MenuSaveAs: TMenuItem
        Caption = 'Save as'
        OnClick = MenuSaveAsClick
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
        OnClick = MenuOpenAtClick
      end
      object MenuClose: TMenuItem
        Caption = 'Close'
        OnClick = MenuCloseClick
      end
    end
    object EditMenu: TMenuItem
      Caption = 'Edit'
      object Undo1: TMenuItem
        Action = ActImgUndo
      end
      object Redo1: TMenuItem
        Action = ActImgRedo
      end
      object MenuCopy: TMenuItem
        Caption = 'Copy'
        ShortCut = 16451
        OnClick = MenuCopyClick
      end
      object MenuPaste: TMenuItem
        Caption = 'Paste'
        ShortCut = 16470
        OnClick = MenuPasteClick
      end
      object TMenuItem
        Enabled = False
      end
      object MenuResize: TMenuItem
        Caption = 'Resize'
        ShortCut = 16466
        OnClick = MenuResizeClick
      end
      object MenuMkAlpha: TMenuItem
        Action = ActImgMakeAlpha
        Hint = 'Generate alpha channel'
      end
      object Makenormalmap1: TMenuItem
        Action = ActImgMakeNMap
        Hint = 'Generate normal map'
      end
    end
    object ViewMenu: TMenuItem
      Caption = 'View'
      object MenuViewAlpha: TMenuItem
        Caption = 'View alpha'
        Hint = 'Show alpha channel'
        OnClick = MenuViewAlphaClick
      end
      object N3: TMenuItem
        Caption = '-'
      end
      object Prevlevel1: TMenuItem
        Action = ActPrevLevel
      end
      object Nextlevel1: TMenuItem
        Action = ActNextLevel
      end
    end
    object Color: TMenuItem
      Caption = 'Color'
      OnClick = ColorClick
      OnAdvancedDrawItem = ColorAdvancedDrawItem
    end
    object Alpha: TMenuItem
      Caption = 'Alpha'
      OnClick = AlphaClick
      OnAdvancedDrawItem = AlphaAdvancedDrawItem
    end
    object Ontop1: TMenuItem
      Caption = 'On top'
      OnClick = Ontop1Click
    end
    object Deselect1: TMenuItem
      Caption = '___'
      OnClick = Deselect1Click
    end
  end
  object ImageList1: TImageList
    Left = 8
    Top = 40
  end
  object OpenPictureDialog: TOpenPictureDialog
    DefaultExt = 'bmp'
    Filter = 
      'All supported formats (*.bmp;*.jpeg;*.jpg;*.ico;*.emf;*.wmf)|*.b' +
      'mp;*.jpeg;*.jpg;*.ico;*.emf;*.wmf|JPEG Image File (*.jpg)|*.jpg|' +
      'JPEG Image File (*.jpeg)|*.jpeg|Bitmaps (*.bmp)|*.bmp|Icons (*.i' +
      'co)|*.ico|Enhanced Metafiles (*.emf)|*.emf|Metafiles (*.wmf)|*'
    Left = 32
    Top = 32
  end
  object SavePictureDialog: TSavePictureDialog
    DefaultExt = 'bmp'
    Filter = 
      'All supported formats (*.bmp;*.jpeg;*.jpg;*.ico;*.emf;*.wmf)|*.b' +
      'mp;*.jpeg;*.jpg;*.ico;*.emf;*.wmf|JPEG Image File (*.jpg)|*.jpg|' +
      'JPEG Image File (*.jpeg)|*.jpeg|Bitmaps (*.bmp)|*.bmp|Icons (*.i' +
      'co)|*.ico|Enhanced Metafiles (*.emf)|*.emf|Metafiles (*.wmf)|*.w' +
      'mf'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 64
    Top = 32
  end
  object Timer1: TTimer
    Interval = 100
    OnTimer = Timer1Timer
    Left = 32
    Top = 64
  end
  object ColorDialog1: TColorDialog
    Left = 96
    Top = 32
  end
  object ActionList1: TActionList
    Left = 64
    Top = 64
    object ActPrevLevel: TAction
      Category = 'View'
      Caption = 'Prev level'
      Hint = 'View previous mip level'
      OnExecute = ActPrevLevelExecute
    end
    object ActImgMakeAlpha: TAction
      Category = 'Edit'
      Caption = 'Make alpha'
      ShortCut = 49217
      OnExecute = ActImgMakeAlphaExecute
    end
    object ActImgMakeNMap: TAction
      Category = 'Edit'
      Caption = 'Make normal map...'
      ShortCut = 49230
      OnExecute = ActImgMakeNMapExecute
    end
    object ActImgApply: TAction
      Category = 'File'
      Caption = 'Apply'
      HelpKeyword = 'ApplyImage'
      Hint = 'Apply changes'
      OnExecute = ActImgApplyExecute
    end
    object ActDeselect: TAction
      Caption = '___'
      Hint = 'Select none'
      OnExecute = ActDeselectExecute
    end
    object ActNextLevel: TAction
      Category = 'View'
      Caption = 'Next level'
      Hint = 'View next mip level'
      OnExecute = ActNextLevelExecute
    end
    object ActImgUndo: TAction
      Category = 'Edit'
      Caption = 'Undo'
      Hint = 'Undo previous operation'
      ShortCut = 16474
      OnExecute = ActImgUndoExecute
    end
    object ActImgRedo: TAction
      Category = 'Edit'
      Caption = 'Redo'
      Hint = 'Redo previously undone operation'
      ShortCut = 16473
      OnExecute = ActImgRedoExecute
    end
  end
end
