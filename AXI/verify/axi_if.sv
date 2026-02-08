`include "axi_define.v"
interface axi_if #(
    parameter ID_WIDTH    = `AXI_ID_WIDTH,
    parameter ADDR_WIDTH  = `AXI_ADDR_WIDTH,
    parameter DATA_WIDTH  = `AXI_DATA_WIDTH,
    parameter LEN_WIDTH   = `AXI_LEN_WIDTH,
    parameter SIZE_WIDTH  = `AXI_SIZE_WIDTH,
    parameter BURST_WIDTH = `AXI_BURST_WIDTH,
    parameter USER_WIDTH  = `AXI_USER_WIDTH,
    parameter MAX_BURST_LEN = 8
)(input clk, input rst_n);

    // --------------------------------------------------------
    // User Interface Signals
    // --------------------------------------------------------
    logic user_req_we; // 1=Write, 0=Read
    logic user_req_valid;
    logic user_req_ready;
    logic [`AXI_ID_WIDTH-1:0] user_req_id;
    logic [`AXI_ADDR_WIDTH-1:0] user_req_addr;
    logic [`AXI_LEN_WIDTH-1:0] user_req_len;
    logic [`AXI_SIZE_WIDTH-1:0] user_req_size;
    logic [`AXI_BURST_WIDTH-1:0] user_req_burst;
    logic [MAX_BURST_LEN*`AXI_DATA_WIDTH-1:0] user_req_wdata;
    logic [MAX_BURST_LEN*(`AXI_DATA_WIDTH/8)-1:0] user_req_wstrb;

    // --------------------------------------------------------
    // AXI Standard Signals
    // --------------------------------------------------------
    // Write Address Channel
    logic [ID_WIDTH-1:0]    awid;
    logic [ADDR_WIDTH-1:0]  awaddr;
    logic [LEN_WIDTH-1:0]   awlen;
    logic [SIZE_WIDTH-1:0]  awsize;
    logic [BURST_WIDTH-1:0] awburst;
    logic                   awvalid;
    logic                   awready;

    // Write Data Channel
    logic [DATA_WIDTH-1:0]  wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                   wlast;
    logic                   wvalid;
    logic                   wready;

    // Write Response Channel
    logic [ID_WIDTH-1:0]    bid;
    logic [1:0]             bresp;
    logic                   bvalid;
    logic                   bready;

    // Read Address Channel
    logic [ID_WIDTH-1:0]    arid;
    logic [ADDR_WIDTH-1:0]  araddr;
    logic [LEN_WIDTH-1:0]   arlen;
    logic [SIZE_WIDTH-1:0]  arsize;
    logic [BURST_WIDTH-1:0] arburst;
    logic                   arvalid;
    logic                   arready;

    // Read Data Channel
    logic [ID_WIDTH-1:0]    rid;
    logic [DATA_WIDTH-1:0]  rdata;
    logic [1:0]             rresp;
    logic                   rlast;
    logic                   rvalid;
    logic                   rready;

    // --------------------------------------------------------
    // SVA (协议检查)
    // --------------------------------------------------------

    // 1. 稳定性检查：当 Valid 拉高但 Ready 为低时，控制信号必须保持稳定
    property p_stable_araddr;
        @(posedge clk) disable iff(!rst_n)
        (arvalid && !arready) |-> $stable({arid, araddr, arlen, arsize, arburst});
    endproperty

    assert_stable_araddr: assert property(p_stable_araddr)
        else $error("AXI Protocol Violation: ARADDR changed while ARVALID is high and ARREADY is low!");

    // 2. 握手检查：不允许出现了 X 态
    property p_valid_no_x;
        @(posedge clk) disable iff(!rst_n)
        !$isunknown(arvalid) && !$isunknown(rvalid);
    endproperty

    assert_valid_no_x: assert property(p_valid_no_x)
        else $error("AXI Protocol Violation: VALID signal has X state!");

    // ----------------------------------------
    // Modport
    // ----------------------------------------
    // Driver 视角的 Modport
    modport DRV (
        input  clk, rst_n, user_req_ready,
        output user_req_we, user_req_valid, user_req_id, user_req_addr, user_req_len,
               user_req_size, user_req_burst, user_req_wdata, user_req_wstrb
    );

endinterface
