unit Produtos.Model;

interface

type
  TProdutosModel = class
  private
    FId: Integer;
    FName: string;
    FDescription: string;
    FPrice: Double;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Price: Double read FPrice write FPrice;
  end;

implementation

end.
