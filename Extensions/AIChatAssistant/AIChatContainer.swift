//
//  AIChatContainer.swift
//  Code
//
//  Container for AI Chat Assistant following app patterns
//

import SwiftUI

struct AIChatContainer: View {
    @EnvironmentObject var App: MainApp
    @EnvironmentObject var stateManager: MainStateManager
    @StateObject private var chatManager = ChatManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(Color.init(id: "activityBar.foreground"))
                Text("AI Coding Assistant")
                    .font(.headline)
                    .foregroundColor(Color.init(id: "activityBar.foreground"))
                Spacer()
                
                Button(action: { chatManager.clearMessages() }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color.init(id: "activityBar.inactiveForeground"))
                }
                .disabled(chatManager.messages.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.init(id: "activityBar.background"))
            
            // Chat interface
            AIChatView()
                .environmentObject(chatManager)
                .background(Color.init(id: "sideBar.background"))
        }
    }
}