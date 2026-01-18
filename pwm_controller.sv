`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2026 20:15:51
// Design Name: 
// Module Name: pwm_controller
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

module pwm_controller(
    input logic clk,           
    input logic rst,           
    input logic [31:0] width_ch1, 
    input logic [31:0] width_ch2,
    input logic [31:0] width_ch3,
    input logic [31:0] width_ch4,
    output logic [3:0] servo_pwm 
    );

    logic [31:0] counter;
    localparam PERIOD_TICKS = 2000000;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
        end else begin
            if (counter >= PERIOD_TICKS - 1)
                counter <= 0;
            else
                counter <= counter + 1;
        end
    end

    always_comb begin
        servo_pwm[0] = (counter < width_ch1) ? 1'b1 : 1'b0;
        servo_pwm[1] = (counter < width_ch2) ? 1'b1 : 1'b0;
        servo_pwm[2] = (counter < width_ch3) ? 1'b1 : 1'b0;
        servo_pwm[3] = (counter < width_ch4) ? 1'b1 : 1'b0;
    end

endmodule