function [case_root,evaluation_depth_m] = propagation_universality_prepare_case(cfg,item,value,parent_dir)
%PROPAGATION_UNIVERSALITY_PREPARE_CASE Single physically shared input for Ref/Mock.
% Requires the annotated Bellhop triplet under cases/universality/baseline.
changes=struct();
key=string(item.key);
evaluation_depth_m=item.evaluation_depth_m;
switch key
    case "frequency", changes.freq_hz=value;
    case "source_depth", changes.source_depth_m=value;
    case "range", changes.receiver_range_km=value;
    case "water_depth"
        % Keep the source AND scored receiver at 50 m for the entire
        % water-depth family. A 500-m source is invalid in 200-m water.
        changes.source_depth_m=cfg.water_family_source_depth_m;
    case "receiver_depth"
        evaluation_depth_m=value; % select a native RD row, NOT a second physical field
    case {"ssp_type","bottom_type"}
        % The categorical level is applied after copying the same baseline.
    otherwise
        error('propagation:UniversalityParameter','Unsupported parameter: %s',key);
end
case_root=propagation_prepare_case(cfg.base_root,parent_dir,changes);
env_file=[case_root '.env'];
switch key
    case "water_depth"
        apply_water_depth(env_file,[case_root '.bty'],value);
    case "ssp_type"
        apply_ssp(env_file,value);
    case "bottom_type"
        apply_bottom(env_file,cfg.bottom_properties(value,:));
end
end

function apply_water_depth(env_file,bty_file,depth)
assert(depth>=100 && depth<=5000,'propagation:UniversalityWaterDepth','Unsupported water depth.');
lines=splitlines(string(fileread(env_file)));
[z,c,first,last]=read_ssp(lines);
assert(depth<=max(z),'propagation:UniversalityWaterDepth','Water depth exceeds SSP coverage.');
keep=z<depth;
zz=[z(keep);depth]; cc=[c(keep);interp1(z,c,depth,'linear')];
new_ssp=arrayfun(@(k) sprintf('%.12g %.12g / ! SSP_POINT',zz(k),cc(k)), ...
    1:numel(zz),'UniformOutput',false);
lines=[lines(1:first-1);string(new_ssp(:));lines(last+1:end)];
lines=replace_row(lines,"SSP_HEADER",3,depth);
lines=replace_row(lines,"BOTTOM_PROPERTIES",1,depth);
% 50 m spacing makes the water-column samples and the 50-m score point explicit.
zmax=depth-50;
nrd=round(zmax/50)+1;
lines=replace_row(lines,"RECEIVER_DEPTH_COUNT",1,nrd);
lines=replace_row(lines,"RECEIVER_DEPTHS_M",1,0);
lines=replace_row(lines,"RECEIVER_DEPTHS_M",2,zmax);
write_text(env_file,join(lines,newline));
bty=splitlines(string(fileread(bty_file)));
n=str2double(bty(2));
assert(isfinite(n)&&n>=2&&numel(bty)>=n+2, ...
    'propagation:UniversalityBoundary','Invalid bathymetry.');
for k=3:n+2
    v=sscanf(bty(k),'%f');
    assert(numel(v)>=2,'propagation:UniversalityBoundary','Invalid BTY point.');
    bty(k)=sprintf('%.12g %.12g',v(1),depth);
end
write_text(bty_file,join(bty,newline));
end

function apply_ssp(env_file,kind)
lines=splitlines(string(fileread(env_file)));
[z,~,first,last]=read_ssp(lines);
switch kind
    case 1 % mixed-layer-dominated illustrative type
        zz=[0 200 500 1400 5000];
        cc=[1535 1535 1532 1520 1545];
    case 2 % pronounced thermocline illustrative type
        zz=[0 100 500 1400 5000];
        cc=[1545 1540 1505 1498 1545];
    case 3 % original Munk-like deep sound channel
        return;
    otherwise
        error('propagation:UniversalitySSP','Unknown SSP category.');
end
assert(max(z)<=max(zz),'propagation:UniversalitySSP','SSP exceeds profile template.');
v=interp1(zz,cc,z,'linear');
for k=first:last
    lines(k)=sprintf('%.12g %.12g / ! SSP_POINT',z(k-first+1),v(k-first+1));
end
write_text(env_file,join(lines,newline));
end

function apply_bottom(env_file,properties)
lines=splitlines(string(fileread(env_file)));
lines=replace_row(lines,"BOTTOM_PROPERTIES",2,properties(1));
lines=replace_row(lines,"BOTTOM_PROPERTIES",4,properties(2));
lines=replace_row(lines,"BOTTOM_PROPERTIES",5,properties(3));
write_text(env_file,join(lines,newline));
end

function [z,c,first,last]=read_ssp(lines)
idx=find(contains(lines,"! SSP_POINT"));
assert(~isempty(idx)&&all(diff(idx)==1), ...
    'propagation:UniversalitySSP','Baseline must contain contiguous tagged SSP points.');
first=idx(1); last=idx(end);
data=zeros(numel(idx),2);
for k=1:numel(idx)
    v=sscanf(lines(idx(k)),'%f');
    assert(numel(v)>=2,'propagation:UniversalitySSP','Malformed SSP node.');
    data(k,:)=v(1:2);
end
z=data(:,1); c=data(:,2);
assert(all(diff(z)>0),'propagation:UniversalitySSP','SSP depths must ascend.');
end

function lines=replace_row(lines,tag,column,value)
idx=find(contains(lines,"! "+tag));
assert(numel(idx)==1,'propagation:UniversalityTemplate', ...
    'Need exactly one %s field in annotated template.',tag);
v=sscanf(lines(idx),'%f');
assert(numel(v)>=column,'propagation:UniversalityTemplate','Malformed %s field.',tag);
v(column)=value;
fields=arrayfun(@(x) sprintf('%.12g',x),v(:),'UniformOutput',false);
suffix=" / ! "+tag;
if tag=="SSP_HEADER" || tag=="RECEIVER_DEPTH_COUNT", suffix=" ! "+tag; end
lines(idx)=string(strjoin(fields,' '))+suffix;
end

function write_text(path,content)
fid=fopen(path,'w');
assert(fid>=0,'propagation:UniversalityIO','Cannot write file: %s',path);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',char(content));
end
