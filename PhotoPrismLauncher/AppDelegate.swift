//
//  AppDelegate.swift
//  PhotoPrism Launcher
//
//  Copyright (C) 2025 Chris Bansart (@chrisbansart)
//  https://github.com/chrisbansart
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>.
//

import Cocoa

@main
struct PhotoPrismApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

// MARK: - Preferences Keys
struct PreferencesKeys {
    static let picturesFolder = "PicturesFolder"
    static let dataFolder = "DataFolder"
    static let startServerOnLaunch = "StartServerOnLaunch"
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainWindow: NSWindow!
    var viewController: PhotoPrismViewController!
    var preferencesWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("PhotoPrism: applicationDidFinishLaunching")
        
        setupDefaultPreferences()
        setupMainMenu()
        
        viewController = PhotoPrismViewController()
        
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        mainWindow.title = "PhotoPrism"
        mainWindow.contentViewController = viewController
        mainWindow.center()
        mainWindow.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Auto-start server if enabled
        if UserDefaults.standard.bool(forKey: PreferencesKeys.startServerOnLaunch) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.viewController.startServer()
            }
        }
        
        print("PhotoPrism: Window created and should be visible")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        viewController?.stopServer()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Default Preferences
    
    private func setupDefaultPreferences() {
        let defaults = UserDefaults.standard
        
        let defaultPicturesPath = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PhotoPrism").path
        let defaultDataPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PhotoPrism").path
        
        if defaults.string(forKey: PreferencesKeys.picturesFolder) == nil {
            defaults.set(defaultPicturesPath, forKey: PreferencesKeys.picturesFolder)
        }
        if defaults.string(forKey: PreferencesKeys.dataFolder) == nil {
            defaults.set(defaultDataPath, forKey: PreferencesKeys.dataFolder)
        }
        // startServerOnLaunch defaults to false (no need to set explicitly)
    }
    
    // MARK: - Menu Setup
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Application menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // About
        let aboutItem = NSMenuItem(
            title: "About PhotoPrism Launcher",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Preferences
        let preferencesItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.keyEquivalentModifierMask = .command
        appMenu.addItem(preferencesItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Services submenu
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Hide
        let hideItem = NSMenuItem(
            title: "Hide PhotoPrism Launcher",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.keyEquivalentModifierMask = .command
        appMenu.addItem(hideItem)
        
        // Hide Others
        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        // Show All
        let showAllItem = NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(showAllItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit PhotoPrism Launcher",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        appMenu.addItem(quitItem)
        
        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        
        let minimizeItem = NSMenuItem(
            title: "Minimize",
            action: #selector(NSWindow.miniaturize(_:)),
            keyEquivalent: "m"
        )
        minimizeItem.keyEquivalentModifierMask = .command
        windowMenu.addItem(minimizeItem)
        
        let closeItem = NSMenuItem(
            title: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        closeItem.keyEquivalentModifierMask = .command
        windowMenu.addItem(closeItem)
        
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "PhotoPrism Launcher"
        alert.informativeText = "A native macOS launcher for PhotoPrism server."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Visit GitHub")
        
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }
        
        // Add clickable link label
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.alignment = .center
        
        let attributedString = NSMutableAttributedString(string: "Developed by @chrisbansart")
        let linkRange = (attributedString.string as NSString).range(of: "@chrisbansart")
        attributedString.addAttribute(.link, value: "https://github.com/chrisbansart", range: linkRange)
        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: NSRange(location: 0, length: attributedString.length))
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
        
        textView.textStorage?.setAttributedString(attributedString)
        alert.accessoryView = textView
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/chrisbansart") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func showPreferences() {
        if preferencesWindow == nil {
            let preferencesVC = PreferencesViewController()
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 250),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.title = "Preferences"
            preferencesWindow?.contentViewController = preferencesVC
            preferencesWindow?.center()
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - PreferencesViewController
class PreferencesViewController: NSViewController {
    
    private var picturesFolderField: NSTextField!
    private var dataFolderField: NSTextField!
    private var startOnLaunchCheckbox: NSButton!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 250))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPreferences()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Folder Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Pictures Folder
        let picturesLabel = NSTextField(labelWithString: "Pictures Folder:")
        picturesLabel.font = NSFont.systemFont(ofSize: 13)
        picturesLabel.alignment = .right
        picturesLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picturesLabel)
        
        picturesFolderField = NSTextField()
        picturesFolderField.isEditable = false
        picturesFolderField.isSelectable = true
        picturesFolderField.font = NSFont.systemFont(ofSize: 12)
        picturesFolderField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picturesFolderField)
        
        let selectPicturesButton = NSButton(title: "Select…", target: self, action: #selector(selectPicturesFolder))
        selectPicturesButton.bezelStyle = .rounded
        selectPicturesButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectPicturesButton)
        
        // Data Folder
        let dataLabel = NSTextField(labelWithString: "Data Folder:")
        dataLabel.font = NSFont.systemFont(ofSize: 13)
        dataLabel.alignment = .right
        dataLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dataLabel)
        
        dataFolderField = NSTextField()
        dataFolderField.isEditable = false
        dataFolderField.isSelectable = true
        dataFolderField.font = NSFont.systemFont(ofSize: 12)
        dataFolderField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dataFolderField)
        
        let selectDataButton = NSButton(title: "Select…", target: self, action: #selector(selectDataFolder))
        selectDataButton.bezelStyle = .rounded
        selectDataButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectDataButton)
        
        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)
        
        // Startup section title
        let startupTitle = NSTextField(labelWithString: "Startup")
        startupTitle.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        startupTitle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startupTitle)
        
        // Start on launch checkbox
        startOnLaunchCheckbox = NSButton(checkboxWithTitle: "Start server when app launches", target: self, action: #selector(toggleStartOnLaunch))
        startOnLaunchCheckbox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startOnLaunchCheckbox)
        
        // Info label
        let infoLabel = NSTextField(labelWithString: "Note: Restart the server after changing folders.")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = NSColor.secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Pictures row
            picturesLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            picturesLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            picturesLabel.widthAnchor.constraint(equalToConstant: 110),
            
            picturesFolderField.centerYAnchor.constraint(equalTo: picturesLabel.centerYAnchor),
            picturesFolderField.leadingAnchor.constraint(equalTo: picturesLabel.trailingAnchor, constant: 10),
            picturesFolderField.trailingAnchor.constraint(equalTo: selectPicturesButton.leadingAnchor, constant: -10),
            
            selectPicturesButton.centerYAnchor.constraint(equalTo: picturesLabel.centerYAnchor),
            selectPicturesButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            selectPicturesButton.widthAnchor.constraint(equalToConstant: 80),
            
            // Data row
            dataLabel.topAnchor.constraint(equalTo: picturesLabel.bottomAnchor, constant: 15),
            dataLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            dataLabel.widthAnchor.constraint(equalToConstant: 110),
            
            dataFolderField.centerYAnchor.constraint(equalTo: dataLabel.centerYAnchor),
            dataFolderField.leadingAnchor.constraint(equalTo: dataLabel.trailingAnchor, constant: 10),
            dataFolderField.trailingAnchor.constraint(equalTo: selectDataButton.leadingAnchor, constant: -10),
            
            selectDataButton.centerYAnchor.constraint(equalTo: dataLabel.centerYAnchor),
            selectDataButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            selectDataButton.widthAnchor.constraint(equalToConstant: 80),
            
            // Separator
            separator.topAnchor.constraint(equalTo: dataLabel.bottomAnchor, constant: 20),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Startup title
            startupTitle.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 15),
            startupTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Start on launch checkbox
            startOnLaunchCheckbox.topAnchor.constraint(equalTo: startupTitle.bottomAnchor, constant: 12),
            startOnLaunchCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25),
            
            // Info label
            infoLabel.topAnchor.constraint(equalTo: startOnLaunchCheckbox.bottomAnchor, constant: 20),
            infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    private func loadPreferences() {
        let defaults = UserDefaults.standard
        picturesFolderField.stringValue = defaults.string(forKey: PreferencesKeys.picturesFolder) ?? ""
        dataFolderField.stringValue = defaults.string(forKey: PreferencesKeys.dataFolder) ?? ""
        startOnLaunchCheckbox.state = defaults.bool(forKey: PreferencesKeys.startServerOnLaunch) ? .on : .off
    }
    
    @objc private func selectPicturesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Select the folder where your photos will be stored (originals and imports)"
        
        if let currentPath = UserDefaults.standard.string(forKey: PreferencesKeys.picturesFolder) {
            panel.directoryURL = URL(fileURLWithPath: currentPath)
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: PreferencesKeys.picturesFolder)
            picturesFolderField.stringValue = url.path
            createSubfolders(at: url, subfolders: ["originals", "import"])
        }
    }
    
    @objc private func selectDataFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Select the folder where PhotoPrism will store its data (cache, database, etc.)"
        
        if let currentPath = UserDefaults.standard.string(forKey: PreferencesKeys.dataFolder) {
            panel.directoryURL = URL(fileURLWithPath: currentPath)
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: PreferencesKeys.dataFolder)
            dataFolderField.stringValue = url.path
            createSubfolders(at: url, subfolders: ["storage", "storage/config"])
        }
    }
    
    @objc private func toggleStartOnLaunch() {
        UserDefaults.standard.set(startOnLaunchCheckbox.state == .on, forKey: PreferencesKeys.startServerOnLaunch)
    }
    
    private func createSubfolders(at baseURL: URL, subfolders: [String]) {
        for subfolder in subfolders {
            let folderURL = baseURL.appendingPathComponent(subfolder)
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }
}

