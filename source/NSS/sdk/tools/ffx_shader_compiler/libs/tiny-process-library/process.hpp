#ifndef TINY_PROCESS_LIBRARY_HPP_
#define TINY_PROCESS_LIBRARY_HPP_
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>
#ifndef _WIN32
#include <sys/wait.h>
#endif

namespace TinyProcessLib {
                                                  
struct Config {
                                                                            
  std::size_t buffer_size = 131072;
                                                                                    
                                                                                                        
  bool inherit_file_descriptors = false;

                                                                                             
                                                                                                                   
                                                                                            
  enum class ShowWindow {
    hide = 0,
    show_normal = 1,
    show_minimized = 2,
    maximize = 3,
    show_maximized = 3,
    show_no_activate = 4,
    show = 5,
    minimize = 6,
    show_min_no_active = 7,
    show_na = 8,
    restore = 9,
    show_default = 10,
    force_minimize = 11
  };
                                                        
  ShowWindow show_window{ShowWindow::show_default};
};

                                                      
                                                                              
                                                                                             
                                                                        
class Process {
public:
#ifdef _WIN32
  typedef unsigned long id_type;                   
  typedef void *fd_type;                                
#ifdef UNICODE
  typedef std::wstring string_type;
#else
  typedef std::string string_type;
#endif
#else
  typedef pid_t id_type;
  typedef int fd_type;
  typedef std::string string_type;
#endif
  typedef std::unordered_map<string_type, string_type> environment_type;

private:
  class Data {
  public:
    Data() noexcept;
    id_type id;
#ifdef _WIN32
    void *handle{nullptr};
#endif
    int exit_status{-1};
  };

public:
                                                                   
  Process(const std::vector<string_type> &arguments, const string_type &path = string_type(),
          std::function<void(const char *bytes, size_t n)> read_stdout = nullptr,
          std::function<void(const char *bytes, size_t n)> read_stderr = nullptr,
          bool open_stdin = false,
          const Config &config = {}) noexcept;
                                                                   
  Process(const string_type &command, const string_type &path = string_type(),
          std::function<void(const char *bytes, size_t n)> read_stdout = nullptr,
          std::function<void(const char *bytes, size_t n)> read_stderr = nullptr,
          bool open_stdin = false,
          const Config &config = {}) noexcept;

                                                  
  Process(const std::vector<string_type> &arguments,
          const string_type &path,
          const environment_type &environment,
          std::function<void(const char *bytes, size_t n)> read_stdout = nullptr,
          std::function<void(const char *bytes, size_t n)> read_stderr = nullptr,
          bool open_stdin = false,
          const Config &config = {}) noexcept;
                                                  
  Process(const string_type &command,
          const string_type &path,
          const environment_type &environment,
          std::function<void(const char *bytes, size_t n)> read_stdout = nullptr,
          std::function<void(const char *bytes, size_t n)> read_stderr = nullptr,
          bool open_stdin = false,
          const Config &config = {}) noexcept;                                                 
#ifndef _WIN32
                                                                   
                                          
  Process(const std::function<void()> &function,
          std::function<void(const char *bytes, size_t n)> read_stdout = nullptr,
          std::function<void(const char *bytes, size_t n)> read_stderr = nullptr,
          bool open_stdin = false,
          const Config &config = {}) noexcept;
#endif
  ~Process() noexcept;

                                                
  id_type get_id() const noexcept;
                                                             
  int get_exit_status() noexcept;
                                                                                             
  bool try_get_exit_status(int &exit_status) noexcept;
                     
  bool write(const char *bytes, size_t n);
                                                                             
  bool write(const std::string &str);
                                                                                                                     
  void close_stdin() noexcept;

                                                                          
  void kill(bool force = false) noexcept;
                                                                                                                           
  static void kill(id_type id, bool force = false) noexcept;
#ifndef _WIN32
                                            
  void signal(int signum) noexcept;
#endif

private:
  Data data;
  bool closed;
  std::mutex close_mutex;
  std::function<void(const char *bytes, size_t n)> read_stdout;
  std::function<void(const char *bytes, size_t n)> read_stderr;
#ifndef _WIN32
  std::thread stdout_stderr_thread;
#else
  std::thread stdout_thread, stderr_thread;
#endif
  bool open_stdin;
  std::mutex stdin_mutex;

  Config config;

  std::unique_ptr<fd_type> stdout_fd, stderr_fd, stdin_fd;

  id_type open(const std::vector<string_type> &arguments, const string_type &path, const environment_type *environment = nullptr) noexcept;
  id_type open(const string_type &command, const string_type &path, const environment_type *environment = nullptr) noexcept;
#ifndef _WIN32
  id_type open(const std::function<void()> &function) noexcept;
#endif
  void async_read() noexcept;
  void close_fds() noexcept;
};

}                            

#endif                             
