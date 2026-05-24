#include <array>
#include <format>
#include <string>

#include <mg/core/logger.hpp>
#include <mg/core/runtime.hpp>
#include <mg/core/types.hpp>

namespace mg
{
namespace
{
constexpr auto ansi_reset = std::string_view {"\x1b[0m"};
constexpr auto ansi_trace = std::string_view {"\x1b[90m"};
constexpr auto ansi_debug = std::string_view {"\x1b[36m"};
constexpr auto ansi_info = std::string_view {"\x1b[32m"};
constexpr auto ansi_warn = std::string_view {"\x1b[33m"};
constexpr auto ansi_error = std::string_view {"\x1b[31m"};

auto global_logger = Logger {};

[[nodiscard]] std::string_view color_for(LogLevel level) noexcept
{
  switch (level) {
    case LogLevel::trace:
      return ansi_trace;
    case LogLevel::debug:
      return ansi_debug;
    case LogLevel::info:
      return ansi_info;
    case LogLevel::warn:
      return ansi_warn;
    case LogLevel::error:
      return ansi_error;
    case LogLevel::off:
      return "";
  }

  return "";
}
}  // namespace

Logger::Logger(LogLevel level_value)
    : level {level_value}
{
}

bool Logger::should_log(LogLevel message_level) const noexcept
{
  return level != LogLevel::off
      && static_cast<unsigned char>(message_level)
      >= static_cast<unsigned char>(level);
}

void Logger::log(LogLevel message_level, std::string_view message)
{
  if (!should_log(message_level)) {
    return;
  }

  const auto color =
      enable_ansi ? color_for(message_level) : std::string_view {};
  const auto reset = enable_ansi ? ansi_reset : std::string_view {};
  const auto rendered = std::format("{}[{}]{}\n    {}\n",
                                    color,
                                    level_name(message_level),
                                    reset,
                                    trim_trailing_newline(message));

  if (message_level == LogLevel::warn || message_level == LogLevel::error) {
    write_stderr(rendered);
  } else {
    write_stdout(rendered);
  }
}

void Logger::info_multi(std::span<const std::string_view> messages)
{
  if (!should_log(LogLevel::info)) {
    return;
  }

  auto rendered = std::string {};
  const auto color = enable_ansi ? ansi_info : std::string_view {};
  const auto reset = enable_ansi ? ansi_reset : std::string_view {};
  rendered += std::format("{}[INFO]{}\n", color, reset);
  for (const auto message : messages) {
    rendered += std::format("    {}\n", trim_trailing_newline(message));
  }

  write_stdout(rendered);
}

Logger& logger()
{
  return global_logger;
}

LogLevel parse_log_level(std::string_view level) noexcept
{
  if (iequals(level, "trace")) {
    return LogLevel::trace;
  }
  if (iequals(level, "debug")) {
    return LogLevel::debug;
  }
  if (iequals(level, "info")) {
    return LogLevel::info;
  }
  if (iequals(level, "warn")) {
    return LogLevel::warn;
  }
  if (iequals(level, "error")) {
    return LogLevel::error;
  }
  if (iequals(level, "off")) {
    return LogLevel::off;
  }
  return LogLevel::info;
}

std::string_view level_name(LogLevel level) noexcept
{
  switch (level) {
    case LogLevel::trace:
      return "TRACE";
    case LogLevel::debug:
      return "DEBUG";
    case LogLevel::info:
      return "INFO";
    case LogLevel::warn:
      return "WARN";
    case LogLevel::error:
      return "ERROR";
    case LogLevel::off:
      return "";
  }

  return "";
}

std::string_view trim_trailing_newline(std::string_view message) noexcept
{
  if (!message.empty() && message.back() == '\n') {
    message.remove_suffix(1);
  }
  return message;
}
}  // namespace mg
