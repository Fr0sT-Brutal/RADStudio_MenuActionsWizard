object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  Width = 748
  Height = 516
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  Padding.Left = 5
  Padding.Top = 5
  Padding.Right = 5
  Padding.Bottom = 5
  ParentFont = False
  TabOrder = 0
  object Panel1: TPanel
    Left = 5
    Top = 5
    Width = 738
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object lblDescr: TLabel
      Left = 0
      Top = 0
      Width = 468
      Height = 32
      AutoSize = False
      WordWrap = True
    end
    object eFilter: TEdit
      Left = 600
      Top = 11
      Width = 137
      Height = 24
      AutoSelect = False
      TabOrder = 0
      OnChange = eFilterChange
    end
  end
  object Panel2: TPanel
    Left = 5
    Top = 46
    Width = 738
    Height = 424
    Align = alClient
    BevelOuter = bvNone
    Caption = 'Hint: VTV will be placed here in run-time'
    TabOrder = 0
  end
  object Panel3: TPanel
    Left = 5
    Top = 470
    Width = 738
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    DesignSize = (
      738
      41)
    object lblShortcutUsed: TLabel
      Left = 0
      Top = 6
      Width = 580
      Height = 35
      Cursor = crHandPoint
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clMaroon
      Font.Height = -13
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
      OnClick = lblShortcutUsedClick
      ExplicitWidth = 582
    end
  end
  object PopupMenu1: TPopupMenu
    Left = 24
    Top = 8
    object miRevert: TMenuItem
      OnClick = miRevertClick
    end
    object miClearDef: TMenuItem
      OnClick = miClearDefClick
    end
  end
end
