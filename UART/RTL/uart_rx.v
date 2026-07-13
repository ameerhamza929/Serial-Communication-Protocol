`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_rx
// Description:
// UART Receiver using 16x oversampling.
//
// Lab Task:
// Complete the UART Receiver by implementing:
//   1. Input synchronization
//   2. UART state machine
//   3. Start bit detection
//   4. Data bit reception
//   5. Stop bit verification
//   6. Data valid and framing error generation
//////////////////////////////////////////////////////////////////////////////////

module uart_rx #(
    parameter integer OVERSAMPLE = 16
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sample_tick,
    input  wire       rx,

    output reg [7:0]  data_out,
    output reg        data_valid,
    output reg        framing_error
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
    reg [1:0] state, next_state;

    reg [3:0] sample_count;

    reg [2:0] bit_index;

    reg [7:0] shift_reg;
    reg [15:0] sample_data;

    // Synchronizer Registers
    reg rx_meta;
    reg rx_sync;

    //====================================================
    // Part 1
    // Synchronize the asynchronous RX input
    //====================================================
    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            rx_meta <= 0;
            rx_sync <= 0;
        end
        else
        begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end


    //====================================================
    // Part 2
    // UART Receiver State Machine
    //====================================================
    
    always@(posedge sample_tick or negedge rst_n)begin
        if(!rst_n)begin
            state <= ST_IDLE;
            sample_count <= 0;
            bit_index <= 0;
            shift_reg <= 0;
            sample_data <= 0;
            data_valid <= 1'b0;
            data_out <= 0;
            framing_error <= 0;
        end
        else begin
            state <= next_state;
            data_valid <= 1'b0;
            framing_error <= 0;
            if(state == ST_START)begin
                sample_count<= sample_count + 1;
                sample_data[sample_count] <= rx_sync;
                if( sample_count == 15)begin
                    sample_count <= 0;
                end
            end
            
            if(state == ST_DATA) begin
                sample_count<= sample_count + 1;
                sample_data[sample_count] <= rx_sync;
                if(sample_count == 15)begin
                    shift_reg <= {sample_data[8],shift_reg[7:1]};
                    sample_count <= 0;
                    sample_data <= 0;
                    bit_index <= bit_index + 1;
                end       
            end
            if(state == ST_STOP) begin
                sample_count<= sample_count + 1;
                sample_data[sample_count] <= rx_sync;
                if(sample_count == 15)begin
                    sample_count <= 0;
                    if(sample_data[8] == 1)begin
                        data_valid <= 1;
                        data_out <= shift_reg;
                    end
                    else begin
                        framing_error <= 1;
                    end
                end  
            end
        
        end
    end
    
    
    
    
    always @(*) begin
    
       case(state)
       ST_IDLE:
       begin
           next_state = (!rx_sync) ? ST_START:ST_IDLE;
       end

       ST_START:
       begin
          
           next_state = (sample_count == 15) ?  ((!sample_data[8]) ? ST_DATA:ST_IDLE) : ST_START ;
       end

       ST_DATA:
       begin
           
           next_state = (bit_index == 3'b111 && sample_count == 15) ? ST_STOP : ST_DATA;
       end

    ST_STOP:
        begin
            next_state = (sample_count == 15) ? ST_IDLE : ST_STOP;
        end

      

       endcase

   end
       
        
    

endmodule