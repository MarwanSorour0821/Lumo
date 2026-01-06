# Food & Supplement Logging Feature

## Overview
This Django app provides API endpoints for logging food and supplement intake, tracking frequency, setting reminders, and analyzing biomarker impacts using AI.

## Database Setup

### 1. Run the SQL Migration
Execute the migration file in your Supabase SQL Editor:
```sql
-- File: backend/migrations/add_food_supplement_logs.sql
```

This creates three tables:
- `food_supplement_items` - Stores items users can log
- `food_supplement_logs` - Individual intake records
- `food_supplement_biomarker_impacts` - AI-generated biomarker impact analysis

### 2. Verify Tables
Check that the tables were created successfully in Supabase:
```sql
SELECT * FROM food_supplement_items LIMIT 1;
SELECT * FROM food_supplement_logs LIMIT 1;
SELECT * FROM food_supplement_biomarker_impacts LIMIT 1;
```

## Django Setup

### 1. Install Dependencies
The app uses `django.contrib.postgres` for PostgreSQL array fields. Make sure it's in `INSTALLED_APPS`:
```python
INSTALLED_APPS = [
    # ...
    'django.contrib.postgres',
    # ...
    'logging_app',
]
```

### 2. Environment Variables
Ensure these environment variables are set:
- `SUPABASE_JWT_SECRET` - For JWT authentication
- `OPENAI_API_KEY` - For AI-powered features (quick log, biomarker analysis)

### 3. Deploy Backend
```bash
cd backend
git add .
git commit -m "Add food/supplement logging feature"
git push
```

## API Endpoints

### Items Management
- `GET /api/logging/items/` - List all items (with optional filters)
- `POST /api/logging/items/` - Create new item
- `GET /api/logging/items/<id>/` - Get item details
- `PUT /api/logging/items/<id>/` - Update item
- `DELETE /api/logging/items/<id>/` - Delete item
- `PUT /api/logging/items/<id>/archive/` - Archive/unarchive item

### Logging
- `POST /api/logging/items/<id>/log/` - Log an intake
- `GET /api/logging/logs/` - Get all logs (with filters)
- `DELETE /api/logging/logs/<id>/` - Delete a log

### AI Features
- `POST /api/logging/quick-log/` - Quick log via voice/text (AI parses input)
- `GET /api/logging/items/<id>/impacts/` - Get biomarker impacts
- `POST /api/logging/items/<id>/impacts/` - Generate biomarker impacts with AI

### Reminders
- `PUT /api/logging/items/<id>/reminder/` - Update reminder settings

## iOS Integration

The iOS app includes:
- Voice input for quick logging
- Local notification reminders
- Biomarker impact modal
- Clean, minimal UI

All iOS files are ready and integrated into the tab bar.

## Testing

### Test Quick Log Endpoint
```bash
curl -X POST https://your-api-url.com/api/logging/quick-log/ \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"input_text": "Vitamin D 1000 IU and fish oil"}'
```

### Test Create Item
```bash
curl -X POST https://your-api-url.com/api/logging/items/ \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Vitamin D3",
    "type": "supplement",
    "frequency": "daily"
  }'
```

## Troubleshooting

### Array Field Error
If you see "column reminder_days is of type integer[] but expression is of type jsonb":
- Make sure `django.contrib.postgres` is in `INSTALLED_APPS`
- The model uses `ArrayField(models.IntegerField())` for PostgreSQL arrays

### Authentication Error
If you see "Unauthorized":
- Check that `SUPABASE_JWT_SECRET` is set correctly
- Verify the JWT token is valid

### AI Features Not Working
If quick log or biomarker impact generation fails:
- Verify `OPENAI_API_KEY` is set
- Check API rate limits
- Review backend logs for detailed errors

## Next Steps

1. Run the SQL migration in Supabase
2. Deploy the updated backend
3. Test the API endpoints
4. Build and test the iOS app
5. Set up reminders and test notifications on device
