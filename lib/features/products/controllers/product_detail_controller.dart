import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/products/controllers/products_controller.dart';
import 'package:ds_clickeat_web_admin/features/products/data/picked_image.dart';
import 'package:ds_clickeat_web_admin/features/products/data/products_repository.dart';
import 'package:ds_clickeat_web_admin/features/products/models/product_detail.dart';

/// Sentinel so [ProductDetailState.copyWith] can tell "argument omitted" apart
/// from "explicitly set to null" for nullable fields.
const Object _unset = Object();

class ProductDetailState {
  final bool loading;
  final String? error;
  final ProductDetail? detail;

  /// Premise the detail was loaded for; needed when uploading/saving.
  final int? premId;

  /// Index of the variant row currently open for inline editing, or `null`
  /// when no row is being edited.
  final int? editingIndex;

  /// `true` when [editingIndex] points to a freshly appended, not-yet-saved
  /// row (so cancelling discards it instead of restoring it).
  final bool addingNew;

  /// `true` while an image upload is in flight.
  final bool uploadingImage;

  /// One-shot message shown when an image upload is rejected/failed.
  final String? imageError;

  /// `true` while the product save is in flight.
  final bool saving;

  /// `true` when the panel is creating a new product (no `prod_id` yet) rather
  /// than editing an existing one. Switches the save call to `products/create`.
  final bool creating;

  /// Image picked while creating a product. It can't be uploaded yet (there is
  /// no `prod_id` until `products/create` returns one), so it's held here and
  /// uploaded right after creation. `null` when none is pending.
  final PickedImage? pendingImage;

  const ProductDetailState({
    this.loading = false,
    this.error,
    this.detail,
    this.premId,
    this.editingIndex,
    this.addingNew = false,
    this.uploadingImage = false,
    this.imageError,
    this.saving = false,
    this.creating = false,
    this.pendingImage,
  });

  ProductDetailState copyWith({
    bool? loading,
    ProductDetail? detail,
    int? premId,
    int? editingIndex,
    bool clearEditing = false,
    bool? addingNew,
    bool? uploadingImage,
    Object? imageError = _unset,
    bool? saving,
    bool? creating,
    Object? pendingImage = _unset,
  }) => ProductDetailState(
    loading: loading ?? this.loading,
    error: error,
    detail: detail ?? this.detail,
    premId: premId ?? this.premId,
    editingIndex: clearEditing ? null : (editingIndex ?? this.editingIndex),
    addingNew: clearEditing ? false : (addingNew ?? this.addingNew),
    uploadingImage: uploadingImage ?? this.uploadingImage,
    imageError: imageError == _unset ? this.imageError : imageError as String?,
    saving: saving ?? this.saving,
    creating: creating ?? this.creating,
    pendingImage: pendingImage == _unset
        ? this.pendingImage
        : pendingImage as PickedImage?,
  );
}

final productDetailControllerProvider =
    StateNotifierProvider<ProductDetailController, ProductDetailState>((ref) {
      return ProductDetailController(ref);
    });

class ProductDetailController extends StateNotifier<ProductDetailState> {
  ProductDetailController(this._ref) : super(const ProductDetailState());
  final Ref _ref;

  Future<void> load(int premId, int prodId) async {
    state = ProductDetailState(loading: true, premId: premId);
    try {
      final detail = await _ref
          .read(productsRepositoryProvider)
          .getDetail(premId, prodId);
      if (detail == null) {
        state = ProductDetailState(
          error: 'No se encontró el producto.',
          premId: premId,
        );
        return;
      }
      state = ProductDetailState(detail: detail, premId: premId);
    } catch (e) {
      state = ProductDetailState(error: e.toString(), premId: premId);
    }
  }

