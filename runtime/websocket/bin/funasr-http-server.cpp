/**
 * Copyright FunASR (https://github.com/alibaba-damo-academy/FunASR). All Rights
 * Reserved. MIT License  (https://opensource.org/licenses/MIT)
 */

// Main executable for HTTP ASR server

#include "http-server.h"
#include <signal.h>
#include <memory>

std::unique_ptr<HttpAsrServer> g_server;

void signal_handler(int signal) {
    LOG(INFO) << "Received signal " << signal << ", shutting down...";
    if (g_server) {
        g_server->Stop();
    }
    exit(0);
}

int main(int argc, char* argv[]) {
    google::InitGoogleLogging(argv[0]);
    FLAGS_logtostderr = 1;
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    try {
        TCLAP::CmdLine cmd("FunASR HTTP Server", ' ', "1.0");
        
        TCLAP::ValueArg<std::string> model_dir_arg(
            "", "model-dir", "Path to the ASR model directory", true, "", "string");
        cmd.add(model_dir_arg);
        
        TCLAP::ValueArg<std::string> vad_dir_arg(
            "", "vad-dir", "Path to the VAD model directory", false, "", "string");
        cmd.add(vad_dir_arg);
        
        TCLAP::ValueArg<std::string> vad_quant_arg(
            "", "vad-quant", "Path to the quantized VAD model", false, "", "string");
        cmd.add(vad_quant_arg);
        
        TCLAP::ValueArg<std::string> punc_dir_arg(
            "", "punc-dir", "Path to the punctuation model directory", false, "", "string");
        cmd.add(punc_dir_arg);
        
        TCLAP::ValueArg<std::string> punc_quant_arg(
            "", "punc-quant", "Path to the quantized punctuation model", false, "", "string");
        cmd.add(punc_quant_arg);
        
        TCLAP::ValueArg<std::string> itn_tagger_arg(
            "", "itn-tagger", "Path to ITN tagger FST", false, "", "string");
        cmd.add(itn_tagger_arg);
        
        TCLAP::ValueArg<std::string> itn_verbalizer_arg(
            "", "itn-verbalizer", "Path to ITN verbalizer FST", false, "", "string");
        cmd.add(itn_verbalizer_arg);
        
        TCLAP::ValueArg<std::string> host_arg(
            "", "host", "Server host address", false, "0.0.0.0", "string");
        cmd.add(host_arg);
        
        TCLAP::ValueArg<int> port_arg(
            "", "port", "Server port", false, 10095, "int");
        cmd.add(port_arg);
        
        TCLAP::ValueArg<int> thread_num_arg(
            "", "thread-num", "Number of threads", false, 8, "int");
        cmd.add(thread_num_arg);
        
        cmd.parse(argc, argv);
        
        // Create and initialize server
        g_server = std::make_unique<HttpAsrServer>();
        
        g_server->InitAsr(
            model_dir_arg.getValue(),
            vad_dir_arg.getValue(),
            vad_quant_arg.getValue(),
            punc_dir_arg.getValue(),
            punc_quant_arg.getValue(),
            itn_tagger_arg.getValue(),
            itn_verbalizer_arg.getValue(),
            thread_num_arg.getValue()
        );
        
        LOG(INFO) << "FunASR HTTP Server starting...";
        LOG(INFO) << "Model directory: " << model_dir_arg.getValue();
        LOG(INFO) << "Listening on: " << host_arg.getValue() << ":" << port_arg.getValue();
        
        // Start server (this blocks)
        g_server->Start(host_arg.getValue(), port_arg.getValue());
        
    } catch (const TCLAP::ArgException& e) {
        LOG(ERROR) << "Command line argument error: " << e.error() << " for arg " << e.argId();
        return -1;
    } catch (const std::exception& e) {
        LOG(ERROR) << "Error: " << e.what();
        return -1;
    }
    
    return 0;
}