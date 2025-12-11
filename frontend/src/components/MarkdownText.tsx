import React from 'react';
import { Text, StyleSheet, View } from 'react-native';
import { Colors, FontSize, Spacing } from '../constants/theme';

interface MarkdownTextProps {
  children: string;
  style?: object;
}

interface ParsedSegment {
  type: 'text' | 'bold' | 'italic' | 'bolditalic' | 'bullet' | 'numbered';
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
  const parseInlineMarkdown = (text: string): React.ReactNode[] => {
    const elements: React.ReactNode[] = [];
    let remaining = text;
    let key = 0;

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
      const nextSpecial = remaining.search(/\*/);
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

    return elements;
  };

  const parseMarkdown = (text: string): React.ReactNode[] => {
    const lines = text.split('\n');
    const elements: React.ReactNode[] = [];

    lines.forEach((line, index) => {
      const trimmedLine = line.trim();
      
      // Check for headings (#, ##, ###)
      if (trimmedLine.startsWith('### ')) {
        const headingContent = trimmedLine.slice(4);
        elements.push(
          <Text key={index} style={[styles.heading3, style]}>
            {parseInlineMarkdown(headingContent)}
          </Text>
        );
      }
      else if (trimmedLine.startsWith('## ')) {
        const headingContent = trimmedLine.slice(3);
        elements.push(
          <Text key={index} style={[styles.heading2, style]}>
            {parseInlineMarkdown(headingContent)}
          </Text>
        );
      }
      else if (trimmedLine.startsWith('# ')) {
        const headingContent = trimmedLine.slice(2);
        elements.push(
          <Text key={index} style={[styles.heading1, style]}>
            {parseInlineMarkdown(headingContent)}
          </Text>
        );
      }
      // Check for bullet points
      else if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('* ')) {
        const bulletContent = trimmedLine.slice(2);
        elements.push(
          <View key={index} style={styles.bulletContainer}>
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
            <View key={index} style={styles.bulletContainer}>
              <Text style={[styles.number, style]}>{match[1]}.</Text>
              <Text style={[styles.bulletText, style]}>
                {parseInlineMarkdown(match[2])}
              </Text>
            </View>
          );
        }
      }
      // Regular text
      else {
        elements.push(
          <Text key={index} style={[styles.text, style]}>
            {parseInlineMarkdown(trimmedLine)}
            {index < lines.length - 1 ? '\n' : ''}
          </Text>
        );
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
});
