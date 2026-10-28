%% ============================================================
%  SECTION 2.8 - video1.avi : CCTV parking-lot footage
%  Task: detect and locate the moving vehicle in each frame
%  ============================================================

%% Step 1 - Reading and inspecting the video
clear; clc; close all;

vr = VideoReader('video1.avi');
N  = vr.NumFrames;
fprintf('--- video1.avi ---\n');
fprintf('Frame size   : %d x %d\n', vr.Height, vr.Width);
fprintf('Frame rate   : %.2f fps\n', vr.FrameRate);
fprintf('Duration     : %.2f s\n', vr.Duration);
fprintf('Total frames : %d\n', N);

frames = read(vr, [1 N]);   % H x W x 3 x N

% Four key frames as a montage
keyIdx   = round(linspace(1, N, 4));
keyCells = cell(1, numel(keyIdx));
for i = 1:numel(keyIdx), keyCells{i} = frames(:,:,:,keyIdx(i)); end
figure, montage(keyCells, 'Size', [1 4])
title(sprintf('Four key frames from video1.avi (frames %s)', mat2str(keyIdx)));

%% Step 2 - Analysing the motion across the sequence
motion = zeros(N-1, 1);
for k = 2:N
    g0 = double(rgb2gray(frames(:,:,:,k-1)));
    g1 = double(rgb2gray(frames(:,:,:,k)));
    motion(k-1) = mean(abs(g1(:) - g0(:)));
end
fprintf('\nFrame-to-frame motion intensity:\n');
fprintf('  min=%.2f, max=%.2f, mean=%.2f\n', min(motion), max(motion), mean(motion));
[~, peakIdx]  = max(motion);
[~, quietIdx] = min(motion);
fprintf('  peak motion at transition %d->%d (van moves)\n', peakIdx, peakIdx+1);
fprintf('  quietest at transition %d->%d (van nearly stationary)\n', quietIdx, quietIdx+1);

figure, plot(motion, 'LineWidth', 1.2), grid on
xlabel('Frame transition (k-1 \rightarrow k)')
ylabel('Mean |frame_{k} - frame_{k-1}|')
title('Frame-to-frame motion intensity across video1.avi')

%% Step 3 - Comparing two background models
% (A) Temporal median - standard model for surveillance, but fails when
%     the object moves only slightly (most pixels then have the object
%     in more than half the frames, so the median IS the object).
% (B) First frame as reference - sharper, no ghost, treats subsequent
%     deviation as foreground.
bgMedian = uint8(median(double(frames), 4));
bgFirst  = frames(:,:,:,1);

figure
subplot(1,2,1), imshow(bgMedian), title('(a) Temporal median - contains ghost of van');
subplot(1,2,2), imshow(bgFirst),  title('(b) First frame - clean reference');

%% Step 4 - Foreground extraction in Lab colour space
% The grayscale difference missed the lower body of the van, because the
% silver paint and the asphalt have similar luminance even though they
% differ strongly in colour. The fix is to work in Lab space and use the
% combined difference across all three channels (L*, a*, b*), which
% picks up the chrominance contrast that grayscale loses.
threshold = 12;                  % Lab Euclidean distance threshold
seOpen    = strel('disk', 2);
seClose   = strel('disk', 15);

% Pre-compute Lab images of the two background models for re-use
bgMedianLab = rgb2lab(bgMedian);
bgFirstLab  = rgb2lab(bgFirst);

sampleIdx = peakIdx + 1;          % peak-motion frame for display
sampleLab = rgb2lab(frames(:,:,:,sampleIdx));

% Lab Euclidean distance per pixel
dA = sqrt(sum((sampleLab - bgMedianLab).^2, 3));
mA = dA > threshold;
mA = imfill(imclose(imopen(mA, seOpen), seClose), 'holes');
mA = bwareafilt(mA, 1);

dB = sqrt(sum((sampleLab - bgFirstLab).^2, 3));
mB = dB > threshold;
mB = imfill(imclose(imopen(mB, seOpen), seClose), 'holes');
mB = bwareafilt(mB, 1);

figure
subplot(2,2,1), imshow(frames(:,:,:,sampleIdx)), title(sprintf('Frame %d', sampleIdx));
subplot(2,2,2), imshow(mA), title('(A) Foreground - median bg (Lab, undersized)');
subplot(2,2,3), imshow(bgFirst), title('First-frame reference');
subplot(2,2,4), imshow(mB), title('(B) Foreground - first-frame ref (Lab, correct)');

%% Step 5 - Comparing two detection methods (both in Lab space)
% Method 1: Frame differencing (consecutive frames). Catches motion only
%   when it actually happens; fails when the van is stationary.
% Method 2: First-frame background subtraction (chosen method). Detects
%   the van whenever it is displaced from its starting position,
%   regardless of whether it is currently moving.

bboxDiff = nan(N, 4);
bboxBG   = nan(N, 4);

% Pre-compute Lab for every frame once
framesLab = zeros(vr.Height, vr.Width, 3, N);
for k = 1:N
    framesLab(:,:,:,k) = rgb2lab(frames(:,:,:,k));
end

