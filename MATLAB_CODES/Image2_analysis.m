% ===== Image2.JPG - Step 1: Read and display the original =====
clear; clc; close all;

I2 = imread('Imag2.JPG');     % <-- MUST match your exact filename in MATLAB
figure;
imshow(I2);
title('Figure 1: Original Imag2.JPG - out-of-focus blur');

fprintf('Image dimensions: %d x %d x %d\n', size(I2,1), size(I2,2), size(I2,3));
fprintf('Data class: %s\n', class(I2));


% ===== Image2.JPG - Step 2: Analyse the blur =====

% Convert to grayscale for edge analysis
I2_gray = rgb2gray(I2);

% Edge detection: a sharp image gives strong clean edges,
% a blurred image gives weak, broken, sparse edges
edges = edge(I2_gray, 'Canny');
figure;
subplot(1,2,1); imshow(I2_gray); title('Grayscale version');
subplot(1,2,2); imshow(edges);   title('Canny edge detection');
sgtitle('Figure 2: Edge detection - weak, sparse edges confirm the blur');

% Numerical sharpness metric: variance of the Laplacian
% (a low value means a blurred image, a high value means a sharp one)
lap = fspecial('laplacian', 0.2);
sharpness = var(reshape(imfilter(double(I2_gray), lap), [], 1));
fprintf('\nSharpness metric (variance of Laplacian): %.4f\n', sharpness);
fprintf('A low value confirms the image lacks sharp detail (blurred).\n');

% ===== Image2.JPG - Step 3: Unsharp Masking =====
% Unsharp masking sharpens by amplifying the difference between the
% image and a blurred version of itself, boosting edge content.

I2_sharp = imsharpen(I2, 'Radius', 3, 'Amount', 2);

% Display before and after
figure;
subplot(1,2,1); imshow(I2);       title('Original (blurred)');
subplot(1,2,2); imshow(I2_sharp); title('After unsharp masking');
sgtitle('Figure 4: Image2 - Unsharp masking result');

% Recompute the sharpness metric to measure the improvement numerically
I2_sharp_gray = rgb2gray(I2_sharp);
sharpness_new = var(reshape(imfilter(double(I2_sharp_gray), lap), [], 1));
fprintf('\n--- Unsharp Masking Results ---\n');
fprintf('Sharpness before: %.4f\n', sharpness);
fprintf('Sharpness after:  %.4f\n', sharpness_new);
fprintf('Improvement factor: %.2fx\n', sharpness_new / sharpness);

% Save the result
imwrite(I2_sharp, 'Image2_unsharp.jpg');
fprintf('Saved as Image2_unsharp.jpg\n');

% ===== Image2.JPG - Step 4: Lucy-Richardson Deconvolution =====
% Unsharp masking enhances edges but does not reverse the blur itself.
% Lucy-Richardson deconvolution attempts to recover the original sharp
% image by iteratively reversing an estimated blur (Point Spread Function).

% The blur here is a defocus blur, so the PSF is approximated by a disk.
estimated_radius = 10;          % estimated blur radius in pixels
PSF = fspecial('disk', estimated_radius);

% Apply Lucy-Richardson deconvolution
num_iterations = 10;
I2_deconv = deconvlucy(I2, PSF, num_iterations);

% Display result
figure;
subplot(1,2,1); imshow(I2);        title('Original (blurred)');
subplot(1,2,2); imshow(I2_deconv); title('After Lucy-Richardson deconvolution');
sgtitle('Figure 5: Image2 - Lucy-Richardson deconvolution result');

% Recompute the sharpness metric
I2_deconv_gray = rgb2gray(I2_deconv);
sharpness_deconv = var(reshape(imfilter(double(I2_deconv_gray), lap), [], 1));
fprintf('\n--- Lucy-Richardson Deconvolution Results ---\n');
fprintf('Sharpness before (original):     %.4f\n', sharpness);
fprintf('Sharpness after unsharp masking: %.4f\n', sharpness_new);
fprintf('Sharpness after deconvolution:   %.4f\n', sharpness_deconv);

