#!/bin/bash
# 重启后快速验证 IOMMU

echo "========================================="
echo "重启后 IOMMU 快速验证"
echo "========================================="
echo ""

# 1. 验证内核启动参数
echo "[1] 内核启动参数："
cat /proc/cmdline
echo ""

if echo $(cat /proc/cmdline) | grep -q "intel_iommu=on"; then
    echo "  ✓ intel_iommu=on 在内核启动参数中"
else
    echo "  ✗ intel_iommu=on 不在内核启动参数中"
    echo ""
    echo "  解决方法："
    echo "  1. 检查 GRUB 配置: grep 'intel_iommu' /boot/grub2/grub.cfg"
    echo "  2. 如果没有，需要重新编辑 GRUB 配置文件"
    echo "  3. 重新启动系统"
    exit 1
fi

echo ""

# 2. 验证 IOMMU 状态
echo "[2] IOMMU 状态："
if dmesg | grep -i "iommu" | grep -i "enabled" > /dev/null 2>&1; then
    echo "  ✓ IOMMU 已启用"
    dmesg | grep -i "iommu" | grep -i "enabled" | head -3
else
    echo "  ✗ IOMMU 未启用"
    echo ""
    echo "  可能的原因："
    echo "  1. BIOS 中没有启用 VT-d"
    echo "  2. 硬件不支持 IOMMU"
    echo "  3. 内核启动参数不正确"
    echo ""
    echo "  解决方法："
    echo "  1. 检查 BIOS 中的 VT-d 设置"
    echo "  2. 检查硬件支持: dmesg | grep -i dmar"
    echo "  3. 检查内核参数: cat /proc/cmdline"
    exit 1
fi

echo ""

# 3. 加载 vfio-pci 模块
echo "[3] 加载 vfio-pci 模块："
if lsmod | grep vfio_pci > /dev/null 2>&1; then
    echo "  ✓ vfio-pci 模块已加载"
else
    echo "  正在加载 vfio-pci 模块..."
    if modprobe vfio-pci > /dev/null 2>&1; then
        echo "  ✓ vfio-pci 模块已加载"
    else
        echo "  ✗ vfio-pci 模块加载失败"
        exit 1
    fi
fi

echo ""
lsmod | grep vfio

echo ""

# 4. 验证虚拟机状态
echo "[4] 虚拟机状态："
if virsh list --all | grep "WorkspaceVM" > /dev/null 2>&1; then
    echo "  ✓ 虚拟机存在"

    if virsh list | grep "WorkspaceVM" > /dev/null 2>&1; then
        echo "  ✓ 虚拟机正在运行"
    else
        echo "  ⚠ 虚拟机未运行"
        echo ""
        echo "  启动虚拟机: virsh start WorkspaceVM"
    fi
else
    echo "  ✗ 虚拟机不存在"
    echo ""
    echo "  重新定义虚拟机: virsh define /etc/libvirt/qemu/WorkspaceVM.xml"
fi

echo ""

# 5. 验证透传设备配置
echo "[5] 透传设备配置："
hostdev_count=$(virsh dumpxml WorkspaceVM 2>/dev/null | grep -c "hostdev.*type.*pci" || echo "0")
if [ "$hostdev_count" -gt 0 ]; then
    echo "  ✓ 找到 $hostdev_count 个透传设备"
else
    echo "  ✗ 没有透传设备配置"
    echo ""
    echo "  解决方法："
    echo "  1. 重新运行配置工具: sudo python3 workspace-config.py"
    echo "  2. 保存配置"
    echo "  3. 重新定义虚拟机: virsh define /etc/libvirt/qemu/WorkspaceVM.xml"
    exit 1
fi

echo ""

echo "========================================="
echo "验证完成"
echo "========================================="
echo ""

# 总结
if echo $(cat /proc/cmdline) | grep -q "intel_iommu=on"; then
    if dmesg | grep -i "iommu" | grep -i "enabled" > /dev/null 2>&1; then
        if lsmod | grep vfio_pci > /dev/null 2>&1; then
            echo "✓ 所有检查通过！"
            echo ""
            echo "现在可以启动虚拟机了："
            echo "  virsh start WorkspaceVM"
            echo ""
            echo "启动后在虚拟机中验证："
            echo "  virsh console WorkspaceVM"
            echo "  lspci -nn"
            echo ""
            echo "应该看到两个 Intel I226-V 网卡！"
        fi
    fi
fi
