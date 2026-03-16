%% ESE 105 – Case Study 3 – Part 3: Holographic Object Extraction
% This script separates objects from a light field by filtering rays based 
% on their incident angle (theta_x). It uses an automated histogram analysis
% to determine the optimal angular separation with guard bands to prevent ghosting.

%% --- 1. Load Data ---
fprintf("Loading lightField.mat...\n");
data = load('lightField.mat');

rays_in = data.rays; % 4xN matrix
clear data;

N_rays = size(rays_in, 2);
fprintf("Loaded %.2f million rays.\n", N_rays/1e6);

% --- System Parameters ---
f = 0.1;          % 100 mm lens
Npixels = 800;    % High resolution (Increased for quality)
set(0, 'defaultFigureColor', 'w');    % Set figure background to white
set(0, 'defaultAxesColor', 'none');   % Set axes background to transparent
set(0, 'defaultAxesXColor', 'k');   % Set all axis lines/ticks to black
set(0, 'defaultAxesYColor', 'k');
set(0, 'defaultAxesZColor', 'k');
set(0, 'defaultTextColor', 'k');   
% Optimal Focus (Hardcoded to the result found in Part 2)
% If d2_final is not in workspace, hardcode the value found in Part 2
if ~exist('d2_final', 'var')
    d2_final = 0.1338; % Replace with your exact peak value
end
d2_optimal = d2_final; % ~133.8 mm
fprintf("Using optimal focus distance d2 = %.3f mm\n", d2_optimal*1000);

%% --- 2. Automated Angle Analysis (The "De-Ghosting" Step) ---
fprintf("\nAnalyzing ray angular distribution...\n");

% Extract horizontal angles (theta_x is row 2)
theta_x = rays_in(2, :);

% Create a histogram to see where the "clumps" of rays are
num_bins = 100;
[counts, edges] = histcounts(theta_x, num_bins);
bin_centers = (edges(1:end-1) + edges(2:end)) / 2;

% --- Find Peaks and Valleys ---
% We assume 3 objects. We split the data into 3 regions to find local maxes.
min_ang = min(theta_x);
max_ang = max(theta_x);
third   = (max_ang - min_ang) / 3;

% Define rough regions
left_mask   = bin_centers < (min_ang + third);
mid_mask    = bin_centers >= (min_ang + third) & bin_centers < (max_ang - third);
right_mask  = bin_centers >= (max_ang - third);

% Find peak location in each region
[~, idx_L] = max(counts .* left_mask);
[~, idx_M] = max(counts .* mid_mask);
[~, idx_R] = max(counts .* right_mask);

peak_L = bin_centers(idx_L);
peak_M = bin_centers(idx_M);
peak_R = bin_centers(idx_R);

% --- Define Ranges with Guard Bands ---
gap = 0.02; % 20 milliradians safety gap

ranges = zeros(3, 2);

% Left Object: From min to midpoint(L,M) - gap
ranges(1, 1) = min_ang;
ranges(1, 2) = (peak_L + peak_M)/2 - gap;

% Center Object: Midpoint(L,M) + gap to Midpoint(M,R) - gap
ranges(2, 1) = (peak_L + peak_M)/2 + gap;
ranges(2, 2) = (peak_M + peak_R)/2 - gap;

% Right Object: Midpoint(M,R) + gap to max
ranges(3, 1) = (peak_M + peak_R)/2 + gap;
ranges(3, 2) = max_ang;

