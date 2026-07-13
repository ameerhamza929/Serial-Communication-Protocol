module i2c_top #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer I2C_FREQ_HZ   = 100_000
)
(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire [7:0]  SW,
    inout  wire        i2c_sda,
    output wire        i2c_scl,
    output wire [15:0] LED
);
    wire rst_n = CPU_RESETN;

    reg btnc_d;
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) btnc_d <= 1'b0;
        else        btnc_d <= BTNC;
    end

    wire start_i2c = BTNC & ~btnc_d;   // one-clock pulse on button press

    wire [7:0] rx_data;
    wire       busy;
    wire       done;
    wire       ack_error;

    
    i2c_master #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .I2C_FREQ_HZ   (I2C_FREQ_HZ)
    ) u_i2c_master (
        .clk        (CLK100MHZ),
        .rst_n      (rst_n),
        .start      (start_i2c),
        .rw         (1'b0),        // write demo
        .slave_addr (7'h50),
        .tx_data    (SW),
        .rx_data    (rx_data),
        .busy       (busy),
        .done       (done),
        .ack_error  (ack_error),
        .scl        (i2c_scl),
        .sda        (i2c_sda)
    );

    assign LED[7:0]   = SW;
    assign LED[8]     = busy;
    assign LED[9]     = done;
    assign LED[10]    = ack_error;
    assign LED[15:11] = 5'b0;

endmodule