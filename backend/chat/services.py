import os
import base64
from io import BytesIO
from PIL import Image
from openai import OpenAI
from django.db import connection
from .models import ChatMessage, ChatStorage


class ChatService:
    """
    Service for handling chat interactions with OpenAI.
    Supports text messages, images (via Vision), and PDFs.
    """
    
    SYSTEM_PROMPT = """You are Lumo, a friendly and knowledgeable health assistant specializing in blood test analysis and general health advice. Your responses should be:

1. **Warm and supportive** - Use a caring, professional tone
2. **Clear and accessible** - Explain medical terms in simple language
3. **Well-formatted** - Use markdown formatting:
   - **Bold** for important terms or emphasis
   - *Italics* for medical terminology (with explanations)
   - Bullet points for lists
   - Numbered lists for steps or procedures
4. **Mathematical expressions** - ALL formulas, calculations, and mathematical expressions MUST be formatted in LaTeX:
   - For inline math (within a sentence): Use \\(formula\\) or $formula$
   - For display math (centered, on its own line): Use \\[formula\\] or $$formula$$
   - Example: \\[\\text{BMI} = \\frac{\\text{weight (kg)}}{\\text{height (m)}^2}\\]
   - **IMPORTANT**: Every mathematical expression, equation, formula, or calculation MUST be wrapped in LaTeX delimiters. Do not include raw mathematical notation without LaTeX formatting.
5. **Accurate but cautious** - Always remind users to consult healthcare professionals for medical decisions
6. **Concise** - Keep responses focused and not overly long

**IMPORTANT - Scope of Knowledge:**
You are specifically trained and experienced in health-related topics including:
- Blood test analysis and interpretation
- Health markers and what they mean
- General health and wellness advice
- Medical document analysis
- Understanding when to seek medical attention
- Nutrition and lifestyle factors affecting health
- Common health conditions and symptoms

**If a user asks about topics NOT related to health, medicine, wellness, or medical topics** (such as technology, cooking recipes, travel, sports, entertainment, etc.), you must politely redirect them with a response like:

"I'm specialized in health and wellness topics, so I don't have knowledge about [topic]. However, I'm well-trained and experienced in health-related matters! I can help you with:
- Understanding blood test results
- Health and wellness questions
- Medical document analysis
- General health advice

Is there anything health-related I can assist you with instead?"

Always include a brief disclaimer when giving health-related advice that users should consult with their healthcare provider for personalized medical advice.

**User Information:**
You will be provided with the user's personal information (name, age, biological sex, height, weight) in the system message below. **IMPORTANT:** When users ask about their personal information (like "What's my name?", "How old am I?", "What's my height?", etc.), you MUST use the provided user information to answer their questions directly. Do NOT say you don't have access to this information - it is provided to you in the system message. Answer naturally and directly using the information provided. For example, if a user asks "What's my name?" and the system message includes "Name: John Doe", you should respond with "Your name is John Doe" or simply "John Doe". This information is provided to help you give personalized health advice and answer questions about the user's own data.

Do NOT:
- Diagnose conditions
- Prescribe treatments
- Make definitive medical conclusions
- Discourage users from seeing doctors
- Answer questions about non-health topics (redirect instead)"""

    # Max file sizes
    MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB
    MAX_PDF_SIZE = 10 * 1024 * 1024    # 10MB
    
    ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
    ALLOWED_PDF_TYPES = ['application/pdf']

    def __init__(self):
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
    
    def get_user_profile_info(self, user_id: str) -> dict:
        """
        Fetch user profile information from Supabase using Django's database connection.
        Returns a dictionary with user information or empty dict if not found.
        """
        try:
            # Use Django's database connection to query Supabase PostgreSQL directly
            with connection.cursor() as cursor:
                # Query the public.users table (not auth.users)
                cursor.execute("""
                    SELECT 
                        first_name, 
                        last_name, 
                        biological_sex, 
                        date_of_birth, 
                        height_cm, 
                        weight_kg, 
                        email
                    FROM public.users
                    WHERE id = %s
                """, [user_id])
                
                row = cursor.fetchone()
                
                if row:
                    user_info = {
                        'first_name': row[0],
                        'last_name': row[1],
                        'biological_sex': row[2],
                        'date_of_birth': row[3],
                        'height_cm': row[4],
                        'weight_kg': row[5],
                        'email': row[6],
                    }
                    return user_info
                    
            return {}
        except Exception as e:
            return {}
    
    def build_user_context_prompt(self, user_profile: dict) -> str:
        """
        Build a user context string from profile information to include in the system prompt.
        """
        if not user_profile:
            return ""
        
        context_parts = []
        
        if user_profile.get('first_name'):
            context_parts.append(f"Name: {user_profile['first_name']}")
            if user_profile.get('last_name'):
                context_parts[-1] += f" {user_profile['last_name']}"
        
        if user_profile.get('biological_sex'):
            sex = user_profile['biological_sex']
            context_parts.append(f"Biological Sex: {sex.capitalize()}")
        
        if user_profile.get('date_of_birth'):
            # Calculate age from date of birth
            try:
                from datetime import datetime
                dob_str = user_profile['date_of_birth']
                # Handle different date formats
                if 'T' in dob_str:
                    # ISO format with time
                    dob = datetime.fromisoformat(dob_str.replace('Z', '+00:00'))
                else:
                    # Date only format
                    dob = datetime.fromisoformat(dob_str)
                
                # Calculate age
                today = datetime.now(dob.tzinfo) if dob.tzinfo else datetime.now()
                age = (today - dob).days // 365
                context_parts.append(f"Age: {age} years old")
            except Exception:
                # If parsing fails, just include the date as-is
                context_parts.append(f"Date of Birth: {user_profile['date_of_birth']}")
        
        if user_profile.get('height_cm'):
            context_parts.append(f"Height: {user_profile['height_cm']} cm")
        
        if user_profile.get('weight_kg'):
            context_parts.append(f"Weight: {user_profile['weight_kg']} kg")
        
        if not context_parts:
            return ""
        
        user_context = "\n\n**Current User's Information (use this when answering questions about the user):**\n" + "\n".join(f"- {part}" for part in context_parts)
        return user_context
    
    def encode_image_to_base64(self, image_bytes: bytes) -> str:
        """Convert image bytes to base64 string with resize/compression."""
        image = Image.open(BytesIO(image_bytes))
        
        # Convert to RGB if necessary (for PNG with transparency, etc.)
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Resize if too large (max 2048px on longest side for efficiency)
        max_size = 2048
        if max(image.size) > max_size:
            ratio = max_size / max(image.size)
            new_size = (int(image.size[0] * ratio), int(image.size[1] * ratio))
            image = image.resize(new_size, Image.Resampling.LANCZOS)
        
        # Save to bytes
        buffered = BytesIO()
        image.save(buffered, format="JPEG", quality=85)
        img_bytes = buffered.getvalue()
        
        return base64.b64encode(img_bytes).decode('utf-8')
    
    def extract_pdf_text(self, pdf_bytes: bytes) -> str:
        """Extract text from PDF bytes."""
        try:
            import fitz  # PyMuPDF
            
            text_parts = []
            with fitz.open("pdf", pdf_bytes) as doc:
                for page_num, page in enumerate(doc, 1):
                    text = page.get_text()
                    if text.strip():
                        text_parts.append(f"--- Page {page_num} ---\n{text}")
            
            full_text = "\n\n".join(text_parts)
            
            # Truncate if too long (max ~8000 chars to leave room for response)
            if len(full_text) > 8000:
                full_text = full_text[:8000] + "\n\n[Document truncated due to length...]"
            
            return full_text
        except ImportError:
            # Fallback to PyPDF2 if PyMuPDF not available
            try:
                import PyPDF2
                
                text_parts = []
                reader = PyPDF2.PdfReader(BytesIO(pdf_bytes))
                for page_num, page in enumerate(reader.pages, 1):
                    text = page.extract_text()
                    if text.strip():
                        text_parts.append(f"--- Page {page_num} ---\n{text}")
                
                full_text = "\n\n".join(text_parts)
                
                if len(full_text) > 8000:
                    full_text = full_text[:8000] + "\n\n[Document truncated due to length...]"
                
                return full_text
            except ImportError:
                return "[Unable to extract PDF text - PDF library not installed]"
    
    def get_response(self, user_id: str, user_message: str, conversation_minutes: int = 30) -> str:
        """
        Get a response from the AI for the user's text message.
        Maintains conversation context within the specified time window.
        """
        # Save the user's message first
        ChatMessage.objects.create(
            user_id=user_id,
            role='user',
            content=user_message,
            message_type='text'
        )
        
        # Get user profile information
        user_profile = self.get_user_profile_info(user_id)
        user_context = self.build_user_context_prompt(user_profile)
        system_prompt = self.SYSTEM_PROMPT + user_context
        
        # Get conversation history
        history = ChatMessage.get_conversation_history(user_id, conversation_minutes)
        
        # Build messages array for OpenAI
        messages = [
            {"role": "system", "content": system_prompt}
        ]
        messages.extend(history)
        
        # Call OpenAI API
        response = self.client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            max_tokens=1000,
            temperature=0.7,
        )
        
        assistant_message = response.choices[0].message.content
        
        # Save the assistant's response
        ChatMessage.objects.create(
            user_id=user_id,
            role='assistant',
            content=assistant_message,
            message_type='text'
        )
        
        return assistant_message
    
    def upload_to_storage(self, file_bytes: bytes, file_name: str, content_type: str) -> str:
        """Upload file bytes to Supabase storage and return storage path."""
        # Use storage3 directly to avoid gotrue proxy issue
        from storage3 import create_client as create_storage_client
        
        url = os.getenv('SUPABASE_URL') or os.getenv('SUPABASE_PROJECT_URL')
        key = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_KEY') or os.getenv('SUPABASE_ANON_KEY')
        
        if not url or not key:
            raise RuntimeError('Supabase credentials are missing.')
        
        bucket = ChatStorage.bucket_name()
        path = f"chat/{file_name}"
        
        # Create storage client directly (bypasses auth client)
        storage_url = f"{url}/storage/v1"
        storage_client = create_storage_client(
            url=storage_url,
            is_async=False,
            headers={"apikey": key, "Authorization": f"Bearer {key}"}
        )
        
        # Upload file
        storage_client.from_(bucket).upload(path, file_bytes, {"content-type": content_type, "upsert": "true"})
        return path

    def get_response_with_image(
        self, 
        user_id: str, 
        image_bytes: bytes, 
        file_name: str,
        file_size: int,
        user_message: str = None,
        conversation_minutes: int = 30,
        content_type: str = "image/jpeg",
    ) -> str:
        """
        Get a response from the AI for an image attachment.
        Uses GPT-4o Vision to analyze the image.
        """
        # Upload to storage
        storage_path = self.upload_to_storage(image_bytes, file_name, content_type)

        # Encode image
        base64_image = self.encode_image_to_base64(image_bytes)
        
        # Create prompt
        prompt = user_message if user_message else "Please analyze this image and provide any relevant health insights."
        
        # Save the user's image message
        ChatMessage.objects.create(
            user_id=user_id,
            role='user',
            content=f"[Shared an image: {file_name}] {prompt}",
            message_type='image',
            file_name=file_name,
            storage_path=storage_path,
            file_size=file_size
        )
        
        # Get user profile information
        user_profile = self.get_user_profile_info(user_id)
        user_context = self.build_user_context_prompt(user_profile)
        system_prompt = self.SYSTEM_PROMPT + user_context
        
        # Get conversation history (text only for context)
        history = ChatMessage.get_conversation_history(user_id, conversation_minutes)
        
        # Build messages - include history but use vision for the current image
        messages = [
            {"role": "system", "content": system_prompt}
        ]
        
        # Add history (excluding the just-added image message)
        for msg in history[:-1]:
            messages.append(msg)
        
        # Add the image message with vision
        messages.append({
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{base64_image}",
                        "detail": "high"
                    }
                }
            ]
        })
        
        # Call OpenAI API with vision model
        response = self.client.chat.completions.create(
            model="gpt-4o",  # Use gpt-4o for vision
            messages=messages,
            max_tokens=1500,
            temperature=0.7,
        )
        
        assistant_message = response.choices[0].message.content
        
        # Save the assistant's response
        ChatMessage.objects.create(
            user_id=user_id,
            role='assistant',
            content=assistant_message,
            message_type='text'
        )
        
        return assistant_message
    
    def get_response_with_pdf(
        self, 
        user_id: str, 
        pdf_bytes: bytes, 
        file_name: str,
        file_size: int,
        user_message: str = None,
        conversation_minutes: int = 30,
        content_type: str = "application/pdf",
    ) -> str:
        """
        Get a response from the AI for a PDF attachment.
        Extracts text from PDF and sends to GPT for analysis.
        """
        # Extract text from PDF
        pdf_text = self.extract_pdf_text(pdf_bytes)
        
        # Create prompt
        base_prompt = user_message if user_message else "Please analyze this document and provide any relevant health insights."
        full_prompt = f"{base_prompt}\n\n--- Document Content ---\n{pdf_text}"
        
        # Save the user's PDF message
        storage_path = self.upload_to_storage(pdf_bytes, file_name, content_type)

        ChatMessage.objects.create(
            user_id=user_id,
            role='user',
            content=f"[Shared a PDF: {file_name}] {base_prompt}",
            message_type='pdf',
            file_name=file_name,
            storage_path=storage_path,
            file_size=file_size
        )
        
        # Get user profile information
        user_profile = self.get_user_profile_info(user_id)
        user_context = self.build_user_context_prompt(user_profile)
        system_prompt = self.SYSTEM_PROMPT + user_context
        
        # Get conversation history
        history = ChatMessage.get_conversation_history(user_id, conversation_minutes)
        
        # Build messages
        messages = [
            {"role": "system", "content": system_prompt}
        ]
        
        # Add history (excluding the just-added PDF message)
        for msg in history[:-1]:
            messages.append(msg)
        
        # Add the PDF analysis request
        messages.append({
            "role": "user",
            "content": full_prompt
        })
        
        # Call OpenAI API
        response = self.client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            max_tokens=1500,
            temperature=0.7,
        )
        
        assistant_message = response.choices[0].message.content
        
        # Save the assistant's response
        ChatMessage.objects.create(
            user_id=user_id,
            role='assistant',
            content=assistant_message,
            message_type='text'
        )
        
        return assistant_message
    
    def clear_conversation(self, user_id: str) -> int:
        """
        Clear all messages for a user.
        Returns the number of messages deleted.
        Also deletes associated files.
        """
        messages = ChatMessage.objects.filter(user_id=user_id)
        for msg in messages:
            msg.delete_file()
        deleted_count, _ = messages.delete()
        return deleted_count


# Singleton instance
chat_service = ChatService()


