`timescale 1ns/1ps

module stanford_risc_cocotb_top;

    import stanford_risc_pkg::*;

    logic clk;
    logic rst_cold_n;
    logic rst_warm_n;
    logic [IRQ_LINES_DEFAULT-1:0] irq_drive;
    logic [31:0] commit_pc;
    logic commit_valid;
    logic exception_flag;

    stanford_risc_system #(
        .IMEM_INIT_FILE ("tb/programs/stanford_risc_basic.hex"),
        .DMEM_INIT_FILE (""),
        .BP_ENTRIES     (BP_ENTRIES_DEFAULT),
        .IRQ_LINES      (IRQ_LINES_DEFAULT),
        .IMEM_DEPTH     (256),
        .DMEM_DEPTH     (64)
    ) u_sys (
        .clk_i          (clk),
        .rst_cold_n_i   (rst_cold_n),
        .rst_warm_n_i   (rst_warm_n),
        .irq_i          (irq_drive),
        .commit_pc_o    (commit_pc),
        .commit_valid_o (commit_valid),
        .exception_o    (exception_flag)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_cold_n = 1'b0;
        rst_warm_n = 1'b0;
        irq_drive  = '0;
    end

endmodule

