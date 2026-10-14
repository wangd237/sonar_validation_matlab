function match = propagation_match_arrivals(ref, sim, cfg)
%PROPAGATION_MATCH_ARRIVALS One-to-one delay matching within reflection families.
% Maximise match count, then minimise summed absolute delay error. Dynamic
% programming on sorted times is optimal for each 1-D reflection family.
check_arrivals(ref); check_arrivals(sim);
peak=max([abs(ref.amplitude(:)); abs(sim.amplitude(:)); 0]);
floor_amp=peak*10^(cfg.arrival_relative_floor_db/20);
ri=find(abs(ref.amplitude(:))>=floor_amp & abs(ref.amplitude(:))>0);
si=find(abs(sim.amplitude(:))>=floor_amp & abs(sim.amplitude(:))>0);
if cfg.match_bounce_counts
    rg=[ref.top_bounces(ri),ref.bottom_bounces(ri)];
    sg=[sim.top_bounces(si),sim.bottom_bounces(si)];
else
    rg=zeros(numel(ri),2); sg=zeros(numel(si),2);
end
groups=unique([rg;sg],'rows'); pairs=zeros(0,2);
for k=1:size(groups,1)
    r=ri(all(rg==groups(k,:),2)); s=si(all(sg==groups(k,:),2));
    [~,order]=sort(ref.delay_s(r)); r=r(order);
    [~,order]=sort(sim.delay_s(s)); s=s(order);
    local=optimal_pairs(ref.delay_s(r),sim.delay_s(s),cfg.match_delay_s);
    pairs=[pairs; r(local(:,1)),s(local(:,2))]; %#ok<AGROW>
end
match.pairs=pairs;
match.reference_indices=ri; match.simulation_indices=si;
match.reference_count=numel(ri); match.simulation_count=numel(si);
match.matched_count=size(pairs,1);
match.delay_error_s=sim.delay_s(pairs(:,2))-ref.delay_s(pairs(:,1));
den=numel(ri)+numel(si);
if den>0, match.structure_error=(den-2*size(pairs,1))/den;
else, match.structure_error=NaN; end
match.amplitude_cutoff=floor_amp;
end

function pairs=optimal_pairs(r,s,gate)
n=numel(r); m=numel(s);
count=zeros(n+1,m+1); cost=zeros(n+1,m+1); action=zeros(n+1,m+1,'uint8');
action(2:end,1)=1; action(1,2:end)=2;
for i=1:n
    for j=1:m
        nc=[count(i,j+1),count(i+1,j),-Inf];
        ec=[cost(i,j+1),cost(i+1,j),Inf];
        d=abs(r(i)-s(j));
        if d<=gate, nc(3)=count(i,j)+1; ec(3)=cost(i,j)+d; end
        options=find(nc==max(nc)); [~,v]=min(ec(options)); choice=options(v);
        count(i+1,j+1)=nc(choice); cost(i+1,j+1)=ec(choice);
        action(i+1,j+1)=choice;
    end
end
pairs=zeros(count(end,end),2); k=size(pairs,1); i=n; j=m;
while i>0 || j>0
    switch action(i+1,j+1)
        case 1, i=i-1;
        case 2, j=j-1;
        case 3, pairs(k,:)=[i,j]; k=k-1; i=i-1; j=j-1;
    end
end
end

function check_arrivals(a)
fields={'delay_s','amplitude','top_bounces','bottom_bounces'};
for k=1:numel(fields)
    assert(isfield(a,fields{k}) && numel(a.(fields{k}))==numel(a.delay_s) ...
        && all(isfinite(a.(fields{k})(:))), ...
        'propagation:Arrivals','Invalid arrival field: %s',fields{k});
    assert(isempty(a.(fields{k})) || size(a.(fields{k}),2)==1, ...
        'propagation:Arrivals','Arrival vectors must be columns.');
end
end
