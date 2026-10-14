# 声传播计算模型校验 MATLAB 示例工程

本工程用于 **Bellhop 声传播计算模型**的配置对比、指标计算、普适性扫描与扰动恢复分析。通用的指标判定、表格保存和评分工具集中在 `common/`。

## 当前运行方式

在 MATLAB 中进入工程根目录，运行：

```matlab
run_all
% 或 run_propagation_validation
```

首次运行检查 `propagation_model/propagation_default_scene.m` 中的两个安装路径：

```matlab
scene.toolbox_dir = 'D:\code\Matlab\COA_cxz\Matlab';
scene.bellhop_exe = 'D:\code\Matlab\COA_cxz\bin\bellhop.exe';
```

输入为 `cases/demo/reference/case` 和 `cases/demo/simulation/case` 两组同名 `.env/.bty/.ati` 三件套，三个文件始终必需。

运行顺序：同配置独立运行自检 → 基准/扰动配置对比 → 同频成对的频率与声源深度扫描 → 已知声源深度扰动的恢复效果分析。结果保存到 `results/propagation/`。

启用主指标 `E_MP`、`RMSE_TL`、`E_SP`，启用辅助指标 `RMSE_tau`、`rho_SP`；`E_H` 只保留接口，显示“未启用”，不参与仿真、评分或判定。

当前使用 **Bellhop 合成参考和演示阈值**，目的是跑通流程；输出反映配置差异，不代表真实待验模型的准确性或验收结论。详细公式、匹配规则、文件输出和接入限制见 [PROPAGATION_GUIDE_CN.md](PROPAGATION_GUIDE_CN.md)，接口见 [INTERFACE_SPEC_CN.md](INTERFACE_SPEC_CN.md)。

仅导出演示原始数据：

```matlab
prepare_demo_data
```

无 Bellhop 依赖的指标回归测试：

```matlab
addpath(genpath(pwd));
results = runtests('tests/test_propagation_metrics.m');
assertSuccess(results);
```

## 使用指南

### 1. 准备 MATLAB 与 Bellhop

使用 MATLAB R2020b 或更高版本。当前适配器按本机声学工具箱的旧版 Bellhop 接口编写，需要能够访问：

```text
D:\code\Matlab\COA_cxz\bin\bellhop.exe
D:\code\Matlab\COA_cxz\Matlab\ReadWrite\read_shd_bin.m
```

如果 Bellhop 或工具箱安装在其他位置，编辑 [propagation_default_scene.m](propagation_model/propagation_default_scene.m)，修改 `scene.bellhop_exe` 和 `scene.toolbox_dir`。不要把 Bellhop 目录永久写入 MATLAB 全局路径；适配器会在运行时临时加入读取函数路径。

### 2. 检查输入环境文件

每个案例必须由同名的三个文件组成：

```text
case.env    Bellhop 环境文件
case.bty    海底地形文件
case.ati    海面形状文件
```

默认演示案例位于：

```text
cases/demo/reference/case.env
cases/demo/reference/case.bty
cases/demo/reference/case.ati

cases/demo/simulation/case.env
cases/demo/simulation/case.bty
cases/demo/simulation/case.ati
```

`.env` 的顶部边界选项第 5 个字符必须是 `*`，底部边界选项第 2 个字符必须是 `*`，这样 Bellhop 才会读取 `.ati` 和 `.bty`。本示例使用 `CVW *` 和 `A*`。即使海面是平面，也必须保留 `.ati` 文件。

默认参考案例和仿真案例的唯一区别是声源深度：40 m 对 42 m。频率、声速剖面、海面、海底和接收网格保持一致。这样可以先验证“配置变化是否正确传递到传播结果”。

#### 配置自己的案例

建议保留 `cases/demo` 作为已验证的排错案例，在 `cases` 下新建自己的目录。例如配置文件名为 `shallow_water`：

