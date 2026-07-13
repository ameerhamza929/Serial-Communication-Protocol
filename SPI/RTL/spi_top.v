`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : spi_top
// Board       : Nexys A7
//
// Description:
// Top-level SPI demonstration design.
//
// Features
// --------
// • Push button starts SPI transmission
// • Switches provide transmit data
// • LEDs display received data and SPI status
// • Communicates with an external SPI slave
//
// Lab Tasks
// ---------
// 1. Connect the reset signal.
// 2. Detect push-button press.
// 3. Generate a one-clock-cycle start pulse.
// 4. Instantiate the SPI Master.
// 5. Connect the SPI interface.
// 6. Display received data and status on LEDs.
//
//////////////////////////////////////////////////////////////////////////////////

module spi_top #(
    parameter integer CLOCK_DIV = 50
)
(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire [7:0]  SW,

    // SPI Interface
    input  wire        spi_miso,
    output wire        spi_mosi,
    output wire        spi_sclk,
    output wire        spi_cs_n,

    output wire [15:0] LED
);

    

    wire rst_n;
     assign rst_n = CPU_RESETN;

    
    reg btnc_d;


    wire start_spi;
    
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) btnc_d <= 0;
        else        btnc_d <= BTNC;
    end
    
    assign start_spi =  btnc_d & ~BTNC;
    
    wire [7:0] rx_data;

    wire busy;

    wire done;

     spi_master #(
     .CLOCK_DIV(50)
    ) u_spi_master (
        .clk     (CLK100MHZ),
        .rst_n   (rst_n),
    
        .start   (start_spi),
        .tx_data (SW),
        .miso    (spi_miso),
    
        .mosi    (spi_mosi),
        .sclk    (spi_sclk),
        .cs_n    (spi_cs_n),
    
        .rx_data (rx_data),
    
        .busy    (busy),
        .done    (done)
    );


    assign LED[7:0] = rx_data;


   
    assign LED[8] = busy;

    
    assign LED[9] = done;
    assign LED[15:0] = 0;

endmodule