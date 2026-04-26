# 编译脚本使用说明

## 📋 功能概述

`compile.sh` 是一个自动化编译脚本，用于将 `/home/sclead/workspace` 目录下的所有 `.sh` 和 `.py` 文件编译成二进制文件，防止代码泄漏。

## 🚀 快速开始

### 1. 安装编译工具

**PyInstaller（Python 编译）：**
```bash
pip3 install pyinstaller
```

**shc（Bash 编译）：**
```bash
sudo apt-get install shc
```

### 2. 运行编译脚本

```bash
cd /home/sclead/workspace
./compile.sh
```

### 3. 测试编译版本

```bash
cd /home/sclead/workspace
./test_compile.sh
```

### 4. 安装编译版本

```bash
cd /home/sclead/workspace/build
sudo ./install.sh
```

## 📝 编译流程

### 步骤1：创建构建目录

脚本会自动创建以下目录结构：
```
/home/sclead/workspace/
├── build/                      # 构建目录
│   ├── install.sh              # 安装脚本
│   ├── README.md               # 编译说明
│   ├── workspace-*            # 编译后的文件
│   └── apps/                   # 应用数据
└── original_backup/            # 原始备份
    └── 20260425_223000/        # 按时间备份
```

### 步骤2：备份原始文件

所有 `.sh` 和 `.py` 文件会自动备份到 `original_backup/YYYYMMDD_HHMMSS/` 目录。

### 步骤3：编译 Python 脚本

**检测 PyInstaller：**
- 如果安装了 PyInstaller，使用 PyInstaller 编译
- 生成独立可执行文件（如 `workspace-config`）

**备用方案：**
- 如果未安装 PyInstaller，使用 Python 字节码编译
- 生成 `.pyc` 文件（如 `workspace-config.pyc`）

### 步骤4：编译 Bash 脚本

**检测 shc：**
- 如果安装了 shc，使用 shc 编译
- 生成二进制可执行文件（如 `workspace-launcher`）

**备用方案：**
- 如果未安装 shc，保持源码形式
- 设置为只读权限（500）

### 步骤5：复制其他文件

以下文件会自动复制到 `build/` 目录：
- `workspace.conf` - 配置文件
- `apps/` - 应用数据目录
- `bin/` - 二进制文件目录

### 步骤6：生成安装脚本

自动生成 `build/install.sh` 脚本，用于安装编译版本。

## 🛠️ 编译工具

### PyInstaller

**优点：**
- 独立可执行文件
- 难以反编译
- 不需要 Python 环境

**缺点：**
- 文件较大
- 编译时间较长

**安装：**
```bash
pip3 install pyinstaller
```

**验证：**
```bash
python3 -c "import PyInstaller; print(PyInstaller.__version__)"
```

### shc

**优点：**
- 编译为 C 代码
- 难以反编译
- 文件较小

**缺点：**
- 不支持所有 Bash 特性

**安装：**
```bash
sudo apt-get install shc
```

**验证：**
```bash
shc -v
```

### Python 字节码

**优点：**
- 编译速度快
- 文件较小

**缺点：**
- 可以被反编译
- 需要 Python 环境

### 只读源码

**优点：**
- 不需要额外工具
- 保持可读性

**缺点：**
- 源码仍然可见
- 安全性低

## 📊 编译结果

### 文件类型对比

| 原始文件 | 编译后 | 方法 | 安全性 | 可读性 |
|---------|--------|------|--------|--------|
| `*.py` | `*` (无后缀) | PyInstaller | 高 | 不可读 |
| `*.py` | `*.pyc` | 字节码 | 中 | 不可读（工具可反编译）|
| `*.sh` | `*` (无后缀) | shc | 高 | 不可读 |
| `*.sh` | `*.sh` | 只读 | 低 | 只读 |

### 文件大小对比

| 文件 | 原始大小 | PyInstaller | 字节码 | shc | 只读 |
|------|---------|-------------|--------|-----|------|
| `workspace-config.py` | ~50KB | ~10MB | ~30KB | - | - |
| `workspace-launcher.sh` | ~16KB | - | - | ~30KB | ~16KB |
| `workspace-app.sh` | ~15KB | - | - | ~30KB | ~15KB |

## 🔍 使用场景

### 场景1：最高安全性

**配置：**
- Python: PyInstaller
- Bash: shc

**适用：**
- 需要保护源代码
- 防止代码泄露
- 增加逆向工程难度

### 场景2：性能优化

**配置：**
- Python: Python 字节码
- Bash: shc

**适用：**
- 文件大小敏感
- 启动速度要求高
- Python 环境可用

### 场景3：快速部署

**配置：**
- Python: Python 字节码
- Bash: 只读源码

**适用：**
- 快速迭代
- 调试方便
- 工具未安装

## ⚠️ 注意事项

### 1. 编译不可逆

- 编译后的文件无法直接修改
- 修改代码需要使用原始备份
- 建议在编译前充分测试

### 2. 依赖性

**PyInstaller：**
- 生成的文件独立运行
- 但依赖系统库（如 libcrypto）
- 需要相同或兼容的操作系统

**shc：**
- 生成的二进制文件
- 需要相同或兼容的系统

### 3. 调试困难

- 编译后的文件难以调试
- 建议保留原始备份用于调试
- 可以使用 `--debug` 参数编译

### 4. 安全性限制

- 没有绝对安全的编译方法
- 有经验的攻击者仍然可能反编译
- 主要目的是增加逆向工程难度

## 🔄 更新和重新编译

### 更新代码后重新编译

```bash
cd /home/sclead/workspace
./compile.sh
```

### 只重新编译特定文件

修改 `compile.sh` 脚本，只编译需要的文件。

### 清理构建缓存

```bash
rm -rf /home/sclead/workspace/build
rm -rf /home/sclead/workspace/__pycache__
rm -rf /home/sclead/workspace/build
```

## 📚 相关文档

| 文档 | 说明 |
|------|------|
| `COMPILE_GUIDE.md` | 详细编译说明 |
| `build/README.md` | 编译版本说明 |
| `QUICK_REF_COMPILE.md` | 编译快速参考 |

## 🆘 故障排查

### 问题1：PyInstaller 未找到

**错误：**
```
ModuleNotFoundError: No module named 'PyInstaller'
```

**解决：**
```bash
pip3 install pyinstaller
```

### 问题2：shc 未找到

**错误：**
```
shc: command not found
```

**解决：**
```bash
sudo apt-get install shc
```

### 问题3：编译后的文件无法运行

**检查：**
```bash
ls -la /home/sclead/workspace/build/

# 设置执行权限
chmod +x /home/sclead/workspace/build/*

# 测试运行
cd /home/sclead/workspace/build
./workspace-launcher help
```

### 问题4：安装失败

**错误：**
```
Permission denied
```

**解决：**
```bash
sudo ./install.sh
```

## 📋 检查清单

编译前检查：
- [ ] 已安装 PyInstaller
- [ ] 已安装 shc（可选）
- [ ] 原始版本测试通过
- [ ] 备份原始文件

编译后检查：
- [ ] 测试编译版本
- [ ] 检查文件权限
- [ ] 验证功能正常
- [ ] 保留原始备份

安装前检查：
- [ ] 备份当前版本
- [ ] 确认编译版本测试通过
- [ ] 准备回滚方案

---

**脚本：** `/home/sclead/workspace/compile.sh`  
**文档：** `COMPILE_GUIDE.md` | `QUICK_REF_COMPILE.md`
