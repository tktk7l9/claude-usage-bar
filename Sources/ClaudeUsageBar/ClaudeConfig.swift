import Foundation

/// Reads Claude Code's local configuration. The values reflect the global
/// defaults in ~/.claude/settings.json; individual sessions may override them,
/// so this is the configured default, not a live session state.
enum ClaudeConfig {
    struct Settings {
        let model: String?
        let effortLevel: String?
    }

    static func read() -> Settings {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return Settings(model: nil, effortLevel: nil)
        }
        func string(_ key: String) -> String? {
            (object[key] as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
        return Settings(model: string("model"), effortLevel: string("effortLevel"))
    }
}
