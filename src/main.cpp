#include <mg/mg.hpp>

#include <iostream>
#include <string_view>
#include <vector>

namespace
{
auto run_cli(int argc, char** argv) -> int
{
  auto args = std::vector<std::string_view> {};
  args.reserve(static_cast<std::size_t>(argc));
  for (auto index = 0; index < argc; ++index) {
    args.emplace_back(argv[index]);
  }

  mg::set_runtime({
      .out = &std::cout,
      .err = &std::cerr,
  });

  auto result = mg::run(args);
  if (!result) {
    return mg::is_user_facing_error(result.error()) ? 1 : 2;
  }
  return 0;
}
} // namespace

auto main(int argc, char** argv) noexcept(false) -> int
{
  try {
    return run_cli(argc, argv);
  } catch (const std::exception& ex) {
    std::cerr << ex.what() << '\n';
  } catch (...) {
    std::cerr << "unknown error\n";
  }

  return 1;
}
