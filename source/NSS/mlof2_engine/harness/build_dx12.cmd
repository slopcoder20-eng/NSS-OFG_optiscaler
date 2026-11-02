@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b %errorlevel%
cd /d "%~dp0"
cl /nologo /EHsc /std:c++17 /O2 mlof2_dx12_harness.cpp /Fe:mlof2_dx12_harness.exe
exit /b %errorlevel%
