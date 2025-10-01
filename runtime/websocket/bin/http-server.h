/**
 * Copyright FunASR (https://github.com/alibaba-damo-academy/FunASR). All Rights
 * Reserved. MIT License  (https://opensource.org/licenses/MIT)
 */

// HTTP server for ASR engine
// Simplified version for one-shot audio recognition

#ifndef HTTP_SERVER_H_
#define HTTP_SERVER_H_

#include <iostream>
#include <memory>
#include <string>
#include <vector>
#include <thread>

#include <glog/logging.h>
#include "funasrruntime.h"
#include "nlohmann/json.hpp"
#include "tclap/CmdLine.h"
#include "com-define.h"

// Fix macOS compatibility issues
#ifdef __APPLE__
#define CPPHTTPLIB_OPENSSL_SUPPORT
#endif

// Simple HTTP server implementation
#include "httplib.h"

class HttpAsrServer {
private:
    FUNASR_HANDLE asr_handle = nullptr;
    std::unique_ptr<httplib::Server> server;
    
    // Model paths
    std::string model_dir;
    std::string vad_dir;
    std::string vad_quant_dir;
    std::string punc_dir;
    std::string punc_quant_dir;
    std::string itn_tagger_fst_dir;
    std::string itn_verbalizer_fst_dir;
    
    // Configuration
    int thread_num = 8;
    int decoder_thread_num = 8;
    
    
    // Handle recognition request
    void handle_recognize(const httplib::Request& req, httplib::Response& res);
    
public:
    HttpAsrServer() : server(std::make_unique<httplib::Server>()) {}
    ~HttpAsrServer();
    
    // Initialize ASR models
    void InitAsr(const std::string& model_dir, 
                 const std::string& vad_dir,
                 const std::string& vad_quant_dir, 
                 const std::string& punc_dir,
                 const std::string& punc_quant_dir,
                 const std::string& itn_tagger_fst_dir,
                 const std::string& itn_verbalizer_fst_dir,
                 int thread_num);
    
    // Start HTTP server
    void Start(const std::string& host, int port);
    
    // Stop server
    void Stop();
};

#endif // HTTP_SERVER_H_