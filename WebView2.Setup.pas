unit WebView2.Setup;

interface

uses
  System.SysUtils,
  System.Classes;

const
  WEBVIEW2_URL_RUNTIME_PADRAO = 'https://go.microsoft.com/fwlink/?linkid=2124703';
  WEBVIEW2_URL_LOADER_PADRAO  = 'https://github.com/Ashewj/edgebrowser/raw/refs/heads/main/WebView2Loader.dll';
  WEBVIEW2_NOME_ARQUIVO_PADRAO = 'WebView2Loader.dll';

type
  IWebView2Setup = interface
    ['{8B6E6A2E-2D9E-4B7C-9B9E-3E9C2E9C2E9C}']

    function ComURLRuntime(const AURL: string): IWebView2Setup;
    function ComURLLoader(const AURL: string): IWebView2Setup;
    function ComNomeArquivoLoader(const ANomeArquivo: string): IWebView2Setup;
    function ComPastaAplicacao(const APasta: string): IWebView2Setup;
    function ComProgressoVisivel(AVisivel: Boolean): IWebView2Setup;

    function RuntimeInstalado: Boolean;
    function LoaderPresente: Boolean;
    function EstaPronto: Boolean;

    function Instalar: Boolean;
    function CarregarLoader: Boolean;

    function CaminhoCompletoLoader: string;
  end;

function NovoWebView2Setup: IWebView2Setup;

implementation

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.Win.Registry,
  System.Net.HttpClient,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Controls;

const
  GUID_WEBVIEW2_RUNTIME = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';

type
  TFormInstalacaoWebView2 = class(TForm)
  private
    FRotulo: TLabel;
    FBarraProgresso: TProgressBar;
    FPodeFechar: Boolean;
  protected
    function CloseQuery: Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure PermitirFechamento;
  end;

  TWebView2Setup = class(TInterfacedObject, IWebView2Setup)
  private
    FURLRuntime: string;
    FURLLoader: string;
    FNomeArquivoLoader: string;
    FPastaAplicacao: string;
    FProgressoVisivel: Boolean;

    function CaminhoLoader: string;
    function BaixarArquivo(const AURL, ADestino: string): Boolean;
    function InstalarRuntime: Boolean;
    function BaixarLoaderSeNecessario: Boolean;
  public
    constructor Create;

    function ComURLRuntime(const AURL: string): IWebView2Setup;
    function ComURLLoader(const AURL: string): IWebView2Setup;
    function ComNomeArquivoLoader(const ANomeArquivo: string): IWebView2Setup;
    function ComPastaAplicacao(const APasta: string): IWebView2Setup;
    function ComProgressoVisivel(AVisivel: Boolean): IWebView2Setup;

    function RuntimeInstalado: Boolean;
    function LoaderPresente: Boolean;
    function EstaPronto: Boolean;

    function Instalar: Boolean;
    function CarregarLoader: Boolean;

    function CaminhoCompletoLoader: string;
  end;

{ TFormInstalacaoWebView2 }

constructor TFormInstalacaoWebView2.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  FPodeFechar := False;

  Width := 400;
  Height := 120;
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  Caption := 'Instalação Única (Microsoft WebView2 Runtime)';

  FRotulo := TLabel.Create(Self);
  FRotulo.Parent := Self;
  FRotulo.Left := 20;
  FRotulo.Top := 15;
  FRotulo.Caption := Caption + '...';

  FBarraProgresso := TProgressBar.Create(Self);
  FBarraProgresso.Parent := Self;
  FBarraProgresso.Left := 20;
  FBarraProgresso.Top := 45;
  FBarraProgresso.Width := 340;
  FBarraProgresso.Height := 20;
  FBarraProgresso.Style := pbstMarquee;
  FBarraProgresso.MarqueeInterval := 30;
end;

function TFormInstalacaoWebView2.CloseQuery: Boolean;
begin
  Result := FPodeFechar;
end;

procedure TFormInstalacaoWebView2.PermitirFechamento;
begin
  FPodeFechar := True;
  Close;
end;

{ TWebView2Setup }

constructor TWebView2Setup.Create;
begin
  inherited Create;
  FURLRuntime := WEBVIEW2_URL_RUNTIME_PADRAO;
  FURLLoader := WEBVIEW2_URL_LOADER_PADRAO;
  FNomeArquivoLoader := WEBVIEW2_NOME_ARQUIVO_PADRAO;
  FPastaAplicacao := ExtractFilePath(ParamStr(0));
  FProgressoVisivel := True;
end;

function TWebView2Setup.ComURLRuntime(const AURL: string): IWebView2Setup;
begin
  FURLRuntime := AURL;
  Result := Self;
end;

function TWebView2Setup.ComURLLoader(const AURL: string): IWebView2Setup;
begin
  FURLLoader := AURL;
  Result := Self;
end;

