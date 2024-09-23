
module asyncfifo (
  rd_aclr,
  wr_aclr,
  rdclk,
  wrclk,
  data,
  rdreq,
  wrreq,
  empty,
  q,
  wrusedw,
  rdusedw);
  parameter   width = 32,
              depth = 10,
              words = 1024;

  input                     rd_aclr;
  input                     wr_aclr;
  input                     rdclk;
  input                     wrclk;
  input       [width-1:0]   data;
  input                     rdreq;
  input                     wrreq;
  output  wire[width-1:0]   q;
  output  wire              empty;
  output  reg [depth-1:0]   wrusedw;
  output  reg [depth-1:0]   rdusedw;

  reg [width-1:0]       memory[words-1:0];
  reg [depth-1:0]       wr_addr, rd_addr;
  assign                empty = (rd_addr == wr_addr);
  assign                full  = (rd_addr == (wr_addr+1'b1));
  assign                q     = memory[rd_addr];
  
  always @(posedge wrclk or posedge wr_aclr) begin
    if(wr_aclr) begin
      wr_addr           <= {depth{1'b0}};
      for(integer idx=0; idx<words; idx=idx+1)
        memory[idx]     <= {width{1'b0}};
      wrusedw           <= {depth{1'b0}};
    end
    else begin
      wrusedw           <= wr_addr - rd_addr;
      wr_addr           <= wrreq? (wr_addr + 1'b1) : wr_addr;
      memory[wr_addr]   <= wrreq? data : memory[wr_addr];
    end
  end

  always @(posedge rdclk or posedge rd_aclr) begin
    if(rd_aclr) begin
      rd_addr           <= {depth{1'b0}};
      rdusedw           <= {depth{1'b0}};
    end
    else begin
      rdusedw           <= wr_addr - rd_addr;
      rd_addr           <= rdreq? (rd_addr + 1'b1) : rd_addr;
    end
  end


endmodule