# Skill c4d-rad-to-poo

A skill refatora cadastros (CRUDs) legados feitos no estilo RAD para camadas no padrão Repository (View, Service, Model e Repository) . Os cadastros de origem são os que usam DataModule com query e componentes DB-aware (`TDBEdit`, `TDBCheckBox`, `TDBMemo`...) ligados direto no banco.

View (Apresentação) — Forms e componentes visuais.
Service — Regras de negócio e casos de uso.
Model (Domínio) — Entidades e objetos de negócio.
Repository (Persistência) — Operações de acesso aos dados.

## O que a skill faz

Transforma o form legado em quatro camadas:

| Camada | Responsabilidade |
|---|---|
| `View (Apresentação)` | Componentes comuns da VCL e grid ligado a um `TFDMemTable`; conversa só com o Service |
| `<Prefixo>.Service` | Validações, regras de negócio, casos de uso e transação |
| `<Prefixo>.Model` | Entidades e objetos de negócio. Classe que espelha a tabela do banco. |
| `<Prefixo>.Repo (Persistência)` | Acesso ao banco com SQL via C4D.Conn: Insert, Update, Delete, GetById e List |

Na prática, a skill:

- **Pergunta o prefixo** das novas units. Com `Clientes`, por exemplo, gera `Clientes.Model`, `Clientes.Repo` e `Clientes.Service`.
- **Levanta as regras do legado**, sem alterar nada. Elas vêm dos eventos do DataModule, das propriedades dos campos e das restrições do banco.
- **Mostra um plano** com a tabela de campos e os arquivos afetados, e espera a sua confirmação.
- **Faz uma pergunta por vez**, inclusive as decisões do plano, e espera a resposta antes de fazer a próxima.
- **Escreve as camadas** e troca os componentes DB-aware pelos equivalentes comuns da VCL.
- **Mantém o grid sincronizado** com os campos da tela.
- **Valida os `.dfm`** com o `convert.exe`.
- **Compila** o projeto com o MSBuild.
- **Testa o Repo/Service** numa cópia do banco.
- **Mantém a tela e o comportamento do legado**, porque a refatoração é de arquitetura, não de interface.

## Pré-requisitos

- **RAD Studio:** testado no Delphi 12 Athens. A validação usa o `convert.exe` e o `rsvars.bat` da instalação.
- **C4D.Conn**, a biblioteca de acesso ao banco usada pelo Repo: [github.com/Code4Delphi/c4d-conn](https://github.com/Code4Delphi/c4d-conn). Instale antes de usar a skill:

  * Instalação via [Boss](https://github.com/HashLoad/boss):

    ```
    boss install github.com/Code4Delphi/c4d-conn
    ```

## ⚡️Como usar

1. Abra seu agente de codificação (Codex, Claude Code, Cursor, etc) na pasta do projeto. O projeto pode continuar aberto no RAD Studio; só não altere nem salve nada nele enquanto o agente trabalha.
2. Peça a refatoração.

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

3. Revise o plano apresentado e confirme.
4. Ao voltar para o RAD Studio, aceite recarregar os arquivos alterados (Yes to All) antes de salvar ou compilar pela IDE. Se ela não oferecer recarregar o projeto, reabra-o (File > Reopen) para as units novas aparecerem.
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

