import React from 'react';
import { Text, StyleSheet, View, Dimensions } from 'react-native';
import { WebView } from 'react-native-webview';
import { Colors, FontSize, Spacing } from '../constants/theme';

interface MarkdownTextProps {
  children: string;
  style?: object;
}

interface ParsedSegment {
  type: 'text' | 'bold' | 'italic' | 'bolditalic' | 'bullet' | 'numbered' | 'math' | 'mathInline';
  content: string;
  number?: number;
}

/**
 * Simple markdown text component that handles:
 * - # Heading 1, ## Heading 2, ### Heading 3
 * - **bold** text
 * - *italic* text
 * - ***bold italic*** text
 * - Bullet points (lines starting with - or *)
 * - Numbered lists (lines starting with 1. 2. etc)
 */
export function MarkdownText({ children, style }: MarkdownTextProps) {
  const createMathHTML = (mathContent: string, isDisplay: boolean = false) => {
    // Properly escape the math content for JavaScript string
    // We need to be careful with backslashes - they're part of LaTeX syntax
    const escapedMath = mathContent
      .replace(/\\/g, '\\\\')  // Escape backslashes first
      .replace(/'/g, "\\'")     // Escape single quotes
      .replace(/"/g, '\\"')     // Escape double quotes
      .replace(/\n/g, ' ')      // Replace newlines with spaces
      .replace(/\r/g, '')       // Remove carriage returns
      .replace(/\$/g, '\\$');   // Escape dollar signs
    
    const containerStyle = isDisplay 
      ? 'display: block; text-align: center; margin: 16px 0;'
      : 'display: inline-block; vertical-align: middle;';
    
    return `
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css" crossorigin="anonymous">
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js" crossorigin="anonymous"></script>
        <style>
          * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
          }
          html, body {
            width: 100%;
            height: 100%;
            margin: 0;
            padding: 0;
            background-color: transparent;
            overflow: hidden;
          }
          body {
            display: flex;
            justify-content: ${isDisplay ? 'center' : 'flex-start'};
            align-items: center;
            width: 100%;
            height: 100%;
          }
          #math {
            ${containerStyle}
            width: ${isDisplay ? '100%' : 'auto'};
            max-width: ${isDisplay ? '100%' : 'none'};
          }
          .katex {
            font-size: ${isDisplay ? '18px' : '14px'} !important;
            color: #FFFFFF !important;
            line-height: 1.2 !important;
          }
          .katex .base {
            color: #FFFFFF !important;
          }
        </style>
      </head>
      <body>
        <div id="math" data-math="${encodeURIComponent(mathContent)}"></div>
        <script>
          (function() {
            var attempts = 0;
            var maxAttempts = 20;
            
            function renderMath() {
              if (typeof katex !== 'undefined' && typeof katex.render === 'function') {
                try {
                  var mathEl = document.getElementById('math');
                  var mathStr = decodeURIComponent(mathEl.getAttribute('data-math') || '');
                  
                  // Clean up the math string
                  mathStr = mathStr.trim();
                  
                  if (!mathStr) {
                    return;
                  }
                  
                  katex.render(mathStr, mathEl, {
                    throwOnError: false,
                    displayMode: ${isDisplay},
                    errorColor: '#FFFFFF',
                    strict: false
                  });
                } catch(e) {
                  console.error('KaTeX render error:', e);
                  var mathEl = document.getElementById('math');
                  var mathStr = decodeURIComponent(mathEl.getAttribute('data-math') || '');
                  mathEl.innerHTML = '<span style="color: #FFFFFF; font-family: monospace; font-size: 14px;">' + 
                    mathStr.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</span>';
                }
              } else {
                attempts++;
                if (attempts < maxAttempts) {
                  setTimeout(renderMath, 100);
                } else {
                  // Fallback: show raw math
                  var mathEl = document.getElementById('math');
                  var mathStr = decodeURIComponent(mathEl.getAttribute('data-math') || '');
                  mathEl.innerHTML = '<span style="color: #FFFFFF; font-family: monospace; font-size: 14px;">' + 
                    mathStr.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</span>';
                }
              }
            }
            
            // Start rendering after a short delay to ensure DOM and scripts are ready
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', function() {
                setTimeout(renderMath, 200);
              });
            } else {
              setTimeout(renderMath, 200);
            }
          })();
        </script>
      </body>
      </html>
    `;
  };

  const parseTextWithInlineMath = (text: string): Array<{ type: 'text' | 'math'; content: string }> => {
    const parts: Array<{ type: 'text' | 'math'; content: string }> = [];
    let currentIndex = 0;

    while (currentIndex < text.length) {
      // Check for inline math \(...\) (LaTeX inline math with backslash)
      const latexStart = text.indexOf('\\(', currentIndex);
      // Check for inline math $...$ (single dollar signs, but not $$)
      // We need to find $ that is NOT followed by another $
      let dollarStart = -1;
      for (let i = currentIndex; i < text.length; i++) {
        if (text[i] === '$') {
          // Check if it's not part of $$
          if (i + 1 >= text.length || text[i + 1] !== '$') {
            dollarStart = i;
            break;
          } else {
            // Skip the $$ (display math)
            i++; // Skip the second $
            continue;
          }
        }
      }
      
      let nextMathStart = -1;
      let nextMathEnd = -1;
      let mathType: 'latex' | 'dollar' | null = null;
      
      // Determine which math comes first
      if (latexStart !== -1 && (dollarStart === -1 || latexStart < dollarStart)) {
        // Found \( first
        const latexEnd = text.indexOf('\\)', latexStart + 2);
        if (latexEnd !== -1) {
          nextMathStart = latexStart;
          nextMathEnd = latexEnd;
          mathType = 'latex';
        }
      } else if (dollarStart !== -1) {
        // Found $ first (and it's not $$)
        // Find the next $ that's not part of $$
        let found = false;
        for (let i = dollarStart + 1; i < text.length; i++) {
          if (text[i] === '$') {
            // Check if it's followed by another $ (making it $$)
            if (i + 1 < text.length && text[i + 1] === '$') {
              // This is the start of $$, so the previous $ was the end of inline math
              nextMathStart = dollarStart;
              nextMathEnd = i;
              mathType = 'dollar';
              found = true;
              break;
            } else {
              // Found closing $ for inline math
              nextMathStart = dollarStart;
              nextMathEnd = i;
              mathType = 'dollar';
              found = true;
              break;
            }
          }
        }
        if (!found) {
          // No closing $ found, treat the $ as regular text and continue
          currentIndex = dollarStart + 1;
          continue;
        }
      }
      
      if (nextMathStart !== -1 && mathType) {
        // Add text before math
        if (nextMathStart > currentIndex) {
          parts.push({ type: 'text', content: text.slice(currentIndex, nextMathStart) });
        }
        
        // Extract math content
        let mathContent: string;
        if (mathType === 'latex') {
          mathContent = text.slice(nextMathStart + 2, nextMathEnd);
          currentIndex = nextMathEnd + 2; // After \)
        } else {
          mathContent = text.slice(nextMathStart + 1, nextMathEnd);
          currentIndex = nextMathEnd + 1; // After $
        }
        
        parts.push({ type: 'math', content: mathContent });
      } else {
        // No more math found, add remaining text
        if (currentIndex < text.length) {
          parts.push({ type: 'text', content: text.slice(currentIndex) });
        }
        break;
      }
    }
    
    // If no parts, return the whole text
    if (parts.length === 0) {
      parts.push({ type: 'text', content: text });
    }
    
    return parts;
  };

  const parseInlineMarkdown = (text: string): React.ReactNode[] => {
    // First extract inline math, then process text parts
    const parts = parseTextWithInlineMath(text);
    const elements: React.ReactNode[] = [];
    let key = 0;

    parts.forEach((part) => {
      if (part.type === 'math') {
        // Render inline math as a separate View
        elements.push(
          <View key={key++} style={styles.mathInlineWrapper}>
            <WebView
              source={{ html: createMathHTML(part.content, false) }}
              style={styles.mathInlineWebView}
              scrollEnabled={false}
              showsVerticalScrollIndicator={false}
              showsHorizontalScrollIndicator={false}
              androidLayerType="hardware"
              originWhitelist={['*']}
              nestedScrollEnabled={false}
              pointerEvents="none"
            />
          </View>
        );
      } else {
        // Process text for markdown (bold, italic, etc.)
        let remaining = part.content;
        
        while (remaining.length > 0) {
          // Check for bold italic (***text***)
          const boldItalicMatch = remaining.match(/^\*\*\*(.+?)\*\*\*/);
          if (boldItalicMatch) {
            elements.push(
              <Text key={key++} style={styles.boldItalic}>
                {boldItalicMatch[1]}
              </Text>
            );
            remaining = remaining.slice(boldItalicMatch[0].length);
            continue;
          }

          // Check for bold (**text**)
          const boldMatch = remaining.match(/^\*\*(.+?)\*\*/);
          if (boldMatch) {
            elements.push(
              <Text key={key++} style={styles.bold}>
                {boldMatch[1]}
              </Text>
            );
            remaining = remaining.slice(boldMatch[0].length);
            continue;
          }

          // Check for italic (*text*)
          const italicMatch = remaining.match(/^\*(.+?)\*/);
          if (italicMatch) {
            elements.push(
              <Text key={key++} style={styles.italic}>
                {italicMatch[1]}
              </Text>
            );
            remaining = remaining.slice(italicMatch[0].length);
            continue;
          }

          // Find the next special character or end of string
          const nextSpecial = remaining.search(/[\\*$]/);
          if (nextSpecial === -1) {
            // No more special characters, add the rest as plain text
            elements.push(<Text key={key++}>{remaining}</Text>);
            break;
          } else if (nextSpecial === 0) {
            // Special character at start but didn't match patterns, treat as text
            elements.push(<Text key={key++}>{remaining[0]}</Text>);
            remaining = remaining.slice(1);
          } else {
            // Add text up to the special character
            elements.push(<Text key={key++}>{remaining.slice(0, nextSpecial)}</Text>);
            remaining = remaining.slice(nextSpecial);
          }
        }
      }
    });

    return elements;
  };

  const parseMarkdown = (text: string): React.ReactNode[] => {
    // Split text into parts: display math blocks and regular text
    // Display math: \[...\] or $$...$$
    const parts: Array<{ type: 'text' | 'math'; content: string }> = [];
    let currentIndex = 0;
    
    // Process the entire text to find all display math blocks
    while (currentIndex < text.length) {
      // Look for \[...\] (LaTeX display math)
      const latexStart = text.indexOf('\\[', currentIndex);
      // Look for $$...$$ (display math)
      const dollarStart = text.indexOf('$$', currentIndex);
      
      let nextMathStart = -1;
      let nextMathEnd = -1;
      let mathType: 'latex' | 'dollar' | null = null;
      
      // Determine which math block comes first
      if (latexStart !== -1 && (dollarStart === -1 || latexStart < dollarStart)) {
        // Found \[ first
        const latexEnd = text.indexOf('\\]', latexStart + 2);
        if (latexEnd !== -1) {
          nextMathStart = latexStart;
          nextMathEnd = latexEnd;
          mathType = 'latex';
        }
      } else if (dollarStart !== -1) {
        // Found $$ first
        const dollarEnd = text.indexOf('$$', dollarStart + 2);
        if (dollarEnd !== -1) {
          nextMathStart = dollarStart;
          nextMathEnd = dollarEnd;
          mathType = 'dollar';
        }
      }
      
      if (nextMathStart !== -1 && mathType) {
        // Add text before the math
        if (nextMathStart > currentIndex) {
          parts.push({ type: 'text', content: text.slice(currentIndex, nextMathStart) });
        }
        
        // Extract math content
        let mathContent: string;
        if (mathType === 'latex') {
          mathContent = text.slice(nextMathStart + 2, nextMathEnd);
          currentIndex = nextMathEnd + 2; // After \]
        } else {
          mathContent = text.slice(nextMathStart + 2, nextMathEnd);
          currentIndex = nextMathEnd + 2; // After $$
        }
        
        parts.push({ type: 'math', content: mathContent });
      } else {
        // No more math blocks, add remaining text
        if (currentIndex < text.length) {
          parts.push({ type: 'text', content: text.slice(currentIndex) });
        }
        break;
      }
    }
    
    // If no parts were created, treat entire text as regular content
    if (parts.length === 0) {
      parts.push({ type: 'text', content: text });
    }

    const elements: React.ReactNode[] = [];
    let elementKey = 0;

    parts.forEach((part) => {
      if (part.type === 'math') {
        // Render display math
        const screenWidth = Dimensions.get('window').width;
        elements.push(
          <View key={elementKey++} style={styles.mathContainer}>
            <WebView
              source={{ html: createMathHTML(part.content, true) }}
              style={[styles.mathWebView, { width: screenWidth - 80 }]}
              scrollEnabled={false}
              showsVerticalScrollIndicator={false}
              showsHorizontalScrollIndicator={false}
              androidLayerType="hardware"
              originWhitelist={['*']}
            />
          </View>
        );
      } else {
        // Parse the text part as markdown
        const lines = part.content.split('\n');
        lines.forEach((line, index) => {
          const trimmedLine = line.trim();
          
          // Check for headings (#, ##, ###)
          if (trimmedLine.startsWith('### ')) {
            const headingContent = trimmedLine.slice(4);
            elements.push(
              <Text key={elementKey++} style={[styles.heading3, style]}>
                {parseInlineMarkdown(headingContent)}
              </Text>
            );
          }
          else if (trimmedLine.startsWith('## ')) {
            const headingContent = trimmedLine.slice(3);
            elements.push(
              <Text key={elementKey++} style={[styles.heading2, style]}>
                {parseInlineMarkdown(headingContent)}
              </Text>
            );
          }
          else if (trimmedLine.startsWith('# ')) {
            const headingContent = trimmedLine.slice(2);
            elements.push(
              <Text key={elementKey++} style={[styles.heading1, style]}>
                {parseInlineMarkdown(headingContent)}
              </Text>
            );
          }
          // Check for bullet points
          else if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('* ')) {
            const bulletContent = trimmedLine.slice(2);
            elements.push(
              <View key={elementKey++} style={styles.bulletContainer}>
                <Text style={[styles.bullet, style]}>•</Text>
                <Text style={[styles.bulletText, style]}>
                  {parseInlineMarkdown(bulletContent)}
                </Text>
              </View>
            );
          }
          // Check for numbered lists
          else if (/^\d+\.\s/.test(trimmedLine)) {
            const match = trimmedLine.match(/^(\d+)\.\s(.*)$/);
            if (match) {
              elements.push(
                <View key={elementKey++} style={styles.bulletContainer}>
                  <Text style={[styles.number, style]}>{match[1]}.</Text>
                  <Text style={[styles.bulletText, style]}>
                    {parseInlineMarkdown(match[2])}
                  </Text>
                </View>
              );
            }
          }
          // Regular text - parse inline markdown which may contain inline math
          else if (line.length > 0 || index < lines.length - 1) {
            // Check if line contains inline math before parsing
            // Look for \(...\) or $...$ (but not $$...$$)
            const hasInlineMath = /\\\([^)]*\\\)|\$(?!\$)[^$]*\$(?!\$)/.test(line);
            const inlineElements = parseInlineMarkdown(line);
            
            // Check if inlineElements contains any View components (math)
            const hasMathViews = inlineElements.some((el: any) => 
              el && typeof el === 'object' && el.type && el.type.displayName === 'View'
            );
            
            if (hasInlineMath || hasMathViews) {
              // Contains math, use View container with flexDirection row for proper layout
              elements.push(
                <View key={elementKey++} style={styles.inlineTextContainer}>
                  {inlineElements}
                  {index < lines.length - 1 ? <Text style={[styles.text, style]}>{'\n'}</Text> : null}
                </View>
              );
            } else {
              // Only text elements, can use Text component
              elements.push(
                <Text key={elementKey++} style={[styles.text, style]}>
                  {inlineElements}
                  {index < lines.length - 1 ? '\n' : ''}
                </Text>
              );
            }
          }
        });
      }
    });

    return elements;
  };

  return <View style={styles.container}>{parseMarkdown(children)}</View>;
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'column',
  },
  text: {
    fontSize: FontSize.md,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    lineHeight: FontSize.md * 1.5,
  },
  heading1: {
    fontSize: FontSize.xxl,
    color: Colors.white,
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
    marginTop: Spacing.md,
    marginBottom: Spacing.sm,
    lineHeight: FontSize.xxl * 1.2,
  },
  heading2: {
    fontSize: FontSize.xl,
    color: Colors.white,
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
    marginTop: Spacing.md,
    marginBottom: Spacing.xs,
    lineHeight: FontSize.xl * 1.3,
  },
  heading3: {
    fontSize: FontSize.lg,
    color: Colors.white,
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
    marginTop: Spacing.sm,
    marginBottom: Spacing.xs,
    lineHeight: FontSize.lg * 1.4,
  },
  bold: {
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
  },
  italic: {
    fontFamily: 'ProductSans-Italic',
    fontStyle: 'italic',
  },
  boldItalic: {
    fontFamily: 'ProductSans-BoldItalic',
    fontWeight: '700',
    fontStyle: 'italic',
  },
  bulletContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginVertical: Spacing.xs / 2,
    paddingLeft: Spacing.sm,
  },
  bullet: {
    fontSize: FontSize.md,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    marginRight: Spacing.sm,
    lineHeight: FontSize.md * 1.5,
  },
  number: {
    fontSize: FontSize.md,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    marginRight: Spacing.sm,
    minWidth: 20,
    lineHeight: FontSize.md * 1.5,
  },
  bulletText: {
    flex: 1,
    fontSize: FontSize.md,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    lineHeight: FontSize.md * 1.5,
  },
  mathContainer: {
    marginVertical: Spacing.sm,
    alignItems: 'center',
    minHeight: 50,
    width: '100%',
  },
  inlineTextContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    alignItems: 'flex-start',
    marginVertical: 1,
  },
  mathInlineWrapper: {
    height: 20,
    minWidth: 50,
    maxWidth: 200,
    marginHorizontal: 2,
    alignSelf: 'center',
    overflow: 'hidden',
  },
  mathInlineWebView: {
    backgroundColor: 'transparent',
    height: 20,
    width: '100%',
  },
  mathWebView: {
    backgroundColor: 'transparent',
    minHeight: 50,
  },
});


