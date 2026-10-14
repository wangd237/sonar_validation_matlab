function result = propagation_traceability_analysis(scene,outdir)
%PROPAGATION_TRACEABILITY_ANALYSIS Intervention/correction/local-sensitivity ranking.
% The reference output is generated once and frozen. Each candidate source is
% corrected or locally perturbed only on the model-under-test side.
ensure_dir(outdir);
scene.validation.allow_traceability_input_mismatch=true;
cfg=propagation_traceability_config();
truth=propagation_case_parameters(scene.reference_root);
current=propagation_case_parameters(scene.simulation_root);

ref=generate_propagation_reference(scene);
base=call_propagation_model_under_test(scene);
baseline=propagation_build_metric_table(scene,ref,base);
[baseline_status,A_base]=propagation_evaluate_metrics(baseline);
assert(isfinite(A_base),'propagation:Traceability','Baseline anomaly score is not finite.');

n=height(cfg); ref_value=zeros(n,1); sim_value=zeros(n,1); deviation=zeros(n,1);
corrected_score=zeros(n,1); reduction=zeros(n,1); sensitivity=zeros(n,1);
minus_score=zeros(n,1); plus_score=zeros(n,1); runs=cell(n,1);
case_dir=fullfile(outdir,'cases');
for i=1:n
    field=char(cfg.ParameterField(i));
    ref_value(i)=truth.(field); sim_value(i)=current.(field);
    deviation(i)=min(1,abs(sim_value(i)-ref_value(i))/cfg.DeviationScale(i));

    [corrected_score(i),corrected_run]=intervention_score( ...
        scene,ref,case_dir,field,ref_value(i));
    reduction(i)=max(0,A_base-corrected_score(i));

    delta=cfg.PerturbationStep(i);
    [minus_score(i),minus_run]=intervention_score( ...
        scene,ref,case_dir,field,sim_value(i)-delta);
    [plus_score(i),plus_run]=intervention_score( ...
        scene,ref,case_dir,field,sim_value(i)+delta);
    sensitivity(i)=abs(plus_score(i)-minus_score(i))/2;
    runs{i}=struct('corrected',corrected_run,'minus',minus_run,'plus',plus_run);
    fprintf('Traceability: %s, correction %.4g, sensitivity %.4g\n', ...
        cfg.ParameterName(i),reduction(i),sensitivity(i));
end

red_n=reduction/(max(reduction)+eps); sens_n=sensitivity/(max(sensitivity)+eps);
raw=cfg.Weight.*(0.35*deviation+0.40*red_n+0.25*sens_n);
contribution=100*raw/(sum(raw)+eps);
T=table(cfg.ParameterName,cfg.ParameterField,cfg.Importance,cfg.Unit,cfg.Weight, ...
    ref_value,sim_value,cfg.DeviationScale,cfg.PerturbationStep,deviation, ...
    corrected_score,reduction,minus_score,plus_score,sensitivity,contribution,cfg.Why, ...
    'VariableNames',{'ParameterName','ParameterField','Importance','Unit','Weight', ...
    'ReferenceValue','SimulationValue','DeviationScale','PerturbationStep', ...
    'InputDeviationRisk','ScoreAfterCorrection','ErrorReduction','MinusScore', ...
    'PlusScore','LocalSensitivity','CandidateContribution_pct','Why'});
T=sortrows(T,'CandidateContribution_pct','descend');
save_table_csv(T,fullfile(outdir,'propagation_traceability_parameter_ranking.csv'));
save_table_csv(baseline,fullfile(outdir,'propagation_traceability_baseline_metrics.csv'));

input_risk=sum(cfg.Weight.*deviation)/(sum(cfg.Weight)+eps);
gain=A_base/(input_risk+eps);
result.method='Parameter intervention, correction experiment, and local sensitivity candidate-source ranking';
result.baseline_status=baseline_status; result.baseline_anomaly_score=A_base;
result.baseline_metrics=baseline; result.input_parameter_risk=input_risk;
result.error_amplification_gain=gain; result.parameter_ranking=T;
result.reference_run=ref.meta.run_dir; result.baseline_run=base.meta.run_dir; result.runs=runs;
result.interpretation=['Candidate contribution index ranks diagnostic priority; ' ...
    'it is not a physical causal or variance contribution percentage.'];
save(fullfile(outdir,'propagation_traceability_result.mat'),'result');

fig=figure('Visible','off','Color','w'); cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
barh(categorical(T.ParameterName),T.CandidateContribution_pct);
xlabel('候选贡献指数 / %'); title('声传播模型候选误差源排序'); grid on;
saveas(fig,fullfile(outdir,'propagation_traceability_ranking.png'));
end

function [score,run]=intervention_score(scene,ref,parent_dir,field,value)
assert(value>0,'propagation:Traceability','Intervention for %s must remain positive.',field);
change=struct(); change.(field)=value;
sc=scene;
sc.simulation_root=propagation_prepare_case(scene.simulation_root,parent_dir,change);
sim=call_propagation_model_under_test(sc);
metrics=propagation_build_metric_table(sc,ref,sim);
[status,score]=propagation_evaluate_metrics(metrics);
assert(isfinite(score),'propagation:Traceability','Intervention score is not finite for %s.',field);
run=struct('parameter_value',value,'status',status,'simulation_run',sim.meta.run_dir,'metrics',metrics);
end
