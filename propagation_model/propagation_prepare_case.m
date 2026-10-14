function case_root = propagation_prepare_case(source_root,parent_dir,changes)
%PROPAGATION_PREPARE_CASE Copy a triplet and intervene on tagged parameters.
ensure_dir(parent_dir);
folder=tempname(parent_dir); ensure_dir(folder);
case_root=fullfile(folder,'case');
for ext={'.env','.bty','.ati'}
    assert(isfile([source_root ext{1}]),'propagation:MissingInput','Missing %s',[source_root ext{1}]);
    copyfile([source_root ext{1}],[case_root ext{1}]);
end
text=fileread([case_root '.env']);
fields=fieldnames(changes);
for k=1:numel(fields)
    field=fields{k}; value=changes.(field);
    assert(isscalar(value) && isfinite(value),'propagation:CasePatch','Patch values must be finite scalars.');
    switch field
        case 'freq_hz'
            assert(value>0,'Frequency must be positive.');
            text=replace_scalar_tag(text,'FREQUENCY_HZ',value,'');
        case 'source_depth_m'
            assert(value>0,'Source depth must be positive.');
            text=replace_scalar_tag(text,'SOURCE_DEPTH_M',value,' /');
        case 'receiver_range_km'
            assert(value>0,'Receiver range must be positive.');
            text=replace_pair_target(text,'RECEIVER_RANGES_KM',value,'upper');
            extend_boundary([case_root '.bty'],value);
            extend_boundary([case_root '.ati'],value);
        case 'receiver_depth_m'
            assert(value>0,'Receiver depth must be positive.');
            text=replace_pair_target(text,'RECEIVER_DEPTHS_M',value,'midpoint');
        case 'ssp_mean_mps'
            assert(value>0,'Sound speed must be positive.');
            text=shift_tagged_column(text,'SSP_POINT',2,value);
        case 'bottom_sound_speed_mps'
            assert(value>0,'Bottom sound speed must be positive.');
            text=replace_tagged_column(text,'BOTTOM_PROPERTIES',2,value);
        case 'bottom_density_g_cm3'
            assert(value>0,'Bottom density must be positive.');
            text=replace_tagged_column(text,'BOTTOM_PROPERTIES',4,value);
        case 'water_depth_m'
            assert(value>0,'Water depth must be positive.');
            maximum_depth=patch_bathymetry([case_root '.bty'],value);
            text=synchronize_vertical_environment(text,maximum_depth);
        otherwise
            error('propagation:CasePatch','Unsupported case patch: %s',field);
    end
end
write_text([case_root '.env'],text);
end

function text=replace_scalar_tag(text,tag,value,suffix)
pattern=['(?m)^[^\r\n]*!\s*' tag '\s*\r?$'];
assert(numel(regexp(text,pattern))==1,'propagation:CasePatch','Need exactly one ! %s tag in ENV.',tag);
text=regexprep(text,pattern,sprintf('%.12g%s ! %s',value,suffix,tag),'once');
end

function text=replace_pair_target(text,tag,target,mode)
[line,values]=tagged_line(text,tag);
assert(numel(values)>=2,'propagation:CasePatch','Tag %s needs two values.',tag);
switch mode
    case 'upper'
        values(2)=target;
        assert(values(2)>values(1),'propagation:CasePatch','Receiver range maximum must exceed minimum.');
    case 'midpoint'
        halfspan=(values(2)-values(1))/2;
        values(1:2)=[target-halfspan,target+halfspan];
        assert(values(1)>0,'propagation:CasePatch','Receiver-depth intervention leaves the water column.');
end
text=replace_line(text,line,sprintf('%.12g %.12g / ! %s',values(1),values(2),tag));
end

function text=shift_tagged_column(text,tag,column,target_mean)
[lines,values]=tagged_lines(text,tag);
current=cellfun(@(x) x(column),values); delta=target_mean-mean(current);
for k=numel(lines):-1:1
    row=values{k}; row(column)=row(column)+delta;
    assert(row(column)>0,'propagation:CasePatch','Intervention produced a non-positive value.');
    text=replace_line(text,lines{k},format_row(row,tag));
end
end

function text=replace_tagged_column(text,tag,column,target)
[line,values]=tagged_line(text,tag);
assert(numel(values)>=column,'propagation:CasePatch','Tag %s lacks column %d.',tag,column);
values(column)=target; text=replace_line(text,line,format_row(values,tag));
end

function [line,values]=tagged_line(text,tag)
[lines,all_values]=tagged_lines(text,tag);
assert(numel(lines)==1,'propagation:CasePatch','Need exactly one ! %s tag in ENV.',tag);
line=lines{1}; values=all_values{1};
end

