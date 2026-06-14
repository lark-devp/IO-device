`timescale 1ns / 1ps

module packet_gen
  #(
   parameter [31:0] FPGA_IP = 32'hC0A8006F, 
   parameter [31:0] HOST_IP = 32'hC0A8006E, 
   parameter [15:0] FPGA_PORT = 16'h4567,
   parameter [15:0] HOST_PORT = 16'h4567,
   parameter [47:0] FPGA_MAC = 48'he86a64e7e830,
   parameter [47:0] HOST_MAC = 48'hf0761c3ed021, 
  parameter [15:0] HEADER_CHECKSUM = 16'hB89B,
    
   parameter        MII_WIDTH = 2,
   parameter        WORD_BYTES = 1
  )
   (
    input                         CLK,
    input                         nRST,

    input [WORD_BYTES*8-1:0]      S_AXIS_TDATA,
    input                         S_AXIS_TVALID,
    input                         S_AXIS_TLAST,
    output                        S_AXIS_TREADY,
    input [11:0]                  S_AXIS_TUSER,

    output logic                  TX_EN,
    output logic [MII_WIDTH-1:0]  TXD
   );

   typedef struct packed {
      logic [1:0][7:0] udp_checksum;
      logic [1:0][7:0] length;
      logic [1:0][7:0] port_destination;
      logic [1:0][7:0] port_source;
   } udp_header;
   
   typedef struct packed {
      udp_header udp;
      logic [3:0][7:0] ip_destination;
      logic [3:0][7:0] ip_source;
      logic [1:0][7:0] header_checksum;
      logic [7:0] protocol;
      logic [7:0] time_to_live;
      logic [1:0][7:0] flags_fragment_offset;
      logic [1:0][7:0] identification;
      logic [1:0][7:0] total_length;
      logic [7:0] dcsp_ecn;
      logic [7:0] version_ihl;
   } ipv4_header;
   
   typedef struct packed {
      ipv4_header ipv4;
      logic [1:0][7:0] eth_type_length;
      logic [5:0][7:0] mac_source;
      logic [5:0][7:0] mac_destination;
   } ethernet_header;

   localparam HEADER_BITS = $bits(ethernet_header);
   localparam HEADER_BYTES = HEADER_BITS/8;

   ethernet_header header;
   logic [HEADER_BITS-1 : 0] header_buffer;
   logic [7*8-1:0]           preamble_buffer;
   logic [7:0]               sfd_buffer;
   logic [31:0]              data_buffer;
   logic [31:0]              fcs_buffer;
   wire  [31:0]              fcs;

   wire [15:0] DATA_BYTES  = S_AXIS_TUSER * WORD_BYTES;
   
   localparam PREAMBLE_LENGTH = 7 * 8 / MII_WIDTH;
   localparam SFD_LENGTH      = 1 * 8 / MII_WIDTH;
   localparam HEADER_LENGTH   = HEADER_BYTES * 8 / MII_WIDTH;
   localparam FCS_LENGTH      = 4 * 8 / MII_WIDTH;
   localparam WAIT_LENGTH     = 12 * 8 / MII_WIDTH; 
   wire [31:0] DATA_LENGTH    = DATA_BYTES * 8 / MII_WIDTH;

   typedef enum {IDLE, PREAMBLE, SFD, HEADER, DATA, FCS, WAIT} state_type;
   state_type current_state = IDLE, next_state = IDLE;

   logic [11:0] fifo_count;
   logic [7:0]  fifo_out;
   logic fifo_rd_en, fifo_wr_en, fifo_empty;
   localparam FIFO_DEPTH = 2048;

   assign S_AXIS_TREADY = (fifo_count < (FIFO_DEPTH - 64)); 
   assign fifo_wr_en = S_AXIS_TVALID && S_AXIS_TREADY;

   eth_header_gen #(
       .FPGA_MAC(FPGA_MAC), .HOST_MAC(HOST_MAC),
       .FPGA_IP(FPGA_IP),   .HOST_IP(HOST_IP),
       .FPGA_PORT(FPGA_PORT), .HOST_PORT(HOST_PORT),
       .HEADER_CHECKSUM(HEADER_CHECKSUM)
   ) eth_gen_i (
      .payload_bytes(DATA_BYTES),
      .output_header(header)
   );

   generic_fifo_with_count #(
      .DATA_WIDTH(8), .DEPTH(FIFO_DEPTH)
   ) data_buffer_fifo (
      .clk(CLK), .nrst(nRST),
      .din(S_AXIS_TDATA), .we(fifo_wr_en),
      .dout(fifo_out),    .re(fifo_rd_en),
      .count(fifo_count), .empty(fifo_empty)
   );

   logic [11:0] state_counter;
   always_ff @(posedge CLK or negedge nRST) begin
      if(!nRST) state_counter <= 0;
      else      state_counter <= (current_state != next_state) ? 0 : state_counter + 1;
   end

   always_comb begin
      next_state = current_state;
      case (current_state)
         IDLE:     if (fifo_count >= DATA_BYTES && DATA_BYTES > 0) next_state = PREAMBLE;
         PREAMBLE: if (state_counter == PREAMBLE_LENGTH-1) next_state = SFD;
         SFD:      if (state_counter == SFD_LENGTH-1)      next_state = HEADER;
         HEADER:   if (state_counter == HEADER_LENGTH-1)   next_state = DATA;
         DATA:     if (state_counter == DATA_LENGTH-1)     next_state = FCS;
         FCS:      if (state_counter == FCS_LENGTH-1)      next_state = WAIT;
         WAIT:     if (state_counter == WAIT_LENGTH-1)     next_state = IDLE;
      endcase
   end

   always_ff @(posedge CLK or negedge nRST) begin
      if(!nRST) current_state <= IDLE;
      else      current_state <= next_state;
   end

   logic [MII_WIDTH-1:0] tx_data;
   logic tx_valid, fcs_en, fcs_rst;

   always_comb begin
      tx_valid = 1'b1; fcs_en = 1'b0; fcs_rst = 1'b0; tx_data = 0;
      case (current_state)
         IDLE:     begin tx_valid = 0; fcs_rst = 1; end
         PREAMBLE: tx_data = preamble_buffer[MII_WIDTH-1:0];
         SFD:      tx_data = sfd_buffer[MII_WIDTH-1:0];
         HEADER:   begin tx_data = header_buffer[MII_WIDTH-1:0]; fcs_en = 1; end
         DATA:     begin tx_data = data_buffer[MII_WIDTH-1:0];   fcs_en = 1; end
         FCS:      tx_data = fcs_buffer[MII_WIDTH-1:0];
         WAIT:     tx_valid = 0;
         default:  tx_valid = 0;
      endcase
   end

   always_ff @(posedge CLK or negedge nRST) begin
      if (!nRST) begin
         header_buffer <= 0; preamble_buffer <= 0; fifo_rd_en <= 0;
         sfd_buffer <= 0; data_buffer <= 0; fcs_buffer <= 0;
      end else begin
         fifo_rd_en <= 0;
         if (current_state == IDLE) begin
            header_buffer   <= header;
            preamble_buffer <= 56'h55555555555555;
            sfd_buffer      <= 8'hd5;
         end
         
         if (next_state == FCS && current_state != FCS)   fcs_buffer <= fcs;
         if (next_state == DATA && current_state != DATA) begin
            data_buffer <= fifo_out;
            fifo_rd_en  <= 1;
         end

         if (current_state == HEADER)   header_buffer   <= header_buffer   >> MII_WIDTH;
         if (current_state == PREAMBLE) preamble_buffer <= preamble_buffer >> MII_WIDTH;
         if (current_state == SFD)      sfd_buffer      <= sfd_buffer      >> MII_WIDTH;
         if (current_state == FCS)      fcs_buffer      <= fcs_buffer      >> MII_WIDTH;
         
         if (current_state == DATA) begin
            if (state_counter % (8/MII_WIDTH) == ((8/MII_WIDTH)-1)) begin
               data_buffer <= fifo_out;
               fifo_rd_en  <= 1;
            end else begin
               data_buffer <= data_buffer >> MII_WIDTH;
            end
         end
      end
   end

   crc_gen crc_gen_i (
      .clk(CLK), .rst(!nRST || fcs_rst),
      .data_in(tx_data), .crc_en(fcs_en), .crc_out(fcs)
   );

   always_ff @(posedge CLK or negedge nRST) begin
      if(!nRST) begin
         TX_EN <= 0; TXD <= 0;
      end else begin
         TX_EN <= tx_valid;
         TXD   <= tx_data;
      end
   end
endmodule

module generic_fifo_with_count #(parameter DATA_WIDTH = 8, DEPTH = 2048) (
    input clk, nrst,
    input [DATA_WIDTH-1:0] din,
    input we, re,
    output [DATA_WIDTH-1:0] dout,
    output logic [11:0] count,
    output logic empty, full
);
    logic [DATA_WIDTH-1:0] mem [DEPTH-1:0] /* synthesis ramstyle = "no_rw_check, M9K" */;
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;

    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            wr_ptr <= 0; rd_ptr <= 0; count <= 0;
        end else begin
            if (we && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= wr_ptr + 1;
            end
            if (re && !empty) begin
                rd_ptr <= rd_ptr + 1;
            end
            case ({we && !full, re && !empty})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: ;
            endcase
        end
    end
    assign dout  = mem[rd_ptr];
    assign empty = (count == 0);
    assign full  = (count >= DEPTH);
endmodule