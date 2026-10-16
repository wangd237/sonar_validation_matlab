%% RUN_TRACEABILITY_VALIDATION Run ONLY the legacy traceability module.
% Its metrics will be updated in a later phase.
clear; clc;
root=fileparts(mfilename('fullpath'));
addpath(genpath(root));
scene=propagation_default_scene();
outdir=fullfile(root,'results','propagation','traceability');
trace=propagation_traceability_analysis(scene,outdir);
disp(trace.parameter_ranking);
fprintf('Traceability (legacy metrics), output: %s\n',outdir);
