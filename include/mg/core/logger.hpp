#pragma once

#include <format>
#include <utility>
#include <span>
#include <string>
#include <string_view>

namespace mg
{
enum class LogLevel : unsigned char
{
  trace = 0,
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
  off = 5,
};

class Logger
{
public:
  explicit Logger(LogLevel level = LogLevel::info);

  LogLevel level {LogLevel::info};
  bool enable_ansi {true};

  [[nodiscard]] auto should_log(LogLevel message_level) const noexcept -> bool;
  void log(LogLevel message_level, std::string_view message);
  void info_multi(std::span<const std::string_view> messages);

  template<typename... Args>
  void log_fmt(LogLevel message_level,
               std::format_string<Args...> format,
               Args&&... args)
  {
    if (!should_log(message_level)) {
      return;
    }

    log(message_level, std::format(format, std::forward<Args>(args)...));
  }
};

[[nodiscard]] auto logger() -> Logger&;
[[nodiscard]] auto parse_log_level(std::string_view level) noexcept -> LogLevel;
[[nodiscard]] auto level_name(LogLevel level) noexcept -> std::string_view;
[[nodiscard]] auto trim_trailing_newline(std::string_view message) noexcept
    -> std::string_view;

template<typename... Args>
void log_error(std::format_string<Args...> format, Args&&... args)
{
  logger().log_fmt(LogLevel::error, format, std::forward<Args>(args)...);
}

template<typename... Args>
void log_warn(std::format_string<Args...> format, Args&&... args)
{
  logger().log_fmt(LogLevel::warn, format, std::forward<Args>(args)...);
}

template<typename... Args>
void log_info(std::format_string<Args...> format, Args&&... args)
{
  logger().log_fmt(LogLevel::info, format, std::forward<Args>(args)...);
}

template<typename... Args>
void log_debug(std::format_string<Args...> format, Args&&... args)
{
  logger().log_fmt(LogLevel::debug, format, std::forward<Args>(args)...);
}
}  // namespace mg
