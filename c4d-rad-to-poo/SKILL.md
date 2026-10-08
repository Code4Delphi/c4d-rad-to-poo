---
name: c4d-rad-to-poo
description: Refatora cadastros (CRUDs) Delphi VCL legados feitos no estilo RAD — DataModule com TFDQuery e componentes DB-aware como TDBEdit, TDBCheckBox, TDBMemo e TDBGrid ligados direto na query — para camadas Model/Repo/Service/View no padrão Repository, usando a biblioteca C4D.Conn no acesso ao banco e TFDMemTable para exibir os dados no grid. Use sempre que o usuário pedir para refatorar, modernizar, migrar, separar em camadas, aplicar Repository/Service/POO, "tirar do RAD" ou remover DataModule/TDBEdit de um form de cadastro Delphi, mesmo que ele não cite C4D.Conn nem o nome da skill.
---

# c4d-rad-to-poo

Transforma um form de cadastro Delphi VCL feito no estilo RAD em quatro camadas:

| Unit | Responsabilidade |
|---|---|
| `<Prefixo>.Model` | Classe que espelha a tabela do banco |
| `<Prefixo>.Repo` | SQL via C4D.Conn: Insert, Update, Delete, GetById, List |
| `<Prefixo>.Service` | Validações, regras de negócio e transação; é quem chama o Repo |
| View (o form existente) | Componentes comuns (TEdit, TCheckBox...), grid ligado a um TFDMemTable, conversa só com o Service |

`references/exemplo/` tem os `.pas` de um cadastro real já refatorado, compilado e testado: `Produtos.Model`, `Produtos.Repo`, `Produtos.Service`, `Produtos.Cad.View` e `Conexao.DM`. Leia esses `.pas` uma vez antes de começar: é a forma mais rápida de entender o resultado esperado. Use-os como modelo de estrutura e estilo, não como texto para copiar; cada CRUD tem seus próprios campos e regras. Os trechos de `.dfm` que você vai precisar estão em `references/mapeamento.md`.

## Princípios

- **Mudar a arquitetura, não a tela.** Layout, captions, ordem de tabulação e fluxo dos botões continuam iguais. O usuário valida a refatoração comparando com o comportamento antigo, e mudanças de interface atrapalham essa comparação. Melhorias que você notar (ex.: pedir confirmação no Excluir) vão como sugestão no relatório final.
- **Paridade de regras.** Toda regra que existe hoje — em eventos do DataModule, nos handlers do form, nas propriedades dos TFields (Required, Size) e nas constraints do banco — precisa continuar existindo, agora no Service. Não invente regras novas sem perguntar; liste-as como sugestão.
- **Convenções do projeto prevalecem.** Siga o CLAUDE.md/AGENTS.md do usuário. Se não houver, use a seção "Convenções de código" de `references/arquitetura.md`.
- **Pare quando sair do escopo.** Veja "Fora do escopo" no fim deste arquivo. É melhor avisar e perguntar do que entregar uma conversão parcial que compila mas perde comportamento.

## Fluxo

### 0. Preparação

1. Identifique o form (.pas + .dfm). Se o usuário não disse qual, pergunte.
2. Veja se o projeto está aberto no RAD Studio (`Get-Process bds | Select-Object MainWindowTitle`). Se estiver, peça para o usuário fechar o projeto (File > Close All) antes de qualquer edição: a IDE mantém os arquivos em memória e sobrescreve as alterações feitas em disco quando o usuário salva. Se as ferramentas MCP da IDE estiverem disponíveis (`listOpenFiles`, `applyEdit`...), siga a skill `ide-file-operations` em vez disso.
3. Pergunte o prefixo das novas units, sugerindo um derivado do nome do form: `Produtos.Cad.View` → `Produtos`; `uCadClientes`/`frmCadClientes` → `Clientes`. O prefixo define os nomes: `Clientes.Model`, `TClientesModel`, `IClientesRepo`, `MTB_Clientes`, `DS_Clientes`...
4. Anote a codificação do .pas legado **antes** de reescrevê-lo (`file` no Git Bash, ou procure o BOM `EF BB BF`). Sem BOM = ANSI (cp1252), o padrão dos projetos Delphi legados; com BOM = UTF-8. Você vai precisar disso na etapa 8.

