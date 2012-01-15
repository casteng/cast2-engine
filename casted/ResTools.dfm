object FResTools: TFResTools
  Left = 1041
  Top = 406
  AutoSize = True
  BorderStyle = bsToolWindow
  Caption = 'Resource Tools'
  ClientHeight = 111
  ClientWidth = 206
  Color = clBtnFace
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
  DesignSize = (
    206
    111)
  PixelsPerInch = 96
  TextHeight = 13
  object OnTopBut: TSpeedButton
    Left = 165
    Top = 89
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
  object GroupBox1: TGroupBox
    Left = 0
    Top = 0
    Width = 113
    Height = 105
    Caption = 'Creation'
    TabOrder = 0
    object LoadPicBut: TButton
      Left = 9
      Top = 36
      Width = 96
      Height = 17
      Hint = 'Add picture resource to scene as a resource'
      HelpContext = 4
      Caption = 'Load picture'
      TabOrder = 1
      OnClick = LoadPicButClick
    end
    object LoadUVBut: TButton
      Left = 9
      Top = 60
      Width = 96
      Height = 17
      Hint = 'Load UV map resource'
      HelpContext = 4
      Caption = 'Load UV map'
      TabOrder = 2
      OnClick = LoadUVButClick
    end
    object AddWavBut: TButton
      Left = 8
      Top = 80
      Width = 97
      Height = 17
      Hint = 'Load a sound as a resource'
      Caption = 'Load WAV file'
      TabOrder = 3
      OnClick = AddWavButClick
    end
    object AddMeshBut: TButton
      Left = 9
      Top = 16
      Width = 96
      Height = 17
      Hint = 'Add a mesh to scene'
      HelpContext = 4
      Caption = 'Load model'
      TabOrder = 0
      OnClick = AddMeshButClick
    end
  end
  object GroupBox2: TGroupBox
    Left = 120
    Top = 0
    Width = 81
    Height = 81
    Caption = 'Action'
    TabOrder = 1
  end
  object ResMeshOpenDialog: TOpenDialog
    DefaultExt = 'obj'
    Filter = 'Wavefront obj files|*.obj|Direct X mesh|*.x|All files|*.*'
    Options = [ofHideReadOnly, ofAllowMultiSelect, ofFileMustExist, ofEnableSizing]
    Title = 'Load mesh file'
    Left = 88
    Top = 8
  end
  object ResOpenPictureDialog: TOpenPictureDialog
    Filter = 
      'All (*.jpg;*.jpeg;*.bmp;*.ico;*.emf;*.wmf)|*.jpg;*.jpeg;*.bmp;*.' +
      'ico;*.emf;*.wmf|JPEG Image File (*.jpg)|*.jpg|JPEG Image File (*' +
      '.jpeg)|*.jpeg|Bitmaps (*.bmp)|*.bmp|Icons (*.ico)|*.ico|Enhanced' +
      ' Metafiles (*.emf)|*.emf|Metafiles (*.wmf)|*.wmf|IDF Textures (*' +
      '.idf)|*.idf'
    Title = 'Load picture as resource'
    Left = 88
    Top = 32
  end
  object ResExportSaveDialog: TSaveDialog
    DefaultExt = 'rdb'
    Filter = 'Resource database|*.rdb'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Export resource'
    Left = 152
    Top = 32
  end
  object ResWAVOpenDialog: TOpenDialog
    DefaultExt = 'wav'
    Filter = 'Wav files|*.wav'
    Title = 'Load Wave file'
    Left = 56
    Top = 72
  end
  object ResUVOpenDialog: TOpenDialog
    DefaultExt = 'uvf'
    Filter = 'UVF Files |*.uvf'
    Title = 'Load UVF mapping'
    Left = 88
    Top = 56
  end
end
