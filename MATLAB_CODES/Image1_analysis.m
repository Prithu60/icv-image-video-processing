% ===== Image1.jpg - Step 1: Read and display the original =====
clear; clc; close all;

I = imread('Image1.jpg');      % Load image into matrix I
figure;                         % Open new figure window
imshow(I);                      % Display the image
title('Figure 1: Original Image1.jpg - strong green colour cast');

% Print image properties in Command Window
fprintf('Image dimensions: %d x %d x %d\n', size(I,1), size(I,2), size(I,3));
fprintf('Data class: %s\n', class(I));
fprintf('Min pixel: %d   Max pixel: %d\n', min(I(:)), max(I(:)));

% ===== Image1.jpg - Step 2: RGB Channel Analysis =====

% Separate the three colour channels
R = I(:,:,1);   % Red channel
G = I(:,:,2);   % Green channel
B = I(:,:,3);   % Blue channel

% Show each channel as a grayscale image
figure;
subplot(1,3,1); imshow(R); title('Red Channel');
subplot(1,3,2); imshow(G); title('Green Channel');
subplot(1,3,3); imshow(B); title('Blue Channel');
sgtitle('Figure 2: RGB channels of Image1 (brighter = more of that colour)');

% Plot histograms for each channel
figure;
subplot(3,1,1); imhist(R); title('Histogram - Red Channel');
subplot(3,1,2); imhist(G); title('Histogram - Green Channel');
subplot(3,1,3); imhist(B); title('Histogram - Blue Channel');
sgtitle('Figure 3: Intensity histograms per channel');

% Calculate and print mean intensity of each channel
fprintf('\n--- Channel Statistics ---\n');
fprintf('Mean Red:   %.2f\n', mean(R(:)));
fprintf('Mean Green: %.2f\n', mean(G(:)));
fprintf('Mean Blue:  %.2f\n', mean(B(:)));

% ===== Image1.jpg - Step 3: Gray World Colour Correction =====

% Convert to double precision for accurate arithmetic
I_double = double(I);

% Calculate the mean of each channel
meanR = mean2(I_double(:,:,1));
meanG = mean2(I_double(:,:,2));
meanB = mean2(I_double(:,:,3));

% Compute the overall average (this is our "target gray" value)
meanGray = (meanR + meanG + meanB) / 3;

% Calculate scaling factors needed to bring each channel to the overall mean
scaleR = meanGray / meanR;
scaleG = meanGray / meanG;
scaleB = meanGray / meanB;

fprintf('\n--- Gray World Scaling Factors ---\n');
fprintf('Target gray value: %.2f\n', meanGray);
fprintf('Red scale factor:   %.3f\n', scaleR);
fprintf('Green scale factor: %.3f\n', scaleG);
fprintf('Blue scale factor:  %.3f\n', scaleB);

% Apply the scaling to each channel
I_corrected = I_double;
I_corrected(:,:,1) = I_corrected(:,:,1) * scaleR;
I_corrected(:,:,2) = I_corrected(:,:,2) * scaleG;
I_corrected(:,:,3) = I_corrected(:,:,3) * scaleB;

% Clip to valid range [0, 255] and convert back to uint8
I_corrected = uint8(min(max(I_corrected, 0), 255));

% Display before and after side by side
figure;
subplot(1,2,1); imshow(I);           title('Original (green cast)');
subplot(1,2,2); imshow(I_corrected); title('Gray World corrected');
sgtitle('Figure 4: Image1 - Before and After Gray World correction');

% Save the corrected image as a file
imwrite(I_corrected, 'Image1_corrected.jpg');
fprintf('\nCorrected image saved as Image1_corrected.jpg\n');

% ===== Image1.jpg - Step 4: White Patch (Max-RGB) Correction =====
% Gray World over-corrected toward magenta. White Patch uses the
% brightest pixel as the white reference instead.

% Use 99th percentile (more robust than absolute max - avoids over-saturating)
maxR_wp = double(prctile(reshape(I(:,:,1), [], 1), 99));
maxG_wp = double(prctile(reshape(I(:,:,2), [], 1), 99));
maxB_wp = double(prctile(reshape(I(:,:,3), [], 1), 99));

