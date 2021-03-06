function plotTrajectories2(data, bins, binLabels, plotType)




% global settings
azimuth = -10;
elevation = 10;
projectionDarkening = .6;
obsThickness = .003;
obsHeight = .009;
colors = [.25 1 1; .25 1 .25];
controlColor = repmat(0, 1, 3);
kinWidthPortion = .8;
kinematicsHistoSeparation = .02;
showPredictedLocations = true;
sidePadding = .02;

% kinematic plot settings
xLims = [-.1 .04];
yLims = [-0.0381 0.0381]; % 3 inches, which is width of wheel
zLims = [0 .015];
scaleBarSize = .01;
circSize = 150;
lineWid = 3;
tracesPerPlot = 8;

% histogram settings
yLimsHisto = [0 .15];
xLimsHisto = [-.06 .06];
xRes = .001;
gausKernelSig = .004; % (m)
transparency = .4;



% initializations
obsX = [0 obsThickness]-.5*obsThickness;
obsY = yLims;
obsZ = [0 obsHeight];

if showPredictedLocations
     predictedLocations = [data.swingStartDistance] + [data.predictedLengths]; % predicted distance to obs
end
binNum = max(bins);
deltaLengths = cellfun(@(x) x(1,3), {data.modifiedSwingLengths}) - [data.predictedLengths];
deltaControlLengths = cellfun(@(x) x(2,3), {data.controlSwingLengths}) - [data.predictedControlLengths];
numModSteps = reshape([data.modStepNum],4,length(data))';

kernel = arrayfun(@(x) (1/(gausKernelSig*sqrt(2*pi))) * exp(-.5*(x/gausKernelSig)^2), ...
    -gausKernelSig*5:xRes:gausKernelSig*5);
kernel = kernel / sum(kernel);
deltaBinCenters = min(min(deltaLengths)-2*gausKernelSig, xLimsHisto(1)) : xRes : max(max(deltaLengths)+2*gausKernelSig, xLimsHisto(2));
deltaBinEdges = [deltaBinCenters deltaBinCenters(end)+xRes] - .5*xRes;

vertices = [obsX(1) obsY(1) obsZ(1)
            obsX(1) obsY(2) obsZ(1)
            obsX(1) obsY(2) obsZ(2)
            obsX(1) obsY(1) obsZ(2)
            obsX(2) obsY(1) obsZ(1)
            obsX(2) obsY(2) obsZ(1)
            obsX(2) obsY(2) obsZ(2)
            obsX(2) obsY(1) obsZ(2)];
% specify which corners to connect for each of 6 faces (6 sides of obs)
faces = [1 2 3 4
         5 6 7 8
         1 2 6 5
         4 3 7 8
         2 6 7 3
         1 5 8 4];

kinematicsWidth = (1-2*sidePadding-kinematicsHistoSeparation) * kinWidthPortion;
histoWidth = (1-2*sidePadding-kinematicsHistoSeparation) * (1-kinWidthPortion);

close all
figure('color', 'white', 'menubar', 'none', 'position', [100 25 900 1000], 'InvertHardcopy', 'off');

% plot PDFs
for h = 1:binNum

    ax = subaxis(binNum, 2, h*2);
    binBins = (bins==h)';
    oneStepBins = binBins & numModSteps(:,3)==1;
    twoStepBins = binBins & numModSteps(:,3)==2;
    oneTwoRatio = sum(oneStepBins) / (sum(oneStepBins) + sum(twoStepBins));

    % control histo
    binCounts = histcounts(deltaControlLengths(binBins), deltaBinEdges);
    histoConv = conv(binCounts, kernel, 'same');
    histoConv = (histoConv/sum(histoConv));
    shadedErrorBar(deltaBinCenters, histoConv, cat(1, histoConv, zeros(1,length(histoConv))), ...
            'lineprops', {'linewidth', 3, 'color', controlColor}, ...
            'patchSaturation', 1-transparency); hold on;
        
    % one step histo
    if any(oneStepBins)
        binCounts = histcounts(deltaLengths(oneStepBins), deltaBinEdges);
        histoConv = conv(binCounts, kernel, 'same');
        histoConv = (histoConv/sum(histoConv)) * oneTwoRatio;
        shadedErrorBar(deltaBinCenters, histoConv, cat(1, histoConv, zeros(1,length(histoConv))), ...
            'lineprops', {'linewidth', 3, 'color', colors(2,:)}, ...
            'patchSaturation', 1-transparency); hold on;
    end

    % two step histo
    binCounts = histcounts(deltaLengths(twoStepBins), deltaBinEdges);
    histoConv = conv(binCounts, kernel, 'same');
    histoConv = (histoConv/sum(histoConv)) * (1-oneTwoRatio);
    shadedErrorBar(deltaBinCenters, histoConv, cat(1, histoConv, zeros(1,length(histoConv))), ...
            'lineprops', {'linewidth', 3, 'color', colors(1,:)}, ...
            'patchSaturation', 1-transparency); hold on;

    % set apearance
    axPos = get(gca, 'position'); axPos(1) = sidePadding+kinematicsWidth+kinematicsHistoSeparation; axPos(3) = histoWidth;
    set(ax, 'box', 'off', 'xlim', xLimsHisto, 'ylim', yLimsHisto, 'tickdir', 'out', ...
        'xtick', [-abs(min(xLimsHisto))*.5 0 abs(min(xLimsHisto))*.5], 'position', axPos, 'ticklength', [0.04 0.025]);
    ax.YAxis.Visible = 'off';
    if h==binNum; xlabel('\Delta swing length (m)'); end
