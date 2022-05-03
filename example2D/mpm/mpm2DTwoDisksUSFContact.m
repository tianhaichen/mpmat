% This file implements the Material Point Method of Sulsky 1994.
% Two dimensional problems.
% The grid is a structured mesh consisting of 4-noded bilinear elements (Q4).
% USL formulation and the contact algorithm of Bardenhangen et al. (2000).
% Use data structures suitable for contact bodies.
%
% The code can switch between standard MPM (no-slip contact) and contact MPM.
%
% Two elastic disks come into contact.
% Example taken from Sulsky et al. 1994 paper.
%
% Vinh Phu Nguyen
% Cardiff University, Wales, UK
% March 2014.

%%

addpath ../../grid/
addpath ../../basis/
addpath ../../particleGen/
addpath ../../constitutiveModels/
addpath ../../util/
addpath ../../postProcessing/
addpath ../../geoMesh/

%%
clc
clear all
colordef white

opts = struct('Color','rgb','Bounds','tight','FontMode','fixed','FontSize',20);
%exportfig(gcf,'splinecurve.eps',opts)


%% Material properties
%

E   = 1000;        % Young's modulus
nu  = 0.3;         % Poisson ratio
rho = 1000;        % density
kappa = 3-4*nu;    % Kolosov constant
mu    = E/2/(1+nu);% shear modulus

v   = 0.1;

stressState ='PLANE_STRAIN'; % either 'PLANE_STRAIN' or "PLANE_STRESS
C = elasticityMatrix(E,nu,stressState);
D = inv(C);

vtkFileName  = 'mpm2DTwoDisks';
vtkFileName1  = '../results/mpm2DTwoDisksReleaseGrid';

plotNormal = 0;
contact    = 1; %either 1 or 0 (free contact in MPM)

tic;

disp([num2str(toc),'   INITIALISATION '])

%% Computational grid

l = 1;

numx2 = 25;      % number of elements along X direction
numy2 = 25;      % number of elements along Y direction

[grid]= buildGrid2D(l,l,numx2,numy2, 0);


%% generate material points

[W,Q]=quadrature(  4, 'GAUSS', 2 ); % 2x2 Gaussian quadrature


% body1

center = [0.2 0.2];
radius = 0.2;


volume = [];
mass   = [];
coord  = [];


for e=1:elemCount                          % start of element loop
    sctr = element(e,:);                   %  element scatter vector
    pts  = node(sctr,:);
    
    for q=1:size(W,1)                           % quadrature loop
        pt=Q(q,:);                              % quadrature point
        wt=W(q);                                % quadrature weight
        [N,dNdxi]=lagrange_basis('Q4',pt);
        J0 = pts'*dNdxi;
        x  = N'*pts;
        r  = norm(x-center);
        if ( r-radius < 0 )
            volume  = [volume;wt*det(J0)];
            mass    = [mass; wt*det(J0)*rho];
            coord   = [coord;x];
        end
    end
end

pCount = length(volume);

body1.volume = volume;
body1.volume0 = volume;
body1.mass   = mass;
body1.coord  = coord;
body1.deform = repmat([1 0 0 1],pCount,1);     % gradient deformation
body1.stress = zeros(pCount,3);                % stress
body1.strain = zeros(pCount,3);                % strain
body1.velo   = ones(pCount,2)*v;               % velocity

%body1.velo(:,2) = 0;

% body 2
center = [0.8 0.8];
radius = 0.2;

volume = [];
mass   = [];
coord  = [];

for e=1:elemCount                          % start of element loop
    sctr = element(e,:);          %  element scatter vector
    pts  = node(sctr,:);
    
    for q=1:size(W,1)                      % quadrature loop
        pt=Q(q,:);                              % quadrature point
        wt=W(q);                                % quadrature weight
        [N,dNdxi]=lagrange_basis('Q4',pt);
        J0 = pts'*dNdxi;
        x  = N'*pts;
        r  = norm(x-center);
        if ( r-radius < 0 )
            volume  = [volume;wt*det(J0)];
            mass    = [mass; wt*det(J0)*rho];
            coord   = [coord;x];
        end
    end
end

pCount = length(volume);

