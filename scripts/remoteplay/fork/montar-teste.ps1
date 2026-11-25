<#
Monta uma pasta de teste do Veyra com PS5 a partir de dois arquivos JA BAIXADOS:

  1. o pacote portatil OFICIAL (Veyra-<versao>-NVIDIA-win64-portable.zip), baixado somente de
     https://github.com/Likely7/Veyra-NRVideo/releases
  2. o zip gerado pelo GitHub Actions do fork raghadev/Veyra-NRVideo
     (artefato veyra-windows-ps5-ci-no-gpu-runtimes)

O script nao baixa nada e nao abre o programa. Ele extrai o pacote oficial em -Destino e troca,
dentro dele, o veyra_qml_ui.exe, a pasta qml\Veyra e a pasta shaders pelos do fork. Os originais
ficam guardados em -Destino\_oficial. A instalacao oficial que voce ja usa nao e tocada.

Uso (PowerShell):
  powershell -ExecutionPolicy Bypass -File montar-teste.ps1 `
    -PacoteOficial C:\Downloads\Veyra-2.2.1-NVIDIA-win64-portable.zip `
    -ZipDoFork C:\Downloads\veyra-windows-ps5-ci-no-gpu-runtimes.zip `
    -Destino C:\Veyra-PS5-teste
#>
param(
    [Parameter(Mandatory = $true)][string]$PacoteOficial,
    [Parameter(Mandatory = $true)][string]$ZipDoFork,
    [Parameter(Mandatory = $true)][string]$Destino
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PacoteOficial -PathType Leaf)) { throw "Pacote oficial nao encontrado: $PacoteOficial" }
if (-not (Test-Path -LiteralPath $ZipDoFork -PathType Leaf)) { throw "Zip do fork nao encontrado: $ZipDoFork" }
if (Test-Path -LiteralPath $Destino) { throw "A pasta de destino ja existe. Escolha outra ou apague-a antes: $Destino" }

$work = Join-Path ([IO.Path]::GetTempPath()) ('veyra-ps5-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    # The artifact downloaded from GitHub wraps the real package in an outer zip.
    $fork = Join-Path $work 'fork'
    Expand-Archive -LiteralPath $ZipDoFork -DestinationPath $fork
    $inner = @(Get-ChildItem -LiteralPath $fork -Filter '*.zip' -File)
    if ($inner.Count -gt 0) { Expand-Archive -LiteralPath $inner[0].FullName -DestinationPath $fork }
    $forkExe = @(Get-ChildItem -LiteralPath $fork -Recurse -Filter 'veyra_qml_ui.exe' -File)
    if ($forkExe.Count -ne 1) { throw "Esperava um veyra_qml_ui.exe no zip do fork, achei $($forkExe.Count)" }
    $forkRoot = $forkExe[0].DirectoryName
    foreach ($need in 'qml\Veyra\Main.qml', 'qml\Veyra\StreamHud.qml', 'shaders') {
        if (-not (Test-Path -LiteralPath (Join-Path $forkRoot $need))) { throw "Falta no zip do fork: $need" }
    }

    Write-Host 'Extraindo o pacote oficial (pode levar alguns minutos)...'
    Expand-Archive -LiteralPath $PacoteOficial -DestinationPath $Destino
    $officialExe = @(Get-ChildItem -LiteralPath $Destino -Recurse -Filter 'veyra_qml_ui.exe' -File)
    if ($officialExe.Count -ne 1) { throw "Esperava um veyra_qml_ui.exe no pacote oficial, achei $($officialExe.Count)" }
    $app = $officialExe[0].DirectoryName
    if (-not (Test-Path -LiteralPath (Join-Path $app 'qml\Veyra\Main.qml'))) { throw "Pacote oficial com estrutura inesperada: $app" }

    # Same swap the upstream project documents for a manual stage: player, its QML and ALL the
    # shaders of the same build. Every other file stays the official one.
    $backup = Join-Path $Destino '_oficial'
    New-Item -ItemType Directory -Path $backup | Out-Null
    Move-Item -LiteralPath (Join-Path $app 'veyra_qml_ui.exe') -Destination $backup
    Move-Item -LiteralPath (Join-Path $app 'qml\Veyra') -Destination (Join-Path $backup 'qml-Veyra')
    if (Test-Path -LiteralPath (Join-Path $app 'shaders')) { Move-Item -LiteralPath (Join-Path $app 'shaders') -Destination $backup }

    Copy-Item -LiteralPath $forkExe[0].FullName -Destination $app
    Copy-Item -LiteralPath (Join-Path $forkRoot 'qml\Veyra') -Destination (Join-Path $app 'qml') -Recurse
    Copy-Item -LiteralPath (Join-Path $forkRoot 'shaders') -Destination $app -Recurse

    $expected = (Get-FileHash -Algorithm SHA256 -LiteralPath $forkExe[0].FullName).Hash
    $placed = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $app 'veyra_qml_ui.exe')).Hash
    if ($placed -ne $expected) { throw 'O veyra_qml_ui.exe copiado nao confere com o do zip do fork' }
    if (-not (Test-Path -LiteralPath (Join-Path $app 'qml\Veyra\StreamHud.qml'))) { throw 'qml\Veyra\StreamHud.qml nao chegou ao destino' }

    $launcher = @(Get-ChildItem -LiteralPath $Destino -Recurse -Filter 'Veyra.exe' -File | Select-Object -First 1)
    Write-Host ''
    Write-Host "PRONTO. Pasta de teste: $Destino"
    Write-Host "Programa do fork (SHA-256): $($placed.ToLowerInvariant())"
    Write-Host "Originais guardados em: $backup"
    if ($launcher.Count -eq 1) { Write-Host "Para abrir: $($launcher[0].FullName)" }
    else { Write-Host "Para abrir: $(Join-Path $app 'veyra_qml_ui.exe')" }
    Write-Host 'No programa: parear o PS5 e apertar Ctrl+Alt+Shift+S para ver o painel de rede.'
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
