import os
import json
from datetime import datetime
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.conf import settings
from django.utils import timezone

from .models import FoodSupplementItem, FoodSupplementLog, FoodSupplementBiomarkerImpact, DoseTakenStatus
from .serializers import (
    FoodSupplementItemSerializer,
    FoodSupplementItemCreateSerializer,
    FoodSupplementLogSerializer,
    FoodSupplementBiomarkerImpactSerializer,
    QuickLogSerializer,
    BiomarkerImpactRequestSerializer
)
from analyses.authentication import get_user_id_from_token

# Import OpenAI for AI-powered features
try:
    from openai import OpenAI
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False


def get_openai_client():
    """Get OpenAI client instance"""
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        return None
    return OpenAI(api_key=api_key)


@api_view(['GET', 'POST'])
def items_list(request):
    """
    GET: List all food/supplement items for the authenticated user
    POST: Create a new food/supplement item
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)
    
    if request.method == 'GET':
        # Get query params for filtering
        item_type = request.query_params.get('type')
        include_archived = request.query_params.get('include_archived', 'false').lower() == 'true'
        
        items = FoodSupplementItem.objects.filter(user_id=user_id)
        
        if not include_archived:
            items = items.filter(is_archived=False)
        
        if item_type:
            items = items.filter(type=item_type)
        
        serializer = FoodSupplementItemSerializer(items, many=True)
        return Response(serializer.data)
    
    elif request.method == 'POST':
        try:
            serializer = FoodSupplementItemCreateSerializer(data=request.data)
            if serializer.is_valid():
                item = FoodSupplementItem.objects.create(
                    user_id=user_id,
                    **serializer.validated_data
                )
                return Response(
                    FoodSupplementItemSerializer(item).data,
                    status=status.HTTP_201_CREATED
                )
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            import traceback
            error_trace = traceback.format_exc()
            print(f"❌ Error creating item: {str(e)}")
            print(f"Traceback: {error_trace}")
            print(f"Request data: {request.data}")
            return Response(
                {'error': str(e), 'detail': error_trace},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@api_view(['GET', 'PUT', 'DELETE'])
def item_detail(request, item_id):
    """
    GET: Get a specific item
    PUT: Update an item
    DELETE: Delete an item
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        item = FoodSupplementItem.objects.get(id=item_id, user_id=user_id)
    except FoodSupplementItem.DoesNotExist:
        return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)
    
    if request.method == 'GET':
        serializer = FoodSupplementItemSerializer(item)
        return Response(serializer.data)
    
    elif request.method == 'PUT':
        serializer = FoodSupplementItemCreateSerializer(item, data=request.data, partial=True)
        if serializer.is_valid():
            for key, value in serializer.validated_data.items():
                setattr(item, key, value)
            item.save()
            return Response(FoodSupplementItemSerializer(item).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    elif request.method == 'DELETE':
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(['POST'])
def log_item(request, item_id):
    """
    Log an intake for a specific item
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        item = FoodSupplementItem.objects.get(id=item_id, user_id=user_id)
    except FoodSupplementItem.DoesNotExist:
        return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)
    
    log = FoodSupplementLog.objects.create(
        user_id=user_id,
        item=item,
        notes=request.data.get('notes'),
        quantity=request.data.get('quantity')
    )
    
    serializer = FoodSupplementLogSerializer(log)
    return Response(serializer.data, status=status.HTTP_201_CREATED)


@api_view(['GET'])
def logs_list(request):
    """
    Get all logs for the authenticated user
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)
    
    # Get query params
    item_id = request.query_params.get('item_id')
    start_date = request.query_params.get('start_date')
    end_date = request.query_params.get('end_date')
    limit = int(request.query_params.get('limit', 50))
    
    logs = FoodSupplementLog.objects.filter(user_id=user_id)
    
    if item_id:
        logs = logs.filter(item_id=item_id)
    
    if start_date:
        logs = logs.filter(logged_at__gte=start_date)
    
    if end_date:
        logs = logs.filter(logged_at__lte=end_date)
    
    logs = logs.select_related('item')[:limit]
    
    serializer = FoodSupplementLogSerializer(logs, many=True)
    return Response(serializer.data)


@api_view(['DELETE'])
def delete_log(request, log_id):
    """
    Delete a specific log entry
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        log = FoodSupplementLog.objects.get(id=log_id, user_id=user_id)
    except FoodSupplementLog.DoesNotExist:
        return Response({'error': 'Log not found'}, status=status.HTTP_404_NOT_FOUND)
    
    log.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(['POST'])
def quick_log(request):
    """
    Quick log via voice transcription or text input.
    Uses AI to parse the input and create/log items.
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)
    
    serializer = QuickLogSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    input_text = serializer.validated_data['input_text']
    
    # Use AI to parse the input
    client = get_openai_client()
    if not client:
        return Response(
            {'error': 'AI service not available'},
            status=status.HTTP_503_SERVICE_UNAVAILABLE
        )
    
    try:
        # Parse the input with AI
        parse_response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": """You are a health logging assistant. Parse the user's input about food or supplements they consumed.
                    
