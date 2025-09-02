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
        insights = await db_helpers.select('insights', order_by="created_at", desc=True)
        print(f'Found {len(insights)} insights in database')
        for insight in insights[-5:]:  # Show last 5
            repo_short = str(insight["repo_id"])[:8] + "..."
            created = insight["created_at"].strftime("%Y-%m-%d %H:%M") if insight["created_at"] else "Unknown"
            print(f'  - PR #{insight["pr_number"]} in {repo_short}: {insight["risk_level"]} - Created: {created}')
            print(f'    Summary: {insight["summary"][:80]}...')
        
        # Check pull requests
        prs = await db_helpers.select('pull_requests', limit=5, order_by="updated_at", desc=True)
        print(f'\nFound {len(prs)} pull requests in database')
        for pr in prs:
            repo_short = str(pr["repo_id"])[:8] + "..."
            print(f'  - PR #{pr["pr_number"]} in {repo_short}: {pr["state"]} (processed: {pr.get("processed", "N/A")})')
        
        # Test the API query that would be used by the endpoint
        print(f'\n--- Testing API Query ---')
        from app.data.database.core_db import get_db
        db = get_db()
        
        query = """
            SELECT 
                i.*,
                pr.additions,
                pr.deletions,
                pr.changed_files,
                pr.files_changed
            FROM insights i
            LEFT JOIN pull_requests pr ON i.repo_id = pr.repo_id AND i.pr_number = pr.pr_number
            ORDER BY i.created_at DESC
            LIMIT 3
        """
        
        api_results = await db.fetch_all(query)
        print(f'API query returned {len(api_results)} results:')
        for result in api_results:
            print(f'  - PR #{result["pr_number"]}: {result["risk_level"]} - {result["additions"]}+/{result["deletions"]}-')
    
    finally:
        await core_db.disconnect()

if __name__ == "__main__":
    asyncio.run(check_insights())
