# Mapeamentos

## 1. Tipo do campo → Model → Repo → tela

| TField no DM | Tipo no Model | Leitura (LoadFields) | Componente na tela | Tela → Model / Model → tela |
|---|---|---|---|---|
| TIntegerField, TSmallintField, TAutoIncField | `Integer` | `AsInteger` | TEdit (chave: `ReadOnly = True`, `Color = clBtnFace`) | `StrToIntDef(Trim(edt.Text), 0)` / `.ToString`; se o DisplayFormat era `'000000'`, use `Format('%.6d', [Id])` |
| TLargeintField | `Int64` | `AsLargeInt` | TEdit | `StrToInt64Def(...)` / `.ToString` |
| TStringField, TWideStringField | `string` | `AsString` | TEdit com `MaxLength` = Size | `Trim(edt.Text)` / `edt.Text := ...` |
| TMemoField, TWideMemoField (ou TStringField grande ligado a TDBMemo) | `string` | `AsString` | TMemo | `mmo.Text` (não `mmo.Lines.Text`, que acrescenta uma quebra de linha no fim a cada gravação) |
| TFloatField, TBCDField, TFMTBCDField, TExtendedField | `Double` | `AsFloat` | TEdit com `Alignment = taRightJustify` | Ver "Campos numéricos" abaixo |
| TCurrencyField ou valor monetário em BCD | `Currency` se o projeto usa, senão `Double` | `AsCurrency`/`AsFloat` | TEdit com `Alignment = taRightJustify` | Ver "Campos numéricos" abaixo |
| TDateField | `TDate` | `AsDateTime` | Se o legado era TDBEdit com `EditMask` (data opcional digitada): TMaskEdit com a mesma máscara. Se não: TDateTimePicker (`Kind = dtkDate`) | TMaskEdit: `TryStrToDate` e erro claro se inválida, vazio = 0; picker: `.Date`. Data vazia = 0 no Model. O TDateTimePicker não aceita vazio sem `ShowCheckbox`, por isso não serve para data opcional |
| TDateTimeField, TSQLTimeStampField | `TDateTime` | `AsDateTime` | TDateTimePicker | `.DateTime` |
| TTimeField | `TTime` | `AsDateTime` | TDateTimePicker (`Kind = dtkTime`) | `.Time` |
| TBooleanField | `Boolean` | `AsBoolean` | TCheckBox | `.Checked` |
| TStringField(1) com 'S'/'N' (TDBCheckBox com ValueChecked) | `Boolean` | `SNToBool(AsString)` | TCheckBox | `.Checked`; grave com `BoolToSN` |
| Inteiro ligado a TDBRadioGroup/TDBComboBox com Values | `Integer` (ou enum se o projeto usa) | `AsInteger` | TRadioGroup / TComboBox | `ItemIndex` ↔ valor, conforme a lista `Values` do legado |

### Nulos

O Model não guarda NULL. Ao gravar, converta o "vazio" do Model (string vazia, data 0, FK 0) para NULL quando a coluna aceitar nulo e o legado gravava nulo. Se uma coluna numérica aceitava NULL e agora vai gravar 0, registre isso no plano como diferença de comportamento.

**No FireDAC, `AddParam('x', Null)` falha em execução** (erro -335, tipo do parâmetro desconhecido): o parâmetro só ganha tipo quando recebe um valor tipado. Com Zeos a passagem direta funciona. Use este helper privado no Repo, que funciona nos dois:

```pascal
procedure TClientesRepo.AddParamOuNulo(const AQuery: IC4DConnQuery; const AParam: string;
  const AValue: Variant; const ANulo: Boolean);
begin
  // A primeira atribuição define o tipo do parâmetro; a segunda grava NULL
  AQuery.AddParam(AParam, AValue);
  if ANulo then
    AQuery.AddParam(AParam, Null);
end;

// uso:
Self.AddParamOuNulo(AQuery, 'email', ACliente.Email, ACliente.Email.IsEmpty);
```

Inclua `System.Variants` na `uses`.

### Datas como parâmetro

`TDate`/`TDateTime` passados para `AddParam` (Variant) viram `varDouble`. O SQLite grava o número (ex.: `33831`) sem erro e a leitura seguinte falha. Converta antes:
- `VarFromDateTime(AModel.Data)`, que gera `varDate` e o FireDAC grava no formato de data do banco; ou
- string no formato que a tabela usa, como o CIOT faz: `FormatDateTime('yyyy-mm-dd', AModel.Data)`.

Para data opcional, combine com o helper de nulos: `Self.AddParamOuNulo(AQuery, 'data_nascimento', VarFromDateTime(ACliente.DataNascimento), ACliente.DataNascimento = 0)`. Confira no teste da etapa 9 que a data volta igual depois de gravada.

## 2. Componente DB-aware → componente comum (.dfm)

