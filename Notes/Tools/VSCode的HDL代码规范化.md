# SystemVerilog and Verilog Formatter 插件

在 `settings.json` 添加如下内容：

```json
"systemverilogFormatter.commandLineArguments": "--indentation_spaces 2 --column_limit 100 --try_wrap_long_lines --failsafe_success --assignment_statement_alignment align --module_net_variable_alignment align --named_port_alignment align --port_declarations_alignment align --named_parameter_alignment align --formal_parameters_alignment align --case_items_alignment align --enum_assignment_statement_alignment align --class_member_variable_alignment align --struct_union_members_alignment align --wrap_end_else_clauses --named_parameter_indentation indent --named_port_indentation indent --port_declarations_indentation indent",
"[verilog]": {
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.wordWrap": "on",
    "editor.defaultFormatter": "bmpenuelas.systemverilog-formatter-vscode"
},
"[systemverilog]": {
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.wordWrap": "on",
    "editor.defaultFormatter": "bmpenuelas.systemverilog-formatter-vscode"
},
```

#### A. 基础排版 (Basic Layout)

- **缩进**: 2 空格 (`--indentation_spaces 2`)
- **行宽**: 100 字符，超长自动折行 (`--column_limit 100`, `--try_wrap_long_lines`)
- **流控**: `else` 强制换行，形成 `end` / `else` / `begin` 阶梯状 (`--wrap_end_else_clauses`)

#### B. 核心对齐 (Core Alignment)

- **赋值**: 对齐 `=` 或 `<=` (`--assignment_statement_alignment`)
- **变量**: 对齐 `wire`/`reg` 定义 (`--module_net_variable_alignment`)
- **端口**: 对齐模块 **声明** 与 **实例化** 时的端口 (`--port_declarations_alignment`, `--named_port_alignment`)
- **参数**: 对齐 `parameter` **定义** 与 **实例化** 时的赋值 (`--formal_parameters_alignment`, `--named_parameter_alignment`) 

#### C. 高级对齐 (Advanced Alignment)

- **Case 语句**: 对齐 `case` 分支的冒号 `:` (`--case_items_alignment`) 
- **数据结构**: 对齐 `enum`、`struct`、`union` 及 `class` 成员定义 (`--enum...`, `--struct...`, `--class...`) 

#### D. 安全机制 (Safety)

- **容错**: 即使解析报错也尝试输出，且不破坏原文件 (`--failsafe_success`)

> [!caution]
>
> 对于使用在 **延时符号#** 后的值，**不能使用 macro**，只能通过 **localparam / parameter** 来维护，否则格式化器会输出类似：**syntax error at token "`DLY "**