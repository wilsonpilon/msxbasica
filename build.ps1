<#
.SYNOPSIS
    Compila o executavel do MSX BASIC+Z80 IDE (editor\BadigEditor.pb) usando o
    PureBasic Compiler (pbcompiler.exe).

.DESCRIPTION
    O caminho do pbcompiler.exe e resolvido nesta ordem de prioridade:
      1) Opcao -C / --compiler na linha de comando
      2) Valor "CompilerPath" gravado em build.config.json (ao lado deste script)
      3) Caminho padrao: %PROGRAMFILES%\PureBasic\Compilers\pbcompiler.exe
    Quando o caminho e informado via -C/--compiler, ele e salvo em
    build.config.json para as proximas execucoes.

    Versao e build sao embutidas no executavel em tempo de compilacao via
    /CONSTANT do pbcompiler (constantes #App_Version/#App_Build/#App_BuildDate
    em editor\BadigEditor.pb, exibidas em Ajuda -> Sobre...): a build e a
    data/hora UTC do momento da compilacao, convertida para hexadecimal
    (segundos desde a epoch Unix).

    Todas as opcoes (-H/--help, -C/--compiler, -R/--run, -V/--version,
    -i/--sourcefile, -o/--outputexe) sao lidas manualmente de $args abaixo, em vez de um bloco
    param() do PowerShell: PowerShell 7 faz *binding posicional* de qualquer
    token que nao reconhece (ex.: "--run") para o primeiro parametro
    declarado, mesmo sem "-" na frente - com param(), ".\build.ps1 --run"
    silenciosamente virava $Version = "--run". Sem param(), $args recebe tudo
    e o parsing abaixo decide o que fazer com cada token.

.EXAMPLE
    .\build.ps1
.EXAMPLE
    .\build.ps1 -C "D:\PureBasic\Compilers\pbcompiler.exe"
.EXAMPLE
    .\build.ps1 --compiler "D:\PureBasic\Compilers\pbcompiler.exe" --run
.EXAMPLE
    .\build.ps1 -V "5.2.0" -R
.EXAMPLE
    .\build.ps1 -H
#>

$ErrorActionPreference = "Stop"

function Show-Help {
    @"
Uso: build.ps1 [opcoes]

Compila (e opcionalmente executa) o MSX BASIC+Z80 IDE via PureBasic Compiler.

Opcoes:
  -C, --compiler <caminho>  Caminho para o pbcompiler.exe. Fica salvo em
                             build.config.json para as proximas execucoes.
  -R, --run                 Executa o programa apos compilar com sucesso.
  -H, --help                Mostra esta ajuda e sai.
  -V, --version <versao>    Versao embutida no executavel (padrao: 5.7.3).
  -i, --sourcefile <arquivo> Arquivo fonte a compilar
                             (padrao: editor\BadigEditor.pb).
  -o, --outputexe <arquivo> Caminho do executavel de saida
                             (padrao: editor\BadigEditor.exe).

Exemplos:
  .\build.ps1
  .\build.ps1 -C "C:\Basic\Compilers\pbcompiler.exe"
  .\build.ps1 --compiler "C:\Basic\Compilers\pbcompiler.exe" --run
  .\build.ps1 -V "5.2.0" -R
"@ | Write-Host
}

# Ver nota no bloco de ajuda acima sobre por que isso nao e um param().
$Help = $false
$Compiler = $null
$Run = $false
$Version = "5.7.3"
$SourceFile = Join-Path $PSScriptRoot "editor\BadigEditor.pb"
$OutputExe = Join-Path $PSScriptRoot "editor\BadigEditor.exe"

# $args e uma variavel automatica por escopo (uma funcao chamada daqui teria
# o SEU PROPRIO $args, nao o deste script) - por isso o parsing e feito inline
# num unico loop, em vez de delegado a uma funcao auxiliar.
$i = 0
while ($i -lt $args.Count) {
    $token = $args[$i]
    switch -Regex ($token) {
        '^(-H|--help)$' { $Help = $true }

        '^(-C|--compiler)$' {
            $i++
            if ($i -ge $args.Count) { Write-Error "Falta o caminho depois de $token."; exit 1 }
            $Compiler = $args[$i]
        }

        '^(-R|--run)$' { $Run = $true }

        '^(-V|--version)$' {
            $i++
            if ($i -ge $args.Count) { Write-Error "Falta a versao depois de $token."; exit 1 }
            $Version = $args[$i]
        }

        '^(-i|--sourcefile)$' {
            $i++
            if ($i -ge $args.Count) { Write-Error "Falta o caminho depois de $token."; exit 1 }
            $SourceFile = $args[$i]
        }

        '^(-o|--outputexe)$' {
            $i++
            if ($i -ge $args.Count) { Write-Error "Falta o caminho depois de $token."; exit 1 }
            $OutputExe = $args[$i]
        }

        default {
            Write-Warning "Parametro desconhecido: $token (use -H ou --help para ver as opcoes)."
        }
    }
    $i++
}

if ($Help) {
    Show-Help
    exit 0
}

$ConfigPath = Join-Path $PSScriptRoot "build.config.json"
$DefaultCompilerPath = Join-Path $env:PROGRAMFILES "PureBasic\Compilers\pbcompiler.exe"

function Get-BuildConfig {
    if (Test-Path $ConfigPath) {
        try {
            return Get-Content $ConfigPath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Nao foi possivel ler $ConfigPath ($($_.Exception.Message)). Ignorando arquivo de configuracao."
        }
    }
    return $null
}

function Set-BuildConfig([string]$CompilerPath) {
    [ordered]@{ CompilerPath = $CompilerPath } | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
}

$config = Get-BuildConfig

if ($Compiler) {
    $CompilerPath = $Compiler
    Set-BuildConfig -CompilerPath $CompilerPath
    Write-Host "Caminho do compilador salvo em $ConfigPath"
} elseif ($config -and $config.CompilerPath) {
    $CompilerPath = $config.CompilerPath
} else {
    $CompilerPath = $DefaultCompilerPath
}

if (-not (Test-Path $CompilerPath)) {
    Write-Error "pbcompiler.exe nao encontrado em: $CompilerPath`nConfigure o caminho correto via -C/--compiler ou edite $ConfigPath."
    exit 1
}

if (-not (Test-Path $SourceFile)) {
    Write-Error "Arquivo fonte nao encontrado: $SourceFile"
    exit 1
}

$OutputDir = Split-Path $OutputExe -Parent
if ($OutputDir -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$UtcNow = [DateTime]::UtcNow
$BuildEpoch = [DateTimeOffset]::new($UtcNow, [TimeSpan]::Zero).ToUnixTimeSeconds()
$BuildHex = "{0:X8}" -f $BuildEpoch
$BuildDateText = $UtcNow.ToString("yyyy-MM-dd HH:mm:ss") + " UTC"

Write-Host "Compilador : $CompilerPath"
Write-Host "Fonte      : $SourceFile"
Write-Host "Saida      : $OutputExe"
Write-Host "Versao     : $Version"
Write-Host "Build      : $BuildHex ($BuildDateText)"
Write-Host ""

& $CompilerPath $SourceFile /OUTPUT $OutputExe /QUIET /CONSOLE `
    /CONSTANT "App_Version=$Version" `
    /CONSTANT "App_Build=$BuildHex" `
    /CONSTANT "App_BuildDate=$BuildDateText"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha na compilacao (codigo $LASTEXITCODE)."
    exit $LASTEXITCODE
}

Write-Host "Build concluido: $OutputExe"

if ($Run) {
    Write-Host "Executando $OutputExe ..."
    Start-Process -FilePath $OutputExe
}
