function tests = test_propagation_metrics
% Formula and failure-mode tests, independent of the Bellhop installation.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(genpath(root));
testCase.TestData.scene=propagation_default_scene();
testCase.TestData.ref=fixture();
end

function testIdentical(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref;
[T,aux]=propagation_build_metric_table(s,r,r);
verifyEqual(testCase,T.Value([1 2 3 5]),zeros(4,1),'AbsTol',1e-14);
verifyEqual(testCase,T.Value(6),1,'AbsTol',1e-14);
verifyEqual(testCase,T.Status(4),"未启用"); verifyFalse(testCase,T.Enabled(4));
[status,score,keypass]=propagation_evaluate_metrics(T);
verifyEqual(testCase,status,"通过"); verifyEqual(testCase,score,0,'AbsTol',1e-14);
verifyTrue(testCase,keypass); verifyEqual(testCase,aux.matched_arrivals,8);
end

function testAmplitudeScale(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref; sim=r;
sim.pressure=2*r.pressure;
T=propagation_build_metric_table(s,r,sim);
verifyEqual(testCase,T.Value(3),20*log10(2),'AbsTol',1e-12);
verifyEqual(testCase,T.Value(5),1,'AbsTol',1e-12);
verifyEqual(testCase,T.Value(6),1,'AbsTol',1e-12);
end

function testPhaseSensitivity(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref; sim=r;
sim.pressure=1i*r.pressure;
T=propagation_build_metric_table(s,r,sim);
verifyEqual(testCase,T.Value(3),0,'AbsTol',1e-12);
verifyEqual(testCase,T.Value(5),sqrt(2),'AbsTol',1e-12);
verifyEqual(testCase,T.Value(6),1,'AbsTol',1e-12);
end

function testOneToOneAndOptimal(testCase)
cfg=testCase.TestData.scene.validation; cfg.match_delay_s=0.011;
r=arrival([1;1.01]); s=arrival(1.005);
m=propagation_match_arrivals(r,s,cfg);
verifyEqual(testCase,m.matched_count,1);
verifyEqual(testCase,m.structure_error,1/3,'AbsTol',1e-14);
% Greedy nearest pairing could lose one match here; optimal assignment cannot.
r=arrival([1;1.01]); s=arrival([1.009;1.02]);
m=propagation_match_arrivals(r,s,cfg);
verifyEqual(testCase,m.matched_count,2);
end

function testReorderingAndBounceFamilies(testCase)
cfg=testCase.TestData.scene.validation;
r=arrival([1;1.1]); s=arrival([1.1;1]);
m=propagation_match_arrivals(r,s,cfg);
verifyEqual(testCase,m.pairs,[1 2;2 1]);
s=arrival([1;1.1]); s.top_bounces(:)=1;
m=propagation_match_arrivals(r,s,cfg);
verifyEqual(testCase,m.matched_count,0); verifyEqual(testCase,m.structure_error,1);
end

function testKnownDelay(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref; sim=r;
for k=1:numel(sim.arrivals), sim.arrivals{k}.delay_s=sim.arrivals{k}.delay_s+0.002; end
T=propagation_build_metric_table(s,r,sim);
verifyEqual(testCase,T.Value(1),0); verifyEqual(testCase,T.Value(2),0.002,'AbsTol',1e-12);
end

function testNoArrivalsDoesNotPass(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref;
r.arrivals(:)={arrival(zeros(0,1))};
T=propagation_build_metric_table(s,r,r);
[status,score,keypass]=propagation_evaluate_metrics(T);
verifyEqual(testCase,status,"不可判定"); verifyTrue(testCase,isnan(score)); verifyFalse(testCase,keypass);
verifyTrue(testCase,isnan(T.Value(1))); verifyTrue(testCase,isnan(T.Value(2)));
end

function testMissingSimulationArrivals(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref; sim=r;
sim.arrivals(:)={arrival(zeros(0,1))};
T=propagation_build_metric_table(s,r,sim);
[status,~,keypass]=propagation_evaluate_metrics(T);
verifyEqual(testCase,T.Value(1),1); verifyTrue(testCase,isnan(T.Value(2)));
verifyEqual(testCase,status,"不通过"); verifyFalse(testCase,keypass);
end

function testZeroReferenceEnergy(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref;
r.pressure(:)=0;
T=propagation_build_metric_table(s,r,r);
[status,~]=propagation_evaluate_metrics(T);
verifyEqual(testCase,status,"不可判定"); verifyTrue(testCase,isnan(T.Value(5)));
end

function testGridAndFrequencyMismatch(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref; sim=r;
sim.freq_hz=501;
verifyError(testCase,@() propagation_build_metric_table(s,r,sim),'propagation:ComparisonGrid');
sim=r; sim.range_m(1)=201;
verifyError(testCase,@() propagation_build_metric_table(s,r,sim),'propagation:ComparisonGrid');
end

function testDisabledFrequencyResponse(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref;
T=propagation_build_metric_table(s,r,r); T.Value(4)=1e8;
[status,score]=propagation_evaluate_metrics(T);
verifyEqual(testCase,status,"通过"); verifyEqual(testCase,score,0,'AbsTol',1e-14);
s.validation.enable_frequency_response=true;
verifyError(testCase,@() propagation_build_metric_table(s,r,r),'propagation:FrequencyResponseDisabled');
end

function testInvalidFieldNotSilentlyDropped(testCase)
s=testCase.TestData.scene; r=testCase.TestData.ref; sim=r; sim.pressure(1)=NaN;
verifyError(testCase,@() propagation_build_metric_table(s,r,sim),'propagation:Field');
end

function r=fixture()
r.freq_hz=500; r.source_depth_m=40;
r.receiver_depth_m=[20;40]; r.range_m=[200;400];
r.pressure=[1+1i,2;3,4-1i]; r.valid_mask=true(2,2);
r.arrivals=repmat({arrival([1;1.1])},2,2); r.H=[];
end

function a=arrival(delays)
a.delay_s=delays(:); a.amplitude=ones(numel(delays),1);
a.top_bounces=zeros(numel(delays),1); a.bottom_bounces=zeros(numel(delays),1);
end
