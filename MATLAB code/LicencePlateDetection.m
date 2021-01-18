function [BoundingBox, plate] = LicencePlateDetection(Im, binarizationType)
Im = imresize(Im, [1548 NaN],'bilinear');
[h, w, ~] = size(Im);

%% Convert RGB image to grayscale image
I = rgb2gray(Im);

%% Enchancing contrast of image
lowhigh = stretchlim(I);
I = imadjust(I, lowhigh,[]);

%% Image filtering using median filter
I = medfilt2(I,[3,3]);
I = medfilt2(I,[3,3]);
I = medfilt2(I,[3,3]);

%% Image binarization (Otsu method)
if(strcmp(binarizationType, 'graythresh'))
    IB = imbinarize(I, graythresh(I));
elseif(strcmp(binarizationType, 'adapt'))
    IB = imbinarize(I, adaptthresh(I,0.9));
end
%% Discarding small connected components that have less than 50 pixels
IB = bwareaopen(IB,50);

%% Finding all regions in image
[L, n] = bwlabel(IB);
stats = regionprops(L, 'BoundingBox', 'Image', 'Euler');

% Euler number of all regions
allEulerNumber = [stats.EulerNumber];

% Index of regions with negative Euler number
ind_neg_Euler_num = find(allEulerNumber < 0 & allEulerNumber > -40);

%% Discarding the regions that do not satisfy conditions for representing licence plate (dimensions, aspect ratio)
k = 0;
regions = [];

for i = ind_neg_Euler_num
   B = stats(i).BoundingBox;
   if(B(3)/B(4) > 1.4 && B(3)/B(4) < 6 && B(3) > 100 && B(3) < 0.80 * w && B(2) > round(h/4))
       k = k + 1;
       regions(k).BoundingBox = stats(i).BoundingBox;
       regions(k).Image = stats(i).Image;
       regions(k).EulerNumber = stats(i).EulerNumber;
   end
end


%% Extracting candidates and detecting edges 

if(k)
    % List of variances
    var_list = zeros(numel(regions),1);
    
    % List of mean values of vertical projection calculated based on image with detected vertical edges
    ver_pr = zeros(numel(regions),1);
    
    for i = 1 : numel(regions)
        % Vertical edge detection using Sobel filter
        IE = edge(regions(i).Image,'sobel','vertical');
        
        % Vertical projection of current region
        S = sum(IE,2);
        
        % Mean value of vertical projection of current region (discarding first 25 percent and last 25 percent)
        ver_pr(i)=mean( S( round(0.25 * length(S)) : round(0.75 * length(S)) ) );
        
        % Variance of vertical projection of current region (discarding first 25 percent and last 25 percent)
        var_list(i) = var(S( round(0.25 * length(S)) : round(0.75 * length(S)) ) );
    end
    
    %% Licence plate = candidate with maximal mean vertical projection
    [~,ind] = max(ver_pr);
    
    if length(ver_pr) > 1
        [ver_pr_sort, index] = sort(ver_pr, 'descend');
        if ver_pr_sort(2) > 0.9 * ver_pr_sort(1)
            if var_list(index(1)) < var_list(index(2))
                ind = index(1);
            else
                ind = index(2);
            end
        end
    end
    
    B = regions(ind).BoundingBox;
    
    %% Cropping the licence plate
    plate = imcrop(Im,[B(1) - 0.1 * B(3) B(2) B(3) + 0.1 * B(3) B(4)]);
    BoundingBox = [B(1) - 0.1 * B(3) B(2) B(3) + 0.1 * B(3) B(4)];
else
    plate = [];
    BoundingBox = [];
end
