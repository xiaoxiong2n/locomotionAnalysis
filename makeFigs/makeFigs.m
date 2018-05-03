%% CALCULATE KINEMATIC DATA

% settings
sessions = {'180122_001', '180122_002', '180122_003', ...
            '180123_001', '180123_003', ...
            '180124_001', '180124_002', '180124_003', ...
            '180125_001', '180125_002', '180125_003'};

% initializations
data = getKinematicData3(sessions);
save([getenv('OBSDATADIR') 'kinematicData.mat'], 'data');
data = data([data.oneSwingOneStance]);

%% LOAD PREVIOUSLY CALCULATEDDATA

load([getenv('OBSDATADIR') 'kinematicData.mat'], 'data')
data = data([data.oneSwingOneStance]);

%% BIN DATA
binNum = 5;

% get bins
% binVar = [data.swingStartDistance]; % phase
% binVar = cellfun(@(x) x(1,3), {data.modifiedWheelVels}); % speed
binVar = [data.swingStartDistance] + [data.predictedLengths]; % predicted distance to obs

binEdges = linspace(min(binVar), max(binVar), binNum+1);
bins = discretize(binVar, binEdges);
binLabels = cell(1,binNum);
for i = 1:binNum; binLabels{i} = sprintf('%.3f', mean(binVar(bins==i))); end


%% MAKE KINEMATIC FIGS

plotType = 'averages';
plotTrajectories(data, bins, binLabels, plotType);


% reformat single bin figure
if binNum==1
    % settings
    traceHgt = 1;
    histoHgt = .2;
    histoWid = .25;
    separation = .25;
    yLims = [-.1 .08];

    % get figure subplots
    obs = findall(gcf);
    obs = obs(strcmp(get(obs, 'type'), 'axes'));
    traceWidHgtRatio = range(get(gca,'xlim')) / range(get(gca,'ylim'));
    traceWid = traceHgt * traceWidHgtRatio;

    set(obs(1), 'position', [((.5-.5*separation)-.5*traceWid) ((1-traceHgt)*.5) traceWid traceHgt], 'ylim', yLims)
    set(obs(2), 'position', [((.5+.5*separation)-.5*histoWid) ((1-histoHgt)*.5) histoWid histoHgt])
    print('-clipboard', '-dmeta')
end

%% DELTA LENGTH HEAT MAP

deltaLengthHeatMap(data, binVar);
blackenFig; print('-clipboard', '-dmeta')


%% REACTION TIMES

tic; plotReactionTimes(data); toc
blackenFig; print('-clipboard', '-dmeta')


%% MAKE SENSORY DEPENDENCE VIDS

% settings
sessions = {'180226_002', '180228_002'};
sessionConditions = {'wisk', 'noWisk'};
obsPosRange = [-.1 .1];
playBackSpeed = .1;
trialNum = 5;
trialProportion = .05;
minVel = .3;

% select trials
for i = 2
    
    % get light on/off inds
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\runAnalyzed.mat'], 'obsOnTimes', 'obsLightOnTimes');
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\tracking\velocityInfo.mat'], 'trialVels');
    lightOnBins = zeros(1,length(obsOnTimes));
    
    for j =1:length(obsOnTimes)    
        if min(abs(obsOnTimes(j) - obsLightOnTimes)) < .5; lightOnBins(j) = 1; end
    end
    
    lightOnInds = find(lightOnBins & trialVels>minVel);
    lightOnTrials = sort(lightOnInds(randperm(length(lightOnInds), trialNum)));
    lightOffInds = find(~lightOnBins & trialVels>minVel);
    lightOffTrials = sort(lightOffInds(randperm(length(lightOffInds), trialNum)));
    
    % make vids
%     makeVidWisk([sessionConditions{i} 'LightOn'], sessions{i}, obsPosRange, playBackSpeed, lightOnTrials);
    makeVidWisk([sessionConditions{i} 'LightOff'], sessions{i}, obsPosRange, playBackSpeed, lightOffTrials);
end

%% MAKE WISK TOUCH AND OBS TOUCH SAMPLE VID

session = '171226_002';
playBackSpeed = .1;
trials = sort([61 121 161 21 81]);

makeVidWisk('wiskAndObsTouchSensingExample', session, [-.1 .1], playBackSpeed, trials);


%% PLOT CORRELATION BTWN PREV STEP LENGTH, SPEED, AND CURRENT STEP LENGTH

% settings
circSize = 8;
circColor = [1 1 0];
lineColor = [0 0 0];

close all;
figure('color', 'white', 'position', [2000 100 1280/3 720], 'InvertHardcopy', 'off', 'menubar', 'none');

lengths = cellfun(@(x) x(2,3), {data.controlSwingLengths});
prevLengths = cellfun(@(x) x(1,3), {data.controlSwingLengths});
vels = cellfun(@(x) x(2,3), {data.controlWheelVels});



subplot(2,1,1)
scatter(vels, lengths, circSize, circColor, 'filled');
xlabel('velocity (m)')
ylabel('swing length (m)')
fit = polyfit(vels, lengths, 1);
line(get(gca,'xlim'), get(gca,'xlim')*fit(1)+fit(2), 'linewidth', 2, 'color', lineColor)
set(gca, 'xlim', [.2 .8]);


subplot(2,1,2)
scatter(prevLengths, lengths, circSize, circColor, 'filled');
xlabel('previous swing length (m)')
ylabel('swing length (m)')
fit = polyfit(prevLengths, lengths, 1);
line(get(gca,'xlim'), get(gca,'xlim')*fit(1)+fit(2), 'linewidth', 2, 'color', lineColor)

blackenFig
print('-clipboard', '-dbitmap')








