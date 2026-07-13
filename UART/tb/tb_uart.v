`timescale 1ns / 1ps

module uart_top_tb;

    reg         CLK100MHZ;
    reg         CPU_RESETN;
    reg         BTNC;
    reg  [7:0]  SW;

    wire        UART_RXD_OUT;
    wire [15:0] LED;

    // Loopback connection
    wire UART_TXD_IN;

    assign UART_TXD_IN = UART_RXD_OUT;

    // DUT
    uart_top #(
        .CLOCK_FREQ_HZ(100_000_000),
        .BAUD_RATE(9600)
    ) dut (
        .CLK100MHZ   (CLK100MHZ),
        .CPU_RESETN  (CPU_RESETN),
        .BTNC        (BTNC),
        .SW          (SW),
        .UART_TXD_IN (UART_TXD_IN),
        .UART_RXD_OUT(UART_RXD_OUT),
        .LED         (LED)
    );

    // 100 MHz clock
    initial begin
        CLK100MHZ = 1;
        forever #5 CLK100MHZ = ~CLK100MHZ;
    end

    // Stimulus
    initial begin
        CPU_RESETN = 0;
        BTNC = 0;
        SW = 8'h00;

        #100;
        CPU_RESETN = 1;

        #100;

        // Transmit 0x55
        SW = 8'h55;
        BTNC = 1;
        #600;
        BTNC = 0;

        // Wait for transmission/reception
        #1200000;

        // Transmit 0xA3
        SW = 8'hA3;
        BTNC = 1;
        #20;
        BTNC = 0;

        #1200000;

        $stop;
    end

endmodule