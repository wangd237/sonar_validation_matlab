function value = propagation_frequency_response_error(~, ~, ~)
%PROPAGATION_FREQUENCY_RESPONSE_ERROR Reserved E_H interface; not implemented.
error('propagation:FrequencyResponseDisabled', ...
    'E_H is reserved and not implemented. Set enable_frequency_response=false.');
value = NaN; %#ok<UNRCH>
end