| Legado | Novo | Remover no .dfm | Observação |
|---|---|---|---|
| TDBEdit | TEdit (ou TMaskEdit se o TField tinha `EditMask`) | `DataField`, `DataSource` | Texto: `MaxLength` = Size do TField. Número: `Alignment = taRightJustify` |
| TDBMemo | TMemo | `DataField`, `DataSource` | |
| TDBCheckBox | TCheckBox | `DataField`, `DataSource`, `ValueChecked`, `ValueUnchecked` | Os valores 'S'/'N' vão para o Repo |
| TDBComboBox | TComboBox | `DataField`, `DataSource` | Mantém `Items`/`Style` |
| TDBRadioGroup | TRadioGroup | `DataField`, `DataSource`, `Values` | `Values` vira conversão no código |
| TDBText | TLabel | `DataField`, `DataSource` | Caption preenchido no código |
| TDBGrid | TDBGrid (fica) | — | `DataSource = DS_<Prefixo>`; `Columns.FieldName` devem existir no MTB |
| TDataSource ligado ao DM | `DS_<Prefixo>` ligado ao `MTB_<Prefixo>` | `DataSet = <DM>.<Query>` | Adicionar `OnDataChange = DS_<Prefixo>DataChange` |
| Componentes DB de terceiros (JVCL, DevExpress `cxDB*`, `wwDB*`) | Versão não-DB da mesma suíte | Propriedades de ligação a dados | Confirme no plano se houver dúvida |

### Campos numéricos

Use só componentes da VCL: TEdit para números. Não use componentes de máscara numérica de terceiros (como TC4DMaskEdit), mesmo que estejam instalados. O TDBEdit herdava o alinhamento do TField, e campos numéricos ficam à direita; mantenha isso com `Alignment = taRightJustify`:

```
    object edtPreco: TEdit
      Left = 32
      Top = 184
      Width = 154
      Height = 23
      Alignment = taRightJustify
      TabOrder = 3
    end
```

A conversão fica na View. Mostre o valor sem separador de milhar, para o texto voltar a ser lido por `TryStrToFloat`:

```pascal
// Model -> tela
edtPreco.Text := FormatFloat('0.00', AProduto.Preco);

// tela -> Model (vazio = 0; texto inválido = erro claro, como o TDBEdit fazia)
var LPreco: Double := 0;
if (not Trim(edtPreco.Text).IsEmpty) and (not TryStrToFloat(Trim(edtPreco.Text), LPreco)) then
  raise Exception.Create('Preço inválido.');
AProduto.Preco := LPreco;
```

Use o número de casas do `DisplayFormat` legado no `FormatFloat` (ex.: `',0.000'` → `'0.000'`). Para inteiros, use `StrToIntDef`/`TryStrToInt` e `.ToString`.

## 3. TFDMemTable no .dfm

Bloco base, copiado do módulo CIOT; ajuste nome, posição e fields:

```
  object MTB_Clientes: TFDMemTable
    FieldDefs = <>
    IndexDefs = <>
    FetchOptions.AssignedValues = [evMode]
    FetchOptions.Mode = fmAll
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvCheckRequired, uvAutoCommitUpdates]
    UpdateOptions.CheckRequired = False
    UpdateOptions.AutoCommitUpdates = True
    StoreDefs = True
    Left = 456
    Top = 88
    object MTB_Clientesid: TIntegerField
      FieldName = 'id'
      DisplayFormat = '000000'
    end
    object MTB_Clientesnome: TStringField
      FieldName = 'nome'
      Size = 60
    end
  end
  object DS_Clientes: TDataSource
    DataSet = MTB_Clientes
    OnDataChange = DS_ClientesDataChange
    Left = 576
    Top = 88
  end
```

Copie dos TFields do DM apenas o que afeta exibição: `FieldName`, `Size`, `DisplayFormat`, `DisplayLabel`, `Alignment`, `Visible`, `EditMask`. Não copie `Origin`, `ProviderFlags` nem `Required`: no MemTable eles não têm função, e `Required` faria o Post do MTB falhar com campo vazio.

Campo 'S'/'N' no grid: use `TBooleanField` com `DisplayValues = 'S;N'` no MTB (o grid continua mostrando S/N) ou mantenha um `TStringField` de tamanho 1.

O MTB pode ter todas as colunas da tabela ou só as do grid. Como `CarregarRegistroSelecionado` busca o registro pelo Service (`GetById`), as duas formas funcionam.

## 4. `uses` do form

| Situação | Ação |
|---|---|
| Não sobrou componente DB-aware (exceto TDBGrid) | Remover `Vcl.DBCtrls` |
| DM legado | Remover a unit do DM |
| TFDMemTable | Adicionar `FireDAC.Stan.Intf`, `FireDAC.Stan.Option`, `FireDAC.Stan.Param`, `FireDAC.Stan.Error`, `FireDAC.DatS`, `FireDAC.Phys.Intf`, `FireDAC.DApt.Intf`, `FireDAC.Comp.DataSet`, `FireDAC.Comp.Client` |
| TMaskEdit | `Vcl.Mask` |
| TDateTimePicker | `Vcl.ComCtrls` |
| Camadas | `<Prefixo>.Model` e `<Prefixo>.Service` (a View não usa o Repo) |
| Sempre | `Data.DB` (TDataSource, TField), `Vcl.Grids` e `Vcl.DBGrids` |
