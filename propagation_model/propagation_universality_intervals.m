function T = propagation_universality_intervals(points,criterion)
%PROPAGATION_UNIVERSALITY_INTERVALS Maximal consecutive passing scan runs.
% Boundaries are observed sample values, NEVER interpolated or extrapolated.
if nargin<2, criterion="focus"; end
criterion=string(criterion);
assert(isscalar(criterion) && any(criterion==["focus","both"]), ...
    'propagation:UniversalityIntervals','Invalid pass criterion.');

% Build strongly typed table columns directly. cell2table/cell2mat can
% otherwise leave nested cells when scan values or labels are heterogeneous.
parameter=strings(0,1);
start_value=zeros(0,1);
end_value=zeros(0,1);
start_label=strings(0,1);
end_label=strings(0,1);
sample_count=zeros(0,1);

if ~isempty(points)
    groups=unique(points.Parameter,'stable');
    for g=1:numel(groups)
        part=points(points.Parameter==groups(g),:);
        % Preserve configured scan order (do not interpolate or sort).
        eligible=part.FocusStatus=="准确";
        if criterion=="both"
            eligible=eligible & part.AccuracyStatus=="准确";
        end

        if any(part.Unit=="category")
            % Categorical settings cannot be expressed as continuous spans.
            begins=find(eligible(:));
            ends=begins;
        else
            % Failed, unknown or non-accurate points break passing runs.
            edges=diff([false;eligible(:);false]);
            begins=find(edges==1);
            ends=find(edges==-1)-1;
        end

        for k=1:numel(begins)
            a=begins(k); b=ends(k);
            next=numel(start_value)+1;
            parameter(next,1)=string(groups(g));
            start_value(next,1)=double(part.Value(a));
            end_value(next,1)=double(part.Value(b));
            start_label(next,1)=string(part.ValueLabel(a));
            end_label(next,1)=string(part.ValueLabel(b));
            sample_count(next,1)=b-a+1;
        end
    end
end

T=table(parameter,start_value,end_value,start_label,end_label, ...
    sample_count,'VariableNames', ...
    {'Parameter','StartValue','EndValue','StartLabel','EndLabel','SampleCount'});
end
