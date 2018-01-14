function locationsTop = getLocationsTop(potentialLocationsTop, locationsBot,...
    xLinearMapping, frameInds, obsPixPositions, frameTimeStamps, paws, fs)

% !!! need to document and make not shitty


% settings
objectNum = 4;
maxVel = 25 / .004;   % max velocity (pixels / sec)
maxXDistance = 25;    % max distance of x position in top from x position in bottom view
% xOccludeBuffer = 10;  % if paws in bottom view have x values within xOccludeBuffer of one another, the paw further away from the camera is treated as occluded
stanceHgt = 6;        % paws in stance (negative x velocity in bottom view) are assigned z values stanceHgt pixels above wheel (wheel defined by circRoiPts)
circRoiPts = [36 172; 224 122; 386 157];
stanceVelDif = 500;   % if paws paw is within this many pix/sec of wheel velocity (actually obs vel for now) then it is considered to be in stance IF length of this period exceeds stanceMin
stanceMin = .04;      % (s)
% obsProximity = 60;    % if paw is within obsProximity pixels of obstacle, stance is no longer assumed when velocity is less than stanceVel
velTime = .025;  % amount of time to compute velocity over

unariesWeight = 1;
pairwiseWeight = 0;
lownessWeight = 0;
scoreWeight = 0;


% initializations
labels = nan(length(potentialLocationsTop), objectNum);
locationsTop.x = nan(length(potentialLocationsTop), objectNum);
locationsTop.z = nan(length(potentialLocationsTop), objectNum);
[wheelRadius, wheelCenter] = fitCircle(circRoiPts - repmat([0 stanceHgt], 3, 1));

% fix x alignment for bottom view
% locationsBot.x = locationsBot.x*xLinearMapping(1) + xLinearMapping(2);

% fix bottom view tracking (fixTracking fills short stretches of missing values and median filters)
locationsBot = fixTracking(locationsBot);

% get x velocities for bottom view tracking
locationsBot.xVel = nan(size(locationsBot.x));
for i = paws
    locationsBot.xVel(:,i) = getVelocity(locationsBot.x(:,i), velTime, fs);
end

% get wheel (in this case obs) velocities
wheelVel = getVelocity(obsPixPositions, velTime, fs);




