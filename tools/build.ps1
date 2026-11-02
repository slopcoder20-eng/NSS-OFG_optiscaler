param([ValidateSet('OptiScaler','Vulkan','D3D12')][string]$Component='OptiScaler')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$nss=Join-Path $repo 'source\NSS'
if($Component -eq 'OptiScaler') {
  $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  $msbuild=& $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
  if(!$msbuild){throw 'Visual Studio C++ tools / MSBuild not found'}
  & $msbuild (Join-Path $repo 'source\OptiScaler\OptiScaler\OptiScaler.vcxproj') /p:Configuration=Release /p:Platform=x64 /p:BuildProjectReferences=false /m /nr:false
} elseif($Component -eq 'Vulkan') {
  & cmake -S $nss -B (Join-Path $nss 'build\release-vk') -A x64 -DFFX_API_BACKEND=vk_windows_x64 -DFFX_BUILD_AS_DLL=ON -DFFX_BUILD_SAMPLES=OFF -DFFX_DEBUG=OFF
  if($LASTEXITCODE -ne 0){throw 'CMake configuration failed'}
  & cmake --build (Join-Path $nss 'build\release-vk') --config Release --target ngsdk_windows_x64
} else {
  if($nss.Contains(' ')){throw 'Use a checkout path without spaces for the inherited DX12 batch build'}
  & (Join-Path $nss 'harness\nfru_dx12\build_ngsdk_dx12.bat')
}
if($LASTEXITCODE -ne 0){throw "Build failed: $LASTEXITCODE"}
