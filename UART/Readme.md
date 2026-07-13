# UART (Universal Asynchronous Receiver/Transmitter)

## What is UART?

UART is a widely-used communication protocol for serial data transmission between devices. It allows full-duplex asynchronous communication, meaning data can be transmitted and received simultaneously without requiring a shared clock signal between the communicating devices.

## Explanation

### Overview

UART operates as a point-to-point communication interface using two main signal lines: TX (Transmit) and RX (Receive). Each device has its own clock source, so they must be configured with the same baud rate (bits per second) to properly synchronize and interpret the transmitted data.

### Key Characteristics

1. **Asynchronous Communication**: Data transmission occurs without a shared clock between sender and receiver. Each device uses its own clock frequency to sample the incoming data.

2. **Full-Duplex**: Simultaneous transmission and reception of data is possible through separate TX and RX lines.

3. **Serial Data Format**: Data is transmitted one bit at a time sequentially over a single wire.

4. **Baud Rate**: Determines the speed of data transmission (e.g., 9600, 115200 baud). Both transmitter and receiver must operate at the same baud rate.

### UART Frame Structure

A UART frame consists of the following components:

- **Start Bit (1 bit)**: Logical 0, signals the beginning of a data frame.
- **Data Bits (5-9 bits)**: The actual payload, typically 8 bits.
- **Parity Bit (1 bit, optional)**: Used for error detection (odd, even, or none).
- **Stop Bits (1-2 bits)**: Logical 1, signals the end of a frame.

Example 8-N-1 frame (8 data bits, no parity, 1 stop bit):
```
START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP
```

### Operating Modes

1. **Transmission Mode**: The transmitter converts parallel data into serial format and sends it bit-by-bit at the specified baud rate.

2. **Reception Mode**: The receiver samples incoming serial data at intervals determined by the baud rate and reconstructs parallel data.

### Applications

- Communication between microcontrollers and computers
- Debugging and logging interfaces
- Serial port communication in embedded systems
- Inter-device communication in IoT applications

---

## Implementation

### Architecture Overview

The UART implementation in this repository provides a complete transmitter and receiver system designed for FPGA deployment. The system is modularized into distinct functional blocks for transmitting and receiving data.

### Module Components

1. **Baud Rate Generator**: Generates clock pulses at the baud rate frequency to synchronize data transmission and reception.

2. **Transmitter (TX)**: Converts parallel input data into serial format and transmits it with proper framing (start bit, data bits, stop bit).

3. **Receiver (RX)**: Samples incoming serial data, verifies framing, and converts it back to parallel format.

4. **Control Logic**: Manages the state transitions and handshaking between TX/RX modules and the host interface.

### Key Design Features

- **Configurable Baud Rate**: Supports multiple standard baud rates through parameterized baud rate divider.
- **Full-Duplex Operation**: Independent TX and RX paths allow simultaneous communication.
- **Status Flags**: Provides indicators for transmission complete, reception complete, buffer status, and error conditions.
- **Standard Frame Format**: Implements the common 8-N-1 configuration (8 data bits, no parity, 1 stop bit).

### File Structure

- **RTL/**: Register Transfer Level (RTL) Verilog implementations of the UART modules
- **tb/**: Testbench files for simulation and verification
- **constraints/**: FPGA constraint files for pin assignments and timing specifications

### Integration with FPGA

The UART is targeted for the Nexys A7 FPGA board. The implementation includes:

- Pin mappings for serial data lines to FPGA I/O pins
- Timing constraints to meet the specified baud rate
- Clock management for baud rate generation from the FPGA's main clock

### Simulation and Validation

The implementation has been thoroughly simulated using Verilog testbenches and validated on the Nexys A7 FPGA board to ensure correct protocol implementation and data integrity across various baud rates and data patterns.