function TWebView2Setup.ComNomeArquivoLoader(const ANomeArquivo: string): IWebView2Setup;
begin
  FNomeArquivoLoader := ANomeArquivo;
  Result := Self;
end;

function TWebView2Setup.ComPastaAplicacao(const APasta: string): IWebView2Setup;
begin
  FPastaAplicacao := IncludeTrailingPathDelimiter(APasta);
  Result := Self;
end;

function TWebView2Setup.ComProgressoVisivel(AVisivel: Boolean): IWebView2Setup;
begin
  FProgressoVisivel := AVisivel;
  Result := Self;
end;

function TWebView2Setup.CaminhoLoader: string;
begin
  Result := IncludeTrailingPathDelimiter(FPastaAplicacao) + FNomeArquivoLoader;
end;

function TWebView2Setup.CaminhoCompletoLoader: string;
begin
  Result := CaminhoLoader;
end;

function TWebView2Setup.RuntimeInstalado: Boolean;
var
  Registro: TRegistry;
begin
  Result := False;
  Registro := TRegistry.Create(KEY_READ or KEY_WOW64_32KEY);
  try
    Registro.RootKey := HKEY_LOCAL_MACHINE;

    if Registro.OpenKeyReadOnly('\SOFTWARE\Microsoft\EdgeUpdate\Clients\' + GUID_WEBVIEW2_RUNTIME) then
      Exit(True);

    Registro.CloseKey;
    if Registro.OpenKeyReadOnly('\SOFTWARE\Microsoft\EdgeUpdate\ClientState\' + GUID_WEBVIEW2_RUNTIME) then
      Exit(True);
  finally
    Registro.Free;
  end;
end;

function TWebView2Setup.LoaderPresente: Boolean;
begin
  Result := FileExists(CaminhoLoader);
end;

function TWebView2Setup.EstaPronto: Boolean;
begin
  Result := RuntimeInstalado and LoaderPresente;
end;

function TWebView2Setup.BaixarArquivo(const AURL, ADestino: string): Boolean;
var
  Cliente: THTTPClient;
  Arquivo: TFileStream;
begin
  Result := False;
  Cliente := THTTPClient.Create;
  try
    try
      Arquivo := TFileStream.Create(ADestino, fmCreate);
      try
        Cliente.Get(AURL, Arquivo);
        Result := True;
      finally
        Arquivo.Free;
      end;
    except
      Result := False;
      if FileExists(ADestino) then
        System.SysUtils.DeleteFile(ADestino);
    end;
  finally
    Cliente.Free;
  end;
end;

function TWebView2Setup.InstalarRuntime: Boolean;
var
  CaminhoInstalador: string;
  InfoExec: TShellExecuteInfo;
  StatusEspera: DWORD;
  Formulario: TFormInstalacaoWebView2;
begin
  Result := False;

  Formulario := nil;
  if FProgressoVisivel then
  begin
    Formulario := TFormInstalacaoWebView2.Create(nil);
    Formulario.Show;
    Formulario.Update;
  end;

  try
    CaminhoInstalador := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
      'MicrosoftEdgeWebView2RuntimeInstaller.exe';

    if not BaixarArquivo(FURLRuntime, CaminhoInstalador) then
      Exit;

    ZeroMemory(@InfoExec, SizeOf(InfoExec));
    InfoExec.cbSize := SizeOf(InfoExec);
    InfoExec.fMask := SEE_MASK_NOCLOSEPROCESS;
    InfoExec.lpFile := PChar(CaminhoInstalador);
    InfoExec.lpParameters := '/silent /install';
    InfoExec.nShow := SW_HIDE;

    if ShellExecuteEx(@InfoExec) then
    begin
      repeat
        StatusEspera := WaitForSingleObject(InfoExec.hProcess, 100);
        Application.ProcessMessages;
      until StatusEspera <> WAIT_TIMEOUT;

      CloseHandle(InfoExec.hProcess);
      Result := True;
    end;
  finally
    if Assigned(Formulario) then
    begin
      Formulario.PermitirFechamento;
      Formulario.Free;
    end;
  end;
end;

function TWebView2Setup.BaixarLoaderSeNecessario: Boolean;
begin
  if LoaderPresente then
    Exit(True);

  Result := BaixarArquivo(FURLLoader, CaminhoLoader);
end;

function TWebView2Setup.CarregarLoader: Boolean;
begin
  Result := False;

  if not LoaderPresente then
    Exit;

  Result := LoadLibrary(PChar(CaminhoLoader)) <> 0;
  if not Result then
    RaiseLastOSError;
end;

function TWebView2Setup.Instalar: Boolean;
begin
  Result := False;

  if not RuntimeInstalado then
    if not InstalarRuntime then
      Exit;

  if not BaixarLoaderSeNecessario then
    Exit;

  Result := CarregarLoader;
end;

function NovoWebView2Setup: IWebView2Setup;
begin
  Result := TWebView2Setup.Create;
end;

end.
