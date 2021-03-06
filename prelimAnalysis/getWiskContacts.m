function [wiskTouchSignal, wiskTouchPixels] = getWiskContacts(vid, showTracking, frameTimeStampsWisk, obsPixPositions)

% !!! need to document

% settings
bgThresh = 120;
wiskThresh = 50;
erosion = 3;
dilation = 6;
minObsArea = 2000;
borderThickness = 10;
wiskTouchThresh = .15; % just used for visualziation // if this is surpassed, pixels are colored white at points fo contact on raw image
obsPixLims = [300 500]; % only analyze frame where obsPixPosition in top view is within these limits

% initializations
wiskTouchSignal = nan(size(frameTimeStampsWisk));
wiskTouchPixels = cell(size(frameTimeStampsWisk));
erodeKern = strel('disk', erosion);
dilateKern = strel('disk', dilation);

% get inds of frames where obs is on
frameInds = find(obsPixPositions>=obsPixLims(1) & obsPixPositions<=obsPixLims(2));

if showTracking
    
    figure('position', [1921 1 750 450], 'menubar', 'none', 'color', 'black');
    frame = rgb2gray(read(vid,1));
    bgMask = frame > bgThresh;
    
    subaxis(2,3,1, 'margin', 0, 'padding', 0, 'margin', 0)
    imRaw = imshow(frame);
    
    subaxis(2,3,2)
    imMasked = imshow(bgMask);
    
    subaxis(2,3,3)
    imObs = imshow(bgMask);
    
    subaxis(2,3,4)
    imWisk = imshow(bgMask);
    
    subaxis(2,3,5)
    imBorder = imshow(bgMask);
    
    subaxis(2,3,6)
    imTouching = imshow(bgMask);
end



for i = frameInds
      
    % raw
    frame = 255 - rgb2gray(read(vid, i));

    
    % masked by bg
    bgMask = frame > bgThresh;
    bgMask = imerode(bgMask, erodeKern);
    bgMask = imdilate(bgMask, dilateKern);
    masked = frame .* uint8(~bgMask);

    
    % obs mask
    blobInfo = bwlabel(bgMask);
    firstCol = blobInfo(:,1);
    invalidLabels = unique(firstCol);
    %!!!
    for j = 1:max(blobInfo(:))
        if sum(blobInfo(:)==j) < minObsArea
            blobInfo(blobInfo==j) = 0;
        end
    end
    obsMask = ~ismember(blobInfo, invalidLabels);
    if sum(obsMask(:)) < minObsArea; obsMask(:) = 0; end
    
    
    % wisk threshed
    wisks = masked > wiskThresh;
    
    
    % get mask for obstacle border
    borderMask = zeros(size(frame));
    
    if any(obsMask(:))
        obsMaskShifted = zeros(size(frame));
%         obsMaskShifted(1:end-borderThickness, 1:end-borderThickness) = obsMask(borderThickness+1:end, borderThickness+1:end); shifted left and up
        obsMaskShifted(:, 1:end-borderThickness) = obsMask(:, borderThickness+1:end); % only shifted left
        borderMask = xor(obsMask, obsMaskShifted) & ~obsMask;
    end
        
    
    % get wisk touches, ie wisks masked by obstacle border
    wiskInBorder = wisks & borderMask;
    
    
    % store results
    wiskTouchSignal(i) = sum(wiskInBorder(:)) / sum(borderMask(:));
    wiskTouchPixels{i} = find(wiskInBorder);
    
    
    % update displays
    if showTracking
        
        if wiskTouchSignal(i) > wiskTouchThresh
            frame(wiskInBorder) = 255;
        end
        
        set(imRaw, 'CData', frame);
        set(imMasked, 'CData', masked);
        set(imObs, 'CData', obsMask);
        set(imWisk, 'CData', wisks);
        set(imBorder, 'CData', borderMask);
        set(imTouching, 'CData', wiskInBorder);
        
        if ~any(obsMask(:))
            pause(.001)
        else
            pause(.05);
        end
    end
end


