# suppsAI API Documentation

## Endpoint: POST /suppsAI/schedule/

**Description:**
Returns an AI-generated supplement schedule for the authenticated user, based on their saved supplements. Requires an active subscription.

**Request:**
- Method: POST
- Auth: Required (user must be logged in)
- Body: (none required)

**Response:**
- 200 OK: `{ "schedule": { "magnesium": "7:00", "zinc": "18:00", ... } }`
- 403 Forbidden: `{ "error": "Subscription required." }`
- 400 Bad Request: `{ "error": "No supplements found." }`

**Logic:**
- Fetches supplements from `food_supplement_items` for the user.
- Sends a prompt to OpenAI (ChatGPT-5) to generate a daily schedule, considering supplement interactions.
- Returns the schedule in JSON format.

**OpenAI Prompt Example:**
> "A user wants to take these supplements daily: magnesium, zinc, vitamin D. Some vitamins and supplements interact and are best taken at certain times. Please create an optimal daily schedule for when to take each supplement. Return the result as a JSON object mapping supplement names to times (e.g. { 'magnesium': '7:00', 'zinc': '18:00' })."

---

## Implementation Notes
- The OpenAI API logic is reused from `ai_analysis/services.py`.
- Only users with valid subscriptions can access this endpoint.
- The schedule can be used to set reminders and display on the home page.
