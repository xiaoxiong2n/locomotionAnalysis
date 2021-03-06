% crop top and bot file from startTime to endTime AND block obstacle in bottom view
% the method for fading out the obs is kind of shitty right now -- it only works when the obstacle is fully in the frame

% user settings
startTime = 3*60 + 22;
endTime = 3*60 + 34;
fs = 250;
folder = 'C:\Users\rick\Google Drive\columbia\obstacleData\svm\testVideo\';
obsWidth = 10; % make even
obsFade = 5;
playbackSpeed = .1;
maskDimming = .3;

% initializations
obsMask = [linspace(1,maskDimming,obsFade) ones(1,obsWidth).*maskDimming fliplr(linspace(1,maskDimming,obsFade))];
obsMask = ones(size(obsMask)) * maskDimming;
frames = (startTime*fs)+1 : endTime*fs;

vidTop = VideoReader([folder 'runTopRaw.mp4']);
vidBot = VideoReader([folder 'runBotRaw.mp4']);

vidWriteTop = VideoWriter([folder 'runTop.mp4'], 'MPEG-4');
vidWriteBot = VideoWriter([folder 'runBot.mp4'], 'MPEG-4');
open(vidWriteTop);
open(vidWriteBot);

load([folder 'runAnalyzed.mat'], 'obsPixPositions');


% write selected frames to video

for i = 1:length(frames)
   
    % top frame
    frameTop = read(vidTop, frames(i));
    writeVideo(vidWriteTop, frameTop);
    
    % bot frame
    frameBot = read(vidBot, frames(i));
    
    if ~isnan(obsPixPositions(frames(i)))
        startPix = round(obsPixPositions(frames(i))-.5*length(obsMask));
        obsRange = [startPix, startPix+length(obsMask)-1];
        obsRange(obsRange>vidBot.Width) = vidBot.Width;
        obsRange(obsRange<1) = 1;
        if diff(obsRange)==length(obsMask)-1
%             disp('ya')
            frameBot(:,obsRange(1):obsRange(2),:) = double(frameBot(:,obsRange(1):obsRange(2),:)) .* repmat(obsMask,size(frameBot,1),1,3);
        end
        
    end
    writeVideo(vidWriteBot, uint8(frameBot));
    
    % report progress
    disp(i/length(frames));
    
end

close(vidWriteTop);
close(vidWriteBot);


%% simple timming of video time AND inversion of black and white



% user settings
startTime = 3.5;
endTime = startTime + 3;
invertColors = true;
yMin = 60; % anything above yMin will be set to zero
fs = 250;
folder = 'C:\Users\rick\Desktop\wiskTest\';
file = 'wisk';
playbackSpeed = .1;
dilation = 20;

% initializations
frames = (startTime*fs)+1 : endTime*fs;
vid = VideoReader([folder file '.mp4']);
dilateKernel = strel('diamond', dilation);
bg = getBgImage(vid, 500, false);
bg = imdilate(bg, dilateKernel);
vidWrite = VideoWriter([folder file 'Short.avi'], 'Uncompressed AVI');
open(vidWrite);



% write selected frames to video

for i = 1:length(frames)
   
    % get frame
    frame = rgb2gray(read(vid, frames(i)));
    frame(1:yMin, :) = 0;
    frame = frame - bg - 1;
    
    % invert colors
    if invertColors
        frame = 255 - frame; % invert
    end
    
    % write video and report progress
    writeVideo(vidWrite, frame);
    disp(i/length(frames));
    
end

close(vidWrite);



