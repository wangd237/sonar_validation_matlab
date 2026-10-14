function [arrivals, pos, freq] = propagation_read_arrivals(filename)
%PROPAGATION_READ_ARRIVALS Legacy 2-D ASCII .arr (local 2010 Bellhop executable).
% No fixed arrival cap: unlike read_arrivals_asc, never silently drops paths.
fid = fopen(filename,'r');
assert(fid>=0,'propagation:ArrivalsOpen','Cannot open %s',filename);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
freq = fscanf(fid,'%f',1);
assert(isscalar(freq) && isfinite(freq) && freq>0, ...
    'propagation:ArrivalsFormat','Expected legacy numeric 2-D .arr header: %s',filename);
counts = take(fid,3);
assert(all(counts>=1 & counts==fix(counts)),'propagation:ArrivalsFormat','Invalid grid counts.');
ns=counts(1); nz=counts(2); nr=counts(3);
pos.source_depth_m = take(fid,ns);
pos.receiver_depth_m = take(fid,nz);
pos.range_m = take(fid,nr); % local executable writes arrivals ranges in metres
arrivals = cell(nz,nr,ns);
for is=1:ns
    max_count = take(fid,1);
    assert(max_count>=0 && max_count==fix(max_count), ...
        'propagation:ArrivalsFormat','Invalid maximum arrival count.');
    for iz=1:nz
        for ir=1:nr
            n=take(fid,1);
            assert(n>=0 && n==fix(n) && n<=max_count, ...
                'propagation:ArrivalsFormat','Invalid arrival count.');
            data=reshape(take(fid,7*n),7,n);
            a.delay_s=data(3,:).';
            a.amplitude=data(1,:).' .* exp(1i*pi/180*data(2,:).');
            a.source_angle_deg=data(4,:).';
            a.receiver_angle_deg=data(5,:).';
            a.top_bounces=data(6,:).';
            a.bottom_bounces=data(7,:).';
            arrivals{iz,ir,is}=a;
        end
    end
end
assert(isempty(strtrim(fread(fid,Inf,'*char').')), ...
    'propagation:ArrivalsFormat','Unexpected trailing data; unsupported .arr version.');
end

function x=take(fid,n)
x=fscanf(fid,'%f',n);
assert(numel(x)==n && all(isfinite(x)),'propagation:ArrivalsFormat', ...
    'Truncated or unsupported arrivals file.');
end
