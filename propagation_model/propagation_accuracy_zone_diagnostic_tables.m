function [detections, matches]=propagation_accuracy_zone_diagnostic_tables(evaluation)
%PROPAGATION_ACCURACY_ZONE_DIAGNOSTIC_TABLES Export exactly the zones used by V2.
% Rows describe both detected and unmatched regions. A separate match table
% records which ref/sim features were compared; NaN means not measurable.
d=evaluation.zone_diagnostics;
assert(d.available,'propagation:ZoneDiagnostics','Zone extraction was not available.');

kind=strings(0,1); dataset=strings(0,1);
zone_index=zeros(0,1); center_m=zeros(0,1);
left_m=zeros(0,1); right_m=zeros(0,1); width_m=zeros(0,1);
prominence_db=zeros(0,1); truncated=false(0,1);
matched_zone_index=zeros(0,1); match_tolerance_m=zeros(0,1);
match_status=strings(0,1);

pair_kind=strings(0,1); ref_index=zeros(0,1); sim_index=zeros(0,1);
ref_center_m=zeros(0,1); sim_center_m=zeros(0,1);
center_error_m=zeros(0,1); gate_m=zeros(0,1);
ref_width_m=zeros(0,1); sim_width_m=zeros(0,1); width_error_m=zeros(0,1);

groups={'convergence','shadow'};
labels=["Convergence","Shadow"];
for g=1:2
    field=groups{g}; label=labels(g);
    zr=d.reference.(field);
    zs=d.simulation.(field);
    if g==1, pairs=d.convergence_pairs; else, pairs=d.shadow_pairs; end
    for side=1:2
        if side==1, z=zr; side_name="Ref"; else, z=zs; side_name="Sim"; end
        for j=1:numel(z)
            kind(end+1,1)=label; %#ok<AGROW>
            dataset(end+1,1)=side_name; %#ok<AGROW>
            zone_index(end+1,1)=j; %#ok<AGROW>
            center_m(end+1,1)=z(j).center_m; %#ok<AGROW>
            left_m(end+1,1)=z(j).left_m; %#ok<AGROW>
            right_m(end+1,1)=z(j).right_m; %#ok<AGROW>
            width_m(end+1,1)=z(j).width_m; %#ok<AGROW>
            prominence_db(end+1,1)=z(j).prominence_db; %#ok<AGROW>
            truncated(end+1,1)=z(j).truncated; %#ok<AGROW>
            other=NaN; tol=NaN; state="Unmatched";
            if side==1
                tol=reference_gate(z(j));
                row=find(pairs(:,1)==j,1);
                if ~isempty(row), other=pairs(row,2); state="Matched"; end
            else
                row=find(pairs(:,2)==j,1);
                if ~isempty(row), other=pairs(row,1); state="Matched"; end
            end
            matched_zone_index(end+1,1)=other; %#ok<AGROW>
            match_tolerance_m(end+1,1)=tol; %#ok<AGROW>
            match_status(end+1,1)=state; %#ok<AGROW>
        end
    end
    for k=1:size(pairs,1)
        r=zr(pairs(k,1)); s=zs(pairs(k,2));
        pair_kind(end+1,1)=label; %#ok<AGROW>
        ref_index(end+1,1)=pairs(k,1); %#ok<AGROW>
        sim_index(end+1,1)=pairs(k,2); %#ok<AGROW>
        ref_center_m(end+1,1)=r.center_m; %#ok<AGROW>
        sim_center_m(end+1,1)=s.center_m; %#ok<AGROW>
        center_error_m(end+1,1)=abs(s.center_m-r.center_m); %#ok<AGROW>
        gate_m(end+1,1)=reference_gate(r); %#ok<AGROW>
        ref_width_m(end+1,1)=r.width_m; %#ok<AGROW>
        sim_width_m(end+1,1)=s.width_m; %#ok<AGROW>
        width_error_m(end+1,1)=abs(s.width_m-r.width_m); %#ok<AGROW>
    end
end

detections=table(kind,dataset,zone_index,center_m,left_m,right_m, ...
    width_m,prominence_db,truncated,matched_zone_index, ...
    match_tolerance_m,match_status,'VariableNames', ...
    {'ZoneType','Dataset','ZoneIndex','Center_m','Left_m','Right_m', ...
    'Width_m','Prominence_dB','Truncated','MatchedZoneIndex', ...
    'MatchTolerance_m','MatchStatus'});
matches=table(pair_kind,ref_index,sim_index,ref_center_m,sim_center_m, ...
    center_error_m,gate_m,ref_width_m,sim_width_m,width_error_m, ...
    'VariableNames',{'ZoneType','RefIndex','SimIndex','RefCenter_m', ...
    'SimCenter_m','CenterError_m','Tolerance_m','RefWidth_m', ...
    'SimWidth_m','WidthError_m'});
end

function tolerance=reference_gate(region)
w=region.width_m;
if ~isfinite(w), w=0; end
tolerance=max(w,0.1*abs(region.center_m));
end
