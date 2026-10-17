function match = propagation_match_arrivals_ordered(ref,sim,cfg)
%PROPAGATION_MATCH_ARRIVALS_ORDERED Simple label-assisted delay matching.
% Weak arrivals are removed using one common relative-amplitude threshold.
% When both inputs provide bounce counts, only paths with the same
% (top,bottom) label can match. Otherwise matching falls back to delay only.

check_arrivals(ref); check_arrivals(sim);
peak=max([abs(ref.amplitude(:));abs(sim.amplitude(:));0]);
floor_amp=peak*10^(cfg.arrival_relative_floor_db/20);
ri=find(abs(ref.amplitude(:))>=floor_amp & abs(ref.amplitude(:))>0);
si=find(abs(sim.amplitude(:))>=floor_amp & abs(sim.amplitude(:))>0);
[~,order]=sort(ref.delay_s(ri)); ri=ri(order);
[~,order]=sort(sim.delay_s(si)); si=si(order);

labels_used=has_bounce_labels(ref) && has_bounce_labels(sim);
available=true(numel(si),1);
pairs=zeros(0,2);
for i=1:numel(ri)
    candidate=find(available);
    if labels_used
        same=ref.top_bounces(ri(i))==sim.top_bounces(si(candidate)) & ...
            ref.bottom_bounces(ri(i))==sim.bottom_bounces(si(candidate));
        candidate=candidate(same);
    end
    if isempty(candidate), continue; end
    difference=abs(sim.delay_s(si(candidate))-ref.delay_s(ri(i)));
    candidate=candidate(difference<=cfg.match_delay_s);
    difference=difference(difference<=cfg.match_delay_s);
    if ~isempty(candidate)
        [~,nearest]=min(difference);
        j=candidate(nearest);
        pairs(end+1,:)=[ri(i),si(j)]; %#ok<AGROW>
        available(j)=false;
    end
end

match.pairs=pairs;
match.reference_indices=ri;
match.simulation_indices=si;
match.reference_count=numel(ri);
match.simulation_count=numel(si);
match.matched_count=size(pairs,1);
match.delay_error_s=sim.delay_s(pairs(:,2))-ref.delay_s(pairs(:,1));
den=numel(ri)+numel(si);
if den>0, match.structure_error=(den-2*size(pairs,1))/den;
else, match.structure_error=NaN; end
match.amplitude_cutoff=floor_amp;
match.path_labels_used=labels_used;
end

function tf=has_bounce_labels(a)
tf=isfield(a,'top_bounces') && isfield(a,'bottom_bounces') && ...
    numel(a.top_bounces)==numel(a.delay_s) && ...
    numel(a.bottom_bounces)==numel(a.delay_s) && ...
    all(isfinite(a.top_bounces(:))) && all(isfinite(a.bottom_bounces(:)));
end

function check_arrivals(a)
fields={'delay_s','amplitude'};
for k=1:numel(fields)
    assert(isfield(a,fields{k}) && numel(a.(fields{k}))==numel(a.delay_s) ...
        && all(isfinite(a.(fields{k})(:))), ...
        'propagation:Arrivals','Invalid arrival field: %s',fields{k});
    assert(isempty(a.(fields{k})) || size(a.(fields{k}),2)==1, ...
        'propagation:Arrivals','Arrival vectors must be columns.');
end
end
