function out = propagation_run_bellhop(scene, case_root, role)
%PROPAGATION_RUN_BELLHOP Run A and C copies, preserving the input triplet.
% Supports the local legacy 2-D executable, external L boundaries, one source.
assert(isfile(scene.bellhop_exe),'propagation:Executable','Bellhop not found: %s',scene.bellhop_exe);
reader_dir=fullfile(scene.toolbox_dir,'ReadWrite');
assert(isfile(fullfile(reader_dir,'read_shd_bin.m')), ...
    'propagation:Toolbox','read_shd_bin.m not found under %s',reader_dir);
for ext={'.env','.bty','.ati'}
    assert(isfile([case_root ext{1}]),'propagation:MissingInput','Missing input: %s',[case_root ext{1}]);
end
original=fileread([case_root '.env']);
lines=regexp(original,'\r\n|\n|\r','split');
quoted=[]; tokens={};
for k=1:numel(lines)
    tok=regexp(lines{k},'^\s*''([^'']*)''','tokens','once');
    if ~isempty(tok), quoted(end+1)=k; tokens{end+1}=tok{1}; end %#ok<AGROW>
end
assert(numel(quoted)>=4,'propagation:Environment','Expected standard 2-D ENV option records.');
top=tokens{2}; bottom=tokens{3}; mode=tokens{4};
assert(numel(top)>=5 && top(5)=='*' && numel(bottom)>=2 && bottom(2)=='*', ...
    'propagation:BoundaryRequired','ENV must enable ATI at top option 5 and BTY at bottom option 2.');
assert(ismember(top(1),'NCS') && top(2)=='V' && ismember(bottom(1),'AR'), ...
    'propagation:Environment','Supported demo contract: N/C/S SSP, vacuum top, A/R bottom.');
assert(~isempty(mode) && ismember(mode(1),'AaCISRE'), ...
    'propagation:Environment','Cannot identify the ENV RunType record.');
assert(numel(mode)<3 || mode(3)==' ', ...
    'propagation:Environment','External source beam patterns are not supported by the three-file interface.');
