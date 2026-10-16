function pairs = propagation_match_zones(reference, simulation)
%PROPAGATION_MATCH_ZONES Order-preserving one-to-one matching of peak centers.
% Reference-specific physical gate: max(reference width, 10% of range).
% Maximize matched count first; minimize total center displacement second.
n=numel(reference); m=numel(simulation);
pairs=zeros(0,2);
if n==0 || m==0, return; end
[~,ro]=sort([reference.center_m]);
[~,so]=sort([simulation.center_m]);
ref=reference(ro); sim=simulation(so);
count=zeros(n+1,m+1); cost=zeros(n+1,m+1);
action=zeros(n+1,m+1,'uint8');
action(2:end,1)=1; action(1,2:end)=2;
for i=1:n
    width=ref(i).width_m;
    if ~isfinite(width), width=0; end % truncated 3-dB boundary
    tol=max(width,0.1*abs(ref(i).center_m));
    for j=1:m
        candidates=[count(i,j+1),count(i+1,j),-Inf];
        costs=[cost(i,j+1),cost(i+1,j),Inf];
        delta=abs(ref(i).center_m-sim(j).center_m);
        if delta<=tol
            candidates(3)=count(i,j)+1;
            costs(3)=cost(i,j)+delta;
        end
        choices=find(candidates==max(candidates));
        [~,ix]=min(costs(choices)); chosen=choices(ix);
        count(i+1,j+1)=candidates(chosen);
        cost(i+1,j+1)=costs(chosen);
        action(i+1,j+1)=chosen;
    end
end
pairs=zeros(count(end,end),2);
k=size(pairs,1); i=n; j=m;
while i>0 || j>0
    switch action(i+1,j+1)
        case 1, i=i-1;
        case 2, j=j-1;
        case 3
            pairs(k,:)=[ro(i),so(j)];
            k=k-1; i=i-1; j=j-1;
    end
end
end
