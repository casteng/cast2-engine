object ModelLoadF: TModelLoadF
  Left = 380
  Top = 428
  Width = 220
  Height = 159
  Caption = 'Multiple Files Selected. Load As:'
  Color = clBtnFace
  Constraints.MinWidth = 220
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  ShowHint = True
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 212
    Height = 100
    ActivePage = TabSheet2
    Align = alClient
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'Single Meshes'
    end
    object TabSheet2: TTabSheet
      Caption = 'Animated'
      ImageIndex = 1
      DesignSize = (
        204
        72)
      object SnapIndexEdit: TEdit
        Left = 132
        Top = 4
        Width = 57
        Height = 21
        Anchors = [akTop, akRight]
        TabOrder = 0
        Text = '0'
      end
      object SnapCBox: TCheckBox
        Left = 8
        Top = 8
        Width = 113
        Height = 17
        Hint = 
          'Align all animation frames in such a way that the selected verte' +
          'x has the same coordinates in all frames'
        Caption = 'Snap to vertex #'
        TabOrder = 1
      end
    end
  end
  object Panel1: TPanel
    Left = 0
    Top = 100
    Width = 212
    Height = 28
    Align = alBottom
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 1
    DesignSize = (
      212
      28)
    object OKBut: TButton
      Left = 2
      Top = 2
      Width = 75
      Height = 25
      Anchors = [akLeft, akBottom]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object CancelBut: TButton
      Left = 135
      Top = 2
      Width = 75
      Height = 25
      Anchors = [akRight, akBottom]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
