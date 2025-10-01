/**
 * Copyright FunASR (https://github.com/alibaba-damo-academy/FunASR). All Rights
 * Reserved. MIT License  (https://opensource.org/licenses/MIT)
 */

#include "http-server.h"
#include <chrono>
#include <algorithm>

// Base64 decode implementation
std::vector<unsigned char> HttpAsrServer::base64_decode(const std::string& encoded_string) {
    static const std::string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    std::vector<unsigned char> decoded;
    int in_len = encoded_string.size();
    int i = 0;
    int bin = 0;
    
    while (i < in_len) {
        int c = encoded_string[i++];
        if (chars.find(c) != std::string::npos) {
            bin = (bin << 6) + chars.find(c);
        } else if (c == '=') {
            bin = bin << 6;
        } else {
            continue;
        }
        
        if (i % 4 == 0) {
            decoded.push_back((bin >> 16) & 0xFF);
            decoded.push_back((bin >> 8) & 0xFF);
            decoded.push_back(bin & 0xFF);
            bin = 0;
        }
    }
    
    if (encoded_string.back() == '=') {
        decoded.pop_back();
    }
    if (encoded_string.size() >= 2 && encoded_string[encoded_string.size()-2] == '=') {
        decoded.pop_back();
    }
    
    return decoded;
}

void HttpAsrServer::InitAsr(const std::string& model_dir,
                           const std::string& vad_dir,
                           const std::string& vad_quant_dir,
                           const std::string& punc_dir,
                           const std::string& punc_quant_dir,
                           const std::string& itn_tagger_fst_dir,
                           const std::string& itn_verbalizer_fst_dir,
                           int thread_num) {
    this->model_dir = model_dir;
    this->vad_dir = vad_dir;
    this->vad_quant_dir = vad_quant_dir;
    this->punc_dir = punc_dir;
    this->punc_quant_dir = punc_quant_dir;
    this->itn_tagger_fst_dir = itn_tagger_fst_dir;
    this->itn_verbalizer_fst_dir = itn_verbalizer_fst_dir;
    this->thread_num = thread_num;
    
    // Initialize ASR model
    std::map<std::string, std::string> model_path;
    model_path.insert({MODEL_DIR, model_dir});
    model_path.insert({QUANTIZE, "true"});
    model_path.insert({THREAD_NUM, std::to_string(thread_num)});
    
    // Add optional components
    if (!vad_dir.empty()) {
        model_path.insert({VAD_DIR, vad_dir});
    }
    if (!vad_quant_dir.empty()) {
        model_path.insert({VAD_QUANT, vad_quant_dir});
    }
    if (!punc_dir.empty()) {
        model_path.insert({PUNC_DIR, punc_dir});
    }
    if (!punc_quant_dir.empty()) {
        model_path.insert({PUNC_QUANT, punc_quant_dir});
    }
    if (!itn_tagger_fst_dir.empty()) {
        model_path.insert({"itn-tagger", itn_tagger_fst_dir});
    }
    if (!itn_verbalizer_fst_dir.empty()) {
        model_path.insert({"itn-verbalizer", itn_verbalizer_fst_dir});
    }
    
    asr_handle = FunOfflineInit(model_path, 1, false, 1);
    if (asr_handle == nullptr) {
        LOG(ERROR) << "Failed to initialize ASR model";
        throw std::runtime_error("Failed to initialize ASR model");
    }
    
    LOG(INFO) << "ASR model initialized successfully";
}