body2.volume = volume;
body2.volume0 = volume;
body2.mass   = mass;
body2.coord  = coord;
body2.deform = repmat([1 0 0 1],pCount,1);     % gradient deformation
body2.stress = zeros(pCount,3);                % stress
body2.strain = zeros(pCount,3);                % strain
body2.velo   = -ones(pCount,2)*v;              % velocity

%body2.velo(:,2) = 0;

%bodies = cell(2,1);

bodies(1) = body1;
bodies(2) = body2;

bodyCount = 2;

%% find elements to which particles belong to
% two data structures are used
% 1. particle -> element
% 2. element  -> particles


for ib=1:length(bodies)
    body      = bodies(ib);
    elems     = ones(length(body.volume),1);
    
    for ip=1:length(body.volume)
        x = body.coord(ip,1); y = body.coord(ip,2);
        e = floor(x/deltax) + 1 + numx2*floor(y/deltay);
        elems(ip) = e;
    end
    
    bodies(ib).elements = unique(elems);
    bodies(ib).nodes    = unique(element(bodies(ib).elements,:));
    
    mpoints = cell(elemCount,1);
    for ie=1:elemCount
        id  = find(elems==ie);
        mpoints{ie}=id;
    end
    
    
    bodies(ib).mpoints  = mpoints;
end


%% plot mesh, particles

coords=[bodies(1).coord;bodies(2).coord];
hold on
plot_mesh(node,element,'Q4','k-',1.);
%plot_mesh(node,element(bodies{1}.elements,:),'Q4','cy-',2.1);
%plot_mesh(node,element(bodies{2}.elements,:),'Q4','r-',2.1);
plot(coords(:,1),coords(:,2),'k.','markersize',10);
axis off

%% node quantities

nmassS    = zeros(nodeCount,1);  % nodal mass vector of the system
nmomentumS= zeros(nodeCount,2);  % nodal momentum vector of the system
niforceS  = zeros(nodeCount,2);  % nodal internal force of the system
nmass     = zeros(nodeCount,1);  % nodal mass vector of each body
nmomentum = zeros(nodeCount,2);  % nodal momentum vector of each body
niforce   = zeros(nodeCount,2);  % nodal internal force vector
neforce   = zeros(nodeCount,2);  % nodal external force vector
nvelo     = zeros(nodeCount,2*(bodyCount+1));  % nodal velocities (body1,body2,center of mass)
nvelo0    = nvelo;
nacce     = zeros(nodeCount,2*bodyCount);

%% check grid normals in a multiple body case

figure(100)
hold on
plot_mesh(node,element,'Q4','k-',1.);
plot(coords(:,1),coords(:,2),'k.','markersize',10);


for ib=1:bodyCount
    body      = bodies(ib);
    nodes     = body.nodes;
    [cellDensity,normals] = computeGridNormal(grid,body);
    
    for i=1:length(nodes)
        nid = nodes(i);
        xI  = node(nid,:);
        nI  = normals(nid,:);
        nI = nI / norm(nI);
        le = 0.06;
        plot([xI(1) xI(1)+le*nI(1)],[xI(2) xI(2)+le*nI(2)],'r-','LineWidth',2);
    end
end
axis off


ta = [];           % time
ka = [];           % kinetic energy
sa = [];           % strain energy

%% Solver

disp([num2str(toc),'   SOLVING '])

tol   = 1e-12; % mass tolerance

c     = sqrt(E/rho);
dtime = 0.001;
time  = 3.3;
t     = 0;

interval     = 20;
nsteps = floor(time/dtime);

pos   = cell(nsteps,1);
vel   = cell(nsteps,1);
istep = 1;

