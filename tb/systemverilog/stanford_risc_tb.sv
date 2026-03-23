`timescale 1ns/1ps

module stanford_risc_tb;

    import stanford_risc_pkg::*;

    localparam string IMEM_INIT_FILE = "tb/programs/stanford_risc_basic.hex";
    localparam logic [31:0] DMEM_BASE = 32'h0000_2000;

    logic clk;
    logic rst_cold_n;
    logic rst_warm_n;
    logic [IRQ_LINES_DEFAULT-1:0] irq;
    logic [31:0] commit_pc;
    logic commit_valid;
    logic exception_flag;

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Resets
    initial begin
        rst_cold_n = 0;
        rst_warm_n = 0;
        #40;
        rst_cold_n = 1;
        rst_warm_n = 1;
    end

    // Interrupt stimulus
    initial begin
        irq = '0;
        @(posedge rst_cold_n);
        repeat (40) @(posedge clk);
        irq[0] = 1'b1;
        repeat (2) @(posedge clk);
        irq[0] = 1'b0;
    end

    stanford_risc_system #(
        .IMEM_INIT_FILE (IMEM_INIT_FILE),
        .DMEM_INIT_FILE (""),
        .BP_ENTRIES     (64),
        .IRQ_LINES      (IRQ_LINES_DEFAULT),
        .IMEM_DEPTH     (256),
        .DMEM_DEPTH     (64)
    ) dut (
        .clk_i          (clk),
        .rst_cold_n_i   (rst_cold_n),
        .rst_warm_n_i   (rst_warm_n),
        .irq_i          (irq),
        .commit_pc_o    (commit_pc),
        .commit_valid_o (commit_valid),
        .exception_o    (exception_flag)
    );

    // Scoreboard
    int unsigned cycles;
    logic load_store_pass;
    logic mul_pass;
    logic interrupt_seen;
    logic overflow_pass;

    initial begin
        cycles = 0;
        load_store_pass = 0;
        mul_pass = 0;
        interrupt_seen = 0;
        overflow_pass = 0;
        wait(rst_cold_n && rst_warm_n);
        forever begin
            @(posedge clk);
            cycles++;
            if (exception_flag)
                interrupt_seen = 1'b1;

            // Check data memory contents
            if (dut.u_sys.u_dmem.mem[((32'h0000_2000 - DMEM_BASE) >> 2)] == 32'd13)
                load_store_pass = 1'b1;
            if (dut.u_sys.u_dmem.mem[((32'h0000_2000 - DMEM_BASE) >> 2) + 1] == 32'h8400_0000)
                mul_pass = 1'b1;
            if (dut.u_sys.u_core.csr_mstatus[0])
                overflow_pass = 1'b1;

            if (load_store_pass && mul_pass && interrupt_seen && overflow_pass)
                disable finish_block;

            if (cycles > 500) begin
                $fatal(1, "Timeout waiting for expected events. load=%0b mul=%0b irq=%0b ovf=%0b",
                       load_store_pass, mul_pass, interrupt_seen, overflow_pass);
            end
        end
    end

    initial begin : finish_block
        wait(load_store_pass && mul_pass && interrupt_seen && overflow_pass);
        $display("All checks passed (load/store, complex multiply overflow, interrupt).");
        #20;
        $finish;
    end

endmodule

