function showLocations(vid, frameInds, potentialLocations, locations, trialIdentities, ...
    showPotentialLocations, vidDelay, anchorPts, cmap, lineLocations)
    
% settings
circSize = 150;
vidSizeScaling = 1.25;
% lineMaskWid = 15;


% initializations
currentFrame = 1;
sampleFrame = rgb2gray(read(vid,currentFrame));
if any(cellfun(@(x) strcmp(x, 'y'), fieldnames(potentialLocations))); dim2 = 'y'; else; dim2 = 'z'; end % figure out whether second dimension is y or z


% prepare figure
close all;
fig = figure('units', 'pixels', 'position', [600 400 vid.Width*vidSizeScaling vid.Height*vidSizeScaling],...
    'menubar', 'none', 'color', 'black', 'keypressfcn', @changeFrames);
colormap gray


rawIm = image(sampleFrame, 'CDataMapping', 'scaled'); hold on;
rawAxis = gca;
set(rawAxis, 'visible', 'off', 'units', 'pixels',...
    'position', [0 0 vid.Width*vidSizeScaling vid.Height*vidSizeScaling]);
circSizes = circSize * ones(1,length(anchorPts));
% circSizes = linspace(100,500,4);

lines = cell(4,1);
if exist('lineLocations', 'var')
    for i = 1:4
        lines{i} = line([0 0], [vid.Height vid.Height-50], 'color', cmap(i,:));
    end
end
    

if showPotentialLocations
    scatterPotentialLocations = scatter(rawAxis, 0, 0, 50, 'white', 'filled', 'linewidth', 2);
end
scatterLocations = scatter(rawAxis, zeros(1,length(anchorPts)), zeros(1,length(anchorPts)),...
    circSizes, cmap, 'linewidth', 3); hold on
scatter(rawAxis, [anchorPts{1}(1) anchorPts{2}(1) anchorPts{3}(1) anchorPts{4}(1)] .* (vid.Width-1) + 1,...
                 [anchorPts{1}(2) anchorPts{2}(2) anchorPts{3}(2) anchorPts{4}(2)] .* (vid.Height-1) + 1,...
                 circSizes, cmap, 'filled', 'linewidth', 3);     % show anchor points

playing = true;
paused = false;


% main loop
while playing
    while paused; pause(.001); end
    updateFrame(1);
end
close(fig)



% keypress controls
function changeFrames(~,~)
    
    key = double(get(fig, 'currentcharacter'));
    
    if ~isempty(key) && isnumeric(key)
        
        if key==28                      % LEFT: move frame backward
            pause(.001);
            paused = true;
            updateFrame(-1);
        
        elseif key==29                  % RIGHT: move frame forward
            pause(.001);
            paused = true;
            updateFrame(1);
        
        elseif key==102                  % 'f': select frame
            pause(.001);
            paused = true;
            input = inputdlg('enter frame number');
            currentFrame = find(frameInds == str2double(input{1}));
            updateFrame(1);
            
        % 't': select trial
        elseif key==116
            pause(.001);
            paused = true;
            input = inputdlg('enter frame number');
            trialInd = find(trialIdentities==str2double(input{1}),1,'first');
            currentFrame = find(frameInds == trialInd);
            updateFrame(1);
        
        elseif key==27                  % ESCAPE: close window
            playing = false;
            paused = false;
        
        else                            % OTHERWISE: close window
            paused = ~paused;
        end
    end
end



% update frame preview
function updateFrame(frameStep)
    
    currentFrame = currentFrame + frameStep;
    if currentFrame > length(frameInds); currentFrame = 1;
    elseif currentFrame < 1; currentFrame = length(frameInds); end
    
    % get frame and sub-frames
    frame = rgb2gray(read(vid, frameInds(currentFrame)));
    frame = imadjust(uint8(frame), [.05 1], [0 1]);
    
    
    % add vertical lines
    if exist('lineLocations', 'var')
        inds = lineLocations(frameInds(currentFrame),1,:);
        for j = 1:4
            set(lines{j}, 'XData', [inds(j) inds(j)])
        end
%         inds = round(inds(~isnan(inds)));
%         frame(:, inds) = 255;
    end
    
    
    % add frame number
    frame = insertText(frame, [size(frame,2) size(frame,1)], ...
        sprintf('trial %i, frame %i', trialIdentities(frameInds(currentFrame)), frameInds(currentFrame)),...
        'BoxColor', 'black', 'AnchorPoint', 'RightBottom', 'TextColor', 'white');
    
    % update figure
    set(rawIm, 'CData', frame);

    try
    set(scatterLocations, 'XData', locations(frameInds(currentFrame),1,:), ...
        'YData', locations((frameInds(currentFrame)),2,:), 'visible', 'on');
    catch; keyboard; end

    if showPotentialLocations
        set(scatterPotentialLocations, 'XData', potentialLocations(frameInds(currentFrame)).x, 'YData', potentialLocations(frameInds(currentFrame)).(dim2));
    end
    
    % pause to reflcet on the little things...
    pause(vidDelay);
end


end