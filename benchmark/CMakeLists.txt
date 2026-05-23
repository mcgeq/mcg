find_package(benchmark CONFIG REQUIRED)

add_executable("${mg_benchmark_target}" "${mg_benchmark_source}")
target_link_libraries(
    "${mg_benchmark_target}" PRIVATE
    "${mg_main_target}"
    benchmark::benchmark
    benchmark::benchmark_main
)
target_compile_features("${mg_benchmark_target}" PRIVATE cxx_std_23)
mg_apply_options("${mg_benchmark_target}")

if(mg_enable_clang_tidy AND mg_clang_tidy_profile STREQUAL "strict")
  mg_set_target_clang_tidy(
      "${mg_benchmark_target}"
      PROFILE recommended
      WARNINGS_AS_ERRORS OFF
  )
endif()

add_custom_target(
    run-benchmarks
    COMMAND
    "${CMAKE_COMMAND}" -E chdir "$<TARGET_FILE_DIR:${mg_benchmark_target}>"
    "$<TARGET_FILE:${mg_benchmark_target}>" --benchmark_min_time=0.01
    DEPENDS "${mg_benchmark_target}"
    VERBATIM
)

add_folders(Benchmark)
