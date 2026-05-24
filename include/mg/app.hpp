#pragma once

#include <expected>
#include <span>
#include <string_view>

#include <mg/core/error.hpp>

namespace mg
{
[[nodiscard]] std::expected<void, MgError> run(
    std::span<const std::string_view> args);
}  // namespace mg
