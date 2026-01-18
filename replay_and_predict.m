clear; clc; close all;

%% 1. HARDWARE SETUP
delete(serialportfind); % Clean up old connections
port = "COM6";          % <--- CHECK YOUR DEVICE MANAGER
baudrate = 9600;

try
    s = serialport(port, baudrate);
    configureTerminator(s, "LF");
    flush(s);
    disp("Connected to Basys 3 for Replay.");
catch
    error("Connection Failed. Check USB or Port Number.");
end

%% 2. LOAD DATA
% Find the most recent CSV file
csv_files = dir('ball_coordinates_*.csv');
if isempty(csv_files)
    error("No tracking data found! Run track__object.py first.");
end
[~, idx] = max([csv_files.datenum]);
latest_csv = csv_files(idx).name;
fprintf('Loading tracking data from: %s\n', latest_csv);

data_table = readtable(latest_csv);
raw_x = data_table.X;
raw_y = data_table.Y;

% Time Parsing (Handle Date Strings or Epoch Numbers)
if isnumeric(data_table.Timestamp)
    raw_t = data_table.Timestamp;
else
    % Convert "2023-10-25 14:30:05.123" to seconds
    raw_t = posixtime(datetime(data_table.Timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS'));
end

%% 3. PREPARE VISUALIZATION
figure('Name', 'Live Replay & Prediction');
hold on; grid on;
xlim([0 640]); ylim([0 480]);
set(gca, 'YDir', 'reverse'); % Camera coordinates (0,0 is top left)
xlabel('X (Pixels)'); ylabel('Y (Pixels)');

hTrue = plot(0,0,'rx', 'MarkerSize', 8, 'DisplayName', 'Recorded Pos');
hPred = plot(0,0,'bo-', 'LineWidth', 2, 'DisplayName', 'Kalman Path');
hFuture = plot(0,0,'mX', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', '15-Step Prediction');
legend show;

%% 4. KALMAN FILTER SETUP
% State: [x; y; vx; vy]
x_est = [raw_x(1); raw_y(1); 0; 0]; 
P = 100 * eye(4);
H = [1 0 0 0; 0 1 0 0];
Q_base = 10 * eye(4); % Process Noise
R = 50 * eye(2);      % Measurement Noise

path_x = [];
path_y = [];

disp("Starting Replay...");
pause(1); % Give you time to look at the board

%% 5. REPLAY LOOP
for k = 1:length(raw_x)
    % --- A. Calculate Time Step (dt) ---
    if k == 1
        dt = 0.2; % Default guess for first frame
    else
        dt = raw_t(k) - raw_t(k-1);
    end
    if dt <= 0; dt = 0.01; end % Safety fix
    
    % --- B. Update Kalman Matrix (Dynamic Physics) ---
    A = [1 0 dt 0; 
         0 1 0 dt; 
         0 0 1 0; 
         0 0 0 1];
     
    % --- C. Kalman Predict & Update ---
    x_pred = A * x_est;
    P_pred = A * P * A' + (Q_base * dt);
    
    z = [raw_x(k); raw_y(k)]; % The recorded measurement
    K = P_pred * H' / (H * P_pred * H' + R);
    x_est = x_pred + K * (z - H * x_pred);
    P = (eye(4) - K * H) * P_pred;
    
    % Store for plotting
    path_x = [path_x, x_est(1)];
    path_y = [path_y, x_est(2)];
    
    % --- D. 15-STEP PREDICTION ---
    % We predict 15 "dt steps" into the future
    steps_ahead = 15;
    future_time = steps_ahead * dt; 
    
    % Formula: Pos_Future = Pos_Current + Velocity * Time
    pred_x = x_est(1) + x_est(3) * future_time;
    pred_y = x_est(2) + x_est(4) * future_time;
    
    % --- E. SEND TO FPGA ---
    % Map 640x480 (Camera) to 0-255 (Servo Byte)
    send_x = round(pred_x * (255/640));
    send_y = round(pred_y * (255/480));
    
    % Clamp to safe byte range
    send_x = max(0, min(255, send_x));
    send_y = max(0, min(255, send_y));
    
    % Send Packet: [Header, X, Y]
    write(s, [255, send_x, send_y], "uint8");
    
    % --- F. VISUALIZE ---
    set(hTrue, 'XData', raw_x(1:k), 'YData', raw_y(1:k));
    set(hPred, 'XData', path_x, 'YData', path_y);
    set(hFuture, 'XData', pred_x, 'YData', pred_y);
    
    title(sprintf('Frame %d/%d | Pred: (%d, %d)', k, length(raw_x), round(pred_x), round(pred_y)));
    drawnow;
    
    % Real-time simulation delay
    pause(0.05); 
end

disp("Replay Finished.");
clear s;