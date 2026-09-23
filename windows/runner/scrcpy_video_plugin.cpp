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
        registrar->texture_registrar(), registrar->GetView()->GetNativeWindow());
    registrar->AddPlugin(std::move(plugin));
  }

  ScrcpyVideoPlugin(flutter::BinaryMessenger* messenger,
                    flutter::TextureRegistrar* textures, HWND view)
      : textures_(textures), view_(view) {
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
  struct WindowSearch {
    DWORD pid;
    HWND window = nullptr;
  };

  static BOOL CALLBACK FindMirrorWindow(HWND window, LPARAM parameter) {
    auto* search = reinterpret_cast<WindowSearch*>(parameter);
    DWORD pid = 0;
    GetWindowThreadProcessId(window, &pid);
    wchar_t name[64]{};
    GetClassNameW(window, name, 64);
    if (pid == search->pid && wcscmp(name, L"SDL_app") == 0) {
      search->window = window;
      return FALSE;
    }
    return TRUE;
  }

  void UpdateEmbeddedWindow(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    auto number = [args](const char* key) -> int {
      if (!args) return 0;
      const auto it = args->find(flutter::EncodableValue(key));
      if (it == args->end()) return 0;
      if (const auto* value = std::get_if<int32_t>(&it->second)) return *value;
      return 0;
    };
    const DWORD pid = static_cast<DWORD>(number("pid"));
    if (pid == 0) {
      result->Error("bad_args", "Mirror process ID required");
      return;
    }
    HWND window = embedded_windows_[pid];
    DWORD owner = 0;
    if (IsWindow(window)) GetWindowThreadProcessId(window, &owner);
    if (owner != pid) window = nullptr;
    if (call.method_name() == "hideEmbedded") {
      if (window) ShowWindowAsync(window, SW_HIDE);
      result->Success();
      return;
    }
    if (!window) {
      WindowSearch search{pid};
      EnumWindows(FindMirrorWindow, reinterpret_cast<LPARAM>(&search));
      window = search.window;
      if (!window) {
        embedded_windows_.erase(pid);
        result->Success(flutter::EncodableValue(false));
        return;
      }
      // Refuse a DPI mismatch instead of forcing a cross-process DPI reset.
      if (!AreDpiAwarenessContextsEqual(GetWindowDpiAwarenessContext(window),
                                       GetWindowDpiAwarenessContext(view_))) {
        ShowWindowAsync(window, SW_HIDE);
        result->Error("mirror_dpi_mismatch", "镜像窗口与主窗口的缩放模式不兼容。");
        return;
      }
      ShowWindow(window, SW_HIDE);
      const auto style = GetWindowLongPtr(window, GWL_STYLE);
      SetWindowLongPtr(window, GWL_STYLE,
          (style & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME)) | WS_CHILD);
      SetLastError(0);
      const HWND previous = SetParent(window, view_);
      if (!previous && GetLastError() != 0) {
        SetWindowLongPtr(window, GWL_STYLE, style);
        result->Error("mirror_embed_failed", "无法将镜像嵌入当前窗口。");
        return;
      }
      embedded_windows_[pid] = window;
    }
    // SDL can resize its own window on phone rotation. Reconcile the native
    // bounds even when Flutter's layout has not changed, without repainting
    // an already-correct window every timer tick.
    RECT bounds{};
    GetWindowRect(window, &bounds);
    MapWindowPoints(HWND_DESKTOP, view_, reinterpret_cast<POINT*>(&bounds), 2);
    if (bounds.left != number("x") || bounds.top != number("y") ||
        bounds.right - bounds.left != number("width") ||
        bounds.bottom - bounds.top != number("height")) {
      SetWindowPos(window, HWND_TOP, number("x"), number("y"),
                   number("width"), number("height"),
                   SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_ASYNCWINDOWPOS);
    }
    if (!IsWindowVisible(window)) ShowWindowAsync(window, SW_SHOWNOACTIVATE);
    result->Success(flutter::EncodableValue(true));
  }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "updateEmbedded" ||
        call.method_name() == "hideEmbedded") {
      UpdateEmbeddedWindow(call, std::move(result));
    } else if (call.method_name() == "create") {
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
  HWND view_;
  std::map<DWORD, HWND> embedded_windows_;
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
