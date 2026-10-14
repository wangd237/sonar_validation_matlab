function result = propagation_self_check(scene,outdir)
%PROPAGATION_SELF_CHECK Two independent Bellhop runs of the same triplet.
ensure_dir(outdir);
scene.simulation_root=scene.reference_root;
ref=generate_propagation_reference(scene);
sim=call_propagation_model_under_test(scene);
[T,aux]=propagation_build_metric_table(scene,ref,sim);
errors=T.Enabled & T.Direction=="lower";
correlations=T.Enabled & T.Direction=="higher";
passed=all(isfinite(T.Value(T.Enabled))) && all(abs(T.Value(errors))<1e-10) ...
    && all(abs(T.Value(correlations)-1)<1e-10) ...
    && T.Status(T.Metric=="E_H")=="未启用";
result.passed=passed; result.metrics=T; result.aux=aux;
result.reference=ref; result.model=sim;
save_table_csv(T,fullfile(outdir,'propagation_self_check_metrics.csv'));
save(fullfile(outdir,'propagation_self_check_result.mat'),'result');
assert(passed,'propagation:SelfCheck','Identical-input self-check failed; see %s',outdir);
fprintf('Identical-input Bellhop self-check: PASS (%d matched arrivals).\n',aux.matched_arrivals);
end
