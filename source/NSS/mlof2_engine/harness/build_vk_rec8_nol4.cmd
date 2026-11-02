@echo off
setlocal enabledelayedexpansion

:: 1. Locate Visual Studio vcvars64.bat
if not defined VSCMD_VER (
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    if exist "!VSWHERE!" (
        for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -latest -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
            if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
                call "%%i\VC\Auxiliary\Build\vcvars64.bat" >nul
            )
        )
    )
    if not defined VSCMD_VER (
        if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
            call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
        )
    )
)

:: 2. Locate Vulkan SDK
set "VK_SDK=%VULKAN_SDK%"
if not exist "%VK_SDK%\Include" (
    if exist "C:\VulkanSDK\1.4.357.0\Include" (
        set "VK_SDK=C:\VulkanSDK\1.4.357.0"
    ) else (
        for /d %%v in (C:\VulkanSDK\*) do (
            if exist "%%v\Include" set "VK_SDK=%%v"
        )
    )
)

cd /d "%~dp0"
echo [build_vk] Using Vulkan SDK: %VK_SDK%
cl /nologo /EHsc /std:c++17 /O2 /DMLOF2_EXPERIMENT /DMLOF2_OF_GEN_DIR=generated_rec8_nol4_v2_int8 /I"E:\nss_VK\Vulkan-Headers\include" /I"%VK_SDK%\Include" mlof2_vk_harness.cpp /Fe:mlof2_vk_harness_rec8_nol4.exe /link /LIBPATH:"%VK_SDK%\Lib" vulkan-1.lib
exit /b %errorlevel%
