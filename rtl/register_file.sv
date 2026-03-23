`timescale 1ns/1ps

module register_file #(
    parameter int XLEN = 32,
    parameter int REG_COUNT = 32
) (
    input  logic                 clk_i,
    input  logic                 rst_n_i,
    input  logic                 we_i,
    input  logic [$clog2(REG_COUNT)-1:0] rd_i,
    input  logic [XLEN-1:0]      wd_i,
    input  logic [$clog2(REG_COUNT)-1:0] rs1_i,
    input  logic [$clog2(REG_COUNT)-1:0] rs2_i,
    output logic [XLEN-1:0]      rs1_o,
    output logic [XLEN-1:0]      rs2_o
);

    logic [XLEN-1:0] regs [REG_COUNT-1:0];

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            for (int i = 0; i < REG_COUNT; i++) begin
                regs[i] <= '0;
            end
        end else if (we_i && (rd_i != '0)) begin
            regs[rd_i] <= wd_i;
        end
    end

    assign rs1_o = (rs1_i == '0) ? '0 : regs[rs1_i];
    assign rs2_o = (rs2_i == '0) ? '0 : regs[rs2_i];

endmodule

