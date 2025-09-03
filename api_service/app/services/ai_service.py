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


def _format_files_changed(files_changed: list, max_total_length: int = 4000) -> str:
    """
    Formats the files_changed JSON data into a readable string for the AI prompt.
    Includes intelligent truncation to stay within token limits.
    """
    if not files_changed:
        return "No files changed"
    
    formatted_files = []
    current_length = 0
    
    for i, file_data in enumerate(files_changed):
        filename = file_data.get('filename', 'unknown')
        status = file_data.get('status', 'unknown')
        additions = file_data.get('additions', 0)
        deletions = file_data.get('deletions', 0)
        changes = file_data.get('changes', 0)
        
        # Start with basic file info
        file_summary = f"- {filename} ({status}): +{additions}/-{deletions} ({changes} changes)"
        
        # Include patch data if available and within limits
        patch = file_data.get('patch', '')
        if patch:
            # Determine how much patch to include based on remaining space
            remaining_space = max_total_length - current_length - len(file_summary)
            
            if remaining_space > 200:  # Only include patch if we have decent space
                patch_preview_length = min(len(patch), remaining_space - 50, 500)
                patch_preview = patch[:patch_preview_length]
                if len(patch) > patch_preview_length:
                    patch_preview += "... [truncated]"
                file_summary += f"\n  Patch preview: {patch_preview}"
            else:
                file_summary += f"\n  Patch: {len(patch)} characters (truncated for space)"
        
        # Check if adding this file would exceed our limit
        if current_length + len(file_summary) > max_total_length:
            remaining_files = len(files_changed) - i
            if remaining_files > 0:
                formatted_files.append(f"... and {remaining_files} more files (truncated for API limits)")
            break
        
        formatted_files.append(file_summary)
        current_length += len(file_summary)
    
    result = "\n".join(formatted_files)
    logger.debug(f"Formatted files_changed: {len(result)} characters from {len(files_changed)} files")
    return result


async def get_ai_insights(pr_data: dict) -> dict | None:
    """
    Generates AI insights for a PR using Gemini with enhanced files_changed analysis.
    Expects `pr_data` to have keys like: title, author, branch_name, files_changed, etc.
    Returns clean JSON with risk_level, summary, recommendation fields.
    Enhanced with better error handling and data size management.
    """
    if not MODEL_NAME or not PROMPT_TEMPLATE:
        logger.error("AI service is not configured. Cannot get insights.")
        return None

    pr_number = pr_data.get('pr_number')
    repo_id = pr_data.get('repo_id')
    
    try:
        # Extract and format files_changed data from the new schema
        files_changed = pr_data.get("files_changed", [])
        
        # Handle case where files_changed might be a JSON string
        if isinstance(files_changed, str):
            try:
                files_changed = json.loads(files_changed)
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON in files_changed data for PR #{pr_number}")
                return None
        
        if not files_changed:
            logger.warning(f"No files_changed data available for AI analysis of PR #{pr_number}")
            return None
        
        # Calculate total patch size for logging
        total_patch_size = sum(len(f.get('patch', '')) for f in files_changed)
        logger.info(f"PR #{pr_number}: Processing {len(files_changed)} files, total patch size: {total_patch_size} chars")
        
        # Format files with intelligent truncation
        formatted_files = _format_files_changed(files_changed, max_total_length=4000)
        
        # Build enhanced prompt with actual file change data
        prompt = PROMPT_TEMPLATE.format(
            author=pr_data.get("author", "N/A"),
            branch_name=pr_data.get("branch_name", "N/A"),
            commit_message=pr_data.get("title", "N/A"),
            files_changed=formatted_files
        )

        # Check prompt size
        prompt_length = len(prompt)
        if prompt_length > 6000:
            logger.warning(f"Large prompt for PR #{pr_number}: {prompt_length} characters")
        
        logger.info(f"Requesting AI insight for PR #{pr_number} in repository {repo_id}")

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
        
        # Check for finish_reason to understand why response might be incomplete
        if hasattr(response, 'candidates') and response.candidates:
            candidate = response.candidates[0]
            finish_reason = getattr(candidate, 'finish_reason', None)
            if finish_reason and str(finish_reason) == 'MAX_TOKENS':
                logger.warning(f"Gemini response truncated due to MAX_TOKENS limit for PR #{pr_number}")
                # We'll still try to extract partial content below
        
        logger.debug(f"Response has text attribute: {hasattr(response, 'text')}")
        if hasattr(response, 'text'):
            response_text = response.text
            logger.debug(f"Response.text type: {type(response_text)}, value: {response_text}")
        
        # Method 1: Try response.text (direct access)
        if hasattr(response, 'text') and response.text:
            raw_response = response.text
            logger.info(f"Extracted text via response.text: {raw_response[:200]}...")
        # Method 2: Try candidates[0].content.parts[0].text
        elif hasattr(response, 'candidates') and response.candidates:
            candidate = response.candidates[0]
            logger.debug(f"Candidate: {candidate}")
            if hasattr(candidate, 'content') and candidate.content and hasattr(candidate.content, 'parts') and candidate.content.parts:
                part = candidate.content.parts[0]
                logger.debug(f"Part: {part}")
                if hasattr(part, 'text') and part.text:
                    raw_response = part.text
                    logger.info(f"Extracted text via candidates path: {raw_response[:200]}...")
                else:
                    logger.debug(f"Part has no text or empty text. Part attributes: {[attr for attr in dir(part) if not attr.startswith('_')]}")
            else:
                logger.debug(f"Candidate structure issue. Content: {getattr(candidate, 'content', None)}")
        
        if not raw_response:
            logger.warning(f"No text content found in Gemini response for PR #{pr_number}.")
            # Try to access the text property directly
            try:
                text_prop = getattr(response, 'text', None)
                logger.debug(f"Direct text property: {text_prop}")
                if text_prop:
                    raw_response = text_prop
                    logger.info(f"Got text via direct property access: {raw_response[:200]}...")
            except Exception as e:
                logger.debug(f"Failed to access text property: {e}")
            
            if not raw_response:
                # Check if this was a MAX_TOKENS issue and return a fallback
                if hasattr(response, 'candidates') and response.candidates:
                    candidate = response.candidates[0]
                    finish_reason = getattr(candidate, 'finish_reason', None)
                    if finish_reason and str(finish_reason) == 'MAX_TOKENS':
                        logger.warning(f"Returning fallback insight due to MAX_TOKENS limit for PR #{pr_number}")
                        return {
                            "risk_level": "medium",
                            "summary": "Complex changes detected that require careful review due to analysis limitations.",
                            "recommendation": "Review this PR carefully as the AI analysis was truncated. Consider breaking down large changes into smaller PRs."
                        }
                
                logger.debug(f"Response structure: {dir(response)}")
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
            
            # Ensure summary and recommendation are not too long
            if len(cleaned_insight['summary']) > 500:
                cleaned_insight['summary'] = cleaned_insight['summary'][:497] + "..."
            if len(cleaned_insight['recommendation']) > 1000:
                cleaned_insight['recommendation'] = cleaned_insight['recommendation'][:997] + "..."
            
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
        logger.error(f"Unexpected error with Gemini API for PR #{pr_data.get('pr_number', 'unknown')}: {str(e)}")
        return None