  /// Loads the premise catalogs and seeds a blank product for creation.
  Future<void> loadForCreate(int premId) async {
    state = ProductDetailState(loading: true, premId: premId, creating: true);
    try {
      final detail = await _ref
          .read(productsRepositoryProvider)
          .getMasterData(premId);
      if (detail == null) {
        state = ProductDetailState(
          error: 'No se pudieron cargar los catálogos.',
          premId: premId,
          creating: true,
        );
        return;
      }
      state = ProductDetailState(
        detail: detail,
        premId: premId,
        creating: true,
      );
    } catch (e) {
      state = ProductDetailState(
        error: e.toString(),
        premId: premId,
        creating: true,
      );
    }
  }

  // ---- Header field edits (in-memory) --------------------------------------

  void setName(String v) => _patch((d) => d.copyWith(prodName: v));
  void setDesc(String v) => _patch((d) => d.copyWith(prodDesc: v));
  void setAvailable(bool v) => _patch((d) => d.copyWith(prodAvailable: v));
  void setOrder(int v) => _patch((d) => d.copyWith(prodOrder: v));
  void setAdult(bool v) => _patch((d) => d.copyWith(prodAdult: v));
  void setCategory(int id) => _patch((d) => d.copyWith(prodCategoryId: id));
  void setPrepArea(int id) =>
      _patch((d) => d.copyWith(prodPreparationAreaId: id));

  void _patch(ProductDetail Function(ProductDetail) update) {
    final d = state.detail;
    if (d == null) return;
    state = state.copyWith(detail: update(d));
  }

  // ---- Image upload --------------------------------------------------------

  /// Uploads [bytes] (a .jpg) and swaps in the returned image URL. [filename]
  /// is validated to be a JPEG; anything else surfaces [imageError].
  Future<void> uploadImage(Uint8List bytes, String filename) async {
    final d = state.detail;
    final premId = state.premId;
    if (d == null || premId == null) return;

    final lower = filename.toLowerCase();
    if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) {
      state = state.copyWith(
        imageError: 'Solo se permiten imágenes .jpg',
      );
      return;
    }

    // Creating: there is no prod_id yet, so hold the image and show a local
    // preview. It is uploaded by [save] once `products/create` returns the id.
    if (state.creating) {
      state = state.copyWith(
        pendingImage: PickedImage(filename, bytes),
        imageError: null,
      );
      return;
    }

