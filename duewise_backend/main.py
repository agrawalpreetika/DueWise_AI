import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Literal
from dotenv import load_dotenv
from groq import Groq
import json
from datetime import datetime
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()

app = FastAPI(title="DueWise AI Agent Backend")

# --- CORS MIDDLEWARE ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = Groq(api_key=os.getenv("GROQ_API_KEY"))

class ChatRequest(BaseModel):
    message: str

# 1. Strict Pydantic model for adding subscriptions
class SubscriptionToolSchema(BaseModel):
    title: str = Field(..., description="Name of the subscription (e.g., Netflix, Gym)")
    amount: float = Field(..., description="Cost amount of the subscription")
    billingCycle: Literal["MONTHLY", "YEARLY", "CUSTOM"] = Field(
        ..., description="Must be CUSTOM if user specifies custom days or months (e.g., every 45 days, every 2 months)."
    )
    customIntervalDays: Optional[int] = Field(
        None, description="Required if billingCycle is CUSTOM. Total calculated days (e.g., convert 2 months to 60 days, 45 days = 45)."
    )
    startDate: str = Field(..., description="Start date in YYYY-MM-DD format")
    category: Literal[
        "Entertainment", "Utility", "Software", "Gym", "Insurance", "Education", "Other"
    ] = Field(..., description="Must strictly match one of the allowed categories.")

# 2. Pydantic model for querying existing subscriptions
class QuerySubscriptionsSchema(BaseModel):
    query_type: Literal[
        "due_today",
        "due_on_date",
        "upcoming_days",
        "monthly_expenses",
        "this_month_expenses",
        "next_month_expenses",
        "by_category",
        "by_name",
        "all_active"
    ] = Field(
        ...,
        description="Type of subscription query: 'due_today' for today's due bills, 'due_on_date' for a specific date, 'upcoming_days' for next N days, 'monthly_expenses' for estimated average monthly spend, 'this_month_expenses' for bills due in the current calendar month, 'next_month_expenses' for bills due in the next calendar month, 'by_category' for a specific category, 'by_name' for a specific subscription or bill title, 'all_active' for listing active subscriptions."
    )
    target_date: Optional[str] = Field(
        None,
        description="Target date in YYYY-MM-DD format when query_type is 'due_on_date'."
    )
    days_ahead: Optional[int] = Field(
        None,
        description="Number of days ahead (e.g., 7 for a week) when query_type is 'upcoming_days'."
    )
    category: Optional[Literal[
        "Entertainment", "Utility", "Utilities", "Software", "Gym", "Insurance", "Education", "Other"
    ]] = Field(
        None,
        description="Category filter when query_type is 'by_category'."
    )
    subscription_name: Optional[str] = Field(
        None,
        description="Specific subscription or bill name when query_type is 'by_name' (e.g., 'Spotify', 'Internet', 'Netflix')."
    )

# 3. Groq Tools / Function Definitions
tools = [
    {
        "type": "function",
        "function": {
            "name": "add_subscription",
            "description": "Extract subscription details from user message when the user wants to add a new subscription.",
            "parameters": SubscriptionToolSchema.model_json_schema()
        }
    },
    {
        "type": "function",
        "function": {
            "name": "query_subscriptions",
            "description": "Query existing subscriptions when the user asks about due dates, today's bills, upcoming subscriptions, monthly expenses, category spending, or a specific subscription/bill by name.",
            "parameters": QuerySubscriptionsSchema.model_json_schema()
        }
    }
]

@app.post("/api/chat")
async def chat_with_agent(req: ChatRequest):
    try:
        today_str = datetime.now().strftime("%Y-%m-%d")
        
        system_instructions = f"""
You are DueWise AI, a precise financial subscription assistant. Today's date is {today_str}.
Your task is to either extract new subscription details (`add_subscription`) OR identify query parameters (`query_subscriptions`) when the user asks about existing subscriptions.

CRITICAL RULES FOR ADDING SUBSCRIPTIONS (`add_subscription`):
1. **Billing Cycle & Custom Intervals**:
  - If the user specifies any custom timeframe (e.g., "every 45 days", "every 2 months", "every 10 days"), you MUST set `billingCycle` to `CUSTOM`.
  - You MUST calculate and provide the numeric total in `customIntervalDays` (Convert months to days: 1 month = 30 days, 2 months = 60 days, etc. For days like 45 days, use 45). Never leave `customIntervalDays` null or empty if billingCycle is CUSTOM.
2. **Categories**:
  - The `category` field MUST be chosen strictly from this exact allowed list: Entertainment, Utility, Software, Gym, Insurance, Education, Other. Do not invent or use any other category.
3. **Dates**:
  - Extract the start date in YYYY-MM-DD format. If no date is given, default to today's date ({today_str}).

CRITICAL RULES FOR QUERYING SUBSCRIPTIONS (`query_subscriptions`):
1. Use `due_today` when the user asks what is due today ("aaj kya due hai?", "due today").
2. Use `due_on_date` when the user asks about a specific date, and convert relative/partial dates using today's date ({today_str}) into exact `YYYY-MM-DD` in `target_date`.
3. Use `upcoming_days` when the user asks about upcoming bills in the next few days or week (e.g., next 7 days -> `days_ahead: 7`).
4. Use `this_month_expenses` when the user asks about bills or expenses due in the current calendar month (e.g., "What are the expenses this month?", "Bills due this month").
5. Use `next_month_expenses` when the user asks about bills or expenses due in the next calendar month (e.g., "What are the expenses in next month?", "Next month bills").
6. Use `monthly_expenses` when the user asks about their general/average monthly spend or run-rate ("what are my monthly expenses?", "average monthly spend").
7. Use `by_category` when the user asks about a specific category ("gym subscriptions", "entertainment spending").
8. Use `by_name` when the user asks about a specific subscription or bill by name (e.g., "How much is my Spotify?", "What is my internet bill?"), and set `subscription_name` to that name/keyword.
9. Use `all_active` when the user asks to list their active subscriptions.
"""

        completion = client.chat.completions.create(
            model="openai/gpt-oss-20b",
            messages=[
                {
                    "role": "system",
                    "content": system_instructions
                },
                {
                    "role": "user",
                    "content": req.message
                }
            ],
            tools=tools,
            tool_choice="auto",
            temperature=0.0
        )
        
        response_message = completion.choices[0].message

        if response_message.tool_calls:
            tool_call = response_message.tool_calls[0]
            function_name = tool_call.function.name
            arguments = json.loads(tool_call.function.arguments)
            
            return {
                "status": "success",
                "type": "tool_call",
                "function": function_name,
                "data": arguments,
                "response": (
                    f"Successfully parsed subscription: {arguments.get('title')}"
                    if function_name == "add_subscription"
                    else f"Running query: {arguments.get('query_type')}"
                )
            }
        else:
            return {
                "status": "success",
                "type": "text",
                "response": response_message.content or "I'm here to help you manage your subscriptions!"
            }
        
    except Exception as e:
        raise HTTPException(status_status=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)