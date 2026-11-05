import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/invoice_images.dart';
import '../data/models/purchase.dart';
import '../providers/party_provider.dart';

/// صورة فاتورة المورّد الأصلية داخل فاتورة الشراء: عرض مصغّر (ضغط = تكبير)،
/// واستبدال/حذف/إرفاق لاحقاً.
class PurchaseImageSection extends StatelessWidget {
  final PurchaseInvoice purchase;
  const PurchaseImageSection({super.key, required this.purchase});

  Future<void> _attach(BuildContext context) async {
    final parties = context.read<PartyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await InvoiceImages.pickAndStore();
      if (name == null) return;
      await parties.setPurchaseImage(purchase.id!, name);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّر إرفاق الصورة: $e')));
    }
  }

  Future<void> _remove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الصورة'),
        content: const Text('تُحذف صورة الفاتورة المؤرشفة من الجهاز. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<PartyProvider>().setPurchaseImage(purchase.id!, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = purchase.imagePath;
    if (name == null || name.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _attach(context),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('إرفاق صورة الفاتورة الورقية'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: FutureBuilder<File?>(
        future: InvoiceImages.resolve(name),
        builder: (ctx, snap) {
          final file = snap.data;
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
          }
          if (file == null) {
            return const Text('ملف الصورة غير موجود على هذا الجهاز',
                style: TextStyle(color: AppColors.warning));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('صورة فاتورة المورّد الأصلية',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InvoiceImageViewer(file: file)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file, height: 180, fit: BoxFit.cover),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _attach(context),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('استبدال'),
                  ),
                  TextButton.icon(
                    onPressed: () => _remove(context),
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    label: const Text('حذف', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// عرض الصورة بالحجم الكامل مع تكبير وتحريك.
class InvoiceImageViewer extends StatelessWidget {
  final File file;
  const InvoiceImageViewer({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('فاتورة المورّد'), backgroundColor: Colors.black),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 6,
        child: Center(child: Image.file(file)),
      ),
    );
  }
}
