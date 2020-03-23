%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% c@ melanie.wuest@zeiss.com & philipp.matten@meduniwien.ac.at
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [denoisedBScan] = denoiseAndRescaleBScan(bScan, scaleFac)
    
    noise = mean2(bScan(end-25:end,:));
    denoisedBScan = ((bScan-noise) ./ scaleFac) .* 255; %scale in dB
    
end
