% function makePlotVid

% get trial
load([getenv('OBSDATADIR') 'kinematicData.mat'], 'data');
data = data([data.oneSwingOneStance] & ~[data.isFlipped]);
trialInd = randperm(length(data), 1);
session = data(trialInd).session;
trials = data(trialInd).trial;
clear data trialInd

%%

% settings 
contrastLims = [.1 .9];
paws = [2 3];
circSize = 100;

% initializations
% colors = hsv(4); colors = colors(paws,:); % use these if you want a different color per paw
colors = [.25 1 1; .25 1 .25]; % use these if you want different colors per step type (lengthened or shortened)
vid = VideoReader([getenv('OBSDATADIR') 'sessions\' session '\runBot.mp4']);
load([getenv('OBSDATADIR') 'sessions\' session '\tracking\stepSegmentation.mat'], 'modifiedStepIdentities')
load([getenv('OBSDATADIR') 'sessions\' session '\tracking\locationsBotCorrected.mat'], 'locations')
load([getenv('OBSDATADIR') 'sessions\' session '\runAnalyzed.mat'], ...
    'obsOnTimes', 'obsOffTimes', 'frameTimeStamps', 'obsPixPositions')
locations = locations.locationsCorrected;
posRange = round(range(obsPixPositions));
dims = [vid.Height posRange+vid.Width];
obsPos = posRange;


%% prepare figure and objects
close all;
fig = figure('menubar', 'none', 'position', [1600 0 dims(2) dims(1)], 'color', 'black');

% frame
colormap gray
frame = zeros(vid.Height, vid.Width);
frameShow = image(1:vid.Width, 1:vid.Height, frame, 'cdatamapping', 'scaled'); hold on;

% obstacle
line([obsPos obsPos], [1 vid.Height], 'color', 'white', 'linewidth', 8);

% kinematic plots
plots = cell(1,length(paws));
for i = 1:length(plots)
    plots{i} = plot(0,0, 'linewidth', 3);
end

% scatter points for end of kinematic trajectories
scatters = cell(1,length(paws));
for i = 1:length(scatters)
    scatters{i} = scatter(0,0, circSize, colors(i,:), 'filled');
end


ax = gca;
set(ax, 'color', 'black', 'position', [0 0 1 1], 'xlim', [1 dims(2)], 'ylim', [1 vid.Height], 'visible', 'off', 'clim', [0 1]);



for i = 1:length(trials)
    
    frameBins = frameTimeStamps>=obsOnTimes(trials(i)) & frameTimeStamps<=obsOffTimes(trials(i));
    frameInds = find(frameBins);
    numModSteps = max(modifiedStepIdentities(frameInds,:), [], 1); % number of mod steps for each of 4 paws
    
    % get final swing inds
    lastSwingInds = nan(1,length(paws));
    for k = 1:length(paws)
        lastSwingInds(k) = find(modifiedStepIdentities(:,paws(k))==1 & frameBins, 1, 'last');
    end
    
    
    % iterate through all frames
    for j = 1:length(frameInds)
        
        % update frame
        frame = rgb2gray(read(vid, frameInds(j)));
        frame = double(frame) / 255;
        frame = imadjust(frame, contrastLims, [0 1]);
        frameLeftInd = round(obsPos - obsPixPositions(frameInds(j)));
        set(frameShow, 'XData', (1:vid.Width)+frameLeftInd, 'CData', frame);
        
        
        
        
        
        for k = 1:length(paws)
            
            locationBins = modifiedStepIdentities(:,paws(k))==1 & frameBins & (1:length(frameTimeStamps))'<=frameInds(j);

            if any(locationBins)
                
                % update plot
                pawLocations = locations(locationBins,:,paws(k));
                pawLocations(:,1) = pawLocations(:,1) - obsPixPositions(locationBins)' + obsPos;
                if numModSteps(paws(k))==1; trialColor = colors(2,:); else; trialColor = colors(1,:); end
                set(plots{k}, 'XData', pawLocations(:,1), 'YData', pawLocations(:,2), 'color', trialColor)
                
                % update scatter
                if frameInds(j)==lastSwingInds(k)
                    set(scatters{k}, 'XData', pawLocations(end,1), ...
                        'YData', pawLocations(end,2), 'CData', trialColor)
                end
            end
        end
            
        
        pause(.02)
        
        
    end
    
end


% close(fig)


















