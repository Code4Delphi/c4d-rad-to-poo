<#
  Valida a refatoracao:
    1. Converte cada .dfm informado com convert.exe -i em uma copia temporaria (o original nao e tocado).
    2. Compila o projeto com rsvars.bat + msbuild.

  Exemplo:
    powershell -ExecutionPolicy Bypass -File validar-delphi.ps1 -Projeto C:\proj\Projeto.dproj -Dfm C:\proj\Src\Clientes.Cad.View.dfm

  Codigo de saida 0 = tudo OK.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Projeto,

  [string[]]$Dfm = @(),

  [string]$Config = 'Debug',

  [string]$Platform = 'Win32',

  [string]$BdsDir
)

$ErrorActionPreference = 'Stop'

# Com "powershell -File", a lista "a,b" chega como uma unica string.
$Dfm = @($Dfm | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })

function Get-BdsDir {
  $raizes = @(
    'HKCU:\Software\Embarcadero\BDS',
    'HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS',
    'HKLM:\SOFTWARE\Embarcadero\BDS'
  )

  foreach ($raiz in $raizes) {
    if (-not (Test-Path $raiz)) { continue }

    $versoes = Get-ChildItem $raiz |
      Where-Object { $_.PSChildName -match '^\d+\.\d+$' } |
      Sort-Object { [version]$_.PSChildName } -Descending

    foreach ($versao in $versoes) {
      $rootDir = (Get-ItemProperty $versao.PSPath -ErrorAction SilentlyContinue).RootDir
      if ($rootDir -and (Test-Path (Join-Path $rootDir 'bin\rsvars.bat'))) {
        return $rootDir.TrimEnd('\')
      }
    }
  }

  throw 'RAD Studio nao encontrado no registro. Informe -BdsDir.'
}

if (-not $BdsDir) { $BdsDir = Get-BdsDir }
$BdsDir = $BdsDir.TrimEnd('\')
$convert = Join-Path $BdsDir 'bin\convert.exe'
$rsvars = Join-Path $BdsDir 'bin\rsvars.bat'
Write-Output "RAD Studio: $BdsDir"

$falhou = $false

if ($Dfm.Count -gt 0) {
  $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('c4d-dfm-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $temp | Out-Null
  try {
    $indice = 0
    foreach ($arquivo in $Dfm) {
      $indice++
      $original = (Resolve-Path -LiteralPath $arquivo).Path
      $pasta = Join-Path $temp $indice
      New-Item -ItemType Directory -Path $pasta | Out-Null
      $copia = Join-Path $pasta (Split-Path $original -Leaf)
      Copy-Item -LiteralPath $original -Destination $copia

      $saida = (& $convert -i $copia | Out-String)
      if (($LASTEXITCODE -ne 0) -or ($saida -notmatch '\(binary\)')) {
        Write-Output "[ERRO] DFM: $original"
        Write-Output $saida
        $falhou = $true
      }
      else {
        Write-Output "[OK] DFM: $original"
      }
    }
  }
  finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$caminhoProjeto = (Resolve-Path -LiteralPath $Projeto).Path
Write-Output "Compilando $caminhoProjeto ($Config/$Platform)..."
$saidaBuild = cmd /c "call `"$rsvars`" && msbuild `"$caminhoProjeto`" /t:Build /p:Config=$Config /p:Platform=$Platform /v:minimal /nologo"
$codigoBuild = $LASTEXITCODE
$saidaBuild | ForEach-Object { Write-Output $_ }

if ($codigoBuild -ne 0) {
  Write-Output "[ERRO] Compilacao falhou (codigo $codigoBuild)."
  $falhou = $true
}
else {
  Write-Output '[OK] Compilacao'
}

if ($falhou) { exit 1 }
exit 0
