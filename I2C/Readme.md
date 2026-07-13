I2C (Inter-Integrated Circuit) Protocol Implementation

Overview

This directory contains a complete Verilog implementation of the I2C (Inter-Integrated Circuit) communication protocol, also known as TWI (Two-Wire Interface). The implementation includes both I2C Master and I2C Slave modules designed for FPGA deployment on the Nexys A7 platform. The design has been validated through comprehensive simulation and hardware testing.

Protocol Background

I2C is a synchronous, half-duplex serial communication protocol that uses two open-drain/open-collector bidirectional lines:
- SCL (Serial Clock Line): Clock signal controlled by the master
- SDA (Serial Data Line): Bidirectional data line

Key Characteristics:
- Supports multiple masters and slaves on the same bus
- Slave addressing scheme with 7-bit or 10-bit addresses (this implementation uses 7-bit)
- Four speed modes: Standard (100 kHz), Fast (400 kHz), Fast+ (1 MHz), and High-Speed (3.4 MHz)
- Open-drain output stages require pull-up resistors on both lines
- Clock stretching support allows slaves to hold SCL low to control transmission pace

Directory Structure

```
I2C/
├── RTL/
│   ├── i2c_top.v          - Top-level wrapper module with FPGA board integration
│   ├── i2c_master.v       - I2C Master controller implementation
│   └── i2c_slave.v        - I2C Slave controller implementation
├── tb/
│   └── tb_i2c.v           - Testbench for simulation and validation
└── Readme.md              - This file
```

Core Modules

i2c_master.v

The I2C Master module initiates communication and controls the serial clock (SCL). It handles all transaction sequencing and implements the complete I2C protocol state machine.

Parameters:
- CLOCK_FREQ_HZ: System clock frequency in Hz (default: 100,000,000 / 100 MHz)
- I2C_FREQ_HZ: Desired I2C bus frequency in Hz (default: 100,000 / 100 kHz)

Port Description:

Input Signals:
- clk: System clock input
- rst_n: Asynchronous active-low reset
- start: Pulse signal to initiate an I2C transaction
- rw: Transaction type selector (0 = Write, 1 = Read)
- slave_addr[6:0]: Target slave 7-bit address
- tx_data[7:0]: Data byte to transmit during write operations

Output Signals:
- rx_data[7:0]: Data byte received during read operations
- busy: Transaction in progress indicator
- done: Single-cycle pulse indicating transaction completion
- ack_error: Signals ACK/NACK response (1 = NACK received, 0 = ACK received)
- scl: Serial clock line output

Bidirectional Signals:
- sda: Serial data line (open-drain, requires external pull-up)

Implementation Details:

The master module implements a 10-state finite state machine to orchestrate I2C transactions:

State Transitions:
1. ST_IDLE: Awaits start signal; transitions to ST_START when triggered
2. ST_START: Generates START condition (SDA falls while SCL is high)
3. ST_SEND_ADDR: Transmits 8-bit address + R/W bit to slave
4. ST_ADDR_ACK: Waits for slave ACK; detects NACK and sets ack_error flag
5. ST_WRITE: Transmits data byte (8 bits) to slave during write operations
6. ST_WRITE_ACK: Waits for slave ACK after data transmission
7. ST_READ: Receives data byte (8 bits) from slave during read operations
8. ST_READ_ACK: Master sends NACK to slave after read (single-byte transaction)
9. ST_STOP: Generates STOP condition (SDA rises while SCL is high)
10. ST_DONE: Signals completion and returns to idle state

Timing Mechanism:

The module generates a periodic tick signal at half-SCL-period intervals. Tick periods are calculated as:
- HALF_DIV = CLOCK_FREQ_HZ / (2 * I2C_FREQ_HZ)

For 100 MHz system clock and 100 kHz I2C bus:
- HALF_DIV = 100,000,000 / (2 * 100,000) = 500 clock cycles
- One I2C bit period = 1000 clock cycles

Each tick event advances the state machine by one half-period, providing smooth SCL transitions between high and low states, with SDA data changes occurring during SCL low periods.

Open-Drain Driver:

The SDA line uses open-drain architecture:
- sda_drive_low = 1'b1: Pulls SDA low through N-channel transistor
- sda_drive_low = 1'b0: Releases SDA (high-impedance state); external pull-up resistor pulls line high

This design allows multiple devices to safely share the bus without driver conflicts.

i2c_slave.v

The I2C Slave module responds to master-initiated transactions and operates in response to bus conditions. It detects START/STOP conditions and address matching to participate in communication.

Parameters:
- SLAVE_ADDR[6:0]: This slave's unique I2C address (default: 7'h50)

Port Description:

Input Signals:
- clk: System clock input
- rst_n: Asynchronous active-low reset
- scl: Serial clock line input (monitored from bus)
- transmit_data[7:0]: Data byte to send during read operations

Output Signals:
- received_data[7:0]: Data byte captured during write operations
- data_valid: Single-cycle pulse asserted when received_data is valid

Bidirectional Signals:
- sda: Serial data line (open-drain, requires external pull-up)

Implementation Details:

The slave module implements a 6-state finite state machine for protocol compliance:

State Transitions:
1. ST_IDLE: Waits for START condition or system initialization
2. ST_ADDR: Captures incoming 8-bit address field (7 bits address + 1 bit R/W)
3. ST_ACK_ADDR: Validates address match; drives ACK if matched, NACK otherwise
4. ST_WRITE: Captures incoming data byte during master write operations
5. ST_ACK_DATA: Acknowledges received data byte; signals data_valid pulse
6. ST_READ: Transmits stored data byte during master read operations

Condition Detection:

The slave module synchronizes external bus signals to prevent metastability:
- START Condition: SCL and SDA are high, then SDA falls while SCL remains high
- STOP Condition: SCL and SDA are high, then SDA rises while SCL remains high
- SCL Rise: Transition from low to high (data sampling edge for slave)
- SCL Fall: Transition from high to low (data setup edge; ACK/NACK transmission window)

Address Matching:

The slave compares the received 7-bit address (shift_reg[7:1]) against SLAVE_ADDR parameter. If matched, it acknowledges; otherwise it remains passive on the bus.

ACK/NACK Protocol:

- ACK: Slave pulls SDA low during designated bit period
- NACK: Slave releases SDA (remains high via pull-up)

Data Transmission:

During read operations (rw_bit=1):
- shift_reg is preloaded with transmit_data parameter value
- Data bits are transmitted MSB-first during SCL low periods
- Slave releases SDA after transmitting all 8 bits, allowing master's ACK/NACK

i2c_top.v

This module serves as the top-level integration layer for FPGA board deployment, providing board-specific I/O mapping.

Port Mapping:
- CLK100MHZ: System 100 MHz oscillator
- CPU_RESETN: Active-low global reset
- BTNC: Center button for transaction trigger
- SW[7:0]: 8 DIP switches for data selection
- i2c_sda: SDA line connection
- i2c_scl: SCL line connection
- LED[15:0]: Status and data display LEDs

Functionality:

The top module instantiates i2c_master and demonstrates write operations. A button debouncer captures press events and initiates I2C transactions. Switch inputs control the transmitted data byte, while LEDs display transaction status (busy, done, ack_error) and echoed data values.

Testbench (tb_i2c.v)

Comprehensive simulation testbench that validates both master and slave functionality through directed tests.

Test Scenarios:

Write Test:
- Master transmits 0xA5 to slave at address 0x50
- Slave receives and stores data
- Status signals verified (busy, done, ack_error)

Read Test:
- Master reads 0x5A from slave at address 0x50
- Slave transmits stored data
- Master captures and validates received byte

Implementation Methodology

Timing Calculation:

For correct protocol operation, SCL period must accommodate:
- Setup time (minimum): 100 ns (conservative)
- Hold time: 0 ns for most implementations
- Minimum SCL high time: 600 ns
- Minimum SCL low time: 1300 ns

For 100 kHz I2C (10 microsecond period):
- Target SCL high time: 5 microseconds
- Target SCL low time: 5 microseconds

Derivation:
- System clock period: 10 ns (100 MHz)
- Required SCL half-period ticks: 5 microseconds / 10 ns = 500 clocks
- HALF_DIV calculation: CLOCK_FREQ_HZ / (2 * I2C_FREQ_HZ) = 500

Synchronization Considerations:

The implementation uses primary synchronization at SCL and SDA inputs to prevent metastability issues when external asynchronous signals interact with internal synchronous logic.

Open-Drain Implementation:

Both master and slave use identical open-drain drivers:
- Active pull-down: sda_drive_low = 1 drives output to 0V
- Release state: sda_drive_low = 0 allows pull-up resistor to charge line to VDD
- External pull-up required on both SCL and SDA lines (typical: 4.7k resistors for 100 kHz operation)

Simulation and Testing

Running Simulation:

```
iverilog -o tb_i2c tb/tb_i2c.v RTL/i2c_master.v RTL/i2c_slave.v
vvp tb_i2c
```

Expected Output:

The testbench produces timestamped console output:
- WRITE TEST: Displays master transmitted data (0xA5) and slave received data
- READ TEST: Displays slave transmitted data (0x5A) and master received data
- ACK_ERROR status indicates protocol completion without NACK conditions

Waveform Analysis:

