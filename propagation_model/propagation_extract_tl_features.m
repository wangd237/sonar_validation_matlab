function features = propagation_extract_tl_features(range_m, tl_db, cfg)
%PROPAGATION_EXTRACT_TL_FEATURES Detect 1-D TL minima/maxima.
% Positive TL: convergence is a minimum, shadow is a maximum.
% Width is the nearest crossing 3 dB below the peak of +/-TL, NOT half-prominence.
% No downsampling or minimum-zone-width filter is applied.
r = double(range_m(:)); tl = double(tl_db(:));
assert(numel(r)==numel(tl) && numel(r)>=3 && ...
    all(isfinite(r)) && all(isfinite(tl)) && all(diff(r)>0), ...
    'propagation:TLFeatures','Need >=3 finite, strictly increasing range/TL samples.');
step = median(diff(r));
span = max(1, round(cfg.smooth_window_m / step));
if mod(span,2)==0, span=span+1; end
span = min(span, numel(r));
if mod(span,2)==0, span=max(1,span-1); end
% A distance-scaled window makes behaviour comparable across sampling densities.
% smooth is preferred (as agreed); movmean is a toolbox-independent fallback.
if exist('smooth','file')==2
    sm = double(smooth(tl,span,'moving'));
else
    sm = movmean(tl,span,'Endpoints','shrink');
end
sm = sm(:);
features.range_m=r;
features.tl_db=tl;
features.smoothed_tl_db=sm;
features.smooth_points=span;
features.convergence=detect_peaks(r,-sm,cfg);
features.shadow=detect_peaks(r,sm,cfg);
end

function zones = detect_peaks(r,signal,cfg)
empty = struct('center_m',{},'left_m',{},'right_m',{}, ...
    'width_m',{},'prominence_db',{},'truncated',{});
zones = empty;
if max(signal)-min(signal)<cfg.min_peak_prominence_db, return; end
[peaks,indices,~,prominences] = findpeaks(signal, ...
    'MinPeakProminence',cfg.min_peak_prominence_db);
for k=1:numel(indices)
    j=indices(k); target=peaks(k)-cfg.width_drop_db;
    % The first crossing on either side is the peak's fixed 3 dB extent.
    left_index=find(signal(1:j-1)<=target,1,'last');
    right_offset=find(signal(j+1:end)<=target,1,'first');
    clipped=isempty(left_index)||isempty(right_offset);
    left=NaN; right=NaN; width=NaN;
    if ~isempty(left_index)
        left=interpolate_crossing(r(left_index),r(left_index+1), ...
            signal(left_index),signal(left_index+1),target);
    end
    if ~isempty(right_offset)
        right_index=j+right_offset;
        right=interpolate_crossing(r(right_index-1),r(right_index), ...
            signal(right_index-1),signal(right_index),target);
    end
    if ~clipped, width=right-left; end
    zones(end+1)=struct('center_m',r(j),'left_m',left, ... %#ok<AGROW>
        'right_m',right,'width_m',width, ...
        'prominence_db',prominences(k),'truncated',clipped);
end
end

function x=interpolate_crossing(x0,x1,y0,y1,target)
if y1==y0, x=(x0+x1)/2;
else, x=x0+(target-y0)*(x1-x0)/(y1-y0); end
end
