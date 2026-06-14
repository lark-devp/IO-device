`timescale 1ps / 1ps
module crc_gen
  (
   input [1:0]   data_in,
   input         crc_en,
   output [31:0] crc_out,
   input         rst,
   input         clk);

   logic [31:0]  lfsr_q,lfsr_c;

   assign crc_out = lfsr_c ^ 32'hffffffff;

   assign lfsr_c[0] = lfsr_q[2];
   assign lfsr_c[1] = lfsr_q[3];
   assign lfsr_c[2] = lfsr_q[4];
   assign lfsr_c[3] = lfsr_q[5];
   assign lfsr_c[4] = (data_in[0] ^ lfsr_q[0] ^ lfsr_q[6]);
   assign lfsr_c[5] = (data_in[1] ^ lfsr_q[1] ^ lfsr_q[7]);
   assign lfsr_c[6] = lfsr_q[8];
   assign lfsr_c[7] = (data_in[0] ^ lfsr_q[0] ^ lfsr_q[9]);
   assign lfsr_c[8] = (data_in[0] ^ data_in[1] ^ lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[10]);
   assign lfsr_c[9] = (data_in[1] ^ lfsr_q[1] ^ lfsr_q[11]);
   assign lfsr_c[10] = lfsr_q[12];
   assign lfsr_c[11] = lfsr_q[13];
   assign lfsr_c[12] = lfsr_q[14];
   assign lfsr_c[13] = lfsr_q[15];
   assign lfsr_c[14] = (data_in[0] ^ lfsr_q[0] ^ lfsr_q[16]);
   assign lfsr_c[15] = (data_in[1] ^ lfsr_q[1] ^ lfsr_q[17]);
   assign lfsr_c[16] = lfsr_q[18];
   assign lfsr_c[17] = lfsr_q[19];
   assign lfsr_c[18] = (data_in[0] ^ lfsr_q[0] ^ lfsr_q[20]);
   assign lfsr_c[19] = (data_in[0] ^ data_in[1] ^ lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[21]);
   assign lfsr_c[20] = (data_in[0] ^ data_in[1] ^ lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[22]);
   assign lfsr_c[21] = (data_in[1] ^ lfsr_q[1] ^ lfsr_q[23]);
   assign lfsr_c[22] = (data_in[0] ^ lfsr_q[0] ^ lfsr_q[24]);
   assign lfsr_c[23] = (data_in[0] ^ data_in[1] ^ lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[25]);
   assign lfsr_c[24] = (data_in[1] ^ lfsr_q[1] ^ lfsr_q[26]);
   assign lfsr_c[25] = (data_in[0] ^ lfsr_q[0] ^ lfsr_q[27]);
   assign lfsr_c[26] = (data_in[0] ^ data_in[1] ^ lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[28]);
   assign lfsr_c[27] = (data_in[1] ^ lfsr_q[1] ^ lfsr_q[29]);
   assign lfsr_c[28] = (data_in[0] ^ lfsr_q[0] ^ lfsr_q[30]);
   assign lfsr_c[29] = (data_in[0] ^ data_in[1] ^ lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[31]);
   assign lfsr_c[30] = (data_in[0] ^ data_in[1] ^ lfsr_q[0] ^ lfsr_q[1]);
   assign lfsr_c[31] = (data_in[1] ^ lfsr_q[1]);


  always @(posedge clk, posedge rst) begin
    if(rst) begin
      lfsr_q <= {32{1'b1}};
    end
    else begin
      lfsr_q <= crc_en ? lfsr_c : lfsr_q;
    end
  end 
endmodule 
