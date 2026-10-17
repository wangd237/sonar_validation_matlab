function result = propagation_universality_analysis(scene,outdir,cfg)
%PROPAGATION_UNIVERSALITY_ANALYSIS Seven OFAT scans using Accuracy V2.
% Bellhop Mock uses identical physical input for reference and simulation.
if nargin<3, cfg=propagation_universality_config(); end
ensure_dir(outdir);
assert(isfield(cfg,'mock') && islogical(cfg.mock) && cfg.mock, ...
    'propagation:UniversalityMode', ...
    'This iteration is Bellhop Mock only; real-model mode is not implemented.');
assert(any(string(cfg.pass_rule)==["focus","both"]), ...
    'propagation:UniversalityRule','Use focus or both.');
for ext={'.env','.bty','.ati'}
    assert(isfile([cfg.base_root ext{1}]), ...
        'propagation:UniversalityTemplate','Missing annotated baseline: %s',ext{1});
end
names=string(cfg.metric_names(:));
assert(numel(names)==10 && isequal(names, ...
    ["TL_curve";"Convergence_count";"Convergence_center";"Convergence_width"; ...
    "Shadow_count";"Shadow_position";"Shadow_width"; ...
    "Arrival_delay";"Adjacent_delay";"Last_arrival"]), ...
    'propagation:UniversalityMetrics','Metric order differs from Accuracy V2.');
id=strings(0,1); parameter=strings(0,1); unit=strings(0,1);
value=zeros(0,1); label=strings(0,1);
accuracy_score=zeros(0,1); accuracy_status=strings(0,1);
focus_score=zeros(0,1); focus_status=strings(0,1);
error_message=strings(0,1); run_root=strings(0,1);
metric_rows=cell(0,8); detail_rows=cell(0,7);
runs=cell(0,1);
k=0;
for g=1:numel(cfg.scans)
    scan=cfg.scans(g);
    assert(numel(scan.focus)==10 && any(scan.focus), ...
        'propagation:UniversalityFocus','Each scan needs ten focus switches.');
    for j=1:numel(scan.values)
        k=k+1;
        v=scan.values(j);
        group=string(scan.key);
        point_id=sprintf('%s_%03d',char(group),j);
        if isempty(scan.labels), point_label=string(sprintf('%.12g',v));
        else, point_label=string(scan.labels(j)); end
        acc=NaN; focus=NaN; acc_state="未验证"; focus_state="未验证";
        message=""; case_root="";
        try
            [case_root,z]=propagation_universality_prepare_case( ...
                cfg,scan,v,fullfile(outdir,'cases',char(group)));
            sc=scene;
            sc.reference_root=case_root;
            sc.simulation_root=case_root;
            sc.work_dir=fullfile(outdir,'work');
            sc.reference_description='Bellhop Mock, shared condition; NOT measured data';
            acfg=cfg.accuracy;
            acfg.evaluation_depth_m=z;
            ref=generate_propagation_reference(sc);
            sim=call_propagation_model_under_test(sc);
            ev=propagation_accuracy_v2_from_bellhop(ref,sim,acfg);
            assert(isequal(string(ev.metrics.Metric(:)),names), ...
                'propagation:UniversalityMetrics','Returned V2 metrics do not match configuration.');
            acc=ev.total_score;
            acc_state=ev.overall_status;
            [focus,focus_state]=propagation_universality_focus(ev.metrics,scan.focus);
            for t=1:10
                metric_rows(end+1,:)={string(point_id),group,v,point_label, ...
                    names(t),double(ev.metrics.Score(t)),string(ev.metrics.Status(t)), ...
                    logical(scan.focus(t))}; %#ok<AGROW>
            end
            sub=propagation_accuracy_v2_detail_table(ev);
            for t=1:height(sub)
                detail_rows(end+1,:)={string(point_id),group,v, ...
                    string(sub.Metric(t)),string(sub.SubMetric(t)), ...
                    double(sub.Value(t)),string(sub.Unit(t))}; %#ok<AGROW>
            end
            runs{end+1,1}=struct('point_id',string(point_id), ...
                'case_root',string(case_root),'reference_run',string(ref.meta.run_dir), ...
                'simulation_run',string(sim.meta.run_dir), ...
                'evaluation',ev,'focus',logical(scan.focus)); %#ok<AGROW>
        catch ME
            message=string(ME.identifier)+": "+string(ME.message);
            acc_state="运行失败"; focus_state="运行失败";
            for t=1:10
                metric_rows(end+1,:)={string(point_id),group,v,point_label, ...
                    names(t),NaN,"运行失败",logical(scan.focus(t))}; %#ok<AGROW>
            end
            if cfg.fail_fast, rethrow(ME); end
            warning('propagation:UniversalityCaseFailed', ...
                '%s: %s',point_id,char(message));
        end
        id(end+1,1)=string(point_id); %#ok<AGROW>
        parameter(end+1,1)=group;
        unit(end+1,1)=string(scan.unit);
        value(end+1,1)=v; label(end+1,1)=point_label;
        accuracy_score(end+1,1)=acc; accuracy_status(end+1,1)=string(acc_state);
        focus_score(end+1,1)=focus; focus_status(end+1,1)=string(focus_state);
        error_message(end+1,1)=message; run_root(end+1,1)=string(case_root);
        fprintf('Universality Mock: %s=%s %s: V2 %s; focus %s\n', ...
            char(group),char(point_label),char(scan.unit), ...
            char(acc_state),char(focus_state));
    end
