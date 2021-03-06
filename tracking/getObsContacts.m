function getObsContacts(session, vidDelay)

% settings
vidSizeScaling = 1.25;

% initializations
playing = true;
paused = false;
currentFrameInd = 1;
vid = VideoReader([getenv('OBSDATADIR') 'sessions\' session '\runTop.mp4']);
vidBot = VideoReader([getenv('OBSDATADIR') 'sessions\' session '\runBot.mp4']);
sampleFrame = rgb2gray(read(vid,currentFrameInd));
sampleFrameBot = rgb2gray(read(vidBot,currentFrameInd));
load([getenv('OBSDATADIR') 'sessions\' session '\runAnalyzed.mat'], 'frameTimeStamps', 'obsOnTimes', 'obsOffTimes');
w = waitbar(0, 'correction progress...', 'position', [1500 50 270 56.2500]);


% load previous data if it exists
if exist([getenv('OBSDATADIR') 'sessions\' session '\obsContacts.mat'], 'file')
    load([getenv('OBSDATADIR') 'sessions\' session '\obsContacts.mat'], 'isCorrected', 'touchingFront', 'touchingTop')
else
    isCorrected = zeros(1,length(frameTimeStamps));
    touchingFront = zeros(1,length(frameTimeStamps));
    touchingTop = zeros(1,length(frameTimeStamps));
end




% get bins for trials (bins where obs is on)
trialBins = zeros(1, length(frameTimeStamps));
for i = 1:length(obsOnTimes)
    trialBins(frameTimeStamps>=obsOnTimes(i) & frameTimeStamps<=obsOffTimes(i)) = 1;
end
frameInds = find(trialBins);
trialIdentities = cumsum([0 diff(trialBins)==1]);
trialIdentities(~trialBins) = 0;




% prepare figure
fig = figure('name', session, 'units', 'pixels', 'position', [600 400 vid.Width*vidSizeScaling (vid.Height+vidBot.Height)*vidSizeScaling],...
    'menubar', 'none', 'color', 'black', 'keypressfcn', @changeFrames);

colormap gray
preview = image([sampleFrame; sampleFrameBot], 'CDataMapping', 'scaled'); hold on;
rawAxis = gca;
set(rawAxis, 'visible', 'off', 'units', 'pixels',...
    'position', [0 0 vid.Width*vidSizeScaling (vid.Height+vidBot.Height)*vidSizeScaling]);






% main loop
while playing
    while paused; pause(.001); end
    updateFrame(1);
end
close(fig)
close(w)

% ---------
% FUNCTIONS
% ---------

% keypress controls
function changeFrames(~,~)
    
    key = double(get(fig, 'currentcharacter'));
    
    switch key
        
        % LEFT: move frame backward
        case 28
            pause(.001);
            paused = true;
            updateFrame(-1);
        
        % RIGHT: move frame forward
        case 29
            pause(.001);
            paused = true;
            updateFrame(1);
        
        % 'q': save frame as not contacting
        case 113
            paused = true;
            touchingFront(frameInds(currentFrameInd)) = 0;
            touchingTop(frameInds(currentFrameInd)) = 0;
            updateFrame(1);
            
        % 'w': save frame as contacting front
        case 119
            paused = true;
            touchingFront(frameInds(currentFrameInd)) = 1;
            touchingTop(frameInds(currentFrameInd)) = 0;
            updateFrame(1);
            
        % 'e': save frame as contacting top
        case 101
            paused = true;
            touchingFront(frameInds(currentFrameInd)) = 0;
            touchingTop(frameInds(currentFrameInd)) = 1;
            updateFrame(1);
        
        % 'f': select frame
        case 102
            pause(.001);
            paused = true;
            input = inputdlg('enter frame number');
            currentFrameInd = find(frameInds == str2double(input{1}));
            updateFrame(1);
            
        % 't': select trial
        case 116
            pause(.001);
            paused = true;
            input = inputdlg('enter frame number');
            trialInd = find(trialIdentities==str2double(input{1}),1,'first');
            currentFrameInd = find(frameInds == trialInd);
            updateFrame(1);
        
        % ESCAPE: close window
        case 27
            playing = false;
            paused = false;
            
        % 's': save current progress
        case 115
            save([getenv('OBSDATADIR') 'sessions\' session '\obsContacts.mat'], 'touchingFront', 'touchingTop', 'isCorrected')
            m = msgbox('saving!!!'); pause(.5); close(m)
            
        % 'c': go to latest corrected frame
        case 99
            pause(.001);
            paused = true;
            currentFrameInd = find(frameInds == find(isCorrected,1,'last'));
            msgbox('moved to latest corrected frame');
            updateFrame(0);
        
        % SPACEBAR: pause playback
        case 32
            paused = ~paused;
    end
end



% update frame preview
function updateFrame(frameStep)
    
    currentFrameInd = currentFrameInd + frameStep;
    if currentFrameInd > length(frameInds); currentFrameInd = length(frameInds);
    elseif currentFrameInd < 1; currentFrameInd = 1; end
    
    % record that this frame has been corrected (somebody looked at it and verified it was correct or corrected it manually)
    isCorrected(frameInds(currentFrameInd)) = true;
    
    % get frame and sub-frames
    frame = rgb2gray(read(vid, frameInds(currentFrameInd)));
    frameBot = rgb2gray(read(vidBot, frameInds(currentFrameInd)));
    frame = [frame; frameBot];
    
    % add frame number
    frame = insertText(frame, [size(frame,2) size(frame,1)], ...
        sprintf('trial %i, frame %i', trialIdentities(frameInds(currentFrameInd)), frameInds(currentFrameInd)),...
	    'BoxColor', 'black', 'AnchorPoint', 'RightBottom', 'TextColor', 'white');
    
    % change frame color if touching front or top
    if touchingFront(frameInds(currentFrameInd)); frame(:,:,3) = frame(:,:,3)*2; end
    if touchingTop(frameInds(currentFrameInd)); frame(:,:,2) = frame(:,:,2)*2; end
    
    % update figure
    set(preview, 'CData', frame);
    
    % pause to reflcet on the little things...
    pause(vidDelay);
    waitbar(currentFrameInd / length(frameInds))
end



    
    
end