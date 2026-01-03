//
//  MarkdownTextView.swift
//  app
//
//  A view that renders markdown-formatted text with support for
//  bold, italics, numbered lists, bullet points, etc.
//

import SwiftUI

struct MarkdownTextView: View {
    let text: String
    let textColor: Color
    let fontSize: CGFloat
    
    init(_ text: String, textColor: Color = .primary, fontSize: CGFloat = 15) {
        self.text = text
        self.textColor = textColor
        self.fontSize = fontSize
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseMarkdown().enumerated()), id: \.offset) { _, element in
                element
            }
        }
    }
    
    private func parseMarkdown() -> [AnyView] {
        var views: [AnyView] = []
        let lines = text.components(separatedBy: "\n")
        var currentParagraph = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check for numbered list (e.g., "1. ", "2. ")
            if let match = trimmedLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                // Flush current paragraph
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                
                let content = String(trimmedLine[match.upperBound...])
                views.append(AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(trimmedLine[..<match.upperBound]))
                            .font(.custom("ProductSans-Bold", size: fontSize))
                            .foregroundColor(textColor)
                            .frame(width: 24, alignment: .trailing)
                        createFormattedText(content)
                    }
                ))
            }
            // Check for bullet point (e.g., "- ", "• ", "* ")
            else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("• ") || trimmedLine.hasPrefix("* ") {
                // Flush current paragraph
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                
                let content = String(trimmedLine.dropFirst(2))
                views.append(AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.custom("ProductSans-Bold", size: fontSize))
                            .foregroundColor(textColor)
                            .frame(width: 16, alignment: .center)
                        createFormattedText(content)
                    }
                ))
            }
            // Check for header (e.g., "### ", "## ", "# ")
            else if trimmedLine.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(4))
                views.append(AnyView(
                    Text(content)
                        .font(.custom("ProductSans-Bold", size: fontSize + 2))
                        .foregroundColor(textColor)
                        .padding(.top, 4)
                ))
            }
            else if trimmedLine.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(3))
                views.append(AnyView(
                    Text(content)
                        .font(.custom("ProductSans-Bold", size: fontSize + 4))
                        .foregroundColor(textColor)
                        .padding(.top, 6)
                ))
            }
            else if trimmedLine.hasPrefix("# ") {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(2))
                views.append(AnyView(
                    Text(content)
                        .font(.custom("ProductSans-Bold", size: fontSize + 6))
                        .foregroundColor(textColor)
                        .padding(.top, 8)
                ))
            }
            // Empty line - flush paragraph
            else if trimmedLine.isEmpty {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
            }
            // Regular text - add to paragraph
            else {
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmedLine
            }
        }
        
        // Flush remaining paragraph
        if !currentParagraph.isEmpty {
            views.append(AnyView(createFormattedText(currentParagraph)))
        }
        
        return views
    }
    
    private func createFormattedText(_ text: String) -> some View {
        var attributedString = AttributedString(text)
        
        // Process bold text (**text** or __text__)
        attributedString = processBold(attributedString)
        
        // Process italic text (*text* or _text_)
        attributedString = processItalic(attributedString)
        
        // Process inline code (`code`)
        attributedString = processInlineCode(attributedString)
        
        return Text(attributedString)
            .font(.custom("ProductSans-Regular", size: fontSize))
            .foregroundColor(textColor)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func processBold(_ input: AttributedString) -> AttributedString {
        var result = input
        let string = String(result.characters)
        
        // Match **text** pattern
        let pattern = #"\*\*(.+?)\*\*"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
            
            // Process matches in reverse order to preserve indices
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: string),
                      let contentRange = Range(match.range(at: 1), in: string) else { continue }
                
                let content = String(string[contentRange])
                var replacement = AttributedString(content)
                replacement.font = .custom("ProductSans-Bold", size: fontSize)
                
                if let attrRange = result.range(of: String(string[fullRange])) {
                    result.replaceSubrange(attrRange, with: replacement)
                }
            }
        }
        
        return result
    }
    
    private func processItalic(_ input: AttributedString) -> AttributedString {
        var result = input
        let string = String(result.characters)
        
        // Match *text* pattern (but not **text**)
        let pattern = #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
            
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: string),
                      let contentRange = Range(match.range(at: 1), in: string) else { continue }
                
                let content = String(string[contentRange])
                var replacement = AttributedString(content)
                replacement.font = .custom("ProductSans-Regular", size: fontSize).italic()
                
                if let attrRange = result.range(of: String(string[fullRange])) {
                    result.replaceSubrange(attrRange, with: replacement)
                }
            }
        }
        
        return result
    }
    
    private func processInlineCode(_ input: AttributedString) -> AttributedString {
        var result = input
        let string = String(result.characters)
        
        // Match `code` pattern
        let pattern = #"`(.+?)`"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
            
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: string),
                      let contentRange = Range(match.range(at: 1), in: string) else { continue }
                
                let content = String(string[contentRange])
                var replacement = AttributedString(content)
                replacement.font = .system(size: fontSize - 1, design: .monospaced)
                replacement.backgroundColor = Color.gray.opacity(0.2)
                
                if let attrRange = result.range(of: String(string[fullRange])) {
                    result.replaceSubrange(attrRange, with: replacement)
                }
            }
        }
        
        return result
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownTextView("""
            **Bold text** and *italic text* work great!
            
            Here's a numbered list:
            1. First item
            2. Second item
            3. Third item
            
            And bullet points:
            - Point one
            - Point two
            - Point three
            
            ### A Header
            
            Some regular text with `inline code` included.
            """, textColor: .primary, fontSize: 15)
        }
        .padding()
    }
}
