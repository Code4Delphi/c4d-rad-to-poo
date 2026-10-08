unit Conexao.DM;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  FireDAC.VCLUI.Wait,
  FireDAC.Phys.SQLiteWrapper.Stat,
  Data.DB,
  FireDAC.Comp.Client,
  C4D.Conn;

type
  TConexaoDM = class(TDataModule)
    FDConnection: TFDConnection;
    FDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink;
    procedure DataModuleCreate(Sender: TObject);
  private

  public

  end;

var
  ConexaoDM: TConexaoDM;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure TConexaoDM.DataModuleCreate(Sender: TObject);
begin
  FDConnection.Params.Database := '..\Data\crud.db';

  C4DConn.Configs
    .ComponentConnectionFireDac
    .ComponentOfConnectionExisting(FDConnection);
end;

end.
