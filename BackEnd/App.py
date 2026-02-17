"""
Crop Disease Detection Chatbot Backend
======================================
Enhanced Flask API with ngrok tunneling for Colab deployment
Supports both local development and cloud hosting
"""

import os
import json
import torch
import logging
import requests
from datetime import datetime
from typing import Dict, Optional, List
from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
from pathlib import Path
import uuid

# ================================================================================
# LOGGING CONFIGURATION
# ================================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('chatbot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


# ================================================================================
# CONFIGURATION
# ================================================================================

class Config:
    """Application configuration"""
    # Model paths
    MODEL_PATH = "/content/drive/MyDrive/Crop_Disease_AI_v2/03_Training_Outputs/checkpoint-300"
    CSV_PATH = "/content/drive/MyDrive/Crop_Disease_AI_v2/crop_data_cleaned.csv"
    
    # Model parameters
    MAX_TOKENS = 256
    TEMPERATURE = 0.7
    TOP_P = 0.95
    REPETITION_PENALTY = 1.1
    
    # Server configuration
    DEBUG = True
    HOST = "0.0.0.0"
    PORT = 5000
    SECRET_KEY = os.urandom(24)
    
    # ngrok configuration
    USE_NGROK = True
    NGROK_AUTH_TOKEN = None  # Set via environment or manually
    
    # API configuration
    MAX_QUERY_LENGTH = 500
    MIN_QUERY_LENGTH = 10
    TIMEOUT = 60
    
    # Features
    ENABLE_HISTORY = True
    ENABLE_AUTHENTICATION = False
    API_KEYS = {}


# ================================================================================
# REQUEST/RESPONSE MODELS
# ================================================================================

class DiagnosisRequest:
    """Structured diagnosis request"""
    def __init__(self, query: str, session_id: Optional[str] = None):
        self.query = query.strip()
        self.session_id = session_id or str(uuid.uuid4())
        self.timestamp = datetime.now()
    
    def is_valid(self) -> tuple[bool, str]:
        """Validate request"""
        if not self.query:
            return False, "Query cannot be empty"
        if len(self.query) < Config.MIN_QUERY_LENGTH:
            return False, f"Query too short (min {Config.MIN_QUERY_LENGTH} chars)"
        if len(self.query) > Config.MAX_QUERY_LENGTH:
            return False, f"Query too long (max {Config.MAX_QUERY_LENGTH} chars)"
        return True, ""


class DiagnosisResponse:
    """Structured diagnosis response"""
    def __init__(self, success: bool, query: str, response: Optional[str] = None, 
                 error: Optional[str] = None, session_id: Optional[str] = None):
        self.success = success
        self.query = query
        self.response = response
        self.error = error
        self.session_id = session_id
        self.timestamp = datetime.now().isoformat()
        self.request_id = str(uuid.uuid4())
    
    def to_dict(self) -> Dict:
        """Convert to dictionary"""
        return {
            "success": self.success,
            "query": self.query,
            "response": self.response,
            "error": self.error,
            "session_id": self.session_id,
            "request_id": self.request_id,
            "timestamp": self.timestamp
        }


# ================================================================================
# MODEL MANAGEMENT
# ================================================================================

