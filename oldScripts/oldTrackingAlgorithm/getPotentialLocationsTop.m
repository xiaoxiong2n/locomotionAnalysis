function potentialLocationsTop = getPotentialLocationsTop(vid, locationsBot,...
    model1, model2, classNum, subFrameSize1, subFrameSize2, scoreThresh, frameInds, showTracking)

% !!! need to document


% settings
overlapThresh = .6;
xMaskWidth = 40;


% initializations
xMaskHalfWidth = floor(xMaskWidth/2);
sampleFrame = rgb2gray(read(vid,1));
kernel = reshape(model1.Beta, subFrameSize1(1), subFrameSize1(2));
bg = getBgImage(vid, 1000, 120, 2*10e-4, false);
cmap = hsv(classNum);



% prepare figure
if showTracking

    figure('position', [680 144 698 834], 'menubar', 'none', 'color', 'black'); colormap gray

    rawAxis = subaxis(3,1,1, 'spacing', 0, 'margin', 0);
    rawIm = image(sampleFrame, 'parent', rawAxis, 'CDataMapping', 'scaled');
    set(gca, 'visible', 'off');
    hold on;
    hold on; scatterAll = scatter(rawAxis, 0, 0, 50, [1 1 1], 'filled');
    
    scatterPaws = cell(1, classNum); % shows results of second round of classification
    for i = 1:classNum
        hold on; scatterPaws{i} = scatter(rawAxis, 0, 0, 150, cmap(i,:), 'linewidth', 3);
    end
    
    maskAxis = subaxis(3,1,2, 'spacing', 0, 'margin', 0);
    maskIm = image(sampleFrame, 'parent', maskAxis, 'CDataMapping', 'scaled');
    set(gca, 'visible', 'off');
    
    predictAxis = subaxis(3,1,3, 'spacing', 0.01, 'margin', .01);
    predictIm = image(sampleFrame, 'parent', predictAxis, 'CDataMapping', 'scaled');
    set(gca, 'visible', 'off');
end


potentialLocationsTop(vid.NumberOfFrames) = struct();
w = waitbar(0, 'getting potentialLocationsTop...', 'position', [1500 50 270 56.2500]);
wInd = 0;

% copy isAnalyzed and trialIdentities fields to potentialLocationsTop
temp = mat2cell([locationsBot.isAnalyzed], ones(length(locationsBot.isAnalyzed),1), 1);
[potentialLocationsTop.isAnalyzed] = temp{:};
temp = mat2cell([locationsBot.trialIdentities], ones(length(locationsBot.trialIdentities),1), 1);
[potentialLocationsTop.trialIdentities] = temp{:};

for i = frameInds
    
    % get frame and subframes
    frame = rgb2gray(read(vid,i));
    frame = frame - bg;
        
    % filter with svm and apply non-maxima suppression
    frameFiltered = -(conv2(double(frame)/model1.KernelParameters.Scale, kernel, 'same') + model1.Bias);
    
    frameFiltered(frameFiltered < scoreThresh) = scoreThresh;
    frameFiltered = frameFiltered - scoreThresh;
    
    
    % mask x positions out of range
    xMask = double(zeros(size(frame)));
    
    for j = 1:4
        if ~isnan(locationsBot.locationsCorrected(i,1,j))
            
            % get mask indices for single paw
            inds = locationsBot.locationsCorrected(i,1,j)-xMaskHalfWidth : locationsBot.locationsCorrected(i,1,j)+xMaskHalfWidth;
            inds = round(inds);
            inds(inds<1) = 1;
            inds(inds>vid.Width) = vid.Width;
            
            % incorporate paw mask into mask
            xMask(:,inds) = 1;
        end
    end
    frameFiltered = frameFiltered .* xMask;
    
    [x, y, scores] = nonMaximumSupress(frameFiltered, subFrameSize1, overlapThresh);
    
    
    if ~isempty(x)
        
        % perform second round of classification (cnn)
        dims = model2.Layers(1).InputSize;
        frameFeatures = nan(dims(1), dims(2), 3, length(x));
        
        for j = 1:length(x)
            img = getSubFrame(frame, [y(j) x(j)], subFrameSize2);
            img = uint8(imresize(img, 'outputsize', model2.Layers(1).InputSize(1:2)));
            img = repmat(img, 1, 1, 3);
            frameFeatures(:,:,:,j) = img;
        end

        classes = uint8(classify(model2, frameFeatures));
        classProbs = predict(model2, frameFeatures);

        
        % store data
        potentialLocationsTop(i).x = x;
        potentialLocationsTop(i).z = y;
        potentialLocationsTop(i).scores = scores;
        potentialLocationsTop(i).class = classes;
        potentialLocationsTop(i).classProbabilities = classProbs;
    end
    
    
    if showTracking
        
        % put lines in top frame
        for j = 1:4
            if locationsBot.locationsRaw(i,1,j)>0 && locationsBot.locationsRaw(i,1,j)<vid.Width
                frame(:,locationsBot.locationsRaw(i,1,j)) = 255;
            end
        end
        
        % update figure
        set(rawIm, 'CData', frame);
        set(maskIm, 'CData', frame .* uint8(xMask));
        set(predictIm, 'CData', frameFiltered)
        set(scatterAll, 'XData', x, 'YData', y);
        
        for j=1:classNum
            set(scatterPaws{j}, 'XData', x(classes==j), 'YData', y(classes==j));
        end
        
        % pause to reflcet on the little things...
        pause(.2);
    end
    
    wInd = wInd+1;
    waitbar(wInd / length(frameInds))
end

close(w)




