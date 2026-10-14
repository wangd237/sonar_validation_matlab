function s = normalized_metric_severity(value, pass_thr, fail_thr, direction)
%NORMALIZED_METRIC_SEVERITY Normalize indicator severity to [0,1].
%  0 means comfortably passing, 0.5 around pass boundary for lower-type
%  indicators, and 1 means reaching/exceeding fail boundary.
if strcmpi(direction,'lower')
    if fail_thr <= 0
        s = double(value > fail_thr);
    else
        s = min(1, max(0, value / fail_thr));
    end
else
    if pass_thr <= fail_thr
        s = double(value < fail_thr);
    elseif value >= pass_thr
        s = 0;
    elseif value <= fail_thr
        s = 1;
    else
        s = (pass_thr - value)/(pass_thr-fail_thr);
    end
end
end
