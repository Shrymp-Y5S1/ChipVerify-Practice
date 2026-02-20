## python

```python
#!/usr/bin/env python3
import os
import sys

# 配置：需要忽略的文件夹
EXCLUDE_DIRS = {
    'csrc', 'simv.daidir', 'verdiLog', '.git', '.vscode',
    '__pycache__', 'work', 'AN.DB', 'ucli.key'
}

# 配置：需要忽略的文件名
EXCLUDE_FILES = {
    'simv', 'novas.conf', 'novas.rc', '.DS_Store', 'command.log', 'compile.log'
}

# 配置：需要忽略的文件后缀
EXCLUDE_EXTENSIONS = {
    '.fsdb', '.vcd', '.vpd', '.key', '.evcd', '.log'
}

def should_exclude_file(filename):
    if filename in EXCLUDE_FILES:
        return True
    if any(filename.endswith(ext) for ext in EXCLUDE_EXTENSIONS):
        return True
    return False

def print_tree(directory, prefix='', current_depth=0, max_depth=None):
    if max_depth is not None and current_depth >= max_depth:
        return

    try:
        # 获取当前目录下的所有项
        items = os.listdir(directory)
        items.sort()
    except PermissionError:
        return

    # 分离文件夹和文件，并进行过滤
    dirs = []
    files = []

    for item in items:
        path = os.path.join(directory, item)
        if os.path.isdir(path):
            if item not in EXCLUDE_DIRS:
                dirs.append(item)
        else:
            if not should_exclude_file(item):
                files.append(item)

    # 合并列表，文件夹在前（可选，也可以按字母顺序混排）
    # 这里保持混合排序可能更直观，或者将文件夹排前面
    entries = dirs + files
    entries.sort() # 如果希望文件夹和文件混合排序，再次排序；如果希望文件夹置顶，去掉这行

    # 为了逻辑上的清晰，一般树状图也是混合排序的，但这里为了区分，我们还是重新排一下
    # 只要在 dirs 和 files 列表里已经是排好序的就行
    # 这里我们采用：先遍历所有有效的文件夹和文件，按字母顺序处理

    filtered_items = [item for item in items if (os.path.isdir(os.path.join(directory, item)) and item not in EXCLUDE_DIRS) or (os.path.isfile(os.path.join(directory, item)) and not should_exclude_file(item))]
    filtered_items.sort()

    count = len(filtered_items)

    for i, entry in enumerate(filtered_items):
        is_last = (i == count - 1)
        connector = "└── " if is_last else "├── "

        print(f"{prefix}{connector}{entry}")

        path = os.path.join(directory, entry)
        if os.path.isdir(path):
            new_prefix = prefix + ("    " if is_last else "│   ")
            print_tree(path, new_prefix, current_depth + 1, max_depth)

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate directory tree structure")
    parser.add_argument("path", nargs="?", default=".", help="Root directory path to generate tree from")
    parser.add_argument("-L", "--level", type=int, default=None, help="Max recursion depth (level)")

    args = parser.parse_args()

    target_path = os.path.abspath(args.path)

    if not os.path.exists(target_path):
        print(f"Error: Directory '{target_path}' does not exist.")
        sys.exit(1)

    print(target_path)
    print_tree(target_path, max_depth=args.level)
```

> [!note]
>
> ### 使用示例
>
> #### 1. 指定任意根目录（解决你的主要需求）
>
> 你可以生成任意路径的目录树，不再局限于脚本所在位置：
>
> ```shell
> # 生成上一级目录的树
> python3 gen_tree.py ..
> 
> # 生成指定绝度路径的树
> python3 gen_tree.py /home/user/project/APB_UART/design
> ```
>
> #### 2. 指定生成的层级深度
>
> 如果你只想看顶层的 2 级目录结构，不想展开太深：
>
> ```shell
> python3 gen_tree.py . -L 2
> ```
>
> #### 3. 组合使用
>
> 同时指定路径和深度：
>
> ```shell
> python3 gen_tree.py /home/user/project/Architectrue -L 3
> ```
>
> #### 4. 查看帮助
>
> 运行以下命令查看所有可用选项：
>
> ```shell
> python3 gen_tree.py --help
> ```
>
> #### 5. 结果保存
>
> 将结果保存到文件
>
> 在写文档或 README 时，通常需要将目录结构保存下来。你可以利用 Linux 的重定向功能：
>
> ```shell
> # 生成并保存到 project_structure.txt
> python3 gen_tree.py > project_structure.txt
> ```
>
> #### 4. 赋予执行权限 (Linux)
>
> 如果你希望像普通命令一样直接运行它（不需要每次都输 `python3`），可以这样做：
>
> 1. 赋予可执行权限
>
> ```shell
> chmod +x gen_tree.py
> ```
>
> 2. 直接运行
>
> ```shell
> ./gen_tree.py
> ```