function cfg = propagation_validation_config()
%PROPAGATION_VALIDATION_CONFIG Demonstration thresholds, not acceptance limits.
cfg.enable_frequency_response = false;
cfg.arrival_relative_floor_db = -40; % common amplitude cutoff per receiver
cfg.match_delay_s = 0.005;
cfg.match_bounce_counts = true;
cfg.pressure_floor = 1e-12;         % common TL floor; 240 dB maximum
% Accuracy/universality require identical physical inputs. Traceability can
% deliberately perturb a biased simulation input while freezing reference.
cfg.allow_traceability_input_mismatch = false;
% Relaxed demonstration limits. RMSE_TL <= 5 dB follows the current
% engineering convention supplied for this project; these are not yet
% frozen acceptance limits.
% Order: E_MP, RMSE_tau (s), RMSE_TL (dB), E_H, E_SP, rho_SP.
cfg.pass_threshold = [0.20; 0.003; 5.0; NaN; 0.50; 0.85];
cfg.fail_threshold = [0.50; 0.005; 8.0; NaN; 1.00; 0.70];
cfg.weight = [0.25; 0.10; 0.25; 0; 0.25; 0.15];
end