% get paw locations for stance periods
for i = paws
    
    % get epoches where wheel vel and paw x vel are similar to one another
    matchedVelBins = abs(wheelVel(1:length(locationsBot.xVel(:,i))) - locationsBot.xVel(:,i)') < stanceVelDif;
    startInds = find(diff(matchedVelBins) == 1) + 1;
    endInds = find(diff(matchedVelBins) == -1) + 1;

    % ensure that the first event is the beginning of an epoch and the last is the end of an epoch
    startInds = startInds(startInds<endInds(end));
    endInds = endInds(endInds>startInds(1));
    
    % only keep epochs that are long enough
    validStances = (frameTimeStamps(endInds) - frameTimeStamps(startInds)) > stanceMin;
    startInds = startInds(validStances);
    endInds = endInds(validStances);
    
    
    % store the coordinates of each paw during stance
    for j=1:length(startInds)
        for k = startInds(j):endInds(j)
            locationsTop.x(k,i) = locationsBot.x(k,i);
            locationsTop.z(k,i) = wheelCenter(2) - round(sqrt(wheelRadius^2 - (locationsBot.x(k,i)-wheelCenter(1))^2)); % !!! should replace this with pre-computed lookup table
        end
    end
end





% iterate through all frameInds

for i = 1:length(frameInds)
    
    % report progress
    disp(i/length(frameInds))
    
    
    % sort paws from closest to furthest away from camera
    ys = locationsBot.y(frameInds(i),:);
    [~, pawSequence] = sort(ys, 'descend');
    if any(isnan(ys))
        nans = sum(isnan(ys));
        pawSequence = [pawSequence(1+nans:end) 1:nans];
    end
    alreadyTaken = false(length(potentialLocationsTop(frameInds(i)).x), 1);
    scores = nan(4, length(potentialLocationsTop(frameInds(i)).x));
    
    
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
        pawScores = (unaries * unaryWeight) + (pairwise * pairwiseWeight);
        pawScores(isTooFar | isTooFast | alreadyTaken) = 0;
        scores(pawSequence(j), :) = pawScores;
        
        [maxScore, maxInd] = max(scores(pawSequence(j), :));
        
        if maxScore>0
            locationsTop.x(frameInds(i), pawSequence(j)) = potentialLocationsTop(frameInds(i)).x(maxInd);
            locationsTop.z(frameInds(i), pawSequence(j)) = potentialLocationsTop(frameInds(i)).z(maxInd);
            alreadyTaken(maxInd) = true;
        end
    end
end











% iterate through all frameInds
% for i = frameInds
%     
%     % report progress
%     disp(i/length(locationsBot.x))
%     
%     % initializations
%     unaries = zeros(objectNum, length(potentialLocationsTop(i).x));
%     pairwise = zeros(objectNum, length(potentialLocationsTop(i).x));
%     valid = ones(objectNum, length(potentialLocationsTop(i).x));
%     wasOccluded = zeros(1, objectNum); % keeps track of whether the object was occluded in the previous frame (used in getBestLabels)
%     
%     
%     for j = paws %1:objectNum
%         
% %         % check if paw is occluded
% %         occludedByBins = abs(locationsBot.x(i,j) - locationsBot.x(i,:)) < xOccludeBuffer & ...
% %                       (locationsBot.y(i,:) > locationsBot.y(i,j));
% %         if any(occludedByBins)
% %             valid(j,:) = 0;
% %         
% %         % if not occluded, compute scores for all potential locations
% %         else
%             
%             % get unary potentials
%             xDistances = abs(locationsBot.x(i,j) - potentialLocationsTop(i).x);
%             xDistances(xDistances>maxXDistance) = maxXDistance;
%             unaries(j,:) = (maxXDistance - xDistances) / maxXDistance;
%             
%             % get pairwise potentials
%             if i>1
%                 % get ind of last detection frame for object j % !!! i think this is a bug... i cant just do i-1 because i-1 might not actually be a member of frameInds!!!
%                 if ~isnan(labels(i-1, j)) 
%                     prevFrame = i-1;
%                 else
%                     prevFrame = find(~isnan(labels(:,j)), 1, 'last'); % !!! this can be sped up quite a bit using a for loop
%                     wasOccluded(j) = 1;
%                 end
% 
%                 % get label at previous dection frame
%                 prevLabel = labels(prevFrame, j);
%                 
%                 if isempty(prevFrame) || isempty(potentialLocationsTop(i).x)
%                     pairwise(j,:) = 0;
%                 else
%                     pairwise(j,:) = getPairwisePotentials(potentialLocationsTop(i).x, potentialLocationsTop(i).y,...
%                         potentialLocationsTop(prevFrame).x(prevLabel), potentialLocationsTop(prevFrame).y(prevLabel),...
%                         frameTimeStamps(i)-frameTimeStamps(prevFrame), maxVel);
%                     valid(j, pairwise(j,:)==0) = 0;
%                 end
%             end
% %         end
%     end
%     
%     % get track scores (from svm)
%     trackScores = repmat(potentialLocationsTop(i).scores', objectNum, 1);
%     
%     % get lowness of potential locations
%     lowness = repmat(potentialLocationsTop(i).y' / range(locationsBot.y(:)), objectNum, 1);
% 
%     % find best labels
%     try
%         scores = unariesWeight.*unaries + pairwiseWeight.*pairwise + scoreWeight.*trackScores + lownessWeight.*lowness;
%         scores = scores .* (unaries>0);
%         scores = scores .* valid;
%     catch
%         scores = []; % !!! this try/catch is a hack... need better way of handling frames where there are no potential locations
%     end
%     
%     % !!! this if/then is temporary // it would be better if getBestLabels handled empty values itself // NEED TO LOOK INTO WHAT HAPPENS WHEN THERE ARE FEWER POTENTIAL OBJECTS THAN LOCATIONS... ARE NANS RETURNED?
%     if isempty(scores)
%         labels(i,:) = nan;
%     else
%         labels(i,:) = getBestLabels(scores, objectNum, wasOccluded);
%     end
%     
% 
%     % only keep labeled locations
%     for j = paws %1:objectNum
%         if isnan(labels(i,j))
%             locationsTop.x(i,j) = nan;
%             locationsTop.z(i,j) = nan;
%         else
%             locationsTop.x(i,j) = potentialLocationsTop(i).x(labels(i,j));
%             locationsTop.z(i,j) = potentialLocationsTop(i).y(labels(i,j));
%         end
%         
% %         % if paw is in stance (negative velocity) make z location directly above the circle floor
% %         if locationsBot.xVel(i,j) < stanceVelDif && (abs(obsPixPositions(i) - locationsBot.x(i,j)) > obsProximity || isnan(obsPixPositions(i)))
% %             locationsTop.x(i,j) = locationsBot.x(i,j);
% %             locationsTop.z(i,j) = wheelCenter(2) - round(sqrt(wheelRadius^2 - (locationsBot.x(i,j)-wheelCenter(1))^2)); % !!! should replace this with pre-computed lookup table
% %         end
%     end
% end



