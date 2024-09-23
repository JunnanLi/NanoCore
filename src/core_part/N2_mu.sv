/*************************************************************/
//  Module name: N2_mu
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/24
//  Function outline: mul and div unit
/*************************************************************/
import NanoCore_pkg::*;

module N2_mu (
  input clk, resetn,
  input   wire          mul_div_v,
  input   wire  [7:0]   uid_d2_i,
  output  logic [7:0]   uid_mu_o,

  input   uop_ctl_t     uop_ctl_i,
  input   wire  [31:0]  mu_rs1_i,
  input   wire  [31:0]  mu_rs2_i,
  output  wire          div_ready_o,

  output  logic [31:0]  alu_rst_mu_o,
  output  reg   [regindex_bits-1:0] rf_dst_mu_o,
  output  logic         rf_we_mu_o
);
  
  wire  [3:0]   mul_op_i = {uop_ctl_i.instr_mul, 
                            uop_ctl_i.instr_mulh, 
                            uop_ctl_i.instr_mulhsu, 
                            uop_ctl_i.instr_mulhu};
  wire  [3:0]   div_op_i = {uop_ctl_i.instr_div, 
                            uop_ctl_i.instr_divu, 
                            uop_ctl_i.instr_rem, 
                            uop_ctl_i.instr_remu};
  wire  [regindex_bits-1:0] rf_dst_idu_i = uop_ctl_i.decoded_rd;
  wire          div_ready, mul_ready;
  wire  [31:0]  mul_rd, div_rd;
  assign        div_ready_o = div_ready;
  wire  [7:0]   mul_uid, div_uid;

  always_ff @(posedge clk) begin
    rf_dst_mu_o <= mul_div_v? rf_dst_idu_i: rf_dst_mu_o;
  end

  always_comb begin
    rf_we_mu_o = div_ready | mul_ready;
    alu_rst_mu_o = mul_ready? mul_rd : 
                div_ready? div_rd : 32'b0;
    uid_mu_o   = mul_ready? mul_uid : 
                  div_ready? div_uid : 32'b0;
  end

  alu_mul alu_mul (
    .clk        (clk            ),
    .resetn     (resetn         ),
    .mul_valid  (mul_div_v      ),
    .mul_op     (mul_op_i       ),
    .mul_rs1    (mu_rs1_i       ),
    .mul_rs2    (mu_rs2_i       ),
    .mul_wr     (               ),
    .uid_i      (uid_d2_i       ),
    .mul_rd     (mul_rd         ),
    .mul_uid    (mul_uid        ),
    .mul_wait   (               ),
    .mul_ready  (mul_ready      )
  );

  //* for div
  alu_div alu_div (
    .clk        (clk            ),
    .resetn     (resetn         ),
    .div_valid  (mul_div_v      ),
    .div_op     (div_op_i       ),
    .div_rs1    (mu_rs1_i       ),
    .div_rs2    (mu_rs2_i       ),
    .div_wr     (               ),
    .div_rd     (div_rd         ),
    .uid_i      (uid_d2_i       ),
    .div_uid    (div_uid        ),
    .div_wait   (               ),
    .div_ready  (div_ready      )
  );


endmodule


