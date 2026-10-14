function save_table_csv(T, filename)
%SAVE_TABLE_CSV Write table and create parent folder when needed.
folder = fileparts(filename);
if ~isempty(folder), ensure_dir(folder); end
writetable(T, filename, 'Encoding','UTF-8');
end
