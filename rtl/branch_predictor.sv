`timescale 1ns/1ps

module branch_predictor #(
    parameter int ENTRIES = 64
) (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic [31:0] pc_i,
    output logic        predict_taken_o,

    // Update interface
    input  logic        update_i,
    input  logic [31:0] update_pc_i,
    input  logic        taken_i
);

    localparam int INDEX_BITS = $clog2(ENTRIES);

    logic [ENTRIES-1:0] history_bits;

    logic [INDEX_BITS-1:0] rd_idx;
    assign rd_idx = pc_i[INDEX_BITS+1:2];

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            history_bits <= '0;
        end else if (update_i) begin
            history_bits[update_pc_i[INDEX_BITS+1:2]] <= taken_i;
        end
    end

    assign predict_taken_o = history_bits[rd_idx];

endmodule