while ( t < time )
    disp(['time step ',num2str(t)])
    
    nvelo(:)     = 0;
    nmassS(:)     = 0;
    nmomentumS(:) = 0;
    %% loop over bodies (update nodal momenta without contact)
    for ib=1:bodyCount
        %% reset grid data (body contribution)
        nmass(:)     = 0;
        nmomentum(:) = 0;
        niforce(:)   = 0;
        
        body      = bodies(ib);
        elems     = body.elements;
        mpoints   = body.mpoints;
        for ie=1:length(elems)         % loop over computational cells or elements
            e     = elems(ie);
            esctr = element(e,:);      % element connectivity
            enode = node(esctr,:);     % element node coords
            mpts  = mpoints{e};        % particles inside element e
            for p=1:length(mpts)       % loop over particles
                pid    = mpts(p);
                xp     = body.coord(pid,:);
                Mp     = body.mass(pid);
                vp     = body.velo(pid,:);
                Vp   = body.volume(pid);
                stress =  bodies(ib).stress(pid,:);
                
                pt(1)= (2*xp(1)-(enode(1,1)+enode(2,1)))/deltax;
                pt(2)= (2*xp(2)-(enode(2,2)+enode(3,2)))/deltay;
                [N,dNdxi]=lagrange_basis('Q4',pt);   % element shape functions
                J0       = enode'*dNdxi;             % element Jacobian matrix
                invJ0    = inv(J0);
                dNdx     = dNdxi*invJ0;
                % loop over nodes of current element "ie"
                for i=1:length(esctr)
                    id    = esctr(i);
                    dNIdx = dNdx(i,1);
                    dNIdy = dNdx(i,2);
                    nmass(id)       = nmass(id)       + N(i)*Mp;
                    nmomentum(id,:) = nmomentum(id,:) + N(i)*Mp*vp;
                    niforce(id,1)   = niforce(id,1) - Vp*(stress(1)*dNIdx + stress(3)*dNIdy);
                    niforce(id,2)   = niforce(id,2) - Vp*(stress(3)*dNIdx + stress(2)*dNIdy);
                end
            end
        end
        
        activeNodes = bodies(ib).nodes;
        
        if (contact)
            massInv = 1./nmass(activeNodes);
            smallMassIds = find(massInv > 1e10);
            if ~isempty(smallMassIds)
                disp('small mass!!!')
                massInv(smallMassIds) = 0;
            end
            % store old velocity v_I^t
            nvelo0(activeNodes,2*ib-1) = nmomentum(activeNodes,1).*massInv;
            nvelo0(activeNodes,2*ib)   = nmomentum(activeNodes,2).*massInv;
            % update body nodal momenta
            nmomentum(activeNodes,:) = nmomentum(activeNodes,:) + niforce(activeNodes,:)*dtime;
            % store uncorrected updated body velocity and acceleration v_I^{t+\Delta t}
            nvelo(activeNodes,2*ib-1) = nmomentum(activeNodes,1).*massInv;
            nvelo(activeNodes,2*ib)   = nmomentum(activeNodes,2).*massInv;
            
            nacce(activeNodes,2*ib-1) = niforce(activeNodes,1).*massInv;
            nacce(activeNodes,2*ib  ) = niforce(activeNodes,2).*massInv;
        end
        
        % store system momentum and mass
        nmomentumS(activeNodes,:) = nmomentumS(activeNodes,:) + nmomentum(activeNodes,:);
        nmassS    (activeNodes  ) = nmassS    (activeNodes  ) + nmass(activeNodes);
        niforceS  (activeNodes,:) = niforceS  (activeNodes,:) + niforce(activeNodes,:);
    end
    
    if (~contact)
        massInv = 1./nmassS(activeNodes);
        smallMassIds = find(massInv > 1e10);
        if ~isempty(smallMassIds)
            disp('small mass!!!')
            massInv(smallMassIds) = 0;
        end
        nvelo(activeNodes,2*bodyCount+1)  = nmomentumS(activeNodes,1).*massInv;
        nvelo(activeNodes,2*bodyCount+2)  = nmomentumS(activeNodes,2).*massInv;
        nacce(activeNodes,2*bodyCount+1)  = niforceS  (activeNodes,1).*massInv;
        nacce(activeNodes,2*bodyCount+2)  = niforceS  (activeNodes,2).*massInv;
    end
    
    % find contact nodes, actually common nodes between two bodies
    if contact
        contactNodes = intersect(bodies(1).nodes,bodies(2).nodes);
        if ~isempty(contactNodes)
            %disp('contact is happening')
            for ib=1:bodyCount
                body      = bodies(ib);
                nodes     = body.nodes;
                [cellDensity,normals] = computeGridNormal(grid,body);
                bodies{ib}.normals = normals;
            end
            % pause
        end
        
        %     setdiff(contactNodes,commonNodes)
        if ~isempty(contactNodes) && (  mod(istep-1,80) == 0 ) && plotNormal
            figure
            coords1=[bodies{1}.coord];
            coords2=[bodies{2}.coord];
            hold on
            plot_mesh(node,element,'Q4','k-',1.);
            %plot_mesh(node,element(bodies{1}.elements,:),'Q4','cy-',2.1);
            %plot_mesh(node,element(bodies{2}.elements,:),'Q4','r-',2.1);
            plot(coords1(:,1),coords1(:,2),'k.','markersize',20);
            plot(coords2(:,1),coords2(:,2),'r.','markersize',15);
            plot(node(contactNodes,1),node(contactNodes,2),'rs','markersize',15);
             %plot(node(activeNodes,1),node(activeNodes,2),'rs','markersize',15);
            for i=1:length(contactNodes)
                nid = contactNodes(i);
                xI  = node(nid,:);
                nI  = bodies{1}.normals(nid,:);
                nI = nI / norm(nI);
                le = 0.09;
                plot([xI(1) xI(1)+le*nI(1)],[xI(2) xI(2)+le*nI(2)],'k-','LineWidth',3);
                
                nI  = bodies{2}.normals(nid,:);
                nI = nI / norm(nI);
                le = 0.06;
                plot([xI(1) xI(1)+le*nI(1)],[xI(2) xI(2)+le*nI(2)],'r-','LineWidth',3);
            end
            axis off
        end
        
        %% correct contact node velocities
        
        for ib=1:bodyCount
            for in=1:length(contactNodes)
                id       =  contactNodes(in);
                velo1    = nvelo(id,2*ib-1:2*ib);
                
                velocm   = [0 0];
                
                if nmassS(id) > tol
                    velocm   = nmomentumS(id,:)/nmassS(id);
                else
                    disp('small mass detected')
                end
                nI       = bodies(ib).normals(id,:);
                nI       = nI / norm(nI);
                alpha    = dot(velo1 - velocm, nI);
                if ( alpha >= 0 )
                    nvelo(id,2*ib-1:2*ib) = velo1 - alpha*nI;
                    nacce(id,2*ib-1:2*ib) = (1/dtime)*( nvelo(id,2*ib-1:2*ib) - nvelo0(id,2*ib-1:2*ib) );
                    % disp('approaching')
                else
                    % disp('separating')
                end
            end
        end
    end
    
    %% update particle velocity and position and stresses
    k = 0; u = 0;
    for ib=1:bodyCount
        body      = bodies(ib);
        elems     = body.elements;
        mpoints   = body.mpoints;
        if (contact)
            indices = 2*ib-1:2*ib;
        else
            indices = 2*bodyCount+1:2*bodyCount+2;
        end
        % loop over computational cells or elements
        for ie=1:length(elems)
            e     = elems(ie);
            esctr = element(e,:);      % element connectivity
            enode = node(esctr,:);     % element node coords
            mpts  = mpoints{e};       % particles inside element e
            % loop over particles
            for p=1:length(mpts)
                pid  = mpts(p);
                xp   = body.coord(pid,:);
                Mp   = body.mass(pid);
                vp   = body.velo(pid,:);
                Vp   = body.volume(pid);
                
                pt(1)= (2*xp(1)-(enode(1,1)+enode(2,1)))/deltax;
                pt(2)= (2*xp(2)-(enode(2,2)+enode(3,2)))/deltay;
                
                [N,dNdxi]=lagrange_basis('Q4',pt);   % element shape functions
                J0       = enode'*dNdxi;             % element Jacobian matrix
                invJ0    = inv(J0);
                dNdx     = dNdxi*invJ0;
                
                Lp   = zeros(2,2);
                for i=1:length(esctr)
                    id = esctr(i);
                    vI = nvelo(id,indices);
                    aI = nacce(id,indices);
                    vp  = vp  + dtime * N(i)*aI;
                    xp  = xp  + dtime * N(i)*vI;
                    Lp  = Lp + vI'*dNdx(i,:);
                end
                
                bodies(ib).velo(pid,:) = vp;
                bodies(ib).coord(pid,:)= xp;
                
                % update stress last
                
                
                F       = ([1 0;0 1] + Lp*dtime)*reshape(bodies(ib).deform(pid,:),2,2);
                bodies(ib).deform(pid,:) = reshape(F,1,4);
                bodies(ib).volume(pid  ) = det(F)*bodies(ib).volume0(pid);
                dEps    = dtime * 0.5 * (Lp+Lp');
                dsigma  = C * [dEps(1,1);dEps(2,2);2*dEps(1,2)] ;
                bodies(ib).stress(pid,:)  = bodies(ib).stress(pid,:) + dsigma';
                bodies(ib).strain(pid,:)  = bodies(ib).strain(pid,:) + [dEps(1,1) dEps(2,2) 2*dEps(1,2)];
                
                % compute strain, kinetic energies
                vp   = bodies(ib).velo(pid,:);
                k = k + 0.5*(vp(1)^2+vp(2)^2)*Mp;
                u = u + 0.5*Vp*bodies(ib).stress(pid,:)*bodies(ib).strain(pid,:)';
            end
        end
    end
    
    % update the element particle list
    
    for ib=1:length(bodies)
        body      = bodies(ib);
        elems     = ones(length(body.volume),1);
        
        for ip=1:length(body.volume)
            x = body.coord(ip,1); y = body.coord(ip,2);
            e = floor(x/deltax) + 1 + numx2*floor(y/deltay);
            elems(ip) = e;
        end
        
        bodies(ib).elements = unique(elems);
        bodies(ib).nodes    = unique(element(bodies(ib).elements,:));
        mpoints = cell(elemCount,1);
        for ie=1:elemCount
            id  = find(elems==ie);
            mpoints{ie}=id;
        end
        
        bodies(ib).mpoints  = mpoints;
    end
    
    % store time,velocty for plotting
    
    ta = [ta;t];
    ka = [ka;k];
    sa = [sa;u];
    
    % VTK output
    
    if (  mod(istep-1,interval) == 0 )
        xp = [bodies(1).coord;bodies(2).coord];
        s  = [bodies(1).stress;bodies(2).stress];
        stress = [s sum(s,2)/3];
        data.stress = stress; data.pstrain=[];
        vtkFile = sprintf('../results/mpm/two-disks-contact/%s%d',vtkFileName,istep-1);
        VTKParticles(xp,vtkFile,data);
    end
    
    
    % advance to the next time step
    
    t = t + dtime;
    istep = istep + 1;
end


%% post processing

disp([num2str(toc),'   POST-PROCESSING '])

pvdFile = fopen(strcat('../results/',vtkFileName,'.pvd'), 'wt');

fprintf(pvdFile,'<VTKFile byte_order="LittleEndian" type="Collection" version="0.1">\n');
fprintf(pvdFile,'<Collection>\n');

for i = 1:nsteps
    if (  mod(i,interval) == 0 )
        vtuFile = sprintf('%s%d%s',vtkFileName,i,'.vtp');
        fprintf(pvdFile,'<DataSet file=''%s'' groups='''' part=''0'' timestep=''%d''/>\n',vtuFile,i);
    end
end

fprintf(pvdFile,'</Collection>\n');
fprintf(pvdFile,'</VTKFile>\n');

fclose(pvdFile);


Ux= zeros(size(node,1),1);
Uy= zeros(size(node,1),1);
sigmaXX = zeros(size(node,1),1);
sigmaYY = zeros(size(node,1),1);
sigmaXY = zeros(size(node,1),1);

VTKPostProcess(node,element,2,'Quad4',vtkFileName1,...
    [sigmaXX sigmaYY sigmaXY],[Ux Uy]);

% plot kinetic, strain energies

figure
set(gca,'FontSize',14)
hold on
plot(ta(1:end-8),ka(1:end-8),'b-','LineWidth',1.6);
plot(ta(1:end-8),sa(1:end-8),'r--','LineWidth',2);
plot(ta(1:end-8),ka(1:end-8)+sa(1:end-8),'g-','LineWidth',2.1);
xlabel('Time')
ylabel('Energy')
legend('kinetic','strain','total')
%set(gca,'XTick',[0 0.5 1.0 1.5 2.0])
%axis([0 2.1 0 3])

disp([num2str(toc),'   DONE '])
