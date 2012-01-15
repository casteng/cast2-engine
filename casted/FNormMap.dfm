object NormMapForm: TNormMapForm
  Left = 492
  Top = 274
  BorderStyle = bsSizeToolWin
  Caption = 'Normal Map Generation'
  ClientHeight = 83
  ClientWidth = 208
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  inline PropsFrame1: TPropsFrame
    Left = 0
    Top = 0
    Width = 208
    Height = 62
    Align = alClient
    TabOrder = 0
    inherited Tree: TVirtualStringTree
      Width = 208
      Height = 62
      Columns = <
        item
          Position = 0
          Width = 120
          WideText = 'Name'
          WideHint = 'Property name'
        end
        item
          Position = 1
          Width = 74
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
  object Panel1: TPanel
    Left = 0
    Top = 62
    Width = 208
    Height = 21
    Align = alBottom
    AutoSize = True
    TabOrder = 1
    DesignSize = (
      208
      21)
    object BtnOK: TButton
      Left = 4
      Top = 2
      Width = 64
      Height = 18
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = BtnOKClick
    end
    object BtnCancel: TButton
      Left = 138
      Top = 1
      Width = 64
      Height = 18
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
      OnClick = BtnCancelClick
    end
  end
end
