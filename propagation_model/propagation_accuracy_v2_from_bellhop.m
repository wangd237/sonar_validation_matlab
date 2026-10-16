function output=propagation_accuracy_v2_from_bellhop(ref,sim,cfg)
%PROPAGATION_ACCURACY_V2_FROM_BELLHOP Single receiver-depth demo adapter.
% Real standard-data adapter must provide its own calibration metadata.
if nargin<3, cfg=propagation_accuracy_v2_config(); end
assert(isequal(ref.range_m(:),sim.range_m(:)) && ...
       isequal(ref.receiver_depth_m(:),sim.receiver_depth_m(:)), ...
       'propagation:AccuracyGrid','V2 demo requires the same receivers.');
z=ref.receiver_depth_m(:);
% Use the receiver-array geometric-center depth (nearest receiver row).
target=(min(z)+max(z))/2;
[~,iz]=min(abs(z-target));
valid=logical(ref.valid_mask(iz,:)) & logical(sim.valid_mask(iz,:));
r=ref.range_m(:); valid=valid(:);
% Identify contiguous usable samples; no interpolation across dry gaps.
runs=contiguous_runs(valid);
a=struct(); b=struct();
if ~isempty(runs)
    [~,which]=max(cellfun(@numel,runs));
    ix=runs{which};
    if numel(ix)>=3
        a.range_m=r(ix); b.range_m=r(ix);
        a.tl_db=ref.tl_db(iz,ix).';
        b.tl_db=sim.tl_db(iz,ix).';
    end
end
% For Bellhop-generated mock arrivals, the simulation impulse-response
% origin is the emission instant and contains no hardware system delay.
% Explicit zeros below are mock-only calibration, not real measurement defaults.
idx=find(valid,1,'last');
if ~isempty(idx)
    ar=ref.arrivals{iz,idx}; as=sim.arrivals{iz,idx};
    ar.tx_time_s=0; ar.system_delay_s=0;
    as.tx_time_s=0; as.system_delay_s=0;
    a.arrivals=ar; b.arrivals=as;
end
output=propagation_accuracy_v2(a,b,cfg);
output.receiver_depth_m=z(iz);
output.receiver_range_m=NaN;
if ~isempty(idx), output.receiver_range_m=r(idx); end
output.source_type="Bellhop mock; no measured reference data";
end

function runs=contiguous_runs(valid)
ix=find(valid);
runs={};
if isempty(ix), return; end
breaks=[0;find(diff(ix)>1);numel(ix)];
for k=1:numel(breaks)-1
    runs{end+1}=ix(breaks(k)+1:breaks(k+1)); %#ok<AGROW>
end
end
