function [coordinates,newElements,varargout] ...
    = QrefineRB(coordinates,elements,varargin)

%QrefineRB: local refinement of quadrilateral mesh by red-blue refinement, 
%          where marked elements are refined by bisecting all edges 
%          of the element
%
%Usage:
%
% [coordinates,elements4,dirichlet,neumann] ...
%    = QrefineRB(coordinates,elements4,dirichlet,neumann,marked)
% or
%
% [coordinates,elements4] ...
%    = QrefineRB(coordinates,elements4,marked)
%
%Comments:
%
%    QrefineRB expects as input a mesh described by the 
%    fields coordinates, elements4, dirichlet (optional) and neumann 
%    (optional). The vector marked contains the indices of elements which
%    are refined by refining all edges of the element.
%    Further elements will be refined by a red-blue refinement to obtain
%    a regular triangulation. To ensure shape regularity of the mesh,
%    blue elements are coarsened before further refined.
% 
%    The function returns the refined mesh in terms of the same data as
%    for the input.
%
%Remark:
%
%    This program is a supplement to the paper 
%    >> Adaptive Mesh Refinement in 2D - An Efficient Implementation in Matlab <<
%    by S. Funken, and A. Schmidt. The reader should 
%    consult that paper for more information.   
%
%Authors:
% 
%    S. Funken, A. Schmidt  20-08-18

persistent nB;
nE = size(elements,1);
markedElements = varargin{end};
%*** Obtain geometric information on edges
[edge2nodes,~,element2edges,boundary2edges{1:nargin-3}] ...
    = provideGeometricData(zeros(0,3),elements,varargin{1:end-1});
%*** Count number of blue sibling elements;
if isempty(nB)
    nB=0;
