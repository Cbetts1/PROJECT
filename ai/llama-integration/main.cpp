// ai/llama-integration/main.cpp
// AIOS-Lite LLaMA Inference Wrapper
// © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
//
// Thin C++ wrapper around llama.cpp's C API for AIOS-Lite.
// Reads a prompt from stdin (or -p flag), runs inference, writes to stdout.
//
// Build (after cloning llama.cpp to build/llama.cpp/):
//   g++ -std=c++17 -O2 -o aios-llm ai/llama-integration/main.cpp \
//       -Ibuild/llama.cpp/include \
//       -Lbuild/llama.cpp/build/lib \
//       -lllama -lm -pthread
//
// Usage:
//   echo "What is the capital of France?" | ./aios-llm -m model.gguf
//   ./aios-llm -m model.gguf -p "Hello, world" -n 128 -t 0.7

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <cstring>
#include <cstdlib>
#include <csignal>
#include <vector>
#include <algorithm>

// ---------------------------------------------------------------------------
// Compile-time detection: include llama.h only if it can be found.
// When llama.cpp is not built yet, this file compiles as a stub.
// ---------------------------------------------------------------------------
#if defined(LLAMA_API)
#  include "llama.h"
#  define HAVE_LLAMA 1
#else
#  define HAVE_LLAMA 0
#endif

// ---------------------------------------------------------------------------
// Configuration (overridable via environment variables)
// ---------------------------------------------------------------------------
struct Config {
    std::string model_path;
    std::string prompt;
    int n_predict   = 256;
    float temp      = 0.7f;
    float top_p     = 0.9f;
    int top_k       = 40;
    float repeat_penalty = 1.1f;
    int n_ctx       = 2048;
    int n_threads   = 4;
    bool verbose    = false;
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
static void usage(const char* prog) {
    std::cerr << "AIOS-Lite LLaMA inference wrapper\n\n"
              << "Usage: " << prog << " [options]\n\n"
              << "Options:\n"
              << "  -m <model>   Path to .gguf model file (required)\n"
              << "  -p <prompt>  Prompt text (default: read from stdin)\n"
              << "  -n <int>     Max tokens to predict (default: 256)\n"
              << "  -t <float>   Temperature 0.0-2.0 (default: 0.7)\n"
              << "  --top-p <f>  Top-p sampling (default: 0.9)\n"
              << "  --top-k <i>  Top-k sampling (default: 40)\n"
              << "  --ctx <int>  Context window size (default: 2048)\n"
              << "  --threads <i> CPU threads (default: 4)\n"
              << "  -v           Verbose output\n"
              << "  -h           Show this help\n\n"
              << "Environment:\n"
              << "  LLAMA_MODEL   Override model path\n"
              << "  LLM_MAX_TOKENS Override max tokens\n"
              << "  LLM_TEMP      Override temperature\n"
              << "  LLM_THREADS   Override thread count\n\n"
              << "Stdin: if -p is not given, prompt is read from stdin.\n";
}

static std::string env_or(const char* name, const std::string& dflt) {
    const char* v = std::getenv(name);
    return v ? std::string(v) : dflt;
}

static int env_int(const char* name, int dflt) {
    const char* v = std::getenv(name);
    return v ? std::atoi(v) : dflt;
}

static float env_float(const char* name, float dflt) {
    const char* v = std::getenv(name);
    return v ? std::atof(v) : dflt;
}

static std::string read_stdin() {
    std::ostringstream ss;
    std::string line;
    while (std::getline(std::cin, line))
        ss << line << '\n';
    return ss.str();
}

// ---------------------------------------------------------------------------
// Argument parser
// ---------------------------------------------------------------------------
static Config parse_args(int argc, char** argv) {
    Config cfg;
    // Apply environment defaults
    cfg.model_path  = env_or("LLAMA_MODEL", "");
    cfg.n_predict   = env_int("LLM_MAX_TOKENS", 256);
    cfg.temp        = env_float("LLM_TEMP", 0.7f);
    cfg.n_threads   = env_int("LLM_THREADS", 4);

    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "-h" || a == "--help") { usage(argv[0]); std::exit(0); }
        else if ((a == "-m" || a == "--model")   && i+1 < argc) cfg.model_path = argv[++i];
        else if ((a == "-p" || a == "--prompt")  && i+1 < argc) cfg.prompt     = argv[++i];
        else if ((a == "-n" || a == "--n-predict")&& i+1 < argc) cfg.n_predict  = std::atoi(argv[++i]);
        else if ((a == "-t" || a == "--temp")    && i+1 < argc) cfg.temp       = std::atof(argv[++i]);
        else if (a == "--top-p"  && i+1 < argc) cfg.top_p        = std::atof(argv[++i]);
        else if (a == "--top-k"  && i+1 < argc) cfg.top_k        = std::atoi(argv[++i]);
        else if (a == "--ctx"    && i+1 < argc) cfg.n_ctx        = std::atoi(argv[++i]);
        else if (a == "--threads"&& i+1 < argc) cfg.n_threads    = std::atoi(argv[++i]);
        else if (a == "-v" || a == "--verbose") cfg.verbose = true;
        else {
            std::cerr << "Unknown argument: " << a << '\n';
            usage(argv[0]);
            std::exit(1);
        }
    }
    return cfg;
}

