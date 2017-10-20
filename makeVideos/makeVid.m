function makeVid(session)

% user settings
dataDir = 'C:\Users\LindseyBuckingham\Google Drive\columbia\obstacleData\sessions\';
obsPosRange = [.31 .445];
maxTrialTime = 1; % trials exceeding maxTrialTime will be trimmed to this duration (s)
playbackSpeed = .1;



% initializations
vidTop = VideoReader([dataDir session '\runTop.mp4']);
vidBot = VideoReader([dataDir session '\runBot.mp4']);
vidWeb = VideoReader([dataDir session '\webCam.avi']);

vidWriter = VideoWriter([dataDir session '\edited.mp4'], 'MPEG-4');
set(vidWriter, 'FrameRate', round(vidTop.FrameRate * playbackSpeed))
open(vidWriter)

load([dataDir session '\run.mat'], 'touch');
load([dataDir session '\runAnalyzed.mat'], 'obsPositions', 'obsTimes',...
                                           'wheelPositions', 'wheelTimes',...
                                           'obsOnTimes', 'obsOffTimes');
load([dataDir session '\frameTimeStamps.mat'], 'timeStamps')
load([dataDir session '\webCamTimeStamps.mat'], 'webCamTimeStamps')
maxFrames = vidTop.FrameRate * maxTrialTime;

obsPositions = fixObsPositions(obsPositions, obsTimes, obsOnTimes); % correct for drift in obstacle position readings



% edit video
w = waitbar(0, 'editing video...');

for i = 1:length(obsOnTimes)
    
    % find trial indices
    startInd = find(obsTimes>obsOnTimes(i)  & obsPositions>=obsPosRange(1), 1, 'first');
    endInd   = find(obsTimes<obsOffTimes(i) & obsPositions<=obsPosRange(2), 1, 'last');
    
    % get frame indices
    frameInds = find(timeStamps>obsTimes(startInd) & timeStamps<obsTimes(endInd));
    if length(frameInds) > maxFrames
        frameInds = frameInds(1:maxFrames);
    end
    
    if isempty(frameInds) % if a block has NaN timestamps (which will happen when unresolved), startInd and endInd will be the same, and frameInds will be empty
        fprintf('skipping trial %i\n', i)
    else
        
%         webIndLast = 0;
        
        for f = frameInds'
            
            webInd = find(webCamTimeStamps>(timeStamps(f)+4), 1, 'first');

            % put together top and bot frames
            frameTop = rgb2gray(read(vidTop, f));
            frameBot = rgb2gray(read(vidBot, f));
%             
%             if webInd>webIndLast
%                 frameWeb = rgb2gray(read(vidWeb, webInd));
%                 frameWeb = imresize(frameWeb, (size(frameTop,2)/size(frameWeb,2)));
%                 webIndLast = webInd;
%             end
            
            frame = imadjust([frameTop; frameBot]);
%             frame = [frame; frameWeb];

            % add trial info text
            frame = insertText(frame, [0 0], ['trial: ' num2str(i)]);

            % write frame to video
            writeVideo(vidWriter, frame);
        end

        % add blank frame between trials
        writeVideo(vidWriter, zeros(size(frame)))
    end
    
    % update waitbar
    waitbar(i/length(obsOnTimes))
    
end



close(w)
close(vidWriter)


