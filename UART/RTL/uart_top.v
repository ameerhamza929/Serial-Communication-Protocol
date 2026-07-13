`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : uart_top
// Board       : NEXYS A7
//
// Description:
// Top-level UART design.
//
// Lab Tasks:
// 1. Generate baud-rate ticks for transmitter.
// 2. Generate 16× oversampling ticks for receiver.
// 3. Detect push-button press to start transmission.
// 4. Instantiate UART Transmitter.
// 5. Instantiate UART Receiver.
// 6. Display received data on LEDs.
// 7. Display UART status signals.
//
//////////////////////////////////////////////////////////////////////////////////

module uart_top #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE      = 9600
)
(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire [7:0]  SW,

    // USB-UART Interface
    input  wire        UART_TXD_IN,
    output wire        UART_RXD_OUT,

    output wire [15:0] LED
);

    //====================================================
    // Reset Signal
    //====================================================
    wire rst_n;

    

    
    //====================================================
    // Internal Signals
    //====================================================

    // Baud-rate generator outputs
    wire tx_tick;
    wire rx_sample_tick;

    // UART Transmitter signals
    wire tx_busy;
    wire tx_done;

    // UART Receiver signals
    wire rx_valid;
    wire framing_error;
    wire [7:0] rx_data;

    //====================================================
    // Push Button Edge Detector
    //====================================================

    wire btnc_d;

    debounce Debounce(
        .clk(CLK100MHZ) ,
        .rst_n(CPU_RESETN),
        .btn(BTNC),
        .btn_db(btnc_d)
    );
   
   
   

    wire start_tx;


 
    baud_rate_generator #(
    .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ), // 100 MHz system clock
    .TICK_RATE_HZ(BAUD_RATE)          // Generate 9600 Hz tick
    ) u_baud_rate_generator (
        .clk   (CLK100MHZ),
        .rst_n (CPU_RESETN),
        .tick  (tx_tick)
    );
    
    
    
  
    
    baud_rate_generator #(
    .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ), // 100 MHz system clock
    .TICK_RATE_HZ(BAUD_RATE * 16)          // Generate 9600 Hz tick
    ) Receiver (
        .clk   (CLK100MHZ),
        .rst_n (CPU_RESETN),
        .tick  (rx_sample_tick)
    );


   
    uart_tx #(
    .packet_size(10)
        ) u_uart_tx (
            .clk       (CLK100MHZ),
            .rst_n     (CPU_RESETN),
            .baud_tick (tx_tick),
            .start     (btnc_d),
            .data_in   (SW),
        
            .tx        (UART_RXD_OUT),
            .busy      (tx_busy),
            .done      (tx_done)
        );

    
    
    uart_rx #(
    .OVERSAMPLE(16)
     ) u_uart_rx (
         .clk            (CLK100MHZ),
         .rst_n          (CPU_RESETN),
         .sample_tick    (rx_sample_tick),
         .rx             (UART_TXD_IN),
     
         .data_out       (rx_data),
         .data_valid     (rx_valid),
         .framing_error  (framing_error)
     );
    
    
    
    
    
    
    
    
    
    
  
    
    assign LED[7:0] = rx_data;

    assign LED[8] = tx_busy;

    assign LED[9] = tx_done;

    assign LED[10] = rx_valid;

    assign LED[11] = framing_error;
    
    assign LED [15:12] = 0;

endmodule