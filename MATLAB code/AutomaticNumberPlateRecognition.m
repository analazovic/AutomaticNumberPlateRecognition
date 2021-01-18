function [BoundingBox, plateNumber, success] = AutomaticNumberPlateRecognition(Iorig)

% Load images of letter templates
load('letterTemplates')

% Load images of digit templates
load('digitTemplates')

% List of licence plate registration areas in Serbia
RegArea = ["AL"; "AR"; "AC"; "BB" ;"BG"; "BO"; "BP"; "BT"; strcat("B",char(262)); "BU"; strcat("B",char(268)) ;"VA"; "VB" ;"VL" ;"VP"; "VR"; "VS"; strcat("V",char(352)); "GL"; "GM";...
    "DE"; strcat(char(272),"A"); "ZA"; "ZR"; "IN"; "IC"; "JA"; "KA" ;"KV"; "KG"; strcat("K",char(381)); "KI"; "KL"; "KM"; "KO"; strcat("K",char(352)); "LB" ;"LE"; "LO"; "LU"; "NV";...
    "NG"; "NI"; "NP"; "NS"; "PA"; "PB"; "PE"; strcat("P",char(381)); "PZ"; "PI"; "PK"; "PN"; "PO"; "PP"; "PR"; "PT"; "RA"; "RU"; "SA"; "SV"; "SD";...
    "SJ"; "SM"; "SO"; "SP";"ST"; "SU"; "TO"; "TS"; "TT"; strcat(char(262),"U"); "UB"; "UE"; "UR"; strcat(char(268),"A"); strcat(char(352),"A"); strcat(char(352),"I")];

% List of possible letters
letterList = ['X'; 'A'; 'B'; 'C'; 'D'; 'E'; 'F'; 'G'; 'H'; 'I'; 'J'; 'K'; 'L'; 'M'; 'N'; 'O'; 'P'; 'R'; 'S'; 'T'; 'U'; 'V'; 'Z';...
    char(262); char(268); char(272); char(352); char(381)];

success = 0;
detectionWithAdaptBin = 1;

% Licence plate detection - first try with global binarization
[BoundingBox, Im] = LicencePlateDetection(Iorig, 'graythresh');
plateNumber = [];

% If the licence plate detection with global binarization was not successful, try detection with adaptive binarization
if(size(Im, 1) == 0)
    % Licence plate detection (adaptive binarization)
    [BoundingBox, Im] = LicencePlateDetection(Iorig, 'adapt');
    detectionWithAdaptBin = 0;
    plateNumber = [];
    success = 0;
end

% If detection was successful, try deskewing if licence plate image is skewed, character segmentation, and character recognition
if(size(Im, 1) > 0)
    % Resize original image
    Im = imresize(Im,[120 500], 'bilinear');
    
    % Deskew image if necessary (global binarization)
    I1 = DeskewingLicencePlate(Im, 'graythresh');
    
    % Resize deskewed image
    I1 = imresize(I1,[120 500], 'bilinear');
    
    % Character segmentation (global binarization)
    [characters, num] = CharacterSegmentation(I1, 'graythresh');
    
    if num
        % Character recognition
        [plateNumber, success] = CharacterRecognition(characters, letterTemplates, digitTemplates, RegArea, letterList);
    end
    
    if (~success)
        % Deskew image if necessary (adapt binarization)
        I1 = DeskewingLicencePlate(Im,'adapt');
        
        I1 = imresize(I1,[120 500],'bilinear');
        
        % Character segmentation (adaptive binarization)
        [characters,num] = CharacterSegmentation(I1, 'adapt');
        
        % Character recognition
        if num
            [plateNumber, success] = CharacterRecognition(characters, letterTemplates, digitTemplates, RegArea, letterList);
        end
    end
end

if(~success && detectionWithAdaptBin)
    
    % Licence plate detection (adaptive binarization)
    [BoundingBox,Im] = LicencePlateDetection(Iorig,'adapt');

    if(size(Im, 1) > 0)
        Im = imresize(Im, [120 500], 'bilinear');
        
        % Deskew image if necessary (adapt binarization)
        I1 = DeskewingLicencePlate(Im, 'adapt');
        I1 = imresize(I1,[120 500], 'bilinear');
        
        % Character segmentation (global binarization)
        [characters, num] = CharacterSegmentation(I1, 'graythresh');
        
        % Character recognition
        if num
            [plateNumber, success] = CharacterRecognition(characters, letterTemplates, digitTemplates, RegArea, letterList);
        end
        
        if (~success)
            % Character segmentation (adaptive binarization)
            [characters, num] = CharacterSegmentation(I1, 'adapt');
            
            % Character recognition
            if num
                [plateNumber, success] = CharacterRecognition(characters, letterTemplates, digitTemplates, RegArea, letterList);
            end
        end
    end
end

end