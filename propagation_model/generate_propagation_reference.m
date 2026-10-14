function ref = generate_propagation_reference(scene)
%GENERATE_PROPAGATION_REFERENCE Synthetic baseline, not measured ground truth.
ref = propagation_run_bellhop(scene, scene.reference_root, 'reference');
ref.role = 'reference';
ref.meta.reference_description = scene.reference_description;
end
