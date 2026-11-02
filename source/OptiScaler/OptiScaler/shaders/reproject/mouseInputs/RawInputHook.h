#pragma once
#include <windows.h>
#include <detours/detours.h>
#include <thread>
#include <atomic>
#include <chrono>
#include <mutex>
#include <iostream>
#include <map>
#include <vector>

                                                        
typedef decltype(&GetRawInputData) PFN_GetRawInputData;
typedef decltype(&RegisterRawInputDevices) PFN_RegisterRawInputDevices;

class RawInputHook
{
  private:
    std::thread pollThread;
    std::atomic<bool> isRunning = false;
    HWND hiddenWindow = nullptr;

                                                            
    std::mutex dataMutex;
    std::map<HRAWINPUT, RAWMOUSE> fakeMouseDataMap;                                        
    std::atomic<uint64_t> nextFakeHandle { 0x10000 };

                                                                                                               
                                                                                                                 
                                                                                            
    HRAWINPUT unreadHandle = nullptr;
    ULONGLONG unreadPostedMs = 0;

    HWND gameWindow = nullptr;

                                                                                                                   
                                                                                                                     
    std::atomic<bool> gameMouseRegistered = false;
    std::atomic<DWORD> gameMouseFlags = 0;

    static constexpr UINT WM_UPDATE_REGISTRATION = WM_APP + 1;

    static inline PFN_GetRawInputData o_GetRawInputData = GetRawInputData;
    static inline PFN_RegisterRawInputDevices o_RegisterRawInputDevices = RegisterRawInputDevices;

                                                        
    static inline RawInputHook* instance = nullptr;

  public:
    static RawInputHook& getInstance()
    {
        if (!instance)
            instance = new RawInputHook();

        return *instance;
    }

    void start()
    {
        if (isRunning)
            return;
        isRunning = true;

        ReadGameRegistration();

                                
        DetourRestoreAfterWith();
        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());

        DetourAttach(&(PVOID&) o_GetRawInputData, hkGetRawInputData);
        DetourAttach(&(PVOID&) o_RegisterRawInputDevices, hkRegisterRawInputDevices);

        DetourTransactionCommit();

                                                       
        pollThread = std::thread(&RawInputHook::PollingThreadLoop, this);
    }

    void stop()
    {
        if (!isRunning)
            return;
        isRunning = false;

        if (hiddenWindow)
        {
            PostMessage(hiddenWindow, WM_CLOSE, 0, 0);
        }

        if (pollThread.joinable())
        {
            pollThread.join();
        }

        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());

        DetourDetach(&(PVOID&) o_GetRawInputData, hkGetRawInputData);
        DetourDetach(&(PVOID&) o_RegisterRawInputDevices, hkRegisterRawInputDevices);

        DetourTransactionCommit();

        RestoreGameRegistration();
    }

  private:
    HWND FindGameWindow();
    void PollingThreadLoop();
    void ReadGameRegistration();
    void RegisterHiddenWindow();
    void RestoreGameRegistration();
    bool ShouldDeliverToGame(bool& foreground);

    static LRESULT CALLBACK HiddenWndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp);

    static BOOL WINAPI hkRegisterRawInputDevices(PCRAWINPUTDEVICE pRawInputDevices, UINT uiNumDevices, UINT cbSize);
    static UINT WINAPI hkGetRawInputData(HRAWINPUT hRawInput, UINT uiCommand, LPVOID pData, PUINT pcbSize,
                                         UINT cbSizeHeader);
};