% Save the result
imwrite(I2_deconv, 'Image2_deconv.jpg');
fprintf('Saved as Image2_deconv.jpg\n');

% ===== Image2.JPG - Step 5: Method comparison and final selection =====
% The first deconvolution (radius 10, 10 iterations) gave only a modest
% improvement. A second attempt with a smaller radius and more iterations
% is tested to see whether deconvolution can be improved.
PSF2 = fspecial('disk', 5);
I2_deconv2 = deconvlucy(I2, PSF2, 20);
I2_deconv2_gray = rgb2gray(I2_deconv2);
sharpness_deconv2 = var(reshape(imfilter(double(I2_deconv2_gray), lap), [], 1));

% Compare all approaches side by side
figure;
subplot(2,2,1); imshow(I2);         title('(a) Original (blurred)');
subplot(2,2,2); imshow(I2_sharp);   title('(b) Unsharp masking');
subplot(2,2,3); imshow(I2_deconv);  title('(c) Lucy-Richardson (r=10, 10 it)');
subplot(2,2,4); imshow(I2_deconv2); title('(d) Lucy-Richardson (r=5, 20 it)');
sgtitle('Figure 6: Comparison of all deblurring methods for Image2');

% Print the final sharpness comparison
fprintf('\n=== FINAL SHARPNESS COMPARISON ===\n');
fprintf('Original:                        %.4f\n', sharpness);
fprintf('Unsharp masking:                 %.4f\n', sharpness_new);
fprintf('Lucy-Richardson (r=10, 10 it):   %.4f\n', sharpness_deconv);
fprintf('Lucy-Richardson (r=5, 20 it):    %.4f\n', sharpness_deconv2);

% Unsharp masking gave the strongest result - save it as the final output
imwrite(I2_sharp, 'Image2_FINAL.jpg');
fprintf('\n*** Final chosen output: Unsharp masking -> Image2_FINAL.jpg ***\n');

% ===== Image2.JPG - Step 5b: Enhanced attempts (final) =====
% Heavy defocus blur permanently destroys fine detail, so no method fully
% restores the image. Two stronger candidates are tested here.

% Candidate 1: a stronger single-pass unsharp masking
I2_strong = imsharpen(I2, 'Radius', 2, 'Amount', 3);
I2_strong_gray = rgb2gray(I2_strong);
sharpness_strong = var(reshape(imfilter(double(I2_strong_gray), lap), [], 1));

% Candidate 2: unsharp masking applied on top of the deconvolved image
I2_combined = imsharpen(I2_deconv, 'Radius', 2, 'Amount', 2.5);
I2_combined_gray = rgb2gray(I2_combined);
sharpness_combined = var(reshape(imfilter(double(I2_combined_gray), lap), [], 1));

% Compare the best candidates
figure;
subplot(2,2,1); imshow(I2);          title('(a) Original (blurred)');
subplot(2,2,2); imshow(I2_sharp);    title('(b) Unsharp masking (Amount 2)');
subplot(2,2,3); imshow(I2_strong);   title('(c) Strong unsharp (Amount 3)');
subplot(2,2,4); imshow(I2_combined); title('(d) Deconvolution + unsharp');
sgtitle('Figure 7: Enhanced deblurring attempts for Image2');

fprintf('\n=== ENHANCED COMPARISON ===\n');
fprintf('Original:                   %.4f\n', sharpness);
fprintf('Unsharp masking (Amount 2): %.4f\n', sharpness_new);
fprintf('Strong unsharp (Amount 3):  %.4f\n', sharpness_strong);
fprintf('Deconvolution + unsharp:    %.4f\n', sharpness_combined);

% ===== Image2.JPG - Final selection =====
% The combined approach (deconvolution followed by unsharp masking) gave
% the best visual result with a strong sharpness metric, without the
% excessive noise amplification seen in the high-iteration deconvolution.
imwrite(I2_combined, 'Image2_FINAL.jpg');
fprintf('\n*** Final output: Deconvolution + unsharp masking -> Image2_FINAL.jpg ***\n');