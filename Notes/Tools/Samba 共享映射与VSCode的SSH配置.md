## Samba 共享映射

> **Windows 编写 + Linux 仿真** 
>
> 在不降低vscode版本的前提下，避开新版 VS Code Server导致的无法通过Remote SSH连接过旧的CentOS7的问题
>
> 不让 VS Code 运行在 Linux 上，而是让它运行在 Windows 上。通过网络共享协议（SMB），把你 Linux 虚拟机里的文件夹，映射成 Windows 的一个磁盘（比如 `Z:` 盘）。

![image-20260114195119109](./Windows与Linux文件互通.assets/image-20260114195119109.png)

- **VS Code 功能全开：** 因为 VS Code 是在 Windows 本地跑的，Copilot、最新插件、主题全部能用，**完全不受 Linux 版本限制**。

- **文件实时同步：** 你在 Windows 修改保存，Linux 里瞬间生效。

- **EDA 环境稳定：** VCS 依然在老旧稳定的 CentOS 7 里跑。

> [!note]
>
> 非常理解！这实际上是 IC 行业目前面临的一个**非常典型的“代沟”问题**：
>
> - **前端需求**：想要用最新的 IDE（VS Code + Copilot + AI 插件）来提高写代码的效率。
> - **后端现状**：EDA 工具（VCS, Verdi, Synopsys全家桶）为了稳定性，死守着古老的 Linux 发行版（CentOS 7 / RHEL 7），其底层库（glibc 2.17）根本跑不动新版 VS Code Server。
>
> 既不降级本地 VS Code，又要流畅开发，**工业界目前最成熟、被广泛使用的替代方案是：**
>
> ### **方案：Samba 共享映射 + 本地 VS Code**
>
> 这是目前在许多大厂（为了规避服务器环境过旧问题）非常流行的**“存算分离”**模式。
>
> - **核心思路：** 不让 VS Code 运行在 Linux 上，而是让它运行在 Windows 上。通过网络共享协议（SMB），把你 Linux 虚拟机里的文件夹，映射成 Windows 的一个磁盘（比如 `Z:` 盘）。
> - **你的收益：**
>   - **VS Code 功能全开：** 因为 VS Code 是在 Windows 本地跑的，Copilot、最新插件、主题全部能用，**完全不受 Linux 版本限制**。
>   - **文件实时同步：** 你在 Windows 修改保存，Linux 里瞬间生效。
>   - **EDA 环境稳定：** VCS 依然在老旧稳定的 CentOS 7 里跑。
>
> ------
>
> ### **具体实施步骤（保姆级教程）**
>
> #### 第一步：在 Linux 虚拟机配置 Samba 服务
>
> 你需要把 Linux 的文件夹“共享”出来。在你的 CentOS 7 终端里执行：
>
> 1. **安装 Samba：**
>
>    ```Bash
>    sudo yum install samba samba-client samba-common
>    ```
>
> 2. 配置共享文件夹：
>
>    先备份配置文件，然后编辑：
>
>    ```Bash
>    sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
>    sudo vim /etc/samba/smb.conf
>    ```
>
>    在文件末尾添加以下内容（假设你的用户名叫 `user`，你想共享整个家目录）：
>
>    ```Ini, TOML
>    [IC_Project]
>    path = /home/user/RTL_Practice
>    browseable = yes
>    writable = yes
>    valid users = user
>    create mask = 0664
>    directory mask = 0775
>    ```
>
> 3. **设置 Samba 密码（不是系统登录密码，可以设一样的）：**
>
>    ```Bash
>    sudo smbpasswd -a user
>    ```
>
> 4. **启动服务并关闭防火墙（虚拟机环境建议直接关防火墙）：**
>
>    ```Bash
>    sudo systemctl start smb
>    sudo systemctl enable smb
>    sudo systemctl stop firewalld
>    sudo systemctl disable firewalld
>    ```
>
> #### 第二步：在 Windows 映射网络驱动器
>
> 1. 确保 Windows 和 Linux 能 `ping` 通（你之前配置过 VMnet8，应该没问题）。
> 2. 打开 Windows 的“文件资源管理器” -> “此电脑” -> 顶部点击 **“... (查看更多)”** -> **“映射网络驱动器”**。
> 3. **驱动器：** 选一个顺眼的，比如 `Z:`。
> 4. **文件夹：** 输入 `\\你的虚拟机IP\IC_Project` （例如 `\\192.168.66.25\IC_Project`）。
> 5. 点击完成，输入刚才设置的 Samba 账号密码。
> 6. 现在，你会发现你的电脑多了一个 `Z:` 盘，里面的文件就是你虚拟机里的文件！
>
> > [!caution]
> >
> > ==先开虚拟机，等会再开 Windows Z 盘。==
> >
> > 当将虚拟机关闭，再次打开发现无法连接映射网络驱动器，可以尝试如下操作：
> >
> > 在Windows的cmd执行以下命令
> >
> > **把旧的记录强制清除**
> >
> > ```dos
> > net use * /delete
> > ```
> >
> > 在 Linux 终端依次执行以下 3 条命令
> >
> > 1. **确认 Samba 服务活着**：
> >
> > ```Bash
> > sudo systemctl restart smb
> > ```
> >
> > *（没有任何报错提示就是最好的消息）*
> >
> > 2. **关闭防火墙（最常见原因）**：
> >
> > - CentOS 7 默认防火墙会拦截 Samba，Ping 能通是因为它允许 ICMP 协议，但它不一定允许 SMB 协议。
> >
> > ```bash
> > sudo systemctl stop firewalld
> > ```
> >
> > 3. **临时关闭 SELinux** ：
> >
> > - 如果你看到了“**拒绝访问**”或**输入密码后进不去**，通常是它的锅。
> >
> > ```bash
> > sudo setenforce 0
> > ```
>
> #### 第三步：VS Code 打开与开发
>
> 1. 打开你本地**最新版**的 VS Code。
> 2. `File` -> `Open Folder` -> 选择 `Z:` 盘里的文件夹。
> 3. **开始写代码！** Copilot 正常工作，语法高亮正常工作。
>
> ------
>
> ### **至关重要的避坑指南**
>
> 使用这种方式，有两个超级大坑，请务必注意：
>
> #### 1. 换行符问题 (CRLF vs LF) —— **导致 VCS 报错的元凶**
>
> - **问题：** Windows 的换行符是 `\r\n` (CRLF)，Linux 是 `\n` (LF)。如果你在 Windows 上保存文件，默认带入 CRLF，VCS 读到这个会报错或识别乱码。
>
> - **解决：** 配置 VS Code 强制使用 Linux 风格。
>
>   - 打开 VS Code 设置 -> 搜索 `eol` (End of Line)。
>
>   - 将 **Files: Eol** 设置为 **`\n`** (LF)。
>
>   - 或者在 VS Code 扩展商店搜索并安装 **EditorConfig for VS Code**（图标是一个老鼠），并在你的项目根目录新建 `.editorconfig` 文件，写入：
>
>     ```Ini, TOML
>     # 这是一个顶级配置文件，停止向上查找
>     root = true
>         
>     # 【核心规则】匹配所有文件
>     [*]
>     charset = utf-8
>     indent_style = space
>     indent_size = 4
>     end_of_line = lf              # <--- 强制使用 Linux 换行符，解决 VCS 问题
>     insert_final_newline = true   # 文件末尾自动加空行（VCS 喜欢这个）
>     trim_trailing_whitespace = true # 自动删除行尾多余空格
>         
>     # 【例外规则】匹配 .bat 批处理文件
>     [*.bat]
>     end_of_line = crlf            # <--- 只有 .bat 文件保持 Windows 风格
>     ```
>
> #### 2. 终端怎么跑仿真？
>
> 虽然代码在 Windows 写，但仿真命令（`vcs ...`）还是得在 Linux 跑。
>
> - **推荐方式：** 在 VS Code 里，不要用默认的 PowerShell 终端。
> - 操作： 1. 确保 Windows 安装了 Git (自带 Git Bash) 或者开启了 SSH 客户端。
>   2. 在 VS Code 终端里直接输入 ssh user@192.168.66.25。
>   3. 这样你就拥有了一个内嵌在 VS Code 里的 Linux 终端。
>   4. 工作流： 上面窗口写代码（Win），下面终端窗口敲命令（Linux），左手画圆右手画方，效率极高。
>
> ------
>
> ### **总结你的新工作流**
>
> 1. **文件管理：** 通过 **Samba** 映射，在 Windows 本地管理文件。
> 2. **代码编写：** 使用 **本地 VS Code (v1.108)** + **Copilot** 编辑 `Z:` 盘文件。
> 3. **代码提交：** 建议在 **VS Code 的 SSH 终端**里用命令行 `git add/commit`（这样能确保文件权限和换行符不出错）。
> 4. **仿真验证：** 在 **VS Code 的 SSH 终端**里运行 `make vcs`。
> 5. **波形调试：** 使用 **RealVNC** 打开 Linux 桌面，查看 Verdi 波形。
>
> **这个方案完美绕过了 glibc 的版本限制，既保住了你的 AI 辅助功能，又保住了 EDA 工具的稳定性。你想现在就开始尝试配置 Samba 吗？**

