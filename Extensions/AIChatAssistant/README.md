# AI Chat Assistant

This extension adds an agentic SWE coding assistant to Code App with a chat UI on the left panel.

## Features

1. **Chat UI Integration**: The chat UI resides on the left panel as an Activity Bar item
2. **AI Inference Integration**: Uses NVIDIA's API for AI responses
3. **System Prompt**: Configured with NeuralQuantum SWE Agent persona for coding assistance
4. **Streaming Responses**: Provides real-time feedback during AI responses
5. **Error Handling**: Comprehensive error handling for API failures
6. **Message History**: Maintains conversation context

## Technical Implementation

### Architecture
- **Extension System**: Implemented as a `CodeAppExtension` following the app's extension pattern
- **Activity Bar Item**: Registered with keyboard shortcut (Cmd+Shift+A)
- **SwiftUI**: Built with SwiftUI using the app's existing styling system
- **Async/Await**: Uses modern Swift concurrency for API calls

### API Configuration
- **Endpoint**: https://integrate.api.nvidia.com/v1/chat/completions
- **Model**: moonshotai/kimi-k2-instruct
- **Max Tokens**: 4096
- **Streaming**: Enabled for real-time responses
- **Authentication**: Bearer token authentication

### Files Structure
```
Extensions/AIChatAssistant/
├── AIChatAssistantExtension.swift     # Main extension registration
├── AIChatContainer.swift              # Container view following app patterns
├── AIChatView.swift                   # Chat UI implementation
├── AIService.swift                    # NVIDIA API integration
└── Models/
    └── ChatModels.swift               # Data models for chat
```

## Usage

1. Click the brain icon in the Activity Bar on the left
2. Type your coding question or request in the text field
3. Press the send button or Enter to submit
4. Watch as the AI streams its response in real-time
5. Continue the conversation with context maintained

## System Prompt

The AI is configured with the NeuralQuantum SWE Agent persona:
> Senior full-stack SWE & AI strategist with end-to-end delivery focus.
> Mission: Given a product brief or feature request, autonomously plan and ship a runnable SaaS vertical slice.

## Keyboard Shortcuts

- **Cmd+Shift+A**: Toggle AI Chat Assistant panel
- **Ctrl+C**: Stop streaming response (when streaming)
- **Cmd+K**: Clear terminal (in toolbar)