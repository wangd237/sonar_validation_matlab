%% RUN_PROPAGATION_VALIDATION Bellhop synthetic configuration comparison.
clear; clc;
root=fileparts(mfilename('fullpath')); addpath(genpath(root));
outdir=fullfile(root,'results','propagation'); ensure_dir(outdir);
scene=propagation_default_scene();
fprintf('Bellhop propagation demo: synthetic reference, demonstration thresholds.\n');
fprintf('[1/4] Identical-input self-check...\n');
self_check=propagation_self_check(scene,fullfile(outdir,'self_check'));
fprintf('[2/4] Source-depth perturbation comparison...\n');
acc=propagation_accuracy_validation(scene,fullfile(outdir,'accuracy'));
fprintf('[3/4] Frequency / source-depth sensitivity scan...\n');
uni=propagation_universality_analysis(scene,fullfile(outdir,'universality'));
fprintf('[4/4] Parameter intervention, correction and candidate-source ranking...\n');
trace=propagation_traceability_analysis(scene,fullfile(outdir,'traceability'));
Summary=table("声传播计算模型",string(acc.overall_status),acc.anomaly_score,self_check.passed, ...
    "未启用","合成配置对比，使用演示阈值", ...
    'VariableNames',{'Model','DemoStatus','DemoAnomalyScore','SelfCheckPassed','E_H','Scope'});
save_table_csv(Summary,fullfile(outdir,'validation_summary.csv'));
save(fullfile(outdir,'propagation_complete_result.mat'),'scene','self_check','acc','uni','trace','Summary');
disp(Summary);
fprintf('Results: %s\n',outdir);