// MARK: - PhotoPrismViewController
class PhotoPrismViewController: NSViewController {
    
    private var serverProcess: Process?
    private var isServerRunning = false
    
    private var statusLabel: NSTextField!
    private var urlLabel: NSTextField!
    private var statusIndicator: NSView!
    private var startStopButton: NSButton!
    private var openWebUIButton: NSButton!
    private var showLogsButton: NSButton!
    private var openPicturesFolderButton: NSButton!
    private var openDataFolderButton: NSButton!
    
    // Paths (computed from preferences)
    private var appSupportPath: URL {
        let path = UserDefaults.standard.string(forKey: PreferencesKeys.dataFolder)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("PhotoPrism").path
        return URL(fileURLWithPath: path)
    }
    
    private var picturesPath: URL {
        let path = UserDefaults.standard.string(forKey: PreferencesKeys.picturesFolder)
            ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!.appendingPathComponent("PhotoPrism").path
        return URL(fileURLWithPath: path)
    }
    
    private var logPath: URL {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
            .appendingPathComponent("PhotoPrism")
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 450))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createDirectories()
        setupUI()
        updateUI()
    }
    
    private func createDirectories() {
        let directories = [
            // Application Support: storage et config
            appSupportPath,
            appSupportPath.appendingPathComponent("storage"),
            appSupportPath.appendingPathComponent("storage/config"),
            // Pictures: originals et import
            picturesPath,
            picturesPath.appendingPathComponent("originals"),
            picturesPath.appendingPathComponent("import"),
            // Logs
            logPath
        ]
        for dir in directories {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let titleLabel = NSTextField(labelWithString: "PhotoPrism")
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Manage your PhotoPrism server")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Status container with indicator and label
        let statusContainer = NSView()
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusContainer)
        
        statusIndicator = NSView()
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.cornerRadius = 6
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(statusIndicator)
        
        statusLabel = NSTextField(labelWithString: "Server Stopped")
        statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = NSColor.labelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(statusLabel)
        
        // URL label (below status)
        urlLabel = NSTextField(labelWithString: "http://localhost:2342")
        urlLabel.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)
        urlLabel.textColor = NSColor.secondaryLabelColor
        urlLabel.alignment = .center
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(urlLabel)
        
        startStopButton = createButton(title: "Start Server", action: #selector(toggleServer))
        view.addSubview(startStopButton)
        
        openWebUIButton = createButton(title: "Open Web UI", action: #selector(openWebUI))
        view.addSubview(openWebUIButton)
        
        showLogsButton = createButton(title: "Show Logs", action: #selector(showLogs))
        view.addSubview(showLogsButton)
        
        openPicturesFolderButton = createButton(title: "Open Pictures Folder", action: #selector(openPicturesFolder))
        view.addSubview(openPicturesFolderButton)
        
        openDataFolderButton = createButton(title: "Open Data Folder", action: #selector(openDataFolder))
        view.addSubview(openDataFolderButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 25),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            statusContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            statusContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusContainer.heightAnchor.constraint(equalToConstant: 24),
            
            statusIndicator.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor),
            statusIndicator.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            
            urlLabel.topAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: 6),
            urlLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            startStopButton.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 20),
            startStopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startStopButton.widthAnchor.constraint(equalToConstant: 200),
            
            openWebUIButton.topAnchor.constraint(equalTo: startStopButton.bottomAnchor, constant: 10),
            openWebUIButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openWebUIButton.widthAnchor.constraint(equalToConstant: 200),
            
            showLogsButton.topAnchor.constraint(equalTo: openWebUIButton.bottomAnchor, constant: 10),
            showLogsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            showLogsButton.widthAnchor.constraint(equalToConstant: 200),
            
            openPicturesFolderButton.topAnchor.constraint(equalTo: showLogsButton.bottomAnchor, constant: 10),
            openPicturesFolderButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openPicturesFolderButton.widthAnchor.constraint(equalToConstant: 200),
            
            openDataFolderButton.topAnchor.constraint(equalTo: openPicturesFolderButton.bottomAnchor, constant: 10),
            openDataFolderButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openDataFolderButton.widthAnchor.constraint(equalToConstant: 200),
        ])
    }
    
    private func createButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func updateUI() {
        if isServerRunning {
            statusLabel.stringValue = "Server Running"
            statusIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
            startStopButton.title = "Stop Server"
        } else {
            statusLabel.stringValue = "Server Stopped"
            statusIndicator.layer?.backgroundColor = NSColor.systemRed.cgColor
            startStopButton.title = "Start Server"
        }
        openWebUIButton.isEnabled = isServerRunning
    }
    
    private func getServerBinaryPath() -> URL? {
        guard let bundlePath = Bundle.main.executableURL?.deletingLastPathComponent() else {
            return nil
        }
        return bundlePath.appendingPathComponent("photoprism-server")
    }
    
    private func getFrameworksPath() -> URL? {
        return Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks")
    }
    
    private func getAssetsPath() -> URL? {
        return Bundle.main.resourceURL?.appendingPathComponent("assets")
    }
    
    func startServer() {
        guard !isServerRunning else { return }
        
        // Refresh directories in case preferences changed
        createDirectories()
        
        guard let serverPath = getServerBinaryPath(),
              FileManager.default.fileExists(atPath: serverPath.path) else {
            showAlert(title: "Error", message: "PhotoPrism server binary not found.\n\nExpected at: \(getServerBinaryPath()?.path ?? "unknown")")
            return
        }
        
        let process = Process()
        process.executableURL = serverPath
        process.arguments = ["start"]
        
        var environment = ProcessInfo.processInfo.environment

        // Photos dans le dossier Pictures configuré
        environment["PHOTOPRISM_ORIGINALS_PATH"] = picturesPath.appendingPathComponent("originals").path
        environment["PHOTOPRISM_IMPORT_PATH"] = picturesPath.appendingPathComponent("import").path

        // Storage dans le dossier Data configuré
        environment["PHOTOPRISM_STORAGE_PATH"] = appSupportPath.appendingPathComponent("storage").path
        environment["PHOTOPRISM_CONFIG_PATH"] = appSupportPath.appendingPathComponent("storage/config").path

        if let assetsPath = getAssetsPath() {
            environment["PHOTOPRISM_ASSETS_PATH"] = assetsPath.path
        }

        environment["PHOTOPRISM_ADMIN_USER"] = "admin"
        environment["PHOTOPRISM_ADMIN_PASSWORD"] = "photoprism"

        if let frameworksPath = getFrameworksPath() {
            let existingPath = environment["DYLD_LIBRARY_PATH"] ?? ""
            environment["DYLD_LIBRARY_PATH"] = frameworksPath.path + (existingPath.isEmpty ? "" : ":\(existingPath)")
        }

        // Add ExifTool to PATH so PhotoPrism can find it
        if let bundlePath = Bundle.main.executableURL?.deletingLastPathComponent() {
            let existingPath = environment["PATH"] ?? ""
            environment["PATH"] = bundlePath.path + (existingPath.isEmpty ? "" : ":\(existingPath)")
        }
        
        process.environment = environment
        
        let logFile = logPath.appendingPathComponent("photoprism.log")
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        
        if let fileHandle = try? FileHandle(forWritingTo: logFile) {
            fileHandle.seekToEndOfFile()
            let startupMessage = "\n[\(Date())] === PhotoPrism Server Starting ===\n"
            if let data = startupMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            process.standardOutput = fileHandle
            process.standardError = fileHandle
        }
        
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isServerRunning = false
                self?.serverProcess = nil
                self?.updateUI()
            }
        }
        
        do {
            try process.run()
            serverProcess = process
            isServerRunning = true
            updateUI()
            
            // Wait 8 seconds before opening browser to let server fully start
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
                if self?.isServerRunning == true {
                    self?.openWebUI()
                }
            }
        } catch {
            showAlert(title: "Failed to start server", message: error.localizedDescription)
        }
    }
    
func stopServer() {
    guard isServerRunning, let process = serverProcess else { return }
    
    // Try graceful shutdown first using photoprism stop command
    if let serverPath = getServerBinaryPath() {
        let stopProcess = Process()
        stopProcess.executableURL = serverPath
        stopProcess.arguments = ["stop"]
        stopProcess.environment = process.environment
        try? stopProcess.run()
        stopProcess.waitUntilExit()
    }
    
    // If still running, force terminate
    if process.isRunning {
        process.terminate()
    }
    
    isServerRunning = false
    serverProcess = nil
    updateUI()
}
    
    @objc private func toggleServer() {
        if isServerRunning {
            stopServer()
        } else {
            startServer()
        }
    }
    
    @objc private func openWebUI() {
        if let url = URL(string: "http://localhost:2342") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func showLogs() {
        let logFile = logPath.appendingPathComponent("photoprism.log")
        if !FileManager.default.fileExists(atPath: logFile.path) {
            try? "PhotoPrism Log\n".write(to: logFile, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(logFile)
    }
    
    @objc private func openPicturesFolder() {
        NSWorkspace.shared.open(picturesPath)
    }
    
    @objc private func openDataFolder() {
        NSWorkspace.shared.open(appSupportPath)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
