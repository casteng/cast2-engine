object PropsFrame: TPropsFrame
  Left = 0
  Top = 0
  Width = 239
  Height = 265
  TabOrder = 0
  object Tree: TVirtualStringTree
    Left = 0
    Top = 0
    Width = 239
    Height = 265
    Align = alClient
    Color = cl3DLight
    Colors.GridLineColor = clActiveCaption
    Colors.UnfocusedSelectionColor = clHighlight
    Colors.UnfocusedSelectionBorderColor = clBlack
    DrawSelectionMode = smBlendedRectangle
    Header.AutoSizeIndex = 1
    Header.DefaultHeight = 17
    Header.Font.Charset = DEFAULT_CHARSET
    Header.Font.Color = clWindowText
    Header.Font.Height = -11
    Header.Font.Name = 'MS Sans Serif'
    Header.Font.Style = []
    Header.Options = [hoAutoResize, hoColumnResize, hoDrag, hoShowHint, hoShowSortGlyphs, hoVisible]
    HintMode = hmTooltip
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
    TreeOptions.AutoOptions = [toAutoDropExpand, toAutoScroll, toAutoScrollOnExpand, toAutoSort, toAutoTristateTracking, toAutoDeleteMovedNodes]
    TreeOptions.MiscOptions = [toAcceptOLEDrop, toFullRepaintOnResize, toGridExtensions, toInitOnSave, toToggleOnDblClick, toWheelPanning]
    TreeOptions.PaintOptions = [toShowButtons, toShowDropmark, toShowHorzGridLines, toShowRoot, toShowTreeLines, toShowVertGridLines, toThemeAware, toUseBlendedImages, toFullVertGridLines]
    TreeOptions.SelectionOptions = [toExtendedFocus, toMultiSelect, toRightClickSelect]
    OnAfterCellPaint = TreeAfterCellPaint
    OnCollapsed = TreeExpanded
    OnColumnResize = TreeColumnResize
    OnCompareNodes = TreeCompareNodes
    OnExpanded = TreeExpanded
    OnFocusChanged = TreeFocusChanged
    OnGetText = TreeGetText
    OnKeyAction = TreeKeyAction
    Columns = <
      item
        Position = 0
        Width = 120
        WideText = 'Name'
        WideHint = 'Property name'
      end
      item
        Options = [coAllowClick, coDraggable, coEnabled, coParentBidiMode, coParentColor, coResizable, coShowDropMark, coVisible, coAutoSpring, coAllowFocus]
        Position = 1
        Width = 105
        WideText = 'Value'
        WideHint = 'Property value'
      end
      item
        Position = 2
        Width = 10
        WideText = 'Type'
        WideHint = 'Property value type'
      end>
    WideDefaultText = 'Undefined'
  end
end
