# Tun2ProxyGUI

A modern macOS graphical user interface for [tun2proxy](https://github.com/tun2proxy/tun2proxy), allowing you to easily route your system traffic through a SOCKS5 or HTTP proxy using a TUN interface.

<img width="481" height="680" alt="image" src="https://github.com/user-attachments/assets/ff98cdfa-60da-40e6-ae11-3b448f957522" />
<img width="481" height="681" alt="image" src="https://github.com/user-attachments/assets/389e2dd8-a509-461a-8516-6bc6ba5e34bb" />


## Features

- **🚀 Native macOS Experience**: Built with SwiftUI for a sleek, modern, and responsive user interface.
- **⚙️ Easy Configuration**: Simple fields to configure your proxy type (SOCKS5, HTTP), host, port, and credentials.
- **🔍 Auto-Detect Binary**: Automatically detects the `tun2proxy-bin` executable if installed via Homebrew or bundled with the app.
- **📱 App Listener Integration**: Scans for active network listeners (using `lsof`) and allows you to bind the proxy to a specific application's port with a single click. This is perfect for quickly routing traffic through tools like SSH tunnels or local proxy services.
- **🛡️ Privilege Management**: Two-way approach to handle TUN interface permissions:
  - **Authorize**: Automatically sets the `setuid root` bit on the binary so it can run with elevated privileges without password prompts.
  - **Setup**: Copies a manual command to the clipboard for users who prefer to run the initial configuration via Terminal.
- **📋 Real-time Logging**: View detailed logs from the underlying binary directly in the app, with separate formatting for `stdout` and `stderr`.
- **⚡ Quick Actions**: Copy setup commands to your clipboard or run a binary test with one click.
- **🌓 Dark Mode Support**: Fully compatible with macOS light and dark themes.

## Prerequisites

- **tun2proxy-bin**: The application can use its own bundled version of `tun2proxy-bin` automatically. However, you can also install it manually (e.g., via Homebrew) and point the app to your custom binary path:
  ```bash
  brew install tun2proxy
  ```
- **macOS 13.0+**: The application is designed for modern macOS versions.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mahdiesbati/Tun2ProxyGui.git
   ```
2. Open `Tun2ProxyGui.xcodeproj` in Xcode.
3. Build and run the project.

## Usage

1. **Authorize Binary**: On the first run, click "Authorize" to give the binary the necessary permissions to create a TUN interface.
2. **Configure Proxy**: Enter your proxy details in the Status tab.
3. **Start**: Click "Start" to begin routing traffic.
4. **Logs**: Check the Logs tab for detailed information about the connection.
5. **Apps**: Use the Apps tab to find local services listening on ports and quickly use them as your proxy source.

## Project Structure

- `Tun2ProxyGui/Models`: Data structures for log entries, app listeners, and proxy types.
- `Tun2ProxyGui/Services`: Core logic for process management, binary authorization, and application scanning.
- `Tun2ProxyGui/ViewModels`: State management for the UI.
- `Tun2ProxyGui/Views`: SwiftUI components and tab-based navigation.


## Other screenshots

<img width="481" height="681" alt="image" src="https://github.com/user-attachments/assets/ff560afa-5ca1-4733-9f8a-530707764b4a" />

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
