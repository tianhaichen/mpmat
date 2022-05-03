% This file implements the  Material Point Method
% 
% Two dimensional problems.
% The grid is a structured mesh consisting of 4-noded bilinear elements (Q4).
%
% Stress wave propagation in granular media. The 4 disks problem.
%
% Vinh Phu Nguyen
% Cardiff University, Wales, UK
% February 2014.

%%

addpath ../../grid/
addpath ../../basis/
addpath ../../particleGen/
addpath ../../constitutiveModels/
addpath ../../util/
addpath ../../geoMesh/
addpath ../../externals/PolyMesher/
addpath ../../postProcessing/

%%
clc
clear all
colordef white

I  = [1 0;0 1];

opts = struct('Color','rgb','Bounds','tight','FontMode','fixed','FontSize',20);
%exportfig(gcf,'splinecurve.eps',opts)


vtkFileName   = '../../results/mpm/4disks/mpm4disks';
vtkFileName1  = '../../results/mpm/4disks/grid';

plotNormal = 0;
contact    = 1; %either 1 or 0 (free contact in MPM)

%% Material properties
%

% sphere
K1      = 7;            % bulk modulus
mu1     = 1.5;          % shear modulus
lambda1 = K1 - 2/3*mu1;
E1      = 9*K1*mu1/(3*K1+mu1);
rho1    = 1e-9;           % density
nu1     = (3*K1-2*mu1)/2/(3*K1+mu1);

% plane = 10 times harder
K2      = 70;          % bulk modulus
mu2     = 15;          % shear modulus
lambda2 = K2 - 2/3*mu2;
E2      = 9*K2*mu2/(3*K2+mu2);
rho2    = 1e-8;         % density
nu2     = (3*K2-2*mu2)/2/(3*K2+mu2);

stressState ='PLANE_STRAIN'; % either 'PLANE_STRAIN' or "PLANE_STRESS
C1 = elasticityMatrix(E1,nu1,stressState);
C2 = elasticityMatrix(E2,nu2,stressState);



tic;

%% Computational grid (all length in mm)

ra    = 0.5;
l     = 8*ra + ra;
w     = 2*ra + 0.5*ra;
ratio = l/w;

noX0      = 100;        % number of elements along X direction
noY0      = floor(noX0/ratio); % number of elements along Y direction (to have square cells)
ghostCell = 0;

[grid]    = buildGrid2D(l,w,noX0,noY0, ghostCell);

node      = grid.node;
element   = grid.element;
deltax    = grid.deltax;
deltay    = grid.deltay;
elemCount = grid.elemCount;
nodeCount = grid.nodeCount;
numx2     = grid.numx;
numy2     = grid.numy;

%% generate material points
% disk1

ppc           = [2 2];
circle.center = [ra ra];
circle.radius = ra;

[res]             = generateMPForCircle(circle,ppc,grid);
res.position(:,2) = res.position(:,2) + 0.25*ra;

pCount        = size(res.position,1);
body1.volume  = res.volume;
body1.volume0 = res.volume;
body1.mass    = res.volume*rho1;
body1.coord   = res.position;
body1.deform  = repmat([1 0 0 1],pCount,1);     % gradient deformation
body1.stress  = zeros(pCount,3);                % stress
body1.strain  = zeros(pCount,3);                % strain
body1.velo    = zeros(pCount,2);                % velocity

% disk2
circle.center = [3*ra ra];
circle.radius = ra;

[res]             = generateMPForCircle(circle,ppc,grid);
res.position(:,2) = res.position(:,2) + 0.25*ra;
pCount        = size(res.position,1);
body2.volume  = res.volume;
body2.volume0 = res.volume;
body2.mass    = res.volume*rho1;
body2.coord   = res.position;
body2.deform  = repmat([1 0 0 1],pCount,1);     % gradient deformation
body2.stress  = zeros(pCount,3);                % stress
body2.strain  = zeros(pCount,3);                % strain
body2.velo    = zeros(pCount,2);                % velocity

% disk3
circle.center = [5*ra ra];
circle.radius = ra;

