

% load files
vid = VideoReader('C:\Users\rick\Google Drive\columbia\obstacleData\sessions\wiskTest4\runWisk.mp4');
showTracking = false;
load('C:\Users\rick\Google Drive\columbia\obstacleData\sessions\wiskTest4\runAnalyzed.mat',...
     'obsOnTimes', 'obsOffTimes', 'frameTimeStampsWisk')

% track wisk contacts
[isWiskTouching, contactPixels] = getWiskContacts(vid, showTracking, frameTimeStampsWisk, obsOnTimes, obsOffTimes);
