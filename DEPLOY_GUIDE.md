# 🚀 Android APK 自动部署系统

这是一套完整的 Android APK 自动化构建、下载和安装工具，让你在每次 push 到 `android-back` 分支后，只需一个命令就能自动完成整个部署流程。

## 📋 目录

- [快速开始](#快速开始)
- [系统要求](#系统要求)
- [首次设置](#首次设置)
- [使用流程](#使用流程)
- [脚本说明](#脚本说明)
- [常见问题](#常见问题)

---

## 🎯 快速开始

```bash
# 1. 测试依赖是否就绪
./test_deploy_deps.sh

# 2. 执行自动部署
./deploy_android.sh
```

---

## 💻 系统要求

- **操作系统**: macOS (脚本使用 osascript 发送通知)
- **GitHub CLI**: 用于触发 workflow 和下载 artifacts
- **Android Studio**: 需要 ADB 工具
- **Android Emulator**: 需要运行中的模拟器

---

## 🔧 首次设置

### 1. 安装 GitHub CLI

```bash
brew install gh
```

### 2. 认证 GitHub CLI

```bash
gh auth login
```

按照提示完成认证，确保选择以下选项：
- Protocol: HTTPS
- Authenticate: Login with a web browser
- Scopes: 确保包含 `repo` 和 `workflow`

### 3. 验证 Android Studio 和 ADB

确保 ADB 在以下路径：
```bash
~/Library/Android/sdk/platform-tools/adb
```

验证 ADB：
```bash
~/Library/Android/sdk/platform-tools/adb version
```

### 4. 运行依赖检查

```bash
./test_deploy_deps.sh
```

如果所有检查都通过（显示绿色 ✅），说明环境已准备就绪！

---

## 📱 使用流程

### 完整工作流程

1. **修改代码** - 在 `android-back` 分支上修改代码
2. **提交并推送**:
   ```bash
   git add .
   git commit -m "your changes"
   git push origin android-back
   ```
3. **运行部署脚本**:
   ```bash
   ./deploy_android.sh
   ```
4. **等待完成** - 脚本会自动：
   - 触发 GitHub Actions 构建
   - 等待构建完成（5-10 分钟）
   - 下载 APK 到本地
   - 卸载旧版本
   - 安装新版本
   - 显示完成通知

---

## 📜 脚本说明

### `deploy_android.sh` - 主部署脚本

**功能**：自动化整个 APK 部署流程

**步骤**：
1. ✅ 触发 GitHub workflow 构建 APK
2. ✅ 清空 `~/test_android` 目录
3. ✅ 下载构建好的 APK artifact
4. ✅ 解压 ZIP 获取 APK 文件
5. ✅ 卸载模拟器上的旧版本 (`ai.querit.searchapiwebui`)
6. ✅ 安装新版本到模拟器
7. ✅ 显示 macOS 弹窗通知完成

**特点**：
- 🎨 彩色输出，易于跟踪进度
- 🔔 每个关键步骤都有 macOS 通知
- 🛡️ 健壮的错误处理
- 🚀 自动启动应用（可选）
- 🧹 自动清理临时文件

**使用**：
```bash
./deploy_android.sh
```

### `test_deploy_deps.sh` - 依赖检查脚本

**功能**：验证所有必需的工具和权限

**检查项**：
1. GitHub CLI 是否安装
2. GitHub CLI 是否已认证
3. ADB 是否存在
4. 是否有运行中的模拟器（警告，非必需）
5. 测试目录状态
6. GitHub 仓库访问权限
7. Workflow 文件是否存在

**使用**：
```bash
./test_deploy_deps.sh
```

---

## 📊 执行示例

### 成功执行的输出

```bash
$ ./deploy_android.sh

ℹ Step 1/7: Triggering GitHub workflow...
✓ Workflow triggered successfully
ℹ Waiting for workflow to start (10 seconds)...
ℹ Getting latest workflow run...
✓ Workflow run ID: 12345678
ℹ Waiting for workflow to complete (this may take several minutes)...
..........
✓ Workflow completed successfully

ℹ Step 2/7: Cleaning local test directory...
✓ Cleaned /Users/username/test_android
✓ Created /Users/username/test_android

ℹ Step 3/7: Downloading APK artifact...
ℹ Fetching artifact list...
ℹ Downloading artifact: SearchAPIWebUI-0.2.1-android
✓ Artifact downloaded successfully

ℹ Step 4/7: Extracting APK from artifact...
✓ APK extracted: SearchAPIWebUI-0.2.1-android-debug.apk
ℹ APK location: /Users/username/test_android/SearchAPIWebUI-0.2.1-android-debug.apk

ℹ Checking for running Android emulator...
✓ Found running emulator

ℹ Step 5/7: Uninstalling existing APK from emulator...
ℹ App is installed, uninstalling...
✓ App uninstalled successfully

ℹ Step 6/7: Installing new APK to emulator...
✓ APK installed successfully

ℹ Step 7/7: Deployment completed!
=========================================
✓ Android APK Deploy Completed Successfully
=========================================
✓ Package: ai.querit.searchapiwebui
✓ APK Location: /Users/username/test_android/SearchAPIWebUI-0.2.1-android-debug.apk
=========================================

ℹ Would you like to launch the app now? (The app will auto-launch after 5 seconds)
ℹ Press Ctrl+C to skip...
ℹ Launching app...
✓ App launched successfully
```

### macOS 通知

在执行过程中，你会收到以下通知：
- 🔄 Step 1/7: Workflow triggered
- 🏗️ Building: APK build in progress...
- 🧹 Step 2/7: Test directory cleaned
- 📥 Step 3/7: APK downloaded
- 📦 Step 4/7: APK extracted
- 🗑️ Step 5/7: Old app removed
- 📲 Step 6/7: APK installed
- 🎉 最终弹窗：部署完成详情

---

## ❓ 常见问题

### Q1: "GitHub CLI (gh) is not installed"

**解决**：
```bash
brew install gh
```

### Q2: "GitHub CLI is not authenticated"

**解决**：
```bash
gh auth login
```
按照提示完成认证。

### Q3: "ADB not found"

**解决**：
1. 确保 Android Studio 已安装
2. 打开 Android Studio → Settings → Appearance & Behavior → System Settings → Android SDK
3. 确认 SDK 路径为：`~/Library/Android/sdk`
4. 如果路径不同，修改 `deploy_android.sh` 中的 `ADB_PATH` 变量

### Q4: "No Android emulator is running"

**解决**：
1. 打开 Android Studio
2. Tools → Device Manager
3. 启动一个模拟器（或创建新模拟器）
4. 等待模拟器完全启动后再运行脚本

### Q5: Workflow 构建失败

**现象**：脚本会自动打开浏览器显示失败的 workflow run

**解决**：
1. 检查 workflow 日志中的错误信息
2. 常见原因：
   - frontend 构建失败 → 检查 Node.js 依赖
   - buildozer 构建失败 → 检查 buildozer.spec 配置
   - 权限问题 → 确认 GitHub token 有 workflow 权限

### Q6: APK 下载后找不到文件

**解决**：
1. 检查 `~/test_android` 目录
2. 确认 artifact 名称匹配（应该是 `SearchAPIWebUI-*-android`）
3. 如果名称不匹配，修改 `deploy_android.sh` 中的 `ARTIFACT_NAME` 查找逻辑

### Q7: 安装到模拟器失败

**解决**：
1. 确认模拟器正在运行：
   ```bash
   ~/Library/Android/sdk/platform-tools/adb devices
   ```
2. 手动测试安装：
   ```bash
   ~/Library/Android/sdk/platform-tools/adb install ~/test_android/*.apk
   ```
3. 如果提示 "INSTALL_FAILED_UPDATE_INCOMPATIBLE"，先手动卸载：
   ```bash
   ~/Library/Android/sdk/platform-tools/adb uninstall ai.querit.searchapiwebui
   ```

### Q8: 想修改配置怎么办？

**可修改的配置**（在 `deploy_android.sh` 顶部）：

```bash
GITHUB_REPO="querit-ai/search-api-webui"     # GitHub 仓库
BRANCH="android-back"                         # 目标分支
WORKFLOW_FILE="build-release.yml"             # Workflow 文件名
TEST_DIR="$HOME/test_android"                 # 下载目录
PACKAGE_NAME="ai.querit.searchapiwebui"      # Android 包名
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb"  # ADB 路径
```

---

## 🎨 进阶使用

### 在不同分支上使用

修改 `deploy_android.sh` 中的 `BRANCH` 变量：
```bash
BRANCH="your-branch-name"
```

### 自动化提交和部署

创建一个 Git hook 或 alias：
```bash
# 在 ~/.zshrc 或 ~/.bashrc 中添加
alias deploy-android="git push origin android-back && ./deploy_android.sh"
```

然后只需：
```bash
deploy-android
```

### 跳过应用启动

修改脚本末尾，注释掉启动逻辑或按 Ctrl+C 跳过。

---

## 📝 注意事项

1. **网络连接**：确保网络稳定，下载 artifact 需要良好的网络
2. **构建时间**：GitHub Actions 构建通常需要 5-10 分钟
3. **并发限制**：同一时间只能有一个 workflow 运行
4. **存储空间**：每次部署会下载约 50MB 的 APK
5. **清理**：脚本会自动清理旧文件，无需手动清理

---

## 🛠️ 故障排查步骤

1. **运行依赖检查**：
   ```bash
   ./test_deploy_deps.sh
   ```

2. **检查 GitHub CLI 权限**：
   ```bash
   gh auth status
   ```
   确保有 `workflow` scope

3. **手动触发 workflow**：
   ```bash
   gh workflow run build-release.yml --repo querit-ai/search-api-webui --ref android-back
   ```

4. **查看最近的 workflow runs**：
   ```bash
   gh run list --repo querit-ai/search-api-webui --workflow build-release.yml --limit 5
   ```

5. **检查模拟器连接**：
   ```bash
   ~/Library/Android/sdk/platform-tools/adb devices
   ```

---

## 📚 相关文档

- [GitHub CLI 文档](https://cli.github.com/manual/)
- [ADB 文档](https://developer.android.com/tools/adb)
- [Buildozer 文档](https://buildozer.readthedocs.io/)

---

## 📄 许可证

MIT License

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**祝部署顺利！🚀**
