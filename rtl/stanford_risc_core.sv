`timescale 1ns/1ps

module stanford_risc_core #(
    parameter int BP_ENTRIES   = stanford_risc_pkg::BP_ENTRIES_DEFAULT,
    parameter int IRQ_LINES    = stanford_risc_pkg::IRQ_LINES_DEFAULT,
    parameter int RESET_VECTOR = 32'h0001_0000,
    parameter bit HAS_MUL      = 1'b1
) (
    input  logic                     clk_i,
    input  logic                     rst_cold_n_i,
    input  logic                     rst_warm_n_i,

    // Instruction AXI-Lite (read-only)
    output logic                     imem_arvalid_o,
    input  logic                     imem_arready_i,
    output logic [31:0]              imem_araddr_o,
    input  logic                     imem_rvalid_i,
    output logic                     imem_rready_o,
    input  logic [31:0]              imem_rdata_i,

    // Data AXI-Lite
    output logic                     dmem_awvalid_o,
    input  logic                     dmem_awready_i,
    output logic [31:0]              dmem_awaddr_o,
    output logic [2:0]               dmem_awprot_o,
    output logic                     dmem_wvalid_o,
    input  logic                     dmem_wready_i,
    output logic [31:0]              dmem_wdata_o,
    output logic [3:0]               dmem_wstrb_o,
    input  logic                     dmem_bvalid_i,
    output logic                     dmem_bready_o,
    output logic                     dmem_arvalid_o,
    input  logic                     dmem_arready_i,
    output logic [31:0]              dmem_araddr_o,
    output logic [2:0]               dmem_arprot_o,
    input  logic                     dmem_rvalid_i,
    output logic                     dmem_rready_o,
    input  logic [31:0]              dmem_rdata_i,

    // Interrupts
    input  logic [IRQ_LINES-1:0]     irq_i,

    // Commit / debug
    output logic [31:0]              commit_pc_o,
    output logic                     commit_valid_o,
    output logic                     exception_o
);

    import stanford_risc_pkg::*;
    localparam int REG_COUNT = stanford_risc_pkg::REG_COUNT;

    // Reset combine
    logic rst_async_n;
    assign rst_async_n = rst_cold_n_i & rst_warm_n_i;

    logic rst_sync_n;
    logic rst_meta;
    always_ff @(posedge clk_i or negedge rst_async_n) begin
        if (!rst_async_n) begin
            rst_meta   <= 1'b0;
            rst_sync_n <= 1'b0;
        end else begin
            rst_meta   <= 1'b1;
            rst_sync_n <= rst_meta;
        end
    end

    logic [31:0] pc_q, pc_d;
    if_id_reg_t  if_id_q;
    id_ex_reg_t  id_ex_q;
    ex_mem_reg_t ex_mem_q;
    mem_wb_reg_t mem_wb_q;

    // Branch predictor
    logic bp_predict_taken;
    logic bp_update;
    branch_predictor #(
        .ENTRIES(BP_ENTRIES)
    ) u_bp (
        .clk_i        (clk_i),
        .rst_n_i      (rst_sync_n),
        .pc_i         (pc_q),
        .predict_taken_o(bp_predict_taken),
        .update_i     (bp_update),
        .update_pc_i  (ex_mem_q.pc),
        .taken_i      (ex_mem_q.branch_taken)
    );

    assign bp_update = ex_mem_q.valid && ex_mem_q.ctrl.branch;

    // Program counter
    logic        pc_hold;
    logic        pc_flush;
    logic [31:0] flush_target;

    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            pc_q <= RESET_VECTOR;
        end else if (!pc_hold) begin
            pc_q <= pc_d;
        end
    end

    always_comb begin
        pc_d = pc_q;
        if (pc_flush) begin
            pc_d = flush_target;
        end else if (!pc_hold) begin
            pc_d = pc_q + 32'd4;
        end
    end

    // Fetch interface
    logic fetch_pending_q, fetch_pending_d;
    logic [31:0] fetch_addr_q;
    logic        if_stall;
    logic        if_valid_d, if_valid_q;
    logic [31:0] if_instr_d, if_instr_q;
    logic [31:0] if_pc_d,    if_pc_q;
    logic        if_pred_d,  if_pred_q;

    assign imem_araddr_o   = pc_q;
    assign imem_arvalid_o  = !fetch_pending_q && !if_stall;
    assign imem_rready_o   = 1'b1;

    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            fetch_pending_q <= 1'b0;
            if_valid_q      <= 1'b0;
        end else begin
            fetch_pending_q <= fetch_pending_d;
            if_valid_q      <= if_valid_d;
            if_instr_q      <= if_instr_d;
            if_pc_q         <= if_pc_d;
            if_pred_q       <= if_pred_d;
        end
    end

    always_comb begin
        fetch_pending_d = fetch_pending_q;
        if_valid_d      = if_valid_q;
        if_instr_d      = if_instr_q;
        if_pc_d         = if_pc_q;
        if_pred_d       = if_pred_q;

        if (pc_flush) begin
            fetch_pending_d = 1'b0;
            if_valid_d      = 1'b0;
        end else begin
            if (imem_arvalid_o && imem_arready_i) begin
                fetch_pending_d = 1'b1;
            end
            if (imem_rvalid_i) begin
                fetch_pending_d = 1'b0;
                if_valid_d      = 1'b1;
                if_instr_d      = imem_rdata_i;
                if_pc_d         = pc_q;
                if_pred_d       = bp_predict_taken;
            end else if (if_stall) begin
                // hold
            end else if (if_id_hold) begin
                // hold in IF/ID reg
            end else begin
                if_valid_d = 1'b0;
            end
        end
    end

    // IF/ID register
    logic       if_id_flush, if_id_hold;
    logic       id_hold;

    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            if_id_q <= '0;
        end else if (if_id_flush) begin
            if_id_q <= '0;
        end else if (!if_id_hold) begin
            if_id_q.valid      <= if_valid_q;
            if_id_q.pc         <= if_pc_q;
            if_id_q.instr      <= if_instr_q;
            if_id_q.pred_taken <= if_pred_q;
        end
    end

    // Decode
    function automatic alu_op_e decode_alur_op(input logic [2:0] func3);
        case (func3)
            3'd0: return ALU_ADD;
            3'd1: return ALU_SUB;
            3'd2: return ALU_AND;
            3'd3: return ALU_OR;
            3'd4: return ALU_XOR;
            3'd5: return ALU_SLT;
            3'd6: return ALU_SLL;
            3'd7: return ALU_SRL;
            default: return ALU_ADD;
        endcase
    endfunction

    logic [5:0] opcode;
    logic [4:0] field_a, field_b, field_c;
    logic [15:0] dec_imm16;
    logic [25:0] dec_u26;
    logic [2:0]  func3;
    ctrl_t        dec_ctrl;
    logic [31:0]  dec_imm;
    logic [4:0]   dec_rs1_idx, dec_rs2_idx, dec_rd_idx;

    assign opcode   = if_id_q.instr[31:26];
    assign field_a  = if_id_q.instr[25:21];
    assign field_b  = if_id_q.instr[20:16];
    assign field_c  = if_id_q.instr[15:11];
    assign dec_imm16= if_id_q.instr[15:0];
    assign dec_u26  = if_id_q.instr[25:0];
    assign func3    = if_id_q.instr[10:8];

    always_comb begin
        dec_ctrl    = '0;
        dec_imm     = {{16{dec_imm16[15]}}, dec_imm16};
        dec_rs1_idx = field_b;
        dec_rs2_idx = field_c;
        dec_rd_idx  = field_a;
        unique case (opcode)
            OPC_NOP: dec_ctrl = '0;
            OPC_ALUR: begin
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.use_imm   = 1'b0;
                dec_ctrl.alu_op    = decode_alur_op(func3);
                dec_rs1_idx        = field_a;
                dec_rs2_idx        = field_b;
                dec_rd_idx         = field_c;
            end
            OPC_ADDI: begin
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.use_imm   = 1'b1;
                dec_ctrl.alu_op    = ALU_ADD;
                dec_rs1_idx        = field_b;
                dec_rs2_idx        = '0;
                dec_rd_idx         = field_a;
            end
            OPC_ANDI: begin
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.use_imm   = 1'b1;
                dec_ctrl.alu_op    = ALU_AND;
                dec_rs1_idx        = field_b;
                dec_rs2_idx        = '0;
                dec_rd_idx         = field_a;
            end
            OPC_ORI: begin
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.use_imm   = 1'b1;
                dec_ctrl.alu_op    = ALU_OR;
                dec_rs1_idx        = field_b;
                dec_rs2_idx        = '0;
                dec_rd_idx         = field_a;
            end
            OPC_XORI: begin
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.use_imm   = 1'b1;
                dec_ctrl.alu_op    = ALU_XOR;
                dec_rs1_idx        = field_b;
                dec_rs2_idx        = '0;
                dec_rd_idx         = field_a;
            end
            OPC_LD: begin
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.mem_read  = 1'b1;
                dec_ctrl.use_imm   = 1'b1;
                dec_ctrl.wb_sel    = 2'd1;
                dec_ctrl.alu_op    = ALU_ADD;
                dec_rs1_idx        = field_b;
                dec_rs2_idx        = '0;
                dec_rd_idx         = field_a;
            end
            OPC_ST: begin
                dec_ctrl.mem_write = 1'b1;
                dec_ctrl.use_imm   = 1'b1;
                dec_ctrl.alu_op    = ALU_ADD;
                dec_rs1_idx        = field_b; // base
                dec_rs2_idx        = field_a; // store data
                dec_rd_idx         = '0;
            end
            OPC_BEQ: begin
                dec_ctrl.branch    = 1'b1;
                dec_ctrl.use_imm   = 1'b1;
                dec_ctrl.alu_op    = ALU_SUB;
                dec_rs1_idx        = field_a;
                dec_rs2_idx        = field_b;
                dec_rd_idx         = '0;
            end
            OPC_BNE: begin
                dec_ctrl.branch    = 1'b1;
                dec_ctrl.use_imm   = 1'b1;
                dec_ctrl.alu_op    = ALU_SUB;
                dec_rs1_idx        = field_a;
                dec_rs2_idx        = field_b;
                dec_rd_idx         = '0;
            end
            OPC_JAL: begin
                dec_ctrl.jump      = 1'b1;
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.wb_sel    = 2'd3;
                dec_imm            = { {6{dec_u26[25]}}, dec_u26, 2'b00 };
                dec_rs1_idx        = '0;
                dec_rs2_idx        = '0;
                dec_rd_idx         = field_a;
            end
            OPC_JR: begin
                dec_ctrl.jump      = 1'b1;
                dec_ctrl.use_imm   = 1'b0;
                dec_rs1_idx        = field_a;
                dec_rs2_idx        = '0;
                dec_rd_idx         = '0;
            end
            OPC_CSR: begin
                dec_ctrl.csr_write = 1'b1;
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.wb_sel    = 2'd2;
                dec_rs1_idx        = field_b;
                dec_rs2_idx        = '0;
                dec_rd_idx         = field_a;
            end
            OPC_MUL: begin
                dec_ctrl.reg_write = 1'b1;
                dec_ctrl.is_mul    = HAS_MUL;
                dec_rs1_idx        = field_a;
                dec_rs2_idx        = field_b;
                dec_rd_idx         = field_c;
            end
            default: dec_ctrl = '0;
        endcase
    end

    // Register file
    logic [31:0] rs1_data, rs2_data;
    register_file #(
        .XLEN(32),
        .REG_COUNT(REG_COUNT)
    ) u_rf (
        .clk_i (clk_i),
        .rst_n_i(rst_sync_n),
        .we_i  (mem_wb_q.ctrl.reg_write & mem_wb_q.valid),
        .rd_i  (mem_wb_q.rd),
        .wd_i  (wb_data),
        .rs1_i (dec_rs1_idx),
        .rs2_i (dec_rs2_idx),
        .rs1_o (rs1_data),
        .rs2_o (rs2_data)
    );

    // ID/EX register
    logic       id_ex_flush;
    logic       id_hold;

    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            id_ex_q <= '0;
        end else if (id_ex_flush) begin
            id_ex_q <= '0;
        end else if (!id_hold) begin
            id_ex_q.valid      <= if_id_q.valid;
            id_ex_q.ctrl       <= dec_ctrl;
            id_ex_q.opcode     <= opcode;
            id_ex_q.pc         <= if_id_q.pc;
            id_ex_q.rs1_data   <= rs1_data;
            id_ex_q.rs2_data   <= rs2_data;
            id_ex_q.rd         <= dec_rd_idx;
            id_ex_q.rs1        <= dec_rs1_idx;
            id_ex_q.rs2        <= dec_rs2_idx;
            id_ex_q.imm        <= dec_imm;
            id_ex_q.pred_taken <= if_id_q.pred_taken;
        end
    end

    // Execute
    logic [31:0] alu_a, alu_b, alu_res;
    logic        branch_taken;
    logic [31:0] branch_target;
    logic        mispredict;
    logic        jump_taken;
    logic [31:0] jump_target;
    logic [31:0] jump_target_calc;
    logic signed [15:0] mul_a_real, mul_a_imag, mul_b_real, mul_b_imag;
    logic signed [15:0] mul_res_real, mul_res_imag;
    logic               mul_overflow_flag;
    logic [31:0]        complex_result;

    assign mul_a_real = alu_a[31:16];
    assign mul_a_imag = alu_a[15:0];
    assign mul_b_real = alu_b[31:16];
    assign mul_b_imag = alu_b[15:0];

    complex_mul16 u_complex_mul (
        .a_real_i   (mul_a_real),
        .a_imag_i   (mul_a_imag),
        .b_real_i   (mul_b_real),
        .b_imag_i   (mul_b_imag),
        .res_real_o (mul_res_real),
        .res_imag_o (mul_res_imag),
        .overflow_o (mul_overflow_flag)
    );

    assign complex_result = {mul_res_real, mul_res_imag};

    assign alu_a = id_ex_q.rs1_data;
    assign alu_b = id_ex_q.ctrl.use_imm ? id_ex_q.imm : id_ex_q.rs2_data;

    always_comb begin
        unique case (id_ex_q.ctrl.alu_op)
            ALU_ADD: alu_res = alu_a + alu_b;
            ALU_SUB: alu_res = alu_a - alu_b;
            ALU_AND: alu_res = alu_a & alu_b;
            ALU_OR : alu_res = alu_a | alu_b;
            ALU_XOR: alu_res = alu_a ^ alu_b;
            ALU_SLT: alu_res = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0;
            ALU_SLL: alu_res = alu_a << alu_b[4:0];
            ALU_SRL: alu_res = alu_a >> alu_b[4:0];
            default: alu_res = 32'd0;
        endcase
        if (id_ex_q.ctrl.is_mul) begin
            alu_res = complex_result;
        end
    end

    assign branch_taken = (id_ex_q.ctrl.branch) ? (
        (id_ex_q.opcode == OPC_BEQ) ? (id_ex_q.rs1_data == id_ex_q.rs2_data) :
        (id_ex_q.opcode == OPC_BNE) ? (id_ex_q.rs1_data != id_ex_q.rs2_data) : 1'b0
    ) : 1'b0;

    assign branch_target = id_ex_q.pc + (id_ex_q.imm << 2);
    assign mispredict    = id_ex_q.ctrl.branch && (branch_taken != id_ex_q.pred_taken);
    assign jump_taken    = id_ex_q.ctrl.jump;

    always_comb begin
        if (id_ex_q.opcode == OPC_JAL) begin
            jump_target_calc = id_ex_q.pc + id_ex_q.imm;
        end else begin
            jump_target_calc = id_ex_q.rs1_data;
        end
    end
    assign jump_target = jump_target_calc;

    // EX/MEM register
    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            ex_mem_q <= '0;
        end else begin
            ex_mem_q.valid        <= id_ex_q.valid;
            ex_mem_q.ctrl         <= id_ex_q.ctrl;
            ex_mem_q.pc           <= id_ex_q.pc;
            ex_mem_q.alu_res      <= alu_res;
            ex_mem_q.rs2_data     <= id_ex_q.rs2_data;
            ex_mem_q.rd           <= id_ex_q.rd;
            ex_mem_q.branch_taken <= branch_taken;
            ex_mem_q.branch_target<= branch_target;
            ex_mem_q.mispredict   <= mispredict;
            ex_mem_q.jump_taken   <= jump_taken;
            ex_mem_q.jump_target  <= jump_target;
            ex_mem_q.mul_overflow <= (id_ex_q.ctrl.is_mul) ? mul_overflow_flag : 1'b0;
        end
    end

    // Memory stage handshake
    logic mem_read_pending_q, mem_write_pending_q;
    logic [31:0] mem_rdata_q;
    logic mem_wait;
    logic misaligned_access;

    assign misaligned_access = (ex_mem_q.ctrl.mem_read || ex_mem_q.ctrl.mem_write) &&
                               (ex_mem_q.alu_res[1:0] != 2'b00);

    // AXI defaults
    assign dmem_awprot_o = 3'b000;
    assign dmem_arprot_o = 3'b000;

    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            mem_read_pending_q  <= 1'b0;
            mem_write_pending_q <= 1'b0;
            mem_rdata_q         <= '0;
        end else begin
            // Read
            if (ex_mem_q.ctrl.mem_read && !mem_read_pending_q && !misaligned_access) begin
                mem_read_pending_q <= 1'b1;
            end
            if (dmem_rvalid_i && dmem_rready_o) begin
                mem_read_pending_q <= 1'b0;
                mem_rdata_q        <= dmem_rdata_i;
            end
            // Write
            if (ex_mem_q.ctrl.mem_write && !mem_write_pending_q && !misaligned_access) begin
                mem_write_pending_q <= 1'b1;
            end
            if (dmem_bvalid_i && dmem_bready_o) begin
                mem_write_pending_q <= 1'b0;
            end
        end
    end

    assign dmem_arvalid_o = ex_mem_q.ctrl.mem_read && !mem_read_pending_q && !misaligned_access;
    assign dmem_araddr_o  = ex_mem_q.alu_res;
    assign dmem_rready_o  = 1'b1;

    assign dmem_awvalid_o = ex_mem_q.ctrl.mem_write && !mem_write_pending_q && !misaligned_access;
    assign dmem_awaddr_o  = ex_mem_q.alu_res;
    assign dmem_wvalid_o  = dmem_awvalid_o;
    assign dmem_wdata_o   = ex_mem_q.rs2_data;
    assign dmem_wstrb_o   = 4'b1111;
    assign dmem_bready_o  = 1'b1;

    assign mem_wait = (mem_read_pending_q || mem_write_pending_q);

    // MEM/WB
    logic [31:0] wb_data;

    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            mem_wb_q <= '0;
        end else begin
            mem_wb_q.valid   <= ex_mem_q.valid && !misaligned_access;
            mem_wb_q.ctrl    <= ex_mem_q.ctrl;
            mem_wb_q.pc      <= ex_mem_q.pc;
            mem_wb_q.alu_res <= ex_mem_q.alu_res;
            mem_wb_q.mem_data<= mem_rdata_q;
            mem_wb_q.rd      <= ex_mem_q.rd;
            mem_wb_q.mul_overflow <= ex_mem_q.mul_overflow;
        end
    end

    always_comb begin
        unique case (mem_wb_q.ctrl.wb_sel)
            2'd0: wb_data = mem_wb_q.alu_res;
            2'd1: wb_data = mem_wb_q.mem_data;
            2'd2: wb_data = csr_read_data;
            2'd3: wb_data = mem_wb_q.pc + 32'd4;
            default: wb_data = mem_wb_q.alu_res;
        endcase
    end

    // CSR / exception
    logic [31:0] csr_mstatus, csr_mtvec, csr_mepc, csr_mcause;
    logic [31:0] csr_read_data;

    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            csr_mstatus <= 32'h0000_0008;
            csr_mtvec   <= RESET_VECTOR;
            csr_mepc    <= '0;
            csr_mcause  <= '0;
        end else begin
            if (mem_wb_q.ctrl.csr_write && mem_wb_q.valid) begin
                unique case (mem_wb_q.mem_data[3:0])
                    4'h0: csr_mstatus <= mem_wb_q.alu_res;
                    4'h1: csr_mtvec   <= mem_wb_q.alu_res;
                    4'h2: csr_mepc    <= mem_wb_q.alu_res;
                    4'h3: csr_mcause  <= mem_wb_q.alu_res;
                    default: ;
                endcase
            end
            if (mem_wb_q.ctrl.is_mul && mem_wb_q.valid) begin
                csr_mstatus[0] <= mem_wb_q.mul_overflow;
            end
            if (take_trap) begin
                csr_mepc   <= trap_pc;
                csr_mcause <= trap_cause;
            end
        end
    end

    always_comb begin
        unique case (dec_imm16[3:0])
            4'h0: csr_read_data = csr_mstatus;
            4'h1: csr_read_data = csr_mtvec;
            4'h2: csr_read_data = csr_mepc;
            4'h3: csr_read_data = csr_mcause;
            default: csr_read_data = 32'h0;
        endcase
    end

    // Interrupt / exception handling
    logic irq_pending;
    assign irq_pending = |irq_i;

    logic take_trap;
    logic [31:0] trap_pc;
    logic [31:0] trap_cause;
    logic        exception_pending;

    assign exception_o = take_trap;

    always_comb begin
        take_trap   = 1'b0;
        trap_pc     = ex_mem_q.pc;
        trap_cause  = 32'd0;
        exception_pending = 1'b0;

        if (misaligned_access) begin
            take_trap  = 1'b1;
            trap_cause = 32'd1;
            trap_pc    = ex_mem_q.pc;
        end else if (irq_pending) begin
            take_trap  = 1'b1;
            trap_cause = 32'd2;
            trap_pc    = pc_q;
        end
    end

    assign pc_flush   = take_trap |
                        (ex_mem_q.ctrl.branch && ex_mem_q.mispredict) |
                        (ex_mem_q.jump_taken && ex_mem_q.valid);
    assign flush_target = take_trap ? csr_mtvec :
                          (ex_mem_q.jump_taken && ex_mem_q.valid) ? ex_mem_q.jump_target :
                          (ex_mem_q.ctrl.branch && ex_mem_q.branch_taken) ? ex_mem_q.branch_target :
                          ex_mem_q.pc + 32'd4;

    assign pc_hold    = if_stall | mem_wait;
    assign if_stall   = id_hold;
    assign if_id_hold = id_hold;
    assign if_id_flush= pc_flush;
    assign id_ex_flush= pc_flush;
    assign id_hold    = load_use_hazard | mem_wait;

    // Load-use detection
    logic load_use_hazard;
    assign load_use_hazard =
        id_ex_q.ctrl.mem_read &&
        ((id_ex_q.rd != '0) &&
         ((id_ex_q.rd == dec_rs1_idx) || (id_ex_q.rd == dec_rs2_idx)));

    // Commit signals
    assign commit_valid_o = mem_wb_q.valid && mem_wb_q.ctrl.reg_write;
    assign commit_pc_o    = mem_wb_q.pc;

endmodule