function [lines,values]=tagged_lines(text,tag)
pattern=['(?m)^[^\r\n]*!\s*' tag '\s*\r?$'];
lines=regexp(text,pattern,'match');
assert(~isempty(lines),'propagation:CasePatch','Missing ! %s tag in ENV.',tag);
values=cell(size(lines));
for k=1:numel(lines)
    body=regexprep(lines{k},'!.*$','');
    tok=regexp(body,'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eEdD][-+]?\d+)?','match');
    values{k}=cellfun(@(x) str2double(regexprep(x,'[dD]','e')),tok);
end
end

function text=replace_line(text,line,replacement)
text=strrep(text,line,replacement);
end

function line=format_row(values,tag)
parts=arrayfun(@(x) sprintf('%.12g',x),values,'UniformOutput',false);
line=[strjoin(parts,' ') ' / ! ' tag];
end

function line=format_plain_row(values,tag)
parts=arrayfun(@(x) sprintf('%.12g',x),values,'UniformOutput',false);
line=[strjoin(parts,' ') ' ! ' tag];
end

function maximum_depth=patch_bathymetry(filename,target_mean)
lines=regexp(fileread(filename),'\r\n|\n|\r','split');
assert(numel(lines)>=4 && strcmp(strtrim(lines{1}),'''L'''), ...
    'propagation:BoundaryFormat','Traceability water-depth patch requires an L boundary.');
n=str2double(strtrim(lines{2}));
assert(isfinite(n) && n>=2 && numel(lines)>=n+2,'propagation:BoundaryFormat','Invalid BTY file.');
data=zeros(n,2);
for k=1:n
    values=sscanf(lines{k+2},'%f');
    assert(numel(values)>=2,'propagation:BoundaryFormat','Invalid BTY coordinate.');
    data(k,:)=values(1:2).';
end
data(:,2)=data(:,2)+(target_mean-mean(data(:,2)));
assert(all(data(:,2)>0),'propagation:CasePatch','Water-depth intervention produced a non-positive bottom.');
maximum_depth=max(data(:,2));
for k=1:n, lines{k+2}=sprintf('%.12g %.12g',data(k,1),data(k,2)); end
write_text(filename,strjoin(lines,newline));
end

function text=synchronize_vertical_environment(text,maximum_depth)
% Only an explicit water-depth intervention reaches this function. Updating
% ENV coverage is consistency maintenance, not another parameter change.
[header_line,header]=tagged_line(text,'SSP_HEADER');
assert(numel(header)>=3,'propagation:CasePatch','SSP_HEADER needs mesh, roughness and depth.');
header(3)=maximum_depth;
text=replace_line(text,header_line,format_plain_row(header,'SSP_HEADER'));

[ssp_lines,ssp_values]=tagged_lines(text,'SSP_POINT');
ssp_depths=cellfun(@(x) x(1),ssp_values);
[~,last_idx]=max(ssp_depths);
interior_depths=ssp_depths; interior_depths(last_idx)=[];
assert(isempty(interior_depths) || maximum_depth>max(interior_depths), ...
    'propagation:CasePatch','Water-depth intervention would cross an interior SSP node.');
last_row=ssp_values{last_idx}; last_row(1)=maximum_depth;
text=replace_line(text,ssp_lines{last_idx},format_row(last_row,'SSP_POINT'));

text=replace_tagged_column(text,'BOTTOM_PROPERTIES',1,maximum_depth);
[ray_line,ray_box]=tagged_line(text,'RAY_BOX');
assert(numel(ray_box)>=3,'propagation:CasePatch','RAY_BOX needs step, zBox and rBox.');
if ray_box(2)<=maximum_depth
    ray_box(2)=maximum_depth+max(10,0.05*maximum_depth);
    text=replace_line(text,ray_line,format_plain_row(ray_box,'RAY_BOX'));
end
end

function extend_boundary(filename,target_range_km)
lines=regexp(fileread(filename),'\r\n|\n|\r','split');
assert(numel(lines)>=4 && strcmp(strtrim(lines{1}),'''L'''), ...
    'propagation:BoundaryFormat','Range intervention requires L boundaries.');
n=str2double(strtrim(lines{2}));
last=sscanf(lines{n+2},'%f');
assert(numel(last)>=2,'propagation:BoundaryFormat','Invalid final boundary point.');
if target_range_km>last(1)
    lines{2}=sprintf('%d',n+1);
    lines=[lines(1:n+2),{sprintf('%.12g %.12g',target_range_km,last(2))},lines(n+3:end)]; %#ok<AGROW>
    write_text(filename,strjoin(lines,newline));
end
end

function write_text(filename,content)
fid=fopen(filename,'w'); assert(fid>=0,'Cannot write prepared input: %s',filename);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',content);
end
