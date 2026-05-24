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
[[nodiscard]] bool runtime_initialized() noexcept;
[[nodiscard]] Runtime& current_runtime();
[[nodiscard]] std::optional<std::filesystem::path> get_fs_cwd();
[[nodiscard]] std::optional<std::filesystem::path> swap_fs_cwd(
    std::optional<std::filesystem::path> path);
void write_stdout(std::string_view bytes);
void write_stderr(std::string_view bytes);
}  // namespace mg
