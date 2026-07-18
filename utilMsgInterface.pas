unit utilMsgInterface;

interface

uses
  SysUtils, System.StrUtils, ExtCtrls, Classes, Dialogs, Controls,
  ufrmUtilAnaliseLogistica, UfrmMovPedFab, UfrmMovPedVenda, UFuncoes, UFuncoesNova,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,  Vcl.Graphics,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, Datasnap.DBClient, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, ufrmUtilMsgInterface, Vcl.StdCtrls, Windows, Math,  Vcl.Forms;

type
  TTipo = (
    Information,
    Confirmation,
    Warning,
    Error,
    Input
  );

type
  iUtilMsg = interface
  ['{EABCB35D-B878-4E3F-B5CA-C5B55C547D34}']

  function Titulo(aValue: string): iUtilMsg;
  function Texto(aValue: string): iUtilMsg; overload;
  function Texto(aValue: string; bValue: TAlignment): iUtilMsg; overload;
  function Tipo(aValue: TTipo): iUtilMsg;
  function TextoTamanHoriz(aValue: Integer): iUtilMsg;
  function Resultado: String;

  function Show : TModalResult;
  end;

type
  TUtilMsg = class(TInterfacedObject, iUtilMsg)
    private
      FForm:      TFormUtilMsg;
      FTitle:     string;
      FText:      string;
      FResult:    string;
      FAlignment: TAlignment;
      FType:      TTipo;
      FTamHoriz: Integer;
      FTamVerti: Integer;

      function _FonteTamanho(ALabel: TLabel; DPI: Integer): Integer;
      function _ContarLinhasLbl(ALabel: TLabel; DPI: Integer): Integer;
      function _MaiorPalavraWidth(ALabel: TLabel; DPI: Integer): Integer;

      procedure _MudarOrdemBotoes;
      procedure _ConfigurarBotoes;
      procedure _OnClickConfirmar(Sender: TObject);
      procedure _OnClickCancelar(Sender: TObject);
    public
      constructor create;
      destructor destroy; override;
      class function New: iUtilMsg;

      function Titulo(aValue: string): iUtilMsg;
      function Texto(aValue: string): iUtilMsg; overload;
      function Texto(aValue: string; bValue: TAlignment): iUtilMsg; overload;
      function Tipo(aValue: TTipo): iUtilMsg;
      function TextoTamanHoriz(aValue: Integer): iUtilMsg;
      function Resultado: String;

      function Show: TModalResult;
  end;

implementation

{Head::TUtilMsg}

constructor TUtilMsg.create;
begin
  FForm := TFormUtilMsg.Create(nil);
end;

destructor TUtilMsg.destroy;
begin
  FForm.Free;
  inherited;
end;

class function TUtilMsg.New: iUtilMsg;
begin
  Result := Self.create;
end;

{Body::TUtilMsg}

function TUtilMsg.TextoTamanHoriz(aValue: Integer): iUtilMsg;
begin
  Result := Self;
  FTamHoriz := aValue;
end;

function TUtilMsg._FonteTamanho(ALabel: TLabel; DPI: Integer): Integer;
begin
  Result := MulDiv(ALabel.Font.Size, DPI, 72);
end;

function TUtilMsg._ContarLinhasLbl(ALabel: TLabel; DPI: Integer): Integer;
var
  R: TRect;
begin
  R := Rect(0, 0, ALabel.Width, 0);

  DrawText(
    ALabel.Canvas.Handle,
    PChar(ALabel.Caption),
    Length(ALabel.Caption),
    R,
    DT_WORDBREAK or DT_CALCRECT
  );

  Result := (R.Height div _FonteTamanho(ALabel, DPI)) + 1;
end;

function TUtilMsg._MaiorPalavraWidth(ALabel: TLabel; DPI: Integer): Integer;
var
  Palavra: string;
  Width: Integer;
  MaxWidth: Integer;
  I: Integer;
  R: TRect;
