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
        MODEL_NAME = None
        logger.warning("GEMINI_API_KEY not found. AI features will be disabled.")
except Exception as e:
    logger.critical(f"FATAL: Failed to configure Gemini API. AI features will be disabled. Error: {e}")
    MODEL_NAME = None

# --- Load prompt template ---
PROMPT_TEMPLATE = ""
try:
    with open("app/data/prompts/get_insight.txt", "r") as f:
        PROMPT_TEMPLATE = f.read()
except FileNotFoundError:
    logger.error("FATAL: Prompt file 'app/data/prompts/get_insight.txt' not found!")

def _clean_json_response(raw_response: str) -> str:
    """Extracts JSON from markdown code blocks and cleans the response."""
    # Remove markdown code blocks
    response = raw_response.strip()
    
    # Try to extract from ```json blocks first
    json_match = re.search(r'```json\s*([\s\S]*?)\s*```', response)
    if json_match:
        response = json_match.group(1).strip()
    else:
        # Try to extract from ``` blocks without json label
        code_match = re.search(r'```\s*([\s\S]*?)\s*```', response)
        if code_match:
            response = code_match.group(1).strip()
    
    # Find JSON object by looking for { ... } pattern
    json_pattern = re.search(r'\{[\s\S]*\}', response)
    if json_pattern:
        response = json_pattern.group(0)
    
    # Clean up any remaining markdown or extra text
    response = response.strip()
    
    # If response doesn't start with {, try to find the first {
    if not response.startswith('{'):
        start_index = response.find('{')
        if start_index != -1:
            response = response[start_index:]
    
    return response


def _format_files_changed(files_changed: list) -> str:
    """Formats the files_changed JSON data into a readable string for the AI prompt."""
    if not files_changed:
        return "No files changed"
    
    formatted_files = []
    for file_data in files_changed:
        filename = file_data.get('filename', 'unknown')
        status = file_data.get('status', 'unknown')
        additions = file_data.get('additions', 0)
        deletions = file_data.get('deletions', 0)
        changes = file_data.get('changes', 0)
        
        # Include patch data if available (truncated for brevity)
        patch = file_data.get('patch', '')
        if patch and len(patch) > 500:
            patch = patch[:500] + "... [truncated]"
        
        file_summary = f"- {filename} ({status}): +{additions}/-{deletions} ({changes} changes)"
        if patch:
            file_summary += f"\n  Patch preview: {patch[:200]}..."
        
        formatted_files.append(file_summary)
    
    return "\n".join(formatted_files)


async def get_ai_insights(pr_data: dict) -> dict | None:
    """
    Generates AI insights for a PR using Gemini with enhanced files_changed analysis.
    Expects `pr_data` to have keys like: title, author, branch_name, files_changed, etc.
    Returns clean JSON with risk_level, summary, recommendation fields.
    """
    if not MODEL_NAME or not PROMPT_TEMPLATE:
        logger.error("AI service is not configured. Cannot get insights.")
        return None

    # Extract and format files_changed data from the new schema
    files_changed = pr_data.get("files_changed", [])
    
    # Handle case where files_changed might be a JSON string
    if isinstance(files_changed, str):
        try:
            files_changed = json.loads(files_changed)
        except json.JSONDecodeError:
            logger.warning("Invalid JSON in files_changed data")
            return None
    
    if not files_changed:
        logger.warning("No files_changed data available for AI analysis")
        return None
    
    formatted_files = _format_files_changed(files_changed)
    
    # Build enhanced prompt with actual file change data
    prompt = PROMPT_TEMPLATE.format(
        author=pr_data.get("author", "N/A"),
        branch_name=pr_data.get("branch_name", "N/A"),
        commit_message=pr_data.get("title", "N/A"),
        files_changed=formatted_files
    )

    pr_number = pr_data.get('pr_number')
    repo_id = pr_data.get('repo_id')
    logger.info(f"Requesting AI insight for PR #{pr_number} in repository {repo_id}")

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
        
        logger.info(f"Raw Gemini response structure: {type(response)}")
        
        # Extract the text from the response using the correct structure
        raw_response = None
        if hasattr(response, 'candidates') and response.candidates:
            candidate = response.candidates[0]
            if hasattr(candidate, 'content') and hasattr(candidate.content, 'parts') and candidate.content.parts:
                raw_response = candidate.content.parts[0].text
                logger.info(f"Extracted text from response: {raw_response[:200]}...")
            else:
                logger.warning(f"Gemini response missing content/parts structure for PR #{pr_number}.")
                return None
        elif hasattr(response, 'text') and response.text:
            # Fallback for older API structure
            raw_response = response.text
            logger.info(f"Using fallback response.text: {raw_response[:200]}...")
        else:
            logger.warning(f"Gemini returned an empty or invalid response for PR #{pr_number}.")
            return None
        
        if not raw_response:
            logger.warning(f"No text content found in Gemini response for PR #{pr_number}.")
            return None
        
        cleaned_response = _clean_json_response(raw_response)
        
        # Parse JSON response with robust error handling
        try:
            insight_json = json.loads(cleaned_response)
            
            # Clean and validate the response to match our schema exactly
            cleaned_insight = {
                "risk_level": insight_json.get('risk_level', insight_json.get('riskLevel', 'low')).lower(),
                "summary": insight_json.get('summary', 'AI analysis completed'),
                "recommendation": insight_json.get('recommendation', 'Review changes carefully')
            }
            
            # Validate risk_level is one of the allowed values
            if cleaned_insight['risk_level'] not in ['low', 'medium', 'high']:
                cleaned_insight['risk_level'] = 'low'
            
            logger.success(f"Successfully generated AI insight for PR #{pr_number}")
            return cleaned_insight
            
        except json.JSONDecodeError as e:
            # Safe logging to avoid format string conflicts with JSON braces
            response_preview = cleaned_response[:200] + "..." if len(cleaned_response) > 200 else cleaned_response
            response_preview = response_preview.replace('{', '{{').replace('}', '}}')  # Escape braces for logging
            
            logger.error(
                f"Failed to decode JSON from Gemini response for PR #{pr_number}. "
                f"Response preview: {response_preview} | Error: {str(e)}"
            )
            return None

    except Exception as e:
        logger.error(f"Unexpected error with Gemini API for PR #{pr_data['pr_number']}: {str(e)}")
        return None