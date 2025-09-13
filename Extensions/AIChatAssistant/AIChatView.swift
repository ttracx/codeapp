//
//  AIChatView.swift
//  Code
//
//  Chat UI for AI Assistant
//

import SwiftUI

struct AIChatView: View {
    @StateObject private var aiService = AIService()
    @EnvironmentObject var chatManager: ChatManager
    @State private var messageText = ""
    @State private var isStreaming = false
    @State private var currentStreamingMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message)
                        }
                        
                        // Show streaming message if active
                        if isStreaming && !currentStreamingMessage.isEmpty {
                            MessageBubble(
                                message: ChatMessage(
                                    role: .assistant,
                                    content: currentStreamingMessage
                                ),
                                isStreaming: true
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: chatManager.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(chatManager.messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: currentStreamingMessage) { _ in
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Input area
            VStack(alignment: .leading, spacing: 8) {
                if let error = aiService.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(Color.init(id: "panelTitle.activeForeground"))
                        Spacer()
                        Button("Dismiss") {
                            aiService.clearError()
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask your AI coding assistant...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...4)
                        .disabled(isStreaming)
                    
                    Button(action: sendMessage) {
                        Image(systemName: isStreaming ? "stop.circle.fill" : "paperplane.fill")
                            .foregroundColor(canSend ? Color.blue : Color.init(id: "activityBar.inactiveForeground"))
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.init(id: "sideBar.background"))
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming
    }
    
    private func sendMessage() {
        if isStreaming {
            // Stop streaming
            isStreaming = false
            if !currentStreamingMessage.isEmpty {
                chatManager.addMessage(ChatMessage(role: .assistant, content: currentStreamingMessage))
                currentStreamingMessage = ""
            }
            return
        }
        
        let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        
        // Add user message
        chatManager.addMessage(ChatMessage(role: .user, content: userMessage))
        messageText = ""
        
        // Start streaming response
        isStreaming = true
        currentStreamingMessage = ""
        
        Task {
            do {
                let stream = try await aiService.sendMessage(userMessage, conversationHistory: chatManager.getConversationHistory())
                
                for try await chunk in stream {
                    await MainActor.run {
                        currentStreamingMessage += chunk
                    }
                }
                
                await MainActor.run {
                    isStreaming = false
                    if !currentStreamingMessage.isEmpty {
                        chatManager.addMessage(ChatMessage(role: .assistant, content: currentStreamingMessage))
                        currentStreamingMessage = ""
                    }
                }
            } catch {
                await MainActor.run {
                    isStreaming = false
                    currentStreamingMessage = ""
                    if let aiError = error as? AIServiceError {
                        aiService.error = aiError
                    } else {
                        aiService.error = .networkError(error)
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ? Color.blue : Color.init(id: "input.background"))
                    )
                    .foregroundColor(message.role == .user ? .white : Color.init(id: "panelTitle.activeForeground"))
                
                if !isStreaming {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(Color.init(id: "activityBar.inactiveForeground"))
                }
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
        .id(isStreaming ? "streaming" : message.id)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Chat Manager
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }
    
    func clearMessages() {
        messages.removeAll()
    }
    
    func getConversationHistory() -> [ChatMessage] {
        // Return messages excluding system messages for API calls
        return messages.filter { $0.role != .system }
    }
}