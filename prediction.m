clear; clc; close all;

%% 1. Define the System (The Physics)
dt = 0.2;  % Time step (seconds)

% State Transition Matrix (A)
% We expect: pos = pos + vel*dt
% State Vector x = [position_X; position_Y; velocity_X; velocity_Y]
A = [1 0 dt 0;
     0 1 0 dt;
     0 0 1 0;
     0 0 0 1];

% Measurement Matrix (H)
% We only measure position (X and Y), not velocity.
H = [1 0 0 0;
     0 1 0 0];

% Process Noise Covariance (Q) - "How much does reality deviate from my model?"
% Small Q = Trust model physics more. Large Q = Trust physics less.
Q = 0.001 * eye(4);

% Measurement Noise Covariance (R) - "How noisy is my sensor?"
% High R = Noisy sensor (Filter will ignore spikes). Low R = Accurate sensor.
R = 100 * eye(2);

%% 2. Initialization
x_est = [0; 0; 0; 0];  % Initial estimate (guess)
P = 10 * eye(4);      % Initial uncertainty (high because we are guessing)
I = eye(4);     % Identity matrix

%% 3. Generate Fake Data (Ground Truth + Noise)
steps = 200;
true_pos = zeros(2, steps);
measurements = zeros(2, steps);
kalman_pos = zeros(2, steps);

% True velocity: moving diagonal (1m/s in X, 0.5m/s in Y)
true_x = [0; 0; 1; 0.5]; 

for k = 1:steps
    % Simulate physics
    true_x = A * true_x; 
    
    % Store true position
    true_pos(:,k) = true_x(1:2);
    
    % Generate noisy measurement (True + Random Gaussian Noise)
    noise = (randn(2, 1) * sqrt(R(1,1))); % Matches R magnitude
    z = H * true_x + noise;
    measurements(:,k) = z;
    
    %% --- KALMAN FILTER LOOP STARTS HERE ---
    
    % 1. PREDICT: Project the state ahead
    x_pred = A * x_est;
    P_pred = A * P * A' + Q;
    
    % 2. UPDATE: Compute Kalman Gain
    % K = P_pred * H' * inv(H * P_pred * H' + R)
    K = P_pred * H' / (H * P_pred * H' + R); 
    
    % 3. UPDATE: Estimate new state using measurement (z)
    x_est = x_pred + K * (z - H * x_pred);
    
    % 4. UPDATE: Estimate new covariance
    P = (I - K * H) * P_pred;
    
    %% --- KALMAN FILTER LOOP ENDS ---
    
    % Store result for plotting
    kalman_pos(:,k) = x_est(1:2);
end


%% 4. Visualization
figure;
plot(true_pos(1,:), true_pos(2,:), 'g-', 'LineWidth', 2); hold on;
plot(measurements(1,:), measurements(2,:), 'rx');
plot(kalman_pos(1,:), kalman_pos(2,:), 'b.-', 'LineWidth', 1.5);
legend('True Path', 'Noisy Measurements', 'Kalman Filter');
title('Kalman Filter Tracking (Manual Implementation)');
xlabel('X Position'); ylabel('Y Position');
grid on;

%% 5. FUTURE PREDICTION (Forecasting)
num_future_steps = 15; % How many seconds into the future to guess
future_preds = zeros(2, num_future_steps);
temp_x = x_est; % Start from the very last estimate we calculated

for k = 1:num_future_steps
    % Pure physics prediction (No measurement update!)
    temp_x = A * temp_x;
    future_preds(:, k) = temp_x(1:2);
end

% Add this to your existing plot
plot(future_preds(1,:), future_preds(2,:), 'm--', 'LineWidth', 2, 'DisplayName', 'Future Prediction');
legend('show'); % Update legend to include the new line

