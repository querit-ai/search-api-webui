# 无 Java 文件实现方案

## 目标
在不新增 Java 文件的约束下，实现点击首页链接跳转外部浏览器的功能。

## 成功方案：Python 轮询 + document.title 信号

### 核心思路
使用 JavaScript 修改 `document.title` 作为信号，Python 通过轮询监听 title 变化，检测到特定信号时打开外部浏览器。

### 实现细节

#### 1. JavaScript 层（App.jsx）
```javascript
const handleClick = () => {
    // 通过修改 document.title 向 Python 发送信号
    document.title = 'OPEN_BROWSER:https://www.google.com';
    
    // 备用：直接导航（会被 Python 拦截）
    setTimeout(() => {
        window.location.href = 'https://www.google.com';
    }, 200);
};
```

#### 2. Python 层（main.py）
- 使用 `threading.Timer` 每 0.5 秒轮询一次
- 使用 `@run_on_ui_thread` 确保 WebView 访问在正确线程
- 监听两种信号：
  1. `document.title` 以 `OPEN_BROWSER:` 开头
  2. URL 包含 `google.com`
- 检测到信号后使用 `Intent.ACTION_VIEW` 打开浏览器

#### 3. 关键代码

**监控循环**:
```python
def start_monitor_timer(self):
    if self.monitor_running:
        Timer(0.5, self.monitor_page).start()

def monitor_page(self):
    if not self.monitor_running:
        return
    self.do_check_page()
    self.start_monitor_timer()  # 自动重新调度
```

**检测逻辑**:
```python
@run_on_ui_thread
def do_check_page(self):
    # 检查 title
    title = self.webview.getTitle()
    if title and title.startswith('OPEN_BROWSER:'):
        url = title.replace('OPEN_BROWSER:', '')
        self.open_in_browser(url)
        return
    
    # 检查 URL
    current_url = self.webview.getUrl()
    if 'google.com' in current_url and 'localhost' not in current_url:
        self.open_in_browser(current_url)
```

**打开浏览器**:
```python
@run_on_ui_thread
def open_in_browser(self, url):
    context = Activity.mActivity
    intent = Intent()
    intent.setAction(Intent.ACTION_VIEW)
    intent.setData(Uri.parse(url))
    context.startActivity(intent)
    
    # 导航回 localhost
    Clock.schedule_once(lambda dt: self.reset_webview(), 0.5)
```

### 测试结果
```
✅ PASS - External browser successfully launched!
Chrome focus confirmed: com.android.chrome/org.chromium.chrome.browser.ChromeTabbedActivity
```

### 关键成功因素

1. **threading.Timer 替代 Clock.schedule_interval**
   - 避免了 Kivy Clock 与 Android UI 线程的同步问题
   - Timer 在独立线程运行，通过 `@run_on_ui_thread` 桥接到 UI 线程

2. **双重检测机制**
   - 主信号：`document.title` 修改（响应快）
   - 备用：URL 变化检测（兜底方案）

3. **线程安全**
   - 所有 WebView 操作都使用 `@run_on_ui_thread` 装饰器
   - 避免跨线程访问导致的崩溃

4. **自动重置**
   - 打开浏览器后自动导航回 localhost
   - 重置 title，避免重复触发

### 文件修改

1. **frontend/src/App.jsx**
   - 修改 `handleClick` 方法
   - 添加 `document.title` 信号
   - 保留 `window.location.href` 备用

2. **main.py**
   - 添加 `Timer` 导入
   - 添加监控相关字段和方法
   - 实现 `do_check_page`、`open_in_browser`、`reset_webview`

3. **无需修改 buildozer.spec**（不需要 Java 文件）

### 日志输出
```
[WebView] Started page monitoring with Timer
[Page Monitor] Title changed to: OPEN_BROWSER:https://www.google.com
[Page Monitor] Browser signal detected, opening: https://www.google.com
[Browser] Opening URL: https://www.google.com
[Browser] Intent sent successfully
[Browser] WebView reset to localhost
```

### 对比之前的 Java 方案

| 特性 | Java 方案 | 无 Java 方案 |
|------|-----------|-------------|
| 额外文件 | 需要 CustomWebViewClient.java | 无 |
| 构建配置 | 需要 android.add_src | 无需修改 |
| 响应速度 | 即时（事件驱动） | 0.5秒轮询间隔 |
| 复杂度 | 中等 | 简单 |
| 可维护性 | 需要维护 Java 代码 | 纯 Python |
| 稳定性 | 高 | 高 |

### 优势
- ✅ 纯 Python + JavaScript 实现
- ✅ 无需额外文件或构建配置
- ✅ 代码简单易懂
- ✅ 易于调试和维护

### 劣势
- ⚠️ 轮询有延迟（最多 0.5 秒）
- ⚠️ 持续轮询消耗少量 CPU

## 提交记录
- 基准: 6e41687
- 成功: 1edfaac (Replace Clock with threading.Timer for monitoring)
- 分支: android-back

## 总结
通过 `document.title` 作为 JavaScript 到 Python 的通信桥梁，结合 threading.Timer 轮询和 @run_on_ui_thread 线程同步，成功实现了无 Java 文件的外部浏览器跳转功能。这个方案简洁、可靠，完全满足需求。