Recommended signals for debugging:
- Master: state, scl, sda, busy, done, ack_error
- Slave: state, scl, sda, received_data, data_valid
- Both: shift_reg, bit_cnt for bit-level timing verification

Hardware Deployment

FPGA Board: Nexys A7
Synthesis Tool: Vivado
Target Clock: 100 MHz

Physical I2C Bus Connections:

Connect external devices or logic analyzer to:
- SDA line: Pin connected to i2c_sda module output (configure for open-drain)
- SCL line: Pin connected to i2c_scl module output (configure for open-drain)
- Pull-up resistors: 4.7k resistors between SDA/SCL and VDD (3.3V)

Pin Configuration Requirements:
- I/O Standard: LVCMOS33 (3.3V signaling)
- Drive Strength: Configure for open-drain/active-low behavior
- Slew Rate: Slow (to minimize EMI)

Usage Example

Initiating a Write Transaction:

1. Set SW[7:0] to desired data value (e.g., 0xA5)
2. Press BTNC (button press generates 1-cycle pulse)
3. Master initiates START condition and sends address 0x50 with RW bit = 0
4. Slave receives address, validates match, responds with ACK
5. Master transmits SW data byte; slave captures and acknowledges
6. Master generates STOP condition
7. LED[8] (busy) pulse observed during transaction
8. LED[9] (done) pulse indicates completion
9. LED[10] (ack_error) remains low indicating successful ACK

Initiating a Read Transaction:

1. Set rw signal to 1 in firmware or modify i2c_top.v instantiation
2. Press BTNC to trigger transaction
3. Master sends address 0x50 with RW bit = 1
4. Slave recognizes read request, transmits pre-loaded data byte
5. Master samples and latches data on each SCL rising edge
6. Master sends NACK after 8 bits to terminate read
7. rx_data[7:0] contains received value

Troubleshooting Guide

Issue: ACK_ERROR Constantly Asserted

Possible Causes:
- Slave address mismatch between master SLAVE_ADDR parameter and slave SLAVE_ADDR
- Missing or insufficient pull-up resistors on SDA/SCL lines
- Slave module stuck in wrong state (verify reset condition)
- SCL or SDA line held low by external device (bus contention)

Solution: Verify parameter matching, measure bus voltages with multimeter (should be 3.3V idle), confirm pull-up resistor values and connections.

Issue: Transactions Never Complete (Busy Remains High)

Possible Causes:
- System clock not running (verify CLK100MHZ input)
- Reset not deasserted (check CPU_RESETN level)
- State machine stuck due to race condition or metastability
- External slave not responding to address

Solution: Add simulation debug signals to track state progression; verify board clock output with scope; force reset pulse and observe response.

Issue: Data Corruption or Bit Errors

Possible Causes:
- Timing parameters miscalculated for target frequency
- Insufficient setup/hold margin around SCL transitions
- Noise on I2C bus (inadequate shielding or long unshielded cables)
- Slave sampling at wrong SCL timing

Solution: Verify HALF_DIV calculation matches frequency requirements; capture bus waveforms with logic analyzer; add filtering capacitors (100nF) across VDD-GND near both pull-up resistors.

Design Specifications

Supported Features:
- Single master, single or multiple slave operation
- Standard mode (100 kHz) I2C bus frequency
- 7-bit addressing scheme
- Single-byte write and read transactions
- ACK/NACK protocol compliance
- START/STOP condition generation
- Clock stretching capable (slaves can hold SCL low)

Design Limitations:
- Single-master architecture (no multi-master arbitration)
- Single-byte transactions per START/STOP sequence
- No 10-bit addressing support
- No high-speed mode or fast+ mode support
- No repeated START condition support (requires protocol extension)

Parameter Customization

To modify I2C bus frequency:

i2c_master instantiation:
```
i2c_master #(
    .CLOCK_FREQ_HZ(100_000_000),  // System clock: 100 MHz
    .I2C_FREQ_HZ(100_000)          // I2C bus: 100 kHz
)
```

Alternative frequencies:
- 400 kHz Fast Mode: .I2C_FREQ_HZ(400_000)
- 1 MHz Fast+ Mode: .I2C_FREQ_HZ(1_000_000)

Recalculated timing automatically through HALF_DIV parameter.

References

I2C Specification: Philips Semiconductor I2C Bus Specification v2.1
Protocol Standard: https://www.nxp.com/docs/en/user-manual/UM10204.pdf

Notes

- This implementation prioritizes correctness and clarity over aggressive optimization
- Simulation tools verified: Icarus Verilog, ModelSim, Vivado Simulator
- All timing parameters assume 3.3V LVCMOS signaling with standard pull-up resistor values (4.7k)
- For production deployments, add comprehensive error handling and extended transaction support as required

