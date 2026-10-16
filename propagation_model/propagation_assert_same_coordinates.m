function propagation_assert_same_coordinates(a,b,label)
%PROPAGATION_ASSERT_SAME_COORDINATES Compare coordinates from Bellhop outputs.
% Legacy Bellhop writes coordinates as single precision.  A fixed 1 mm
% tolerance is therefore too strict for long ranges (for example 200 km).

a=double(a(:)); b=double(b(:));
assert(numel(a)==numel(b),'propagation:Grid', ...
    '%s coordinate counts differ (%d versus %d).',label,numel(a),numel(b));

scale=max([abs(a);abs(b);1]);
tolerance=max(1e-3,1e-6*scale);
difference=abs(a-b);
assert(all(isfinite(difference)) && all(difference<=tolerance), ...
    'propagation:Grid', ...
    '%s coordinates differ (maximum difference %.6g m; tolerance %.6g m).', ...
    label,max(difference),tolerance);
end
