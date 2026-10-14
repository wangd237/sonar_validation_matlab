# 待校验模型接口约定

## 当前主接口：声传播计算模型

```matlab
ref = generate_propagation_reference(scene);
sim = call_propagation_model_under_test(scene);
[T, aux] = propagation_build_metric_table(scene, ref, sim);
```

`scene` 由 `propagation_default_scene()` 创建：

| 字段 | 含义 |
|---|---|
| `reference_root` | 参考三件套的路径和主文件名，不含扩展名 |
| `simulation_root` | 待测三件套的路径和主文件名，不含扩展名 |
| `bellhop_exe` | 本机 Bellhop 可执行文件路径 |
| `toolbox_dir` | 本机声学工具箱 MATLAB 目录 |
| `work_dir` | 独立运行目录的父目录 |
| `validation` | 五项指标的阈值、权重、多途筛选/匹配配置；E_H 禁用 |
| `reference_description` | 参考数据来源说明 |

每组必须有 `.env/.bty/.ati`。`.env` 顶边界选项第 5 位与底边界选项第 2 位必须为 `*`。适配层不覆盖输入；工作副本分别选择 `A` 和 `C` 运行模式。

统一输出 `ref/sim`：

```matlab
out.freq_hz                 % 当前单个频率 (Hz)
out.source_depth_m          % 当前单个声源深度 (m)，两侧允许不同
out.receiver_depth_m        % Nz x 1 (m)
out.range_m                 % Nr x 1 (m)
out.pressure                % Nz x Nr，Bellhop 归一化复声场
out.tl_db                   % Nz x Nr，-20log10(max(abs(p),统一下限))
out.valid_mask              % Nz x Nr，海面与海底之间的有效水域
out.arrivals                % Nz x Nr cell，每格为一个接收点的到达结构体
out.H                      % []，预留 E_H
out.meta                   % 输入快照、运行目录、程序信息、相位/归一化约定
out.role                   % reference / model_under_test
```

每个 `out.arrivals{iz,ir}`：

```matlab
a.delay_s                  % Npath x 1，绝对到达时延 (s)
a.amplitude                % Npath x 1，复幅值
a.top_bounces              % Npath x 1，海面反射次数
a.bottom_bounces           % Npath x 1，海底反射次数
a.source_angle_deg         % Npath x 1，辅助信息
a.receiver_angle_deg       % Npath x 1，辅助信息
```

无到达用各字段为空列向量表示，不能用虚构的零时延路径填充。比较要求两侧频率与接收网格一致、采用相同的复声压归一化和相位约定；不自动插值、移动时延或归一化两侧幅值。

当前适配器按已验证的本地 2010 版 `bellhop.exe` / `read_shd_bin.m` 接入，读取旧格式 2-D ASCII `.arr`（7 列到达记录）和二进制 `.shd`。初版限定单声源、二维规则接收网格、N/C/S 声速插值、真空海面、A/R 底边界和 L 型边界文件；不引入 `.ssp/.sbp` 等额外文件。其他工具箱版本或输入类型需先扩展适配器，不能假定格式兼容。

将来接入待验模型时替换 `interfaces/call_propagation_model_under_test.m`；接入标准数据时替换 `generate_propagation_reference.m`，保持以上输出结构即可继续使用指标和报告模块。

