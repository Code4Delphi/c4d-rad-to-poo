# Skill c4d-rad-to-poo

A skill refatora cadastros (CRUDs) legados feitos no estilo RAD para camadas no padrão Repository. Os cadastros de origem são os que usam DataModule com query e componentes DB-aware (`TDBEdit`, `TDBCheckBox`, `TDBMemo`...) ligados direto no banco.

## O que a skill faz

Transforma o form legado em quatro camadas:

| Camada | Responsabilidade |
|---|---|
| `<Prefixo>.Model` | Classe que espelha a tabela do banco |
| `<Prefixo>.Repo` | Acesso ao banco com SQL via C4D.Conn: Insert, Update, Delete, GetById e List |
| `<Prefixo>.Service` | Validações, regras de negócio e transação |
| View (o form existente) | Componentes comuns da VCL e grid ligado a um `TFDMemTable`; conversa só com o Service |

Na prática, a skill:

- **Pergunta o prefixo** das novas units. Com `Clientes`, por exemplo, gera `Clientes.Model`, `Clientes.Repo` e `Clientes.Service`.
- **Levanta as regras do legado**, sem alterar nada. Elas vêm dos eventos do DataModule, das propriedades dos campos e das restrições do banco.
- **Mostra um plano** com a tabela de campos e os arquivos afetados, e espera a sua confirmação.
- **Escreve as camadas** e troca os componentes DB-aware pelos equivalentes comuns da VCL.
- **Mantém o grid sincronizado** com os campos da tela.
- **Valida os `.dfm`** com o `convert.exe`.
- **Compila** o projeto com o MSBuild.
- **Testa o Repo/Service** numa cópia do banco.
- **Mantém a tela e o comportamento do legado**, porque a refatoração é de arquitetura, não de interface.

## Pré-requisitos

- **RAD Studio:** testado no Delphi 12 Athens. A validação usa o `convert.exe` e o `rsvars.bat` da instalação.
- **C4D.Conn**, a biblioteca de acesso ao banco usada pelo Repo: [github.com/Code4Delphi/c4d-conn](https://github.com/Code4Delphi/c4d-conn). Instale antes de usar a skill:

  * Instalação via Boss:

    ```
    boss install github.com/Code4Delphi/c4d-conn
    ```

## Como usar

1. Feche o projeto no RAD Studio. A IDE sobrescreve arquivos alterados em disco quando o projeto é salvo.
2. Abra seu agente de codificação (Codex, Claude Code, Cursor, etc) na pasta do projeto.
3. Peça a refatoração.

   **Sugestão de prompts para utilização:**

   * **Completo:**
     ```
     /c4d-rad-to-poo Refatore @SuaUnit com prefixo <AddPrefixo>
     ```
   * **Simples:**
     ```
     /c4d-rad-to-poo @SuaUnit
     ```

   Na versão simples, a skill pergunta o prefixo e sugere um nome derivado da unit.

4. Revise o plano apresentado e confirme.
5. No fim, teste a tela seguindo o roteiro do relatório: navegar no grid, incluir, alterar, cancelar, excluir e uma validação.


## Estrutura da skill

```
skills/c4d-rad-to-poo/
├── SKILL.md                       Fluxo da refatoração em 11 etapas, princípios e o que fica fora do escopo
├── references/
│   ├── arquitetura.md             Nomes, responsabilidade de cada camada, exceções e convenções de código
│   ├── mapeamento.md              Tipo do campo → Model → componente; DB-aware → VCL comum; bloco do TFDMemTable; uses
│   ├── conexao-c4dconn.md         Detecção e configuração da C4D.Conn, consultas, id gerado no Insert e transação
│   ├── validacao.md               Codificação dos arquivos, validação dos .dfm, compilação e teste do Repo/Service
│   └── exemplo/                   Cadastro de Produtos já refatorado, usado como modelo de estrutura e estilo
│       ├── Conexao.DM.pas         DataModule de conexão que configura a C4D.Conn
│       ├── Produtos.Model.pas     Classe que espelha a tabela product
│       ├── Produtos.Repo.pas      SQL via C4D.Conn
│       ├── Produtos.Service.pas   Validações e transação
│       └── Produtos.Cad.View.pas  Form com TFDMemTable no grid e componentes comuns da VCL
└── scripts/
    ├── normalizar-arquivos.ps1    Converte os arquivos para ANSI (cp1252) ou UTF-8 com BOM, sempre com CRLF
    └── validar-delphi.ps1         Valida os .dfm com convert.exe e compila o projeto com MSBuild
```

O `SKILL.md` é carregado sempre que a skill é acionada. As `references` são lidas só quando necessário, e os `scripts` são executados, não lidos.

## Fora do escopo (v1)

A skill para e pergunta antes de converter quando encontra:

- **Master-detail:** `MasterSource`/`MasterFields`, `DataSetField`, ou mais de uma tabela editada no mesmo form.
- **Lookups:** `TDBLookupComboBox` e campos lookup ou calculados.
- **Atualização indireta:** `TClientDataSet` com `TDataSetProvider`, cached updates ou `TDBNavigator`.
- **SQL em eventos:** SQL executado em eventos que alteram outras tabelas.
- **Imagens e blobs:** `TDBImage` e campos blob.

## Exemplo neste repositório

O cadastro de Produtos (`Src/Produtos`) foi o primeiro a ser refatorado e serviu de modelo para a skill:

- **Antes:** commit `add-c4d-conn`, com DataModule + `TFDQuery` + `TDBEdit`.
- **Depois:** commit `refactor/produtos-repository-001`, com Model, Repo, Service e View com `TFDMemTable`, mais o `Src/Conexao.DM`.
