`timescale 1ns / 1ps

module debounce
  #(
    parameter DEBOUNCE_LIMIT = 500_000, 
    parameter NUM_PINS = 4
  )
   (
    input                       clk,
    input                       nrst,    
    input [NUM_PINS-1:0]        gpio_in,
    output logic [NUM_PINS-1:0] gpio_out
    );

   localparam WIDTH = $clog2(DEBOUNCE_LIMIT);

   logic [NUM_PINS-1:0][WIDTH-1:0] counters;

   always_ff @(posedge clk or negedge nrst) begin
      if (!nrst) begin
         counters <= '0;
         gpio_out <= '0;
      end
      else begin
         for (int i = 0; i < NUM_PINS; i = i + 1) begin
            
            if (gpio_in[i] == gpio_out[i]) begin
               counters[i] <= '0;
            end
            else begin
               if (counters[i] < DEBOUNCE_LIMIT) begin
                  counters[i] <= counters[i] + 1'b1;
               end
               else begin
                  gpio_out[i] <= gpio_in[i];
                  counters[i] <= '0;
               end
            end
            
         end
      end
   end
   
endmodule