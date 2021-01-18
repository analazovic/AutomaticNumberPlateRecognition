function binarizedImage = LicencePlateBinarization(image, binarizationType)
%% Convert RGB image to grayscale image
I=rgb2gray(image);

%% Enchancing contrast of image
lowhigh = stretchlim(I);
I=imadjust(I,lowhigh,[]);

%% Image filtering using median filter
I=medfilt2(I,[3,3]);
I=medfilt2(I,[3,3]);
I=medfilt2(I,[3,3]);

%% Binarization
if(strcmp(binarizationType,'graythresh'))
    binarizedImage=imbinarize(I,graythresh(I));
elseif(strcmp(binarizationType,'adapt'))
    binarizedImage=imbinarize(I,adaptthresh(I,0.8));
end

end