function ensure_dir(folder)
%ENSURE_DIR Create folder if it does not exist.
if ~exist(folder, 'dir')
    mkdir(folder);
end
end
