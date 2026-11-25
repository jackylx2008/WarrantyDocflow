$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
Set-Location -LiteralPath $projectRoot

$python = if (Test-Path -LiteralPath (Join-Path $projectRoot ".build-venv\Scripts\python.exe")) {
    Join-Path $projectRoot ".build-venv\Scripts\python.exe"
} elseif (Test-Path -LiteralPath (Join-Path $projectRoot ".venv\Scripts\python.exe")) {
    Join-Path $projectRoot ".venv\Scripts\python.exe"
} else {
    "python"
}

& $python -c "import PyInstaller, PIL, fitz, yaml, docx, openpyxl"
if ($LASTEXITCODE -ne 0) {
    throw "缺少构建依赖，请先运行: $python -m pip install -r requirements-build.txt"
}

$appName = "质保作业申请归档"
$iconPath = Join-Path $projectRoot "assets\warranty-docflow.ico"
$buildDir = Join-Path $projectRoot "build"
$distDir = Join-Path $buildDir "delivery"
$workDir = Join-Path $buildDir "run_archive"
$specDir = $buildDir
$output = Join-Path $distDir "$appName.exe"
$entryPoint = Join-Path $projectRoot "warranty-docflow.py"
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

& $python -m PyInstaller `
    --onefile `
    --windowed `
    --clean `
    --noconfirm `
    --name $appName `
    --icon $iconPath `
    --add-data "$iconPath;assets" `
    --paths (Join-Path $projectRoot "src") `
    --distpath $distDir `
    --workpath $workDir `
    --specpath $specDir `
    $entryPoint
if ($LASTEXITCODE -ne 0) {
    throw "EXE 构建失败，退出代码: $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
    throw "构建完成但未找到输出文件: $output"
}

# Only remove generated PyInstaller intermediates after the final EXE is confirmed.
if (Test-Path -LiteralPath $workDir) {
    $resolvedBuildDir = (Resolve-Path -LiteralPath $buildDir).Path
    $resolvedWorkDir = (Resolve-Path -LiteralPath $workDir).Path
    if (-not $resolvedWorkDir.StartsWith($resolvedBuildDir, [StringComparison]::OrdinalIgnoreCase)) {
        throw "拒绝清理构建目录之外的路径: $resolvedWorkDir"
    }
    Remove-Item -LiteralPath $resolvedWorkDir -Recurse -Force
}

Get-ChildItem -LiteralPath $specDir -Filter "*.spec" -File | Remove-Item -Force
Get-ChildItem -LiteralPath $distDir -Filter "*.exe" -File |
    Where-Object { $_.FullName -ne $output } |
    Remove-Item -Force

Write-Host "构建完成: $output"
