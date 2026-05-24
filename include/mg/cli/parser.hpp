#pragma once

#include <span>
#include <string_view>

#include <mg/core/types.hpp>

namespace mg::cli
{
enum class ParseResult
{
  help,
  version,
  fs,
  pkg,
  none,
};

struct Options
{
  bool dry_run {false};
};

[[nodiscard]] Options parse_options(
    std::span<const std::string_view> args) noexcept;
[[nodiscard]] ParseResult parse(std::span<const std::string_view> args);
}  // namespace mg::cli
