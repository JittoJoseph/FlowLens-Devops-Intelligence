# api_service/app/services/ai_service.py
import json
import re
from loguru import logger
from google import genai
from google.genai import types
from app.data.configs.app_settings import settings

# --- Configure Gemini client ---
try:
    if settings.GEMINI_API_KEY:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        MODEL_NAME = settings.GEMINI_AI_MODEL
        logger.success("Gemini API configured successfully.")
    else:
        model = None
        logger.warning("GEMINI_API_KEY not found. AI features will be disabled.")
except Exception as e:
    logger.critical(f"FATAL: Failed to configure Gemini API. AI features will be disabled. Error: {e}")
    model = None

# --- Load prompt template ---
PROMPT_TEMPLATE = ""
try:
    with open("app/data/prompts/get_insight.txt", "r") as f:
        PROMPT_TEMPLATE = f.read()
except FileNotFoundError:
    logger.error("FATAL: Prompt file 'app/data/prompts/get_insight.txt' not found!")

def _clean_json_response(raw_response: str) -> str:
    """Extracts JSON from markdown code blocks if present."""
    match = re.search(r'```json\s*([\s\S]*?)\s*```', raw_response)
    if match:
        return match.group(1).strip()
    return raw_response.strip()

async def get_ai_insights(pr_data: dict) -> dict | None:
    """
    Generates AI insights for a PR using Gemini. Now resilient to API errors.
    Expects `pr_data` to have keys like: title, author, branch_name, etc.
    """
    if not model or not PROMPT_TEMPLATE:
        logger.error("AI service is not configured. Cannot get insights.")
        return None

    # The new `pull_requests` table doesn't have `files_changed`, so we remove it from the prompt for now.
    # In a future version, you could fetch this via GitHub API if needed.
    prompt = PROMPT_TEMPLATE.format(
        author=pr_data.get("author", "N/A"),
        branch_name=pr_data.get("branch_name", "N/A"),
        commit_message=pr_data.get("title", "N/A"),
        files_changed="N/A" # Placeholder as this data is not in the `pull_requests` table.
    )

    pr_number = pr_data.get('pr_number')
    logger.info(f"Requesting AI insight for PR #{pr_number}")

    try:
        generation_config = types.GenerateContentConfig(
            temperature=settings.AI_TEMP,
            max_output_tokens=settings.AI_MAX_TOKEN,
        )
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=[{"role": "user", "parts": [{"text": prompt}]}],
            config=generation_config,
        )        
        
        # --- FIX 1: DEFENSIVE CHECK for empty or invalid responses ---
        if not response or not hasattr(response, 'text') or not response.text:
            logger.warning(f"Gemini returned an empty or invalid response object for PR #{pr_number}.")
            return None
        
        cleaned_response = _clean_json_response(response.text)
        
        # --- FIX 2: ISOLATED JSON PARSING with robust error handling ---
        try:
            insight_json = json.loads(cleaned_response)
            logger.success(f"Successfully generated and parsed AI insight for PR #{pr_number}")
            return insight_json
        except json.JSONDecodeError as e:
            logger.error(
                f"Failed to decode JSON from Gemini response for PR #{pr_number}. The AI returned malformed JSON.",
                response_text=cleaned_response,
                exception=str(e)
            )
            return None

    except Exception as e:
        logger.error(f"An unexpected error occurred with the Gemini API for PR #{pr_number}", exception=e)
        return None