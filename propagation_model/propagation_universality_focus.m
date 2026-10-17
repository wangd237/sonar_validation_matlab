function [score,status] = propagation_universality_focus(metrics,focus)
%PROPAGATION_UNIVERSALITY_FOCUS Reuse EXACTLY the V2 aggregation policy.
% A zero switch removes a metric from this scope, not from accuracy V2.
assert(istable(metrics) && height(metrics)==10 && numel(focus)==10 && ...
    all(ismember(focus(:),[0 1])) && any(focus), ...
    'propagation:UniversalityFocus','Expected ten binary focus switches.');
subset=metrics;
subset.Weight(~logical(focus(:)))=0;
[score,status]=propagation_accuracy_aggregate_scores(subset);
end
