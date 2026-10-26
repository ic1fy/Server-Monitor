<h1 align="center">Server Monitor</h1>

<p align="center">在 macOS 菜单栏查看服务器的 GPU、CPU、内存和磁盘使用情况。</p>

## 安装

需要 macOS 14+ 和 Xcode Command Line Tools。

```sh
git clone https://github.com/ic1fy/Server-Monitor.git
cd Server-Monitor
./scripts/build_app.sh
```

将生成的 `outputs/Server Monitor.app` 拖入「应用程序」并打开。

Intel Mac 构建时使用 `SERVER_MONITOR_ARCHS=x86_64 ./scripts/build_app.sh`。

## 使用

1. 确认终端可以通过 `ssh 服务器别名` 免密码连接。
2. 点击菜单栏图标，打开 **「… → 服务器设置」**，添加服务器别名。
3. 点击服务器名称展开或折叠，点击图钉选择菜单栏显示的服务器。

GPU 指标需要服务器安装 `nvidia-smi`。
