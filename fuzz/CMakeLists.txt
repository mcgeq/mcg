if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  message(
      STATUS
      "Skipping fuzz target because libFuzzer entrypoints are only wired for Clang."
  )
  return()
endif()

add_executable("${mg_fuzz_target}" "${mg_fuzz_source}")
target_link_libraries("${mg_fuzz_target}" PRIVATE "${mg_main_target}")
target_compile_features("${mg_fuzz_target}" PRIVATE cxx_std_23)
mg_apply_options("${mg_fuzz_target}")

if(WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  target_compile_definitions(
      "${mg_fuzz_target}"
      PRIVATE
      _DISABLE_STRING_ANNOTATION
      _DISABLE_VECTOR_ANNOTATION
  )

  execute_process(
      COMMAND
      "${CMAKE_CXX_COMPILER}" --print-file-name=clang_rt.asan_dynamic-x86_64.dll
      OUTPUT_VARIABLE mg_asan_runtime_dll
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_QUIET
  )
  if(EXISTS "${mg_asan_runtime_dll}")
    add_custom_command(
        TARGET "${mg_fuzz_target}"
        POST_BUILD
        COMMAND
        "${CMAKE_COMMAND}" -E copy_if_different
        "${mg_asan_runtime_dll}"
        "$<TARGET_FILE_DIR:${mg_fuzz_target}>"
        VERBATIM
    )
  endif()
endif()

target_compile_options(
    "${mg_fuzz_target}"
    PRIVATE
    -fsanitize=fuzzer,address,undefined
)
target_link_options(
    "${mg_fuzz_target}"
    PRIVATE
    -fsanitize=fuzzer,address,undefined
)

if(mg_enable_clang_tidy)
  mg_set_target_clang_tidy(
      "${mg_fuzz_target}"
      PROFILE recommended
      WARNINGS_AS_ERRORS OFF
  )
endif()

add_custom_target(
    run-fuzz-smoke
    COMMAND
    "${CMAKE_COMMAND}" -E chdir "$<TARGET_FILE_DIR:${mg_fuzz_target}>"
    "$<TARGET_FILE:${mg_fuzz_target}>" -max_total_time=3
    DEPENDS "${mg_fuzz_target}"
    VERBATIM
)

add_folders(Fuzz)
