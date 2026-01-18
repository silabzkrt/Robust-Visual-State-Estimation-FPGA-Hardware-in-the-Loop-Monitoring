module send_data(
    input logic clk,
    input logic btnC,         // Reset
    input logic [7:0] sw,     // sw[3:0]=X, sw[7:4]=Y
    output logic RsTx,        // UART TX Pin
    output logic [6:0] seg,   // Debug Display
    output logic [3:0] an
    );

    // 1. Inputs from Switches
    // We pad them with zeros to make a full 8-bit byte
    logic [7:0] val_x;
    logic [7:0] val_y;
    
    assign val_x = {4'b0000, sw[3:0]}; // 0-15
    assign val_y = {4'b0000, sw[7:4]}; // 0-15

    // 2. UART Transmitter Instance
    logic tx_start;
    logic [7:0] tx_byte;
    logic tx_done;
    logic tx_active;

    uart_tx u_tx (
        .clk(clk), .rst(btnC),
        .tx_start(tx_start), .tx_byte(tx_byte),
        .tx_active(tx_active), .tx_serial(RsTx), .tx_done(tx_done)
    );

    // 3. High-Speed State Machine
    // Sends: [HEADER 255] -> [X] -> [Y] -> Repeat
    typedef enum {IDLE, SEND_HDR, WAIT_HDR, SEND_X, WAIT_X, SEND_Y, WAIT_Y, DELAY} state_type;
    state_type state = IDLE;
    
    // Counter for the "2 Clock Cycle" delay
    logic [1:0] delay_counter = 0; 

    always_ff @(posedge clk) begin
        if (btnC) begin
            state <= IDLE;
            tx_start <= 0;
            delay_counter <= 0;
        end else begin
            case(state)
                IDLE: state <= SEND_HDR;

                // --- 1. Send Header (255) ---
                SEND_HDR: begin
                    tx_byte <= 8'd255;
                    tx_start <= 1;
                    state <= WAIT_HDR;
                end
                WAIT_HDR: begin
                    tx_start <= 0;
                    if (tx_done) state <= SEND_X;
                end

                // --- 2. Send X (Switches 0-3) ---
                SEND_X: begin
                    tx_byte <= val_x;
                    tx_start <= 1;
                    state <= WAIT_X;
                end
                WAIT_X: begin
                    tx_start <= 0;
                    if (tx_done) state <= SEND_Y;
                end

                // --- 3. Send Y (Switches 4-7) ---
                SEND_Y: begin
                    tx_byte <= val_y;
                    tx_start <= 1;
                    state <= WAIT_Y;
                end
                WAIT_Y: begin
                    tx_start <= 0;
                    if (tx_done) state <= DELAY;
                end

                // --- 4. The "2 Clock Cycle" Delay ---
                DELAY: begin
                    if (delay_counter == 2) begin
                        delay_counter <= 0;
                        state <= SEND_HDR; // Loop back immediately
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
            endcase
        end
    end

    // 4. Debug Display (Show X on left, Y on right)
    // Display: "00XY" (Hex)
    logic [15:0] debug_val;
    assign debug_val = {8'h00, sw[7:4], sw[3:0]};

    seven_seg_driver u_disp (
        .clk(clk), .rst(btnC),
        .value(debug_val), .seg(seg), .an(an)
    );

endmodule