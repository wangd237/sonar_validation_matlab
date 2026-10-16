function propagation_accuracy_plot_tl_field_2d(ref,sim,outdir)
%PROPAGATION_ACCURACY_PLOT_TL_FIELD_2D 2-D TL fields and Sim-Ref difference.
% Use the Bellhop depth-by-range TL arrays directly; do not choose a depth
% slice or resample the grids. Invalid/dry cells remain transparent (gray).
% Ref and Sim share a physical TL colour range; difference is centred on 0.
assert(isequal(ref.range_m(:),sim.range_m(:)) && ...
    isequal(ref.receiver_depth_m(:),sim.receiver_depth_m(:)), ...
    'propagation:TLFieldGrid','Reference and simulation receiver grids must match.');

r=double(ref.range_m(:)); z=double(ref.receiver_depth_m(:));
assert(numel(r)>=2 && numel(z)>=2 && all(isfinite(r)) && ...
    all(isfinite(z)) && all(diff(r)>0) && all(diff(z)>0), ...
    'propagation:TLFieldGrid','A finite increasing 2-D receiver grid is required.');
expected=[numel(z),numel(r)];
assert(isequal(size(ref.tl_db),expected) && isequal(size(sim.tl_db),expected), ...
    'propagation:TLFieldShape','TL arrays must have size [depth,range].');
assert(isfield(ref,'valid_mask') && isfield(sim,'valid_mask') && ...
    isequal(size(ref.valid_mask),expected) && ...
    isequal(size(sim.valid_mask),expected), ...
    'propagation:TLFieldMask','Valid masks must have size [depth,range].');

% Mask each source independently; compare only where both have valid data.
ref_valid=logical(ref.valid_mask) & isfinite(ref.tl_db);
sim_valid=logical(sim.valid_mask) & isfinite(sim.tl_db);
both_valid=ref_valid & sim_valid;
ref_tl=double(ref.tl_db); sim_tl=double(sim.tl_db);
ref_tl(~ref_valid)=NaN;
sim_tl(~sim_valid)=NaN;
difference=sim_tl-ref_tl;
difference(~both_valid)=NaN;

all_tl=[ref_tl(ref_valid);sim_tl(sim_valid)];
assert(~isempty(all_tl),'propagation:TLFieldEmpty', ...
    'No valid TL cells are available for a 2-D plot.');
common_clim=[min(all_tl),max(all_tl)];
if common_clim(1)==common_clim(2)
    common_clim=common_clim+[-0.5 0.5];
end

valid_difference=difference(both_valid);
if isempty(valid_difference)
    % Still show the individual fields; no overlap is shown as gray.
    diff_radius=1;
else
    diff_radius=max(abs(valid_difference));
    if diff_radius==0, diff_radius=1; end
end

ensure_dir(outdir);
fig=figure('Visible','off','Color','w','Position',[100 70 1400 1050]);
cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
x=r/1000;

ax1=subplot(3,1,1);
render_field(ax1,x,z,ref_tl,ref_valid,common_clim,parula(256), ...
    'Reference TL field (Bellhop mock)','TL (dB)');

ax2=subplot(3,1,2);
render_field(ax2,x,z,sim_tl,sim_valid,common_clim,parula(256), ...
    'Simulation TL field (Bellhop mock)','TL (dB)');

ax3=subplot(3,1,3);
render_field(ax3,x,z,difference,both_valid,[-diff_radius diff_radius], ...
    diverging_colormap(256), ...
    'TL difference (Simulation - Reference)','Difference (dB)');

% No receiver-depth overlay in this iteration.
linkaxes([ax1 ax2 ax3],'xy');
saveas(fig,fullfile(outdir,'propagation_accuracy_tl_field_2d.png'));
end

function render_field(ax,x,z,tl,valid,limits,map,heading,bar_label)
h=imagesc(ax,x,z,tl);
set(h,'AlphaData',double(valid));
set(ax,'YDir','reverse','Color',[0.89 0.89 0.89]);
axis(ax,'tight');
colormap(ax,map);
caxis(ax,limits);
cb=colorbar(ax);
ylabel(cb,bar_label);
xlabel(ax,'Range (km)');
ylabel(ax,'Depth (m)');
title(ax,heading);
end

function map=diverging_colormap(n)
% Blue = negative error, white = zero, red = positive error.
v=linspace(0,1,n).';
anchors=[0 0.5 1];
map=[interp1(anchors,[0.18 1 0.75],v), ...
     interp1(anchors,[0.35 1 0.16],v), ...
     interp1(anchors,[0.77 1 0.18],v)];
end
