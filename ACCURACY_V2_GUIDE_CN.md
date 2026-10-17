# 准确性 V2 模块（独立运行 / Mock 阶段）

## 独立入口

在 MATLAB 仓库根目录运行：

```matlab
run_accuracy_validation
```

此命令仅运行准确性，不自动运行普适性或溯源性。原 `run_all`、`run_propagation_validation` 已停用。

内部调用关系：

```text
run_accuracy_validation
  -> propagation_accuracy_validation
      -> Bellhop mock reference + simulation
      -> propagation_accuracy_v2_from_bellhop
          -> propagation_accuracy_v2
              -> TL RMSE / Pearson
              -> 1-D zone extraction / matching
              -> corrected arrival matching
              -> independent scores for ten indicators
              -> propagation_accuracy_aggregate_scores
      -> per-indicator CSV / raw submetric CSV / TL plot / MAT
```

## 数据与算法

- `propagation_accuracy_v2` 接受同一接收深度的 `range_m` 和 `tl_db` 列向量。仅比较双方共有的原始采样距离，不大范围插值。
- Bellhop 适配器在 `propagation_accuracy_v2_config.m` 中显式指定 `evaluation_depth_m=500`，并要求最近接收深度与目标相差不超过 25 m；不再默认使用 0–5000 m 阵列的几何中点 2500 m。汇聚区/影区采用 5000 m 平滑窗口提取宏观包络，避免把短程干涉条纹当成区域特征。
- 到达路径先校正发射时间和固定系统延迟，再按共同的相对幅度门限过滤并按时延排序。双方都有海面/海底反射次数时，先以 `(top_bounces,bottom_bounces)` 作为路径标签，只在同类内选择 10 ms 门限内时延最近且未占用的路径；标签缺失时退化为纯时延最近匹配。不使用动态规划。相邻到达间隔使用相邻匹配对的间隔差。10 ms 只决定能否配对，评分仍使用 1 ms（80 分界）和 5 ms（60 分界）的严格误差阈值。
- 输出 `propagation_accuracy_multipath_arrivals.png`：上下两排显示参考与仿真的主要多径，绿线表示匹配、红叉表示未匹配、黑框表示最后有效到达；点大小仅用于表示相对幅度。
- Bellhop Mock 适配器默认取接收阵几何中心最近的深度行，并使用最长连续有效距离段。该适配器不代表未来实测接口。
- 区域检测：`smooth`（若不可用则 `movmean`）的移动平均；当前不下采样、不增加最小持续距离门限。汇聚区检测 `-TL`、影区检测 `TL`；`MinPeakProminence=10 dB`，宽度为距离峰顶固定下降3 dB左右交点，而非 MATLAB 默认半突起度宽度。无法找到完整交点的区域会被标记截断，宽度为 NaN。
- 匹配：两侧区域一对一，参考侧门限 `max(W_ref,0.1*abs(R_ref))`。若参考区宽度因截断不可计算，目前只使用 0.1R 作为匹配上限。数量指标报告数量误差及 TP/FP/FN；中心和宽度只比较匹配成功且能提取的特征。
- 到达信息：`delay_s`、`amplitude`、`top_bounces`、`bottom_bounces`、`tx_time_s`、`system_delay_s`。时间校正字段必须提供，不能推断实际测量的发射时刻或设备延迟。Bellhop Mock 适配器明确使用两个零校正量；同一接收点计算主要路径到达时延 RMSE、相邻有效匹配时延间隔 RMSE 和最后有效到达时刻的绝对误差。
- 没有可提取数据或没有可匹配特征的子项暂记为「未验证」，这与误差等于0严格区分。

## 评分接口

每项指标都返回独立 `Score`（0—100）、`Status`（准确/关注/不准确/未验证）、`Weight`。总评函数 `propagation_accuracy_aggregate_scores` **只接受十个指标的得分、状态、权重**，不读取物理量或子指标。

