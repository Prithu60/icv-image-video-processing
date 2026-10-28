%% ============================================================
%  SECTION 2.6 - Image6.jpg : HAZE / DUST + COLOUR CAST + LOW CONTRAST
%  ============================================================

%% Step 1 - Read and display the original image
clear; clc; close all;

img6 = imread('Image6.jpg');
fprintf('--- Image6.jpg properties ---\n');
fprintf('Size     : %d x %d\n', size(img6,1), size(img6,2));
fprintf('Channels : %d\n', size(img6,3));
fprintf('Class    : %s\n', class(img6));

figure, imshow(img6)
title('Original Image6.jpg - heavy dust/haze, yellow cast and low contrast');

%% Step 2 - Analysing the haze, colour cast and contrast
% Per-channel means quantify the colour cast; per-channel and grayscale
% standard deviation / dynamic range quantify the loss of contrast.
R = img6(:,:,1);  G = img6(:,:,2);  B = img6(:,:,3);
fprintf('\nChannel means : R=%.2f, G=%.2f, B=%.2f\n', ...
    mean(R(:)), mean(G(:)), mean(B(:)));
fprintf('Channel stds  : R=%.2f, G=%.2f, B=%.2f\n', ...
    std(double(R(:))), std(double(G(:))), std(double(B(:))));

gray6 = rgb2gray(img6);
fprintf('Grayscale dynamic range : [%d  %d]\n', min(gray6(:)), max(gray6(:)));
fprintf('Grayscale mean = %.2f, std = %.2f\n', ...
    mean(gray6(:)), std(double(gray6(:))));

figure
subplot(1,3,1), imhist(R), title('Red channel histogram');
subplot(1,3,2), imhist(G), title('Green channel histogram');
subplot(1,3,3), imhist(B), title('Blue channel histogram');

%% Step 3 - Method 1: imreducehaze (built-in dehazing)
% imreducehaze estimates the atmospheric light scattered into the scene
% and subtracts an estimated transmission map to recover the underlying scene.
% 'approxdcp' = approximate dark channel prior (He et al. 2011).
img6_dehaze = imreducehaze(img6, 0.8, 'Method', 'simpledcp');

figure
subplot(1,2,1), imshow(img6),        title('Original');
subplot(1,2,2), imshow(img6_dehaze), title('imreducehaze (amount=0.8)');

%% Step 4 - Method 2: Decorrelation stretch
% decorrstretch removes correlation between the colour channels - particularly
% effective when one channel dominates the scene (here, yellow = R+G).
img6_decorr = decorrstretch(img6, 'Tol', 0.01);

figure
subplot(1,2,1), imshow(img6),        title('Original');
subplot(1,2,2), imshow(img6_decorr), title('Decorrelation stretch');

%% Step 5 - Combined approach and final selection
% imreducehaze recovers depth/contrast well but leaves residual local haze;
% CLAHE on the Value channel of the dehazed image firms up local contrast
% without re-introducing a colour cast.
hsvImg = rgb2hsv(img6_dehaze);
hsvImg(:,:,3) = adapthisteq(hsvImg(:,:,3), 'ClipLimit', 0.005);
img6_final = im2uint8(hsv2rgb(hsvImg));

% Post-correction statistics
gray_final = rgb2gray(img6_final);
fprintf('\n--- After correction (final) ---\n');
fprintf('Final grayscale mean = %.2f, std = %.2f\n', ...
    mean(gray_final(:)), std(double(gray_final(:))));
fprintf('Final dynamic range  : [%d  %d]\n', ...
    min(gray_final(:)), max(gray_final(:)));

figure
subplot(2,2,1), imshow(img6),        title('(a) Original');
subplot(2,2,2), imshow(img6_dehaze), title('(b) imreducehaze');
subplot(2,2,3), imshow(img6_decorr), title('(c) Decorrelation stretch');
subplot(2,2,4), imshow(img6_final),  title('(d) imreducehaze + CLAHE (final)');

imwrite(img6_final, 'Image6_FINAL.jpg');
fprintf('\nFinal image saved as Image6_FINAL.jpg\n');