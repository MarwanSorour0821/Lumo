"""
Service functions for supplement scheduling via OpenAI.
"""

import os
import json
import logging
from openai import OpenAI

# Configure logging
logger = logging.getLogger("suppsAI")

class SuppsAIOpenAIService:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

    def get_supplement_schedule(self, supplements):
        """
        Given a list of supplement names, send a prompt to OpenAI to get a recommended schedule.
        Returns: dict mapping supplement name to time string.
        Extensive logs for prompt, response, and errors.
        """
        prompt = (
            "A user wants to take these supplements daily: {}. "
            "Some vitamins and supplements interact and are best taken at certain times. "
            "Please create an optimal daily schedule for when to take each supplement. "
            "Return the result as a JSON object mapping supplement names to times (e.g. {{'magnesium': '7:00', 'zinc': '18:00'}})."
        ).format(", ".join(supplements))

        logger.info("\n" + "="*60)
        logger.info("🧠 SENDING SUPPLEMENT SCHEDULE PROMPT TO OPENAI")
        logger.info("Prompt:")
        logger.info(prompt)
        logger.info("="*60)

        try:
            response = self.client.chat.completions.create(
                model="gpt-5",
                messages=[{"role": "user", "content": prompt}],
            )
            logger.info("Received response from OpenAI:")
            logger.info(response)
            # Extract JSON from response
            content = response.choices[0].message.content
            logger.info("OpenAI response content:")
            logger.info(content)
            schedule = json.loads(content)
            logger.info("Parsed supplement schedule:")
            logger.info(schedule)
            return schedule
        except Exception as e:
            logger.error("Error communicating with OpenAI:")
            logger.error(str(e))
            raise
