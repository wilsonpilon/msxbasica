# Script de compilação PowerShell para o projeto fossauro
# Executa o pbcompiler para gerar o executável fossauro.exe

$ErrorActionPreference = "Stop"

Write-Host "Iniciando compilação do fossauro..." -ForegroundColor Cyan

# Executa o compilador PureBasic
& pbcompiler fossauro.pb /THREAD /OUTPUT fossauro.exe /CONSTANT "App_Version=8.1.7"

if ($LASTEXITCODE -eq 0) {
    Write-Host "------------------------------------------------------------" -ForegroundColor Green
    Write-Host " SUCESSO: Compilação concluída com êxito!" -ForegroundColor Green
    Write-Host " Executável criado: fossauro.exe" -ForegroundColor Green
    Write-Host "------------------------------------------------------------" -ForegroundColor Green
} else {
    Write-Host "------------------------------------------------------------" -ForegroundColor Red
    Write-Host " ERRO: Falha na compilação do fossauro!" -ForegroundColor Red
    Write-Host "------------------------------------------------------------" -ForegroundColor Red
    exit $LASTEXITCODE
}
