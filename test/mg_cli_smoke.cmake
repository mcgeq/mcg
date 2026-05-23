if(NOT DEFINED MG_EXE)
  message(FATAL_ERROR "MG_EXE is required")
endif()

if(NOT DEFINED SMOKE_ROOT)
  set(SMOKE_ROOT "${CMAKE_CURRENT_BINARY_DIR}/mg-cli-smoke")
endif()

function(run_mg_smoke name expected)
  execute_process(
      COMMAND "${MG_EXE}" ${ARGN}
      RESULT_VARIABLE result
      OUTPUT_VARIABLE stdout
      ERROR_VARIABLE stderr
  )

  if(NOT result EQUAL 0)
    message(
        FATAL_ERROR
        "Smoke scenario '${name}' failed with exit code ${result}\n"
        "stdout:\n${stdout}\n"
        "stderr:\n${stderr}"
    )
  endif()

  set(combined "${stdout}\n${stderr}")
  string(FIND "${combined}" "${expected}" found)
  if(found EQUAL -1)
    message(
        FATAL_ERROR
        "Smoke scenario '${name}' did not contain expected text '${expected}'\n"
        "stdout:\n${stdout}\n"
        "stderr:\n${stderr}"
    )
  endif()
endfunction()

function(write_smoke_file path content)
  get_filename_component(parent "${path}" DIRECTORY)
  file(MAKE_DIRECTORY "${parent}")
  file(WRITE "${path}" "${content}")
endfunction()

file(REMOVE_RECURSE "${SMOKE_ROOT}")

set(cargo_dir "${SMOKE_ROOT}/cargo")
write_smoke_file(
    "${cargo_dir}/Cargo.toml"
    "[package]\nname = \"mg-smoke-cargo\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"
)
run_mg_smoke(
    cargo_run
    "cargo run smoke"
    --dry-run
    --cwd "${cargo_dir}"
    run smoke
)
run_mg_smoke(
    cargo_exec_check
    "cargo check"
    --dry-run
    --cwd "${cargo_dir}"
    exec
    --
    check
)
run_mg_smoke(
    cargo_exec_metadata
    "cargo metadata --no-deps"
    --dry-run
    --cwd "${cargo_dir}"
    exec
    --
    metadata
    --no-deps
)

set(npm_dir "${SMOKE_ROOT}/npm")
file(MAKE_DIRECTORY "${npm_dir}")
file(
    WRITE
    "${npm_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-npm\",\n  \"version\": \"1.0.0\"\n}\n"
)
run_mg_smoke(
    npm_install
    "npm install"
    --dry-run
    --cwd "${npm_dir}"
    install
)
write_smoke_file("${npm_dir}/package-lock.json" "{\n  \"name\": \"mg-smoke-npm\"\n}\n")
run_mg_smoke(
    npm_run
    "npm run smoke"
    --dry-run
    --cwd "${npm_dir}"
    run smoke
)
run_mg_smoke(
    npm_exec_list
    "npm list"
    --dry-run
    --cwd "${npm_dir}"
    exec
    --
    list
)
run_mg_smoke(
    npm_exec_node
    "npm exec -- node smoke.js"
    --dry-run
    --cwd "${npm_dir}"
    exec
    --
    exec
    --
    node
    smoke.js
)

set(pnpm_dir "${SMOKE_ROOT}/pnpm")
write_smoke_file(
    "${pnpm_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-pnpm\",\n  \"packageManager\": \"pnpm@9.12.0\"\n}\n"
)
run_mg_smoke(
    pnpm_package_manager_install
    "pnpm install"
    --dry-run
    --cwd "${pnpm_dir}"
    install
)
run_mg_smoke(
    pnpm_exec_node
    "pnpm exec node smoke.js"
    --dry-run
    --cwd "${pnpm_dir}"
    exec
    --
    exec
    node
    smoke.js
)

set(workspace_dir "${SMOKE_ROOT}/workspace")
set(child_dir "${workspace_dir}/packages/app")
file(MAKE_DIRECTORY "${child_dir}")
file(
    WRITE
    "${workspace_dir}/package.json"
    "{\n"
    "  \"name\": \"mg-smoke-workspace\",\n"
    "  \"packageManager\": \"pnpm@9.12.0\"\n"
    "}\n"
)
file(
    WRITE
    "${child_dir}/package.json"
    "{\n"
    "  \"name\": \"mg-smoke-app\",\n"
    "  \"scripts\": {\n"
    "    \"build\": \"node build.js\"\n"
    "  }\n"
    "}\n"
)
run_mg_smoke(
    pnpm_workspace_run
    "pnpm run build"
    --dry-run
    --cwd "${child_dir}"
    run build
)
run_mg_smoke(
    pnpm_workspace_child_install
    "pnpm install"
    --dry-run
    --cwd "${child_dir}"
    install
)

