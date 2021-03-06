% to try: make frame skipping inferface // smarter reappearance function?


% load tracking data
load('C:\Users\rick\Google Drive\columbia\obstacleData\svm\trackedData\tracked.mat', 'locations')

% user settings
vidFile = 'C:\Users\rick\Google Drive\columbia\obstacleData\svm\testVideo\runBot.mp4';

unaryWeight = 2;
pairwiseWeight = .1;
occludedWeight = .001;
occlusionGridSpacing = 30;
maxDistance = .8;

maxVelocity = 30;
paws = 1:4;
vidDelay = .02;

% initializations
frameHeight = 242; % !!! hacky temp
frameWidth = 398;
[gridX, gridY] = meshgrid(1:occlusionGridSpacing:frameWidth,...
                          1:occlusionGridSpacing:frameHeight);
gridPts = [gridX(:), gridY(:)];
numOccluded = size(gridPts,1);

tic

%% compute unary potentials
unary = cell(1,length(locations));

for i = 1:length(locations)

    % ensure first unaries are not zero (this will cause all paths to be zero for all time!)
    if (i==1 && unaryWeight==0)
        unaryWeightTemp = 1;
    else
        unaryWeightTemp = unaryWeight;
    end
    
    % don't enfore maxDistance for first frame
    if (i==1)
        maxDistanceTemp = 1;
    else
        maxDistanceTemp = maxDistance;
    end
    

    frameUnaries = nan(4, length(locations(i).x) + numOccluded);
    
    frameUnaries(1,1:end) = getUnaryPotentials(locations(i).x, locations(i).y, locations(i).scores, frameWidth, frameHeight, 0, .2, numOccluded, unaryWeightTemp, maxDistanceTemp); % RH
    frameUnaries(2,1:end) = getUnaryPotentials(locations(i).x, locations(i).y, locations(i).scores, frameWidth, frameHeight, 0, 1, numOccluded, unaryWeightTemp, maxDistanceTemp); % RF
    frameUnaries(3,1:end) = getUnaryPotentials(locations(i).x, locations(i).y, locations(i).scores, frameWidth, frameHeight, 1, .2, numOccluded, unaryWeightTemp, maxDistanceTemp); % LH
    frameUnaries(4,1:end) = getUnaryPotentials(locations(i).x, locations(i).y, locations(i).scores, frameWidth, frameHeight, 1, 1, numOccluded, unaryWeightTemp, maxDistanceTemp); % LF
        
    unary{i} = frameUnaries;
    
end



% compute pairwise potentials
pairwise = cell(1,length(locations)-1);

for i = 1:length(locations)-1
    
    pairwise{i} = getPairwisePotentials([locations(i+1).x, locations(i+1).y], [locations(i).x, locations(i).y],...
                                        maxVelocity, pairwiseWeight, occludedWeight, gridPts);
end



% find most probable paths!

% initializations
objectNum = size(unary{1}, 1);
labels = nan(length(unary), objectNum);
nodeScores = cell(1, length(unary));
backPointers = cell(1, length(unary)-1);
pathScores = nan(1,4);
nodeScores{1} = unary{1};


for i = 1:objectNum
    
    for j = 2:length(unary)
        
        % forward
        
        % initialize containers for first object only
        if i==1
            nodeScores{j}   = nan(objectNum, size(pairwise{j-1},1));
            backPointers{j-1} = nan(objectNum, size(pairwise{j-1},1));
        end
        
        previousScores = nodeScores{j-1}(i,:);
        currentUnary   = unary{j}(i,:)';
        
        allTransitionScores = repmat(previousScores, length(currentUnary), 1) + ...
                              repmat(currentUnary, 1, length(previousScores)) + ...
                              pairwise{j-1};
        
        % make invalid transitions impossible                      
        invalidInds = (pairwise{j-1}==0) |...
                      (repmat(previousScores, length(currentUnary), 1)==0);          
        allTransitionScores(invalidInds) = 0;
        
        % make transitions to locations with 0 unary potential impossible
        inds = find(currentUnary==0);
        allTransitionScores(inds<=length(locations(j).x), 1:length(locations(j-1).x)) = 0;
        
        % make transitions to previously occupied state impossible
        if i>1
            labelInds = labels(j-1,1:i-1);
            labelInds = labelInds( labelInds <= length(locations(j-1).x) ); % occluded locations can be multiply occupied
            allTransitionScores(:, labelInds) = 0;
        end
        
        
        [nodeScores{j}(i,:), backPointers{j-1}(i,:)] = max(allTransitionScores, [], 2);
%         backPointers{j-1}(i,:) = backPointers{j-1}(i,:) .* double(nodeScores{j}(i,:)>0);
    end
    
    % backward
    [pathScores(i), labels(end,i)] = max(nodeScores{end}(i,:));
    
    for j = fliplr(1:length(unary)-1) 
        labels(j,i) = backPointers{j}(i, labels(j+1,i));
    end
end


toc

%% visualize tracking
showTracking(VideoReader(vidFile), locations, labels, gridPts, vidDelay, paws);




