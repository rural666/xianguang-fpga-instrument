# 验证记录

2026-10-07 对整理后的 v2.1.2 工程重新执行：

- 58个核心文件、约束、ROM/预览数据和原始固件SHA-256一致性校验通过。
- 19项音频与控制仿真通过，含UART、I²S、两种编码、音频FIFO、合成器24声部/8音色、节拍器、I²C、旋钮、姿态锁定/复位、小喇叭链路、传感器及控制协议。
- Gowin Education V1.9.11.03离线构建完成；系统时钟27MHz，Fmax33.786MHz；像素时钟25.2MHz，Fmax28.153MHz，建立/保持时间摘要无违规。
- Gowin工程引用和本地HTML预览图片路径已检查。

这次没有烧录或进行新的实板测试。原始 `firmware/control.fs` 保持不变，重建镜像写在忽略提交的build目录，避免覆盖已提供的基线。完整结果在local_validation.json与simulation_results.txt；历史报告摘要另外标注supplied来源。本机路径和构建原始日志不发布。
