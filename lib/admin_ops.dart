import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'cloud.dart';
import 'store.dart';
import 'widgets.dart';

class AdminOpsScreen extends StatefulWidget {
  final String title;
  final String table;
  final String permission;
  final List<String> fields;
  final String statusField;
  const AdminOpsScreen({super.key, required this.title, required this.table, required this.permission, this.fields = const [], this.statusField = 'status'});
  @override
  State<AdminOpsScreen> createState() => _AdminOpsScreenState();
}

class _AdminOpsScreenState extends State<AdminOpsScreen> {
  bool loading = true;
  String error = '';
  List<Map<String, dynamic>> rows = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { loading = true; error = ''; });
    final data = await Cloud.select(widget.table, query: {'select': '*', 'limit': '150'});
    if (!mounted) return;
    setState(() { rows = data ?? []; loading = false; if (data == null) error = 'Data load nahi hua. Supabase migration, login aur role permissions check karein.'; });
  }
  Future<void> _create() async {
    final ctrls = {for (final f in widget.fields) f: TextEditingController()};
    String? result;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: EdgeInsets.fromLTRB(18, 20, 18, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Add ${widget.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ...ctrls.entries.map((e) => Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: e.value, decoration: InputDecoration(labelText: e.key.replaceAll('_', ' '))))),
        if (result != null) Text(result!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          final payload = <String, dynamic>{};
          for (final e in ctrls.entries) { final v = e.value.text.trim(); if (v.isNotEmpty) payload[e.key] = v; }
          final r = await Cloud.insert(widget.table, payload);
          if (r != null) { setS(() => result = r); return; }
          if (ctx.mounted) Navigator.pop(ctx);
          _load();
        }, child: const Text('Save'))),
      ])),
    )));
    for (final c in ctrls.values) { c.dispose(); }
  }
  Future<void> _changeStatus(Map<String, dynamic> row) async {
    final id = row['id']; if (id == null) { toast(context, 'Record ID missing'); return; }
    const options = ['requested','approved','rejected','pickup_scheduled','item_received','inspected','refund_open','closed','pending_admin_approval','processing','paid','open','in_progress','waiting_customer','resolved','cancelled'];
    final selected = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: options.map((v) => ListTile(title: Text(v.replaceAll('_',' ').toUpperCase()), onTap: () => Navigator.pop(ctx,v))).toList())));
    if (selected == null) return;
    String? err;
    if (widget.table == 'refund_records') {
      final result = await Cloud.invokeFunction('refund-admin-action', {'id':'$id','status':selected});
      err = result.ok ? null : result.error;
    } else {
      err = await Cloud.update(widget.table, {'id':'eq.$id'}, {widget.statusField:selected});
    }
    if (err != null) { if (mounted) toast(context, err); } else { _load(); }
  }
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.isAdmin || !store.adminUnlocked || !store.canManage(widget.permission)) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const EmptyState(title:'Access denied', subtitle:'Admin login required.', icon:Icons.lock_outline));
    return Scaffold(appBar: AppBar(title: Text(widget.title), actions:[IconButton(onPressed:_load, icon:const Icon(Icons.refresh))]),
      floatingActionButton: widget.fields.isEmpty ? null : FloatingActionButton.extended(onPressed:_create, icon:const Icon(Icons.add), label:const Text('Add')),
      body: loading ? const Center(child:CircularProgressIndicator()) : error.isNotEmpty ? Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(error,textAlign:TextAlign.center))) : rows.isEmpty ? EmptyState(title:'No ${widget.title.toLowerCase()} yet', subtitle:'New records will appear here.') : RefreshIndicator(onRefresh:_load, child:ListView.separated(padding:const EdgeInsets.all(14), itemCount:rows.length, separatorBuilder:(_,__)=>const SizedBox(height:8), itemBuilder:(ctx,i){
        final r=rows[i]; final title='${r['title'] ?? r['name'] ?? r['order_id'] ?? r['id'] ?? 'Record'}';
        final sub=r.entries.where((e)=>!['id','user_id','created_at','updated_at'].contains(e.key)).take(4).map((e)=>'${e.key}: ${e.value}').join('  ·  ');
        return Card(child:ListTile(title:Text(title,maxLines:1,overflow:TextOverflow.ellipsis), subtitle:Text(sub,maxLines:3,overflow:TextOverflow.ellipsis), trailing:widget.statusField.isEmpty?null:(r[widget.statusField] is bool?Switch(value:r[widget.statusField] as bool,onChanged:(v)async{final id=r['id']??r['product_id'];final err=await Cloud.update(widget.table,{'${r.containsKey('id')?'id':'product_id'}':'eq.$id'},{widget.statusField:v});if(err!=null){if(mounted)toast(context,err);}else{_load();}}):IconButton(tooltip:'Update status',icon:const Icon(Icons.edit_note),onPressed:()=>_changeStatus(r))), onTap:()=>showDialog(context:context,builder:(_)=>AlertDialog(title:Text(widget.title),content:SingleChildScrollView(child:Text(const JsonEncoder.withIndent('  ').convert(r))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]))));
      })));
  }
}

