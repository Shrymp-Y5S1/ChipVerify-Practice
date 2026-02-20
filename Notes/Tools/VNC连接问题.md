> [!caution]
>
> 如果遇到如下问题：
>
> 通过VNC连接CentOS虚拟机，双击连接依次显示如下内容
>
> ```
> “Connecting to 192.168.66.25:1...”
> 
> “Timed out waiting for a response from the computer”
> ```
>
> 可以成功通过 SSH 登录 `five` 用户，且 `root` 用户的 VNC (`:2`) 也能正常连接
>
> - 连接配置root的“192.168.66.25:2”可以成功连接。
>
> - 另外在vscode成功通过 SSH 登录 `five` 用户
>
> ```bash
> five@192.168.66.25's password: 
> Last login: Thu Feb  5 01:42:12 2026 from 192.168.66.1
> [five@eda1 ~]$ 
> ```

问题大概率出在 **VNC 服务端（CentOS）针对 `:1` (用户 five) 的服务状态** 或 **防火墙的具体端口配置** 上。

请按照以下步骤，在你的 VS Code 终端（已经登录了 `five` 用户）中依次排查：

------

### 第一步：检查 VNC 服务是否在监听 `:1` (端口 5901)

最可能的原因是：虽然你为 `root` 启动了 VNC 服务，但并没有为用户 `five` 启动服务，或者服务启动失败了。

在 VS Code 的终端中，输入以下命令查看端口监听情况：

```Bash
# 如果是 CentOS 7/8，可能需要 sudo 权限或者切换到 root 查看所有端口
sudo netstat -tpln | grep vnc
# 或者使用 ss 命令
sudo ss -tpln | grep vnc
```

**预期结果：**

你应该看到类似这样的输出：

- `0.0.0.0:5902` (对应你的 `:2` root，这个肯定是有的)
- **关键点：** 如果你**没有**看到 `0.0.0.0:5901` 或 `:::5901`，说明针对 `five` 用户的 VNC 服务压根没跑起来。

**解决方法：**

如果是服务没跑起来，请以 `five` 用户身份直接启动它：

1. 切换/确保当前是 `five` 用户。

2. 运行启动命令：

   ```Bash
   vncserver :1
   ```

   *如果提示 `command not found`，说明 VNC 未安装或路径不对，但既然 root 能用，说明已安装。*

   *如果这是第一次运行，它会要求你设置 VNC 密码。*

------

### 第二步：检查防火墙 (Firewall)

如果第一步中你发现 `5901` 端口确实在监听，但依然连接超时，那么大概率是被防火墙拦截了。你可能只开放了 5902，却忘了开放 5901。

在终端中（可能需要 `sudo`）检查防火墙状态：

```Bash
sudo firewall-cmd --list-all
```

查看 `ports` 那一行。

- 如果你看到 `5902/tcp` 但没有 `5901/tcp`，这就是原因。

**解决方法：**

开放 5901 端口：

```Bash
# 开放 5901 端口
sudo firewall-cmd --zone=public --add-port=5901/tcp --permanent

# 重新加载防火墙配置使其生效
sudo firewall-cmd --reload
```

------

### 第三步：检查 VNC 密码配置

如果服务启动了，端口也开了，但连接时瞬间断开或提示其他错误（虽然你是超时，但也值得检查），确认 `five` 用户是否配置了 VNC 密码。

**解决方法：**

在 `five` 用户的终端下重置一次密码：

```Bash
vncpasswd
```

按提示输入并确认密码，View-only password 可以选 `n`。

------

### 第四步：检查是否有僵尸进程 (Stale Process)

有时候，上次非正常退出会留下锁文件 (Lock file)，导致 VNC 认为 `:1` 正在运行，但实际没法响应。

**解决方法：**

1. **杀掉进程：**

   ```Bash
   vncserver -kill :1
   ```

   *如果提示 "Can't find file..." 说明本来就没跑。*

2. **清理（可选，如果上面杀不掉）：**

   检查 `/tmp/.X11-unix/` 和 `/tmp/.X1-lock` 文件并手动删除（小心操作）。

3. **重新启动：**

   ```Bash
   vncserver :1 -geometry 1920x1080
   # -geometry 后面的分辨率可以根据你屏幕调整
   ```

------

### 总结建议

既然你在 SSH 里已经登录了 `five` 用户，我建议你直接执行以下“组合拳”：

1. 先杀掉旧进程（以防卡死）：`vncserver -kill :1`
2. 手动启动新进程：`vncserver :1`
3. 看一眼日志输出，确保没有报错。
4. 再尝试用 VNC Viewer 连接 `192.168.66.25:1`。