class CropDiseaseModel:
    """Manage fine-tuned Llama model"""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.model = None
        self.tokenizer = None
        self.device = self._get_device()
        self.is_loaded = False
        logger.info(f"Model initialized. Device: {self.device}")

    def _get_device(self) -> str:
        """Detect available device"""
        if torch.cuda.is_available():
            device = "cuda"
            logger.info(f"CUDA available. GPU: {torch.cuda.get_device_name(0)}")
        else:
            device = "cpu"
            logger.warning("GPU not available. Using CPU (slow)")
        return device

    def load_model(self) -> bool:
        """Load model and tokenizer"""
        try:
            from transformers import AutoModelForCausalLM, AutoTokenizer
            
            if not os.path.exists(self.model_path):
                logger.error(f"Model path not found: {self.model_path}")
                return False
            
            logger.info(f"Loading model from {self.model_path}...")
            
            # Load tokenizer
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_path)
            if self.tokenizer.pad_token is None:
                self.tokenizer.pad_token = self.tokenizer.eos_token
            
            # Load model
            dtype = torch.float16 if self.device == "cuda" else torch.float32
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_path,
                torch_dtype=dtype,
                device_map="auto" if self.device == "cuda" else None,
                low_cpu_mem_usage=True
            )
            
            if self.device == "cpu":
                self.model = self.model.to(self.device)
            
            self.model.eval()
            self.is_loaded = True
            logger.info("✓ Model loaded successfully")
            return True
            
        except ImportError as e:
            logger.error(f"Missing dependency: {str(e)}")
            return False
        except Exception as e:
            logger.error(f"Failed to load model: {str(e)}")
            return False

    def diagnose(self, query: str, max_tokens: int = None) -> Dict:
        """
        Get diagnosis from model
        
        Args:
            query: User's symptom/disease question
            max_tokens: Maximum response length
            
        Returns:
            Dictionary with diagnosis result
        """
        if not self.is_loaded:
            return {
                "success": False,
                "error": "Model not loaded",
                "response": None
            }
        
        max_tokens = max_tokens or Config.MAX_TOKENS

        try:
            prompt = f"""Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{query}

### Input:


### Response:
"""
            
            inputs = self.tokenizer(
                prompt, 
                return_tensors="pt",
                max_length=2048,
                truncation=True,
                padding=True
            ).to(self.device)
            
            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=max_tokens,
                    temperature=Config.TEMPERATURE,
                    top_p=Config.TOP_P,
                    repetition_penalty=Config.REPETITION_PENALTY,
                    do_sample=True,
                    pad_token_id=self.tokenizer.eos_token_id,
                )
            
            response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            
            # Clean response
            if "### Response:" in response:
                response = response.split("### Response:")[-1].strip()
            
            # Remove repetition
            lines = response.split('\n')
            unique_lines = []
            for line in lines:
                if line not in unique_lines:
                    unique_lines.append(line)
            response = '\n'.join(unique_lines[:15])  # Limit to 15 lines
            
            logger.info(f"✓ Diagnosis complete for: {query[:50]}...")
            
            return {
                "success": True,
                "response": response.strip(),
                "error": None
            }
            
        except torch.cuda.OutOfMemoryError:
            logger.error("GPU out of memory")
            return {
                "success": False,
                "error": "Model memory exceeded. Try with shorter query.",
                "response": None
            }
        except Exception as e:
            logger.error(f"Diagnosis error: {str(e)}")
            return {
                "success": False,
                "error": f"Processing error: {str(e)}",
                "response": None
            }

    def get_status(self) -> Dict:
        """Get model status"""
        return {
            "loaded": self.is_loaded,
            "device": self.device,
            "gpu_available": torch.cuda.is_available(),
            "gpu_memory": f"{torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB" if torch.cuda.is_available() else "N/A"
        }


# ================================================================================
# CONVERSATION HISTORY MANAGER
# ================================================================================

class ConversationHistory:
    """Manage conversation history"""
    
    def __init__(self, max_size: int = 100):
        self.history: Dict[str, List[Dict]] = {}
        self.max_size = max_size
    
    def add_message(self, session_id: str, role: str, content: str):
        """Add message to history"""
        if session_id not in self.history:
            self.history[session_id] = []
        
        self.history[session_id].append({
            "role": role,
            "content": content,
            "timestamp": datetime.now().isoformat()
        })
        
        # Limit history size
        if len(self.history[session_id]) > self.max_size:
            self.history[session_id] = self.history[session_id][-self.max_size:]
    
    def get_history(self, session_id: str) -> List[Dict]:
        """Get conversation history"""
        return self.history.get(session_id, [])
    
    def clear_history(self, session_id: str):
        """Clear session history"""
        if session_id in self.history:
            del self.history[session_id]


# ================================================================================
# FLASK APP
# ================================================================================

app = Flask(__name__)
app.config.from_object(Config)
CORS(app)

# Global instances
disease_model = None
conversation_history = ConversationHistory()
ngrok_url = None


def init_model():
    """Initialize model"""
    global disease_model
    disease_model = CropDiseaseModel(Config.MODEL_PATH)
    return disease_model.load_model()


def setup_ngrok(auth_token: Optional[str] = None) -> Optional[str]:
    """Setup ngrok tunnel"""
    global ngrok_url
    try:
        from pyngrok import ngrok, conf
        
        if auth_token:
            ngrok.set_auth_token(auth_token)
        
        ngrok_url = ngrok.connect(Config.PORT)
        logger.info(f"✓ ngrok tunnel established: {ngrok_url}")
        return str(ngrok_url)
    except ImportError:
        logger.warning("pyngrok not installed. Install with: pip install pyngrok")
        return None
    except Exception as e:
        logger.error(f"ngrok setup failed: {str(e)}")
        return None


# ================================================================================
# HTML DASHBOARD (Optional UI)
# ================================================================================

