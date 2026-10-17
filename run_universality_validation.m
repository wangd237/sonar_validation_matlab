%% RUN_UNIVERSALITY_VALIDATION Run ONLY Universality V2 Bellhop Mock.
clear; clc;
root=fileparts(mfilename('fullpath'));
addpath(genpath(root));
scene=propagation_default_scene();
cfg=propagation_universality_config();
outdir=fullfile(root,'results','propagation','universality');
uni=propagation_universality_analysis(scene,outdir,cfg);
disp(uni.points);
disp(uni.sampled_intervals);
fprintf('Universality V2 (Bellhop Mock, NOT actual model applicability): %s\n',outdir);
