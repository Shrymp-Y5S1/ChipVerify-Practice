module reg_map #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 16
)(
    input PCLK,
    input PRESETn,
    // input from APB
    input [ADDR_WIDTH-1:0] PADDR,
    input PSELx,
    input PENABLE,  // 0: setup, 1: access
    input PWRITE,   // 1: write, 0: read
    input [DATA_WIDTH-1:0] PWDATA,
    // input from uart_tx_fifo
    input full_tx,
    // input from uart_rx_fifo
    input [DATA_WIDTH-1:0] rx_dout_fifo,
    input empty_rx,
    // input from uart_tx
    input tx_busy,
    input data_ack,
    // input from uart_rx
    input rx_error,
    input rx_ready,
    input rx_busy,
    // output to uart_tx_fifo
    output reg wr_en,
    output reg [DATA_WIDTH-1:0] tx_din_fifo,
    // output to uart_rx_fifo
    output reg rd_en_rx_fifo,
    // output to baud_generate
    output reg [1:0] clk_freq_index,
    output reg [1:0] baud_rate_index,
    // output to APB
    output reg PREADY,
    output reg [DATA_WIDTH-1:0] PRDATA,
    output reg PSLVERR
);

    // localparam UART_BASE = 32'h4000_1000;

    localparam REG_UART_DATA = 16'h00,
               REG_UART_CTRL = 16'h04,
               REG_UART_STAT = 16'h08,
               REG_UART_INT = 16'h0c;

    reg[DATA_WIDTH-1:0] uart_data_reg;  // TX/RX register, data:[7:0]
    reg[DATA_WIDTH-1:0] uart_ctrl_reg;  // Control register, en:[0], IE:[1], clk_freq_index:[3:2], baud_rate_index:[5:4]
    reg[DATA_WIDTH-1:0] uart_stat_reg;  // Status register, rx_empty:[0], rx_ready:[1], rx_busy:[2], rx_err:[3], tx_full:[4], tx_busy:[5]
    reg[DATA_WIDTH-1:0] uart_int_reg;   // Interrupt register , rx_done:[0], tx_done:[1]

    localparam IDLE = 2'b00,
               SETUP = 2'b01,
               ACCESS = 2'b11;

    reg [1:0] state;

    // Operating states
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)
            state <= IDLE;
        else begin
            case(state)
                IDLE: begin
                    if(PSELx && !PENABLE)
                        state <= SETUP;
                    else
                        state <= IDLE;
                end
                SETUP: begin
                    if(PSELx && PENABLE)
                        state <= ACCESS;
                    else
                        state <= IDLE;
                end
                ACCESS: begin
                    if(PREADY)begin
                        if(PSELx && !PENABLE)
                            state <= SETUP;
                        else
                            state <= IDLE;
                    end else begin
                        state <= ACCESS;
                    end
                end
            endcase
        end
    end

    // PRDATA signal generation
    always @(*)begin
        if((state == ACCESS || state == SETUP)&& !PWRITE)begin
            case(PADDR)
                REG_UART_DATA: PRDATA = uart_data_reg;
                REG_UART_CTRL: PRDATA = uart_ctrl_reg;
                REG_UART_STAT: PRDATA = uart_stat_reg;
                REG_UART_INT:  PRDATA = uart_int_reg;
                default: PRDATA = 0;
            endcase
        end else begin
            PRDATA = 0;
        end
    end

    // PREADY signal generation
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)
            PREADY <= 1;
        else begin
            if(state == ACCESS)begin
                if(PWRITE && (PADDR == REG_UART_DATA) && full)begin
                    PREADY <= 0;
                end else if(!PWRITE && (PADDR == REG_UART_DATA) && empty_rx)begin
                    PREADY <= 0;
                end else begin
                    PREADY <= 1;
                end
            end else begin
                PREADY <= 1;
            end
        end
    end

    // PSLVERR signal generation
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)
            PSLVERR <= 0;
        else begin
            PSLVERR <= 0;
        end
    end

    // UART DATA REGISTER
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)begin
            uart_data_reg <= 0;
        end else begin
            wr_en <= 0;
            rd_en_rx_fifo <= 0;
            if(state == ACCESS)begin
                if(PWRITE && (PADDR == REG_UART_DATA))begin   // write
                    uart_data_reg <= PWDATA;
                    tx_din_fifo <= PWDATA;
                    if(!full_tx)begin
                        wr_en <= 1;
                    end
                end else if(!PWRITE && (PADDR == REG_UART_DATA))begin   // read
                    uart_data_reg <= rx_dout_fifo;
                    if(!empty_rx)begin
                        rd_en_rx_fifo <= 1;
                    end
                end
            end
        end
    end

    // UART CONTROL REGISTER
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)begin
            uart_ctrl_reg <= 0;
        end else if(state == ACCESS)begin
            if(PWRITE && (PADDR == REG_UART_CTRL))begin
                uart_ctrl_reg <= PWDATA;
                clk_freq_index <= PWDATA[3:2];
                baud_rate_index <= PWDATA[5:4];
            end
        end
    end

    // UART STATUS REGISTER
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)begin
            uart_stat_reg <= 0;
        end else begin
            uart_stat_reg[0] <= empty_rx;
            uart_stat_reg[1] <= rx_ready;
            uart_stat_reg[2] <= rx_busy;
            uart_stat_reg[3] <= rx_error;
            uart_stat_reg[4] <= full_tx;
            uart_stat_reg[5] <= tx_busy;
        end
    end

    // UART INTERRUPT REGISTER (Write 1 to Clear)
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)begin
            uart_int_reg <= 0;
        end else begin
            if(rx_ready) uart_int_reg[0] <= 1;
            if(data_ack) uart_int_reg[1] <= 1;
            if((state == ACCESS) && PWRITE && (PADDR == REG_UART_INT))begin
                if(PWDATA[0])uart_int_reg[0] <= 0;   // rx_done
                if(PWDATA[1])uart_int_reg[1] <= 0;   // tx_done
            end
        end
    end

    // address decoding
    // always @(*)begin
    //     case(PADDR)
    //         REG_UART_DATA: begin
    //             if(PWRITE)
    //         end
    //         REG_UART_CTRL: begin
    //             // logic for UART control register
    //         end
    //         REG_UART_STAT: begin
    //             // logic for UART status register
    //         end
    //         REG_UART_INT: begin
    //             // logic for UART interrupt register
    //         end
    //         default: begin
    //             // default case
    //         end
    //     endcase
    // end

endmodule
