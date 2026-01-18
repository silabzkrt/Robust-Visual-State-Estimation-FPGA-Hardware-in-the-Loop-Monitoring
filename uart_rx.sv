`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2026 20:09:24
// Design Name: 
// Module Name: uart_rx
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

module uart_rx(
    input logic clk,       // 100 MHz
    input logic rst,
    input logic rx_serial, // The raw USB-UART Pin (B18)
    output logic rx_done,  // Goes HIGH for 1 tick when a byte is ready
    output logic [7:0] rx_byte // The byte we just received
    );
    localparam CLKS_PER_BIT = 10416;

    parameter s_IDLE         = 3'b000;
    parameter s_RX_START_BIT = 3'b001;
    parameter s_RX_DATA_BITS = 3'b010;
    parameter s_RX_STOP_BIT  = 3'b011;
    parameter s_CLEANUP      = 3'b100;

    logic [2:0] state = s_IDLE;
    logic [13:0] clk_count = 0;
    logic [2:0] bit_index = 0; // 0 to 7

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= s_IDLE;
            rx_done <= 0;
            clk_count <= 0;
            bit_index <= 0;
            rx_byte <= 0;
        end else begin
            case (state)
                s_IDLE : begin
                    rx_done <= 0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_serial == 1'b0) // Detected Start Bit (Low)
                        state <= s_RX_START_BIT;
                    else
                        state <= s_IDLE;
                end

                // Wait half a bit width to sample in the middle
                s_RX_START_BIT : begin
                    if (clk_count == (CLKS_PER_BIT-1)/2) begin
                        if (rx_serial == 1'b0) begin
                            clk_count <= 0;
                            state <= s_RX_DATA_BITS;
                        end else
                            state <= s_IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                s_RX_DATA_BITS : begin
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        rx_byte[bit_index] <= rx_serial; // Save the bit
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= s_RX_STOP_BIT;
                        end
                    end
                end

                s_RX_STOP_BIT : begin
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        rx_done <= 1'b1; // SIGNAL: Byte is ready!
                        clk_count <= 0;
                        state <= s_CLEANUP;
                    end
                end

                s_CLEANUP : begin
                    state <= s_IDLE;
                    rx_done <= 1'b0;
                end

                default : state <= s_IDLE;
            endcase
        end
    end
endmodule