```text
cases/
├─ demo/
└─ shallow_water_case/
   ├─ reference/
   │  ├─ shallow_water.env
   │  ├─ shallow_water.bty
   │  └─ shallow_water.ati
   └─ simulation/
      ├─ shallow_water.env
      ├─ shallow_water.bty
      └─ shallow_water.ati
```

文件可以改名，名称不要求必须是 `case`。每一组内部的 `.env/.bty/.ati` 必须拥有相同主文件名。参考组与仿真组也允许使用不同主文件名，例如 `reference/baseline.*` 和 `simulation/perturbed.*`。

然后编辑 [propagation_default_scene.m](propagation_model/propagation_default_scene.m)，路径填写到主文件名，不带 `.env`、`.bty` 或 `.ati` 扩展名：

```matlab
scene.reference_root = fullfile( ...
    root,'cases','shallow_water_case','reference','shallow_water');

scene.simulation_root = fullfile( ...
    root,'cases','shallow_water_case','simulation','shallow_water');
```

如果两组采用不同主文件名，则分别填写：

```matlab
scene.reference_root = fullfile( ...
    root,'cases','shallow_water_case','reference','baseline');

scene.simulation_root = fullfile( ...
    root,'cases','shallow_water_case','simulation','perturbed');
```

程序会自动在路径后添加三个扩展名。不要把路径写成 `shallow_water.env`，否则程序会尝试寻找 `shallow_water.env.env`。

#### 自定义 ENV 文件的必要条件

当前适配器要求：

- 参考组和仿真组的频率一致；
- 接收距离数组和接收深度数组一致；
- 当前只支持一个声源深度，参考与仿真的声源深度可以不同；
- 使用二维规则接收网格；
- 声速插值类型为 `N`、`C` 或 `S`；
- 顶边界为真空边界，且顶部选项第 5 位为 `*`；
- 底边界类型为 `A` 或 `R`，且底部选项第 2 位为 `*`；
- `.ati` 和 `.bty` 当前使用 `L` 型分段线性边界；
- 三个文件的距离单位遵循 Bellhop 约定：`.env/.bty/.ati` 中的水平距离使用 km，深度使用 m；
- `.ati` 和 `.bty` 的距离范围必须覆盖全部接收距离；
- 当前三文件接口不使用额外的 `.ssp`、`.sbp` 等文件。

程序会读取 `.env` 中已有的 Run Type，但实际计算时会在临时副本中分别改为 `A` 和 `C`。原始配置文件不会被修改。

如果希望使用完整的频率扫描和声源深度恢复分析，`.env` 中还需要各有一个参数标签：

```text
500.0       ! FREQUENCY_HZ
...
40.0 /      ! SOURCE_DEPTH_M
```

标签名称、下划线和大小写应保持一致，并且每个标签只能出现一次。单场景 `ref/sim` 比较不依赖这些标签；只有 `propagation_universality_analysis` 和 `propagation_traceability_analysis` 会通过标签创建配置副本。

项目外的 `E:\sonar_validation_matlab\envcases\make_ShallowWater.m` 已按这一约定更新。生成脚本中的 `freq` 和 `sourceDepth` 分别控制两行数值，并自动写出 `FREQUENCY_HZ` 与 `SOURCE_DEPTH_M` 标签。生成参考和仿真配置时，应分别设置所需的 `sourceDepth`，运行脚本后将同次生成的 `.env/.bty/.ati` 三件套放入对应目录；不要只替换 `.env` 而混用另一环境的边界文件。

### 3. 运行完整流程

#### 第一步：先运行演示案例

在使用自己的配置前，建议先保持默认 `cases/demo` 路径运行一次。这一步用于确认 MATLAB、Bellhop 可执行文件和工具箱读取函数已经配置正确：

在 MATLAB 当前目录切换到项目根目录后执行：

```matlab
cd('E:\sonar_validation_matlab\sonar_validation_matlab');
addpath(genpath(pwd));
run_all;
```

