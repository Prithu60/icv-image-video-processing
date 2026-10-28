%% ============================================================
%  SECTION 2.9 - video2.avi : night-time car approach footage
%  ============================================================

%% Step 1 - Reading and inspecting the video
clear; clc; close all;

vr = VideoReader('video2.avi');
N  = vr.NumFrames;
H  = vr.Height;
W  = vr.Width;

fprintf('--- video2.avi ---\n');
fprintf('Frame size   : %d x %d\n', H, W);
fprintf('Frame rate   : %.2f fps\n', vr.FrameRate);
fprintf('Duration     : %.2f s\n', vr.Duration);
fprintf('Total frames : %d\n', N);

frames = read(vr, [1 N]);

% Montage of four key frames
keyIdx   = round(linspace(1, N, 4));
keyCells = cell(1, 4);
for i = 1:4, keyCells{i} = frames(:,:,:,keyIdx(i)); end
figure, montage(keyCells, 'Size', [1 4])
title(sprintf('Four key frames from video2.avi (frames %s)', mat2str(keyIdx)))

meanBright = zeros(N,1);
for k = 1:N
    meanBright(k) = mean(mean(rgb2gray(frames(:,:,:,k))));
end
fprintf('\nBrightness across sequence:\n');
fprintf('  min=%.1f, max=%.1f, mean=%.1f (out of 255)\n', ...
    min(meanBright), max(meanBright), mean(meanBright));

%% Step 2 - Aggressive brightness enhancement for dim headlights
gamma_val = 0.4;
enhFrames = cell(N,1);
for k = 1:N
    hsv = rgb2hsv(frames(:,:,:,k));
    % CLAHE on value channel
    hsv(:,:,3) = adapthisteq(hsv(:,:,3), 'ClipLimit', 0.03, 'NumTiles', [8 8]);
    % Then gammaZ
    hsv(:,:,3) = imadjust(hsv(:,:,3), [], [], gamma_val);
    enhFrames{k} = hsv2rgb(hsv);
end

midK = round(N/2);
figure
subplot(1,2,1), imshow(frames(:,:,:,midK))
title(sprintf('Frame %d — original (dark)', midK))
subplot(1,2,2), imshow(enhFrames{midK})
title(sprintf('Frame %d — CLAHE + gamma', midK))
figure
plot(1:N, meanBright, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 3)
xlabel('Frame'), ylabel('Mean brightness (0-255)')
title('Per-frame mean brightness across video2.avi')
grid on

%% Step 3 - Build median background (FIXED: explicit sizing)
bgStack = zeros(H, W, N, 'double');
for k = 1:N
    gFrame = double(rgb2gray(frames(:,:,:,k)));
    bgStack(:,:,k) = gFrame;
end
medianBG = median(bgStack, 3);

fprintf('\nMedian background computed.\n');
fprintf('Background brightness: mean=%.1f\n', mean(medianBG(:)));

% Show background vs mid-frame difference
figure
subplot(1,3,1), imshow(uint8(medianBG)), title('Median background')
subplot(1,3,2), imshow(frames(:,:,:,midK)), title('Mid frame (original)')
gMidOrig = double(rgb2gray(frames(:,:,:,midK)));
diffMid = abs(gMidOrig - medianBG);
subplot(1,3,3), imshow(uint8(min(diffMid * 3, 255))), title('Difference x3 (motion regions)')

%% Step 4 - Detect car using background subtraction + headlight brightness (FIXED)
roiTop    = round(0.30 * H);
roiBottom = round(0.85 * H);
colL      = round(0.10 * W);
colR      = round(0.90 * W);

bboxRaw = nan(N, 4);
cxAll   = nan(N, 1);
cyAll   = nan(N, 1);

for k = 1:N
    % Enhanced grayscale (explicit double conversion)
    gEnh = double(rgb2gray(im2uint8(enhFrames{k})));
    
    % Original grayscale
    gOrig = double(rgb2gray(frames(:,:,:,k)));
    
    % Ensure same size
    if size(gEnh,1) ~= H || size(gEnh,2) ~= W || size(gOrig,1) ~= H || size(gOrig,2) ~= W
        gEnh = imresize(gEnh, [H W]);
        gOrig = imresize(gOrig, [H W]);
    end
    
    % Background difference
    diffMap = abs(gOrig - medianBG);
    
    % Adaptive thresholds from ROI only
    roiGEnh = gEnh(roiTop:roiBottom, colL:colR);
    roiDiff = diffMap(roiTop:roiBottom, colL:colR);
    
    brightThr = prctile(roiGEnh(:), 97);
    diffThr   = prctile(roiDiff(:), 85);
    
    % Combined mask: bright AND moving
    mask = (gEnh > brightThr) & (diffMap > diffThr);
    
    % Apply ROI
    mask(1:roiTop, :)     = false;
    mask(roiBottom:end,:) = false;
    mask(:, 1:colL)       = false;
    mask(:, colR:end)     = false;
    
    % Morphology
    mask = imclose(mask, strel('disk', 12));
    mask = imfill(mask, 'holes');
    mask = bwareafilt(mask, [50 25000]);
    
    s = regionprops(mask, 'Area', 'BoundingBox', 'Centroid');
    if ~isempty(s)
        [~, idx]     = max([s.Area]);
        bboxRaw(k,:) = s(idx).BoundingBox;
        cxAll(k)     = s(idx).Centroid(1);
        cyAll(k)     = s(idx).Centroid(2);
    end
end

