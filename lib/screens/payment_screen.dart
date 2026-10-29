import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'booking_list_screen.dart';

/// ชำระเงิน: สแกน PromptPay QR (ยอดถูกใส่ให้อัตโนมัติ) หรือโอนเข้าบัญชี แล้วแนบสลิป
/// แอดมินตรวจสลิปแล้วกดยืนยันการจอง ลูกค้าจะได้รับการแจ้งเตือน
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.hotelName, required this.total, this.bookingCode});

  final String hotelName;
  final int total;
  final String? bookingCode;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String method = 'promptpay'; // promptpay | bank
  Future<Map<String, dynamic>>? _info;

  XFile? _slip;
  Uint8List? _slipBytes;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.bookingCode != null) _info = ApiService.getPaymentInfo(widget.bookingCode!);
  }

  Future<void> _pickSlip() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _slip = picked;
        _slipBytes = bytes;
      });
    } catch (e) {
      _toast('เลือกรูปไม่สำเร็จ: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_slip == null) return _toast('กรุณาแนบสลิปการโอนเงินก่อน');
    setState(() => _sending = true);
    try {
      await ApiService.submitPayment(bookingCode: widget.bookingCode!, method: method, slip: _slip!);
      if (!mounted) return;
      _toast('ส่งสลิปเรียบร้อย รอเจ้าหน้าที่ตรวจสอบและยืนยัน');
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BookingListScreen()), (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _qrCard(Map<String, dynamic> info) {
    final payload = info['promptpayPayload']?.toString();
    if (payload == null || payload.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('ร้านยังไม่ได้ตั้งค่า PromptPay กรุณาเลือก "โอนเข้าบัญชี" หรือติดต่อทีมงาน', style: TextStyle(color: AppColors.textSoft)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border, width: 2)),
              child: QrImageView(data: payload, size: 210, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 12),
            Text('สแกนเพื่อชำระ ${widget.total}฿', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('เปิดแอปธนาคารแล้วสแกน QR นี้ ยอดเงินถูกกรอกให้อัตโนมัติ', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _bankCard(Map<String, dynamic> info) {
    final bank = Map<String, dynamic>.from(info['bank'] ?? {});
    final no = (bank['accountNo'] ?? '').toString();
    if (no.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('ร้านยังไม่ได้ตั้งค่าบัญชีธนาคาร กรุณาติดต่อทีมงาน', style: TextStyle(color: AppColors.textSoft)),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          ListTile(leading: const Icon(Icons.account_balance_rounded, color: AppColors.primary), title: const Text('ธนาคาร'), subtitle: Text('${bank['name']}')),
          ListTile(
            leading: const Icon(Icons.numbers_rounded, color: AppColors.primary),
            title: const Text('เลขที่บัญชี'),
            subtitle: Text(no),
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: no));
                _toast('คัดลอกเลขบัญชีแล้ว');
              },
            ),
          ),
          ListTile(leading: const Icon(Icons.person_outline_rounded, color: AppColors.primary), title: const Text('ชื่อบัญชี'), subtitle: Text('${bank['accountName']}')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ชำระเงิน')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            const AppSectionTitle(title: 'ชำระเงิน', subtitle: 'โอนเงินแล้วแนบสลิป เพื่อให้เจ้าหน้าที่ยืนยันการจอง'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.coralLight]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ยอดชำระทั้งหมด (ค่ามัดจำ)', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('${widget.total}฿', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(widget.hotelName, style: const TextStyle(color: Color(0xFFE7EEFF), fontSize: 13)),
                  if (widget.bookingCode != null) ...[
                    const SizedBox(height: 2),
                    Text('รหัสการจอง: ${widget.bookingCode}', style: const TextStyle(color: Color(0xFFE7EEFF), fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('* หากยกเลิกการจองหลังชำระค่ามัดจำ จะไม่สามารถคืนได้', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
            const Text('  กรุณาชำระและส่งสลิปภายใน 24 ชั่วโมง มิฉะนั้นระบบจะยกเลิกการจองให้อัตโนมัติ', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
            const SizedBox(height: 8),
            if (_info == null)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('ไม่พบรหัสการจอง')))
            else
              FutureBuilder<Map<String, dynamic>>(
                future: _info,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Text('${snap.error}'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            FilledButton(onPressed: () => setState(() => _info = ApiService.getPaymentInfo(widget.bookingCode!)), child: const Text('ลองใหม่')),
                          ],
                        ),
                      ),
                    );
                  }
                  final info = snap.data!;
                  if (info['status'] != 'pending') {
                    return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('รายการนี้ไม่ได้อยู่ในสถานะรอชำระเงิน')));
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (info['slipSubmitted'] == true)
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.info_outline_rounded, color: AppColors.primary),
                            title: Text('เคยส่งสลิปแล้ว'),
                            subtitle: Text('ส่งใหม่ได้หากต้องการเปลี่ยนสลิป'),
                          ),
                        ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'promptpay', label: Text('PromptPay QR'), icon: Icon(Icons.qr_code_2_rounded)),
                          ButtonSegment(value: 'bank', label: Text('โอนเข้าบัญชี'), icon: Icon(Icons.account_balance_rounded)),
                        ],
                        selected: {method},
                        onSelectionChanged: (v) => setState(() => method = v.first),
                      ),
                      const SizedBox(height: 12),
                      method == 'promptpay' ? _qrCard(info) : _bankCard(info),
                    ],
                  );
                },
              ),
            const SizedBox(height: 14),
            if (_slipBytes != null) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('สลิปการโอน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text))),
                          IconButton(tooltip: 'ลบรูป', onPressed: () => setState(() { _slip = null; _slipBytes = null; }), icon: const Icon(Icons.close_rounded)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: SizedBox(width: double.infinity, child: Image.memory(_slipBytes!, fit: BoxFit.contain)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _pickSlip,
              icon: Icon(_slipBytes != null ? Icons.swap_horiz_rounded : Icons.upload_file_rounded),
              label: Text(_slipBytes != null ? 'เปลี่ยนรูปสลิป' : 'แนบสลิปการโอน'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              // ต้องแนบสลิปก่อนถึงกดส่งได้
              onPressed: (_slip == null || _sending || widget.bookingCode == null) ? null : _submit,
              icon: const Icon(Icons.verified_rounded),
              label: Text(_sending ? 'กำลังส่ง...' : 'ส่งสลิปเพื่อยืนยันการชำระเงิน'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BookingListScreen()), (route) => route.isFirst),
              child: const Text('ชำระภายหลัง (การจองจะรอชำระเงิน)'),
            ),
          ],
        ),
      ),
    );
  }
}
