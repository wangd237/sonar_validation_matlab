function value = propagation_demo_parameter(case_root,tag)
%PROPAGATION_DEMO_PARAMETER Read one tagged scalar without duplicating inputs.
text=fileread([case_root '.env']);
token=regexp(text,['(?m)^\s*([-+0-9.eEdD]+)[^\r\n]*!\s*' tag '\s*\r?$'],'tokens');
assert(numel(token)==1,'propagation:CasePatch','Expected exactly one demo tag: %s',tag);
value=str2double(regexprep(token{1}{1},'[dD]','e'));
assert(isfinite(value),'propagation:CasePatch','Invalid tagged parameter: %s',tag);
end
