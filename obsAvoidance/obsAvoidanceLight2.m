function obsAvoidanceLight2(mouse, expName)

% compare obstacle avoidance with and without the obstacle light on
%
% input         mouse:      name of mouse to analyze
%               expName:    string or cell array of experiments to include in analysis




% user settings
% dataDir = 'C:\Users\LindseyBuckingham\Google Drive\columbia\obstacleData\sessions\';
dataDir = 'C:\Users\Rick\Google Drive\columbia\obstacleData\sessions\';
conditionColors = [1 0 0; 0 1 0];
obsPrePost = [.6 .25]; % plot this much before and after the obstacle reaches the mouse
posRes = .001; % resolution of x axis, in meters
touchPosRes = .0001;
ylims = [.1 .7]; % m/s
% trialRange = [0 .8]; % only include trials #s between these limits, so performance metrices are not dragged down when the animal is warming up or sated near the end
obsPos = .382; % m, position at which obstacle is in the middle of the frame // use getFrameTimes function to determine this value
frameEdges = [.336 .444]; % (m)
sig = .0025; % sigma for gaussian kernal
probYlims = [0 .008];
minTouchTime = 0; % only touches count that are >= minTouchTime


% initializations
sessionInfo = readtable([dataDir 'sessionInfo.xlsx']);

sessionInds = strcmp(sessionInfo.mouse, mouse) &...
              cellfun(@(x) any(strcmp(x, expName)), sessionInfo.experiment) &...
              sessionInfo.include;
sessions = sessionInfo.session(sessionInds);

posInterp = -obsPrePost(1) : posRes : obsPrePost(2);            % velocities will be interpolated across this grid of positional values
touchPosInterp = frameEdges(1): touchPosRes : frameEdges(2);    % positions for touch probability figs with be interpolated across this grid

gausKernel = arrayfun(@(x) (1/(sig*sqrt(2*pi))) * exp(-.5*(x/sig)^2), -sig*5:1/(1/touchPosRes):sig*5); % kernal for touch probability figure
gausKernel = gausKernel/sum(gausKernel);

data = struct(); % stores trial data for all sessions
dataInd = 0;



% COMPILE DATA

% iterate over sessions
for i = 1:length(sessions)

    % load session data
    load([dataDir sessions{i} '\runAnalyzed.mat'],...
            'wheelPositions', 'wheelTimes',...
            'obsPositions', 'obsTimes',...
            'obsOnTimes', 'obsOffTimes',...
            'obsLightOnTimes', 'obsLightOffTimes',...
            'touchOnTimes', 'touchOffTimes',...
            'rewardTimes', 'targetFs');
    
    obsPositions = fixObsPositions(obsPositions, obsTimes, obsOnTimes);
    
    
    % remove brief touches
    validLengthInds = (touchOffTimes - touchOnTimes) >= minTouchTime;
    touchOnTimes = touchOnTimes(validLengthInds);
    touchOffTimes = touchOffTimes(validLengthInds);
    
    
    % get touch positions and ensure all touches fall within frame
    touchPositions = interp1(obsTimes, obsPositions, touchOnTimes, 'linear');
    validPosInds = touchPositions>frameEdges(1) & touchPositions<frameEdges(2);
    touchOnTimes = touchOnTimes(validPosInds);
    touchOffTimes = touchOffTimes(validPosInds);
    touchPositions = touchPositions(validPosInds);    
  
    
    % compute velocity
    vel = getVelocity(wheelPositions, .5, targetFs);
    
    
    % iterate over all trials
    for j = 1:length(obsOnTimes)
        
        dataInd = dataInd + 1;
        data(dataInd).session = sessions{1};
        data(dataInd).sessionNum = i;
        data(dataInd).name = mouse;
        
        % locate trial
        obsOnPos = obsPositions( find(obsTimes >= obsOnTimes(j), 1, 'first') );
        obsTime  = obsTimes(find( obsTimes >= obsOnTimes(j) & obsPositions >= obsPos, 1, 'first')); % time at which obstacle reaches obsPos
        obsWheelPos = wheelPositions(find(wheelTimes>=obsTime, 1, 'first')); % position of wheel at moment obstacle reaches obsPos

        % get trial positions and velocities
        trialInds = (wheelPositions > obsWheelPos-obsPrePost(1)) & (wheelPositions < obsWheelPos+obsPrePost(2));
        trialPos = wheelPositions(trialInds);
        trialPos = trialPos - obsWheelPos; % normalize s.t. 0 corresponds to the position at which the obstacle is directly over the wheel
        trialVel = vel(trialInds);

        % remove duplicate positional values
        [trialPos, uniqueInds] = unique(trialPos, 'stable');
        trialVel = trialVel(uniqueInds);

        % interpolate velocities across positional grid
        trialVelInterp = interp1(trialPos, trialVel, posInterp, 'linear');

        % store results
        data(dataInd).velocity = trialVelInterp;
        
        % find whether and where obstacle was toucheed
        trialTouchInds = touchOnTimes>obsOnTimes(j) & touchOnTimes<obsOffTimes(j);
        data(dataInd).avoided = ~any(trialTouchInds);
        trialTouchPositions = touchPositions(trialTouchInds);
        
        % compute touch probability as function of position
        touchCounts = histcounts(trialTouchPositions, touchPosInterp);
        touchCounts = touchCounts / length(trialTouchInds);
        data(dataInd).touchProbability = conv(touchCounts, gausKernel, 'same');
        
        % find whether light was on
        data(dataInd).obsLightOn = min(abs(obsOnTimes(j) - obsLightOnTimes)) < .5;
        
        % record position at which obstacle turned on
        data(dataInd).obsOnPositions = obsPos - obsOnPos;
    end
