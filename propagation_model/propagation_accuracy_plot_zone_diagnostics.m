function propagation_accuracy_plot_zone_diagnostics(evaluation,outdir)
%PROPAGATION_ACCURACY_PLOT_ZONE_DIAGNOSTICS Plot the SAME zones used in scoring.
% For each region type:
%  top: reference raw/smoothed TL, detected centers and fixed-3dB intervals
%  mid: simulation raw/smoothed TL, detected centers and intervals
%  bot: reference gates, center correspondence and unmatched detections
d=evaluation.zone_diagnostics;
if ~isfield(d,'available') || ~d.available, return; end
render_group(d.reference,d.simulation,'convergence', ...
    d.convergence_pairs,'Convergence zones', ...
    fullfile(outdir,'propagation_accuracy_convergence_zones.png'));
render_group(d.reference,d.simulation,'shadow', ...
    d.shadow_pairs,'Shadow zones', ...
    fullfile(outdir,'propagation_accuracy_shadow_zones.png'));
end

function render_group(ref,sim,field,pairs,heading,filename)
zr=ref.(field); zs=sim.(field);
fig=figure('Visible','off','Color','w','Position',[80 60 1250 900]);
cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
ax1=subplot(3,1,1);
plot_one_field(ref,zr,field,[0.11 0.44 0.78],'Reference (mock)');
ax2=subplot(3,1,2);
plot_one_field(sim,zs,field,[0.91 0.38 0.12],'Simulation (mock)');
ax3=subplot(3,1,3);
plot_links(ref.range_m,zr,zs,pairs,heading);
% Consistent distance and TL axes make comparisons directly visual.
linkaxes([ax1 ax2 ax3],'x');
if ~isempty(ref.range_m)
    xlim(ax1,[ref.range_m(1),ref.range_m(end)]/1000);
end
if ~isempty([ref.tl_db(:);sim.tl_db(:)])
    lo=min([ref.tl_db(:);sim.tl_db(:)]);
    hi=max([ref.tl_db(:);sim.tl_db(:)]);
    if hi>lo
        pad=max(1,0.05*(hi-lo));
        ylim(ax1,[lo-pad hi+pad]); ylim(ax2,[lo-pad hi+pad]);
    end
end
print(fig,filename,'-dpng','-r150');
end

function plot_one_field(feature,zones,field,color,side)
x=feature.range_m(:)/1000;
raw=feature.tl_db(:);
smooth_tl=feature.smoothed_tl_db(:);
hraw=plot(x,raw,'Color',[0.73 0.73 0.73],'LineWidth',0.75);
hold on;
hsmooth=plot(x,smooth_tl,'-','Color',color,'LineWidth',1.7);
is_convergence=strcmp(field,'convergence');
for k=1:numel(zones)
    z=zones(k);
    peak=interp1(feature.range_m(:),smooth_tl,z.center_m,'linear');
    if is_convergence
        level=peak+3; marker='v'; label_offset=-0.03;
    else
        level=peak-3; marker='^'; label_offset=0.03;
    end
    if isfinite(z.left_m) && isfinite(z.right_m)
        % Fixed 3 dB threshold crossing positions returned by the detector.
        plot([z.left_m z.right_m]/1000,[level level],'-', ...
            'Color',color,'LineWidth',3,'HandleVisibility','off');
        plot([z.left_m z.right_m]/1000,[level level],'o', ...
            'Color',color,'MarkerSize',4,'HandleVisibility','off');
    end
    plot(z.center_m/1000,peak,marker,'MarkerSize',7, ...
        'MarkerFaceColor',color,'MarkerEdgeColor',color, ...
        'HandleVisibility','off');
    if z.truncated
        tag=sprintf('#%d (boundary missing)',k);
    else
        tag=sprintf('#%d',k);
    end
    if label_offset<0
        valign='top';
    else
        valign='bottom';
    end
    text(z.center_m/1000,peak,tag,'FontSize',8,'Color',color, ...
        'VerticalAlignment',valign,'HorizontalAlignment','center');
end
xlabel('Range (km)'); ylabel('TL (dB)'); grid on;
title(sprintf('%s: %d detected; raw / smooth + 3 dB intervals', ...
    side,numel(zones)));
legend([hraw hsmooth],{'Raw TL','Smoothed TL'},'Location','best');
end

function plot_links(range_m,zr,zs,pairs,heading)
hold on;
plot([range_m(1) range_m(end)]/1000,[1 1],'-', ...
    'Color',[0.75 0.75 0.75]);
plot([range_m(1) range_m(end)]/1000,[0 0],'-', ...
    'Color',[0.75 0.75 0.75]);
for j=1:numel(zr)
    center=zr(j).center_m;
    width=zr(j).width_m;
    if ~isfinite(width), width=0; end
    tol=max(width,0.1*abs(center)); % EXACT same gate as matching
    plot(([center-tol,center+tol])/1000,[1 1],'-', ...
        'LineWidth',3,'Color',[0.72 0.84 0.96]);
    plot(center/1000,1,'o','MarkerFaceColor',[0.11 0.44 0.78], ...
        'MarkerEdgeColor',[0.11 0.44 0.78]);
    text(center/1000,1.14,sprintf('R%d',j), ...
        'FontSize',8,'HorizontalAlignment','center');
end
for j=1:numel(zs)
    center=zs(j).center_m;
    plot(center/1000,0,'o','MarkerFaceColor',[0.91 0.38 0.12], ...
        'MarkerEdgeColor',[0.91 0.38 0.12]);
    text(center/1000,-0.18,sprintf('S%d',j), ...
        'FontSize',8,'HorizontalAlignment','center');
end
for k=1:size(pairs,1)
    rr=zr(pairs(k,1)).center_m/1000;
    ss=zs(pairs(k,2)).center_m/1000;
    plot([rr ss],[1 0],'-','LineWidth',1.8,'Color',[0.12 0.60 0.30]);
end
unmatched_r=setdiff(1:numel(zr),pairs(:,1).');
unmatched_s=setdiff(1:numel(zs),pairs(:,2).');
for j=unmatched_r
    plot(zr(j).center_m/1000,1,'x','Color',[0.8 0.1 0.1], ...
        'MarkerSize',10,'LineWidth',2);
end
for j=unmatched_s
    plot(zs(j).center_m/1000,0,'x','Color',[0.8 0.1 0.1], ...
        'MarkerSize',10,'LineWidth',2);
end
ylim([-0.35,1.4]); yticks([0 1]); yticklabels({'Sim','Ref'});
xlabel('Range (km)'); grid on;
title(sprintf('%s: ref %d, sim %d, matched %d, missed %d, extra %d', ...
    heading,numel(zr),numel(zs),size(pairs,1), ...
    numel(unmatched_r),numel(unmatched_s)));
end
