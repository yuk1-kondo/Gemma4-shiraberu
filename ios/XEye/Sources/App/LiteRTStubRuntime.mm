#include <cstdlib>
#include <cstring>
#include <sstream>
#include <string>

namespace {
struct StubEngine {
    std::string modelPath;
};

char *makeCString(const std::string &value) {
    size_t size = value.size() + 1;
    char *buffer = static_cast<char *>(std::malloc(size));
    if (!buffer) {
        return nullptr;
    }
    std::memcpy(buffer, value.c_str(), size);
    return buffer;
}

void setError(char **outError, const std::string &message) {
    if (!outError) {
        return;
    }
    *outError = makeCString(message);
}
} // namespace

extern "C" __attribute__((visibility("default"))) int
litertlm_create(const char *model_path, void **out_engine, char **out_error) {
    if (!model_path || std::strlen(model_path) == 0) {
        setError(out_error, "stub create failed: model_path is empty");
        return 1;
    }
    if (!out_engine) {
        setError(out_error, "stub create failed: out_engine is null");
        return 1;
    }

    auto *engine = new StubEngine();
    engine->modelPath = model_path;
    *out_engine = engine;
    return 0;
}

extern "C" __attribute__((visibility("default"))) int
litertlm_infer_rgba(void *engine,
                    const uint8_t *rgba,
                    int width,
                    int height,
                    int bytes_per_row,
                    const char *prompt,
                    char **out_text,
                    char **out_error) {
    if (!engine) {
        setError(out_error, "stub infer failed: engine is null");
        return 1;
    }
    if (!rgba || width <= 0 || height <= 0 || bytes_per_row <= 0) {
        setError(out_error, "stub infer failed: invalid image input");
        return 1;
    }
    if (!out_text) {
        setError(out_error, "stub infer failed: out_text is null");
        return 1;
    }

    auto *stub = static_cast<StubEngine *>(engine);

    std::ostringstream ss;
    ss << "光る石板が おかれている！\n";
    ss << "なんと…！ LiteRT開発スタブが反応した。\n";
    ss << "入力: " << width << "x" << height << ", row=" << bytes_per_row << "\n";
    if (prompt && std::strlen(prompt) > 0) {
        ss << "詠唱: " << std::string(prompt).substr(0, 48);
    } else {
        ss << "詠唱: (なし)";
    }
    ss << " / model=" << stub->modelPath;

    *out_text = makeCString(ss.str());
    if (!*out_text) {
        setError(out_error, "stub infer failed: memory allocation");
        return 1;
    }
    return 0;
}

extern "C" __attribute__((visibility("default"))) void
litertlm_destroy(void *engine) {
    auto *stub = static_cast<StubEngine *>(engine);
    delete stub;
}

extern "C" __attribute__((visibility("default"))) void
litertlm_free_string(char *value) {
    std::free(value);
}
