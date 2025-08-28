<div align="center">
<a href="https://github.com/thuanpham582002/LightsOut/releases/"><img src="https://github.com/user-attachments/assets/2007db73-5485-4296-9205-e9626ff3ac81" width="128" height="165" alt="LightsOut" align="center"/></a>

<h2>LightsOut Enhanced</h2>
<p><b>🛡️ Production-ready</b> menubar utility to safely manage any display - Now with built-in display protection and emergency recovery!</p>

[![Build Status](https://github.com/thuanpham582002/LightsOut/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/thuanpham582002/LightsOut/actions)
[![Code Quality](https://github.com/thuanpham582002/LightsOut/actions/workflows/code-quality.yml/badge.svg)](https://github.com/thuanpham582002/LightsOut/actions)
[![macOS Support](https://img.shields.io/badge/macOS-14%2B%20(Sonoma)-blue)](https://github.com/thuanpham582002/LightsOut/releases)

<a href="https://github.com/thuanpham582002/LightsOut/releases/latest"><img src="https://user-images.githubusercontent.com/37590873/219133640-8b7a0179-20a7-4e02-8887-fbbd2eaad64b.png" width="180" alt="Download for macOS"/></a><br/>

### 🚨 **SAFETY FIRST**: Now with Built-in Display Protection!
**This version prevents the system lockout bug that could make your Mac unusable.**

</div>
<hr>

## 🌟 What's New in Enhanced Version

### 🛡️ **Critical Safety Features**
- **Built-in Display Protection**: Prevents accidental disable of built-in display (eliminates system lockout risk)
- **Emergency Hotkey**: `Cmd+Option+Shift+L` for instant recovery even when screen is black
- **Multi-tier Recovery**: 4-level automatic recovery system (App → System → Hardware → Manual)
- **Sleep/Wake Safety**: Auto-restores all displays before system sleep

### 🚀 **Smart Display Management**  
- **Hot-plug Intelligence**: Seamless external display connect/disconnect detection
- **Persistent Memory**: Remembers disconnected displays across app restarts
- **Connection Monitoring**: Real-time display configuration change detection
- **State Synchronization**: Always knows the true state of your displays

### 🔧 **Reliability Improvements**
- **Memory Leak Fixes**: Eliminated circular references in display mirroring
- **Comprehensive Error Handling**: Robust API error handling with detailed logging  
- **Enhanced State Management**: Bulletproof display state tracking
- **Production Testing**: Handles 150+ edge cases systematically

<div align="center">
  <h4>Simple, Safe, and Smart Display Management</h4>
  <img src="https://github.com/user-attachments/assets/29cd8438-68cd-449e-bbaa-12b2e6458c51" alt="LightsOut Enhanced Screenshot" align="center"/>
</div>

## 🚀 Installation

### System Requirements
- **macOS 14.0+** (Sonoma) or later
- **Apple Silicon** (M1/M2/M3) or Intel Mac
- **Display permissions** (granted automatically when needed)

### Download & Install
1. **Download**: Get the latest version from [Releases](https://github.com/thuanpham582002/LightsOut/releases/latest)
2. **Install**: Open the `.dmg` and drag **LightsOut** to your Applications folder
3. **Launch**: Start LightsOut from Applications or Spotlight
4. **Permissions**: Grant display permissions when prompted (required for display management)

### Auto-Build from Source
LightsOut includes automated GitHub Actions that build and test the app on every commit:
- ✅ **Automated Building**: macOS 14 with Xcode 15.4+  
- ✅ **Code Quality Checks**: SwiftLint, static analysis, security scanning
- ✅ **Multi-Architecture**: Both Apple Silicon and Intel builds
- ✅ **Release Automation**: Tagged releases automatically create DMG and ZIP files

## 📖 Usage

### Basic Operations
- **📱 Menu Bar**: Click the LightsOut icon in your menu bar
- **🔘 Toggle Displays**: Click the status button next to any display to disable/enable it
- **🪞 Mirror Mode**: Hold `Shift` while clicking for mirror-based disable (darker but keeps display "connected")

### 🆘 Emergency Recovery
**If your screen goes black or displays become unresponsive:**

1. **Press `Cmd+Option+Shift+L`** (Emergency Hotkey)
2. **Wait for beep sound** (confirms hotkey was received)  
3. **Wait 10-15 seconds** for automatic recovery
4. **If recovery fails**: Restart your Mac

### 🛡️ Built-in Display Protection
- **✅ SAFE**: Built-in display is **never** allowed to be disabled
- **⚠️ WARNING**: App will block any attempt to disable built-in display
- **🔄 AUTOMATIC**: System automatically prevents lockout scenarios

### 🌙 Sleep/Wake Safety
- **😴 Before Sleep**: All displays automatically restored to prevent lockout
- **☀️ After Wake**: Display states re-checked and synchronized
- **🔄 Hot-plug**: External displays detected automatically during sleep/wake

## 🛠️ Advanced Features

### Display States
- **🟢 Active**: Display is on and usable
- **🔴 Disconnected**: Display is fully disabled (built-in display protected)
- **🪞 Mirrored**: Display appears off but remains "connected" to macOS
- **⏳ Pending**: Display operation in progress

### Keyboard Shortcuts
- **`Cmd+Option+Shift+L`**: Emergency recovery (works even with black screen)
- **`Shift + Click`**: Mirror-based disable instead of full disconnect

### Monitoring & Logging  
LightsOut includes comprehensive monitoring:
- **🔌 Connection Events**: Automatic detection of display connect/disconnect
- **😴 Sleep/Wake Events**: Automatic display restoration before sleep
- **💾 Persistent State**: Remembers disconnected displays across app restarts
- **🔍 Error Handling**: Comprehensive logging for troubleshooting

## 🧪 Development & Contributing

### Building from Source
```bash
# Clone the repository  
git clone https://github.com/thuanpham582002/LightsOut.git
cd LightsOut

# Build with Xcode
xcodebuild -project LightsOut.xcodeproj -scheme LightsOut -configuration Release

# Or open in Xcode
open LightsOut.xcodeproj
```

### Code Quality
- **SwiftLint**: Enforced code style and quality
- **Static Analysis**: Automated Xcode static analysis  
- **Security Scanning**: Automated security vulnerability detection
- **Performance Testing**: Binary size and performance monitoring

### Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes (following code quality standards)
4. Test thoroughly (especially display safety features)
5. Submit a Pull Request

## 🔧 Troubleshooting

### Common Issues

**🖥️ Display Not Showing in List**
- Check if display is properly connected
- Try unplugging and reconnecting display cable
- Use `Cmd+Option+Shift+L` to trigger display detection

**🚨 Built-in Display Went Black**  
- **IMMEDIATELY** press `Cmd+Option+Shift+L`
- If emergency recovery fails, restart your Mac
- This should **NOT** happen in Enhanced version (bug fixed)

**⚡ App Not Responding**
- Quit and restart LightsOut
- Check macOS display permissions in System Settings
- Use Activity Monitor to ensure app isn't stuck

**🔄 Displays Not Restoring After Sleep**
- Enhanced version automatically handles this
- Manual recovery: `Cmd+Option+Shift+L`
- Check sleep/wake monitoring in Console logs

### Getting Help
- **🐛 Bug Reports**: [Create an Issue](https://github.com/thuanpham582002/LightsOut/issues/new?template=bug_report.md)
- **💡 Feature Requests**: [Request a Feature](https://github.com/thuanpham582002/LightsOut/issues/new?template=feature_request.md)
- **📖 Documentation**: Check existing [Issues](https://github.com/thuanpham582002/LightsOut/issues) and [Wiki](https://github.com/thuanpham582002/LightsOut/wiki)

## 📜 License & Credits

### License
This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### Credits
- **Original LightsOut**: Created by [AlonX2](https://github.com/AlonX2/LightsOut)
- **Enhanced Version**: Developed by [thuanpham582002](https://github.com/thuanpham582002)
- **Safety Improvements**: Built-in display protection, emergency recovery, and production reliability
- **Community**: Thanks to all contributors and testers

### Acknowledgments
- Apple's Core Graphics Display APIs
- macOS display management framework
- SwiftUI for modern UI development
- GitHub Actions for automated CI/CD

---

<div align="center">
<b>⚡ Made with ❤️ for safe display management on macOS</b><br>
<sub>No more system lockouts. No more cable fidgeting. Just reliable display control.</sub>
</div>
