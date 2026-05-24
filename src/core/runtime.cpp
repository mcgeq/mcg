#include <iostream>
#include <stdexcept>

#include <mg/core/runtime.hpp>

namespace mg
{
namespace
{
auto global_runtime = std::optional<Runtime> {};

[[nodiscard]] std::ostream& stream_for(OutputTarget target)
{
  auto& runtime = current_runtime();
  if (target == OutputTarget::stdout_stream) {
    return runtime.out == nullptr ? std::cout : *runtime.out;
  }

  return runtime.err == nullptr ? std::cerr : *runtime.err;
}

void write_output(OutputTarget target, std::string_view bytes)
{
  if (bytes.empty()) {
    return;
  }

  stream_for(target) << bytes;
  stream_for(target).flush();
}
}  // namespace

void set_runtime(Runtime runtime)
{
  global_runtime = std::move(runtime);
}

bool runtime_initialized() noexcept
{
  return global_runtime.has_value();
}

Runtime& current_runtime()
{
  if (!global_runtime) {
    global_runtime = Runtime {
        .out = &std::cout,
        .err = &std::cerr,
    };
  }

  return *global_runtime;
}

std::optional<std::filesystem::path> get_fs_cwd()
{
  return current_runtime().fs_cwd;
}

std::optional<std::filesystem::path> swap_fs_cwd(
    std::optional<std::filesystem::path> path)
{
  auto& runtime = current_runtime();
  auto previous = runtime.fs_cwd;
  runtime.fs_cwd = std::move(path);
  return previous;
}

void write_stdout(std::string_view bytes)
{
  write_output(OutputTarget::stdout_stream, bytes);
}

void write_stderr(std::string_view bytes)
{
  write_output(OutputTarget::stderr_stream, bytes);
}
}  // namespace mg
