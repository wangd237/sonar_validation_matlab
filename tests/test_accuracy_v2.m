function tests=test_accuracy_v2
%TEST_ACCURACY_V2 Synthetic tests independent of Bellhop installation.
tests=functiontests(localfunctions);
end

function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
tc.TestData.cfg=propagation_accuracy_v2_config();
end

function testZonePeaksAndThreeDbWidths(tc)
cfg=tc.TestData.cfg;
cfg.smooth_window_m=1;
r=(0:50:10000).';
% Two independent 12 dB TL valleys, with 1000-m Gaussian scale.
tl=80-12*exp(-0.5*((r-3000)/500).^2) ...
     -12*exp(-0.5*((r-7000)/500).^2);
f=propagation_extract_tl_features(r,tl,cfg);
verifyEqual(tc,numel(f.convergence),2);
verifyEqual(tc,[f.convergence.center_m],[3000 7000]);
expected=2*500*sqrt(-2*log(1-3/12));
verifyLessThan(tc,abs(f.convergence(1).width_m-expected),60);
end

function testAdaptiveGate(tc)
a=zone(10000,1000); b=zone(10900,1100);
p=propagation_match_zones(a,b);
verifyEqual(tc,p,[1 1]);
b=zone(11200,1100);
verifyEmpty(tc,propagation_match_zones(a,b));
end

function testIdenticalCurveAndNoZone(tc)
cfg=tc.TestData.cfg;
cfg.smooth_window_m=1;
r=(0:50:10000).';
tl=80-12*exp(-0.5*((r-5000)/500).^2);
a=struct('range_m',r,'tl_db',tl);
o=propagation_accuracy_v2(a,a,cfg);
verifyEqual(tc,o.metrics.Score(1),100,'AbsTol',1e-10);
verifyEqual(tc,o.metrics.Score(2),100,'AbsTol',1e-10);
verifyEqual(tc,o.metrics.Score(3),100,'AbsTol',1e-10);
verifyEqual(tc,o.metrics.Score(4),100,'AbsTol',1e-10);
verifyEqual(tc,o.overall_status,"未验证"); % no arrivals to score
end

function testNoInventedTimingCalibration(tc)
cfg=tc.TestData.cfg;
a=struct('arrivals',arrival([1;1.02]));
a.arrivals=rmfield(a.arrivals,{'tx_time_s','system_delay_s'});
out=propagation_accuracy_v2(a,a,cfg);
verifyEqual(tc,out.metrics.Status(8:10),repmat("未验证",3,1));
end

function testCalibratedTimeShift(tc)
cfg=tc.TestData.cfg;
a=struct('arrivals',arrival([1;1.02;1.04]));
b=a;
b.arrivals.delay_s=b.arrivals.delay_s+0.002;
b.arrivals.tx_time_s=0.002;
out=propagation_accuracy_v2(a,b,cfg);
verifyEqual(tc,out.metrics.Score(8),100,'AbsTol',1e-9);
verifyEqual(tc,out.metrics.Score(9),100,'AbsTol',1e-9);
verifyEqual(tc,out.metrics.Score(10),100,'AbsTol',1e-9);
end

function testAggregationUsesOnlyScoresStatusesAndWeights(tc)
names=strings(10,1);
scores=100*ones(10,1);
statuses=repmat("准确",10,1);
weights=ones(10,1);
T=table(names,scores,statuses,weights, ...
    'VariableNames',{'Metric','Score','Status','Weight'});
[s,level]=propagation_accuracy_aggregate_scores(T);
verifyEqual(tc,s,100,'AbsTol',1e-12);
verifyEqual(tc,level,"准确");
T.Score(2)=NaN; T.Status(2)="未验证";
[s,level]=propagation_accuracy_aggregate_scores(T);
verifyTrue(tc,isnan(s));
verifyEqual(tc,level,"未验证");
end

