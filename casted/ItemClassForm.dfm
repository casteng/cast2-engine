object ItemClassF: TItemClassF
  Left = 435
  Top = 380
  BorderStyle = bsSizeToolWin
  Caption = 'Choose class'
  ClientHeight = 449
  ClientWidth = 265
  Color = clBtnFace
  Constraints.MinHeight = 120
  Constraints.MinWidth = 180
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
  OnShow = FormShow
  DesignSize = (
    265
    449)
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 264
    Height = 446
    ActivePage = TabSheet1
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    OnChange = PageControl1Change
    object TabSheet1: TTabSheet
      Caption = 'Create/Modify'
      DesignSize = (
        256
        418)
      object ClassCreateBut: TButton
        Left = 0
        Top = 396
        Width = 49
        Height = 22
        Hint = 'Create a new item of the selected class'
        Anchors = [akLeft, akBottom]
        Caption = 'Create'
        TabOrder = 2
        TabStop = False
        OnClick = ClassCreateButClick
      end
      object ClassModifyBut: TButton
        Left = 57
        Top = 396
        Width = 49
        Height = 22
        Hint = 'Change the selected item'#39's class to the selected one'
        Anchors = [akLeft, akBottom]
        Caption = 'Modify'
        TabOrder = 3
        TabStop = False
        OnClick = ClassModifyButClick
      end
      object CatList: TListBox
        Left = 0
        Top = 0
        Width = 107
        Height = 396
        Anchors = [akLeft, akTop, akBottom]
        ItemHeight = 13
        TabOrder = 0
        OnClick = CatListClick
      end
      object ClassList: TListBox
        Left = 110
        Top = 0
        Width = 145
        Height = 417
        Anchors = [akLeft, akTop, akRight, akBottom]
        ItemHeight = 13
        Sorted = True
        TabOrder = 1
        OnDblClick = ClassListDblClick
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'Setup'
      ImageIndex = 1
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      DesignSize = (
        256
        418)
      object OnTopBut: TSpeedButton
        Left = 215
        Top = 396
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
      object CatSetupText: TMemo
        Left = 0
        Top = 0
        Width = 254
        Height = 395
        Hint = 'Add class categories in form "Name = <base class>'
        Anchors = [akLeft, akTop, akRight, akBottom]
        Lines.Strings = (
          '<All classes> = TItem')
        TabOrder = 0
      end
    end
  end
end