module alu_mul #(
  parameter EXTRA_MUL_FFS = 0,
  parameter EXTRA_INSN_FFS = 0,
  parameter MUL_CLKGATE = 0
) (
  input clk, resetn,

  input                 mul_valid,
  input         [3:0]   mul_op,
  input         [31:0]  mul_rs1,
  input         [31:0]  mul_rs2,
  output  wire          mul_wr,
  output  wire  [31:0]  mul_rd,
  input   wire  [7:0]   uid_i,
  output  wire  [7:0]   mul_uid,
  output  wire          mul_wait,
  output  wire          mul_ready
);
  wire instr_mul, instr_mulh, instr_mulhsu, instr_mulhu; //* from mul
  assign {instr_mul, instr_mulh, instr_mulhsu, instr_mulhu} = mul_op;
  wire instr_any_mul = |mul_op && mul_valid;
  wire instr_any_mulh = |{instr_mulh, instr_mulhsu, instr_mulhu};
  wire instr_rs1_signed = |{instr_mulh, instr_mulhsu};
  wire instr_rs2_signed = |{instr_mulh};

  reg shift_out, instr_any_mulh_delay;
  reg [3:0] active;
  reg [7:0] r_mul_uid[1:0];
  reg [32:0] rs1, rs2, rs1_q, rs2_q;
  reg [63:0] rd, rd_q;

  wire mul_insn_valid = mul_valid && instr_any_mul;
  reg mul_insn_valid_q;

  always_ff @(posedge clk) begin
    mul_insn_valid_q <= mul_insn_valid;
    if (!MUL_CLKGATE || active[0]) begin
      rs1_q <= rs1;
      rs2_q <= rs2;
    end
    if (!MUL_CLKGATE || active[1]) begin
      rd <= $signed(EXTRA_MUL_FFS ? rs1_q : rs1) * $signed(EXTRA_MUL_FFS ? rs2_q : rs2);
    end
    if (!MUL_CLKGATE || active[2]) begin
      rd_q <= rd;
    end
  end

  always_ff @(posedge clk) begin
    if (instr_any_mul && !(EXTRA_MUL_FFS ? active[3:0] : active[1:0])) begin
      if (instr_rs1_signed)
        rs1 <= $signed(mul_rs1);
      else
        rs1 <= $unsigned(mul_rs1);

      if (instr_rs2_signed)
        rs2 <= $signed(mul_rs2);
      else
        rs2 <= $unsigned(mul_rs2);
      active[0] <= 1;
      r_mul_uid[0]  <= uid_i;
    end else begin
      active[0] <= 0;
    end

    active[3:1] <= active;
    r_mul_uid[1]  <= r_mul_uid[0];
    {shift_out,instr_any_mulh_delay} <= {instr_any_mulh_delay,instr_any_mulh};

    if (!resetn)
      active <= 0;
  end

  assign mul_wr = active[EXTRA_MUL_FFS ? 3 : 1];
  assign mul_wait = 0;
  assign mul_ready = active[EXTRA_MUL_FFS ? 3 : 1];
  assign mul_uid = r_mul_uid[1];
  assign mul_rd = shift_out ? (EXTRA_MUL_FFS ? rd_q : rd) >> 32 : (EXTRA_MUL_FFS ? rd_q : rd);
endmodule


module alu_div (
  input clk, resetn,

  input                 div_valid,
  input         [3:0]   div_op,
  input         [31:0]  div_rs1,
  input         [31:0]  div_rs2,
  input   wire  [7:0]   uid_i,
  output  reg   [7:0]   div_uid,
  output  reg           div_wr,
  output  reg   [31:0]  div_rd,
  output  wire          div_wait,
  output  reg           div_ready
);
  reg instr_div, instr_divu, instr_rem, instr_remu;
  // wire instr_div, instr_divu, instr_rem, instr_remu;
  // assign {instr_div, instr_divu, instr_rem, instr_remu} = div_op;

  reg div_wait_q;
  assign div_wait = (|div_op) && resetn && div_valid;
  wire start = div_wait && !div_wait_q;

  always @(posedge clk) begin
    // div_wait    <= (|div_op) && resetn && div_valid;
    div_wait_q  <= div_wait && resetn;
    {instr_div, instr_divu, instr_rem, instr_remu} <= div_valid? div_op: 
                  {instr_div, instr_divu, instr_rem, instr_remu};
  end

  reg [31:0] dividend;
  reg [62:0] divisor;
  reg [31:0] quotient;
  reg [31:0] quotient_msk;
  reg running;
  reg outsign;

  always_ff @(posedge clk) begin
    div_ready     <= 'b0;
    div_wr        <= 'b0;
    div_rd        <= 'bx;
    div_uid       <= (div_valid & (|div_op))? uid_i: div_uid;

    if (!resetn) begin
      running     <= 'b0;
    end else
    if (start) begin
      running     <= 'b1;
      dividend    <= (instr_div || instr_rem) && div_rs1[31] ? -div_rs1 : div_rs1;
      divisor     <= ((instr_div || instr_rem) && div_rs2[31] ? -div_rs2 : div_rs2) << 31;
      outsign     <= (instr_div && (div_rs1[31] != div_rs2[31]) && |div_rs2) || (instr_rem && div_rs1[31]);
      quotient    <= 'b0;
      quotient_msk<= 1 << 31;
    end else
    if (!quotient_msk && running) begin
      running     <= 'b0;
      div_ready   <= 'b1;
      div_wr      <= 'b1;

      if (instr_div || instr_divu)
        div_rd    <= outsign ? -quotient : quotient;
      else
        div_rd    <= outsign ? -dividend : dividend;
    end else begin
      if (divisor <= dividend) begin
        dividend  <= dividend - divisor;
        quotient  <= quotient | quotient_msk;
      end
      divisor     <= divisor >> 1;
      quotient_msk<= quotient_msk >> 1;
    end
  end
endmodule