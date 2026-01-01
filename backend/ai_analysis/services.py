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
      "category": "Category Name (e.g., 'Red Blood Cell Status & Anemia Assessment', 'White Blood Cells & Immune Function', 'Platelet Function & Clotting Readiness')",
      "icon": "medical-outline",
      "biomarkers": ["Hemoglobin", "RBC"],
      "summary": "A brief one-line summary (max 100 characters) of what this section covers"
    }}
  ],
  "biomarker_insights": {{
    "Hemoglobin": {{
      "general": "A 2-3 sentence explanation of what this biomarker is and what it measures in general terms. Write as if explaining to someone who doesn't know what it is.",
      "specific": "A 2-4 sentence interpretation of THIS patient's specific result. Include the value, whether it's normal/high/low, and what this means for their health. Include any relevant recommendations or context.",
      "recommendations": "2-4 actionable health recommendations based on this specific result. Use web search to find evidence-based advice from reputable medical sources (Mayo Clinic, NIH, Cleveland Clinic, etc.). Include dietary suggestions, lifestyle changes, or when to see a doctor. Be specific and practical."
    }},
    "RBC": {{
      "general": "General explanation of this biomarker...",
      "specific": "Specific interpretation of the patient's result...",
      "recommendations": "Evidence-based recommendations for this result..."
    }}
  }}
}}
```

⚠️ CRITICAL ANALYSIS RULES - MUST FOLLOW EXACTLY:

1. **SECTION SEPARATION IS MANDATORY**: Create SEPARATE sections for EACH physiological system or functional category. DO NOT combine multiple systems into a single section.
   - INCORRECT: One section called "Blood Cell Analysis & Inflammation" with biomarkers ["Hemoglobin", "RBC", "WBC", "PLT", "ESR"]
   - CORRECT: Separate sections like "Red Blood Cell Status", "White Blood Cells & Immune Function", "Platelet Function" - each with only its own biomarkers

2. **Each Section Must Have Its Own Biomarkers Array**: Every section's "biomarkers" array must list ONLY the biomarkers that belong to that physiological system.
   - Red Blood Cell sections: ["Hemoglobin", "RBC", "HCT", "MCV", "MCH", "MCHC", "RDW-CV", "RDW-SD", "ESR"]
   - White Blood Cell sections: ["WBC", "NEU%", "LYM%", "MON%", "EOS%", "BAS%", "LYM#", "GRA#"]
   - Platelet sections: ["PLT"]

3. **Create Sections Dynamically**: The number and type of sections depends on what biomarkers are present in the test. Common groupings:
   - Red Blood Cell Status & Anemia Assessment
   - White Blood Cells & Immune Function
   - Platelet Function & Clotting Readiness
   - Kidney Function
   - Liver Function
   - Electrolytes & Kidney Balance
   - Glucose & Metabolic Health
   - Lipid Panel & Cholesterol Balance
   - Thyroid Function
   - Iron Status

4. **BIOMARKER_INSIGHTS IS REQUIRED**: You MUST include a "biomarker_insights" object with an entry for EVERY biomarker in test_results. Each entry must have "general", "specific", AND "recommendations" fields.
   - "general": Explain what the biomarker is and what it measures (educational, same for everyone)
   - "specific": Interpret THIS patient's specific value (personalized to their result)
   - "recommendations": Provide 2-4 actionable, evidence-based health recommendations. Search reputable medical sources for advice on diet, lifestyle, supplements, or when to see a doctor. Be practical and specific.

5. **Icons Match Categories**: 
   - 'body-outline' or 'medical-outline' for blood cell analysis
   - 'heart-outline' for cardiovascular/cholesterol
   - 'water-outline' for kidney/fluid/electrolytes
   - 'pulse-outline' for platelets/clotting
   - 'flask-outline' for liver/metabolic
   - 'speedometer-outline' for thyroid/metabolic rate

6. **Test Overview Synthesis**: The test_overview should provide a high-level summary of ALL findings across all sections, synthesizing the overall health picture.

7. **Every Biomarker Must Appear**: Ensure that every biomarker in test_results appears in:
   - At least one section's "biomarkers" array
   - The "biomarker_insights" object with both general and specific explanations

After the second JSON block, you may include additional detailed analysis text if needed."""

        # Call GPT-5.1 with responses API and web search enabled for recommendations
        response = self.client.responses.create(
            model="gpt-5.1",
            input=prompt,
            tools=[{"type": "web_search"}],
            reasoning={"effort": "medium"},
            text={"verbosity": "medium"}
        )
        
        output_text = response.output_text
        
        # Parse the response to extract JSON data, structured analysis, and remaining text
        parsed_data, structured_analysis, analysis_text = self._parse_gpt_response(output_text)
        
        logger.info("")
        logger.info("="*60)
        logger.info("✅ GPT-5.1 EXTRACTION & ANALYSIS COMPLETE (with web search)")
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
