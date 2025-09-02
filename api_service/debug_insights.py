#!/usr/bin/env python3
import asyncio
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

async def check_insights():
    from app.data.database import db_helpers, core_db
    
    # Initialize database
    await core_db.connect()
    
    try:
        # Check insights table
        insights = await db_helpers.select('insights')
        print(f'Found {len(insights)} insights in database')
        for insight in insights:
            repo_short = str(insight["repo_id"])[:8] + "..."
            print(f'  - PR #{insight["pr_number"]} in repo {repo_short}: {insight["risk_level"]} - {insight["summary"][:50]}...')
        
        # Check pull requests
        prs = await db_helpers.select('pull_requests', limit=5)
        print(f'\nFound {len(prs)} pull requests in database')
        for pr in prs:
            repo_short = str(pr["repo_id"])[:8] + "..."
            print(f'  - PR #{pr["pr_number"]} in repo {repo_short}: {pr["state"]} (processed: {pr.get("processed", "N/A")})')
    
    finally:
        await core_db.disconnect()

if __name__ == "__main__":
    asyncio.run(check_insights())
