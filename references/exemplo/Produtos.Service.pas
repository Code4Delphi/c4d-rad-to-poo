unit Produtos.Service;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  C4D.Conn,
  Produtos.Model,
  Produtos.Repo;

type
  IProdutosService = interface
    ['{7995C97A-90F7-4D22-8C86-01B9BECFE8D1}']
    function Insert(const AProduto: TProdutosModel): Integer;
    procedure Update(const AProduto: TProdutosModel);
    procedure Delete(const AId: Integer);
    function GetById(const AId: Integer): TProdutosModel;
    function List: TObjectList<TProdutosModel>;
  end;

  TProdutosService = class(TInterfacedObject, IProdutosService)
  private
    FRepo: IProdutosRepo;
    procedure ValidarId(const AId: Integer);
    procedure ValidarPreenchimento(const AProduto: TProdutosModel);
  protected
    function Insert(const AProduto: TProdutosModel): Integer;
    procedure Update(const AProduto: TProdutosModel);
    procedure Delete(const AId: Integer);
    function GetById(const AId: Integer): TProdutosModel;
    function List: TObjectList<TProdutosModel>;
  public
    class function New: IProdutosService;
    constructor Create;
  end;

implementation

class function TProdutosService.New: IProdutosService;
begin
  Result := Self.Create;
end;

constructor TProdutosService.Create;
begin
  FRepo := TProdutosRepo.New;
end;

function TProdutosService.Insert(const AProduto: TProdutosModel): Integer;
begin
  Self.ValidarPreenchimento(AProduto);

  C4DConn.Connection.StartTransaction;
  try
    Result := FRepo.Insert(AProduto);
    C4DConn.Connection.Commit;
  except
    on E: Exception do
    begin
      C4DConn.Connection.Rollback;
      raise Exception.Create('Não foi possível inserir o produto no banco de dados' + sLineBreak + E.Message);
    end;
  end;
end;

procedure TProdutosService.Update(const AProduto: TProdutosModel);
begin
  Self.ValidarId(AProduto.Id);
  Self.ValidarPreenchimento(AProduto);

  C4DConn.Connection.StartTransaction;
  try
    FRepo.Update(AProduto);
    C4DConn.Connection.Commit;
  except
    on E: Exception do
    begin
      C4DConn.Connection.Rollback;
      raise Exception.Create('Não foi possível alterar o produto no banco de dados' + sLineBreak + E.Message);
    end;
  end;
end;

procedure TProdutosService.Delete(const AId: Integer);
begin
  Self.ValidarId(AId);

  C4DConn.Connection.StartTransaction;
  try
    FRepo.Delete(AId);
    C4DConn.Connection.Commit;
  except
    on E: Exception do
    begin
      C4DConn.Connection.Rollback;
      raise Exception.Create('Não foi possível excluir o produto no banco de dados' + sLineBreak + E.Message);
    end;
  end;
end;

function TProdutosService.GetById(const AId: Integer): TProdutosModel;
begin
  Self.ValidarId(AId);
  Result := FRepo.GetById(AId);
end;

function TProdutosService.List: TObjectList<TProdutosModel>;
begin
  Result := FRepo.List;
end;

procedure TProdutosService.ValidarId(const AId: Integer);
begin
  if AId <= 0 then
    raise Exception.Create('Código do produto inválido');
end;

procedure TProdutosService.ValidarPreenchimento(const AProduto: TProdutosModel);
begin
  if not Assigned(AProduto) then
    raise Exception.Create('Produto não informado');

  if AProduto.Name.Length > 60 then
    raise Exception.Create('O nome do produto deve ter no máximo 60 caracteres');

  if AProduto.Description.Length > 60 then
    raise Exception.Create('A descrição do produto deve ter no máximo 60 caracteres');

  if (AProduto.Price < 1) or (AProduto.Price > 1000) then
    raise Exception.Create('O preço do produto deve estar entre 1 e 1000');
end;

end.
