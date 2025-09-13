//
//  ChatModels.swift
//  Code
//
//  Data models for AI Chat Assistant
//

import Foundation

// MARK: - Chat Message Models
struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

enum MessageRole: String, Codable, CaseIterable {
    case system = "system"
    case user = "user" 
    case assistant = "assistant"
}

// MARK: - API Request/Response Models
struct AIAPIRequest: Codable {
    let model: String
    let messages: [APIMessage]
    let temperature: Double
    let top_p: Double
    let frequency_penalty: Double
    let presence_penalty: Double
    let max_tokens: Int
    let stream: Bool
}

struct APIMessage: Codable {
    let role: String
    let content: String
    
    init(from chatMessage: ChatMessage) {
        self.role = chatMessage.role.rawValue
        self.content = chatMessage.content
    }
}

struct AIAPIResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [APIChoice]?
}

struct APIChoice: Codable {
    let index: Int?
    let message: APIMessage?
    let delta: APIDelta?
    let finish_reason: String?
}

struct APIDelta: Codable {
    let role: String?
    let content: String?
}

// MARK: - Error Models
enum AIServiceError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case apiError(String)
    case streamingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from API"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        }
    }
}