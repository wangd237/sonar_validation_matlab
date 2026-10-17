# 普适性 V2：Bellhop Mock / 单因素扫描

## 定位
本模块**尚未接入待验模型**，同时使用**完全相同的**工况三件套运行参考 Bellhop 与 Mock Bellhop。目的是验证“配置 -> 参数扫描 -> TL + .arr -> 准确性 V2 -> 分数/状态 -> 采样区间”链路；**任何 Mock 得分或通过区间均不能证明真实模型的普适性**。评分阈值也仍为 V2 演示占位值，并非正式验收标准。

## 独立运行
在 MATLAB 仓库根目录：

```matlab
addpath(genpath(pwd))
run_universality_validation
```

必须按 `propagation_default_scene.m` 配置本地 `bellhop.exe` 和 Acoustic Toolbox；未提供本地运行环境时请先执行不调用 Bellhop 的测试：

```matlab
results = runtests('tests/test_universality_v2.m');
assertSuccess(results);
```

首次建议仅运行小规模 smoke scan：

```matlab
scene=propagation_default_scene();
cfg=propagation_universality_config();
cfg.scans=cfg.scans(1);        % 先只扫频率
cfg.scans.values=[50 500];    % 两个工况
r=propagation_universality_analysis(scene, ...
  fullfile(pwd,'results','propagation','universality_smoke'),cfg);
```

完整默认扫描：频率 [10,50,100,500,1000,3000,9200] Hz；声源深度 [50,100,200,500,1000,1400,2000] m；接收深度 [50,100,250,500,1000,1400,2500] m；最远接收距离 [50,100,200] km；水深 [200,1000,5000] m；SSP 类型 [mixed_layer, thermocline, deep_channel]；底质 [soft_mud, sand, rock]。默认总共 **33** 个点；每个点分别调用 Bellhop 的 A/C 两种输出作参考和 Mock，实际计算量较大。

`propagation_universality_config.m` 内 `scans(k).values` 和 `scans(k).focus` 可改，不需要调整准确性代码。二元开关的指标顺序固定为：TL形态、汇聚区数量、汇聚区中心、汇聚区宽度、影区数量、影区位置、影区宽度、多径时延、相邻时延间隔、最后有效到达时延。**0 是专项不关注，不是打0分**。全10项准确性评分从不受开关影响；专项评分以未被关闭指标的原 V2 权重调用**同一个** `propagation_accuracy_aggregate_scores`。被关注指标未验证时不生成专项得分；原始总分中的缺项照常导致全项未验证。

## 参数化工况

工况基础文件单独存放于 `cases/universality/baseline/case.{env,bty,ati}`，由 Munk 示例复制并增加参数标记；不修改原 `cases/mycases`。参考与 Mock 使用**同一个** `case_root`，从不把“待验模型的输入偏移”当作真实普适性误差。

- 频率、声源深度、距离：使用已有 `propagation_prepare_case.m`，对双方同时施加同一参数值。
- 接收深度：在既有接收网格上改变 V2 的 `evaluation_depth_m`，而非将整个阵列平移；默认网格采样间隔50 m。
- 水深：以各类别共有的50 m声源和50 m评价接收点为固定起点，修改海底边界、SSP末端和有效接收阵深（深度不得超出海底）；这是**水深扫描家族内**共同的基准，与其它参数家族默认500 m评价深度不同。200 m 浅海示例仅为 Mock 工况，不代表经验数据的覆盖范围。
- SSP类型：3种显式的说明性声速曲线（混合层、强跃层、原 Munk 型深海声道），不是“平均声速平移”。
- 海底类型：三组说明性 `[声速, 密度, 衰减]`。当前取值用于演示，不是测量标定的标准底质参数。

水深/SSP/底质“类型”是**类别场景对比**，不是严格连续数值扰动。后续有实测/待验模型覆盖范围时，按数据支持区间调整网格和代表性场景。频率两端、射线模型在低频浅海的可信度尤其需独立确认。

## 结果文件

`results/propagation/universality/`：

- `propagation_universality_points.csv`：严格按扫描顺序保存每个参数值、总准确性分数/状态、关注指标分数/状态、运行异常及工况输入路径。
- `propagation_universality_metric_scores.csv`：每个工况10行，10项V2分数、状态及关注开关；失败工况保留10项NaN/运行失败，绝不伪造通过记录。
- `propagation_universality_raw_metrics.csv`：V2原始子指标（TL RMSE/Pearson、区域位置/宽度、时延误差等）。
- `propagation_universality_sampled_intervals.csv`：仅将**相邻已测且准确**的数值点标识为采样通过段，失败/未验证断开；类别逐项列出，不对未扫描点内插。默认根据专项分数80分及状态准确判断；可配置 `pass_rule="both"` 要求总体亦准确。
- `propagation_universality_*.png`：各组 V2 全项总分与关注分数随参数的变化曲线。
- `propagation_universality_result.mat`：保留评价明细、生成工况路径和运行目录（内含 Bellhop SHD/ARR）。这些输出是计算过程记录，非正式适用边界报告。

## 后续模型接入
未来待验模型接入 `interfaces/call_propagation_model_under_test.m` 后，需要改写本模块当前只允许 `cfg.mock=true` 的模式护栏，同时提供真实标准数据适配器、检验输入与接收坐标一致性、明确不可评价指标的处理规则，并经正式阈值审定再发布适用范围。不要仅把 `cfg.mock` 改为false就宣称完成真实普适性验证。
