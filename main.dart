import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:intl/intl.dart';

const String taskKey = "realityCheckRemind";
final FlutterLocalNotificationsPlugin notificationPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == taskKey) {
      const AndroidNotificationDetails androidDetail =
          AndroidNotificationDetails(
        "lucid_remind",
        "清醒梦现实检验提醒",
        channelDescription: "定时弹出现实检验通知",
        importance: Importance.high,
        priority: Priority.high,
      );
      const NotificationDetails notifyDetail =
          NotificationDetails(android: androidDetail);
      await notificationPlugin.show(
        1,
        "现实检验",
        "我现在是在做梦吗？捏鼻试试能不能呼吸，看看文字会不会变形。回想一个梦境碎片。",
        notifyDetail,
      );
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);
  await notificationPlugin.initialize(initSettings);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "清醒梦训练助手",
      theme: ThemeData.dark()
          .copyWith(scaffoldBackgroundColor: const Color(0xff0b0c14)),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DreamLog {
  String time;
  String text;
  String tag;
  String mood;
  bool isLucid;
  String lucidNote;
  int timestamp;

  DreamLog({
    required this.time,
    required this.text,
    required this.tag,
    required this.mood,
    required this.isLucid,
    required this.lucidNote,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      "time": time,
      "text": text,
      "tag": tag,
      "mood": mood,
      "isLucid": isLucid,
      "lucidNote": lucidNote,
      "timestamp": timestamp,
    };
  }

  static DreamLog fromMap(Map<String, dynamic> m) {
    return DreamLog(
      time: m["time"],
      text: m["text"],
      tag: m["tag"],
      mood: m["mood"],
      isLucid: m["isLucid"],
      lucidNote: m["lucidNote"],
      timestamp: m["timestamp"],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentTab = 0;
  int stage = 1;
  List<DreamLog> dreamList = [];

  final TextEditingController dreamTextCtrl = TextEditingController();
  final TextEditingController dreamTagCtrl = TextEditingController();
  final TextEditingController lucidNoteCtrl = TextEditingController();
  String dreamMood = "情绪：平静";
  bool isLucid = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final sp = await SharedPreferences.getInstance();
    setState(() => stage = sp.getInt("stage") ?? 1);
    final raw = sp.getStringList("dreamData") ?? [];
    final list =
        raw.map((s) => DreamLog.fromMap(json.decode(s))).toList();
    setState(() => dreamList = list);
  }

  Future<void> saveDream() async {
    final sp = await SharedPreferences.getInstance();
    final log = DreamLog(
      time: DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now()),
      text: dreamTextCtrl.text,
      tag: dreamTagCtrl.text,
      mood: dreamMood,
      isLucid: isLucid,
      lucidNote: lucidNoteCtrl.text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    dreamList.insert(0, log);
    final arr = dreamList.map((d) => json.encode(d.toMap())).toList();
    await sp.setStringList("dreamData", arr);
    dreamTextCtrl.clear();
    dreamTagCtrl.clear();
    lucidNoteCtrl.clear();
    setState(() => isLucid = false);
    await checkStageUpgrade();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("梦境保存成功")));
    }
  }

  Future<void> checkStageUpgrade() async {
    final sp = await SharedPreferences.getInstance();
    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekRecords = dreamList
        .where((d) => DateTime.fromMillisecondsSinceEpoch(d.timestamp)
            .isAfter(weekStartDay))
        .toList();
    int newStage = stage;
    if (stage == 1 && weekRecords.length >= 4) newStage = 2;
    if (stage == 2 && weekRecords.any((r) => r.isLucid)) newStage = 3;
    if (newStage != stage) {
      setState(() => stage = newStage);
      await sp.setInt("stage", newStage);
    }
  }

  Future<void> scheduleRemind() async {
    await Workmanager().registerPeriodicTask(
      "remind10",
      taskKey,
      initialDelay: Duration(hours: _calcDelay(10)),
      frequency: const Duration(hours: 24),
      existsOnlyOnce: true,
    );
    await Workmanager().registerPeriodicTask(
      "remind15",
      taskKey,
      initialDelay: Duration(hours: _calcDelay(15)),
      frequency: const Duration(hours: 24),
      existsOnlyOnce: true,
    );
    await Workmanager().registerPeriodicTask(
      "remind19",
      taskKey,
      initialDelay: Duration(hours: _calcDelay(19)),
      frequency: const Duration(hours: 24),
      existsOnlyOnce: true,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅系统定时提醒已注册（10点/15点/19点）")));
    }
  }

  double _calcDelay(int targetHour) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, targetHour);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    return next.difference(now).inHours.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab,
        onTap: (idx) => setState(() => currentTab = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "主页"),
          BottomNavigationBarItem(
              icon: Icon(Icons.edit_note), label: "记录梦境"),
          BottomNavigationBarItem(
              icon: Icon(Icons.article), label: "梦境列表"),
        ],
      ),
      body: [buildHomePage(), buildRecordPage(), buildDreamListPage()]
          [currentTab],
    );
  }

  Widget buildHomePage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("清醒梦训练助手",
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text("当前阶段：$stage / 3",
            style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 20),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: scheduleRemind,
                child: const Text("开启每日现实检验提醒（10点/15点/19点）"))),
        const SizedBox(height: 20),
        const Text("阶段说明：",
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Text("阶段1：每周记录≥4次梦境 → 升级阶段2"),
        const Text("阶段2：成功做一次清醒梦 → 升级阶段3"),
        const Text("阶段3：自由练习控梦"),
        const SizedBox(height: 20),
        const Text("⚠️ WBTB每周最多2次，身体不适立刻停练。",
            style: TextStyle(color: Colors.orange)),
      ]),
    );
  }

  Widget buildRecordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        TextField(
            controller: dreamTextCtrl,
            decoration: const InputDecoration(labelText: "梦境内容"),
            maxLines: 3),
        const SizedBox(height: 12),
        TextField(
            controller: dreamTagCtrl,
            decoration:
                const InputDecoration(labelText: "标签（人物/场景/梦兆）")),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: dreamMood,
          decoration: const InputDecoration(labelText: "情绪"),
          items: const [
            DropdownMenuItem(value: "情绪：平静", child: Text("平静")),
            DropdownMenuItem(value: "情绪：恐惧", child: Text("恐惧")),
            DropdownMenuItem(value: "情绪：喜悦", child: Text("喜悦")),
            DropdownMenuItem(value: "情绪：压抑", child: Text("压抑")),
            DropdownMenuItem(value: "情绪：奇异", child: Text("奇异")),
          ],
          onChanged: (v) => setState(() => dreamMood = v!),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text("本次是清醒梦"),
          value: isLucid,
          onChanged: (v) => setState(() => isLucid = v!),
        ),
        if (isLucid)
          TextField(
              controller: lucidNoteCtrl,
              decoration: const InputDecoration(
                  labelText: "控梦体验备注（Lv1~Lv4）"),
              maxLines: 2),
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: saveDream, child: const Text("保存梦境记录"))),
      ]),
    );
  }

  Widget buildDreamListPage() {
    if (dreamList.isEmpty)
      return const Center(child: Text("还没有梦境记录，去记录第一条吧！"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dreamList.length,
      itemBuilder: (ctx, idx) {
        final item = dreamList[idx];
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.time,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(item.mood),
                  const SizedBox(height: 4),
                  Text(item.text),
                  if (item.tag.isNotEmpty)
                    Text("标签：${item.tag}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (item.isLucid)
                    const Text("✨ 清醒梦",
                        style: TextStyle(color: Colors.cyan)),
                  if (item.isLucid && item.lucidNote.isNotEmpty)
                    Text("控梦：${item.lucidNote}",
                        style: const TextStyle(fontSize: 12)),
                ])));
      },
    );
  }
}
