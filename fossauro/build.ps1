# Script de compilação PowerShell para o projeto bafmsx
# Executa o pbcompiler para gerar o executável bafmsx_test2.exe

$ErrorActionPreference = "Stop"

Write-Host "Iniciando compilação do bafmsx..." -ForegroundColor Cyan

# Executa o compilador PureBasic
& pbcompiler bafmsx.pb /THREAD /OUTPUT bafmsx_test2.exe

if ($LASTEXITCODE -eq 0) {
    Write-Host "------------------------------------------------------------" -ForegroundColor Green
    Write-Host " SUCESSO: Compilação concluída com êxito!" -ForegroundColor Green
    Write-Host " Executável criado: bafmsx_test2.exe" -ForegroundColor Green
    Write-Host "------------------------------------------------------------" -ForegroundColor Green
} else {
    Write-Host "------------------------------------------------------------" -ForegroundColor Red
    Write-Host " ERRO: Falha na compilação do bafmsx!" -ForegroundColor Red
    Write-Host "------------------------------------------------------------" -ForegroundColor Red
    exit $LASTEXITCODE
}
