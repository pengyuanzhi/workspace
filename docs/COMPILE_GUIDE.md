# 工作区编译说明

## 概述

为了防止代码泄漏，可以将工作区的 `.sh` 和 `.py` 文件编译成二进制文件。

## 编译方法

### 1. Python 脚本编译

#### 方法1：PyInstaller（推荐）

**优点：**
- 独立可执行文件
- 难以反编译
- 不需要 Python 环境
- 安全性高

**安装：**
```bash
pip3 install pyinstaller
```

**编译：**
```bash
cd /home/sclead/workspace
./compile.sh
```

**生成的文件：**
- `workspace-config` - 独立可执行文件
- 无需 `.py` 后缀

#### 方法2：Python 字节码

**优点：**
- 编译速度快
- 文件较小
- 不需要额外工具

**缺点：**
- 可以被反编译
- 需要 Python 环境
- 安全性中等

**编译：**
```bash
cd /home/sclead/workspace
./compile.sh
```

**生成的文件：**
- `workspace-config.pyc` - Python 字节码文件

### 2. Bash 脚本编译

#### 方法1：shc（推荐）

**优点：**
- 编译为 C 代码
- 难以反编译
- 独立可执行文件
- 安全性高

**安装：**
```bash
sudo apt-get install shc
```

**编译：**
```bash
cd /home/sclead/workspace
./compile.sh
```

**生成的文件：**
- `workspace-launcher` - 独立可执行文件（shc 编译）
- `workspace-app` - 独立可执行文件（shc 编译）

#### 方法2：只读源码

**优点：**
- 不需要额外工具
- 保持可读性（但只读）

**缺点：**
- 源码仍然可见
- 安全性低

**编译：**
```bash
cd /home/sclead/workspace
./compile.sh
```

**生成的文件：**
- `workspace-launcher.sh` - 只读源码（权限 500）
- `workspace-app.sh` - 只读源码（权限 500）

## 使用方法

### 1. 编译工作区

```bash
cd /home/sclead/workspace
./compile.sh
```

**编译过程：**
1. 检查编译工具（PyInstaller, shc）
2. 备份原始文件到 `original_backup/YYYYMMDD_HHMMSS/`
3. 编译 Python 脚本
4. 编译 Bash 脚本
5. 复制配置文件和数据目录
6. 生成 `build/` 目录
7. 创建 `install.sh` 安装脚本

### 2. 测试编译版本

```bash
cd /home/sclead/workspace
./test_compile.sh
```

**测试内容：**
1. Python 脚本是否可以运行
2. Bash 脚本是否可以运行
3. 文件权限是否正确
4. 文件完整性检查
5. 文件大小对比

### 3. 安装编译版本

#### 方法1：使用安装脚本（推荐）

```bash
cd /home/sclead/workspace/build
sudo ./install.sh
```

**安装过程：**
1. 备份当前版本
2. 复制编译后的文件到 `/home/sclead/workspace/`
3. 设置正确的权限

#### 方法2：手动安装

```bash
# 备份当前版本
sudo cp -r /home/sclead/workspace /home/sclead/workspace_backup_$(date +%Y%m%d)

# 复制编译后的文件
sudo cp -r /home/sclead/workspace/build/* /home/sclead/workspace/

# 设置权限
sudo chmod +x /home/sclead/workspace/*
```

### 4. 回滚到原始版本

#### 方法1：使用原始备份

```bash
# 查看可用的备份
ls -la /home/sclead/workspace/original_backup/

# 恢复特定备份
sudo cp -r /home/sclead/workspace/original_backup/20260425_XXXXXX/* /home/sclead/workspace/

# 设置权限
sudo chmod +x /home/sclead/workspace/*
```

#### 方法2：使用完整备份

```bash
# 查看可用的备份
ls -la /home/sclead/workspace/workspace_backup_*/

# 恢复特定备份
sudo cp -r /home/sclead/workspace/workspace_backup_YYYYMMDD/* /home/sclead/workspace/

# 设置权限
sudo chmod +x /home/sclead/workspace/*
```

## 安全性对比

### 安全级别

| 方法 | 安全级别 | 反编译难度 | 文件大小 |
|------|----------|------------|----------|
| PyInstaller | 高 | 很难 | 较大 |
| shc | 高 | 很难 | 较小 |
| Python 字节码 | 中 | 容易 | 小 |
| 只读源码 | 低 | 不需要 | 最小 |

### 推荐配置

**最高安全性：**
- Python: PyInstaller
- Bash: shc

**性能优化：**
- Python: Python 字节码
- Bash: shc

