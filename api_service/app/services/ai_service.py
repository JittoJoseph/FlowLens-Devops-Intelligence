# api_service/app/services/ai_service.py

import json
import re
from loguru import logger
from google import genai
from google.genai import types
from app.data.configs.app_settings import settings

# Configure the Gemini API client
try:
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-1.5-flash')
    logger.success("Gemini API configured successfully.")
except Exception as e:
    logger.critical(f"Failed to configure Gemini API: {e}")
    model = None

def load_prompt_template() -> str:
    """Loads the prompt from the text file."""
    try:
        with open("app/data/prompts/get_insight.txt", "r") as f:
            return f.read()
    except FileNotFoundError:
        logger.error("Prompt file 'get_insight.txt' not found!")
        return ""

PROMPT_TEMPLATE = load_prompt_template()

def _clean_json_response(raw_response: str) -> str:
    """Cleans the typical markdown formatting from AI JSON responses."""
    # Find the JSON block within ```json ... ```
    match = re.search(r'```json\s*([\s\S]*?)\s*```', raw_response)
    if match:
        return match.group(1).strip()
    # Fallback for responses without markdown
    return raw_response.strip()

async def get_ai_insights(pr_data: dict) -> dict | None:
    """
    Generates AI insights for a pull request using the Gemini API.
    """
    if not model or not PROMPT_TEMPLATE:
        logger.error("AI service is not configured. Cannot get insights.")
        return None

    # Prepare the files_changed string for the prompt
    files_str = "\n".join(f"- {file}" for file in pr_data.get("files_changed", []))

    prompt = PROMPT_TEMPLATE.format(
        author=pr_data.get("author", "N/A"),
        branch_name=pr_data.get("branch_name", "N/A"),
        commit_message=pr_data.get("title", "N/A"),
        files_changed=files_str
    )
    
    logger.info(f"Requesting AI insight for PR #{pr_data.get('pr_number')}")
    try:
        response = await model.generate_content_async(prompt)
        cleaned_response = _clean_json_response(response.text)
        
        insight_json = json.loads(cleaned_response)
        logger.success(f"Successfully generated AI insight for PR #{pr_data.get('pr_number')}")
        return insight_json

    except json.JSONDecodeError as e:
        logger.error(f"Failed to decode JSON from AI response: {e}. Response was: {response.text}")
        return None
    except Exception as e:
        logger.error(f"An unexpected error occurred with Gemini API: {e}")
        return None