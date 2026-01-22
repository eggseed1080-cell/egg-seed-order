import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'dart:convert';
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

// --- [주문 페이지: 실시간 합계 계산 및 주소 API 보완] ---
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
  final int _pricePerBox = 66000;

  void _searchAddress() {
    // allowInterop을 사용하여 JS 콜백 안전하게 처리
    js.context.callMethod('openDaumPostcode', [
      js.allowInterop((String addr) {
        setState(() => _addressController.text = addr);
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('에그앤씨드 주문')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("고로쇠 수액 1.5L * 12병", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 20),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '성함', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: '연락처', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              readOnly: true,
              onTap: _searchAddress,
              decoration: const InputDecoration(labelText: '주소 (클릭하여 검색)', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 30),
            
            // --- 주문 수량 및 실시간 합계 UI ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green)),
              child: Column(
                children: [
                  const Text("주문 수량 선택", style: TextStyle(fontSize: 18)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: () => setState(() => _quantity > 1 ? _quantity-- : null), icon: const Icon(Icons.remove_circle, color: Colors.red)),
                      Text("$_quantity", style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => setState(() => _quantity++), icon: const Icon(Icons.add_circle, color: Colors.green)),
                    ],
                  ),
                  const Divider(),
                  Text("총 주문금액: ${NumberFormat('#,###').format(_pricePerBox * _quantity)}원", 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submitOrder,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('주문하기', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_addressController.text.isEmpty) return;
    try {
      await Supabase.instance.client.from('orders').insert({
        'customer_name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'quantity': _quantity,
        'total_price': _pricePerBox * _quantity,
        'status': '미처리',
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문이 접수되었습니다.')));
    } catch (e) {
      print(e);
    }
  }
}

// --- [관리자 페이지: 데이터 출력 에러 해결] ---
class AdminListPage extends StatelessWidget {
  const AdminListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문 마스터')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('orders').stream(primaryKey: ['id']).order('id', ascending: false),
        builder: (context, snapshot) {
          // 데이터가 오고 있는 중이거나 에러가 났을 때 처리
          if (snapshot.hasError) return Center(child: Text("에러: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!;
          int totalSum = 0;
          for (var o in orders) {
            // 타입 에러 방지를 위해 toString() 후 파싱
            totalSum += int.tryParse(o['total_price'].toString()) ?? 0;
          }

          return Column(
            children: [
              Container(padding: const EdgeInsets.all(15), color: Colors.blueGrey[100], child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("총 건수: ${orders.length}건"),
                  Text("총 매출: ${NumberFormat('#,###').format(totalSum)}원", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              )),
              Expanded(
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text("${o['id']}")),
                        title: Text("${o['customer_name']} (${o['quantity']}병)"),
                        subtitle: Text("${o['address']}\n${NumberFormat('#,###').format(int.tryParse(o['total_price'].toString()) ?? 0)}원"),
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

// AdminLoginPage 등 나머지 코드는 기존 유지
class AdminLoginPage extends StatelessWidget {
  const AdminLoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/admin_list'), child: const Text("관리자 접속"))));
  }
}

class EggAndSeedApp extends StatelessWidget {
  const EggAndSeedApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: const CustomerOrderPage(), routes: {
      '/admin_list': (context) => const AdminListPage(),
    });
  }
}
