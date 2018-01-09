function locationsBot = getLocationsBot(potentialLocationsBot, frameTimeStamps, frameWid, frameHgt, frameInds)

% !!! need to document


% settings
objectNum = 4;
anchorPts = {[0 0], [0 1], [1 0], [1 1]}; % LH, RH, LF, RF (x, y)
maxDistanceX = .6;    % x coordinates can only be this far away from the x anchor points (expressed as percentage of frame width)
maxDistanceY = .65;
maxVel = 30 / .004;    % pixels / sec

unaryWeight = 2;
pairwiseWeight = 1;
minScore = .5 * (unaryWeight + pairwiseWeight); % location scores lower than minScores are set to zero (this way an object prefers occlusion to being assigned to a crummy location)
scoreWeight = 0;


% initializations
labels = nan(length(potentialLocationsBot), objectNum);
locationsBot.x = nan(length(potentialLocationsBot), objectNum);
locationsBot.y = nan(length(potentialLocationsBot), objectNum);


% iterate through remaining frames

for i = frameInds(1:end)
    
    % report progress
    disp(i/length(potentialLocationsBot))
    
    
    % get unary and pairwise potentials
    unaries = nan(objectNum, length(potentialLocationsBot(i).x));
    pairwise = ones(objectNum, length(potentialLocationsBot(i).x));
    wasOccluded = zeros(1, objectNum);
    
    for j = 1:objectNum
        
        % unary
        unaries(j,:) = getUnaryPotentials(potentialLocationsBot(i).x, potentialLocationsBot(i).y,...
            frameWid, frameHgt, anchorPts{j}(1), anchorPts{j}(2), maxDistanceX, maxDistanceY);
        
        % pairwise
        if i>frameInds(1)
            
            % get ind of last detection frame for object j
            if ~isnan(labels(i-1, j)) 
                prevFrame = i-1;
            else
                prevFrame = find(~isnan(labels(:,j)), 1, 'last');
                wasOccluded(j) = 1;
            end

            % get label at last dection frame
            prevLabel = labels(prevFrame, j);
            
            % get pairwise scores
            pairwise(j,:) = getPairwisePotentials(potentialLocationsBot(i).x, potentialLocationsBot(i).y,...
                potentialLocationsBot(prevFrame).x(prevLabel), potentialLocationsBot(prevFrame).y(prevLabel),...
                frameTimeStamps(i)-frameTimeStamps(prevFrame), maxVel);
        end
    end
    
    
    % get svm scores for potential locations
    svmScores = repmat(potentialLocationsBot(i).scores', objectNum, 1);
    
    
    % get final scores for each potential location for each paw
    scores = unaryWeight.*unaries + pairwiseWeight.*pairwise + scoreWeight.*svmScores;
    scores(unaries==0 | pairwise==0) = 0;
    scores(scores<minScore) = 0;

    
    % find best labels (find labels for all paws that maximizes overall score)
    if ~isempty(scores)
        labels(i,:) = getBestLabels(scores, objectNum, wasOccluded);
    end
    
    
    % only keep labeled locations
    for j = 1:objectNum
        if ~isnan(labels(i,j))
            locationsBot.x(i,j) = potentialLocationsBot(i).x(labels(i,j));
            locationsBot.y(i,j) = potentialLocationsBot(i).y(labels(i,j));
        end
    end
end





