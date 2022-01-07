// https://www.intel.com/content/www/us/en/programmable/quartushelp/13.0/mergedProjects/hdl/vlog/vlog_pro_ram_inferred.htm

module bram (
    input clk,
    // Write in
    input enable_wr,
    input [BRAM_ADDR_WIDTH-1:0] addr_wr, 
    input [BRAM_DATA_WIDTH-1:0] bram_data_wr,
    // Read out
    input [BRAM_ADDR_WIDTH-1:0] addr_rd, 
    output reg [BRAM_DATA_WIDTH-1:0] bram_data_rd
);

    parameter BRAM_ADDR_WIDTH = 9;
    parameter BRAM_DATA_WIDTH = 305; // 1 byte per data point

    (* ram_style = "distributed" *)
    reg [BRAM_DATA_WIDTH-1:0] mem [(1<<BRAM_ADDR_WIDTH)-1:0];

    // Empty initialise block
    initial begin
        for (integer i = 0; i < BRAM_ADDR_WIDTH; i = i + 1) begin
            mem[i] = 0;
        end
    end

    // BRAM Read Interface
    always @(posedge clk) begin
        bram_data_rd <= mem[addr_rd];
    end

    // BRAM Write Interface
    always @(negedge clk) begin
        if (enable_wr) begin
            mem[addr_wr] <= bram_data_wr;
        end
    end

endmodule