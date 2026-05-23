#pragma once

#include <mg/core/types.hpp>

#include <span>
#include <string_view>

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

[[nodiscard]] auto parse_options(std::span<const std::string_view> args) noexcept
    -> Options;
[[nodiscard]] auto parse(std::span<const std::string_view> args) -> ParseResult;
}  // namespace mg::cli
