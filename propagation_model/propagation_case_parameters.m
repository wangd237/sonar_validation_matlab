function p = propagation_case_parameters(case_root)
%PROPAGATION_CASE_PARAMETERS Read scalar traceability coordinates from inputs.
text=fileread([case_root '.env']);
p.freq_hz=scalar_tag(text,'FREQUENCY_HZ');
p.source_depth_m=scalar_tag(text,'SOURCE_DEPTH_M');
p.receiver_range_km=pair_tag(text,'RECEIVER_RANGES_KM',2);
depths=pair_values(text,'RECEIVER_DEPTHS_M'); p.receiver_depth_m=mean(depths(1:2));
ssp=tag_rows(text,'SSP_POINT'); p.ssp_mean_mps=mean(ssp(:,2));
bottom=tag_rows(text,'BOTTOM_PROPERTIES');
assert(size(bottom,1)==1 && size(bottom,2)>=4,'propagation:CasePatch','Invalid bottom property tag.');
p.bottom_sound_speed_mps=bottom(1,2); p.bottom_density_g_cm3=bottom(1,4);
p.water_depth_m=mean_boundary_depth([case_root '.bty']);
end

function value=scalar_tag(text,tag)
rows=tag_rows(text,tag); assert(numel(rows)==1,'propagation:CasePatch','Invalid scalar tag: %s',tag); value=rows(1);
end

function value=pair_tag(text,tag,column)
row=pair_values(text,tag); assert(numel(row)>=column,'propagation:CasePatch','Invalid pair tag: %s',tag); value=row(column);
end

function row=pair_values(text,tag)
rows=tag_rows(text,tag); assert(size(rows,1)==1,'propagation:CasePatch','Invalid pair tag: %s',tag); row=rows(1,:);
end

function rows=tag_rows(text,tag)
lines=regexp(text,['(?m)^[^\r\n]*!\s*' tag '\s*\r?$'],'match');
assert(~isempty(lines),'propagation:CasePatch','Missing traceability tag: %s',tag);
cells=cell(size(lines)); width=0;
for k=1:numel(lines)
    body=regexprep(lines{k},'!.*$','');
    tok=regexp(body,'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eEdD][-+]?\d+)?','match');
    cells{k}=cellfun(@(x) str2double(regexprep(x,'[dD]','e')),tok); width=max(width,numel(cells{k}));
end
assert(all(cellfun(@numel,cells)==width),'propagation:CasePatch','Inconsistent tagged rows: %s',tag);
rows=vertcat(cells{:});
end

function value=mean_boundary_depth(filename)
lines=regexp(fileread(filename),'\r\n|\n|\r','split');
assert(numel(lines)>=4 && strcmp(strtrim(lines{1}),'''L'''),'propagation:BoundaryFormat','Expected L boundary.');
n=str2double(strtrim(lines{2})); depths=zeros(n,1);
for k=1:n
    v=sscanf(lines{k+2},'%f'); assert(numel(v)>=2,'propagation:BoundaryFormat','Invalid boundary point.'); depths(k)=v(2);
end
value=mean(depths);
end
