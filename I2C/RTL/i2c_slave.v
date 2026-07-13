


module i2c_slave #(
    parameter [6:0] SLAVE_ADDR = 7'h50
)
(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       scl,
    inout  wire       sda,

    output reg [7:0]  received_data,
    input  wire [7:0] transmit_data,

    output reg        data_valid
);

    localparam ST_IDLE     = 3'd0;
    localparam ST_ADDR     = 3'd1;
    localparam ST_ACK_ADDR = 3'd2;
    localparam ST_WRITE    = 3'd3;
    localparam ST_ACK_DATA = 3'd4;
    localparam ST_READ     = 3'd5;

    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg       rw_bit;
    reg       sda_drive_low;
    reg       scl_d;
    reg       sda_d;

    //====================================================
    // Open-Drain SDA Driver
    //====================================================
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    //====================================================
    // Synchronize SCL and SDA
    //====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_d <= 1'b1;
            sda_d <= 1'b1;
        end else begin
            scl_d <= scl;
            sda_d <= sda;
        end
    end

    wire scl_rise        =  scl & ~scl_d;
    wire scl_fall        = ~scl &  scl_d;
    wire start_condition =  scl & scl_d &  sda_d & ~sda;  // SCL steady-high, SDA falls
    wire stop_condition  =  scl & scl_d & ~sda_d &  sda;  // SCL steady-high, SDA rises

    //====================================================
    // I2C Slave State Machine
    //====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            bit_cnt       <= 0;
            shift_reg     <= 0;
            rw_bit        <= 0;
            sda_drive_low <= 0;
            received_data <= 0;
            data_valid    <= 0;
        end else begin
            data_valid <= 1'b0;   // default; pulses only where explicitly set below

            if (stop_condition) begin
                state         <= ST_IDLE;
                sda_drive_low <= 1'b0;
            end else if (start_condition) begin
                state         <= ST_ADDR;
                bit_cnt       <= 0;
                sda_drive_low <= 1'b0;
            end else begin
                case (state)

                    //--------------------------------------------------
                    ST_IDLE: begin
                        sda_drive_low <= 1'b0;
                    end

                    //--------------------------------------------------
                    ST_ADDR: begin
                        if (scl_rise) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1;
                            if (bit_cnt == 4'd7) begin
                                state   <= ST_ACK_ADDR;
                                bit_cnt <= 0;
                            end
                        end
                    end

                    //--------------------------------------------------
                    ST_ACK_ADDR: begin
                        // bit_cnt reused here as a 2-step sub-phase:
                        // 0 = drive the ACK bit, 1 = hold until it's been sampled, then release
                        if (bit_cnt == 0) begin
                            if (scl_fall) begin
                                if (shift_reg[7:1] == SLAVE_ADDR) begin
                                    sda_drive_low <= 1'b1;      // ACK
                                    rw_bit        <= shift_reg[0];
                                    bit_cnt       <= 1;
                                end else begin
                                    sda_drive_low <= 1'b0;      // NACK, not addressed to us
                                    state         <= ST_IDLE;
                                end
                            end
                        end else begin
                            if (scl_fall) begin
                                sda_drive_low <= 1'b0;          // release after ACK pulse completes
                                bit_cnt       <= 0;
                                if (rw_bit) begin
                                    shift_reg <= transmit_data;
                                    state     <= ST_READ;
                                end else begin
                                    state <= ST_WRITE;
                                end
                            end
                        end
                    end

                    //--------------------------------------------------
                    ST_WRITE: begin
                        if (scl_rise) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1;
                            if (bit_cnt == 4'd7) begin
                                state   <= ST_ACK_DATA;
                                bit_cnt <= 0;
                            end
                        end
                    end

                    //--------------------------------------------------
                    ST_ACK_DATA: begin
                        // same 2-step ACK-hold pattern as ST_ACK_ADDR
                        if (bit_cnt == 0) begin
                            if (scl_fall) begin
                                sda_drive_low <= 1'b1;
                                received_data <= shift_reg;
                                bit_cnt       <= 1;
                            end
                        end else begin
                            if (scl_fall) begin
                                sda_drive_low <= 1'b0;
                                data_valid    <= 1'b1;
                                bit_cnt       <= 0;
                                state         <= ST_IDLE;
                            end
                        end
                    end

                    //--------------------------------------------------
                    ST_READ: begin
                        // bit_cnt: 0-7 drive real data bits, 8 = release for master's ACK/NACK slot
                        if (scl_fall) begin
                            if (bit_cnt == 4'd8) begin
                                sda_drive_low <= 1'b0;
                                bit_cnt       <= 0;
                                state         <= ST_IDLE;
                            end else begin
                                sda_drive_low <= ~shift_reg[7];
                                shift_reg     <= {shift_reg[6:0], 1'b0};
                                bit_cnt       <= bit_cnt + 1;
                            end
                        end
                    end

                    //--------------------------------------------------
                    default: state <= ST_IDLE;

                endcase
            end
        end
    end

endmodule