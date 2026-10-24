# Arquitetura alvo

## Nomes

Com o prefixo `Clientes`:

| Item | Nome |
|---|---|
| Model | unit `Clientes.Model`, classe `TClientesModel` |
| Repo | unit `Clientes.Repo`, `IClientesRepo` + `TClientesRepo` |
| Service | unit `Clientes.Service`, `IClientesService` + `TClientesService` |
| View | **mantém** a unit e a classe do form legado (quem abre o form não precisa mudar) |
| MemTable / DataSource / Grid | `MTB_Clientes`, `DS_Clientes`, `gridClientes` |
| Fields do MemTable | `MTB_Clientes<campo>` (ex.: `MTB_Clientesnome`), FieldName igual à coluna do banco |
| Propriedades do Model | mesmo nome da coluna em PascalCase (`data_nascimento` → `DataNascimento`) |

Coloque as units novas na mesma pasta do form legado, a menos que o projeto já organize módulos em subpastas `Model/Repo/Service/View`; nesse caso siga o padrão existente.

Gere um GUID novo para cada interface (`[guid]::NewGuid()` no PowerShell). Nunca reaproveite GUIDs de outras interfaces.

## O que vai em cada camada

**Model** — só dados. Campos privados, propriedades públicas, construtor apenas para defaults ou objetos internos (e destrutor que os libera). Nada de `uses` de banco ou VCL.

**Repo** — só SQL e mapeamento linha ↔ objeto.
- Métodos da interface em `protected`; `class function New: I<Prefixo>Repo`.
- `AddParams(AQuery, AModel)` monta os parâmetros comuns a Insert e Update; `LoadFields(AQuery, AModel)` lê uma linha para o Model. Assim cada coluna aparece em um só lugar para escrita e um só para leitura.
- Colunas explícitas em `insert`/`update`; `select *` é aceitável em GetById/List quando `LoadFields` lê por nome.
- Ordene o `List` como o SQL legado ordenava (ex.: `order by nome`). Se o legado não ordenava, use a chave, para o grid ter ordem estável.
- Quem chama é dono dos objetos devolvidos (`GetById`, `List`) e deve liberá-los.
- Não valida, não controla transação, não mostra mensagem, não conhece componentes.
- Se o sistema for multiempresa e a tabela tiver coluna de empresa, filtre como o restante do projeto faz (no Solusys: `id_empresa = V_EmpresaLogId`). Não invente o filtro se o legado não tinha.

**Service** — regras e orquestração.
- `FRepo` criado no construtor (`T<Prefixo>Repo.New`).
- `ValidarId` (id > 0) antes de Update/Delete/GetById; `ValidarPreenchimento` antes de Insert/Update.
- Fontes das regras: TField `Required` e `Size`, eventos BeforePost/OnValidate/BeforeDelete do DM, validações nos handlers do form, constraints do banco (NOT NULL, CHECK, tamanho). Cada regra vira um `if ... then raise` com mensagem para o usuário final.
- Transação em Insert/Update/Delete; em caso de erro, Rollback e relança com contexto (`'Não foi possível inserir o cliente no banco de dados' + sLineBreak + E.Message`). As validações ficam **fora** do try, para a mensagem chegar limpa ao usuário.

**View** — só tela.
- Fala apenas com o Service (`T<Prefixo>Service.New.Metodo`). Nada de SQL, query ou referência ao DM.
- Estado: `FIdAtual` (id do registro na tela) e `FAlterando` (gravar faz Update ou Insert).
- Métodos padrão: `CarregarLista`, `CarregarRegistroSelecionado`, `Consultar<Entidade>(AId)`, `CarregarModelNaTela(AModel)`, `PreencherModel(AModel)`, `LimparCampos`.
- Conversão de texto da tela para tipo (data, número) é responsabilidade da View; regra de negócio não.

## Exceções e mensagens

- **Erros e validações:** `raise Exception.Create('...')` da RTL, com mensagem para o usuário final.
- **Diálogos:** só onde o legado já perguntava ou avisava, com a mesma função que ele usava (`MessageDlg`, `Application.MessageBox`, `ShowMessage`).
- Não use bibliotecas de exceções ou mensagens de terceiros (como c4d-exceptions e c4d-msg), mesmo que estejam no projeto.

## Convenções de código

Valem quando o usuário não tiver regras próprias (CLAUDE.md/AGENTS.md). Se tiver, as dele prevalecem.

- `uses` com uma unit por linha, sempre na seção interface (nunca na implementation).
- `Self.` ao chamar métodos da própria classe (`Self.CarregarLista`), mas não em componentes (`btnGravar.Click`).
- Variáveis locais com declaração inline (`var LProduto := TProdutosModel.Create;`).
- Sem `begin`/`end` em bloco de um comando só.
- `Pred(X)` em vez de `X - 1`.
- `.IsEmpty` para comparar com vazio; `Trim(edt.Text)` em vez de `edt.Text.Trim`.
- `.ToUpper`, `.ToLower`, `.ToInteger` em vez de `UpperCase`, `LowerCase`, `StrToInt`.
- Componentes novos são declarados no .dfm, nunca criados em runtime.
- Form com `KeyPreview = True`.
- Caption de TGroupBox com espaço antes e depois (`' Endereço '`).
- Em SQL dentro do Delphi, compare com vazio usando aspas duplas: `coalesce(campo, "") = ""`.
- Nada de acento em nomes de componentes; strings acentuadas no .dfm com escape (`'Descri'#231#227'o'`).

Prefixos de componentes: TLabel `lb`, TEdit/TDateTimePicker `edt`, TButton/TPngBitBtn `btn`, TDBGrid `grid`, TStringGrid `strGrid`, TPanel `pn`, TCheckBox `ck`, TTabSheet `tab`, TComboBox `cBox`, TRadioButton `rd`, TGroupBox `gBox`, TRadioGroup `rdGroup`, TPageControl `pageControl`, TFDQuery/TZQuery `Q`, TZReadOnlyQuery `TB`, TDataSource `DS_`, TFDMemTable `MTB_`.

## O que não copiar do módulo CIOT (Solusys)

O CIOT inspirou esta arquitetura, mas tem desvios que não devem se espalhar:
- `uses` na implementation (CIOT.Service) e `var` sem ser inline (CIOT.Repo).
- `GetById`/`List` sem liberar o Result quando ocorre exceção.
- Globais do Solusys (`CommonDMConn`, `V_EmpresaLogId`, `ConfForm`, `KeyDownPadrao`) em projetos que não os têm.
