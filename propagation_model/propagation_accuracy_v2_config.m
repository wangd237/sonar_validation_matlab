function cfg=propagation_accuracy_v2_config()
%PROPAGATION_ACCURACY_V2_CONFIG Provisional private scoring limits.
% These are NOT empirical acceptance limits. Do not expose them as expert weights.
cfg.weights=ones(10,1);
cfg.min_peak_prominence_db=10;
cfg.width_drop_db=3;
cfg.smooth_window_m=500;
cfg.maximum_zone_step_m=250;
cfg.arrival_relative_floor_db=-40;
cfg.match_delay_s=0.005;
cfg.match_bounce_counts=true;
% Each pair: [80-point threshold, 60-point threshold].
cfg.limits.tl_rmse_db=[3 8];
cfg.limits.tl_correlation_loss=[0.05 0.3];
cfg.limits.zone_count=[0.5 2];
cfg.limits.zone_miss_loss=[0.1 0.6];
cfg.limits.zone_position_m=[500 2500];
cfg.limits.zone_width_m=[500 2500];
cfg.limits.arrival_delay_s=[0.001 0.005];
cfg.limits.adjacent_delay_s=[0.001 0.005];
cfg.limits.last_arrival_s=[0.001 0.005];
end