### 1. Levantamento (somente leitura)

Leia e anote:

- **Form (.pas/.dfm):** componentes DB-aware e seus `DataField`; os `TDataSource` e para qual dataset apontam (normalmente `<DM>.<Query>`); colunas do TDBGrid; o que cada handler faz no dataset (Open, Append, Edit, Post, Cancel, Delete, Refresh) e qualquer validação ou regra escrita ali.
- **DataModule:** componente de conexão (TFDConnection) e driver; SQL da query (tabela, colunas, chave primária); TFields persistentes (tipo, Size, DisplayFormat, DisplayLabel, Required, ReadOnly); eventos com regra (BeforePost, OnNewRecord, OnValidate, AfterPost, BeforeDelete, OnGetText/OnSetText).
- **Banco:** estrutura da tabela quando der para ler sem risco — arquivo SQLite local, scripts DDL no projeto. Procure NOT NULL, CHECK, tamanhos, default e autoincremento; isso vira validação no Service. Não conecte em servidor de banco sem perguntar.
- **Quem mais usa o DM:** Grep pelo nome do DM e da query no projeto inteiro. Isso decide se o DM pode virar só conexão, ser removido ou precisa ficar.
- **Infraestrutura:** se a c4d-conn está no projeto (boss.json, `modules/c4d-conn`, `DCC_UnitSearchPath` do .dproj) e se o C4DConn já é configurado em algum lugar (Grep `C4DConn.Configs`). Detalhes em `references/conexao-c4dconn.md`.
- **Fora do escopo:** procure os itens da seção final deste arquivo.

Se a c4d-conn não estiver no projeto, pare e avise. Sugira `boss install github.com/Solusys/c4d-conn` (ou o fork que o usuário usa) e não instale nada sem ele pedir. Pare também se a conexão do projeto não for um `TFDConnection`: a c4d-conn trabalha só com FireDAC.

### 2. Plano — confirme antes de escrever

Mostre ao usuário, de forma compacta:

- Tabela de campos: `campo no banco | TField | propriedade no Model (tipo) | componente antes → depois`.
- Units que serão criadas/alteradas/renomeadas/removidas, inclusive o destino do DM e onde o C4DConn será configurado.
- Regras que vão para o Service e de onde vieram (evento do DM, constraint, handler do form).
- Diferenças de comportamento inevitáveis (ex.: campo que aceitava NULL e agora vira 0).
- Itens fora do escopo encontrados.

Espere a confirmação. CRUD legado quase sempre esconde alguma regra num evento, e este é o momento barato de descobrir.

### 3. Model

Uma classe com campos privados e propriedades espelhando a tabela, com tipos conforme `references/mapeamento.md`. Sem acesso a banco, sem UI. Construtor só se houver valor padrão ou objetos internos.

### 4. Repo

Interface `I<Prefixo>Repo` + classe `T<Prefixo>Repo(TInterfacedObject)` com `class function New`, métodos da interface em `protected` (só acessíveis via interface) e helpers privados `AddParams` e `LoadFields`. Siga `exemplo/Produtos.Repo.pas` e as regras de `references/conexao-c4dconn.md`. As duas que mais causam erro:

- Monte o SQL inteiro antes do primeiro `AddParam`: no FireDAC, cada `Add` recria os parâmetros.
- Para pegar o id gerado no FireDAC use `GetLastAutoGenValue('')`. Passando o nome do campo, o SQLite procura a tabela `sqlite_sequence` e falha.

Antes de gravar coluna que aceita NULL ou coluna de data, leia "Nulos" e "Datas como parâmetro" em `references/mapeamento.md`. Os dois casos compilam e só falham em execução no FireDAC.

O Repo não valida, não abre transação e não mostra mensagem. `GetById` devolve um Model vazio (Id = 0) quando não encontra. `List` devolve `TObjectList<T>.Create(True)`. Nos dois, libere o Result se ocorrer exceção antes de devolvê-lo.

