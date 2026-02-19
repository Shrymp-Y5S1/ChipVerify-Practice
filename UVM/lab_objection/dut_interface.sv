// 接口定义
interface dut_interface (
    input bit clk
);

  // 信号声明
  logic        rst_n;
  logic [15:0] din;
  logic [15:0] frame_n;
  logic [15:0] valid_n;
  logic [15:0] dout;
  logic [15:0] busy_n;
  logic [15:0] valido_n;
  logic [15:0] frameo_n;

  // 时钟域定义
  // 驱动时钟域
  clocking driver_cb @(posedge clk);
    // 默认输入延迟为1周期，输出无延迟
    default input #1 output #0;
    output rst_n;  // 方向：Driver -> 输出 -> DUT
    output frame_n;  // 方向：Driver -> 输出 -> DUT
    output valid_n;  // 方向：Driver -> 输出 -> DUT
    output din;  // 方向：Driver -> 输出 -> DUT
    input busy_n;  // 方向：DUT -> 输入 -> Driver (Driver 只能读取/等待这个信号)
  endclocking
  // 输入监视时钟域clocking block
  clocking i_monitor_cb @(posedge clk);
    // 默认输入延迟为1周期，输出无延迟
    default input #1 output #0;
    input frame_n;
    input valid_n;
    input din;
    input busy_n;
  endclocking
  // 输出监视时钟域
  clocking o_monitor_cb @(posedge clk);
    // 默认输入延迟为1周期，输出无延迟
    default input #1 output #0;
    input dout;
    input valido_n;
    input frameo_n;
  endclocking

  // 模块接口定义
  // 定义modport，指定每个时钟域中哪些信号是输入，哪些是输出
  // 驱动modport，指定driver_cb时钟域中的rst_n信号为输出
  modport driver(clocking driver_cb,
      output rst_n
  );  // clocking用于指定时钟域，output用于指定信号方向
  // 输入监视modport，指定i_monitor_cb时钟域中的信号为输入
  modport i_monitor(clocking i_monitor_cb);
  // 输出监视modport，指定o_monitor_cb时钟域中的信号为输入
  modport o_monitor(clocking o_monitor_cb);

endinterface
