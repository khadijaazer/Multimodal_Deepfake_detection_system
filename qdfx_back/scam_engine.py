import torch
import re
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from typing import List, Dict

# --- GLOBAL VARIABLES & STATE ---
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
HF_MODEL_NAME = "alaegmr98/multilingual-scam-detector"

class AIState:
    model = None
    tokenizer = None

state = AIState()

# --- EXACT DICTIONARIES FROM YOUR FRIEND ---
SCAM_KEYWORDS = {
    'urgency':[
        'urgent', 'immediately', 'asap', 'warning', 'alert', 'attention', 'critical',
        '立刻', '紧急', 'عاجل', 'urgente', 'dringend', 'urgente', 'urgent',
        'act now', 'expires', 'deadline', 'limited time'
    ],
    'financial':[
        'bank', 'account', 'credit card', 'paypal', 'wire transfer', 'western union',
        '银行卡', '账户', '信用卡', 'بنك', 'حساب', 'banco', 'cuenta', 'konto',
        'investment', 'profit', 'million', 'bitcoin', 'crypto'
    ],
    'prize':[
        'won', 'winner', 'lottery', 'prize', 'million', 'inheritance', 'gift',
        '中奖', '彩票', 'جائزة', 'ganador', 'lotería', 'gewonnen', 'lotterie',
        'congratulations', 'selected', 'award'
    ],
    'threat':[
        'suspend', 'block', 'close', 'terminate', 'legal action', 'lawsuit',
        '暂停', '关闭', '法律行动', 'معلقة', 'bloqueado', 'gesperrt',
        'arrest', 'police', 'court', 'fine', 'penalty'
    ],
    'personal':[
        'ssn', 'social security', 'password', 'pin', 'credit card number', 'cvv',
        '密码', '社会安全号码', 'رقم سري', 'contraseña', 'passwort',
        'identity', 'date of birth', 'mother\'s maiden name'
    ]
}

SAFETY_TIPS = {
    'phishing':[
        "Never click on suspicious links - they may steal your information",
        "Check the sender's email address carefully for misspellings",
        "Hover over links to see the real URL before clicking",
        "Contact the company directly using official channels (not the message)"
    ],
    'lottery':[
        "Legitimate lotteries never ask for money to release prizes",
        "You cannot win a lottery you didn't enter",
        "Never share bank details for 'prize claims'",
        "Delete these messages immediately"
    ],
    'bank_fraud':[
        "Banks never ask for full passwords or PINs via email/text",
        "Call your bank using the number on your card (not the message)",
        "Enable two-factor authentication on all accounts",
        "Check your account directly by logging into the official website"
    ],
    'investment':[
        "If it sounds too good to be true, it probably is",
        "Research investment opportunities thoroughly",
        "Never invest based on an unsolicited message",
        "Consult with a financial advisor"
    ],
    'general':[
        "Don't respond to unsolicited messages",
        "Never send money to strangers",
        "Keep your personal information private",
        "Report suspicious messages to authorities",
        "Block the sender immediately"
    ]
}

# --- EXACT FUNCTIONS FROM YOUR FRIEND ---
def load_model():
    try:
        print("=" * 60)
        print(f"Loading model from Hugging Face: {HF_MODEL_NAME}")
        print("=" * 60)
        print("This may take a few minutes on first run (downloading model)...")
        
        state.tokenizer = AutoTokenizer.from_pretrained(HF_MODEL_NAME)
        state.model = AutoModelForSequenceClassification.from_pretrained(HF_MODEL_NAME)
        state.model.to(device)
        state.model.eval()
        
        print("Model loaded successfully from Hugging Face!")
        print(f"Using device: {device}")
        print(f"Model type: {state.model.config.model_type}")
        print("=" * 60)
    except Exception as e:
        print(f"Error loading model: {e}")
        import traceback
        traceback.print_exc()

def extract_entities(text: str) -> Dict:
    entities = {'urls': [], 'phones':[], 'emails': []}
    
    url_pattern = r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.(com|org|net|io|gov|edu|co|uk|de|fr|es|it|ru|cn|jp)(?:/[^\s]*)?'
    urls = re.findall(url_pattern, text, re.IGNORECASE)
    entities['urls'] = [url for url in urls if url]
    
    phone_pattern = r'[\+\(]?[1-9][0-9 .\-\(\)]{8,}[0-9]'
    phones = re.findall(phone_pattern, text)
    entities['phones'] =[phone for phone in phones if len(phone) >= 8]
    
    email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    emails = re.findall(email_pattern, text)
    entities['emails'] = [email for email in emails if email]
    
    return entities

def detect_scam_patterns(text: str) -> Dict:
    text_lower = text.lower()
    patterns = {'urgency': [], 'financial': [], 'prize': [], 'threat': [], 'personal':[]}
    for category, keywords in SCAM_KEYWORDS.items():
        for keyword in keywords:
            if keyword.lower() in text_lower:
                patterns[category].append(keyword)
    return patterns

def get_threat_level(confidence: float, patterns: Dict, has_urls: bool, has_phones: bool) -> str:
    score = confidence
    if has_urls: score += 15
    if has_phones: score += 5
    if len(patterns['urgency']) > 0: score += 5 * len(patterns['urgency'])
    if len(patterns['financial']) > 0: score += 8 * len(patterns['financial'])
    if len(patterns['prize']) > 0: score += 10 * len(patterns['prize'])
    if len(patterns['threat']) > 0: score += 8 * len(patterns['threat'])
    if len(patterns['personal']) > 0: score += 15 * len(patterns['personal'])
    
    score = min(score, 100)
    if score >= 85: return "CRITICAL"
    elif score >= 70: return "HIGH"
    elif score >= 50: return "MEDIUM"
    else: return "LOW"

def get_scam_category(patterns: Dict, confidence: float) -> List[str]:
    categories = []
    if len(patterns['financial']) >= 2 and len(patterns['urgency']) >= 1: categories.append("Banking Phishing Scam")
    if len(patterns['prize']) >= 1: categories.append("Lottery/Prize Scam")
    if len(patterns['personal']) >= 1: categories.append("Identity Theft Attempt")
    if len(patterns['threat']) >= 1: categories.append("Intimidation/Extortion Scam")
    if confidence >= 90 and len(patterns['financial']) == 0 and len(patterns['prize']) == 0: categories.append("Generic Phishing")
    return categories if categories else ["Suspicious Message"]

def get_safety_recommendations(categories: List[str], has_urls: bool, has_phones: bool) -> Dict:
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