# api_service/app/services/ai_service.py
import json
import re
from loguru import logger
from google import genai
from google.genai import types
from app.data.configs.app_settings import settings


# --- Configure Gemini client with single API key ---
try:
    client = genai.Client(api_key=settings.GEMINI_API_KEY)
    MODEL_NAME = settings.GEMINI_AI_MODEL
    logger.success("Gemini API configured successfully.")
except Exception as e:
    logger.critical(f"FATAL: Failed to configure Gemini API. AI features will be disabled. Error: {e}")
    client = None
    MODEL_NAME = None


# --- Load prompt template ---
PROMPT_TEMPLATE = ""
try:
    with open("app/data/prompts/get_insight.txt", "r") as f:
        PROMPT_TEMPLATE = f.read()
except FileNotFoundError:
    logger.error("FATAL: Prompt file 'get_insight.txt' not found!")


def _clean_json_response(raw_response: str) -> str:
    """Extract JSON from inside ```json ... ``` blocks if present."""
    match = re.search(r'```json\s*([\s\S]*?)\s*```', raw_response)
    if match:
        return match.group(1).strip()
    return raw_response.strip()


async def get_ai_insights(pr_data: dict) -> dict | None:
    """
    Generate AI insights for a PR using Gemini.
    Expects `pr_data` to have keys: pr_number, author, branch_name, title, files_changed.
    """
    if not client or not PROMPT_TEMPLATE:
        logger.error("AI service is not configured. Cannot get insights.")
        return None

    files_str = "\n".join(f"- {file}" for file in pr_data.get("files_changed", []))
    prompt = PROMPT_TEMPLATE.format(
        author=pr_data.get("author", "N/A"),
        branch_name=pr_data.get("branch_name", "N/A"),
        commit_message=pr_data.get("title", "N/A"),
        files_changed=files_str
    )

    pr_number = pr_data.get('pr_number')
    logger.info(f"Requesting AI insight for PR #{pr_number}")

    try:
        generation_config = types.GenerateContentConfig(
            temperature=0.3,
            max_output_tokens=1024,
        )
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=[{"role": "user", "parts": [{"text": prompt}]}],
            config=generation_config,
        )
        # --- FIX 1: DEFENSIVE CHECK ---
        # Check if the response or its text is empty before proceeding.
        if not response or not response.text:
            logger.warning(f"Gemini returned an empty response for PR #{pr_number}.")
            return None
        
        cleaned_response = _clean_json_response(response.text)
        
        # --- FIX 2: ISOLATED JSON PARSING ---
        try:
            insight_json = json.loads(cleaned_response)
            logger.success(f"Successfully generated and parsed AI insight for PR #{pr_number}")
            return insight_json
        except json.JSONDecodeError as e:
            # --- FIX 3: SAFE LOGGING ---
            # We log the problematic string as extra data, not in the main message.
            # This prevents the logger itself from crashing.
            logger.error(
                f"Failed to decode JSON from Gemini response for PR #{pr_number}",
                response_text=cleaned_response,
                exception=e
            )
        logger.success(f"Successfully generated AI insight for PR #{pr_number}")
        return insight_json

    except json.JSONDecodeError as e:
        logger.error(
            f"Failed to decode JSON from AI response for PR #{pr_number}. "
            f"Response: {response.text}",
            exception=e
        )
        return None
    except Exception as e:
        logger.error(f"An unexpected error occurred with Gemini API for PR #{pr_number}", exception=e)
        return None
