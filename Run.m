%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% MAIN FILE for data processing pipeline of Ant. Eye Segmentation-Pipeline
%                               copyright:
%       @melanie.wuest@zeiss.com & @philipp.matten@meduniwien.ac.at
%
%   Center for Medical Physics and Biomedical Engineering (Med Uni Vienna)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Forward declarations and globals

% Add main path of repository of search path
warning("Calution!!! Change 'localGlobPath'-variable to your local path, were you keep the repository")
localGlobPath = 'C:\Users\ZEISS Lab\Documents\MATLAB\AnteriorEyeSegmentationPipeline\Code';
addpath(localGlobPath);
file = 'octDataCube.bin';
a = 1024; %static for standard
b = 512;
c = 128;

%% Preprocessing
% Check if a data stack is already in the workspace
if exist('octData', 'var')
    answer = questdlg('There is already a data set in the workspace. Would you like to load a new set?', ...
        'Load OCT data from image files', 'Yes', 'No', 'No');
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
    path = uigetdir();
    octData = loadOctImages(path, a, b, 'bmp');
    % Check if octDataCube.bin-file exists
    % -> if not: dialog for saving OCT volume in said *.bin-file
    if isfile(fullfile(localGlobPath, file))
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
            saveDataCubeAsBinFile(path, file, octData)
        end
    end
    
end


%% Display b-Scan
% bScan = octData(:,:,60);
% figure; imshow(bScan);

%% Pre-segementation image filter
%filteredOctCube = [];
answer = questdlg('Would you like to apply an image filter to enhance contrast of edges?', ...
    'Apply pre-layer-segementation image filter volume', 'Yes, weighted edge', 'Yes, noise reduction', 'No', 'No');
switch answer
    case 'Yes, weighted edge'
        disp('Applying image filter... TBD!!!')
        warning("No filter option implemented yet");
    case 'Yes, noise reduction'
        disp('Applying image filter... TBD!!!')
        warning("No filter option implemented yet");
        % Apply filter to octData
        %     case 'Yes, noise reduction'
        %         disp('Applying image filter... TBD!!!')
        %         warning("No filter option implemented yet");
        %         % Apply filter to octData
    case 'No'
        filteredOctCube = octData;
        
end

%% Begin segmenatation
% CAUTION!!! Still in manual trial-phase of implementation
% TODO: call from loop, to go through whole volume
cubeSz = size(filteredOctCube);
fltBScan = filteredOctCube(:,:,64);
pts = selectNPointsManually(fltBScan, round(cubeSz(2)/20)); %returns "point-string" of 1st interface in bScan

%% TODO: FROM Here on
intPts = interpolateSegmentedPoints(pts, cubeSz(2), cubeSz(1)); %returns "point-string" of 1st interface in bScan
mask(:,:,1) = zeros(cubeSz(1), cubeSz(2)); %declare mask of first layer
%loop to replace all boarder pixels with ones
for i = 1:length(intPts)
    if (intPts(1,i) <= cubeSz(2)) && (intPts(2,i) <= cubeSz(1))
        mask(intPts(2,i),intPts(1,i),1) = 1;
    end
end

figure; imshow(fltBScan);
figure; imshow(mask);

%TODO: Add saving logic for segmented masks in a sub-folder
%TODO: add pre-check if masks already exist