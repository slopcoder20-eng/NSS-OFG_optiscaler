@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul
cd /d E:\nss_VK\NSS\mlof2_engine\harness
cl /nologo /O2 /EHsc /std:c++17 wmma_util.cpp /Fe:wmma_util.exe
