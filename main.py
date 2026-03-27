import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import requests
import yfinance as yf
from transformers import pipeline

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 1. ADD THIS: A simple route so Render knows the server is "Alive"
@app.get("/")
def health_check():
    return {"status": "online"}

print("🚀 Loading Lightweight AI Model...")
# 2. OPTIMIZE: Use 'distilbart' - it uses 70% less memory than the large version
classifier = pipeline("zero-shot-classification", model="valhalla/distilbart-mnli-12-3")

NEWS_API_KEY = "77d006c92aeb410bab7469ee777ceb9c" 

@app.get("/pulse/{ticker}")
def get_event_pulse(ticker: str):
    try:
        news_url = f"https://newsapi.org/v2/everything?q={ticker}&apiKey={NEWS_API_KEY}"
        response = requests.get(news_url).json()
        articles = response.get("articles", [])[:5]
        
        stock = yf.Ticker(ticker)
        hist = stock.history(period="7d")
        current_price = float(hist['Close'].iloc[-1]) if not hist.empty else 0.0
        chart_points = hist['Close'].tolist() if not hist.empty else []

        results = []
        labels = ["layoff", "merger", "acquisition", "stock split", "neutral"]

        for art in articles:
            content = f"{art['title']} {art['description'] or ''}"
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
        return {"error": str(e)}