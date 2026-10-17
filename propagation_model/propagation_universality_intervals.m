function T = propagation_universality_intervals(points,criterion)
%PROPAGATION_UNIVERSALITY_INTERVALS Maximal consecutive passing scan runs.
% Boundaries are observed sample values, NEVER interpolated or extrapolated.
if nargin<2, criterion="focus"; end
assert(any(string(criterion)==["focus","both"]), ...
    'propagation:UniversalityIntervals','Invalid pass criterion.');
names={'Parameter','StartValue','EndValue','StartLabel','EndLabel','SampleCount'};
rows=cell(0,6);
if isempty(points)
    T=cell2table(rows,'VariableNames',names); return;
end
groups=unique(points.Parameter,'stable');
for g=1:numel(groups)
    part=points(points.Parameter==groups(g),:);
    % Ordering in points is the configured scanning order.
    eligible=part.FocusStatus=="准确";
    if criterion=="both", eligible=eligible & part.AccuracyStatus=="准确"; end
    % A failed/unknown point separates segments; categories are discrete.
    if any(part.Unit=="category")
        for j=find(eligible(:)).'
            rows(end+1,:)={groups(g),part.Value(j),part.Value(j), ...
                part.ValueLabel(j),part.ValueLabel(j),1}; %#ok<AGROW>
        end
    else
        edge=diff([false;eligible(:);false]);
        begins=find(edge==1); ends=find(edge==-1)-1;
        for j=1:numel(begins)
            a=begins(j); b=ends(j);
            rows(end+1,:)={groups(g),part.Value(a),part.Value(b), ...
                part.ValueLabel(a),part.ValueLabel(b),b-a+1}; %#ok<AGROW>
        end
    end
end
T=cell2table(rows,'VariableNames',names);
if isempty(T), return; end
T.Parameter=string(T.Parameter); T.StartValue=cell2mat(T.StartValue);
T.EndValue=cell2mat(T.EndValue); T.StartLabel=string(T.StartLabel);
T.EndLabel=string(T.EndLabel); T.SampleCount=cell2mat(T.SampleCount);
end