[res]             = generateMPForCircle(circle,ppc,grid);
res.position(:,2) = res.position(:,2) + 0.25*ra;
pCount        = size(res.position,1);
body3.volume  = res.volume;
body3.volume0 = res.volume;
body3.mass    = res.volume*rho1;
body3.coord   = res.position;
body3.deform  = repmat([1 0 0 1],pCount,1);     % gradient deformation
body3.stress  = zeros(pCount,3);                % stress
body3.strain  = zeros(pCount,3);                % strain
body3.velo    = zeros(pCount,2);                % velocity

% disk4
circle.center = [7*ra ra];
circle.radius = ra;

[res]             = generateMPForCircle(circle,ppc,grid);
res.position(:,2) = res.position(:,2) + 0.25*ra;
pCount        = size(res.position,1);
body4.volume  = res.volume;
body4.volume0 = res.volume;
body4.mass    = res.volume*rho1;
body4.coord   = res.position;
body4.deform  = repmat([1 0 0 1],pCount,1);     % gradient deformation
body4.stress  = zeros(pCount,3);                % stress
body4.strain  = zeros(pCount,3);                % strain
body4.velo    = zeros(pCount,2);                % velocity

% put all bodies in one variable
bodies    = cell(4,1);
bodies{1} = body1;
bodies{2} = body2;
bodies{3} = body3;
bodies{4} = body4;
bodyCount = length(bodies);

%% find elements to which particles belong to
% two data structures are used
% 1. particle -> element
% 2. element  -> particles

for ib=1:length(bodies)
    body      = bodies{ib};
    elems     = ones(length(body.volume),1);
    
    for ip=1:length(body.volume)
        x = body.coord(ip,1); y = body.coord(ip,2);
        e = floor(x/deltax) + 1 + numx2*floor(y/deltay);
        elems(ip) = e;
    end
    
    bodies{ib}.elements = unique(elems);
    bodies{ib}.nodes    = unique(element(bodies{ib}.elements,:));
    mpoints = cell(elemCount,1);
    for ie=1:elemCount
        id  = find(elems==ie);
        mpoints{ie}=id;
    end
    
    bodies{ib}.mpoints  = mpoints;
end

% boundary nodes
bottom = grid.bNodes;

%% plot mesh, particles

coords=[bodies{1}.coord;bodies{2}.coord;bodies{3}.coord;bodies{4}.coord];
hold on
plot_mesh(node,element,'Q4','k-',1.);
%plot_mesh(node,element(bodies{1}.elements,:),'Q4','cy-',2.1);
%plot_mesh(node,element(bodies{2}.elements,:),'Q4','r-',2.1);
plot(coords(:,1),coords(:,2),'k.','markersize',10);
%plot(coords2(:,1),coords2(:,2),'r.','markersize',10);
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

gBasis     = zeros(bodyCount,pCount,4);
gGradX     = zeros(bodyCount,pCount,4);
gGradY     = zeros(bodyCount,pCount,4);


%% check grid normals in a multiple body case

figure(100)
hold on
plot_mesh(node,element,'Q4','k-',1.);
plot(coords1(:,1),coords1(:,2),'k.','markersize',10);


for ib=1:bodyCount
    body      = bodies{ib};
    nodes     = body.nodes;
    [cellDensity,normals] = computeGridNormal(grid,body);
    
    for i=1:length(nodes)
        nid = nodes(i);
        xI  = node(nid,:);
        nI  = normals(nid,:);
        nI = nI / norm(nI);
        le = 200;
        plot([xI(1) xI(1)+le*nI(1)],[xI(2) xI(2)+le*nI(2)],'r-','LineWidth',2);
    end
end
axis off


ta  = [];           % time
xcm = [];           % center of mass position

%% Solver

disp([num2str(toc),'   SOLVING '])

tol   = 1e-14; % mass tolerance

c     = sqrt(E1/rho1);
dtime = 0.00005;
time  = 0.3;
t     = 0;

interval     = 10;
nsteps = floor(time/dtime);

pos   = cell(nsteps,1);
vel   = cell(nsteps,1);
istep = 1;

