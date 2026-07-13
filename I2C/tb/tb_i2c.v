`timescale 1ns/1ps


module tb_i2c;

    //------------------------------------------------------------
    // Clock / Reset
    //------------------------------------------------------------

    reg clk;
    reg rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;      //100MHz
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    //------------------------------------------------------------
    // Master Signals
    //------------------------------------------------------------

    reg         start;
    reg         rw;
    reg [6:0]   slave_addr;
    reg [7:0]   tx_data;

    wire [7:0]  rx_data;
    wire        busy;
    wire        done;
    wire        ack_error;

    wire scl;
    wire sda;

    //------------------------------------------------------------
    // Slave Signals
    //------------------------------------------------------------

    wire [7:0] slave_rx;
    reg  [7:0] slave_tx;
    wire       data_valid;

    //------------------------------------------------------------
    // Master
    //------------------------------------------------------------

    i2c_master #(
        .CLOCK_FREQ_HZ(100_000_000),
        .I2C_FREQ_HZ(100_000)
    ) master_inst (

        .clk(clk),
        .rst_n(rst_n),

        .start(start),
        .rw(rw),

        .slave_addr(slave_addr),
        .tx_data(tx_data),

        .rx_data(rx_data),

        .busy(busy),
        .done(done),
        .ack_error(ack_error),

        .scl(scl),
        .sda(sda)
    );

    //------------------------------------------------------------
    // Slave
    //------------------------------------------------------------

    i2c_slave #(
        .SLAVE_ADDR(7'h50)
    ) slave_inst (

        .clk(clk),
        .rst_n(rst_n),

        .scl(scl),
        .sda(sda),

        .received_data(slave_rx),
        .transmit_data(slave_tx),

        .data_valid(data_valid)
    );

    //------------------------------------------------------------
    // Test
    //------------------------------------------------------------

    initial begin

        start      = 0;
        rw         = 0;
        slave_addr = 7'h50;

        tx_data    = 8'hA5;
        slave_tx   = 8'h3C;

        @(posedge rst_n);

        //--------------------------------------------------------
        // WRITE TEST
        //--------------------------------------------------------

        $display("\n==============================");
        $display("WRITE TEST");
        $display("==============================");

        #1000;

        @(posedge clk);
        rw    = 0;
        start = 1;

        @(posedge clk);
        start = 0;

        @(posedge done);

        #1000;

        $display("Master TX = %02X", tx_data);
        $display("Slave RX  = %02X", slave_rx);
        $display("ACK Error = %0d", ack_error);

        //--------------------------------------------------------
        // READ TEST
        //--------------------------------------------------------

        $display("\n==============================");
        $display("READ TEST");
        $display("==============================");

        tx_data  = 8'h00;
        slave_tx = 8'h5A;

        #1000;

        @(posedge clk);
        rw    = 1;
        start = 1;

        @(posedge clk);
        start = 0;

        @(posedge done);

        #1000;

        $display("Slave TX  = %02X", slave_tx);
        $display("Master RX = %02X", rx_data);
        $display("ACK Error = %0d", ack_error);

        //--------------------------------------------------------
        // PASS / FAIL
        //--------------------------------------------------------

        if ((slave_rx == 8'hA5) &&
            (rx_data  == 8'h5A) &&
            (!ack_error))
            $display("\n*********** PASS ***********");
        else
            $display("\n*********** FAIL ***********");

        #5000;
        $finish;

    end

endmodule