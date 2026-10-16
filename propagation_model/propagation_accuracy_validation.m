function result=propagation_accuracy_validation(scene,outdir)
%PROPAGATION_ACCURACY_VALIDATION Standalone ten-indicator accuracy V2.
% Reference and simulation are BOTH Bellhop-generated MOCK data at present.
% Legacy five-indicator evaluation remains available separately to the
% universality/traceability modules, but is NOT the accuracy result.
ensure_dir(outdir);
ref=generate_propagation_reference(scene);
sim=call_propagation_model_under_test(scene);
eval=propagation_accuracy_v2_from_bellhop(ref,sim);
submetrics=propagation_accuracy_v2_detail_table(eval);
save_table_csv(eval.metrics,fullfile(outdir,'propagation_accuracy_metrics.csv'));
save_table_csv(submetrics,fullfile(outdir,'propagation_accuracy_submetrics.csv'));
% Diagnostics reuse exactly the candidates/pairs that produced the scores.
% A separate export allows inspecting detection mistakes vs matching mistakes.
detections=table(); matches=table();
if eval.zone_diagnostics.available
    [detections,matches]=propagation_accuracy_zone_diagnostic_tables(eval);
    save_table_csv(detections, ...
        fullfile(outdir,'propagation_accuracy_zone_detections.csv'));
    save_table_csv(matches, ...
        fullfile(outdir,'propagation_accuracy_zone_matches.csv'));
    propagation_accuracy_plot_zone_diagnostics(eval,outdir);
    fprintf('Convergence zones: Ref %d, Sim %d, matched %d.\n', ...
        numel(eval.zone_diagnostics.reference.convergence), ...
        numel(eval.zone_diagnostics.simulation.convergence), ...
        size(eval.zone_diagnostics.convergence_pairs,1));
    fprintf('Shadow zones: Ref %d, Sim %d, matched %d.\n', ...
        numel(eval.zone_diagnostics.reference.shadow), ...
        numel(eval.zone_diagnostics.simulation.shadow), ...
        size(eval.zone_diagnostics.shadow_pairs,1));
else
    fprintf('Zone diagnostics unavailable: TL sampling did not satisfy detection conditions.\n');
end

result.scene=scene;
result.reference=ref;
result.model=sim;
result.metrics=eval.metrics;
result.details=eval.detail;
result.zone_detections=detections;
result.zone_matches=matches;
result.total_score=eval.total_score;
result.overall_status=eval.overall_status;
result.evaluation=eval;
result.source_type="Bellhop mock reference and simulation";
save(fullfile(outdir,'propagation_accuracy_result.mat'),'result');
if isfield(eval,'tl_curve') && ~isempty(eval.tl_curve.range_m)
    plot_tl_comparison(eval.tl_curve,outdir);
end
end

function plot_tl_comparison(curve,outdir)
fig=figure('Visible','off','Color','w');
cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
subplot(2,1,1);
plot(curve.range_m/1000,curve.ref_tl_db,'DisplayName','Reference (mock)');
hold on;
plot(curve.range_m/1000,curve.sim_tl_db,'DisplayName','Simulation (mock)');
xlabel('Range (km)'); ylabel('TL (dB)');
title('Accuracy V2: receiver-depth TL comparison');
legend('Location','best'); grid on;
subplot(2,1,2);
plot(curve.range_m/1000,curve.sim_tl_db-curve.ref_tl_db);
xlabel('Range (km)'); ylabel('TL difference (dB)'); grid on;
saveas(fig,fullfile(outdir,'propagation_accuracy_tl_curve.png'));
end