while ( t < 0 )
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
        neforce(:)   = 0;
        
        body      = bodies{ib};
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
                stress =  bodies{ib}.stress(pid,:);
                
                pt(1)= (2*xp(1)-(enode(1,1)+enode(2,1)))/deltax;
                pt(2)= (2*xp(2)-(enode(2,2)+enode(3,2)))/deltay;
                [N,dNdxi]=lagrange_basis('Q4',pt);   % element shape functions
                J0       = enode'*dNdxi;             % element Jacobian matrix
                invJ0    = inv(J0);
                dNdx     = dNdxi*invJ0;
                % store grid basis functions and gradients
                gBasis(ib,pid,:) = N;
                gGradX(ib,pid,:) = dNdx(:,1);
                gGradY(ib,pid,:) = dNdx(:,2);
        
                % loop over nodes of current element "ie"
                for i=1:length(esctr)
                    id    = esctr(i);
                    dNIdx = dNdx(i,1);
                    dNIdy = dNdx(i,2);
                    nmass(id)       = nmass(id)       + N(i)*Mp;
                    nmomentum(id,:) = nmomentum(id,:) + N(i)*Mp*vp;
                    niforce(id,1)   = niforce(id,1) - Vp*(stress(1)*dNIdx + stress(3)*dNIdy);
                    niforce(id,2)   = niforce(id,2) - Vp*(stress(3)*dNIdx + stress(2)*dNIdy);
                    if (ib==1) neforce(id,:)   = neforce(id,:) + Mp*N(i)*bodyf; end
                end
            end
        end
        
        activeNodes = bodies{ib}.nodes;
        
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
            nmomentum(activeNodes,:) = nmomentum(activeNodes,:) + (niforce(activeNodes,:) + neforce(activeNodes,:))*dtime;
            % store uncorrected updated body velocity and acceleration v_I^{t+\Delta t}
            nvelo(activeNodes,2*ib-1) = nmomentum(activeNodes,1).*massInv;
            nvelo(activeNodes,2*ib)   = nmomentum(activeNodes,2).*massInv;
            
            nacce(activeNodes,2*ib-1) = (niforce(activeNodes,1) + neforce(activeNodes,1)).*massInv;
            nacce(activeNodes,2*ib  ) = (niforce(activeNodes,2) + neforce(activeNodes,2)).*massInv;
        end
        
        % store system momentum and mass
        nmomentumS(activeNodes,:) = nmomentumS(activeNodes,:) + nmomentum(activeNodes,:);
        nmassS    (activeNodes  ) = nmassS    (activeNodes  ) + nmass(activeNodes);
        niforceS  (activeNodes,:) = niforceS  (activeNodes,:) + niforce(activeNodes,:);
    end
    
    nvelo(bottom,:) = 0;
    nacce(bottom,:) = 0;
    
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
        contactNodes = intersect(bodies{1}.nodes,bodies{2}.nodes);
        if ~isempty(contactNodes)
            %disp('contact is happening')
            for ib=1:bodyCount
                body      = bodies{ib};
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
                le = 200;
                plot([xI(1) xI(1)+le*nI(1)],[xI(2) xI(2)+le*nI(2)],'k-','LineWidth',3);
                
                nI  = bodies{2}.normals(nid,:);
                nI = nI / norm(nI);
                le = 200;
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
                nI       = bodies{ib}.normals(id,:);
                nI       = nI / norm(nI);
                deltaVe  = velo1 - velocm;
                D        = dot(deltaVe, nI);
                C        = deltaVe(1)*nI(2) - deltaVe(2)*nI(1);
                absC     = abs(C);
                muPrime  = min(fric,absC/D);
                if ( D >= 0 )
                    nvelo(id,2*ib-1:2*ib) = velo1 - D*( nI + (muPrime/absC)*[nI(2)*C -nI(1)*C] );
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
        body      = bodies{ib};
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
                % retrieve the grid functions/grads
                N    = gBasis(ib,pid,:);
                dNdx = [squeeze(gGradX(ib,pid,:)) squeeze(gGradY(ib,pid,:))];
                
                Lp   = zeros(2,2);
                for i=1:length(esctr)
                    id = esctr(i);
                    vI = nvelo(id,indices);
                    aI = nacce(id,indices);
                    vp  = vp  + dtime * N(i)*aI;
                    xp  = xp  + dtime * N(i)*vI;
                    Lp  = Lp + vI'*dNdx(i,:);
                end
                
                bodies{ib}.velo(pid,:) = vp;
                bodies{ib}.coord(pid,:)= xp;
                
                % update stress last
                
                F       = ([1 0;0 1] + Lp*dtime)*reshape(bodies{ib}.deform(pid,:),2,2);
                bodies{ib}.deform(pid,:) = reshape(F,1,4);
                bodies{ib}.volume(pid  ) = det(F)*bodies{ib}.volume0(pid);
                J       = det(F);
                
