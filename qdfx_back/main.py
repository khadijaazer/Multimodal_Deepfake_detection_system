# -*- coding: utf-8 -*-
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi import Request
from pydantic import BaseModel
import uvicorn
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch
import os
import re
from typing import List, Dict, Optional
from langdetect import detect, detect_langs

app = FastAPI()

# Enhanced CORS for better connectivity
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*", "http://localhost", "http://localhost:8000", "http://127.0.0.1:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

@app.middleware("http")
async def add_cors_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept"
    response.headers["Access-Control-Max-Age"] = "3600"
    return response

class TextRequest(BaseModel):
    text: str

class EnhancedAnalysisResponse(BaseModel):
    # Basic info
    isScam: bool
    confidence: float
    language: str
    language_confidence: float
    
    # Threat assessment
    threat_level: str
    risk_score: float
    scam_category: List[str]
    
    # Pattern detection
    suspicious_patterns: List[Dict[str, List[str]]]
    urgency_indicators: List[str]
    financial_indicators: List[str]
    urls_found: List[str]
    phone_numbers: List[str]
    emails_found: List[str]
    
    # Recommendations
    safety_tips: List[str]
    actions_to_take: List[str]
    
    # Indicators (for backward compatibility)
    indicators: List[str]

# Global variables
model = None
tokenizer = None
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# YOUR HUGGING FACE MODEL NAME
HF_MODEL_NAME = "alaegmr98/multilingual-scam-detector"

# Scam pattern databases by language
SCAM_KEYWORDS = {
    'urgency': [
        'urgent', 'immediately', 'asap', 'warning', 'alert', 'attention', 'critical',
        '立刻', '紧急', 'عاجل', 'urgente', 'dringend', 'urgente', 'urgent',
        'act now', 'expires', 'deadline', 'limited time'
    ],
    'financial': [
        'bank', 'account', 'credit card', 'paypal', 'wire transfer', 'western union',
        '银行卡', '账户', '信用卡', 'بنك', 'حساب', 'banco', 'cuenta', 'konto',
        'investment', 'profit', 'million', 'bitcoin', 'crypto'
    ],
    'prize': [
        'won', 'winner', 'lottery', 'prize', 'million', 'inheritance', 'gift',
        '中奖', '彩票', 'جائزة', 'ganador', 'lotería', 'gewonnen', 'lotterie',
        'congratulations', 'selected', 'award'
    ],
    'threat': [
        'suspend', 'block', 'close', 'terminate', 'legal action', 'lawsuit',
        '暂停', '关闭', '法律行动', 'معلقة', 'bloqueado', 'gesperrt',
        'arrest', 'police', 'court', 'fine', 'penalty'
    ],
    'personal': [
        'ssn', 'social security', 'password', 'pin', 'credit card number', 'cvv',
        '密码', '社会安全号码', 'رقم سري', 'contraseña', 'passwort',
        'identity', 'date of birth', 'mother\'s maiden name'
    ]
}

# Safety recommendations by scam type
SAFETY_TIPS = {
    'phishing': [
        "Never click on suspicious links - they may steal your information",
        "Check the sender's email address carefully for misspellings",
        "Hover over links to see the real URL before clicking",
        "Contact the company directly using official channels (not the message)"
    ],
    'lottery': [
        "Legitimate lotteries never ask for money to release prizes",
        "You cannot win a lottery you didn't enter",
        "Never share bank details for 'prize claims'",
        "Delete these messages immediately"
    ],
    'bank_fraud': [
        "Banks never ask for full passwords or PINs via email/text",
        "Call your bank using the number on your card (not the message)",
        "Enable two-factor authentication on all accounts",
        "Check your account directly by logging into the official website"
    ],
    'investment': [
        "If it sounds too good to be true, it probably is",
        "Research investment opportunities thoroughly",
        "Never invest based on an unsolicited message",
        "Consult with a financial advisor"
    ],
    'general': [
        "Don't respond to unsolicited messages",
        "Never send money to strangers",
        "Keep your personal information private",
        "Report suspicious messages to authorities",
        "Block the sender immediately"
    ]
}

