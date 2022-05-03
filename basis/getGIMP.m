function [phi,dphi]=getGIMP(x,h,lp)

% compute the GIMP shape function at point x
% h:  element size
% lp: particle size

lp2 = lp/2;

if      ( abs(x) < lp2 )
    phi  = 1.0 - (4*x^2+lp^2)/(4*h*lp);
    dphi = -8*x/(4*h*lp);
elseif  ( abs(x) < h - lp2)
    phi  = 1-abs(x)/h;
    dphi = -1/h*sign(x);
elseif  ( abs(x) < h + lp2)
    phi  = (h+lp2-abs(x))^2/(2*h*lp);
    dphi = -(h+lp2-abs(x))/(h*lp)*sign(x);
else
    phi = 0;
    dphi = 0;
end