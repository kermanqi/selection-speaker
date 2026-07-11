# 划词朗读器

一个轻量的 macOS 菜单栏工具：选中英文单词或短句，松开鼠标后自动用 macOS 自带语音朗读；需要时，再用 DeepSeek 显示中文翻译。

它不追求做成完整词典，也不要求复杂配置。打开、授权、划词，就可以开始使用。

## 功能

- 划选英文单词或短句后自动朗读
- 使用 macOS 自带语音，不需要额外下载语音模型
- 可选在鼠标附近显示 DeepSeek 中文翻译
- 支持中译英模式：中文或中英文混合选区翻译成英文并朗读
- 中译英模式下选中英文时，朗读英文并显示中文翻译
- 支持自定义 DeepSeek 模型和翻译提示词
- API Key 保存在 macOS Keychain 中，不写入项目或 App
- 支持自定义全局快捷键开关朗读、翻译和切换翻译方向
- Universal App，同时支持 Apple Silicon 和 Intel Mac

## 安装

从 [Releases](../../releases) 下载：

- `.dmg`：推荐普通用户使用，打开后将 App 拖入“应用程序”文件夹
- `.zip`：解压后直接打开 App

本项目目前没有使用 Apple Developer ID 签名，也没有 notarization。App 使用临时 ad-hoc 签名。第一次打开时，如果 macOS 提示无法验证开发者，请在 Finder 中右键点击“划词朗读器.app”，选择“打开”，再确认一次。

如果仍然无法打开，可以在“系统设置 -> 隐私与安全性”中点击“仍要打开”。只有在确认下载来源可信时，才建议使用这个操作。

如果右键选择“打开”仍然无法启动，可以在终端执行下面的命令。这里假设你已经把 App 放进了“应用程序”文件夹：

```sh
xattr -dr com.apple.quarantine "/Applications/划词朗读器.app"
open "/Applications/划词朗读器.app"
```

这会移除该 App 的下载隔离标记，不需要 `sudo`。如果你把 App 放在其他位置，请把命令中的路径替换成实际路径。只对确认来源可信的文件执行此命令。

首次启动后，请在：

```text
系统设置 -> 隐私与安全性 -> 辅助功能
```

允许“划词朗读器”。授权后重新打开 App。

## 使用

1. 打开 App，菜单栏会出现扬声器图标。
2. 在网页、PDF、文档或其他应用中划选英文。
3. 松开鼠标，App 会自动朗读选中的内容。
4. 点击菜单栏图标，可以暂停自动朗读、开启翻译、切换英译中/中译英方向、设置 API Key、修改模型、停止朗读或退出。

英译中模式只处理英文选区；中译英模式还会处理纯中文和中英文混合选区。所有模式都会忽略空白、纯标点和不含中英文字符的选区。某些应用不直接暴露选中文本时，App 会临时读取剪贴板内容，然后立即恢复原剪贴板。

## 中文翻译

翻译默认关闭。开启方式：

1. 点击菜单栏图标，选择“开启/关闭翻译”。
2. 第一次开启时输入 DeepSeek API Key。
3. 默认是英译中：划选英文后继续朗读英文，并在鼠标附近显示中文翻译。
4. 在菜单中选择“切换为中译英模式”，或使用偏好设置中自定义的方向快捷键。红灯表示中译英模式。
5. 中译英模式下，划选中文或中英文混合文本时，App 会显示并朗读英文翻译；划选纯英文时，会朗读英文并显示中文翻译。

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

If macOS still refuses to open it after using **Open**, run the following in Terminal after moving the app to the Applications folder:

```sh
xattr -dr com.apple.quarantine "/Applications/划词朗读器.app"
open "/Applications/划词朗读器.app"
```

This removes the download quarantine flag for this app. Use it only when you trust the download source.

## License

MIT License. See [LICENSE](LICENSE).