**快速部署：**
- Python: Python 字节码
- Bash: 只读源码

## 编译工具安装

### PyInstaller

```bash
# 安装
pip3 install pyinstaller

# 升级
pip3 install --upgrade pyinstaller

# 验证安装
python3 -c "import PyInstaller; print(PyInstaller.__version__)"
```

### shc

```bash
# 安装
sudo apt-get install shc

# 验证安装
shc -v
```

## 编译结果

### 构建目录结构

```
build/
├── workspace-config           # Python 可执行文件 (PyInstaller)
├── workspace-config.pyc       # Python 字节码 (备用)
├── workspace-launcher         # Bash 可执行文件 (shc)
├── workspace-app             # Bash 可执行文件 (shc)
├── workspace-connect          # Bash 可执行文件 (shc)
├── workspace.conf             # 配置文件
├── apps/                      # 应用数据目录
├── bin/                       # 二进制文件目录
├── install.sh                 # 安装脚本
└── README.md                  # 编译说明
```

### 原始备份目录

```
original_backup/
└── 20260425_223000/          # 按时间戳备份
    ├── workspace-config.py
    ├── workspace-launcher.sh
    ├── workspace-app.sh
    └── ...                    # 所有 .sh 和 .py 文件
```

## 故障排查

### 问题1：PyInstaller 编译失败

**错误信息：**
```
ModuleNotFoundError: No module named 'PyInstaller'
```

**解决方法：**
```bash
pip3 install pyinstaller
```

### 问题2：shc 编译失败

**错误信息：**
```
shc: command not found
```

**解决方法：**
```bash
sudo apt-get install shc
```

### 问题3：编译后的文件无法运行

**检查步骤：**
```bash
# 检查文件权限
ls -la /home/sclead/workspace/build/

# 设置执行权限
chmod +x /home/sclead/workspace/build/*

# 测试运行
cd /home/sclead/workspace/build
./workspace-launcher help
```

### 问题4：Python 脚本找不到模块

**错误信息：**
```
ImportError: No module named 'xxx'
```

**解决方法：**
```bash
# 安装缺失的模块
pip3 install xxx

# 或者在 PyInstaller 中包含隐藏导入
pyinstaller --hidden-import=xxx script.py
```

### 问题5：Bash 脚本找不到命令

**错误信息：**
```
xxx: command not found
```

**解决方法：**
```bash
# 检查 PATH 环境变量
echo $PATH

# 确保所有依赖的命令都已安装
which xxx
sudo apt-get install xxx
```

## 注意事项

### 1. 编译不可逆

- 编译后的文件无法直接修改
- 修改代码需要使用原始备份
- 建议在编译前充分测试

### 2. 文件大小增加

- PyInstaller 生成的文件较大
- shc 编译的文件也较大
- Python 字节码文件较小

### 3. 兼容性问题

- PyInstaller 可能不完全兼容所有 Python 版本
- shc 可能不支持某些 Bash 特性
- 编译前请测试所有功能

### 4. 调试困难

- 编译后的文件难以调试
- 建议保留原始备份用于调试
- 可以使用 `--debug` 参数编译

### 5. 安全性限制

- 没有绝对安全的编译方法
- 有经验的攻击者仍然可能反编译
- 主要目的是增加逆向工程难度

## 相关文件

### 编译脚本
- `compile.sh` - 主编译脚本
- `test_compile.sh` - 编译测试脚本

### 文档
- `COMPILE_GUIDE.md` - 本文档
- `build/README.md` - 编译版本说明

### 备份目录
- `original_backup/` - 原始文件备份
- `workspace_backup_*` - 完整备份

## 总结

### 推荐编译流程

1. **安装编译工具**
   ```bash
   pip3 install pyinstaller
   sudo apt-get install shc
   ```

2. **编译工作区**
   ```bash
   cd /home/sclead/workspace
   ./compile.sh
   ```

3. **测试编译版本**
   ```bash
   ./test_compile.sh
   ```

4. **安装编译版本**
   ```bash
   cd /home/sclead/workspace/build
   sudo ./install.sh
   ```

### 安全性建议

1. **使用最高安全级别**
   - Python: PyInstaller
   - Bash: shc

2. **定期重新编译**
   - 代码更新后重新编译
   - 定期检查安全性

3. **妥善保管备份**
   - 保留原始备份
   - 删除不需要的备份

4. **限制访问权限**
   - 设置适当的文件权限
   - 限制用户访问

---

**编译脚本：** `/home/sclead/workspace/compile.sh`  
**测试脚本：** `/home/sclead/workspace/test_compile.sh`  
**文档：** `COMPILE_GUIDE.md`