set(cargo_parent_dir "${SMOKE_ROOT}/cargo-parent")
set(npm_child_dir "${cargo_parent_dir}/apps/web")
write_smoke_file(
    "${cargo_parent_dir}/Cargo.toml"
    "[package]\nname = \"mg-smoke-cargo-parent\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"
)
write_smoke_file(
    "${npm_child_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-web\",\n  \"version\": \"1.0.0\"\n}\n"
)
run_mg_smoke(
    npm_child_over_cargo_install
    "npm install"
    --dry-run
    --cwd "${npm_child_dir}"
    install
)

set(bun_dir "${SMOKE_ROOT}/bun")
write_smoke_file(
    "${bun_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-bun\",\n  \"scripts\": {\"smoke\": \"bun smoke.js\"}\n}\n"
)
write_smoke_file("${bun_dir}/bun.lock" "lockfileVersion 1\n")
run_mg_smoke(
    bun_run
    "bun run smoke"
    --dry-run
    --cwd "${bun_dir}"
    run smoke
)
run_mg_smoke(
    bun_exec_test
    "bun test"
    --dry-run
    --cwd "${bun_dir}"
    exec
    --
    test
)

set(yarn_dir "${SMOKE_ROOT}/yarn")
write_smoke_file(
    "${yarn_dir}/package.json"
    "{\n  \"name\": \"mg-smoke-yarn\",\n  \"scripts\": {\"smoke\": \"node smoke.js\"}\n}\n"
)
write_smoke_file("${yarn_dir}/yarn.lock" "__metadata:\n  version: 8\n")
run_mg_smoke(
    yarn_run
    "yarn run smoke"
    --dry-run
    --cwd "${yarn_dir}"
    run smoke
)
run_mg_smoke(
    yarn_exec_list
    "yarn list"
    --dry-run
    --cwd "${yarn_dir}"
    exec
    --
    list
)

set(uv_dir "${SMOKE_ROOT}/uv")
file(MAKE_DIRECTORY "${uv_dir}")
file(
    WRITE
    "${uv_dir}/pyproject.toml"
    "[project]\n"
    "name = \"mg-smoke-uv\"\n"
    "version = \"0.1.0\"\n"
    "\n"
    "[tool.uv]\n"
    "package = true\n"
)
run_mg_smoke(
    uv_group_install
    "uv sync --group docs --frozen"
    --dry-run
    --cwd "${uv_dir}"
    install
    --profile docs
    --
    --frozen
)
run_mg_smoke(
    uv_run
    "uv run python -c"
    --dry-run
    --cwd "${uv_dir}"
    run
    python
    --
    -c
    "print('mg-smoke-uv')"
)
run_mg_smoke(
    uv_exec_lock
    "uv lock"
    --dry-run
    --cwd "${uv_dir}"
    exec
    --
    lock
)
run_mg_smoke(
    uv_install_profiles
    "uv sync --group dev --group docs --group lint"
    --dry-run
    --cwd "${uv_dir}"
    install
    --dev
    --profile docs
    --profile lint
)

set(pip_dir "${SMOKE_ROOT}/pip")
write_smoke_file("${pip_dir}/requirements.txt" "requests==2.32.0\n")
run_mg_smoke(
    pip_exec_version
    "pip --version"
    --dry-run
    --cwd "${pip_dir}"
    exec
    --
    --version
)

set(poetry_dir "${SMOKE_ROOT}/poetry")
write_smoke_file(
    "${poetry_dir}/pyproject.toml"
    "[tool.poetry]\nname = \"mg-smoke-poetry\"\nversion = \"0.1.0\"\ndescription = \"\"\nauthors = [\"dev <dev@example.com>\"]\n"
)
run_mg_smoke(
    poetry_run
    "poetry run python smoke.py"
    --dry-run
    --cwd "${poetry_dir}"
    run python smoke.py
)
run_mg_smoke(
    poetry_install_profiles
    "poetry install --with dev --with docs --with lint"
    --dry-run
    --cwd "${poetry_dir}"
    install
    --dev
    --profile docs
    --profile lint
)

set(pdm_dir "${SMOKE_ROOT}/pdm")
write_smoke_file(
    "${pdm_dir}/pyproject.toml"
    "[project]\nname = \"mg-smoke-pdm\"\nversion = \"0.1.0\"\n\n[tool.pdm]\ndistribution = true\n"
)
run_mg_smoke(
    pdm_run
    "pdm run python smoke.py"
    --dry-run
    --cwd "${pdm_dir}"
    run python smoke.py
)
run_mg_smoke(
    pdm_exec_script_shortcut
    "pdm smoke"
    --dry-run
    --cwd "${pdm_dir}"
    exec
    --
    smoke
)
run_mg_smoke(
    pdm_list_profiles
    "pdm list --dev --group docs --group lint"
    --dry-run
    --cwd "${pdm_dir}"
    list
    --dev
    --profile docs
    --profile lint
)

set(fs_dir "${SMOKE_ROOT}/fs")
file(MAKE_DIRECTORY "${fs_dir}/src/nested")
file(WRITE "${fs_dir}/src/app.cpp" "int main() {}\n")
file(WRITE "${fs_dir}/src/nested/app.cpp" "int main() {}\n")
run_mg_smoke(
    fs_recursive_list
    "nested/app.cpp"
    --cwd "${fs_dir}"
    fs
    list
    "src/**/*.cpp"
)
