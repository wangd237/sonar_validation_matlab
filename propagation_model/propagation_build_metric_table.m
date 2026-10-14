function [T,aux] = propagation_build_metric_table(scene,ref,sim)
%PROPAGATION_BUILD_METRIC_TABLE Five active metrics, reserved E_H row.
cfg=scene.validation;
if ~cfg.allow_traceability_input_mismatch
    assert(abs(ref.freq_hz-sim.freq_hz)<1e-6, ...
        'propagation:ComparisonGrid','Compare ref/sim at the same frequency.');
    same_grid(ref.range_m,sim.range_m); same_grid(ref.receiver_depth_m,sim.receiver_depth_m);
else
    assert(numel(ref.range_m)==numel(sim.range_m) ...
        && numel(ref.receiver_depth_m)==numel(sim.receiver_depth_m), ...
        'propagation:ComparisonGrid', ...
        'Traceability perturbations must preserve receiver-grid dimensions.');
end
expected=[numel(ref.receiver_depth_m),numel(ref.range_m)];
assert(isequal(size(ref.pressure),expected) && isequal(size(sim.pressure),expected) ...
    && isequal(size(ref.valid_mask),expected) && isequal(size(sim.valid_mask),expected) ...
    && isequal(size(ref.arrivals),expected) && isequal(size(sim.arrivals),expected), ...
    'propagation:ComparisonGrid','Output arrays must all have [depth,range] dimensions.');
assert(isfinite(cfg.pressure_floor) && cfg.pressure_floor>0 ...
    && isfinite(cfg.match_delay_s) && cfg.match_delay_s>=0 ...
    && isfinite(cfg.arrival_relative_floor_db) && cfg.arrival_relative_floor_db<=0, ...
    'propagation:ValidationConfig','Invalid metric configuration.');
mask=logical(ref.valid_mask) & logical(sim.valid_mask);
assert(all(isfinite(ref.pressure(mask))) && all(isfinite(sim.pressure(mask))), ...
    'propagation:Field','Non-finite values inside the common water-domain mask.');
nr=0; ns=0; nm=0; delay_errors=[];
mp=nan(expected); delay_map=nan(expected); matches=cell(expected);
for idx=find(mask(:)).'
    M=propagation_match_arrivals(ref.arrivals{idx},sim.arrivals{idx},cfg);
    nr=nr+M.reference_count; ns=ns+M.simulation_count; nm=nm+M.matched_count;
    delay_errors=[delay_errors;M.delay_error_s]; %#ok<AGROW>
    mp(idx)=M.structure_error;
    if ~isempty(M.delay_error_s), delay_map(idx)=sqrt(mean(M.delay_error_s.^2)); end
    matches{idx}=M;
end
emp=NaN; tau=NaN; tl_error=NaN; esp=NaN; rho=NaN;
if nr+ns>0, emp=(nr+ns-2*nm)/(nr+ns); end
if ~isempty(delay_errors), tau=sqrt(mean(delay_errors.^2)); end
ref_tl=-20*log10(max(abs(ref.pressure),cfg.pressure_floor));
sim_tl=-20*log10(max(abs(sim.pressure),cfg.pressure_floor));
if any(mask(:))
    tl_error=sqrt(mean((sim_tl(mask)-ref_tl(mask)).^2));
    r=ref.pressure(mask); s=sim.pressure(mask);
    if norm(r)>0, esp=norm(s-r)/norm(r); end
    if norm(r)>0 && norm(s)>0
        rho=min(1,abs(r'*s)/(norm(r)*norm(s)));
    end
end
eh=NaN;
if cfg.enable_frequency_response
    eh=propagation_frequency_response_error(ref,sim,cfg);
end
Domain=["多途";"时延";"传播损失";"频率响应";"空间声场";"空间声场"];
Metric=["E_MP";"RMSE_tau";"RMSE_TL";"E_H";"E_SP";"rho_SP"];
Unit=["1";"s";"dB";"1";"1";"1"];
Level=["K";"A";"K";"A";"K";"A"];
Value=[emp;tau;tl_error;eh;esp;rho];
Enabled=[true;true;true;cfg.enable_frequency_response;true;true];
PassThreshold=cfg.pass_threshold(:); FailThreshold=cfg.fail_threshold(:);
Direction=["lower";"lower";"lower";"lower";"lower";"higher"];
Weight=cfg.weight(:);
assert(numel(PassThreshold)==6 && numel(FailThreshold)==6 && numel(Weight)==6 ...
    && all(isfinite(PassThreshold(Enabled))) && all(isfinite(FailThreshold(Enabled))) ...
    && all(isfinite(Weight) & Weight>=0) && sum(Weight(Enabled))>0, ...
    'propagation:ValidationConfig','Invalid thresholds or weights.');
Weight(~Enabled)=0;
Status=strings(6,1);
for k=1:6
    if ~Enabled(k), Status(k)="未启用";
    elseif ~isfinite(Value(k)), Status(k)="不可计算";
    else, Status(k)=metric_status(Value(k),PassThreshold(k),FailThreshold(k),char(Direction(k))); end
end
Why=["有效到达按反射次数分组，在时延门限内一对一匹配；未匹配数/两侧到达总数。"; ...
    "所有匹配到达的时延误差RMSE；无匹配时不记零。"; ...
    "共同有效网格上TL差的RMSE；采用统一幅度下限。"; ...
    "预留接口，当前不参与运行、评分和判定。"; ...
    "共同有效网格上复声场差的二范数/参考复声场二范数。"; ...
    "复声场内积模/两侧范数乘积，不去均值。"];
T=table(Domain,Metric,Unit,Level,Enabled,Value,PassThreshold,FailThreshold,Direction,Weight,Status,Why);
aux.valid_mask=mask; aux.ref_tl_db=ref_tl; aux.sim_tl_db=sim_tl;
aux.tl_difference_db=sim_tl-ref_tl;
aux.structure_error_map=mp; aux.delay_rmse_map_s=delay_map;
aux.matches=matches;
aux.reference_arrivals=nr; aux.simulation_arrivals=ns; aux.matched_arrivals=nm;
aux.common_grid_points=nnz(mask);
aux.threshold_note='Demonstration thresholds; synthetic configuration comparison only.';
end

function same_grid(a,b)
assert(numel(a)==numel(b) && all(isfinite(a(:))) && all(isfinite(b(:))) ...
    && all(abs(a(:)-b(:))<1e-6),'propagation:ComparisonGrid', ...
    'Receiver grids must agree; implicit interpolation is not supported.');
end
