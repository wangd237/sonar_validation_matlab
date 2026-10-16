%% RUN_UNIVERSALITY_VALIDATION Run ONLY the legacy universality module.
% Its metrics will be updated in a later phase.
clear; clc;
root=fileparts(mfilename('fullpath'));
addpath(genpath(root));
scene=propagation_default_scene();
outdir=fullfile(root,'results','propagation','universality');
uni=propagation_universality_analysis(scene,outdir);
disp(uni.scene_table);
fprintf('Universality (legacy metrics), output: %s\n',outdir);
