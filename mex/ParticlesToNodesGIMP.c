#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <float.h>
#include "matrix.h"
#include "mex.h"
#include "util.h"
#include "basis.h"


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	/*	Interpolate from particles to grid nodes used with GIMP.
	//
	// We expect the function to be called as :
        // [nmass,nmomenta,nforce] = ParticlesToNodesGIMP(bodies,mesh)
	// bodies: bodies in the simulation. Bodies are stored in a cell array so that
        // bodies{1} represents the 1st body which is a structure that contains many fields. 
        // bodies{ib}.coord => particle coordinates for example.
        // mesh:   background grid
        //
        // VP Nguyen
        // Adelaide, South Australia, August 2014.
        */
   const mxArray* bodies;
         mxArray  *masst, *body, *coordp;
         double   *mass, *vol, *coord, *velo, *stress, *gra;
   mwSize          bodyCount, particleCount;
   mwIndex         ib;

   /* get the inputs from Matlab*/
   bodies    = prhs[0];
   bodyCount = mxGetNumberOfElements(prhs[0]);
      
   double* phx  = mxGetPr(mxGetField(prhs[1], 0, "deltax"));
   double* phy  = mxGetPr(mxGetField(prhs[1], 0, "deltay"));
   double* pnx  = mxGetPr(mxGetField(prhs[1], 0, "numx"));
   double* pny  = mxGetPr(mxGetField(prhs[1], 0, "numy"));
   double* lpx  = mxGetPr(mxGetField(prhs[1], 0, "lpx"));
   double* lpy  = mxGetPr(mxGetField(prhs[1], 0, "lpy"));
   double* ncoord= mxGetPr(mxGetField(prhs[1], 0, "node"));

   double h[2]   = {*phx, *phy}; 
   double lp[2]  = {*lpx, *lpy}; 

   int    numx  = (int) *pnx;
   int    numy  = (int) *pny;
   int    nodeCount = (numx+1)*(numy+1);

   /* outputs: nodal mass, nodal momenta, nodal forces*/

   plhs[0] = mxCreateDoubleMatrix(nodeCount,1,mxREAL);
   plhs[1] = mxCreateDoubleMatrix(nodeCount,2,mxREAL);
   plhs[2] = mxCreateDoubleMatrix(nodeCount,2,mxREAL);

   double *nmass     = mxGetPr(plhs[0]);
   double *nmomenta  = mxGetPr(plhs[1]);
   double *nforce    = mxGetPr(plhs[2]);

   /* local variables*/

   double xp,yp;
   double f, dfx, dfy; 
   double vpx, vpy, Mp, Vp, sigxx, sigyy, sigxy, g;
   int    nodes[16];
   int    nodeid;
   double x[2];

   int ip, in;

   for(ib = 0; ib < bodyCount; ib++){                     /* loop over bodies*/
      body   = mxGetCell ( bodies, ib  );

      coordp  = mxGetField(body, 0, "coord");             /* get particle info. of this body*/
      coord   = mxGetPr(coordp);
      vol     = mxGetPr(mxGetField(body, 0, "volume"));
      gra     = mxGetPr(mxGetField(body, 0, "gravity"));
      velo    = mxGetPr(mxGetField(body, 0, "velo"));
      mass    = mxGetPr(mxGetField(body, 0, "mass"));
      stress  = mxGetPr(mxGetField(body, 0, "stress"));

      masst  = mxGetField(body, 0, "mass");

     
        particleCount = mxGetM(masst);
    

      for(ip = 0; ip < particleCount; ip++){          /* loop over particles of this body*/
         xp    = coord[ip];
         yp    = coord[ip+particleCount];
         Mp    = mass[ip];
         Vp    = vol[ip];
         vpx   = velo[ip];
         vpy   = velo[ip+particleCount];
         sigxx = stress[ip];
         sigyy = stress[ip+particleCount];
         sigxy = stress[ip+2*particleCount];
         getNodesForParticleGIMP2D ( xp, yp, h[0], h[1], numx, numy, nodes );
         /*
         mexPrintf("%f %f \n,", xp, yp);
         mexPrintf("%d %d %d %d\n,", nodes[0],nodes[1],nodes[2],nodes[3]);	
         mexPrintf("%d %d %d %d\n,", nodes[4],nodes[5],nodes[6],nodes[7]);	
         mexPrintf("%d %d %d %d\n,", nodes[8],nodes[9],nodes[10],nodes[11]);	
         mexPrintf("%d %d %d %d\n,", nodes[12],nodes[13],nodes[14],nodes[15]);	
         */
         for(in = 0; in < 16; in++){                   
            nodeid = nodes[in];
            x[0]   = xp - ncoord[nodeid];
            x[1]   = yp - ncoord[nodeid+nodeCount];
            /*mexPrintf("%f%f\n,", ncoord[nodeid],ncoord[nodeid+nodeCount]);	*/
            computeGIMPBasis2D (x,h,lp,&f,&dfx,&dfy);
            nmass[nodeid]               += f*Mp;
            nmomenta[nodeid]            += f*Mp*vpx;
            nmomenta[nodeid+nodeCount]  += f*Mp*vpy;
            nforce[nodeid]              += - Vp*(sigxx*dfx + sigxy*dfy);
            nforce[nodeid+nodeCount]    += - Vp*(sigxy*dfx + sigyy*dfy) - Mp*f*gra[0];  
         }
      }
   }
}


 
 
 
 

