function sensoryDependence
% plot sensory dependence of obstacle avoidance

% settings
wiskSessions = {'171117_001', '171118_001', '180225_000', '180225_001', '180225_002', '180226_000', '180226_001', '180226_002'};
noWiskSessions = {'171121_000', '171122_001', '180228_000', '180228_001', '180228_002', '180301_000', '180301_001', '180301_002'};
touchThresh = 6; % if paw contacts obs for more than touchThresh frames, trial is considered touching
maxTrialNum = 130; % DON'T SET THIS HIGHER THAN 130 // only analyzes up to this trial within each session // david didn't analyze beyond 130 in some really long sessions

% initializations
sessions = cat(2, wiskSessions, noWiskSessions);
hasWiskers = [true(1,length(wiskSessions)) false(1,length(noWiskSessions))];
sessionInfo = readtable([getenv('OBSDATADIR') 'sessions\sessionInfo.xlsx']);
dataInd = 1;


data = struct();
sessionTrials = nan(1,length(sessions));


for i = 1:length(sessions)
    
    % get session data
    sessionBin = strcmp(sessionInfo.session, sessions{i});
    mouse = sessionInfo.mouse{sessionBin};
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\runAnalyzed.mat'], ...
        'obsOnTimes', 'obsOffTimes', 'wheelPositions', 'wheelTimes', 'targetFs', 'obsLightOnTimes', 'frameTimeStamps');
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\run.mat'], 'breaks');
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\obsContacts.mat'], 'touchingFront', 'touchingTop');
    
    for j = 1:length(obsOnTimes)
        
        % determine if light is on
        isLightOn = min(abs(obsOnTimes(j) - obsLightOnTimes)) < 1; % did the light turn on near whether the obstacle turned on
        
        % get trial speed
        onInd = find(wheelTimes>=obsOnTimes(j),1,'first');
        offInd = find(wheelTimes<=obsOffTimes(j),1,'last');
        vel = (wheelPositions(offInd)-wheelPositions(onInd)) / (obsOffTimes(j)-obsOnTimes(j));
        
        % determine whether there was a wheel break
        isWheelBreak = any(breaks.times>obsOnTimes(j) & breaks.times<obsOffTimes(j));
        
        % count frames in trial in which paw is touching obs
        frameBins = frameTimeStamps>obsOnTimes(j) & frameTimeStamps<obsOffTimes(j);
        frontTouchingFrames = sum(touchingFront(frameBins));
        topTouchingFrames = sum(touchingTop(frameBins));
        
        % store results
        data(dataInd).session = sessions{i};
        data(dataInd).mouse = mouse;
        data(dataInd).trial = j;
        data(dataInd).hasWiskers = hasWiskers(i);
        data(dataInd).isLightOn = isLightOn;
        data(dataInd).isWheelBreak = isWheelBreak;
        data(dataInd).vel = vel;
        data(dataInd).frontTouchingFrames = frontTouchingFrames;
        data(dataInd).topTouchingFrames = topTouchingFrames;
        dataInd = dataInd + 1;
    end
    
    sessionTrials(i) = j;
end




% PLOT!

% settings
lineEdges = [-.25 .25];
lineWidth = 3;
colors = winter(2);
circSize = 80;
successYLims = [0 1];
velYLim = [.2 .6];
jitterRange = .25;

% determine whether trial was successful
isSuccess = num2cell((([data.frontTouchingFrames] + [data.topTouchingFrames]) < touchThresh) & ~[data.isWheelBreak]);
[data.isSuccess] = isSuccess{:};


figure('color', 'white', 'menubar', 'none', 'inverthardcopy', 'off', 'position', [100 100 1280/2 720]);


mice = unique({data.mouse});

for wisk = [false true]
    for light = [false true]
        
        successRates = nan(1,length(mice));
        vels = nan(1,length(mice));
        jitters = linspace(-jitterRange/2, jitterRange/2, length(mice));
        
        for mouse = 1:length(mice)
            
            % get session performance
            trialBins = [data.hasWiskers]==wisk & ...
                ([data.isLightOn]==light) & ...
                strcmp(mice{mouse}, {data.mouse}) & ...
                [data.trial]<=maxTrialNum;
            trialBinsNoBreak = trialBins & ~[data.isWheelBreak];
            successRates(mouse) = sum([data(trialBins).isSuccess]) / sum(trialBins);
            vels(mouse) = mean([data(trialBinsNoBreak).vel]);
            
            % plot
            subplot(2,2,wisk+1)
            scatter(light-.5 + jitters(mouse), successRates(mouse), circSize, colors(light+1,:), 'filled'); hold on
            subplot(2,2,wisk+3)
            scatter(light-.5 + jitters(mouse), vels(mouse), circSize, colors(light+1,:), 'filled'); hold on
        end
        
        % plot means
        subplot(2,2,wisk+1)
        line(lineEdges+light-.5, [mean(successRates) mean(successRates)], 'linewidth', lineWidth, 'color', 'black')
        subplot(2,2,wisk+3)
        line(lineEdges+light-.5, [mean(vels) mean(vels)], 'lineWidth', lineWidth, 'color', 'black')
    end
end

% pimp figs
subplot(2,2,1)
set(gca, 'xcolor', 'white', 'ylim', successYLims)
ylabel('success rate')

subplot(2,2,2)
set(gca, 'xcolor', 'white', 'ylim', successYLims)

subplot(2,2,3)
set(gca, 'xtick', [-.5 .5], 'xticklabel', {'no light', 'light'}, 'ylim', velYLim)
xlabel('no whiskers')
ylabel('velocity (m/s)')

subplot(2,2,4)
set(gca, 'xtick', [-.5 .5], 'xticklabel', {'no light', 'light'}, 'ylim', velYLim)
xlabel('whiskers')

saveas(gcf, [getenv('OBSDATADIR') 'figures\sensoryDependennce.png']);















