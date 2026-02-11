# 🧪 Android APK 自动点击测试脚本

## 📋 概述

`test_android_click.sh` 是一个自动化测试脚本，用于验证 Android APK 的点击功能。它会自动启动应用、点击屏幕、并验证是否成功跳转到外部浏览器。

## 🎯 功能

该脚本自动执行以下步骤：

1. ✅ **检查应用安装状态** - 确认 APK 已安装
2. ✅ **停止运行中的应用** - 确保干净的测试环境
3. ✅ **获取屏幕分辨率** - 动态计算点击坐标
4. ✅ **启动应用** - 自动启动测试应用
5. ✅ **截图（点击前）** - 保存点击前的屏幕状态
6. ✅ **点击屏幕中心** - 模拟用户点击操作
7. ✅ **截图（点击后）** - 保存点击后的屏幕状态
8. ✅ **验证浏览器启动** - 检查是否成功打开外部浏览器

## 🚀 使用方法

### 前提条件

- Android 模拟器正在运行
- APK 已安装（运行 `./deploy_android.sh` 完成安装）

### 执行测试

```bash
./test_android_click.sh
```

## 📊 测试流程

```
┌─────────────────────────────────────┐
│ 1. 检查应用安装状态                  │
├─────────────────────────────────────┤
│ 2. 停止运行中的应用                  │
├─────────────────────────────────────┤
│ 3. 获取屏幕分辨率                    │
│    - 计算中心点坐标                  │
│    - 计算其他测试点                  │
├─────────────────────────────────────┤
│ 4. 启动应用                          │
│    - 等待 5 秒加载完成               │
├─────────────────────────────────────┤
│ 5. 截图（点击前）                    │
│    → before_click.png                │
├─────────────────────────────────────┤
│ 6. 点击屏幕中心                      │
│    - 执行 adb input tap              │
├─────────────────────────────────────┤
│ 7. 等待 3 秒                         │
│    - 让浏览器有时间启动              │
├─────────────────────────────────────┤
│ 8. 截图（点击后）                    │
│    → after_click.png                 │
├─────────────────────────────────────┤
│ 9. 验证结果                          │
│    - 检查 mCurrentFocus              │
│    - 检查 mResumedActivity           │
│    - 检查浏览器进程                  │
├─────────────────────────────────────┤
│ 10. 显示结果 & 通知                  │
│     - macOS 弹窗通知                 │
│     - 自动打开截图文件夹             │
└─────────────────────────────────────┘
```

## 📸 输出文件

测试完成后，会在 `~/test_android/` 目录生成以下文件：

- **`before_click.png`** - 点击前的屏幕截图
- **`after_click.png`** - 点击后的屏幕截图

脚本会自动打开这个文件夹，方便你查看结果。

## ✅ 成功标准

脚本会根据以下条件判断测试是否成功：

### ✅ PASS（通过）

以下任一条件满足即视为成功：

1. `mCurrentFocus` 包含 `chrome` 或 `browser` 关键词
2. `mResumedActivity` 包含 `chrome` 或 `browser` 关键词
3. 检测到浏览器进程正在运行

### ⚠️ PARTIAL（部分通过）

- 点击成功执行但无法明确确认浏览器启动
- 可能应用使用了内部 WebView

### ❌ FAIL（失败）

- 应用未安装
- 模拟器未运行
- 脚本执行出错

## 📝 示例输出

```bash
$ ./test_android_click.sh

ℹ Checking for running Android emulator...
✓ Found running emulator

===========================================
▶ Android APK Automatic Click Test
===========================================

▶ Step 1/8: Checking if app is installed...
✓ App is installed: ai.querit.searchapiwebui

▶ Step 2/8: Stopping app if running...
✓ App stopped

▶ Step 3/8: Getting screen resolution...
✓ Screen resolution: 1080x1920
ℹ Test points calculated:
ℹ   Center: (540, 960)
ℹ   Top-left quadrant: (270, 480)
ℹ   Bottom-right quadrant: (810, 1440)

▶ Step 4/8: Starting the app...
✓ App started
ℹ Waiting 5 seconds for app to fully load...

▶ Step 5/8: Taking screenshot before click...
✓ Screenshot saved: /Users/username/test_android/before_click.png

▶ Step 6/8: Clicking center of screen...
ℹ Clicking at coordinates: (540, 960)
✓ Click executed
ℹ Waiting 3 seconds for browser to launch...

▶ Step 7/8: Taking screenshot after click...
✓ Screenshot saved: /Users/username/test_android/after_click.png

▶ Step 8/8: Verifying browser launch...
ℹ Current focus: mCurrentFocus=Window{abc123 u0 com.android.chrome/...}
✓ SUCCESS! Browser detected in current focus
ℹ Checking top activity...
ℹ Top activity: mResumedActivity: ActivityRecord{xyz789 u0 com.android.chrome/...}
✓ Browser activity confirmed!

===========================================
▶ Test Complete!
===========================================

Result: ✅ PASS
Message: External browser successfully launched!

Screenshots saved to:
  - Before click: /Users/username/test_android/before_click.png
  - After click:  /Users/username/test_android/after_click.png

To view screenshots:
  open /Users/username/test_android/before_click.png
  open /Users/username/test_android/after_click.png
```

