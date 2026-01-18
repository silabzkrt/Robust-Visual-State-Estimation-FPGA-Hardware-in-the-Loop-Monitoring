% 1. Setup the Serial Connection
% CHECK DEVICE MANAGER for your actual COM Port (e.g., "COM3")
clear s; % Close any old connections
port = "COM6"; 
baudrate = 9600; % Must match your FPGA Baud Rate

try
    s = serialport(port, baudrate);
    disp("Connected to Basys 3!");
catch
    error("Could not connect. Check USB cable and COM port number.");
end

% 2. Define your Data (e.g., from your Image Processing results)
x_coord = 0106;  % Example X coordinate
y_coord = 0505;  % Example Y coordinate

% 3. Format the Data Packet
% We will send: [HEADER(255), X_HIGH, X_LOW, Y_HIGH, Y_LOW]
header = 255;

x_high = floor(x_coord / 256);
x_low = mod(x_coord, 256);

y_high = floor(y_coord / 256);
y_low = mod(y_coord, 256);

packet = [header, x_high, x_low, y_high, y_low];

% 4. Send the Data
write(s, packet, "uint8");

disp(["Sent Packet: ", num2str(packet)]);

% 5. Clean up (Optional, keep open if sending in a loop)
% clear s;