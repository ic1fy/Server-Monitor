# Server Monitor

在 macOS 菜单栏查看 Linux 服务器的 GPU、CPU、内存和磁盘使用情况。通过 SSH 连接，可同时监测多台服务器，无需安装服务器端代理。

## 功能

- **GPU**：利用率、已用显存与总显存，按实际 GPU 数量显示。
- **CPU / 内存**：CPU 总体使用率，以及已用内存与总内存。
- **磁盘**：已用、剩余和总容量；多块磁盘分别显示，悬停查看挂载路径。
- **多服务器**：独立刷新、折叠展开；点击图钉选择菜单栏显示哪台服务器。

服务器名称下显示资源总量，例如 `4 GPU · 504G 内存 · 3.4T 磁盘`。多块磁盘容量相加，没有 GPU 数据时省略 GPU 项。

## 安装

需要 **macOS 14+** 和 **Xcode Command Line Tools**。在终端执行：

```sh
xcode-select --install  # 已安装可跳过
git clone https://github.com/ic1fy/Server-Monitor.git
cd Server-Monitor
./scripts/build_app.sh
```

将生成的 `outputs/Server Monitor.app` 拖入「应用程序」并打开。应用显示在屏幕顶部菜单栏中。

默认构建 Apple Silicon 版本。Intel Mac 使用：

```sh
SERVER_MONITOR_ARCHS=x86_64 ./scripts/build_app.sh
```

通用版本使用 `SERVER_MONITOR_ARCHS="arm64 x86_64"`。构建默认采用本地签名，未经过 Apple 公证。

## 连接服务器

在 `~/.ssh/config` 中配置服务器，例如：

```sshconfig
Host my-server
    HostName server.example.com
    User your-user
    IdentityFile ~/.ssh/id_ed25519
```

替换为自己的主机地址、用户名和密钥路径。先在终端运行 `ssh my-server`，完成首次主机确认，再确认以下命令可以不输入密码执行：

```sh
ssh -o BatchMode=yes my-server true
```

打开应用的 **「… → 服务器设置」**，填写 `my-server`，可继续添加其他服务器，并选择 2、5、10 或 30 秒的刷新间隔。

服务器需提供 Linux 的 `/proc`、`awk` 和 GNU `df`；GPU 指标另需 `nvidia-smi`。没有 GPU 的服务器也可以使用。

## 显示规则

- 菜单栏按 GPU 编号显示利用率；没有 GPU 数据时显示 CPU 使用率。
- 内存已用量按总量减去可用量计算。
- 磁盘统计来自已挂载的本地文件系统，隐藏启动分区、内存盘和容器虚拟文件系统。未挂载磁盘和网络文件系统不计入。
- 连接失败后保留上次数据并标记过期，后续自动重试。
- 服务器列表保存在本机偏好设置中；登录用户、密钥和跳板机等配置由系统 SSH 管理。

## 开发

使用 Swift、SwiftUI 和 AppKit，无第三方依赖。

```sh
./scripts/verify.sh
```

验证涵盖指标解析、磁盘过滤、配置保存和多服务器并发，使用合成数据，无需连接真实服务器。源码位于 `Sources/`，验证位于 `Tests/`。

## 许可证

[MIT](LICENSE)