确认控制台出现：

```text
Identical-input Bellhop self-check: PASS
```

并确认 `results/propagation/self_check/propagation_self_check_metrics.csv` 中误差指标为 0、`rho_SP` 为 1。演示案例可以运行而自定义案例不能运行时，应优先检查自定义三件套的格式和覆盖范围。

#### 第二步：对自己的配置进行单场景预检

修改 `propagation_default_scene.m` 指向自己的文件后，先不要直接运行全部扫描。依次执行：

```matlab
cd('E:\sonar_validation_matlab\sonar_validation_matlab');
addpath(genpath(pwd));

scene = propagation_default_scene();
ref = generate_propagation_reference(scene);
sim = call_propagation_model_under_test(scene);
[T, aux] = propagation_build_metric_table(scene, ref, sim);
disp(T);
```

重点检查：

- `ref.freq_hz` 与 `sim.freq_hz` 相同；
- `ref.range_m` 与 `sim.range_m` 完全一致；
- `ref.receiver_depth_m` 与 `sim.receiver_depth_m` 完全一致；
- `size(ref.pressure)` 与 `size(sim.pressure)` 一致；
- `ref.valid_mask` 中存在有效水域点；
- `ref.arrivals` 和 `sim.arrivals` 能读到有效到达；
- 指标表中除暂未启用的 `E_H` 外，没有意外的“不可计算”。

如果预检失败，查看异常信息以及 `results/propagation/work/<运行目录>/case_A.log`、`case_C.log` 和 `.prt` 文件。每次运行均使用新工作目录，因此应查看时间最新的目录。

#### 第三步：运行完整分析

单场景预检正常后执行：

```matlab
run_all;
```

`run_all` 实际调用 `run_propagation_validation`，依次执行：

1. 同配置自检：同一组三件套独立运行两次，检查读取和比较链路；
2. 单场景对比：40 m 参考声源与 42 m 仿真声源；
3. 普适性结构演示：250、500、1000 Hz 与 0、1、2 m 声源深度偏移组合；
4. 恢复效果分析：扫描声源深度偏移，检查恢复到参考值后误差是否降低。

需要注意，当前完整流程的扫描频率固定为 250、500、1000 Hz，声源深度偏移固定为 0、1、2 m；恢复分析还会扫描 0、1、2、3、4 m。它们定义在 `propagation_universality_analysis.m` 和 `propagation_traceability_analysis.m` 中。自己的环境不适合这些频率或深度时，应先修改扫描数组，避免产生超出环境文件有效范围的场景。

如果只想运行传播流程，也可以执行：

```matlab
run_propagation_validation;
```

如果只需要生成一对演示输出，而不需要汇总分析，执行：

```matlab
prepare_demo_data;
```

#### 运行时注意事项

- 不要在 Bellhop 运行过程中编辑正在使用的输入文件；
- 不要让参考组和仿真组使用不同接收网格，当前代码不会自动插值；
- 不建议直接用不同频率的 ref 和 sim 计算误差，应在同一频率下成对比较；
- 如果只改变声源深度，其他环境参数应保持一致，便于解释指标变化；
- 参考数据目前也是 Bellhop 合成结果，输出只能解释为配置差异；
- `run_all` 会执行多次 Bellhop，并保留各次工作文件，场景较大时应预留运行时间和磁盘空间；
- 重复运行会更新汇总 CSV/MAT 和图片，但已有的独立 `work` 子目录会保留；
- 当前演示阈值不是验收标准，不应为了让自己的案例“通过”而直接套用或调整；
- `E_H` 尚未实现，保持 `enable_frequency_response=false`。

### 4. Bellhop 的实际运行方式

每次场景运行都会创建独立工作目录，并复制 `.env/.bty/.ati` 三件套。适配器随后对同一环境执行两次 Bellhop：