for k = 1:N
    % --- Method 1: frame differencing (k vs k-1) ---
    if k > 1
        d1 = sqrt(sum((framesLab(:,:,:,k) - framesLab(:,:,:,k-1)).^2, 3));
        m1 = d1 > threshold;
        m1 = imclose(imopen(m1, seOpen), seClose);
        m1 = imfill(m1, 'holes');
        m1 = bwareafilt(m1, 1);
        s1 = regionprops(m1, 'Area', 'BoundingBox');
        if ~isempty(s1) && s1.Area > 1000
            bboxDiff(k,:) = s1.BoundingBox;
        end
    end

    % --- Method 2: first-frame background subtraction ---
    d2 = sqrt(sum((framesLab(:,:,:,k) - bgFirstLab).^2, 3));
    m2 = d2 > threshold;
    m2 = imclose(imopen(m2, seOpen), seClose);
    m2 = imfill(m2, 'holes');
    m2 = bwareafilt(m2, 1);
    s2 = regionprops(m2, 'Area', 'BoundingBox');
    if ~isempty(s2) && s2.Area > 1000
        bboxBG(k,:) = s2.BoundingBox;
    end
end

nDiff = sum(~isnan(bboxDiff(:,1)));
nBG   = sum(~isnan(bboxBG(:,1)));
fprintf('\nDetection rate comparison:\n');
fprintf('  Frame differencing       : %d / %d frames (%.1f%%)\n', ...
    nDiff, N, 100*nDiff/N);
fprintf('  First-frame bg subtract  : %d / %d frames (%.1f%%)\n', ...
    nBG, N, 100*nBG/N);
fprintf('  Note: frame 1 has no foreground by definition (= reference)\n');

% Visual comparison on a stationary frame and a moving frame
figure
quietFrame  = quietIdx + 1;
movingFrame = peakIdx + 1;
for plotPos = 1:2
    if plotPos == 1
        k = quietFrame; tagFr = 'stationary';
    else
        k = movingFrame; tagFr = 'moving';
    end
    d1 = sqrt(sum((framesLab(:,:,:,k) - framesLab(:,:,:,max(k-1,1))).^2, 3));
    m1 = imfill(imclose(imopen(d1>threshold, seOpen), seClose), 'holes');
    m1 = bwareafilt(m1, 1);
    d2 = sqrt(sum((framesLab(:,:,:,k) - bgFirstLab).^2, 3));
    m2 = imfill(imclose(imopen(d2>threshold, seOpen), seClose), 'holes');
    m2 = bwareafilt(m2, 1);
    subplot(2,3,(plotPos-1)*3 + 1), imshow(frames(:,:,:,k))
    title(sprintf('Frame %d (%s)', k, tagFr))
    subplot(2,3,(plotPos-1)*3 + 2), imshow(m1)
    title('Method 1: frame differencing')
    subplot(2,3,(plotPos-1)*3 + 3), imshow(m2)
    title('Method 2: first-frame bg (chosen)')
end

%% Step 6 - Centroid trajectory of the chosen method
centroids = nan(N, 2);
for k = 1:N
    if ~isnan(bboxBG(k,1))
        centroids(k,1) = bboxBG(k,1) + bboxBG(k,3)/2;   % x centre
        centroids(k,2) = bboxBG(k,2) + bboxBG(k,4)/2;   % y centre
    end
end

figure
imshow(bgFirst), hold on
plot(centroids(:,1), centroids(:,2), 'g-', 'LineWidth', 1.5)
plot(centroids(:,1), centroids(:,2), 'go', 'MarkerSize', 5, 'MarkerFaceColor', 'g')
plot(centroids(1,1), centroids(1,2), 'bs', 'MarkerSize', 12, 'LineWidth', 2)
plot(centroids(end,1), centroids(end,2), 'rs', 'MarkerSize', 12, 'LineWidth', 2)
legend({'trajectory','centroids','start','end'}, 'Location','northeast', 'TextColor','w')
title('Van centroid trajectory across video1.avi')
hold off

% Bounding-box area as a stability check
areas = bboxBG(:,3) .* bboxBG(:,4);
figure
plot(1:N, areas, 'LineWidth', 1.2), grid on
xlabel('Frame number'), ylabel('Bounding box area (pixels)')
title('Bounding box area across frames (stability check)')

fprintf('\nCentroid displacement (chosen method):\n');
validC = centroids(~isnan(centroids(:,1)), :);
if size(validC,1) >= 2
    dx = max(validC(:,1)) - min(validC(:,1));
    dy = max(validC(:,2)) - min(validC(:,2));
    fprintf('  range x = %.1f px, range y = %.1f px\n', dx, dy);
    fprintf('  mean bbox area = %.0f px, std = %.0f px\n', ...
        mean(areas, 'omitnan'), std(areas, 'omitnan'));
end

%% Step 7 - Annotated output video using the chosen method
vw = VideoWriter('video1_tracked.avi', 'Motion JPEG AVI');
vw.FrameRate = vr.FrameRate;
open(vw);
for k = 1:N
    f = frames(:,:,:,k);
    if ~isnan(bboxBG(k,1))
        f = insertShape(f, 'Rectangle', bboxBG(k,:), 'Color','green','LineWidth',3);
        f = insertText(f, [bboxBG(k,1) max(bboxBG(k,2)-25,0)], 'Moving vehicle', ...
            'FontSize',16, 'BoxColor','green', 'TextColor','black');
    end
    f = insertText(f, [10 10], sprintf('Frame %d / %d', k, N), ...
        'FontSize',14, 'BoxColor','black', 'TextColor','white');
    writeVideo(vw, f);
end
close(vw);
fprintf('\nAnnotated video written to video1_tracked.avi\n');