% --- Visualization of the Sorting ---
f_hist = figure('Name', 'Angle Distribution', 'Position', [100, 100, 800, 600]);
bar(bin_centers, counts, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none'); hold on;
xline(ranges(1,2), 'r--', 'LineWidth', 2);
xline(ranges(2,1), 'r--', 'LineWidth', 2);
xline(ranges(2,2), 'r--', 'LineWidth', 2);
xline(ranges(3,1), 'r--', 'LineWidth', 2);
title('Automated Ray Sorting (Red lines = Cutoffs with Guard Bands)');
xlabel('Incoming Angle \theta_x (rad)');
ylabel('Number of Rays');
grid on;

% Set Font Size for Report Readability
set(gca, 'FontSize', 14); % Make tick marks and numbers readable
xlabel('Incoming Angle \theta_x (rad)', 'FontSize', 16);
ylabel('Number of Rays', 'FontSize', 16);
title('Automated Ray Sorting', 'FontSize', 18);

text(peak_L, max(counts), 'Left Object', 'Horiz', 'center', 'Vert', 'bottom', 'FontSize', 12);
text(peak_M, max(counts), 'Center Object', 'Horiz', 'center', 'Vert', 'bottom', 'FontSize', 12);
text(peak_R, max(counts), 'Right Object', 'Horiz', 'center', 'Vert', 'bottom', 'FontSize', 12);

% Save Histogram using current background color (original)
exportgraphics(f_hist, 'Angle_Histogram.png', 'BackgroundColor', 'current');


%% --- 3. Matrix Optics Setup ---
M_f = [1, 0, 0, 0; -1/f, 1, 0, 0; 0, 0, 1, 0; 0, 0, -1/f, 1];
M_d2 = [1, d2_optimal, 0, 0; 0, 1, 0, 0; 0, 0, 1, d2_optimal; 0, 0, 0, 1];
M_total = M_d2 * M_f;


%% --- 4. Process and Render Each Object ---
fprintf("\nProcessing angle groups...\n");

object_names = {'Left_Object', 'Center_Object', 'Right_Object'};
titles_disp  = {'Left View (WashU Crest)', 'Center View (Bruno Sinopoli)', 'Right View (Boston Dynamics Robot)'};

for i = 1:3
    fprintf("  Rendering %s (Theta: %.3f to %.3f)...\n", ...
        object_names{i}, ranges(i,1), ranges(i,2));
    
    % --- Filter Rays ---
    mask = (theta_x >= ranges(i,1)) & (theta_x <= ranges(i,2));
    rays_filtered = rays_in(:, mask);
    
    if sum(mask) < 1000
        continue;
    end
    
    % --- Apply Optics ---
    rays_out = M_total * rays_filtered;
    x_sensor = rays_out(1, :);
    y_sensor = rays_out(3, :);
    
    % --- Post-Processing ---
    xc = x_sensor - mean(x_sensor, 'omitnan');
    yc = y_sensor - mean(y_sensor, 'omitnan');
    
    % Hard Crop physically first to remove outliers
    valid = abs(xc) < 0.0025 & abs(yc) < 0.0025; 
    xc = xc(valid);
    yc = yc(valid);
    
    % Sensor width for calculation (slightly wider than zoom to avoid edge cutoffs)
    sensor_w = 0.003; 
    
    % --- Render Image ---
    [img, X, Y] = rays2img(xc, yc, sensor_w, Npixels);
    
    % --- Contrast Enhancement ---
    img_dbl = double(img);
    sorted_vals = sort(img_dbl(:));
    low_val  = sorted_vals(round(0.01 * length(sorted_vals)));
    high_val = sorted_vals(round(0.995 * length(sorted_vals)));
    
    img_disp = (img_dbl - low_val) / (high_val - low_val);
    img_disp(img_disp < 0) = 0;
    img_disp(img_disp > 1) = 1;
    
    % --- Display & Save ---
    f_obj = figure('Position', [100, 100, 800, 800]); % Large window
    imagesc(X*1000, Y*1000, img_disp);
    colormap('gray');
    axis image;
    
    % --- ZOOM IN FOR REPORT ---
    % Restrict view to -1mm to +1mm (Visual Zoom only)
    xlim([-1, 1]);
    ylim([-1, 1]);
    
    xlabel('x (mm)'); ylabel('y (mm)');
    title(sprintf('%s', titles_disp{i}));
    
    % Large Font for Report Readability
    set(gca, 'FontSize', 14);
    
    % Save automatically using CURRENT background color
    filename = sprintf('%s.png', object_names{i});
    fprintf("  Saving %s...\n", filename);
    exportgraphics(f_obj, filename, 'BackgroundColor', 'current');
end

fprintf("\n=== Separation Complete ===\n");