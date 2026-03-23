`timescale 1ns/1ps

// Simple AXI-Lite read-only memory (used for instruction fetch)
module axi_lite_imem #(
    parameter int unsigned DEPTH_WORDS = 1024,
    parameter logic [31:0] BASE_ADDR   = 32'h0001_0000,
    parameter string       INIT_FILE   = ""
) (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        arvalid_i,
    output logic        arready_o,
    input  logic [31:0] araddr_i,
    output logic        rvalid_o,
    input  logic        rready_i,
    output logic [31:0] rdata_o
);

    logic [31:0] mem [0:DEPTH_WORDS-1];

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    assign arready_o = 1'b1;

    logic        pending_q;
    logic [31:0] data_q;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            pending_q <= 1'b0;
            data_q    <= '0;
            rvalid_o  <= 1'b0;
        end else begin
            if (arvalid_i && arready_o) begin
                int unsigned idx;
                idx = (araddr_i - BASE_ADDR) >> 2;
                if (idx < DEPTH_WORDS) begin
                    data_q <= mem[idx];
                end else begin
                    data_q <= 32'h0000_0000;
                end
                pending_q <= 1'b1;
            end

            if (pending_q) begin
                rvalid_o <= 1'b1;
            end

            if (rvalid_o && rready_i) begin
                rvalid_o  <= 1'b0;
                pending_q <= 1'b0;
            end
        end
    end

    assign rdata_o = data_q;

endmodule

// Simple AXI-Lite read/write memory (data memory)
module axi_lite_dmem #(
    parameter int unsigned DEPTH_WORDS = 1024,
    parameter logic [31:0] BASE_ADDR   = 32'h0000_0000,
    parameter string       INIT_FILE   = ""
) (
    input  logic        clk_i,
    input  logic        rst_n_i,
    // Write address channel
    input  logic        awvalid_i,
    output logic        awready_o,
    input  logic [31:0] awaddr_i,
    // Write data channel
    input  logic        wvalid_i,
    output logic        wready_o,
    input  logic [31:0] wdata_i,
    input  logic [3:0]  wstrb_i,
    // Write response
    output logic        bvalid_o,
    input  logic        bready_i,
    // Read address
    input  logic        arvalid_i,
    output logic        arready_o,
    input  logic [31:0] araddr_i,
    // Read data
    output logic        rvalid_o,
    input  logic        rready_i,
    output logic [31:0] rdata_o
);

    logic [31:0] mem [0:DEPTH_WORDS-1];

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    assign awready_o = 1'b1;
    assign wready_o  = 1'b1;
    assign arready_o = 1'b1;

    logic        rvalid_q;
    logic [31:0] rdata_q;
    logic        bvalid_q;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            rvalid_q <= 1'b0;
            bvalid_q <= 1'b0;
            rdata_q  <= '0;
        end else begin
            // Writes
            if (awvalid_i && wvalid_i) begin
                int unsigned idx;
                idx = (awaddr_i - BASE_ADDR) >> 2;
                if (idx < DEPTH_WORDS) begin
                    for (int i = 0; i < 4; i++) begin
                        if (wstrb_i[i]) begin
                            mem[idx][8*i +: 8] <= wdata_i[8*i +: 8];
                        end
                    end
                end
                bvalid_q <= 1'b1;
            end

            if (bvalid_q && bready_i) begin
                bvalid_q <= 1'b0;
            end

            // Reads
            if (arvalid_i) begin
                int unsigned idx_r;
                idx_r = (araddr_i - BASE_ADDR) >> 2;
                if (idx_r < DEPTH_WORDS) begin
                    rdata_q <= mem[idx_r];
                end else begin
                    rdata_q <= 32'h0000_0000;
                end
                rvalid_q <= 1'b1;
            end

            if (rvalid_q && rready_i) begin
                rvalid_q <= 1'b0;
            end
        end
    end

    assign rvalid_o = rvalid_q;
    assign rdata_o  = rdata_q;
    assign bvalid_o = bvalid_q;

endmodule

