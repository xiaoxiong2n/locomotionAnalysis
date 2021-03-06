function makeLabeledSet(className, imNumbers, egsPerFrame, file, subHgtWid)

    % !!! need to document
    
    
    % user settings
    dataDir = 'C:\Users\rick\Google Drive\columbia\obstacleData\svm\trainingImages\';
    startPosits = [40 70; 40 100; 50 70; 50 100];
    negativeEgsPerEg = 15;
    negEgOverlap = 1; % allow negative examples to overlap by at most this much with the positive examples
    negEgOffset = .5;
    
    % initializations
    negImNumbers = (imNumbers(1)-1)*negativeEgsPerEg+1:imNumbers(end)*negativeEgsPerEg; % indices of negative examples
    imNumberInd = 1;
    negImNumberInd = 1;
    pixPerEg = subHgtWid(1) * subHgtWid(2);
    
    % load video and sample frame
    vid = VideoReader(file);
    frame = rgb2gray(read(vid,1));
    bg = getBgImage(vid, 1000, true);
   
    % prepare figure
    close all;
    myFig = figure('units', 'normalized', 'outerposition', [0 .1 1 .9], 'keypressfcn', @keypress);
    rawAxis = subaxis(2,egsPerFrame,1:egsPerFrame, 'margin', .01', 'spacing', .01);
    rawPreview = imshow(getFeatures(frame), 'parent', rawAxis);
    circs = viscircles(gca, [0 0], 5);
    
    % for each sub frame create axes, previews, and rectangles
    for i=1:egsPerFrame
        subFrames(i).axis = subaxis(2,egsPerFrame,egsPerFrame+i);
        subFrames(i).rect = imrect(rawAxis, [startPosits(i,2) startPosits(i,1) subHgtWid(2)-1, subHgtWid(1)-1]);
        pos = getPosition(subFrames(i).rect);
        subFrames(i).img = frame(pos(2):pos(2)+pos(4), pos(1):pos(1)+pos(3),:);
        subFrames(i).preview = imshow(subFrames(i).img, 'parent', subFrames(i).axis);
        addNewPositionCallback(subFrames(i).rect, @updateSubPreviews);
    end
    
    % make training set!
    while imNumberInd<=length(imNumbers)
        
        % get random frame and allow user to move rectangles around
        frame = rgb2gray(read(vid,randi(vid.numberofframes)));
        frame = frame - bg;
        set(rawPreview, 'CData', getFeatures(frame));
        updateSubPreviews();
        
        % wait for user to press enter
        stillGoing = true;
        while stillGoing; waitforbuttonpress; end
        disp(imNumberInd)
    end
    
    close all
    
    
    
    
    % ---------
    % FUNCTIONS
    % ---------
    
    function keypress(~,~)
        
        % save positive and create/save negative examples when ENTER is pressed
        key = double(get(myFig, 'currentcharacter'));
        
        if ~isempty(key) && isnumeric(key)
            if key==13
                stillGoing = false;
                
                % create mask of locations of positive examples
                egsMask = logical(zeros(size(frame,1), size(frame,2)));
                
                for j=1:egsPerFrame
                    pos = round(getPosition(subFrames(j).rect));
                    egsMask(pos(2):pos(2)+pos(4), pos(1):pos(1)+pos(3)) = 1;
                end
                
                negEgPos = nan(0,2);
                
                
                % save positive and create negative examples
                for j=1:egsPerFrame
                    
                    img = subFrames(j).img;
                    save([dataDir className '\positive\img' num2str(imNumbers(imNumberInd)) '.mat'], 'img');
                    imNumberInd = imNumberInd+1;
                    
                    % create/save negative examples for every positive example
                    for k=1:negativeEgsPerEg
                        
                        % find a frame that doesn't overlap with positive examples
                        acceptableImage = false;
                        while ~acceptableImage 
                            pos = [randi(size(frame,1)-subHgtWid(1)) randi(size(frame,2)-subHgtWid(2))]; % y,x
                            posMask = logical(zeros(size(frame,1), size(frame,2)));
                            posMask(pos(1):pos(1)+subHgtWid(1), pos(2):pos(2)+subHgtWid(2)) = 1;
%                             keyboard
                            pixelsOverlap = sum(egsMask(:)+posMask(:)>1);
                            img = frame(pos(1):pos(1)+subHgtWid(1)-1, pos(2):pos(2)+subHgtWid(2)-1,:);

%                             if pixelsOverlap<(pixPerEg*negEgOverlap) && mean(img(:))>5; acceptableImage=true; end
                            if pixelsOverlap==0 && mean(img(:))>5; acceptableImage=true; end
                        end
                        
                        % try replacing negative egs with negative egs adjacent to positive eg
%                         if k<=8
%                             
%                             positivePos = round(getPosition(subFrames(j).rect));
%                             posTemp = round([positivePos(2) positivePos(1)]); % this value will be adjusted below
%                             % get negative eg position
%                             switch k
%                                 case 1
%                                     posTemp = posTemp + round([-subHgtWid(1) -subHgtWid(2)] .* negEgOffset);
%                                 case 2
%                                     posTemp = posTemp + round([0 -subHgtWid(2)] .* negEgOffset);
%                                 case 3
%                                     posTemp = posTemp + round([subHgtWid(1) -subHgtWid(2)] .* negEgOffset);
%                                 case 4
%                                     posTemp = posTemp + round([subHgtWid(1) 0] .* negEgOffset);
%                                 case 5
%                                     posTemp = posTemp + round([subHgtWid(1) subHgtWid(2)] .* negEgOffset);
%                                 case 6
%                                     posTemp = posTemp + round([0 subHgtWid(2)] .* negEgOffset);
%                                 case 7
%                                     posTemp = posTemp + round([-subHgtWid(1) subHgtWid(2)] .* negEgOffset);
%                                 case 8
%                                     posTemp = posTemp + round([-subHgtWid(1) 0] .* negEgOffset);
%                             end
%                             
%                             try
%                                 % determine whether positiion overlaps with a positive example
%                                 posMask = logical(zeros(size(frame,1), size(frame,2)));
%                                 posMask(posTemp(1):posTemp(1)+subHgtWid(1), posTemp(2):posTemp(2)+subHgtWid(2)) = 1;
%                                 pixelsOverlap = sum(egsMask(:)+posMask(:)>1);
%                                 imgTemp = frame(pos(1):pos(1)+subHgtWid(1)-1, pos(2):pos(2)+subHgtWid(2)-1,:);
% 
%                                 if pixelsOverlap <= (pixPerEg*negEgOffset*1.1) && mean(imgTemp(:))>5
%                                     pos = posTemp;
%                                     img = imgTemp;
%                                 end
%                             catch
%                                 disp('subframe out of range')
%                             end
%                         end

                        % save negative example
                        save([dataDir className '\negative\img' num2str(negImNumbers(negImNumberInd)) '.mat'], 'img');
                        negImNumberInd = negImNumberInd+1;
                        negEgPos(end+1,:) = fliplr(pos+.5*subHgtWid);
                    end
                end
                circs = viscircles(rawAxis, negEgPos, ones(1,size(negEgPos,1))*.5*mean(subHgtWid));
                waitforbuttonpress; delete(circs)
            
            % if the letter 'n' is pressed, select new random frame
            elseif key==110
                frame = rgb2gray(read(vid,randi(vid.numberofframes)));
                frame = frame - bg;
                set(rawPreview, 'CData', getFeatures(frame));
                updateSubPreviews();
            end
        end
    end


    function updateSubPreviews(~,~)
        
        for j=1:egsPerFrame
            pos = round(getPosition(subFrames(j).rect));
            subFrames(j).img = frame(pos(2):pos(2)+pos(4), pos(1):pos(1)+pos(3),:);
            set(subFrames(j).preview, 'CData', getFeatures(subFrames(j).img));
        end
    end
end






