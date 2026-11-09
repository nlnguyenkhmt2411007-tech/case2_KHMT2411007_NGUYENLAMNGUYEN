import 'package:flutter/material.dart';
import '../../services/collaboration_service.dart';
import 'assign_task_screen.dart';

class TaskTeamScreen extends StatefulWidget {
  final String taskId;
  final String title;
  const TaskTeamScreen({super.key,required this.taskId,required this.title});
  @override
  State<TaskTeamScreen> createState()=>_TaskTeamScreenState();
}
class _TaskTeamScreenState extends State<TaskTeamScreen> {
  bool loading=true, busy=false;
  String? error;
  Map<String,dynamic> data={};
  final emails=TextEditingController();
  String selectedRole='viewer';
  @override void initState(){super.initState();load();}
  @override void dispose(){emails.dispose();super.dispose();}
  Future<void> load() async {
    setState((){loading=true;error=null;});
    final result=await CollaborationService.team(widget.taskId);
    if(!mounted)return;
    setState((){loading=false;if(result['success']==true){data=result;}else{error='${result['message']}';}});
  }
  void message(String value){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));}
  Future<void> action(Future<Map<String,dynamic>> Function() request) async {
    if(busy)return;
    setState(()=>busy=true);
    final result=await request();
    if(!mounted)return;
    setState(()=>busy=false);
    message('${result['message']??(result['success']==true?'Thành công':'Thao tác thất bại')}');
    if(result['success']==true)await load();
  }
  List<String> parseEmails()=>emails.text.split(RegExp(r'[,;\n\r]+')).map((s)=>s.trim().toLowerCase()).where((s)=>s.isNotEmpty).toList();
  Future<void> share()async{
    final list=parseEmails();
    if(list.isEmpty || list.length>20 || list.toSet().length!=list.length || list.any((s)=>!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s))){message('Nhập 1–20 email hợp lệ, không trùng');return;}
    await action(()=>CollaborationService.share(widget.taskId,list,selectedRole));
    if(mounted)emails.clear();
  }
  Widget section(String title)=>Padding(padding:const EdgeInsets.fromLTRB(0,18,0,8),child:Text(title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)));
  Widget person(Map person, {String? subtitle,VoidCallback? onRemove,VoidCallback? onPrimary}) {
    return Card(child:ListTile(
      title:Text('${person['fullName']??''}'),subtitle:Text('${person['email']??''}${subtitle==null?'':'\n$subtitle'}'),
      isThreeLine:subtitle!=null,
      trailing: (onRemove==null && onPrimary==null)?null:PopupMenuButton<String>(
        onSelected:(value){if(value=='primary')onPrimary?.call();if(value=='remove')onRemove?.call();},
        itemBuilder:(_)=>[if(onPrimary!=null)const PopupMenuItem(value:'primary',child:Text('Chọn phụ trách chính')),if(onRemove!=null)const PopupMenuItem(value:'remove',child:Text('Thu hồi'))]
      )
    ));
  }
  @override Widget build(BuildContext context){
    final isOwner=data['role']=='owner';
    final assignees=(data['assignees'] as List?)??[];
    final shares=(data['shares'] as List?)??[];
    final primary=data['primaryAssignee'];
    return Scaffold(appBar:AppBar(title:const Text('Thành viên và chia sẻ'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
      body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):
      ListView(padding:const EdgeInsets.all(16),children:[
        Text(widget.title,style:Theme.of(context).textTheme.titleLarge),
        Text('Vai trò của bạn: ${data['role']}'),
        section('Người tạo'),if(data['owner'] is Map) person(data['owner'] as Map),
        section('Người phụ trách chính'),primary is Map?person(primary):const Text('Chưa chọn'),
        section('Người được giao (${assignees.length})'),
        if(assignees.isEmpty)const Text('Chưa có người được giao'),
        for(final item in assignees) if(item is Map) person(item,
          onPrimary:isOwner && !busy?()=>action(()=>CollaborationService.setPrimary(widget.taskId,'${item['email']}')):null,
          onRemove:isOwner && !busy?()=>action(()=>CollaborationService.removeAssignee(widget.taskId,'${item['_id']}')):null),
        if(isOwner) OutlinedButton.icon(onPressed:()=>Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>AssignTaskScreen(taskId:widget.taskId,taskTitle:widget.title))).then((_){if(mounted)load();}),icon:const Icon(Icons.person_add),label:const Text('Giao thêm người')),
        section('Người được chia sẻ (${shares.length})'),
        if(shares.isEmpty)const Text('Chưa chia sẻ'),
        for(final item in shares) if(item is Map && item['user'] is Map) person(item['user'] as Map,subtitle:'Quyền: ${item['role']}',
          onRemove:isOwner && !busy?()=>action(()=>CollaborationService.removeShare(widget.taskId,'${(item['user'] as Map)['_id']}')):null),
        if(isOwner)...[
          section('Chia sẻ / cập nhật quyền'),
          TextField(controller:emails,maxLines:3,decoration:const InputDecoration(labelText:'Email (mỗi dòng một người)',border:OutlineInputBorder())),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(initialValue:selectedRole,items:const [DropdownMenuItem(value:'viewer',child:Text('Viewer — chỉ xem')),DropdownMenuItem(value:'editor',child:Text('Editor — được sửa'))],onChanged:busy?null:(v)=>setState(()=>selectedRole=v??'viewer'),decoration:const InputDecoration(labelText:'Quyền chia sẻ')),
          const SizedBox(height:12),
          FilledButton.icon(onPressed:busy?null:share,icon:const Icon(Icons.share),label:Text(busy?'Đang xử lý...':'Cấp / cập nhật quyền')),
        ]
      ])
    );
  }
}