- 唯一面向专家的配置是 `propagation_accuracy_v2_config().weights`，十项初始权重全部为1。
- 单项内部 `cfg.limits.*` 阈值为 Mock 演示占位，并非已经验证的物理验收标准；映射采用 80 / 60 分三级锚点。
- 只要正权重指标存在「未验证」，整体总分和等级暂记「未验证」，**不擅自零分处理或改权重重算**；待确认规则后再修改。
- 普适性和溯源性仍调用旧版 `propagation_build_metric_table`，后续需基于 V2 统一准确性接口另行更新，当前不混合成一张总报表。

## 输出

- `results/propagation/accuracy/propagation_accuracy_metrics.csv`：10项指标分数、状态和权重；
- `results/propagation/accuracy/propagation_accuracy_submetrics.csv`：可导出的量化子指标（例如 TL RMSE、Pearson、TP/FP/FN、位置偏差和时延差异）；
- `results/propagation/accuracy/propagation_accuracy_tl_curve.png`：相同深度、共同距离下的 TL 曲线及差异；
- `results/propagation/accuracy/propagation_accuracy_tl_field_2d.png`：Ref、Sim 原生 `plotshd` 二维场和逐网格差值图；两幅 TL 使用同一色标，差值图以0为中心，差值无效水域为灰色，不叠加接收深度；
- `results/propagation/accuracy/propagation_accuracy_convergence_zones.png`：原始/平滑 TL、汇聚区中心、3 dB边界、匹配门限与匹配连线；
- `results/propagation/accuracy/propagation_accuracy_shadow_zones.png`：相同要素，用于影区；
- `results/propagation/accuracy/propagation_accuracy_zone_detections.csv`：每个检测区域的 Ref/Sim、中心、边界、宽度、显著度、截断标记和匹配状态；
- `results/propagation/accuracy/propagation_accuracy_zone_matches.csv`：成功匹配的区域对应关系、中心偏差、匹配容差、宽度差；
- `results/propagation/accuracy/propagation_accuracy_result.mat`：完整指标、原始检测与匹配明细、标准化输入、Mock 元信息以及总体评定。

两个诊断 PNG 都有三层：Ref TL、Sim TL、区域匹配示意。前两层以灰色显示原始 TL、彩色显示平滑后的 TL；三角形标记中心，水平粗线和圆点标记固定3 dB下降点宽度。第三层蓝色横线表示每个参考区域的自适应匹配容差，绿色连线表示匹配成功，红叉表示未匹配。若未找到3 dB边界，宽度记 NaN，不绘制对应区间。

这些结果直接取自 `propagation_accuracy_v2` 已参与评分的候选区域和匹配对，**画图不执行二次 findpeaks**。如果距离分辨率不足而不能提取区域，程序会删除之前留下的区域诊断图与区域 CSV，并在控制台提示，避免误读过期图表。

后续实验使用标准经验公式设计的环境时，只需修改 `propagation_default_scene.m` 中参考和仿真三件套路径，再独立运行 `run_accuracy_validation`。此阶段没有实现自动生成经验环境。

二维 Ref/Sim 使用声学工具箱 `Matlab/Plot/plotshd.m` 直接绘制已有的 `meta.run_dir/case_C.shd`；无需重新实现读取声压和绘图。差值图使用适配器已有的 `tl_db` 与双方 `valid_mask`，仅展示共同有效单元。要求 Ref/Sim 具有相同的接收距离和深度网格。不会改变一维提取、区域匹配或准确性分数。

基础输入校验测试（无需 Bellhop）；`plotshd` 与真实 `.shd` 的绘图集成需本地运行 `run_accuracy_validation` 验证：

```matlab
results = runtests('tests/test_accuracy_tl_field_2d.m');
assertSuccess(results);
```

## 测试状态

```matlab
addpath(genpath(pwd))
results = runtests('tests/test_accuracy_v2.m');
assertSuccess(results)
```

当前会话可编辑 GitHub 仓库，但没有可调用的 MATLAB/Bellhop 本地运行环境。因而不能宣称本次代码已通过 MATLAB 运行测试。提交属于代码与接口集成，不等同于实测准确性验证。
