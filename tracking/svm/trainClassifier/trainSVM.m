function trainSVM(className)
    
    % user settings
    dataDir = 'C:\Users\rick\Google Drive\columbia\obstacleData\svm\trainingImages\';

    % compile examples and labels
    categories = {'negative', 'positive'};
    labels = [];
    
    for i = 1:length(categories)
        % load category data
        cat = cell2mat(categories(i));
        temp = dir([dataDir className '\' cat]); files = {temp.name}; files = files(3:end);
        load([dataDir className '\' cat '\' files{1}], 'imgTemp');

        % initialize storage variable on the first go-around
        if i==1; examples = nan(0, size(imgTemp,1), size(imgTemp,2), size(imgTemp,3)); end

        % get training examples
        for j = 1:length(files)
            load([dataDir className '\' cat '\' files{j}])
            examples(end+1,:,:,:) = imgTemp;
        end

        labels = vertcat(labels, ones(length(files),1)*i);
    end

   
    % get features from subFrames
    [~, tempVector] = getFeatures(squeeze(examples(1,:,:,:)));
    features = nan(size(examples,1), length(tempVector));
    
    for i=1:size(examples,1)
        [~, features(i,:)] = getFeatures(squeeze(examples(i,:,:,:)));
    end


    % TRAIN CLASSIFIER
    model = svmtrain(labels, features, '-t 0');
    model.w = model.sv_coef' * model.SVs;
    subHgt = size(imgTemp,1);
    subWid = size(imgTemp,2);
    uisave ({'model', 'subHgt', 'subWid'}, [dataDir 'classifier_' className '_' date '.mat']);
end
