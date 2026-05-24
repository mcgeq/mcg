import mg;

#include <exception>
#include <iostream>

namespace
{
int run()
{
  std::cout << mg::project_name() << ' ' << mg::project_version() << '\n';
  return 0;
}
}  // namespace

int main() noexcept(false)
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