// ---------------------------------------------------------------------------
// Stub inference (when llama.cpp is not linked)
// ---------------------------------------------------------------------------
#if !HAVE_LLAMA
static int run_stub(const Config& cfg) {
    if (cfg.model_path.empty()) {
        std::cerr << "ERROR: No model specified (-m <model.gguf>)\n"
                  << "ERROR: This binary was compiled without llama.cpp.\n"
                  << "       Run: bash build/build.sh --target hosted\n"
                  << "       to build the full llama.cpp binary.\n";
        return 1;
    }
    const std::string prompt = cfg.prompt.empty() ? read_stdin() : cfg.prompt;
    std::cerr << "[aios-llm] Stub mode — llama.cpp not linked at compile time.\n"
              << "[aios-llm] Model: " << cfg.model_path << "\n"
              << "[aios-llm] Prompt: " << prompt.substr(0, 80) << "...\n"
              << "[aios-llm] To run inference: use llama-cli from build/llama.cpp/\n"
              << "[aios-llm] or rebuild with: g++ ... -lllama ...\n";
    // Echo prompt back as a placeholder so callers get non-empty output
    std::cout << "[stub] Prompt received (" << prompt.size() << " chars). "
              << "Build llama.cpp to enable real inference.\n";
    return 0;
}
#endif

// ---------------------------------------------------------------------------
// Real inference (when HAVE_LLAMA = 1)
// ---------------------------------------------------------------------------
#if HAVE_LLAMA
static volatile bool g_stop = false;
static void handle_sigint(int) { g_stop = true; }

static int run_llama(const Config& cfg) {
    if (cfg.model_path.empty()) {
        std::cerr << "ERROR: No model file specified. Use -m <model.gguf>\n";
        return 1;
    }

    std::string prompt = cfg.prompt.empty() ? read_stdin() : cfg.prompt;
    if (prompt.empty()) {
        std::cerr << "ERROR: Empty prompt.\n";
        return 1;
    }

    // Initialise llama backend
    llama_backend_init();

    // Load model
    llama_model_params mparams = llama_model_default_params();
    llama_model* model = llama_load_model_from_file(cfg.model_path.c_str(), mparams);
    if (!model) {
        std::cerr << "ERROR: Failed to load model: " << cfg.model_path << "\n";
        llama_backend_free();
        return 1;
    }

    // Create context
    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx      = static_cast<uint32_t>(cfg.n_ctx);
    cparams.n_threads  = static_cast<uint32_t>(cfg.n_threads);

    llama_context* ctx = llama_new_context_with_model(model, cparams);
    if (!ctx) {
        std::cerr << "ERROR: Failed to create llama context.\n";
        llama_free_model(model);
        llama_backend_free();
        return 1;
    }

    if (cfg.verbose) {
        std::cerr << "[aios-llm] Model loaded: " << cfg.model_path << "\n"
                  << "[aios-llm] Context: " << cfg.n_ctx << " tokens, "
                  << cfg.n_threads << " threads\n"
                  << "[aios-llm] Prompt length: " << prompt.size() << " chars\n";
    }

    // Tokenise prompt
    std::vector<llama_token> tokens(prompt.size() + 32);
    int n_tokens = llama_tokenize(model, prompt.c_str(),
                                  static_cast<int>(prompt.size()),
                                  tokens.data(),
                                  static_cast<int>(tokens.size()),
                                  /*add_special=*/true,
                                  /*parse_special=*/false);
    if (n_tokens < 0) {
        tokens.resize(-n_tokens);
        n_tokens = llama_tokenize(model, prompt.c_str(),
                                  static_cast<int>(prompt.size()),
                                  tokens.data(),
                                  static_cast<int>(tokens.size()),
                                  true, false);
    }
    tokens.resize(n_tokens);

    if (cfg.verbose)
        std::cerr << "[aios-llm] Tokens: " << n_tokens << "\n";

    // Decode prompt
    if (llama_decode(ctx, llama_batch_get_one(tokens.data(), n_tokens)) != 0) {
        std::cerr << "ERROR: llama_decode failed.\n";
        llama_free(ctx);
        llama_free_model(model);
        llama_backend_free();
        return 1;
    }

    // Sampling setup
    llama_sampler* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(cfg.top_k));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(cfg.top_p, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(cfg.temp));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(/*seed=*/42));

    signal(SIGINT, handle_sigint);

    // Generate tokens
    int n_gen = 0;
    while (n_gen < cfg.n_predict && !g_stop) {
        llama_token new_token = llama_sampler_sample(sampler, ctx, -1);

        if (new_token == llama_token_eos(model))
            break;

        char buf[256];
        int n = llama_token_to_piece(model, new_token, buf, sizeof(buf), 0, false);
        if (n > 0) {
            std::cout.write(buf, n);
            std::cout.flush();
        }

        // Decode next token
        llama_batch batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(ctx, batch) != 0)
            break;

        ++n_gen;
    }
    std::cout << '\n';

    if (cfg.verbose)
        std::cerr << "[aios-llm] Generated " << n_gen << " tokens.\n";

    llama_sampler_free(sampler);
    llama_free(ctx);
    llama_free_model(model);
    llama_backend_free();
    return 0;
}
#endif

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
int main(int argc, char** argv) {
    Config cfg = parse_args(argc, argv);

#if HAVE_LLAMA
    return run_llama(cfg);
#else
    return run_stub(cfg);
#endif
}
