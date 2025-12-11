import base64
import os
from io import BytesIO
from PIL import Image
from openai import OpenAI


class OpenAIService:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
    
    def encode_image_to_base64(self, image_file):
        """Convert image file to base64 string"""
        # Read image and convert if necessary
        image = Image.open(image_file)
        
        # Convert to RGB if necessary (for PNG with transparency, etc.)
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Save to bytes
        buffered = BytesIO()
        image.save(buffered, format="JPEG")
        img_bytes = buffered.getvalue()
        
        # Encode to base64
        return base64.b64encode(img_bytes).decode('utf-8')
    
    def parse_blood_test_image(self, image_file):
        """
        Use GPT-4o to parse blood test image and extract structured data
        Returns JSON with all blood test values
        """
        # Encode image
        base64_image = self.encode_image_to_base64(image_file)
        
        # Create prompt for parsing
        prompt = """
        You are a medical data extraction assistant. Analyze this blood test image and extract ALL visible data into a structured JSON format.
        
        Extract the following information:
        1. Patient information (if visible): name, age, date of test
        2. All blood test markers with their:
           - Name/abbreviation
           - Value
           - Unit
           - Reference range (normal range)
           - Status (normal, high, low) if indicated
        
        Return ONLY valid JSON in this exact format:
        {
            "patient_info": {
                "name": "string or null",
                "age": "string or null",
                "test_date": "string or null"
            },
            "test_results": [
                {
                    "marker": "marker name",
                    "value": "numeric value",
                    "unit": "unit of measurement",
                    "reference_range": "normal range as string",
                    "status": "normal|high|low|null"
                }
            ]
        }
        
        Be thorough and extract every visible test result. If information is unclear or not visible, use null.
        """
        
        # Call GPT-4o with vision
        response = self.client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            max_tokens=2000
        )
        
        # Extract JSON from response
        content = response.choices[0].message.content
        
        # Try to parse JSON (remove markdown code blocks if present)
        import json
        if content.startswith("```json"):
            content = content[7:]
        if content.startswith("```"):
            content = content[3:]
        if content.endswith("```"):
            content = content[:-3]
        
        return json.loads(content.strip())
    
    def analyze_blood_test(self, parsed_data):
        """
        Use GPT-5.1 to analyze the parsed blood test data
        Returns comprehensive medical analysis
        """
        import json
        
        # Create analysis prompt
        prompt = f"""
        You are an expert medical analyst specializing in blood test interpretation. 
        
        Analyze the following blood test results and provide a comprehensive, easy-to-understand analysis:
        
        {json.dumps(parsed_data, indent=2)}
        
        Provide your analysis in the following structure:
        
        1. OVERVIEW: Brief summary of overall health status based on the results
        
        2. DETAILED FINDINGS: For each abnormal or noteworthy marker:
           - What it measures
           - What the current value indicates
           - Potential health implications
           - Whether it's concerning or not
        
        3. NORMAL RESULTS: List which markers are within normal ranges (brief)
        
        4. RECOMMENDATIONS:
           - Lifestyle changes if applicable
           - Whether to consult a doctor
           - Any follow-up tests that might be needed
        
        5. IMPORTANT NOTES:
           - Remind that this is AI analysis and not a substitute for professional medical advice
           - Encourage consulting with healthcare provider for proper interpretation
        
        Be thorough but use clear, non-technical language when possible. When using medical terms, explain them.
        """
        
        # Call GPT-5.1 with responses API
        response = self.client.responses.create(
            model="gpt-5.1",
            input=prompt,
            reasoning={"effort": "medium"},
            text={"verbosity": "medium"}
        )
        
        return response.output_text
