# Validação

## 1. Codificação e quebra de linha

`scripts/normalizar-arquivos.ps1` converte os arquivos escritos pelas ferramentas (UTF-8 sem BOM, LF) para o formato do Delphi:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill>\scripts\normalizar-arquivos.ps1" -Encoding Ansi -Arquivos "C:\proj\Src\Clientes\Clientes.Service.pas,C:\proj\Src\Clientes\Clientes.Cad.View.pas"
```

- `-Encoding Ansi`: cp1252, o padrão de projeto legado sem BOM. `-Encoding Utf8Bom`: quando o .pas legado tinha BOM.
- Arquivo que já tem BOM UTF-8 (como o `.dproj`) continua UTF-8 com BOM; só a quebra de linha é ajustada.
- Arquivo que já está em ANSI é reconhecido e não é convertido de novo, então rodar duas vezes é seguro.
- O script avisa quando um `.dfm` tem caractere não ASCII. Nesse caso, troque por escape (`'Descri'#231#227'o'`).

Rode depois da última edição de cada arquivo. Para editar de novo um arquivo que já está em ANSI, converta antes com `-Encoding Utf8`, edite e volte com `-Encoding Ansi`. Editar o ANSI direto troca os acentos por caracteres inválidos.

## 2. .dfm e compilação

```powershell
powershell -ExecutionPolicy Bypass -File "<skill>\scripts\validar-delphi.ps1" -Projeto "C:\proj\Projeto.dproj" -Dfm "C:\proj\Src\Clientes\Clientes.Cad.View.dfm,C:\proj\Src\Conexao.DM.dfm"
```

- Cada .dfm é copiado para uma pasta temporária e convertido com `convert.exe -i`. Se a conversão falha, o .dfm tem erro de sintaxe. O original não é tocado.
- Depois roda `rsvars.bat` + `msbuild /t:Build` (padrão Debug/Win32; use `-Config` e `-Platform` para mudar) e mostra erros e warnings.
- O RAD Studio é localizado pelo registro (`HKCU/HKLM\Software\Embarcadero\BDS\<versão>\RootDir`), usando a maior versão instalada. Para escolher outra, passe `-BdsDir "C:\Program Files (x86)\Embarcadero\Studio\23.0"`.
- Saída diferente de zero = falhou. Corrija e rode de novo até passar.

Erros de compilação comuns nesta refatoração:

| Erro | Causa provável |
|---|---|
| `Undeclared identifier: 'TFDMemTable'` | Faltam as units FireDAC na `uses` do form |
| `Field <nome> does not have a corresponding component` / dfm sem campo | Declaração no .pas diferente do .dfm (nome ou classe) |
| `File not found: 'ZConnection.dcu'` | Zeos fora do library path; a c4d-conn precisa dele |

## 3. Sobras do legado

Grep no .pas e no .dfm do form refatorado. Nada disto pode sobrar:
- `TDB` (exceto `TDBGrid`), `DataField`, `ValueChecked`.
- O nome da unit e da variável do DM antigo, se ele foi removido ou renomeado.
- Componentes com nome padrão da IDE (`Label1`, `Edit1`, `DataSource1`, `DBGrid1`).

Grep no projeto inteiro pelo nome do DM antigo e pelos componentes renomeados: outras units podiam referenciá-los.

## 4. Teste do Repo/Service

Programa console temporário no diretório de scratch (nunca dentro do projeto), que:

1. Cria o DM de conexão (ou configura o C4DConn) apontando para uma **cópia** do banco, se ele for um arquivo.
2. Chama `List` e mostra a quantidade.
3. Faz Insert e mostra o id gerado; GetById confere os valores.
4. Faz Update e confere de novo com GetById.
5. Dispara cada validação do Service com um Model inválido e mostra a mensagem.
6. Faz Delete e confere que `GetById` devolve Id 0.
7. Envolve tudo em `try/except` e imprime `E.ClassName` e `E.Message`.

Esqueleto (ajuste nomes e campos):

```pascal
program TesteClientes;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Conexao.DM,
  Clientes.Model,
  Clientes.Service;

begin
  try
    ConexaoDM := TConexaoDM.Create(nil);
    try
      ConexaoDM.FDConnection.Params.Database := ParamStr(1);
      var LService := TClientesService.New;
      ...
    finally
      ConexaoDM.Free;
    end;
  except
    on E: Exception do
      Writeln('FALHA: ', E.ClassName, ': ', E.Message);
  end;
end.
```

Compilação com `dcc32` (Git Bash). O jeito mais simples é compilar o projeto principal antes (etapa 2) e apontar `-U` para a pasta de DCUs dele, que já tem a c4d-conn, o Zeos e as demais dependências compiladas. Junte as pastas de fonte das units do teste:

```bash
"$BDS/bin/dcc32.exe" -Q -NS"System;Winapi;System.Win;Data;Data.Win;Vcl;Xml" \
  -U"<proj>\DCU;<proj>\Src;<proj>\Src\Clientes;<proj>\modules\c4d-conn\src" \
  -E"out" -NU"dcu" TesteClientes.dpr
```

Se faltar alguma unit de biblioteca, acrescente o caminho dela (do `DCC_UnitSearchPath` do .dproj ou do library path no registro) em `-U`, e em `-I` quando ela usar arquivos `.inc` (o Zeos usa).

Problemas conhecidos do `dcc32`:
- **`E1026` (arquivo `.dfm` não encontrado):** acrescente as pastas dos `.dfm` usados pelas units do teste em `-R`.
- **`E2288` (caminho muito longo):** a lista de `-U` ficou grande demais. Rode o `dcc32` de dentro da pasta de scratch e use caminhos relativos, ou passe só as pastas necessárias.

Se o banco for um servidor, pergunte ao usuário antes de rodar: o teste grava e apaga um registro.

Não use `Setup`, `Install`, `Update` ou `Patch` no nome do programa de teste. O Windows trata esses executáveis como instaladores, exige elevação e a execução falha com "Permission denied".

Rode o executável passando o caminho da cópia, confira a saída e apague a cópia depois. A saída do console sai em cp1252; para ler no Git Bash use `| iconv -f CP1252 -t UTF-8`.
