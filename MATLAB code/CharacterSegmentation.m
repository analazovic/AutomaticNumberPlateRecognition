function [segmentedCharacters, num] = CharacterSegmentation(Im, binarizationType)
%% Original RGB inage
Im = imresize(Im,[120 500],'bilinear');

% Binarization of an image
IB = LicencePlateBinarization(Im, binarizationType);

%% Computing the negative of the image in order to find regions (white areas)
IB =~ IB;

%% Finding regions
[L,~] = bwlabel(IB);
stats = regionprops(L, 'BoundingBox', 'Image');

% BoundingBox of regions
allBB = [stats.BoundingBox];

% Width of regions
allWidths = allBB(3:4:end);

% Heights of regions
allHeights = allBB(4:4:end);

%% Finding the regions that have appropriate weight and height, because they might represent characters
lettersIndexes = find((allWidths > 15 & allWidths < 80 & allHeights > 30 & allHeights < 100)| (allWidths > 5 & allHeights > 50 & allHeights <100));

% Image with appropriate regions
binaryImage = ismember(L, lettersIndexes);
binaryImage = imclearborder(binaryImage);

%% Remaining regions
[L, n] = bwlabel(binaryImage);
stats = regionprops(L, 'BoundingBox', 'Image', 'EulerNumber');

if(n)
    % Solving the problem of digit 0 (combining two regions that overlap into one region)
    regions(1).BoundingBox = stats(1).BoundingBox;
    regions(1).Image = stats(1).Image;
    num = 1;
    for i = 2 : n
        B1 = stats(i - 1).BoundingBox;
        B2 = stats(i).BoundingBox;
        
        if(abs(B1(1) - B2(1)) < 12)
            x0 = min(B1(1), B2(1));
            y0 = min(B1(2), B2(2));
            w = abs(x0 - max(B1(1) + B1(3), B2(1) + B2(3)));
            h = abs(y0 - max(B1(2) + B1(4), B2(2) + B2(4)));
            regions(num).BoundingBox = [x0 y0 w h];
            regions(num).Image = imcrop(binaryImage, regions(num).BoundingBox);
            regions(num).EulerNumber = 2;
        else
            num = num + 1;
            regions(num).BoundingBox = stats(i).BoundingBox;
            regions(num).Image = stats(i).Image;
            regions(num).EulerNumber = stats(i).EulerNumber;
        end
    end
    
    allBB = [regions.BoundingBox];

    % Solving the problem of the skewed letter I
    allWidths = allBB(3:4:end);
    ind1 = find(allWidths > 5 & allWidths < 20);
    if(ind1)
        for j = 1 : length(ind1)
            angle = -10 : 10;
            B = zeros(length(angle), 4);
            for i = 1 : length(angle)
                Im1 = imrotate(regions(ind1(j)).Image, angle(i));
                [L,~] = bwlabel(Im1);
                reg = regionprops(L, 'BoundingBox', 'Image');
                B(i,:) = reg.BoundingBox;
            end
            
            % Finding angle that corresponds to the minimal character width
            [~, ind] = min(B(:,3));
            angle2 = -angle(ind); % angle for deskewing  
            
            % Define affine transform
            tm2 = [1 0 0; tand(angle2) 1 0; 0 0 1];
            tform = affine2d(tm2);
            
            % Apply inverse affine transform in order to correct character tilt, then crop and resize deskewed image of character I
            Temp = imwarp(regions(ind1(j)).Image, invert(tform));

            regions(ind1(j)).Image = imcrop(Temp, B(ind,:));
        end
    end
    
    % Discarding bad regions
    allHeights = allBB(4:4:end);
    mediana = median(allHeights);
    ind5 =(allHeights - mediana) < 15 & (allHeights - mediana) > -10;
    
    % Segmented characters
    segmentedCharacters = regions(ind5);
    
    % Number of segmented characters
    num = numel(segmentedCharacters);
else
    num = 0;
    segmentedCharacters = [];
end

