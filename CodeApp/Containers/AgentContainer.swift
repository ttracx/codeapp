//
//  AgentContainer.swift
//  Code App
//
//  Created by Assistant on 13/09/2025.
//

import SwiftUI
import Foundation

struct AgentMessage: Identifiable, Equatable {
    enum Role { case user, assistant, system }
    let id = UUID()
    let role: Role
    var text: String
}

@MainActor
final class AgentChatManager: ObservableObject {
    @Published var messages: [AgentMessage] = []
    @Published var isStreaming: Bool = false
    @Published var error: String? = nil

    func appendUser(_ text: String) {
        messages.append(.init(role: .user, text: text))
    }

    func appendAssistantChunk(_ text: String) {
        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[lastIndex].text += text
        } else {
            messages.append(.init(role: .assistant, text: text))
        }
    }

    func reset() {
        messages.removeAll()
        error = nil
    }
}

struct AgentContainer: View {
    @EnvironmentObject var App: MainApp
    @StateObject private var chat = AgentChatManager()
    @State private var input: String = ""
    @State private var savingPath: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NeuralQuantum SWE Agent").bold()
                Spacer()
                if chat.isStreaming { ProgressView().scaleEffect(0.8) }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.init(id: "sideBar.background"))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chat.messages) { msg in
                            HStack(alignment: .top) {
                                Text(badge(for: msg.role))
                                    .font(.caption)
                                    .padding(6)
                                    .background(roleColor(msg.role))
                                    .cornerRadius(6)
                                Text(msg.text)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.init("T1"))
                                    .textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .id(msg.id)
                        }
                        if let error = chat.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .onChange(of: chat.messages.count) { _ in
                    if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Ask the agent to build or modify code...", text: $input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.isStreaming)
                }
                HStack(spacing: 8) {
                    TextField("Optional: save to path relative to workspace (e.g. src/App.tsx)", text: $savingPath)
                        .textFieldStyle(.roundedBorder)
                    Button(action: { savingPath = "" }) { Text("Clear") }
                }
            }
            .padding(12)
            .background(Color.init(id: "sideBar.background"))
        }
    }

    private func badge(for role: AgentMessage.Role) -> String {
        switch role { case .user: return "You"; case .assistant: return "Agent"; case .system: return "System" }
    }

    private func roleColor(_ role: AgentMessage.Role) -> Color {
        switch role { case .user: return Color.blue.opacity(0.2); case .assistant: return Color.green.opacity(0.2); case .system: return Color.gray.opacity(0.2) }
    }

    private func send() {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        chat.appendUser(prompt)
        input = ""
        Task { await streamCompletion(userContent: prompt) }
    }

    private func streamCompletion(userContent: String) async {
        chat.isStreaming = true
        defer { chat.isStreaming = false }
        chat.error = nil

        guard let url = URL(string: NVIDIA_INVOKE_URL) else {
            chat.error = "Invalid API URL"
            return
        }

        let payload: [String: Any] = [
            "model": NVIDIA_MODEL_ID,
            "messages": [
                ["role": "system", "content": NQ_AGENT_SYSTEM_PROMPT],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.6,
            "top_p": 0.9,
            "frequency_penalty": 0,
            "presence_penalty": 0,
            "max_tokens": 4096,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(NVIDIA_API_KEY)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let session = URLSession(configuration: .default)

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                chat.error = "API error: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                return
            }
            var aggregatedAssistant = ""
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" { break }
                    if let data = jsonString.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let choices = obj["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String, !content.isEmpty {
                            chat.appendAssistantChunk(content)
                            aggregatedAssistant += content
                        }
                    }
                }
            }
            // Auto-persist code blocks when possible
            await parseAndPersistBlocks(text: aggregatedAssistant)
            // Manual override path save (if provided)
            if !savingPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let last = chat.messages.last?.text {
                await persist(content: last, relativePath: savingPath)
            }
        } catch {
            chat.error = error.localizedDescription
        }
    }

    private func parseAndPersistBlocks(text: String) async {
        let fences = extractCodeFences(from: text)
        guard !fences.isEmpty else { return }
        for fence in fences {
            if let path = detectPath(info: fence.info, content: fence.content) {
                await persist(content: fence.content, relativePath: path)
            }
        }
    }

    private func extractCodeFences(from text: String) -> [(info: String, content: String)] {
        // Matches ```info\n...content...\n```
        // Dot matches newlines
        let pattern = "(?s)```([^\n]*)\n(.*?)\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        var results: [(String, String)] = []
        for m in matches {
            if m.numberOfRanges >= 3 {
                let info = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let content = ns.substring(with: m.range(at: 2))
                results.append((info, content))
            }
        }
        return results
    }

    private func detectPath(info: String, content: String) -> String? {
        // Try from info string first: path=, file=, filename=
        let lowered = info.lowercased()
        if let p = value(afterAnyOf: ["path=", "file=", "filename="], in: lowered) {
            return sanitizePath(p)
        }
        // Heuristic: info itself looks like a relative path (contains '/' and a '.')
        if !info.contains(" "), info.contains("/"), info.contains(".") {
            return sanitizePath(info)
        }
        // Try first few lines of content for File/Path headers inside comments
        let firstLines = content.split(separator: "\n", maxSplits: 5, omittingEmptySubsequences: false)
        for rawLine in firstLines {
            var line = String(rawLine).trimmingCharacters(in: .whitespaces)
            // strip common comment prefixes
            for prefix in ["//", "#", ";", "*", "--", "<!--", "/*"] {
                if line.hasPrefix(prefix) {
                    line = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            let l = line.lowercased()
            if let p = value(afterAnyOf: ["file:", "path:", "filename:"], in: l) {
                return sanitizePath(p)
            }
        }
        return nil
    }

    private func value(afterAnyOf prefixes: [String], in text: String) -> String? {
        for prefix in prefixes {
            if let r = text.range(of: prefix) {
                let v = text[r.upperBound...].split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first
                if let v { return String(v).trimmingCharacters(in: CharacterSet(charactersIn: "\"'`")) }
            }
        }
        return nil
    }

    private func sanitizePath(_ raw: String) -> String {
        return raw.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).replacingOccurrences(of: "..", with: "")
    }

    private func persist(content: String, relativePath: String) async {
        guard let root = App.workSpaceStorage.currentDirectory._url else { return }
        let sanitized = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !sanitized.contains("..") else {
            chat.error = "Invalid path"
            return
        }
        let target = root.appendingPathComponent(sanitized)
        do {
            let dir = target.deletingLastPathComponent()
            if !(try await App.workSpaceStorage.fileExists(at: dir)) {
                try await App.workSpaceStorage.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try await App.workSpaceStorage.write(
                at: target,
                content: Data(content.utf8),
                atomically: false,
                overwrite: true
            )
            App.reloadDirectory()
        } catch {
            chat.error = error.localizedDescription
        }
    }
}

