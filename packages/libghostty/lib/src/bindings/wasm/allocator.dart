import '../../generated/libghostty_wasm.g.dart';

// The Wasm allocator guarantees byte-addressable storage, not a C struct's
// alignment. Keep the original allocation span only for the rare case where
// an aligned interior pointer is returned; the normal path remains a direct
// allocation with no bookkeeping.
final _alignedU8Allocations = <int, (int pointer, int length)>{};

extension WasmAllocation on GhosttyExports {
  int allocateOpaque() => ghostty_wasm_alloc_opaque();

  void freeOpaque(int pointer) => ghostty_wasm_free_opaque(pointer);

  int allocateSgrAttribute() => ghostty_wasm_alloc_sgr_attribute();

  void freeSgrAttribute(int pointer) =>
      ghostty_wasm_free_sgr_attribute(pointer);

  int allocateU8() => ghostty_wasm_alloc_u8();

  void freeU8(int pointer) => ghostty_wasm_free_u8(pointer);

  int allocateU8Array(int length) => ghostty_wasm_alloc_u8_array(length);

  int allocateAlignedU8Array(int length, {required int alignment}) {
    if (alignment <= 0 || alignment & (alignment - 1) != 0) {
      throw ArgumentError.value(alignment, 'alignment');
    }
    final pointer = allocateU8Array(length);
    if (pointer == 0 || alignment == 1 || pointer % alignment == 0) {
      return pointer;
    }
    freeU8Array(pointer, length);
    final spanLength = length + alignment - 1;
    final base = allocateU8Array(spanLength);
    if (base == 0) return 0;
    final aligned = (base + alignment - 1) & -alignment;
    _alignedU8Allocations[aligned] = (base, spanLength);
    return aligned;
  }

  void freeU8Array(int pointer, int length) {
    final allocation = _alignedU8Allocations.remove(pointer);
    if (allocation != null) {
      ghostty_wasm_free_u8_array(allocation.$1, allocation.$2);
      return;
    }
    ghostty_wasm_free_u8_array(pointer, length);
  }

  int allocateU16Array(int length) => ghostty_wasm_alloc_u16_array(length);

  void freeU16Array(int pointer, int length) =>
      ghostty_wasm_free_u16_array(pointer, length);

  int allocateUsize() => ghostty_wasm_alloc_usize();

  void freeUsize(int pointer) => ghostty_wasm_free_usize(pointer);

  int allocate(int allocator, int length) => ghostty_alloc(allocator, length);

  void free(int allocator, int pointer, int length) =>
      ghostty_free(allocator, pointer, length);
}
