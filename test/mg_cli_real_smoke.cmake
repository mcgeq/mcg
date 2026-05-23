if(NOT DEFINED MG_EXE)
  message(FATAL_ERROR "MG_EXE is required")
endif()

if(NOT DEFINED REAL_SMOKE_ROOT)
  set(REAL_SMOKE_ROOT "${CMAKE_CURRENT_BINARY_DIR}/mg-cli-real-smoke")
endif()

set(real_smoke_selected 0)
set(real_smoke_passed 0)
set(real_smoke_skipped 0)
set(real_smoke_failed 0)
set(real_smoke_unknown_scenarios "")

if(DEFINED REAL_SMOKE_SCENARIOS)
  string(REPLACE "\\;" ";" REAL_SMOKE_SCENARIOS "${REAL_SMOKE_SCENARIOS}")
endif()

set(real_smoke_generated_path_cargo_exec_check "target")
set(real_smoke_generated_path_uv_exec_sync ".venv")
set(real_smoke_generated_path_uv_exec_lock "uv.lock")

function(register_real_smoke name)
  get_property(real_smoke_known_scenarios GLOBAL PROPERTY REAL_SMOKE_KNOWN_SCENARIOS)
  list(FIND real_smoke_known_scenarios "${name}" index)
  if(index EQUAL -1)
    set_property(GLOBAL APPEND PROPERTY REAL_SMOKE_KNOWN_SCENARIOS "${name}")
  endif()
endfunction()

function(real_smoke_selected name out_var)
  if(NOT DEFINED REAL_SMOKE_SCENARIOS OR REAL_SMOKE_SCENARIOS STREQUAL "")
    set("${out_var}" TRUE PARENT_SCOPE)
    return()
  endif()

  list(FIND REAL_SMOKE_SCENARIOS "${name}" index)
  if(index EQUAL -1)
    set("${out_var}" FALSE PARENT_SCOPE)
  else()
    set("${out_var}" TRUE PARENT_SCOPE)
  endif()
endfunction()

function(validate_real_smoke_filters)
  if(NOT DEFINED REAL_SMOKE_SCENARIOS OR REAL_SMOKE_SCENARIOS STREQUAL "")
    return()
  endif()

  get_property(real_smoke_known_scenarios GLOBAL PROPERTY REAL_SMOKE_KNOWN_SCENARIOS)
  foreach(scenario IN LISTS REAL_SMOKE_SCENARIOS)
    list(FIND real_smoke_known_scenarios "${scenario}" index)
    if(index EQUAL -1)
      list(APPEND real_smoke_unknown_scenarios "${scenario}")
    endif()
  endforeach()

  if(real_smoke_unknown_scenarios)
    message(SEND_ERROR "Unknown real smoke scenario(s): ${real_smoke_unknown_scenarios}")
    message(STATUS "Available real smoke scenarios:")
    foreach(scenario IN LISTS real_smoke_known_scenarios)
      message(STATUS "  - ${scenario}")
    endforeach()
    set(real_smoke_unknown_scenarios "${real_smoke_unknown_scenarios}" PARENT_SCOPE)
  endif()
endfunction()

function(write_smoke_file path content)
  get_filename_component(parent "${path}" DIRECTORY)
  file(MAKE_DIRECTORY "${parent}")
  file(WRITE "${path}" "${content}")
endfunction()

function(skip_real_smoke name manager reason)
  math(EXPR real_smoke_skipped "${real_smoke_skipped} + 1")
  set(real_smoke_skipped "${real_smoke_skipped}" PARENT_SCOPE)
  message(STATUS "[SKIP] ${name}: `${manager}` ${reason}")
endfunction()

function(pass_real_smoke name manager)
  math(EXPR real_smoke_passed "${real_smoke_passed} + 1")
  set(real_smoke_passed "${real_smoke_passed}" PARENT_SCOPE)
  message(STATUS "[PASS] ${name}: manager=${manager}")
endfunction()

function(fail_real_smoke name manager reason stdout stderr)
  math(EXPR real_smoke_failed "${real_smoke_failed} + 1")
  set(real_smoke_failed "${real_smoke_failed}" PARENT_SCOPE)
  message(SEND_ERROR "[FAIL] ${name}: manager=${manager}")
  message(SEND_ERROR "Reason: ${reason}")
  if(NOT "${stdout}" STREQUAL "")
    message(SEND_ERROR "stdout:\n${stdout}")
  endif()
  if(NOT "${stderr}" STREQUAL "")
    message(SEND_ERROR "stderr:\n${stderr}")
  endif()
