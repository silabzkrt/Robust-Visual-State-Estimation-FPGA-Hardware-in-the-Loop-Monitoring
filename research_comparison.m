clear; clc; close all;

%% 1. DATA INGESTION
% Automatically find the most recent CSV file
csv_files = dir('ball_coordinates_*.csv');
if isempty(csv_files)
    error('No CSV files found! Run track_object.py first.');
end
[~, idx] = max([csv_files.datenum]);
file_name = csv_files(idx).name;
fprintf('Loading Dataset: %s\n', file_name);

opts = detectImportOptions(file_name);
opts.VariableNamesLine = 1;
data_table = readtable(file_name, opts);

% Parse Columns (Robust to potential format variations)
if iscell(data_table.X)
    raw_x = str2double(data_table.X);
    raw_y = str2double(data_table.Y);
    raw_r = str2double(data_table.Radius);
else
    raw_x = data_table.X;
    raw_y = data_table.Y;
    raw_r = data_table.Radius;
end

% Create Time Vector (normalized to start at t=0)
if ismember('Timestamp', data_table.Properties.VariableNames)
    t = data_table.Timestamp;
else
    t = (1:length(raw_x))' * 0.033; % Fallback: Assume 30 FPS
end
t = t - t(1); 
dt = mean(diff(t)); % Average sampling time

%% 2. FILTER CONFIGURATION

% State Vector: [x; y; vx; vy]
% Transition Matrix (Constant Velocity Model)
F = [1 0 dt 0; 
     0 1 0 dt; 
     0 0 1 0; 
     0 0 0 1];

% Measurement Matrix (We measure position x, y)
H = [1 0 0 0; 
     0 1 0 0];

% Measurement Noise Covariance (R)
% High values = noisy sensor (Trust Physics more)
% Low values = precise sensor (Trust Measurement more)
R = 5 * eye(2); 

% -- Standard Filter Init --
x_std = [raw_x(1); raw_y(1); 0; 0];
P_std = 100 * eye(4);
Q_std = 0.5 * eye(4); % Fixed Process Noise

% -- Adaptive Filter Init --
x_adp = x_std;
P_adp = P_std;
Q_base = 0.5 * eye(4); 
Q_adp = Q_base;

%% 3. RECURSIVE ESTIMATION LOOP

% Pre-allocate for speed
n_samples = length(raw_x);
path_std = zeros(4, n_samples);
path_adp = zeros(4, n_samples);
nis_history = nan(1, n_samples);
Q_scale_history = ones(1, n_samples);

% Chi-Squared Threshold for 95% confidence (2 Degrees of Freedom)
CHI_SQ_THRESHOLD = 5.99; 

for k = 1:n_samples
    % --- A. PREDICTION STEP (Time Update) ---
    x_std = F * x_std;
    P_std = F * P_std * F' + Q_std;
    
    x_adp = F * x_adp;
    P_adp = F * P_adp * F' + Q_adp;
    
    % --- B. CORRECTION STEP (Measurement Update) ---
    % Check for Occlusion (NaN or 0)
    has_measurement = ~isnan(raw_x(k));
    
    if has_measurement
        z = [raw_x(k); raw_y(k)];
        
        % 1. Standard Filter Update
        y_std = z - H * x_std;       % Innovation
        S_std = H * P_std * H' + R;  % Innovation Covariance
        K_std = P_std * H' / S_std;  % Kalman Gain
        x_std = x_std + K_std * y_std;
        P_std = (eye(4) - K_std * H) * P_std;
        
        % 2. Adaptive Filter Update
        y_adp = z - H * x_adp;
        S_adp = H * P_adp * H' + R;
        
        % Calculate NIS (Normalized Innovation Squared)
        % This is the "Mahalanobis Distance" of the error
        nis_val = y_adp' / S_adp * y_adp;
        nis_history(k) = nis_val;
        
        % ADAPTATION LOGIC:
        % If NIS > Threshold, the model is failing (Maneuver detected).
        % We inflate Q to allow the filter to react faster.
        if nis_val > CHI_SQ_THRESHOLD
            alpha = nis_val / CHI_SQ_THRESHOLD; % Scaling factor
            Q_adp = Q_base * alpha; 
            Q_scale_history(k) = alpha;
            
            % Re-predict P with new Q for this step
            P_adp = F * P_adp * F' + Q_adp;
            S_adp = H * P_adp * H' + R; % Re-calc S
        else
            Q_adp = Q_base;
            Q_scale_history(k) = 1;
        end
        
        K_adp = P_adp * H' / S_adp;
        x_adp = x_adp + K_adp * y_adp;
        P_adp = (eye(4) - K_adp * H) * P_adp;
        
    else
        % Occlusion Handling: Do not update, just trust prediction
        % Q grows naturally via P = F*P*F' + Q
    end
    
    % Store States
    path_std(:, k) = x_std;
    path_adp(:, k) = x_adp;
end

%% 4. RESEARCH PLOTS (Publication Quality)

% Figure 1: Trajectory Analysis
figure('Color','w', 'Name', 'Trajectory Analysis', 'Position', [100 100 1200 600]);

% Figure 2: Statistical Consistency (NIS)
subplot(1,2,2); hold on; grid on;
plot(t, nis_history, 'm', 'LineWidth', 1);

% --- SAFE REPLACEMENT FOR YLINE ---
% This draws the threshold line manually using coordinates
line([0 t(end)], [CHI_SQ_THRESHOLD CHI_SQ_THRESHOLD], ...
    'Color', 'k', 'LineStyle', '--', 'LineWidth', 2);
text(0, CHI_SQ_THRESHOLD + 1, '95% Confidence', 'FontSize', 8);
% ----------------------------------

ylabel('Normalized Innovation Squared (NIS)');
xlabel('Time (s)');
title('Filter Consistency Check');
xlim([0 t(end)]);
ylim([0 20]); % Zoom in to see the threshold