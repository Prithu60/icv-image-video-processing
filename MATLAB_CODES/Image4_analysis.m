% ===== Image4.jpg - Step 1: Read and display the original =====
clear; clc; close all;

I4 = imread('Image4.jpg');
figure;
imshow(I4);
title('Figure 1: Original Image4.jpg - underexposed / too dark');

fprintf('Image dimensions: %d x %d x %d\n', size(I4,1), size(I4,2), size(I4,3));
fprintf('Data class: %s\n', class(I4));


% ===== Image4.jpg - Step 2: Analyse the brightness =====

% Convert to grayscale to analyse the overall brightness distribution
I4_gray = rgb2gray(I4);

% Histogram of the grayscale image
figure;
imhist(I4_gray);
title('Figure 2: Intensity histogram of Image4 - heavy skew toward dark values');

% Print brightness statistics
fprintf('\n--- Brightness Statistics ---\n');
fprintf('Mean brightness:   %.1f (out of 255)\n', mean(I4_gray(:)));
fprintf('Median brightness: %.1f\n', median(double(I4_gray(:))));
dark_pct = 100 * sum(I4_gray(:) < 60) / numel(I4_gray);
fprintf('Pixels below 60 (dark):    %.1f%%\n', dark_pct);
bright_pct = 100 * sum(I4_gray(:) > 200) / numel(I4_gray);
fprintf('Pixels above 200 (bright): %.1f%%\n', bright_pct);

% ===== Image4.jpg - Step 3: Global Histogram Equalisation =====
% Histogram equalisation redistributes the intensity values so they span
% the full range more evenly, increasing contrast and revealing detail
% hidden in the shadows. For a colour image, the equalisation is applied
% only to the brightness (Value) channel in HSV colour space, so that the
% colours themselves are preserved.

% Convert to HSV colour space
I4_hsv = rgb2hsv(I4);

% Apply histogram equalisation to the Value (brightness) channel only
I4_hsv_eq = I4_hsv;
I4_hsv_eq(:,:,3) = histeq(I4_hsv(:,:,3));

% Convert back to RGB (and to uint8 for consistency)
I4_histeq = im2uint8(hsv2rgb(I4_hsv_eq));

% Display before and after
figure;
subplot(1,2,1); imshow(I4);        title('Original (underexposed)');
subplot(1,2,2); imshow(I4_histeq); title('After global histogram equalisation');
sgtitle('Figure 3: Image4 - Global histogram equalisation result');

% Show the new brightness statistics
I4_histeq_gray = rgb2gray(I4_histeq);
fprintf('\n--- Histogram Equalisation Results ---\n');
fprintf('Mean brightness - original:  %.1f\n', mean(I4_gray(:)));
fprintf('Mean brightness - equalised: %.1f\n', mean(I4_histeq_gray(:)));

% Save the result
imwrite(I4_histeq, 'Image4_histeq.jpg');
fprintf('Saved as Image4_histeq.jpg\n');

% ===== Image4.jpg - Step 4: Adaptive Histogram Equalisation (CLAHE) =====
% Global equalisation brightened the image but produced a washed-out, hazy
% look because it applies one transformation to the whole image. CLAHE
% (Contrast-Limited Adaptive Histogram Equalisation) instead works on small
% local tiles and limits the contrast gain in each one, giving a more
% natural result and avoiding over-amplification.

% Convert to HSV and apply adapthisteq to the Value channel only
I4_hsv_clahe = I4_hsv;
I4_hsv_clahe(:,:,3) = adapthisteq(I4_hsv(:,:,3), 'ClipLimit', 0.02);
I4_clahe = im2uint8(hsv2rgb(I4_hsv_clahe));

% Display before and after
figure;
subplot(1,2,1); imshow(I4);       title('Original (underexposed)');
subplot(1,2,2); imshow(I4_clahe); title('After CLAHE (adaptive equalisation)');
sgtitle('Figure 4: Image4 - Adaptive histogram equalisation (CLAHE) result');

% Brightness statistic
I4_clahe_gray = rgb2gray(I4_clahe);
fprintf('\n--- CLAHE Results ---\n');
fprintf('Mean brightness - original: %.1f\n', mean(I4_gray(:)));
fprintf('Mean brightness - CLAHE:    %.1f\n', mean(I4_clahe_gray(:)));

% Save the result
imwrite(I4_clahe, 'Image4_clahe.jpg');
fprintf('Saved as Image4_clahe.jpg\n');

% ===== Image4.jpg - Step 5: Comparison and final selection =====
% Global equalisation looked hazy, and CLAHE at ClipLimit 0.02 amplified
% noise in the dark sky. Two refinements are tested: a gentler CLAHE with a
% lower clip limit, and gamma correction, which brightens the shadows with
% a smooth curve and does not amplify noise the way equalisation does.

% Refinement 1: gentler CLAHE (lower clip limit)
I4_hsv_clahe2 = I4_hsv;
I4_hsv_clahe2(:,:,3) = adapthisteq(I4_hsv(:,:,3), 'ClipLimit', 0.005);
I4_clahe2 = im2uint8(hsv2rgb(I4_hsv_clahe2));

% Refinement 2: gamma correction on the Value channel (gamma < 1 brightens)
I4_hsv_gamma = I4_hsv;
I4_hsv_gamma(:,:,3) = imadjust(I4_hsv(:,:,3), [], [], 0.5);
I4_gamma = im2uint8(hsv2rgb(I4_hsv_gamma));

% Compare all candidates
figure;
subplot(2,2,1); imshow(I4);        title('(a) Original (underexposed)');
subplot(2,2,2); imshow(I4_histeq); title('(b) Global equalisation');
subplot(2,2,3); imshow(I4_clahe2); title('(c) Gentle CLAHE (clip 0.005)');
subplot(2,2,4); imshow(I4_gamma);  title('(d) Gamma correction (gamma 0.5)');
sgtitle('Figure 5: Comparison of contrast enhancement methods for Image4');

% Brightness comparison
g_histeq = rgb2gray(I4_histeq);
g_clahe2 = rgb2gray(I4_clahe2);
g_gamma  = rgb2gray(I4_gamma);
fprintf('\n=== FINAL BRIGHTNESS COMPARISON ===\n');
fprintf('Original:            %.1f\n', mean(I4_gray(:)));
fprintf('Global equalisation: %.1f\n', mean(g_histeq(:)));
fprintf('Gentle CLAHE:        %.1f\n', mean(g_clahe2(:)));
fprintf('Gamma correction:    %.1f\n', mean(g_gamma(:)));

% Save the gamma-corrected result as the likely final output
imwrite(I4_gamma, 'Image4_FINAL.jpg');
fprintf('\n*** Final output: Gamma correction -> Image4_FINAL.jpg ***\n');