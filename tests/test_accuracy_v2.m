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
verifyEqual(tc,numel(f.shadow),0); % A flat broad shoulder is not a true shadow peak.
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

function testInvalidInputAndWeights(tc)
cfg=tc.TestData.cfg;
cfg.weights(1)=-1;
verifyError(tc,@() propagation_accuracy_v2(struct(),struct(),cfg), ...
    'propagation:AccuracyWeights');
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
