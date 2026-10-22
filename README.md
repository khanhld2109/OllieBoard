# OllieBoard

Thú cưng anime chạy trên Desktop macOS. Các nhân vật đi lại, ngủ, chơi với nhau, đá và dọn dẹp icon thật trên Desktop. Mỗi phiên AI coding agent (Claude Code, Codex, Gemini…) đang chạy cũng có một nhân vật riêng, báo cho bạn khi agent làm xong hoặc cần bạn duyệt.

App chỉ có icon 🐾 trên menu bar, không hiện trên Dock.

## Tính năng

- **5 nhân vật:** Anya Forger (Spy x Family), Nezuko Kamado (Kimetsu no Yaiba), Frieren (Sousou no Frieren), Hitori Gotoh (Bocchi the Rock!), Rem (Re:Zero). Mỗi nhân vật có tính cách và 2 kỹ năng đặc biệt riêng.
- **Tương tác với Desktop:** nhân vật đá icon bay đi, hoặc xếp gọn icon thành lưới ở góc trên bên phải màn hình chính.
- **Phòng chơi:** một căn phòng vẽ trên Desktop (nằm dưới các cửa sổ). Nhân vật được đưa vào phòng sẽ ở trên sàn và chỉ chơi với nhau.
- **Nhân vật cho AI agent:** tự phát hiện các phiên Claude Code, Codex, Gemini CLI, OpenCode, Cursor Agent và Aider đang chạy.
- **3 ngôn ngữ thoại:** Tiếng Việt, English, 日本語.

## Cài đặt

1. Tải `OllieBoard-<version>.dmg` ở [Releases](https://github.com/vfa-khuongdv/OllieBoard/releases/latest), mở ra và kéo **OllieBoard** vào **Applications**.
2. App chỉ ký ad-hoc (chưa notarize), nên lần đầu mở: chuột phải vào app → **Open** → **Open**.
   Nếu macOS báo app bị hỏng:
   ```sh
   xattr -dr com.apple.quarantine /Applications/OllieBoard.app
   ```
3. Cho phép OllieBoard điều khiển **Finder** khi được hỏi. Đây là quyền để nhân vật di chuyển được icon trên Desktop.

Yêu cầu: macOS 13 trở lên, chip Apple Silicon (bản release hiện chỉ build cho arm64).

## Sử dụng

Mọi thao tác nằm trong menu 🐾 trên menu bar:

| Mục | Chức năng |
| --- | --- |
| Nhân vật | Bật/tắt từng nhân vật. Mặc định chỉ bật Nezuko. |
| Phòng chơi | Hiện phòng, chọn ai ở trong phòng, chỉnh vị trí và kích thước phòng. |
| Ngôn ngữ / Language / 言語 | Đổi ngôn ngữ thoại. |
| Nhân vật cho AI agent | Bật/tắt nhân vật cho agent, chọn loại agent, cài hook cho Claude Code. |
| Đá một icon ngay | Bảo một nhân vật đá icon ngay lập tức. |
| Dọn dẹp Desktop | Bảo một nhân vật xếp gọn icon. |

Tương tác trực tiếp với nhân vật:

- **Click:** nhân vật vui. Click liên tục (4 lần trong 3 giây) thì nhân vật cáu, riêng Bocchi thì "tan chảy". Click khi đang ngủ sẽ đánh thức nhân vật.
- **Kéo thả:** nhấc nhân vật sang chỗ khác.
- **Chuột phải:** mở menu kỹ năng đặc biệt của nhân vật đó.

Bocchi nhút nhát nên sẽ chạy trốn con trỏ chuột.

### Khi icon không di chuyển

- Menu hiện **⚠️ Chưa điều khiển được Finder**: chọn **Mở cài đặt quyền Automation…** và bật quyền Finder cho OllieBoard.
- Menu hiện **⚠️ Desktop đang bật Sort By — icon bị khoá**: chọn **Tắt Sort By trên Desktop**, hoặc tự tắt trong Finder (View → Sort By → None).

## Nhân vật cho AI agent

OllieBoard quét danh sách tiến trình mỗi 2 giây để tìm các phiên `claude`, `codex`, `gemini`, `opencode`, `cursor-agent` và `aider`. Mỗi phiên có một nhân vật mang tên agent và tên thư mục project (ví dụ `Claude · OllieBoard`). Nhân vật chỉ xuất hiện khi agent đang làm hoặc đang chờ bạn. Khi agent làm xong hoặc cần duyệt, nhân vật chạy tới con trỏ chuột để báo. Click vào nhân vật sẽ chuyển sang cửa sổ terminal của phiên đó.

Mặc định trạng thái của agent được đoán qua mức dùng CPU. Với Claude Code, có thể cài hook để biết trạng thái chính xác: menu → **Nhân vật cho AI agent** → **Cài hook trạng thái cho Claude Code…**. Thao tác này sẽ:

- tạo script `~/Library/Application Support/OllieBoard/claude-hook.sh`;
- thêm hook cho các sự kiện `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `Notification`, `Stop` vào `~/.claude/settings.json`. Các hook có sẵn được giữ nguyên, bản cũ được sao lưu thành `settings.json.ollieboard-backup`.

Hook chỉ có hiệu lực với các phiên Claude Code mở sau khi cài.

## Build từ mã nguồn

Yêu cầu: macOS 13+ và Xcode 15+ (hoặc Swift 5.9 toolchain).

```sh
./scripts/build-app.sh
open build/OllieBoard.app
```

Script sẽ vẽ lại sprite sheet (`swift run -c release SpriteGen`), build bản release và đóng gói thành `build/OllieBoard.app`.

Mặc định app được ký ad-hoc, nên mỗi lần build lại macOS sẽ hỏi lại quyền điều khiển Finder. Muốn giữ quyền giữa các lần build thì ký bằng một chứng chỉ cố định:

```sh
security find-identity -v -p codesigning   # xem danh sách chứng chỉ
SIGN_IDENTITY="Apple Development: ..." ./scripts/build-app.sh
```

### Đóng gói DMG

```sh
STAGE=$(mktemp -d)
cp -R build/OllieBoard.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname OllieBoard -srcfolder "$STAGE" -ov -format UDZO build/OllieBoard-1.0.dmg
```

## Cấu trúc thư mục

```
Sources/
  OllieBoard/            App chính
    AppDelegate.swift    Menu trên menu bar
    World.swift          Quản lý các nhân vật, vòng lặp animation, phân chia icon
    Pet.swift            Hành vi và kỹ năng của một nhân vật
    PetWindow.swift      Cửa sổ trong suốt vẽ nhân vật, xử lý chuột
    Room.swift           Phòng chơi
    DesktopIcons.swift   Đọc và di chuyển icon Desktop qua AppleScript (Finder)
    AgentMonitor.swift   Phát hiện các phiên AI agent đang chạy
    ClaudeHooks.swift    Cài hook trạng thái cho Claude Code
    Characters.swift     Danh sách nhân vật và tính cách
    Dialogue*.swift      Lời thoại theo từng ngôn ngữ
    Resources/Sprites/   Sprite sheet do SpriteGen tạo ra
  SpriteGen/             Vẽ nhân vật bằng Core Graphics và xuất sprite sheet
scripts/build-app.sh     Build và đóng gói OllieBoard.app
```