end








% plot trial trajectories
if strcmp(plotType, 'trials')

    % initializations
    modStepNum = cellfun(@(x) x(1,3), {data.modStepNum});
    
    for h = 1:binNum

        subaxis(binNum, 2, h*2-1);
        if showPredictedLocations
            line(repmat(mean(predictedLocations(bins==h)),1,2), yLims, [0 0], ...
                'color', [0 0 0], 'linewidth', 3, 'linestyle', ':'); hold on; % add line for predicted landing locations
        end


        % get inds for one and two step trials within bin
        % (making sure the number of trials of each type reflects the proportion of each type across all trials)
        binBins = (bins==h);
        oneStepPortion = sum(modStepNum(binBins)==1) / sum(binBins);
        oneTwoStepTrialNums = [round(tracesPerPlot*oneStepPortion) round(tracesPerPlot*(1-oneStepPortion))];

        if oneTwoStepTrialNums(1)>0
            oneStepInds = find(binBins & modStepNum==1);
            oneStepInds = oneStepInds(randperm(length(oneStepInds), oneTwoStepTrialNums(1)));
        else
            oneStepInds = [];
        end
        twoStepInds = find(binBins & modStepNum>1);
        twoStepInds = twoStepInds(randperm(length(twoStepInds), oneTwoStepTrialNums(2)));


        % plot individual trials
        for i = [oneStepInds twoStepInds]
            for j = 3 %2:3

                % plot x and y trajectories
                locationInds = data(i).modifiedStepIdentities(:,j)==1;
                x = data(i).locations(locationInds,1,j);
                y = data(i).locations(locationInds,2,j);
                z = data(i).locations(locationInds,3,j);
                
                if data(i).modStepNum(1,j)~=1; colorInd=1; else; colorInd=2; end
                plot3(x, y, z, 'color', colors(colorInd,:), 'linewidth', 1.5); hold on
                plot3(x, ones(1,length(y))*yLims(1), z, 'color', colors(colorInd,:)*projectionDarkening, 'linewidth', 1.5); hold on

                % scatter dots at start of each swing
%                 scatter3(x(end), y(end), z(end), 100, colors(colorInd,:), 'filled'); hold on
% 
%                 % scatter position of swing foot at obsPos
%                 if j==3
%                     scatter3(data(i).locations(data(i).obsPosInd,1,j), ...
%                              data(i).locations(data(i).obsPosInd,2,j), ...
%                              data(i).locations(data(i).obsPosInd,3,j), ...
%                              100, colors(colorInd,:), 'x'); hold on
%                 end
            end
        end
        
        % add obstacle
        patch('Vertices', vertices, 'Faces', faces);
        
        % add lines for sides of wheel
        line([xLims; xLims]', [yLims; yLims], zeros(2,2), ...
            'color', [0 0 0], 'linewidth', 2) % x1


        % get right control locations
        controlLocations = cellfun(@(x) x{3}(end,:,:), ...
            {data(binBins).controlLocationsInterp}, 'uniformoutput', 0); % only take last control step
        controlLocations = cat(1,controlLocations{:});

        % get x offset (mean starting x pos of modified steps)
        modLocations = cellfun(@(x) x{3}(1,:,:), {data(binBins).modifiedLocationsInterp}, 'uniformoutput', 0);
        modLocations = cat(1,modLocations{:});
        xOffset = mean(squeeze(modLocations(:,1,1)));

        x = squeeze(controlLocations(:,1,:));
        x = x - (mean(x(:,1)) - xOffset);
        y = squeeze(controlLocations(:,2,:));
        z = squeeze(controlLocations(:,3,:));
        plot3(mean(x,1), mean(y,1), mean(z,1), 'color', controlColor, 'linewidth', lineWid); hold on;
        plot3(mean(x,1), ones(1,size(y,2))*yLims(1), mean(z,1), 'color', controlColor*projectionDarkening, 'linewidth', lineWid); hold on;




        % set appearance
        daspect([1 1 1]);
        axPos = get(gca, 'position'); % axPos(2) = histoHgt+botPadding; axPos(4) = (1-(histoHgt+botPadding)-topPadding);
        axPos(1) = sidePadding; axPos(3) = kinematicsWidth;
        set(gca, 'xlim', xLims, 'ylim', yLims, 'zlim', zLims, ...
            'position', axPos, 'view', [azimuth elevation], 'YDir', 'reverse');
        axis off
    %     xlabel(['predicted dist to obs (m): ' binLabels{h}]);
    end
    
    
