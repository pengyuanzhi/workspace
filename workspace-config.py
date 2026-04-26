#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
工作区虚拟机配置工具
Workspace VM Configuration Tool

图形化配置 WorkspaceVM 虚拟机参数
使用 libvirt XML 格式
"""

import sys
import os
import subprocess
import shutil
from xml.etree import ElementTree as ET

# 修复 QStandardPaths 警告：在导入 PyQt5 之前设置 XDG_RUNTIME_DIR
if os.geteuid() == 0:
    os.environ['XDG_RUNTIME_DIR'] = '/run/user/0'

try:
    from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                                    QHBoxLayout, QLabel, QLineEdit, QSpinBox, 
                                    QPushButton, QMessageBox, QStatusBar,
                                    QGroupBox, QFrame, QDialog, QComboBox,
                                    QListWidget, QFileDialog, QScrollArea)
    from PyQt5.QtCore import Qt
    from PyQt5.QtGui import QFont
except ImportError:
    print("错误: PyQt5 未安装")
    print("请安装: sudo apt-get install python3-pyqt5")
    sys.exit(1)

# 配置文件路径
WORKSPACE_DIR = os.environ.get("WORKSPACE_DIR", "/opt/workspace")
WORKSPACE_CONF = os.path.join(WORKSPACE_DIR, "workspace.conf")
LIBVIRT_DIR = "/etc/libvirt/qemu"
VM_XML_FILE = os.path.join(LIBVIRT_DIR, "WorkspaceVM.xml")

# libvirt XML 命名空间
LIBVIRT_NS = {"libvirt": "http://libvirt.org/schemas/domain/1.0"}

# 默认值
DEFAULT_CPUS = 2
DEFAULT_MEMORY = 4096  # MB
DEFAULT_DISK_SIZE = 40  # GB
DEFAULT_DISK_PATH = os.path.join(WORKSPACE_DIR, "workspace-vm.qcow2")

class VMConfigWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        
        self.config = {}
        self.devices = []
        self.root_element = None
        self.disks = []  # 存储多个磁盘配置
        self.disk_widgets = []  # 存储磁盘配置控件
        
        self.init_ui()
        self.load_config()
    
    def init_ui(self):
        """初始化界面"""
        self.setWindowTitle("虚拟机配置")
        self.setGeometry(400, 200, 500, 700)
        
        # 主窗口
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        
        # 主布局
        main_layout = QVBoxLayout()
        main_widget.setLayout(main_layout)
        
        # 虚拟机名称
        vm_group = QGroupBox("虚拟机名称")
        vm_layout = QHBoxLayout()
        
        self.vm_name_edit = QLineEdit()
        vm_layout.addWidget(self.vm_name_edit)
        vm_group.setLayout(vm_layout)
        main_layout.addWidget(vm_group)
        
        # CPU 配置
        cpu_group = QGroupBox("CPU 配置")
        cpu_layout = QHBoxLayout()
        
        cpu_label = QLabel("CPU 核心数:")
        cpu_label.setMinimumWidth(100)  # 固定标签宽度
        self.cpus_spin = QSpinBox()
        self.cpus_spin.setMinimum(1)
        self.cpus_spin.setMaximum(16)
        cpu_layout.addWidget(cpu_label)
        cpu_layout.addWidget(self.cpus_spin)
        cpu_layout.addStretch()
        
        cpu_group.setLayout(cpu_layout)
        main_layout.addWidget(cpu_group)
        
        # 内存配置
        memory_group = QGroupBox("内存配置")
        memory_layout = QHBoxLayout()
        
        memory_label = QLabel("内存大小 (MB):")
        memory_label.setMinimumWidth(100)  # 固定标签宽度
        self.memory_spin = QSpinBox()
        self.memory_spin.setMinimum(512)
        self.memory_spin.setMaximum(32768)
        self.memory_spin.setSingleStep(512)
        memory_layout.addWidget(memory_label)
        memory_layout.addWidget(self.memory_spin)
        memory_layout.addStretch()
        
        memory_group.setLayout(memory_layout)
        main_layout.addWidget(memory_group)
        
        # 磁盘配置
        disk_group = QGroupBox("磁盘配置")
        disk_layout = QVBoxLayout()
        
        # 磁盘数量标签
        self.disk_count_label = QLabel("磁盘数量: 0")
        disk_layout.addWidget(self.disk_count_label)
        
        # 滚动区域（用于多个磁盘配置）
        disk_scroll = QScrollArea()
        disk_scroll.setWidgetResizable(True)
        disk_scroll.setMaximumHeight(250)
        
        # 磁盘配置容器
        self.disk_config_widget = QWidget()
        self.disk_config_layout = QVBoxLayout()
        self.disk_config_widget.setLayout(self.disk_config_layout)
        disk_scroll.setWidget(self.disk_config_widget)
        
        disk_layout.addWidget(disk_scroll)
        
        # 磁盘操作按钮
        disk_button_layout = QHBoxLayout()
        add_disk_button = QPushButton("添加磁盘")
        add_disk_button.clicked.connect(self.add_disk)
        add_disk_button.setStyleSheet("background-color: #2196F3; color: white;")
        add_disk_button.setMaximumWidth(120)
        
        remove_disk_button = QPushButton("删除磁盘")
        remove_disk_button.clicked.connect(self.remove_disk)
        remove_disk_button.setStyleSheet("background-color: #F44336; color: white;")
        remove_disk_button.setMaximumWidth(120)
        
        disk_button_layout.addWidget(add_disk_button)
        disk_button_layout.addWidget(remove_disk_button)
        disk_button_layout.addStretch()
        disk_layout.addLayout(disk_button_layout)
        
        disk_group.setLayout(disk_layout)
        main_layout.addWidget(disk_group)
        
        # 设备透传
        device_group = QGroupBox("设备透传")
        device_layout = QVBoxLayout()
        
        self.device_list = QListWidget()
        device_layout.addWidget(self.device_list)
        
        # 设备操作按钮布局
        device_button_layout = QHBoxLayout()
        
        add_usb_button = QPushButton("添加 USB 设备")
        add_usb_button.clicked.connect(self.scan_usb_devices)
        add_usb_button.setStyleSheet("background-color: #2196F3; color: white;")
        add_usb_button.setMinimumWidth(120)
        add_usb_button.setMaximumHeight(30)
        
        add_pci_button = QPushButton("添加 PCI 设备")
        add_pci_button.clicked.connect(self.scan_pci_devices)
        add_pci_button.setStyleSheet("background-color: #2196F3; color: white;")
        add_pci_button.setMinimumWidth(120)
        add_pci_button.setMaximumHeight(30)
        
        add_button = QPushButton("添加设备")
        add_button.clicked.connect(self.add_device)
        add_button.setStyleSheet("background-color: #2196F3; color: white;")
        add_button.setMinimumWidth(120)
        add_button.setMaximumHeight(30)
        
        remove_button = QPushButton("删除设备")
        remove_button.clicked.connect(self.remove_device)
        remove_button.setStyleSheet("background-color: #F44336; color: white;")  # 红色系
        remove_button.setMinimumWidth(120)
        remove_button.setMaximumHeight(30)
        
        # 查看透传设备按钮
        view_devices_button = QPushButton("查看设备")
        view_devices_button.clicked.connect(self.show_devices)
        view_devices_button.setStyleSheet("background-color: #9C27B0; color: white;")  # 紫色系
        view_devices_button.setMinimumWidth(120)
        view_devices_button.setMaximumHeight(30)
        
        device_button_layout.addWidget(add_usb_button)
        device_button_layout.addWidget(add_pci_button)
        device_button_layout.addWidget(add_button)
        device_button_layout.addWidget(remove_button)
        device_button_layout.addWidget(view_devices_button)
        device_button_layout.addStretch()
        device_layout.addLayout(device_button_layout)
        
        device_group.setLayout(device_layout)
        main_layout.addWidget(device_group)
        
        # 按钮区域
        button_frame = QFrame()
        button_layout = QHBoxLayout()
        
        save_button = QPushButton("备份配置")
        save_button.clicked.connect(self.save_config)
        save_button.setStyleSheet("background-color: #4CAF50; color: white;")
        
        reset_button = QPushButton("重置默认")
        reset_button.clicked.connect(self.reset_defaults)
        
        apply_button = QPushButton("应用配置")
        apply_button.clicked.connect(self.apply_config)
        apply_button.setStyleSheet("background-color: #2196F3; color: white;")
        
        quit_button = QPushButton("退出")
        quit_button.clicked.connect(self.close)
        
        button_layout.addWidget(save_button)
        button_layout.addWidget(reset_button)
        button_layout.addWidget(apply_button)
        button_layout.addStretch()
        button_layout.addWidget(quit_button)
        button_frame.setLayout(button_layout)
        main_layout.addWidget(button_frame)
        
        # 状态栏
        self.status_bar = QStatusBar()
        self.setStatus("就绪")
        main_layout.addWidget(self.status_bar)
    
    def load_config(self):
        """加载配置"""
        # 默认配置
        self.config = {
            "vm_name": "WorkspaceVM",
            "cpus": DEFAULT_CPUS,
            "memory": DEFAULT_MEMORY,
            "disk_size": DEFAULT_DISK_SIZE,
            "disk_path": DEFAULT_DISK_PATH,
            "devices": []
        }
        
        # 初始化磁盘列表
        self.disks = []
        
        # 读取 workspace.conf
        if os.path.exists(WORKSPACE_CONF):
            with open(WORKSPACE_CONF, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("VM_NAME="):
                        vm_name = line.split("=")[1].strip('"')
                        self.config["vm_name"] = vm_name
        
        # 读取 libvirt XML 配置文件
        if os.path.exists(VM_XML_FILE):
            try:
                self.load_libvirt_xml()
            except Exception as e:
                QMessageBox.warning(self, "警告", f"读取 libvirt XML 配置失败: {e}")
        
        # 更新界面
        self.vm_name_edit.setText(self.config["vm_name"])
        self.cpus_spin.setValue(self.config["cpus"])
        self.memory_spin.setValue(self.config["memory"])
        
        # 更新磁盘配置框
        self.update_disk_widgets()
        
        # 更新设备列表
        self.device_list.clear()
        for device in self.devices:
            self.device_list.addItem(device)
    
    def update_disk_widgets(self):
        """更新磁盘配置控件"""
        # 清除现有控件
        for widget_dict in self.disk_widgets:
            # 从字典中获取实际的控件对象
            widget_dict['frame'].setParent(None)
            widget_dict['frame'].deleteLater()
        self.disk_widgets.clear()
        
        # 更新磁盘数量标签
        self.disk_count_label.setText(f"磁盘数量: {len(self.disks)}")
        
        # 为每个磁盘创建配置框
        for i, disk in enumerate(self.disks):
            disk_frame = QGroupBox(f"磁盘 {i+1}")
            disk_layout = QVBoxLayout()
            
            # 磁盘路径
            path_layout = QHBoxLayout()
            path_label = QLabel("路径:")
            path_edit = QLineEdit(disk['path'])
            path_edit.setPlaceholderText("/path/to/disk.qcow2")
            path_layout.addWidget(path_label)
            path_layout.addWidget(path_edit)
            disk_layout.addLayout(path_layout)
            
            # 总线类型
            bus_layout = QHBoxLayout()
            bus_label = QLabel("总线:")
            bus_combo = QComboBox()
            bus_combo.addItems(["sata", "virtio"])
            bus_combo.setCurrentText(disk.get('bus', 'sata'))
            bus_layout.addWidget(bus_label)
            bus_layout.addWidget(bus_combo)
            disk_layout.addLayout(bus_layout)
            
            # 存储控件引用
            self.disk_widgets.append({
                'frame': disk_frame,
                'path': path_edit,
                'bus': bus_combo,
                'index': i
            })
            
            disk_frame.setLayout(disk_layout)
            self.disk_config_layout.addWidget(disk_frame)
        
        # 添加弹性空间
        self.disk_config_layout.addStretch()
    
    def add_disk(self):
        """添加磁盘"""
        # 显示文件选择对话框
        filename, _ = QFileDialog.getOpenFileName(
            self,
            "选择磁盘镜像",
            "/var/lib/libvirt/images",
            "QCOW2 磁盘镜像 (*.qcow2);;所有文件 (*.*)"
        )
        
        if filename:
            # 添加新的磁盘配置
            new_disk = {
                "path": filename,
                "device": "disk",
                "bus": "sata"
            }
            self.disks.append(new_disk)
            self.update_disk_widgets()
            self.setStatus(f"已添加磁盘: {filename}")
    
    def remove_disk(self):
        """删除磁盘"""
        # 检查是否有磁盘
        if not self.disks:
            QMessageBox.warning(self, "警告", "没有可删除的磁盘")
            return
        
        # 删除最后一个磁盘
        if len(self.disks) > 1:
            removed_disk = self.disks.pop()
            self.update_disk_widgets()
            self.setStatus(f"已删除磁盘: {removed_disk['path']}")
        else:
            QMessageBox.warning(self, "警告", "至少需要保留一个磁盘")
    
    def update_disk_config_xml(self, devices_elem):
        """更新磁盘配置的 XML"""
        # 获取当前的磁盘元素
        disk_elems = devices_elem.findall("disk", LIBVIRT_NS)
        
        # 移除所有现有磁盘
        for disk_elem in disk_elems:
            devices_elem.remove(disk_elem)
        
        # 添加新磁盘
        for i, disk in enumerate(self.disks):
            disk_elem = ET.SubElement(devices_elem, "disk", type="file", device=disk["device"])
            ET.SubElement(disk_elem, "driver", name="qemu", type="qcow2")
            ET.SubElement(disk_elem, "source", file=disk["path"])
            
            # 根据总线类型设置设备名
            if disk["bus"] == "sata":
                dev_name = f"sd{chr(97 + i)}"  # sda, sdb, sdc...
            else:
                dev_name = f"vd{chr(97 + i)}"  # vda, vdb, vdc...
            
            ET.SubElement(disk_elem, "target", dev=dev_name, bus=disk["bus"])
            
            # 添加地址（对于 sata 控制器）
            ET.SubElement(disk_elem, "address", type="drive", controller="0", bus="0", target="0", unit=str(i))
    
    def get_pci_device_info(self, bdf_address):
        """根据 PCI BDF 地址获取设备详细信息"""
        try:
            # 清理 BDF 地址格式 (可能是 0000:02:00.0 或 02:00.0)
            bdf = bdf_address.lstrip('0x')
            # 使用 lspci 获取设备信息
            result = subprocess.run(['lspci', '-s', bdf, '-nn'], capture_output=True, text=True)
            if result.stdout:
                # lspci -s 输出格式: "02:00.0 Network controller: Intel Corporation Device 02f0 [8086:02f0]"
                device_info = result.stdout.strip()
                return device_info
        except Exception as e:
            print(f"DEBUG: 获取 PCI 设备信息失败: {e}")
        return None
    
    def get_usb_device_info(self, vendor_id, product_id):
        """根据 USB 厂商/产品 ID 获取设备详细信息"""
        try:
            # 使用 lsusb 获取设备信息
            result = subprocess.run(['lsusb', '-d', f'{vendor_id}:{product_id}'], capture_output=True, text=True)
            if result.stdout:
                # lsusb 输出格式: "Bus 001 Device 004: ID 1234:5678 Device Name"
                device_info = result.stdout.strip()
                # 移除开头的 Bus/Device 部分
                if ': ' in device_info:
                    # 取冒号后面的部分，如 "ID 1234:5678 Device Name"
                    after_colon = device_info.split(': ', 1)[1]
                    # 移除 ID vendor:product 前缀，只保留设备名称
                    if after_colon.startswith('ID '):
                        # 跳过 "ID " 和 "vendor:product " 两个部分
                        parts = after_colon.split(' ', 2)
                        if len(parts) > 2:
                            return parts[2].strip()
                    return after_colon.strip()
        except Exception as e:
            print(f"DEBUG: 获取 USB 设备信息失败: {e}")
        return None
    
    def load_libvirt_xml(self):
        """加载 libvirt XML 配置"""
        # 检查文件是否存在且可读
        if not os.path.exists(VM_XML_FILE):
            QMessageBox.warning(self, "警告", 
                "无法访问虚拟机配置文件\n\n"
                "可能原因:\n"
                "1. 虚拟机未创建\n"
                "2. 权限不足\n\n"
                "解决方法:\n"
                "如需修改配置，请使用: sudo ./workspace-config.py")
            return
        
        # 检查文件是否可读
        if not os.access(VM_XML_FILE, os.R_OK):
            QMessageBox.warning(self, "警告", 
                "无法读取虚拟机配置文件\n\n"
                "原因: 权限不足\n\n"
                "解决方法:\n"
                "如需修改配置，请使用: sudo ./workspace-config.py")
            return
        
        try:
            tree = ET.parse(VM_XML_FILE)
        except ET.ParseError as e:
            QMessageBox.warning(self, "警告", f"解析 XML 配置文件失败: {e}")
            return
        except Exception as e:
            QMessageBox.warning(self, "警告", f"读取配置文件失败: {e}")
            return
        
        root = tree.getroot()
        self.root_element = root
        
        # 读取虚拟机名称
        name_elem = root.find("name")
        if name_elem is not None:
            self.config["vm_name"] = name_elem.text
        
        # 读取 CPU 核心数
        vcpu_elem = root.find("vcpu")
        if vcpu_elem is not None:
            try:
                self.config["cpus"] = int(vcpu_elem.text)
            except ValueError:
                pass
        
        # 读取内存大小（libvirt 使用 KiB，需要转换为 MB）
        memory_elem = root.find("memory")
        if memory_elem is not None:
            try:
                memory_kib = int(memory_elem.text)
                self.config["memory"] = memory_kib // 1024  # 转换为 MB
            except ValueError:
                pass
        
        print(f"DEBUG: 已加载 {len(self.disks)} 个磁盘配置") if self.disks else None
        
        # 读取磁盘配置
        devices_elem = root.find("devices")
        if devices_elem is not None:
            disk_elems = devices_elem.findall("disk", LIBVIRT_NS)
            for disk_elem in disk_elems:
                if disk_elem.get("type") == "file":
                    source_elem = disk_elem.find("source")
                    if source_elem is not None:
                        disk_path = source_elem.get("file")
                        if disk_path:
                            # 保存所有磁盘配置
                            self.disks.append({
                                "path": disk_path,
                                "device": disk_elem.get("device", "disk"),
                                "bus": None
                            })
                            
                            # 读取总线类型
                            target_elem = disk_elem.find("target")
                            if target_elem is not None:
                                self.disks[-1]["bus"] = target_elem.get("bus")
            
            # 默认显示第一个磁盘
            if self.disks:
                self.config["disk_path"] = self.disks[0]["path"]
        
        # 读取设备透传配置
        self.devices = []
        if devices_elem is not None:
            hostdev_elems = devices_elem.findall("hostdev", LIBVIRT_NS)
            for hostdev_elem in hostdev_elems:
                device_type = hostdev_elem.get("type")
                if device_type == "usb":
                    vendor_elem = hostdev_elem.find("source/vendor")
                    product_elem = hostdev_elem.find("source/product")
                    if vendor_elem is not None and product_elem is not None:
                        vendor_id = vendor_elem.get("id")
                        product_id = product_elem.get("id")
                        # 获取设备详细信息
                        device_name = self.get_usb_device_info(vendor_id, product_id)
                        if device_name:
                            self.devices.append(f"USB: {device_name} [{vendor_id}:{product_id}]")
                        else:
                            self.devices.append(f"USB: {vendor_id}:{product_id}")
                elif device_type == "pci":
                    # PCI 透传设备的 address 元素在 source 下面
                    source_elem = hostdev_elem.find("source")
                    if source_elem is not None:
                        address_elem = source_elem.find("address")
                        if address_elem is not None:
                            domain = address_elem.get("domain")
                            bus = address_elem.get("bus")
                            slot = address_elem.get("slot")
                            function = address_elem.get("function")
                            # 格式化 BDF 地址 (lspci 格式: domain:bus:slot.function)
                            # domain 格式可能是 "0x0000" 或 "0000"
                            if domain:
                                # 移除 0x 前缀并填充为 4 位
                                domain_clean = domain.lstrip('0x').zfill(4)
                                # bus 和 slot 格式化为两位
                                bus_clean = bus.lstrip('0x').zfill(2)
                                slot_clean = slot.lstrip('0x').zfill(2)
                                # function 格式化为一位
                                func_clean = function.lstrip('0x').zfill(1)
                                # 构建 BDF 地址 (lspci 格式: domain:bus:slot.function)
                                bdf_address = f"{domain_clean}:{bus_clean}:{slot_clean}.{func_clean}"
                                # 获取设备详细信息
                                device_info = self.get_pci_device_info(bdf_address)
                                if device_info:
                                    self.devices.append(f"PCI: {device_info}")
                                else:
                                    self.devices.append(f"PCI: {bdf_address}")
        
        print(f"DEBUG: 已加载 {len(self.disks)} 个磁盘配置")
        for i, disk in enumerate(self.disks):
            print(f"DEBUG: 磁盘 {i+1}: {disk['path']} ({disk['bus']})")
    
    def save_config(self):
        """保存配置"""
        try:
            print(f"DEBUG: 准备保存配置...")
            print(f"DEBUG:   当前有 {len(self.devices)} 个透传设备")
            for device in self.devices:
                print(f"DEBUG:   - {device}")
            print(f"DEBUG:   设备列表中的项目: {self.device_list.count()}")
            
            # 检查目标目录是否可写
            target_dir = os.path.dirname(VM_XML_FILE)
            if not os.path.exists(target_dir):
                QMessageBox.critical(self, "错误", 
                    "无法写入虚拟机配置文件")
                return False
            
            # 检查是否有写入权限
            if os.path.exists(VM_XML_FILE):
                # 文件已存在，检查是否可写
                if not os.access(VM_XML_FILE, os.W_OK):
                    reply = QMessageBox.question(self, "权限不足", 
                        "无法写入虚拟机配置文件\n\n"
                        "原因: 权限不足\n\n"
                        "解决方法: 使用 sudo 运行此脚本\n\n"
                        "sudo ./workspace-config.py\n\n"
                        "是否现在使用 sudo 重新运行？",
                        QMessageBox.Yes | QMessageBox.No, QMessageBox.Yes)
                    if reply == QMessageBox.Yes:
                        # 提示用户使用 sudo
                        QMessageBox.information(self, "提示", 
                            "请在终端中使用以下命令重新运行:\n\n"
                            "sudo ./workspace-config.py\n\n"
                            "然后应用您的配置")
                    return False
            else:
                # 文件不存在，检查目录是否可写
                if not os.access(target_dir, os.W_OK):
                    reply = QMessageBox.question(self, "权限不足", 
                        "无法写入虚拟机配置文件\n\n"
                        "原因: 权限不足\n\n"
                        "解决方法: 使用 sudo 运行此脚本\n\n"
                        "sudo ./workspace-config.py\n\n"
                        "是否现在使用 sudo 重新运行？",
                        QMessageBox.Yes | QMessageBox.No, QMessageBox.Yes)
                    if reply == QMessageBox.Yes:
                        QMessageBox.information(self, "提示", 
                            "请在终端中使用以下命令重新运行:\n\n"
                            f"sudo {sys.argv[0]}\n\n"
                            "然后应用您的配置")
                    return False
            
            # 生成 libvirt XML
            xml_content = self.generate_libvirt_xml()
            
            # 备份原文件
            if os.path.exists(VM_XML_FILE):
                backup_file = VM_XML_FILE + ".backup"
                shutil.copy2(VM_XML_FILE, backup_file)
                self.setStatus("已自动备份原配置文件")
            
            # 写入新配置
            with open(VM_XML_FILE, 'w', encoding='utf-8') as f:
                f.write(xml_content)
            
            # 验证写入的内容
            print(f"DEBUG: 配置已写入 {VM_XML_FILE}")
            
            # 重新读取文件进行验证
            with open(VM_XML_FILE, 'r', encoding='utf-8') as f:
                written_content = f.read()
            
            if "<hostdev" in written_content:
                hostdev_count = written_content.count("<hostdev")
                print(f"DEBUG: 文件中有 {hostdev_count} 个 hostdev 元素")
            else:
                print(f"DEBUG: 文件中没有 hostdev 元素")
            
            # 列出所有透传设备
            if "<hostdev" in written_content:
                import re
                hostdev_matches = re.findall(r'<hostdev.*?>', written_content)
                print(f"DEBUG: 找到 {len(hostdev_matches)} 个 hostdev 标签")
                for i, match in enumerate(hostdev_matches):
                    print(f"DEBUG: 透传设备 {i+1}: {match[:50]}...")
            
            QMessageBox.information(self, "成功", "配置已备份\n\n已自动备份原配置文件\n\n需要重启虚拟机以使配置生效")
            return True
        except PermissionError:
            QMessageBox.critical(self, "错误", "权限不足\n\n请使用 sudo 运行此程序\n\nsudo ./workspace-config")
            return False
        except Exception as e:
            QMessageBox.critical(self, "错误", f"保存配置失败: {e}")
            return False
    
    def generate_libvirt_xml(self):
        """生成 libvirt XML - 基于原始文件修改，只修改必要的节点"""
        # 如果存在原始配置，基于它修改
        if self.root_element is not None:
            root = self.root_element
            
            # 修改虚拟机名称
            name_elem = root.find("name")
            if name_elem is not None:
                name_elem.text = self.vm_name_edit.text().strip()
            
            # 修改内存大小
            memory_mb = self.memory_spin.value()
            memory_kib = memory_mb * 1024
            
            memory_elem = root.find("memory")
            if memory_elem is not None:
                memory_elem.text = str(memory_kib)
            
            current_memory_elem = root.find("currentMemory")
            if current_memory_elem is not None:
                current_memory_elem.text = str(memory_kib)
            
            # 修改 CPU 核心数
            vcpu_elem = root.find("vcpu")
            if vcpu_elem is not None:
                vcpu_elem.text = str(self.cpus_spin.value())
            
            # 更新磁盘配置（从控件读取配置并更新 XML）
            devices_elem = root.find("devices")
            if devices_elem is not None:
                # 从控件读取配置并更新 self.disks
                for widget in self.disk_widgets:
                    index = widget['index']
                    if index < len(self.disks):
                        self.disks[index]['path'] = widget['path'].text().strip()
                        self.disks[index]['bus'] = widget['bus'].currentText()
                
                # 更新 XML 中的磁盘配置
                self.update_disk_config_xml(devices_elem)
            
            # 添加设备透传
            print(f"DEBUG: 准备添加 {len(self.devices)} 个透传设备")
            if devices_elem is not None:
                # 移除旧的 hostdev 元素
                old_hostdevs = devices_elem.findall("hostdev", LIBVIRT_NS)
                print(f"DEBUG: 移除 {len(old_hostdevs)} 个旧 hostdev 元素")
                for hostdev_elem in old_hostdevs:
                    devices_elem.remove(hostdev_elem)
                
                # 添加新的设备透传
                for device in self.devices:
                    print(f"DEBUG: 处理设备: {device}")
                    if device.startswith("USB:"):
                        # USB 设备透传
                        device_info = device[4:].strip()
                        if ":" in device_info:
                            vendor_id, product_id = device_info.split(":")
                            hostdev_elem = ET.SubElement(devices_elem, "hostdev", mode="subsystem", type="usb")
                            source_elem = ET.SubElement(hostdev_elem, "source")
                            ET.SubElement(source_elem, "vendor", id=vendor_id)
                            ET.SubElement(source_elem, "product", id=product_id)
                            print(f"DEBUG: 已添加 USB 设备: {vendor_id}:{product_id}")
                    elif device.startswith("PCI:"):
                        # PCI 设备透传
                        device_info = device[4:].strip()
                        print(f"DEBUG: PCI 设备信息: {device_info}")
                        
                        # 提取 PCI 地址（使用正则表达式）
                        # 格式可能是: "02:00.0 ..." 或 "0000:02:00.0 ..."
                        import re
                        
                        # 尝试匹配完整的 PCI 地址（带域）
                        pci_match = re.search(r'([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])', device_info)
                        
                        if pci_match:
                            domain = pci_match.group(1)
                            bus = pci_match.group(2)
                            slot = pci_match.group(3)
                            func = pci_match.group(4)
                            print(f"DEBUG: 提取 PCI 地址（带域）: domain={domain}, bus={bus}, slot={slot}, function={func}")
                            
                            hostdev_elem = ET.SubElement(devices_elem, "hostdev", mode="subsystem", type="pci", managed="yes")
                            source_elem = ET.SubElement(hostdev_elem, "source")
                            ET.SubElement(source_elem, "address", domain=domain, bus=bus, slot=slot, function=func)
                            print(f"DEBUG: 已添加 PCI 设备: {domain}:{bus}:{slot}.{func}")
                        else:
                            # 尝试匹配简化的 PCI 地址（不带域）
                            pci_match = re.search(r'([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])', device_info)
                            
                            if pci_match:
                                bus = pci_match.group(1)
                                slot = pci_match.group(2)
                                func = pci_match.group(3)
                                domain = "0x0000"  # 默认域
                                print(f"DEBUG: 提取 PCI 地址（不带域）: domain={domain}, bus={bus}, slot={slot}, function={func}")
                                
                                hostdev_elem = ET.SubElement(devices_elem, "hostdev", mode="subsystem", type="pci", managed="yes")
                                source_elem = ET.SubElement(hostdev_elem, "source")
                                ET.SubElement(source_elem, "address", domain=domain, bus=bus, slot=slot, function=func)
                                print(f"DEBUG: 已添加 PCI 设备: {domain}:{bus}:{slot}.{func}")
                            else:
                                print(f"DEBUG: 无法解析 PCI 地址: {device_info}")
                
                # 验证透传设备已添加
                new_hostdevs = devices_elem.findall("hostdev", LIBVIRT_NS)
                print(f"DEBUG: XML 中现在有 {len(new_hostdevs)} 个 hostdev 元素")
            else:
                print(f"DEBUG: devices_elem 为 None，无法添加透传设备")
            
            # 格式化输出
            ET.indent(root, space="  ")
            xml_content = ET.tostring(root, encoding="unicode")
            
            # 添加 XML 声明
            return f'<?xml version="1.0" encoding="UTF-8"?>\n{xml_content}'
        else:
            # 如果没有原始配置，生成新的默认配置
            root = ET.Element("domain", type="kvm")
            
            # 虚拟机名称
            name_elem = ET.SubElement(root, "name")
            name_elem.text = self.vm_name_edit.text().strip()
            
            # 内存配置（转换为 KiB）
            memory_mb = self.memory_spin.value()
            memory_kib = memory_mb * 1024
            
            memory_elem = ET.SubElement(root, "memory", unit="KiB")
            memory_elem.text = str(memory_kib)
            
            current_memory_elem = ET.SubElement(root, "currentMemory", unit="KiB")
            current_memory_elem.text = str(memory_kib)
            
            # CPU 配置
            vcpu_elem = ET.SubElement(root, "vcpu", placement="static")
            vcpu_elem.text = str(self.cpus_spin.value())
            
            # 操作系统配置
            os_elem = ET.SubElement(root, "os")
            type_elem = ET.SubElement(os_elem, "type", arch="x86_64", machine="pc")
            type_elem.text = "hvm"
            
            # 特性
            features_elem = ET.SubElement(root, "features")
            ET.SubElement(features_elem, "acpi")
            ET.SubElement(features_elem, "apic")
            
            # CPU 特性
            cpu_elem = ET.SubElement(root, "cpu", mode="host-passthrough")
            
            # 设备
            devices_elem = ET.SubElement(root, "devices")
            
            # 磁盘设备
            disk_elem = ET.SubElement(devices_elem, "disk", type="file", device="disk")
            ET.SubElement(disk_elem, "driver", name="qemu", type="qcow2")
            # 使用第一个磁盘或默认磁盘路径
            disk_path = DEFAULT_DISK_PATH
            if self.disks:
                disk_path = self.disks[0]['path']
            ET.SubElement(disk_elem, "source", file=disk_path)
            ET.SubElement(disk_elem, "target", dev="vda", bus="virtio")
            ET.SubElement(disk_elem, "address", type="pci", domain="0x0000", bus="0x00", slot="0x04", func="0x0")
            
            # 网络设备
            interface_elem = ET.SubElement(devices_elem, "interface", type="network")
            ET.SubElement(interface_elem, "source", network="default")
            ET.SubElement(interface_elem, "model", type="virtio")
            
            # 显示设备
            graphics_elem = ET.SubElement(devices_elem, "graphics", type="spice", autoport="yes")
            
            # 视频设备
            video_elem = ET.SubElement(devices_elem, "video")
            ET.SubElement(video_elem, "model", type="qxl")
            
            # 控制台设备
            console_elem = ET.SubElement(devices_elem, "console", type="pty")
            ET.SubElement(console_elem, "target", type="serial", port="0")
            
            # 输入设备
            input_elem = ET.SubElement(devices_elem, "input", type="tablet", bus="usb")
            
            # 设备透传
            for device in self.devices:
                if device.startswith("USB:"):
                    # USB 设备透传
                    device_info = device[4:].strip()
                    if ":" in device_info:
                        vendor_id, product_id = device_info.split(":")
                        hostdev_elem = ET.SubElement(devices_elem, "hostdev", mode="subsystem", type="usb")
                        source_elem = ET.SubElement(hostdev_elem, "source")
                        ET.SubElement(source_elem, "vendor", id=vendor_id)
                        ET.SubElement(source_elem, "product", id=product_id)
                elif device.startswith("PCI:"):
                    # PCI 设备透传
                    device_info = device[4:].strip()
                    parts = device_info.split(":")
                    if len(parts) >= 2:
                        bus, slot_func = parts
                        if "." in slot_func:
                            slot, func = slot_func.split(".")
                            hostdev_elem = ET.SubElement(devices_elem, "hostdev", mode="subsystem", type="pci", managed="yes")
                            source_elem = ET.SubElement(hostdev_elem, "source")
                            ET.SubElement(source_elem, "address", domain=bus, bus=slot, slot=slot, function=func)
            
            # 格式化输出
            ET.indent(root, space="  ")
            xml_content = ET.tostring(root, encoding="unicode")
            
            # 添加 XML 声明
            return f'<?xml version="1.0" encoding="UTF-8"?>\n{xml_content}'
    
    def scan_usb_devices(self):
        """添加 USB 设备"""
        self.setStatus("添加 USB 设备...")
        print("""DEBUG [scan_usb_devices]: 开始扫描 USB 设备...""")
        try:
            # 使用 lsusb 扫描 USB 设备
            result = subprocess.run(['lsusb'], capture_output=True, text=True)
            usb_devices = result.stdout.strip().split('\n') if result.stdout else []
            
            print(f"DEBUG [scan_usb_devices]: 找到 {len(usb_devices)} 个 USB 设备")
            for i, device in enumerate(usb_devices):
                print(f"DEBUG [scan_usb_devices]:   {i+1}. {device[:60]}...")
            
            if not usb_devices:
                QMessageBox.information(self, "信息", "未找到 USB 设备")
                self.setStatus("就绪")
                return
            
            # 显示 USB 设备选择对话框
            print("DEBUG [scan_usb_devices]: 显示设备选择对话框")
            dialog = USBDeviceDialog(usb_devices, self)
            result = dialog.exec_()
            print(f"DEBUG [scan_usb_devices]: 对话框结果 = {result} (Accepted={QDialog.Accepted})")
            
            if result == QDialog.Accepted:
                selected_devices = dialog.get_selected_devices()
                print(f"DEBUG [scan_usb_devices]: 选择了 {len(selected_devices)} 个设备")
                for device in selected_devices:
                    print(f"DEBUG [scan_usb_devices]:   - {device}")
                    self.devices.append(f"USB: {device}")
                    self.device_list.addItem(f"USB: {device}")
                
                self.setStatus(f"已添加 {len(selected_devices)} 个设备")
                print(f"DEBUG [scan_usb_devices]: 当前设备列表中共有 {len(self.devices)} 个透传设备")
            else:
                print("DEBUG [scan_usb_devices]: 用户取消了选择")
                self.setStatus("就绪")
                
        except Exception as e:
            QMessageBox.critical(self, "错误", f"扫描 USB 设备失败: {e}")
            self.setStatus("扫描失败")
    
    def scan_pci_devices(self):
        """添加 PCI 设备"""
        self.setStatus("添加 PCI 设备...")
        print("DEBUG [scan_pci_devices]: 开始扫描 PCI 设备...")
        try:
            # 使用 lspci 扫描 PCI 设备
            result = subprocess.run(['lspci', '-nn'], capture_output=True, text=True)
            pci_devices = result.stdout.strip().split('\n') if result.stdout else []
            
            print(f"DEBUG [scan_pci_devices]: 找到 {len(pci_devices)} 个 PCI 设备")
            for i, device in enumerate(pci_devices):
                print(f"DEBUG [scan_pci_devices]:   {i+1}. {device[:60]}...")
            
            if not pci_devices:
                QMessageBox.information(self, "信息", "未找到 PCI 设备")
                self.setStatus("就绪")
                return
            
            # 显示 PCI 设备选择对话框
            print("DEBUG [scan_pci_devices]: 显示设备选择对话框")
            dialog = PCIDeviceDialog(pci_devices, self)
            result = dialog.exec_()
            print(f"DEBUG [scan_pci_devices]: 对话框结果 = {result} (Accepted={QDialog.Accepted})")
            
            if result == QDialog.Accepted:
                selected_devices = dialog.get_selected_devices()
                print(f"DEBUG [scan_pci_devices]: 选择了 {len(selected_devices)} 个设备")
                for device in selected_devices:
                    print(f"DEBUG [scan_pci_devices]:   - {device}")
                    self.devices.append(f"PCI: {device}")
                    self.device_list.addItem(f"PCI: {device}")
                
                self.setStatus(f"已添加 {len(selected_devices)} 个设备")
                print(f"DEBUG [scan_pci_devices]: 当前设备列表中共有 {len(self.devices)} 个透传设备")
            else:
                print("DEBUG [scan_pci_devices]: 用户取消了选择")
                self.setStatus("就绪")
                
        except FileNotFoundError:
            QMessageBox.critical(self, "错误", "lspci 命令未找到\n\n请安装 pciutils: sudo apt-get install pciutils")
            self.setStatus("扫描失败")
        except Exception as e:
            QMessageBox.critical(self, "错误", f"扫描 PCI 设备失败: {e}")
            self.setStatus("扫描失败")
    
    def add_device(self):
        """添加设备"""
        dialog = AddDeviceDialog(self)
        if dialog.exec_() == QDialog.Accepted:
            device_info = dialog.get_device()
            if device_info:
                device_str = f"{device_info['type']}: {device_info['path']}"
                self.devices.append(device_str)
                self.device_list.addItem(device_str)
                self.setStatus(f"已添加设备: {device_info['path']}")
    
    def remove_device(self):
        """删除设备"""
        current_item = self.device_list.currentItem()
        if current_item:
            row = self.device_list.row(current_item)
            device = self.devices.pop(row)
            self.device_list.takeItem(row)
            self.setStatus(f"已删除设备: {device}")
        else:
            QMessageBox.warning(self, "警告", "请选择要删除的设备")
    
    def show_devices(self):
        """显示透传设备列表"""
        print("""
