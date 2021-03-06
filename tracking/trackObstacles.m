function [obsPixPositions, mappings] = trackObstacles(vid, obsOnTimes, obsOffTimes, frameTimeStamps, obsPositions, obsTimes,...
                                          xLims, yLims, pixThreshFactor, obsMinThickness, invertColors, showTracking)

% !!! need to document



% initializations
frame = rgb2gray(read(vid,1));
if invertColors; frame = 255-frame; end
pixThresh = pixThreshFactor * mean(frame(:));
totalFrames = vid.NumberOfFrames;
if mod(obsMinThickness,2)==1; obsMinThickness = obsMinThickness-1; end % ensure obsMinThickness is even, which ensures medFiltSize is odd // this way the filtered version doesn't shift by one pixel relative to the unfiltered version
medFiltSize = obsMinThickness*2+1;

% prepare figure if showTracking enabled
if showTracking
    
    fig = figure('position', [1923 35 vid.Width vid.Height*2], 'menubar', 'none', 'color', 'black');
    
    axRaw = subplot(2,1,1, 'units', 'pixels');
    imRaw = imshow(frame);
    
    axSum = subplot(2,1,2, 'units', 'pixels');
    imSum = imshow(frame);
    
    set(axRaw, 'position', [1 size(frame,1)+1 size(frame,2) size(frame,1)]);
    set(axSum, 'position', [1 1 size(frame,2) size(frame,1)]);
end


% iternate through all obstacle on epochs
obsPixPositions = nan(1, totalFrames);
mappings = nan(length(obsOnTimes), 2); % stores linear mappings from obsPositions (meters) to obsPixPositions(pixels)


for i = 1:length(obsOnTimes)

    % get frame indices for current obstacle epoch
    frameInds = find(frameTimeStamps>=obsOnTimes(i) & frameTimeStamps<=obsOffTimes(i));
    trialObsPixPositions = nan(length(frameInds), 1);
    
    % iterate through all frames within epoch
    for j = 1:length(frameInds)
        
        % get frame
        frame = rgb2gray(read(vid, frameInds(j)));
        if invertColors; frame = 255-frame; end
        
        % sum across columns and normalize
        frameMasked = frame;
        frameMasked([1:yLims(1), yLims(2):end], :) = 0;
        frameMasked(:, [1:xLims(1), xLims(2):end]) = 0;
        colSums = sum(frameMasked,1) / diff(yLims);
        
        % threshold and median filter to remove thin threshold crossings with few adjacent columns
        colThreshed = colSums > pixThresh;
        colThreshed = medfilt1(double(colThreshed), medFiltSize);
        
        if any(colThreshed)
            if ((find(colThreshed,1,'first')-xLims(1)) < obsMinThickness) ||...
               ((xLims(2)-find(colThreshed,1,'last')) < obsMinThickness)
                colThreshed(:) = 0;
            end
        end
        
        trialObsPixPositions(j) = mean(find(colThreshed));
        
        % update figure if showTracking enabled
        if showTracking
            
            threshFrame = frame .* uint8(repmat(colThreshed, size(frame,1), 1));
            colFrame = repmat(colSums, size(frame,1), 1);
            
            set(imRaw, 'CData', frame .* uint8(~threshFrame));
            set(imSum, 'CData', colFrame);
            
            pause(.001)
            if any(colThreshed); pause(.05); end
        end
    end
    
    
    % find mapping from obsPositions (from rotary encoder) to obsPixPositions for trial
    trialObsPositions = interp1(obsTimes, obsPositions, frameTimeStamps(frameInds)); % get position of obstacle for all frames
    validInds = ~isnan(trialObsPixPositions); % !!! why would this ever be nan?
    if any(validInds)
        mapping = polyfit(trialObsPositions(validInds), trialObsPixPositions(validInds), 1);
    else
        mapping = [nan nan];
        fprintf('  failed to track obstacle in trial: %i\n', i);
    end
    mappings(i,:) = mapping;
    
    % recreate obsPixPositions for trial by mapping from obsPositions to obsPixPositions
    % (this effectively smooths the obstacle position, and more importantly ensures that the obstacles is tracked even at the very edges of the frame)
    trialObsPixPositionsRemapped = trialObsPositions*mapping(1) + mapping(2);
    obsPixPositions(frameInds) = trialObsPixPositionsRemapped;
end

if showTracking; close(fig); end



