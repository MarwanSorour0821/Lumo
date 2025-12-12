import jwt
import os
from rest_framework import authentication, exceptions
from django.conf import settings


class SupabaseUser:
    """
    Simple user object to hold Supabase user info.
    """
    def __init__(self, user_id, email=None):
        self.id = user_id
        self.user_id = user_id
        self.email = email
        self.is_authenticated = True

    def __str__(self):
        return str(self.user_id)


class SupabaseAuthentication(authentication.BaseAuthentication):
    """
    Custom authentication class to verify Supabase JWT tokens.
    """
    
    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION')
        
        if not auth_header:
            return None
        
        try:
            # Extract the token from "Bearer <token>"
            parts = auth_header.split()
            if len(parts) != 2 or parts[0].lower() != 'bearer':
                return None
            
            token = parts[1]
            
            # Get Supabase JWT secret from environment
            jwt_secret = os.getenv('SUPABASE_JWT_SECRET')
            
            if not jwt_secret:
                raise exceptions.AuthenticationFailed(
                    'Server configuration error: JWT secret not set'
                )
            
            # Decode and verify the token
            try:
                payload = jwt.decode(
                    token,
                    jwt_secret,
                    algorithms=['HS256'],
                    audience='authenticated'
                )
            except jwt.ExpiredSignatureError:
                raise exceptions.AuthenticationFailed('Token has expired')
            except jwt.InvalidTokenError as e:
                raise exceptions.AuthenticationFailed(f'Invalid token: {str(e)}')
            
            # Extract user info from payload
            user_id = payload.get('sub')
            email = payload.get('email')
            
            if not user_id:
                raise exceptions.AuthenticationFailed('Invalid token payload')
            
            # Create a simple user object
            user = SupabaseUser(user_id=user_id, email=email)
            
            return (user, token)
            
        except exceptions.AuthenticationFailed:
            raise
        except Exception as e:
            raise exceptions.AuthenticationFailed(f'Authentication error: {str(e)}')

    def authenticate_header(self, request):
        return 'Bearer'
