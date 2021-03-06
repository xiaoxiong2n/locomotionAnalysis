function data = getKinematicData(sessions)

% settings
isObsPosStatic = false; % if true, assumes wisks touch obstacle at obsPos, which can be manually set to mean of contact positions // otherwise, contact position is computed on trial to trial basis
speedTime = .02; % compute velocity over this interval
interpSmps = 100;
swingMinLength = .005; % swings must be at least this long to be included in analysis (meters)
swingMaxSmps = 50; % when averaging swing locations without interpolating don't take more than swingMaxSmps for each swing

% initializations
sessionInfo = readtable([getenv('OBSDATADIR') 'sessions\sessionInfo.xlsx']);
controlSteps = 2; % !!! don't change this - currently requires this number is two
data = struct();
dataInd = 1;


% collect data for all trials
for i = 1:length(sessions)
    
    % report progress
    fprintf('%s: collecting data\n', sessions{i});
    
    % load session data
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\runAnalyzed.mat'],...
            'obsPositions', 'obsTimes', 'obsPixPositions', 'frameTimeStamps', 'mToPixMapping', ...
            'obsOnTimes', 'obsOffTimes', 'nosePos', 'targetFs', 'wheelPositions', 'wheelTimes', 'targetFs', ...
            'wiskTouchSignal', 'frameTimeStampsWisk');
    obsPositions = fixObsPositions(obsPositions, obsTimes, obsPixPositions, frameTimeStamps, obsOnTimes, obsOffTimes, nosePos(1));
    mToPixMapping = median(mToPixMapping,1);
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\tracking\locationsBotCorrected.mat'], 'locations')
    locations = locations.locationsCorrected;
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\tracking\stanceBins.mat'], 'stanceBins')
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\tracking\isExcluded.mat'], 'isExcluded')
    load([getenv('OBSDATADIR') 'sessions\' sessions{i} '\wiskContactTimes.mat'], 'contactTimes', 'contactPositions')
    vel = getVelocity(wheelPositions, speedTime, targetFs);
    
        
    % get velocities for all trials in session
    if isObsPosStatic
        obsPos = nanmedian(contactPositions);
        sessionVels = getTrialSpeedsAtObsPos(obsPos, wheelPositions, wheelTimes, obsPositions, obsTimes, obsOnTimes, speedTime, targetFs);
    else
        sessionVels = nan(1,length(obsOnTimes));
    end
    
    % get wheel velocities
    wheelVel = getVelocity(wheelPositions, speedTime, targetFs);
    wheelVel = interp1(wheelTimes, wheelVel, frameTimeStamps)';

    % normalize y values
    locations(:,2,:) = locations(:,2,:) - nosePos(2); % subtract midline from all y values
    
    
    % get swing identities (each swing is given a number, in ascending order)
    swingBins = ~stanceBins;
    swingIdentities = nan(size(swingBins));
    
    for j = 1:4
        
        % get start and end of swings
        swingStartInds = find([0; diff(swingBins(:,j))==1]');
        swingEndInds = find([diff(swingBins(:,j))==-1; 0]');
        
        % make sure first ind is a start and last ind is an end
        swingStartInds = swingStartInds(swingStartInds<swingEndInds(end));
        swingEndInds = swingEndInds(swingEndInds>swingStartInds(1));
        
        % remove swings that are too short
        validBins = locations(swingEndInds,1,j) - locations(swingStartInds,1,j) > swingMinLength;
        swingStartInds = swingStartInds(validBins);
        swingEndInds = swingEndInds(validBins);
        
        swingCount = 1;
        for k = 1:length(swingStartInds)
            swingIdentities(swingStartInds(k):swingEndInds(k),j) = swingCount;
            swingCount = swingCount + 1;
        end
    end
    
    
    % collect data for all trials within session
    for j = 1:length(obsOnTimes)
        
        % get trial bins, locations, and swingIdentities
        trialBins = frameTimeStamps>=obsOnTimes(j) & frameTimeStamps<=obsOffTimes(j) & ~isnan(obsPixPositions)';
        trialLocations = locations(trialBins,:,:);
        trialSwingIdentities = swingIdentities(trialBins,:);
        trialTimeStamps = frameTimeStamps(trialBins);
        trialObsPixPositions = obsPixPositions(trialBins);
        trialIsExcluded = isExcluded(trialBins);
        trialWheelVel = wheelVel(trialBins);
        
        trialBinsWisk = frameTimeStampsWisk>=obsOnTimes(j) & frameTimeStampsWisk<=obsOffTimes(j);
        trialFrameTimeStampsWisk = frameTimeStampsWisk(trialBinsWisk);
        trialWiskTouchSignal = wiskTouchSignal(trialBinsWisk);
        
        if ~any(isnan(trialLocations(:))) && ~any(trialIsExcluded) % !!! this is a hack // should check that velocity criteria is met AND that the locations have in fact been analyzed for the session
        
            % get vel at moment of contact
            obsPos = contactPositions(j);
            if isnan(obsPos); obsPos = nanmedian(contactPositions); end
            sessionVels(j) = interp1(wheelTimes, vel, contactTimes(j));
            
            % get frame ind at which obs reaches obsPos
            obsPosTime = obsTimes(find(obsPositions>=obsPos & obsTimes>obsOnTimes(j), 1, 'first'));
            obsPosInd = knnsearch(trialTimeStamps, obsPosTime);
            
            % get trial swing identities and define control and modified steps
            controlStepIdentities = nan(size(trialSwingIdentities));
            modifiedStepIdentities = nan(size(trialSwingIdentities));

            for k = 1:4

                overObsInd = find(trialLocations(:,1,k)>trialObsPixPositions', 1, 'first');
                swingOverObsIdentity = trialSwingIdentities(overObsInd, k);
                firstModifiedIdentitiy = trialSwingIdentities(find(~isnan(trialSwingIdentities(:,k))' & 1:size(trialSwingIdentities,1)>=obsPosInd, 1, 'first'), k);

                modifiedBins = (trialSwingIdentities(:,k) >= firstModifiedIdentitiy) & (trialSwingIdentities(:,k) <= swingOverObsIdentity);
                controlBins = (trialSwingIdentities(:,k) >= (firstModifiedIdentitiy-controlSteps)) & (trialSwingIdentities(:,k) < firstModifiedIdentitiy);

                modifiedStepIdentities(:,k) = cumsum([0; diff(modifiedBins)==1]);
                modifiedStepIdentities(~modifiedBins,k) = nan;
                if ~any(~isnan(modifiedStepIdentities(:,k))); keyboard; end
                controlStepIdentities(:,k) = cumsum([0; diff(controlBins)==1]);
                controlStepIdentities(~controlBins,k) = nan;

            end
            
            % determine whether left and right forepaws are in swing at obsPos moment
            isLeftSwing = ~isnan(modifiedStepIdentities(obsPosInd,2));
            isRightSwing = ~isnan(modifiedStepIdentities(obsPosInd,3));
            oneSwingOneStance = xor(isLeftSwing, isRightSwing);
            
            % flip y values if the left fore is the swinging foot (thus making it the right paw)
            isFlipped = false;
            if oneSwingOneStance && isLeftSwing
                trialLocations = trialLocations(:,:,[4 3 2 1]);
                controlStepIdentities = controlStepIdentities(:,[4 3 2 1]);
                modifiedStepIdentities = modifiedStepIdentities(:,[4 3 2 1]);
                trialLocations(:,2,:) = -trialLocations(:,2,:);
                isFlipped = true;
            end
            
            % correct x locations (transform them s.t. obs is always at position 0 and positions move forward as though there were no wheel)
            trialLocations(:,1,:) = trialLocations(:,1,:) - trialObsPixPositions';           
            
            % convert to meters
            trialLocations = trialLocations / abs(mToPixMapping(1));
            
            % get stance distance from obs
            stanceDistance = trialLocations(obsPosInd,1,2); % left fore paw (2) is always the stance foot at this point after flipping y values above
            swingStartDistance = trialLocations(find(modifiedStepIdentities(:,3)==1,1,'first'),1,3);
            
            % get control step(s) length, duration, wheel velocity
            controlSwingLengths = nan(controlSteps,4);
            controlSwingDurations = nan(controlSteps,4);
            controlWheelVels = nan(controlSteps,4);
            for k = 1:4
                for m = 1:controlSteps
                    stepBins = controlStepIdentities(:,k)==m;
                    stepXLocations = trialLocations(stepBins,1,k);
                    controlSwingLengths(m,k) = stepXLocations(end) - stepXLocations(1);
                    stepTimes = trialTimeStamps(stepBins);
                    controlSwingDurations(m,k) = stepTimes(end) - stepTimes(1);
                    
%                     stepInds = find(stepBins);
%                     randInd = stepInds(randperm(length(stepInds),1));
                    controlWheelVels(m,k) = trialWheelVel(find(stepBins,1,'first'));
                end
            end
            
            % get first modified step length for swing foot
            modifiedSwingLengths = nan(1,4);
            modifiedSwingDurations = nan(1,4);
            modifiedWheelVels = nan(1,4);
            for k = 1:4
                stepBins = modifiedStepIdentities(:,k)==1;
                stepXLocations = trialLocations(stepBins,1,k);
                modifiedSwingLengths(k) = stepXLocations(end) - stepXLocations(1);
                stepTimes = trialTimeStamps(stepBins);
                modifiedSwingDurations(1,k) = stepTimes(end) - stepTimes(1);

                modifiedWheelVels(k) = trialWheelVel(find(stepBins,1,'first'));
            end
            
            % get interpolated and non-interpolated control and modified step locations
            controlLocations = cell(1,4);
            modLocations = cell(1,4);
            controlLocationsInterp = cell(1,4);
            modLocationsInterp = cell(1,4);
            modStepNum = nan(1,4);
            pawObsPosIndInterp = nan(1,4);
            pawObsPosInd = nan(1,4);
            
            for k = 1:4
                
                % control
                stepNum = max(controlStepIdentities(:,k));
                pawControlLocations = nan(stepNum, 2, swingMaxSmps);
                pawControlLocationsInterp = nan(stepNum, 2, interpSmps);
                
                for m = 1:stepNum
                    stepBins = controlStepIdentities(:,k)==m;
                    stepBins(find(stepBins,1,'first')+swingMaxSmps:end) = 0; % make sure there are no more than swingMaxSmps true bins
                    
                    stepX = trialLocations(stepBins,1,k);
                    stepY = trialLocations(stepBins,2,k);
                    pawControlLocations(m,:,1:length(stepX)) = cat(1,stepX',stepY');
                    
                    xInterp = interp1(1:length(stepX), stepX, linspace(1,length(stepX),interpSmps));
                    yInterp = interp1(1:length(stepY), stepY, linspace(1,length(stepY),interpSmps));
                    pawControlLocationsInterp(m,:,:) = cat(1,xInterp,yInterp);
                end
                
                controlLocations{k} = pawControlLocations;
                controlLocationsInterp{k} = pawControlLocationsInterp;
                
                
                % modified
                modStepNum(k) = max(modifiedStepIdentities(:,k));
                pawModifiedLocations = nan(modStepNum(k), 2, swingMaxSmps);
                pawModifiedLocationsInterp = nan(modStepNum(k), 2, interpSmps);
                
                for m = 1:modStepNum(k)
                    stepBins = modifiedStepIdentities(:,k)==m;
                    stepBins(find(stepBins,1,'first')+swingMaxSmps:end) = 0; % make sure there are no more than swingMaxSmps true bins
                    
                    stepX = trialLocations(stepBins,1,k);
                    stepY = trialLocations(stepBins,2,k);
                    pawModifiedLocations(m,:,1:length(stepX)) = cat(1,stepX',stepY');
                    
                    xInterp = interp1(1:length(stepX), stepX, linspace(1,length(stepX),interpSmps));
                    yInterp = interp1(1:length(stepY), stepY, linspace(1,length(stepY),interpSmps));
                    pawModifiedLocationsInterp(m,:,:) = cat(1,xInterp,yInterp);
                    
                    % get ind of obs hit in interpolated coordinates
                    if m==1
                        stepObsPosInd = obsPosInd - find(stepBins,1,'first') + 1;
                        pawObsPosIndInterp(k) = interp1(linspace(1,length(stepX),interpSmps), ...
                            1:interpSmps, stepObsPosInd, 'nearest');
                        pawObsPosInd(k) = obsPosInd - find(stepBins,1,'first');
%                     if isnan(obsPosIndInterp(k)) && k==3 && oneSwingOneStance; keyboard; end
                    end
                end
                
                modLocations{k} = pawModifiedLocations;
                modLocationsInterp{k} = pawModifiedLocationsInterp;
                
                
            end



            % store results
            sessionInfoBin = find(strcmp(sessionInfo.session, sessions{i}));
            data(dataInd).mouse = sessionInfo.mouse{sessionInfoBin};
            data(dataInd).session = sessions{i};
            
            data(dataInd).vel = sessionVels(j);
            data(dataInd).obsPos = obsPos;
            data(dataInd).obsPosInd = obsPosInd;
            data(dataInd).pawObsPosIndInterp = pawObsPosIndInterp;
            data(dataInd).pawObsPosInd = pawObsPosInd;
            data(dataInd).timeStamps = trialTimeStamps;
            data(dataInd).locations = trialLocations;
            data(dataInd).controlLocations = controlLocations;
            data(dataInd).modifiedLocations = modLocations;
            data(dataInd).controlLocationsInterp = controlLocationsInterp;
            data(dataInd).modifiedLocationsInterp = modLocationsInterp;
            data(dataInd).controlStepIdentities = controlStepIdentities;
            data(dataInd).modifiedStepIdentities = modifiedStepIdentities;
            data(dataInd).modStepNum = modStepNum;
            data(dataInd).oneSwingOneStance = oneSwingOneStance;
            data(dataInd).stanceDistance = stanceDistance;
            data(dataInd).swingStartDistance = swingStartDistance;
            data(dataInd).isFlipped = isFlipped;
            
            data(dataInd).controlSwingLengths = controlSwingLengths;
            data(dataInd).modifiedSwingLengths = modifiedSwingLengths;
            data(dataInd).controlSwingDurations = controlSwingDurations;
            data(dataInd).modifiedSwingDurations = modifiedSwingDurations;
            data(dataInd).controlWheelVels = controlWheelVels;
            data(dataInd).modifiedWheelVels = modifiedWheelVels;
            
            dataInd = dataInd + 1;
        end
    end
end


% make model to predict would-be mod swing length using wheel vel and previous swing lengths as predictors
mice = unique({data.mouse});
models = cell(1,length(mice));

for i = 1:length(mice)
    
    mouseBins = strcmp({data.mouse}, mice{i});
    
    % make predictive model
    
    % predictors: wheel speed, previous stride length
    prevLengths = cellfun(@(x) x(1,3), {data(mouseBins).controlSwingLengths});
    vel = cellfun(@(x) x(2,3), {data(mouseBins).controlWheelVels});

    % dependent variable: stride length
    lengths = cellfun(@(x) x(2,3), {data(mouseBins).controlSwingLengths});
    
    % make linear model
    models{i} = fitlm(cat(1,prevLengths,vel)', lengths, 'Linear', 'RobustOpts', 'on');
    
    % generate predictions
    prevLengths = cellfun(@(x) x(2,3), {data(mouseBins).controlSwingLengths});
    vel = cellfun(@(x) x(1,3), {data(mouseBins).modifiedWheelVels});
    predictedLengths = num2cell(predict(models{i}, cat(1,prevLengths,vel)'));
    [data(mouseBins).predictedLengths] = predictedLengths{:};
end


fprintf('--- done collecting data ---\n');









