function [LicencePlateNumber, success] = CharacterRecognition(segmentedCharacters, characterTemplates, digitTemplates, RegPod, letters)

for i = 1 : numel(segmentedCharacters)
    % Resize every segmented character to be the same size as the template images
    characters(i).Image = imresize(segmentedCharacters(i).Image, [57,28], 'bilinear');
    
    % Dilate image in order to fill small holes
    se = strel('diamond',1); 
    Ipom = imdilate(characters(i).Image, se);
    
    % Label image in order to find regions of the image and appropriate property (Euler number)
    [L, n] = bwlabel(Ipom);
    stats = regionprops(L, 'EulerNumber');
    segmentedCharacters(i).EulerNumber = stats.EulerNumber;
end

if numel(characters) > 7
    
    % List of correlation coefficients for the first character
    C_first = zeros(1, length(characterTemplates) - 1);
    
    for j = 2 : length(characterTemplates)
        C_first(j - 1) = corr2(characterTemplates{1, j}, characters(1).Image);
    end
    
    % Sorted list of correlation coefficients for the first character (descending order)
    C_first_sort = sort(C_first, 'descend');
    
    % List of correlation coefficients for the last character
    C_last = zeros(1, length(characterTemplates) - 1);
    
    for j = 2 : length(characterTemplates)
        C_last(j - 1) = corr2(characterTemplates{1, j}, characters(end).Image);
    end
    
    % Sorted list of correlation coefficients for the last character (descending order)
    C_last_sort = sort(C_last, 'descend');
    
    % Discard the first segmented character if it does not represent part of the licence plate number
    if(C_first_sort(1) < 0.3)
        characters = characters(2 : end);
        segmentedCharacters = segmentedCharacters(2 : end);
    end
    
    % Discard the last segmented character if it does not represent part of the licence plate number
    if(C_last_sort(1) < 0.3)
        characters = characters(1 : end - 1);
        segmentedCharacters = segmentedCharacters(1 : end - 1);
    end
end

% Number of characters after discarding the charaters that do not represent the part of the licence plate number
num = numel(characters);
switch(num)
    case 7
        PN = char(ones(1,7)*'*');
    case 8
        PN = char(ones(1,8)*'*');
    case 9
        PN = char(ones(1,9)*'*');
end

