`timescale 1ns/1ps

module complex_mul16 (
    input  logic signed [15:0] a_real_i,
    input  logic signed [15:0] a_imag_i,
    input  logic signed [15:0] b_real_i,
    input  logic signed [15:0] b_imag_i,
    output logic signed [15:0] res_real_o,
    output logic signed [15:0] res_imag_o,
    output logic               overflow_o
);

    logic signed [31:0] real_full;
    logic signed [31:0] imag_full;

    assign real_full = (a_real_i * b_real_i) - (a_imag_i * b_imag_i);
    assign imag_full = (a_real_i * b_imag_i) + (a_imag_i * b_real_i);

    assign res_real_o = real_full[15:0];
    assign res_imag_o = imag_full[15:0];

    function automatic logic overflow16(input logic signed [31:0] val);
        return (val > 32'sd32767) || (val < -32'sd32768);
    endfunction

    assign overflow_o = overflow16(real_full) || overflow16(imag_full);

endmodule

