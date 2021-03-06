function data = getAllSessionTrialSpeeds(experiments, posRange)

% make a data structure for all sessions in experiments where each row is a trial, and compute whether light was on and the velocity of the trial
% vel is computed from position whether obs is center above the wheel (obsPos) plus and minus posRange
% posRange: compute speed bewteen posRange(1) and posRange(2)


% initializations
sessions = readtable([getenv('OBSDATADIR') 'sessions\sessionInfo.xlsx']);
sessionBins = ismember(sessions.experiment, experiments) &...
              sessions.include;
sessions = sessions(sessionBins, :);

data(height(sessions)*300) = struct(); % stores trial data for all sessions // make it too big then cut it later
dataInd = 1;

% get trial speeds for all sessions
for i = 1:height(sessions)
    disp(i / height(sessions));
    
    load([getenv('OBSDATADIR') 'sessions\' sessions.session{i} '\runAnalyzed.mat'],...
        'obsPositions', 'obsTimes', 'obsOnTimes', 'obsOffTimes', 'obsLightOnTimes');
    obsPositions = fixObsPositions(obsPositions, obsTimes, obsOnTimes);
    
    for j = 1:length(obsOnTimes)-1
        
        % get trial velocity
        % !!! should be doing this with wheel positions, not obs positions!!!
        startInd = find(obsTimes>obsOnTimes(j) & obsPositions>posRange(1), 1, 'first');
        endInd = find(obsTimes>obsOnTimes(j) & obsPositions>posRange(2), 1, 'first');
        trialVel = (obsPositions(endInd) - obsPositions(startInd)) / (obsTimes(endInd) - obsTimes(startInd));
        
        % determine whether light was on in trial
        isLightOn = min(abs(obsOnTimes(j) - obsLightOnTimes)) < 1; % did the light turn on near whether the obstacle turned on
        if isempty(isLightOn); isLightOn = 0; end
        
        % store results
        data(dataInd).session = sessions.session{i};
        data(dataInd).mouse = sessions.mouse{i};
        data(dataInd).vel = trialVel;
        data(dataInd).lightOn = isLightOn;
        data(dataInd).videoRecorded = exist([getenv('OBSDATADIR') 'sessions\' sessions.session{i} '\runTop.mp4'], 'file')==2;
        data(dataInd).trialNum = j;
        
        dataInd = dataInd + 1;
    end
end

data = data(1:dataInd-1); % remove empty rows



