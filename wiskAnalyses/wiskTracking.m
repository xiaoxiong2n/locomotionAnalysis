
% temp
session = '171231_002';
h5File = 'C:\Users\rick\Desktop\test2\whiskers.h5';
wiskData = h5read(h5File, '/summary');

% settings
bgThresh = 180;
follicleTipYLine = 150;
minWiskLength = 100;
tridentMaxX = 90;
bgErosion = 10;
minScore = 0;
angleLims = [0 135];

% initializations
% file = ['C:\Users\rick\Google Drive\columbia\obstacleData\sessions\' session '\runWiskEdited.'];
file = 'C:\Users\rick\Desktop\test\runWisk.';
wisks = LoadWhiskers([file 'whiskers']);
% wisks = rmfield(wisks, {'id', 'thick', 'scores'}); % remove fields i don't need to free up memory
measures = LoadMeasurements([file 'measurements']);
measures = rmfield(measures, {'wid', 'label', 'face_x', 'face_y', 'curvature'}); % remove fields i don't need to free up memory
vid = VideoReader([file 'mp4']);
frame = read(vid,1);
frameNum = vid.NumberOfFrames;

%
bg = getBgImage(vid, 1000, 0, 0, false);
bgMask = bg < bgThresh;
bgMask = imerode(bgMask, strel('disk', bgErosion));

%%
close all; figure();
im = imshow(frame); hold on
line([1 size(frame,2)], [follicleTipYLine follicleTipYLine])
set(gcf, 'position', [2163 2 1076 994])


% get wisk tip and base locations
x = {measures.follicle_x, measures.tip_x}; x = cat(1, x{:});
y = {measures.follicle_y, measures.tip_y}; y = cat(1, y{:});

% find whiskers completely outside of bgMask
x = round(x); x(x<1) = 1; x(x>size(frame,2)) = size(frame,2);
y = round(y); y(y<1) = 1; y(y>size(frame,2)) = size(frame,2);
maskInds = sub2ind(size(frame), y, x);
isOutsideMask = ~bgMask(maskInds)';
isOutsideMask = isOutsideMask(1:length(measures)) & isOutsideMask(length(measures)+1:end); % find wiskers where either tip or base are ouside of mask

% find long enough wisks
isLongEnough = [measures.length] > minWiskLength;

% find trident
isTrident = (x(1:length(measures))' < tridentMaxX) & (x(length(measures)+1:end)' < tridentMaxX);

% find wiskers wether follicle is above follicleTipYLine and tip is below follicleTipYLine
isCrossingYLine = (y(length(measures)+1:end)' > follicleTipYLine) & (y(1:length(measures))' < follicleTipYLine);

% find valid scores
isValidScore = [measures.score] > minScore;

% find valid angles
isValidAngle = ([measures.angle] > angleLims(1)) & ([measures.angle] < angleLims(2));

% find valid wiskers
isValid = isOutsideMask & isLongEnough & ~isTrident & isCrossingYLine & isValidScore & isValidAngle;
% isValid = isOutsideMask & isLongEnough & ~isTrident & isValidAngle;

meanAngles = nan(1, frameNum);
%
for i = 1:frameNum
    
    disp(i/frameNum)
    
    % get frame and frameBins
%     frame = read(vid,i);
%     frame = frame .* repmat(uint8(~bgMask), 1, 1, 3);
    bins = ([wisks.time] == i-1) & isValid;
%     bins = ([wisks.time] == i-1);
    
    % get two longest wisks
    [~, maxInds] = sort([measures.length] .* bins);
    bins = maxInds(end);
    meanAngles(i) = mean([measures(bins).angle]);
    
    % get wisk data
    x = {wisks(bins).x}; x = cat(1, x{:});
    y = {wisks(bins).y}; y = cat(1, y{:});
    
    % make x and y acceptable frame indices
    x = round(x); x(x<1) = 1; x(x>size(frame,2)) = size(frame,2);
    y = round(y); y(y<1) = 1; y(y>size(frame,2)) = size(frame,2);
    
    % add tracked wisks to frame
    inds = sub2ind(size(frame), y, x);
    frame(inds) = 255;
    
    % update preview
%     set(im, 'CData', frame);
%     pause(.001)
    
end