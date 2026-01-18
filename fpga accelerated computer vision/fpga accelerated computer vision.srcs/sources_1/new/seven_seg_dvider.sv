`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2026 20:14:40
// Design Name: 
// Module Name: seven_seg_dvider
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

module seven_seg_driver(
    input logic clk,           // 100 MHz clock
    input logic rst,           // Reset
    input logic [15:0] value,  // The number to display (4 Hex Digits)
    output logic [6:0] seg,    // Cathodes (A-G)
    output logic [3:0] an      // Anodes (Digit Select)
    );

    // 1. Clock Divider for Refresh Rate
    // We need ~1kHz refresh rate. 100MHz / 100,000 = 1kHz.
    logic [19:0] refresh_counter;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) refresh_counter <= 0;
        else refresh_counter <= refresh_counter + 1;
    end

    // Use the top 2 bits of the counter to select which digit is active
    logic [1:0] digit_select;
    assign digit_select = refresh_counter[19:18];

    // 2. Digit Selector (Multiplexing)
    logic [3:0] hex_digit;
    
    always_comb begin
        case(digit_select)
            2'b00: begin
                an = 4'b1110; // Turn on Rightmost digit (Active LOW)
                hex_digit = value[3:0];
            end
            2'b01: begin
                an = 4'b1101;
                hex_digit = value[7:4];
            end
            2'b10: begin
                an = 4'b1011;
                hex_digit = value[11:8];
            end
            2'b11: begin
                an = 4'b0111; // Turn on Leftmost digit
                hex_digit = value[15:12];
            end
            default: begin
                an = 4'b1111; 
                hex_digit = 4'b0000;
            end
        endcase
    end

    // 3. Decoder: Hex -> 7-Segment Patterns (Cathode Active LOW)
    // format: gfedcba (0 is ON, 1 is OFF)
    always_comb begin
        case(hex_digit)
            4'h0: seg = 7'b1000000; // 0
            4'h1: seg = 7'b1111001; // 1
            4'h2: seg = 7'b0100100; // 2
            4'h3: seg = 7'b0110000; // 3
            4'h4: seg = 7'b0011001; // 4
            4'h5: seg = 7'b0010010; // 5
            4'h6: seg = 7'b0000010; // 6
            4'h7: seg = 7'b1111000; // 7
            4'h8: seg = 7'b0000000; // 8
            4'h9: seg = 7'b0010000; // 9
            4'hA: seg = 7'b0001000; // A
            4'hB: seg = 7'b0000011; // b
            4'hC: seg = 7'b1000110; // C
            4'hD: seg = 7'b0100001; // d
            4'hE: seg = 7'b0000110; // E
            4'hF: seg = 7'b0001110; // F
            default: seg = 7'b1111111; // Off
        endcase
    end

endmodule