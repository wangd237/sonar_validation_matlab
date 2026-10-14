function scene = propagation_default_scene()
%PROPAGATION_DEFAULT_SCENE File-driven demo; no measured truth is implied.
% 注释：基于文件驱动的演示场景；不代表实测真值（是仿真参考，不是实验实测数据）
root = fileparts(fileparts(mfilename('fullpath')));
% mfilename('fullpath') 获取当前这个m文件的完整路径
% 两层fileparts，拿到本脚本所在项目的**根目录**

scene.model_name = 'propagation_model';
% 模型名称标识
scene.reference_root = fullfile(root,'cases','mycases','reference','ShallowWater');
% 基准参考结果文件夹（reference：参考Bellhop输出，作为对比真值，合成参考场）
scene.simulation_root = fullfile(root,'cases','mycases','simulation','ShallowWater');
% 待测试仿真的存放目录（被测模型输出）

scene.toolbox_dir = 'D:\code\Matlab\COA_cxz\Matlab';
% 工具箱路径，存放Matlab函数脚本
scene.bellhop_exe = 'D:\code\Matlab\COA_cxz\bin\bellhop.exe';
% Bellhop可执行文件完整路径，核心！脚本会调用这个exe跑声场仿真
scene.work_dir = fullfile(root,'results','propagation','work');
% 临时工作目录：Bellhop生成env/shd等输入输出文件放这里

scene.validation = propagation_validation_config();
% 加载验证评估配置（就是前面你看到的指标、TL阈值、E_H水平声能等评价参数）
scene.reference_description = 'Bellhop baseline configuration (synthetic reference)';
% 对参考场的说明：基准Bellhop仿真，属于合成参考（不是海上实测数据）
end
