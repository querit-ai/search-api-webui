# -*- mode: python ; coding: utf-8 -*-

'''
PyInstaller spec file for Search API WebUI Windows app.
'''

import os
from pathlib import Path

# Get project paths
project_root = Path(SPECPATH).resolve()
app_module = project_root / 'search_api_webui'
frontend_dist = project_root / 'frontend' / 'dist'

# Check if frontend is built
if not frontend_dist.exists():
    raise FileNotFoundError(
        f'Frontend build not found at {frontend_dist}. '
        'Please build frontend first: cd frontend && npm install && npm run build'
    )

# Collect data files
datas = [
    (str(app_module / 'providers.yaml'), '.'),
    (str(frontend_dist), 'static'),
]

# Hidden imports that PyInstaller might miss
hiddenimports = [
    'flask',
    'flask_cors',
    'requests',
    'yaml',
    'jmespath',
    'webview',
    'webview.platforms.winforms',
    'clr',
    'pythonnet',
    'search_api_webui.providers',
]

# Analysis
a = Analysis(
    [str(app_module / 'app.py')],
    pathex=[str(project_root)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
)

# PYZ archive
pyz = PYZ(a.pure, a.zipped_data, cipher=None)

# EXE
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='SearchAPIWebUI',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,  # No console window for GUI app
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,  # Auto-detect architecture
    codesign_identity=None,
    entitlements_file=None,
    icon=str(project_root / 'frontend' / 'public' / 'AppIcon.ico'),
)

# COLLECT - onedir mode (recommended for Windows)
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='SearchAPIWebUI',
)
