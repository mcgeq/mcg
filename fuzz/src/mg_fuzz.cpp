#include <cstddef>
#include <cstdint>
#include <string_view>

#include <mg/core/project_info.hpp>
#include <mg/core/types.hpp>
#include <mg/pkgm/registry.hpp>

extern "C" auto LLVMFuzzerTestOneInput(const std::uint8_t* data,
                                       std::size_t size) -> int
{
  const auto bytes = std::string_view {
      reinterpret_cast<const char*>(data),
      size,
  };

  (void)mg::parse_manager_type(bytes);

  if (bytes == mg::project_name()) {
    (void)mg::pkgm::action_requires_packages(bytes);
  }

  return 0;
}
