#include "scrcpy_video_plugin.h"

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <atomic>
#include <cstdint>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <vector>

#include "scrcpy_video_decoder.h"

namespace {

// One decoded scrcpy stream surfaced as a Flutter pixel-buffer texture.
class WinTextureSession {
 public:
  WinTextureSession() = default;

  bool Init(flutter::TextureRegistrar* textures) {
    textures_ = textures;
    texture_ = std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
        [this](size_t width, size_t height) { return CopyPixelBuffer(); }));
    texture_id_ = textures_->RegisterTexture(texture_.get());
    if (texture_id_ < 0) {
      texture_.reset();
      return false;
    }

    auto decoder = std::make_shared<ScrcpyVideoDecoder>([this]() {
      std::lock_guard<std::mutex> lock(frame_notification_mutex_);
      if (!stopping_.load(std::memory_order_acquire)) {
        textures_->MarkTextureFrameAvailable(texture_id_);
      }
    });
    {
      std::lock_guard<std::mutex> lock(decoder_mutex_);
      decoder_ = std::move(decoder);
    }
    return true;
  }

  ~WinTextureSession() {
    Stop();
  }

  int64_t texture_id() const { return texture_id_; }

  // Stop publishing first, then join the decoder outside the ownership lock.
  // Flutter may still call CopyPixelBuffer until UnregisterTexture completes,
  // so the session and its pixel buffer must outlive that callback.
  void Stop() {
    {
      std::lock_guard<std::mutex> lock(frame_notification_mutex_);
      if (stopping_.exchange(true, std::memory_order_acq_rel)) return;
    }
    std::shared_ptr<ScrcpyVideoDecoder> decoder;
    {
      std::lock_guard<std::mutex> lock(decoder_mutex_);
      decoder = std::move(decoder_);
    }
    decoder.reset();
  }

  void Feed(const uint8_t* data, size_t size) {
    if (stopping_.load(std::memory_order_acquire)) return;
    std::shared_ptr<ScrcpyVideoDecoder> decoder;
    {
      std::lock_guard<std::mutex> lock(decoder_mutex_);
      decoder = decoder_;
    }
    if (decoder) decoder->Feed(data, size);
  }

 private:
  const FlutterDesktopPixelBuffer* CopyPixelBuffer() {
    std::shared_ptr<ScrcpyVideoDecoder> decoder;
    {
      std::lock_guard<std::mutex> lock(decoder_mutex_);
      decoder = decoder_;
    }
    int w = 0;
    int h = 0;
    if (!decoder || !decoder->CopyLatestFrame(&pixel_data_, &w, &h)) {
      return nullptr;
    }
    pixel_buffer_.buffer = pixel_data_.data();
    pixel_buffer_.width = static_cast<size_t>(w);
    pixel_buffer_.height = static_cast<size_t>(h);
    pixel_buffer_.release_context = nullptr;
    pixel_buffer_.release_callback = nullptr;
    return &pixel_buffer_;
  }

  flutter::TextureRegistrar* textures_ = nullptr;
  std::unique_ptr<flutter::TextureVariant> texture_;
  std::mutex frame_notification_mutex_;
  std::mutex decoder_mutex_;
  std::shared_ptr<ScrcpyVideoDecoder> decoder_;
  std::atomic<bool> stopping_{false};
  int64_t texture_id_ = -1;

  // Returned to the engine on the raster thread; the engine reads it
  // synchronously within the copy callback, so a single buffer is safe.
  FlutterDesktopPixelBuffer pixel_buffer_{};
  std::vector<uint8_t> pixel_data_;
};

class ScrcpyVideoPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<ScrcpyVideoPlugin>(registrar->messenger(),
                                                      registrar->texture_registrar());
    registrar->AddPlugin(std::move(plugin));
  }

  ScrcpyVideoPlugin(flutter::BinaryMessenger* messenger,
                    flutter::TextureRegistrar* textures)
      : textures_(textures) {
    method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, "flutter_scrcpy/video", &flutter::StandardMethodCodec::GetInstance());
    method_channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
          HandleMethodCall(call, std::move(result));
        });

    messenger->SetMessageHandler(
        "flutter_scrcpy/video/feed",
        [this](const uint8_t* message, size_t size, flutter::BinaryReply reply) {
          HandleFeed(message, size);
          reply(nullptr, 0);
        });
  }

  ~ScrcpyVideoPlugin() override = default;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "create") {
      auto session = std::make_shared<WinTextureSession>();
      if (!session->Init(textures_)) {
        result->Error("texture_register_failed",
                      "Unable to register the Windows mirror texture");
        return;
      }
      const int64_t id = session->texture_id();
      {
        std::lock_guard<std::mutex> lock(sessions_mutex_);
        sessions_[id] = std::move(session);
      }
      result->Success(flutter::EncodableValue(id));
    } else if (call.method_name() == "dispose") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args == nullptr) {
        result->Error("bad_args", "textureId required");
        return;
      }
      const auto it = args->find(flutter::EncodableValue("textureId"));
      if (it == args->end()) {
        result->Error("bad_args", "textureId required");
        return;
      }
      int64_t id = 0;
      if (const auto* i64 = std::get_if<int64_t>(&it->second)) {
        id = *i64;
      } else if (const auto* i32 = std::get_if<int32_t>(&it->second)) {
        id = *i32;
      }
      std::shared_ptr<WinTextureSession> session;
      {
        std::lock_guard<std::mutex> lock(sessions_mutex_);
        const auto session_it = sessions_.find(id);
        if (session_it != sessions_.end()) {
          session = session_it->second;
          sessions_.erase(session_it);
        }
      }
      if (session) {
        session->Stop();
        textures_->UnregisterTexture(
            id, [session = std::move(session)]() mutable { session.reset(); });
      }
      result->Success();
    } else {
      result->NotImplemented();
    }
  }

  void HandleFeed(const uint8_t* message, size_t size) {
    if (message == nullptr || size <= 8) return;
    int64_t id = 0;
    std::memcpy(&id, message, sizeof(int64_t));  // Dart writes little-endian; Windows is LE
    std::lock_guard<std::mutex> lock(sessions_mutex_);
    const auto it = sessions_.find(id);
    if (it != sessions_.end()) {
      it->second->Feed(message + 8, size - 8);
    }
  }

  flutter::TextureRegistrar* textures_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::mutex sessions_mutex_;
  std::map<int64_t, std::shared_ptr<WinTextureSession>> sessions_;
};

}  // namespace

void RegisterScrcpyVideoPlugin(flutter::FlutterEngine* engine) {
  ScrcpyVideoPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(
              engine->GetRegistrarForPlugin("ScrcpyVideoPlugin")));
}
