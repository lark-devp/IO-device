`timescale 1ns / 1ps

module axis_gpio
  #(
    parameter BYTE_START = 18,     
    parameter GPIO_WIDTH = 5,     
    parameter AXI_WIDTH  = 8       
    )
   ( 
     input		             clk,
     input		             nrst,         
     input [AXI_WIDTH-1:0]   s_axis_data,
     input		             s_axis_valid,
     input		             s_axis_last,
     output		             s_axis_ready,
     output [GPIO_WIDTH-1:0] led_out       
   );

   logic [7:0] axi_counter;
   logic [GPIO_WIDTH-1:0] led_reg;

   assign s_axis_ready = 1'b1;

   always_ff @(posedge clk or negedge nrst) begin
      if (!nrst) begin
         axi_counter <= 0;
         led_reg     <= 0;
      end 
      else if (s_axis_valid) begin
         if (axi_counter == BYTE_START) begin
            led_reg <= s_axis_data[GPIO_WIDTH-1:0];
         end
         
         if (s_axis_last)
            axi_counter <= 0;
         else
            axi_counter <= axi_counter + 1;
      end
   end

   assign led_out = ~led_reg; 

endmodule