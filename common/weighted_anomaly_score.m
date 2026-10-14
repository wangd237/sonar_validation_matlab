function score = weighted_anomaly_score(T)
%WEIGHTED_ANOMALY_SCORE Weighted score from a metric table.
% Table must contain Value, PassThreshold, FailThreshold, Direction, Weight.
sev = zeros(height(T),1);
for i=1:height(T)
    sev(i) = normalized_metric_severity(T.Value(i), T.PassThreshold(i), ...
        T.FailThreshold(i), char(T.Direction(i)));
end
w = T.Weight(:);
score = sum(w.*sev)/(sum(w)+eps);
end
