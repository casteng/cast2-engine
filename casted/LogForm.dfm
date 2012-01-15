object LogF: TLogF
  Left = 500
  Top = 530
  BorderStyle = bsSizeToolWin
  Caption = 'Log'
  ClientHeight = 186
  ClientWidth = 367
  Color = clBtnFace
  Constraints.MinHeight = 125
  Constraints.MinWidth = 100
  DragKind = dkDock
  DragMode = dmAutomatic
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  Icon.Data = {
    0000010001001010000001002000680400001600000028000000100000002000
    0000010020000000000000000000000000000000000000000000000000009CA5
    A21498A09D9A929A97F68D9592FC878F8CFC828A87FC7E8582FC79807DFC747C
    78FC707874FC6B736FFC666E6AFC606864FC5B625FF5575E5A97515854119EA6
    A39AB4B9B7FBCCCECDFFBEC1C0FFAEB1B0FF9DA1A0FF959998FF909593FF8C91
    8FFF878C8BFF828786FF7E8381FF797F7DFF737A77FF606663F9525955909DA6
    A3F6D6D8D7FF232423FF020302FF010201FF010201FF010201FF010201FF0102
    01FF010201FF010201FF010201FF010201FF121413FF727976FF525955F39CA5
    A2FCD7D8D7FF060606FF111F18FF111F18FF111F18FF111F18FF111F18FF111F
    18FF111F18FF112018FF112019FF112019FF000000FF7A807EFF515854FF9CA5
    A2FCD7D8D7FF060706FF1A3126FF1A3227FF1B3227FF1B3227FF1B3328FF1B33
    28FF1B3428FF1C3429FF1C3429FF1C3529FF000000FF7D8381FF515854FF9CA5
    A2FCD7D8D7FF060707FF1D3329FF1A3127FF193027FF193127FFF1F3F2FFF1F3
    F2FFF1F3F2FFEAEDECFF1A3228FF1A3228FF000000FF818684FF515854FF9CA5
    A2FCD7D8D7FF060707FF3A5A4CFFC8D1CEFF647D73FF274A3BFF264A3BFF264A
    3BFF264A3BFF274B3CFF274B3CFF274C3CFF000000FF838987FF515854FF9CA5
    A2FCD7D8D7FF060807FF3D564CFF556A61FFCBD3CFFFCDD6D3FF254537FF2343
    36FF234436FF234436FF234536FF234537FF000000FF878C8AFF515854FF9CA5
    A2FCD7D8D7FF080909FF5F8273FF8AA399FFDBE3E0FFC6D2CDFF507869FF3765
    53FF32614EFF32624FFF32624FFF32634FFF000000FF8A8F8DFF515854FF9CA5
    A2FCD7D8D7FF090B0AFF59756AFFD4DED9FF6C847AFF527165FF517164FF4D6E
    61FF365E4EFF2B5646FF2B5646FF2C5746FF000000FF8D9291FF515854FF9CA5
    A2FCD7D8D7FF0A0C0BFF81A697FF7FA495FF7DA294FF79A292FF76A090FF749F
    8EFF729D8CFF699885FF548975FF417C65FF000000FF909593FF515854FF9CA5
    A2FCD7D8D7FF0C0E0DFF749084FF719084FF708E82FF6D8D80FF6B8C7FFF698B
    7EFF67897CFF65887BFF648779FF608576FF000000FF939896FF515854FF9CA5
    A2FCD7D8D7FF0D100FFF9BBFB1FF98BEAFFF97BDAEFF94BCACFF92BAAAFF90B9
    A9FF8EB8A8FF8DB6A5FF8AB5A4FF87B3A2FF000000FF979B9AFF515854FF9DA6
    A3F4D5D7D6FF333634FF070808FF070808FF070808FF070808FF070808FF0708
    08FF070808FF070808FF060707FF060707FF2D312FFF969998FF525955F09DA6
    A392B1B6B4FAD5D7D7FFDDDEDDFFDCDEDDFFDCDDDDFFDCDDDDFFDCDDDDFFDCDD
    DDFFDCDDDDFFDCDDDDFFD9DBDBFFCBCDCCFFB1B4B2FF727774F9525955889CA5
    A20E98A09D87949C99EE8D9592FB88908DFB838B88FB7E8683FB7A817EFB757D
    79FB707874FB6B736FFB666E6AFB616965FB5E6562EC575E5A835158540CFFFF
    0000C00300008001000080000000800000008000000080000000800000008000
    00008000000080000000800000008000000080010000C0030000FFFF0000}
  OldCreateOrder = False
  ShowHint = True
  Visible = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  DesignSize = (
    367
    186)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 0
    Top = 166
    Width = 27
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Mode'
  end
  object OnTopBut: TSpeedButton
    Left = 325
    Top = 162
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
  object ClearLogBut: TButton
    Left = 245
    Top = 162
    Width = 75
    Height = 22
    Hint = 'Clear log'
    Anchors = [akRight, akBottom]
    Caption = 'Clear'
    TabOrder = 2
    OnClick = ClearLogButClick
  end
  object LogModeCBox: TComboBox
    Left = 32
    Top = 162
    Width = 81
    Height = 21
    Hint = 'Current logging level'
    Style = csDropDownList
    Anchors = [akLeft, akBottom]
    ItemIndex = 0
    TabOrder = 1
    Text = 'Debug'
    OnChange = LogModeCBoxChange
    Items.Strings = (
      'Debug'
      'Info'
      'Notice'
      'Warning'
      'Error'
      'Fatal error'
      'Quiet')
  end
  object LogPageControl: TPageControl
    Left = 0
    Top = 0
    Width = 366
    Height = 161
    ActivePage = TabSheet1
    Anchors = [akLeft, akTop, akRight, akBottom]
    MultiLine = True
    TabHeight = 16
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'All'
      object LogMemo: TMemo
        Left = 0
        Top = 0
        Width = 358
        Height = 135
        Align = alClient
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'Debug'
      ImageIndex = 1
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object DebugLogMemo: TMemo
        Left = 0
        Top = 0
        Width = 358
        Height = 135
        Align = alClient
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'Info'
      ImageIndex = 2
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object InfoLogMemo: TMemo
        Left = 0
        Top = 0
        Width = 358
        Height = 135
        Align = alClient
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
    object TabSheet4: TTabSheet
      Caption = 'Warnings'
      ImageIndex = 3
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object WarningsLogMemo: TMemo
        Left = 0
        Top = 0
        Width = 309
        Height = 128
        Align = alClient
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
    object TabSheet5: TTabSheet
      Caption = 'Errors'
      ImageIndex = 4
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object ErrorsLogMemo: TMemo
        Left = 0
        Top = 0
        Width = 309
        Height = 128
        Align = alClient
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
  end
end
