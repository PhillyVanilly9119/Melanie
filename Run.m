%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% MAIN FILE for data processing pipeline of Ant. Eye Segmentation-Pipeline
%                               copyright:
%       @melanie.wuest@zeiss.com & @philipp.matten@meduniwien.ac.at
%
%   Center for Medical Physics and Biomedical Engineering (Med Uni Vienna)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Forward declarations and globals

% Add main path of repository of search path
warning("Change 'localGlobPath'-variable to your local path, were you keep the repository")
localGlobPath = 'C:\Users\ZEISS Lab\Documents\MATLAB\AnteriorEyeSegmentationPipeline';
addpath(fullfile(localGlobPath, 'Code'));

binFileOct = 'octDataCube.bin';
maskFolder = fullfile(localGlobPath, 'Data', 'SegmentedMasks');
a = 1024; %static for standard
b = 512;
c = 128;

%% 1) Preprocessing
% Check if a data stack is already in the workspace
if exist('octData', 'var')
    answer = questdlg('There is already a data set in the workspace. Would you like to load a new set?', ...
        'Load OCT data from image files', 'Yes', 'No', 'No');
    flag_ImageQualiyIsGood = 1;
    switch answer
        case 'Yes'
            disp('Loading new data set...')
            path = uigetdir();
            octData = loadOctImages(path, a, b, 'bmp');
        case 'No'
            octData = octData;
            %flag_Savedata = 0;
    end
    
else
    flag_ImageQualiyIsGood = 0;
    path = uigetdir();
    octData = loadOctImages(path, a, b, 'bmp');
    % Check if octDataCube.bin-file exists
    % -> if not: dialog for saving OCT volume in said *.bin-file
    if isfile(fullfile(localGlobPath, binFileOct))
        answer = questdlg('Would you like to save all images as a binary-file?', ...
            'Saving Options for OCT Images', 'Yes', 'No', 'No');
        switch answer
            case 'Yes'
                disp('Saving your data on same path as images were loaded from')
                flag_Savedata = 1;
            case 'No'
                disp('Data was not saved')
                flag_Savedata = 0;
        end
        if flag_Savedata == 1
            saveDataCubeAsBinFile(path, binFileOct, octData)
        end
    end
    
end

sz = size(octData);
temp = split(path, '\');
maskSubFolder = temp{end};

%% Display b-Scan
% bScan = octData(:,:,60);
% figure; imshow(bScan);

%% 2) Pre-segementation image-filter-options

if exist('flag_ImageQualiyIsGood', 'var') && ~flag_ImageQualiyIsGood
    imshow(octData(:,:,round(sz(3)/2)));
    title("B-Scan at the middle of the loaded volume")
    pause(2);
    [flag_ImageQualiyIsGood, filteredOctCube] = filterVolume(octData);
else
    filteredOctCube = octData;
end

while ~flag_ImageQualiyIsGood
    close all
    
    imshow(filteredOctCube(:,:,round(sz(3)/2)));
    title("B-Scan at the middle of the pre-processed volume")
    pause(2);
    
    answer = questdlg('Would you like to continue to apply image filter?', ...
        'Is the image qualitey satisfying to start segmentation?', 'Yes', 'No', 'No');
    switch answer
        case 'Yes'
            [flag_ImageQualiyIsGood, filteredOctCube] = filterVolume(filteredOctCube);
        case 'No'
            flag_ImageQualiyIsGood = 1;
    end
    
    close all
    
end

imshow(filteredOctCube(:,:,sz(3)))
%% Begin segmenatation
% CAUTION!!! Still in manual trial-phase of implementation

%Check if folder for masks exists &/ create it
%TODO: add volume ID
maskFolder = fullfile(maskFolder, maskSubFolder);
if ~exist(maskFolder, 'dir')
    mkdir(maskFolder)
end

%%Maunal segmentation
%TODO: REF - think about putting the segmentation into class
for i = 1:sz(3)
    
    segPts = round(sz(2)/20);
    bScan = filteredOctCube(:,:,i);
    mask = zeros(sz(1), sz(2), 2);
    [isEndo, isOVD] = segmentationDecision(bScan);
    
    if isEndo
        pts = selectNPointsManually(bScan, segPts, 1);
        while length(pts(1,:)) ~= length(unique(pts(1,:)))
            f = msgbox('Points are not unique, please reselect!','Re-segmentation neccessary');
            pause(1)
            pts = selectNPointsManually(bScan, segPts, 1);    
        end
        intPts = interpolateSegmentedPoints(pts, sz(2), sz(1));
        % write values in mask 1
        for ii = 1:length(intPts)
            mask(intPts(2,ii),intPts(1,ii),1) = 1;
        end
    else
        mask(:,:,1) = mask(:,:,1);
    end
    
    if isOVD
        pts = selectNPointsManually(bScan, segPts, 2);
        while length(pts(1,:)) ~= length(unique(pts(1,:)))
            f = msgbox('Points are not unique, please reselect!','Re-segmentation neccessary');
            pause(1)
            pts = selectNPointsManually(bScan, segPts, 2);    
        end
        intPts = interpolateSegmentedPoints(pts, sz(2), sz(1));
        % write values in mask 2
        for ii = 1:length(intPts) 
            mask(intPts(2,ii),intPts(1,ii),2) = 1; 
        end
    else
        mask(:,:,2) = mask(:,:,2);
    end
    
    %Save masks as *.bin-file and images
    saveCalculatedMask(mask, maskFolder, i);
    
end

%%CONTINUE HERE

%% Michis segmentation logic
% TODO: place before manual segmentation (once it works)

% fltBScan = filteredOctCube(:,:,64);
% % fltBScan = filterImageNoise(fltBScan(5:end,:), 'openAndClose', 3);
% % fltBScan = filterImageNoise(fltBScan, 'open', 7);
% % fltBScan = denoiseAndRescaleBScan(fltBScan, 25);
% % figure; imshow(fltBScan)
% sz = size(fltBScan);
% mask = zeros(sz(1), sz(2));
%
% im = createGradImg(single(fltBScan)); %if no image-processing toolbox available
% figure; imshow(im);
% [seg, mns] = segmentImage(im, mask, 1e-4);
%
% figure
% imagesc(fltBScan);
% colormap gray;
% hold on, plot(seg)
% %??? TODO: implement function that finds boarder on basis of gradient


% gradImg = findVerticalImageGradient(fltBScan);
% figure; imshow(gradImg);