void HttpAsrServer::handle_recognize(const httplib::Request& req, httplib::Response& res) {
    auto start_time = std::chrono::high_resolution_clock::now();
    
    try {
        // Parse JSON request
        if (req.body.empty()) {
            res.status = 400;
            res.set_content("{\"error\":\"Empty request body\"}", "application/json");
            return;
        }
        
        nlohmann::json json_req;
        try {
            json_req = nlohmann::json::parse(req.body);
        } catch (const std::exception& e) {
            res.status = 400;
            res.set_content("{\"error\":\"Invalid JSON\"}", "application/json");
            LOG(ERROR) << "JSON parse error: " << e.what();
            return;
        }
        
        // Extract parameters
        std::string audio_base64 = json_req.value("audio", "");
        std::string wav_format = json_req.value("wav_format", "pcm");
        std::string wav_name = json_req.value("wav_name", "audio");
        bool itn = json_req.value("itn", true);
        int audio_fs = json_req.value("audio_fs", 16000);
        std::string hotwords_str = json_req.value("hotwords", "");
        std::string svs_lang = json_req.value("svs_lang", "auto");
        bool svs_itn = json_req.value("svs_itn", true);
        
        if (audio_base64.empty()) {
            res.status = 400;
            res.set_content("{\"error\":\"Missing audio data\"}", "application/json");
            return;
        }
        
        // Decode base64 audio data
        std::vector<unsigned char> audio_data_raw = base64_decode(audio_base64);
        std::vector<char> audio_data(audio_data_raw.begin(), audio_data_raw.end());
        
        LOG(INFO) << "Processing audio: " << audio_data.size() << " bytes, format: " << wav_format;
        LOG(INFO) << "Recognition parameters:";
        LOG(INFO) << "  audio_fs: " << audio_fs;
        LOG(INFO) << "  wav_format: " << wav_format;
        LOG(INFO) << "  itn: " << itn;
        LOG(INFO) << "  svs_lang: " << svs_lang;
        LOG(INFO) << "  svs_itn: " << svs_itn;
        
        // Process hotwords if provided
        std::vector<std::vector<float>> hotwords_embedding;
        if (!hotwords_str.empty()) {
            try {
                hotwords_embedding = CompileHotwordEmbedding(asr_handle, hotwords_str);
                LOG(INFO) << "Hotwords processed: " << hotwords_str;
            } catch (const std::exception& e) {
                LOG(WARNING) << "Hotwords processing failed: " << e.what();
            }
        }
        
        // Create decoder handle with default values
        float global_beam = 7.0f;
        float lattice_beam = 6.0f; 
        float am_scale = 10.0f;
        FUNASR_DEC_HANDLE decoder_handle = FunASRWfstDecoderInit(asr_handle, ASR_OFFLINE, global_beam, lattice_beam, am_scale);
        
        // Perform ASR inference (same parameters as WebSocket)
        FUNASR_RESULT result = nullptr;
        try {
            result = FunOfflineInferBuffer(
                asr_handle, 
                audio_data.data(), 
                audio_data.size(),
                RASR_NONE, 
                nullptr, 
                hotwords_embedding,
                audio_fs, 
                wav_format,
                itn, 
                decoder_handle,  // Use decoder_handle like WebSocket
                svs_lang, 
                svs_itn
            );
        } catch (const std::exception& e) {
            LOG(ERROR) << "ASR inference failed: " << e.what();
            res.status = 500;
            res.set_content("{\"error\":\"ASR inference failed\"}", "application/json");
            return;
        }
        
        // Prepare response
        nlohmann::json response;
        if (result != nullptr) {
            try {
                std::string asr_result = FunASRGetResult(result, 0);
                std::string timestamp = FunASRGetStamp(result);
                std::string stamp_sents = FunASRGetStampSents(result);
                
                response["text"] = asr_result;
                response["mode"] = "offline";
                response["is_final"] = true;
                response["wav_name"] = wav_name;
                
                if (!timestamp.empty()) {
                    response["timestamp"] = timestamp;
                }
                
                if (!stamp_sents.empty()) {
                    try {
                        nlohmann::json json_stamp = nlohmann::json::parse(stamp_sents);
                        response["stamp_sents"] = json_stamp;
                    } catch (const std::exception& e) {
                        LOG(WARNING) << "Failed to parse stamp_sents: " << e.what();
                        response["stamp_sents"] = "";
                    }
                }
                
                FunASRFreeResult(result);
                
                LOG(INFO) << "Recognition result: " << asr_result;
            } catch (const std::exception& e) {
                LOG(ERROR) << "Result processing failed: " << e.what();
                response["text"] = "";
                response["error"] = "Result processing failed";
            }
        } else {
            response["text"] = "";
            response["error"] = "Recognition failed";
            response["mode"] = "offline";
            response["is_final"] = true;
            response["wav_name"] = wav_name;
        }
        
        // Clean up decoder handle
        if (decoder_handle) {
            FunASRWfstDecoderUninit(decoder_handle);
        }
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
        response["processing_time_ms"] = duration.count();
        
        res.set_content(response.dump(), "application/json");
        res.set_header("Access-Control-Allow-Origin", "*");
        res.set_header("Access-Control-Allow-Methods", "POST, OPTIONS");
        res.set_header("Access-Control-Allow-Headers", "Content-Type");
        
    } catch (const std::exception& e) {
        LOG(ERROR) << "Unexpected error: " << e.what();
        res.status = 500;
        nlohmann::json error_response;
        error_response["error"] = "Internal server error";
        res.set_content(error_response.dump(), "application/json");
    }
}

void HttpAsrServer::Start(const std::string& host, int port) {
    if (asr_handle == nullptr) {
        throw std::runtime_error("ASR model not initialized");
    }
    
    // Set up routes
    server->Post("/recognize", [this](const httplib::Request& req, httplib::Response& res) {
        handle_recognize(req, res);
    });
    
    // Health check endpoint
    server->Get("/health", [](const httplib::Request& req, httplib::Response& res) {
        res.set_content("{\"status\":\"ok\"}", "application/json");
    });
    
    // CORS preflight
    server->Options("/recognize", [](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        res.set_header("Access-Control-Allow-Methods", "POST, OPTIONS");
        res.set_header("Access-Control-Allow-Headers", "Content-Type");
    });
    
    LOG(INFO) << "Starting HTTP server on " << host << ":" << port;
    
    if (!server->listen(host, port)) {
        throw std::runtime_error("Failed to start HTTP server");
    }
}

void HttpAsrServer::Stop() {
    if (server) {
        server->stop();
        LOG(INFO) << "HTTP server stopped";
    }
}

HttpAsrServer::~HttpAsrServer() {
    Stop();
    if (asr_handle) {
        FunOfflineUninit(asr_handle);
        LOG(INFO) << "ASR handle released";
    }
}