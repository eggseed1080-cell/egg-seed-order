import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js; // 자바스크립트 호출을 위한 임포트
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xtjthadsvnbvcxyhrbrn.supabase.co',
    anonKey: 'sb_publishable_oAuKNnX9kFJWOwdia4nTuQ_H3XhnI5s',
  );
  runApp(const EggAndSeedApp());
}

// 연락처 자동 하이픈 포맷터
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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

  // --- 주소 자동 입력 함수 (JS 호출) ---
  void _searchAddress() {
    js.context.callMethod('openDaumPostcode', [
      (String addr) {
        setState(() {
          _addressController.text = addr; // 선택한 주소를 텍스트 필드에 입력
        });
      },
    ]);
  }

  // 주문 전 최종 검증 팝업
  void _confirmOrder() {
    if (_nameController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 정보를 입력해 주세요.')));
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
            Text(
              "수량: $_quantity병 / 결제금액: ${NumberFormat('#,###').format(66000 * _quantity)}원",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("수정"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveOrder();
            },
            child: const Text("최종 주문"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOrder() async {
    try {
      await Supabase.instance.client.from('orders').insert({
        'customer_name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'product_name': '고로쇠 수액 1.5L*12병',
        'quantity': _quantity,
        'total_price': 66000 * _quantity,
        'status': '입금대기',
      });
      _sendSMS();
      _showSuccess();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }

  void _sendSMS() async {
    final String msg =
        "[에그앤씨드 주문]\n성함: ${_nameController.text}\n금액: ${NumberFormat('#,###').format(66000 * _quantity)}원\n계좌: 카카오뱅크 3333-01-2345678";
    final Uri uri = Uri(
      scheme: 'sms',
      path: _phoneController.text,
      queryParameters: {'body': msg},
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("주문 접수 완료"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("확인"),
          ),
        ],
      ),
    );
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('에그앤씨드 주문'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/admin_login'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "고로쇠 수액 1.5L * 12병 (66,000원)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '성함',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                PhoneNumberFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: '연락처',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              readOnly: true,
              onTap: _searchAddress, // 탭하면 주소 자동 검색창 실행
              decoration: const InputDecoration(
                labelText: '주소 (클릭 시 자동 입력)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _confirmOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('주문하기'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 관리자 페이지 (기존 한국 시간대 변환 로직 포함) ---
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
      appBar: AppBar(title: const Text('관리자 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_pw.text == "admin123")
                  Navigator.pushReplacementNamed(context, '/admin_list');
              },
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminListPage extends StatelessWidget {
  const AdminListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문 목록 (한국 시간)')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, i) {
              final o = snapshot.data![i];
              // 한국 시간대 변환
              final date = DateFormat(
                'yyyy-MM-dd HH:mm',
              ).format(DateTime.parse(o['created_at']).toLocal());
              return Card(
                child: ListTile(
                  title: Text("${o['customer_name']} 님 ($date)"),
                  subtitle: Text("${o['address']}\n${o['phone']}"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