% Scaling factors to bring each channel's "near-max" to 255
scaleR_wp = 255 / maxR_wp;
scaleG_wp = 255 / maxG_wp;
scaleB_wp = 255 / maxB_wp;

fprintf('\n--- White Patch Scaling Factors (99th percentile) ---\n');
fprintf('99th percentile R: %.1f  -> scale: %.3f\n', maxR_wp, scaleR_wp);
fprintf('99th percentile G: %.1f  -> scale: %.3f\n', maxG_wp, scaleG_wp);
fprintf('99th percentile B: %.1f  -> scale: %.3f\n', maxB_wp, scaleB_wp);

% Apply the White Patch scaling
I_wp = double(I);
I_wp(:,:,1) = I_wp(:,:,1) * scaleR_wp;
I_wp(:,:,2) = I_wp(:,:,2) * scaleG_wp;
I_wp(:,:,3) = I_wp(:,:,3) * scaleB_wp;
I_wp = uint8(min(max(I_wp, 0), 255));

% Compare all THREE versions side by side
figure;
subplot(1,3,1); imshow(I);           title('(a) Original (green cast)');
subplot(1,3,2); imshow(I_corrected); title('(b) Gray World (magenta cast)');
subplot(1,3,3); imshow(I_wp);        title('(c) White Patch');
sgtitle('Figure 5: Comparison of colour correction methods');

% Save White Patch result
imwrite(I_wp, 'Image1_corrected_whitepatch.jpg');
fprintf('\nWhite Patch corrected image saved.\n');

% ===== Image1.jpg - Step 5: Soft Gray World (tuned correction) =====
% Full Gray World over-corrects to magenta. We apply a "softer" version
% by blending the Gray World scale factors with no-correction (scale = 1).
% A strength of 0.6 means we apply 60% of the Gray World correction.

strength = 0.85;   % Tuning parameter: 0 = no correction, 1 = full Gray World

% Compute softened scale factors (pull each scale toward 1.0)
scaleR_soft = 1 + (scaleR - 1) * strength;
scaleG_soft = 1 + (scaleG - 1) * strength;
scaleB_soft = 1 + (scaleB - 1) * strength;

fprintf('\n--- Soft Gray World (strength = %.1f) ---\n', strength);
fprintf('Red scale:   %.3f  (was %.3f)\n', scaleR_soft, scaleR);
fprintf('Green scale: %.3f  (was %.3f)\n', scaleG_soft, scaleG);
fprintf('Blue scale:  %.3f  (was %.3f)\n', scaleB_soft, scaleB);

% Apply the softer scaling
I_soft = double(I);
I_soft(:,:,1) = I_soft(:,:,1) * scaleR_soft;
I_soft(:,:,2) = I_soft(:,:,2) * scaleG_soft;
I_soft(:,:,3) = I_soft(:,:,3) * scaleB_soft;
I_soft = uint8(min(max(I_soft, 0), 255));

% Final comparison of ALL methods
figure;
subplot(2,2,1); imshow(I);           title('(a) Original (green cast)');
subplot(2,2,2); imshow(I_corrected); title('(b) Gray World (magenta)');
subplot(2,2,3); imshow(I_wp);        title('(c) White Patch (no change)');
subplot(2,2,4); imshow(I_soft);      title('(d) Soft Gray World - FINAL');
sgtitle('Figure 6: All correction methods compared - Soft Gray World wins');

% Verify the result by checking the new channel means
meanR_new = mean2(I_soft(:,:,1));
meanG_new = mean2(I_soft(:,:,2));
meanB_new = mean2(I_soft(:,:,3));
fprintf('\n--- After Soft Gray World correction ---\n');
fprintf('New Mean Red:   %.2f  (was %.2f)\n', meanR_new, meanR);
fprintf('New Mean Green: %.2f  (was %.2f)\n', meanG_new, meanG);
fprintf('New Mean Blue:  %.2f  (was %.2f)\n', meanB_new, meanB);

% Save the FINAL corrected image
imwrite(I_soft, 'Image1_FINAL_corrected.jpg');
fprintf('\n*** FINAL corrected image saved as Image1_FINAL_corrected.jpg ***\n');