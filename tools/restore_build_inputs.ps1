$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$meta = Get-Content -LiteralPath (Join-Path $repo 'UPSTREAM.json') -Raw | ConvertFrom-Json
$cache = Join-Path $repo '.build-input-cache'
New-Item -ItemType Directory -Force $cache | Out-Null
function Run-Git([string[]]$GitArgs) {
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git failed: $GitArgs" }
}
function Copy-Inputs([string]$from, [string]$to) {
    if (!(Test-Path -LiteralPath $from)) { return }
    $base = (Resolve-Path -LiteralPath $from).Path
    Get-ChildItem -LiteralPath $base -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($base.Length).TrimStart('\')
        if ($rel -match '(^|\\)\.git(\\|$)' -or $rel -match 'nvngx_dlss') { return }
        $dest = Join-Path $to $rel
        New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
    }
}
foreach ($name in @('OptiScaler','NSS')) {
    $checkout = Join-Path $cache $name
    $info = $meta.$name
    if (!(Test-Path -LiteralPath (Join-Path $checkout '.git'))) { Run-Git -GitArgs @('clone','--no-checkout',$info.url,$checkout) }
    Run-Git -GitArgs @('-C',$checkout,'checkout','--detach',$info.commit)
    Run-Git -GitArgs @('-C',$checkout,'submodule','update','--init','--recursive')
    if ($name -eq 'OptiScaler') {
        Copy-Inputs (Join-Path $checkout 'external') (Join-Path $repo 'source\OptiScaler\external')
        Copy-Inputs (Join-Path $checkout 'OptiScaler\library') (Join-Path $repo 'source\OptiScaler\OptiScaler\library')
    } else {
        foreach ($path in @('sdk\tools\ffx_shader_compiler\libs\SPIRV-Cross','sdk\libs\SPIRV-Headers','sdk\libs\SPIRV-Tools','prebuilt_binaries')) {
            Copy-Inputs (Join-Path $checkout $path) (Join-Path $repo ('source\NSS\'+$path))
        }
    }
}
Write-Host 'Dependencies restored. Obtain NVIDIA NGX headers separately under their terms before building OptiScaler.'
