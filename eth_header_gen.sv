`timescale 1ns / 1ps

module eth_header_gen
  #(
   parameter [31:0] FPGA_IP   = 32'hC0A8006F,      
    parameter [31:0] HOST_IP   = 32'hC0A8006E,     
    parameter [15:0] FPGA_PORT = 16'h4567,          
    parameter [15:0] HOST_PORT = 16'h4567,          
    parameter [47:0] FPGA_MAC  = 48'he86a64e7e830,  
    parameter [47:0] HOST_MAC  = 48'hf0761c3ed021,  
    parameter [15:0] HEADER_CHECKSUM = 16'h65F4     
    )
   (
    input  [11:0]   payload_bytes,
    output [499:0]  output_header
    );

   typedef struct packed {
      logic [1:0][7:0] udp_checksum;
      logic [1:0][7:0] length;
      logic [1:0][7:0] port_destination;
      logic [1:0][7:0] port_source;
   } udp_header;
   
   typedef struct packed {
      udp_header       udp;
      logic [3:0][7:0] ip_destination;
      logic [3:0][7:0] ip_source;
      logic [1:0][7:0] header_checksum;
      logic [7:0]      protocol;
      logic [7:0]      time_to_live;
      logic [1:0][7:0] flags_fragment_offset;
      logic [1:0][7:0] identification;
      logic [1:0][7:0] total_length;
      logic [7:0]      dcsp_ecn;
      logic [7:0]      version_ihl;
   } ipv4_header;
   
   typedef struct packed {
      ipv4_header      ipv4;
      logic [1:0][7:0] eth_type_length;
      logic [5:0][7:0] mac_source;
      logic [5:0][7:0] mac_destination;
   } ethernet_header;
   
   localparam [15:0] ETHERTYPE = 16'h0800;
   localparam [7:0]  VERSION_IHL = 8'h45;
   localparam [7:0]  DCSP_ECN = 8'h00;
   localparam [15:0] IDENTIFICATION = 16'h0000;
   localparam [15:0] FLAGS_FRAGMENT_OFFSET = 16'h0000;
   localparam [7:0]  TIME_TO_LIVE = 8'h40;
   localparam [7:0]  PROTOCOL = 8'h11;
   localparam [15:0] UDP_CHECKSUM = 16'h0000;
   
   localparam [15:0] UDP_HEADER_BYTES = $bits(udp_header)/8;
   localparam [15:0] IPV4_HEADER_BYTES = $bits(ipv4_header)/8;
   
   logic [15:0] UDP_LENGTH;
   assign UDP_LENGTH = UDP_HEADER_BYTES + payload_bytes;
   
   logic [15:0] IPV4_LENGTH;
   assign IPV4_LENGTH = IPV4_HEADER_BYTES + payload_bytes;
   
   ethernet_header header;

   assign header.mac_source      = {FPGA_MAC[7:0], FPGA_MAC[15:8], FPGA_MAC[23:16], FPGA_MAC[31:24], FPGA_MAC[39:32], FPGA_MAC[47:40]};
   assign header.mac_destination = {HOST_MAC[7:0], HOST_MAC[15:8], HOST_MAC[23:16], HOST_MAC[31:24], HOST_MAC[39:32], HOST_MAC[47:40]};
   
   assign header.eth_type_length = {ETHERTYPE[7:0], ETHERTYPE[15:8]};
   
   assign header.ipv4.version_ihl  = VERSION_IHL;
   assign header.ipv4.dcsp_ecn     = DCSP_ECN;
   assign header.ipv4.time_to_live = TIME_TO_LIVE;
   assign header.ipv4.protocol     = PROTOCOL;
 
   assign header.ipv4.total_length          = {IPV4_LENGTH[7:0], IPV4_LENGTH[15:8]};
   assign header.ipv4.identification        = {IDENTIFICATION[7:0], IDENTIFICATION[15:8]};
   assign header.ipv4.flags_fragment_offset = {FLAGS_FRAGMENT_OFFSET[7:0], FLAGS_FRAGMENT_OFFSET[15:8]};
   assign header.ipv4.header_checksum       = {HEADER_CHECKSUM[7:0], HEADER_CHECKSUM[15:8]};
   
   assign header.ipv4.ip_source      = {FPGA_IP[7:0], FPGA_IP[15:8], FPGA_IP[23:16], FPGA_IP[31:24]};
   assign header.ipv4.ip_destination = {HOST_IP[7:0], HOST_IP[15:8], HOST_IP[23:16], HOST_IP[31:24]};
   
   assign header.ipv4.udp.port_source      = {FPGA_PORT[7:0], FPGA_PORT[15:8]};
   assign header.ipv4.udp.port_destination = {HOST_PORT[7:0], HOST_PORT[15:8]};
   assign header.ipv4.udp.length           = {UDP_LENGTH[7:0], UDP_LENGTH[15:8]};
   assign header.ipv4.udp.udp_checksum     = {UDP_CHECKSUM[7:0], UDP_CHECKSUM[15:8]};

   assign output_header = header;

endmodule