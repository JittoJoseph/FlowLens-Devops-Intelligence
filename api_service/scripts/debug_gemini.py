#!/usr/bin/env python3
"""
Debug utility to inspect Gemini API response structure
"""
import asyncio
import json
import sys
import os

# Add the parent directory to the path so we can import from app
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.data.configs.app_settings import settings
from google import genai
from google.genai import types

async def debug_gemini_response():
    """Debug the Gemini API response structure"""
    print("🔍 Debugging Gemini API Response Structure")
    print("=" * 50)
    
    try:
        # Configure client
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        
        # Simple test prompt
        test_prompt = """
You are a code reviewer. Analyze this simple change and return a JSON object ONLY:

File: test.py
Change: Added print statement

Your JSON response must be:
{
  "risk_level": "low",
  "summary": "Added debug print statement",
  "recommendation": "Remove debug print before production"
}
"""
        
        print("📤 Sending test prompt...")
        
        generation_config = types.GenerateContentConfig(
            temperature=0.3,
            max_output_tokens=256,
        )
        
        response = client.models.generate_content(
            model=settings.GEMINI_AI_MODEL,
            contents=[{"role": "user", "parts": [{"text": test_prompt}]}],
            config=generation_config,
        )
        
        print("📥 Response received!")
        print(f"Response type: {type(response)}")
        print(f"Response dir: {[attr for attr in dir(response) if not attr.startswith('_')]}")
        
        # Try different ways to extract content
        print("\n🔍 Attempting different extraction methods:")
        
        # Method 1: candidates[0].content.parts[0].text
        try:
            if hasattr(response, 'candidates') and response.candidates:
                candidate = response.candidates[0]
                print(f"Candidate type: {type(candidate)}")
                print(f"Candidate dir: {[attr for attr in dir(candidate) if not attr.startswith('_')]}")
                
                if hasattr(candidate, 'content'):
                    content = candidate.content
                    print(f"Content type: {type(content)}")
                    print(f"Content dir: {[attr for attr in dir(content) if not attr.startswith('_')]}")
                    
                    if hasattr(content, 'parts') and content.parts:
                        part = content.parts[0]
                        print(f"Part type: {type(part)}")
                        print(f"Part dir: {[attr for attr in dir(part) if not attr.startswith('_')]}")
                        
                        if hasattr(part, 'text'):
                            text = part.text
                            print(f"✅ Method 1 (parts[0].text): {text[:100]}...")
                        else:
                            print("❌ Method 1: No text attribute in part")
                    else:
                        print("❌ Method 1: No parts in content")
                else:
                    print("❌ Method 1: No content in candidate")
            else:
                print("❌ Method 1: No candidates in response")
        except Exception as e:
            print(f"❌ Method 1 failed: {e}")
        
        # Method 2: Direct text access
        try:
            if hasattr(response, 'text'):
                text = response.text
                print(f"✅ Method 2 (response.text): {text[:100]}...")
            else:
                print("❌ Method 2: No text attribute in response")
        except Exception as e:
            print(f"❌ Method 2 failed: {e}")
        
        # Method 3: String representation parsing
        try:
            response_str = str(response)
            print(f"📝 String representation: {response_str[:200]}...")
            
            # Look for JSON patterns
            import re
            json_match = re.search(r'\{[^{}]*"risk_level"[^{}]*\}', response_str)
            if json_match:
                potential_json = json_match.group(0)
                print(f"✅ Method 3 (regex): Found potential JSON: {potential_json}")
            else:
                print("❌ Method 3: No JSON pattern found in string")
        except Exception as e:
            print(f"❌ Method 3 failed: {e}")
        
        # Method 4: Try to access response as dict
        try:
            if hasattr(response, '__dict__'):
                response_dict = response.__dict__
                print(f"📋 Response dict keys: {list(response_dict.keys())}")
                for key, value in response_dict.items():
                    if isinstance(value, str) and len(value) > 10:
                        print(f"✅ Method 4 (dict['{key}']): {value[:100]}...")
                    elif key == 'candidates' and value:
                        print(f"📋 Candidates[0] dict: {value[0].__dict__ if hasattr(value[0], '__dict__') else 'No __dict__'}")
        except Exception as e:
            print(f"❌ Method 4 failed: {e}")
        
    except Exception as e:
        print(f"💥 Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(debug_gemini_response())
