module project_top (
    input SYS_CLK,
    input KEY1,
    input KEY2,
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

    //-------- Push button handler --------//
    
    reg PWM_activated = 0;

    always @(posedge CLK_27MHz) begin
        if (KEY1 == 0 && KEY2 == 0) begin
            // Both button pressed: do nothing
        end else if (KEY1 == 0) begin
            // Activate
            PWM_activated <= 1;
        end else if (KEY2 == 0) begin
            // Deactivate
            PWM_activated <= 0;
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
    assign antenna = PWM_output & PWM_activated;
    
    //-------- PAL State Machine --------//

    // keep track of time
    parameter PAL_USEC_TICKS = 159; // 160MHz clock
    reg [15:0] PAL_ticks  = 16'd0;

    // voltage level
    parameter PAL_LEVEL_LOW  = 0;
    parameter PAL_LEVEL_BLACK  = 1;
    parameter PAL_LEVEL_WHITE  = 2;
    reg [4:0] PAL_level = PAL_LEVEL_LOW;

    // line number
    reg [10:0] PAL_line  = 10'd1; // ranges from 1 to 625

    // line states
    wire PAL_sync_long_long = (PAL_line == 1 || PAL_line == 2 ||
                               PAL_line == 314 || PAL_line == 315);
    wire PAL_sync_short_short = (PAL_line == 4 || PAL_line == 5 ||
                                 PAL_line == 311 || PAL_line == 312 ||
                                 PAL_line == 316 || PAL_line == 317 ||
                                 PAL_line == 623 || PAL_line == 624 || PAL_line == 625);
    wire PAL_sync_long_short = (PAL_line == 3);
    wire PAL_sync_short_long = (PAL_line == 313);
    wire PAL_field_one = (6 <= PAL_line && PAL_line <= 310);
    wire PAL_field_two = (318 <= PAL_line && PAL_line <= 622);
    
    // Functions to calculate screen coordinates
    parameter integer PAL_LINE_OFFSET_TICKS = (1.65+4.7+5.6) * PAL_USEC_TICKS;
    parameter PAL_LINE_FULLRANGE_TICKS = (64-(1.65+4.7+5.6)) * PAL_USEC_TICKS;
    parameter integer PAL_LINE_TICKS_PER_PIXEL = PAL_LINE_FULLRANGE_TICKS / UART_PIXELS;
    
    reg [15:0] PAL_screen_X_ticks = 16'd0;
    reg [15:0] PAL_screen_X_count = 16'd0;

    // Slow function; deprecated
    function [10:0] PAL_screen_X;
        input [31:0] ticks;
        begin
            PAL_screen_X = ((ticks-PAL_LINE_OFFSET_TICKS) / PAL_LINE_TICKS_PER_PIXEL);
        end
    endfunction

    parameter integer PAL_BLANKING_LINES = 48 + 20; // arbitrary value - shift down due to overscan
    parameter integer PAL_TOTAL_LINES = 512; // according to uart buffer size of 9 bits

    function [10:0] PAL_screen_Y;
        input [10:0] line;
        begin
            if (6 <= line && line <= 310) begin
                PAL_screen_Y = (line-6)*2 | 1; // Field One (Odd)
            end else if (318 <= line && line <= 622) begin
                PAL_screen_Y = (line-318)*2 | 0; // Field Two (Even)
            end else begin
                PAL_screen_Y = 0;
            end
        end
    endfunction

    // process
    always @(posedge CLK_159MHz) begin
        // ticks
        if (PAL_ticks < (64*PAL_USEC_TICKS)) begin
            PAL_ticks <= PAL_ticks + 1;
        end else begin
            PAL_line <= PAL_line + 1;
            PAL_ticks <= 0;
        end
        
        // level to pwm
        case (PAL_level)
            PAL_LEVEL_LOW: PWM_threshold <= 7;
            PAL_LEVEL_BLACK: PWM_threshold <= 2;
            PAL_LEVEL_WHITE: PWM_threshold <= 0;
        endcase
        
        // state machine
        if (625 < PAL_line) begin
            PAL_line <= 0;
            PAL_ticks <= 0;
        end else if (PAL_sync_long_long) begin
            // Long/Long (27.3us low + 4.7us high / 27.3us low + 4.7us high)
            if (PAL_ticks < (27.3 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < (32 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else if (PAL_ticks < (59.3 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < (64 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else begin
                PAL_line <= PAL_line + 1;
                PAL_ticks <= 0;
            end
        end else if (PAL_sync_long_short) begin
            // Long/Short (27.3us low + 4.7us high / 2.35us low + 29.65us high)
            if (PAL_ticks < (27.3 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < (32 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else if (PAL_ticks < (34.35 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < (64 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else begin
                PAL_line <= PAL_line + 1;
                PAL_ticks <= 0;
            end
        end else if (PAL_sync_short_long) begin
            // Short/Long (2.35us low + 29.65us high / 27.3us low + 4.7us high)
            if (PAL_ticks < (2.35 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < (32 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else if (PAL_ticks < (59.3 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < (64 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else begin
                PAL_line <= PAL_line + 1;
                PAL_ticks <= 0;
            end
        end else if (PAL_sync_short_short) begin
            // Short/Long (2.35us low + 29.65us high / 27.3us low + 4.7us high)
            if (PAL_ticks < (2.35 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < (32 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else if (PAL_ticks < (34.35 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < (64 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else begin
                PAL_line <= PAL_line + 1;
                PAL_ticks <= 0;
            end
        end else begin
            // front porch 1.65ms high 
            // horizontal sync 4.7ms low 
            // back porch 5.7ms high 
            if (PAL_ticks < (1.65 * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
                // Reset parameters for BRAM
                bram_addr_rd <= (PAL_screen_Y(PAL_line) > PAL_BLANKING_LINES) ? PAL_screen_Y(PAL_line)-PAL_BLANKING_LINES : 0; 
                PAL_screen_X_ticks <= 0;
                PAL_screen_X_count <= 0;
            end else if (PAL_ticks < ((1.65+4.7) * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_LOW;
            end else if (PAL_ticks < ((1.65+4.7+5.6) * PAL_USEC_TICKS)) begin
                PAL_level <= PAL_LEVEL_BLACK;
            end else if (PAL_ticks < (64 * PAL_USEC_TICKS)) begin
                // Divider for screen X count because the function had timing issues
                if (PAL_screen_X_ticks < PAL_LINE_TICKS_PER_PIXEL) begin
                    PAL_screen_X_ticks <= PAL_screen_X_ticks + 1;
                end else begin
                    PAL_screen_X_ticks <= 0;
                    PAL_screen_X_count <= PAL_screen_X_count + 1;
                end

                // Select the line from the BRAM
                if (PAL_screen_Y(PAL_line) < PAL_BLANKING_LINES) begin
                    PAL_level <= PAL_LEVEL_BLACK;
                end else if (PAL_screen_Y(PAL_line) >= (PAL_TOTAL_LINES + PAL_BLANKING_LINES)) begin
                    PAL_level <= PAL_LEVEL_BLACK;
                end else begin
                    if (bram_data_rd[PAL_screen_X_count]) begin
                        PAL_level <= PAL_LEVEL_WHITE;
                    end else begin
                        PAL_level <= PAL_LEVEL_BLACK;
                    end
                end

                // Test screen X pixels
                /*
                if (PAL_screen_Y(PAL_line) < 2*PAL_screen_X_count)
                    PAL_level <= PAL_LEVEL_BLACK;
                else PAL_level <= PAL_LEVEL_WHITE;
                */

                // Test uart_line_index
                /*
                if (PAL_ticks < ((32+uart_line_index) * PAL_USEC_TICKS))
                    PAL_level <= PAL_LEVEL_WHITE;
                else PAL_level <= PAL_LEVEL_BLACK;
                */

                // Test screen Y lines
                /*
                if (PAL_ticks < ((14*PAL_USEC_TICKS + PAL_screen_Y(PAL_line)*PAL_USEC_TICKS/12)))
                    PAL_level <= PAL_LEVEL_WHITE;
                else PAL_level <= PAL_LEVEL_BLACK;
                */

            end
        end
    end



endmodule
