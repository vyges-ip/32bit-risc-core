`ifndef STANFORD_RISC_PKG_SV
`define STANFORD_RISC_PKG_SV

package stanford_risc_pkg;

  localparam int XLEN               = 32;
  localparam int REG_COUNT          = 32;
  localparam int BP_ENTRIES_DEFAULT = 64;
  localparam int IRQ_LINES_DEFAULT  = 4;

  typedef enum logic [5:0] {
    OPC_NOP  = 6'b000000,
    OPC_ALUR = 6'b000001,
    OPC_ADDI = 6'b000010,
    OPC_ANDI = 6'b000011,
    OPC_ORI  = 6'b000100,
    OPC_XORI = 6'b000101,
    OPC_LD   = 6'b001000,
    OPC_ST   = 6'b001001,
    OPC_BEQ  = 6'b010000,
    OPC_BNE  = 6'b010001,
    OPC_JAL  = 6'b011000,
    OPC_JR   = 6'b011001,
    OPC_CSR  = 6'b100000,
    OPC_MUL  = 6'b100001
  } stanford_opcode_e;

  typedef enum logic [2:0] {
    ALU_ADD = 3'd0,
    ALU_SUB = 3'd1,
    ALU_AND = 3'd2,
    ALU_OR  = 3'd3,
    ALU_XOR = 3'd4,
    ALU_SLT = 3'd5,
    ALU_SLL = 3'd6,
    ALU_SRL = 3'd7
  } alu_op_e;

  typedef struct packed {
    logic        reg_write;
    logic        mem_read;
    logic        mem_write;
    logic        branch;
    logic        jump;
    logic        use_imm;
    logic        is_mul;
    logic        csr_write;
    logic [1:0]  wb_sel;    // 0: ALU, 1: MEM, 2: CSR, 3: PC+4
    alu_op_e     alu_op;
  } ctrl_t;

  typedef struct packed {
    logic             valid;
    logic [XLEN-1:0]  pc;
    logic [XLEN-1:0]  instr;
    logic             pred_taken;
  } if_id_reg_t;

  typedef struct packed {
    logic             valid;
    ctrl_t            ctrl;
    stanford_opcode_e opcode;
    logic [XLEN-1:0]  pc;
    logic [XLEN-1:0]  rs1_data;
    logic [XLEN-1:0]  rs2_data;
    logic [4:0]       rd;
    logic [4:0]       rs1;
    logic [4:0]       rs2;
    logic [XLEN-1:0]  imm;
    logic             pred_taken;
  } id_ex_reg_t;

  typedef struct packed {
    logic             valid;
    ctrl_t            ctrl;
    logic [XLEN-1:0]  pc;
    logic [XLEN-1:0]  alu_res;
    logic [XLEN-1:0]  rs2_data;
    logic [4:0]       rd;
    logic             branch_taken;
    logic [XLEN-1:0]  branch_target;
    logic             mispredict;
    logic             jump_taken;
    logic [XLEN-1:0]  jump_target;
  } ex_mem_reg_t;

  typedef struct packed {
    logic             valid;
    ctrl_t            ctrl;
    logic [XLEN-1:0]  pc;
    logic [XLEN-1:0]  alu_res;
    logic [XLEN-1:0]  mem_data;
    logic [4:0]       rd;
  } mem_wb_reg_t;

endpackage : stanford_risc_pkg

`endif // STANFORD_RISC_PKG_SV

