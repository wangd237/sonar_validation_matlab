function result = propagation_universality_analysis(scene,outdir)
%PROPAGATION_UNIVERSALITY_ANALYSIS Demo sensitivity over frequency/depth offset.
% Each ref/sim pair has identical frequency and receiver coordinates.
ensure_dir(outdir);
frequencies=[250 500 1000]; offsets=[0 1 2];
z0=propagation_demo_parameter(scene.reference_root,'SOURCE_DEPTH_M');
rows=cell(numel(frequencies)*numel(offsets),11); pairs=cell(size(rows,1),1); n=0;
for f=frequencies
    sc=scene;
    sc.reference_root=propagation_prepare_case(scene.reference_root, ...
        fullfile(outdir,'cases'),struct('freq_hz',f));
    ref=generate_propagation_reference(sc);
    for dz=offsets
        sc.simulation_root=propagation_prepare_case(scene.reference_root, ...
            fullfile(outdir,'cases'),struct('freq_hz',f,'source_depth_m',z0+dz));
        sim=call_propagation_model_under_test(sc);
        T=propagation_build_metric_table(sc,ref,sim);
        [overall,score,key_pass,key_norm]=propagation_evaluate_metrics(T);
        n=n+1;
        rows(n,:)={f,dz,T.Value(1),T.Value(2),T.Value(3),T.Value(5),T.Value(6), ...
            key_pass,key_norm,score,overall};
        pairs{n}=struct('reference_run',ref.meta.run_dir,'simulation_run',sim.meta.run_dir,'metrics',T);
        fprintf('Propagation scan: %g Hz, source offset %+g m, %s\n',f,dz,overall);
    end
end
T=cell2table(rows,'VariableNames',{'Frequency_Hz','SourceDepthOffset_m', ...
    'E_MP','RMSE_tau_s','RMSE_TL_dB','E_SP','rho_SP','KeyPass', ...
    'KeyNormalizedError','AnomalyScore','Status'});
by_frequency=summarize(T,'Frequency_Hz',frequencies);
by_offset=summarize(T,'SourceDepthOffset_m',offsets);
save_table_csv(T,fullfile(outdir,'propagation_universality_scene_results.csv'));
save_table_csv(by_frequency,fullfile(outdir,'propagation_universality_by_frequency.csv'));
save_table_csv(by_offset,fullfile(outdir,'propagation_universality_by_source_offset.csv'));
result.scene_table=T; result.by_frequency=by_frequency; result.by_source_offset=by_offset;
result.runs=pairs;
result.interpretation='Synthetic perturbation scan; not a verified applicability boundary.';
save(fullfile(outdir,'propagation_universality_result.mat'),'result');
fig=figure('Visible','off','Color','w'); cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
for f=frequencies
    idx=T.Frequency_Hz==f;
    plot(T.SourceDepthOffset_m(idx),T.KeyNormalizedError(idx),'-o','DisplayName',sprintf('%g Hz',f)); hold on;
end
yline(1,'--','Demo pass boundary'); grid on; legend('Location','best');
xlabel('Source depth offset (m)'); ylabel('Maximum normalized key error');
title('Synthetic configuration sensitivity');
saveas(fig,fullfile(outdir,'propagation_universality.png'));
end

function S=summarize(T,field,values)
n=numel(values); N=zeros(n,1); ValidN=N; PassRate=N; P95_NormalizedError=nan(n,1);
for k=1:n
    idx=T.(field)==values(k); x=T.KeyNormalizedError(idx);
    N(k)=nnz(idx); ValidN(k)=nnz(isfinite(x)); PassRate(k)=mean(T.KeyPass(idx));
    % Do not hide invalid cases by dropping their errors from the percentile.
    if ValidN(k)==N(k), P95_NormalizedError(k)=percentile_simple(x,95); end
end
S=table(values(:),N,ValidN,PassRate,P95_NormalizedError, ...
    'VariableNames',{'GroupValue','N','ValidN','PassRate','P95_NormalizedError'});
end
