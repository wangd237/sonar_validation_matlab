%% RUN_ACCURACY_VALIDATION Run ONLY the accuracy module (Bellhop mock).
clear; clc;
root=fileparts(mfilename('fullpath'));
addpath(genpath(root));
scene=propagation_default_scene();
outdir=fullfile(root,'results','propagation','accuracy');
acc=propagation_accuracy_validation(scene,outdir);
disp(acc.metrics);
fprintf('Accuracy V2: %s',char(acc.overall_status));
if isfinite(acc.total_score)
    fprintf(' (%.2f / 100)',acc.total_score);
end
fprintf('\nOutput: %s\n',outdir);
