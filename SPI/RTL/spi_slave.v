`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : spi_slave
//
// Description:
// SPI Slave Controller
//
// Features
// --------
// • SPI Mode 0 (CPOL = 0, CPHA = 0)
// • 8-bit Full-Duplex Communication
// • Receives data from MOSI
// • Sends data on MISO
//
// Lab Tasks
// ---------
// 1. Detect SPI clock edges.
// 2. Detect Chip Select.
// 3. Receive one byte.
// 4. Transmit one byte.
// 5. Generate data_valid after reception.
//
//////////////////////////////////////////////////////////////////////////////////

module spi_slave
(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       sclk,
    input  wire       cs_n,

    input  wire       mosi,
    output reg        miso,

    input  wire [7:0] tx_data,

    output reg [7:0]  rx_data,

    output reg        data_valid
);


    reg sclk_d;

    reg cs_d;

    reg [2:0] bit_cnt;

    reg [7:0] tx_shift;

    reg [7:0] rx_shift;


    

    wire sclk_rise;


    

    wire sclk_fall;
    
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sclk_d <= 0;
        else        sclk_d <= sclk;
    end
    
    assign sclk_rise =  sclk & ~sclk_d;
    assign sclk_fall = ~sclk &  sclk_d;

    

    wire cs_fall;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cs_d <= 0;
        else        cs_d <= cs_n;
    end

    assign cs_fall = ~cs_n &  cs_d;





    //====================================================
    // SPI Slave Logic
    //====================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt    <= 0;
            tx_shift   <= 0;
            rx_shift   <= 0;
            rx_data    <= 0;
            data_valid <= 0;
            miso       <= 0;
        end else begin
            data_valid <= 0;  // default
    
            if (cs_n) begin
                bit_cnt  <= 0;
                tx_shift <= tx_data;
            end else begin
    
                if (cs_fall) begin
                    miso <= tx_data[7];   // preload MSB before first sclk_rise
                    tx_shift <= {tx_shift[6:0], 1'b0};
                end
    
                if (sclk_rise) begin
                    rx_shift <= {rx_shift[6:0], mosi};
                end
    
                if (sclk_fall) begin
                    miso     <= tx_shift[7];
                    tx_shift <= {tx_shift[6:0], 1'b0};
                    if (bit_cnt == 3'b111) begin
                        rx_data    <= rx_shift;
                        data_valid <= 1;
                        bit_cnt    <= 0;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end
        end
    end

endmodule