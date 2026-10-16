function result = propagation_accuracy_validation(scene,outdir)
%PROPAGATION_ACCURACY_VALIDATION Synthetic ref/sim comparison through Bellhop.
ensure_dir(outdir);
ref=generate_propagation_reference(scene);
sim=call_propagation_model_under_test(scene);
[T,aux]=propagation_build_metric_table(scene,ref,sim);
[overall,score]=propagation_evaluate_metrics(T);
print_metric_table(T,'声传播模型配置对比（合成参考、演示阈值）');
save_table_csv(T,fullfile(outdir,'propagation_accuracy_metrics.csv'));
v2=propagation_accuracy_v2_from_bellhop(ref,sim);
save_table_csv(v2.metrics,fullfile(outdir,'propagation_accuracy_v2_metrics.csv'));
result.accuracy_v2=v2;
result.scene=scene; result.reference=ref; result.model=sim;
result.metrics=T; result.overall_status=overall; result.anomaly_score=score; result.aux=aux;
save(fullfile(outdir,'propagation_accuracy_result.mat'),'result','scene','ref','sim','T','aux','overall','score');
plot_results(ref,sim,aux,outdir);
end

function plot_results(ref,sim,aux,outdir)
fig=figure('Visible','off','Color','w'); cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
values={aux.ref_tl_db,aux.sim_tl_db,aux.tl_difference_db,aux.structure_error_map};
titles={'Reference TL (dB)','Simulation TL (dB)','Simulation - reference TL (dB)','Multipath structure error'};
limits=[min([aux.ref_tl_db(aux.valid_mask);aux.sim_tl_db(aux.valid_mask)]), ...
    max([aux.ref_tl_db(aux.valid_mask);aux.sim_tl_db(aux.valid_mask)])];
for k=1:4
    subplot(2,2,k); v=values{k}; v(~aux.valid_mask)=NaN;
    imagesc(ref.range_m/1000,ref.receiver_depth_m,v); colorbar;
    xlabel('Range (km)'); ylabel('Depth (m)'); title(titles{k});
    if k<=2 && numel(limits)==2 && limits(2)>limits(1), caxis(limits); end
end
set(fig,'Position',[100 100 1100 750]);
saveas(fig,fullfile(outdir,'propagation_accuracy_fields.png'));
clear cleanup;

fig=figure('Visible','off','Color','w'); cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
% Pick an actual valid point with arrivals, rather than assuming a wet cell.
idx=find(aux.valid_mask & isfinite(aux.structure_error_map),1,'last');
if ~isempty(idx)
    [iz,ir]=ind2sub(size(aux.valid_mask),idx);
    r=ref.arrivals{idx}; s=sim.arrivals{idx};
    stem(r.delay_s,abs(r.amplitude),'DisplayName','Reference'); hold on;
    stem(s.delay_s,abs(s.amplitude),'--','DisplayName','Simulation');
    title(sprintf('Arrivals at range %.0f m, depth %.0f m',ref.range_m(ir),ref.receiver_depth_m(iz)));
    xlabel('Delay (s)'); ylabel('Arrival amplitude'); grid on; legend('Location','best');
else
    text(0.1,0.5,'No valid arrivals to compare'); axis off;
end
saveas(fig,fullfile(outdir,'propagation_accuracy_arrivals.png'));
end
