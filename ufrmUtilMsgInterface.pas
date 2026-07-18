unit ufrmUtilMsgInterface;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Buttons, Vcl.ExtCtrls, JvExControls,
  JvGradientHeaderPanel, Vcl.StdCtrls;

type
  TFormUtilMsg = class(TForm)
    JvGHPTitle: TJvGradientHeaderPanel;
    Panel2: TPanel;
    btnConfirmar: TSpeedButton;
    btnCancelar: TSpeedButton;
    Panel1: TPanel;
    btnOk: TSpeedButton;
    lblMain: TLabel;
    edtMain: TEdit;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormUtilMsg: TFormUtilMsg;

implementation

{$R *.dfm}

end.
