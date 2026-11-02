@echo off
rem NFRU DX12: build ngsdk_dx12_windows_x64.dll (ffx-api + frame interpolation / optical flow components + DX12 backend).
rem usage: build_ngsdk_dx12.bat [compile-only file.cpp]
setlocal
if defined VSCMD_VER goto toolchain_ready
for /f "usebackq delims=" %%I in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do call "%%I\VC\Auxiliary\Build\vcvars64.bat" >nul
where cl >nul 2>nul
if errorlevel 1 exit /b 1
:toolchain_ready
for %%I in ("%~dp0..\..") do set "N=%%~fI"
set "O=%N%\harness\nfru_dx12\build"
if not exist "%O%" mkdir "%O%"
set "DEFS=/DWIN32 /D_WINDOWS /DNDEBUG /DFFX_FI /DFFX_OF /DFFX_PLATFORM_WINDOWS=1 /DFFXDLL_VERSION_MAJOR=1 /DFFXDLL_VERSION_MINOR=0 /DFFXDLL_VERSION_PATCH=0 /DCI_PIPELINE_ID=0 /DFFXDLL_VERSION_API=DX12 /DFFX_BACKEND_DX12 /DFFX_BUILD_AS_DLL /D_UNICODE /DUNICODE /DNOMINMAX /D_CRT_SECURE_NO_WARNINGS"
set "INC=/I%N%\sdk\include /I%N%\build\Release\Release\ffx_graphs /I%N%\sdk\libs /I%N%\harness\nfru_dx12\shaders\dx12_headers /I%N%\sdk\src\components /I%N%\sdk\src\shared /I%N%\sdk\src\backends\shared /I%N%\ffx-api\include /I%N%\ffx-api\src"
set "CF=/nologo /c /O2 /MT /EHsc /std:c++20 /permissive- /Zc:__cplusplus /utf-8 /Zi /W3 /wd4005 /wd4244 /wd4267 %DEFS% %INC%"
if not "%~1"=="" (
  cl %CF% /Fo"%O%\\" "%~1"
  exit /b %errorlevel%
)
set SRCS=%N%\sdk\src\backends\dx12\ffx_dx12.cpp %N%\sdk\src\backends\dx12\ffx_dx12_nfru_blobs.cpp %N%\sdk\src\backends\dx12\ffx_dx12_fsr3of_stubs.cpp %N%\sdk\src\shared\ffx_assert.cpp %N%\sdk\src\shared\ffx_util.cpp %N%\sdk\src\shared\ffx_object_management.cpp %N%\sdk\src\components\frameinterpolation\ffx_frameinterpolation.cpp %N%\sdk\src\components\opticalflow\ffx_opticalflow.cpp %N%\ffx-api\src\backends.cpp %N%\ffx-api\src\ffx_api.cpp %N%\ffx-api\src\ffx_provider.cpp %N%\ffx-api\src\validation.cpp %N%\ffx-api\src\ffx_provider_framegeneration.cpp
cl %CF% /Fd"%O%\vc.pdb" /Fo"%O%\\" %SRCS%
if errorlevel 1 exit /b 1
link /nologo /DLL /DEBUG /OPT:REF /OPT:ICF /OUT:"%O%\ngsdk_dx12_windows_x64.dll" "%O%\*.obj" d3d12.lib dxgi.lib dxguid.lib user32.lib
exit /b %errorlevel%
