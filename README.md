# 纸上飞行

一款 Godot 2D 一键飞行小游戏。玩家点击、轻触屏幕或按空格，让折叠纸飞机向上跃起；松开后重力会把飞机拉下。穿过珊瑚、柠檬黄、薄荷、天蓝、薰衣草紫与叶绿色的彩铅素描管道即可得分，撞到管道或飞出页面边缘时本轮结束。

## 操作

- 鼠标左键或轻触屏幕：起飞、向上飞、重新开始
- 空格或回车：起飞、向上飞、重新开始

## Android 下载

- [直接下载 Android v1.1.0 APK](https://github.com/schlapiadeziel-rgb/paperglide/releases/download/v1.1.0-android-debug/paperglide-android-v1.1.0.apk)
- [GitHub Release 页面](https://github.com/schlapiadeziel-rgb/paperglide/releases/tag/v1.1.0-android-debug)

APK 使用调试签名，可侧载安装，不是 Play 商店发布包。v1.1.0 起会在 Android 启动时检查公开 GitHub Release；只有发现带 APK 的较新版本时才提示，并由玩家手动打开下载页、下载和安装。旧版 v1.0.0 没有自动检查功能，首次升级到 v1.1.0 需要手动安装。

## 进阶效果

手绘笔记本纸张纹理、彩铅障碍轮换配色、纸飞机投影与浮层阴影；包含起飞、通过障碍和碰撞三种轻柔音效。每存活一段时间，障碍推进速度会加快、出现间隔会缩短，难度最高提升至第 9 节奏。最佳纪录保存在本地设备中。

## 开发

- `npm run check`：运行核心玩法与进阶效果烟雾检查
- `npm run preview:build`：构建游戏预览
- `npm run dev`：启动项目预览服务
- `npm run build`：生成可移植的 Godot Web 导出

游戏内容语言：简体中文。
