module reg_map #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 8,   // 8/16/32 bits wide
    parameter WAIT_STATES = 0   // 0: no wait states, 1: wait state
)(
    // input from APB
    input PCLK,
    input PRESETn,
    input [ADDR_WIDTH-1:0] PADDR,
    input PSELx,    // slave select
    input PENABLE,
    input PWRITE,   // 1: write, 0: read
    input [DATA_WIDTH-1:0] PWDATA,

    // input from uart_tx_fifo
    input full_tx_fifo,
    input [ADDR_WIDTH:0] cnt_tx_fifo,

    // input from uart_rx_fifo
    input [DATA_WIDTH-1:0] dout_rx_fifo,
    input empty_rx_fifo,
    input [ADDR_WIDTH:0] cnt_rx_fifo,

    // input from uart_tx
    input tx_busy,
    input tx_ready,

    // input from uart_rx
    input rx_error,
    input rx_ready,
    input rx_busy,

    // output to APB
    output reg PREADY,
    output reg [DATA_WIDTH-1:0] PRDATA,
    output reg PSLVERR,

    // output to uart_sys
    output reg en_sys,

    // output to baud_generate
    output reg [1:0] clk_freq_index,
    output reg [2:0] baud_rate_index,

    // output to uart_tx_fifo
    output reg [DATA_WIDTH-1:0] din_tx_fifo,
    output reg wr_en_tx_fifo,
    output reg dma_tx_req,

    // output to uart_rx_fifo
    output reg rd_en_rx_fifo,
    output reg dma_rx_req,

    // output to uart_tx
    output reg tx_en
);

    // localparam UART_BASE = 32'h4000_1000;

    localparam REG_UART_DATA = 4'h0,
               REG_UART_CTRL = 4'h4,
               REG_UART_STAT = 4'h8,
               REG_UART_INT = 4'hc;

    reg[DATA_WIDTH-1:0] uart_data_reg;  // Data register, data:[7:0]
    reg[DATA_WIDTH-1:0] uart_ctrl_reg;  // Control register, en_sys:[0], IE:[1], clk_freq_index:[3:2], baud_rate_index:[6:4], tx_en:[7]
    reg[DATA_WIDTH-1:0] uart_stat_reg;  // Status register, rx_empty:[0], rx_ready:[1], rx_busy:[2], rx_err:[3], tx_full:[4], tx_ready:[5], tx_busy:[6]
    reg[DATA_WIDTH-1:0] uart_int_reg;   // Interrupt register , rx_done:[0], tx_done:[1]

    reg add_error;

    // PREADY
    always @(*)begin
        if(!WAIT_STATES)
            PREADY = 1;
        else begin
            if(PWRITE && (PADDR == REG_UART_DATA) && full_tx_fifo)
            PREADY = 0;
        else
            PREADY = 1;
        end
    end

    wire valid_write = PSELx && PENABLE && PWRITE && PREADY;
    wire valid_read  = PSELx && PENABLE && !PWRITE && PREADY;

    // PSLVERR
    always @(*)begin
        if(rx_error)    // pulse error signal
            PSLVERR = 1;
        else if(add_error) begin
            PSLVERR = 1;
        end else if(empty_rx_fifo && !PWRITE && (PADDR == REG_UART_DATA)) begin
            PSLVERR = 1;
            // ... other error conditions can be added here
        end else
            PSLVERR = 0;
    end

    // PRDATA
    always @(*)begin
        if(valid_read)begin
            case(PADDR)
                REG_UART_DATA: begin
                    if(!empty_rx_fifo) begin
                        PRDATA = dout_rx_fifo;
                        rd_en_rx_fifo = 1;
                    end else begin
                        PRDATA = 8'hff;
                        rd_en_rx_fifo = 0;
                    end
                end
                REG_UART_CTRL: PRDATA = uart_ctrl_reg;
                REG_UART_STAT: PRDATA = uart_stat_reg;
                REG_UART_INT: PRDATA = uart_int_reg;
                default: PRDATA = 0;
            endcase
        end else begin
            PRDATA = 0;
            rd_en_rx_fifo = 0;
        end
    end

    // data register write operation
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn) begin
            uart_data_reg <= 0;
            din_tx_fifo <= 0;
            wr_en_tx_fifo <= 0;
        end else begin
            wr_en_tx_fifo <= 0;
            if(valid_write && (PADDR == REG_UART_DATA)) begin
                uart_data_reg <= PWDATA;
                din_tx_fifo <= PWDATA;
                wr_en_tx_fifo <= 1;
            end else begin
                din_tx_fifo <= 0;
                wr_en_tx_fifo <= 0;
            end
        end
    end

    // control registers write operation
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn) begin
            uart_ctrl_reg <= 0;
            en_sys <= 0;
            clk_freq_index <= 0;
            baud_rate_index <= 0;
            tx_en <= 0;
        end else if(valid_write && (PADDR == REG_UART_CTRL)) begin
            uart_ctrl_reg <= PWDATA;
            en_sys <= PWDATA[0];
            clk_freq_index <= PWDATA[3:2];
            baud_rate_index <= PWDATA[6:4];
            tx_en <= PWDATA[7];
        end
    end

    // status register update
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn) begin
            uart_stat_reg <= 0;
        end else begin
            uart_stat_reg[0] <= empty_rx_fifo;    // rx_empty
            uart_stat_reg[1] <= rx_ready;         // rx_ready
            uart_stat_reg[2] <= rx_busy;          // rx_busy
            uart_stat_reg[3] <= rx_error;         // rx_err
            uart_stat_reg[4] <= full_tx_fifo;     // tx_full
            uart_stat_reg[5] <= tx_ready;         // tx_ready
            uart_stat_reg[6] <= tx_busy;          // tx_busy
        end
    end

    // interrupt register (write 1 to clear)
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn) begin
            uart_int_reg <= 0;
        end else if(uart_ctrl_reg[1])begin
            if(rx_ready) uart_int_reg[0] <= 1;   // rx_done
            if(tx_ready) uart_int_reg[1] <= 1;   // tx_done
            if(valid_write && (PADDR == REG_UART_INT)) begin
                if(PWDATA[0]) uart_int_reg[0] <= 0;   // rx_done
                if(PWDATA[1]) uart_int_reg[1] <= 0;   // tx_done
            end
        end else begin
            uart_int_reg <= 0;
        end
    end

    // DMA request signals
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn) begin
            dma_tx_req <= 0;
            dma_rx_req <= 0;
        end else begin
            dma_tx_req <= cnt_tx_fifo <= (1 << (ADDR_WIDTH-1)) && tx_en;   // half full
            dma_rx_req <= cnt_rx_fifo >= (1 << (ADDR_WIDTH-1));   // half full
        end
    end

    // add_error
    always @(*)begin
        add_error = (PADDR != REG_UART_DATA) &&
                    (PADDR != REG_UART_CTRL) &&
                    (PADDR != REG_UART_STAT) &&
                    (PADDR != REG_UART_INT);
    end

endmodule
