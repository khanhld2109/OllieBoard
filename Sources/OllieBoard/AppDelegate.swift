import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let world = World()
    private var statusItem: NSStatusItem!
    private let enabledKey = "enabledCharacters"

    private var enabledIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: enabledKey) ?? ["nezuko"]) }
        set { UserDefaults.standard.set(Array(newValue), forKey: enabledKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "OllieBoard")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        world.start()
        for character in allCharacters where enabledIDs.contains(character.id) {
            world.setEnabled(character, true)
        }
    }

    // Rebuilt every time it opens so warnings reflect Finder's current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: "Nhân vật", action: nil, keyEquivalent: "").isEnabled = false
        for group in characterGroups(#selector(toggleCharacter(_:)), isOn: { self.world.pets[$0.id] != nil }) {
            menu.addItem(group)
        }
        menu.addItem(withTitle: "    Chuột phải vào nhân vật để dùng kỹ năng đặc biệt", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(withTitle: "Phòng chơi", action: nil, keyEquivalent: "").submenu = roomMenu()

        let languageItem = menu.addItem(withTitle: "Ngôn ngữ / Language / 言語", action: nil, keyEquivalent: "")
        let languages = NSMenu()
        for language in Language.allCases {
            let item = languages.addItem(withTitle: language.title, action: #selector(setLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == Language.current ? .on : .off
        }
        languageItem.submenu = languages

        menu.addItem(.separator())
        let agentsItem = menu.addItem(withTitle: "Nhân vật cho AI agent", action: #selector(toggleAgents), keyEquivalent: "")
        agentsItem.target = self
        agentsItem.state = world.agentsEnabled ? .on : .off
        if world.agentsEnabled {
            let kinds = NSMenu()
            for kind in AgentKind.allCases {
                let item = kinds.addItem(withTitle: kind.title, action: #selector(toggleAgentKind(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = kind.rawValue
                item.state = world.disabledAgentKinds.contains(kind) ? .off : .on
            }
            menu.addItem(withTitle: "    Chọn agent", action: nil, keyEquivalent: "").submenu = kinds
            for pet in world.agentPets.values.sorted(by: { ($0.tag ?? "") < ($1.tag ?? "") }) {
                guard let agent = pet.agent else { continue }
                let state: String
                switch agent.state {
                case .idle: state = "rảnh"
                case .working: state = "đang làm"
                case .done: state = "xong, chờ bạn"
                case .needsInput: state = "cần bạn duyệt"
                }
                menu.addItem(withTitle: "    \(pet.tag ?? agent.kind.title) — \(state)", action: nil, keyEquivalent: "").isEnabled = false
            }
            if ClaudeHooks.isInstalled {
                menu.addItem(withTitle: "    ✓ Đã cài hook trạng thái cho Claude Code", action: nil, keyEquivalent: "").isEnabled = false
            } else {
                addItem(menu, "    Cài hook trạng thái cho Claude Code…", #selector(installClaudeHooks))
            }
        }

        menu.addItem(.separator())
        addItem(menu, "Đá một icon ngay", #selector(kickNow))
        addItem(menu, "Dọn dẹp Desktop", #selector(arrangeNow))

        if let error = world.desktop.lastError {
            menu.addItem(.separator())
            let warn = menu.addItem(withTitle: "⚠️ Chưa điều khiển được Finder", action: nil, keyEquivalent: "")
            warn.toolTip = error
            warn.isEnabled = false
            addItem(menu, "Mở cài đặt quyền Automation…", #selector(openAutomationSettings))
        } else if world.desktop.iconsArePinned {
            menu.addItem(.separator())
            menu.addItem(withTitle: "⚠️ Desktop đang bật Sort By — icon bị khoá", action: nil, keyEquivalent: "").isEnabled = false
            addItem(menu, "Tắt Sort By trên Desktop", #selector(disableAutoArrange))
        }

        menu.addItem(.separator())
        addItem(menu, "Thoát OllieBoard", #selector(quit), key: "q")
    }

    private func roomMenu() -> NSMenu {
        let room = world.room
        let menu = NSMenu()
        let open = menu.addItem(withTitle: "Hiện phòng chơi", action: #selector(toggleRoom), keyEquivalent: "")
        open.target = self
        open.state = room.isOpen ? .on : .off
        let scenes = NSMenu()
        for scene in RoomScene.allCases {
            let item = scenes.addItem(withTitle: scene.title, action: #selector(setRoomScene(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scene.rawValue
            item.state = scene == room.scene ? .on : .off
        }
        menu.addItem(withTitle: "Phong cảnh", action: nil, keyEquivalent: "").submenu = scenes
        menu.addItem(.separator())
        menu.addItem(withTitle: "Ở trong phòng:", action: nil, keyEquivalent: "").isEnabled = false
        for group in characterGroups(#selector(toggleRoomMember(_:)), isOn: { room.members.contains($0.id) }) {
            menu.addItem(group)
        }
        menu.addItem(.separator())
        let edit = menu.addItem(withTitle: "Chỉnh vị trí và kích thước phòng", action: #selector(toggleRoomEditing), keyEquivalent: "")
        edit.target = self
        edit.state = room.editing ? .on : .off
        return menu
    }

    /// One submenu per series listing its characters; each item's tag is the character's index in allCharacters.
    /// A series shows a dash when some of its characters are on.
    private func characterGroups(_ action: Selector, isOn: (Character) -> Bool) -> [NSMenuItem] {
        Series.allCases.compactMap { series in
            let members = allCharacters.enumerated().filter { $0.element.series == series }
            guard !members.isEmpty else { return nil }
            let submenu = NSMenu()
            for (i, character) in members {
                let item = submenu.addItem(withTitle: character.name, action: action, keyEquivalent: "")
                item.target = self
                item.tag = i
                item.state = isOn(character) ? .on : .off
            }
            let group = NSMenuItem(title: series.rawValue, action: nil, keyEquivalent: "")
            group.submenu = submenu
            group.state = members.contains { isOn($0.element) } ? .mixed : .off
            return group
        }
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
    }

    @objc private func toggleCharacter(_ sender: NSMenuItem) {
        let character = allCharacters[sender.tag]
        let enable = world.pets[character.id] == nil
        world.setEnabled(character, enable)
        if enable { enabledIDs.insert(character.id) } else { enabledIDs.remove(character.id) }
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let language = Language(rawValue: raw) {
            Language.current = language
        }
    }

    @objc private func toggleAgents() { world.agentsEnabled.toggle() }

    @objc private func toggleAgentKind(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let kind = AgentKind(rawValue: raw) else { return }
        if world.disabledAgentKinds.contains(kind) { world.disabledAgentKinds.remove(kind) } else { world.disabledAgentKinds.insert(kind) }
    }

    @objc private func toggleRoom() { world.room.setOpen(!world.room.isOpen) }

    /// Putting a character in the room also brings it out if it was turned off.
    @objc private func toggleRoomMember(_ sender: NSMenuItem) {
        let character = allCharacters[sender.tag]
        let inside = !world.room.members.contains(character.id)
        world.room.setMember(character.id, inside)
        if inside && world.pets[character.id] == nil {
            world.setEnabled(character, true)
            enabledIDs.insert(character.id)
        }
    }

    @objc private func setRoomScene(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let scene = RoomScene(rawValue: raw) {
            world.room.setScene(scene)
        }
    }

    @objc private func toggleRoomEditing() { world.room.setEditing(!world.room.editing) }

    @objc private func installClaudeHooks() {
        NSApp.activate(ignoringOtherApps: true)
        let confirm = NSAlert()
        confirm.messageText = "Cài hook trạng thái cho Claude Code?"
        confirm.informativeText = """
        OllieBoard sẽ thêm hook vào \(ClaudeHooks.settings.path) để biết chính xác khi nào Claude Code đang làm, \
        đã xong hay cần bạn duyệt. Các hook hiện có được giữ nguyên; bản cũ được sao lưu thành settings.json.ollieboard-backup.
        """
        confirm.addButton(withTitle: "Cài đặt")
        confirm.addButton(withTitle: "Huỷ")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        let result = NSAlert()
        do {
            try ClaudeHooks.install()
            result.messageText = "Đã cài hook"
            result.informativeText = "Áp dụng cho các phiên Claude Code mở từ bây giờ (phiên đang chạy cần khởi động lại)."
        } catch {
            result.alertStyle = .warning
            result.messageText = "Không cài được hook"
            result.informativeText = error.localizedDescription
        }
        result.runModal()
    }

    @objc private func kickNow() { world.command(.kick) }
    @objc private func arrangeNow() { world.command(.arrange) }

    @objc private func openAutomationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    @objc private func disableAutoArrange() { world.desktop.disableAutoArrange {} }

    @objc private func quit() { NSApp.terminate(nil) }
}
