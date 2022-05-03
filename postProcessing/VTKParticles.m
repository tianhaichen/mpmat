% Write Material Point Method results to VTK files
% which can be processed by ViSIT and/or Paraview.
% Written by:
% Vinh Phu Nguyen, nvinhphu@gmail.com
% 17 February 2014

function VTKParticles(node,vtuFile,data)



% node:     particle positions at time step
% vtuFile:  VTK file to be written
% data:    data to be written to file


dim      = size(node,2);
numNodes = size(node,1);
x        = node;

sigma    = data.stress;


if (dim==2)
    x(:,3) = 0;
end

% Output files

outfileVTU  = strcat(vtuFile, '.vtp');
results_vtu = fopen(outfileVTU, 'wt');

%% Write headers
fprintf(results_vtu, '<VTKFile type="PolyData"  version="0.1"   > \n');
fprintf(results_vtu, '<PolyData> \n');
fprintf(results_vtu, '<Piece  NumberOfPoints="  %g" NumberOfVerts=" %g" NumberOfLines=" %g" NumberOfStrips=" %g" NumberOfPolys=" %g"> \n',...
    numNodes, 0,0,0,0);


%% Write point coordinates

fprintf(results_vtu, '<Points> \n');
fprintf(results_vtu, '<DataArray  type="Float64"  NumberOfComponents="3"  format="ascii" > \n');

for i=1:numNodes
    fprintf(results_vtu, '%f %f %f \n',  x(i,1:3));
end

fprintf(results_vtu, '</DataArray> \n');
fprintf(results_vtu, '</Points> \n');

%% write point data

names = {'sigmaXX', 'sigmaYY','sigmaXY'};

fprintf(results_vtu, '<PointData  Scalars="vonMises" Vectors="sigma"> \n');

fprintf(results_vtu, '<DataArray  type="Float64"  Name="vonMises" format="ascii"> \n');

for i=1:numNodes
    
    fprintf(results_vtu, '%f   ', sigma(i,4));
    
    fprintf(results_vtu, '\n');
end

fprintf(results_vtu, '</DataArray> \n');

if (isfield(data,'pstrain'))
    pstrain  = data.pstrain; % equivalent plastic strain
    fprintf(results_vtu, '<DataArray  type="Float64"  Name="pStrain" format="ascii"> \n');
    
    for i=1:numNodes
        
        fprintf(results_vtu, '%f   ', pstrain(i));
        
        fprintf(results_vtu, '\n');
    end
    fprintf(results_vtu, '</DataArray> \n');
end


fprintf(results_vtu, '<DataArray  type="Float64"  Name="sigmaXX" format="ascii"> \n');

for i=1:numNodes
    fprintf(results_vtu, '%f   ', sigma(i,1) );
    
    fprintf(results_vtu, '\n');
end

fprintf(results_vtu, '</DataArray> \n');

fprintf(results_vtu, '<DataArray  type="Float64"  Name="sigmaYY" format="ascii"> \n');

for i=1:numNodes
    fprintf(results_vtu, '%f   ', sigma(i,2) );
    
    fprintf(results_vtu, '\n');
end

fprintf(results_vtu, '</DataArray> \n');

fprintf(results_vtu, '<DataArray  type="Float64"  Name="sigmaXY" format="ascii"> \n');

for i=1:numNodes
    fprintf(results_vtu, '%f   ', sigma(i,3) );
    
    fprintf(results_vtu, '\n');
end

fprintf(results_vtu, '</DataArray> \n');

if (isfield(data,'velo'))
    velo     = data.velo;    % particle velocity 
    fprintf(results_vtu, '<DataArray  type="Float64"  Name="velocity" NumberOfComponents="3" format="ascii"> \n');
    
    for i=1:numNodes
        fprintf(results_vtu, '%f   ', velo(i,1) );
        fprintf(results_vtu, '%f   ', velo(i,2) );
        fprintf(results_vtu, '%f   ', 0         );
        
        fprintf(results_vtu, '\n');
    end
    
    fprintf(results_vtu, '</DataArray> \n');
end

if (isfield(data,'color'))
    color     = data.color;    % particle velocity 
    fprintf(results_vtu, '<DataArray  type="Float64"  Name="color" NumberOfComponents="1" format="ascii"> \n');
    
    for i=1:numNodes
        fprintf(results_vtu, '%f   ', color(i) );
        
        fprintf(results_vtu, '\n');
    end
    
    fprintf(results_vtu, '</DataArray> \n');
end

if (isfield(data,'damage'))
    dam     = data.damage;    % particle velocity 
    fprintf(results_vtu, '<DataArray  type="Float64"  Name="damage" NumberOfComponents="1" format="ascii"> \n');
    
    for i=1:numNodes
        fprintf(results_vtu, '%f   ', dam(i) );
        
        fprintf(results_vtu, '\n');
    end
    
    fprintf(results_vtu, '</DataArray> \n');
end

fprintf(results_vtu, '</PointData> \n');

% end of VTK file

fprintf(results_vtu, '</Piece> \n');
fprintf(results_vtu, '</PolyData> \n');
fprintf(results_vtu, '</VTKFile> \n');

% close file
fclose(results_vtu);
