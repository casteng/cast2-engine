object FormNewMaterial: TFormNewMaterial
  Left = 885
  Top = 386
  Width = 370
  Height = 542
  Caption = 'New Material'
  Color = clBtnFace
  Constraints.MinHeight = 210
  Constraints.MinWidth = 170
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  ShowHint = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  DesignSize = (
    362
    515)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 28
    Height = 13
    Caption = 'Name'
  end
  object OnTopBut: TSpeedButton
    Left = 313
    Top = 469
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
  object Label4: TLabel
    Left = 8
    Top = 44
    Width = 51
    Height = 13
    Caption = 'Technique'
  end
  object Label5: TLabel
    Left = 8
    Top = 82
    Width = 23
    Height = 13
    Caption = 'Pass'
  end
  object SButNewTech: TSpeedButton
    Left = 233
    Top = 41
    Width = 57
    Height = 22
    Anchors = [akTop, akRight]
    Caption = 'New'
  end
  object SButDelTech: TSpeedButton
    Left = 297
    Top = 41
    Width = 57
    Height = 22
    Anchors = [akTop, akRight]
    Caption = 'Delete'
  end
  object SButDelPass: TSpeedButton
    Left = 297
    Top = 79
    Width = 57
    Height = 22
    Anchors = [akTop, akRight]
    Caption = 'Delete'
  end
  object SButNewPass: TSpeedButton
    Left = 233
    Top = 79
    Width = 57
    Height = 22
    Anchors = [akTop, akRight]
    Caption = 'New'
  end
  object SButShow: TSpeedButton
    Left = 336
    Top = 6
    Width = 18
    Height = 18
    Hint = 'Show in tree'
    Anchors = [akTop, akRight]
    OnClick = SButShowClick
  end
  object CBoxTechnique: TComboBox
    Left = 72
    Top = 41
    Width = 155
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    ImeName = #1056#1091#1089#1089#1082#1072#1103
    ItemHeight = 13
    TabOrder = 1
    OnChange = CBoxTechniqueChange
  end
  object CBoxPass: TComboBox
    Left = 72
    Top = 79
    Width = 155
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    ImeName = #1056#1091#1089#1089#1082#1072#1103
    ItemHeight = 13
    TabOrder = 2
    OnChange = CBoxPassChange
  end
  object cboxName: TComboBox
    Left = 72
    Top = 5
    Width = 265
    Height = 21
    ImeName = #1056#1091#1089#1089#1082#1072#1103
    ItemHeight = 13
    TabOrder = 0
    OnChange = EditNameChange
  end
  object BtnCreate: TButton
    Left = 8
    Top = 466
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Create'
    Default = True
    TabOrder = 4
    OnClick = BtnCreateClick
  end
  object PageControl1: TPageControl
    Left = 8
    Top = 112
    Width = 346
    Height = 348
    ActivePage = TabSheet1
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 3
    object TabSheet1: TTabSheet
      Caption = 'Stages'
      DesignSize = (
        338
        320)
      object Label2: TLabel
        Left = 3
        Top = 65
        Width = 36
        Height = 13
        Caption = 'Texture'
      end
      object Label3: TLabel
        Left = 3
        Top = 38
        Width = 24
        Height = 13
        Caption = 'Type'
      end
      object Label6: TLabel
        Left = 3
        Top = 11
        Width = 28
        Height = 13
        Caption = 'Stage'
      end
      object SButDelStage: TSpeedButton
        Left = 269
        Top = 7
        Width = 57
        Height = 22
        Anchors = [akTop, akRight]
        Caption = 'Delete'
      end
      object SButNewStage: TSpeedButton
        Left = 206
        Top = 7
        Width = 57
        Height = 22
        Anchors = [akTop, akRight]
        Caption = 'New'
      end
      object CBoxBlend: TComboBox
        Left = 53
        Top = 35
        Width = 275
        Height = 21
        Hint = 'Blending mode'
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        ImeName = #1056#1091#1089#1089#1082#1072#1103
        ItemHeight = 13
        ItemIndex = 0
        TabOrder = 1
        Text = 'Opaque'
        Items.Strings = (
          'Opaque'
          'Alpha test'
          'Alpha blend'
          'Additive blend'
          'Custom')
      end
      object EditTextureName: TEdit
        Left = 53
        Top = 62
        Width = 275
        Height = 21
        Anchors = [akLeft, akTop, akRight]
        ImeName = #1056#1091#1089#1089#1082#1072#1103
        TabOrder = 2
      end
      object ScrollBox1: TScrollBox
        Left = 3
        Top = 96
        Width = 325
        Height = 221
        HorzScrollBar.Visible = False
        VertScrollBar.Tracking = True
        Anchors = [akLeft, akTop, akRight, akBottom]
        TabOrder = 3
        OnMouseWheel = ScrollBox1MouseWheel
        object Panel1: TPanel
          Left = 0
          Top = 0
          Width = 321
          Height = 63
          Align = alTop
          AutoSize = True
          Constraints.MinHeight = 24
          Constraints.MinWidth = 24
          ParentBackground = False
          TabOrder = 0
        end
      end
      object CBoxStage: TComboBox
        Left = 53
        Top = 8
        Width = 147
        Height = 21
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        ImeName = #1056#1091#1089#1089#1082#1072#1103
        ItemHeight = 13
        TabOrder = 0
        OnChange = CBoxStageChange
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'Shaders'
      ImageIndex = 1
      DesignSize = (
        338
        320)
      object Label7: TLabel
        Left = 8
        Top = 12
        Width = 30
        Height = 13
        Caption = 'Vertex'
      end
      object Label8: TLabel
        Left = 8
        Top = 184
        Width = 22
        Height = 13
        Anchors = [akLeft, akBottom]
        Caption = 'Pixel'
      end
      object SButVSShow: TSpeedButton
        Left = 305
        Top = 10
        Width = 18
        Height = 18
        Hint = 'Show in tree'
        Anchors = [akTop, akRight]
        OnClick = SButVSShowClick
      end
      object SButPSShow: TSpeedButton
        Left = 305
        Top = 182
        Width = 18
        Height = 18
        Hint = 'Show in tree'
        Anchors = [akLeft, akBottom]
        OnClick = SButPSShowClick
      end
      object CBoxVertexShader: TComboBox
        Left = 60
        Top = 9
        Width = 239
        Height = 21
        Hint = 'Vertex shader resource'
        Anchors = [akLeft, akTop, akRight]
        ImeName = #1056#1091#1089#1089#1082#1072#1103
        ItemHeight = 0
        TabOrder = 0
      end
      object CBoxPixelShader: TComboBox
        Left = 60
        Top = 181
        Width = 239
        Height = 21
        Anchors = [akLeft, akBottom]
        ImeName = #1056#1091#1089#1089#1082#1072#1103
        ItemHeight = 0
        TabOrder = 1
      end
      object VListPShaderConst: TValueListEditor
        Left = 3
        Top = 208
        Width = 320
        Height = 106
        Anchors = [akLeft, akBottom]
        DefaultColWidth = 32
        DropDownRows = 16
        FixedCols = 1
        ScrollBars = ssVertical
        Strings.Strings = (
          '=')
        TabOrder = 2
        TitleCaptions.Strings = (
          'N'
          'Constant')
        OnKeyDown = VListPShaderConstKeyDown
        OnValidate = VListPShaderConstValidate
        ColWidths = (
          32
          282)
      end
      object VListVShaderConst: TValueListEditor
        Left = 3
        Top = 36
        Width = 320
        Height = 137
        Anchors = [akLeft, akTop, akBottom]
        DefaultColWidth = 32
        DropDownRows = 16
        FixedCols = 1
        KeyOptions = [keyEdit, keyAdd, keyDelete]
        ScrollBars = ssVertical
        Strings.Strings = (
          '=')
        TabOrder = 3
        TitleCaptions.Strings = (
          'N'
          'Constant')
        OnGetPickList = VListVShaderConstGetPickList
        OnKeyDown = VListVShaderConstKeyDown
        OnValidate = VListVShaderConstValidate
        ColWidths = (
          32
          282)
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'Declaration'
      ImageIndex = 2
    end
    object TabSheet4: TTabSheet
      Caption = 'Presets'
      ImageIndex = 3
    end
  end
  object Timer1: TTimer
    Interval = 300
    OnTimer = Timer1Timer
    Left = 8
    Top = 24
  end
end
