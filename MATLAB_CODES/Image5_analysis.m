%% ============================================================
%  SECTION 2.5 - Image5.jpg : LOCALISED MOTION BLUR
%  ============================================================

%% Step 1 - Read and display the original image
clear; clc; close all;

img5 = imread('Image5.jpg');
fprintf('--- Image5.jpg properties ---\n');
fprintf('Size     : %d x %d\n', size(img5,1), size(img5,2));
fprintf('Channels : %d\n', size(img5,3));
fprintf('Class    : %s\n', class(img5));

figure, imshow(img5)
title('Original Image5.jpg - motion blur on the walking subject');

%% Step 2 - Analysing the blur
% KEY POINT: the blur is LOCALISED to the moving subject - the building,
% signs and trees are sharp. So all measurements must be taken on a crop
% of the SUBJECT, not the whole image (the sharp background would dominate).

gray5 = rgb2gray(img5);

% --- Subject region of interest (the blurred man) - ADJUST to your image ---
rTop = 300; rBot = 1424; cLeft = 350; cRight = 950;
subj = gray5(rTop:rBot, cLeft:cRight);

figure
subplot(1,2,1), imshow(gray5), title('Grayscale Image5');
hold on, rectangle('Position',[cLeft rTop cRight-cLeft rBot-rTop], ...
        'EdgeColor','y','LineWidth',2), hold off
subplot(1,2,2), imshow(subj), title('Cropped subject region (analysed)');

% (a) Canny edge map of the subject - weak/broken edges = blurred
figure, imshow(edge(subj,'canny')), title('Canny edge map of subject region');

% (b) Laplacian-variance sharpness metric, measured on the SUBJECT only
lap = fspecial('laplacian', 0.2);
sharpness = @(I) var(reshape( ...
    imfilter(double(rgb2gray(I(rTop:rBot,cLeft:cRight,:))), lap), [], 1));
sharp_orig = sharpness(img5);
fprintf('\nSubject-region sharpness (original) = %.2f\n', sharp_orig);

% (c) Directional gradient test on the SUBJECT - horizontal motion blur
% smears vertical edges, so it reduces |Gx|. Expect |Gy| > |Gx|, ratio > 1.
[Gx, Gy] = imgradientxy(double(subj));
Eh = mean(abs(Gx(:)));  Ev = mean(abs(Gy(:)));
fprintf('Subject mean |Gx| = %.3f, mean |Gy| = %.3f\n', Eh, Ev);
fprintf('Vertical/Horizontal ratio = %.2f  (>1 => horizontal motion blur)\n', Ev/Eh);

%% Step 3 - Estimating the motion PSF
% Directional blur => line PSF. Subject walks roughly horizontally => THETA ~ 0.
% LEN estimated from the visible streak length on the subject.
LEN   = 31;   % tune across ~21-45 and keep the most natural result
THETA = 0;    % horizontal
PSF = fspecial('motion', LEN, THETA);

%% Step 4 - Method comparison: Lucy-Richardson vs Wiener (global)
img5_lucy = deconvlucy(img5, PSF, 10);
img5_wnr  = deconvwnr(img5, PSF, 0.01);

fprintf('\nSubject sharpness - Lucy-Richardson = %.2f\n', sharpness(img5_lucy));
fprintf('Subject sharpness - Wiener         = %.2f\n', sharpness(img5_wnr));

figure
subplot(1,3,1), imshow(img5),      title('(a) Original');
subplot(1,3,2), imshow(img5_lucy), title('(b) Lucy-Richardson');
subplot(1,3,3), imshow(img5_wnr),  title('(c) Wiener - note ringing on background');

%% Step 5 - Masked compositing and final selection
% Global deconvolution damages the already-sharp background. The fix is to
% keep the DEBLURRED SUBJECT and the ORIGINAL SHARP BACKGROUND, blended with
% a feathered mask. Lucy-Richardson is used (least ringing).

mask = zeros(size(gray5));
mask(rTop:rBot, cLeft:cRight) = 1;
mask = imgaussfilt(mask, 40);            % feather the edges for a smooth blend
mask3 = repmat(mask, [1 1 3]);

img5_final = uint8( double(img5_lucy).*mask3 + double(img5).*(1-mask3) );

fprintf('\n--- Subject-region sharpness comparison ---\n');
fprintf('Original                    : %.2f\n', sharp_orig);
fprintf('Lucy-Richardson (global)    : %.2f\n', sharpness(img5_lucy));
fprintf('Wiener (global)             : %.2f\n', sharpness(img5_wnr));
fprintf('Lucy-Richardson + composite : %.2f\n', sharpness(img5_final));

figure
subplot(2,2,1), imshow(img5),       title('(a) Original');
subplot(2,2,2), imshow(img5_lucy),  title('(b) Lucy-Richardson (global)');
subplot(2,2,3), imshow(img5_wnr),   title('(c) Wiener (global) - ringing');
subplot(2,2,4), imshow(img5_final), title('(d) Lucy + composite (final)');

imwrite(img5_final, 'Image5_FINAL.jpg');
fprintf('\nFinal image saved as Image5_FINAL.jpg\n');