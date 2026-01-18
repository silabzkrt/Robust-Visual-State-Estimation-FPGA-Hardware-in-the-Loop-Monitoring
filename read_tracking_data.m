csv_files = dir('ball_coordinates_*.csv');
if ~isempty(csv_files)
    % Load the most recent .csv file
    [~, idx] = max([csv_files.datenum]);
    latest_csv = csv_files(idx).name;
    fprintf('Loading data from: %s\n', latest_csv);
    data_table = readtable(latest_csv);
    
    x_coords = data_table.X;
    y_coords = data_table.Y;
    radii = data_table.Radius;
    
    % Plot the results
    figure('Name', 'Ball Tracking Analysis');
    
    % Plot X coordinate over sample
    subplot(3, 1, 1);
    plot(x_coords, 'b-', 'LineWidth', 2);
    xlabel('Sample Number');
    ylabel('X Coordinate (pixels)');
    title('X Position Over Samples');
    grid on;
    
    % Plot Y coordinate over sample
    subplot(3, 1, 2);
    plot(y_coords, 'r-', 'LineWidth', 2);
    xlabel('Sample Number');
    ylabel('Y Coordinate (pixels)');
    title('Y Position Over Samples');
    grid on;
    
    % Plot trajectory (X vs Y)
    subplot(3, 1, 3);
    plot(x_coords, y_coords, 'g-', 'LineWidth', 2);
    hold on;
    plot(x_coords(1), y_coords(1), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    plot(x_coords(end), y_coords(end), 'bs', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    xlabel('X Coordinate (pixels)');
    ylabel('Y Coordinate (pixels)');
    title('Ball Trajectory (Red=Start, Blue=End)');
    legend('Trajectory', 'Start', 'End');
    grid on;
    axis equal;
else
    error('No tracking data files found!');
end

fprintf('Data loaded successfully!\n');
fprintf('Total samples: %d\n', length(x_coords));
fprintf('X range: [%d, %d]\n', min(x_coords), max(x_coords));
fprintf('Y range: [%d, %d]\n', min(y_coords), max(y_coords));
