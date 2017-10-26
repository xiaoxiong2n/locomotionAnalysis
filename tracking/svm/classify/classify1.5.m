
% USER SETTINGS

% settings
vidFile = 'C:\Users\rick\Google Drive\columbia\obstacleData\sessions\171025_002\runBot.mp4';
classifier = 'C:\Users\rick\Google Drive\columbia\obstacleData\svm\classifiers\classifier_pawBot_26-Oct-2017';
startFrame = 6000;

% load sample frame and sample sub-frame
vid = VideoReader(vidFile);
sampleFrame = read(vid,startFrame-1);
frmHgt = size(sampleFrame,1);
frmWid = size(sampleFrame,2);

% load classifier
load(classifier)

%% prepare figure
close all;
figure('units', 'normalized', 'position', [0 0 1 1]);
rawPlot = subaxis(2,1,1, 'spacing', 0.01, 'margin', .01);
predictPlot = subaxis(2,1,2);
%
for i = startFrame:vid.numberofframes
    
    % get frame and sub-frames
    frame = rgb2gray(read(vid,i));
    
    % filter with svm
    tic
    frameFiltered = conv2(frame, reshape(model.w, 36, 36)', 'same') - model.rho;
    toc
    
    % update figure
    imshow(getFeatures(frame), 'parent', rawPlot);
    imshow(frameFiltered, 'parent', predictPlot);

    % pause to reflcet on the little things...
    pause(.001);
end