### 5. Service

Interface `I<Prefixo>Service` + classe com `FRepo` criado no construtor. `ValidarId` e `ValidarPreenchimento` concentram as regras levantadas na etapa 1. Insert/Update/Delete rodam dentro de transação (`C4DConn.Connection.StartTransaction/Commit/Rollback`) e relançam o erro com uma mensagem de contexto. Se o projeto já controla transação de outro jeito, siga o padrão do projeto. Exceções: `Exception` da RTL.

### 6. View

**.dfm** — troque cada componente DB-aware pelo equivalente comum e remova as propriedades que só existem na versão DB (tabela em `references/mapeamento.md`). Renomeie os componentes fora do padrão de prefixos (`Label1` → `lbNome`, `DataSource1` → `DS_<Prefixo>`, `DBGrid1` → `grid<Prefixo>`), atualizando `FocusControl` e as referências no código. Adicione `MTB_<Prefixo>` (TFDMemTable) com fields persistentes copiados dos TFields do DM — FieldName, Size, DisplayFormat, DisplayLabel; sem Origin, ProviderFlags ou Required — e aponte `DS_<Prefixo>` para ele. Mantenha `KeyPreview = True`.

**.pas** — cada objeto do .dfm precisa de um campo com o mesmo nome e classe na declaração do form. Ajuste a `uses`: tire `Vcl.DBCtrls` e a unit do DM; inclua as units FireDAC do TFDMemTable e as units dos componentes novos. A IDE adicionaria essas units sozinha, mas na edição em texto isso é com você. A tabela abaixo mostra como o legado vira o novo; o código completo está em `exemplo/Produtos.Cad.View.pas`:

| Legado | Novo |
|---|---|
| FormCreate: `Query.Open` | `MTB.CreateDataSet` + `CarregarLista` |
| Novo: `Query.Append` | `LimparCampos`, `FAlterando := False`, modo edição, foco no 1º campo |
| Alterar: `Query.Edit` | Sem registro (`FIdAtual <= 0`): faça o que o legado fazia, ou lance exceção se ele não tratava. Depois: `Consultar<Entidade>(FIdAtual)`, `FAlterando := True`, modo edição |
| Gravar: `Query.Post` | Cria o Model, `PreencherModel`, Service.Insert ou Update, `CarregarLista`, modo navegação |
| Cancelar: `Query.Cancel` | `FAlterando := False`, `CarregarLista`, modo navegação |
| Excluir: `Query.Delete` | Mesma regra do Alterar para registro vazio; mantenha a confirmação se o legado pedia; Service.Delete, `FIdAtual := 0`, `CarregarLista` |
| Atualizar: `Query.Refresh` | `CarregarLista` |
| Grid rolando e TDBEdits acompanhando | `DS_<Prefixo>.OnDataChange` com `Field = nil` → `CarregarRegistroSelecionado` |

Esse último item é o comportamento que o DB-aware dava de graça e é o mais fácil de esquecer. `CarregarLista` envolve o preenchimento do MTB em `DisableControls/EnableControls`: o `EnableControls` dispara um único `OnDataChange`, que carrega o registro posicionado. Guarde o id atual antes de recarregar e use `Locate` depois, para o usuário continuar no mesmo registro.

Os métodos de estado da tela que já existem (ex.: `EditionOn`/`EditionOFF`) ficam com os nomes originais.

### 7. Projeto

- **.dpr e .dproj:** registre as units novas nos dois arquivos (`uses` do .dpr e `DCCReference` no .dproj) e remova ou renomeie as do DM.
- **Caminhos com `\u`:** num caminho como `Src\Clientes쫜lientes.pas`, o trecho `쫜` (`\u` + 4 dígitos hexadecimais) pode ser interpretado como escape Unicode ao passar pelas ferramentas de edição e virar um caractere estranho. Isso é comum com units legadas `uCad...`. Depois de editar, releia as linhas alteradas; o `normalizar-arquivos.ps1` também acusa esse caso.
- **Unit renomeada:** se o DM virar o DM de conexão, use `git mv` para manter o histórico.
- **Configuração do C4DConn:** se o projeto ainda não configura, faça isso uma única vez na inicialização. O DM de conexão deve ser o primeiro `CreateForm` do .dpr. Veja `references/conexao-c4dconn.md`.

