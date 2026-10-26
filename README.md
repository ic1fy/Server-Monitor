# Server Monitor

在 macOS 菜单栏查看 Linux 服务器的 GPU、CPU、内存和磁盘使用情况。通过 SSH 连接，可同时监测多台服务器，无需安装服务器端代理。

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

点击服务器名称可折叠面板，点击图钉可选择菜单栏显示的服务器。GPU 指标需要服务器上的 `nvidia-smi`，没有 GPU 的服务器也可以使用。