endfunction()

function(is_known_environment_failure combined out_var)
  string(TOLOWER "${combined}" lower)
  set(patterns
      "python was not found"
      "node: not found"
      "command not found"
      "not recognized as an internal or external command"
      "could not find executable"
      "failed to spawn process: no such file or directory"
      "package manager not found in path"
      "lnk1181"
      "dbghelp.lib"
  )

  foreach(pattern IN LISTS patterns)
    string(FIND "${lower}" "${pattern}" found)
    if(NOT found EQUAL -1)
      set("${out_var}" TRUE PARENT_SCOPE)
      return()
    endif()
  endforeach()

  set("${out_var}" FALSE PARENT_SCOPE)
endfunction()

function(run_real_smoke name manager start_dir expected)
  register_real_smoke("${name}")

  real_smoke_selected("${name}" selected)
  if(NOT selected)
    return()
  endif()

  math(EXPR real_smoke_selected "${real_smoke_selected} + 1")
  set(real_smoke_selected "${real_smoke_selected}" PARENT_SCOPE)

  unset(manager_exe)
  unset(manager_exe CACHE)
  find_program(manager_exe NAMES "${manager}" NO_CACHE)
  if(NOT manager_exe)
    skip_real_smoke("${name}" "${manager}" "not found in PATH")
    set(real_smoke_skipped "${real_smoke_skipped}" PARENT_SCOPE)
    return()
  endif()

  execute_process(
      COMMAND "${MG_EXE}" --cwd "${start_dir}" ${ARGN}
      RESULT_VARIABLE result
      OUTPUT_VARIABLE stdout
      ERROR_VARIABLE stderr
  )

  set(combined "${stdout}\n${stderr}")
  if(NOT result EQUAL 0)
    is_known_environment_failure("${combined}" known_environment_failure)
    if(known_environment_failure)
      skip_real_smoke("${name}" "${manager}" "blocked by local runtime/toolchain")
      set(real_smoke_skipped "${real_smoke_skipped}" PARENT_SCOPE)
      return()
    endif()

    fail_real_smoke(
        "${name}"
        "${manager}"
        "command failed with exit code ${result}"
        "${stdout}"
        "${stderr}"
    )
    set(real_smoke_failed "${real_smoke_failed}" PARENT_SCOPE)
    return()
  endif()

  set(manager_banner "Using ${manager} package manager")
  string(FIND "${combined}" "${manager_banner}" manager_banner_found)
  if(manager_banner_found EQUAL -1)
    fail_real_smoke(
        "${name}"
        "${manager}"
        "missing manager detection banner `${manager_banner}`"
        "${stdout}"
        "${stderr}"
    )
    set(real_smoke_failed "${real_smoke_failed}" PARENT_SCOPE)
    return()
  endif()

  if(NOT "${expected}" STREQUAL "")
    string(FIND "${combined}" "${expected}" found)
    if(found EQUAL -1)
      fail_real_smoke(
          "${name}"
          "${manager}"
          "missing expected text `${expected}`"
          "${stdout}"
          "${stderr}"
      )
      set(real_smoke_failed "${real_smoke_failed}" PARENT_SCOPE)
      return()
    endif()
  endif()

  set(generated_path_var "real_smoke_generated_path_${name}")
  if(DEFINED "${generated_path_var}")
    set(generated_path "${${generated_path_var}}")
    set(generated_full_path "${start_dir}/${generated_path}")
    if(NOT EXISTS "${generated_full_path}")
      fail_real_smoke(
          "${name}"
          "${manager}"
          "missing generated path `${generated_path}`"
          "${stdout}"
          "${stderr}"
      )
      set(real_smoke_failed "${real_smoke_failed}" PARENT_SCOPE)
      return()
    endif()
  endif()

  pass_real_smoke("${name}" "${manager}")
  set(real_smoke_passed "${real_smoke_passed}" PARENT_SCOPE)
endfunction()

file(REMOVE_RECURSE "${REAL_SMOKE_ROOT}")
file(MAKE_DIRECTORY "${REAL_SMOKE_ROOT}")

