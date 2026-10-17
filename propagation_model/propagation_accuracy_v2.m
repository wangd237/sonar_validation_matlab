function out = propagation_accuracy_v2(reference, simulation, cfg)
%PROPAGATION_ACCURACY_V2 Standalone feature-level accuracy evaluator.
% Input: reference/simulation with range_m, tl_db (1-D), arrivals (struct).
% Final aggregator depends only on the ten scores and their weights.
if nargin<3, cfg=propagation_accuracy_v2_config(); end
names=["TL_curve";"Convergence_count";"Convergence_center";"Convergence_width"; ...
    "Shadow_count";"Shadow_position";"Shadow_width"; ...
    "Arrival_delay";"Adjacent_delay";"Last_arrival"];
score=nan(10,1); status=repmat("未验证",10,1); detail=cell(10,1);
% Preserve EXACT detection/matching inputs for post-run diagnosis. Visualization
% must use the same features and pairs as scoring; no secondary peak detection.
zone_diag=struct('available',false,'reference',[],'simulation',[], ...
    'convergence_pairs',zeros(0,2),'shadow_pairs',zeros(0,2));
assert(isequal(size(cfg.weights),[10 1]) && all(isfinite(cfg.weights)) ...
    && all(cfg.weights>=0),'propagation:AccuracyWeights','Invalid weights.');
% Only explicit single-depth TL vectors are used; never fabricate spatial coverage.
has_tl=isfield(reference,'range_m') && isfield(simulation,'range_m') ...
    && isfield(reference,'tl_db') && isfield(simulation,'tl_db');
if has_tl
    [r,ia,ib]=intersect(reference.range_m(:),simulation.range_m(:),'stable');
    a=reference.tl_db(:); b=simulation.tl_db(:);
    if numel(a)==numel(reference.range_m) && numel(b)==numel(simulation.range_m) ...
            && numel(r)>=3 && all(isfinite(a(ia))) && all(isfinite(b(ib)))
        er=b(ib)-a(ia);
        rmse=sqrt(mean(er.^2));
        rho=NaN;
        if std(a(ia))>0 && std(b(ib))>0
            C=corrcoef(a(ia),b(ib)); rho=C(1,2);
        end
        detail{1}=struct('rmse_db',rmse,'pearson',rho,'common_points',numel(r));
        if isfinite(rho)
            q=[lower_score(rmse,cfg.limits.tl_rmse_db), ...
                lower_score(1-rho,cfg.limits.tl_correlation_loss)];
            score(1)=mean(q);
        end
    end
    % Zone extraction requires dense, same-grid measurements; never infer
    % unobserved zone geometry through interpolation.
    if numel(r)>=3 && numel(a)==numel(reference.range_m) ...
            && numel(b)==numel(simulation.range_m) && ...
            all(isfinite(a(ia))) && all(isfinite(b(ib))) && ...
            max(diff(r))<=cfg.maximum_zone_step_m
        fa=propagation_extract_tl_features(r,a(ia),cfg);
        fb=propagation_extract_tl_features(r,b(ib),cfg);
        [score(2:4),detail(2:4)]=zone_group(fa.convergence,fb.convergence,cfg);
        [score(5:7),detail(5:7)]=zone_group(fa.shadow,fb.shadow,cfg);
        zone_diag.available=true;
        zone_diag.reference=fa;
        zone_diag.simulation=fb;
        zone_diag.convergence_pairs=detail{3}.pairs;
        zone_diag.shadow_pairs=detail{6}.pairs;
    end
end
% Multi-path input represents a single, identified receiver; use no invented
% launch-time or fixed-system-delay correction.
if isfield(reference,'arrivals') && isfield(simulation,'arrivals') ...
        && isstruct(reference.arrivals) && isstruct(simulation.arrivals)
    [score(8:10),detail(8:10)]=arrival_group(reference.arrivals,simulation.arrivals,cfg);
end
for i=1:10
    if isfinite(score(i))
        if score(i)>=80, status(i)="准确";
        elseif score(i)>=60, status(i)="关注";
        else, status(i)="不准确"; end
    end
end
out.metrics=table(names,score,status,cfg.weights,'VariableNames', ...
    {'Metric','Score','Status','Weight'});
out.detail=detail;
out.zone_diagnostics=zone_diag;
[out.total_score,out.overall_status]= ...
    propagation_accuracy_aggregate_scores(out.metrics);
end

