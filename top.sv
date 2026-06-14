`timescale 1 ns / 1 ps


module top (
    input  wire       CLK,       
    input  wire       nRST,      

    input  wire [3:0] BUTTONS,   
    output wire [4:0] LEDS,      

    output wire       ETH_MDC,
    inout  wire       ETH_MDIO,
    output wire       ETH_REF_CLK,
    input  wire       ETH_CRSDV,
    input  wire [1:0] ETH_RXD,
    output wire       ETH_TXEN,
    output wire [1:0] ETH_TXD
);

    assign ETH_REF_CLK = ~CLK;
    
    wire [7:0]  rx_tdata;
    wire        rx_tvalid;
    wire        rx_tlast;
    wire        rx_tready;

    wire [7:0]  tx_tdata;
    wire        tx_tvalid;
    wire        tx_tlast;
    wire        tx_tready;
    wire [11:0] tx_tuser;

  
    rmii_axis_v1_0 #(
        .FPGA_IP_1(192), .FPGA_IP_2(168), .FPGA_IP_3(0), .FPGA_IP_4(111),
        .HOST_IP_1(192), .HOST_IP_2(168), .HOST_IP_3(0), .HOST_IP_4(110),
        .FPGA_PORT(17767),
        .HOST_PORT(17767),
        .FPGA_MAC(48'he86a64e7e830),
        .HOST_MAC(48'hf0761c3ed021),
        .HEADER_CHECKSUM(16'h65F4),
        .CHECK_DESTINATION(1)          
    ) eth_core (
        .ETH_MDC    (ETH_MDC),
        .ETH_MDIO   (ETH_MDIO),
        .ETH_CRSDV  (ETH_CRSDV),
        .ETH_RXD    (ETH_RXD),
        .ETH_TXEN   (ETH_TXEN),
        .ETH_TXD    (ETH_TXD),

        .m00_axis_aclk   (CLK),
        .m00_axis_aresetn(nRST),
        .m00_axis_tdata  (rx_tdata),
        .m00_axis_tvalid (rx_tvalid),
        .m00_axis_tlast  (rx_tlast),
        .m00_axis_tready (rx_tready),

        .s00_axis_aclk   (CLK),
        .s00_axis_aresetn(nRST),
        .s00_axis_tdata  (tx_tdata),
        .s00_axis_tvalid (tx_tvalid),
        .s00_axis_tlast  (tx_tlast),
        .s00_axis_tuser  (tx_tuser),
        .s00_axis_tready (tx_tready)
    );

    axis_gpio_v1_0 #(
        .SW_WIDTH (4),
        .LED_WIDTH(5)
    ) gpio_core (
        .SW (BUTTONS),
        .LED(LEDS),

        .s00_axis_aclk   (CLK),
        .s00_axis_aresetn(nRST),
        .s00_axis_tdata  (rx_tdata),
        .s00_axis_tvalid (rx_tvalid),
        .s00_axis_tlast  (rx_tlast),
        .s00_axis_tready (rx_tready),

        .m00_axis_aclk   (CLK),
        .m00_axis_aresetn(nRST),
        .m00_axis_tdata  (tx_tdata),
        .m00_axis_tvalid (tx_tvalid),
        .m00_axis_tlast  (tx_tlast),
        .m00_axis_tuser  (tx_tuser),
        .m00_axis_tready (tx_tready)
    );

endmodule