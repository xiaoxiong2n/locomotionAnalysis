function locationsTop = getLocationsTopMarkers(potentialLocationsTop, locationsBot, frameTimeStamps, xLinearMapping, frameInds)

% !!! need to document
unaryWeight = 1;
pairwiseWeight = 1;


% settings
maxXDistance = 40;    % max distance of x position in top from x position in bottom view
maxVel = 25 / .004;   % max velocity (pixels / sec)

% initializations
locationsTop.x = nan(length(potentialLocationsTop), 4);
locationsTop.z = nan(length(potentialLocationsTop), 4);

% fix x alignment for bottom view and smooth/interpolate
locationsBot.x = locationsBot.x * xLinearMapping(1) + xLinearMapping(2);
locationsBot = fixTracking(locationsBot); % fixTracking fills short stretches of missing values and median filters



% initialize locations

[~, pawSequence] = sort(locationsBot.x(frameInds(1), :), 'descend'); % sort paws from closest to furthest away from camera
alreadyTaken = false(4,1);

for i = 1:4
    
    % get unary potentials
    xDistances = abs(locationsBot.x(frameInds(1), pawSequence(i)) - potentialLocationsTop(frameInds(1)).x);
    isTooFar = xDistances > maxXDistance;
    
    unaries = xDistances;
    unaries(isTooFar) = maxXDistance;
    unaries = (maxXDistance - unaries) / maxXDistance;
    unaries(isnan(unaries)) = 0;
    
    
    [maxScore, maxInd] = max(unaries);
        
    if maxScore > 0
        locationsTop.x(frameInds(1), pawSequence(i)) = potentialLocationsTop(frameInds(1)).x(maxInd);
        locationsTop.z(frameInds(1), pawSequence(i)) = potentialLocationsTop(frameInds(1)).z(maxInd);
        alreadyTaken(maxInd) = true;
    end
end




% iterate through all frameInds

for i = 2:length(frameInds)
    
    % report progress
    disp(i/length(frameInds))
    
    
    % sort paws from closest to furthest away from camera
    [~, pawSequence] = sort(locationsBot.y(frameInds(i), :), 'descend');
    alreadyTaken = false(4,1);
    
    for j = 1:length(pawSequence)
        
        % get unary potentials
        xDistances = abs(locationsBot.x(frameInds(i), pawSequence(j)) - potentialLocationsTop(frameInds(i)).x);
        isTooFar = xDistances > maxXDistance;
        
        unaries = xDistances;
        unaries(isTooFar) = maxXDistance;
        unaries = (maxXDistance - unaries) / maxXDistance;
        unaries(isnan(unaries)) = 0;
        
        
        % get pairwise potentials
        
        % find last ind with detected paw
        lastInd = 1;
        for k = fliplr(1:i-1) % find last ind with detected frame
            if ~isnan(locationsTop.x(frameInds(k), pawSequence(j)))
                lastInd = k;
                break;
            end
        end
                
        dx = locationsTop.x(frameInds(lastInd), pawSequence(j)) - potentialLocationsTop(frameInds(i)).x;
        dz = locationsTop.z(frameInds(lastInd), pawSequence(j)) - potentialLocationsTop(frameInds(i)).z;
        dt = frameTimeStamps(frameInds(i)) - frameTimeStamps(frameInds(lastInd));
        vels = sqrt(dx.^2 + dz.^2) / dt;
        isTooFast = vels > maxVel;
        
        pairwise = vels;
        pairwise(isTooFast) = maxVel;
        pairwise = (maxVel - pairwise) / maxVel;
        pairwise(isnan(pairwise)) = 0;
        
        
        % compute scores
        scores = (unaries * unaryWeight) + (pairwise * pairwiseWeight);
        scores(isTooFar | isTooFast) = 0;
        
        
        [maxScore, maxInd] = max(scores);
        
        if maxScore>0
            locationsTop.x(frameInds(i), pawSequence(j)) = potentialLocationsTop(frameInds(i)).x(maxInd);
            locationsTop.z(frameInds(i), pawSequence(j)) = potentialLocationsTop(frameInds(i)).z(maxInd);
            alreadyTaken(maxInd) = true;
        end
        
        if frameInds(i)==218465; keyboard; end
    end
    
    % maximize scores
    labels = getBestLabels(scores, objectNum, wasOccluded);
    
    
    
end