begin
  ALabel.Canvas.Font := ALabel.Font;
  Palavra := '';
  MaxWidth := 0;

  R := Rect(0, 0, ALabel.Width, 0);

  DrawText(
    ALabel.Canvas.Handle,
    PChar(ALabel.Caption),
    Length(ALabel.Caption),
    R,
    DT_WORDBREAK or DT_CALCRECT
  );

  for I := 1 to Length(ALabel.Caption) do
  begin
    if ((R.Height > ALabel.Canvas.TextHeight('W')) and (ALabel.Caption[I] = ' '))
        or (ALabel.Caption[I] = #13)
        or (ALabel.Caption[I] = #10) then
    begin
      Width := ALabel.Canvas.TextWidth(Palavra);
      if Width > MaxWidth then
        MaxWidth := Width;
      Palavra := '';
    end
    else
      Palavra := Palavra + ALabel.Caption[I];
  end;

  Width := ALabel.Canvas.TextWidth(Palavra);
  if Width > MaxWidth then
    MaxWidth := Width;

  Result := MaxWidth;
end;

procedure TUtilMsg._MudarOrdemBotoes;
begin
  var Tipo := (FType = TTipo.Confirmation)
              or (FType = TTipo.Input);

  FForm.btnCancelar.Visible  := Tipo;
  FForm.btnConfirmar.Visible := Tipo;
  FForm.btnOk.Visible        := not Tipo;

  FForm.edtMain.Visible      := FType = TTipo.Input;
end;

procedure TUtilMsg._ConfigurarBotoes;
begin
  FForm.btnCancelar.OnClick  := _OnClickCancelar;
  FForm.btnConfirmar.OnClick := _OnClickConfirmar;
  FForm.btnOk.OnClick        := _OnClickConfirmar;
end;

procedure TUtilMsg._OnClickConfirmar(Sender: TObject);
begin
  FForm.ModalResult := mrOk;
end;

procedure TUtilMsg._OnClickCancelar(Sender: TObject);
begin
  FForm.ModalResult := mrCancel;
end;

function TUtilMsg.Titulo(aValue: string): iUtilMsg;
begin
  Result := Self;
  FTitle := aValue;
end;

function TUtilMsg.Texto(aValue: string): iUtilMsg;
begin
  Result := Self;

  FText := aValue;
  FAlignment := TAlignment(-1);
end;

function TUtilMsg.Texto(aValue: string; bValue: TAlignment): iUtilMsg;
begin
  Result := Self;

  FText := aValue;
  FAlignment := bValue;
end;

function TUtilMsg.Tipo(aValue: TTipo): iUtilMsg;
begin
  Result := Self;
  FType := aValue;
end;

function TUtilMsg.Resultado: String;
begin
  Result := FResult;
end;

function TUtilMsg.Show: TModalResult;
begin
  _MudarOrdemBotoes;
  _ConfigurarBotoes;

  FForm.lblMain.Caption := IfThen(FText.EndsWith(#10) or FText.EndsWith(#13),
                                  Copy(FText, 1, Length(FText) - 1),
                                  FText);

  if (FAlignment <> TAlignment(-1)) then
    FForm.lblMain.Alignment := FAlignment;

  FForm.JvGHPTitle.LabelCaption := FTitle;
  case FType of
    Information, Input: begin
      FForm.JvGHPTitle.GradientStartColor := RGB(0, 0, 128);
      FForm.JvGHPTitle.GradientEndColor := clSkyBlue;
    end;
    Confirmation: begin
      FForm.JvGHPTitle.GradientStartColor := RGB(60, 179, 113);
      FForm.JvGHPTitle.GradientEndColor := clLime;
    end;
    Warning: begin
      FForm.JvGHPTitle.GradientStartColor := RGB(189, 183, 107);
      FForm.JvGHPTitle.GradientEndColor := clYellow;
    end;
    Error: begin
      FForm.JvGHPTitle.GradientStartColor := RGB(128, 0, 0);
      FForm.JvGHPTitle.GradientEndColor := clRed;
    end;
  end;

  var DPI: Integer := GetDpiForWindow(Application.MainForm.Handle);

  var vPadding: Integer := 5;
  var vHeight: Integer  := DPI + FForm.JvGHPTitle.Height + vPadding;

  FForm.lblMain.Width := Screen.Width;

  var vTextWidth: Integer := _MaiorPalavraWidth(FForm.lblMain, DPI);
  var vBtnMinWidth: Integer := FForm.btnConfirmar.Left
                             + FForm.btnConfirmar.Width
                             + vPadding * 2;

  FForm.Width := Max(FTamHoriz, Max(vTextWidth, vBtnMinWidth))
               + FForm.lblMain.Left * 2;

  FForm.lblMain.Width := FForm.Width - FForm.lblMain.Left * 2;

  var vLinhas: Integer := _ContarLinhasLbl(FForm.lblMain, DPI);
  {TODO: tratar quando tiver muitas linhas e a res/dpi for pequena}

  FForm.Height := vHeight + (_FonteTamanho(FForm.lblMain, DPI) * vLinhas);

  if FForm.edtMain.Visible then
    FForm.Height := FForm.Height + FForm.edtMain.Height;
    
  FForm.ShowModal;

  FResult := FForm.edtMain.Text;

  Result := FForm.ModalResult;
end;

end.