@app.on_event("startup")
async def load_model():
    global model, tokenizer
    try:
        print("=" * 60)
        print(f"Loading model from Hugging Face: {HF_MODEL_NAME}")
        print("=" * 60)
        print("This may take a few minutes on first run (downloading model)...")
        print("Model files will be cached locally for faster future loads")
        
        # Load tokenizer and model directly from Hugging Face
        tokenizer = AutoTokenizer.from_pretrained(HF_MODEL_NAME)
        model = AutoModelForSequenceClassification.from_pretrained(HF_MODEL_NAME)
        model.to(device)
        model.eval()
        
        print("Model loaded successfully from Hugging Face!")
        print(f"Using device: {device}")
        print(f"Model type: {model.config.model_type}")
        print("Model cached locally for future runs")
        print("=" * 60)
        
    except Exception as e:
        print(f"Error loading model: {e}")
        print("Please check:")
        print(f"  - Is the model name correct? {HF_MODEL_NAME}")
        print("  - Is your model public?")
        print("  - Are you logged in with huggingface-cli login?")
        import traceback
        traceback.print_exc()

def extract_entities(text: str) -> Dict:
    """Extract URLs, phone numbers, emails from text"""
    entities = {
        'urls': [],
        'phones': [],
        'emails': []
    }
    
    # URLs
    url_pattern = r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.(com|org|net|io|gov|edu|co|uk|de|fr|es|it|ru|cn|jp)(?:/[^\s]*)?'
    urls = re.findall(url_pattern, text, re.IGNORECASE)
    entities['urls'] = [url for url in urls if url]
    
    # Phone numbers (international format)
    phone_pattern = r'[\+\(]?[1-9][0-9 .\-\(\)]{8,}[0-9]'
    phones = re.findall(phone_pattern, text)
    entities['phones'] = [phone for phone in phones if len(phone) >= 8]
    
    # Emails
    email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    emails = re.findall(email_pattern, text)
    entities['emails'] = [email for email in emails if email]
    
    return entities

def detect_scam_patterns(text: str) -> Dict:
    """Detect various scam patterns in text"""
    text_lower = text.lower()
    patterns = {
        'urgency': [],
        'financial': [],
        'prize': [],
        'threat': [],
        'personal': []
    }
    
    for category, keywords in SCAM_KEYWORDS.items():
        for keyword in keywords:
            if keyword.lower() in text_lower:
                patterns[category].append(keyword)
    
    return patterns

def get_threat_level(confidence: float, patterns: Dict, has_urls: bool, has_phones: bool) -> str:
    """Determine threat level based on multiple factors"""
    score = confidence
    
    if has_urls:
        score += 15
    if has_phones:
        score += 5
    if len(patterns['urgency']) > 0:
        score += 5 * len(patterns['urgency'])
    if len(patterns['financial']) > 0:
        score += 8 * len(patterns['financial'])
    if len(patterns['prize']) > 0:
        score += 10 * len(patterns['prize'])
    if len(patterns['threat']) > 0:
        score += 8 * len(patterns['threat'])
    if len(patterns['personal']) > 0:
        score += 15 * len(patterns['personal'])
    
    score = min(score, 100)
    
    if score >= 85:
        return "CRITICAL"
    elif score >= 70:
        return "HIGH"
    elif score >= 50:
        return "MEDIUM"
    else:
        return "LOW"

def get_scam_category(patterns: Dict, confidence: float) -> List[str]:
    """Determine scam category based on patterns"""
    categories = []
    
    if len(patterns['financial']) >= 2 and len(patterns['urgency']) >= 1:
        categories.append("Banking Phishing Scam")
    if len(patterns['prize']) >= 1:
        categories.append("Lottery/Prize Scam")
    if len(patterns['personal']) >= 1:
        categories.append("Identity Theft Attempt")
    if len(patterns['threat']) >= 1:
        categories.append("Intimidation/Extortion Scam")
    if confidence >= 90 and len(patterns['financial']) == 0 and len(patterns['prize']) == 0:
        categories.append("Generic Phishing")
    
    return categories if categories else ["Suspicious Message"]