set(cargo_dir "${REAL_SMOKE_ROOT}/cargo")
write_smoke_file(
    "${cargo_dir}/Cargo.toml"
    "[package]\nname = \"mg-smoke-cargo\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"
)
write_smoke_file(
    "${cargo_dir}/src/main.rs"
    "fn main() {\n    println!(\"mg-smoke-cargo\");\n}\n"
)
write_smoke_file(
    "${cargo_dir}/src/lib.rs"
    "#[cfg(test)]\nmod tests {\n    #[test]\n    fn smoke_test() {\n        println!(\"mg-smoke-cargo-test\");\n        assert_eq!(2 + 2, 4);\n    }\n}\n"
)
run_real_smoke(cargo_run cargo "${cargo_dir}" "mg-smoke-cargo" run smoke)
run_real_smoke(cargo_exec_version cargo "${cargo_dir}" "" exec -- --version)
run_real_smoke(cargo_exec_test cargo "${cargo_dir}" "mg-smoke-cargo-test" exec -- test -- --nocapture)
run_real_smoke(cargo_exec_check cargo "${cargo_dir}" "" exec -- check)
run_real_smoke(cargo_exec_metadata cargo "${cargo_dir}" "mg-smoke-cargo" exec -- metadata --no-deps)

set(npm_dir "${REAL_SMOKE_ROOT}/npm")
write_smoke_file(
    "${npm_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-npm\",\n  \"version\": \"0.0.0\",\n  \"scripts\": {\"smoke\": \"node smoke.js\"}\n}\n"
)
write_smoke_file(
    "${npm_dir}/package-lock.json"
    "{\n  \"name\": \"mg-smoke-npm\",\n  \"lockfileVersion\": 3,\n  \"packages\": {}\n}\n"
)
write_smoke_file("${npm_dir}/smoke.js" "console.log(\"mg-smoke-npm\");\n")
run_real_smoke(npm_run npm "${npm_dir}" "mg-smoke-npm" run smoke)
run_real_smoke(npm_exec_version npm "${npm_dir}" "" exec -- --version)
run_real_smoke(npm_exec_list npm "${npm_dir}" "mg-smoke-npm" exec -- list)
run_real_smoke(npm_exec_run npm "${npm_dir}" "mg-smoke-npm" exec -- run smoke)
run_real_smoke(npm_exec_node npm "${npm_dir}" "mg-smoke-npm" exec -- exec -- node smoke.js)

set(npm_package_json_only_dir "${REAL_SMOKE_ROOT}/npm-package-json-only")
write_smoke_file(
    "${npm_package_json_only_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-npm-fallback\",\n  \"version\": \"0.0.0\"\n}\n"
)
run_real_smoke(
    npm_package_json_install_dry_run
    npm
    "${npm_package_json_only_dir}"
    "npm install"
    --dry-run
    install
)

set(pnpm_dir "${REAL_SMOKE_ROOT}/pnpm")
write_smoke_file(
    "${pnpm_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-pnpm\",\n  \"version\": \"0.0.0\",\n  \"scripts\": {\"smoke\": \"node smoke.js\"}\n}\n"
)
write_smoke_file("${pnpm_dir}/pnpm-lock.yaml" "lockfileVersion: '9.0'\n")
write_smoke_file("${pnpm_dir}/smoke.js" "console.log(\"mg-smoke-pnpm\");\n")
run_real_smoke(pnpm_run pnpm "${pnpm_dir}" "mg-smoke-pnpm" run smoke)
run_real_smoke(pnpm_exec_version pnpm "${pnpm_dir}" "" exec -- --version)
run_real_smoke(pnpm_exec_list pnpm "${pnpm_dir}" "" exec -- list)
run_real_smoke(pnpm_exec_run pnpm "${pnpm_dir}" "mg-smoke-pnpm" exec -- run smoke)
run_real_smoke(pnpm_exec_node pnpm "${pnpm_dir}" "mg-smoke-pnpm" exec -- exec node smoke.js)

set(pnpm_package_manager_dir "${REAL_SMOKE_ROOT}/pnpm-package-manager")
write_smoke_file(
    "${pnpm_package_manager_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-pnpm-package-manager\",\n  \"version\": \"0.0.0\",\n  \"packageManager\": \"pnpm@9.12.0\"\n}\n"
)
run_real_smoke(
    pnpm_package_manager_install_dry_run
    pnpm
    "${pnpm_package_manager_dir}"
    "pnpm install"
    --dry-run
    install
)