function testSubmetricCsvTableContract(tc)
cfg=tc.TestData.cfg;
r=(0:50:10000).';
tl=80-12*exp(-0.5*((r-5000)/500).^2);
a=struct('range_m',r,'tl_db',tl);
o=propagation_accuracy_v2(a,a,cfg);
raw=propagation_accuracy_v2_detail_table(o);
verifyTrue(tc,istable(raw));
verifyTrue(tc,any(raw.SubMetric=="rmse_db"));
verifyTrue(tc,any(raw.SubMetric=="pearson"));
end

function testZoneDiagnosticsUseSamePairsAsScoring(tc)
cfg=tc.TestData.cfg;
cfg.smooth_window_m=1;
r=(0:50:10000).';
ref_tl=80-12*exp(-0.5*((r-3000)/500).^2) ...
    -12*exp(-0.5*((r-7000)/500).^2);
sim_tl=80-12*exp(-0.5*((r-3050)/500).^2) ...
    -12*exp(-0.5*((r-7050)/500).^2);
ref=struct('range_m',r,'tl_db',ref_tl);
sim=struct('range_m',r,'tl_db',sim_tl);
o=propagation_accuracy_v2(ref,sim,cfg);
verifyTrue(tc,o.zone_diagnostics.available);
[d,m]=propagation_accuracy_zone_diagnostic_tables(o);
verifyEqual(tc,sum(d.ZoneType=="Convergence" & d.Dataset=="Ref"), ...
    numel(o.zone_diagnostics.reference.convergence));
verifyEqual(tc,sum(d.ZoneType=="Convergence" & d.Dataset=="Sim"), ...
    numel(o.zone_diagnostics.simulation.convergence));
verifyEqual(tc,size(m,1), ...
    size(o.zone_diagnostics.convergence_pairs,1) + ...
    size(o.zone_diagnostics.shadow_pairs,1));
verifyEqual(tc,o.detail{2}.matched, ...
    size(o.zone_diagnostics.convergence_pairs,1));
verifyEqual(tc,o.detail{5}.matched, ...
    size(o.zone_diagnostics.shadow_pairs,1));
verifyTrue(tc,all(m.CenterError_m<=m.Tolerance_m));
verifyGreaterThan(tc,height(m),0);
temp=tempname; mkdir(temp);
cleanup=onCleanup(@() rmdir(temp,'s')); %#ok<NASGU>
propagation_accuracy_plot_zone_diagnostics(o,temp);
verifyTrue(tc,isfile(fullfile(temp, ...
    'propagation_accuracy_convergence_zones.png')));
verifyTrue(tc,isfile(fullfile(temp, ...
    'propagation_accuracy_shadow_zones.png')));
end

function testZoneDiagnosticsEmptyAndPlots(tc)
cfg=tc.TestData.cfg;
r=(0:100:8000).';
ref=struct('range_m',r,'tl_db',60+zeros(size(r)));
out=propagation_accuracy_v2(ref,ref,cfg);
verifyTrue(tc,out.zone_diagnostics.available);
[d,m]=propagation_accuracy_zone_diagnostic_tables(out);
verifyEqual(tc,height(d),0);
verifyEqual(tc,height(m),0);
temp=tempname;
mkdir(temp);
cleanup=onCleanup(@() rmdir(temp,'s')); %#ok<NASGU>
propagation_accuracy_plot_zone_diagnostics(out,temp);
verifyTrue(tc,isfile(fullfile(temp, ...
    'propagation_accuracy_convergence_zones.png')));
verifyTrue(tc,isfile(fullfile(temp, ...
    'propagation_accuracy_shadow_zones.png')));
end

function testInvalidInputAndWeights(tc)
cfg=tc.TestData.cfg;
cfg.weights(1)=-1;
verifyError(tc,@() propagation_accuracy_v2(struct(),struct(),cfg), ...
    'propagation:AccuracyWeights');
end

function testBellhopAdapterUsesConfiguredEvaluationDepth(tc)
cfg=tc.TestData.cfg;
ref=bellhop_fixture(); sim=ref;
out=propagation_accuracy_v2_from_bellhop(ref,sim,cfg);
verifyEqual(tc,out.requested_receiver_depth_m,500);
verifyEqual(tc,out.receiver_depth_m,500);
end