end

keyboard




% PLOT EVERYTHING

% prepare figure
figure('name', mouse); pimpFig;
labels = {' (light on)', ' (light off)'};
set(gcf, 'menubar', 'none',...
         'units', 'inches',...
         'position', [4 1.5 11 6.5]);


    
% plot touch probability
subplot(1,3,1)
allTouchProbs = reshape([data(:).touchProbability], length(data(1).touchProbability), length(data))';
touchPosCenters = touchPosInterp(1:end-1) - .5*touchPosRes - obsPos;
plot(touchPosCenters, mean(allTouchProbs([data.obsLightOn],:), 1), 'color', conditionColors(1,:), 'linewidth', 2); hold on;
plot(touchPosCenters, mean(allTouchProbs(~[data.obsLightOn],:), 1), 'color', conditionColors(2,:), 'linewidth', 2);

title('touch probability')
xlabel('\itposition (m)')
ylabel('\ittouch probability')

set(gca, 'xdir', 'reverse', 'xlim', [touchPosCenters(1) touchPosCenters(end)], 'ylim', probYlims, 'ytick', {});



% plot velocity

subplot(1,3,2)
allVelocities = reshape([data(:).velocity], length(data(1).velocity), length(data))';
plot(posInterp, nanmean(allVelocities([data.obsLightOn],:), 1), 'color', conditionColors(1,:), 'linewidth', 2); hold on
plot(posInterp, nanmean(allVelocities(~[data.obsLightOn],:), 1), 'color', conditionColors(2,:), 'linewidth', 2);

title('velocity');
xlabel('\itposition (m)')
ylabel('\itvelocity (m/s)')

set(gca, 'xlim', [-obsPrePost(1) obsPrePost(2)], 'ylim', ylims)
x1 = frameEdges(1)-obsPos;
x2 = frameEdges(2)-obsPos;
line([x1 x1], ylims, 'color', [0 0 0], 'linewidth', 2)
line([x2 x2], ylims, 'color', [0 0 0], 'linewidth', 2)
% obsOnPos = obsPos - mean([data.obsOnPositions]);
% line([obsOnPos obsOnPos], ylims, 'color', [0 0 0], 'linewidth', 2)


% plot obstacle avoidance
subplot(1,3,3)

% compute avoidance per session for light on and off conditions
lightOnAvoidance  = nan(1,length(sessions));
lightOffAvoidance = nan(1,length(sessions));

for i = 1:length(sessions)
    
    trials = sum([data.sessionNum] == i);
    
    trialOnInds = [data.sessionNum]==i & [data.obsLightOn];
    trialOffInds = [data.sessionNum]==i & ~[data.obsLightOn];
    
    lightOnAvoidance(i)  = sum([data(trialOnInds).avoided]) / trials;
    lightOffAvoidance(i) = sum([data(trialOffInds).avoided]) / trials;    
end


title('success rate')
xlabel('\itcondition')
ylabel('\itfraction avoided')
keyboard

% save fig
savefig(['obsAvoidance\figs\' mouse 'lights.fig'])
