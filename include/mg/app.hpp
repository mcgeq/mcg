#pragma once

#include <expected>
#include <mg/core/error.hpp>

#include <span>
#include <string_view>

namespace mg
{
[[nodiscard]] auto run(std::span<const std::string_view> args)
    -> std::expected<void, MgError>;
}  // namespace mg