set(workspace_dir "${REAL_SMOKE_ROOT}/pnpm-workspace")
set(workspace_child_dir "${workspace_dir}/packages/app")
write_smoke_file(
    "${workspace_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-pnpm-workspace\",\n  \"private\": true,\n  \"packageManager\": \"pnpm@9.12.0\"\n}\n"
)
write_smoke_file(
    "${workspace_child_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-pnpm-workspace-app\",\n  \"version\": \"0.0.0\",\n  \"scripts\": {\"smoke\": \"node smoke.js\"}\n}\n"
)
write_smoke_file(
    "${workspace_child_dir}/smoke.js"
    "console.log(\"mg-smoke-pnpm-workspace-child\");\n"
)
run_real_smoke(
    pnpm_workspace_child_install_dry_run
    pnpm
    "${workspace_child_dir}"
    "pnpm install"
    --dry-run
    install
)
run_real_smoke(
    pnpm_workspace_child_run
    pnpm
    "${workspace_child_dir}"
    "mg-smoke-pnpm-workspace-child"
    run smoke
)

set(cargo_parent_dir "${REAL_SMOKE_ROOT}/cargo-parent")
set(npm_child_dir "${cargo_parent_dir}/apps/web")
write_smoke_file(
    "${cargo_parent_dir}/Cargo.toml"
    "[package]\nname = \"mg-smoke-cargo-root\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"
)
write_smoke_file(
    "${npm_child_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-web\",\n  \"version\": \"0.0.0\"\n}\n"
)
run_real_smoke(
    npm_child_package_over_cargo_root_install_dry_run
    npm
    "${npm_child_dir}"
    "npm install"
    --dry-run
    install
)

set(bun_dir "${REAL_SMOKE_ROOT}/bun")
write_smoke_file(
    "${bun_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-bun\",\n  \"version\": \"0.0.0\",\n  \"scripts\": {\"smoke\": \"bun smoke.js\"}\n}\n"
)
write_smoke_file("${bun_dir}/bun.lock" "lockfileVersion 1\n")
write_smoke_file("${bun_dir}/smoke.js" "console.log(\"mg-smoke-bun\");\n")
write_smoke_file(
    "${bun_dir}/smoke.test.ts"
    "import { expect, test } from \"bun:test\";\n\ntest(\"smoke\", () => {\n    console.log(\"mg-smoke-bun-test\");\n    expect(2 + 2).toBe(4);\n});\n"
)
run_real_smoke(bun_run bun "${bun_dir}" "mg-smoke-bun" run smoke)
run_real_smoke(bun_exec_version bun "${bun_dir}" "" exec -- --version)
run_real_smoke(bun_exec_test bun "${bun_dir}" "mg-smoke-bun-test" exec -- test)
run_real_smoke(bun_exec_run bun "${bun_dir}" "mg-smoke-bun" exec -- run smoke)

set(yarn_dir "${REAL_SMOKE_ROOT}/yarn")
write_smoke_file(
    "${yarn_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-yarn\",\n  \"version\": \"0.0.0\",\n  \"scripts\": {\"smoke\": \"node smoke.js\"}\n}\n"
)
write_smoke_file("${yarn_dir}/yarn.lock" "# yarn lockfile v1\n")
write_smoke_file("${yarn_dir}/smoke.js" "console.log(\"mg-smoke-yarn\");\n")
run_real_smoke(yarn_run yarn "${yarn_dir}" "mg-smoke-yarn" run smoke)
run_real_smoke(yarn_exec_version yarn "${yarn_dir}" "" exec -- --version)
run_real_smoke(yarn_exec_list yarn "${yarn_dir}" "" exec -- list)
run_real_smoke(yarn_exec_run yarn "${yarn_dir}" "mg-smoke-yarn" exec -- run smoke)

set(uv_dir "${REAL_SMOKE_ROOT}/uv")
write_smoke_file(
    "${uv_dir}/pyproject.toml"
    "[project]\nname = \"mg-smoke-uv\"\nversion = \"0.1.0\"\n\n[tool.uv]\npackage = false\n"
)
run_real_smoke(
    uv_run
    uv
    "${uv_dir}"
    "mg-smoke-uv"
    run python -- -c "print('mg-smoke-uv')"
)
run_real_smoke(uv_exec_version uv "${uv_dir}" "" exec -- --version)
run_real_smoke(uv_exec_sync uv "${uv_dir}" "" exec -- sync)
run_real_smoke(uv_exec_tree uv "${uv_dir}" "mg-smoke-uv" exec -- tree)
run_real_smoke(
    uv_exec_run
    uv
    "${uv_dir}"
    "mg-smoke-uv"
    exec -- run python -c "print('mg-smoke-uv')"
)
run_real_smoke(uv_exec_lock uv "${uv_dir}" "" exec -- lock)
run_real_smoke(
    uv_install_profiles_dry_run
    uv
    "${uv_dir}"
    "uv sync --group dev --group docs --group lint"
    --dry-run
    install
    --dev
    --profile
    docs
    --profile
    lint
)

