/**
 * Copyright FunASR (https://github.com/alibaba-damo-academy/FunASR). All Rights
 * Reserved. MIT License  (https://opensource.org/licenses/MIT)
 */

#include "http-server.h"
#include <chrono>
#include <algorithm>


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
        // Check if request has file upload
        auto file_iter = req.files.find("file");
        if (file_iter == req.files.end()) {
            res.status = 400;
            res.set_content("{\"error\":\"Missing audio file\"}", "application/json");
            return;
        }
        
        const auto& file = file_iter->second;
        if (file.content.empty()) {
            res.status = 400;
            res.set_content("{\"error\":\"Empty audio file\"}", "application/json");
            return;
        }
        
        // Get audio data directly from uploaded file
        std::vector<char> audio_data(file.content.begin(), file.content.end());
        
        // Extract parameters from form data
        std::string wav_format = "pcm"; // Default to pcm since we'll extract PCM data
        std::string wav_name = file.filename.empty() ? "audio" : file.filename;
        bool itn = true;
        int audio_fs = 16000;
        std::string hotwords_str = "";
        std::string svs_lang = "auto";
        bool svs_itn = true;
        
        // Override with form parameters if provided
        if (req.has_param("wav_format")) {
            wav_format = req.get_param_value("wav_format");
        }
        if (req.has_param("itn")) {
            itn = req.get_param_value("itn") == "true";
        }
        if (req.has_param("audio_fs")) {
            audio_fs = std::stoi(req.get_param_value("audio_fs"));
        }
        if (req.has_param("hotwords")) {
            hotwords_str = req.get_param_value("hotwords");
        }
        if (req.has_param("svs_lang")) {
            svs_lang = req.get_param_value("svs_lang");
        }
        if (req.has_param("svs_itn")) {
            svs_itn = req.get_param_value("svs_itn") == "true";
        }
        
        LOG(INFO) << "Processing uploaded audio file: " << wav_name;
        LOG(INFO) << "Audio size: " << audio_data.size() << " bytes, format: " << wav_format;
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
        LOG(INFO) << "Creating decoder handle...";
        FUNASR_DEC_HANDLE decoder_handle = FunASRWfstDecoderInit(asr_handle, ASR_OFFLINE, global_beam, lattice_beam, am_scale);
        if (decoder_handle == nullptr) {
            LOG(WARNING) << "Decoder handle is null, proceeding without it";
        } else {
            LOG(INFO) << "Decoder handle created successfully";
        }
        
        // Handle WAV file format - skip WAV header if present
        if (file.filename.find(".wav") != std::string::npos || wav_format == "wav") {
            // Skip WAV header (typically 44 bytes) to get PCM data
            if (audio_data.size() > 44) {
                // Simple WAV header check
                if (audio_data[0] == 'R' && audio_data[1] == 'I' && 
                    audio_data[2] == 'F' && audio_data[3] == 'F') {
                    LOG(INFO) << "Detected WAV file, extracting PCM data...";
                    // Find "data" chunk
                    size_t data_start = 44; // Default WAV header size
                    for (size_t i = 36; i < audio_data.size() - 8; i++) {
                        if (audio_data[i] == 'd' && audio_data[i+1] == 'a' && 
                            audio_data[i+2] == 't' && audio_data[i+3] == 'a') {
                            data_start = i + 8; // Skip "data" + size field
                            break;
                        }
                    }
                    audio_data.erase(audio_data.begin(), audio_data.begin() + data_start);
                    wav_format = "pcm"; // Now it's PCM data
                    LOG(INFO) << "Extracted PCM data size: " << audio_data.size();
                }
            }
        }
        
        // Perform ASR inference (same parameters as WebSocket)
        FUNASR_RESULT result = nullptr;
        LOG(INFO) << "Starting ASR inference...";
        LOG(INFO) << "  Audio data size: " << audio_data.size();
        LOG(INFO) << "  Audio format: " << wav_format;
        LOG(INFO) << "  Sample rate: " << audio_fs;
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
                nullptr,  // Try with nullptr for decoder_handle since it fails to create
                svs_lang, 
                svs_itn
            );
            LOG(INFO) << "ASR inference completed, result pointer: " << (result != nullptr ? "not null" : "null");
        } catch (const std::exception& e) {
            LOG(ERROR) << "ASR inference failed: " << e.what();
            res.status = 500;
            res.set_content("{\"error\":\"ASR inference failed\"}", "application/json");
            if (decoder_handle) {
                FunASRWfstDecoderUninit(decoder_handle);
            }
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
                
                LOG(INFO) << "Recognition result: " << (asr_result.empty() ? "(empty)" : asr_result);
                LOG(INFO) << "Response JSON: " << response.dump();
            } catch (const std::exception& e) {
                LOG(ERROR) << "Result processing failed: " << e.what();
                response["text"] = "";
                response["error"] = "Result processing failed";
            }
        } else {
            LOG(WARNING) << "ASR result is null";
            response["text"] = "";
            response["error"] = "Recognition failed";
            response["mode"] = "offline";
            response["is_final"] = true;
            response["wav_name"] = wav_name;
        }
        
        // Clean up decoder handle (currently not used)
        // if (decoder_handle) {
        //     FunASRWfstDecoderUninit(decoder_handle);
        // }
        
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
    
    // Set up single endpoint that clients use
    server->Post("/transcribe/normal", [this](const httplib::Request& req, httplib::Response& res) {
        handle_recognize(req, res);
    });
    
    // CORS preflight for main endpoint
    server->Options("/transcribe/normal", [](const httplib::Request& req, httplib::Response& res) {
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