    state = state.copyWith(uploadingImage: true, imageError: null);
    try {
      final url = await _ref
          .read(productsRepositoryProvider)
          .uploadProductImage(
            premId: premId,
            prodId: d.prodId,
            bytes: bytes,
            filename: filename,
          );
      if (url != null && url.isNotEmpty) {
        state = state.copyWith(
          detail: d.copyWith(prodImageUrl: url),
          uploadingImage: false,
        );
      } else {
        state = state.copyWith(
          uploadingImage: false,
          imageError: 'No se pudo subir la imagen.',
        );
      }
    } catch (e) {
      state = state.copyWith(uploadingImage: false, imageError: e.toString());
    }
  }

  /// Clears the one-shot image error after it has been shown.
  void clearImageError() => state = state.copyWith(imageError: null);

  // ---- Save ----------------------------------------------------------------

  /// Persists the whole product and returns true on success.
  ///
  /// Editing posts to `products/update`. Creating posts to `products/create`,
  /// which returns the new `prod_id`; if an image was picked while creating, it
  /// is uploaded afterwards with that id. A failed image upload does not void a
  /// successful creation. On success the products list is refreshed.
  Future<bool> save() async {
    final d = state.detail;
    final premId = state.premId;
    if (d == null || premId == null) return false;

    state = state.copyWith(saving: true);
    try {
      final repo = _ref.read(productsRepositoryProvider);
      final bool ok;
      if (state.creating) {
        final prodId = await repo.createProduct(d.toCreateJson(premId));
        ok = prodId != null;
        final pending = state.pendingImage;
        if (prodId != null && pending != null) {
          try {
            await repo.uploadProductImage(
              premId: premId,
              prodId: prodId,
              bytes: pending.bytes,
              filename: pending.name,
            );
          } catch (_) {
            // Creation succeeded; the image can be set later by editing.
          }
        }
      } else {
        ok = await repo.saveProduct(d.toBackendJson(premId));
      }
      // Refresh the list behind the panel so it reflects the change without a
      // manual page reload.
      if (ok) {
        await _ref.read(productsControllerProvider.notifier).load(premId);
      }
      state = state.copyWith(saving: false);
      return ok;
    } catch (e) {
      state = state.copyWith(saving: false);
      return false;
    }
  }

  // ---- Inline variant editing ----------------------------------------------
  //
  // Edits/creations/deletions mutate the in-memory [ProductDetail] only. They
  // are NOT persisted yet — there is no backend write endpoint. Once one
  // exists, call it from [saveVariant] / [deleteVariant] and reconcile here.

  /// Opens an existing row for editing.
  void startEdit(int index) {
    if (state.editingIndex != null) return; // one row at a time
    state = state.copyWith(editingIndex: index, addingNew: false);
  }

  /// Appends a blank variant and opens it for editing.
  void startAdd() {
    final detail = state.detail;
    if (detail == null || state.editingIndex != null) return;
    final blank = const ProductVariant(
      prodsId: 0,
      prodsName: '',
      prodoId: 0,
      prodoName: '',
      prodPrice: '0.00',
      prodStock: 0,
      prodAvailable: true,
    );
    final variants = [...detail.variants, blank];
    state = state.copyWith(
      detail: detail.copyWith(variants: variants),
      editingIndex: variants.length - 1,
      addingNew: true,
    );
  }

  /// Discards the current edit. Removes the row if it was a new, unsaved one.
  void cancelEdit() {
    final detail = state.detail;
    final index = state.editingIndex;
    if (detail == null || index == null) return;
    if (state.addingNew) {
      final variants = [...detail.variants]..removeAt(index);
      state = state.copyWith(
        detail: detail.copyWith(variants: variants),
        clearEditing: true,
      );
    } else {
      state = state.copyWith(clearEditing: true);
    }
  }

  /// Commits the edited/new variant at [index] into the in-memory detail.
  void saveVariant(int index, ProductVariant updated) {
    final detail = state.detail;
    if (detail == null) return;
    final variants = [...detail.variants];
    if (index < 0 || index >= variants.length) return;
    variants[index] = updated;
    state = state.copyWith(
      detail: detail.copyWith(variants: variants),
      clearEditing: true,
    );
  }

  /// Removes the variant at [index].
  void deleteVariant(int index) {
    final detail = state.detail;
    if (detail == null) return;
    final variants = [...detail.variants];
    if (index < 0 || index >= variants.length) return;
    variants.removeAt(index);
    state = state.copyWith(
      detail: detail.copyWith(variants: variants),
      clearEditing: true,
    );
  }

  /// Returns true if [sizeId]×[optionId] already exists on another row.
  bool isDuplicate(int sizeId, int optionId, int exceptIndex) {
    final variants = state.detail?.variants ?? const [];
    for (var i = 0; i < variants.length; i++) {
      if (i == exceptIndex) continue;
      final v = variants[i];
      if (v.prodsId == sizeId && v.prodoId == optionId) return true;
    }
    return false;
  }

  // ---- Linked add-ons (product_additional_collect) -------------------------

  /// Links/unlinks an add-on product by [prodaId]. In-memory only for now.
  void toggleAdditional(int prodaId) {
    final detail = state.detail;
    if (detail == null) return;
    final linked = {...detail.linkedAdditionalIds};
    if (!linked.add(prodaId)) linked.remove(prodaId);
    state = state.copyWith(
      detail: detail.copyWith(linkedAdditionalIds: linked),
    );
  }

  /// Resets the state when the panel is closed.
  void clear() {
    state = const ProductDetailState();
  }
}