function [scores,details]=zone_group(a,b,cfg)
scores=nan(3,1); details=cell(3,1);
pairs=propagation_match_zones(a,b);
tp=size(pairs,1); fn=numel(a)-tp; fp=numel(b)-tp;
% Both empty = correct count agreement; no valid positional/width sample.
if numel(a)+numel(b)==0
    f1=1;
else
    f1=2*tp/(numel(a)+numel(b));
end
count_delta=abs(numel(a)-numel(b));
scores(1)=mean([lower_score(count_delta,cfg.limits.zone_count), ...
    lower_score(1-f1,cfg.limits.zone_miss_loss)]);
details{1}=struct('reference_count',numel(a),'simulation_count',numel(b), ...
    'matched',tp,'missed',fn,'extra',fp,'f1',f1);
details{2}=struct('pairs',pairs,'center_mae_m',NaN,'boundary_mae_m',NaN);
details{3}=struct('width_mae_m',NaN);
if tp>0
    ra=[a(pairs(:,1)).center_m]; rb=[b(pairs(:,2)).center_m];
    center=mean(abs(ra-rb));
    scores(2)=lower_score(center,cfg.limits.zone_position_m);
    details{2}.center_mae_m=center;
    la=[a(pairs(:,1)).left_m]; lb=[b(pairs(:,2)).left_m];
    ua=[a(pairs(:,1)).right_m]; ub=[b(pairs(:,2)).right_m];
    valid=isfinite(la)&isfinite(lb)&isfinite(ua)&isfinite(ub);
    if any(valid)
        details{2}.boundary_mae_m=mean((abs(la(valid)-lb(valid))+abs(ua(valid)-ub(valid)))/2);
    end
    wa=[a(pairs(:,1)).width_m]; wb=[b(pairs(:,2)).width_m];
    good=isfinite(wa)&isfinite(wb);
    if any(good)
        err=mean(abs(wa(good)-wb(good)));
        scores(3)=lower_score(err,cfg.limits.zone_width_m);
        details{3}.width_mae_m=err;
    end
end
end

function [scores,details]=arrival_group(a,b,cfg)
scores=nan(3,1); details=cell(3,1);
required={'delay_s','amplitude'};
if ~all(isfield(a,required)) || ~all(isfield(b,required)), return; end
if ~isfield(a,'tx_time_s') || ~isfield(b,'tx_time_s') || ...
        ~isfield(a,'system_delay_s') || ~isfield(b,'system_delay_s')
    return; % timing calibration is mandatory, not assumed zero
end
a.delay_s=a.delay_s(:)-a.tx_time_s-a.system_delay_s;
b.delay_s=b.delay_s(:)-b.tx_time_s-b.system_delay_s;
if ~all(isfinite(a.delay_s)) || ~all(isfinite(b.delay_s)), return; end
m=propagation_match_arrivals_ordered(a,b,cfg);
details{1}=struct('matched',m.matched_count, ...
    'reference_count',m.reference_count,'simulation_count',m.simulation_count, ...
    'path_labels_used',m.path_labels_used);
if ~isempty(m.delay_error_s)
    err=sqrt(mean(m.delay_error_s.^2));
    scores(1)=lower_score(err,cfg.limits.arrival_delay_s);
    details{1}.rmse_s=err;
end
pairs=m.pairs;
if size(pairs,1)>=2
    % The ordered matcher returns chronological pairs. Compare consecutive
    % gaps in that matched sequence; no ray-family metadata is required.
    ref_intervals=diff(a.delay_s(pairs(:,1)));
    sim_intervals=diff(b.delay_s(pairs(:,2)));
    interval_error=sim_intervals-ref_intervals;
    delta=sqrt(mean(interval_error.^2));
    scores(2)=lower_score(delta,cfg.limits.adjacent_delay_s);
    details{2}=struct('rmse_s',delta, ...
        'compared_intervals',numel(interval_error));
end
if m.reference_count>0 && m.simulation_count>0
    % Last effective path: independent of matching, after time calibration.
    last=abs(max(a.delay_s(m.reference_indices))-max(b.delay_s(m.simulation_indices)));
    scores(3)=lower_score(last,cfg.limits.last_arrival_s);
    details{3}=struct('absolute_error_s',last);
end
end

function s=lower_score(err,limits)
% Private zero-to-100 mapping; [accurate-threshold, inaccurate-threshold].
lo=limits(1); hi=limits(2);
assert(isfinite(lo)&&isfinite(hi)&&lo>0&&hi>lo);
if err<=lo, s=100-20*err/lo;
elseif err<=hi, s=80-20*(err-lo)/(hi-lo);
else, s=max(0,60-60*(err-hi)/(hi-lo)); end
end
