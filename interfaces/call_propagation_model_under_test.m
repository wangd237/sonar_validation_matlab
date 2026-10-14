function out = call_propagation_model_under_test(scene)
%CALL_PROPAGATION_MODEL_UNDER_TEST Replace this body when a real model arrives.
out = propagation_run_bellhop(scene, scene.simulation_root, 'simulation');
out.role = 'model_under_test';
end
