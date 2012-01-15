object TextEditForm: TTextEditForm
  Left = 783
  Top = 427
  Caption = 'Resource Edit'
  ClientHeight = 306
  ClientWidth = 468
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    468
    306)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 12
    Width = 46
    Height = 13
    Caption = 'Resource'
  end
  object ResNameEdit: TEdit
    Left = 80
    Top = 8
    Width = 379
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
  end
  object ApplyButton: TButton
    Left = 8
    Top = 265
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Apply'
    Default = True
    TabOrder = 2
    OnClick = ApplyButtonClick
  end
  object RevertButton: TButton
    Left = 386
    Top = 265
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Revert'
    TabOrder = 3
    OnClick = RevertButtonClick
  end
  object SourceEdit: TSynEdit
    Left = 8
    Top = 32
    Width = 451
    Height = 227
    Anchors = [akLeft, akTop, akRight, akBottom]
    ActiveLineColor = clWindow
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Courier New'
    Font.Style = []
    TabOrder = 1
    Gutter.AutoSize = True
    Gutter.DigitCount = 2
    Gutter.Font.Charset = DEFAULT_CHARSET
    Gutter.Font.Color = clWindowText
    Gutter.Font.Height = -11
    Gutter.Font.Name = 'Courier New'
    Gutter.Font.Style = []
    Gutter.LeftOffset = 0
    Gutter.RightOffset = 1
    Gutter.ShowLineNumbers = True
    Gutter.Width = 22
    Gutter.Gradient = True
    Gutter.GradientStartColor = clGradientInactiveCaption
    Gutter.GradientEndColor = clGradientActiveCaption
    Gutter.GradientSteps = 16
    MaxScrollWidth = 1
    Options = [eoAutoIndent, eoAutoSizeMaxScrollWidth, eoDragDropEditing, eoEnhanceHomeKey, eoEnhanceEndKey, eoGroupUndo, eoHideShowScrollbars, eoScrollHintFollows, eoScrollPastEol, eoShowScrollHint, eoSmartTabDelete, eoSmartTabs, eoTabsToSpaces, eoTrimTrailingSpaces]
    WantTabs = True
  end
  object SynGeneralSyn1: TSynGeneralSyn
    Comments = []
    DetectPreprocessor = False
    IdentifierChars = '_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    Left = 168
    Top = 288
  end
  object SynIniSyn1: TSynIniSyn
    Left = 120
    Top = 288
  end
  object SynJavaSyn1: TSynJavaSyn
    Left = 208
    Top = 288
  end
end
