`timescale 1 ns / 1 ps

module packet_recv 
  #(
   parameter [31:0]  FPGA_IP   = 32'hC0A8006F,
   parameter [15:0]  FPGA_PORT = 16'h4567,
   parameter [47:0]  FPGA_MAC  = 48'he86a64e7e830,
   parameter         CHECK_DESTINATION = 1,
   parameter         ALLOW_BROADCAST   = 0 
  )
   (
    input [1:0]      RXD,
    input            RXDV, 
    input            clk,  
    input            nRST,
   
    output logic     M_AXIS_TVALID,
    output logic [7:0] M_AXIS_TDATA,
    output logic     M_AXIS_TLAST
  );

 
   localparam [15:0] ETHTYPE_IPV4 = 16'h0800;
   localparam [7:0]  IP_PROTO_UDP = 8'h11;

 
   logic [1:0] rxd_reg;
   logic       rxdv_reg, rxdv_old;
   
   always_ff @(posedge clk) begin
      rxd_reg  <= RXD;
      rxdv_reg <= RXDV;
      rxdv_old <= rxdv_reg;
   end

   typedef enum logic [2:0] {IDLE, HEADER, DATA, DISCARD} state_type;
   state_type state;

   logic [1:0]  tick_phase; 
   logic [7:0]  shift_reg;
   logic [7:0]  curr_byte;
   logic        byte_ready;
   logic [11:0] byte_count;

   logic match_mac, match_ip, match_port, match_ethertype, match_udp, is_broadcast;
   logic dest_ok;

   always_ff @(posedge clk or negedge nRST) begin
      if (!nRST) begin
         tick_phase <= 0;
         shift_reg  <= 0;
         byte_ready <= 0;
         curr_byte  <= 0;
      end else begin
         byte_ready <= 0;
         if (!rxdv_reg) begin
            tick_phase <= 0;
         end else if (state == IDLE) begin
            if (rxd_reg == 2'b11) tick_phase <= 0; 
         end else begin
            shift_reg <= {rxd_reg, shift_reg[7:2]};
            tick_phase <= tick_phase + 1;
            if (tick_phase == 2'b11) begin
               curr_byte  <= {rxd_reg, shift_reg[7:2]};
               byte_ready <= 1;
            end
         end
      end
   end

   always_ff @(posedge clk or negedge nRST) begin
      if (!nRST) begin
         state <= IDLE;
         byte_count <= 0;
         match_mac <= 1; match_ip <= 1; match_port <= 1;
         match_ethertype <= 1; match_udp <= 1; is_broadcast <= 1;
      end else begin
         if (!rxdv_reg) begin
            state <= IDLE;
         end else begin
            case (state)
               IDLE: begin
                  byte_count <= 0;
                  match_mac <= 1; match_ip <= 1; match_port <= 1;
                  match_ethertype <= 1; match_udp <= 1; is_broadcast <= 1;
                  if (rxd_reg == 2'b11) state <= HEADER;
               end

               HEADER: begin
                  if (byte_ready) begin
                     byte_count <= byte_count + 1;

                     if (byte_count <= 5) begin
                        if (curr_byte != FPGA_MAC[47 - byte_count*8 -: 8]) match_mac <= 0;
                        if (curr_byte != 8'hFF) is_broadcast <= 0;
                     end
                     else if (byte_count == 12 && curr_byte != ETHTYPE_IPV4[15:8]) match_ethertype <= 0;
                     else if (byte_count == 13 && curr_byte != ETHTYPE_IPV4[7:0])  match_ethertype <= 0;
                     else if (byte_count == 14 && curr_byte != 8'h45) match_ethertype <= 0;
                     else if (byte_count == 23 && curr_byte != IP_PROTO_UDP) match_udp <= 0;
                     else if (byte_count >= 30 && byte_count <= 33) begin
                        if (curr_byte != FPGA_IP[31 - (byte_count-30)*8 -: 8]) match_ip <= 0;
                     end
                     else if (byte_count >= 36 && byte_count <= 37) begin
                        if (curr_byte != FPGA_PORT[15 - (byte_count-36)*8 -: 8]) match_port <= 0;
                     end

                     if (byte_count == 41) begin 
                        if (match_ethertype && match_udp && 
                           ((match_mac || (ALLOW_BROADCAST && is_broadcast)) && match_ip && match_port || !CHECK_DESTINATION)) 
                           state <= DATA;
                        else
                           state <= DISCARD;
                     end
                  end
               end

               DATA: begin
               end

               DISCARD: begin
               end
               
               default: state <= IDLE;
            endcase
         end
      end
   end

   always_ff @(posedge clk or negedge nRST) begin
      if (!nRST) begin
         M_AXIS_TVALID <= 0;
         M_AXIS_TDATA  <= 0;
         M_AXIS_TLAST  <= 0;
      end else begin
         if (state == DATA && byte_ready) begin
            M_AXIS_TVALID <= 1;
            M_AXIS_TDATA  <= curr_byte;
         end else begin
            M_AXIS_TVALID <= 0;
         end

         if (state == DATA && rxdv_old && !rxdv_reg)
            M_AXIS_TLAST <= 1;
         else
            M_AXIS_TLAST <= 0;
      end
   end

endmodule