# 准确性 V2（独立增量，Mock 阶段）

新版入口 `propagation_accuracy_v2(reference,simulation,cfg)`。老版五项启用指标及普适性/溯源性暂不变；现有准确性入口还会额外保存 `propagation_accuracy_v2_metrics.csv`，并将完整结果放在 `result.accuracy_v2` 中。

## 数据边界

- 新版直接接受已抽取的**单一接收深度** `range_m`（米）和 `tl_db`（dB）两个列向量；只比较严格相同的共同采样点，不外推、不大范围插值。
- Bellhop Mock 接口 `propagation_accuracy_v2_from_bellhop` 取接收阵几何中心最近的深度行，选用最长连续有效距离段。
- 区域使用窗口按米定义的 `smooth` 移动平均（缺少 smooth 时退化为 `movmean`）；暂不下采样、不设置最小持续距离。以 `findpeaks` 的10 dB显著度门限寻找 `-TL` 的汇聚峰和 `TL` 的影区峰。宽度取距峰顶固定下降3 dB的左右首次交点，**不是 half-prominence**；范围越界则宽度为 NaN。
- 区域中心用参考侧自适应门限 `max(W_ref,0.1*abs(R_ref))` 按距离顺序一对一匹配，允许漏检、多检；两侧数量均为0时数量项视为一致，但位置和宽度仍记未验证。
- 多径需要 `arrivals.delay_s`、`amplitude`、`top_bounces`、`bottom_bounces`、`tx_time_s`、`system_delay_s`，其中后两个校正字段必须明确提供。Bellhop Mock 明确设为零；真实测量数据不得沿用这两个零值假设。单个接收位置计算主要路径的到达时延 RMSE、相邻有效匹配路径的时延间隔 RMSE、最后有效到达时刻绝对误差。
- 真实测量/待验模型的 JSON 输入与标准数据适配器目前**没有实现**，待输入契约和真实数据到位后对接。

## 评分契约

- 十个固定指标分别输出 `Metric / Score / Status / Weight`，子指标及误差明细放在 `detail`；总评只读这十项结果，不读取物理特征。
- 外部仅需编辑 `cfg.weights`（十个权重，默认均为1）。
- 内部误差阈值和0—100映射暂为**Mock 演示占位**（`propagation_accuracy_v2_config`），不代表专家验收标准；分数 >=80 为准确，60—80为关注，否则不准确。
- 任一正权重指标未验证时，**整体暂不产生分数和等级**，以免擅自决定缺失指标如何聚合；等待对“未验证”含义的核实。

## 测试

MATLAB 环境执行：

```matlab
addpath(genpath(pwd))
results = runtests('tests/test_accuracy_v2.m');
assertSuccess(results)
```

此代码提交前未能在当前工具环境中实际运行 MATLAB/Bellhop，需完成上面的测试与真实数据契约验证。
