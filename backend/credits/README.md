# Credits System Implementation

## Overview
The credits system allows users to purchase credits to analyze blood tests. Users need 1 credit per analysis.

## Architecture

### Backend (Django)
- **Module**: `credits/`
- **Endpoints**:
  - `GET /api/credits/` - Get user's current credit balance
  - `POST /api/credits/deduct/` - Deduct one credit (returns 402 if insufficient)
  - `POST /api/credits/checkout/` - Create Stripe checkout session for credit purchase
  - `POST /api/credits/webhook/` - Handle Stripe webhook for payment completion

### iOS (Swift)
- **CreditService.swift** - API service for credit operations
- **CreditsModalView.swift** - Modal UI for purchasing credits with bundle options
- **HomeView.swift updates**:
  - `AnalyseModalView` - Checks credits before analysis
  - `SettingsTabView` - Displays credit balance with buy button
  - `CreditBalanceCard` - UI component for showing credits

### Database (Supabase)
- **Migration**: `migrations/add_credits_to_users.sql`
- Adds `credits` column to `users` table
- Creates `add_credits()` and `deduct_credit()` functions
- Creates `credit_purchases` table for purchase history

## Setup Instructions

### 1. Run Database Migration
Execute the SQL in `migrations/add_credits_to_users.sql` in Supabase SQL Editor.

### 2. Configure Stripe Products
Create three products in Stripe Dashboard with one-time payment prices:
- 1 Credit: $1.99
- 3 Credits: $3.99
- 5 Credits: $5.99

### 3. Set Environment Variables
Add to your backend `.env`:
```
STRIPE_CREDIT_1_PRICE_ID=price_xxx
STRIPE_CREDIT_3_PRICE_ID=price_xxx
STRIPE_CREDIT_5_PRICE_ID=price_xxx
```

### 4. Configure Stripe Webhook
Add the `/api/credits/webhook/` endpoint to your Stripe webhook configuration.
Enable the `checkout.session.completed` event.

## User Flow

1. User uploads blood test file in `AnalyseModalView`
2. When clicking "Continue", system calls `deductCredit()`
3. If user has credits → deduct one and proceed with analysis
4. If insufficient credits → show `CreditsModalView` with bundle options
5. User selects bundle and clicks purchase
6. Opens Stripe checkout in Safari
7. After payment, Stripe webhook adds credits to user account
8. User is redirected back to app via `lumo://credits-success` deep link
9. Modal closes and analysis proceeds (or user can retry)

## Credit Bundle Options
| Bundle | Price | Per Credit |
|--------|-------|------------|
| 1 Credit | $1.99 | $1.99 |
| 3 Credits | $3.99 | $1.33 (Save 33%) |
| 5 Credits | $5.99 | $1.20 (Best Value) |

## Files Changed/Created

### Created
- `/backend/credits/__init__.py`
- `/backend/credits/apps.py`
- `/backend/credits/views.py`
- `/backend/credits/urls.py`
- `/ios/app/app/Services/CreditService.swift`
- `/ios/app/app/Views/CreditsModalView.swift`
- `/backend/.env.example`
- `/backend/migrations/add_credits_to_users.sql`

### Modified
- `/backend/backend/settings.py` - Added 'credits' to INSTALLED_APPS
- `/backend/backend/urls.py` - Added credits URL routing
- `/ios/app/app/Views/HomeView.swift` - Updated AnalyseModalView and SettingsTabView
- `/ios/app/app/Info.plist` - Added 'lumo' URL scheme for deep links
