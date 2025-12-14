import os
from supabase import create_client, Client


# Lazy singleton for Supabase client
_supabase_client: Client | None = None


def get_supabase_client() -> Client:
    global _supabase_client
    if _supabase_client is None:
        url: str = os.environ.get("SUPABASE_URL") or os.environ.get("SUPABASE_PROJECT_URL")
        key: str = os.environ.get("SUPABASE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
        
        if not url or not key:
            raise RuntimeError('Supabase credentials are missing. Set SUPABASE_URL and SUPABASE_KEY (or SUPABASE_SERVICE_ROLE_KEY).')
        
        _supabase_client = create_client(url, key)
    return _supabase_client



