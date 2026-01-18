`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2026 21:01:05
// Design Name: 
// Module Name: uart_tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module uart_tx(
    input logic clk,
    input logic rst,
    input logic tx_start,      // Pulse high to send
    input logic [7:0] tx_byte, // Byte to send
    output logic tx_active,    // High while sending
    output logic tx_serial,    // The physical wire (RsTx)
    output logic tx_done       // Pulse high when finished
    );

    localparam CLKS_PER_BIT = 10416; // 9600 baud @ 100MHz

    typedef enum {IDLE, START, DATA, STOP} state_type;
    state_type state = IDLE;
    
    logic [13:0] clk_count = 0;
    logic [2:0] bit_index = 0;
    logic [7:0] data_copy = 0;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            tx_serial <= 1; // Idle high
            tx_done <= 0;
            tx_active <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_serial <= 1;
                    tx_done <= 0;
                    if (tx_start) begin
                        state <= START;
                        tx_active <= 1;
                        data_copy <= tx_byte;
                        clk_count <= 0;
                    end
                end
                
                START: begin // Send Start Bit (0)
                    tx_serial <= 0;
                    if (clk_count < CLKS_PER_BIT-1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        state <= DATA;
                        bit_index <= 0;
                    end
                end
                
                DATA: begin // Send 8 Data Bits
                    tx_serial <= data_copy[bit_index];
                    if (clk_count < CLKS_PER_BIT-1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else
                            state <= STOP;
                    end
                end
                
                STOP: begin // Send Stop Bit (1)
                    tx_serial <= 1;
                    if (clk_count < CLKS_PER_BIT-1)
                        clk_count <= clk_count + 1;
                    else begin
                        tx_done <= 1;
                        tx_active <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