### 8. Codificação e validação

Os arquivos escritos pelas ferramentas saem em UTF-8 com LF; o Delphi legado espera ANSI (cp1252) com CRLF. Rode os scripts da pasta `scripts/` desta skill, com caminho absoluto. As listas de arquivos vão numa única string, separadas por vírgula:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill>\scripts\normalizar-arquivos.ps1" -Encoding Ansi -Arquivos "<arq1.pas>,<arq2.dfm>,<Projeto.dpr>,<Projeto.dproj>"
powershell -ExecutionPolicy Bypass -File "<skill>\scripts\validar-delphi.ps1" -Projeto "<Projeto.dproj>" -Dfm "<form.dfm>,<Conexao.DM.dfm>"
```

- **Codificação:** use `-Encoding Utf8Bom` se o .pas legado tinha BOM (etapa 0). O `.dproj` é UTF-8 com BOM; o script preserva arquivos que já têm BOM.
- **Normalize só depois da última edição.** Editar um arquivo que já está em ANSI corrompe os acentos, porque as ferramentas de edição trabalham em UTF-8. Se precisar corrigir algo depois (ex.: erro de compilação), rode o script com `-Encoding Utf8` nesse arquivo, edite e rode com `-Encoding Ansi` de novo.
- **Acentos em .dfm:** strings acentuadas usam escape Delphi (`'Pre'#231'o'`). O script avisa se encontrar caractere não ASCII num .dfm.
- **Validação:** o `validar-delphi.ps1` passa cada .dfm pelo `convert.exe` numa cópia temporária e compila o projeto com MSBuild. Corrija qualquer erro e rode de novo.
- **Sobras do legado:** faça um Grep no form refatorado procurando `TDB` (exceto `TDBGrid`), `DataField` e o nome do DM antigo. Não deve sobrar nada.

O checklist completo está em `references/validacao.md`.

### 9. Teste do Repo/Service

A compilação não pega erro de SQL nem de driver: o `GetLastAutoGenValue` do SQLite, por exemplo, compila e só falha em execução. Escreva um programa console temporário no diretório de scratch que exercite Insert, GetById, Update, as validações, Delete e List. Para banco em arquivo (SQLite, Firebird embarcado), rode contra uma **cópia** do arquivo. Para banco em servidor, pergunte antes, porque o teste grava dados. Como montar e compilar: `references/validacao.md`.

### 10. Relatório final

Entregue:

- Arquivos criados, alterados e removidos.
- O que foi validado e o resultado: convert, compilação e teste do Repo/Service.
- Diferenças de comportamento e sugestões de melhoria que não foram aplicadas.
- Roteiro curto para o usuário testar a tela: navegar no grid, Novo/Gravar, Alterar/Gravar, Cancelar, Excluir, e uma validação.

Não faça commit sem o usuário pedir.

## Fora do escopo (v1)

Se encontrar algum destes itens, descreva o que achou e pergunte como seguir em vez de converter por conta própria:

- **Master-detail:** `MasterSource`/`MasterFields`, `DataSetField`, mais de uma tabela editada no mesmo form. Uma versão futura pode seguir o padrão de listas do módulo CIOT, com `TObjectList` no Model e um `MTB_` por lista.
- **Lookups:** `TDBLookupComboBox`/`TDBLookupListBox` e campos lookup ou calculados que vão além de formatação.
- **Atualização indireta:** `TClientDataSet` com `TDataSetProvider`, cached updates, `TDBNavigator` controlando o dataset.
- **SQL espalhado:** comandos SQL executados em eventos ou triggers chamados pelo form, que mudam outras tabelas.
- **Imagens e blobs:** `TDBImage` e campos blob.
