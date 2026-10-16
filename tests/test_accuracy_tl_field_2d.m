function tests=test_accuracy_tl_field_2d
%TEST_ACCURACY_TL_FIELD_2D Basic input checks independent of Bellhop.
% Successful rendering through plotshd requires real .shd outputs; exercise
% that integration through run_accuracy_validation on a MATLAB workstation.
tests=functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
end

function testMatchingGridRequired(tc)
[ref,sim]=demo_fields();
sim.range_m(2)=sim.range_m(2)+1;
verifyError(tc,@() propagation_accuracy_plot_tl_field_2d( ...
    ref,sim,tempdir,tempdir),'propagation:TLFieldGrid');
end

function testMatrixDimensionsRequired(tc)
[ref,sim]=demo_fields();
sim.tl_db=sim.tl_db(:,1:end-1);
verifyError(tc,@() propagation_accuracy_plot_tl_field_2d( ...
    ref,sim,tempdir,tempdir),'propagation:TLFieldShape');
end

function testFiniteFieldRequired(tc)
[ref,sim]=demo_fields();
ref.valid_mask(:)=false;
sim.valid_mask(:)=false;
verifyError(tc,@() propagation_accuracy_plot_tl_field_2d( ...
    ref,sim,tempdir,tempdir),'propagation:TLFieldEmpty');
end

function testShadeOutputsRequired(tc)
[ref,sim]=demo_fields();
verifyError(tc,@() propagation_accuracy_plot_tl_field_2d( ...
    ref,sim,tempdir,tempdir),'propagation:TLFieldShade');
end

function [ref,sim]=demo_fields()
ref.range_m=(0:1000:5000).';
ref.receiver_depth_m=[100;500;1000;2000];
[R,Z]=meshgrid(ref.range_m,ref.receiver_depth_m);
ref.tl_db=60+R/1500+Z/180;
ref.valid_mask=true(size(ref.tl_db));
sim=ref;
sim.tl_db=ref.tl_db+2*sin(R/3000);
end
