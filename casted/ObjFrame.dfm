object ItemsFrame: TItemsFrame
  Left = 0
  Top = 0
  Width = 297
  Height = 271
  ParentShowHint = False
  ShowHint = True
  TabOrder = 0
  object Tree: TVirtualStringTree
    Left = 0
    Top = 0
    Width = 297
    Height = 253
    Align = alClient
    ButtonFillMode = fmShaded
    ButtonStyle = bsTriangle
    CheckImageKind = ckXP
    ClipboardFormats.Strings = (
      'CSV'
      'Plain text'
      'Virtual Tree Data')
    Color = cl3DLight
    Colors.GridLineColor = clActiveCaption
    Colors.UnfocusedSelectionColor = clMedGray
    DrawSelectionMode = smBlendedRectangle
    Header.AutoSizeIndex = -1
    Header.DefaultHeight = 17
    Header.Font.Charset = DEFAULT_CHARSET
    Header.Font.Color = clWindowText
    Header.Font.Height = -11
    Header.Font.Name = 'MS Sans Serif'
    Header.Font.Style = []
    Header.Options = [hoColumnResize, hoDrag, hoShowHint, hoShowSortGlyphs, hoVisible]
    HintMode = hmTooltip
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
    TreeOptions.AutoOptions = [toAutoDropExpand, toAutoScroll, toAutoScrollOnExpand, toAutoDeleteMovedNodes]
    TreeOptions.MiscOptions = [toAcceptOLEDrop, toCheckSupport, toEditable, toFullRepaintOnResize, toGridExtensions, toInitOnSave, toToggleOnDblClick, toWheelPanning, toVariableNodeHeight]
    TreeOptions.PaintOptions = [toShowButtons, toShowDropmark, toShowHorzGridLines, toShowRoot, toShowTreeLines, toShowVertGridLines, toThemeAware, toUseBlendedImages, toUseBlendedSelection]
    TreeOptions.SelectionOptions = [toExtendedFocus, toFullRowSelect, toMultiSelect, toRightClickSelect]
    Visible = False
    OnAfterCellPaint = TreeAfterCellPaint
    OnChecking = TreeChecking
    OnCompareNodes = TreeCompareNodes
    OnEditing = TreeEditing
    OnGetCellIsEmpty = TreeGetCellIsEmpty
    OnGetText = TreeGetText
    OnHeaderClick = TreeHeaderClick
    OnInitNode = TreeInitNode
    OnMeasureItem = TreeMeasureItem
    OnNewText = TreeNewText
    Columns = <
      item
        Position = 0
        Width = 110
        WideText = 'Name'
        WideHint = 'Item name'
      end
      item
        Position = 1
        Style = vsOwnerDraw
        WideText = 'Preview'
      end
      item
        Options = [coAllowClick, coDraggable, coEnabled, coParentBidiMode, coParentColor, coShowDropMark, coVisible]
        Position = 2
        Width = 85
        WideText = 'Class'
        WideHint = 'Item class'
      end
      item
        Position = 3
        WideText = 'Status'
        WideHint = 'Item status'
      end>
    WideDefaultText = 'Undefined'
  end
  object ButtonsPanel: TPanel
    Left = 0
    Top = 253
    Width = 297
    Height = 18
    Align = alBottom
    ParentBackground = False
    TabOrder = 1
    object RenderModeBut: TSpeedButton
      Left = 0
      Top = 0
      Width = 60
      Height = 18
      Hint = 'Push to control rendering with object checkboxes'
      GroupIndex = 1
      Down = True
      Caption = 'Render'
      Flat = True
      OnClick = RenderModeButClick
    end
    object ProcessModeBut: TSpeedButton
      Left = 60
      Top = 0
      Width = 60
      Height = 18
      Hint = 'Push to control processing with object checkboxes'
      GroupIndex = 1
      Caption = 'Process'
      OnClick = RenderModeButClick
    end
    object BoundsModeBut: TSpeedButton
      Left = 152
      Top = 0
      Width = 60
      Height = 18
      Hint = 
        'Push to control bounding volumes visualisation with object check' +
        'boxes'
      GroupIndex = 1
      Caption = 'Bounds'
      OnClick = RenderModeButClick
    end
    object DisableTessButton: TSpeedButton
      Left = 222
      Top = 0
      Width = 24
      Height = 18
      Hint = 'Disable tesselation'
      AllowAllUp = True
      GroupIndex = 2
      Caption = '#'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object BtnPause: TPngSpeedButton
      Left = 124
      Top = 0
      Width = 24
      Height = 18
      AllowAllUp = True
    end
    object ProgressBar1: TProgressBar
      Left = 224
      Top = 9
      Width = 144
      Height = 16
      TabOrder = 0
      Visible = False
    end
  end
end
