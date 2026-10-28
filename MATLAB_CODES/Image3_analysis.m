% ===== Image3.bmp - Step 1: Read and display the original =====
clear; clc; close all;

I3 = imread('Image3.bmp');
figure;
imshow(I3);
title('Figure 1: Original Image3.bmp - heavy noise');

fprintf('Image dimensions: %d x %d\n', size(I3,1), size(I3,2));
fprintf('Number of channels: %d\n', size(I3,3));
fprintf('Data class: %s\n', class(I3));


% ===== Image3.bmp - Step 2: Analyse the noise =====

% Histogram of the noisy image
figure;
imhist(I3);
title('Figure 2: Intensity histogram of Image3.bmp');

% Zoom into a small region to make the noise texture clearly visible
region = I3(50:90, 90:150);
figure;
subplot(1,2,1); imshow(I3); title('Full noisy image');
subplot(1,2,2); imshow(region, 'InitialMagnification', 500);
title('Zoomed region - noise clearly visible');
sgtitle('Figure 3: Close-up showing the noise texture');

% Estimate the noise level from the standard deviation of a flatter region
flat_region = I3(150:175, 195:220);
noise_std = std(double(flat_region(:)));
fprintf('\nEstimated noise level (std dev of a flat region): %.2f\n', noise_std);
fprintf('A high value indicates strong noise contamination.\n');

% ===== Image3.bmp - Step 3: Median Filtering =====
% Median filtering replaces each pixel with the median of its neighbourhood.
% It is particularly effective against impulse (salt-and-pepper) noise and
% preserves edges better than simple averaging.

I3_median3 = medfilt2(I3, [3 3]);     % 3x3 median filter
I3_median5 = medfilt2(I3, [5 5]);     % 5x5 median filter

% Display the results
figure;
subplot(1,3,1); imshow(I3);         title('Original (noisy)');
subplot(1,3,2); imshow(I3_median3); title('Median filter 3x3');
subplot(1,3,3); imshow(I3_median5); title('Median filter 5x5');
sgtitle('Figure 4: Image3 - Median filtering results');

% Measure noise reduction in the same flat region used in Step 2
flat3 = I3_median3(150:175, 195:220);
flat5 = I3_median5(150:175, 195:220);
fprintf('\n--- Median Filtering Results ---\n');
fprintf('Noise std - original:    %.2f\n', noise_std);
fprintf('Noise std - 3x3 median:  %.2f\n', std(double(flat3(:))));
fprintf('Noise std - 5x5 median:  %.2f\n', std(double(flat5(:))));

% Save the 5x5 result
imwrite(I3_median5, 'Image3_median.jpg');
fprintf('Saved as Image3_median.jpg\n');

% ===== Image3.bmp - Step 4: Wiener Filtering =====
% The Wiener filter (wiener2) is an adaptive filter: it estimates the local
% image statistics and adjusts its smoothing accordingly, smoothing more in
% flat areas and less near edges. It is well suited to Gaussian noise.

I3_wiener3 = wiener2(I3, [3 3]);
I3_wiener5 = wiener2(I3, [5 5]);

% Display results
figure;
subplot(1,3,1); imshow(I3);         title('Original (noisy)');
subplot(1,3,2); imshow(I3_wiener3); title('Wiener filter 3x3');
subplot(1,3,3); imshow(I3_wiener5); title('Wiener filter 5x5');
sgtitle('Figure 5: Image3 - Wiener filtering results');

% Measure noise reduction in the same flat road-surface region
fw3 = I3_wiener3(150:175, 195:220);
fw5 = I3_wiener5(150:175, 195:220);
fprintf('\n--- Wiener Filtering Results ---\n');
fprintf('Noise std - original:    %.2f\n', noise_std);
fprintf('Noise std - 3x3 Wiener:  %.2f\n', std(double(fw3(:))));
fprintf('Noise std - 5x5 Wiener:  %.2f\n', std(double(fw5(:))));

% Save the 5x5 result
imwrite(I3_wiener5, 'Image3_wiener.jpg');
fprintf('Saved as Image3_wiener.jpg\n');

% ===== Image3.bmp - Step 5: Comparison and final selection =====
% The noise in Image3 is a combination of impulse (pepper) noise and
% Gaussian noise. Median filtering handles the impulse noise well, while
% Wiener filtering targets the Gaussian component. A combined approach is
% tested: median filtering first to remove impulse noise, then a light
% Wiener filter to reduce the residual Gaussian noise.

I3_combined = wiener2(medfilt2(I3, [3 3]), [3 3]);

% Measure noise level of each candidate in the flat road-surface region
std_median5  = std(double(reshape(I3_median5(150:175,195:220),  [], 1)));
std_wiener5  = std(double(reshape(I3_wiener5(150:175,195:220),  [], 1)));
std_combined = std(double(reshape(I3_combined(150:175,195:220), [], 1)));

% Compare the best candidates side by side
figure;
subplot(2,2,1); imshow(I3);          title('(a) Original (noisy)');
subplot(2,2,2); imshow(I3_median5);  title('(b) Median 5x5');
subplot(2,2,3); imshow(I3_wiener5);  title('(c) Wiener 5x5');
subplot(2,2,4); imshow(I3_combined); title('(d) Median 3x3 + Wiener 3x3');
sgtitle('Figure 6: Comparison of denoising methods for Image3');

% Print the final comparison
fprintf('\n=== FINAL NOISE COMPARISON ===\n');
fprintf('Original:                  %.2f\n', noise_std);
fprintf('Median 5x5:                %.2f\n', std_median5);
fprintf('Wiener 5x5:                %.2f\n', std_wiener5);
fprintf('Median 3x3 + Wiener 3x3:   %.2f\n', std_combined);

% Save the combined result as the final output
imwrite(I3_combined, 'Image3_FINAL.jpg');
fprintf('\n*** Final output: Median + Wiener -> Image3_FINAL.jpg ***\n');