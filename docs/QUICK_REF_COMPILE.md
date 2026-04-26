# 编译脚本快速参考

## 🚀 快速开始

### 1. 编译工作区
```bash
cd /home/sclead/workspace
./compile.sh
```

### 2. 测试编译版本
```bash
cd /home/sclead/workspace
./test_compile.sh
```

### 3. 安装编译版本
```bash
cd /home/sclead/workspace/build
sudo ./install.sh
```

## 📋 编译方法

### Python 脚本

| 方法 | 命令 | 安全性 | 文件大小 |
|------|------|--------|----------|
| PyInstaller | 自动检测 | 高 | 较大 |
| 字节码 | 自动检测 | 中 | 小 |

### Bash 脚本

| 方法 | 命令 | 安全性 | 文件大小 |
|------|------|--------|----------|
| shc | 自动检测 | 高 | 较小 |
| 只读源码 | 自动检测 | 低 | 最小 |

## 🛠️ 安装编译工具

### PyInstaller
```bash
pip3 install pyinstaller
```

### shc
```bash
sudo apt-get install shc
```

## 📁 目录结构

```
/home/sclead/workspace/
├── compile.sh                  # 编译脚本
├── test_compile.sh             # 测试脚本
├── build/                      # 构建目录（编译后）
│   ├── install.sh              # 安装脚本
│   ├── README.md               # 编译说明
│   ├── workspace-*            # 编译后的文件
│   └── apps/                   # 应用数据
└── original_backup/            # 原始备份
    └── YYYYMMDD_HHMMSS/        # 按时间备份
```

## ⚠️ 重要提示

### 编译前
1. ✅ 安装编译工具（PyInstaller, shc）
2. ✅ 测试原始版本功能正常
3. ✅ 备份原始文件

### 编译后
1. ✅ 测试编译版本
2. ✅ 检查文件权限
3. ✅ 保留原始备份

### 安装前
1. ✅ 备份当前版本
2. ✅ 确认编译版本测试通过
3. ✅ 准备回滚方案

## 🔍 故障排查

### PyInstaller 问题
```bash
pip3 install --upgrade pyinstaller
```

### shc 问题
```bash
sudo apt-get install shc
```

### 权限问题
```bash
chmod +x /home/sclead/workspace/build/*
```

## 🔄 回滚到原始版本

```bash
# 查看备份
ls -la /home/sclead/workspace/original_backup/

# 恢复备份
sudo cp -r /home/sclead/workspace/original_backup/20260425_XXXXXX/* /home/sclead/workspace/

# 设置权限
sudo chmod +x /home/sclead/workspace/*
```

## 📚 相关文档

| 文档 | 说明 |
|------|------|
| `COMPILE_GUIDE.md` | 详细编译说明 |
| `build/README.md` | 编译版本说明 |
| `QUICK_REF_COMPILE.md` | 本文件 |

## 💡 提示

1. **编译时间**：首次编译可能需要 5-10 分钟
2. **文件大小**：PyInstaller 生成的文件较大
3. **安全性**：PyInstaller + shc = 最高安全级别
4. **备份重要性**：务必保留原始备份

---

**脚本：** `compile.sh` | `test_compile.sh`  
**文档：** `COMPILE_GUIDE.md` | `build/README.md`  
**状态：** ✅ 准备就绪
