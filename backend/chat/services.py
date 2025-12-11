import os
from openai import OpenAI
from .models import ChatMessage


class ChatService:
    """
    Service for handling chat interactions with OpenAI.
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

You can help users:
- Understand their blood test results
- Learn about health markers and what they mean
- Get general health and wellness advice
- Understand when to seek medical attention

Always include a brief disclaimer when giving health-related advice that users should consult with their healthcare provider for personalized medical advice.

Do NOT:
- Diagnose conditions
- Prescribe treatments
- Make definitive medical conclusions
- Discourage users from seeing doctors"""

    def __init__(self):
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
    
    def get_response(self, user_id: str, user_message: str, conversation_minutes: int = 30) -> str:
        """
        Get a response from the AI for the user's message.
        Maintains conversation context within the specified time window.
        """
        # Save the user's message first
        ChatMessage.objects.create(
            user_id=user_id,
            role='user',
            content=user_message
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
            model="gpt-4o-mini",  # Cost-effective model for chat
            messages=messages,
            max_tokens=1000,
            temperature=0.7,
        )
        
        assistant_message = response.choices[0].message.content
        
        # Save the assistant's response
        ChatMessage.objects.create(
            user_id=user_id,
            role='assistant',
            content=assistant_message
        )
        
        return assistant_message
    
    def clear_conversation(self, user_id: str) -> int:
        """
        Clear all messages for a user.
        Returns the number of messages deleted.
        """
        deleted_count, _ = ChatMessage.objects.filter(user_id=user_id).delete()
        return deleted_count


# Singleton instance
chat_service = ChatService()
