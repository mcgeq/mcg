#include <mg/pkgm/executor.hpp>
#include <benchmark/benchmark.h>

#include <optional>
#include <string>
#include <vector>

static void bm_format_command_preview(benchmark::State& state)
{
  const auto argv = std::vector<std::string> {"uv", "sync", "--frozen"};
  for (auto _ : state) {
    benchmark::DoNotOptimize(mg::pkgm::format_command_preview(argv, std::nullopt));
  }
}

BENCHMARK(bm_format_command_preview);
