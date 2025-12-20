import os
import json
from urllib.parse import urlparse, parse_qs, urlencode
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from supabase import create_client, Client


def get_supabase_client() -> Client:
    """Get Supabase client instance."""
    url = os.environ.get("SUPABASE_URL") or os.environ.get("SUPABASE_PROJECT_URL")
    key = os.environ.get("SUPABASE_ANON_KEY") or os.environ.get("SUPABASE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    
    if not url or not key:
        raise RuntimeError('Supabase credentials are missing. Set SUPABASE_URL and SUPABASE_ANON_KEY.')
    
    return create_client(url, key)


@api_view(['POST'])
@permission_classes([AllowAny])
@csrf_exempt
def google_oauth_initiate(request):
    """
    Initiate Google OAuth flow.
    POST /api/auth/google/
    Body: {"redirect_url": "com.lumoblood.app://auth/callback"}
    Returns: {"url": "https://..."}
    """
    try:
        data = json.loads(request.body)
        redirect_url = data.get('redirect_url')
        
        if not redirect_url:
            return Response(
                {'error': 'redirect_url is required'},
                status=400
            )
        
        # Get Supabase client
        supabase = get_supabase_client()
        
        # Generate OAuth URL using Supabase
        # The Python client uses a different API - we need to build the URL manually
        # or use the get_url_for_provider method
        try:
            # Build the OAuth URL manually using Supabase's auth endpoint
            supabase_url = os.environ.get("SUPABASE_URL") or os.environ.get("SUPABASE_PROJECT_URL")
            if not supabase_url:
                raise ValueError("SUPABASE_URL not set")
            
            # Construct the OAuth authorization URL
            params = {
                'provider': 'google',
                'redirect_to': redirect_url
            }
            oauth_url = f"{supabase_url}/auth/v1/authorize?{urlencode(params)}"
            
            return Response({
                'url': oauth_url
            })
        except Exception as e:
            return Response(
                {'error': f'Failed to generate OAuth URL: {str(e)}'},
                status=500
            )
        
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=500
        )


@api_view(['POST'])
@permission_classes([AllowAny])
@csrf_exempt
def google_oauth_callback(request):
    """
    Handle Google OAuth callback.
    POST /api/auth/google/callback/
    Body: {"callback_url": "com.lumoblood.app://auth/callback#access_token=..."}
    Returns: {"user": {"id": "...", "email": "...", "first_name": "...", "last_name": "..."}}
    """
    try:
        data = json.loads(request.body)
        callback_url = data.get('callback_url')
        
        if not callback_url:
            return Response(
                {'error': 'callback_url is required'},
                status=400
            )
        
        # Parse the callback URL to extract tokens
        parsed_url = urlparse(callback_url)
        
        # Extract tokens from URL fragment (OAuth typically uses fragments)
        access_token = None
        refresh_token = None
        
        if parsed_url.fragment:
            # Parse fragment: access_token=xxx&refresh_token=yyy
            fragment_params = parse_qs(parsed_url.fragment)
            access_token = fragment_params.get('access_token', [None])[0]
            refresh_token = fragment_params.get('refresh_token', [None])[0]
        
        # If not in fragment, try query parameters
        if not access_token and parsed_url.query:
            query_params = parse_qs(parsed_url.query)
            access_token = query_params.get('access_token', [None])[0]
            refresh_token = query_params.get('refresh_token', [None])[0]
        
        if not access_token:
            return Response(
                {'error': 'No access token found in callback URL'},
                status=400
            )
        
        # Get Supabase client
        supabase = get_supabase_client()
        
        # Set the session using the access token
        try:
            session_response = supabase.auth.set_session(
                access_token=access_token,
                refresh_token=refresh_token or ''
            )
            
            if not session_response or not session_response.user:
                return Response(
                    {'error': 'Failed to set session'},
                    status=500
                )
            
            user = session_response.user
        except Exception as e:
            return Response(
                {'error': f'Failed to set session: {str(e)}'},
                status=500
            )
        
        # Extract user metadata
        metadata = user.user_metadata or {}
        full_name = metadata.get('full_name') or metadata.get('name')
        
        first_name = (
            metadata.get('given_name') or
            (full_name.split(' ')[0] if full_name else None)
        )
        
        last_name = (
            metadata.get('family_name') or
            (' '.join(full_name.split(' ')[1:]) if full_name and len(full_name.split(' ')) > 1 else None)
        )
        
        return Response({
            'user': {
                'id': str(user.id),
                'email': user.email,
                'first_name': first_name,
                'last_name': last_name
            }
        })
        
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=500
        )

