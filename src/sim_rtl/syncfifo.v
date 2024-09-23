
module syncfifo (
  aclr,
  clock,
  data,
  rdreq,
  wrreq,
  empty,
  full,
  q,
  usedw);
  parameter   width = 32,
              depth = 10,
              words = 1024;

  input                     aclr;
  input                     clock;
  input       [width-1:0]   data;
  input                     rdreq;
  input                     wrreq;
  output  wire [width-1:0]  q;
  output  wire              empty;
  output  wire              full;
  output  reg [depth-1:0]   usedw;

  reg [width-1:0]       memory[words-1:0];
  reg [depth-1:0]       wr_addr, rd_addr;
  assign                empty = (rd_addr == wr_addr);
  assign                full  = (rd_addr == (wr_addr+1'b1));
  assign                q     = memory[rd_addr];

  always @(posedge clock or posedge aclr) begin
    if(aclr) begin
      rd_addr           <= {depth{1'b0}};
      wr_addr           <= {depth{1'b0}};
      for(integer idx=0; idx<words; idx=idx+1)
        memory[idx]     <= {width{1'b0}};
      usedw             <= {depth{1'b0}};
    end
    else begin
      usedw             <= wr_addr - rd_addr;
      case({rdreq,wrreq})
        2'b00: begin
          wr_addr       <= wr_addr;
          rd_addr       <= rd_addr;
        end
        2'b01: begin
          wr_addr         <= wr_addr + 1'b1;
          memory[wr_addr] <= data;
          rd_addr         <= rd_addr;
        end
        2'b10: begin
          wr_addr         <= wr_addr;
          rd_addr         <= rd_addr + 1'b1;
        end
        2'b11: begin
          wr_addr         <= wr_addr + 1'b1;
          memory[wr_addr] <= data;
          rd_addr         <= rd_addr + 1'b1;
        end
        default: begin end
      endcase
    end
  end


endmodule