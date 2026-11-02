#pragma once
#include <thread>
#include <mutex>
#include <queue>
#include <condition_variable>
#include <future>
#include <functional>
#include <objbase.h>
class NfruPresentationController {
    std::mutex mutex;
    std::condition_variable cv;
    std::queue<std::function<void()>> tasks;
    bool stop=false;
    std::thread worker;
public:
    NfruPresentationController():worker([this]{
        HRESULT com=CoInitializeEx(nullptr,COINIT_MULTITHREADED);
        for(;;){std::function<void()> task;{std::unique_lock lock(mutex);cv.wait(lock,[&]{return stop||!tasks.empty();});if(stop&&tasks.empty())break;task=std::move(tasks.front());tasks.pop();}task();}
        if(SUCCEEDED(com))CoUninitialize();
    }){}
    ~NfruPresentationController(){{std::lock_guard lock(mutex);stop=true;}cv.notify_all();if(worker.joinable())worker.join();}
    template<class F> void Run(F&& f){
        auto task=std::make_shared<std::packaged_task<void()>>(std::forward<F>(f));auto future=task->get_future();
        {std::lock_guard lock(mutex);tasks.push([task]{(*task)();});}cv.notify_one();future.get();
    }
};
