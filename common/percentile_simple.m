function q = percentile_simple(x, p)
%PERCENTILE_SIMPLE Toolbox-free percentile using linear interpolation.
x = sort(x(isfinite(x)));
if isempty(x), q = NaN; return; end
if numel(x)==1, q=x; return; end
p = max(0,min(100,p));
pos = 1 + (numel(x)-1)*p/100;
i = floor(pos); j = ceil(pos);
if i==j
    q=x(i);
else
    q=x(i)+(pos-i)*(x(j)-x(i));
end
end
