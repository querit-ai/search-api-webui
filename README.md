# Search API WebUI

A lightweight, cross-platform WebUI and native Mac App for testing, comparing, and visualizing Search APIs (Querit, You, Tavily, Exa, Baidu, Brave, Parallel, Serper etc.).

![Screenshot](docs/images/screenshot.webp)

## Features

* **Search**: Support for multiple search providers including:
  - [Querit.ai](https://www.querit.ai/en/docs/reference/post)
  - [You.com](https://docs.you.com/api-reference/search/v1-search)
  - [Tavily.com](https://docs.tavily.com/documentation/api-reference/introduction)
  - [Exa.ai](https://docs.exa.ai/reference/search)
  - [Parallel.ai](https://docs.parallel.ai/api-reference/search-beta/search)
  - [Baidu.com](https://cloud.baidu.com/doc/WENXINWORKSHOP/s/4lilb2lpf)
  - [Brave.com](https://api-dashboard.search.brave.com/documentation)
  - [Serper.dev](https://serper.dev) - Google Search API
  - And generic Search APIs via configuration
* **API Arena**: Compare two search providers side-by-side to benchmark latency, payload size, and result relevance.
* **Performance Metrics**: Real-time display of request latency and payload size.
* **Visual Rendering**: Renders standard search results (Title, Snippet, URL) in a clean card layout.
* **Configurable**: Easy-to-edit providers.yaml to add or modify search providers.
* **Secure**: API Keys are stored locally in your $HOME folder.
## Installation

### macOS Installation

For macOS users, you can download the DMG installer from the GitHub Releases page:

1. Visit the [Releases page](https://github.com/querit-ai/search-api-webui/releases)
2. Download the appropriate DMG file for your Mac architecture:
   - **Apple Silicon (M1/M2/M3)**: `SearchAPIWebUI-<version>-macOS-arm64.dmg`
   - **Intel Macs**: `SearchAPIWebUI-<version>-macOS-x86_64.dmg`
3. Open the DMG file and drag `SearchAPIWebUI` to your Applications folder
4. Launch `SearchAPIWebUI` from Applications

**Note**: Since the application is not code-signed, macOS may block it on first launch. To allow it to run:
- Go to **System Settings** > **Privacy & Security**
- Look for the message about `SearchAPIWebUI` being blocked
- Click **Open Anyway** to allow the application to run

### Windows Installation

For Windows users, you can download the installer from the GitHub Releases page:

1. Visit the [Releases page](https://github.com/querit-ai/search-api-webui/releases)
2. Download the appropriate Setup file for your Windows system:
   - **64-bit Windows** (most common): `SearchAPIWebUI-<version>-Windows-x64-Setup.exe`
   - **32-bit Windows** (legacy): `SearchAPIWebUI-<version>-Windows-x86-Setup.exe`
3. Run the Setup executable and follow the installation wizard
4. Launch `SearchAPIWebUI` from the Start Menu or Desktop shortcut

**Note**:
- The installer requires .NET Framework 4.5 or later (usually pre-installed on Windows 8+)
- Windows Defender SmartScreen may show a warning for unsigned applications. Click "More info" → "Run anyway" to proceed

### Prerequisites

Python 3.7+

### Install via Pip

Use this method if you just want to run the tool without modifying the code.

```
pip install search-api-webui
```

### Run the Server

```
search-api-webui
```

## Development

Use this method if you want to contribute to the code or build from source.

### Prerequisites

* Python 3.7+
* Node.js & npm (for building the frontend)

### Quick Start with Makefile

**Clone the repository**

```bash
git clone https://github.com/querit-ai/search-api-webui.git
cd search-api-webui
```

**Development Mode** (with hot reload)

```bash
make dev
```

This will:
- Set up Python virtual environment and install dependencies
- Install frontend dependencies (node_modules)
- Start Flask backend on http://localhost:8889 with hot reload
- Start Vite frontend dev server on http://localhost:5173
- Automatically open your browser
- Enable hot module replacement for instant updates

**Build Python Wheel**

```bash
make              # or 'make all'
```

**Build macOS DMG** (macOS only)

```bash
make dmg          # Builds DMG for your current architecture (incl. .app build)
make build-app    # Build only the .app bundle (without DMG)
# Override architecture if needed:
make ARCH=arm64 dmg   # Force Apple Silicon build
make ARCH=x86_64 dmg  # Force Intel build (requires x86_64 Python)
```

### Manual Setup

If you prefer not to use Makefile:

**Build Frontend**

```bash
cd frontend
npm install
npm run build
cd ..
```

**Install search-api-webui (Editable Mode)**

```bash
pip install -e .
```

**Run the Server**

```bash
python -m search_api_webui.app
```

### Available Make Commands

```bash
make              # Build Python wheel package (default)
make dev          # Start development servers with hot reload
make dmg          # Build macOS DMG for current architecture
make clean        # Clean build artifacts
make clean-all    # Clean everything including virtual environment
make help         # Show all available commands
```

## Configuration

### Add API Keys

Open the WebUI settings page (click the gear icon). Enter your API Key for the selected provider (e.g., Querit). Keys are saved locally in $HOME/.search-api-webui/config.json.

### Add New Providers

Edit providers.yaml in the root directory to add custom API endpoints. The system uses JMESPath to map JSON responses to the UI.

```
my_custom_search:
  url: "https://api.example.com/search"
  method: "POST"
  headers:
    "Accept": "application/json"
    "Authorization": "Bearer {api_key}"
    "Content-Type": "application/json"
  payload:
    query: "{query}"
    count: "{limit}"
  response_mapping:
    root_path: "results.result"
    server_latency_path: "took"
    fields:
      url: "url"
      title: "title"
      site_name: "site_name"
      site_icon: "site_icon"
      page_age: "page_age"
```

## License

MIT License. See LICENSE for details.