% plot average trajectories
elseif strcmp(plotType, 'averages')
    
    % initializations
    obsPosIndInterps = cellfun(@(x) x(1,3), {data.pawObsPosIndInterp});


    for h = 1:binNum

        % get subplot bins
        subaxis(binNum, 2, h*2-1);
        if showPredictedLocations
            line(repmat(mean(predictedLocations(bins==h)),1,2), yLims, [0 0], ...
                'color', [0 0 0], 'linewidth', 3, 'linestyle', ':'); hold on; % add line for predicted landing locations
        end
        
        % get subplot bins for different conditions
        binBins = (bins==h)';
        controlBins = binBins;
        leftModBins = binBins & numModSteps(:,2)==1;
        rightModOneStepBins = binBins & (numModSteps(:,3)==1);
        rightModTwoStepBins = binBins & (numModSteps(:,3)==2);
        oneTwoRatio = sum(rightModOneStepBins) / (sum(rightModOneStepBins) + sum(rightModTwoStepBins)); % ratio of trials in which swing foot takes one large step to those in which an additional step is taken
        oneTwoRatio = oneTwoRatio * 2 - 1; % scale from -1 to 1


        % get left and right control locations
        controlLocations = {data(controlBins).controlLocationsInterp};
%         leftControlLocations = cellfun(@(x) x{2}(end,:,:), controlLocations, 'uniformoutput', 0);
%         leftControlLocations = cat(1,leftControlLocations{:});
        rightControlLocations = cellfun(@(x) x{3}(end,:,:), controlLocations, 'uniformoutput', 0);
        rightControlLocations = cat(1,rightControlLocations{:});

        % get left modified locations
%         leftModLocations = {data(leftModBins).modifiedLocationsInterp};
%         leftModLocations = cellfun(@(x) x{2}, leftModLocations, 'uniformoutput', 0);
%         leftModLocations = cat(1,leftModLocations{:});

        % get right modified (one step) locations
        rightModOneStepLocations = {data(rightModOneStepBins).modifiedLocationsInterp};
        rightModOneStepLocations = cellfun(@(x) x{3}, rightModOneStepLocations, 'uniformoutput', 0);
        rightModOneStepLocations = cat(1,rightModOneStepLocations{:});

        % get right modified (two step) locations
        rightModTwoStepLocations = {data(rightModTwoStepBins).modifiedLocationsInterp};
        rightModTwoStepLocations = cellfun(@(x) x{3}(1,:,:), rightModTwoStepLocations, 'uniformoutput', 0);
        rightModTwoStepLocations = cat(1,rightModTwoStepLocations{:});

        % get left and right x offsets
%         modLocations = cellfun(@(x) x{2}(1,:,:), {data(binBins).modifiedLocationsInterp}, 'uniformoutput', 0);
%         modLocations = cat(1,modLocations{:});
%         xOffsetLeft = mean(squeeze(modLocations(:,1,1)));
        modLocations = cellfun(@(x) x{3}(1,:,:), {data(binBins).modifiedLocationsInterp}, 'uniformoutput', 0);
        modLocations = cat(1,modLocations{:});
        xOffsetRight = mean(squeeze(modLocations(:,1,1)));


