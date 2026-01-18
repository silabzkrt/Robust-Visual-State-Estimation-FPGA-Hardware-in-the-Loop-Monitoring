clear; clc; close all;

%% 1. SETUP SERIAL
delete(serialportfind);
port = "COM6";
baudrate = 9600;

try
    s = serialport(port, baudrate);
catch
    error("Connection Failed.");
end

%% 2. PREPARE RECORDER
f = figure('Name', 'Variable Rate Recorder', 'NumberTitle', 'off');
ax = axes('Parent', f);
hold(ax, 'on'); grid(ax, 'on');
xlim(ax, [0 600]); ylim(ax, [0 600]);
title('Recording Phase');

global keep_recording; 
keep_recording = true;
btn = uicontrol('Style', 'pushbutton', 'String', 'Stop & Analyze', ...
    'Position', [20 20 150 40], ...
    'Callback', 'global keep_recording; keep_recording = false;');

hRaw = plot(0,0,'rx', 'MarkerSize', 8);

% Data Storage
raw_x = [];
raw_y = [];
raw_t = []; % Time storage

%% 3. RECORDING LOOP (With Time!)
startTime = tic; % Start the clock

while keep_recording && isvalid(f)
    if s.NumBytesAvailable >= 3
        header = read(s, 1, "uint8");
        if header == 255
            % 1. Capture Time IMMEDIATELY
            currentTime = toc(startTime);
            
            data = read(s, 2, "uint8");
            px = double(data(1)) * 40;
            py = double(data(2)) * 40;
            
            % 2. Store Data + Time
            raw_x = [raw_x, px];
            raw_y = [raw_y, py];
            raw_t = [raw_t, currentTime];
            
            set(hRaw, 'XData', raw_x, 'YData', raw_y);
            drawnow limitrate;
        end
    end
end

disp("Recording Stopped. Running Variable-Dt Kalman Filter");

%% 4. VARIABLE-TIME KALMAN FILTER
if length(raw_x) < 2
    disp("Not enough data!");
    return;
end

% Initial State (Start at first point, zero velocity)
x_est = [raw_x(1); raw_y(1); 0; 0]; 
P = 100 * eye(4);

% Constant Matrices
H = [1 0 0 0; 0 1 0 0];
Q_base = 10 * eye(4); % Base process noise
R = 20 * eye(2);      % Measurement noise

kalman_x = [];
kalman_y = [];

% Iterate through history
for k = 1:length(raw_x)
    % A. Calculate Time Step (dt)
    if k == 1
        dt = 0.1; % First step guess
    else
        dt = raw_t(k) - raw_t(k-1); % ACTUAL time difference
    end
    
    % Safety: If dt is zero (duplicate data), force small dt
    if dt <= 0; dt = 0.001; end
    
    % B. Update State Transition Matrix (A) with REAL dt
    % Position = Old_Pos + Velocity * dt
    A = [1 0 dt 0; 
         0 1 0 dt; 
         0 0 1 0; 
         0 0 0 1];
     
    % C. Prediction Step
    x_pred = A * x_est;
    % Process noise grows with time (longer gap = more uncertainty)
    P_pred = A * P * A' + (Q_base * dt); 
    
    % D. Update Step
    z = [raw_x(k); raw_y(k)];
    K = P_pred * H' / (H * P_pred * H' + R);
    x_est = x_pred + K * (z - H * x_pred);
    P = (eye(4) - K * H) * P_pred;
    
    % Save
    kalman_x = [kalman_x, x_est(1)];
    kalman_y = [kalman_y, x_est(2)];
end

%% 5. PREDICTION (Projecting Velocity)
% We predict 2 seconds into the future
future_horizon = 10.0; 
% We can use the LAST known velocity directly
% Final State: [Pos_X, Pos_Y, Vel_X, Vel_Y]
final_vx = x_est(3);
final_vy = x_est(4);

pred_x = x_est(1) + final_vx * future_horizon;
pred_y = x_est(2) + final_vy * future_horizon;

%% 6. FINAL VISUALIZATION
plot(raw_x, raw_y, 'r--', 'Color', [1 0.7 0.7], 'DisplayName', 'Raw Switch Data');
plot(kalman_x, kalman_y, 'b.-', 'LineWidth', 1.5, 'DisplayName', 'Variable-Dt Filter');
% Draw Prediction Line
plot([kalman_x(end), pred_x], [kalman_y(end), pred_y], 'm->', 'LineWidth', 2, 'DisplayName', '2s Prediction');

legend show;
title('Speed Aware Prediction');