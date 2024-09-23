
module syncram (
  address_a,
  address_b,
  clock,
  data_a,
  data_b,
  rden_a,
  rden_b,
  wren_a,
  wren_b,
  q_a,
  q_b
);
  parameter   width = 32,
              depth = 10,
              words = 1024;

  input       [depth-1:0]   address_a;
  input       [depth-1:0]   address_b;
  input                     clock;
  input       [width-1:0]   data_a;
  input       [width-1:0]   data_b;
  input                     rden_a;
  input                     rden_b;
  input                     wren_a;
  input                     wren_b;
  output  reg [width-1:0]   q_a;
  output  reg [width-1:0]   q_b;

  reg [width-1:0]       memory[words-1:0];
  reg [depth-1:0]       r_addr_a, r_addr_b;
  wire[words-1:0]       we_a_dec, we_b_dec;
  
  always @(clock) begin
    if(clock) begin
      r_addr_a          <= (rden_a | wren_a)? address_a: r_addr_a;
      r_addr_b          <= (rden_b | wren_b)? address_b: r_addr_b;
      memory[address_a] <= wren_a? data_a: memory[address_a];

      //* read;
      q_a               <= memory[r_addr_a];
      q_b               <= memory[r_addr_b];
    end
    else begin
      memory[address_b] <= wren_b? data_b: memory[address_b];
    end

  end

  
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  // always @(posedge clock) begin
  //   r_addr_a            <= (rden_a | wren_a)? address_a: r_addr_a;
  //   r_addr_b            <= (rden_b | wren_b)? address_b: r_addr_b;

  //   //* read;
  //   q_a                 <= memory[r_addr_a];
  //   q_b                 <= memory[r_addr_b];

  //   //* write;
  //   for(integer idx=0; idx<=words; idx=idx+1)
  //     memory[idx]       <= we_a_dec[idx]? data_a:
  //                           we_b_dec[idx]? data_b: memory[idx];
  // end

  // generate
  //   for (genvar gidx = 0; gidx < words; gidx=gidx+1) begin : gen_we_decoder
  //     assign we_a_dec[gidx] = (address_a == gidx) ? wren_a : 1'b0;
  //     assign we_b_dec[gidx] = (address_b == gidx) ? wren_b : 1'b0;
  //   end
  // endgenerate
  //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

endmodule