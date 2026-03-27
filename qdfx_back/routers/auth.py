# backend/routers/auth.py
from fastapi import APIRouter
from pydantic import BaseModel
import requests
import dns.resolver

# Create a Router specifically for Authentication
router = APIRouter()

class EmailVerificationRequest(BaseModel):
    email: str
    company_name: str = ""

@router.post("/verify-corporate-email")
async def verify_corporate_email(request: EmailVerificationRequest):
    email = request.email.lower().strip()
    domain = email.split('@')[-1]
    
    # 1. Block public domains immediately
    public_domains =['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'mail.ru']
    if domain in public_domains:
        return {"status": "REJECTED", "message": "Public email domains are not allowed."}

    results =[]
    
    # 2. Rapid Email Verifier
    try:
        response = requests.get(f"https://rapid-email-verifier.fly.dev/api/validate?email={email}", timeout=5)
        if response.status_code == 200:
            data = response.json()
            is_valid = data.get("status") in["VALID", "PROBABLY_VALID"]
            is_disposable = data.get("validations", {}).get("is_disposable", False)
            
            if is_disposable:
                return {"status": "REJECTED", "message": "Disposable emails not allowed."}
                
            results.append({
                "service": "RapidVerifier",
                "valid": is_valid
            })
    except Exception as e:
        print(f"RapidVerifier failed: {e}")

    # 3. DNS / MX Record Check
    try:
        mx_records = dns.resolver.resolve(domain, 'MX')
        results.append({"service": "DNS_MX_Check", "valid": len(mx_records) > 0})
    except Exception as e:
        print(f"DNS Check failed: {e}")
        results.append({"service": "DNS_MX_Check", "valid": False})

    # 4. Consensus Logic
    valid_count = sum(1 for r in results if r.get("valid") == True)
    
    if valid_count >= 2:
        return {"status": "AUTO_APPROVED", "message": "Corporate domain verified."}
    elif valid_count == 1:
        return {"status": "MANUAL_REVIEW", "message": "Pending admin review."}
    else:
        return {"status": "REJECTED", "message": "Domain does not exist."}