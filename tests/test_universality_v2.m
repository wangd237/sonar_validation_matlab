function tests=test_universality_v2
%TEST_UNIVERSALITY_V2 Pure-MATLAB checks; no Bellhop executable required.
tests=functiontests(localfunctions);
end

function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
tc.TestData.cfg=propagation_universality_config();
end

function testFocusMasksAndMetricOrdering(tc)
cfg=tc.TestData.cfg;
verifyEqual(tc,numel(cfg.scans),7);
expected=[6,4,3,5,9,4,3];
for k=1:numel(cfg.scans)
    verifyEqual(tc,numel(cfg.scans(k).focus),10);
    verifyEqual(tc,nnz(cfg.scans(k).focus),expected(k));
end
verifyEqual(tc,cfg.scans(1).values(1),10);
verifyEqual(tc,cfg.scans(1).values(end),9200);
verifyEqual(tc,cfg.scans(4).values,[50 100 200]);
verifyTrue(tc,all(cfg.scans(4).values>=50));
end

function testScopeExcludesNonfocusMissingWithoutEditingV2(tc)
names=strings(10,1); score=100*ones(10,1);
status=repmat("准确",10,1); weights=ones(10,1);
score(5)=NaN; status(5)="未验证";
T=table(names,score,status,weights, ...
    'VariableNames',{'Metric','Score','Status','Weight'});
mask=logical([1 0 0 0 0 0 0 1 0 1]);
[s,level]=propagation_universality_focus(T,mask);
verifyEqual(tc,s,100); verifyEqual(tc,level,"准确");
[global_score,global_level]=propagation_accuracy_aggregate_scores(T);
verifyTrue(tc,isnan(global_score));
verifyEqual(tc,global_level,"未验证");
mask(5)=true;
[s,level]=propagation_universality_focus(T,mask);
verifyTrue(tc,isnan(s)); verifyEqual(tc,level,"未验证");
end

function testSampleIntervalsSplitOnFailedOrUnknownPoints(tc)
Parameter=repmat("frequency",6,1);
Unit=repmat("Hz",6,1);
Value=[10;50;100;500;1000;9200];
ValueLabel=string(Value);
FocusStatus=["不准确";"准确";"准确";"未验证";"准确";"准确"];
AccuracyStatus=["准确";"准确";"关注";"准确";"准确";"准确"];
P=table(Parameter,Unit,Value,ValueLabel,FocusStatus,AccuracyStatus);
intervals=propagation_universality_intervals(P,"focus");
verifyEqual(tc,height(intervals),2);
verifyEqual(tc,intervals.StartValue,[50;1000]);
verifyEqual(tc,intervals.EndValue,[100;9200]);
both=propagation_universality_intervals(P,"both");
verifyEqual(tc,both.StartValue,[50;1000]);
verifyEqual(tc,both.EndValue,[50;9200]);
end

function testCategoricalLevelsStayDiscrete(tc)
Parameter=repmat("bottom_type",3,1);
Unit=repmat("category",3,1);
Value=(1:3)';
ValueLabel=["mud";"sand";"rock"];
FocusStatus=repmat("准确",3,1);
AccuracyStatus=FocusStatus;
P=table(Parameter,Unit,Value,ValueLabel,FocusStatus,AccuracyStatus);
T=propagation_universality_intervals(P,"focus");
verifyEqual(tc,height(T),3);
verifyEqual(tc,T.StartValue,T.EndValue);
end

function testNoPassingSamplesReturnsTypedEmptyTable(tc)
Parameter=repmat("frequency",3,1);
Unit=repmat("Hz",3,1);
Value=[10;50;100];
ValueLabel=string(Value);
FocusStatus=["不准确";"未验证";"运行失败"];
AccuracyStatus=["准确";"准确";"准确"];
P=table(Parameter,Unit,Value,ValueLabel,FocusStatus,AccuracyStatus);
T=propagation_universality_intervals(P,"focus");
verifyEqual(tc,height(T),0);
verifyEqual(tc,width(T),6);
verifyClass(tc,T.StartValue,'double');
verifyClass(tc,T.EndValue,'double');
verifyClass(tc,T.Parameter,'string');
verifyClass(tc,T.SampleCount,'double');
empty=propagation_universality_intervals(P([],:),"focus");
verifyEqual(tc,height(empty),0);
verifyEqual(tc,empty.Properties.VariableNames,T.Properties.VariableNames);
verifyClass(tc,empty.StartValue,'double');
end

function testCategoricalFailuresDoNotMergeLevels(tc)
Parameter=repmat("ssp_type",4,1);
Unit=repmat("category",4,1);
Value=(1:4)';
ValueLabel=["mixed";"thermocline";"channel";"unknown"];
FocusStatus=["准确";"运行失败";"准确";"未验证"];
AccuracyStatus=repmat("准确",4,1);
P=table(Parameter,Unit,Value,ValueLabel,FocusStatus,AccuracyStatus);
T=propagation_universality_intervals(P,"focus");
verifyEqual(tc,T.StartValue,[1;3]);
verifyEqual(tc,T.EndValue,[1;3]);
verifyEqual(tc,T.StartLabel,["mixed";"channel"]);
verifyEqual(tc,T.SampleCount,[1;1]);
end

function testAllSevenCaseGenerators(tc)
cfg=tc.TestData.cfg;
parent=tempname; mkdir(parent);
cleanup=onCleanup(@() rmdir(parent,'s')); %#ok<NASGU>
for k=1:numel(cfg.scans)
    s=cfg.scans(k);
    for v=s.values([1 end])
        [path,depth]=propagation_universality_prepare_case(cfg,s,v,parent);
        verifyTrue(tc,isfile([path '.env']));
        verifyTrue(tc,isfile([path '.bty']));
        verifyTrue(tc,isfile([path '.ati']));
        verifyGreaterThan(tc,depth,0);
        txt=fileread([path '.env']);
        verifyNotEmpty(tc,strfind(txt,'! SSP_POINT')); %#ok<STRCL1>
        if s.key=="frequency"
            verifyNotEmpty(tc,strfind(txt,sprintf('%.12g',v))); %#ok<STRCL1>
        elseif s.key=="water_depth"
            verifyEqual(tc,depth,50);
            verifyNotEmpty(tc,strfind(txt,'! RECEIVER_DEPTH_COUNT')); %#ok<STRCL1>
            [zz,cc]=ssp(txt);
            verifyEqual(tc,zz(end),v,'AbsTol',1e-8);
            verifyTrue(tc,all(isfinite(cc)));
        elseif s.key=="receiver_depth"
            verifyEqual(tc,depth,v);
        end
    end
end
end

function [z,c]=ssp(txt)
rows=regexp(txt,'(?m)^[^\r\n]*! SSP_POINT\s*\r?$','match');
data=zeros(numel(rows),2);
for k=1:numel(rows)
    v=sscanf(rows{k},'%f');
    data(k,:)=v(1:2);
end
z=data(:,1); c=data(:,2);
end
