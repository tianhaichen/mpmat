#include<math.h>

void getNodesForParticle2D(double x, double y, double dx, double dy, int numx, int numy, int* nodes )
/*
 * get nodes to which particle at (x,y) will contribute.
 * For linear basis functions i.e. MPM 
 * Nodes are numbered from 0 to be compatible with zero-based indexing of C arrays.
 */
{
  int xi = floor ( x/dx ) ;
  int yi = floor ( y/dy ) ;

  int n1 = xi + (numx+1)*yi;
  int n4 = xi + (numx+1)*(yi+1);

  int n2 = n1 + 1;
  int n3 = n4 + 1;

  nodes[0] = n1;
  nodes[1] = n2;
  nodes[2] = n3;
  nodes[3] = n4;
}

void getNodesForParticle3D(double x, double y, double z, 
                         double dx, double dy, double dz,
                         int numx, int numy, int numz, int* nodes )
{
}

void getNodesForParticleGIMP2D(double x, double y, double dx, double dy, int numx, int numy, int* nodes )
/*
 * For GIMP i.e. quadratic basis functions.
 * Nodes are numbered from 0 to be compatible with zero-based indexing of C arrays.
 */
{
  int xi = floor ( x/dx ) ;
  int yi = floor ( y/dy ) ;

  int n1 = xi + (numx+1)*(yi-1);
  int n2 = xi + (numx+1)*yi;
  int n3 = xi + (numx+1)*(yi+1);
  int n4 = xi + (numx+1)*(yi+2);

  nodes[0] = n1 - 1;
  nodes[1] = n1;
  nodes[2] = n1 + 1;
  nodes[3] = n1 + 2;
  nodes[4] = n2 - 1;
  nodes[5] = n2 ;
  nodes[6] = n2 + 1;
  nodes[7] = n2 + 2;
  nodes[8] = n3 - 1;
  nodes[9] = n3 ;
  nodes[10] = n3 + 1;
  nodes[11] = n3 + 2;
  nodes[12] = n4 - 1;
  nodes[13] = n4 ;
  nodes[14] = n4 + 1;
  nodes[15] = n4 + 2;
}