if (num == 7 || num == 8 || num == 9) % if the number of candidate is 7, 8 or 9
    
    for i=1:num
        % Recognition of licence plate registration area = first two characters
        if (i == 1 || i == 2)
            C = zeros(1, length(characterTemplates) - 1);
            
            for j = 2 : length(characterTemplates)
                C(j - 1) = corr2(characterTemplates{1,j}, characters(i).Image);
            end
            
            % Neccessary for checking the licence plate registration area
            if (i == 1)
                K1 = C; % list of correlation coefficients for the first character
            elseif(i == 2)
                K2 = C; % list of correlation coefficients for the second character
            end
            
            [~, ind] = max(C);
            temp = letters(ind + 1);
            
            % Recognition of the last two characters
        elseif (i == num - 1 || i == num)
            C = zeros(1, length(characterTemplates) - 5);
            
            for j = 1 : length(characterTemplates)-5
                C(j) = corr2(characterTemplates{1,j}, characters(i).Image);
            end
            
            [~, ind] = max(C);
            temp = letters(ind);
            
        else % Recognition of digits (middle characters)
            C = zeros(1, length(digitTemplates));
            
            for j = 1 : length(digitTemplates)
                C(j) = corr2(digitTemplates{1,j}, characters(i).Image);
            end
            
            [~, ind] = max(C);
            temp = num2str(ind-1);
        end
        PN(i) = temp;
    end
        
    % Solving the problem of misclassifying letters D and O
    temp = [1 2 length(PN)-1 length(PN)];
    for k = 1 : length(temp)
        if(PN(temp(k)) == 'O' || PN(temp(k)) == char(272))
            angle = -10 : 10;
            B = zeros(length(angle),4);
            
            for i = 1 : length(angle)
                Im1 = imrotate(characters(temp(k)).Image, angle(i));
                [L, ~] = bwlabel(Im1);
                reg = regionprops(L, 'BoundingBox', 'Image');
                B(i,:) = reg.BoundingBox;
            end
            
            % Finding angle that corresponds to the minimal character width
            [~, ind] = min(B(:, 3));
            angle2 = - angle(ind);
            
            % Define affine transform
            tm2 = [1 0 0; tand(angle2) 1 0; 0 0 1];
            tform = affine2d(tm2);
            
            % Apply inverse affine transform in order to correct character tilt,  then crop and resize deskewed character image
            Temp = imwarp(characters(temp(k)).Image, invert(tform));
            Temp = imcrop(Temp, B(ind,:));
            Temp = imresize(Temp, [57,28], 'bilinear');
            
            C = zeros(1,length(characterTemplates) - 5);
            
            for j = 1 : length(characterTemplates) - 5
                C(j) = corr2(characterTemplates{1,j}, Temp);
            end
            
            [~, ind] = max(C);
            PN(temp(k)) = letters(ind);
        end
    end
    
    % Solving the problem of misclassifying digits 1 and 7
    ind = find(PN(3:length(PN) - 2)) + 2;
    for k = ind
        if(PN(k) == '1' || PN(k) == '7')
            angle = -15:15;
            C = zeros(length(angle), 2);
            
            for i = 1 : length(angle)
                Im1 = imrotate(characters(k).Image, angle(i));
                [L,~] = bwlabel(Im1);
                
                reg = regionprops(L, 'BoundingBox', 'Image');
                B = reg.BoundingBox;
                
                Temp = imcrop(Im1,B);
                Temp = imresize(Temp,[57,28],'bilinear');
                
                C(i,:) = [corr2(digitTemplates{1,2}, Temp) corr2(digitTemplates{1,8}, Temp)];
                Max1 = max(C(:,1));
                Max2 = max(C(:,2));
                
                if (Max1 > Max2)
                    PN(k) = '1';
                else
                    PN(k) = '7';
                end
            end
        end
    end
    
    % Correction of misclassifying letter I
    temp = [1 2 length(PN)-1 length(PN)];
    for k = 1 : length(temp)
        if(sum(sum(characters(temp(k)).Image(2:end, 2:end))) > 0.85 * size(characters(temp(k)).Image(2 : end, 2 : end), 1) * size(characters(temp(k)).Image(2 : end, 2 : end), 2) && PN(k) ~= 'M' && PN(k) ~= 'N')
            PN(temp(k)) = 'I';
        end
        if PN(temp(k)) == 'Z'
            angle = -20 : 20;
            B = zeros(length(angle), 4);
            for i = 1 : length(angle)
                Im1 = imrotate(characters(temp(k)).Image, angle(i));
                [L,~] = bwlabel(Im1);
                reg = regionprops(L,'BoundingBox','Image');
                B(i,:) = reg.BoundingBox;
            end
            
            % Finding angle that corresponds to the minimal character width
            [~,ind] = min(B(:,3));
            angle2 = -angle(ind);
            
            % Define affine transform
            tm2 = [1 0 0; tand(angle2) 1 0; 0 0 1];
            tform = affine2d(tm2);
            
            % Apply inverse affine transform in order to correct character tilt, then crop and resize deskewed character image
            Temp = imwarp(characters(temp(k)).Image, invert(tform));
            Temp = imcrop(Temp, B(ind,:)); 
            Temp = imresize(Temp, [57,28], 'bilinear');
            
            C = zeros(1,length(characterTemplates) - 5);
            for j = 1:length(characterTemplates) - 5
                C(j) = corr2(characterTemplates{1,j}, Temp);
            end
            
            [~, ind] = max(C);
            PN(temp(k)) = letters(ind);
        end  
    end
    
    % Checking the Euler number (solving the problem of misclassifying letter B as D, Dj or O)
    temp = [1 2 length(PN)-1 length(PN)];
    for k = 1 : length(temp)
        if(PN(temp(k)) == 'D' || PN(temp(k)) == char(272) || PN(temp(k)) == 'O')
            if(segmentedCharacters(temp(k)).EulerNumber == -1)
                PN(temp(k)) = 'B';
            end
        end
    end
    
    % Solving the problem of misclassifying the letters A, K and X
    temp = [1 2 length(PN)-1 length(PN)];
    for k = 1 : length(temp)
        if((PN(temp(k)) == 'K' || PN(temp(k)) == 'X') && (segmentedCharacters(temp(k)).EulerNumber == 0))
                PN(temp(k))='A';
        end
    end
    
    % Checking the licence plate registration area
    validRegArea = find(RegPod == PN(1:2));
    [K_1, idx1] = sort(K1, 'descend');
    [K_2, idx2] = sort(K2, 'descend');
    
    i = 1;
    k = 1;
    pom_PN = PN;
    while(isempty(validRegArea) && i < length(K_1))
        pom_PN = PN;
        if(K_1(1) - K_1(i + 1) < K_2(1) - K_2(k + 1))
            pom_PN(1) = letters(idx1(i + 1) + 1);
            i = i + 1;
        else
            pom_PN(2) = letters(idx2(k + 1) + 1);
            k = k + 1;
        end
        validRegArea = find(RegPod == pom_PN(1 : 2));
    end
    PN = pom_PN;
    
    if(PN(3) == '7' && (PN(1:2) ~= "BG" || PN(end - 1 : end) ~= "TX"))
        PN(3) = '1';
    end
    
    if (num == 7)
        LicencePlateNumber = [PN(1) PN(2) ' ' PN(3) PN(4) PN(5) '-' PN(6) PN(7)];
    elseif(num == 8)
        LicencePlateNumber=[PN(1) PN(2) ' ' PN(3) PN(4) PN(5) PN(6) '-' PN(7) PN(8)];
    else
        LicencePlateNumber = [PN(1) PN(2) ' ' PN(3) PN(4) PN(5) PN(6) PN(7) '-' PN(8) PN(9)];
    end
    
    success = 1;   
else
    success = 0;
    LicencePlateNumber = [];
end

if (num == 9 && (PN(end - 1 : end) ~= "TX" || PN(1 : 2) ~= "BG")) || (num == 8 && PN(1 : 2) ~= "BG" && PN(end - 1 : end) ~= "TX")
    success = 0;
    LicencePlateNumber = [];
end

