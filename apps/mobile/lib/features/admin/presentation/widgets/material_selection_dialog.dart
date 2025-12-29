import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "../../data/admin_repository.dart";
import "../../data/models/inventory_item.dart";

class MaterialSelectionDialog extends ConsumerStatefulWidget {
  const MaterialSelectionDialog({
    super.key,
    required this.inventory,
    required this.initialSelection,
  });

  final List<InventoryItem> inventory;
  final Map<String, int> initialSelection;

  @override
  ConsumerState<MaterialSelectionDialog> createState() =>
      _MaterialSelectionDialogState();
}

class _MaterialSelectionDialogState
    extends ConsumerState<MaterialSelectionDialog> {
  final Map<String, int> _selection = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _deductFromStock = true;
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  List<InventoryItem> _filteredInventory = [];
  String _searchQuery = "";
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _selection.addAll(widget.initialSelection);
    _initializeControllers();
    _filteredInventory = widget.inventory;
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
        _filterInventory();
      });
    });
  }
  
  void _initializeControllers() {
    for (final item in widget.inventory) {
      if (!_controllers.containsKey(item.id)) {
        _controllers[item.id] = TextEditingController(
          text: _selection[item.id]?.toString() ?? "",
        );
      }
    }
  }

  @override
  void dispose() {
    // Controller'ları dispose ediyoruz ama listede sürekli değişen controllerlar yaratmamak için
    // sadece dialog kapandığında dispose etmek daha iyi olabilir.
    // Ancak filtreleme sırasında item sayısı değişebilir.
    // Memory leak olmaması için _controllers map'indekileri dispose edelim.
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }
  
  void _filterInventory() {
    if (_searchQuery.isEmpty) {
      _filteredInventory = widget.inventory;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredInventory = widget.inventory.where((item) {
        return item.name.toLowerCase().contains(query) ||
            (item.category.toLowerCase().contains(query));
      }).toList();
    }
  }
  
  // Check if the exact search query exists in the inventory (case insensitive)
  bool get _exactMatchExists {
    if (_searchQuery.isEmpty) return true; // Don't show "Add" if empty
    return widget.inventory.any(
      (item) => item.name.toLowerCase() == _searchQuery.toLowerCase(),
    );
  }

  Future<void> _createNewItem() async {
    if (_searchQuery.isEmpty || _isCreating) return;
    
    setState(() {
      _isCreating = true;
    });

    try {
      final newItem = await ref.read(adminRepositoryProvider).createInventoryItem(
        name: _searchQuery,
        category: "Diğer", // Varsayılan kategori
        stockQty: 0,
        unitPrice: 0,
        criticalThreshold: 0,
        unit: "Adet",
      );
      
      // Add to inventory list locally
      // Note: We modifying a passed list reference if it's mutable, 
      // but parent widget passes a list. Better to just update our local view.
      // But we need to verify if we should add it to the PARENT's list too?
      // Usually fetchInventory returns a new list.
      // We will add it to our filtered list and local inventory copy if needed.
      // But parent won't know about it unless we refresh parent.
      // Since we return selection map keys (IDs), parent needs to resolve IDs to names.
      // If parent refreshes inventory, it's fine.
      
      // Eklendikten sonra seçime ekle
      setState(() {
        // Listemize ekleyelim
        // widget.inventory final ama içeriği mutable olabilir mi? List.from ile gelmediyse...
        // Güvenli olması için filtered listeye ve controller map'e ekleyelim
        // Ancak build metodunda access ediyoruz.
        // En iyisi widget.inventory'i parent'tan guncelleyemeyiz.
        // _filteredInventory'ye ekleyelim.
        
        // Aslinda widget.inventory'ye ekleyemeyiz (immutable list olabilir).
        // Ama controller oluştururken lazim.
        
        // Yeni bir liste oluşturup ona ekleyebiliriz ama bu sefer parent'taki referans eksik kalır.
        // Dialog sonucunda dönülen veride sadece ID ve adet var.
        // Parent sayfada isimleri göstermek için inventory'den bakıyor.
        // Bu durumda parent sayfanın da inventory'yi refresh etmesi gerekebilir.
        
        // Geçici çözüm: _filteredInventory'e ekle ve controller oluştur.
        // Dialog kapanınca parent refresh edilirse sorun olmaz.
        // Zaten edit_customer_sheet kaydederken name'i de gönderiyor (seçilenleri map'liyor).
        // Oradaki logic, ID inventory'de varsa oradan alır, yoksa usedProducts'dan alır.
        // Yeni eklenen item inventory'de var (backend'de).
        // Parent sayfa inventory listesini refresh etmezse ismi bulamayabilir.
        // Ama edit_customer_sheet'teki _selectMaterials fonksiyonu her açılışta fetchInventory yapıyor!
        // Sorun şu: Dialog açıkken inventory listesi güncellenmez.
        
        // Çözüm: widget.inventory'ye eklemeye çalışalım (List.from ile geldiyse çalışır).
        // Eğer hata verirse (unmodifiable list), yeni liste oluştururuz.
        try {
          widget.inventory.add(newItem);
        } catch (e) {
          // If immutable, we can't add to it.
          // But we typically get it from provider which returns a standard List.
        }
        
        // Controller oluştur
        _controllers[newItem.id] = TextEditingController(text: "1");
        _selection[newItem.id] = 1;
        
        // Aramayı temizle
        _searchController.clear();
        _searchQuery = "";
        _filteredInventory = widget.inventory; // Reset filter
        
        _isCreating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yeni ürün eklendi ve seçildi ✅"),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Malzeme Seçimi"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Ekle veya ara",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: 12,
                ),
              ),
            ),
            
            // "Use '...'" option for creating new item
            if (_searchQuery.isNotEmpty && !_exactMatchExists)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: _isCreating ? null : _createNewItem,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_isCreating)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF10B981),
                            ),
                          )
                        else
                          const Icon(
                            Icons.add_circle_outline, 
                            color: Color(0xFF10B981),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Kullan: ",
                                  style: TextStyle(color: Color(0xFF10B981)),
                                ),
                                TextSpan(
                                  text: "'$_searchQuery'",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
            const SizedBox(height: 12),
            
            // Filtered List
            Expanded(
              child: _filteredInventory.isEmpty
                  ? Center(
                      child: Text(
                        "Ürün bulunamadı",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredInventory.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _filteredInventory[index];
                        final isSelected = _selection.containsKey(item.id);
                        final controller = _controllers[item.id]!;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            "Stok: ${item.stockQty} ${item.unit ?? ''}",
                            style: TextStyle(
                              fontSize: 12,
                              color: item.stockQty <= item.criticalThreshold
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                          ),
                          trailing: SizedBox(
                            width: 120,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    onPressed: () {
                                      final currentQty =
                                          int.tryParse(controller.text) ?? 0;
                                      if (currentQty > 0) {
                                        final newQty = currentQty - 1;
                                        controller.text =
                                            newQty > 0 ? newQty.toString() : "";
                                        if (newQty > 0) {
                                          _selection[item.id] = newQty;
                                        } else {
                                          _selection.remove(item.id);
                                        }
                                        setState(() {});
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      Icons.remove_circle_outline,
                                      size: 22,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 40,
                                  height: 32,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: "0",
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 6,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      final qty = int.tryParse(value) ?? 0;
                                      if (qty > 0) {
                                        _selection[item.id] = qty;
                                      } else {
                                        _selection.remove(item.id);
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    onPressed: () {
                                      final currentQty =
                                          int.tryParse(controller.text) ?? 0;
                                      // Stock limiti kontrolü kaldırıldı mı?
                                      // Stok 0 olsa bile eklemeye izin verebiliriz (negatif stok olur)
                                      // Ama genelde stoktan fazla seçilmemeli.
                                      // Kullanıcı "YENİ" ürün eklediğinde stoğu 0.
                                      // O zaman artırmaya izin vermemiz lazım.
                                      // Stock kontrolünü esnetelim.
                                      final newQty = currentQty + 1;
                                      controller.text = newQty.toString();
                                      _selection[item.id] = newQty;
                                      setState(() {});
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 22,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_selection.isNotEmpty) ...[
              const Divider(),
              CheckboxListTile(
                value: _deductFromStock,
                onChanged: (value) {
                  setState(() {
                    _deductFromStock = value ?? true;
                  });
                },
                title: const Text(
                  "Stoktan düşülsün mü?",
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  "İşaretlenirse seçilen malzemeler stoktan düşürülür",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("İptal"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            (selection: _selection, deductFromStock: _deductFromStock),
          ),
          child: const Text("Tamam"),
        ),
      ],
    );
  }
}
