#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <float.h>
#include "matrix.h"
#include "mex.h"
#include "string.h"
#include "basis.h"
#include "util.h"


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	/*	Update particle positions, velocities and stresses
	//
	// We expect the function to be called as UpdateParticles(bodies,mesh,nvelo,nacce,dtim)
	// bodies: bodies in the simulation.
        // mesh:   background grid
        // nvelo:  nodal velocities at time t+dtime
        // nacce:  nodal accelerations at time t+dtime
        // bodies are modified to update stress, positions, velocities of particles.
        //
        // VP Nguyen
        // Saigon, Vietnam, June 2014.
        */
	
   const mxArray* bodies;
         mxArray  *masst, *body, *coordp, *matProp;
         double   *mass, *vol, *vol0, *coord, *velo, *stress, *strain, *Cma, *defo;
         double   *kappa;
   mwSize          bodyCount, particleCount;
   mwIndex         ib;

   /* get the inputs from Matlab*/
   bodies    = prhs[0];
   bodyCount = mxGetNumberOfElements(prhs[0]);
      
   double* phx  = mxGetPr(mxGetField(prhs[1], 0, "deltax"));
   double* phy  = mxGetPr(mxGetField(prhs[1], 0, "deltay"));
   double* pnx  = mxGetPr(mxGetField(prhs[1], 0, "numx"));
   double* pny  = mxGetPr(mxGetField(prhs[1], 0, "numy"));
   double* ncoord= mxGetPr(mxGetField(prhs[1], 0, "node"));
   
   double* nvelo = mxGetPr(prhs[2]);  /* nodal velocities at time t+dt  */                   
   double* nacce = mxGetPr(prhs[3]);  /* nodal accelerations at t+dt*/
   double* pdt   = mxGetPr(prhs[4]);  /* time increment dt*/

   double h[2]  = {*phx, *phy}; 

   int    numx  = (int) *pnx;
   int    numy  = (int) *pny;
   int    nodeCount = (numx+1)*(numy+1);

   double dtime = *pdt;

   /* local variables*/

   double xp,yp;
   double f, dfx, dfy; 
   double C11, C12, C13, C21, C22, C23, C31, C32, C33;
   double vpx, vpy, a11, a12, a21, a22, Fxx, Fxy, Fyx, Fyy;
   double fxx, fxy, fyx, fyy, detF;
   double vix, viy;
   double newcoordx, newcoordy, newvelox, newveloy;
   int    nodes[4];
   int    nodeid;
   double x[2];
   double L[4]; 
   double dstrain[3];

   /* for calling mexCallMatlab
   // used to call constitutive model implemented in Matlab M files.*/

   mxArray *output_array[3], *input_array[3];
   mxArray *str, *sigmaPtr, *epsPtr;
   double  *strp, *stressOut;
   
   int ip, in;

   for(ib = 0; ib < bodyCount; ib++){                     /* loop over bodies*/
      body   = mxGetCell ( bodies, ib  );
      coordp  = mxGetField(body, 0, "coord");             /* get particle info. of this body*/
      coord   = mxGetPr(coordp);
      vol     = mxGetPr(mxGetField(body, 0, "volume"));
      vol0    = mxGetPr(mxGetField(body, 0, "volume0"));
      velo    = mxGetPr(mxGetField(body, 0, "velo"));
      defo    = mxGetPr(mxGetField(body, 0, "deform"));   /* deformation gradient*/
      stress  = mxGetPr(mxGetField(body, 0, "stress"));   
      strain  = mxGetPr(mxGetField(body, 0, "strain"));   

      Cma     = mxGetPr(mxGetField(body, 0, "C"));        

      particleCount = mxGetM(coordp);
      

      C11 = Cma[0]; C21 = Cma[1]; C31 = Cma[2];
      C12 = Cma[3]; C22 = Cma[4]; C32 = Cma[5];
      C13 = Cma[6]; C23 = Cma[7]; C33 = Cma[8];
    

      for(ip = 0; ip < particleCount; ip++){          /* loop over particles of this body*/
         xp          = coord[ip];
         yp          = coord[ip+particleCount];
         newcoordx   = xp;
         newcoordy   = yp;
         newvelox    = velo[ip];
         newveloy    = velo[ip+particleCount];
         
         getNodesForParticle2D ( xp, yp, h[0], h[1], numx, numy, nodes );
         memset(L,0.,sizeof(L));
         for(in = 0; in < 4; in++){                   /* interpolate to nodes belong to this particle*/
            nodeid = nodes[in];
            x[0]   = xp - ncoord[nodeid];
            x[1]   = yp - ncoord[nodeid+nodeCount];
            computeMPMBasis2D (x,h,&f,&dfx,&dfy);
            /* update particle coordinates and velocities*/
            vix = nvelo[nodeid];
            viy = nvelo[nodeid+nodeCount];
            newcoordx += dtime * f * vix;
            newcoordy += dtime * f * viy;
            newvelox  += dtime * f * nacce[nodeid];
            newveloy  += dtime * f * nacce[nodeid+nodeCount];
            L[0] +=  dfx*vix;   /* L_xx */
            L[1] +=  dfy*vix;   /* L_xy */
            L[2] +=  dfx*viy;   /* L_yx */
            L[3] +=  dfy*viy;   /* L_yy */
         }
         coord[ip]               = newcoordx;
         coord[ip+particleCount] = newcoordy;
         velo[ip]                = newvelox;
         velo[ip+particleCount]  = newveloy;
        
         /*compute gradient deformation */
         a11 = 1.+dtime*L[0]; a12 = dtime*L[1]; a21 = dtime*L[2]; a22 = 1.+dtime*L[3];
         fxx = defo[ip]; fyx = defo[ip+particleCount]; fxy = defo[ip+2*particleCount]; fyy = defo[ip+3*particleCount];
         Fxx = a11*fxx + a12*fyx;
         Fxy = a11*fxy + a12*fyy;
         Fyx = a21*fxx + a22*fyx;
         Fyy = a21*fxy + a22*fyy;
         detF     = Fxx*Fyy - Fxy*Fyx;
         
         vol[ip]  = vol0[ip]*detF;
         /* NOTE: putting vol[ip] = vol0[ip]*detF after the following did not work!!!*/
         defo[ip]                 = Fxx;
         defo[ip+  particleCount] = Fyx;
         defo[ip+2*particleCount] = Fxy;
         defo[ip+3*particleCount] = Fyy;
         /* strain increment */
         dstrain[0] = dtime*L[0];
         dstrain[1] = dtime*L[3];
         dstrain[2] = dtime*(L[1]+L[2]);
         

         /* update strain*/
         strain[ip]                 += dstrain[0];
         strain[ip+particleCount]   += dstrain[1];
         strain[ip+2*particleCount] += dstrain[2];
         
         /* update stress*/
         stress[ip]                 += C11*dstrain[0] + C12*dstrain[1] + C13*dstrain[2];
         stress[ip+particleCount]   += C21*dstrain[0] + C22*dstrain[1] + C23*dstrain[2];
         stress[ip+2*particleCount] += C31*dstrain[0] + C32*dstrain[1] + C33*dstrain[2];

         /* call Matlab function to update stress Hooke
         // it seems quite slow however!!!
         //str = mxCreateDoubleMatrix(3, 1, mxREAL);
         //strp = mxGetPr(str);
         //strp[0]=strain[ip];
         //strp[1]=strain[ip+particleCount];
         //strp[2]=strain[ip+2*particleCount];

         //input_array[0] = str;
         //input_array[1] = matProp;
         //input_array[2] = mxCreateDoubleScalar(kappa[ip]);
         //// call Matlab M file "updateStressIsoDamage.m" to update stress
         //mexCallMATLAB(3, output_array, 3, input_array, "updateStressIsoDamage");
         //// get outputs
         //kappa[ip]                  = *mxGetPr(output_array[1]);
         //stressOut                  = mxGetPr(output_array[0]);
         //stress[ip]                 = stressOut[0];
         //stress[ip+particleCount]   = stressOut[1];
         //stress[ip+2*particleCount] = stressOut[2];

         //// free memory 
         //mxDestroyArray ( str );*/
      }
   }
}


 
 
 
 

