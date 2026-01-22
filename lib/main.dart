import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xtjthadsvnbvcxyhrbrn.supabase.co',
    anonKey: 'sb_publishable_oAuKNnX9kFJWOwdia4nTuQ_H3XhnI5s',
  );
  runApp(const EggAndSeedApp());
}

// 연락처 포맷터 (010-0000-0000)
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 11) text = text.substring(0, 11);
    String formatted = '';
    if (text.length >= 3) {
      formatted += '${text.substring(0, 3)}-';
      if (text.length >= 7) {
        formatted += '${text.substring(3, 7)}-${text.substring(7)}';
      } else {
        formatted += text.substring(3);
      }
    } else {
      formatted = text;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class EggAndSeedApp extends StatelessWidget {
  const EggAndSeedApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '에그앤씨드 고로쇠',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const CustomerOrderPage(),
      routes: {
        '/admin_login': (context) => const AdminLoginPage(),
        '/admin_list': (context) => const AdminListPage(),
      },
    );
  }
}

class CustomerOrderPage extends StatefulWidget {
  const CustomerOrderPage({super.key});
  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  int _quantity = 1;
  final int _unitPrice = 66000;

  void _searchAddress() {
    js.context.callMethod('openDaumPostcode', [
      (String addr) {
        setState(() => _addressController.text = addr);
      },
    ]);
  }

  void _confirmOrder() {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty || _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('배송 정보를 모두 입력해 주세요.'), backgroundColor: Colors.redAccent));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("주문 내용 확인"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("성함: ${_nameController.text}"),
            Text("연락처: ${_phoneController.text}"),
            Text("주소: ${_addressController.text}"),
            const Divider(),
            Text("최종 수량: $_quantity병"),
            Text("결제 금액: ${NumberFormat('#,###').format(_unitPrice * _quantity)}원"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("수정")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _saveOrder(); }, child: const Text("주문 확정")),
        ],
      ),
    );
  }

  Future<void> _saveOrder() async {
    try {
      await Supabase.instance.client.from('orders').insert({
        'customer_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'product_name': '고로쇠 수액 1.5L*12병',
        'quantity': _quantity,
        'total_price': _unitPrice * _quantity,
        'status': '미처리',
      });
      _sendSMS();
      _showSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    }
  }

  void _sendSMS() async {
    final String msg = "[에그앤씨드]\n입금대기: ${NumberFormat('#,###').format(_unitPrice * _quantity)}원\n계좌: 카카오뱅크 3333-01-2345678";
    final Uri uri = Uri(scheme: 'sms', path: _phoneController.text, queryParameters: {'body': msg});
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showSuccess() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("접수 완료"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))]));
    _nameController.clear(); _phoneController.clear(); _addressController.clear();
    setState(() => _quantity = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('에그앤씨드 주문'), actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.pushNamed(context, '/admin_login'))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text("고로쇠 수액 1.5L * 12병", textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
            Text("단가: ${NumberFormat('#,###').format(_unitPrice)}원", style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 30),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '성함', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _phoneController, inputFormatters: [PhoneNumberFormatter()], decoration: const InputDecoration(labelText: '연락처', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _addressController, readOnly: true, onTap: _searchAddress, decoration: const InputDecoration(labelText: '주소 (클릭하여 검색)', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search))),
            const SizedBox(height: 30),
            
            // --- 주문 수량 및 합계 실시간 표시 ---
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  const Text("주문 수량 설정", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: () => setState(() => _quantity > 1 ? _quantity-- : null), icon: const Icon(Icons.remove_circle, color: Colors.redAccent)),
                      Text("$_quantity", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => setState(() => _quantity++), icon: const Icon(Icons.add_circle, color: Colors.green)),
                    ],
                  ),
                  const Divider(),
                  Text("총 주문 합계: ${NumberFormat('#,###').format(_unitPrice * _quantity)}원", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _confirmOrder, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 65), backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('위 내용으로 주문하기', style: TextStyle(fontSize: 20))),
          ],
        ),
      ),
    );
  }
}

// --- [관리자 목록 페이지: 안정성 강화 버전] ---
class AdminListPage extends StatefulWidget {
  const AdminListPage({super.key});
  @override
  State<AdminListPage> createState() => _AdminListPageState();
}

class _AdminListPageState extends State<AdminListPage> {
  DateTime? _filterDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 마스터')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('orders').stream(primaryKey: ['id']).order('id', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("데이터 오류: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allOrders = snapshot.data!;
          int totalQty = 0;
          int totalPrice = 0;

          // 데이터 안전 파싱 및 통계 계산
          for (var o in allOrders) {
            totalQty += int.tryParse(o['quantity'].toString()) ?? 0;
            totalPrice += int.tryParse(o['total_price'].toString()) ?? 0;
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                color: Colors.blueGrey[50],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummary("총 건수", "${allOrders.length}건"),
                    _buildSummary("총 수량", "$totalQty병"),
                    _buildSummary("총 합계", "${NumberFormat('#,###').format(totalPrice)}원"),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: allOrders.length,
                  itemBuilder: (context, i) {
                    final o = allOrders[i];
                    final String name = o['customer_name']?.toString() ?? "이름없음";
                    final String date = o['created_at'] != null ? DateFormat('MM/dd HH:mm').format(DateTime.parse(o['created_at']).toLocal()) : "-";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(child: Text("${o['id']}")),
                        title: Text("$name 님 ($date)", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${o['address']}\n수량: ${o['quantity']}병 / 금액: ${NumberFormat('#,###').format(int.tryParse(o['total_price'].toString()) ?? 0)}원"),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary(String title, String value) {
    return Column(children: [Text(title, style: const TextStyle(fontSize: 12)), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue))]);
  }
}

// 관리자 로그인 생략 (기존 코드 유지)
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _pw = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 인증')),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(children: [
          TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호')),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () { if (_pw.text == "admin123") Navigator.pushReplacementNamed(context, '/admin_list'); }, child: const Text('로그인'))
        ]),
      ),
    );
  }
}
