# 弦光界面设计工程包 · 当前一行双八度版

双击 `界面预览.html` 可看当前 HDL 仿真的待机和演奏画面。图片是 FPGA 画面代码产生的预览，不是另画的效果图；当前板子输出 640×480，7 英寸屏实际显示为 800×480。

## 可编辑的文件

- `fpga_source/rtl/studio_scene.v`：画面布局、琴键形状与下沉、波形、参数和状态文字的主实现。
- `make_ui_assets_v2_1_1.py`：顶部文字、音色字形等位图素材生成器；使用 Python、Pillow 和 Windows 字体。它与 `fpga_source/assets/` 保持相邻目录关系，可从本包根目录运行。
- `inline_scene_text.py`：把 `scene_text.hex` 的字形索引写入 Verilog。运行前建议备份 `studio_scene.v`。
- `fpga_source/assets/`：素材源、生成的 `.hex` 数据以及待机／演奏预览图。`Studio.xaml` 属于此前电脑控制界面的参考布局，不是当前 HDMI 画面主源。
- `fpga_source/control.gprj`、`rtl/`、`constraints/`、`scripts/`、`sim/`：完整的 Gowin FPGA 画面工程、约束、构建和仿真文件。音频模块也包含在 `rtl/` 中，因为当前画面取实际合成声音绘制波形。
- `fpga_source/firmware/control.fs`：已烧录验证过的画面及发声程序。
- `触摸界面交互源码/`：触摸坐标到屏幕琴键、按钮的对应代码。
- `设计说明与生成脚本/弦光_界面设计说明.md`：早期 800×480 视觉设计规范，用于理解配色和排版。当前上屏的一行双八度版本与早期参考稿有改动，以 `studio_scene.v` 和预览图为准。

原说明文档提到 `xianguang_v6.html` 等 HTML 原稿，本机未找到这些原稿。本包保留了实际可重新编译的 FPGA 画面源码和当前预览，没有把预览图冒充原始 HTML 设计文件。

## 检查与重建

在包根目录可以运行 `fpga_source/scripts/validate_roms.ps1 -Project ./fpga_source` 检查画面数据。完整 FPGA 编译需要另行安装 Gowin Education V1.9.11.03；运行 `fpga_source/scripts/build_fpga.ps1 -GowinRoot <Gowin安装目录>`。工具安装程序不包含在本包内。仅查看和编辑界面无需编译或接开发板。
