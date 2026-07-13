`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_tx
// Description:
// UART Transmitter (8 Data Bits, No Parity, 1 Stop Bit)
//
// Lab Task:
// Complete the UART transmitter by implementing:
//   1. Idle state
//   2. Start bit transmission
//   3. Data bit transmission (LSB first)
//   4. Stop bit transmission
//   5. Busy and done signal generation
//////////////////////////////////////////////////////////////////////////////////

module uart_tx #(
 parameter packet_size = 10
 )(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       baud_tick,
    input  wire       start,
    input  wire [7:0] data_in,

    output reg        tx,
    output reg        busy,
    output reg        done
);

    //====================================================
    // State Encoding
    //====================================================
    localparam ST_IDLE  = 2'd0;
    localparam ST_START = 2'd1;
    localparam ST_DATA  = 2'd2;
    localparam ST_STOP  = 2'd3;

    //====================================================
    // Internal Registers
    //====================================================
    reg [1:0] state,next_state;

    reg [2:0] bit_index;

    reg [7:0] shift_reg;

    //====================================================
    // UART Transmitter State Machine
    //====================================================
    
    always@(posedge baud_tick or negedge rst_n)begin
        if(!rst_n)begin
            state <= ST_IDLE;
            shift_reg <= 0;
            bit_index <= 0;
            busy <= 0;
            done <= 0;
        end
        else begin
            if(state == ST_IDLE) begin
                shift_reg <= data_in;
                bit_index <= 0;
                done <= 0;
            end
            if(state == ST_START) begin
                busy <= 1;
            end
            if(state == ST_DATA)begin
                shift_reg <= {1'b0,shift_reg[7:1]};
                bit_index <= bit_index + 1;
            end
            if (state == ST_STOP)begin
                done <= 1;
                busy <= 0;
            end
            state <= next_state;
        end
        
    end
    
    
    always @(*)
    begin
       

            case(state)

                ST_IDLE:
                begin
                    tx = 1'b1;
                    // Wait for start signal
                    next_state = (start) ? ST_START:ST_IDLE;
                    
                end
   
                ST_START:
                begin
    
                    tx = 1'b0;
                    // Wait for baud_tick
                    next_state = ST_DATA;
    
                end
    
  
                ST_DATA:
                begin
                    tx = shift_reg[0];
                    next_state = (bit_index == 3'b111) ?  ST_STOP:ST_DATA;
                end
    
                ST_STOP:
                begin
   
                    tx = 1'b1;
                    next_state = ST_IDLE;
    
                end
            
            endcase

        

    end

endmodule