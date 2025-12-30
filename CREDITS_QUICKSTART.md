# Credits System - Quick Start Guide

## 🚀 Quick Setup (5 Minutes)

### 1. Run Database Migration
```sql
-- In Supabase SQL Editor, run:
/Users/marwansorour/Desktop/Lumo/backend/migrations/add_credits_to_users.sql
```

### 2. Create Stripe Products
Go to [Stripe Dashboard](https://dashboard.stripe.com/products) and create:
- **1 Credit**: $1.99 one-time payment
- **3 Credits**: $3.99 one-time payment  
- **5 Credits**: $5.99 one-time payment

Copy the Price IDs.

### 3. Update Environment Variables
Add to `/backend/.env`:
```bash
STRIPE_CREDIT_1_PRICE_ID=price_xxxxx
STRIPE_CREDIT_3_PRICE_ID=price_xxxxx
STRIPE_CREDIT_5_PRICE_ID=price_xxxxx
```

### 4. Configure Webhook
In Stripe → Webhooks, add endpoint:
```
https://your-api.com/api/credits/webhook/
```
Event: `checkout.session.completed`

### 5. Deploy & Test
```bash
# Deploy backend
cd /Users/marwansorour/Desktop/Lumo/backend
# Deploy to your platform (Render, etc.)

# Build iOS app
cd /Users/marwansorour/Desktop/Lumo/ios/app
# Build and run in Xcode
```

---

## 📋 Quick Test

1. Open iOS app → Settings
2. See credit balance (0)
3. Try to analyze a blood test
4. Credits modal appears
5. Select a bundle
6. Complete Stripe checkout
7. Return to app
8. Credits are added ✅

---

## 🔍 Key Files

**Backend**:
- `/backend/credits/views.py` - All credit logic
- `/backend/credits/urls.py` - API routes

**iOS**:
- `/ios/app/app/Services/CreditService.swift` - API calls
- `/ios/app/app/Views/CreditsModalView.swift` - Purchase UI
- `/ios/app/app/Views/HomeView.swift` - Integration points

**Database**:
- `/backend/migrations/add_credits_to_users.sql` - Schema

---

## 💡 How It Works

```
User clicks "Continue" on analysis
         ↓
Check if user has credits (API call)
         ↓
   Has credits? 
    ↙         ↘
  YES          NO
   ↓            ↓
Deduct      Show Purchase
credit      Modal
   ↓            ↓
Proceed     User buys credits
to             ↓
analysis    Stripe Webhook
            adds credits
               ↓
            Retry analysis
```

---

## 🎯 Environment Variables Needed

```bash
# Existing (should already be set)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# New (add these)
STRIPE_CREDIT_1_PRICE_ID=price_...
STRIPE_CREDIT_3_PRICE_ID=price_...
STRIPE_CREDIT_5_PRICE_ID=price_...
```

---

## ✅ Verification

After setup, verify:
- [ ] `/api/credits/` returns `{"credits": 0}`
- [ ] Analysis triggers credit modal when credits = 0
- [ ] Stripe checkout opens in Safari
- [ ] Webhook logs show successful events
- [ ] Credits appear in Settings after purchase

---

## 🆘 Common Issues

**"Stripe price ID not configured"**
→ Set environment variables and restart backend

**Credits modal doesn't show**
→ Check CreditsModalView is imported in HomeView

**Webhook not working**
→ Verify webhook URL and secret in Stripe Dashboard

**Deep link not returning to app**
→ Check Info.plist has `lumo` URL scheme

---

**Documentation**: See `CREDITS_IMPLEMENTATION.md` for full details