end
points=table(id,parameter,unit,value,label,accuracy_score, ...
    accuracy_status,focus_score,focus_status,error_message,run_root, ...
    'VariableNames',{'PointID','Parameter','Unit','Value','ValueLabel', ...
    'AccuracyScore','AccuracyStatus','FocusScore','FocusStatus', ...
    'ErrorMessage','CaseRoot'});
metric_table=cell2table(metric_rows,'VariableNames', ...
    {'PointID','Parameter','Value','ValueLabel','Metric','Score','Status','Focus'});
detail_table=cell2table(detail_rows,'VariableNames', ...
    {'PointID','Parameter','Value','Metric','SubMetric','RawValue','Unit'});
if ~isempty(metric_table)
    metric_table.PointID=string(metric_table.PointID);
    metric_table.Parameter=string(metric_table.Parameter);
    metric_table.Value=cell2mat(metric_table.Value);
    metric_table.ValueLabel=string(metric_table.ValueLabel);
    metric_table.Metric=string(metric_table.Metric);
    metric_table.Score=cell2mat(metric_table.Score);
    metric_table.Status=string(metric_table.Status);
    metric_table.Focus=cell2mat(metric_table.Focus);
end
if ~isempty(detail_table)
    detail_table.PointID=string(detail_table.PointID);
    detail_table.Parameter=string(detail_table.Parameter);
    detail_table.Value=cell2mat(detail_table.Value);
    detail_table.Metric=string(detail_table.Metric);
    detail_table.SubMetric=string(detail_table.SubMetric);
    detail_table.RawValue=cell2mat(detail_table.RawValue);
    detail_table.Unit=string(detail_table.Unit);
end
intervals=propagation_universality_intervals(points,cfg.pass_rule);
save_table_csv(points,fullfile(outdir,'propagation_universality_points.csv'));
save_table_csv(metric_table,fullfile(outdir,'propagation_universality_metric_scores.csv'));
save_table_csv(detail_table,fullfile(outdir,'propagation_universality_raw_metrics.csv'));
save_table_csv(intervals,fullfile(outdir,'propagation_universality_sampled_intervals.csv'));
result=struct('points',points,'metric_scores',metric_table, ...
    'raw_metrics',detail_table,'sampled_intervals',intervals,'runs',{runs}, ...
    'config',cfg,'source_type',"Bellhop Mock, not model validation", ...
    'interpretation',"Observed passing SAMPLE RUNS only; Mock cannot determine real applicability.");
save(fullfile(outdir,'propagation_universality_result.mat'),'result','-v7.3');
if cfg.emit_figures
    for g=1:numel(cfg.scans)
        scan=cfg.scans(g);
        part=points(points.Parameter==string(scan.key),:);
        f=figure('Visible','off','Color','w');
        cleanup=onCleanup(@() close(f)); %#ok<NASGU>
        x=1:height(part);
        plot(x,part.FocusScore,'-o','DisplayName','Focus'); hold on;
        plot(x,part.AccuracyScore,'--s','DisplayName','All 10');
        yline(80,':','V2 demo accurate threshold');
        ylim([0 105]); xlim([0.5 max(1.5,height(part)+0.5)]);
        xticks(x); xticklabels(cellstr(part.ValueLabel));
        xlabel(sprintf('%s (%s)',char(scan.key),char(scan.unit)));
        ylabel('V2 score (0-100)'); legend('Location','best'); grid on;
        title('Bellhop Mock: scores do not establish applicability');
        saveas(f,fullfile(outdir,sprintf('propagation_universality_%s.png',char(scan.key))));
        clear cleanup;
    end
end
end
