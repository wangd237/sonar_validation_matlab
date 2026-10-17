function propagation_accuracy_plot_arrivals(evaluation,outdir)
%PROPAGATION_ACCURACY_PLOT_ARRIVALS Compact view of scored multipath arrivals.
d=evaluation.arrival_diagnostics;
if ~isfield(d,'available') || ~d.available, return; end
a=d.reference; b=d.simulation; m=d.match;
ri=m.reference_indices(:); si=m.simulation_indices(:); pairs=m.pairs;
if isempty(ri) && isempty(si), return; end

fig=figure('Visible','off','Color','w','Position',[100 100 1250 520]);
cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
ax=axes(fig); hold(ax,'on');
for k=1:size(pairs,1)
    plot(ax,[a.delay_s(pairs(k,1)),b.delay_s(pairs(k,2))],[1 0],'-', ...
        'Color',[0.20 0.65 0.35],'LineWidth',1.2,'HandleVisibility','off');
end

peak=max([abs(a.amplitude(ri));abs(b.amplitude(si));eps]);
ref_size=35+75*sqrt(abs(a.amplitude(ri))/peak);
sim_size=35+75*sqrt(abs(b.amplitude(si))/peak);
hRef=scatter(ax,a.delay_s(ri),ones(size(ri)),ref_size,[0.11 0.44 0.78], ...
    'filled','DisplayName','Reference arrivals');
hSim=scatter(ax,b.delay_s(si),zeros(size(si)),sim_size,[0.91 0.38 0.12], ...
    'filled','DisplayName','Simulation arrivals');

unmatched_ref=setdiff(ri,pairs(:,1),'stable');
unmatched_sim=setdiff(si,pairs(:,2),'stable');
if ~isempty(unmatched_ref)
    plot(ax,a.delay_s(unmatched_ref),ones(size(unmatched_ref)),'rx', ...
        'MarkerSize',11,'LineWidth',2,'HandleVisibility','off');
end
if ~isempty(unmatched_sim)
    plot(ax,b.delay_s(unmatched_sim),zeros(size(unmatched_sim)),'rx', ...
        'MarkerSize',11,'LineWidth',2,'HandleVisibility','off');
end
if ~isempty(ri)
    [~,k]=max(a.delay_s(ri));
    plot(ax,a.delay_s(ri(k)),1,'ks','MarkerSize',12,'LineWidth',1.5, ...
        'HandleVisibility','off');
end
if ~isempty(si)
    [~,k]=max(b.delay_s(si));
    plot(ax,b.delay_s(si(k)),0,'ks','MarkerSize',12,'LineWidth',1.5, ...
        'HandleVisibility','off');
end

arrival_ms=scalar_detail(evaluation.detail{8},'rmse_s');
adjacent_ms=scalar_detail(evaluation.detail{9},'rmse_s');
last_ms=scalar_detail(evaluation.detail{10},'absolute_error_s');
title(ax,sprintf(['Multipath arrivals: matched %d | ref %d | sim %d | ' ...
    'delay RMSE %.3f ms | adjacent RMSE %.3f ms | last %.3f ms'], ...
    m.matched_count,m.reference_count,m.simulation_count, ...
    1000*arrival_ms,1000*adjacent_ms,1000*last_ms));
xlabel(ax,'Corrected arrival time (s)');
yticks(ax,[0 1]); yticklabels(ax,{'Simulation','Reference'});
ylim(ax,[-0.35 1.35]); grid(ax,'on');
legend(ax,[hRef hSim],'Location','best');
print(fig,fullfile(outdir,'propagation_accuracy_multipath_arrivals.png'), ...
    '-dpng','-r150');
end

function value=scalar_detail(detail,field)
value=NaN;
if isstruct(detail) && isfield(detail,field), value=detail.(field); end
end
