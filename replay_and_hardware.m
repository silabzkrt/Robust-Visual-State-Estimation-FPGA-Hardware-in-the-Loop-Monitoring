clear; clc; 

%% 1. CONFIGURATION
COM_PORT = 'COM6'; 
BAUD_RATE = 9600;

%% 2. LOAD DATA
csv_files = dir('ball_coordinates_*.csv');
if isempty(csv_files), error('No CSV files found!'); end
[~, idx] = max([csv_files.datenum]);
data = readtable(csv_files(idx).name);
raw_x = data.X;
raw_y = data.Y;
t = data.Timestamp; 
dt = mean(diff(t));

%% 3. SERIAL CONNECTION
delete(serialportfind); % Clean up old ports
try
    s = serialport(COM_PORT, BAUD_RATE);
    configureTerminator(s, "LF");
    fprintf('Connected to FPGA on %s\n', COM_PORT);
catch
    warning('FPGA not detected. Running in Simulation Mode.');
    s = [];
end

%% 4. REAL-TIME REPLAY LOOP
% KF Init
x_est = [raw_x(1); raw_y(1); 0; 0];
P = 100*eye(4);
F = [1 0 dt 0; 0 1 0 dt; 0 0 1 0; 0 0 0 1];
H = [1 0 0 0; 0 1 0 0];
R = 5*eye(2); Q = 0.5*eye(4);

total_dist = 0;
prev_vel = 0;

figure('Name', 'HIL Dashboard', 'Color', 'w');
hLine = plot(0,0,'b-','LineWidth',2);
axis([0 640 0 480]); axis ij; grid on;
title('HIL Simulation: Sending Data to FPGA...');

for k = 1:length(raw_x)
    tic; % Start timer
    
    % --- KALMAN FILTER STEP ---
    x_est = F * x_est;
    P = F * P * F' + Q;
    
    if ~isnan(raw_x(k))
        y = [raw_x(k); raw_y(k)] - H * x_est;
        S = H * P * H' + R;
        K = P * H' / S;
        x_est = x_est + K * y;
        P = (eye(4) - K * H) * P;
    end
    
    % --- PHYSICS CALCULATION ---
    vel_mag = sqrt(x_est(3)^2 + x_est(4)^2);
    acc_mag = abs(vel_mag - prev_vel) / dt;
    total_dist = total_dist + (vel_mag * dt);
    prev_vel = vel_mag;
    
    % --- DATA PACKING FOR FPGA ---
    % Scale values to fit in 1 Byte (0-255)
    % You may need to tune these divisors based on your camera resolution
    b_dist = mod(round(total_dist / 10), 255); 
    b_vel  = min(255, round(vel_mag * 2));     
    b_acc  = min(255, round(acc_mag * 4));     
    
    % Packet Format: [HEADER(255), DIST, VEL, ACC]
    if ~isempty(s)
        write(s, [255, b_dist, b_vel, b_acc], "uint8");
    end
    
    % --- VISUALIZATION ---
    % Update plot every 5 frames to save CPU
    if mod(k, 5) == 0
        hLine.XData = [hLine.XData, x_est(1)];
        hLine.YData = [hLine.YData, x_est(2)];
        drawnow limitrate;
    end
    
    % Sync with real-time (approximate)
    elapsed = toc;
    pause(max(0, dt - elapsed)); 
end

fprintf('HIL Replay Complete.\n');