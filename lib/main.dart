import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
// 웹 환경에서의 다운로드를 위해 추가
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 설정
  await Supabase.initialize(
    url: 'https://xtjthadsvnbvcxyhrbrn.supabase.co',
    anonKey: 'sb_publishable_oAuKNnX9kFJWOwdia4nTuQ_H3XhnI5s',
  );
  runApp(const EggAndSeedApp());
}

class EggAndSeedApp extends StatelessWidget {
  const EggAndSeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '에그앤씨드 고로쇠',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const CustomerOrderPage(),
        '/admin_login': (context) => const AdminLoginPage(),
        '/admin_list': (context) => const AdminListPage(),
      },
    );
  }
}

// --- [관리자 로그인 페이지] ---
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _passwordController = TextEditingController();
  final String _adminPassword = "admin123";

  void _login() {
    if (_passwordController.text == _adminPassword) {
      Navigator.pushReplacementNamed(context, '/admin_list');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 올바르지 않습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 인증')),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호를 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _login,
                child: const Text('로그인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- [고객 주문 페이지] ---
class CustomerOrderPage extends StatefulWidget {
  const CustomerOrderPage({super.key});
  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // 요구사항 반영: 4.5L 삭제, 1.5L 66,000원으로 수정
  final List<Map<String, dynamic>> _products = [
    {'name': '고로쇠 수액 1.5L', 'price': 66000},
  ];

  int _selectedProductIndex = 0;
  int _quantity = 1;

  // 입력 필드 초기화 함수
  void _resetFields() {
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
    setState(() {
      _quantity = 1;
      _selectedProductIndex = 0;
    });
  }

  Future<void> _submitOrder() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('배송 정보를 모두 입력해 주세요.')));
      return;
    }

    try {
      await Supabase.instance.client.from('orders').insert({
        'customer_name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'product_name': _products[_selectedProductIndex]['name'],
        'quantity': _quantity,
        'total_price': _products[_selectedProductIndex]['price'] * _quantity,
        'status': '입금대기',
        'tracking_number': '',
      });
      if (mounted) {
        _showSuccessDialog();
        _resetFields(); // 주문 성공 시 필드 초기화
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('주문 실패: $e')));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("주문 완료"),
        content: const Text("성공적으로 주문이 접수되었습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('에그앤씨드 고로쇠 주문'),
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
            const Icon(Icons.water_drop, size: 60, color: Colors.blue),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: _selectedProductIndex,
              decoration: const InputDecoration(
                labelText: '상품 선택',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                _products.length,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    "${_products[i]['name']} (${NumberFormat('#,###').format(_products[i]['price'])}원)",
                  ),
                ),
              ),
              onChanged: (v) => setState(() => _selectedProductIndex = v!),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("수량 선택", style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          setState(() => _quantity > 1 ? _quantity-- : null),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      "$_quantity",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '성함',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '연락처',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: '주소',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submitOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('주문하기', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- [관리자 목록 페이지] ---
class AdminListPage extends StatefulWidget {
  const AdminListPage({super.key});
  @override
  State<AdminListPage> createState() => _AdminListPageState();
}

class _AdminListPageState extends State<AdminListPage> {
  final List<String> _statusOptions = ['입금대기', '결제완료', '배송중', '배송완료', '취소'];

  // 웹 전용 엑셀 내보내기 함수
  void _exportToExcelWeb(List<Map<String, dynamic>> orders) {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Orders'];

    sheet.appendRow([
      TextCellValue('주문일자'),
      TextCellValue('주문자'),
      TextCellValue('연락처'),
      TextCellValue('주소'),
      TextCellValue('상품명'),
      TextCellValue('수량'),
      TextCellValue('금액'),
      TextCellValue('상태'),
      TextCellValue('송장번호'),
    ]);

    for (var o in orders) {
      final String formattedDate = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(DateTime.parse(o['created_at']));
      sheet.appendRow([
        TextCellValue(formattedDate),
        TextCellValue(o['customer_name']),
        TextCellValue(o['phone']),
        TextCellValue(o['address']),
        TextCellValue(o['product_name']),
        IntCellValue(o['quantity']),
        IntCellValue(o['total_price']),
        TextCellValue(o['status']),
        TextCellValue(o['tracking_number'] ?? ''),
      ]);
    }

    // 웹에서 다운로드 트리거
    final bytes = excel.encode();
    if (bytes != null) {
      final content = base64Encode(bytes);
      final anchor =
          html.AnchorElement(
              href:
                  "data:application/octet-stream;charset=utf-16le;base64,$content",
            )
            ..setAttribute(
              "download",
              "고로쇠_주문내역_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx",
            )
            ..click();
    }
  }

  Future<void> _updateStatus(dynamic id, String newStatus) async {
    await Supabase.instance.client
        .from('orders')
        .update({'status': newStatus})
        .match({'id': id});
  }

  Future<void> _updateTracking(dynamic id, String tracking) async {
    await Supabase.instance.client
        .from('orders')
        .update({'tracking_number': tracking})
        .match({'id': id});
  }

  Future<void> _deleteOrder(dynamic id) async {
    await Supabase.instance.client.from('orders').delete().match({'id': id});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 관리 마스터'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('orders')
                .stream(primaryKey: ['id']),
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.file_download),
                onPressed: snapshot.hasData
                    ? () => _exportToExcelWeb(snapshot.data!)
                    : null,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              final trackingController = TextEditingController(
                text: o['tracking_number'],
              );
              final String displayDate = DateFormat(
                'MM/dd HH:mm',
              ).format(DateTime.parse(o['created_at']));

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${o['customer_name']} 님 ($displayDate)",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<String>(
                            value: _statusOptions.contains(o['status'])
                                ? o['status']
                                : '입금대기',
                            items: _statusOptions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => _updateStatus(o['id'], val!),
                          ),
                        ],
                      ),
                      Text("연락처: ${o['phone']}"),
                      Text("주소: ${o['address']}"),
                      Text(
                        "주문: ${o['product_name']} / ${o['quantity']}병",
                        style: const TextStyle(color: Colors.blue),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: trackingController,
                              decoration: const InputDecoration(
                                hintText: '송장번호',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.save, color: Colors.green),
                            onPressed: () => _updateTracking(
                              o['id'],
                              trackingController.text,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("삭제 확인"),
                                  content: const Text("이 주문을 정말 삭제할까요?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("취소"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _deleteOrder(o['id']);
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text(
                                        "삭제",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
