from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth.models import AnonymousUser
import jwt
import os


class SupabaseAuthentication(BaseAuthentication):
    """
    Custom authentication class that validates Supabase JWT tokens.
    """
    
    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        
        if not auth_header.startswith('Bearer '):
            return None
        
        token = auth_header.split(' ')[1]
        
        try:
            # Get Supabase JWT secret from environment
            jwt_secret = os.environ.get('SUPABASE_JWT_SECRET') or os.environ.get('SUPABASE_ANON_KEY')
            
            if not jwt_secret:
                raise AuthenticationFailed('JWT secret not configured')
            
            # Decode and verify the token
            payload = jwt.decode(token, jwt_secret, algorithms=['HS256'], options={"verify_signature": True})
            
            # Extract user information
            user_id = payload.get('sub')
            
            if not user_id:
                raise AuthenticationFailed('Invalid token: missing user ID')
            
            # Create a simple user object
            user = type('User', (), {
                'user_id': user_id,
                'is_authenticated': True,
            })()
            
            return (user, None)
            
        except jwt.ExpiredSignatureError:
            raise AuthenticationFailed('Token has expired')
        except jwt.InvalidTokenError:
            raise AuthenticationFailed('Invalid token')
        except Exception as e:
            raise AuthenticationFailed(f'Authentication failed: {str(e)}')


