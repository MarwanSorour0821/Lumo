import os
import base64
from io import BytesIO
from PIL import Image
from openai import OpenAI
from .models import ChatMessage, ChatStorage
from .supabase_client import get_supabase_client


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
4. **Accurate but cautious** - Always remind users to consult healthcare professionals for medical decisions
5. **Concise** - Keep responses focused and not overly long

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
        
        # Get conversation history
        history = ChatMessage.get_conversation_history(user_id, conversation_minutes)
        
        # Build messages array for OpenAI
        messages = [
            {"role": "system", "content": self.SYSTEM_PROMPT}
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
        
        # Get conversation history (text only for context)
        history = ChatMessage.get_conversation_history(user_id, conversation_minutes)
        
        # Build messages - include history but use vision for the current image
        messages = [
            {"role": "system", "content": self.SYSTEM_PROMPT}
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
        
        # Get conversation history
        history = ChatMessage.get_conversation_history(user_id, conversation_minutes)
        
        # Build messages
        messages = [
            {"role": "system", "content": self.SYSTEM_PROMPT}
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

