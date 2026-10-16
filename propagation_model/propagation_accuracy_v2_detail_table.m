function T=propagation_accuracy_v2_detail_table(evaluation)
%PROPAGATION_ACCURACY_V2_DETAIL_TABLE Flatten scalar raw metrics for review.
% Full paired-zone/path structures remain available in the MAT output.
metric=strings(0,1); quantity=strings(0,1); value=zeros(0,1);
unit=strings(0,1);
for i=1:height(evaluation.metrics)
    d=evaluation.detail{i};
    if ~isstruct(d) || ~isscalar(d), continue; end
    keys=fieldnames(d);
    for k=1:numel(keys)
        key=keys{k}; v=d.(key);
        if ~isnumeric(v) || ~isscalar(v) || ~isreal(v), continue; end
        metric(end+1,1)=evaluation.metrics.Metric(i); %#ok<AGROW>
        quantity(end+1,1)=string(key); %#ok<AGROW>
        value(end+1,1)=double(v); %#ok<AGROW>
        if endsWith(key,'_db')
            u="dB";
        elseif endsWith(key,'_m')
            u="m";
        elseif endsWith(key,'_s')
            u="s";
        else
            u="1";
        end
        unit(end+1,1)=u; %#ok<AGROW>
    end
end
T=table(metric,quantity,value,unit,'VariableNames', ...
    {'Metric','SubMetric','Value','Unit'});
end
