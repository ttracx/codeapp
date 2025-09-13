//
//  AIChatAssistantExtension.swift
//  Code
//
//  AI Chat Assistant Extension for SWE coding assistance
//

import SwiftUI

class AIChatAssistantExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        // Register the AI Chat Assistant as an Activity Bar item
        let aiChatItem = ActivityBarItem(
            itemID: "AI_CHAT_ASSISTANT",
            iconSystemName: "brain.head.profile",
            title: "AI Assistant",
            shortcutKey: "a",
            modifiers: [.command, .shift],
            view: AnyView(AIChatContainer()),
            contextMenuItems: nil,
            positionPrecedence: 50, // Position after existing items
            bubble: { nil },
            isVisible: { true }
        )
        
        contribution.activityBar.registerItem(item: aiChatItem)
    }
}