## VSCode terminal 的SSH配置

> [!note]
>
> 这是一个能够极大提升你“Samba + VS Code”模式开发体验的关键配置。
>
> 配置的目标是：**打开 VS Code 时，不需要手动敲 SSH 命令，终端自动连上你的 Linux 虚拟机，且最好不需要每次都输密码。**
>
> 我们将分三个阶段来完成这个配置，从“能用”到“好用”。
>
> ------
>
> ### 第一阶段：最简单的手动连接（先跑通）
>
> 这是你现在立刻就能用的方式，确认 Windows 本身支持 SSH。
>
> 1. 在 VS Code 界面，按下快捷键 **`Ctrl + ~`** （也就是 `Esc` 下面那个波浪号键），或者点击顶部菜单 **查看 (View) -> 终端 (Terminal)**。
>
> 2. 底部会弹出一个面板，默认通常是 PowerShell。
>
> 3. 在里面直接输入以下命令（根据你之前的截图，用户是 `five`，IP 是 `192.168.66.25`）：
>
>    PowerShell
>
>    ```
>    ssh five@192.168.66.25
>    ```
>
> 4. 输入密码。
>
> 5. **成功标志：** 如果光标前的提示符从 `PS C:\Users\xxx>` 变成了 `[five@localhost ~]$`，恭喜你，你已经成功在 VS Code 里“遥控”了 Linux。
>
> ------
>
> ### 第二阶段：配置 VS Code 自动化 Profile（一键连接）
>
> 每次都敲命令太麻烦了。我们可以利用 VS Code 的 **Terminal Profiles** 功能，把这个 SSH 连接做成一个“内置选项”。
>
> 1. 在 VS Code 中，点击左下角 **齿轮图标 -> 设置 (Settings)**。
> 2. 点击右上角的 **“打开设置(json)”图标**（看起来像一张纸上有一个弯箭头 `{}`）。
> 3. 在 `settings.json` 文件的**大括号 `{ ... }` 内部**，添加以下代码（注意：如果上面还有其他设置，记得在上一行末尾加个逗号 `,`）：
>
> ```json
>     "terminal.integrated.profiles.windows": {
>         "CentOS7-SSH": {
>             "path": "C:\\Windows\\System32\\OpenSSH\\ssh.exe",
>             "args": [
>                 "five@192.168.66.25"
>             ],
>             "icon": "terminal-linux"
>         }
>     },
>     // 可选：设置它为默认启动终端
>     "terminal.integrated.defaultProfile.windows": "CentOS7-SSH"
> ```
>
> 配置完后的效果：
>
> 以后你点击终端面板右上角的 + 号旁边的下拉箭头，就会看到一个名为 CentOS7-SSH 的选项。一点它，VS Code 就会直接帮你执行 SSH 命令。
>
> ------
>
> ### 第三阶段：配置 SSH 免密登录（终极形态）
>
> 现在虽然自动连接了，但还要输密码。对于高频的编译操作（`make run`），输密码会让你崩溃。我们需要打通 **Windows -> Linux** 的 SSH 密钥认证。
>
> **注意：** 这次是在 **Windows (PowerShell)** 下生成密钥，发给 Linux。
>
> #### 1. 在 Windows 生成密钥
>
> 打开你刚才配置好的 VS Code 终端（确认为 PowerShell 状态，或者新开一个），输入：
>
> ```PowerShell
> ssh-keygen -t ed25519
> ```
>
> - 一路回车（不要设密码），直到生成完成。
>
> #### 2. 将公钥发送给 Linux
>
> Windows 默认没有 `ssh-copy-id` 命令，我们需要用一点“笨办法”把公钥内容贴过去。
>
> - 第一步：获取 Windows 的公钥内容
>
>   在 PowerShell 里输入：
>
>   ```PowerShell
>   type $env:USERPROFILE\.ssh\id_ed25519.pub
>   ```
>
>   **复制** 输出的那一串以 `ssh-ed25519` 开头的字符。
>
> - 第二步：粘贴到 Linux
>
>   使用你刚才配置好的 SSH 终端登录到 Linux (ssh five@192.168.66.25)，然后执行：
>
>   ```bash
>   mkdir -p ~/.ssh
>   chmod 700 ~/.ssh
>   vim ~/.ssh/authorized_keys
>   ```
>
>   - 按 `i` 进入编辑模式。
>
>   - **粘贴** 你刚才在 Windows 复制的那串字符。
>
>   - 按 `Esc`，输入 `:wq` 保存退出。
>
>   - **关键权限设置（必须做）：**
>
>     ```Bash
>     chmod 600 ~/.ssh/authorized_keys
>     ```
>
> ------
>
> ### 最终验收
>
> 关掉 VS Code，重新打开。
>
> 1. 按下 `Ctrl + ~`。
>
> 2. 如果一切配置正确，你应该不需要输入任何命令，也不需要输入任何密码，终端提示符直接显示为：
>
>    [five@localhost ~]$
>
> **此时，你的工作流是这样的：**
>
> - **上半部分窗口：** 编辑代码（Windows 本地，享用 Copilot）。
> - **下半部分窗口：** 编译/Git（Linux 远程，享用 VCS 环境）。
>
> **现在去试试配置这个“第三阶段”，成功后告诉我，我们就可以进行 Git 的上传操作了！**

## 关闭虚拟机后