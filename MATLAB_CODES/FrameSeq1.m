%% ============================================================
%  SECTION 2.7 - FrameSeq1 : night-time sequence of a moving Vespa
%  Per-frame artefacts : severe underexposure + sensor noise
%  Sequence-level task : detect and track the moving subject
%  ============================================================

%% Step 1 - Reading and inspecting the image sequence
clear; clc; close all;

seqDir = 'FrameSeq1';   % folder containing vespa001.jpg ... vespa240.jpg
files  = dir(fullfile(seqDir, 'vespa*.jpg'));
N      = numel(files);

firstFrame = imread(fullfile(seqDir, files(1).name));
fprintf('--- FrameSeq1 ---\n');
fprintf('Folder           : %s\n', seqDir);
fprintf('Number of frames : %d\n', N);
fprintf('Frame size       : %d x %d, %d channels (%s)\n', ...
    size(firstFrame,1), size(firstFrame,2), size(firstFrame,3), class(firstFrame));

% Six representative frames as a montage
keyIdx   = round(linspace(1, N, 6));
keyCells = cell(1, numel(keyIdx));
for k = 1:numel(keyIdx)
    keyCells{k} = imread(fullfile(seqDir, files(keyIdx(k)).name));
end
figure, montage(keyCells, 'Size', [2 3])
title(sprintf('Six representative frames from FrameSeq1 (frames %s)', mat2str(keyIdx)));

%% Step 2 - Per-frame brightness and contrast analysis
meanBright = zeros(N,1);
stdBright  = zeros(N,1);
for k = 1:N
    g = rgb2gray(imread(fullfile(seqDir, files(k).name)));
    meanBright(k) = mean(g(:));
    stdBright(k)  = std(double(g(:)));
end
fprintf('\nMean brightness across all %d frames:\n', N);
fprintf('  min=%.1f, max=%.1f, mean=%.1f  (out of 255)\n', ...
    min(meanBright), max(meanBright), mean(meanBright));
fprintf('Mean per-frame standard deviation = %.1f\n', mean(stdBright));

figure
subplot(2,1,1), plot(meanBright, 'LineWidth',1.2), grid on
xlabel('Frame number'), ylabel('Mean brightness (0-255)')
title('Per-frame mean brightness across the sequence'), ylim([0 60])
subplot(2,1,2), plot(stdBright, 'LineWidth',1.2), grid on
xlabel('Frame number'), ylabel('Standard deviation')
title('Per-frame standard deviation (contrast)')

%% Step 3 - Per-frame enhancement (gamma + noise reduction)
% Gamma 0.4 brightens shadows aggressively; this also amplifies the
% low-light sensor noise, so a mild Wiener filter is applied per
% channel afterwards (same family of filter selected for Image3).
gammaVal = 0.4;
enhFrames = cell(N,1);
for k = 1:N
    f = imadjust(imread(fullfile(seqDir, files(k).name)), [], [], gammaVal);
    for c = 1:3
        f(:,:,c) = wiener2(f(:,:,c), [3 3]);
    end
    enhFrames{k} = f;
end

sampleIdx = 120;
figure
subplot(1,2,1), imshow(imread(fullfile(seqDir, files(sampleIdx).name)))
title(sprintf('Original frame %d  (mean = %.1f)', sampleIdx, meanBright(sampleIdx)));
gEnh = rgb2gray(enhFrames{sampleIdx});
subplot(1,2,2), imshow(enhFrames{sampleIdx})
title(sprintf('Enhanced frame  (mean = %.1f)', mean(gEnh(:))));

%% Step 4 - Detecting the brake light (raw frames, within spatial ROI)
% Inspection of the six representative frames in Step 1 showed the brake
% light is always within the LOWER-CENTRAL region of the frame. Restricting
% detection to this region rejects false positives from street signs and
% lamps in the upper periphery.
[H, W, ~] = size(firstFrame);
roiMask = false(H, W);
roiMask(round(H/3):H, round(W*0.15):round(W*0.85)) = true;

seClose   = strel('disk', 2);
centroids = nan(N, 2);

for k = 1:N
    f = imread(fullfile(seqDir, files(k).name));
    R = f(:,:,1); G = f(:,:,2); B = f(:,:,3);

    mask = (R > 120) & (G < 80) & (B < 80) & roiMask;
    mask = imclose(mask, seClose);

    stats = regionprops(mask, 'Area', 'Centroid');
    if ~isempty(stats)
        [~, idx] = max([stats.Area]);
        centroids(k,:) = stats(idx).Centroid;
    end
end

nFound = sum(~isnan(centroids(:,1)));
fprintf('\nBrake light detected in %d / %d frames (%.1f%%)\n', ...
    nFound, N, 100*nFound/N);

% Visualise the colour mask on the sample frame
fSample = imread(fullfile(seqDir, files(sampleIdx).name));
R = fSample(:,:,1); G = fSample(:,:,2); B = fSample(:,:,3);
maskSample = imclose((R>120)&(G<80)&(B<80)&roiMask, seClose);
figure
subplot(1,2,1), imshow(fSample),    title(sprintf('Raw frame %d', sampleIdx));
subplot(1,2,2), imshow(maskSample), title('Brake-light colour mask (within ROI)');

%% Step 5 - Trajectory smoothing, plot, and annotated output video
% Even with the spatial ROI, a small number of single-frame false positives
% remain. A 1-D moving median across the centroid time series smooths these
% out without distorting the underlying motion.
cxSmooth = movmedian(centroids(:,1), 7, 'omitnan');
cySmooth = movmedian(centroids(:,2), 7, 'omitnan');

figure
subplot(1,2,1), imshow(enhFrames{1}), hold on
plot(centroids(:,1), centroids(:,2), 'y-', 'LineWidth', 1)
title('(a) Raw centroids - spikes visible'), hold off
subplot(1,2,2), imshow(enhFrames{1}), hold on
plot(cxSmooth, cySmooth, 'y-', 'LineWidth', 1.5)
plot(cxSmooth(1),   cySmooth(1),   'go', 'MarkerSize', 10, 'LineWidth', 2)
plot(cxSmooth(end), cySmooth(end), 'rs', 'MarkerSize', 10, 'LineWidth', 2)
title('(b) After moving-median smoothing (width 7)')
legend('Trajectory','Start','End','Location','best'), hold off

vw = VideoWriter('FrameSeq1_tracked.avi','Motion JPEG AVI');
vw.FrameRate = 25;
open(vw);
for k = 1:N
    f = enhFrames{k};
    if ~isnan(cxSmooth(k))
        f = insertShape(f, 'Circle', [cxSmooth(k) cySmooth(k) 12], ...
            'Color','green','LineWidth',2);
    end
    f = insertText(f, [10 10], sprintf('Frame %d / %d', k, N), ...
        'FontSize',14,'BoxColor','black','TextColor','white');
    writeVideo(vw, f);
end
close(vw);
fprintf('\nTracked sequence written to FrameSeq1_tracked.avi\n');