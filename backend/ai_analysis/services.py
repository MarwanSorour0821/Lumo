import json
import os
import logging
from openai import OpenAI
from .textract_utils import parse_document_with_textract

# Configure logging
logger = logging.getLogger(__name__)


class OpenAIService:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
    
    def parse_blood_test_with_textract(self, file_obj, filename):
        """
        Use AWS Textract to parse blood test document.
        Returns the RAW Textract output - no processing.
        
        Args:
            file_obj: File-like object (image or PDF)
            filename: Original filename
            
        Returns:
            dict: Raw Textract structured data (tables, key-values, lines)
        """
        # Get structured data from Textract (raw, unprocessed)
        structured = parse_document_with_textract(file_obj, filename)
        
        logger.info("")
        logger.info("="*60)
        logger.info("📦 RAW TEXTRACT DATA (NO PROCESSING)")
        logger.info("="*60)
        logger.info(f"   Lines: {len(structured.get('lines', []))}")
        logger.info(f"   Key-Value Pairs: {len(structured.get('key_values', {}))}")
        logger.info(f"   Tables: {len(structured.get('tables', []))}")
        logger.info("="*60)
        
        # Return raw Textract output - GPT-5.1 will do the intelligent extraction
        return structured
    
    # Keep the old method for backward compatibility
    def parse_blood_test_image(self, image_file):
        """
        Parse blood test image using Textract.
        """
        filename = getattr(image_file, 'name', 'blood_test.jpg')
        
        if hasattr(image_file, 'seek'):
            image_file.seek(0)
        
        return self.parse_blood_test_with_textract(image_file, filename)
    
    def analyze_blood_test(self, raw_textract_data):
        """
        Use GPT-5.1 to BOTH extract biomarkers AND analyze them.
        Takes raw Textract output and lets GPT-5.1 do intelligent interpretation.
        
        Args:
            raw_textract_data: Raw Textract output with tables, key_values, lines
            
        Returns:
            dict: Contains both parsed_data (structured biomarkers) and analysis (text)
        """
        
        # Format the raw Textract data for GPT-5.1
        textract_summary = self._format_textract_for_gpt(raw_textract_data)
        
        logger.info("")
        logger.info("="*60)
        logger.info("🧠 SENDING RAW TEXTRACT DATA TO GPT-5.1")
        logger.info("="*60)
        
        # Single prompt for both extraction AND analysis
        prompt = f"""You are an expert medical analyst specializing in blood test interpretation.

I have OCR data from a blood test document parsed by AWS Textract. Your job is to:
1. EXTRACT the biomarkers/test results from this raw OCR data
2. ANALYZE them and provide medical interpretation

Here is the raw Textract OCR output:

{textract_summary}

---

Please respond with a JSON object followed by your analysis text.

FIRST, output a JSON block with the extracted data in this EXACT format:
```json
{{
  "patient_info": {{
    "name": "patient name or null",
    "age": "age or null",
    "sex": "sex/gender or null",
    "test_date": "date or null"
  }},
  "test_results": [
    {{
      "marker": "Test Name (e.g., Hemoglobin, RBC, WBC)",
      "value": "numeric value as string",
      "unit": "unit or null",
      "reference_range": "normal range or null",
      "status": "normal/high/low based on reference range, or null if can't determine"
    }}
  ]
}}
```

IMPORTANT EXTRACTION RULES:
- Only extract ACTUAL medical biomarkers/test results (Hemoglobin, RBC, WBC, Platelets, etc.)
- Do NOT include administrative fields like Patient ID, Test ID, Doctor name, Hospital address, etc.
- Look primarily at the TABLES for test results - they usually have columns like: Test Name | Result | Normal Range | Units
- The key-value pairs may contain patient info but are often noisy for biomarkers
- Compare each value to its reference range to determine status (high/low/normal)

THEN, after the JSON block, provide a SECOND JSON block with structured analysis in this EXACT format:
```json
{{
  "test_overview": "A high-level summary paragraph (2-4 sentences) that provides an overall interpretation of ALL biomarkers in this test. This should give a general health picture, highlighting key patterns, areas of concern, and positive aspects. Write naturally and clearly.",
  "sections": [
    {{
      "category": "Category Name (e.g., 'Cholesterol Balance', 'Liver Function', 'Blood Cell Analysis', 'Kidney Function')",
      "icon": "medical-outline",
      "biomarkers": ["Hemoglobin", "RBC"],
      "summary": "A brief one-line summary (max 100 characters) of what this section covers",
      "details": "Detailed explanation (2-4 paragraphs) covering ALL biomarkers in this category. For EACH biomarker in the category, explain: 1) What it measures, 2) What the current value indicates for THAT specific biomarker, 3) Health implications, 4) Any recommendations. Be specific about each biomarker mentioned in the 'biomarkers' array."
    }}
  ]
}}
```

IMPORTANT ANALYSIS RULES:
- Group biomarkers logically by function/system (e.g., all cholesterol markers together, all liver markers together, all blood cell counts together)
- Create sections dynamically based on what categories of biomarkers are present in the test
- The test_overview should synthesize ALL biomarkers into one cohesive summary
- Each section MUST include a "biomarkers" array listing the exact biomarker names (e.g., ["Hemoglobin", "RBC", "WBC"]) that belong to that section
- In the "details" field, explain EACH biomarker individually - what it measures, what the value means, implications
- Each section should focus on biomarkers that belong to the same physiological system or function
- Use clear, non-technical language. When using medical terms, explain them
- Icons should be from Ionicons: 'medical-outline', 'heart-outline', 'water-outline', 'pulse-outline', 'flask-outline', 'body-outline', 'speedometer-outline'
- Choose icons that match the category (heart for cardiovascular, water for kidney/fluid, etc.)
- Be thorough - every biomarker in test_results should be mentioned in at least one section

After the second JSON block, you may include additional detailed analysis text if needed."""

        # Call GPT-5.1 with responses API
        response = self.client.responses.create(
            model="gpt-5.1",
            input=prompt,
            reasoning={"effort": "medium"},
            text={"verbosity": "medium"}
        )
        
        output_text = response.output_text
        
        # Parse the response to extract JSON data, structured analysis, and remaining text
        parsed_data, structured_analysis, analysis_text = self._parse_gpt_response(output_text)
        
        logger.info("")
        logger.info("="*60)
        logger.info("✅ GPT-5.1 EXTRACTION & ANALYSIS COMPLETE")
        logger.info("="*60)
        logger.info(f"   Extracted {len(parsed_data.get('test_results', []))} biomarkers")
        logger.info(f"   Patient: {parsed_data.get('patient_info', {}).get('name', 'Unknown')}")
        if structured_analysis:
            logger.info(f"   Structured analysis: {len(structured_analysis.get('sections', []))} sections")
        
        return {
            "parsed_data": parsed_data,
            "analysis": analysis_text,
            "structured_analysis": structured_analysis
        }
    
    def _format_textract_for_gpt(self, structured):
        """
        Format raw Textract data into a clear text format for GPT-5.1.
        """
        parts = []
        
        # Add tables (most important for lab results)
        tables = structured.get('tables', [])
        if tables:
            parts.append("=== TABLES ===")
            for i, table in enumerate(tables, 1):
                parts.append(f"\nTable {i}:")
                for row_idx, row in enumerate(table):
                    row_str = " | ".join(str(cell) for cell in row)
                    parts.append(f"  Row {row_idx + 1}: {row_str}")
        
        # Add key-value pairs (useful for patient info)
        key_values = structured.get('key_values', {})
        if key_values:
            parts.append("\n=== KEY-VALUE PAIRS ===")
            for key, value in key_values.items():
                parts.append(f"  '{key}' → '{value}'")
        
        # Add text lines (backup context)
        lines = structured.get('lines', [])
        if lines:
            parts.append("\n=== TEXT LINES (first 50) ===")
            for i, line in enumerate(lines[:50], 1):
                parts.append(f"  {i}. {line}")
            if len(lines) > 50:
                parts.append(f"  ... and {len(lines) - 50} more lines")
        
        return "\n".join(parts)
    
    def _parse_gpt_response(self, output_text):
        """
        Parse GPT-5.1 response to extract JSON data, structured analysis, and remaining text.
        """
        import re
        
        parsed_data = {
            "patient_info": {"name": None, "age": None, "sex": None, "test_date": None},
            "test_results": []
        }
        structured_analysis = None
        analysis_text = output_text
        
        # Extract all JSON blocks
        json_matches = list(re.finditer(r'```json\s*([\s\S]*?)\s*```', output_text))
        
        if json_matches:
            # First JSON block is the parsed_data (biomarkers)
            try:
                json_str = json_matches[0].group(1)
                parsed_data = json.loads(json_str)
                logger.info(f"✅ Parsed biomarker data: {len(parsed_data.get('test_results', []))} markers")
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse first JSON block from GPT response: {e}")
            
            # Second JSON block is the structured analysis (if present)
            if len(json_matches) > 1:
                try:
                    json_str = json_matches[1].group(1)
                    structured_analysis = json.loads(json_str)
                    logger.info(f"✅ Parsed structured analysis: {len(structured_analysis.get('sections', []))} sections")
                except json.JSONDecodeError as e:
                    logger.warning(f"Failed to parse second JSON block (structured analysis): {e}")
            
            # Remove all JSON blocks from analysis text
            last_match_end = json_matches[-1].end()
            analysis_text = output_text[last_match_end:].strip()
            # Clean up any leading dashes or whitespace
            analysis_text = re.sub(r'^[\s\-]*', '', analysis_text)
        
        return parsed_data, structured_analysis, analysis_text