def get_safety_recommendations(categories: List[str], has_urls: bool, has_phones: bool) -> Dict:
    """Generate safety recommendations based on scam type"""
    tips = set()
    actions = set()
    
    for category in categories:
        if "Banking" in category or "Phishing" in category:
            tips.update(SAFETY_TIPS['bank_fraud'])
            tips.update(SAFETY_TIPS['phishing'])
        elif "Lottery" in category or "Prize" in category:
            tips.update(SAFETY_TIPS['lottery'])
        elif "Identity" in category:
            tips.update(SAFETY_TIPS['bank_fraud'])
            tips.update(SAFETY_TIPS['general'])
        elif "Intimidation" in category:
            tips.update(SAFETY_TIPS['general'])
    
    if has_urls:
        actions.add("Do NOT click any links in this message")
        actions.add("Hover over links to verify the real destination")
    
    if has_phones:
        actions.add("Do NOT call any phone numbers in the message")
        actions.add("Contact companies using official numbers only")
    
    actions.add("Delete this message immediately")
    actions.add("Block the sender")
    
    if "Identity" in str(categories):
        actions.add("Monitor your accounts for suspicious activity")
        actions.add("Consider changing your passwords")
    
    return {
        'tips': list(tips)[:5] if tips else SAFETY_TIPS['general'][:3],
        'actions': list(actions)[:5]
    }

@app.options("/{full_path:path}")
async def options_handler(request: Request, full_path: str):
    """Handle OPTIONS requests for CORS preflight"""
    return JSONResponse(
        content={},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Accept",
            "Access-Control-Max-Age": "3600",
        }
    )

