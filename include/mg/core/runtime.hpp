#pragma once

#include <filesystem>
#include <functional>
#include <iosfwd>
#include <optional>
#include <string_view>

namespace mg
{
enum class OutputTarget
{
  stdout_stream,
  stderr_stream,
};

struct Runtime
{
  std::ostream* out {nullptr};
  std::ostream* err {nullptr};
  std::optional<std::filesystem::path> fs_cwd {};
};

void set_runtime(Runtime runtime);
[[nodiscard]] auto runtime_initialized() noexcept -> bool;
[[nodiscard]] auto current_runtime() -> Runtime&;
[[nodiscard]] auto get_fs_cwd() -> std::optional<std::filesystem::path>;
[[nodiscard]] auto swap_fs_cwd(std::optional<std::filesystem::path> path)
    -> std::optional<std::filesystem::path>;
void write_stdout(std::string_view bytes);
void write_stderr(std::string_view bytes);
}  // namespace mg
