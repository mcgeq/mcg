import mg;

#include <exception>
#include <iostream>

namespace
{
auto run() -> int
{
  std::cout << mg::project_name() << ' ' << mg::project_version() << '\n';
  return 0;
}
} // namespace

auto main() noexcept(false) -> int
{
  try {
    return run();
  } catch (const std::exception& ex) {
    std::cerr << ex.what() << '\n';
  } catch (...) {
    std::cerr << "unknown error\n";
  }

  return 1;
}
