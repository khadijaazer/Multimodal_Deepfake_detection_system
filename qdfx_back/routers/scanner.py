from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict
import torch
from langdetect import detect_langs

# Import exact logic from scam_engine
from scam_engine import (
    state, device, HF_MODEL_NAME, 
    extract_entities, detect_scam_patterns, get_threat_level, 
    get_scam_category, get_safety_recommendations
)

router = APIRouter()

# --- EXACT SCHEMAS FROM YOUR FRIEND ---
class TextRequest(BaseModel):
    text: str

class EnhancedAnalysisResponse(BaseModel):
    isScam: bool
    confidence: float
    language: str
    language_confidence: float
    threat_level: str
    risk_score: float
    scam_category: List[str]
    suspicious_patterns: List[Dict[str, List[str]]]
    urgency_indicators: List[str]
    financial_indicators: List[str]
    urls_found: List[str]
    phone_numbers: List[str]
    emails_found: List[str]
    safety_tips: List[str]
    actions_to_take: List[str]
    indicators: List[str]


# --- EXACT /analyze ENDPOINT FROM YOUR FRIEND ---
@router.post("/analyze", response_model=EnhancedAnalysisResponse)
async def analyze_text(request: TextRequest):
    try:
        if state.model is None or state.tokenizer is None:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        text = request.text
        print("Analyzing text:", text[:50], "...")
        
        inputs = state.tokenizer(
            text, return_tensors="pt", truncation=True, max_length=512, padding=True
        ).to(device)
        
        with torch.no_grad():
            outputs = state.model(**inputs)
            probabilities = torch.nn.functional.softmax(outputs.logits, dim=-1)
            if probabilities.shape[-1] == 2:
                prediction = probabilities[0][1].item()
            else:
                prediction = probabilities[0][0].item()
            confidence = prediction * 100
        
        is_scam = prediction > 0.5
        print(f"Analysis complete - Scam: {is_scam}, Confidence: {confidence:.2f}%")
        
        try:
            langs = detect_langs(text)
            lang_code = str(langs[0]).split(':')[0]
            lang_confidence = float(str(langs[0]).split(':')[1]) * 100
            language_map = {
                "en": "English", "ar": "Arabic", "fr": "French", "es": "Spanish", "de": "German", 
                "zh": "Chinese", "hi": "Hindi", "ur": "Urdu", "bn": "Bengali", "pt": "Portuguese", 
                "ru": "Russian", "ja": "Japanese", "it": "Italian", "tr": "Turkish", "nl": "Dutch",
                "pl": "Polish", "uk": "Ukrainian", "fa": "Persian"
            }
            language = language_map.get(lang_code, lang_code.upper())
            language_confidence = round(lang_confidence, 2)
        except:
            language = "Unknown"
            language_confidence = 0.0
        
        entities = extract_entities(text)
        patterns = detect_scam_patterns(text)
        threat_level = get_threat_level(confidence, patterns, len(entities['urls']) > 0, len(entities['phones']) > 0)
        categories = get_scam_category(patterns, confidence)
        recommendations = get_safety_recommendations(categories, len(entities['urls']) > 0, len(entities['phones']) > 0)
        
        risk_score = confidence
        if len(entities['urls']) > 0: risk_score += 15
        if len(entities['phones']) > 0: risk_score += 8
        if len(patterns['financial']) > 0: risk_score += 5 * len(patterns['financial'])
        if len(patterns['personal']) > 0: risk_score += 10 * len(patterns['personal'])
        risk_score = min(round(risk_score, 2), 100)
        
        suspicious_patterns = [
            {"type": ["urgency"], "matches": patterns['urgency'][:5]},
            {"type": ["financial"], "matches": patterns['financial'][:5]},
            {"type": ["prize"], "matches": patterns['prize'][:5]},
            {"type": ["threat"], "matches": patterns['threat'][:5]},
            {"type": ["personal"], "matches": patterns['personal'][:5]}
        ]
        
        indicators =[f"Scam probability: {confidence:.1f}%", f"Threat level: {threat_level}", f"Risk score: {risk_score:.1f}/100"]
        if categories: indicators.append(f"Scam type: {', '.join(categories)}")
        if entities['urls']: indicators.append(f"Found {len(entities['urls'])} suspicious URL(s)")
        if entities['phones']: indicators.append(f"Found {len(entities['phones'])} phone number(s)")
        if entities['emails']: indicators.append(f"Found {len(entities['emails'])} email address(es)")
        if patterns['urgency']: indicators.append(f"Urgency keywords: {', '.join(patterns['urgency'][:3])}")
        if patterns['financial']: indicators.append("Financial keywords detected")
        if patterns['prize']: indicators.append("Prize/lottery keywords detected")
        
        if is_scam and confidence > 90: indicators.append("HIGH CONFIDENCE SCAM - Take immediate action")
        elif is_scam and confidence > 70: indicators.append("MEDIUM CONFIDENCE - Proceed with caution")
        elif not is_scam and confidence > 90: indicators.append("Message appears safe")
        
        return EnhancedAnalysisResponse(
            isScam=is_scam, confidence=round(confidence, 2), language=language, language_confidence=language_confidence,
            threat_level=threat_level, risk_score=risk_score, scam_category=categories, suspicious_patterns=suspicious_patterns,
            urgency_indicators=patterns['urgency'][:5], financial_indicators=patterns['financial'][:5], urls_found=entities['urls'],
            phone_numbers=entities['phones'], emails_found=entities['emails'], safety_tips=recommendations['tips'],
            actions_to_take=recommendations['actions'], indicators=indicators
        )
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

# --- EXACT /health AND /model-info ENDPOINTS ---
@router.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": state.model is not None, "model_source": HF_MODEL_NAME if state.model else None, "device": str(device)}

@router.get("/model-info")
async def model_info():
    if state.model:
        return {"model_source": HF_MODEL_NAME, "model_type": state.model.config.model_type, "num_labels": state.model.config.num_labels, "max_length": state.tokenizer.model_max_length if state.tokenizer else 512, "device": str(device)}
    return {"error": "Model not loaded"}