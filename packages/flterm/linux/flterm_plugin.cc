#include "include/flterm/flterm_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk/gdk.h>
#include <gtk/gtk.h>

#define FLTERM_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flterm_plugin_get_type(), FltermPlugin))

namespace {

constexpr char kChannelName[] = "dev.flterm/native_keyboard";

enum ModBits {
  kShift = 1 << 0,
  kControl = 1 << 1,
  kAlt = 1 << 2,
  kSuper = 1 << 3,
  kCapsLock = 1 << 4,
  kNumLock = 1 << 5,
  kShiftSide = 1 << 6,
  kControlSide = 1 << 7,
  kAltSide = 1 << 8,
  kSuperSide = 1 << 9,
};

int64_t ModifiersFromGdk(guint state, bool level3_is_alt = false) {
  int64_t result = 0;
  if ((state & GDK_SHIFT_MASK) != 0) result |= kShift;
  if ((state & GDK_CONTROL_MASK) != 0) result |= kControl;
  if ((state & GDK_MOD1_MASK) != 0) result |= kAlt;
  if (level3_is_alt && (state & GDK_MOD5_MASK) != 0) result |= kAlt;
  if ((state & (GDK_SUPER_MASK | GDK_META_MASK)) != 0) result |= kSuper;
  if ((state & GDK_LOCK_MASK) != 0) result |= kCapsLock;
  if ((state & GDK_MOD2_MASK) != 0) result |= kNumLock;
  return result;
}

bool IsModifierKey(guint keyval) {
  switch (keyval) {
    case GDK_KEY_Shift_L:
    case GDK_KEY_Shift_R:
    case GDK_KEY_Control_L:
    case GDK_KEY_Control_R:
    case GDK_KEY_Alt_L:
    case GDK_KEY_Alt_R:
    case GDK_KEY_Meta_L:
    case GDK_KEY_Meta_R:
    case GDK_KEY_Super_L:
    case GDK_KEY_Super_R:
    case GDK_KEY_Hyper_L:
    case GDK_KEY_Hyper_R:
    case GDK_KEY_Caps_Lock:
    case GDK_KEY_Num_Lock:
    case GDK_KEY_ISO_Level3_Shift:
    case GDK_KEY_Mode_switch:
      return true;
    default:
      return false;
  }
}

bool IsDeadKey(guint keyval) {
  const gchar* name = gdk_keyval_name(keyval);
  return name != nullptr && g_str_has_prefix(name, "dead_");
}

void Set(FlValue* map, const char* key, FlValue* value) {
  fl_value_set_string_take(map, key, value);
}

}  // namespace

struct _FltermPlugin {
  GObject parent_instance;
  FlBasicMessageChannel* channel;
  FlView* view;
  gulong key_press_handler;
  gulong key_release_handler;
};

G_DEFINE_TYPE(FltermPlugin, flterm_plugin, g_object_get_type())

static gboolean SendKeyEvent(FltermPlugin* self,
                             GdkEventKey* event,
                             gboolean down) {
  if (IsModifierKey(event->keyval)) return FALSE;

  GdkKeymap* keymap = gdk_keymap_get_for_display(
      gtk_widget_get_display(GTK_WIDGET(self->view)));

  guint translated_keyval = 0;
  gint effective_group = 0;
  gint level = 0;
  GdkModifierType consumed = static_cast<GdkModifierType>(0);
  gdk_keymap_translate_keyboard_state(
      keymap, event->hardware_keycode,
      static_cast<GdkModifierType>(event->state), event->group,
      &translated_keyval, &effective_group, &level, &consumed);

  const GdkKeymapKey unshifted_key = {
      event->hardware_keycode,
      static_cast<gint>(event->group),
      0,
  };
  const guint unshifted_keyval = gdk_keymap_lookup_key(keymap, &unshifted_key);
  gunichar unshifted = gdk_keyval_to_unicode(unshifted_keyval);
  if (unshifted < 0x20 || unshifted == 0x7F) unshifted = 0;

  g_autoptr(FlValue) message = fl_value_new_map();
  Set(message, "platform", fl_value_new_string("linux"));
  Set(message, "scanCode", fl_value_new_int(event->hardware_keycode));
  Set(message, "keyCode", fl_value_new_int(event->keyval));
  Set(message, "down", fl_value_new_bool(down));
  Set(message, "eventTime", fl_value_new_int(event->time));
  Set(message, "mods",
      fl_value_new_int(ModifiersFromGdk(event->state, true)));
  Set(message, "consumedMods",
      fl_value_new_int(
          ModifiersFromGdk(consumed & event->state, true)));
  Set(message, "unshiftedCodepoint", fl_value_new_int(unshifted));
  Set(message, "textWithoutAlt", fl_value_new_null());
  Set(message, "deadKey",
      fl_value_new_bool(down && IsDeadKey(event->keyval)));
  fl_basic_message_channel_send(self->channel, message, nullptr, nullptr,
                                nullptr);
  return FALSE;
}

static gboolean KeyPressCallback(GtkWidget*,
                                 GdkEventKey* event,
                                 gpointer user_data) {
  return SendKeyEvent(FLTERM_PLUGIN(user_data), event, TRUE);
}

static gboolean KeyReleaseCallback(GtkWidget*,
                                   GdkEventKey* event,
                                   gpointer user_data) {
  return SendKeyEvent(FLTERM_PLUGIN(user_data), event, FALSE);
}

static void flterm_plugin_dispose(GObject* object) {
  FltermPlugin* self = FLTERM_PLUGIN(object);
  if (self->view != nullptr) {
    if (self->key_press_handler != 0) {
      g_signal_handler_disconnect(self->view, self->key_press_handler);
    }
    if (self->key_release_handler != 0) {
      g_signal_handler_disconnect(self->view, self->key_release_handler);
    }
    g_object_remove_weak_pointer(G_OBJECT(self->view),
                                 reinterpret_cast<gpointer*>(&self->view));
    self->view = nullptr;
  }
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(flterm_plugin_parent_class)->dispose(object);
}

static void flterm_plugin_class_init(FltermPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flterm_plugin_dispose;
}

static void flterm_plugin_init(FltermPlugin* self) {
  self->channel = nullptr;
  self->view = nullptr;
  self->key_press_handler = 0;
  self->key_release_handler = 0;
}

void flterm_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FltermPlugin* plugin = FLTERM_PLUGIN(
      g_object_new(flterm_plugin_get_type(), nullptr));
  g_autoptr(FlStandardMessageCodec) codec = fl_standard_message_codec_new();
  plugin->channel = fl_basic_message_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_MESSAGE_CODEC(codec));
  plugin->view = fl_plugin_registrar_get_view(registrar);
  if (plugin->view == nullptr) {
    g_object_unref(plugin);
    return;
  }
  g_object_add_weak_pointer(G_OBJECT(plugin->view),
                            reinterpret_cast<gpointer*>(&plugin->view));
  plugin->key_press_handler = g_signal_connect(
      plugin->view, "key-press-event", G_CALLBACK(KeyPressCallback), plugin);
  plugin->key_release_handler = g_signal_connect(
      plugin->view, "key-release-event", G_CALLBACK(KeyReleaseCallback), plugin);
  g_object_set_data_full(G_OBJECT(plugin->view), "dev.flterm.plugin", plugin,
                         g_object_unref);
}
