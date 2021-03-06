function [unaryPotentials, invalidPositions] = getUnaryPotentials(x, y, frameWidth, frameHeight, anchorX, anchorY, maxDistanceX, maxDistanceY)

% computes the prior likelihood that a paw exists in a given location
% simply computse distance of the paw to the anchorPoint (x,y)
% the likelihood is the inverse of the distance to the anchor point
% width and height are normalized from 0 to 1
% 
% inputs        x:             vector of x locations of tracks
%               y:             vector of x locations of tracks
%               frameHeight:   height of frame (used to normalize y from 0 to 1)
%               frameWidth:    width of frame (used to normalize x from 0 to 1)
%               anchorPointX:  most likely x position of paw, expressed from 0 to 1
%               anchorPointY:  most likely y position of paw, expressed from 0 to 1
%               maxDistance:   scores are set to 0 if ddistances between anchor point and xy point is greater than max distance


% compute distant of points to anchorPoint
dx = (x / frameWidth) - anchorX;
dy = (y / frameHeight) - anchorY;
unaryPotentials = sqrt(2) - sqrt(dx.^2 + dy.^2); % sqrt(2) is the maximum possible distance, eg the distance from one corner to the opposite corner
invalidPositions = (abs(dx) > maxDistanceX) | (abs(dy) > maxDistanceY);
unaryPotentials(invalidPositions) = 0;
unaryPotentials(invalidPositions) = 0;
