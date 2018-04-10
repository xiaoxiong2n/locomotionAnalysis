%% RECALCULATE KINEMATIC DATA

% settings
sessions = {'180122_001', '180122_002', '180122_003', ...
            '180123_001', '180123_002', '180123_003', ...
            '180124_001', '180124_002', '180124_003', ...
            '180125_001', '180125_002', '180125_003'};


% initializations
data = getKinematicData(sessions);
save([getenv('OBSDATADIR') 'kinematicData.mat'], 'data');
data = data([data.oneSwingOneStance]);

%% LOAD DATA

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

plotType = 'trials';
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
obsPosRange = [-.1 .1];
playBackSpeed = .1;
trialProportion = .05;


makeVidWisk(sessions{1}, obsPosRange, playBackSpeed, trialProportion);









