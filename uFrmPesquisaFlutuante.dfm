object frmPesquisaFlutuante: TfrmPesquisaFlutuante
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsNone
  Caption = 'Pesquisa Flutuante'
  ClientHeight = 390
  ClientWidth = 520
  Color = 1644828
  TransparentColorValue = clFuchsia
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  RoundedCorners = rcOn
  Scaled = False
  StyleElements = [seFont, seClient]
  ShowInTaskBar = True
  OnCreate = FormCreate
  TextHeight = 15
  object Core: TEdgeBrowser
    Left = 0
    Top = 0
    Width = 520
    Height = 390
    Align = alClient
    TabOrder = 1
    AllowSingleSignOnUsingOSPrimaryAccount = False
    TargetCompatibleBrowserVersion = '137.0.3296.44'
    UserDataFolder = '%LOCALAPPDATA%\bds.exe.WebView2'
    OnWebMessageReceived = CoreWebMessageReceived
  end
  object Move: TPanel
    Left = 0
    Top = 2
    Width = 473
    Height = 19
    Cursor = crSizeAll
    BevelEdges = []
    BevelOuter = bvNone
    Color = 1841433
    ParentBackground = False
    ShowCaption = False
    TabOrder = 0
    OnMouseDown = MoveMouseDown
  end
end