end
nR = nE-nB;
%*** Mark edges for refinement
edge2newNode = zeros(1,size(edge2nodes,1));
marked = markedElements(markedElements<=nR);
edge2newNode(element2edges(marked,:)) = 1;
marked = ceil((markedElements(markedElements>nR)-nR)/3);
edge2newNode(element2edges(nR+[3*marked-2,3*marked+3*nE-1])) = 1;
hashR = [1,1,1,1;1,1,0,0;0,0,1,1];
[mapR,valueR] = hash2map((0:15)',hashR); 
hashB = logical([1,1,0,0,0,0;1,1,1,0,0,1;1,1,0,1,1,0;1,1,1,1,1,1]);
[mapB,valueB] = hash2map((0:63)',hashB); 
swap = 1;
while  ~isempty(swap) || any(flags(:))
    markedEdge = edge2newNode(element2edges);
    %*** Change flags for red elements
    bit = markedEdge(1:nR,:);
    dec = sum(bit.*(ones(nR,1)*2.^(0:3)),2);
    valR = valueR(dec+1);
    [idx,jdx] = find(~bit & mapR(dec+1,:));
    swap = idx+(jdx-1)*nE;
    edge2newNode(element2edges(swap)) = 1;
    %*** Change flags for blue elements
    bit = [markedEdge(nR+1:3:end,1),markedEdge(nR+2:3:end,4), ...
        markedEdge(nR+1:3:end,4),markedEdge(nR+2:3:end,1), ...
        markedEdge(nR+3:3:end,1:2)];
    dec = sum(bit.*(ones(nB/3,1)*2.^(0:5)),2);
    valB = valueB(dec+1);
    bdx = find(valB)';
    flags = ~bit(bdx,:) & mapB(dec(dec>0)+1,:);
    edge2newNode(element2edges(nR+3*bdx(flags(:,1))-2,1))=1;
    edge2newNode(element2edges(nR+3*bdx(flags(:,2))-1,4))=1;
    edge2newNode(element2edges(nR+3*bdx(flags(:,3))-2,4))=1;
    edge2newNode(element2edges(nR+3*bdx(flags(:,4))-1,1))=1;
    edge2newNode(element2edges(nR+3*bdx(flags(:,5)),1))=1;
    edge2newNode(element2edges(nR+3*bdx(flags(:,6)),2))=1;
end
edge2newNode(element2edges(nR+3*bdx(hashB(valB(bdx),3))-2,3))=1;
edge2newNode(element2edges(nR+3*bdx(hashB(valB(bdx),4))-1,2))=1;
%*** Generate new nodes on edges
edge2newNode(edge2newNode~=0) = size(coordinates,1)...
                                    + (1:nnz(edge2newNode));
idx = find(edge2newNode);
coordinates(edge2newNode(idx),:) = (coordinates(edge2nodes(idx,1),:)...
                                + coordinates(edge2nodes(idx,2),:))/2;
%*** Refine boundary conditions
varargout = cell(nargout-2,1);
for j = 1:nargout-2
    boundary = varargin{j};
    if ~isempty(boundary)
        newNodes = edge2newNode(boundary2edges{j})';
        markedEdges = find(newNodes);
        if ~isempty(markedEdges)
            boundary = [boundary(~newNodes,:); ...
                boundary(markedEdges,1),newNodes(markedEdges); ...
                newNodes(markedEdges),boundary(markedEdges,2)];
        end
    end
    varargout{j} = boundary;
end
%*** Provide new nodes for refinement of elements
newNodes = edge2newNode(element2edges);
%*** Determine type of refinement for each red element
none   = find(valR == 0);
red    = find(valR == 1);
bluer = find(valR == 2);
bluel = find(valR == 3);
%*** Generate new interior nodes if red elements are refined
idx = [red,bluer,bluel];
midNodes = zeros(nE,1);
midNodes(idx) = size(coordinates,1)+(1:length(idx));
coordinates = [coordinates; ...
    ( coordinates(elements(idx,1),:) ...
    + coordinates(elements(idx,2),:) ...
    + coordinates(elements(idx,3),:) ...
    + coordinates(elements(idx,4),:) )/4];
%*** Determine type of refinement for each blue element
b2blue      = nR + find(valB==0);
b2red        = nR + find(valB==1);
b2east       = nR + find(valB==2);
b2south      = nR + find(valB==3);
b2southeast  = nR + find(valB==4);
%*** Generate element numbering for refined mesh
rdx = zeros(nR+nB/3,1);
rdx(none)    = 1;
rdx([red,b2red])     = 4;
rdx([b2south,b2east]) = 2;
rdx(b2southeast)  = 5;
rdx = [1;1+cumsum(rdx)];
bdx = zeros(size(rdx));
bdx([bluer,bluel,b2blue]) = 3;
bdx([b2south,b2east,b2southeast]) = 6;
bdx = rdx(end)+[0;0+cumsum(bdx)];
%*** Generate new red elements
tmp = [elements(1:nR,:),midNodes(1:nR,:),newNodes(1:nR,:),...
    zeros(nR,6);elements(nR+2:3:end,1),elements(nR+3:3:end,2),...
    elements(nR+1:3:end,1:2),elements(nR+3:3:end,4),...
    elements(nR+2:3:end,2),elements(nR+1:3:end,4),...
    newNodes(nR+1:3:end,1),newNodes(nR+2:3:end,4),newNodes(nR...
    +2:3:end,1),newNodes(nR+3:3:end,:),newNodes(nR+1:3:end,4)];
%*** Generate new interior nodes if blue elements are refined
dummy = unique([b2south(:);b2southeast(:)]);
tmp(dummy,16) = size(coordinates,1)+(1:length(dummy));
coordinates = [coordinates; ...
    (9*coordinates(tmp(dummy,1),:)+3*coordinates(tmp(dummy,2),:)...
    +1*coordinates(tmp(dummy,3),:)+3*coordinates(tmp(dummy,4),:))/16];
dummy = unique([b2south(:);b2southeast(:);b2east(:)]);
tmp(dummy,17) = size(coordinates,1)+(1:length(dummy));
coordinates = [coordinates; ...
    (3*coordinates(tmp(dummy,1),:)+9*coordinates(tmp(dummy,2),:) ...
    +3*coordinates(tmp(dummy,3),:)+1*coordinates(tmp(dummy,4),:))/16];
dummy = unique([b2east(:);b2southeast(:)]);
tmp(dummy,18) = size(coordinates,1)+(1:length(dummy));
coordinates = [coordinates; ...
    (1*coordinates(tmp(dummy,1),:)+3*coordinates(tmp(dummy,2),:) ...
    +9*coordinates(tmp(dummy,3),:)+3*coordinates(tmp(dummy,4),:))/16];
%*** Generate new red elements first
newElements = 1+zeros(bdx(end)-1,4);
newElements(rdx(none),:) = elements(none,:);
newElements([rdx(red),1+rdx(red),2+rdx(red),3+rdx(red)],:) ...
    = [tmp(red,[1,6,5,9]);tmp(red,[2,7,5,6]);...
    tmp(red,[3,8,5,7]);tmp(red,[4,9,5,8]);];
newElements([rdx(b2red),1+rdx(b2red),2+rdx(b2red),3+rdx(b2red)],:) ...
    = [tmp(b2red,[1,6,5,9]);tmp(b2red,[2,7,5,6]); ...
    tmp(b2red,[3,8,5,7]);tmp(b2red,[4,9,5,8])];
newElements([rdx(b2east),1+rdx(b2east)],:) ...
    = [tmp(b2east,[1,6,5,9]);tmp(b2east,[4,9,5,8])];
newElements([rdx(b2south),1+rdx(b2south)],:) ...
    = [tmp(b2south,[3,8,5,7]);tmp(b2south,[4,9,5,8])];
newElements([rdx(b2southeast),1+rdx(b2southeast), ...
    2+rdx(b2southeast),3+rdx(b2southeast),4+rdx(b2southeast)],:) ...
    = [tmp(b2southeast,[6,11,17,14]);tmp(b2southeast,[2,12,17,11]);...
    tmp(b2southeast,[7,13,17,12]);tmp(b2southeast,[5,14,17,13]); ...
    tmp(b2southeast,[4,9,5,8]);];
%*** New blue elements
newElements([bdx(bluer),1+bdx(bluer),2+bdx(bluer)],:) ...
    = [tmp(bluer,[3,4,5,7]);tmp(bluer,[1,6,5,4]);tmp(bluer,[6,2,7,5])];
newElements([bdx(bluel),1+bdx(bluel),2+bdx(bluel)],:) ...
    = [tmp(bluel,[1,2,5,9]);tmp(bluel,[3,8,5,2]);tmp(bluel,[8,4,9,5])];
newElements([bdx(b2blue),1+bdx(b2blue),2+bdx(b2blue)],:)=[tmp(...
    b2blue,[3,4,5,7]);tmp(b2blue,[1,6,5,4]);tmp(b2blue,[6,2,7,5])];
newElements([bdx(b2south),1+bdx(b2south),2+bdx(b2south), ...
    3+bdx(b2south),4+bdx(b2south),5+bdx(b2south)],:) ...
    = [tmp(b2south,[5,9,16,14]);tmp(b2south,[1,10,16,9]); ...
    tmp(b2south,[10,6,14,16]);tmp(b2south,[2,7,17,11]); ...
    tmp(b2south,[5,14,17,7]);tmp(b2south,[14,6,11,17])];
newElements([bdx(b2east),1+bdx(b2east),2+bdx(b2east), ...
    3+bdx(b2east),4+bdx(b2east),5+bdx(b2east)],:) ...
    = [tmp(b2east,[5,6,17,13]);tmp(b2east,[2,12,17,6]); ...
    tmp(b2east,[12,7,13,17]);tmp(b2east,[3,8,18,15]); ...
    tmp(b2east,[5,13,18,8]);tmp(b2east,[13,7,15,18])];
newElements([bdx(b2southeast),1+bdx(b2southeast),2+...
    bdx(b2southeast),3+bdx(b2southeast),4+bdx(b2southeast),...
    5+bdx(b2southeast)],:) = [tmp(b2southeast,[5,9,16,14]);...
    tmp(b2southeast,[1,10,16,9]);tmp(b2southeast,[10,6,14,16]);...
    tmp(b2southeast,[3,8,18,15]);tmp(b2southeast,[5,13,18,8]);...
    tmp(b2southeast,[13,7,15,18])];
nB = size(newElements,1)-rdx(end)+1;


