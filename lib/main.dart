import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
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
  int _quantity = 1;
  final int _price = 66000;

  void _searchAddress() {
    js.context.callMethod('openDaumPostcode', [
      js.allowInterop((String addr) {
        setState(() => _addressController.text = addr);
      }),
    ]);
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("정보를 모두 입력해주세요.")));
      return;
    }
    await Supabase.instance.client.from('orders').insert({
      'customer_name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'quantity': _quantity,
      'total_price': _price * _quantity,
      'status': '미처리',
    });
    _showDone();
  }

  void _showDone() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("접수 완료"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))]));
    _nameController.clear(); _phoneController.clear(); _addressController.clear();
    setState(() => _quantity = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('에그앤씨드 주문'), actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.pushNamed(context, '/admin_login'))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("고로쇠 수액 1.5L * 12병", style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 20),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '성함', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: '연락처', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _addressController, readOnly: true, onTap: _searchAddress, decoration: const InputDecoration(labelText: '주소 (클릭 검색)', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search))),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(onPressed: () => setState(() => _quantity > 1 ? _quantity-- : null), icon: const Icon(Icons.remove_circle_outline)),
                    Text("$_quantity", style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => setState(() => _quantity++), icon: const Icon(Icons.add_circle_outline)),
                  ]),
                  Text("총 합계: ${NumberFormat('#,###').format(_price * _quantity)}원", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.green), child: const Text('주문하기', style: TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
      ),
    );
  }
}

// --- [관리자 로그인] ---
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

// --- [관리자 목록 페이지] ---
class AdminListPage extends StatelessWidget {
  const AdminListPage({super.key});

  Future<void> _toggleStatus(int id, String currentStatus) async {
    final nextStatus = currentStatus == '완료' ? '미처리' : '완료';
    await Supabase.instance.client.from('orders').update({'status': nextStatus}).match({'id': id});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문 관리 마스터')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('orders').stream(primaryKey: ['id']).order('id', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data!;
          int totalSum = 0;
          int completedCount = 0;
          for (var o in orders) {
            totalSum += int.tryParse(o['total_price'].toString()) ?? 0;
            if (o['status'] == '완료') completedCount++;
          }
          return Column(
            children: [
              Container(padding: const EdgeInsets.all(15), color: Colors.blueGrey[50], child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [const Text("총 주문", style: TextStyle(fontSize: 12)), Text("${orders.length}건", style: const TextStyle(fontWeight: FontWeight.bold))]),
                  Column(children: [const Text("완료/미처리", style: TextStyle(fontSize: 12)), Text("$completedCount / ${orders.length - completedCount}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))]),
                  Column(children: [const Text("총 매출액", style: TextStyle(fontSize: 12)), Text("${NumberFormat('#,###').format(totalSum)}원", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                ],
              )),
              Expanded(
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    final bool isDone = o['status'] == '완료';
                    return Card(
                      color: isDone ? Colors.grey[100] : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: isDone ? Colors.grey : Colors.green, child: Text("${o['id']}", style: const TextStyle(color: Colors.white, fontSize: 12))),
                        title: Text("${o['customer_name']} (${o['quantity']}병)", style: TextStyle(fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null)),
                        subtitle: Text("${o['address']}\n${NumberFormat('#,###').format(int.tryParse(o['total_price'].toString()) ?? 0)}원"),
                        trailing: ElevatedButton(
                          onPressed: () => _toggleStatus(o['id'], o['status'] ?? '미처리'),
                          style: ElevatedButton.styleFrom(backgroundColor: isDone ? Colors.grey : Colors.orange),
                          child: Text(isDone ? "완료됨" : "처리하기", style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
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
}