% IQR-based outlier rejection
validY = cyAll(~isnan(cyAll));
if ~isempty(validY)
    Q1y = prctile(validY,25); Q3y = prctile(validY,75); IQRy = Q3y - Q1y;
    yLo = Q1y - 2.0*IQRy;    yHi = Q3y + 2.0*IQRy;
else
    yLo = 1; yHi = H;
end

validX = cxAll(~isnan(cxAll));
if ~isempty(validX)
    Q1x = prctile(validX,25); Q3x = prctile(validX,75); IQRx = Q3x - Q1x;
    xLo = Q1x - 2.0*IQRx;    xHi = Q3x + 2.0*IQRx;
else
    xLo = 1; xHi = W;
end

fprintf('Accepted centroid X range: [%.1f, %.1f]\n', xLo, xHi);
fprintf('Accepted centroid Y range: [%.1f, %.1f]\n', yLo, yHi);

bboxCar = bboxRaw;
for k = 1:N
    if ~isnan(cxAll(k))
        if cxAll(k) < xLo || cxAll(k) > xHi || ...
           cyAll(k) < yLo || cyAll(k) > yHi
            bboxCar(k,:) = nan;
        end
    end
end

nDet = sum(~isnan(bboxCar(:,1)));
nRej = sum(~isnan(bboxRaw(:,1))) - nDet;
fprintf('Car detection rate : %d / %d frames (%.1f%%)\n', nDet, N, 100*nDet/N);
fprintf('Outliers rejected  : %d frames\n', nRej);

%% Step 5 - Centroid trajectory + bbox growth analysis
centroids = nan(N,2);
bboxW     = nan(N,1);
bboxH     = nan(N,1);

for k = 1:N
    if ~isnan(bboxCar(k,1))
        centroids(k,1) = bboxCar(k,1) + bboxCar(k,3)/2;
        centroids(k,2) = bboxCar(k,2) + bboxCar(k,4)/2;
        bboxW(k)       = bboxCar(k,3);
        bboxH(k)       = bboxCar(k,4);
    end
end

firstDet = find(~isnan(centroids(:,1)), 1, 'first');
lastDet  = find(~isnan(centroids(:,1)), 1, 'last');

% Trajectory plot
figure
imshow(enhFrames{round(N/2)}), hold on
validMask = ~isnan(centroids(:,1));
if sum(validMask) > 0
    plot(centroids(validMask,1), centroids(validMask,2), 'g-',  'LineWidth', 2)
    plot(centroids(validMask,1), centroids(validMask,2), 'go',  'MarkerSize', 5, 'MarkerFaceColor','g')
    legendEntries = {'trajectory','centroids'};
    if ~isempty(firstDet)
        plot(centroids(firstDet,1), centroids(firstDet,2), 'bs', 'MarkerSize',12, 'LineWidth',2)
        legendEntries{end+1} = 'start';
    end
    if ~isempty(lastDet)
        plot(centroids(lastDet,1), centroids(lastDet,2), 'rs', 'MarkerSize',12, 'LineWidth',2)
        legendEntries{end+1} = 'end';
    end
    legend(legendEntries, 'Location','northeast', 'TextColor','w')
end
title('Car centroid trajectory across video2.avi')
xlim([1 W]); ylim([1 H]);
hold off

validC = centroids(~isnan(centroids(:,1)),:);
if ~isempty(validC)
    fprintf('Centroid displacement: x range=%.1f px, y range=%.1f px\n', ...
        max(validC(:,1))-min(validC(:,1)), max(validC(:,2))-min(validC(:,2)));
end

% Bbox growth plot
validIdx = find(~isnan(bboxW));
if ~isempty(validIdx)
    figure
    subplot(2,1,1)
    pw = polyfit(validIdx, bboxW(validIdx)', 1);
    plot(validIdx, bboxW(validIdx), 'b-o', 'LineWidth',1.5, 'MarkerSize',3), hold on
    plot(validIdx, polyval(pw, validIdx), 'b--', 'LineWidth',2), hold off
    xlabel('Frame'), ylabel('Width (px)')
    title(sprintf('Bounding box width — slope: %.2f px/frame', pw(1)))
    legend('width','linear trend'), grid on
    
    subplot(2,1,2)
    ph = polyfit(validIdx, bboxH(validIdx)', 1);
    plot(validIdx, bboxH(validIdx), 'r-o', 'LineWidth',1.5, 'MarkerSize',3), hold on
    plot(validIdx, polyval(ph, validIdx), 'r--', 'LineWidth',2), hold off
    xlabel('Frame'), ylabel('Height (px)')
    title(sprintf('Bounding box height — slope: %.2f px/frame', ph(1)))
    legend('height','linear trend'), grid on
end

%% Step 6 - Annotated output video
vw = VideoWriter('video2_tracked.avi', 'Motion JPEG AVI');
vw.FrameRate = vr.FrameRate;
open(vw);
for k = 1:N
    f = im2uint8(enhFrames{k});
    if ~isnan(bboxCar(k,1))
        f = insertShape(f, 'Rectangle', bboxCar(k,:), ...
            'Color','green', 'LineWidth',3);
        f = insertText(f, [bboxCar(k,1) max(bboxCar(k,2)-20,1)], ...
            sprintf('Car [%.0fx%.0f]', bboxCar(k,3), bboxCar(k,4)), ...
            'FontSize',10, 'BoxColor','green', 'TextColor','black');
    end
    f = insertText(f, [5 5], sprintf('Frame %d/%d', k, N), ...
        'FontSize',10, 'BoxColor','black', 'TextColor','white');
    writeVideo(vw, f);
end
close(vw);
fprintf('Annotated video written to video2_tracked.avi\n');