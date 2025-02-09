/*
 * Declaration of functions used to evaluate MPM basis functions and first derivatives.
 * Implemented basis include: MPM, GIMP
 * Definition given in file basis.c
 *
 * VP Nguyen, nvinhphu@gmail.com
 * 24 June 2014, Saigon, Vietnam.
 */

void computeMPMBasis1D (double x, double h, double * f, double * df);
void computeMPMBasis2D (double* x, double* h, double * f, double * dfx, double * dfy);

void computeGIMPBasis1D (double x, double h, double lp, double * f, double * df);
void computeGIMPBasis2D (double* x, double* h, double* lp, double * f, double * dfx, double * dfy);

