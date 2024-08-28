/*************************************************************/
//  Module name: N2_lsu
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/06/26
//  Function outline: load and store unit
/*************************************************************/
import NanoCore_pkg::*;

module N2_lsu (
  input clk, resetn,
  input                 to_ld_v_i,
  input                 to_st_v_i,
  input   wire  [7:0]   uid_d2_i,
  output  wire  [7:0]   uid_lsu_o,

  input   wire  [31:0]  alu_op1_i,
  input   wire  [31:0]  alu_op2_i,
  output  wire  [31:0]  alu_rst_o,
  output  wire  [regindex_bits-1:0] rf_dst_lsu_ns_o,
  output  wire  [regindex_bits-1:0] rf_dst_lsu_o,
  input   uop_ctl_t     uop_ctl_i,
  input   wire          data_gnt_i,
  output  wire          data_req_o,
  output  wire          data_we_o,
  output  wire  [31:0]  data_addr_o,
  output  wire  [31:0]  data_wdata_o,
  output  wire  [ 3:0]  data_wstrb_o,
  input   wire          data_ready_i,
  input   wire  [31:0]  data_rdata_i,
  output  wire          rf_we_lsu_o,
  output  wire          lsu_stall_idu_o
);

  wire  [regindex_bits-1:0] rf_dst_idu_i = uop_ctl_i.decoded_rd;
  wire          instr_sb_i = uop_ctl_i.instr_sb;
  wire          instr_sh_i = uop_ctl_i.instr_sh;
  wire          instr_sw_i = uop_ctl_i.instr_sw;
  wire          instr_lb_i = uop_ctl_i.instr_lb;
  wire          instr_lh_i = uop_ctl_i.instr_lh;
  wire          instr_lw_i = uop_ctl_i.instr_lw;
  wire          instr_lbu_i = uop_ctl_i.instr_lbu;
  wire          instr_lhu_i = uop_ctl_i.instr_lhu;
  wire          is_lbu_lhu_lw_i = uop_ctl_i.is_lbu_lhu_lw;
  wire  [31:0]  decoded_imm_i = uop_ctl_i.decoded_imm;

  //* add lsq
  reg   [2:0] lsq_rd_ptr, lsq_wr_ptr, lsq_fetch_ptr;
  lsu_ctl_t lsq_entry[7:0], lsu_ctl_fetch, lsu_ctl_idu, lsu_ctl_rd;
  // assign lsu_ctl_idu.addr = alu_op1_i + decoded_imm_i;
  assign lsu_ctl_idu.addr = uop_ctl_i.waddr;
  assign lsu_ctl_idu.mem_wordsize = {instr_sb_i|instr_lb_i|instr_lbu_i, instr_sh_i|instr_lh_i|instr_lhu_i};
  assign lsu_ctl_idu.wdata = (lsu_ctl_idu.mem_wordsize == 'd2)? {4{alu_op2_i[7:0]}}:
                              (lsu_ctl_idu.mem_wordsize == 'd1)? {2{alu_op2_i[15:0]}}: alu_op2_i;
  assign lsu_ctl_idu.wstrb = (lsu_ctl_idu.mem_wordsize == 'd2)? 4'b0001 << lsu_ctl_idu.addr[1:0]:
                              (lsu_ctl_idu.mem_wordsize == 'd1)? {{2{lsu_ctl_idu.addr[1]}},{2{~lsu_ctl_idu.addr[1]}}}: 4'b1111;;
  assign lsu_ctl_idu.we = to_st_v_i;
  assign lsu_ctl_idu.is_lu = is_lbu_lhu_lw_i;
  assign lsu_ctl_idu.is_lh = instr_lh_i;
  assign lsu_ctl_idu.is_lb = instr_lb_i;
  assign lsu_ctl_idu.rf_dst = rf_dst_idu_i;
  assign lsu_ctl_idu.uid = uid_d2_i;

  wire   lsq_bypass = lsq_wr_ptr == lsq_fetch_ptr;
  wire [3:0] lsq_left = {~lsq_wr_ptr[2] & lsq_rd_ptr[2],lsq_wr_ptr} - {1'b0,lsq_rd_ptr};
  assign lsu_stall_idu_o = lsq_left[2];
  logic [31:0]  w_data_rdata;

  assign data_req_o   = ~lsq_bypass | to_st_v_i | to_ld_v_i;
  assign data_addr_o  = lsu_ctl_fetch.addr;
  assign data_wdata_o = lsu_ctl_fetch.wdata;
  assign data_wstrb_o = lsu_ctl_fetch.wstrb & {4{lsu_ctl_fetch.we}};
  assign data_we_o    = lsu_ctl_fetch.we;
  assign rf_dst_lsu_ns_o  = lsu_ctl_fetch.rf_dst;
  assign rf_we_lsu_o  = data_ready_i & ~lsu_ctl_rd.we;
  assign rf_dst_lsu_o = lsu_ctl_rd.rf_dst;
  assign alu_rst_o    = {32{lsu_ctl_rd.is_lu}} & w_data_rdata |
                        {32{lsu_ctl_rd.is_lh}} & {{16{w_data_rdata[15]}},w_data_rdata[15:0]} |
                        {32{lsu_ctl_rd.is_lb}} & {{24{w_data_rdata[7]}},w_data_rdata[7:0]};
  assign uid_lsu_o    = lsu_ctl_rd.uid;

  always_ff @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      lsq_rd_ptr        <= '0;
      lsq_wr_ptr        <= '0;
      lsq_fetch_ptr     <= '0;
    end
    else begin
      //* write lsq;
      if(to_st_v_i | to_ld_v_i) begin
        lsq_entry[lsq_wr_ptr] <= lsu_ctl_idu;
        lsq_wr_ptr            <= lsq_wr_ptr + 1;
      end
      //* read/write data;
      // data_req          <= data_gnt_i? ~lsq_bypass: data_req_o;
      lsq_fetch_ptr     <= (data_gnt_i & data_req_o)? (lsq_fetch_ptr + 1): lsq_fetch_ptr;
      // if((to_st_v_i | to_ld_v_i | ~lsq_bypass ) & (data_gnt_i | ~data_req_o)) begin
      //   data_addr_o     <= lsu_ctl_fetch.addr;
      //   data_wdata_o    <= lsu_ctl_fetch.wdata;
      //   data_wstrb_o    <= lsu_ctl_fetch.wstrb & {4{lsu_ctl_fetch.we}};
      //   data_req_o      <= 1'b1;
      //   data_we_o       <= lsu_ctl_fetch.we;
      //   lsq_fetch_ptr   <= lsq_fetch_ptr + 1;
      // end


      lsq_rd_ptr      <= data_ready_i? (lsq_rd_ptr + 1): lsq_rd_ptr;
      // //* respond
      // rf_we_lsu_o       <= 1'b0;
      // if (data_ready_i) begin
      //   lsq_rd_ptr      <= lsq_rd_ptr + 1;
      //   rf_we_lsu_o     <= ~lsu_ctl_rd.we;
      //   (* parallel_case, full_case *)
      //   case (1'b1)
      //     lsu_ctl_rd.is_lu: alu_rst_o <= w_data_rdata;
      //     lsu_ctl_rd.is_lh: alu_rst_o <= $signed(w_data_rdata[15:0]);
      //     lsu_ctl_rd.is_lb: alu_rst_o <= $signed(w_data_rdata[7:0]);
      //   endcase
      // end
      // uid_lsu_o       <= lsu_ctl_rd.uid;
      // rf_dst_lsu_o    <= lsu_ctl_rd.rf_dst;
    end
  end

  always_comb begin
    case(lsu_ctl_rd.mem_wordsize)
      0: w_data_rdata = data_rdata_i;
      1: begin
        case (lsu_ctl_rd.addr[1])
          1'b0: w_data_rdata = {16'b0, data_rdata_i[15: 0]};
          1'b1: w_data_rdata = {16'b0, data_rdata_i[31:16]};
        endcase
      end
      2: begin
        case (lsu_ctl_rd.addr[1:0])
          2'b00: w_data_rdata = {24'b0, data_rdata_i[ 7: 0]};
          2'b01: w_data_rdata = {24'b0, data_rdata_i[15: 8]};
          2'b10: w_data_rdata = {24'b0, data_rdata_i[23:16]};
          2'b11: w_data_rdata = {24'b0, data_rdata_i[31:24]};
        endcase
      end
    endcase
  end


  always_comb begin
    case({lsq_bypass,lsq_fetch_ptr})
      {1'b0,3'd0}: lsu_ctl_fetch = lsq_entry[0];
      {1'b0,3'd1}: lsu_ctl_fetch = lsq_entry[1];
      {1'b0,3'd2}: lsu_ctl_fetch = lsq_entry[2];
      {1'b0,3'd3}: lsu_ctl_fetch = lsq_entry[3];
      {1'b0,3'd4}: lsu_ctl_fetch = lsq_entry[4];
      {1'b0,3'd5}: lsu_ctl_fetch = lsq_entry[5];
      {1'b0,3'd6}: lsu_ctl_fetch = lsq_entry[6];
      {1'b0,3'd7}: lsu_ctl_fetch = lsq_entry[7];
      default:     lsu_ctl_fetch = lsu_ctl_idu;     
    endcase
  end

  always_comb begin
    case(lsq_rd_ptr)
      3'd0: lsu_ctl_rd = lsq_entry[0];
      3'd1: lsu_ctl_rd = lsq_entry[1];
      3'd2: lsu_ctl_rd = lsq_entry[2];
      3'd3: lsu_ctl_rd = lsq_entry[3];
      3'd4: lsu_ctl_rd = lsq_entry[4];
      3'd5: lsu_ctl_rd = lsq_entry[5];
      3'd6: lsu_ctl_rd = lsq_entry[6];
      3'd7: lsu_ctl_rd = lsq_entry[7];
      default: begin end 
    endcase
  end

endmodule