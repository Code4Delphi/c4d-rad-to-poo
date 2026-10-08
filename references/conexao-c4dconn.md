# C4D.Conn

Biblioteca de acesso a banco usada pelo Repo (`github.com/Solusys/c4d-conn`, instalada via Boss em `modules/c4d-conn`). Uma unit só na `uses`: `C4D.Conn`. Ela expõe a função global `C4DConn` e os tipos `IC4DConn` e `IC4DConnQuery`.

## 1. A dependência existe?

Procure, nesta ordem:
1. `boss.json` com `c4d-conn` em `dependencies`, e a pasta `modules/c4d-conn/Src`.
2. `DCC_UnitSearchPath` do `.dproj` contendo `c4d-conn`.
3. Library path global do Delphi (`HKCU\Software\Embarcadero\BDS\<versão>\Library\Win32`, valor `Search Path`).

Se não encontrar, pare e avise o usuário. Ele decide entre `boss install github.com/Solusys/c4d-conn` e um search path manual. Não instale por conta própria.

A unit `C4D.Conn` sempre inclui os adaptadores Zeos e FireDAC. Por isso o projeto precisa do Zeos no library path, mesmo usando só FireDAC. Se a compilação reclamar de `ZConnection` ou `ZAbstractConnection`, é isso.

## 2. Configuração (uma única vez, na inicialização)

Primeiro procure se o projeto já configura (Grep `C4DConn.Configs`). Se já configura, não mexa: o Repo novo só usa `C4DConn.Query`.

Se não configura, ligue o C4DConn ao componente de conexão que o projeto já tem:

```pascal
// FireDAC
C4DConn.Configs
  .ComponentConnectionFireDac
  .ComponentOfConnectionExisting(FDConnection);

// Zeos
C4DConn.Configs
  .ComponentConnectionZeos
  .ComponentOfConnectionExisting(ZConnection);
```

- `ComponentConnectionFireDac`/`ComponentConnectionZeos` lança exceção se for chamado duas vezes. Por isso a configuração fica num ponto que roda uma vez só: o `OnCreate` do DM de conexão, criado como primeiro `Application.CreateForm` no .dpr.
- Use sempre `ComponentOfConnectionExisting` com o componente do projeto. O adaptador FireDAC da c4d-conn só traz o driver MySQL; com o componente existente, valem o driver link e os parâmetros que o projeto já usa (SQLite, Firebird, MSSQL...).
- Onde fica a conexão:
  - DM legado usado só pelo form refatorado → vira o DM de conexão (`git mv` para algo como `Conexao.DM`), mantendo só a conexão e o driver link. Veja `exemplo/Conexao.DM.pas`.
  - DM usado por outros forms → mantenha o DM, remova só a query e os fields deste cadastro e configure o C4DConn nele (ou num DM de conexão comum que o projeto já tenha).
  - DM do cadastro sem conexão própria, com a query usando a conexão de outro DM (`Connection = OutroDM.FDConnection1`) → o DM do cadastro pode ser removido. Configure o C4DConn no `OnCreate` do DM dono da conexão e garanta, no .dpr, que ele seja criado antes de qualquer uso. Não mova a conexão nem mexa nos outros cadastros que a usam: eles continuam legados e fora do escopo.
  - Projeto que já tem DM de conexão comum (no Solusys é o `CommonDMConn`, ligado no splash) → só use.

## 3. Consultas

```pascal
// comando
C4DConn.Query
  .Add('delete from cliente where id = :id')
  .AddParam('id', AId)
  .ExecSQL;

// consulta
var LQuery := C4DConn.Query
  .Add('select * from cliente where id = :id')
  .AddParam('id', AId)
  .Open;

while not LQuery.Eof do
begin
  ... LQuery.FieldByName('nome').AsString ...
  LQuery.Next;
end;
```

- Cada `C4DConn.Query` cria uma query nova, liberada junto com a interface. Crie uma por método.
- **Monte todo o SQL antes do primeiro `AddParam`.** `AddParam` faz `ParamByName(...).Value := ...`, e no FireDAC cada `Add` recria a lista de parâmetros. Em SQL dinâmico, monte as linhas condicionais primeiro e passe os parâmetros depois.
- `IsEmpty`, `Eof`, `Next`, `First`, `FieldByName`, `RecordCount` e `DataSet` funcionam como no TDataSet.

## 4. Id gerado no Insert

| Conexão | Chamada |
|---|---|
| FireDAC (SQLite, MySQL, MSSQL) | `GetLastAutoGenValue('')`. Nome vazio usa o último id da sessão. No SQLite, passar um nome faz o FireDAC ler `sqlite_sequence`, que só existe em tabelas com AUTOINCREMENT, e o Insert falha. |
| FireDAC (Firebird, PostgreSQL com generator/sequence) | `GetLastAutoGenValue('<nome do generator/sequence>')`, ou `insert ... returning id` com `Open` |
| Zeos | `GetLastAutoGenValue('<tabela>')`. A c4d-conn executa `select Last_Insert_ID() from <tabela>`, então isso **só funciona com MySQL**. Para outro banco no Zeos, use `returning` ou a estratégia que o projeto já usa. |

O resultado é `Variant`; atribua direto ao `Integer`. Confirme no teste da etapa 9: esse é um erro que compila e só aparece em execução.

## 5. Transação

```pascal
C4DConn.Connection.StartTransaction;
try
  Result := FRepo.Insert(AModel);
  C4DConn.Connection.Commit;
except
  on E: Exception do
  begin
    C4DConn.Connection.Rollback;
    raise Exception.Create('Não foi possível inserir o cliente no banco de dados' + sLineBreak + E.Message);
  end;
end;
```

A transação fica no Service, nunca no Repo: assim um Service pode chamar vários métodos de Repo na mesma transação. Se o projeto controla transação por outro objeto (no Solusys, `CommonDMConn.ZConnection.StartTransaction`), siga o projeto.
