function Corrected_Plate = DeskewingLicencePlate(skewImage, binarizationType)

% Binarization of the image of the skewed licence plate 
binarizedImage = LicencePlateBinarization(skewImage, binarizationType);

% Egde detection using Canny filter
edgeDetectedImage = edge(binarizedImage, 'canny');

% Finding vertical tilt angle
theta = 0 : 180;
[R,~] = radon(edgeDetectedImage, theta);
maxR = max(R(:));
[~, columnOfMax] = find(R == maxR);

% Angle for correction of vertical tilt
verticalTiltAngle = columnOfMax - 90;

% Image rotation (correction of vertical tilt)
vecCorrectedTiltImage = imrotate(skewImage, -verticalTiltAngle,'bilinear','crop');

I5 = imrotate(binarizedImage, - verticalTiltAngle,'bilinear','crop');
I_pom = I5;
I5 = bwareaopen(I5,20);
I5 =~ I5;

%% Affine transform for correction of horizontal tilt
[L, n] = bwlabel(I5);
stats = regionprops(L, 'BoundingBox', 'Image');

% BoundingBox
allBB = [stats.BoundingBox];

% Region width
allWidths = allBB(3:4:end);

% Region height
allHeights = allBB(4:4:end);

%% Finding the region for calculation of horizontal tilt angle 
targetIndexes = find(((allWidths > 15 & allWidths < 80 & allHeights > 20 & allHeights < 100)| (allWidths > 5 & allHeights > 50 & allHeights <100 )));
binaryImage = ismember(L, targetIndexes);

[L,n] = bwlabel(binaryImage);
stats = regionprops(L, 'BoundingBox', 'Image');

%% Solving the problem of digit 0 (combining two regions that overlap into one region)
num = 0;
if(n)
    regions(1).BoundingBox = stats(1).BoundingBox;
    regions(1).Image = stats(1).Image;
    num = 1;
    for i = 2 : n
        B1 = stats(i - 1).BoundingBox;
        B2 = stats(i).BoundingBox;
        if(abs(B1(1) - B2(1))<12)
            x0 = min(B1(1), B2(1));
            y0 = min(B1(2), B2(2));
            w = abs(x0 - max(B1(1) + B1(3), B2(1) + B2(3)));
            h = abs(y0-max(B1(2) + B1(4), B2(2) + B2(4)));
            regions(num).BoundingBox = [x0 y0 w h];
            regions(num).Image = imcrop(binaryImage, regions(num).BoundingBox);
        else
            num = num + 1;
            regions(num).BoundingBox = stats(i).BoundingBox;
            regions(num).Image = stats(i).Image;
        end
    end
end

if(num > 2)
    p = 0;
    for k = floor(median(1 : numel(regions))) - 1 : ceil(median(1 : numel(regions))) + 1
        Im = regions(k).Image;
        angle = -30:30;
        W = zeros(1,length(angle));
        
        for i = 1 : length(angle)
            Im1 = imrotate(Im,angle(i));
            
            [L, n] = bwlabel(Im1);
            reg = regionprops(L, 'BoundingBox', 'Image');
            if (n == 2)
                B1 = reg(1).BoundingBox;
                B2 = reg(2).BoundingBox;
                x0 = min(B1(1), B2(1));
                w = abs(x0 - max(B1(1) + B1(3), B2(1) + B2(3)));
                W(i) = w;
            else
                B = reg.BoundingBox;
                W(i) = B(3);
            end
        end
        [~, ind] = min(W);
        p = p + 1;
        regions_angle(p) = angle(ind);
    end

    %% Applying the affine transform
    horCorrectionTiltAngle = - mean(regions_angle);
    tm2 = [1 0 0; tand(horCorrectionTiltAngle) 1 0; 0 0 1];
    tform = affine2d(tm2);
    Corrected_pom = imwarp(I_pom,invert(tform));
    
    [h1, w1, ~] = size(Corrected_pom);
    [L, n] = bwlabel(Corrected_pom);
    stats = regionprops(L, 'BoundingBox', 'EulerNumber');
    
    % Euler number of regions
    EulerNumber = [stats.EulerNumber];
    
    % BoundingBox of regions
    allBB = [stats.BoundingBox];
    
    % Width of regions
    allWidths = allBB(3:4:end);
    
    % Height of regions
    allHeights = allBB(4:4:end);
    
    % Indices of regions that satisfy conditions to represent characters
    idx = allWidths./allHeights > 3 & allWidths/allHeights < 10 & allWidths > 0.5 * w1 & allHeights > 0.3 * h1 & abs(EulerNumber) > 8;

    Corrected_Plate = imwarp(vecCorrectedTiltImage,invert(tform));
    
    if(sum(idx))
        B = stats(idx).BoundingBox;
        Corrected_Plate = imcrop(Corrected_Plate,[B(1) - 0.1 * B(3) B(2) B(3) + 0.1 * B(3) B(4)]);
        Corrected_Plate = imresize(Corrected_Plate, [120 500], 'bilinear');
    else
        Corrected_Plate = skewImage;
    end
else
    Corrected_Plate = skewImage;
end

end