%                 if ( ~isreal(F) || J < 0 )
%                     error('imaginary F')
%                 end
%                 
%                 b       = F*F';
%                 mu      = body.mu;
%                 lambda  = body.lambda;
%                 sigma   = 1/J*( mu*(b-I) + lambda*log(J)*I );
%                 bodies{ib}.stress(pid,:)  = [sigma(1,1) sigma(2,2)  sigma(1,2) ];
%                 
                dEps    = dtime * 0.5 * (Lp+Lp');
                dsigma  = body.Cmatrix * [dEps(1,1);dEps(2,2);2*dEps(1,2)] ;
                bodies{ib}.stress(pid,:)  =  bodies{ib}.stress(pid,:)  + dsigma';
            end
        end
    end
    
    % update the element particle list
    xx = 0;
    for ib=1:length(bodies)
        body      = bodies{ib};
        elems     = ones(length(body.volume),1);
        
        for ip=1:length(body.volume)
            x = body.coord(ip,1);
            y = body.coord(ip,2);
            
%             if ( x > grid.xmax || x < grid.xmin  || y > grid.ymax || y < grid.ymin )
%                 x,y
%                 error('OUT OF CELL');
%             end
%             
%             if (~isreal(x) || ~isreal(y))
%                 error('imaginary particle position');
%             end
            
            m = body.mass(ip);
            e = floor(x/deltax) + 1 + numx2*floor(y/deltay);
            elems(ip) = e;
            
            if (ib==1) xx = xx + m*x; end
        end
        
        bodies{ib}.elements = unique(elems);
        bodies{ib}.nodes    = unique(element(bodies{ib}.elements,:));
        mpoints = cell(elemCount,1);
        for ie=1:elemCount
            id  = find(elems==ie);
            mpoints{ie}=id;
        end
        
        bodies{ib}.mpoints  = mpoints;
    end
    
    xx  = xx / sum(bodies{1}.mass);
    
    % store time,velocty for plotting
    
    ta  = [ta;t];
    xcm = [xcm;xx];
    
    % VTK output
    
    if (  mod(istep-1,interval) == 0 )
        xp = [bodies{1}.coord;bodies{2}.coord];
        s  = [bodies{1}.stress;bodies{2}.stress];
        stress = [s sum(s,2)/3];
        data.stress = stress; 
        data.velo=[bodies{1}.velo;bodies{2}.velo];
        vtkFile = sprintf('%s%d',vtkFileName,istep-1);
        VTKParticles(xp,vtkFile,data);
    end
    
    
    % advance to the next time step
    
    t = t + dtime;
    istep = istep + 1;
end


% 
% Ux= zeros(size(node,1),1);
% Uy= zeros(size(node,1),1);
% sigmaXX = zeros(size(node,1),1);
% sigmaYY = zeros(size(node,1),1);
% sigmaXY = zeros(size(node,1),1);
% 
% VTKPostProcess(node,element,2,'Quad4',vtkFileName1,...
%     [sigmaXX sigmaYY sigmaXY],[Ux Uy]);

%% post processing

disp([num2str(toc),'   POST-PROCESSING '])

% exact solution

tt = 0:0.01:t;
xx1 = zeros(length(tt),1);
xx2 = zeros(length(tt),1);


for i=1:length(tt)
    xx1(i) = ra + 0.5*g*tt(i)^2*(sin(theta)-fric*cos(theta));
    xx2(i) = ra + 1/3*g*tt(i)^2*sin(theta);
end

xcm = xcm/1000;
xx1 = xx1/1000;
xx2 = xx2/1000;

% noslip = load('rolling-sphere-noslip.mat');
% wislip = load('rolling-sphere-slip.mat');

figure
set(gca,'FontSize',14)
hold on
plot(tt,xx1,'r-','LineWidth',2.2);
plot(ta,xcm,'black--','LineWidth',2);
%plot(noslip.ta,noslip.xcm,'r--','LineWidth',2);
xlabel('Time [s]')
ylabel('center of mass position [m]')
legend('stick-analytical','stick-MPM')
%set(gca,'XTick',[0 0.5 1.0 1.5 2.0])
%axis([0 2 0 16])

disp([num2str(toc),'   DONE '])
