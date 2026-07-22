# FinderToolkit

FinderToolkit 是一个 macOS Finder Sync Extension，为 Finder 右键菜单增加常用文件操作：
复制路径、新建文件、计算哈希值、在当前目录打开终端或开发工具。

## 功能

| 功能 | 触发位置 | 说明 |
|------|----------|------|
| 复制路径 | 选中文件、文件夹、空白处、侧边栏、工具栏菜单 | 复制选中项路径；空白处复制当前 Finder 目录路径；多选时按行分隔 |
| 新建文件 | 选中文件夹、文件或目录空白处 | 在目标目录创建 `txt`、`docx`、`xlsx`、`pptx`、`md`、`csv` 文件，自动避开重名 |
| 计算 hash | 选中文件 | 对一个或多个文件流式计算 `CRC32`、`CRC32C`、`MD5`、`SHA1`、`SHA224`、`SHA256`、`SHA384`、`SHA512`、`SM3`；默认启用 `MD5`、`SHA1`、`SHA256` |
| 打开终端 | 选中文件夹、文件或目录空白处 | 在目标目录打开 Terminal |
| 在开发工具中打开 | 选中文件夹、文件或目录空白处 | 可在设置页多选 VS Code、Cursor、IntelliJ IDEA、PyCharm、WebStorm、Android Studio、Xcode，Finder 菜单按选择动态显示 |

## 项目结构

```text
FinderToolkit/
├── FinderToolkit.xcodeproj/
│   └── project.pbxproj
├── FinderToolkit/
│   ├── AppDelegate.swift
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   └── AccentColor.colorset/
│   ├── FinderToolkit.entitlements
│   ├── Info.plist
│   └── main.swift
├── FinderToolkitExtension/
│   ├── FinderSync.swift
│   ├── HashCalculator.swift
│   ├── HashResultWindowController.swift
│   ├── NewFileWindowController.swift
│   ├── FinderToolkitExtension.entitlements
│   └── Info.plist
└── Tools/
    └── generate_app_icon.swift
```

## 环境要求

- macOS 13.0 Ventura 或更高版本
- Xcode 15 或更高版本
- 一个可用于本机开发签名的 Apple Development 证书

工程当前使用 Swift 5，主 App 和 Extension 的最低部署版本均为 macOS 13.0。

## 开发运行

1. 打开项目：

```bash
open FinderToolkit.xcodeproj
```

2. 配置签名：

在 Xcode 中分别选择 `FinderToolkit` 和 `FinderToolkitExtension` target，进入 `Signing & Capabilities`，选择自己的开发者团队。

两个 Bundle Identifier 必须保持父子关系：

```text
主 App:    <your.bundle.prefix>.FinderToolkit
Extension: <your.bundle.prefix>.FinderToolkit.Extension
```

3. 运行：

选择 `FinderToolkit` scheme，按 `Command + R` 运行。

4. 启用扩展：

系统设置 -> 隐私与安全性 -> 扩展 -> Finder 扩展，勾选 `FinderToolkitExtension`。

## 图标

项目包含 `Assets.xcassets/AppIcon.appiconset`，Xcode 会在构建时生成 `AppIcon.icns` 并写入 bundle 的 `CFBundleIconName`。

如需重新生成图标资源：

```bash
swift Tools/generate_app_icon.swift
```

生成后再重新构建 App 即可。

## 打包与安装

下面的命令使用钥匙串内的 Apple Development 证书手动签名。为了避免泄露隐私，不要把真实证书指纹、Team ID、邮箱或个人路径写入仓库；在本机 shell 中用环境变量传入。

1. 查看本机可用的代码签名证书：

```bash
security find-identity -v -p codesigning
```

2. 设置本机环境变量：

```bash
export CERT_SHA1="<Apple Development certificate SHA-1>"
export DEVELOPMENT_TEAM="<Apple Developer Team ID>"
```

3. Release 构建并手动签名：

```bash
xcodebuild \
  -project FinderToolkit.xcodeproj \
  -scheme FinderToolkit \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$CERT_SHA1" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  clean build
```

构建产物位于：

```text
build/DerivedData/Build/Products/Release/FinderToolkit.app
```

4. 验证签名：

```bash
codesign --verify --deep --strict --verbose=2 \
  build/DerivedData/Build/Products/Release/FinderToolkit.app
```

5. 生成 DMG：

```bash
rm -rf dist/dmgroot
mkdir -p dist/dmgroot
ditto build/DerivedData/Build/Products/Release/FinderToolkit.app \
  dist/dmgroot/FinderToolkit.app
ln -s /Applications dist/dmgroot/Applications

hdiutil create \
  -volname FinderToolkit \
  -srcfolder dist/dmgroot \
  -ov \
  -format UDZO \
  FinderToolkit.dmg
```

6. 可选：签名并校验 DMG：

```bash
codesign --force --sign "$CERT_SHA1" --timestamp=none FinderToolkit.dmg
codesign --verify --verbose=2 FinderToolkit.dmg
hdiutil verify FinderToolkit.dmg
```

7. 本机安装：

```bash
ditto build/DerivedData/Build/Products/Release/FinderToolkit.app \
  /Applications/FinderToolkit.app
```

如 Dock 或 Finder 未立即显示新图标，可刷新缓存：

```bash
APP=/Applications/FinderToolkit.app
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

"$LSREGISTER" -f -R -trusted "$APP"
mdimport "$APP" || true
qlmanage -r cache >/dev/null 2>&1 || true
killall iconservicesagent 2>/dev/null || true
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true
```

## 权限说明

Extension 运行在 App Sandbox 中，当前 entitlements 包含：

- `com.apple.security.app-sandbox`
- `com.apple.security.files.user-selected.read-write`
- `com.apple.security.automation.apple-events`
- `com.apple.security.temporary-exception.files.absolute-path.read-write`

Finder Sync 监听根目录 `directoryURLs = [URL(fileURLWithPath: "/")]`，因此能覆盖常规 Finder 窗口。新建文件和打开终端在必要时会通过 Apple Events 回退到 Finder 或 Terminal，因此系统可能会请求自动化权限。

复制路径成功后会发送系统通知；如果用户未授权通知，不影响路径复制本身。

## 调试

查看 Finder Sync Extension 日志：

```bash
log stream --predicate 'process == "FinderToolkitExtension"' --level debug
```

也可以在 Xcode 中选择 Debug -> Attach to Process，附加到 `FinderToolkitExtension`。

Finder Sync Extension 崩溃通常不会弹出明显提示，调试时优先查看 Console.app 或 `log stream`。

## 代码说明

- `FinderSync.swift`：注册 Finder 右键菜单，处理复制路径、新建文件、计算 hash、打开终端。
- `AppDelegate.swift`：主 App 入口，处理 `findertoolkit://` URL scheme，展示 hash 结果，执行需要主 App 协助的文件创建。
- `HashCalculator.swift`：使用 1 MB buffer 流式读取文件，避免大文件一次性读入内存。
- `HashResultWindowController.swift`：展示并复制 hash 计算结果。
- `Tools/generate_app_icon.swift`：生成 AppIcon 所需的多尺寸 PNG。

## 上传到 GitHub 前

建议不要提交以下内容：

- `build/`
- `dist/`
- `DerivedData/`
- `FinderToolkit.dmg`
- 任何真实证书指纹、开发者账号邮箱、Team ID、个人机器路径或本机日志

README 中的打包命令均使用占位符和环境变量，上传前请确认没有把本机真实签名信息写入文档或脚本。