set(pip_dir "${REAL_SMOKE_ROOT}/pip")
write_smoke_file("${pip_dir}/requirements.txt" "requests==2.32.0\n")
run_real_smoke(pip_exec_version pip "${pip_dir}" "" exec -- --version)

set(poetry_dir "${REAL_SMOKE_ROOT}/poetry")
write_smoke_file(
    "${poetry_dir}/pyproject.toml"
    "[tool.poetry]\nname = \"mg-smoke-poetry\"\nversion = \"0.1.0\"\ndescription = \"\"\nauthors = [\"mg <mg@example.com>\"]\n\n[tool.poetry.dependencies]\npython = \">=3.10,<4.0\"\n"
)
write_smoke_file("${poetry_dir}/poetry.lock" "[[package]]\nname = \"demo\"\nversion = \"0.1.0\"\n")
write_smoke_file("${poetry_dir}/smoke.py" "print(\"mg-smoke-poetry\")\n")
run_real_smoke(poetry_exec_version poetry "${poetry_dir}" "" exec -- --version)
run_real_smoke(poetry_exec_check poetry "${poetry_dir}" "" exec -- check)
run_real_smoke(poetry_exec_show poetry "${poetry_dir}" "" exec -- show)
run_real_smoke(
    poetry_exec_run
    poetry
    "${poetry_dir}"
    "mg-smoke-poetry"
    exec -- run python smoke.py
)
run_real_smoke(
    poetry_run
    poetry
    "${poetry_dir}"
    "mg-smoke-poetry"
    run python smoke.py
)
run_real_smoke(
    poetry_install_profiles_dry_run
    poetry
    "${poetry_dir}"
    "poetry install --with dev --with docs --with lint"
    --dry-run
    install
    --dev
    --profile
    docs
    --profile
    lint
)

set(pdm_dir "${REAL_SMOKE_ROOT}/pdm")
write_smoke_file(
    "${pdm_dir}/pyproject.toml"
    "[project]\nname = \"mg-smoke-pdm\"\nversion = \"0.1.0\"\nrequires-python = \">=3.10\"\n\n[tool.pdm]\ndistribution = false\n\n[tool.pdm.scripts]\nsmoke = \"python smoke.py\"\n"
)
write_smoke_file("${pdm_dir}/pdm.lock" "[metadata]\nlock_version = \"4.0\"\n")
write_smoke_file("${pdm_dir}/smoke.py" "print(\"mg-smoke-pdm\")\n")
run_real_smoke(pdm_exec_version pdm "${pdm_dir}" "" exec -- --version)
run_real_smoke(pdm_exec_list pdm "${pdm_dir}" "" exec -- list)
run_real_smoke(pdm_exec_run_list pdm "${pdm_dir}" "smoke" exec -- run --list)
run_real_smoke(pdm_exec_run pdm "${pdm_dir}" "mg-smoke-pdm" exec -- run python smoke.py)
run_real_smoke(pdm_run pdm "${pdm_dir}" "mg-smoke-pdm" run python smoke.py)
run_real_smoke(pdm_exec_script_shortcut pdm "${pdm_dir}" "mg-smoke-pdm" exec -- smoke)
run_real_smoke(
    pdm_list_profiles_dry_run
    pdm
    "${pdm_dir}"
    "pdm list --dev --group docs --group lint"
    --dry-run
    list
    --dev
    --profile
    docs
    --profile
    lint
)

message(
    STATUS
    "Real smoke summary: selected=${real_smoke_selected}, passed=${real_smoke_passed}, skipped=${real_smoke_skipped}, failed=${real_smoke_failed}"
)

validate_real_smoke_filters()

if(real_smoke_unknown_scenarios OR NOT real_smoke_failed EQUAL 0)
  message(FATAL_ERROR "Real smoke scenarios failed")
endif()
