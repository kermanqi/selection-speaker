# 划词朗读器

一个轻量的 macOS 菜单栏工具：选中英文单词或短句，松开鼠标后自动用 macOS 自带语音朗读；需要时，再用 DeepSeek 显示中文翻译。

它不追求做成完整词典，也不要求复杂配置。打开、授权、划词，就可以开始使用。

## 功能

- 划选英文单词或短句后自动朗读
- 使用 macOS 自带语音，不需要额外下载语音模型
- 可选在鼠标附近显示 DeepSeek 中文翻译
- 支持自定义 DeepSeek 模型和翻译提示词
- API Key 保存在 macOS Keychain 中，不写入项目或 App
- 支持全局快捷键开关朗读和翻译
- Universal App，同时支持 Apple Silicon 和 Intel Mac

## 安装

从 [Releases](../../releases) 下载：

- `.dmg`：推荐普通用户使用，打开后将 App 拖入“应用程序”文件夹
- `.zip`：解压后直接打开 App

本项目目前没有使用 Apple Developer ID 签名，也没有 notarization。App 使用临时 ad-hoc 签名。第一次打开时，如果 macOS 提示无法验证开发者，请在 Finder 中右键点击“划词朗读器.app”，选择“打开”，再确认一次。

如果仍然无法打开，可以在“系统设置 -> 隐私与安全性”中点击“仍要打开”。只有在确认下载来源可信时，才建议使用这个操作。

首次启动后，请在：

```text
系统设置 -> 隐私与安全性 -> 辅助功能
```

允许“划词朗读器”。授权后重新打开 App。

## 使用

1. 打开 App，菜单栏会出现扬声器图标。
2. 在网页、PDF、文档或其他应用中划选英文。
3. 松开鼠标，App 会自动朗读选中的内容。
4. 点击菜单栏图标，可以暂停自动朗读、开启中文翻译、设置 API Key、修改模型、停止朗读或退出。

App 会优先处理含有英文字母的选区，并忽略空白或纯中文选区。某些应用不直接暴露选中文本时，App 会临时读取剪贴板内容，然后立即恢复原剪贴板。

## 中文翻译

中文翻译默认关闭。开启方式：

1. 点击菜单栏图标，选择“显示中文翻译”。
2. 第一次开启时输入 DeepSeek API Key。
3. 之后划选英文，App 会继续朗读英文，并在鼠标附近显示中文翻译。

开启翻译后，选中的文本会发送到 DeepSeek API。API Key 只保存在本机 Keychain 中，不会随 App 发布。请根据自己的隐私需求决定是否开启翻译。

默认模型是 `deepseek-v4-flash`，可以在菜单中修改。偏好设置中也可以编辑系统提示词和用户提示词模板；用户提示词模板必须保留 `{selectedText}`。

## 从源码构建

要求：

- macOS 13 或更高版本
- Swift 6.1 或更高版本
- Xcode Command Line Tools 或 Xcode

运行开发版本：

```sh
swift run
```

构建 Universal App：

```sh
./scripts/build-app.sh 1.0.0
```

生成：

```text
build/划词朗读器.app
```

构建 GitHub Release 文件：

```sh
./scripts/build-release.sh 1.0.0
```

生成的 `.dmg`、`.zip` 和 SHA-256 校验文件位于：

```text
build/releases/
```

## 发布

向 GitHub 推送版本标签后，GitHub Actions 会自动测试、构建并创建 Release：

```sh
git tag v1.0.0
git push origin v1.0.0
```

Release 会包含：

- Universal `.dmg`
- Universal `.zip`
- SHA-256 校验文件

## English

**Selection Speaker** is a lightweight macOS menu bar app for Chinese learners. Select an English word or phrase in any app, release the mouse, and let macOS read it aloud. Optionally, use DeepSeek to show a Chinese translation near the cursor.

Features include native macOS speech, optional DeepSeek translation, editable prompts, Keychain storage for the API key, global shortcuts, and a Universal build for Apple Silicon and Intel Macs.

Download the `.dmg` or `.zip` package from [Releases](../../releases). The app is not signed with an Apple Developer ID and is not notarized; it uses an ad-hoc signature. On first launch, right-click the app and choose **Open**, then grant Accessibility permission in **System Settings -> Privacy & Security -> Accessibility**.

## License

MIT License. See [LICENSE](LICENSE).
