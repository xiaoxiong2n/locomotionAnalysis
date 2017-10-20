function spikeAnalysis2(dataDir, varsToOverWrite)

    % performs preliminary analysis on spike data and save in runAnalyzed.mat
    % !!! should add a way of ensuring that correct variables exist in run.csv before attempting to load them!


    % settings
    targetFs = 1000; % frequency that positional data will be resampled to
    minRewardInteveral = 1;

    % rig characteristics
    whEncoderSteps = 2880; % 720cpr * 4
    wheelRad = 95.25; % mm
    obEncoderSteps = 1000; % 250cpr * 4
    obsRad = 96 / (2*pi); % radius of timing pulley driving belt of obstacles platform

    % if no variables to overwrite are specified, set to default
    if nargin==1
        varsToOverWrite = {' '};
    end

    % find all data folders in dataDir
    dataFolders = dir(dataDir);
    dataFolders = dataFolders(3:end); % remove current and parent directory entries
    dataFolders = dataFolders([dataFolders.isdir]); % keep only folders




    % iterate over data folders and analyze those that have not been analyzed
    for i = 1:length(dataFolders)

        
        % load or initialize data structure
        sessionDir = [dataDir '\' dataFolders(i).name '\'];
        
        if exist([sessionDir 'runAnalyzed.mat'], 'file')
            varStruct = load([sessionDir 'runAnalyzed.mat']);
        else
            varStruct = struc();
        end
        varNames = fieldnames(varStruct);
        


        % analyze reward times
        if analyzeVar('rewardTimes', varNames, varsToOverWrite)
            
            fprintf('%s: getting reward times\n', dataFolders(i).name)
            load([sessionDir 'run.mat'], 'reward')
                        
            % find reward times
            rewardInds = logical([0; find(diff(reward.values>2)==1)]);
            rewardTimes = reward.times(rewardInds);

            % remove reward times occuring within minRewardInteveral seconds of eachother
            rewardTimes = rewardTimes(logical([diff(rewardTimes) > minRewardInteveral; 1]));

            % save values
            varStruct.rewardTimes = rewardTimes;
        end
        
        
        
        
        % decode stepper motor commands
        if analyzeVar('motorPositions', varNames, varsToOverWrite) ||...
           analyzeVar('motorTimes', varNames, varsToOverWrite)
            
            load([sessionDir 'run.mat'], 'step', 'stepDir')
            
            % decode stepper motor
            if ~isempty(stepDir.times)
                fprintf('%s: decoding stepper motor commands\n', dataFolders(i).name)
                [motorPositions, motorTimes] = motorDecoder(stepDir.level, stepDir.times, step.times, targetFs);
            else
                motorPositions = [];
                motorTimes = [];
            end
            
            % save values
            varStruct.motorPositions = motorPositions;
            varStruct.motorTimes = motorTimes;
            varStruct.targetFs = targetFs;
        end
        
        
        
        
        % decode obstacle position (based on obstacle track rotary encoder)
        if analyzeVar('obsPositions', varNames, varsToOverWrite) ||...
           analyzeVar('obsTimes', varNames, varsToOverWrite)
            
            load([sessionDir 'run.mat'], 'obEncodA', 'obEncodB')
            
            if ~isempty(obEncodA.times)
                fprintf('%s: decoding obstacle position\n', dataFolders(i).name)
                [obsPositions, obsTimes] = rotaryDecoder(obEncodA.times, obEncodA.level,...
                                                             obEncodB.times, obEncodB.level,...
                                                             obEncoderSteps, obsRad, targetFs);
            else
                obsPositions = [];
                obsTimes = [];
            end
            
            % save values
            varStruct.obsPositions = obsPositions;
            varStruct.obsTimes = obsTimes;
            varStruct.targetFs = targetFs;
        end
        
        
        
        
        % decode wheel position
        if analyzeVar('wheelPositions', varNames, varsToOverWrite) ||...
           analyzeVar('wheelTimes', varNames, varsToOverWrite)
            
            fprintf('%s: decoding wheel position\n', dataFolders(i).name)
            load([sessionDir 'run.mat'], 'whEncodA', 'whEncodB')
            
            [wheelPositions, wheelTimes] = rotaryDecoder(whEncodA.times, whEncodA.level,...
                                                         whEncodB.times, whEncodB.level,...
                                                         whEncoderSteps, wheelRad, targetFs);
            % save values
            varStruct.wheelPositions = wheelPositions;
            varStruct.wheelTimes = wheelTimes;
            varStruct.targetFs = targetFs;
        end
        
        
        
        
        % get obstacle on and off times
        % (ensuring that first event is obs turning ON and last is obs turning OFF)
        if analyzeVar('obsOnTimes', varNames, varsToOverWrite) ||...
           analyzeVar('obsOffTimes', varNames, varsToOverWrite)
       
            fprintf('%s: getting obstacle on and off times\n', dataFolders(i).name)
            load([sessionDir 'run.mat'], 'obsOn')
       
            firstOnInd  = find(obsOn.level, 1, 'first');
            lastOffInd  = find(~obsOn.level, 1, 'last');
            
            obsOn.level = obsOn.level(firstOnInd:lastOffInd);
            obsOn.times = obsOn.times(firstOnInd:lastOffInd);
            
            obsOnTimes  =  obsOn.times(logical(obsOn.level));
            obsOffTimes = obsOn.times(logical(~obsOn.level));
            
            % save values
            varStruct.obsOnTimes = obsOnTimes;
            varStruct.obsOffTimes = obsOffTimes; 
        end
        
        
        
        
        % get frame timeStamps
        if analyzeVar('frameTimeStamps', varNames, varsToOverWrite)
            
            if exist([sessionDir 'run.csv'], 'file')
                
                fprintf('%s: getting frame time stamps\n', dataFolders(i).name)
                load([sessionDir '\run.mat'], 'exposure')

                % get camera metadata and spike timestamps
                camMetadata = dlmread([sessionDir '\run.csv']); % columns: bonsai timestamps, point grey counter, point grey timestamps (uninterpretted)
                frameCounts = camMetadata(:,2);
                timeStampsFlir = timeStampDecoderFLIR(camMetadata(:,3));

                if length(exposure.times) >= length(frameCounts)
                    frameTimeStamps = getFrameTimes(exposure.times, timeStampsFlir, frameCounts);
                else
                    disp('  there are more frames than exposure TTLs... saving frameTimeStamps as empty vector')
                    frameTimeStamps = [];
                end
                
                % save values
                varStruct.frameTimeStamps = frameTimeStamps;
            end
        end
        
        
        
        
        % get webCam timeStamps if webCam data exist
        if analyzeVar('webCamTimeStamps', varNames, varsToOverWrite)
            
            if exist([sessionDir 'webCam.csv'], 'file') &&...
               exist([sessionDir 'run.csv'], 'file') &&...
               any(strcmp(varNames, 'frameTimeStamps'))
                
                fprintf('%s: getting webcam time stamps\n', dataFolders(i).name)
                
                % load data
                camMetadata = dlmread([sessionDir '\run.csv']);
                camSysClock = camMetadata(:,1) / 1000;
                camSpikeClock = varStruct.frameTimeStamps;
                webCamSysClock = dlmread([sessionDir '\webCam.csv']) / 1000; % convert from ms to s

                % remove discontinuities
                webCamTimeSteps = cumsum([0; diff(webCamSysClock)<0]);
                webCamSysClock = webCamSysClock + webCamTimeSteps;
                webCamSysClock = webCamSysClock - webCamSysClock(1); % set first time to zero

                camTimeSteps = cumsum([0; diff(camSysClock)<0]);
                camSysClock = camSysClock + camTimeSteps;
                camSysClock = camSysClock - camSysClock(1); % set first time to zero


                % determine spike clock times from system clock times
                validInds = ~isnan(camSpikeClock);
                sysToSpike = polyfit(camSysClock(validInds), camSpikeClock(validInds), 1);
                webCamSpikeClock = webCamSysClock * sysToSpike(1) + sysToSpike(2);

                % save
                varStruct.webCamTimeStamps = webCamSpikeClock;
            end
        end
        
        
        
        
        % save results
        save([sessionDir 'runAnalyzed.mat'], '-struct', 'varStruct')
        fprintf('----------\n')
    end
    
    
    
    
    % ---------
    % FUNCTIONS
    % ---------
    
    function analyze = analyzeVar(var, varNames, varsToOverWrite)

        analyze = ~any(strcmp(varNames, var)) || any(strcmp(varsToOverWrite, var));
        
    end
end

