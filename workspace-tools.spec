%{!?install_dir: %global install_dir /opt/workspace}
%{!?bin_dir: %global bin_dir %{install_dir}/bin}
%{!?apps_dir: %global apps_dir %{install_dir}/apps}

# 禁用调试包和调试信息
%global debug_package %{nil}
%global __strip /bin/true

Name:           workspace-tools
Version:        %{workspace_version:1.0.0}
Release:        %{workspace_release:1}%{?dist}
Summary:        工作区工具集 - 编译后的二进制工具包

License:        Proprietary
URL:            https://github.com/workspace-tools/workspace-tools
Source0:        %{name}-%{version}.tar.gz

# 移除 BuildArch: noarch，因为包中包含二进制文件
# BuildArch 由 rpmbuild 自动检测
# BuildRoot 在新版 rpmbuild 中已不需要

Requires:       bash
Requires:       python3

%description
工作区工具集包含编译后的二进制工具，用于工作区管理和自动化任务。

默认安装路径: %{install_dir}

%prep
%setup -q

%build
# 所有二进制已在编译阶段生成，无需构建

%install
rm -rf %{buildroot}

# 创建目标目录
mkdir -p %{buildroot}%{bin_dir}
mkdir -p %{buildroot}%{_bindir}

# 复制二进制文件到 bin 目录
if [ -d "bin" ]; then
    find bin -type f -executable -exec cp -p {} %{buildroot}%{bin_dir}/ \;
fi

# 复制 apps 目录（如果存在）
if [ -d "apps" ]; then
    mkdir -p %{buildroot}%{apps_dir}
    cp -r apps/* %{buildroot}%{apps_dir}/ 2>/dev/null || true
fi

# 复制配置文件（如果存在）
if [ -f "workspace.conf" ]; then
    install -m 644 workspace.conf %{buildroot}%{install_dir}/
fi

# 创建到 /usr/local/bin 的符号链接（如果存在二进制文件）
if [ -d "%{buildroot}%{bin_dir}" ]; then
    for binary in %{buildroot}%{bin_dir}/*; do
        if [ -f "$binary" ] && [ -x "$binary" ]; then
            name=$(basename "$binary")
            # 使用相对路径创建符号链接
            ln -sf ../../../opt/workspace/bin/$name %{buildroot}%{_bindir}/$name
        fi
    done
fi

# 设置权限
find %{buildroot}%{bin_dir} -type f -exec chmod 755 {} \;
if [ -d "%{buildroot}%{apps_dir}" ]; then
    find %{buildroot}%{apps_dir} -type f -exec chmod 644 {} \;
    find %{buildroot}%{apps_dir} -type d -exec chmod 755 {} \;
fi

# 创建安装信息文件
cat > %{buildroot}%{install_dir}/.rpm-info << EOF
Package: %{name}
Version: %{version}-%{release}
Install Date: $(date)
Install Dir: %{install_dir}
EOF

%clean
rm -rf %{buildroot}

%post
# 设置正确的权限
if [ -d "%{bin_dir}" ]; then
    chown -R root:root %{bin_dir}
    find %{bin_dir} -type f -exec chmod 755 {} \;
fi

if [ -d "%{apps_dir}" ]; then
    chown -R root:root %{apps_dir}
    find %{apps_dir} -type f -exec chmod 644 {} \;
    find %{apps_dir} -type d -exec chmod 755 {} \;
fi

# 刷新系统路径
if [ -x /usr/bin/hash ]; then
    /usr/bin/hash -r
fi

echo "工作区工具已安装到: %{install_dir}"
echo "工具路径: %{bin_dir}"
echo "符号链接: %{_bindir}"

%preun
if [ "$1" = 0 ]; then
    echo "正在卸载工作区工具..."
    # 删除符号链接
    if [ -d "%{bin_dir}" ]; then
        for binary in %{bin_dir}/*; do
            if [ -f "$binary" ] && [ -x "$binary" ]; then
                name=$(basename "$binary")
                rm -f "%{_bindir}/$name" 2>/dev/null || true
            fi
        done
    fi
fi

%postun
if [ "$1" = 0 ]; then
    echo "工作区工具已卸载"
    # 刷新系统路径
    if [ -x /usr/bin/hash ]; then
        /usr/bin/hash -r
    fi
fi

%files
%defattr(-,root,root,-)
%dir %{install_dir}
%config(noreplace) %{install_dir}/workspace.conf
%{install_dir}/.rpm-info
%dir %{bin_dir}
%{bin_dir}/*
%dir %{apps_dir}
%{apps_dir}/*
%{_bindir}/*

%changelog
* Sun Apr 26 2026 Workspace Tools Maintainer <maintainer@workspace-tools.com> - 1.0.0-1
- 初始版本
- 支持自定义安装路径
