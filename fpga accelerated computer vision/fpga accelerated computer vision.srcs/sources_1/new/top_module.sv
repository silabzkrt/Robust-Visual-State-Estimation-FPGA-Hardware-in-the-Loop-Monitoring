`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2026 20:10:09
// Design Name: 
// Module Name: top_module
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


module demonstrate_data(
    input logic clk,
    input logic btnC,        // Reset
    input logic RsRx,        // UART RX Pin (B18)
    input logic [15:0] sw,   // Switches
    output logic [3:0] ja,   // Servos
    output logic [6:0] seg,  // Display Segments
    output logic [3:0] an    // Display Anodes
    );

    // --- 1. UART Receiver Instantiation ---
    logic rx_done_tick;
    logic [7:0] rx_data_out;
    
    uart_rx u_uart (
        .clk(clk),
        .rst(btnC),
        .rx_serial(RsRx),
        .rx_done(rx_done_tick),
        .rx_byte(rx_data_out)
    );

    // --- 2. State Machine to Reconstruct Data ---
    logic [15:0] x_stored = 0;
    logic [15:0] y_stored = 0;
    
    // Temporary buffers
    logic [7:0] x_high_buf;
    logic [7:0] x_low_buf;
    logic [7:0] y_high_buf;

    typedef enum {IDLE, WAIT_XH, WAIT_XL, WAIT_YH, WAIT_YL, UPDATE} state_type;
    state_type state = IDLE;

    always_ff @(posedge clk) begin
        if (btnC) begin
            state <= IDLE;
            x_stored <= 0;
            y_stored <= 0;
        end else if (rx_done_tick) begin
            // Only act when a new byte arrives
            case(state)
                IDLE: begin
                    if (rx_data_out == 8'd255) // Header Found!
                        state <= WAIT_XH;
                end
                
                WAIT_XH: begin
                    x_high_buf <= rx_data_out;
                    state <= WAIT_XL;
                end

                WAIT_XL: begin
                    x_low_buf <= rx_data_out;
                    state <= WAIT_YH;
                end

                WAIT_YH: begin
                    y_high_buf <= rx_data_out;
                    state <= WAIT_YL;
                end

                WAIT_YL: begin
                    // Reconstruction: Combine High and Low bytes
                    // {High, Low} means Concatenate bits
                    x_stored <= {x_high_buf, x_low_buf}; 
                    y_stored <= {y_high_buf, rx_data_out};
                    state <= IDLE; // Go back and wait for next packet
                end
            endcase
        end
    end

    // --- 3. Display Logic (Multiplexer) ---
    // If Switch 15 is DOWN -> Show X
    // If Switch 15 is UP   -> Show Y
    logic [15:0] display_value;
    assign display_value = (sw[15] == 0) ? x_stored : y_stored;

    seven_seg_driver u_disp (
        .clk(clk),
        .rst(btnC),
        .value(display_value),
        .seg(seg),
        .an(an)
    );

    // --- 4. Servo Logic (Keep manual control for now) ---
    // (You can link this to x_stored later!)
    logic [31:0] pwm_width;
    assign pwm_width = (sw[0]) ? 200000 : 100000; // Manual test

    pwm_controller u_pwm (
        .clk(clk),
        .rst(btnC),
        .width_ch1(pwm_width), .width_ch2(pwm_width),
        .width_ch3(pwm_width), .width_ch4(pwm_width),
        .servo_pwm(ja)
    );

endmodule