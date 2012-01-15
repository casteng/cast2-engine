object UVForm: TUVForm
  Left = 1214
  Top = 871
  Width = 483
  Height = 301
  Caption = 'UV mapping'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  KeyPreview = True
  OldCreateOrder = False
  ShowHint = True
  OnActivate = FormActivate
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  DesignSize = (
    475
    270)
  PixelsPerInch = 96
  TextHeight = 13
  object Label5: TLabel
    Left = 8
    Top = 8
    Width = 28
    Height = 13
    Caption = 'Name'
  end
  object Label7: TLabel
    Left = 8
    Top = 232
    Width = 50
    Height = 13
    Caption = 'Image size'
  end
  object OnTopBut: TSpeedButton
    Left = 416
    Top = 253
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
  object NameEdit: TEdit
    Left = 80
    Top = 4
    Width = 105
    Height = 21
    Hint = 'Resource name'
    TabOrder = 0
    Text = 'UVM_'
  end
  object ApplyBut: TButton
    Left = 8
    Top = 249
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Apply'
    ModalResult = 1
    TabOrder = 7
    OnClick = ApplyButClick
  end
  object ImgWidthEdit: TEdit
    Left = 64
    Top = 228
    Width = 41
    Height = 21
    TabOrder = 4
    Text = '1024'
    OnChange = ImgWidthEditChange
    OnEnter = ImgWidthEditChange
  end
  object ImgHeightEdit: TEdit
    Left = 112
    Top = 228
    Width = 41
    Height = 21
    TabOrder = 5
    Text = '1024'
    OnChange = ImgWidthEditChange
    OnEnter = ImgWidthEditChange
  end
  object UVGrid: TStringGrid
    Left = 192
    Top = 4
    Width = 264
    Height = 243
    Anchors = [akLeft, akTop, akRight, akBottom]
    Ctl3D = True
    DefaultRowHeight = 16
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goRowSelect, goThumbTracking]
    ParentCtl3D = False
    TabOrder = 9
    OnClick = UVGridClick
    ColWidths = (
      22
      64
      64
      64
      64)
  end
  object Panel1: TPanel
    Left = 4
    Top = 32
    Width = 185
    Height = 105
    ParentBackground = False
    TabOrder = 1
    object Label3: TLabel
      Left = 32
      Top = 8
      Width = 28
      Height = 13
      Caption = 'Offset'
    end
    object Label1: TLabel
      Left = 28
      Top = 56
      Width = 34
      Height = 13
      Caption = 'Frames'
    end
    object WidthEdit: TEdit
      Left = 72
      Top = 28
      Width = 49
      Height = 21
      Hint = 'Width or right edge'
      TabOrder = 2
      Text = '64'
      OnChange = UOfsEditChange
      OnEnter = UOfsEditChange
    end
    object HeightEdit: TEdit
      Left = 128
      Top = 28
      Width = 49
      Height = 21
      Hint = 'Height or bottom edge'
      TabOrder = 3
      Text = '64'
      OnChange = UOfsEditChange
      OnEnter = UOfsEditChange
    end
    object UOfsEdit: TEdit
      Left = 72
      Top = 4
      Width = 49
      Height = 21
      Hint = 'U coordinate offset'
      TabOrder = 0
      Text = '0'
      OnChange = UOfsEditChange
      OnEnter = UOfsEditChange
    end
    object VOfsEdit: TEdit
      Left = 128
      Top = 4
      Width = 49
      Height = 21
      Hint = 'V coordinate offset'
      TabOrder = 1
      Text = '0'
      OnChange = UOfsEditChange
      OnEnter = UOfsEditChange
    end
    object FramesEdit: TEdit
      Left = 72
      Top = 52
      Width = 49
      Height = 21
      Hint = 'Number of frames to add'
      TabOrder = 4
      Text = '1'
      OnChange = UOfsEditChange
      OnEnter = UOfsEditChange
    end
    object VerticalCBox: TCheckBox
      Left = 8
      Top = 79
      Width = 57
      Height = 17
      Hint = 'Check to add several frames vertically'
      Caption = 'Vertical'
      TabOrder = 5
    end
    object AddBut: TButton
      Left = 128
      Top = 56
      Width = 51
      Height = 45
      Caption = 'Add'
      TabOrder = 6
      OnClick = AddButClick
    end
    object EndKindCBox: TComboBox
      Left = 8
      Top = 28
      Width = 57
      Height = 21
      Hint = 'Second coordinate mode'
      Style = csDropDownList
      ItemHeight = 13
      ItemIndex = 0
      TabOrder = 7
      Text = 'W/H'
      Items.Strings = (
        'W/H'
        'End')
    end
  end
  object Panel2: TPanel
    Left = 4
    Top = 144
    Width = 185
    Height = 52
    ParentBackground = False
    TabOrder = 2
    object UParEdit: TEdit
      Left = 8
      Top = 4
      Width = 49
      Height = 21
      Hint = 'Value to add to U or width'
      TabOrder = 0
      Text = '0'
      OnChange = UParEditChange
      OnEnter = UParEditChange
    end
    object VParEdit: TEdit
      Left = 64
      Top = 4
      Width = 49
      Height = 21
      Hint = 'Value to add to V or height'
      TabOrder = 1
      Text = '0'
      OnChange = UParEditChange
      OnEnter = UParEditChange
    end
    object ModBut: TButton
      Left = 128
      Top = 3
      Width = 51
      Height = 45
      Caption = 'Modify'
      TabOrder = 2
      OnClick = ModButClick
    end
    object OpTypeCBox: TComboBox
      Left = 8
      Top = 27
      Width = 105
      Height = 21
      Hint = 'What to modify'
      Style = csDropDownList
      ItemHeight = 13
      ItemIndex = 0
      TabOrder = 3
      Text = 'Add to U/V'
      OnChange = UParEditChange
      OnEnter = UParEditChange
      Items.Strings = (
        'Add to U/V'
        'Add to W/H')
    end
  end
  object RemoveBut: TButton
    Left = 80
    Top = 200
    Width = 65
    Height = 25
    Hint = 'Remove element selected in list on the right'
    Caption = 'Remove'
    TabOrder = 3
    OnClick = RemoveButClick
  end
  object ShowBut: TButton
    Left = 96
    Top = 249
    Width = 75
    Height = 25
    Hint = 
      'Show selected elements on image. An image should be selected in ' +
      'images window'
    Anchors = [akLeft, akBottom]
    Caption = 'Show'
    Default = True
    TabOrder = 8
    OnClick = ShowButClick
  end
  object RefreshBut: TButton
    Left = 224
    Top = 249
    Width = 51
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Refresh'
    TabOrder = 6
    OnClick = RefreshButClick
  end
  object SaveBut: TButton
    Left = 308
    Top = 250
    Width = 57
    Height = 24
    Hint = 'Save UV mapping to file'
    Anchors = [akLeft, akBottom]
    Caption = 'Save'
    TabOrder = 10
    OnClick = SaveButClick
  end
  object LoadBut: TButton
    Left = 370
    Top = 250
    Width = 57
    Height = 24
    Hint = 'Load UV mapping from file'
    Anchors = [akLeft, akBottom]
    Caption = 'Load'
    TabOrder = 11
    OnClick = LoadButClick
  end
  object AddSelBut: TButton
    Left = 8
    Top = 200
    Width = 65
    Height = 25
    Hint = 'Add currently select on image area'
    Caption = 'Add area'
    TabOrder = 12
    OnClick = AddSelButClick
  end
  object ObjUpDown: TUpDown
    Left = 168
    Top = 200
    Width = 24
    Height = 49
    Hint = 'Move element'
    Max = 2
    Position = 1
    TabOrder = 13
    Wrap = True
    OnChangingEx = ObjUpDownChangingEx
  end
  object UVOpenDialog: TOpenDialog
    DefaultExt = 'uvf'
    Filter = 'UVF Files |*.uvf'
    Title = 'Load UVF mapping'
    Left = 384
    Top = 248
  end
  object UVSaveDialog: TSaveDialog
    DefaultExt = 'uvf'
    Left = 320
    Top = 248
  end
end
