`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : spi_master
//
// Description:
// SPI Master Controller
//
// Features
// --------
// • SPI Mode 0 (CPOL = 0, CPHA = 0)
// • Full-Duplex Communication
// • 8-bit Data Transfer
// • Programmable Clock Divider
//
// Lab Tasks
// ---------
// 1. Generate SPI clock.
// 2. Generate Chip Select.
// 3. Transmit one byte.
// 4. Receive one byte.
// 5. Control SPI transfer using an FSM.
//
//////////////////////////////////////////////////////////////////////////////////

module spi_master #(
    parameter integer CLOCK_DIV = 50
)
(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       start,
    input  wire [7:0] tx_data,
    input  wire       miso,

    output reg        mosi,
    output wire        sclk,
    output reg        cs_n,

    output reg [7:0]  rx_data,

    output reg        busy,
    output reg        done
);

    localparam ST_IDLE     = 2'd0;
    localparam ST_TRANSFER = 2'd1;
    localparam ST_DONE     = 2'd2;

    reg [1:0]  state, next_state;
    reg [7:0]  tx_shift;
    reg [7:0]  rx_shift;
    reg [2:0]  bit_cnt;
    reg [31:0] div_cnt;
    reg        div_tick;

    //====================================================
    // Clock Divider
    //====================================================
    wire spi_active = ~cs_n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt  <= 0;
            div_tick <= 0;
        end else if (!spi_active) begin
            div_cnt  <= 0;
            div_tick <= 0;
        end else begin
            if (div_cnt == (CLOCK_DIV-1)/2) begin
                div_cnt  <= 0;
                div_tick <= ~div_tick;
            end else begin
                div_cnt <= div_cnt + 1;
            end
        end
    end

    assign sclk = div_tick;

    
    reg sclk_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sclk_d <= 0;
        else        sclk_d <= sclk;
    end

    wire sclk_rise =  sclk & ~sclk_d;
    wire sclk_fall = ~sclk &  sclk_d;

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            tx_shift <= 0;
            rx_shift <= 0;
            bit_cnt  <= 0;
            mosi     <= 0;
            cs_n     <= 1;
            rx_data  <= 0;
            busy     <= 0;
            done     <= 0;
        end else begin
            state <= next_state;
            done  <= 0;

            case (state)

                ST_IDLE: begin
                    busy <= 0;
                    if (start) begin
                        tx_shift <= tx_data;
                        mosi     <= tx_data[7];  // preload MSB before first sclk_rise (CPHA=0)
                        cs_n     <= 0;
                        bit_cnt  <= 0;
                    end
                end

                ST_TRANSFER: begin
                    busy <= 1;
                    if (sclk_rise) begin
                        rx_shift <= {rx_shift[6:0], miso};
                    end
                    if (sclk_fall) begin
                        tx_shift <= {tx_shift[6:0], 1'b0};
                        mosi     <= tx_shift[6];      // next bit to present
                        bit_cnt  <= bit_cnt + 1;
                    end
                end

                ST_DONE: begin
                    cs_n    <= 1;
                    done    <= 1;
                    rx_data <= rx_shift;
                    busy    <= 0;
                end

            endcase
        end
    end


    always @(*) begin
        case (state)
            ST_IDLE:     next_state = start ? ST_TRANSFER : ST_IDLE;
            ST_TRANSFER: next_state = (sclk_fall && bit_cnt == 3'b111) ? ST_DONE : ST_TRANSFER;
            ST_DONE:     next_state = ST_IDLE;
            default:     next_state = ST_IDLE;
        endcase
    end

endmodule