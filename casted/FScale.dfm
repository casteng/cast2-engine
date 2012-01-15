object ScaleForm: TScaleForm
  Left = 1014
  Top = 744
  AutoSize = True
  BorderStyle = bsToolWindow
  Caption = 'Modify Mesh Components'
  ClientHeight = 159
  ClientWidth = 281
  Color = clBtnFace
  Constraints.MaxHeight = 190
  Constraints.MaxWidth = 291
  Constraints.MinHeight = 181
  Constraints.MinWidth = 287
  DockSite = True
  DragKind = dkDock
  DragMode = dmAutomatic
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  ShowHint = True
  OnActivate = FormActivate
  OnShow = FormActivate
  DesignSize = (
    281
    159)
  PixelsPerInch = 96
  TextHeight = 13
  object OnTopBut: TSpeedButton
    Left = 240
    Top = 137
    Width = 41
    Height = 22
    AllowAllUp = True
    Anchors = [akRight, akBottom]
    GroupIndex = 1
    Down = True
    Caption = 'On top'
    OnClick = OnTopButClick
  end
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 281
    Height = 132
    ActivePage = TabSheet5
    MultiLine = True
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'XYZ'
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object ScaleXEdit: TEdit
        Left = 5
        Top = 8
        Width = 49
        Height = 21
        Hint = 'Scale X component'
        TabOrder = 0
        Text = '1'
        OnChange = ScaleXEditChange
        OnEnter = ScaleEditEnter
      end
      object RotXEdit: TEdit
        Left = 5
        Top = 32
        Width = 49
        Height = 21
        Hint = 'Rotate X component'
        TabOrder = 5
        Text = '0'
        OnChange = ScaleXEditChange
        OnEnter = RotateEditEnter
      end
      object MoveXEdit: TEdit
        Left = 5
        Top = 56
        Width = 49
        Height = 21
        Hint = 'Move X component'
        TabOrder = 9
        Text = '0'
        OnChange = ScaleXEditChange
        OnEnter = MoveEditEnter
      end
      object MoveYEdit: TEdit
        Left = 57
        Top = 56
        Width = 49
        Height = 21
        Hint = 'Move Y component'
        TabOrder = 10
        Text = '0'
        OnChange = ScaleXEditChange
        OnEnter = MoveEditEnter
      end
      object RotYEdit: TEdit
        Left = 57
        Top = 32
        Width = 49
        Height = 21
        Hint = 'Rotate Y component'
        TabOrder = 6
        Text = '0'
        OnChange = ScaleXEditChange
        OnEnter = RotateEditEnter
      end
      object ScaleYEdit: TEdit
        Left = 57
        Top = 8
        Width = 49
        Height = 21
        Hint = 'Scale Y component'
        TabOrder = 1
        Text = '1'
        OnChange = ScaleXEditChange
        OnEnter = ScaleEditEnter
      end
      object ScaleZEdit: TEdit
        Left = 109
        Top = 8
        Width = 49
        Height = 21
        Hint = 'Scale Z component'
        TabOrder = 2
        Text = '1'
        OnChange = ScaleXEditChange
        OnEnter = ScaleEditEnter
      end
      object RotZEdit: TEdit
        Left = 109
        Top = 32
        Width = 49
        Height = 21
        Hint = 'Rotate Z component'
        TabOrder = 7
        Text = '0'
        OnChange = ScaleXEditChange
        OnEnter = RotateEditEnter
      end
      object MoveZEdit: TEdit
        Left = 109
        Top = 56
        Width = 49
        Height = 21
        Hint = 'Move Z component'
        TabOrder = 11
        Text = '0'
        OnChange = ScaleXEditChange
        OnEnter = MoveEditEnter
      end
      object MoveBut: TButton
        Left = 165
        Top = 56
        Width = 49
        Height = 21
        Hint = 'Perform move'
        Caption = 'Move'
        TabOrder = 12
        OnClick = MoveButClick
      end
      object RotBut: TButton
        Left = 165
        Top = 32
        Width = 49
        Height = 21
        Hint = 'Perform rotate'
        Caption = 'Rotate'
        TabOrder = 8
        OnClick = RotButClick
      end
      object ScaleBut: TButton
        Left = 165
        Top = 8
        Width = 49
        Height = 21
        Hint = 'Perform scale'
        Caption = 'Scale'
        Default = True
        TabOrder = 3
        OnClick = ScaleButClick
      end
      object AlignBut: TButton
        Left = 219
        Top = 8
        Width = 49
        Height = 21
        Hint = 'Scale mesh to fit in X scale component units'
        Caption = 'Align'
        TabOrder = 4
        OnClick = AlignButClick
      end
      object CalcNormBut: TButton
        Left = 5
        Top = 80
        Width = 92
        Height = 21
        Hint = 'Calculate normals'
        Caption = 'Calc. normals'
        Enabled = False
        TabOrder = 13
      end
      object InvNormBut: TButton
        Left = 109
        Top = 80
        Width = 92
        Height = 21
        Hint = 'Inverse normals direction'
        Caption = 'Inv. normals'
        TabOrder = 14
        OnClick = InvNormButClick
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'UVW'
      ImageIndex = 1
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      DesignSize = (
        273
        104)
      object ScaleUEdit: TEdit
        Left = 117
        Top = 8
        Width = 49
        Height = 21
        TabOrder = 1
        Text = '1'
        OnChange = ScaleXEditChange
      end
      object MoveUEdit: TEdit
        Left = 5
        Top = 56
        Width = 49
        Height = 21
        TabOrder = 8
        Text = '1'
        OnChange = ScaleXEditChange
      end
      object MoveVEdit: TEdit
        Left = 57
        Top = 56
        Width = 49
        Height = 21
        TabOrder = 9
        Text = '1'
        OnChange = ScaleXEditChange
      end
      object ScaleVEdit: TEdit
        Left = 169
        Top = 8
        Width = 49
        Height = 21
        TabOrder = 2
        Text = '1'
        OnChange = ScaleXEditChange
      end
      object ScaleWEdit: TEdit
        Left = 221
        Top = 8
        Width = 49
        Height = 21
        TabOrder = 3
        Text = '1'
        OnChange = ScaleXEditChange
      end
      object MoveWEdit: TEdit
        Left = 109
        Top = 56
        Width = 49
        Height = 21
        TabOrder = 10
        Text = '1'
        OnChange = ScaleXEditChange
      end
      object TexMoveBut: TButton
        Left = 5
        Top = 32
        Width = 49
        Height = 21
        Caption = 'Move'
        Enabled = False
        TabOrder = 4
      end
      object TexScaleBut: TButton
        Left = 117
        Top = 32
        Width = 49
        Height = 21
        Caption = 'Scale'
        TabOrder = 5
        OnClick = TexScaleButClick
      end
      object TexAlignBut: TButton
        Left = 169
        Top = 32
        Width = 49
        Height = 21
        Caption = 'Align'
        Enabled = False
        TabOrder = 6
      end
      object TexFlipBut: TButton
        Left = 221
        Top = 32
        Width = 49
        Height = 21
        Caption = 'Flip'
        Enabled = False
        TabOrder = 7
      end
      object SetCBox: TComboBox
        Left = 4
        Top = 0
        Width = 105
        Height = 21
        Hint = 'Texture set'
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 0
        Text = 'Texture 0'
        OnChange = SetCBoxChange
        Items.Strings = (
          'Texture 0'
          'Texture 1'
          'Texture 2'
          'Texture 3'
          'Texture 4'
          'Texture 5'
          'Texture 6'
          'Texture 7')
      end
      object TexBoxEdit: TEdit
        Left = 4
        Top = 84
        Width = 265
        Height = 19
        Anchors = [akLeft, akTop, akRight]
        BevelEdges = []
        BevelInner = bvNone
        BevelOuter = bvNone
        Color = clBtnFace
        Constraints.MaxHeight = 19
        Ctl3D = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -10
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentCtl3D = False
        ParentFont = False
        ReadOnly = True
        TabOrder = 11
        OnKeyPress = BBoxEditKeyPress
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'Info'
      ImageIndex = 2
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      DesignSize = (
        273
        104)
      object Label1: TLabel
        Left = 0
        Top = 0
        Width = 25
        Height = 13
        Caption = 'BBox'
      end
      object Label3: TLabel
        Left = 0
        Top = 32
        Width = 42
        Height = 13
        Caption = 'Statistics'
      end
      object BBoxEdit: TEdit
        Left = 64
        Top = 0
        Width = 209
        Height = 19
        Anchors = [akLeft, akTop, akRight]
        BevelEdges = []
        BevelInner = bvNone
        BevelOuter = bvNone
        Color = clBtnFace
        Constraints.MaxHeight = 19
        Ctl3D = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -10
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentCtl3D = False
        ParentFont = False
        ReadOnly = True
        TabOrder = 0
        OnKeyPress = BBoxEditKeyPress
      end
      object ValidateMeshBut: TButton
        Left = 5
        Top = 72
        Width = 75
        Height = 25
        Caption = 'Validate'
        TabOrder = 1
        OnClick = ValidateMeshButClick
      end
    end
    object TabSheet5: TTabSheet
      Caption = 'Optimize'
      ImageIndex = 4
      DesignSize = (
        273
        104)
      object OptStatLabel: TLabel
        Left = 0
        Top = 8
        Width = 9
        Height = 13
        Anchors = [akLeft, akBottom]
        Caption = '---'
      end
      object OptResLabel: TLabel
        Left = 0
        Top = 64
        Width = 9
        Height = 13
        Anchors = [akLeft, akBottom]
        Caption = '---'
      end
      object PBar: TProgressBar
        Left = 0
        Top = 84
        Width = 272
        Height = 16
        Anchors = [akLeft, akRight, akBottom]
        Smooth = True
        Step = 1
        TabOrder = 2
        Visible = False
      end
      object Button1: TButton
        Left = 0
        Top = 31
        Width = 75
        Height = 25
        Hint = 'Remove unnecessary vertices and faces if any'
        Anchors = [akLeft, akBottom]
        Caption = 'Optimize'
        TabOrder = 0
        OnClick = Button1Click
      end
      object AnalizeBut: TButton
        Left = 79
        Top = 31
        Width = 75
        Height = 25
        Hint = 'Check if some vertices or faces can be removed from the mesh'
        Anchors = [akBottom]
        Caption = 'Analize'
        Default = True
        TabOrder = 1
        OnClick = AnalizeButClick
      end
    end
    object TabSheet4: TTabSheet
      Caption = 'Convert'
      ImageIndex = 3
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
    end
  end
  object ReverseBut: TButton
    Left = 109
    Top = 136
    Width = 92
    Height = 21
    Hint = 'Reverese faces order'
    Caption = 'Rev. face order'
    TabOrder = 1
  end
end