function testBellhopAdapterRejectsUnavailableEvaluationDepth(tc)
cfg=tc.TestData.cfg;
cfg.evaluation_depth_m=525;
cfg.evaluation_depth_tolerance_m=20;
ref=bellhop_fixture();
verifyError(tc,@() propagation_accuracy_v2_from_bellhop(ref,ref,cfg), ...
    'propagation:AccuracyDepth');
end

function testMatchingGateDoesNotRelaxArrivalScoreLimits(tc)
cfg=tc.TestData.cfg;
verifyEqual(tc,cfg.match_delay_s,0.010,'AbsTol',1e-12);
a=struct('arrivals',arrival([1;1.02]));
b=a;
b.arrivals.delay_s=b.arrivals.delay_s+0.008;
out=propagation_accuracy_v2(a,b,cfg);
verifyEqual(tc,out.detail{8}.matched,2);
verifyLessThan(tc,out.metrics.Score(8),60);
verifyEqual(tc,out.metrics.Status(8),"不准确");
end

function testOrderedArrivalMatchingUsesBounceLabels(tc)
cfg=tc.TestData.cfg;
a=arrival([1;1.02;1.04]);
b=arrival([1.008;1.028;1.048]);
a.top_bounces=[0;1;2]; a.bottom_bounces=[2;1;0];
b.top_bounces=[0;1;9]; b.bottom_bounces=[2;1;9];
m=propagation_match_arrivals_ordered(a,b,cfg);
verifyTrue(tc,m.path_labels_used);
verifyEqual(tc,m.pairs,[1 1;2 2]);
verifyEqual(tc,m.delay_error_s,0.008*ones(2,1),'AbsTol',1e-12);
end

function testOrderedArrivalMatchingSkipsUnmatchedPaths(tc)
cfg=tc.TestData.cfg;
a=rmfield(arrival([1;1.02;1.04]),{'top_bounces','bottom_bounces'});
b=rmfield(arrival([0.9;1.008;1.048;1.2]), ...
    {'top_bounces','bottom_bounces'});
m=propagation_match_arrivals_ordered(a,b,cfg);
verifyFalse(tc,m.path_labels_used);
verifyEqual(tc,m.pairs,[1 2;3 3]);
verifyEqual(tc,m.matched_count,2);
end

function testArrivalMetricsDoNotRequireBounceMetadata(tc)
cfg=tc.TestData.cfg;
a=rmfield(arrival([1;1.02]),{'top_bounces','bottom_bounces'});
b=a; b.delay_s=b.delay_s+0.002;
out=propagation_accuracy_v2(struct('arrivals',a),struct('arrivals',b),cfg);
verifyEqual(tc,out.detail{8}.matched,2);
verifyFalse(tc,out.detail{8}.path_labels_used);
verifyEqual(tc,out.detail{8}.rmse_s,0.002,'AbsTol',1e-12);
verifyEqual(tc,out.detail{9}.compared_intervals,1);
verifyTrue(tc,out.arrival_diagnostics.available);
temp=tempname; mkdir(temp);
cleanup=onCleanup(@() rmdir(temp,'s')); %#ok<NASGU>
propagation_accuracy_plot_arrivals(out,temp);
verifyTrue(tc,isfile(fullfile(temp, ...
    'propagation_accuracy_multipath_arrivals.png')));
end

function z=zone(c,w)
z=struct('center_m',c,'left_m',c-w/2,'right_m',c+w/2, ...
    'width_m',w,'prominence_db',12,'truncated',false);
end

function a=arrival(t)
a.delay_s=t(:);
a.amplitude=ones(numel(t),1);
a.top_bounces=zeros(numel(t),1);
a.bottom_bounces=zeros(numel(t),1);
a.tx_time_s=0;
a.system_delay_s=0;
end

function out=bellhop_fixture()
out.range_m=(0:100:1000).';
out.receiver_depth_m=[100;500;1000];
[R,Z]=meshgrid(out.range_m,out.receiver_depth_m);
out.tl_db=60+0.001*R+0.002*Z;
out.valid_mask=true(size(out.tl_db));
out.arrivals=repmat({arrival([1;1.02])},size(out.tl_db));
end
