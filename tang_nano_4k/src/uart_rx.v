//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
// Modified by Manzel Seet (zst123)
//////////////////////////////////////////////////////////////////////
// This file contains the UART Receiver.  This receiver is able to
// receive 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When receive is complete o_rx_dv will be
// driven high for one clock cycle.
// 
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
module uart_rx #(
    parameter CLOCK_RATE = 100000000,
    parameter BAUD_RATE = 9600
)(
    input        i_CLK,
    input        i_RX,
    output       o_READY,
    output [7:0] o_DATA
);
    
    // Bit cycles
    localparam CLKS_PER_BIT = CLOCK_RATE / BAUD_RATE;
    
    // States
    localparam STATE_IDLE = 4'h0;
    localparam STATE_START = 4'h1;
    localparam STATE_DATA = 4'h2;
    localparam STATE_STOP = 4'h3;
    
    // Variables
    reg [3:0] state = STATE_IDLE;
    reg [15:0] delay_count = 0;
    reg [3:0] data_index = 0;
    
    // Output registers
    reg       r_READY = 0;
    reg [7:0] r_DATA = "X";
    assign o_DATA = r_DATA;
    assign o_READY = r_READY;
    
    // Fix metastability issue (sampling of external slower-clocked signal with a faster clock)
    // https://zipcpu.com/blog/2017/10/20/cdc.html 
    reg r_RX = 1;
    reg [9:0] xfer_pipe;
    always @(posedge i_CLK) begin
        { r_RX, xfer_pipe } <= { xfer_pipe, i_RX };
    end

    always @(posedge i_CLK) begin
        case (state)
            STATE_IDLE: begin
                // Reset to idle
                r_READY <= 0;
                delay_count <= 0;
                data_index <= 0;
                
                // Wait until start bit (falling edge)
                if (r_RX == 1'b0) begin
                    state <= STATE_START;
                end else begin
                    state <= STATE_IDLE;
                end
            end
            STATE_START: begin
                if (delay_count < (CLKS_PER_BIT/2)) begin
                    // Wait for half a clock so that we start sampling in the middle point
                    delay_count <= delay_count + 16'd1;
                end else begin
                    delay_count <= 0;
                    // Check that the line is still valid before continuing
                    if (r_RX == 1'b0) begin
                        state <= STATE_DATA;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end
            end
            STATE_DATA: begin
                if (delay_count < CLKS_PER_BIT) begin
                    // Wait one clock before sampling
                    delay_count <= delay_count + 1;
                end else if (delay_count == CLKS_PER_BIT) begin
                    if (data_index < 7) begin
                        r_DATA[data_index] <= r_RX;
                    end
                    delay_count <= delay_count + 1;
                end else begin
                    delay_count <= 0;
                    if (data_index < 7) begin
                        data_index <= data_index + 1;
                    end else begin
                        state <= STATE_STOP;
                    end
                end
            end
            STATE_STOP: begin
                if (delay_count < CLKS_PER_BIT) begin
                    // Wait one more clock for the Stop bit
                    delay_count <= delay_count + 1;
                end else begin
                    // Wait until stop bit (rising edge)
                    r_READY = 1'b1;
                    if (r_RX == 1'b1) begin
                        state <= STATE_IDLE;
                    end
                end
            end
        endcase // case (state)
    end // always @(posedge i_CLK) 
endmodule // uart_rx
