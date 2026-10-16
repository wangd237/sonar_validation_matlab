# 声传播计算模型校验 MATLAB 工程

当前处于 **模块独立迭代 / Bellhop Mock 验证** 阶段。一次只运行一个模块，分别检查其子指标、得分和输出，不再默认执行 `run_all`。三个模块的完整新指标体系还未全部升级。

## 独立运行入口

在 MATLAB 中进入仓库根目录，逐个手动调用：

```matlab
run_accuracy_validation       % 准确性：新版10项指标（本阶段推荐）
run_universality_validation   % 普适性：旧版指标，待后续更新
run_traceability_validation   % 溯源性：旧版指标，待后续更新
```

每个命令**只启动自己的模块**，不会自动执行另外两个模块。
`run_all` 和 `run_propagation_validation` 在指标迁移期已禁用，以免把新旧口径混成一个总结果。

## 输出位置

| 模块 | 输出目录 | 主要结果 |
|---|---|---|
| 准确性 V2 | `results/propagation/accuracy/` | `propagation_accuracy_metrics.csv`、`propagation_accuracy_submetrics.csv`、`propagation_accuracy_tl_curve.png`、`propagation_accuracy_result.mat` |
| 普适性（旧版） | `results/propagation/universality/` | `propagation_universality_scene_results.csv`、统计 CSV、MAT、图片 |
| 溯源性（旧版） | `results/propagation/traceability/` | `propagation_traceability_parameter_ranking.csv`、基线 CSV、MAT、图片 |

**不要将历史输出的** `validation_summary.csv`、`propagation_complete_result.mat` **视为新版总评结果**；独立入口不再生成它们。旧结果文件可能仍在目录内，需按生成时间辨别。

## 运行前准备

修改 `propagation_model/propagation_default_scene.m` 中的路径：

```matlab
scene.reference_root = fullfile(root,'cases','mycases','reference','ShallowWater');
scene.simulation_root = fullfile(root,'cases','mycases','simulation','ShallowWater');
scene.toolbox_dir = 'D:\code\Matlab\COA_cxz\Matlab';
scene.bellhop_exe = 'D:\code\Matlab\COA_cxz\bin\bellhop.exe';
```

`reference_root`、`simulation_root` 是三件套 `.env/.bty/.ati` 的共同主文件名，**不带扩展名**。如使用 `cases/demo`，须显式修改两侧路径。需要本地 Bellhop 可执行文件和工具箱 `ReadWrite/read_shd_bin.m`。

当前参考组和仿真组均通过 Bellhop 生成，仅用于 Mock 跑通链路，不代表实测真值或真实待验模型性能。

## 准确性 V2

- 在接收阵几何中心（最近的有效接收深度行）提取一维 TL；在共同的原有距离点直接比较 `RMSE`、`Pearson`。
- 汇聚区取 `-TL`、影区取 `TL`，使用平滑 + `findpeaks`、10 dB 峰值显著度、峰值下降固定 3 dB 计算宽度，不启用最小持续距离或下采样。
- 区域一对一匹配使用参考侧尺度 `max(W_ref,0.1*abs(R_ref))`；主要到达使用路径匹配与 Mock 的零时刻、零硬件延迟校准。
- 每项指标独立生成 0–100 分，最终汇总只依赖十项分数、状态和权重。默认十个权重都是 1；单项评分阈值当前是程序内部演示占位值。
- 任一正权重项为“未验证”时，**暂不产生整体分数**，等待明确该状态的汇总语义。这不影响其他已得到的指标和子指标。
- 实测参考和 JSON 待验模型适配接口仍待后续接入。

算法及接口细节见 [ACCURACY_V2_GUIDE_CN.md](ACCURACY_V2_GUIDE_CN.md)。

## 测试

先单独运行无需 Bellhop 的评价函数测试：

```matlab
addpath(genpath(pwd));
results = runtests('tests/test_accuracy_v2.m');
assertSuccess(results);
```

旧版多径与指标基础回归（主要服务于尚未升级的普适性、溯源性）：

```matlab
results = runtests('tests/test_propagation_metrics.m');
assertSuccess(results);
```

当前仓库更新尚未在真实 MATLAB/Bellhop 环境执行这两组测试。更详细的旧版配置文件格式与运行环境限制见 [PROPAGATION_GUIDE_CN.md](PROPAGATION_GUIDE_CN.md)，其中关于 `run_all` 和旧指标报告的说明只适用于迁移前版本。
