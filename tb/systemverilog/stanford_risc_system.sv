`timescale 1ns/1ps

module stanford_risc_system #(
    parameter string IMEM_INIT_FILE = "",
    parameter string DMEM_INIT_FILE = "",
    parameter int    BP_ENTRIES     = stanford_risc_pkg::BP_ENTRIES_DEFAULT,
    parameter int    IRQ_LINES      = stanford_risc_pkg::IRQ_LINES_DEFAULT,
    parameter int    IMEM_DEPTH     = 1024,
    parameter int    DMEM_DEPTH     = 1024
) (
    input  logic                    clk_i,
    input  logic                    rst_cold_n_i,
    input  logic                    rst_warm_n_i,
    input  logic [IRQ_LINES-1:0]    irq_i,
    output logic [31:0]             commit_pc_o,
    output logic                    commit_valid_o,
    output logic                    exception_o
);

    import stanford_risc_pkg::*;

    // AXI-Lite wires
    logic        imem_arvalid;
    logic        imem_arready;
    logic [31:0] imem_araddr;
    logic        imem_rvalid;
    logic        imem_rready;
    logic [31:0] imem_rdata;

    logic        dmem_awvalid;
    logic        dmem_awready;
    logic [31:0] dmem_awaddr;
    logic [2:0]  dmem_awprot;
    logic        dmem_wvalid;
    logic        dmem_wready;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_bvalid;
    logic        dmem_bready;
    logic        dmem_arvalid;
    logic        dmem_arready;
    logic [31:0] dmem_araddr;
    logic [2:0]  dmem_arprot;
    logic        dmem_rvalid;
    logic        dmem_rready;
    logic [31:0] dmem_rdata;

    stanford_risc_core #(
        .BP_ENTRIES (BP_ENTRIES),
        .IRQ_LINES  (IRQ_LINES)
    ) u_core (
        .clk_i             (clk_i),
        .rst_cold_n_i      (rst_cold_n_i),
        .rst_warm_n_i      (rst_warm_n_i),
        .imem_arvalid_o    (imem_arvalid),
        .imem_arready_i    (imem_arready),
        .imem_araddr_o     (imem_araddr),
        .imem_rvalid_i     (imem_rvalid),
        .imem_rready_o     (imem_rready),
        .imem_rdata_i      (imem_rdata),
        .dmem_awvalid_o    (dmem_awvalid),
        .dmem_awready_i    (dmem_awready),
        .dmem_awaddr_o     (dmem_awaddr),
        .dmem_awprot_o     (dmem_awprot),
        .dmem_wvalid_o     (dmem_wvalid),
        .dmem_wready_i     (dmem_wready),
        .dmem_wdata_o      (dmem_wdata),
        .dmem_wstrb_o      (dmem_wstrb),
        .dmem_bvalid_i     (dmem_bvalid),
        .dmem_bready_o     (dmem_bready),
        .dmem_arvalid_o    (dmem_arvalid),
        .dmem_arready_i    (dmem_arready),
        .dmem_araddr_o     (dmem_araddr),
        .dmem_arprot_o     (dmem_arprot),
        .dmem_rvalid_i     (dmem_rvalid),
        .dmem_rready_o     (dmem_rready),
        .dmem_rdata_i      (dmem_rdata),
        .irq_i             (irq_i),
        .commit_pc_o       (commit_pc_o),
        .commit_valid_o    (commit_valid_o),
        .exception_o       (exception_o)
    );

    axi_lite_imem #(
        .DEPTH_WORDS (IMEM_DEPTH),
        .BASE_ADDR   (32'h0001_0000),
        .INIT_FILE   (IMEM_INIT_FILE)
    ) u_imem (
        .clk_i      (clk_i),
        .rst_n_i    (rst_cold_n_i & rst_warm_n_i),
        .arvalid_i  (imem_arvalid),
        .arready_o  (imem_arready),
        .araddr_i   (imem_araddr),
        .rvalid_o   (imem_rvalid),
        .rready_i   (imem_rready),
        .rdata_o    (imem_rdata)
    );

    axi_lite_dmem #(
        .DEPTH_WORDS (DMEM_DEPTH),
        .BASE_ADDR   (32'h0000_2000),
        .INIT_FILE   (DMEM_INIT_FILE)
    ) u_dmem (
        .clk_i      (clk_i),
        .rst_n_i    (rst_cold_n_i & rst_warm_n_i),
        .awvalid_i  (dmem_awvalid),
        .awready_o  (dmem_awready),
        .awaddr_i   (dmem_awaddr),
        .wvalid_i   (dmem_wvalid),
        .wready_o   (dmem_wready),
        .wdata_i    (dmem_wdata),
        .wstrb_i    (dmem_wstrb),
        .bvalid_o   (dmem_bvalid),
        .bready_i   (dmem_bready),
        .arvalid_i  (dmem_arvalid),
        .arready_o  (dmem_arready),
        .araddr_i   (dmem_araddr),
        .rvalid_o   (dmem_rvalid),
        .rready_i   (dmem_rready),
        .rdata_o    (dmem_rdata)
    );

endmodule

