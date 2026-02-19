module tb_top;

  bit sys_clk;

  dut_interface if0 (sys_clk);

  router dut (
      .clk     (if0.clk),
      .rst_n   (if0.rst_n),
      .din     (if0.din),
      .frame_n (if0.frame_n),
      .valid_n (if0.valid_n),
      .dout    (if0.dout),
      .busy_n  (if0.busy_n),
      .valido_n(if0.valido_n),
      .frameo_n(if0.frameo_n)
  );

  initial begin
    sys_clk = 1'b0;
    forever begin
      #10 sys_clk = ~sys_clk;
    end
  end

  initial begin
    // 注意uvm_test_top是UVM的默认顶层组件名称，无论你的 Test 类叫什么名字（my_test, base_test, sanity_test），UVM 都会把这个最顶层的实例命名为 "uvm_test_top"。
    uvm_config_db#(virtual dut_interface)::set(null, "uvm_test_top", "top_if", if0);
    run_test();
  end

  initial begin
    $fsdbDumpfile(tb_top.fsdb);
    $fsdbDumpvars(0, tb_top);
  end


endmodule
