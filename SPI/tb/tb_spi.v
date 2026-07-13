`timescale 1ns/1ps

module tb_spi;

    //-------------------------------------------------
    // Clock / Reset
    //-------------------------------------------------

    reg clk;
    reg rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;      // 100 MHz
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    //-------------------------------------------------
    // Master Inputs
    //-------------------------------------------------

    reg        start;
    reg [7:0]  master_tx;

    //-------------------------------------------------
    // Slave Inputs
    //-------------------------------------------------

    reg [7:0] slave_tx;

    //-------------------------------------------------
    // SPI Wires
    //-------------------------------------------------

    wire mosi;
    wire miso;
    wire sclk;
    wire cs_n;

    //-------------------------------------------------
    // Outputs
    //-------------------------------------------------

    wire [7:0] master_rx;
    wire [7:0] slave_rx;

    wire busy;
    wire done;
    wire data_valid;

    //-------------------------------------------------
    // Master
    //-------------------------------------------------

    spi_master #(
        .CLOCK_DIV(10)
    ) master_inst (
        .clk(clk),
        .rst_n(rst_n),

        .start(start),
        .tx_data(master_tx),

        .miso(miso),

        .mosi(mosi),
        .sclk(sclk),
        .cs_n(cs_n),

        .rx_data(master_rx),

        .busy(busy),
        .done(done)
    );

    //-------------------------------------------------
    // Slave
    //-------------------------------------------------

    spi_slave slave_inst (
        .clk(clk),
        .rst_n(rst_n),

        .sclk(sclk),
        .cs_n(cs_n),

        .mosi(mosi),
        .miso(miso),

        .tx_data(slave_tx),

        .rx_data(slave_rx),

        .data_valid(data_valid)
    );

  

    initial begin

        start     = 0;
        master_tx = 8'hA5;
        slave_tx  = 8'h3C;

        @(posedge rst_n);

        #50;

        // One-cycle start pulse
        @(posedge clk);
        start = 1;

        @(posedge clk);
        start = 0;

        // Wait for transfer to complete
        @(posedge done);

        #20;

        $display("--------------------------------");
        $display("Master TX : %02X", master_tx);
        $display("Slave RX  : %02X", slave_rx);
        $display("Slave TX  : %02X", slave_tx);
        $display("Master RX : %02X", master_rx);
        $display("--------------------------------");

        if (slave_rx == master_tx &&
            master_rx == slave_tx)
            $display("PASS");
        else
            $display("FAIL");

        #100;
        $finish;

    end

endmodule