Return a JSON object with:
{
    "items": [
        {
            "name": "item name (standardized, e.g., 'Vitamin D3' not 'vit d')",
            "type": "food" or "supplement",
            "quantity": "amount taken (e.g., '500mg', '1 pill', '1 serving')"
        }
    ]
}

Be smart about:
- Standardizing names (e.g., "fish oil" -> "Omega-3 Fish Oil")
- Determining type (vitamins, minerals, protein powders = supplement; meals, snacks = food)
- Extracting quantities when mentioned

Only return the JSON, nothing else."""
                },
                {
                    "role": "user",
                    "content": input_text
                }
            ],
            temperature=0.3
        )
        
        parsed = json.loads(parse_response.choices[0].message.content)
        items_data = parsed.get('items', [])
        
        created_items = []
        created_logs = []
        
        for item_data in items_data:
            # Check if item already exists for this user
            existing_item = FoodSupplementItem.objects.filter(
                user_id=user_id,
                name__iexact=item_data['name']
            ).first()
            
            if existing_item:
                item = existing_item
            else:
                # Create new item
                item = FoodSupplementItem.objects.create(
                    user_id=user_id,
                    name=item_data['name'],
                    type=item_data.get('type', 'supplement')
                )
                created_items.append(FoodSupplementItemSerializer(item).data)
            
            # Create log entry
            log = FoodSupplementLog.objects.create(
                user_id=user_id,
                item=item,
                quantity=item_data.get('quantity')
            )
            created_logs.append(FoodSupplementLogSerializer(log).data)
        
        return Response({
            'success': True,
            'parsed_input': input_text,
            'items_created': created_items,
            'logs_created': created_logs
        }, status=status.HTTP_201_CREATED)
        
    except json.JSONDecodeError:
        return Response(
            {'error': 'Failed to parse AI response'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET', 'POST'])
def biomarker_impacts(request, item_id):
    """
    GET: Get biomarker impacts for an item
    POST: Generate biomarker impacts using AI
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        item = FoodSupplementItem.objects.get(id=item_id, user_id=user_id)
    except FoodSupplementItem.DoesNotExist:
        return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)
    
    if request.method == 'GET':
        impacts = item.biomarker_impacts.all()
        serializer = FoodSupplementBiomarkerImpactSerializer(impacts, many=True)
        return Response(serializer.data)
    
    elif request.method == 'POST':
        # Generate biomarker impacts using AI
        client = get_openai_client()
        if not client:
            return Response(
                {'error': 'AI service not available'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )
        
        try:
            response = client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "system",
                        "content": """You are a health and nutrition expert. Analyze the impact of a food or supplement on blood biomarkers.

Return a JSON array of biomarker impacts:
[
    {
        "biomarker_name": "Name of the biomarker (e.g., 'Vitamin D', 'LDL Cholesterol', 'HbA1c')",
        "impact_type": "positive", "negative", or "neutral",
        "impact_description": "Brief explanation of the impact (1-2 sentences)",
        "impact_score": number from -100 to 100 (negative = harmful, positive = beneficial),
        "scientific_source": "Brief reference to scientific evidence"
    }
]

Focus on the most significant biomarker impacts (3-8 biomarkers). Be accurate and evidence-based.
Only return the JSON array, nothing else."""
                    },
                    {
                        "role": "user",
                        "content": f"Analyze the biomarker impacts of: {item.name} (Type: {item.type})"
                    }
                ],
                temperature=0.3
            )
            
            impacts_data = json.loads(response.choices[0].message.content)
            
            # Clear existing impacts and create new ones
            item.biomarker_impacts.all().delete()
            
            created_impacts = []
            for impact_data in impacts_data:
                impact = FoodSupplementBiomarkerImpact.objects.create(
                    item=item,
                    biomarker_name=impact_data['biomarker_name'],
                    impact_type=impact_data['impact_type'],
                    impact_description=impact_data.get('impact_description'),
                    impact_score=impact_data.get('impact_score', 0),
                    scientific_source=impact_data.get('scientific_source')
                )
                created_impacts.append(
                    FoodSupplementBiomarkerImpactSerializer(impact).data
                )
            
            return Response({
                'item_name': item.name,
                'impacts': created_impacts
            }, status=status.HTTP_201_CREATED)
            
        except json.JSONDecodeError:
            return Response(
                {'error': 'Failed to parse AI response'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@api_view(['PUT'])
def update_reminder(request, item_id):
    """
    Update reminder settings for an item.
    Accepts reminder_times as an array of time strings (e.g., ["09:00:00", "14:00:00", "21:00:00"])
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)

    try:
        item = FoodSupplementItem.objects.get(id=item_id, user_id=user_id)
    except FoodSupplementItem.DoesNotExist:
        return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)

    item.reminder_enabled = request.data.get('reminder_enabled', item.reminder_enabled)
    item.reminder_times = request.data.get('reminder_times', item.reminder_times)
    item.reminder_days = request.data.get('reminder_days', item.reminder_days)
    item.save()

    return Response(FoodSupplementItemSerializer(item).data)


@api_view(['PUT'])
def archive_item(request, item_id):
    """
    Archive or unarchive an item
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)

    try:
        item = FoodSupplementItem.objects.get(id=item_id, user_id=user_id)
    except FoodSupplementItem.DoesNotExist:
        return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)

    item.is_archived = request.data.get('is_archived', not item.is_archived)
    item.save()

    return Response(FoodSupplementItemSerializer(item).data)