@app.post("/analyze", response_model=EnhancedAnalysisResponse)
async def analyze_text(request: TextRequest):
    try:
        if model is None or tokenizer is None:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        text = request.text
        print("Analyzing text:", text[:50], "...")
        
        # Model prediction
        inputs = tokenizer(
            text,
            return_tensors="pt",
            truncation=True,
            max_length=512,
            padding=True
        ).to(device)
        
        with torch.no_grad():
            outputs = model(**inputs)
            probabilities = torch.nn.functional.softmax(outputs.logits, dim=-1)
            if probabilities.shape[-1] == 2:
                prediction = probabilities[0][1].item()
            else:
                prediction = probabilities[0][0].item()
            confidence = prediction * 100
        
        is_scam = prediction > 0.5
        print(f"Analysis complete - Scam: {is_scam}, Confidence: {confidence:.2f}%")
        
        # Language detection with confidence
        try:
            langs = detect_langs(text)
            lang_code = str(langs[0]).split(':')[0]
            lang_confidence = float(str(langs[0]).split(':')[1]) * 100
            
            language_map = {
                "en": "English", "ar": "Arabic", "fr": "French",
                "es": "Spanish", "de": "German", "zh": "Chinese",
                "hi": "Hindi", "ur": "Urdu", "bn": "Bengali",
                "pt": "Portuguese", "ru": "Russian", "ja": "Japanese",
                "it": "Italian", "tr": "Turkish", "nl": "Dutch",
                "pl": "Polish", "uk": "Ukrainian", "fa": "Persian"
            }
            language = language_map.get(lang_code, lang_code.upper())
            language_confidence = round(lang_confidence, 2)
        except:
            language = "Unknown"
            language_confidence = 0.0
        
        # Extract entities and patterns
        entities = extract_entities(text)
        patterns = detect_scam_patterns(text)
        
        # Determine threat level and category
        threat_level = get_threat_level(
            confidence, 
            patterns, 
            len(entities['urls']) > 0,
            len(entities['phones']) > 0
        )
        categories = get_scam_category(patterns, confidence)
        
        # Get recommendations
        recommendations = get_safety_recommendations(
            categories, 
            len(entities['urls']) > 0,
            len(entities['phones']) > 0
        )
        
        # Calculate risk score
        risk_score = confidence
        if len(entities['urls']) > 0:
            risk_score += 15
        if len(entities['phones']) > 0:
            risk_score += 8
        if len(patterns['financial']) > 0:
            risk_score += 5 * len(patterns['financial'])
        if len(patterns['personal']) > 0:
            risk_score += 10 * len(patterns['personal'])
        risk_score = min(round(risk_score, 2), 100)
        
        # Build suspicious patterns list
        suspicious_patterns = [
            {"type": ["urgency"], "matches": patterns['urgency'][:5]},
            {"type": ["financial"], "matches": patterns['financial'][:5]},
            {"type": ["prize"], "matches": patterns['prize'][:5]},
            {"type": ["threat"], "matches": patterns['threat'][:5]},
            {"type": ["personal"], "matches": patterns['personal'][:5]}
        ]
        
        # Build indicators list
        indicators = [
            f"Scam probability: {confidence:.1f}%",
            f"Threat level: {threat_level}",
            f"Risk score: {risk_score:.1f}/100"
        ]
        
        if categories:
            indicators.append(f"Scam type: {', '.join(categories)}")
        
        if entities['urls']:
            indicators.append(f"Found {len(entities['urls'])} suspicious URL(s)")
        
        if entities['phones']:
            indicators.append(f"Found {len(entities['phones'])} phone number(s)")
        
        if entities['emails']:
            indicators.append(f"Found {len(entities['emails'])} email address(es)")
        
        if patterns['urgency']:
            indicators.append(f"Urgency keywords: {', '.join(patterns['urgency'][:3])}")
        
        if patterns['financial']:
            indicators.append("Financial keywords detected")
        
        if patterns['prize']:
            indicators.append("Prize/lottery keywords detected")
        
        if is_scam and confidence > 90:
            indicators.append("HIGH CONFIDENCE SCAM - Take immediate action")
        elif is_scam and confidence > 70:
            indicators.append("MEDIUM CONFIDENCE - Proceed with caution")
        elif not is_scam and confidence > 90:
            indicators.append("Message appears safe")
        
        return EnhancedAnalysisResponse(
            # Basic info
            isScam=is_scam,
            confidence=round(confidence, 2),
            language=language,
            language_confidence=language_confidence,
            
            # Threat assessment
            threat_level=threat_level,
            risk_score=risk_score,
            scam_category=categories,
            
            # Pattern detection
            suspicious_patterns=suspicious_patterns,
            urgency_indicators=patterns['urgency'][:5],
            financial_indicators=patterns['financial'][:5],
            urls_found=entities['urls'],
            phone_numbers=entities['phones'],
            emails_found=entities['emails'],
            
            # Recommendations
            safety_tips=recommendations['tips'],
            actions_to_take=recommendations['actions'],
            
            # Indicators
            indicators=indicators
        )
    
    except Exception as e:
        print("Error during analysis:", e)
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "model_source": HF_MODEL_NAME if model else None,
        "device": str(device)
    }

@app.get("/model-info")
async def model_info():
    if model:
        return {
            "model_source": HF_MODEL_NAME,
            "model_type": model.config.model_type,
            "num_labels": model.config.num_labels,
            "max_length": tokenizer.model_max_length if tokenizer else 512,
            "device": str(device)
        }
    return {"error": "Model not loaded"}

if __name__ == "__main__":
    print("=" * 60)
    print("Starting Enhanced Multilingual Scam Detection Server")
    print("=" * 60)
    print(f"Model source: {HF_MODEL_NAME}")
    print("Server will run at: http://localhost:8000")
    print("API endpoints:")
    print("  - POST /analyze  (enhanced analysis)")
    print("  - GET  /health    (check server status)")
    print("  - GET  /model-info (model information)")
    print("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=8000) 