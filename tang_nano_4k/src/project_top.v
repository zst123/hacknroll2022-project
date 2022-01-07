module project_top (
    input SYS_CLK,
    input uart_rxd,
    output antenna,
    output reg led
);

    //-------- Clock --------//
    // External oscillator + PLL
    wire CLK_159MHz;
    wire CLK_27MHz;
    assign CLK_27MHz = SYS_CLK;
    Gowin_PLLVR your_instance_name(
        .clkout(CLK_159MHz), //output clkout
        .clkin(CLK_27MHz) //input clkin
    );

    //-------- LED --------//
    reg [31:0] counter;
    always @(posedge CLK_159MHz) begin
        if (counter < (32'd159_000_000)) begin // 1s delay
            counter <= counter + 1;
        end else begin
            counter <= 32'd0;
            led <= ~led;
        end
    end

    //-------- Block RAM --------//
    reg bram_enable_wr = 0;
    reg [9:0] bram_addr_wr = 0;
    reg [300-1:0] bram_data_wr = 0;
    
    reg [9:0] bram_addr_rd = 0;
    wire [400-1:0] bram_data_rd;

    bram bram_inst1 (
        .clk(CLK_27MHz),
        .enable_wr(bram_enable_wr),
        .addr_wr(bram_addr_wr),
        .bram_data_wr(bram_data_wr),
        .addr_rd(bram_addr_rd),
        .bram_data_rd(bram_data_rd)
    );



    //-------- UART State Machine --------//
    // # reset to line 1
    // + increment line
    // 0-9a-f store hex values and increment index
    wire [7:0] uart_data;
    wire       uart_ready;

    uart_rx #(
        .CLOCK_RATE(27_000_000),
        .BAUD_RATE(2200000)
        //.BAUD_RATE(115200)
    ) uart_m_instance (
        .i_CLK(CLK_27MHz),
        .i_RX(uart_rxd),
        .o_READY(uart_ready),
        .o_DATA(uart_data)
    );

    parameter UART_LINES = 304*2; // Vertical lines
    parameter UART_PIXELS = 300; // Horizontal pixels
    reg [UART_PIXELS-1:0] uart_buffer[UART_LINES-1:0];
    reg [9:0] uart_line_index = 10'h00;
    reg [9:0] uart_pixel_index = 10'h00;
    reg [1:0] uart_state = 0;

    function [3:0] hex2bits;
        input [7:0] hexstr;
        begin
            case(hexstr)
                "0": hex2bits = 4'h0;
                "1": hex2bits = 4'h1;
                "2": hex2bits = 4'h2;
                "3": hex2bits = 4'h3;
                "4": hex2bits = 4'h4;
                "5": hex2bits = 4'h5;
                "6": hex2bits = 4'h6;
                "7": hex2bits = 4'h7;
                "8": hex2bits = 4'h8;
                "9": hex2bits = 4'h9;
                "A": hex2bits = 4'hA;
                "B": hex2bits = 4'hB;
                "C": hex2bits = 4'hC;
                "D": hex2bits = 4'hD;
                "E": hex2bits = 4'hE;
                "F": hex2bits = 4'hF;
                default: hex2bits = 4'h0;
            endcase
        end
    endfunction

    always @(posedge CLK_27MHz) begin
        if (uart_state == 0) begin
            // Wait until data is ready
            if (uart_ready) begin
                /* Handle chars */
                if (uart_data == "#") begin
                    uart_line_index <= 0;
                    uart_pixel_index <= 0;
                    bram_data_wr <= 0; // Reset pending data
                    bram_enable_wr <= 0;
                end else if (uart_data == "+") begin
                    if (uart_line_index < UART_LINES) begin
                        uart_line_index <= uart_line_index + 1;
                    end else begin
                        uart_line_index <= 0;
                    end
                    uart_pixel_index <= 0;
                    bram_data_wr <= 0; // Reset pending data
                    bram_enable_wr <= 0;
                end else begin
                    bram_addr_wr <= uart_line_index;
                    bram_data_wr <= bram_data_wr | (hex2bits(uart_data) << ((uart_pixel_index-1)*4));
                    bram_enable_wr <= 1; // Write while waiting as current byte is stable
                end
                uart_state <= 1;
            end
        end else begin
            // Wait until next byte is coming in
            if (!uart_ready) begin
                bram_enable_wr <= 0; // Next byte is coming in, stop writing 
                uart_state <= 0;
                if (uart_pixel_index <= uart_pixel_index) begin 
                    uart_pixel_index <= uart_pixel_index + 1;
                end else begin
                    uart_pixel_index <= 0;
                end
            end
        end
    end

    //-------- PWM generator --------//
    // 159 MHz / 13 = 12.23 MHz
    // 12.23 MHz * 5 = 61.15 MHz

    parameter PWM_ticks = 8'd13 - 8'd1;
    reg [7:0] PWM_counter = 8'd0;
    reg [7:0] PWM_threshold = 9;
    
    always @(posedge CLK_159MHz) begin
        if (PWM_counter < PWM_ticks) begin
            PWM_counter <= PWM_counter + 8'd1;
        end else begin
            PWM_counter <= 8'd0;
        end
    end
    
    wire PWM_output = PWM_counter < PWM_threshold;
    assign antenna = PWM_output;

endmodule