@api_view(['PUT'])
def toggle_taken(request, item_id):
    """
    Toggle the taken status of an item.
    If currently taken today, marks as not taken (clears last_taken_at and deletes today's log).
    If not taken today, marks as taken (sets last_taken_at to now and creates a log entry).
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)

    try:
        item = FoodSupplementItem.objects.get(id=item_id, user_id=user_id)
    except FoodSupplementItem.DoesNotExist:
        return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)

    # Check if taken today
    today = timezone.now().date()
    is_taken_today = item.last_taken_at and item.last_taken_at.date() == today

    if is_taken_today:
        # Mark as not taken (clear the timestamp)
        item.last_taken_at = None
        message = f"{item.name} unmarked"

        # Delete today's log entry for this item
        FoodSupplementLog.objects.filter(
            user_id=user_id,
            item=item,
            logged_at__date=today
        ).delete()
    else:
        # Mark as taken
        now = timezone.now()
        item.last_taken_at = now
        message = f"{item.name} marked as taken"

        # Create a log entry
        FoodSupplementLog.objects.create(
            user_id=user_id,
            item=item,
            logged_at=now
        )

    item.save()

    return Response({
        'item': FoodSupplementItemSerializer(item).data,
        'message': message,
        'is_taken_today': not is_taken_today
    })


@api_view(['PUT'])
def toggle_dose(request, item_id, time_index):
    """
    Toggle the taken status of a specific dose for a multi-dose item.
    This is used for items with multiple reminder times per day.

    Parameters:
    - item_id: UUID of the item
    - time_index: Index of the dose time (0, 1, 2, etc.) corresponding to reminder_times array
    """
    user_id = get_user_id_from_token(request)
    if not user_id:
        return Response({'error': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)

    try:
        item = FoodSupplementItem.objects.get(id=item_id, user_id=user_id)
    except FoodSupplementItem.DoesNotExist:
        return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)

    # Validate time_index
    if not item.reminder_times or time_index >= len(item.reminder_times):
        return Response(
            {'error': f'Invalid time_index. Item has {len(item.reminder_times) if item.reminder_times else 0} reminder times.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    today = timezone.now().date()
    now = timezone.now()

    # Get or create the dose status for today
    dose_status, created = DoseTakenStatus.objects.get_or_create(
        item=item,
        user_id=user_id,
        date=today,
        time_index=time_index,
        defaults={'is_taken': False}
    )

    # Toggle the status
    dose_status.is_taken = not dose_status.is_taken
    if dose_status.is_taken:
        dose_status.taken_at = now
        message = f"{item.name} dose {time_index + 1} marked as taken"

        # Create a log entry for this dose
        FoodSupplementLog.objects.create(
            user_id=user_id,
            item=item,
            logged_at=now,
            notes=f"Dose {time_index + 1} ({item.reminder_times[time_index]})"
        )
    else:
        dose_status.taken_at = None
        message = f"{item.name} dose {time_index + 1} unmarked"

        # Delete today's log entry for this specific dose
        FoodSupplementLog.objects.filter(
            user_id=user_id,
            item=item,
            logged_at__date=today,
            notes__contains=f"Dose {time_index + 1}"
        ).delete()

    dose_status.save()

    # Check if all doses are now taken
    all_taken = DoseTakenStatus.objects.filter(
        item=item,
        date=today,
        is_taken=True
    ).count() >= len(item.reminder_times)

    # Update the item's last_taken_at if all doses are taken
    if all_taken:
        item.last_taken_at = now
        item.save()
    elif not dose_status.is_taken and item.last_taken_at and item.last_taken_at.date() == today:
        # If un-marking a dose and item was marked as all taken, clear last_taken_at
        item.last_taken_at = None
        item.save()

    return Response({
        'item': FoodSupplementItemSerializer(item).data,
        'dose_status': {
            'id': str(dose_status.id),
            'time_index': dose_status.time_index,
            'time': item.reminder_times[time_index],
            'is_taken': dose_status.is_taken,
            'taken_at': dose_status.taken_at.isoformat() if dose_status.taken_at else None
        },
        'message': message,
        'all_doses_taken_today': all_taken
    })
