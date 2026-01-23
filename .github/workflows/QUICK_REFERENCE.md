# Quick Reference: GitHub Actions macOS Build

## 🚀 Quick Start

### Create a Release
```bash
# Update version in pyproject.toml, then:
git tag v0.1.8
git push origin v0.1.8
# ✨ GitHub Actions will build and release automatically
```

### Manual Build
Go to Actions → Build macOS DMG → Run workflow

## 📦 What Gets Built

| Architecture | Runner | Output File |
|--------------|--------|-------------|
| arm64 | macos-14 | `SearchAPIWebUI-{version}-macOS-arm64.dmg` |
| x86_64 | macos-13 | `SearchAPIWebUI-{version}-macOS-x86_64.dmg` |

## 🔄 Trigger Conditions

- ✅ Push to `main` or `dmg` branch
- ✅ Pull request to `main`
- ✅ Tag push (v*)
- ✅ Manual dispatch

## ⚡ Build Time

- First build: ~10-15 minutes
- Cached builds: ~5-8 minutes
- Both architectures run in parallel

## 💰 Cost (Free Tier)

- macOS minutes: 10x multiplier
- Each full build: ~20-30 minutes
- Monthly capacity: ~6-8 builds

## 📥 Download Artifacts

**For commits:**
- Go to Actions → Select run → Artifacts section

**For releases:**
- Go to Releases → Download DMG

## 🧪 Test Locally

```bash
# Build
./scripts/build_macos_app.sh arm64
./scripts/create_dmg.sh arm64

# Test
open dist/SearchAPIWebUI-*-macOS-arm64.dmg
```

## 🐛 Common Issues

**Build fails:**
- Check if `AppIcon.icns` exists in `frontend/public/`
- Verify version format in `pyproject.toml`

**DMG not found:**
- Ensure scripts have execute permissions
- Check build logs for errors

**Wrong version in filename:**
- Version is extracted from `pyproject.toml`
- Format: `version = "0.1.7"`

## 📁 Files

```
.github/workflows/
├── build-macos.yml     # Main workflow
├── README.md          # English docs
└── README_CN.md       # Chinese docs
```

## 🔧 Customization

Edit [build-macos.yml](.github/workflows/build-macos.yml):

- Change trigger branches
- Modify cache strategy
- Add code signing
- Configure notifications

## 🔗 Related

- [BUILD_MACOS.md](../BUILD_MACOS.md) - Local build guide
- [BUILD_SUMMARY.md](../BUILD_SUMMARY.md) - Build system overview
