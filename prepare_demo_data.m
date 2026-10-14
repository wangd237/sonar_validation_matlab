%% PREPARE_DEMO_DATA Export Bellhop baseline and perturbed configuration outputs.
clear; clc;
root=fileparts(mfilename('fullpath')); addpath(genpath(root));
outdir=fullfile(root,'demo_data'); ensure_dir(outdir);

propagation_scene=propagation_default_scene();
propagation_reference=generate_propagation_reference(propagation_scene);
propagation_sim_output=call_propagation_model_under_test(propagation_scene);
save(fullfile(outdir,'propagation_reference_and_sim.mat'), ...
    'propagation_scene','propagation_reference','propagation_sim_output','-v7.3');

fprintf('演示数据已保存到：%s\n',outdir);