DASHBOARD_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Crop Disease Chatbot</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', sans-serif; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                  color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
        .chat-box { background: white; border-radius: 10px; padding: 20px; 
                    height: 500px; overflow-y: auto; margin-bottom: 15px;
                    border: 1px solid #ddd; }
        .message { margin: 10px 0; padding: 10px; border-radius: 5px; }
        .user { background: #e3f2fd; text-align: right; }
        .bot { background: #f3e5f5; }
        .input-group { display: flex; gap: 10px; margin-bottom: 15px; }
        input { flex: 1; padding: 12px; border: 1px solid #ddd; border-radius: 5px; }
        button { padding: 12px 30px; background: #667eea; color: white;
                border: none; border-radius: 5px; cursor: pointer; font-weight: bold; }
        button:hover { background: #764ba2; }
        .status { padding: 15px; background: #e8f5e9; border-radius: 5px;
                  color: #2e7d32; margin-bottom: 15px; }
        .error { background: #ffebee; color: #c62828; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌾 Crop Disease Chatbot</h1>
            <p>Get instant diagnosis for crop diseases and pests</p>
        </div>
        
        <div id="status" class="status">Loading...</div>
        <div class="chat-box" id="chatBox"></div>
        
        <div class="input-group">
            <input type="text" id="queryInput" placeholder="Describe symptoms or ask about disease..." />
            <button onclick="sendQuery()">Send</button>
        </div>
    </div>

    <script>
        const chatBox = document.getElementById('chatBox');
        const queryInput = document.getElementById('queryInput');
        const statusDiv = document.getElementById('status');

        // Check API health
        fetch('/api/health')
            .then(r => r.json())
            .then(data => {
                statusDiv.innerHTML = `✓ System Ready | Model: ${data.model_loaded ? 'Loaded' : 'Loading...'}`;
            })
            .catch(() => statusDiv.classList.add('error'));

        function sendQuery() {
            const query = queryInput.value.trim();
            if (!query) return;

            addMessage('user', query);
            queryInput.value = '';

            fetch('/api/diagnose', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ query })
            })
            .then(r => r.json())
            .then(data => {
                if (data.success) {
                    addMessage('bot', data.response);
                } else {
                    addMessage('bot', '❌ Error: ' + (data.error || 'Unknown error'));
                }
            })
            .catch(e => addMessage('bot', '❌ Connection error'));
        }

        function addMessage(role, text) {
            const msg = document.createElement('div');
            msg.className = 'message ' + role;
            msg.textContent = text;
            chatBox.appendChild(msg);
            chatBox.scrollTop = chatBox.scrollHeight;
        }

        queryInput.addEventListener('keypress', e => {
            if (e.key === 'Enter') sendQuery();
        });
    </script>
</body>
</html>
"""


# ================================================================================
# API ENDPOINTS
# ================================================================================

@app.route("/", methods=["GET"])
def home():
    """Home page with dashboard"""
    return render_template_string(DASHBOARD_HTML)


@app.route("/api/health", methods=["GET"])
def health():
    """Health check endpoint"""
    status = disease_model.get_status() if disease_model else {}
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "model": status,
        "ngrok_url": ngrok_url
    }), 200


@app.route("/api/diagnose", methods=["POST"])
def diagnose():
    """Main diagnosis endpoint"""
    try:
        data = request.get_json() or {}
        
        # Validate request
        req = DiagnosisRequest(data.get("query", ""), data.get("session_id"))
        valid, error_msg = req.is_valid()
        
        if not valid:
            return jsonify({"success": False, "error": error_msg}), 400
        
        logger.info(f"[{req.session_id}] New request: {req.query[:50]}...")
        
        # Get diagnosis
        result = disease_model.diagnose(req.query)
        
        # Create response
        response = DiagnosisResponse(
            success=result["success"],
            query=req.query,
            response=result["response"],
            error=result["error"],
            session_id=req.session_id
        )
        
        # Save to history
        if Config.ENABLE_HISTORY and result["success"]:
            conversation_history.add_message(req.session_id, "user", req.query)
            conversation_history.add_message(req.session_id, "bot", result["response"])
        
        return jsonify(response.to_dict()), (200 if result["success"] else 400)
        
    except Exception as e:
        logger.error(f"Endpoint error: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/history/<session_id>", methods=["GET"])
def get_history(session_id):
    """Get conversation history"""
    if not Config.ENABLE_HISTORY:
        return jsonify({"error": "History disabled"}), 403
    
    history = conversation_history.get_history(session_id)
    return jsonify({"session_id": session_id, "messages": history}), 200


@app.route("/api/clear-history/<session_id>", methods=["POST"])
def clear_history(session_id):
    """Clear conversation history"""
    conversation_history.clear_history(session_id)
    return jsonify({"success": True, "message": "History cleared"}), 200


@app.route("/api/info", methods=["GET"])
def api_info():
    """API information"""
    return jsonify({
        "service": "Crop Disease Detection API",
        "version": "2.0.0",
        "endpoints": {
            "GET /": "Web dashboard",
            "GET /api/health": "Health check",
            "POST /api/diagnose": "Get diagnosis",
            "GET /api/history/<session_id>": "Get chat history",
            "POST /api/clear-history/<session_id>": "Clear history",
            "GET /api/info": "This endpoint"
        },
        "ngrok_url": ngrok_url
    }), 200


@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found", "status": 404}), 404


@app.errorhandler(500)
def server_error(error):
    return jsonify({"error": "Internal server error", "status": 500}), 500


# ================================================================================
# CONSOLE INTERFACE
# ================================================================================

def run_console():
    """Interactive console for testing"""
    print("\n" + "="*80)
    print("CROP DISEASE CHATBOT - CONSOLE INTERFACE")
    print("="*80)
    print("\nCommands:")
    print("  • Type your query directly")
    print("  • 'help' - Show examples")
    print("  • 'history' - Show recent responses")
    print("  • 'clear' - Clear history")
    print("  • 'status' - Show model status")
    print("  • 'exit' - Quit\n")
    
    default_session = str(uuid.uuid4())
    
    while True:
        try:
            user_input = input("You: ").strip()
            
            if not user_input:
                continue
            
            if user_input.lower() == "exit":
                print("\n👋 Goodbye!")
                break
            
            if user_input.lower() == "help":
                print("\n📚 Example queries:")
                examples = [
                    "My apple tree has velvety olive-green spots",
                    "How to treat powdery mildew on grapes?",
                    "Rice plants showing yellow patches - what disease?",
                    "White cotton-like masses on apple twigs - help!",
                    "Tomato plants wilting with brown spots"
                ]
                for ex in examples:
                    print(f"  • {ex}")
                print()
                continue
            
            if user_input.lower() == "status":
                status = disease_model.get_status()
                print(f"\n📊 Model Status:")
                for key, value in status.items():
                    print(f"  {key}: {value}")
                print()
                continue
            
            if user_input.lower() == "history":
                hist = conversation_history.get_history(default_session)
                if hist:
                    print("\n📜 Recent interactions:")
                    for msg in hist[-5:]:
                        print(f"  [{msg['role']}]: {msg['content'][:60]}...")
                else:
                    print("\n(No history yet)")
                print()
                continue
            
            if user_input.lower() == "clear":
                conversation_history.clear_history(default_session)
                print("✓ History cleared\n")
                continue
            
            # Validate and diagnose
            req = DiagnosisRequest(user_input, default_session)
            valid, error = req.is_valid()
            
            if not valid:
                print(f"⚠️  {error}\n")
                continue
            
            print("🔄 Processing...", end="", flush=True)
            result = disease_model.diagnose(user_input)
            print("\r" + " "*30 + "\r", end="")
            
            if result["success"]:
                print(f"\nBot: {result['response']}\n")
                if Config.ENABLE_HISTORY:
                    conversation_history.add_message(default_session, "user", user_input)
                    conversation_history.add_message(default_session, "bot", result['response'])
            else:
                print(f"\n❌ Error: {result['error']}\n")
        
        except KeyboardInterrupt:
            print("\n\n👋 Shutting down...")
            break
        except Exception as e:
            logger.error(f"Console error: {str(e)}")
            print(f"\n❌ Error: {str(e)}\n")


# ================================================================================
# MAIN
# ================================================================================

if __name__ == "__main__":
    import sys
    
    print("\n" + "="*80)
    print("CROP DISEASE CHATBOT - INITIALIZATION")
    print("="*80 + "\n")
    
    # Initialize model
    logger.info("Initializing model...")
    if not init_model():
        logger.error("Failed to initialize model!")
        sys.exit(1)
    
    logger.info("Model ready!")
    
    # Parse arguments
    if "--api" in sys.argv:
        # API server mode
        mode = "--api-only" in sys.argv
        logger.info(f"Starting Flask API server (port {Config.PORT})...")
        
        # Setup ngrok if requested
        if "--ngrok" in sys.argv:
            auth_token = None
            # Try to get from environment
            if "NGROK_AUTH_TOKEN" in os.environ:
                auth_token = os.environ["NGROK_AUTH_TOKEN"]
            # Or from command line
            for arg in sys.argv:
                if arg.startswith("--ngrok-token="):
                    auth_token = arg.split("=")[1]
            
            if auth_token:
                logger.info("Setting up ngrok...")
                setup_ngrok(auth_token)
            else:
                logger.warning("ngrok token not provided. Run with --ngrok-token=YOUR_TOKEN")
        
        logger.info(f"API server running at http://localhost:{Config.PORT}")
        if ngrok_url:
            logger.info(f"ngrok URL: {ngrok_url}")
        print(f"\nEndpoints:")
        print(f"  GET  http://localhost:{Config.PORT}/ (Dashboard)")
        print(f"  POST http://localhost:{Config.PORT}/api/diagnose")
        print(f"  GET  http://localhost:{Config.PORT}/api/health")
        print(f"  GET  http://localhost:{Config.PORT}/api/info\n")
        
        app.run(host=Config.HOST, port=Config.PORT, debug=Config.DEBUG)
    else:
        # Console mode (default)
        run_console()
