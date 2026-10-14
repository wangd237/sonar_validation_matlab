function [overall,score,key_pass,key_normalized] = propagation_evaluate_metrics(T)
%PROPAGATION_EVALUATE_METRICS Disabled metrics excluded, missing metrics explicit.
active=T.Enabled; key=active & T.Level=="K";
if any(~isfinite(T.Value(key))) || ~any(key)
    overall="不可判定";
elseif any(T.Status(key)=="不通过")
    overall="不通过";
elseif any(~isfinite(T.Value(active))) || any(T.Status(key)=="关注") ...
        || any(T.Status(active)=="不通过")
    overall="关注";
else
    overall="通过";
end
score=NaN;
if all(isfinite(T.Value(active))) && any(active)
    score=weighted_anomaly_score(T(active,:));
end
key_pass=any(key) && all(T.Status(key)=="通过");
key_normalized=NaN;
if any(key) && all(isfinite(T.Value(key)))
    key_normalized=max(T.Value(key)./T.PassThreshold(key)); % all current K are lower-is-better
end
end
