

module i2c_master #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer I2C_FREQ_HZ   = 100_000
)
(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       start,
    input  wire       rw,          // 0 = Write, 1 = Read

    input  wire [6:0] slave_addr,
    input  wire [7:0] tx_data,

    output reg [7:0]  rx_data,

    output reg        busy,
    output reg        done,
    output reg        ack_error,

    output reg        scl,

    inout  wire       sda
);

    localparam integer TICK_DIV = CLOCK_FREQ_HZ/I2C_FREQ_HZ; // clk cycles per full SCL period
    localparam integer HALF_DIV = TICK_DIV/2;                // clk cycles per half SCL period

    localparam ST_IDLE      = 4'd0;
    localparam ST_START     = 4'd1;
    localparam ST_SEND_ADDR = 4'd2;
    localparam ST_ADDR_ACK  = 4'd3;
    localparam ST_WRITE     = 4'd4;
    localparam ST_WRITE_ACK = 4'd5;
    localparam ST_READ      = 4'd6;
    localparam ST_READ_ACK  = 4'd7;
    localparam ST_STOP      = 4'd8;
    localparam ST_DONE      = 4'd9;

    reg [3:0]  state;
    reg [1:0]  phase;      // sub-step counter within a bit / START / STOP sequence
    reg [3:0]  bit_cnt;
    reg [7:0]  shift_reg;
    reg [31:0] tick_count;
    reg        tick;
    reg        sda_drive_low;

    //====================================================
    // SDA Open-Drain Driver
    //====================================================
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    //====================================================
    // Tick Generator - one tick per half SCL period
    //====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_count <= 0;
            tick       <= 0;
        end else begin
            tick <= 0;
            if (tick_count == HALF_DIV-1) begin
                tick_count <= 0;
                tick       <= 1;
            end else begin
                tick_count <= tick_count + 1;
            end
        end
    end

    //====================================================
    // I2C Master State Machine
    //====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            phase         <= 0;
            bit_cnt       <= 0;
            shift_reg     <= 0;
            sda_drive_low <= 0;
            scl           <= 1;   // idle bus is high
            rx_data       <= 0;
            busy          <= 0;
            done          <= 0;
            ack_error     <= 0;
        end else begin
            done <= 0;   // default every clk cycle -> one-cycle pulse

            if (tick) begin
                case (state)

                    //--------------------------------------------------
                    ST_IDLE: begin
                        busy <= 0;
                        if (start) begin
                            shift_reg <= {slave_addr, rw};
                            bit_cnt   <= 0;
                            phase     <= 0;
                            busy      <= 1;
                            ack_error <= 0;
                            state     <= ST_START;
                        end
                    end

                    //--------------------------------------------------
                    ST_START: begin
                        if (phase == 0) begin
                            scl           <= 1;
                            sda_drive_low <= 1;   // SDA falls while SCL high -> START
                            phase         <= 1;
                        end else begin
                            scl   <= 0;           // bring SCL low, ready to clock
                            phase <= 0;
                            state <= ST_SEND_ADDR;
                        end
                    end

                    //--------------------------------------------------
                    ST_SEND_ADDR: begin
                        if (phase == 0) begin
                            sda_drive_low <= ~shift_reg[7];  // drive while SCL low
                            scl           <= 0;
                            phase         <= 1;
                        end else begin
                            scl       <= 1;                  // clock bit in
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            bit_cnt   <= bit_cnt + 1;
                            phase     <= 0;
                            if (bit_cnt == 4'd7) begin
                                state   <= ST_ADDR_ACK;
                                bit_cnt <= 0;
                            end
                        end
                    end

                    //--------------------------------------------------
                    ST_ADDR_ACK: begin
                        if (phase == 0) begin
                            sda_drive_low <= 0;   // release, let slave drive ACK
                            scl           <= 0;
                            phase         <= 1;
                        end else begin
                            scl       <= 1;
                            ack_error <= sda;      // 0 = ACK, 1 = NACK
                            shift_reg <= tx_data;  // preload for write path
                            phase     <= 0;
                            state     <= rw ? ST_READ : ST_WRITE;
                        end
                    end

                    //--------------------------------------------------
                    ST_WRITE: begin
                        if (phase == 0) begin
                            sda_drive_low <= ~shift_reg[7];
                            scl           <= 0;
                            phase         <= 1;
                        end else begin
                            scl       <= 1;
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            bit_cnt   <= bit_cnt + 1;
                            phase     <= 0;
                            if (bit_cnt == 4'd7) begin
                                state   <= ST_WRITE_ACK;
                                bit_cnt <= 0;
                            end
                        end
                    end

                    //--------------------------------------------------
                    ST_WRITE_ACK: begin
                        if (phase == 0) begin
                            sda_drive_low <= 0;
                            scl           <= 0;
                            phase         <= 1;
                        end else begin
                            scl       <= 1;
                            ack_error <= sda;
                            phase     <= 0;
                            state     <= ST_STOP;
                        end
                    end

                    //--------------------------------------------------
                    ST_READ: begin
                        if (phase == 0) begin
                            sda_drive_low <= 0;   // release, let slave drive data
                            scl           <= 0;
                            phase         <= 1;
                        end else begin
                            scl       <= 1;
                            shift_reg <= {shift_reg[6:0], sda};  // sample on rising edge
                            bit_cnt   <= bit_cnt + 1;
                            phase     <= 0;
                            if (bit_cnt == 4'd7) begin
                                rx_data <= {shift_reg[6:0], sda};
                                state   <= ST_READ_ACK;
                                bit_cnt <= 0;
                            end
                        end
                    end

                    //--------------------------------------------------
                    ST_READ_ACK: begin
                        // single-byte read -> master sends NACK (leave SDA released)
                        if (phase == 0) begin
                            sda_drive_low <= 0;
                            scl           <= 0;
                            phase         <= 1;
                        end else begin
                            scl   <= 1;
                            phase <= 0;
                            state <= ST_STOP;
                        end
                    end

                    //--------------------------------------------------
                    ST_STOP: begin
                        if (phase == 0) begin
                            scl           <= 0;
                            sda_drive_low <= 1;   // pull SDA low first
                            phase         <= 1;
                        end else if (phase == 1) begin
                            scl   <= 1;            // raise SCL while SDA still low
                            phase <= 2;
                        end else begin
                            sda_drive_low <= 0;    // release SDA -> rises while SCL high -> STOP
                            phase         <= 0;
                            state         <= ST_DONE;
                        end
                    end

                    //--------------------------------------------------
                    ST_DONE: begin
                        busy  <= 0;
                        done  <= 1;
                        state <= ST_IDLE;
                    end

                    //--------------------------------------------------
                    default: state <= ST_IDLE;

                endcase
            end
        end
    end

endmodule