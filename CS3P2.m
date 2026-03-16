%% Task 1a: Load and view the raw light field
clear; 
clc; 
close all;

load('lightField.mat');
rays_in = rays; % The data is a 4xN matrix called 'rays'
clear rays; % Free up memory, as 'rays' is very large

% Set reasonable sensor parameters
width = 5 / 1000;  % 5 mm width
Npixels = 400;     % 200x200 pixels

% Use rays2img to render the raw rays
% rays_in(1,:) is x-position 
% rays_in(3,:) is y-position 
[img_raw, x, y] = rays2img(rays_in(1,:), rays_in(3,:), width, Npixels);

figure;
imagesc(x, y, img_raw);
colormap('gray');
axis image;
title('Task 1a: Raw lightField.mat Data');
% We see a blurry image that is similar to figure 8

%% Task 1d: Test propagation in free space
d = 0.1; % 100 mm (Try a few different values for d)

% Free-space propagation matrix M_d 
M_d = [
    1, d, 0, 0;
    0, 1, 0, 0;
    0, 0, 1, d;
    0, 0, 0, 1
];

% Propagate all rays
rays_out_d = M_d * rays_in;

% Render the propagated rays
[img_d, x, y] = rays2img(rays_out_d(1,:), rays_out_d(3,:), width, Npixels);

figure;
imagesc(x, y, img_d);
colormap('gray');
axis image;
title(sprintf('Task 1d: Propagated by d = %.1f m', d));
% This is also blurry

%% Task 2: Verbal Explanation about Bluriness
% Provide a verbal explanation about the observed bluriness
%
% We are unable to create a sharp, focused image because the 
% free-space propagation Matrix M_d only simulates rays traveling in
% straight lines,

% As the hint suggests, rays from a single object point are traveling at random angles.
% When we render this data directly (Task 1a), we're essentially placing a sensor in the middle of all these mixed-up rays. 
% Each pixel on our sensor gets hit by rays from many different object points,
% resulting in a blurry, unintelligible image (like in Figure 8).

% The initial blur observed in the raw light field arises because rays emanating 
% from a single point on the object propagate at varying angles3. In free space propagation ($M_d$),
%  there is no mechanism to redirect these diverging rays back to a single point. 
% Consequently, any given pixel on the sensor integrates rays originating from multiple distinct 
% points on the object4. This spatial mixing destroys high-frequency information, resulting in 
% a blurry image. The lens matrix $M_f$ is required to refract these diverging rays so that they
%  converge at the specific image distance $d_2$.

% The matrix M_d can't fix this because the matrix can't change the angle
% of the ray, it will never allow these rays to converge, which is more or
% less what we are looking for in focusing a blurry image.

% We need to physically bend these ryas, which is why we have the lens
% matrix M_f
disp('The bluriness observed in the images is likely due to the propagation distance being too large or the lens not being properly focused. Adjusting the focal length or the propagation distance may help achieve a clearer image.');

%% Task 3: Design an imaging system to focus the rays
disp('Running Task 3: Hunting for focus...');

% Load the rays again if needed
if ~exist('rays_in', 'var')
    load('lightField.mat');
    rays_in = rays;
    clear rays;
end

% 1. Choose a fixed focal length for your lens
f = 0.1; % 100 mm (You can experiment with this value)

% Define the lens matrix M_f 
M_f = [
    1, 0, 0, 0;
    -1/f, 1, 0, 0;
    0, 0, 1, 0;
    0, 0, -1/f, 1
];
% 2. find for the focus by trying different d2 distances 
% We will try 10 distances from 50mm to 200mm
d2_range = linspace(0.05, 0.2, 10); 

% Sensor parameters
width = 5 / 1000;
Npixels = 200;

figure('Name', 'Task 3: Hunting for Focus');
sgtitle(sprintf('Hunting for focus with f = %.0f mm', f*1000));

for i = 1:length(d2_range)
    d2 = d2_range(i);
    fprintf('  Trying d2 = %.3f m...\n', d2);
    
    % 3. Define propagation matrix M_d2 
    M_d2 = [
        1, d2, 0, 0;
        0, 1, 0, 0;
        0, 0, 1, d2;
        0, 0, 0, 1
    ];
    
    % 4. Build total system matrix M = M_d2 * M_f
    % (Rays hit lens, then propagate distance d2)
    M_total = M_d2 * M_f;
    
    % 5. Transform all 3 million rays (this may take a second)
    rays_final = M_total * rays_in;
    
    % 6. Render the image at this d2 distance 
    [img, x, y] = rays2img(rays_final(1,:), rays_final(3,:), width, Npixels);
    
    % 7. Display the image in a subplot
    subplot(2, 5, i); % Assumes a 2x5 grid for 10 images
    imagesc(x, y, img);
    colormap('gray');
    axis image;
    set(gca, 'XTick', [], 'YTick', []); % Hide axes ticks
    title(sprintf('d2 = %.0f mm', d2*1000));
end


%% --- Fine-Tune Focus Step ---
% We found a potential object around d2 = 140 mm (0.14 m).
% Now we scan tightly around that value to find the perfect focus.


disp('Running Fine-Tune Search...');

% 1. Keep the SAME focal length you used before
f = 0.1; % 100 mm 

% 2. Define a NARROW range around the point of interest
d2_fine = linspace(0.132, 0.1355, 4); % Scan 130mm to 140mm

% Define lens matrix M_f (constant)
M_f = [
    1, 0, 0, 0;
    -1/f, 1, 0, 0;
    0, 0, 1, 0;
    0, 0, -1/f, 1
];

% Setup the figure
figure('Name', 'Fine Focus Hunt');
sgtitle(sprintf('Fine-Tuning Focus around d2 ~ 140mm (f=%.0fmm)', f*1000));

% 3. Loop through the fine values
for i = 1:length(d2_fine)
    d2 = d2_fine(i);
    
    % Define propagation matrix M_d2
    M_d2 = [
        1, d2, 0, 0;
        0, 1, 0, 0;
        0, 0, 1, d2;
        0, 0, 0, 1
    ];
    
    % Build total system matrix
    M_total = M_d2 * M_f;
    
    % Transform rays
    rays_final = M_total * rays_in;
    
    % Render image
    % (You might want to increase Npixels to 300 or 400 here for better detail!)
    [img, x, y] = rays2img(rays_final(1,:), rays_final(3,:), width, Npixels);
    
    % Plot
    subplot(2, 2, i);
    imagesc(x, y, img);
    colormap('gray');
    axis image;
    set(gca, 'XTick', [], 'YTick', []);
    
    % Title with ONE decimal place to see the subtle differences
    title(sprintf('d2 = %.1f mm', d2*1000));
end