========================================
当前透传设备列表
========================================
""")
        print(f"设备总数: {len(self.devices)}")
        print("")
        
        for i, device in enumerate(self.devices, 1):
            print(f"{i}. {device}")
        
        print("")
        print(f"列表控件中的项目数: {self.device_list.count()}")
        print("========================================")
        
        # 也显示在对话框中
        message = f"当前透传设备总数: {len(self.devices)}\n\n"
        for i, device in enumerate(self.devices, 1):
            message += f"{i}. {device}\n"
        
        QMessageBox.information(self, "透传设备列表", message)
    
    def reset_defaults(self):
        """重置默认值"""
        reply = QMessageBox.question(self, "确认", "确定要重置为默认配置吗？",
                                     QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if reply == QMessageBox.Yes:
            self.load_config()
            self.setStatus("已重置为默认配置")
            QMessageBox.information(self, "完成", "已重置为默认配置")
    
    def apply_config(self):
        """应用配置"""
        reply = QMessageBox.question(self, "确认", "确定要应用此配置吗？\n\n配置将保存到虚拟机配置文件\n\n请确保已保存当前工作再继续",
                                     QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if reply == QMessageBox.Yes:
            if self.save_config():
                self.setStatus("配置已应用")
                QMessageBox.information(self, "成功", "配置已应用\n\n需要重启虚拟机以使配置生效")
    
    def setStatus(self, message):
        """设置状态栏"""
        self.status_bar.showMessage(message)

class USBDeviceDialog(QDialog):
    def __init__(self, usb_devices, parent=None):
        super().__init__(parent)
        self.setWindowTitle("选择 USB 设备")
        self.setGeometry(400, 300, 500, 400)
        
        self.usb_devices = usb_devices
        self.selected_devices = []
        
        self.init_ui()
    
    def init_ui(self):
        """初始化界面"""
        layout = QVBoxLayout()
        self.setLayout(layout)
        
        # 设备列表
        device_list = QListWidget()
        for i, device in enumerate(self.usb_devices, 1):
            device_list.addItem(f"{i}. {device}")
        
        device_list.setSelectionMode(QListWidget.MultiSelection)
        device_list.itemSelectionChanged.connect(self.on_selection_changed)
        self.device_list_widget = device_list
        layout.addWidget(device_list)
        
        # 按钮
        button_layout = QHBoxLayout()
        
        ok_button = QPushButton("确定")
        ok_button.clicked.connect(self.accept)
        
        cancel_button = QPushButton("取消")
        cancel_button.clicked.connect(self.reject)
        
        button_layout.addWidget(ok_button)
        button_layout.addWidget(cancel_button)
        button_layout.addStretch()
        layout.addLayout(button_layout)
    
    def on_selection_changed(self):
        """选择改变"""
        selected_items = self.device_list_widget.selectedItems()
        self.selected_devices = []
        print(f"DEBUG [USBDialog]: 选择改变，找到 {len(selected_items)} 个选中的项目")
        for item in selected_items:
            text = item.text().split(". ", 1)[1]
            print(f"DEBUG [USBDialog]: 处理项目文本: {text}")
            # 解析 lsusb 输出: "Bus 001 Device 002: ID 1234:5678 ..."
            if "ID " in text:
                id_part = text.split("ID ")[1].split()[0]
                print(f"DEBUG [USBDialog]: 提取 ID: {id_part}")
                self.selected_devices.append(id_part)
                print(f"DEBUG [USBDialog]: 已添加 ID 到选择列表")
            else:
                print(f"DEBUG [USBDialog]: 项目文本中没有 'ID ' 标记")
    
    def get_selected_devices(self):
        """获取选择的设备"""
        return self.selected_devices

class PCIDeviceDialog(QDialog):
    def __init__(self, pci_devices, parent=None):
        super().__init__(parent)
        self.setWindowTitle("选择 PCI 设备")
        self.setGeometry(400, 300, 600, 400)
        
        self.pci_devices = pci_devices
        self.selected_devices = []
        
        self.init_ui()
    
    def init_ui(self):
        """初始化界面"""
        layout = QVBoxLayout()
        self.setLayout(layout)
        
        # 设备列表
        device_list = QListWidget()
        for i, device in enumerate(self.pci_devices, 1):
            device_list.addItem(f"{i}. {device}")
        
        device_list.setSelectionMode(QListWidget.MultiSelection)
        device_list.itemSelectionChanged.connect(self.on_selection_changed)
        self.device_list_widget = device_list
        layout.addWidget(device_list)
        
        # 按钮
        button_layout = QHBoxLayout()
        
        ok_button = QPushButton("确定")
        ok_button.clicked.connect(self.accept)
        
        cancel_button = QPushButton("取消")
        cancel_button.clicked.connect(self.reject)
        
        button_layout.addWidget(ok_button)
        button_layout.addWidget(cancel_button)
        button_layout.addStretch()
        layout.addLayout(button_layout)
    
    def on_selection_changed(self):
        """选择改变"""
        selected_items = self.device_list_widget.selectedItems()
        self.selected_devices = []
        print(f"DEBUG [PCIDialog]: 选择改变，找到 {len(selected_items)} 个选中的项目")
        for item in selected_items:
            # 解析 lspci -nn 输出: "1. 0000:00:02.0 VGA..."
            # 移除编号和空格
            text = item.text()
            print(f"DEBUG [PCIDialog]: 处理项目文本: {text}")
            # 提取 PCI 地址部分
            # 格式: "0000:00:02.0"
            # 跳过编号
            text = text.split('. ', 1)[1] if '. ' in text else text
            # 移除多余的空格
            address = text.strip()
            print(f"DEBUG [PCIDialog]: 提取的地址: {address}")
            # 格式化为标准格式（去掉中间的空格）
            # 从 "0000:00:02.0" 格式化为 "0000:00:02.0"
            if ':' in address:
                self.selected_devices.append(address)
                print(f"DEBUG [PCIDialog]: 已添加地址到选择列表: {address}")
            else:
                print(f"DEBUG [PCIDialog]: 地址格式无效，跳过: {address}")
        print(f"DEBUG [PCIDialog]: 总共选择了 {len(self.selected_devices)} 个 PCI 设备")
    
    def get_selected_devices(self):
        """获取选择的设备"""
        return self.selected_devices

class AddDeviceDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("添加设备")
        self.setGeometry(400, 200, 400, 250)
        
        self.device = None
        self.init_ui()
    
    def init_ui(self):
        """初始化界面"""
        layout = QVBoxLayout()
        self.setLayout(layout)
        
        # 设备类型
        type_layout = QHBoxLayout()
        type_label = QLabel("设备类型:")
        self.type_combo = QComboBox()
        self.type_combo.addItems(["USB", "PCI", "其他"])
        type_layout.addWidget(type_label)
        type_layout.addWidget(self.type_combo)
        layout.addLayout(type_layout)
        
        # 设备路径
        path_layout = QHBoxLayout()
        path_label = QLabel("设备标识:")
        self.path_edit = QLineEdit()
        self.path_edit.setPlaceholderText("USB: 1234:5678, PCI: 0000:00:02.0")
        path_layout.addWidget(path_label)
        path_layout.addWidget(self.path_edit)
        layout.addLayout(path_layout)
        
        # 按钮
        button_layout = QHBoxLayout()
        
        ok_button = QPushButton("确定")
        ok_button.clicked.connect(self.on_ok)
        
        cancel_button = QPushButton("取消")
        cancel_button.clicked.connect(self.reject)
        
        button_layout.addWidget(ok_button)
        button_layout.addWidget(cancel_button)
        button_layout.addStretch()
        layout.addLayout(button_layout)
    
    def on_ok(self):
        """确定按钮"""
        device_type = self.type_combo.currentText()
        device_path = self.path_edit.text().strip()
        
        if not device_path:
            QMessageBox.warning(self, "警告", "请输入设备标识")
            return
        
        self.device = {
            "type": device_type,
            "path": device_path
        }
        
        self.accept()
    
    def get_device(self):
        """获取设备"""
        return self.device

def main():
    # 检查 PyQt5 是否安装
    try:
        from PyQt5.QtWidgets import QApplication
    except ImportError:
        print("错误: PyQt5 未安装")
        print("请安装: sudo apt-get install python3-pyqt5")
        return
    
    # 检查 libvirt 配置文件是否可访问
    libvirt_accessible = False
    try:
        if os.path.exists(LIBVIRT_DIR):
            libvirt_accessible = True
        else:
            print("警告: 虚拟机配置文件需要 sudo 权限访问")
            print("      如需修改配置，请使用: sudo ./workspace-config.py")
    except PermissionError:
        print("警告: 虚拟机配置文件需要 sudo 权限访问")
        print("      如需修改配置，请使用: sudo ./workspace-config.py")
        print("      如果只需要查看配置，可以继续")
        libvirt_accessible = False
    
    # 检查图形界面环境
    if not os.environ.get('DISPLAY'):
        print("错误: 未在图形界面环境中运行")
        print("")
        print("解决方法:")
        print("1. 在本地桌面环境中运行（双击桌面图标或在终端运行）")
        print("2. 使用 SSH X11 转发: ssh -X user@host")
        print("3. 设置 DISPLAY 环境变量: export DISPLAY=:0")
        print("")
        print("当前环境:")
        print(f"  DISPLAY: {os.environ.get('DISPLAY', '未设置')}")
        print(f"  XDG_SESSION_TYPE: {os.environ.get('XDG_SESSION_TYPE', '未设置')}")
        return
    
    app = QApplication(sys.argv)
    
    # 设置应用样式
    app.setStyle('Fusion')
    
    window = VMConfigWindow()
    window.show()
    
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
