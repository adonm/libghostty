import '../../types/types.dart';

abstract interface class SystemBindings {
  void sysClearLogCallback();
  void sysClearPngDecoder();
  void sysSetLogCallback(SysLogCallback callback);
  void sysSetLogToStderr();
  void sysSetPngDecoder(PngDecoder decoder);
}
