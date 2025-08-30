#!/usr/bin/env python3
"""
DeepSeek Interface for ELIAS Geppetto
Handles DeepSeek model inference via Port communication with Elixir
"""

import json
import sys
import struct
import logging
import os
from typing import Dict, Any, Optional

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler('/tmp/deepseek.log'), logging.StreamHandler()]
)
logger = logging.getLogger('deepseek_interface')

class DeepSeekInterface:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.model_loaded = False
        
    def initialize_model(self):
        """Initialize DeepSeek model and tokenizer"""
        try:
            logger.info("Initializing DeepSeek model...")
            
            # Try to import transformers
            try:
                from transformers import AutoTokenizer, AutoModelForCausalLM
            except ImportError:
                logger.error("Transformers library not installed")
                return False
            
            # Model path - check if model exists locally
            model_path = "/data/models/deepseek-coder-6.7b-instruct"
            
            if not os.path.exists(model_path):
                logger.warning(f"Model not found at {model_path}, using default")
                model_path = "deepseek-ai/deepseek-coder-6.7b-instruct"
            
            # Load tokenizer and model
            self.tokenizer = AutoTokenizer.from_pretrained(
                model_path, 
                trust_remote_code=True
            )
            
            self.model = AutoModelForCausalLM.from_pretrained(
                model_path,
                trust_remote_code=True,
                torch_dtype="auto",
                device_map="auto"
            )
            
            self.model_loaded = True
            logger.info("DeepSeek model initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize DeepSeek model: {e}")
            return False
    
    def generate_response(self, prompt: str, options: Dict[str, Any]) -> str:
        """Generate response from DeepSeek model"""
        if not self.model_loaded:
            raise RuntimeError("Model not loaded")
        
        try:
            # Default generation parameters
            max_length = options.get('max_length', 512)
            temperature = options.get('temperature', 0.7)
            top_p = options.get('top_p', 0.9)
            
            # Tokenize input
            inputs = self.tokenizer(prompt, return_tensors="pt")
            
            # Generate response
            with torch.no_grad():
                outputs = self.model.generate(
                    inputs.input_ids,
                    max_length=max_length,
                    temperature=temperature,
                    top_p=top_p,
                    do_sample=True,
                    pad_token_id=self.tokenizer.eos_token_id
                )
            
            # Decode response
            response = self.tokenizer.decode(
                outputs[0], 
                skip_special_tokens=True
            )
            
            # Remove the original prompt from response
            if response.startswith(prompt):
                response = response[len(prompt):].strip()
            
            return response
            
        except Exception as e:
            logger.error(f"Generation failed: {e}")
            raise

class PortCommunicator:
    """Handles communication with Elixir via Port protocol"""
    
    def __init__(self):
        self.deepseek = DeepSeekInterface()
        
    def send_message(self, data: Dict[str, Any]):
        """Send message to Elixir using 4-byte length prefix"""
        try:
            json_data = json.dumps(data)
            json_bytes = json_data.encode('utf-8')
            length = len(json_bytes)
            
            # Send length prefix (4 bytes, big-endian)
            sys.stdout.buffer.write(struct.pack('>I', length))
            
            # Send JSON data
            sys.stdout.buffer.write(json_bytes)
            sys.stdout.buffer.flush()
            
        except Exception as e:
            logger.error(f"Failed to send message: {e}")
    
    def receive_message(self) -> Optional[Dict[str, Any]]:
        """Receive message from Elixir using 4-byte length prefix"""
        try:
            # Read length prefix (4 bytes)
            length_bytes = sys.stdin.buffer.read(4)
            if len(length_bytes) != 4:
                return None
                
            length = struct.unpack('>I', length_bytes)[0]
            
            # Read JSON data
            json_bytes = sys.stdin.buffer.read(length)
            if len(json_bytes) != length:
                return None
            
            json_data = json_bytes.decode('utf-8')
            return json.loads(json_data)
            
        except Exception as e:
            logger.error(f"Failed to receive message: {e}")
            return None
    
    def handle_request(self, request: Dict[str, Any]):
        """Handle incoming request from Elixir"""
        request_id = request.get('request_id', 'unknown')
        request_type = request.get('type', 'unknown')
        
        try:
            if request_type == 'query':
                prompt = request.get('prompt', '')
                options = request.get('options', {})
                
                logger.info(f"Processing query request {request_id}")
                result = self.deepseek.generate_response(prompt, options)
                
                response = {
                    'request_id': request_id,
                    'status': 'success',
                    'result': result
                }
                
            elif request_type == 'train':
                # Training not implemented yet
                response = {
                    'request_id': request_id,
                    'status': 'error',
                    'message': 'Training not implemented'
                }
                
            else:
                response = {
                    'request_id': request_id,
                    'status': 'error',
                    'message': f'Unknown request type: {request_type}'
                }
            
            self.send_message(response)
            
        except Exception as e:
            logger.error(f"Error handling request {request_id}: {e}")
            error_response = {
                'request_id': request_id,
                'status': 'error',
                'message': str(e)
            }
            self.send_message(error_response)
    
    def run(self):
        """Main communication loop"""
        logger.info("Starting DeepSeek interface...")
        
        # Initialize model
        if self.deepseek.initialize_model():
            # Send ready signal
            self.send_message({'status': 'ready'})
            logger.info("DeepSeek interface ready")
        else:
            # Send error signal
            self.send_message({
                'status': 'error',
                'message': 'Failed to initialize model'
            })
            return
        
        # Main communication loop
        try:
            while True:
                request = self.receive_message()
                if request is None:
                    logger.info("Port closed, exiting")
                    break
                
                self.handle_request(request)
                
        except KeyboardInterrupt:
            logger.info("Received interrupt, shutting down")
        except Exception as e:
            logger.error(f"Unexpected error in main loop: {e}")

def main():
    """Entry point"""
    communicator = PortCommunicator()
    communicator.run()

if __name__ == '__main__':
    main()