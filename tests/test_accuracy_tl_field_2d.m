function tests=test_accuracy_tl_field_2d
%TEST_ACCURACY_TL_FIELD_2D Figure smoke tests without Bellhop.
tests=functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
end

function testPlotSyntheticMaskedFields(tc)
[ref,sim]=demo_fields();
outdir=tempname;
mkdir(outdir);
cleanup=onCleanup(@() rmdir(outdir,'s')); %#ok<NASGU>
propagation_accuracy_plot_tl_field_2d(ref,sim,outdir);
filename=fullfile(outdir,'propagation_accuracy_tl_field_2d.png');
verifyTrue(tc,isfile(filename));
metadata=dir(filename);
verifyGreaterThan(tc,metadata.bytes,1000);
end

function testPlotIdenticalConstantFields(tc)
[ref,~]=demo_fields();
ref.tl_db(:)=70;
outdir=tempname;
mkdir(outdir);
cleanup=onCleanup(@() rmdir(outdir,'s')); %#ok<NASGU>
propagation_accuracy_plot_tl_field_2d(ref,ref,outdir);
verifyTrue(tc,isfile(fullfile(outdir, ...
    'propagation_accuracy_tl_field_2d.png')));
end

function testGridAndShapeValidation(tc)
[ref,sim]=demo_fields();
sim.range_m(2)=sim.range_m(2)+1;
verifyError(tc,@() propagation_accuracy_plot_tl_field_2d( ...
    ref,sim,tempdir),'propagation:TLFieldGrid');
sim=ref;
sim.tl_db=sim.tl_db(:,1:end-1);
verifyError(tc,@() propagation_accuracy_plot_tl_field_2d( ...
    ref,sim,tempdir),'propagation:TLFieldShape');
end

function testMissingValidField(tc)
[ref,sim]=demo_fields();
ref.valid_mask(:)=false;
sim.valid_mask(:)=false;
verifyError(tc,@() propagation_accuracy_plot_tl_field_2d( ...
    ref,sim,tempdir),'propagation:TLFieldEmpty');
end

function [ref,sim]=demo_fields()
ref.range_m=(0:1000:5000).';
ref.receiver_depth_m=[100;500;1000;2000];
[nz,nr]=deal(numel(ref.receiver_depth_m),numel(ref.range_m));
[R,Z]=meshgrid(ref.range_m,ref.receiver_depth_m);
ref.tl_db=60+R/1500+Z/180;
ref.valid_mask=true(nz,nr);
ref.valid_mask(1,2)=false; % invalid/dry cell is hidden in the plot
sim=ref;
sim.tl_db=ref.tl_db+2*sin(R/3000);
sim.valid_mask(3,4)=false;
end
