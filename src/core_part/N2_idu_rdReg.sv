/*************************************************************/
//  Module name: N2_idu
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/21
//  Function outline: instruction decode unit
/*************************************************************/
import NanoCore_pkg::*;

module N2_idu #(
  parameter [ 0:0] CATCH_MISALIGN = 1,
  parameter [ 0:0] CATCH_ILLINSN = 1,
  parameter [31:0] PROGADDR_RESET = 32'b0,
  parameter [ 0:0] TWO_CYCLE_ALU = 0,
  parameter [ 0:0] TWO_CYCLE_COMPARE = 0
) (
  input clk, resetn,
  input state_t     cpu_state_i,

  input wire        instr_any_div_rem_i,
  input wire        instr_any_mul_i,
  input wire [regindex_bits-1:0] latched_rd_ifu,
  output reg [regindex_bits-1:0] latched_rd_o,
  input wire [31:0] decoded_imm_i,
  input wire [31:0] cpuregs_rs1,
  input wire [31:0] cpuregs_rs2,
  input wire [regindex_bits-1:0] decoded_rs1, 
  input wire [regindex_bits-1:0] decoded_rs2,
  input wire        instr_trap_i,
  input wire        is_rdcycle_rdcycleh_rdinstr_rdinstrh_i,
  input wire        is_lui_auipc_jal_i,
  input wire        is_lb_lh_lw_lbu_lhu_i,
  input wire        is_slli_srli_srai_i,
  input wire        is_jalr_addi_slti_sltiu_xori_ori_andi_i,
  input wire        is_sb_sh_sw_i,
  input wire        is_sll_srl_sra_i,
  input wire        is_beq_bne_blt_bge_bltu_bgeu_i,
  input wire        instr_rdcycle_i,
  input wire        instr_rdcycleh_i,
  input wire        instr_rdinstr_i,
  input wire        instr_rdinstrh_i,
  input wire        instr_retirq_i,
  input wire        instr_maskirq_i,
  input wire        instr_lui_i,

  output reg [31:0] reg_op1_o,
  output reg [31:0] reg_op2_o,
  output reg [31:0] reg_out_o,
  output reg        mul_div_valid_o,
  output reg        latched_store_o,
  output reg        latched_branch_o,
  output reg        alu_wait_o, 
  output reg        alu_wait_2_o,
  
  input wire [31:0] irq_retPC_i,
  input wire [31:0] reg_pc_i,
  output reg        irq_processing_o,
  output reg [31:0] irq_mask_o,

  input wire [2:0]  iq_prefetch_ptr,
  output wire[2:0]  iq_rd_ptr_o,
  output reg        instr_valid_o,
  output reg [31:0] instr_opcode_o,
  input  wire       instr_ready_i,
  input  wire[31:0] instr_rdata_i,
  input  wire       latched_branch_i,
  input  wire       latched_branch_ifu_i,

  input wire [63:0] count_cycle_i,
  input wire [63:0] count_instr_i
);

  always_ff @(posedge clk) begin
    alu_wait_2_o <= 'b0;
    if(!resetn) begin
      irq_mask_o <= '0;
      irq_processing_o  <= 'b0;
    `ifdef ENABLE_MUL
      mul_div_valid_o <= '0;
    `endif
    end
    else if(cpu_state_i == cpu_state_ld_rs) begin
      latched_rd_o <= latched_rd_ifu;
      reg_op1_o <= 'bx;
      reg_op2_o <= 'bx;
      reg_out_o <= 'bx;
      latched_store_o <= '0;
      latched_branch_o <= '0;
      alu_wait_o <= 'b0;
    `ifdef ENABLE_MUL
      mul_div_valid_o <= instr_any_div_rem_i | instr_any_mul_i;
    `endif

      (* parallel_case *)
      case (1'b1)
        (CATCH_ILLINSN) && instr_trap_i: begin
          `debug($display("EBREAK OR UNSUPPORTED INSN AT 0x%08x", reg_pc_i);)
        end
        is_rdcycle_rdcycleh_rdinstr_rdinstrh_i: begin
          (* parallel_case, full_case *)
          case (1'b1)
            instr_rdcycle_i:
              reg_out_o <= count_cycle_i[31:0];
            instr_rdcycleh_i:
              reg_out_o <= count_cycle_i[63:32];
            instr_rdinstr_i:
              reg_out_o <= count_instr_i[31:0];
            instr_rdinstrh_i:
              reg_out_o <= count_instr_i[63:32];
          endcase
          latched_store_o <= 1;
          reg_op2_o <= decoded_imm_i;
          if (TWO_CYCLE_ALU)
            alu_wait_o <= 1;
        end
        is_lui_auipc_jal_i: begin
          reg_op1_o <= instr_lui_i ? 0 : reg_pc_i;
          reg_op2_o <= decoded_imm_i;
          if (TWO_CYCLE_ALU)
            alu_wait_o <= 1;
        end
      `ifdef ENABLE_IRQ
        instr_retirq_i: begin
          latched_branch_o    <= 'b1;
          latched_store_o     <= 'b1;
          `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
          reg_out_o           <= CATCH_MISALIGN ? (irq_retPC_i & 32'h fffffffe) : irq_retPC_i;
          irq_processing_o    <= 1'b0;
        end
        instr_maskirq_i: begin
          latched_store_o     <= 'b1;
          reg_out_o           <= irq_mask_o;
          `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
          irq_mask_o          <= cpuregs_rs1;
        end
      `endif
        is_lb_lh_lw_lbu_lhu_i && !instr_trap_i: begin
          `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
          reg_op1_o <= cpuregs_rs1;
        end
        is_jalr_addi_slti_sltiu_xori_ori_andi_i, is_slli_srli_srai_i: begin
          `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
          reg_op1_o <= cpuregs_rs1;
          reg_op2_o <= is_slli_srli_srai_i? decoded_rs2 : decoded_imm_i;
          if (TWO_CYCLE_ALU)
            alu_wait_o <= 1;
        end
        default: begin
          `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
          reg_op1_o <= cpuregs_rs1;

          `debug($display("LD_RS2: %2d 0x%08x", decoded_rs2, cpuregs_rs2);)
          reg_op2_o <= cpuregs_rs2;
          (* parallel_case *)
          case (1'b1)
            is_sb_sh_sw_i: begin
            end
          `ifdef ENABLE_MUL
            instr_any_div_rem_i | instr_any_mul_i: begin
            end
          `endif  
            default: begin
              if (TWO_CYCLE_ALU || (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu_i)) begin
                alu_wait_2_o <= TWO_CYCLE_ALU && (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu_i);
                alu_wait_o <= 1;
              end
            end
          endcase
        end
      endcase
    end
  end


  //* fifo used to store pre-decoded instr;
  reg [2:0] iq_wr_ptr, iq_rd_ptr;
  iq_data_t iq_entry[15:0];
  iq_data_t iq_entry_sel;
  assign iq_rd_ptr_o = iq_rd_ptr;
  reg instr_valid_delay;
  reg tag_wati_wr;
  always_ff @(posedge clk or negedge resetn) begin
    instr_valid_delay   <= instr_valid_o;
    if(!resetn) begin
      iq_wr_ptr         <= '0;
      iq_rd_ptr         <= '0;
      instr_valid_o     <= '0; 
      iq_rd_ptr         <= '0;
      iq_wr_ptr         <= '0;
      tag_wati_wr       <= '0;
    end
    else begin
      //* write;
      if(instr_ready_i) begin
        for(integer idx=0; idx<8; idx=idx+1) begin
          if(idx == iq_wr_ptr)
            iq_entry[idx].opcode = instr_rdata_i;
          iq_wr_ptr     <= 3'd1 + iq_wr_ptr;
        end
      end
      //* read;
      instr_valid_o     <= 1'b0;
      if(cpu_state_i == cpu_state_fetch && instr_valid_o == 1'b0 && instr_valid_delay == 1'b0) begin
        if(~tag_wati_wr && (iq_rd_ptr != iq_wr_ptr)) begin
          instr_valid_o     <= 1'b1;
          instr_opcode_o    <= iq_entry_sel.opcode; 
          iq_rd_ptr         <= 3'd1 + iq_rd_ptr;
        end
      end
      if(latched_branch_i | latched_branch_ifu_i) begin
        instr_valid_o   <= 1'b0;
        tag_wati_wr     <= 1'b1;
        iq_rd_ptr       <= iq_prefetch_ptr;
      end
      else if(iq_rd_ptr == iq_wr_ptr)
        tag_wati_wr     <= 1'b0;
    end
  end

  always_comb begin
    case(iq_rd_ptr)
      8'd0: iq_entry_sel = iq_entry[0];
      8'd1: iq_entry_sel = iq_entry[1];
      8'd2: iq_entry_sel = iq_entry[2];
      8'd3: iq_entry_sel = iq_entry[3];
      8'd4: iq_entry_sel = iq_entry[4];
      8'd5: iq_entry_sel = iq_entry[5];
      8'd6: iq_entry_sel = iq_entry[6];
      8'd7: iq_entry_sel = iq_entry[7];
      8'd8: iq_entry_sel = iq_entry[8];
    endcase
  end

endmodule