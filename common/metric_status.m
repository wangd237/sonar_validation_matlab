function status = metric_status(value, pass_thr, fail_thr, direction)
%METRIC_STATUS Return Chinese three-level status string.
if strcmpi(direction,'lower')
    if value <= pass_thr
        status = "通过";
    elseif value <= fail_thr
        status = "关注";
    else
        status = "不通过";
    end
else
    if value >= pass_thr
        status = "通过";
    elseif value >= fail_thr
        status = "关注";
    else
        status = "不通过";
    end
end
end