```text
A 模式   生成 .arr，用于多途到达和时延
C 模式   生成 .shd，用于复声场和传播损失
```

运行模式只修改 `.env` 中 Run Type 的第一个字符，其他环境内容保持不变。输出目录会保存输入副本、`.arr`、`.shd`、`.prt` 和 `.log`，因此可以回溯每次 Bellhop 调用。

### 5. 查看结果

主要结果位于：

```text
results/propagation/
├─ self_check/
├─ accuracy/
├─ universality/
├─ traceability/
├─ work/
├─ validation_summary.csv
└─ propagation_complete_result.mat
```

重点文件包括：

| 文件 | 用途 |
|---|---|
| `accuracy/propagation_accuracy_metrics.csv` | 六行指标结果；`E_H` 为“未启用” |
| `accuracy/propagation_accuracy_fields.png` | 参考 TL、仿真 TL、TL 差和多途结构误差图 |
| `accuracy/propagation_accuracy_arrivals.png` | 一个接收点的多途到达对比图 |
| `self_check/propagation_self_check_metrics.csv` | 同配置自检指标，应接近理想零误差 |
| `universality/propagation_universality_scene_results.csv` | 各频率和声源深度偏移的明细 |
| `traceability/propagation_traceability_source_depth.csv` | 声源深度扰动和恢复结果 |
| `work/*/*.log` | Bellhop 命令输出和诊断信息 |

当前演示运行的同配置自检应满足：`E_MP=0`、`RMSE_tau=0`、`RMSE_TL=0`、`E_SP=0`、`rho_SP=1`。40 m 与 42 m 的扰动结果应出现非零差异；这表示流程检测到了配置变化，不表示某个真实待验模型不合格。

### 6. 运行指标测试

指标测试不调用 Bellhop，适合检查公式、边界条件和异常处理：

```matlab
addpath(genpath(pwd));
results = runtests('tests/test_propagation_metrics.m');
assertSuccess(results);
```

测试覆盖同输入零误差、幅度变化、相位变化、多途一对一匹配、无到达、网格不一致、频率不一致、零参考能量和 `E_H` 禁用逻辑。

### 7. 接入真实待验模型

拿到待验模型后，保持 `ref` 和 `sim` 的统一输出结构，只替换 [call_propagation_model_under_test.m](interfaces/call_propagation_model_under_test.m)。真实模型适配器需要返回：

```matlab
out.freq_hz
out.source_depth_m
out.receiver_depth_m
out.range_m
out.pressure
out.tl_db
out.valid_mask
out.arrivals
out.H
out.meta
```

拿到真实参考数据后，再替换 [generate_propagation_reference.m](propagation_model/generate_propagation_reference.m)。指标代码、结果目录和报告流程不需要改变。真实数据接入时应重新确认复声压归一化、相位基准、接收网格、到达筛选门限和参考数据不确定度。

### 8. 修改演示参数

指标阈值和权重集中在 [propagation_validation_config.m](propagation_model/propagation_validation_config.m)：

```matlab
cfg.arrival_relative_floor_db = -40;
cfg.match_delay_s = 0.005;
cfg.pressure_floor = 1e-12;
cfg.pass_threshold = [0.20; 0.003; 5.0; NaN; 0.50; 0.85];
cfg.fail_threshold = [0.50; 0.005; 8.0; NaN; 1.00; 0.70];
```

其中 `RMSE_TL <= 5 dB` 采用当前项目给出的传播损失允许偏差。其余指标也暂时采用较宽松的演示范围：`E_MP <= 0.20`、`RMSE_tau <= 3 ms`、`E_SP <= 0.50`、`rho_SP >= 0.85`。超过通过阈值但尚未达到失败阈值时判为“关注”。这些范围后续仍需根据真实数据、模型重复试验和任务要求冻结。

`E_H` 的开关默认是 `false`。目前仅保留接口；将其改为 `true` 会明确报错，避免产生未实现的频率响应结果。

---
