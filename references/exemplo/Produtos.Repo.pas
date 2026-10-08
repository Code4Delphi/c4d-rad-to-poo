unit Produtos.Repo;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  C4D.Conn,
  Produtos.Model;

type
  IProdutosRepo = interface
    ['{E9E68EA5-6482-4530-8E2E-1997CDB02B25}']
    function Insert(const AProduto: TProdutosModel): Integer;
    procedure Update(const AProduto: TProdutosModel);
    procedure Delete(const AId: Integer);
    function GetById(const AId: Integer): TProdutosModel;
    function List: TObjectList<TProdutosModel>;
  end;

  TProdutosRepo = class(TInterfacedObject, IProdutosRepo)
  private
    procedure AddParams(const AQuery: IC4DConnQuery; const AProduto: TProdutosModel);
    procedure LoadFields(const AQuery: IC4DConnQuery; const AProduto: TProdutosModel);
  protected
    function Insert(const AProduto: TProdutosModel): Integer;
    procedure Update(const AProduto: TProdutosModel);
    procedure Delete(const AId: Integer);
    function GetById(const AId: Integer): TProdutosModel;
    function List: TObjectList<TProdutosModel>;
  public
    class function New: IProdutosRepo;
  end;

implementation

class function TProdutosRepo.New: IProdutosRepo;
begin
  Result := Self.Create;
end;

function TProdutosRepo.Insert(const AProduto: TProdutosModel): Integer;
begin
  var LQuery := C4DConn.Query
    .Add('insert into product (name, description, price)')
    .Add('values (:name, :description, :price)');

  Self.AddParams(LQuery, AProduto);
  LQuery.ExecSQL;

  Result := LQuery.GetLastAutoGenValue('');
end;

procedure TProdutosRepo.Update(const AProduto: TProdutosModel);
begin
  var LQuery := C4DConn.Query
    .Add('update product set')
    .Add('name = :name,')
    .Add('description = :description,')
    .Add('price = :price')
    .Add('where id = :id');

  Self.AddParams(LQuery, AProduto);
  LQuery
    .AddParam('id', AProduto.Id)
    .ExecSQL;
end;

procedure TProdutosRepo.Delete(const AId: Integer);
begin
  C4DConn.Query
    .Add('delete from product where id = :id')
    .AddParam('id', AId)
    .ExecSQL;
end;

function TProdutosRepo.GetById(const AId: Integer): TProdutosModel;
begin
  Result := TProdutosModel.Create;
  try
    var LQuery := C4DConn.Query
      .Add('select * from product where id = :id')
      .AddParam('id', AId)
      .Open;

    if not LQuery.IsEmpty then
      Self.LoadFields(LQuery, Result);
  except
    Result.Free;
    raise;
  end;
end;

function TProdutosRepo.List: TObjectList<TProdutosModel>;
begin
  Result := TObjectList<TProdutosModel>.Create(True);
  try
    var LQuery := C4DConn.Query
      .Add('select * from product order by id')
      .Open;

    while not LQuery.Eof do
    begin
      var LProduto := TProdutosModel.Create;
      Result.Add(LProduto);
      Self.LoadFields(LQuery, LProduto);
      LQuery.Next;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TProdutosRepo.AddParams(const AQuery: IC4DConnQuery; const AProduto: TProdutosModel);
begin
  AQuery
    .AddParam('name', AProduto.Name)
    .AddParam('description', AProduto.Description)
    .AddParam('price', AProduto.Price);
end;

procedure TProdutosRepo.LoadFields(const AQuery: IC4DConnQuery; const AProduto: TProdutosModel);
begin
  AProduto.Id := AQuery.FieldByName('id').AsInteger;
  AProduto.Name := AQuery.FieldByName('name').AsString;
  AProduto.Description := AQuery.FieldByName('description').AsString;
  AProduto.Price := AQuery.FieldByName('price').AsFloat;
end;

end.
