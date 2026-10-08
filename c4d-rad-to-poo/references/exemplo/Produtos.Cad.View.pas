unit Produtos.Cad.View;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Grids,
  Vcl.DBGrids,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  Produtos.Model,
  Produtos.Service;

type
  TProdutosCadView = class(TForm)
    pnDadosCadastrais: TPanel;
    pnBotoes: TPanel;
    btnNovo: TButton;
    btnGravar: TButton;
    btnAlterar: TButton;
    btnExcluir: TButton;
    btnAtualizar: TButton;
    btnFechar: TButton;
    btnCancelar: TButton;
    lbID: TLabel;
    edtID: TEdit;
    lbName: TLabel;
    edtName: TEdit;
    lbDescription: TLabel;
    edtDescription: TEdit;
    lbPrice: TLabel;
    edtPrice: TEdit;
    pnGrid: TPanel;
    gridProdutos: TDBGrid;
    MTB_Produtos: TFDMemTable;
    MTB_Produtosid: TIntegerField;
    MTB_Produtosname: TStringField;
    MTB_Produtosdescription: TStringField;
    MTB_Produtosprice: TFloatField;
    DS_Produtos: TDataSource;
    procedure btnFecharClick(Sender: TObject);
    procedure btnNovoClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnGravarClick(Sender: TObject);
    procedure btnAlterarClick(Sender: TObject);
    procedure btnExcluirClick(Sender: TObject);
    procedure btnAtualizarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure DS_ProdutosDataChange(Sender: TObject; Field: TField);
  private
    FIdAtual: Integer;
    FAlterando: Boolean;
    procedure CarregarLista;
    procedure CarregarRegistroSelecionado;
    procedure ConsultarProduto(const AId: Integer);
    procedure CarregarModelNaTela(const AProduto: TProdutosModel);
    procedure PreencherModel(const AProduto: TProdutosModel);
    procedure LimparCampos;
    procedure EditionOFF;
    procedure EditionOn;
  public

  end;

implementation

{$R *.dfm}

procedure TProdutosCadView.FormCreate(Sender: TObject);
begin
  MTB_Produtos.CreateDataSet;
  Self.CarregarLista;
  Self.EditionOFF;
end;

procedure TProdutosCadView.btnNovoClick(Sender: TObject);
begin
  Self.LimparCampos;
  FAlterando := False;
  Self.EditionOn;
  edtName.SetFocus;
end;

procedure TProdutosCadView.btnCancelarClick(Sender: TObject);
begin
  FAlterando := False;
  Self.CarregarLista;
  Self.EditionOFF;
end;

procedure TProdutosCadView.btnGravarClick(Sender: TObject);
begin
  var LProduto := TProdutosModel.Create;
  try
    Self.PreencherModel(LProduto);
    if FAlterando then
      TProdutosService.New.Update(LProduto)
    else
      FIdAtual := TProdutosService.New.Insert(LProduto);
  finally
    LProduto.Free;
  end;

  FAlterando := False;
  Self.CarregarLista;
  Self.EditionOFF;
end;

procedure TProdutosCadView.btnAlterarClick(Sender: TObject);
begin
  if FIdAtual <= 0 then
    raise Exception.Create('Selecione um produto para alterar');

  Self.ConsultarProduto(FIdAtual);
  FAlterando := True;
  Self.EditionOn;
  edtName.SetFocus;
end;

procedure TProdutosCadView.btnExcluirClick(Sender: TObject);
begin
  if FIdAtual <= 0 then
    raise Exception.Create('Selecione um produto para excluir');

  TProdutosService.New.Delete(FIdAtual);
  FIdAtual := 0;
  Self.CarregarLista;
end;

procedure TProdutosCadView.btnAtualizarClick(Sender: TObject);
begin
  Self.CarregarLista;
end;

procedure TProdutosCadView.btnFecharClick(Sender: TObject);
begin
  Self.Close;
end;

procedure TProdutosCadView.DS_ProdutosDataChange(Sender: TObject; Field: TField);
begin
  if Field = nil then
    Self.CarregarRegistroSelecionado;
end;

procedure TProdutosCadView.CarregarLista;
begin
  var LUltId := FIdAtual;
  if LUltId <= 0 then
    LUltId := MTB_Produtosid.AsInteger;

  MTB_Produtos.DisableControls;
  try
    MTB_Produtos.EmptyDataSet;

    var LLista := TProdutosService.New.List;
    try
      for var LProduto in LLista do
      begin
        MTB_Produtos.Append;
        MTB_Produtosid.AsInteger := LProduto.Id;
        MTB_Produtosname.AsString := LProduto.Name;
        MTB_Produtosdescription.AsString := LProduto.Description;
        MTB_Produtosprice.AsFloat := LProduto.Price;
        MTB_Produtos.Post;
      end;
    finally
      LLista.Free;
    end;

    if not MTB_Produtos.Locate('id', LUltId, []) then
      MTB_Produtos.First;
  finally
    MTB_Produtos.EnableControls;
  end;
end;

procedure TProdutosCadView.CarregarRegistroSelecionado;
begin
  if MTB_Produtos.IsEmpty then
    Self.LimparCampos
  else
    Self.ConsultarProduto(MTB_Produtosid.AsInteger);
end;

procedure TProdutosCadView.ConsultarProduto(const AId: Integer);
begin
  var LProduto := TProdutosService.New.GetById(AId);
  try
    if LProduto.Id <= 0 then
      raise Exception.Create('Produto não localizado');

    Self.CarregarModelNaTela(LProduto);
  finally
    LProduto.Free;
  end;
end;

procedure TProdutosCadView.CarregarModelNaTela(const AProduto: TProdutosModel);
begin
  FIdAtual := AProduto.Id;
  edtID.Text := Format('%.6d', [AProduto.Id]);
  edtName.Text := AProduto.Name;
  edtDescription.Text := AProduto.Description;
  edtPrice.Text := FormatFloat('0.00', AProduto.Price);
end;

procedure TProdutosCadView.PreencherModel(const AProduto: TProdutosModel);
begin
  var LPrice: Double := 0;
  if (not Trim(edtPrice.Text).IsEmpty) and (not TryStrToFloat(Trim(edtPrice.Text), LPrice)) then
    raise Exception.Create('Preço inválido');

  AProduto.Id := FIdAtual;
  AProduto.Name := Trim(edtName.Text);
  AProduto.Description := Trim(edtDescription.Text);
  AProduto.Price := LPrice;
end;

procedure TProdutosCadView.LimparCampos;
begin
  FIdAtual := 0;
  edtID.Clear;
  edtName.Clear;
  edtDescription.Clear;
  edtPrice.Clear;
end;

procedure TProdutosCadView.EditionOn;
begin
  pnDadosCadastrais.Enabled := True;
  pnGrid.Enabled := False;

  btnNovo.Enabled := False;
  btnGravar.Enabled := True;
  btnAlterar.Enabled := False;
  btnExcluir.Enabled := False;
  btnCancelar.Enabled := True;
  btnAtualizar.Enabled := False;
  btnFechar.Enabled := False;
end;

procedure TProdutosCadView.EditionOFF;
begin
  pnDadosCadastrais.Enabled := False;
  pnGrid.Enabled := True;

  btnNovo.Enabled := True;
  btnGravar.Enabled := False;
  btnAlterar.Enabled := True;
  btnExcluir.Enabled := True;
  btnCancelar.Enabled := False;
  btnAtualizar.Enabled := True;
  btnFechar.Enabled := True;
end;

end.
