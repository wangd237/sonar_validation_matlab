function propagation_accuracy_plot_tl_field_2d(ref,sim,outdir,toolbox_dir)
%PROPAGATION_ACCURACY_PLOT_TL_FIELD_2D Use Acoustic Toolbox plotshd for TL.
% Ref/Sim are plotted directly from the Bellhop .shd outputs via plotshd.
% Only their difference needs a small custom plot; scores are unchanged.
assert(isequal(ref.range_m(:),sim.range_m(:)) && ...
    isequal(ref.receiver_depth_m(:),sim.receiver_depth_m(:)), ...
    'propagation:TLFieldGrid','Reference and simulation receiver grids must match.');

r=ref.range_m(:)/1000;
z=ref.receiver_depth_m(:);
shape=[numel(z),numel(r)];
assert(isequal(size(ref.tl_db),shape) && isequal(size(sim.tl_db),shape), ...
    'propagation:TLFieldShape','TL fields must be [receiver depth, range].');
assert(isfield(ref,'valid_mask') && isfield(sim,'valid_mask') && ...
    isequal(size(ref.valid_mask),shape) && isequal(size(sim.valid_mask),shape), ...
    'propagation:TLFieldMask','Invalid TL valid_mask dimensions.');

valid_ref=logical(ref.valid_mask) & isfinite(ref.tl_db);
valid_sim=logical(sim.valid_mask) & isfinite(sim.tl_db);
both=valid_ref & valid_sim;
values=[ref.tl_db(valid_ref);sim.tl_db(valid_sim)];
assert(~isempty(values),'propagation:TLFieldEmpty','No finite TL cells.');
limits=[min(values),max(values)];
if limits(1)==limits(2), limits=limits+[-0.5,0.5]; end

% The runner writes coherent .shd at a fixed internal name in run_dir.
assert(isfield(ref,'meta') && isfield(sim,'meta') && ...
    isfield(ref.meta,'run_dir') && isfield(sim.meta,'run_dir'), ...
    'propagation:TLFieldShade','Bellhop .shd run directories are required.');
ref_file=fullfile(ref.meta.run_dir,'case_C.shd');
sim_file=fullfile(sim.meta.run_dir,'case_C.shd');
assert(isfile(ref_file) && isfile(sim_file), ...
    'propagation:TLFieldShade','Bellhop .shd outputs are missing.');

plot_dir=fullfile(toolbox_dir,'Plot');
read_dir=fullfile(toolbox_dir,'ReadWrite');
assert(isfile(fullfile(plot_dir,'plotshd.m')) && ...
    isfile(fullfile(read_dir,'read_shd.m')), ...
    'propagation:TLFieldToolbox','Acoustic Toolbox plotshd/read_shd not found.');
oldpath=path;
global units
oldunits=units;
restore=onCleanup(@() restore_toolbox_context(oldpath,oldunits)); %#ok<NASGU>
addpath(plot_dir,read_dir,'-begin');
units='km';

ensure_dir(outdir);
fig=figure('Visible','off','Color','w','Position',[80 80 1300 950]);
cleanup=onCleanup(@() close(fig)); %#ok<NASGU>

% Native Acoustic Toolbox visualization of the two .shd files.
subplot(3,1,1);
plotshd(ref_file);
title('Reference TL');
caxis(limits);
subplot(3,1,2);
plotshd(sim_file);
title('Simulation TL');
caxis(limits);

% plotshd plots one .shd file; it does not natively plot Sim - Ref.
ax=subplot(3,1,3);
d=double(sim.tl_db)-double(ref.tl_db);
d(~both)=NaN;
h=imagesc(ax,r,z,d);
set(h,'AlphaData',double(both));
set(ax,'YDir','reverse','Color',[0.88 0.88 0.88]);
valid_diff=d(both);
scale=1;
if ~isempty(valid_diff), scale=max(1e-6,max(abs(valid_diff))); end
caxis(ax,[-scale,scale]);
colorbar(ax);
xlabel(ax,'Range (km)');
ylabel(ax,'Depth (m)');
title(ax,'TL difference (Simulation - Reference)');
saveas(fig,fullfile(outdir,'propagation_accuracy_tl_field_2d.png'));
end

function restore_toolbox_context(oldpath,oldunits)
global units
units=oldunits;
path(oldpath);
end
