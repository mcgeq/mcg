# mg - 多功能包管理 CLI 工具

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Zig](https://img.shields.io/badge/zig-0.15.1-yellow.svg)](https://ziglang.org/)

一款基于 **Zig** 编写的跨生态系统包管理工具，无需第三方依赖。支持 **cargo**、**npm**、**pnpm**、**yarn**、**bun**、**pip**、**pdm** 和 **poetry**。

## 功能特性

- **零依赖**: 基于纯 Zig 标准库构建
- **彩色输出**: 错误/警告/信息使用 ANSI 颜色编码
- **通配符支持**: `*` 和 `?` 模式匹配
- **智能检测**: 文件/目录存在性检查
- **自动检测**: 自动识别项目类型
- **文件操作**: 内置 `fs` 命令，支持预览模式

## 日志格式

```
[17:53:31] INFO Created file: test.txt
[17:53:31] ERROR Path not found: test.txt
[17:53:31] DEBUG [dry-run] Remove: old.txt
```

- **时间戳**: `[HH:MM:SS]` (本地时间)
- **颜色编码**: ERROR(红色), INFO(绿色), WARN(黄色), DEBUG(青色)
- **预览模式**: `[dry-run]` 前缀用于预览操作

## 快速开始

```bash
# 从源码构建
git clone https://github.com/mcgeq/mg.git
cd mg
zig build

# 添加到 PATH (Windows)
set PATH=.\mg\zig-out\bin;%PATH%

# 或者创建别名
alias mg='.\mg\zig-out\bin\mg.exe'

# 使用 mg
mg add lodash          # 添加包
mg remove lodash       # 移除包
mg upgrade             # 升级所有包
mg fs create src/      # 创建目录
mg fs copy a.txt b.txt # 复制文件
```

## 使用方法

### 包管理命令

```bash
mg add <package>       # 添加包
mg remove <package>    # 移除包
mg upgrade             # 升级所有包
mg install             # 安装依赖
mg analyze             # 列出依赖
```

### 文件系统命令

```bash
mg fs create <path>              # 创建文件或目录
mg fs remove <path>             # 移除文件或目录
mg fs copy <src> <dst>          # 复制文件或目录
mg fs move <src> <dst>          # 移动/重命名文件或目录
mg fs list <path>               # 列出目录内容
mg fs read <path>              # 读取文件内容
mg fs write <path> <content>   # 写入文件
mg fs exists <path>            # 检查路径是否存在
```

### 简短别名

| 命令 | 别名 |
|------|------|
| `fs create` | `c`, `touch` |
| `fs remove` | `r`, `rm` |
| `fs copy` | `cp`, `y` |
| `fs move` | `mv`, `m` |

### 选项

- `--dry-run`, `-d`: 预览命令而不执行
- `--help`, `-h`: 显示帮助

> **注意**: 通配符模式 (`*`, `?`) 必须在 shell 中使用引号:
> - `mg fs r 'test*.txt'` - 正常工作
> - `mg fs r test*.txt` - 可能会被 shell 展开

## 支持的包管理器

| 包管理器 | 命令 | 检测文件 | 优先级 |
|---------|------|---------|--------|
| Cargo | add, remove, upgrade | Cargo.toml | 0 (最高) |
| pnpm | add, remove, upgrade | pnpm-lock.yaml | 1 |
| Bun | add, remove, upgrade | bun.lock | 2 |
| npm | add, remove, upgrade | package-lock.json | 3 |
| yarn | add, remove, upgrade | yarn.lock | 4 |
| pip | add, remove, upgrade | requirements.txt | 5 |
| Poetry | add, remove, upgrade | pyproject.toml | 6 |
| PDM | add, remove, upgrade | pdm.lock | 7 |

## 示例

### Cargo 项目
```bash
mg add serde -F derive
# 等同于: cargo add serde --features derive

mg remove serde
# 等同于: cargo remove serde
```

### npm 项目
```bash
mg add lodash -D
# 等同于: npm install lodash --save-dev

mg remove lodash
# 等同于: npm uninstall lodash
```

### Python/Poetry
```bash
mg add requests -G dev
# 等同于: poetry add requests --group dev
```

### 通配符示例 (新增)
```bash
# 删除多个匹配的文件
mg fs r 'test*.txt'       # 删除所有 test*.txt 文件
mg fs r '*.log'          # 删除所有 log 文件

# 删除前预览
mg fs r 'old_*.tmp' --dry-run

# 使用模式复制
mg fs y 'src/*.c' backup/  # 复制所有 .c 文件
```

## 文件系统操作

```bash
# 自动检测创建
mg fs c test.txt       # 创建文件
mg fs c src/           # 创建目录 (尾部斜杠)

# 通配符支持 (新增)
mg fs r 'test*.txt'      # 删除 test1.txt, test2.txt 等
mg fs r 'demo_?.txt'   # 删除 demo_a.txt, demo_b.txt (单个字符)
mg fs r '*.log'         # 删除所有 .log 文件
mg fs r 'backup*' --dry-run  # 预览删除

# 智能存在性检查 (新增)
mg fs c existing.txt
# [17:53:31] INFO File already exists: existing.txt

# 递归复制
mg fs y src/ backup/   # 递归复制目录

# 安全删除
mg fs r file.txt       # 删除文件
mg fs r dir/           # 递归删除目录

# 预览模式
mg --dry-run fs remove old/
# [dry-run] Remove: old/
```

## 项目结构

```
mg/
├── build.zig           # Zig 构建配置
├── src/
│   ├── main.zig       # 入口点和 CLI 解析
│   ├── error.zig      # 错误类型
│   ├── logger.zig     # 日志工具
│   ├── types.zig      # 核心类型
│   ├── cache.zig      # 检测缓存
│   ├── config.zig     # 配置
│   ├── fs.zig         # 文件系统核心
│   ├── fs/            # 文件系统命令
│   │   └── commands.zig
│   └── pkgm.zig       # 包管理器接口
│       ├── detect.zig   # 包管理器检测
│       ├── registry.zig # 包管理器注册
│       └── executor.zig # 命令执行
└── README.md
```

## 构建

```bash
# Debug 构建
zig build

# Release 构建
zig build -Doptimize=ReleaseSafe

# 运行测试
zig build test
```

## 为什么选择 Zig?

- **无运行时依赖**: 编译为单个静态二进制文件
- **性能**: 原生级别速度
- **安全性**: 内存安全，无垃圾回收
- **简洁**: 标准库就是你所需要的

## 贡献

1. 添加新的包管理器: 在 `src/pkgm.zig` 中实现
2. 改进错误处理: 更新 `src/error.zig`
3. 添加测试: 添加到现有测试部分

## 许可证

MIT License

---

**基于 Zig 构建** ⚡
