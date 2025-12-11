# AI Analysis Setup

## Backend Setup

### 1. Install Dependencies
```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Configure OpenAI API Key
Edit `backend/.env` and add your OpenAI API key:
```
OPENAI_API_KEY=your-actual-openai-api-key
```

### 3. Run the Django Server
```bash
python manage.py runserver
```

The API will be available at `http://localhost:8000`

## Frontend Setup

### 1. Configure API URL
Create `frontend/.env` (copy from `.env.example`):
```
EXPO_PUBLIC_API_URL=http://localhost:8000
```

For iOS simulator, use: `http://localhost:8000`
For Android emulator, use: `http://10.0.2.2:8000`

### 2. Start Expo
```bash
cd frontend
npm start
```

## API Endpoints

### Analyze Blood Test
**POST** `/api/ai/analyze/`

Upload a blood test image for AI analysis.

**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Body: `file` (image file)

**Response:**
```json
{
  "parsed_data": {
    "patient_info": {
      "name": "string or null",
      "age": "string or null",
      "test_date": "string or null"
    },
    "test_results": [
      {
        "marker": "marker name",
        "value": "numeric value",
        "unit": "unit of measurement",
        "reference_range": "normal range",
        "status": "normal|high|low|null"
      }
    ]
  },
  "analysis": "Comprehensive AI-generated analysis text",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### Health Check
**GET** `/api/ai/health/`

Check if the AI service is running.

## How It Works

1. **Image Upload**: User uploads a photo or PDF of their blood test
2. **GPT-4o Parsing**: The image is sent to GPT-4o which extracts all blood test data into structured JSON
3. **GPT-5.1 Analysis**: The structured data is sent to GPT-5.1 for comprehensive medical analysis
4. **Results Display**: User receives detailed analysis with explanations and recommendations

## Models Used

- **GPT-4o**: For vision-based parsing of blood test images
- **GPT-5.1**: For medical analysis with medium reasoning effort and verbosity

## Important Notes

- Ensure your OpenAI API key has access to both GPT-4o and GPT-5.1 models
- The analysis is AI-generated and should not replace professional medical advice
- Images should be clear and legible for best results
