# 原始版本范围与整理说明

本次发布仅以用户指定的v2.1.2 ZIP为基线，未引入后续界面特效版本。`docs/baseline-v2.1.2.json`记录原ZIP的SHA-256以及保留文件的校验值。

保留：RTL、约束、音频与画面数据、原始FPGA固件、Gowin工程文件、输入/触摸C代码。清理：仿真中间二进制、构建/烧录日志、旧画面临时源码、重复文件清单。历史验证报告只提取时钟与资源摘要，不发布本机绝对路径。

补充：仓库README、接线和协议说明、当前工程完整性校验、独立参考测试向量、缺失依赖说明。构建脚本创建自身输出目录，并将重建固件写入build/firmware，保留原始固件。

## 需要外部工程或软件的部分

1. Gowin工具与厂商原语库；原包使用Gowin Education V1.9.11.03。普通重建使用随包字库，字体重生需要Python/Pillow和Windows字体。
2. USB Host/FreeRTOS/BL616平台层、入口、板级配置及曲谱库。原包的 `instrument_keys.c` 引用 `song_library.h`，但ZIP未提供该头文件或完整平台工程；`touch_usb.c`也依赖USB Host和FreeRTOS头文件。固件清单中的BL616 SHA仅为历史记录，不能替代该镜像或平台源码。
3. 电脑WPF控制器 `controller/` 与音频测试采集 `testdata/` 不在原包内。依赖它们的脚本保留于legacy_scripts作为参考，不列为可直接运行入口。

完整FPGA端验证和输入平台的集成验证分别记录；不会把仅包含适配文件的输入层描述为可独立编译的USB主机工程。
