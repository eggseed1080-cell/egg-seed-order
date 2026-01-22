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

// 주문 페이지
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
    // allowInterop을 사용하여 자바스크립트 에러 방지
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
            const Text("고로쇠 수액 1.5L * 12병", style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 20),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '성함', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: '연락처', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _addressController, readOnly: true, onTap: _searchAddress, 
              decoration: const InputDecoration(labelText: '주소 (클릭 검색)', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search))),
            const SizedBox(height: 20),
            
            // 수량 및 실시간 금액 합계 표시
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
            ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.green), 
              child: const Text('주문하기', style: TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
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
  }
}

// 관리자 마스터 페이지 (데이터 표시 해결)
class AdminListPage extends StatelessWidget {
  const AdminListPage({super.key});

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
          for (var o in orders) {
            // 에러 방지를 위해 toString() 후 파싱
            totalSum += int.tryParse(o['total_price'].toString()) ?? 0;
          }

          return Column(
            children: [
              Container(padding: const EdgeInsets.all(15), color: Colors.blueGrey[50], 
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("총 주문: ${orders.length}건"),
                  Text("총 매출액: ${NumberFormat('#,###').format(totalSum)}원", style: const TextStyle(fontWeight: FontWeight.bold)),
                ])),
              Expanded(
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    return Card(child: ListTile(
                      title: Text("${o['customer_name']} (${o['quantity']}병)"),
                      subtitle: Text("${o['address']}\n${NumberFormat('#,###').format(int.tryParse(o['total_price'].toString()) ?? 0)}원"),
                    ));
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

class EggAndSeedApp extends StatelessWidget {
  const EggAndSeedApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: const CustomerOrderPage(), routes: {
      '/admin_login': (context) => const CustomerOrderPage(), // 실제 경로에 맞게 수정
      '/admin_list': (context) => const AdminListPage(),
    });
  }
}
