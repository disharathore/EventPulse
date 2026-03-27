import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import requests
import yfinance as yf
from transformers import pipeline

app = FastAPI()

# Part 1 — FastAPI setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

print("🚀 Initializing AI Model... please wait.")
classifier = pipeline("zero-shot-classification", model="facebook/bart-large-mnli")

# IMPORTANT: Use your real key from newsapi.org
NEWS_API_KEY = "77d006c92aeb410bab7469ee777ceb9c" 

@app.get("/pulse/{ticker}")
def get_event_pulse(ticker: str):
    print(f"🔍 Analyzing: {ticker}")
    try:
        # Fetch News
        news_url = f"https://newsapi.org/v2/everything?q={ticker}&apiKey={NEWS_API_KEY}"
        response = requests.get(news_url).json()
        articles = response.get("articles", [])[:5]
        
        # Fetch Stock Price + History
        stock = yf.Ticker(ticker)
        hist = stock.history(period="5d")
        
        current_price = 0.0
        chart_points = []
        if not hist.empty:
            current_price = float(hist['Close'].iloc[-1])
            chart_points = hist['Close'].tolist()

        results = []
        labels = ["layoff", "merger", "acquisition", "stock split", "neutral"]

        for art in articles:
            content = f"{art['title']} {art['description'] or ''}"
            # NLP Classifier
            classification = classifier(content, candidate_labels=labels)
            results.append({
                "title": art['title'],
                "event_type": classification['labels'][0],
                "confidence": float(classification['scores'][0])
            })

        return {
            "ticker": ticker.upper(),
            "current_price": round(current_price, 2),
            "chart_points": chart_points,
            "events": results
        }
    except Exception as e:
        print(f"❌ Error: {e}")
        return {"error": str(e)}

# THIS BLOCK ENSURES THE SERVER STAYS RUNNING
if __name__ == "__main__":
    print("✅ Server is starting on http://127.0.0.1:8000")
    uvicorn.run(app, host="127.0.0.1", port=8000)