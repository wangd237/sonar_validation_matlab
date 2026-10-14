function print_metric_table(T, title_str)
%PRINT_METRIC_TABLE Console helper.
fprintf('\n==== %s ====\n', title_str);
disp(T(:, {'Domain','Metric','Level','Value','Status'}));
end
