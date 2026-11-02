#pragma once
                                                                                                                       
                                                                                                                   
                                                                                    
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
inline const char* nss_getenv(const char* name)
{
                                                                                              
    static thread_local char ring[8][256];
    static thread_local unsigned next = 0;
    char* buf = ring[next++ & 7u];
    const DWORD n = GetEnvironmentVariableA(name, buf, 256);
    return (n == 0 || n >= 256) ? nullptr : buf;
}
#define getenv nss_getenv

                                                                           
                                                              
inline bool nss_file_logging_enabled()
{
    static const bool enabled = []() {
        HMODULE self = nullptr;
        char path[MAX_PATH] = {};
        if (!GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                               GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                               reinterpret_cast<LPCSTR>(&nss_file_logging_enabled), &self) ||
            !GetModuleFileNameA(self, path, MAX_PATH)) return true;
        char* slash = strrchr(path, '\\');
        if (!slash) return true;
        *slash = 0;
        char ini[MAX_PATH] = {};
        sprintf_s(ini, "%s\\OptiScaler.ini", path);
        if (GetFileAttributesA(ini) == INVALID_FILE_ATTRIBUTES) {
            slash = strrchr(path, '\\');
            if (!slash) return true;
            *slash = 0;
            sprintf_s(ini, "%s\\OptiScaler.ini", path);
        }
        char value[32] = {};
        GetPrivateProfileStringA("Log", "LogToFile", "auto", value, sizeof(value), ini);
        return _stricmp(value, "false") && _stricmp(value, "off") && strcmp(value, "0");
    }();
    return enabled;
}

                                                                                                                                
                                                                                                    
#include <stdio.h>
#include <stdarg.h>
                                                                                                                            
typedef void (*NssTraceSink)(unsigned, const char*);
inline NssTraceSink& nss_trace_sink()
{
    static NssTraceSink s = nullptr;
    return s;
}

inline void nss_trace(const char* fmt, ...)
{
    if (!nss_file_logging_enabled()) return;
                                                                                                                                      
                                                                                                                  
    static long budget = 700;
    static const int on = []() {
        char b[8];
        return (GetEnvironmentVariableA("NSS_TRACE", b, sizeof(b)) || GetEnvironmentVariableA("NSS_PROFILE", b, sizeof(b))) ? 1 : 0;
    }();
    if (!on && budget-- <= 0) return;
    char line[320];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(line, sizeof(line), fmt, ap);
    va_end(ap);
    if (FILE* f = fopen("nss_trace.log", "a"))
    {
        fputs(line, f);
        fputc('\n', f);
        fclose(f);
    }
    if (NssTraceSink sink = nss_trace_sink())
        sink(1, line);
}
#else
inline void nss_trace(const char*, ...) {}
#endif
