sessions = {'180607_000', '180607_001', '180607_002', '180607_003', '180607_004', '180607_005'};
vidDir = 'C:\Users\rick\Desktop\trainingExamples\leap\trainingSet2\';
framesPerVid = 1000;
outputDims =[404 396];

prepareTrainingVidsForLeap(sessions, vidDir, framesPerVid, outputDims)