bty=read_boundary([case_root '.bty']); ati=read_boundary([case_root '.ati']);
ensure_dir(scene.work_dir);
% A fresh directory prevents accidentally accepting stale Bellhop output.
run_dir=tempname(scene.work_dir); ensure_dir(run_dir);
old_dir=pwd; old_path=path;
restore=onCleanup(@() restore_context(old_dir,old_path)); %#ok<NASGU>
addpath(reader_dir,'-begin');
cd(run_dir);
for job={'A','C'}
    letter=job{1}; stem=['case_' letter];
    copyfile([case_root '.bty'],[stem '.bty']);
    copyfile([case_root '.ati'],[stem '.ati']);
    modified=lines;
    changed_mode=mode; changed_mode(1)=letter;
    modified{quoted(4)}=regexprep(lines{quoted(4)}, ...
        '^\s*''[^'']*''',['''' changed_mode ''''],'once');
    write_text([stem '.env'],strjoin(modified,newline));
    command=sprintf('"%s" %s',scene.bellhop_exe,stem);
    [status,log]=system(command);
    write_text([stem '.log'],log);
    assert(status==0,'propagation:BellhopFailed','Bellhop failed (%d); see %s',status,run_dir);
    if letter=='A', ext='.arr'; else, ext='.shd'; end
    assert(isfile([stem ext]),'propagation:MissingOutput', ...
        'Bellhop did not produce %s; inspect logs in %s',[stem ext],run_dir);
    if isfile([stem '.prt'])
        prt=fileread([stem '.prt']);
        assert(isempty(regexpi(prt,'fatal|\*\*\*\s*error','once')), ...
            'propagation:BellhopFailed','Bellhop reported an error; see %s',run_dir);
    end
end
[arrivals,ap,arr_freq]=propagation_read_arrivals('case_A.arr');
% Reuse the Acoustic Toolbox's binary SHD reader. Local legacy copies
% return six outputs; newer copies return seven (extra "atten" field).
% Inspect the resolved function signature instead of assuming a version.
reader_nout=nargout('read_shd_bin');
if reader_nout==6
    [~,plot_type,freq_vec,~,pos,p]=read_shd_bin('case_C.shd');
elseif reader_nout==7
    [~,plot_type,freq_vec,~,~,pos,p]=read_shd_bin('case_C.shd');
else
    error('propagation:Toolbox', ...
        'Unsupported read_shd_bin output count: %d (%s)', ...
        reader_nout,which('read_shd_bin'));
end
assert(strcmp(strtrim(plot_type),'rectilin'),'propagation:Grid','Only rectangular fields are supported.');
% Coordinate field names also differ across Acoustic Toolbox revisions.
if isfield(pos.s,'z'), source_depth=pos.s.z;
elseif isfield(pos.s,'depth'), source_depth=pos.s.depth;
else, error('propagation:Grid','Missing source depth in SHD coordinates.'); end
if isfield(pos.r,'z'), receiver_depth=pos.r.z;
elseif isfield(pos.r,'depth'), receiver_depth=pos.r.depth;
else, error('propagation:Grid','Missing receiver depth in SHD coordinates.'); end
if isfield(pos.r,'r'), receiver_range=pos.r.r;
elseif isfield(pos.r,'range'), receiver_range=pos.r.range;
else, error('propagation:Grid','Missing receiver range in SHD coordinates.'); end
assert(isscalar(freq_vec) && numel(source_depth)==1 && ...
    size(p,1)==1 && numel(p)==numel(receiver_depth)*numel(receiver_range), ...
    'propagation:Grid','Expected one frequency/source/bearing and a 2-D receiver section.');
assert(abs(double(freq_vec(1))-double(arr_freq))<1e-4, ...
    'propagation:Grid','A/C frequencies differ.');
assert_same(ap.range_m,receiver_range,'A/C receiver range');
assert_same(ap.receiver_depth_m,receiver_depth,'A/C receiver depth');
assert_same(ap.source_depth_m,source_depth,'A/C source depth');
out.freq_hz=double(freq_vec(1));
out.source_depth_m=double(source_depth(:));
out.receiver_depth_m=double(receiver_depth(:));
out.range_m=double(receiver_range(:));
% With one source/bearing, all reader layouts flatten to [depth, range].
out.pressure=reshape(double(p),numel(out.receiver_depth_m),numel(out.range_m));
assert(all(isfinite(out.pressure(:))),'propagation:Field','Non-finite pressure values.');
out.arrivals=arrivals;
out.tl_db=-20*log10(max(abs(out.pressure),scene.validation.pressure_floor));
top_z=interp1(ati(:,1),ati(:,2),out.range_m,'linear',NaN).';
bottom_z=interp1(bty(:,1),bty(:,2),out.range_m,'linear',NaN).';
assert(all(isfinite(top_z) & isfinite(bottom_z) & bottom_z>top_z), ...
    'propagation:BoundaryCoverage','ATI/BTY must cover all receivers with a positive water depth.');
out.valid_mask=out.receiver_depth_m>top_z & out.receiver_depth_m<bottom_z;
out.H=[];
out.meta.input_root=case_root;
out.meta.input_env=original;
out.meta.input_bty=fileread([case_root '.bty']);
out.meta.input_ati=fileread([case_root '.ati']);
out.meta.bellhop_exe=scene.bellhop_exe;
exe=dir(scene.bellhop_exe);
out.meta.executable_bytes=exe.bytes; out.meta.executable_modified=exe.date;
out.meta.reader=which('read_shd_bin');
out.meta.run_dir=run_dir;
out.meta.field_mode='C';
out.meta.pressure_convention='Bellhop normalized complex pressure; TL=-20log10(abs(p))';
out.meta.role=role;
out.meta.created_at=datestr(now,30);
end

function data=read_boundary(filename)
fid=fopen(filename,'r'); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
kind=strtrim(fgetl(fid));
assert(strcmp(kind,'''L'''),'propagation:BoundaryFormat','Initial interface requires L boundaries: %s',filename);
n=fscanf(fid,'%d',1); data=fscanf(fid,'%f',[2,n]).';
assert(n>=2 && size(data,1)==n && all(isfinite(data(:))) && all(diff(data(:,1))>0), ...
    'propagation:BoundaryFormat','Invalid boundary coordinates: %s',filename);
data(:,1)=1000*data(:,1); % boundary files use km
end

function assert_same(a,b,label)
assert(numel(a)==numel(b) && all(abs(double(a(:))-double(b(:)))<1e-3), ...
    'propagation:Grid','%s coordinates differ.',label);
end

function write_text(filename,content)
fid=fopen(filename,'w'); assert(fid>=0,'Cannot write %s',filename);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',content);
end

function restore_context(old_dir,old_path)
cd(old_dir); path(old_path);
end
