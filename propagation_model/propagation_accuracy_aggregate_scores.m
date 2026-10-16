function [total,status] = propagation_accuracy_aggregate_scores(metrics)
%PROPAGATION_ACCURACY_AGGREGATE_SCORES Weighted final score.
% Knows only per-metric Score, Status and Weight. Does not inspect features.
required={'Score','Status','Weight'};
assert(istable(metrics) && all(ismember(required,metrics.Properties.VariableNames)), ...
    'propagation:AccuracyAggregation','Expected Score, Status and Weight columns.');
w=metrics.Weight(:); values=metrics.Score(:);
assert(numel(values)==10 && numel(w)==10 && all(isfinite(w)) ...
    && all(w>=0),'propagation:AccuracyWeights','Exactly ten nonnegative finite weights are required.');
total=NaN; status="未验证";
active=w>0;
if ~any(active) || any(~isfinite(values(active))) || ...
        any(metrics.Status(active)=="未验证")
    % Missing-data aggregation policy is deliberately unresolved.
    return;
end
assert(all(values(active)>=0 & values(active)<=100), ...
    'propagation:AccuracyAggregation','Metric scores must be between 0 and 100.');
total=sum(values(active).*w(active))/sum(w(active));
if total>=80
    status="准确";
elseif total>=60
    status="关注";
else
    status="不准确";
end
end
