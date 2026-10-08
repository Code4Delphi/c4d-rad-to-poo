<#
  Converte arquivos Delphi escritos em UTF-8/LF para a codificacao do projeto, com CRLF.

  -Encoding Ansi    : cp1252 (padrao de projeto Delphi legado, sem BOM)
  -Encoding Utf8Bom : UTF-8 com BOM
  -Encoding Utf8    : UTF-8 sem BOM. Use para EDITAR de novo um arquivo que ja foi convertido para ANSI
                      (as ferramentas de edicao trabalham em UTF-8); depois de editar, rode com -Encoding Ansi.

  Arquivos que ja tem BOM UTF-8 (ex.: .dproj) continuam UTF-8 com BOM; so a quebra de linha muda.
  Arquivos que ja estao em ANSI sao detectados e nao sao convertidos de novo.
  Avisa quando um .dfm/.fmx tem caractere nao ASCII (deve usar escape #NNN).
  Codigo de saida = quantidade de arquivos com problema.
#>
param(
  [Parameter(Mandatory = $true)]
  [string[]]$Arquivos,

  [ValidateSet('Ansi', 'Utf8Bom', 'Utf8')]
  [string]$Encoding = 'Ansi'
)

$ErrorActionPreference = 'Stop'

# Com "powershell -File", a lista "a,b" chega como uma unica string.
$Arquivos = @($Arquivos | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })

$utf8Estrito = New-Object System.Text.UTF8Encoding($false, $true)
$utf8ComBom = New-Object System.Text.UTF8Encoding($true)
$utf8SemBom = New-Object System.Text.UTF8Encoding($false)
$ansiLeitura = [System.Text.Encoding]::GetEncoding(1252)
$ansiEstrito = [System.Text.Encoding]::GetEncoding(1252, [System.Text.EncoderFallback]::ExceptionFallback, [System.Text.DecoderFallback]::ExceptionFallback)
$problemas = 0

foreach ($arquivo in $Arquivos) {
  if (-not (Test-Path -LiteralPath $arquivo)) {
    Write-Warning "Arquivo nao encontrado: $arquivo"
    $problemas++
    continue
  }

  $caminho = (Resolve-Path -LiteralPath $arquivo).Path
  $bytes = [System.IO.File]::ReadAllBytes($caminho)
  $temBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)

  if ($temBom) {
    $texto = $utf8Estrito.GetString($bytes, 3, $bytes.Length - 3)
    $origem = 'UTF-8 com BOM'
    $destino = $utf8ComBom
    $nomeDestino = 'UTF-8 com BOM (mantido)'
  }
  else {
    try {
      $texto = $utf8Estrito.GetString($bytes)
      if ($texto -match '[^\x00-\x7F]') { $origem = 'UTF-8' } else { $origem = 'ASCII' }
    }
    catch {
      $texto = $ansiLeitura.GetString($bytes)
      $origem = 'ANSI'
    }

    if ($Encoding -eq 'Utf8Bom') {
      $destino = $utf8ComBom
      $nomeDestino = 'UTF-8 com BOM'
    }
    elseif ($Encoding -eq 'Utf8') {
      $destino = $utf8SemBom
      $nomeDestino = 'UTF-8 sem BOM (para edicao)'
    }
    else {
      $destino = $ansiEstrito
      $nomeDestino = 'ANSI (cp1252)'
    }
  }

  $texto = $texto -replace "`r`n", "`n" -replace "`r", "`n" -replace "`n", "`r`n"

  # Caractere acima de U+00FF em codigo Delphi legado quase sempre e corrupcao:
  # um caminho como Src\Clientes쫜lientes.pas pode ter "쫜" lido como escape Unicode.
  if ($texto -match '[^\x00-\xFF]') {
    $linhas = $texto -split "`r`n"
    for ($i = 0; $i -lt $linhas.Count; $i++) {
      if ($linhas[$i] -match '[^\x00-\xFF]') {
        Write-Warning ("{0}({1}): caractere suspeito (fora do Latin-1). Verifique se um trecho '\u' + 4 hex de um caminho virou escape Unicode: {2}" -f $caminho, ($i + 1), $linhas[$i].Trim())
      }
    }
    $problemas++
    continue
  }

  try {
    $conteudo = $destino.GetBytes($texto)
  }
  catch {
    Write-Warning "$caminho : ha caracteres que nao existem em cp1252. Use -Encoding Utf8Bom ou troque os caracteres."
    $problemas++
    continue
  }

  if ($destino -eq $utf8ComBom) {
    $conteudo = $utf8ComBom.GetPreamble() + $conteudo
  }

  [System.IO.File]::WriteAllBytes($caminho, $conteudo)
  Write-Output "[OK] $caminho : $origem -> $nomeDestino, CRLF"

  $extensao = [System.IO.Path]::GetExtension($caminho).ToLower()
  if (($extensao -eq '.dfm' -or $extensao -eq '.fmx') -and ($texto -match '[^\x00-\x7F]')) {
    $linhas = $texto -split "`r`n"
    for ($i = 0; $i -lt $linhas.Count; $i++) {
      if ($linhas[$i] -match '[^\x00-\x7F]') {
        Write-Warning ("{0}({1}): caractere nao ASCII no .dfm; use escape Delphi (ex.: 'Descri'#231#227'o'): {2}" -f $caminho, ($i + 1), $linhas[$i].Trim())
      }
    }
    $problemas++
  }
}

exit $problemas
