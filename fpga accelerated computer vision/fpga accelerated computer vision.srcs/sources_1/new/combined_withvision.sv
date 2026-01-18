`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.01.2026 21:09:18
// Design Name: 
// Module Name: combined_withvision
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

module combined_withvision(
    input logic clk,
    input logic btnC,        // Reset
    input logic RsRx,        // UART RX Pin (B18) - LISTENING
    input logic [15:0] sw,   // Switches (Optional Overrides)
    output logic [3:0] ja,   // Servos
    output logic [6:0] seg,  // Display Segments
    output logic [3:0] an    // Display Anodes
    );

    // 1. UART Receiver
    logic rx_done_tick;
    logic [7:0] rx_data_out;
    
    uart_rx u_uart (
        .clk(clk), .rst(btnC), .rx_serial(RsRx),
        .rx_done(rx_done_tick), .rx_byte(rx_data_out)
    );

    // 2. Packet Parser [255, X, Y]
    logic [7:0] val_x = 000; // Start Center
    logic [7:0] val_y = 000; // Start Center
    
    typedef enum {IDLE, GET_X, GET_Y} state_type;
    state_type state = IDLE;

    always_ff @(posedge clk) begin
        if (rx_done_tick) begin
            case(state)
                IDLE: begin
                    if (rx_data_out == 255) state <= GET_X;
                end
                GET_X: begin
                    val_x <= rx_data_out;
                    state <= GET_Y;
                end
                GET_Y: begin
                    val_y <= rx_data_out;
                    state <= IDLE;
                end
            endcase
        end
    end

    // 3. Servo Mapping (0-255 -> 1ms-2ms)
    // 0 -> 100,000
    // 255 -> 200,000
    // Formula: 100,000 + (val * 392)
    logic [31:0] width1, width2;
    assign width1 = 100000 + (val_x * 392);
    assign width2 = 100000 + (val_y * 392);

    pwm_controller u_pwm (
        .clk(clk), .rst(btnC),
        .width_ch1(width1), .width_ch2(width2),
        .width_ch3(150000), .width_ch4(150000), // Fixed Elbow/Grip
        .servo_pwm(ja)
    );

    // 4. Display (Show received X and Y)
    // Shows "XXYY" in Hex
    seven_seg_driver u_disp (
        .clk(clk), .rst(btnC),
        .value({val_x, val_y}), .seg(seg), .an(an)
    );

endmodule