## 🔧 配置选项

脚本顶部可修改以下配置：

```bash
PACKAGE_NAME="ai.querit.searchapiwebui"                      # Android 包名
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb"      # ADB 路径
TEST_DIR="$HOME/test_android"                                 # 截图保存目录
```

## 🐛 故障排查

### Q: "No Android emulator is running"

**解决**：在 Android Studio 中启动一个模拟器

### Q: "App is not installed"

**解决**：先运行 `./deploy_android.sh` 安装 APK

### Q: "Browser not detected in current focus"

**原因**：可能有以下几种情况：
1. 应用使用内部 WebView（不会启动外部浏览器）
2. 点击坐标不准确
3. 应用加载时间过长

**解决**：
- 检查截图确认应用是否正常加载
- 增加等待时间
- 检查应用代码确认使用的是 `window.open(_blank)` 还是内部 WebView

### Q: 点击坐标不准确

**解决**：脚本会自动计算屏幕中心点，但如果需要调整：

```bash
# 修改点击位置（在脚本中）
CENTER_X=$((WIDTH / 2))      # 修改为其他位置
CENTER_Y=$((HEIGHT / 2))     # 修改为其他位置
```

## 🎨 与主流程集成

### 完整部署 + 测试流程

```bash
# 1. 推送代码到 android-back 分支
git push origin android-back

# 2. 自动构建并部署 APK
./deploy_android.sh

# 3. 等待部署完成后，自动测试
./test_android_click.sh
```

### 创建组合脚本

你也可以创建一个组合脚本：

```bash
#!/bin/bash
# deploy_and_test.sh

echo "🚀 Starting deploy and test..."

# Deploy APK
./deploy_android.sh

# Wait a moment for everything to settle
sleep 5

# Run test
./test_android_click.sh

echo "✅ Deploy and test complete!"
```

## 📚 技术细节

### 使用的 ADB 命令

- `adb devices` - 列出连接的设备
- `adb shell pm list packages` - 列出已安装应用
- `adb shell am force-stop` - 强制停止应用
- `adb shell wm size` - 获取屏幕分辨率
- `adb shell monkey -p` - 启动应用
- `adb shell screencap` - 截屏
- `adb pull` - 下载文件
- `adb shell input tap` - 模拟点击
- `adb shell dumpsys window` - 获取窗口信息
- `adb shell dumpsys activity` - 获取活动信息
- `adb shell ps` - 列出运行进程

### 验证逻辑

脚本使用多种方法验证浏览器启动：

1. **检查当前焦点窗口** (`mCurrentFocus`)
   - 最可靠的方法
   - 显示当前用户正在交互的窗口

2. **检查前台活动** (`mResumedActivity`)
   - 显示当前前台运行的 Activity
   - 如果是浏览器，说明跳转成功

3. **检查进程列表** (`ps`)
   - 确认浏览器进程是否在运行
   - 辅助验证方法

## 🎯 为什么整个页面可点击？

为了简化测试，前端代码已修改为**整个页面都可点击**：

```jsx
<div
  onClick={handleClick}
  style={{
    height: '100vh',
    width: '100vw',
    cursor: 'pointer',
    // ... 铺满整个屏幕
  }}
>
  Google
</div>
```

这样做的好处：
- ✅ 无需精确计算链接坐标
- ✅ 点击屏幕任何位置都会跳转
- ✅ 测试更稳定可靠
- ✅ 适配不同屏幕尺寸

## 📄 许可证

MIT License

---

**祝测试顺利！🧪**
