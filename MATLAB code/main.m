clear all
close all
clc

% Read a vehicle image
vehicleImage = imread('input_image.jpg');

% Resize a vehicle image
vehicleImage = imresize(vehicleImage,[1548 NaN],'bilinear');

% Show a vehicle image
figure
imshow(vehicleImage)
title('Vehicle image')

% If plate number is found (success = 1), return bounding box of plate and plate number
[BoundingBox, plateNumber, success] = AutomaticNumberPlateRecognition(vehicleImage);

% Show the original image with licence plate bounding box
if(success)
   figure
   imshow(vehicleImage)
   title('Vegicle image with licence plate bounding box')
   rectangle('Position',BoundingBox,'EdgeColor','g','LineWidth',2) 
end