class AdminReportsScreen extends StatefulWidget { const AdminReportsScreen({super.key}); @override State<AdminReportsScreen> createState()=>_AdminReportsScreenState(); }
class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool loading=true, exporting=false; Map<String,int> counts={};
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final tables=['orders','return_requests','refund_records','payment_receipts','support_tickets','supplier_payments','products']; final m=<String,int>{}; for(final t in tables){final r=await Cloud.select(t,query:{'select':'id','limit':'1000'});m[t]=r?.length??0;} if(mounted)setState(() { counts=m; loading=false; }); }
  Future<void> _export() async {
    setState(()=>exporting=true);
    final tables=['orders','return_requests','refund_records','payment_receipts','support_tickets','supplier_payments'];
    final out=StringBuffer();
    for(final t in tables){
      final rows=await Cloud.select(t,query:{'select':'*','limit':'1000'});
      out.writeln(''); out.writeln('### $t');
      if(rows==null||rows.isEmpty){out.writeln('No data');continue;}
      final keys=rows.first.keys.toList();
      String cell(dynamic v){final raw=(v is Map||v is List)?jsonEncode(v):'${v??''}';return '"${raw.replaceAll('"','""')}"';}
      out.writeln(keys.map(cell).join(','));
      for(final r in rows){out.writeln(keys.map((k)=>cell(r[k])).join(','));}
    }
    final dir=await getTemporaryDirectory();
    final file=File('${dir.path}/zenvora_operations_export.csv');
    await file.writeAsString(out.toString());
    await Share.shareXFiles([XFile(file.path)],text:'Zenvora Mart operations export');
    if(mounted)setState(()=>exporting=false);
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Business analytics'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[Text('Operational overview · latest 1,000 records per module',style:TextStyle(color:muted)),const SizedBox(height:8),OutlinedButton.icon(onPressed:exporting?null:_export,icon:const Icon(Icons.file_download_outlined),label:Text(exporting?'Preparing export…':'Export operational data (CSV / Excel compatible)')),const SizedBox(height:12),...counts.entries.map((e)=>Card(child:ListTile(title:Text(e.key.replaceAll('_',' ').toUpperCase()),trailing:Text('${e.value}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:20))))),const SizedBox(height:12),Text('Note: CSV opens in Excel. Profit/loss needs supplier cost entries; scheduled backup/export must be configured in GitHub/Supabase.',style:TextStyle(color:muted))]));
}


class AdminAccessScreen extends StatefulWidget { const AdminAccessScreen({super.key}); @override State<AdminAccessScreen> createState()=>_AdminAccessScreenState(); }
class _AdminAccessScreenState extends State<AdminAccessScreen> {
  final email=TextEditingController(); String role='staff'; bool loading=false; String message='';
  final perms=<String,bool>{'products.manage':true,'orders.manage':true,'orders.update':false,'returns.manage':false,'refunds.manage':false,'support.manage':false,'suppliers.manage':false,'membership.manage':false,'messages.send':false,'analytics.view':false,'coupons.manage':false,'receipts.view':false,'audit.view':false,'settings.manage':false};
  Future<void> _submit({bool remove=false}) async { setState(()=>loading=true); final res=await Cloud.invokeFunction('admin-access-control',{'email':email.text.trim(),'role':role,'permissions':perms,'action':remove?'remove':'upsert'}); if(mounted)setState(() { loading=false; message=res.ok?'Admin access updated.':(res.error??'Request failed'); }); }
  @override void dispose(){email.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('X-Admin & Staff permissions')),body:ListView(padding:const EdgeInsets.all(16),children:[Text('Target user ka account pehle customer app mein create hona chahiye. Staff ko fixed Products + Orders access milega.',style:TextStyle(color:muted)),const SizedBox(height:12),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Registered user email')),const SizedBox(height:12),DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Role'),items:const [DropdownMenuItem(value:'staff',child:Text('Staff · limited access')),DropdownMenuItem(value:'x_admin',child:Text('X-Admin · custom permissions'))],onChanged:(v)=>setState(()=>role=v??'staff')),if(role=='x_admin')...perms.entries.map((e)=>SwitchListTile(title:Text(e.key),value:e.value,onChanged:(v)=>setState(()=>perms[e.key]=v))),if(message.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(message,style:TextStyle(color:muted))),const SizedBox(height:12),FilledButton(onPressed:loading?null:()=>_submit(),child:loading?const CircularProgressIndicator():const Text('Grant / Update access')),OutlinedButton(onPressed:loading?null:()=>_submit(remove:true),child:const Text('Revoke admin access'))]));
}
