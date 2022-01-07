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

    //-------- UART State Machine --------//
    wire [7:0] uart_data;
    wire       uart_ready;

    uart_rx #(
        .CLOCK_RATE(27_000_000),
        .BAUD_RATE(115200)
    ) uart_m_instance (
        .i_CLK(CLK_27MHz),
        .i_RX(uart_rxd),
        .o_READY(uart_ready),
        .o_DATA(uart_data)
    );

endmodule
