`timescale 1ns / 1ps

module sw_axis
  #(
    parameter PREFIX_STRING = "SWITCHES CHANGED! NEW VALUE: 0x",
    parameter PREFIX_CHARS  = 31,
    parameter POSTFIX_STRING = "", 
    parameter POSTFIX_CHARS  = 0,  
    parameter INCLUDE_CRLF   = 1,  
    parameter GPIO_WIDTH    = 4,      
    parameter AXI_OUT_WIDTH = 8
    )
   ( 
     input			         clk,
     input			         nrst,         

     input [GPIO_WIDTH-1:0]	 gpio_in,      
   
     output [AXI_OUT_WIDTH-1:0] m_axis_data,
     output			         m_axis_valid,
     output			         m_axis_last,
     output [11:0]		     m_axis_tuser,
     input			         m_axis_ready
   );

   logic [GPIO_WIDTH-1:0] gpio_debounced;
   logic [GPIO_WIDTH-1:0] gpio_prev;
   logic                  start_tx;

   debounce #(
       .DEBOUNCE_LIMIT(500000), 
       .NUM_PINS(GPIO_WIDTH)
   ) debounce_i (
      .clk(clk),
      .nrst(nrst),
      .gpio_in(~gpio_in), 
      .gpio_out(gpio_debounced)
   );

   typedef enum logic [2:0] {IDLE, SEND_PREFIX, SEND_DATA, SEND_POSTFIX, SEND_CRLF} state_type;
   state_type current_state, next_state;

   logic [7:0]  state_counter;
   logic [GPIO_WIDTH-1:0] latched_sw;

   localparam DATA_CHARS = (GPIO_WIDTH + 3) / 4; 
   localparam CRLF_LEN   = (INCLUDE_CRLF) ? 2 : 0;
   localparam TOTAL_LEN  = PREFIX_CHARS + DATA_CHARS + POSTFIX_CHARS + CRLF_LEN; 
   
   assign m_axis_tuser = TOTAL_LEN;

   always_ff @(posedge clk or negedge nrst) begin
      if (!nrst) begin
         current_state <= IDLE;
         gpio_prev     <= 0;
         start_tx      <= 0;
      end else begin
         current_state <= next_state;
         gpio_prev     <= gpio_debounced;
         
         if (gpio_debounced != gpio_prev && current_state == IDLE)
            start_tx <= 1;
         else
            start_tx <= 0;
      end
   end

   always_comb begin
      next_state = current_state;
      case (current_state)
         IDLE:         if (start_tx) next_state = SEND_PREFIX;
         
         SEND_PREFIX:  if (state_counter == (PREFIX_CHARS-1) && m_axis_ready) 
                          next_state = SEND_DATA;
                          
         SEND_DATA:    if (state_counter == (DATA_CHARS-1) && m_axis_ready) 
                          next_state = (POSTFIX_CHARS > 0) ? SEND_POSTFIX : 
                                       (INCLUDE_CRLF ? SEND_CRLF : IDLE);
                                       
         SEND_POSTFIX: if (state_counter == (POSTFIX_CHARS-1) && m_axis_ready)
                          next_state = (INCLUDE_CRLF) ? SEND_CRLF : IDLE;
                          
         SEND_CRLF:    if (state_counter == (CRLF_LEN-1) && m_axis_ready) 
                          next_state = IDLE;
      endcase
   end

   always_ff @(posedge clk or negedge nrst) begin
      if (!nrst) begin
         state_counter <= 0;
         latched_sw    <= 0;
      end else begin
         if (current_state == IDLE && start_tx) begin
            state_counter <= 0;
            latched_sw    <= gpio_debounced;
         end 
         else if (m_axis_ready && (current_state != IDLE)) begin
            if (next_state != current_state)
               state_counter <= 0;
            else
               state_counter <= state_counter + 1'b1;
         end
      end
   end

   logic [7:0] prefix_array [0:PREFIX_CHARS-1];
   genvar i;
   generate
      for (i = 0; i < PREFIX_CHARS; i = i + 1) begin : gen_prefix
         assign prefix_array[i] = PREFIX_STRING[(PREFIX_CHARS-1-i)*8 +: 8];
      end
   endgenerate

   logic [7:0] postfix_array [0:POSTFIX_CHARS-1];
   generate
      if (POSTFIX_CHARS > 0) begin : gen_postfix_block
         for (i = 0; i < POSTFIX_CHARS; i = i + 1) begin : gen_postfix
            assign postfix_array[i] = POSTFIX_STRING[(POSTFIX_CHARS-1-i)*8 +: 8];
         end
      end
   endgenerate

   function automatic [7:0] to_hex(input [3:0] val);
      return (val < 10) ? (8'd48 + val) : (8'd55 + val);
   endfunction

   logic [7:0] tx_data_mux;
   logic       tx_valid_mux;
   logic       tx_last_mux;

   always_comb begin
      tx_valid_mux = 1'b1;
      tx_last_mux  = 1'b0;
      tx_data_mux  = 8'h00;
      
      case (current_state)
         SEND_PREFIX:  tx_data_mux = prefix_array[state_counter];
         
         SEND_DATA:    tx_data_mux = to_hex(latched_sw[3:0]);
         
         SEND_POSTFIX: tx_data_mux = postfix_array[state_counter];
         
         SEND_CRLF: begin
            tx_data_mux = (state_counter == 0) ? 8'h0D : 8'h0A;
            if (state_counter == (CRLF_LEN-1)) tx_last_mux = 1'b1;
         end
         
         default: begin
            tx_valid_mux = 1'b0;
         end
      endcase
      
      if (current_state == SEND_DATA && next_state == IDLE) tx_last_mux = 1'b1;
      if (current_state == SEND_POSTFIX && next_state == IDLE) tx_last_mux = 1'b1;
   end

   assign m_axis_data  = tx_data_mux;
   assign m_axis_valid = tx_valid_mux;
   assign m_axis_last  = tx_last_mux;

endmodule