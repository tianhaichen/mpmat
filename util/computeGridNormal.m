function [cellDensity,normals] = computeGridNormal(grid,body) 

%% retrieve grid data
node      = grid.node;
element   = grid.element;
elemCount = grid.elemCount;
numx2     = grid.numx;
numy2     = grid.numy;
deltax    = grid.deltax;
deltay    = grid.deltay;
% retrieve body data
elems     = body.elements;
mpoints   = body.mpoints;
xp        = body.coord;
Mp        = body.mass;

%% cell density computation
cellDensity = zeros(elemCount,1);
volInv      = 1/(deltax*deltay);
for i=1:elemCount
    ie        = i;
    neighbors = getNeighbors(ie, numx2, numy2);
    center    = 1/4*sum( node(element(ie,:),:) );
    for in=1:length(neighbors)
        elemId = neighbors(in);
        mpts   = mpoints{elemId};
        for p=1:length(mpts)
            pid  = mpts(p);
            x    = xp(pid,:);
            [phi,~]=getQuadraticBspline2D(x-center,deltax,deltay);
            cellDensity(ie) = cellDensity(ie) + phi*Mp(pid);
        end        
    end
    cellDensity(ie) = cellDensity(ie) * volInv;
end


%% Now, compute normals at nodes of all elements

normals = zeros(length(node),2);

for iel = 1 : size(elems,1)
    eId    = elems(iel);
    sctr   = element(eId,:);
    dens   = cellDensity(eId);
    center = 1/4*sum( node(element(eId,:),:) );
    for in=1:4
        nId        = sctr(in);
        xI         = node(nId,:);
        [~,dNdx]   = getMPM2D(center-xI,deltax,deltay);
        normals(nId,:) = normals(nId,:) + dNdx*dens;
    end
end