%         % plot control left
%         x = squeeze(leftControlLocations(:,1,:));
%         x = x - (mean(x(:,1)) - xOffsetLeft);
%         y = squeeze(leftControlLocations(:,2,:));
%         plot(mean(y,1), mean(x,1), 'color', controlColor, 'linewidth', lineWid); hold on;
% 
%         % plot control right
        x = squeeze(rightControlLocations(:,1,:));
        x = x - (mean(x(:,1)) - xOffsetRight);
        y = squeeze(rightControlLocations(:,2,:));
        z = squeeze(rightControlLocations(:,3,:));
        plot3(mean(x,1), mean(y,1), mean(z,1), 'color', controlColor, 'linewidth', lineWid); hold on;
%         plot3(mean(x,1), ones(1,size(y,2))*yLims(1), mean(z,1), ...
%             'color', controlColor*projectionDarkening, 'linewidth', lineWid); hold on;

        % plot mod left
%         x = squeeze(leftModLocations(:,1,:));
%         y = squeeze(leftModLocations(:,2,:));
%         plot(mean(y,1), mean(x,1), 'color', colors(2,:), 'linewidth', lineWid); hold on;

        % plot mod right, one step
        if ~isempty(rightModOneStepLocations)
            x = squeeze(rightModOneStepLocations(:,1,:));
            y = squeeze(rightModOneStepLocations(:,2,:));
            z = squeeze(rightModOneStepLocations(:,3,:));
            plot3(mean(x,1), mean(y,1), mean(z,1), 'color', colors(2,:), 'linewidth', lineWid + oneTwoRatio*lineWid); hold on;
%             plot3(mean(x,1), ones(1,size(y,2))*yLims(1), mean(z,1), ...
%                 'color', colors(2,:)*projectionDarkening, 'linewidth', lineWid + oneTwoRatio*lineWid); hold on;
        end

        % plot mod right, two step
        if ~isempty(rightModTwoStepLocations)
            x = squeeze(rightModTwoStepLocations(:,1,:));
            y = squeeze(rightModTwoStepLocations(:,2,:));
            z = squeeze(rightModTwoStepLocations(:,3,:));
            plot3(mean(x,1), mean(y,1), mean(z,1), 'color', colors(1,:), 'linewidth', lineWid + -oneTwoRatio*lineWid); hold on;
%             plot3(mean(x,1), ones(1,size(y,2))*yLims(1), mean(z,1), ...
%                 'color', colors(1,:)*projectionDarkening, 'linewidth', lineWid + -oneTwoRatio*lineWid); hold on;
        end

        % mark avg position of obsPos
%         if any(rightModOneStepBins)
%             oneStepObsPos = round(mean(obsPosIndInterps(rightModOneStepBins)));
%             scatter(mean(squeeze(rightModOneStepLocations(:,2,oneStepObsPos))), ...
%                     mean(squeeze(rightModOneStepLocations(:,1,oneStepObsPos))), circSize + oneTwoRatio*circSize, colors(2,:), 'filled'); hold on
%         end
% 
%         if any(rightModTwoStepBins)
%             twoStepObsPos = round(nanmean(obsPosIndInterps(rightModTwoStepBins)));
%             scatter(mean(squeeze(rightModTwoStepLocations(:,2,twoStepObsPos))), ...
%                     mean(squeeze(rightModTwoStepLocations(:,1,twoStepObsPos))), circSize + -oneTwoRatio*circSize, colors(1,:), 'filled'); hold on
%         end

        % add obstacle
        patch('Vertices', vertices, 'Faces', faces);
        
        % add lines for sides of wheel
        line([xLims; xLims]', [yLims; yLims], zeros(2,2), ...
            'color', [0 0 0], 'linewidth', 2) % x1



        % set appearance
        daspect([1 1 1]);
        axPos = get(gca, 'position'); % axPos(2) = histoHgt+botPadding; axPos(4) = (1-(histoHgt+botPadding)-topPadding);
        axPos(1) = sidePadding; axPos(3) = kinematicsWidth;
        set(gca, 'xlim', xLims, 'ylim', yLims, 'zlim', zLims, ...
            'position', axPos, 'view', [azimuth elevation], 'YDir', 'reverse');
        axis off
    end
end






% add scale bar
% line([xLims(2)-scaleBarSize xLims(2)], repmat(yLims(2),1,2)-.02, 'linewidth', 3, 'color', 'black')
% text(xLims(2)-.5*scaleBarSize, yLims(2)-.02+.005, sprintf('%i mm', scaleBarSize*1000), 'horizontalalignment', 'center')

blackenFig;
saveas(gcf, [getenv('OBSDATADIR') 'figures\trialKinematics.png']);
savefig([getenv('OBSDATADIR') 'figures\trialKinematics.fig'])
print('-clipboard', '-dmeta')






